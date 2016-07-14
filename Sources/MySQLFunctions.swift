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
        //FIX
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
        print(mysql.query(statement: "ALTER TABLE Users ADD Bio TEXT"))
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
