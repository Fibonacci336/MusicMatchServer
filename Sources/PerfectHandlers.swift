//
//  PerfectHandlers.swift
//  MusicMatchServer
//
//  Created by Ben Carlson on 4/23/16.
//  Copyright © 2016 Ben Carlson. All rights reserved.
//

//
//  PerfectHandlers.swift
//  MusicMatchServer
//
//  Created by Ben Carlson on 4/23/16.
//  Copyright © 2016 Ben Carlson. All rights reserved.
//

#if os(Linux)
import SwiftGlibc
#else
import AVKit
import AVFoundation
import Darwin
#endif

import SwiftGD

import PerfectMySQL

import PerfectLib
import PerfectHTTP
import PerfectHTTPServer
import PerfectNotifications
import Foundation


// host where mysql server is

//#if os(Linux)
let HOST = "fibonacciinstance.ceqqk1kcroae.us-west-2.rds.amazonaws.com"
let USER = "fibonacci"
//#else
//let HOST = "127.0.0.1"
//// mysql username
//let USER = "root"
//#endif
// mysql root password
let PASSWORD = "123qweasdzxC"
// database name
let SCHEMA = "MusicMatch"

var currentURL = "http://0.0.0.0:8181/"


//public method that is being called by the server framework to initialise your module.
public func PerfectServerModuleInit() {
    
    do{
        let mysql = try initializeDatabaseConnection()
    }catch{
        print("Could not initialize database connection or created database")
    }
    initializeUserData()
    initializeMessagesData()
    initializeUserLogInData()
    initializeNotificationSystem(configurationName: "MusicMatch.Configuration")
    initializeNotificationSystem(configurationName: "MusicMatch.Silent.Configuration")
    if(production){
        currentURL = "http://www.lassoconsultant.com:8183/"
        print("Production")
    }
    
}

public enum ServerError: Swift.Error {
    case generic(String)
}

//MOCKSTOCK HANDLERS
func stockListHandler(_ request : HTTPRequest, response : HTTPResponse){
    print("Handling Stock Request")
}


func messageHandler(_ request : HTTPRequest, response : HTTPResponse){
    print("Handling Message Request")
    
    if let dict = try? request.postBodyString!.jsonDecode() as! [String : String]{
        print(dict)
        let messageUUID = dict["messageUUID"]
        let senderUUID = dict["sender"]
        let recipientUUID = dict["recipient"]
        let messageBody = dict["body"]
        let date = dict["date"]
        let status = dict["status"]
        let messageType = dict["mediatype"]
        
        
        
        let messageDataRequest = "INSERT INTO Messages (MessageUUID, Sender, Recipient, MessageContent, SendDate, Status, MessageType) VALUES (\"\(messageUUID!)\", \"\(senderUUID!)\", \"\(recipientUUID!)\", \"\(messageBody!)\", \"\(date!)\", \"\(status!)\", \"\(messageType!)\");"
        let data = try? getDataFromDatabase(with: messageDataRequest)
        
        sendMessageNotification(message: messageBody!, recipientUUID: recipientUUID!, senderUUID: senderUUID!)
        
    }else{
        print("Could not convert body string to dictionary")
    }
    
}

func getDataFromDatabase(with request : String) throws -> [Int : [String?]]{
    
    guard request != "" else{
        print("Empty Request")
        throw DatabaseError.emptyRequestError
    }
    let mysql = try initializeDatabaseConnection()
    defer {
        mysql.close()
    }
    
    let query = mysql.query(statement: request)
    if(query){
        var dictionary = [Int : [String?]]()
        if let queryResults = mysql.storeResults(){
            var index = 0
            queryResults.forEachRow{ row in
                dictionary[index] = row
                index+=1
            }
            
            return dictionary
        }else{
            return dictionary
        }
    }else{
        print("Request Failed")
        throw DatabaseError.failedRequestError
    }
    
    
}


func sendSilentMessageNotification(recipientDeviceToken : String){
    let notificationArray = [APNSNotificationItem.contentAvailable]
    let pusher = NotificationPusher()
    
    pusher.apnsTopic = "com.fibonacci.MusicMatch"
    let configurationName = "MusicMatch.Silent.Configuration"
    pusher.pushIOS(configurationName: configurationName, deviceToken: recipientDeviceToken, expiration: 0, priority: 10,notificationItems: notificationArray, callback:{
        (response : NotificationResponse) -> Void in
        print(response.status)
    })
}



