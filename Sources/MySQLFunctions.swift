//
//  SQLiteFunctions.swift
//  MusicMatchServer
//
//  Created by Ben Carlson on 4/30/16.
//  Copyright © 2016 Ben Carlson. All rights reserved.
//

import Foundation
import MySQL


let url = "http://0.0.0.0:8181/request/"


func initializeDatabaseConnection() throws -> MySQL{
    // open mysql connection
    let mysql = MySQL()
    
    let connected = mysql.connect(host: HOST, user: USER, password: PASSWORD, port: 0, socket: nil, flag: 0)
    
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
        let tableSuccess = mysql.query(statement: "CREATE TABLE IF NOT EXISTS UserLogInData (UUID TEXT, FullName TEXT, Email TEXT, ADD Password TEXT)")
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
        let tableSuccess = mysql.query(statement: "CREATE TABLE IF NOT EXISTS Messages (MessageUUID TEXT, Sender TEXT, Recipient TEXT, MessageContent TEXT, SendDate DATETIME, Status TEXT, MessageType TEXT)")
        
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
        //FIX
        let tableSuccess = mysql.query(statement: "CREATE TABLE IF NOT EXISTS Users (UserType TEXT, UserName TEXT, UUID TEXT, BirthDate DATE, MusicType TEXT, BandPosition TEXT, VideoName TEXT, CurrentLat DOUBLE, CurrentLong DOUBLE, Available INT, Bio TEXT)")
        
        guard tableSuccess else {
            print(mysql.errorMessage())
            return
        }
    }catch{
        print("Could not initialize database connection")
    }
}

func performRequest(_ command : String, requestData : [String : AnyObject]?, method : String = "GET") -> String?{
    
    var request = URLRequest(url: URL(string: (url + command))!)
    request.httpMethod = method
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    var dataReturn = ""
    
    do{
        
        if(requestData != nil){
            let bodyData = try JSONSerialization.data(withJSONObject: requestData as! AnyObject, options: JSONSerialization.WritingOptions.prettyPrinted)
            request.httpBody = bodyData
        }
        URLSession.shared.dataTask(with: request, completionHandler: {
            (data, response, error) -> Void in
            print(error?.localizedDescription)
            guard response == nil else{
                guard data == nil else{
                    if let dataString = String.init(data: data!, encoding: String.Encoding.utf8){
                        print("Data: \(dataString)")
                        
                        guard let dataResponse = try? JSONSerialization.jsonObject(with: data!, options: []) else{
                            print("Failed JSON")
                            return
                        }
                        dataReturn = dataString
                        print("JSON: \(dataResponse)")
                        return
                    }
                    return
                }
                return
            }
            
        }).resume()
        
        
    }catch{
        print("Invalid JSON")
    }
    
    
    return dataReturn
    
}
