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

// host where mysql server is
let HOST = "127.0.0.1"
// mysql username
let USER = "root"
// mysql root password
let PASSWORD = "123qweasdzxC"
// database name
let SCHEMA = "MusicMatch"

let currentURL = "http://0.0.0.0:8181/"
//public method that is being called by the server framework to initialise your module.
public func PerfectServerModuleInit() {
    
    // Install the built-in routing handler.
    // Using this system is optional and you could install your own system if desired.
    //Routing.Handler.registerGlobally()
    
    // Create Routes
    Routing.Routes[HTTPMethod.get, ["/", "index.html"] ] = indexHandler
    //Routing.Routes["*"] = { _ in return StaticFileHandler() }
    Routing.Routes["/avthumb/{videoname}"] = thumbHandler
    Routing.Routes["/request/{command}"] = restJSONHandler
    Routing.Routes["/distcheck/{command}"] = distanceCheck

    print("\(Routing.Routes.description)")
    //initializeUserData()
    //initializeMessagesData()
    //initializeUserLogInData()

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
            let statement = "SELECT UserType,UserName,BirthDate,MusicType,BandPosition,VideoName,Available,UUID FROM users where UUID=\"" + UUID! + "\";"
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
    let videoPath = (request.urlVariables["videoname"]!) + ".mp4"
    let imagePath = (request.urlVariables["videoname"]!) + ".png"
    let documentsDir = webRoot + "/"
    if let thumbnail = try? getVideoThumbnail(videoURL: currentURL + videoPath){
        saveImage(thumbnail, locationPath: documentsDir + imagePath)
        response.appendBody(string: ((request.urlVariables["videoname"]!) + ".png"))
    }
    
    response.completed()
    }
func getDocumentsDirectory() -> NSString {
    let fileManager = FileManager.default()
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
        throw AVError.exportFailed
    }
    
}

func saveImage(_ image : NSImage, locationPath : String){
    let cgRef = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let newRep: NSBitmapImageRep = NSBitmapImageRep(cgImage: cgRef)
    newRep.size = image.size
    // if you want the same resolution
    let fileManager = FileManager.default()
    let pngData = newRep.representation(using: NSBitmapImageFileType.PNG, properties: [:])
    guard fileManager.createFile(atPath: locationPath, contents: pngData, attributes: [:]) else{
        print("Could not write to PNG file")
        return
    }
    print("Successfully wrote to PNG file")

}


func initializeDatabaseConnection() throws -> MySQL{
    // open mysql connection
    let mysql = MySQL()
    
    let connected = mysql.connect(host: HOST, user: USER, password: PASSWORD, db: SCHEMA, port: 0, socket: nil, flag: 0)
    
    guard connected else {
        print(mysql.errorMessage())
        throw DatabaseError.connectionError
    }
    
    var schemaExists = mysql.selectDatabase(named: SCHEMA)
    if !schemaExists {
        schemaExists = mysql.query(statement: "CREATE DATABASE \(SCHEMA);")
    }
    
    guard schemaExists else {
        print(mysql.errorMessage())
        throw DatabaseError.schemaCreationError
    }
    
    
    
    return mysql
}

enum DatabaseError : ErrorProtocol{
    
    case connectionError
    case schemaCreationError
}

func deleteColumn(_ name : String, mysql : MySQL, table : String){
    print(mysql.query(statement: "ALTER TABLE \(table) DROP COLUMN \(name)"))
}

func initializeUserLogInData(){
    do{
        let mysql = try initializeDatabaseConnection()
        defer {
            mysql.close()
        }
        let tableSuccess = mysql.query(statement: "CREATE TABLE IF NOT EXISTS UserLogInData (id INT(11) AUTO_INCREMENT, Content varchar(255), PRIMARY KEY (id))")
        print(mysql.query(statement: "ALTER TABLE UserLogInData ADD UUID TEXT"))
        print(mysql.query(statement: "ALTER TABLE UserLogInData ADD FullName TEXT"))
        print(mysql.query(statement: "ALTER TABLE UserLogInData ADD Email TEXT"))
        print(mysql.query(statement: "ALTER TABLE UserLogInData ADD Password TEXT"))
        deleteColumn("id", mysql: mysql, table: "UserLogInData")
        deleteColumn("Content", mysql: mysql, table: "UserLogInData")
        
        
        print(mysql.query(statement: "INSERT INTO UserLogInData (UUID, FullName, Email, Password) VALUES (\"iUser*ben*perkins*10*8*2000\", \"Ben Perkins\", \"bcarlson336@gmail.com\", \"123qweasdzxC\");"))
        guard tableSuccess else {
            print(mysql.errorMessage())
            return
        }
    }catch{
        print("Could not initialize database connection")
    }
}