func sendMessageNotification(message : String, recipientUUID : String, senderUUID : String){
    let senderDataRequest = "SELECT UserName,DeviceToken FROM Users WHERE UUID=\"\(senderUUID)\" OR UUID=\"\(recipientUUID)\";"
    if let data = try? getDataFromDatabase(with: senderDataRequest){
        
        guard !data.isEmpty else{
            print("Empty Dictionary")
            return
        }
        
        
        let senderUser = data[0]
        
        guard let recipientUser = data[1] else{
            print("Nil Recipient User")
            return
        }
        
        guard let deviceToken = recipientUser[1] else{
            print("Nil Device Token, Possibly a Simulator Account?")
            return
        }
        //Send Notification
        let notificationArray = [APNSNotificationItem.alertBody(message), APNSNotificationItem.sound("default"), APNSNotificationItem.alertTitle(senderUser![0]!)]
        let pusher = NotificationPusher()
        
        pusher.apnsTopic = "com.fibonacci.MusicMatch"
        let configurationName = "MusicMatch.Configuration"
        sendSilentMessageNotification(recipientDeviceToken: deviceToken)
        pusher.pushIOS(configurationName: configurationName, deviceToken: deviceToken, expiration: 0, priority: 10,notificationItems: notificationArray, callback:{
            (response : NotificationResponse) -> Void in
            print(response.status)
        })
        
    }
    
}

func fileAccessed(_ request : HTTPRequest, response : HTTPResponse){
    
    print("Accessing File: \(request.uri)")
    
    StaticFileHandler(documentRoot: webRoot).handleRequest(request: request, response: response)
}

func fileUpload(_ request : HTTPRequest, response : HTTPResponse){
    
    print("Handling File Upload Request")
    
    print(request.postFileUploads)
    
    print("Media Type: " + request.urlVariables.first!.value)
    let upload = request.postFileUploads![0]
    
    guard upload.fileName != "" else{
        print("Empty Upload File Name, Can Not Save File")
        response.completed(status: .badRequest)
        return
    }
    let file = File(upload.tmpFileName)
    do {
        let _ = try file.moveTo(path: webRoot + "/" + upload.fileName, overWrite: true)
    } catch {
        print(error)
    }
    response.completed()
}


func recieveLocalUsers(_ request: HTTPRequest, response: HTTPResponse) {
    let requestArray = request.postBodyString?.components(separatedBy: ",")
    var currentUUID = requestArray![0]
    let userRange : Double = Double((requestArray?[1])!)!
    
    var currentLat = Double(requestArray![2])!
    var currentLong = Double(requestArray![3])!
    
    
    var currentDict = [String : [String?]]()
    do{
        let mysql = try initializeDatabaseConnection()
        defer {
            mysql.close()
        }
        
        //If uploaded coordinates are 0,0(invalid), check server for last updated coordinates
        if currentLat == 0 && currentLong == 0{
            let mysqlStatement = "SELECT CurrentLat, CurrentLong FROM Users WHERE UUID=\"\(currentUUID)\";"
            _ = mysql.query(statement: mysqlStatement)
            let results = mysql.storeResults()
            
            results?.forEachRow{ row in
                
                currentLat = Double(row[0]!)!
                currentLong = Double(row[1]!)!
            }
        }
        
        let mysqlStatement = "UPDATE Users SET CurrentLat=\(currentLat), CurrentLong=\(currentLong) WHERE UUID=\"\(currentUUID)\";"
        
        
        print("MySQL Query Did Succeed?: \(mysql.query(statement: mysqlStatement))")
        
        var userArray = getUsersInArea(currentLat: currentLat, currentLong: currentLong, range: userRange)!
        
        var returnDict = [String : [String?]]()
        
        for i in 0..<userArray.keys.count{
            let UUID = userArray[i]
            let statement = "SELECT UserType,UserName,BirthDate,MusicType,BandPosition,UserMedia,Available,UUID, CurrentLat, CurrentLong, DistanceUnit, LastLogin FROM Users where UUID=\"" + UUID! + "\";"
            let query = mysql.query(statement: statement)
            
            if(query){
                if let queryResults = mysql.storeResults(){
                    let row = queryResults.next()!
                    returnDict[String(i)] = row
                }
            }
            
        }
        currentDict = returnDict
        
    }catch{
        print("Could not initialize database connection")
    }
    
    do{
        let jsonString = try currentDict.jsonEncodedString()
        response.appendBody(string: jsonString)
        print("Successfully Converted Dictionary to String")
    }catch JSONConversionError.notConvertible(let key){
        print("Not convertible \(key)")
    }catch JSONConversionError.invalidKey(let key){
        print("Invalid Key \(key)")
    }catch{
        print("Failed to encode dictionary")
    }
    response.completed()
}

