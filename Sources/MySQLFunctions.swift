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
