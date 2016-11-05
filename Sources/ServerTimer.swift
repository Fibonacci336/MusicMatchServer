//
//  ServerTimer.swift
//  MusicMatchServer
//
//  Created by Ben Carlson on 10/12/16.
//
//

import Foundation
import PerfectLib

protocol ServerTimer{
    
    var timeInterval : Int { get set}
    var repeats : Bool { get set}
    
    func update()
}

extension ServerTimer{
    
    func initializeServerTimerLoop(){
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(timeInterval), execute: {
            self.update()
            if self.repeats{
                self.initializeServerTimerLoop()
            }
        })
    }
}

class StockRefreshTimer : ServerTimer{
    internal var repeats: Bool

    var symbolArray = [String]()
    
    internal var timeInterval: Int = 0

    init(timeInterval : Int = 60, repeats : Bool = true){
        self.timeInterval = timeInterval
        self.repeats = repeats
        let arrayString = readStockJSONFile(fileName: "symbolList.json")
        symbolArray = getArrayFromArrayString(arrayString: arrayString!) as! [String]
        initializeServerTimerLoop()
    }
    
    func update(){
        print("Refreshing Stock Data")
        
        for symbol in symbolArray{
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(25), execute: {
                self.loadStock(symbol)
            })
            
        }
        
    }
    
    func getArrayFromArrayString(arrayString : String) -> [Any]?{
        do{
            let array = try arrayString.jsonDecode() as! [Any]
            return array
        }catch let error as JSONConversionError{
            print("Failed to decode array string with error: " + error.localizedDescription)
        }catch{
            print("Failed to decode array with unknown error")
        }
        return nil
    }
    
    func readStockJSONFile(fileName : String) -> String?{
        
        let path = URL.init(fileURLWithPath: "./" + fileName, isDirectory: false)
        //reading
        do {
            let text = try String(contentsOf: path, encoding: String.Encoding.utf8)
            return text
        }catch {
            print("Could not read file!")
            return nil
        }
    }
    
    func loadStock(_ symbol : String){
        
        let url: URL = URL(string:"https://query.yahooapis.com/v1/public/yql?q=select%20Name%2CDaysLow%2CDaysHigh%2CLastTradePriceOnly%2CChange%2CDaysRange%20from%20yahoo.finance.quote%20where%20symbol%20%3D%20%22" + symbol + "%22&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=")!
        var request :URLRequest = URLRequest(url: url)
        
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.httpMethod = "GET"
        
        let session = URLSession.shared
        
        let task = session.dataTask(with: request, completionHandler: {
            (data : Data?, response : URLResponse?, error : Error?) -> Void in
            
            
            if let _ = error {
                print("Stock request failed with error \(error!.localizedDescription)")
                self.loadStock(symbol)
            } else {
                
                if let dataString = String.init(data: data!, encoding: String.Encoding.utf8){
                    if let jsonDictionary = try? dataString.jsonDecode() as! [String : Any]{
                        let queryDict = jsonDictionary["query"] as! [String : Any]
                        let resultsDict = queryDict["results"] as! [String : Any]
                        var quoteDict = resultsDict["quote"] as! [String : Any]
                        
                        do{
                            var isNull = try quoteDict["Name"].jsonEncodedString() == "null"
                            guard !isNull else{
                                print("Invalid Stock Symbol")
                                return
                            }
                            isNull = try quoteDict["DaysLow"].jsonEncodedString() == "null"
                            guard !isNull else{
                                print("Invalid Stock Symbol")
                                return
                            }
                            isNull = try quoteDict["DaysHigh"].jsonEncodedString() == "null"
                            guard !isNull else{
                                print("Invalid Stock Symbol")
                                return
                            }
                            
                        }catch{
                            print("Could not convert \"Name\", \"DaysLow\",or \"DaysHigh\" to JSON")
                        }
                        let dict = quoteDict as! [String : String]
                        
                        let low = Float(dict["DaysLow"]!)!
                        let high = Float(dict["DaysHigh"]!)!
                        let last = Float(dict["LastTradePriceOnly"]!)!
                        let range = dict["DaysRange"]!
                        let company = dict["Name"]!
                        let rangeArray = range.characters.split(separator: "-").map(String.init)
                        let open = Float(rangeArray[0].replacingOccurrences(of: " ", with: ""))!
                        let close = Float(rangeArray[1].replacingOccurrences(of: " ", with: ""))!
                        let stock = Stock(stockSymbol: symbol, company: company, lastPrice: last, lowPrice: low, highPrice: high, openPrice: open, closePrice: close)
                        if let findStockIndex = stockArray.index(where: { return $0.stockSymbol == symbol }){
                            stockArray[findStockIndex] = stock
                            print("Refreshed Stock: " + symbol)
                        }else{
                            stockArray.append(stock)
                            print("Appended Stock: " + symbol)
                        }
                    }else{
                        print("Could not decode data string!")
                    }
                }else{
                    print("Could not convert response data to string!")
                }
                
            }
        
        
        })
        task.resume()

    }
}
