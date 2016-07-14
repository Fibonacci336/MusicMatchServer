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
