//
//  SQLiteFunctions.swift
//  MusicMatchServer
//
//  Created by Ben Carlson on 4/30/16.
//  Copyright © 2016 Ben Carlson. All rights reserved.
//

import Foundation
import PerfectMySQL

struct HelloWorld{
    
    
    let host = HOST
    
    init(){
        print(HOST)
    }
    
    
    
}

func initializeDatabaseConnection() throws -> MySQL{
    // open mysql connection
    let mysql = MySQL()
    
    let connected = mysql.connect(host: HOST, user: USER, password: PASSWORD, port: 3306, socket: nil, flag: 0)
    
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

enum DatabaseError : Error{
    
    case connectionError
    case failedRequestError
    case emptyRequestError
    case schemaCreationError
}

enum FileError : Error{
    case exportFailed
}

func deleteColumn(_ name : String, mysql : MySQL, table : String){
    print(mysql.query(statement: "ALTER TABLE \(table) DROP COLUMN \(name)"))
}

func initializeUserLogInData(){
    do{
        let mysql = try initializeDatabaseConnection()

        let tableSuccess = mysql.query(statement: "CREATE TABLE IF NOT EXISTS UserLogInData (UUID TEXT, FullName TEXT, Email TEXT,Password TEXT);")
        guard tableSuccess else {
            print(mysql.errorMessage())
            return
        }
        
        print("Initialized \"UserLogInData\" Table")
    }catch{
        print("Could not initialize database connection")
    }
}



func initializeMessagesData(){
    do{
        let mysql = try initializeDatabaseConnection()

        let tableSuccess = mysql.query(statement: "CREATE TABLE IF NOT EXISTS Messages (MessageUUID TEXT, Sender TEXT, Recipient TEXT, MessageContent TEXT, SendDate DATETIME, Status TEXT, MessageType TEXT);")
        
        guard tableSuccess else {
            print(mysql.errorMessage())
            return
        }
        
        print("Initialized \"Messages\" Table")
    }catch{
        print("Could not initialize database connection")
    }
}

func initializeUserData(){
    do{
        let mysql = try initializeDatabaseConnection()
        
        //FIX
        let tableSuccess = mysql.query(statement: "CREATE TABLE IF NOT EXISTS Users (UserType TEXT, UserName TEXT, UUID TEXT, BirthDate DATE, MusicType TEXT, BandPosition TEXT, UserMedia TEXT, CurrentLat DOUBLE, CurrentLong DOUBLE, Available INT, Bio TEXT, LookingFor TEXT, DistanceUnit TEXT, DeviceToken TEXT, LastLogin DATETIME);")
        
        guard tableSuccess else {
            print(mysql.errorMessage())
            return
        }
        
        print("Initialized \"Users\" Table")
    }catch{
        print("Could not initialize database connection")
    }
}

func checkForExtraMedia(mysqlStatement : String){
    //Trim UserMedia
    guard mysqlStatement.contains("UserMedia="),
        let startIndex = mysqlStatement.range(of: "UserMedia=\'")?.upperBound,
        let endSub = mysqlStatement.range(of: "\' WHERE") else{
        
        print("Statement does not update UserMedia")
        return
    }
        
    let userMediaJSON = String(mysqlStatement[startIndex..<endSub.lowerBound])
    guard let decodedUMDict = try? userMediaJSON.jsonDecode() as? [String:String] else{
        print("Could not decode recieved dict")
        return
    }
    guard let currentMediaDict = try? getDataFromDatabase(with: "SELECT UserMedia FROM Users WHERE" + mysqlStatement[endSub.upperBound...]) else {
        print("Could not get current UserMedia from database")
        return
    }
            
    guard let result = currentMediaDict["0"]?.first, let jsonResult = try? result?.jsonDecode() as? [String : String] else{
        print("Could not decode UserMedia data")
        return
    }
                

    if decodedUMDict.keys.count != jsonResult.keys.count{
        
        for (imageName, _) in jsonResult{
            if decodedUMDict.keys.contains(imageName){
                continue
            }
            do{
                try FileManager.default.removeItem(at: URL(fileURLWithPath: webRoot + "/" + imageName))
                print("Removed \(imageName)")
            }catch let e{
                print("Failed to remove \(imageName) with error: \(e.localizedDescription)")
            }
            
        }
    }
}

func getDataFromDatabase(with request : String) throws -> [String : [String?]]{
    
    guard request != "" else{
        print("Empty Request")
        throw DatabaseError.emptyRequestError
    }
    let mysql = try initializeDatabaseConnection()
    
    let query = mysql.query(statement: request)
    if(query){
        var dictionary = [String : [String?]]()
        if let queryResults = mysql.storeResults(){
            var index = 0
            queryResults.forEachRow{ row in
                dictionary[String(index)] = row
                index+=1
            }
            
            return dictionary
        }
        
        return dictionary
    }else{
        print("Request Failed")
        throw DatabaseError.failedRequestError
    }
    
    
}