func restJSONHandler(_ request: HTTPRequest, response: HTTPResponse) {
    do{
        let mysql = try initializeDatabaseConnection()
        defer {
            mysql.close()
        }
        print("Getting REST Query")
        let statement = request.postBodyString!
        
        if statement.contains(string: "SELECT"){
            print("Returning Data From REST Query")
        }else if statement.contains(string: "UPDATE"){
            print("Updating Server Data")
        }
        
        let query = mysql.query(statement: statement)
        if(query){
            var dictionary = [String : [String?]]()
            if let queryResults = mysql.storeResults(){
                var index = 0
                queryResults.forEachRow{ row in
                    print(row)
                    dictionary[String(index)] = row
                    index+=1
                }
                
                do{
                    let jsonString = try dictionary.jsonEncodedString()
                    response.appendBody(string: jsonString)
                }catch{
                    print("Could not encode dictionary")
                }
            }else{
                response.appendBody(string: "true")
            }
        }
    }catch{
        print("Could not initialize database connection")
        response.appendBody(string: "false")
    }
    response.completed()
}


//Create a handler for index Route

func indexHandler(_ request: HTTPRequest, response: HTTPResponse) {
    response.appendBody(string: "Hello")
    response.completed()
}

func thumbHandler(_ request: HTTPRequest, response: HTTPResponse) {
    
    print("Handling Thumbnail Request")
    
    let extensions = [".MOV", ".mov", ".mp4"]
    
    let imagePath = (request.urlVariables["videoname"]!) + ".png"
    let documentsDir = webRoot + "/"
    for string in extensions{
        let videoPath = (request.urlVariables["videoname"]!) + string
        if let thumbnail = try? getVideoThumbnail(videoURL: currentURL + videoPath){
            #if !os(Linux)
            saveImage(thumbnail, locationPath: documentsDir + imagePath)
            #endif
            response.appendBody(string: imagePath)
            break
        }
    }
    
    response.completed()
}

#if !os(Linux)
func getDocumentsDirectory() -> String {
    let fileManager = FileManager.default
    let documentsDirectory = fileManager.currentDirectoryPath
    return documentsDirectory
}
#endif

func fileExistsHandler(_ request: HTTPRequest, response: HTTPResponse) {
    let name = request.urlVariables["fileName"]
    let doesExist = fileExists(fileName: name!)
    
    response.appendBody(string: String(doesExist))
    response.completed()
}


func fileExists(fileName : String) -> Bool{
    
    
    let fileManager = FileManager.default
    let filePath = webRoot + "/" + fileName
    
    return fileManager.fileExists(atPath: filePath)
    
}

func getVideoThumbnail(videoURL : String) throws -> Image{
    #if os(Linux)
    return try getVideoThumbnailFromLinux(videoURL: videoURL)
    #else
    return try getVideoThumbnailFromOSX(videoURL: videoURL)
    #endif
    
}
#if os(Linux)
func getVideoThumbnailFromLinux(videoURL : String) throws -> Image{
    
    let videoPath = webRoot + "/" + videoURL.lastFilePathComponent
    let imagePath = webRoot + "/" + videoURL.lastFilePathComponent.deletingFileExtension + ".png"
    
    var duration : Double = 0
    let durationString = runTerminalCommand(with: "./getVideoDurationLinux", args: videoPath).outputArray[0]
    if let durationDouble = Double(durationString){
        duration = durationDouble
    }
    
    //Input Video, Output Image, Time for Thumbnail
    let exitCode = runTerminalCommand(with: "./createThumbnailLinux", args: videoPath, imagePath, String(duration/2))
    print(exitCode)
    
    let imageURL = URL(fileURLWithPath: imagePath)
    
    
    guard let thumbnail = Image(url: imageURL) else{
        throw ServerError.generic("Could not access image")
    }
    
    return thumbnail
}
#endif

#if !os(Linux)
func getVideoThumbnailFromOSX(videoURL : String) throws -> Image{
    
    let asset = AVAsset(url: URL(string: videoURL)!)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    var time = asset.duration
    time.value /= 2
    
    if let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil){
        
        guard let cgImageData = cgImage.data else{
            throw FileError.exportFailed
        }
        
        let image = try Image(data: cgImageData, as: .any)
        return image
    }else{
        print("Returning Nil Thumbnail for Video " + videoURL)
        throw ServerError.couldNotAccessImage
    }
    
}
/*
 func saveImage(_ image : NSImage, locationPath : String){
 let cgRef = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
 let newRep: NSBitmapImageRep = NSBitmapImageRep(cgImage: cgRef)
 newRep.size = image.size
 // if you want the same resolution
 let fileManager = FileManager.default
 let pngData = newRep.representation(using: NSBitmapImageFileType.PNG, properties: [:])
 guard fileManager.createFile(atPath: locationPath, contents: pngData, attributes: [:]) else{
 print("Could not write to PNG file")
 return
 }
 print("Successfully wrote to PNG file")
 
 }
 */
