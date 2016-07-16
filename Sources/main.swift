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
import PerfectHTTP
import PerfectHTTPServer

// Initialize base-level services
PerfectServer.initializeServices()

// Create our webroot
// This will serve all static content by default
let webRoot = "./webroot"
var production = false
try Dir(webRoot).create()

// Add our routes and such
// Register your own routes and handlers


do {
    
    // Launch the HTTP server on port 8181
    let server = HTTPServer()
    configureServer(server)
    PerfectServerModuleInit()
    if(production){
        server.serverAddress = "http://www.lassoconsultant.com"
        server.serverPort = 8183
    }else{
        server.serverPort = 8181
    }
    try server.start()
    
} catch PerfectError.networkError(let err, let msg) {
    print("Network error thrown: \(err) \(msg)")
}