func initializeMessagesData(){
    do{
        let mysql = try initializeDatabaseConnection()
        defer {
            mysql.close()
        }
        let tableSuccess = mysql.query(statement: "CREATE TABLE IF NOT EXISTS Messages (id INT(11) AUTO_INCREMENT, Content varchar(255), PRIMARY KEY (id))")
        print(mysql.query(statement: "ALTER TABLE Messages ADD MessageUUID TEXT"))
        print(mysql.query(statement: "ALTER TABLE Messages ADD Sender TEXT"))
        print(mysql.query(statement: "ALTER TABLE Messages ADD Recipient TEXT"))
        print(mysql.query(statement: "ALTER TABLE Messages ADD MessageContent TEXT"))
        print(mysql.query(statement: "ALTER TABLE Messages ADD SendDate DATETIME"))
        print(mysql.query(statement: "ALTER TABLE Messages ADD Status TEXT"))
        print(mysql.query(statement: "ALTER TABLE Messages ADD MessageType TEXT"))
        deleteColumn("id", mysql: mysql, table: "Messages")
        deleteColumn("Content", mysql: mysql, table: "Messages")

        
        print(mysql.query(statement: "INSERT INTO Messages (MessageUUID, Sender, Recipient, MessageContent, SendDate, Status, MessageType) VALUES (\"message12345\", \"iUser*erica*riley*15*2*1964\", \"iUser*ben*perkins*10*8*2000\", \"Hey Ben What's Up\", \"2016-7-8 10:0:0\", \"read\", \"text\");"))
        guard tableSuccess else {
            print(mysql.errorMessage())
            return
        }
    }catch{
        print("Could not initialize database connection")
    }
}

func initializeUserData(){
    do{
        let mysql = try initializeDatabaseConnection()
        defer {
            mysql.close()
        }
        let tableSuccess = mysql.query(statement: "CREATE TABLE IF NOT EXISTS Users (id INT(11) AUTO_INCREMENT, Content varchar(255), PRIMARY KEY (id))")
        print(mysql.query(statement: "ALTER TABLE Users ADD UserType TEXT"))
        print(mysql.query(statement: "ALTER TABLE Users ADD UserName TEXT"))
        print(mysql.query(statement: "ALTER TABLE Users ADD UUID TEXT"))
        print(mysql.query(statement: "ALTER TABLE Users ADD BirthDate DATE"))
        print(mysql.query(statement: "ALTER TABLE Users ADD MusicType TEXT"))
        print(mysql.query(statement: "ALTER TABLE Users ADD BandPosition TEXT"))
        print(mysql.query(statement: "ALTER TABLE Users ADD VideoName TEXT"))
        print(mysql.query(statement: "ALTER TABLE Users ADD CurrentLat DOUBLE"))
        print(mysql.query(statement: "ALTER TABLE Users ADD CurrentLong DOUBLE"))
        print(mysql.query(statement: "ALTER TABLE Users ADD Available INT"))
        deleteColumn("id", mysql: mysql, table: "Users")
        deleteColumn("Content", mysql: mysql, table: "Users")
        
        print(mysql.query(statement: "INSERT INTO Users (UserType, UserName, UUID, BirthDate, MusicType, BandPosition, VideoName, Available) VALUES (\"individual\", \"Erica Riley\", \"iUser*erica*riley*15*2*1964\", \"1964-02-15\", \"Classical\", \"Harpist\", \"toystory\", 1);"))
        print(mysql.query(statement: "INSERT INTO Users (UserType, UserName, UUID, BirthDate, MusicType, BandPosition, VideoName, Available) VALUES (\"individual\", \"Frank Riley\", \"iUser*frank*riley*15*6*1964\", \"1964-06-15\", \"Classic Rock\", \"Drummer\", \"talkinghead\", 1);"))
        print(mysql.query(statement: "INSERT INTO Users (UserType, UserName, UUID, BirthDate, MusicType, BandPosition, VideoName, Available) VALUES (\"individual\", \"Ben Perkins\", \"iUser*ben*perkins*10*8*2000\", \"2000-08-10\", \"Classic Rock\", \"Drummer\", \"small\", 1);"))
        guard tableSuccess else {
            print(mysql.errorMessage())
            return
        }
    }catch{
        print("Could not initialize database connection")
    }
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













