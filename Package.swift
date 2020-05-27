// swift-tools-version:5.0
//
//  Package.swift
//  PerfectTemplate
//
//  Created by Kyle Jessup on 4/20/16.
//	Copyright (C) 2016 PerfectlySoft, Inc.
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

import PackageDescription

let package = Package(
    name: "MusicMatchServer",
    products: [
        .library(name: "MusicMatchServer", targets: ["MusicMatchServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", from: "3.0.0"),
        .package(url: "https://github.com/PerfectlySoft/Perfect-MySQL.git", from: "3.0.0"),
        .package(url: "https://github.com/PerfectlySoft/Perfect-Notifications.git", from: "3.0.0"),
        .package(url: "https://github.com/twostraws/SwiftGD.git", .exact("2.4.0"))
    ],
    targets: [
        .target(name: "MusicMatchServer", dependencies: ["PerfectHTTPServer", "PerfectMySQL", "PerfectNotifications", "SwiftGD"], path: "Sources")
    ]
)
