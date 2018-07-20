//
//  Stock.swift
//  MusicMatchServer
//
//  Created by Ben Carlson on 10/13/16.
//
//

import Foundation

class Stock {
    
    var stockSymbol : String?;
    var company : String = "";
    var price : Float?;
    var lowPrice : Float = 0;
    var highPrice : Float = 0;
    var openPrice : Float = 0;
    var closePrice : Float = 0;
    var exchange : String = "";
    
    init(stockSymbol : String, company : String, lastPrice : Float, lowPrice : Float, highPrice : Float, openPrice : Float, closePrice : Float){
        self.stockSymbol = stockSymbol;
        self.company = company
        self.price = lastPrice
        self.lowPrice = lowPrice
        self.highPrice = highPrice
        self.openPrice = openPrice
        self.closePrice = closePrice
    }
    
}