func saveImage(_ image : Image, locationPath : String){
    
    guard let imageURL = URL(string: locationPath) else{
        return
    }
    
    if image.write(to: imageURL){
        print("Successfully wrote to PNG file")
        return
    }
    print("Could not write to PNG file")
}
#endif

func getUsersInArea(currentLat : Double, currentLong : Double, range : Double) -> [Int : String]?{
    
    do{
        let mysql = try initializeDatabaseConnection()
        defer {
            mysql.close()
        }
        
        let formula = "111.045* DEGREES(ACOS(COS(RADIANS(\(currentLat))) * COS(RADIANS(CurrentLat)) * COS(RADIANS(\(currentLong)) - RADIANS(CurrentLong)) + SIN(RADIANS(\(currentLat))) * SIN(RADIANS(CurrentLat))))"
        let statement = "SELECT UUID,CurrentLat,CurrentLong, Available FROM Users WHERE " + formula
        let fullStatement = statement + " <= \(range) AND Available=1;"
        print("Executing User Query")
        print(mysql.query(statement: fullStatement))
        let results = mysql.storeResults()
        var uuidArray = [Int : String]()
        var index = 0
        print(results?.numRows())
        results?.forEachRow{ row in
            uuidArray[index] = row[0]
            index+=1
        }
        
        return uuidArray
        
        
    }catch{
        print("Could not initialize database connection")
        return nil
    }
}

#if !os(Linux)
extension CGImage{
    
    
    var data : Data?{
        
        guard let mutableData = CFDataCreateMutable(nil, 0) else{
            return nil
        }
        guard let destination = CGImageDestinationCreateWithData(mutableData,  "public.png" as CFString, 1, nil) else{
            return nil
        }
        
        CGImageDestinationAddImage(destination, self, nil)
        if CGImageDestinationFinalize(destination) {
            return mutableData as Data
        }
        print("Error writing Image")
        return nil
        
    }
    
}
#endif

@discardableResult
func runTerminalCommand(with command : String, args: String...) -> (statusCode: Int, outputArray : [String]){
    
    var output : [String] = []
    
    var completeArgs = args
    completeArgs.insert(command, at: 0)
    
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = completeArgs
    
    //Gets Output From Command
    let outpipe = Pipe()
    task.standardOutput = outpipe
    
    task.launch()
    
    let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
    if var string = String(data: outdata, encoding: .utf8) {
        string = string.trimmingCharacters(in: .newlines)
        output = string.components(separatedBy: "\n")
    }
    task.waitUntilExit()
    return (Int(task.terminationStatus), output)
}

func deleteUser(_ request: HTTPRequest, response: HTTPResponse) {
    print("Recieved Delete User Request")    
    
    guard let uuid = request.urlVariables["userUUID"] else{
        print("No User to Delete!")
        return
    }
    
    guard let mysql = try? initializeDatabaseConnection() else{
        print("Could not initalize MySQL connection")
        
        return
    }
    defer {
        mysql.close()
    }
    
    let request1 = "DELETE FROM Users WHERE UUID=\"\(uuid)\"; "
    let request2 = "DELETE FROM UserLogInData WHERE UUID=\"\(uuid)\"; "
    let request3 = "DELETE FROM Messages WHERE Sender=\"\(uuid)\"; "
    let request4 = "DELETE FROM Messages WHERE Recipient=\"\(uuid)\"; "
    
    let succeeded = mysql.query(statement: "SELECT UserMedia FROM Users WHERE UUID=\"\(uuid)\";")
    
    if let queryResults = mysql.storeResults(){
        queryResults.forEachRow{ row in
            print(row)
        }
    }
    
    let didSucceed = (mysql.query(statement: request1) && mysql.query(statement: request2) && mysql.query(statement: request3) && mysql.query(statement: request4))
    if !didSucceed{
        let errorCode = mysql.errorCode()
        let errorMessage = "Request failed: \(mysql.errorMessage())"
		print(errorMessage)
        displayErrorCode(errorCode: Int(errorCode), response: response, description: errorMessage)
        response.completed()
        
        return
    }

    print("Successfully Deleted User")
    response.appendBody(string: "Successfully Deleted User (\"\(uuid)\")")
    response.completed()    
    
}

func displayErrorCode(errorCode : Int, response : HTTPResponse, description: String = "", returnDictionary: [String : [String?]] = [String : [String?]]()){
    var dictionary = returnDictionary
    dictionary["error_message"] = [((description == "") ? "Request Failed with error code: \(errorCode)" : description)]
	dictionary["error_code"] = ["\(errorCode)"]
    
    guard let jsonString = try? dictionary.jsonEncodedString() else{
        return
    }
    response.appendBody(string: jsonString)
    print("Successfully Converted Dictionary to String")
}

