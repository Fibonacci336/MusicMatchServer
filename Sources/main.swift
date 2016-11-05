//
//  main.swift
//  PerfectTemplate
//
//  Created by Kyle Jessup on 2015-11-05.
//	Copyright (C) 2015 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import PerfectLib
import PerfectNet
import PerfectThread
import PerfectHTTPServer
import PerfectHTTP
import PerfectNotifications
import Foundation

// Create our webroot
// This will serve all static content by default
let webRoot = "./webroot"
var production = false
var stockRefreshTimer : StockRefreshTimer? = nil
var stockArray : [Stock] = [Stock]()

try Dir(webRoot).create()

// Add our routes and such
// Register your own routes and handlers



do {

    // Launch the HTTP server on port 8181
    let server = HTTPServer()
    var routes = Routes()
    routes.add(method: .post, uri: "/mockstock/stocks/", handler: stockListHandler)
    routes.add(method: .post, uri: "/distcheck/{command}", handler: distanceCheck)
    routes.add(method: .post, uri: "/request/{command}", handler: restJSONHandler)
    routes.add(method: .get, uri: "/avthumb/{videoname}", handler: thumbHandler)
    
    routes.add(method: .post, uri: "/upload/{fileType}", handler: fileUpload)
    routes.add(method: .get, uri: "/upload/{fileType}", handler: fileUpload)
    
    routes.add(method: .post, uri: "/message/", handler: messageHandler)
    routes.add(method: .get, uri: "/", handler: indexHandler)
    routes.add(method: .get, uri: "/*", handler: StaticFileHandler(documentRoot: webRoot).handleRequest)
    
    
    print(routes.navigator.description)
    server.addRoutes(routes)
    configureServer(server)
    PerfectServerModuleInit()
    if(production){
        server.serverAddress = "http://www.lassoconsultant.com"
        server.serverPort = 8183
    }else{
        server.serverPort = 8181
    }
    //stockRefreshTimer = StockRefreshTimer(timeInterval: 15, repeats: false)
    try server.start()
    
    
} catch PerfectError.networkError(let err, let msg) {
    print("Network error thrown: \(err) \(msg)")
}


public func initializeNotificationSystem(){
    let configurationName = "MusicMatch Configuration"
    
    NotificationPusher.addConfigurationIOS(name: configurationName) {
        (net : NetTCPSSL) in
        
        // This code will be called whenever a new connection to the APNS service is required.
        // Configure the SSL related settings.
        
        net.keyFilePassword = "123qweasdzxC"
        
        guard net.useCertificateFile(cert: "./MusicMatchPush.pem") && net.usePrivateKeyFile(cert: "./MusicMatchPush.pem") && net.checkPrivateKey() else {
                
                let code = Int32(net.errorCode())
                print("Error validating private key file: \(net.errorStr(forCode: code))")
                return
        }
    }
    
    NotificationPusher.development = true
}
