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

import PerfectLib
import AVKit
import AVFoundation
import MySQL
import CoreLocation
import PerfectHTTP
import PerfectHTTPServer
import PerfectNotifications


// host where mysql server is
let HOST = "127.0.0.1"
// mysql username
let USER = "root"
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
    initializeNotificationSystem()
    if(production){
        currentURL = "http://www.lassoconsultant.com:8183/"
        print("Production")
    }
    

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
                print(row)
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



func sendMessageNotification(message : String, recipientUUID : String, senderUUID : String){
    let senderDataRequest = "SELECT UserName,DeviceToken FROM Users WHERE UUID=\"\(senderUUID)\" OR UUID=\"\(recipientUUID)\";"
    if let data = try? getDataFromDatabase(with: senderDataRequest){
        
        guard !data.isEmpty else{
            print("Empty Dictionary")
            return
        }
        
        let recipientuser = data[1]
        let userName = recipientuser![0]
        let deviceToken = recipientuser![1]
        //Send Notification
        let notificationArray = [IOSNotificationItem.alertBody(message), IOSNotificationItem.sound("default"), IOSNotificationItem.alertTitle(userName!)]
        let pusher = NotificationPusher()

        pusher.apnsTopic = "com.fibonacci.MusicMatch"
        let configurationName = "MusicMatch Configuration"
        pusher.pushIOS(configurationName: configurationName, deviceToken: deviceToken!, expiration: 0, priority: 10,notificationItems: notificationArray, callback:{
            (response : NotificationResponse) -> Void in
            print(response.status)
        })
    
    }
    
}

func fileUpload(_ request : HTTPRequest, response : HTTPResponse){

    print("Handling File Upload Request")

    print(request.postFileUploads)

    print("Media Type: " + request.urlVariables.first!.value)
    let upload = request.postFileUploads![0]
    let file = File(upload.tmpFileName)
    do {
        let _ = try file.moveTo(path: webRoot + "/" + upload.fileName, overWrite: true)
    } catch {
        print(error)
    }
    response.completed()
}


func distanceCheck(_ request: HTTPRequest, response: HTTPResponse) {
    let requestArray = request.postBodyString?.components(separatedBy: ",")
    var currentUUID = requestArray?[0]
    currentUUID = "\"" + currentUUID! + "\""
    var currentLocation = CLLocation()
    let userRange : Double = Double((requestArray?[1])!)!
    var currentDict = [String : [String?]]()
    do{
        let mysql = try initializeDatabaseConnection()
        defer {
            mysql.close()
        }
        let mysqlStatement = "SELECT CurrentLat,CurrentLong FROM Users WHERE UUID=" + currentUUID! + ";"

        let query = mysql.query(statement: mysqlStatement)

        if(query){
            if let queryResults = mysql.storeResults(){
                let row = queryResults.next()!
                let currentLat = Double((row[0])!)!
                let currentLong = Double((row[1])!)!
                currentLocation = CLLocation(latitude: currentLat, longitude: currentLong)
            }
        }
        var userArray = getUsersInArea(currentLocation: currentLocation, range: userRange)!

        var returnDict = [String : [String?]]()

        for var i in 0..<userArray.keys.count{
            let UUID = userArray[i]
            let statement = "SELECT UserType,UserName,BirthDate,MusicType,BandPosition,VideoName,Available,UUID, CurrentLat, CurrentLong, DistanceUnit, LastLogin FROM Users where UUID=\"" + UUID! + "\";"
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
    
    let extensions = [".mov", ".MOV", ".mp4"]
    
    let imagePath = (request.urlVariables["videoname"]!) + ".png"
    let documentsDir = webRoot + "/"
    for string in extensions{
        let videoPath = (request.urlVariables["videoname"]!) + string
        if let thumbnail = try? getVideoThumbnail(videoURL: currentURL + videoPath){
            saveImage(thumbnail, locationPath: documentsDir + imagePath)
            response.appendBody(string: imagePath)
            break
        }
    }

    response.completed()
}

func getDocumentsDirectory() -> String {
    let fileManager = FileManager.default
    let documentsDirectory = fileManager.currentDirectoryPath
    return documentsDirectory
}

func getVideoThumbnail(videoURL : String) throws -> NSImage{

    let asset = AVAsset(url: URL(string: videoURL)!)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    var time = asset.duration
    time.value /= 2

    if let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil){
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        return image
    }else{
        print("Returning Nil Thumbnail for Video " + videoURL)
        throw FileError.exportFailed
    }

}

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

func getUsersInArea(currentLocation : CLLocation, range : Double) -> [Int : String]?{

    do{
        let mysql = try initializeDatabaseConnection()
        defer {
            mysql.close()
        }
        let currentLat = currentLocation.coordinate.latitude
        let currentLong = currentLocation.coordinate.longitude
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

