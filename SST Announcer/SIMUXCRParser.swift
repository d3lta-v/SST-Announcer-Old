//
//  SIMUXCRParser.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 5/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

public class SIMUXCRParser: NSObject {

    // MARK: - Private Variables

    private struct Item {
        var title: String
        var description: String
    }
    private var tempItem: Item = Item(title: "", description: "")
    private var feeds: [Item] = []
    private var element: String = ""

    private var errorBoolean: Bool = false

    // MARK: - Initializers

    override init() {
        super.init()
    }

    // MARK: - Public exposed functions

    /**
        Retrieves HTML from a URL specified and runs it through the SIMUXCR parser, and returns the title and "description", which is the content of the cleaned HTML through a closure.

        - parameter htmlString: A URL for which you want to parse with the SIMUXCR parser
        - parameter completionClosure: A closure for you to retrieve the data from the SIMUXCR parser once it completes
    */
    public func convertHTML(htmlString: String!, completionClosure: (title: String, description: String) -> Void) {
        var returnTuple = (title: "", description: "") // Init empty named tuple

        // Test for connectivity to node1.sstinc.org and if not available, fallback to another server
        let urlFirstSegment = "https://node1.sstinc.org/api/fulltextrss/extract.php?url="

        // Actual REST JSON loading, with extremely strict optional error checking
        let url = NSURL(string: "\(urlFirstSegment)\(htmlString)&format=json")
        let getData = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            if error == nil {
                if let dataUnwrapped = data {
                    var jsonError: NSError? = nil
                    if let jsonObject = NSJSONSerialization.JSONObjectWithData(data!, options: .MutableContainers) as? NSDictionary {
                        if jsonError == nil {
                            if let title = jsonObject["title"] as? String, description = jsonObject["content"] as? String {
                                returnTuple.title = title
                                returnTuple.description = description
                            } else {self.errorBoolean = true}
                        } else {self.errorBoolean = true}
                    } else {self.errorBoolean = true}
                } else {self.errorBoolean = true}
            } else {print(error);self.errorBoolean = true}

            // Error parsing mechanism
            if self.errorBoolean {
                returnTuple.title = "Error"
                returnTuple.description = "<p align=\"center\">There was a problem loading this article, please check your connection, or try opening the URL in Safari via the share button above.</p>"
            }

            completionClosure(title: returnTuple.title, description: returnTuple.description)
        }

        getData.resume()
    }

}
