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
        
        // Actual REST JSON loading, with extremely strict optional error checking
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
                            returnTuple.description = json["item","description"].string!.stringByDecodingHTMLEntities
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

// MARK: - Extensions

extension String {
    
    /// Returns a new string made by replacing in the `String`
    /// all HTML character entity references with the corresponding
    /// character.
    
    var stringByDecodingHTMLEntities : String {
        
        let characterEntities : [String:Character] = [
            // XML predefined entities:
            "&quot;"    : "\"",
            "&amp;"     : "&",
            "&apos;"    : "'",
            "&lt;"      : "<",
            "&gt;"      : ">",
            
            // HTML character entity references:
            "&nbsp;"    : "\u{00a0}",
            // ...
            "&diams;"   : "♦",
        ]
        
        // ===== Utility functions =====
        
        // Convert the number in the string to the corresponding
        // Unicode character, e.g.
        //    decodeNumeric("64", 10)   --> "@"
        //    decodeNumeric("20ac", 16) --> "€"
        func decodeNumeric(string : String, base : Int32) -> Character? {
            let code = UInt32(strtoul(string, nil, base))
            return Character(UnicodeScalar(code))
        }
        
        // Decode the HTML character entity to the corresponding
        // Unicode character, return `nil` for invalid input.
        //     decode("&#64;")    --> "@"
        //     decode("&#x20ac;") --> "€"
        //     decode("&lt;")     --> "<"
        //     decode("&foo;")    --> nil
        func decode(entity : String) -> Character? {
            
            if entity.hasPrefix("&#x") || entity.hasPrefix("&#X"){
                return decodeNumeric(entity.substringFromIndex(advance(entity.startIndex, 3)), 16)
            } else if entity.hasPrefix("&#") {
                return decodeNumeric(entity.substringFromIndex(advance(entity.startIndex, 2)), 10)
            } else {
                return characterEntities[entity]
            }
        }
        
        // ===== Method starts here =====
        
        var result = ""
        var position = startIndex
        
        // Find the next '&' and copy the characters preceding it to `result`:
        while let ampRange = self.rangeOfString("&", range: position ..< endIndex) {
            result.extend(self[position ..< ampRange.startIndex])
            position = ampRange.startIndex
            
            // Find the next ';' and copy everything from '&' to ';' into `entity`
            if let semiRange = self.rangeOfString(";", range: position ..< endIndex) {
                let entity = self[position ..< semiRange.endIndex]
                position = semiRange.endIndex
                
                if let decoded = decode(entity) {
                    // Replace by decoded character:
                    result.append(decoded)
                } else {
                    // Invalid entity, copy verbatim:
                    result.extend(entity)
                }
            } else {
                // No matching ';'.
                break
            }
        }
        // Copy remaining characters to `result`:
        result.extend(self[position ..< endIndex])
        return result
    }
}