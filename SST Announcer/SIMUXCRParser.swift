//
//  SIMUXCRParser.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 5/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

class SIMUXCRParser: NSObject {
    
    // MARK: - Private Variables
    
    private struct Item {
        var title : String
        var description : String
    }
    private var tempItem : Item = Item(title: "", description: "")
    private var feeds : [Item] = []
    private var element : String = ""
    
    private var errorBoolean : Bool = false
    
    // MARK: - Initializers
    
    override init() {
        super.init()
    }
    
    // MARK: - Public exposed functions
    
    func convertHTML(htmlString:String!, completionClosure:(result:(title: String, description: String), errorPresent: Bool)->Void) {
        var returnTuple = (title: "", description: "") // Init empty named tuple
        
        // Test for connectivity to statixind.net and if not available, fallback to another server
        let testUrl = NSURL(string: "https://simux.org/v1/clear.php/")
        var useFallback = false
        let test = NSURLSession.sharedSession().dataTaskWithURL(testUrl!) {(data, response, error) in
            if error == nil {
                if (response as! NSHTTPURLResponse).statusCode != 200 { // Use fallback here
                    useFallback = true
                } else {
                    useFallback = false
                }
            } else {
                self.errorBoolean = true
            }
        }
        var urlFirstSegment : String
        if useFallback {
            urlFirstSegment = "https://api.statixind.net/v1/clear?url="
        } else {
            urlFirstSegment = "https://simux.org/v1/clear?url="
        }
        
        // Actual REST JSON loading, with extremely strict error checking
        let url = NSURL(string: "\(urlFirstSegment)\(htmlString)&format=json")
        let getData = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            if error == nil {
                if let dataUnwrapped = data {
                    var jsonError : NSError?
                    let jsonObject : AnyObject! = NSJSONSerialization.JSONObjectWithData(dataUnwrapped, options: NSJSONReadingOptions.MutableContainers, error: &jsonError)
                    if jsonError == nil {
                        let json = JSON(jsonObject)
                        if let title = json["item","title"].string {
                            returnTuple.title = title
                            returnTuple.description = json["item","description"].string!
                        } else {
                            self.errorBoolean = true
                        }
                    } else {
                        self.errorBoolean = true
                    }
                } else {
                    self.errorBoolean = true
                }
            } else {
                println(error)
                self.errorBoolean = true
            }
            
            // Error parsing mechanism
            if self.errorBoolean {
                returnTuple.title = "Error"
                returnTuple.description = "<html><p align=\"center\">There was a problem loading this article, please check your Internet connection, or try opening the URL in Safari via the share button above.</p></html>"
            }
            
            completionClosure(result: returnTuple, errorPresent: self.errorBoolean)
        }
        getData.resume()
    }
}
