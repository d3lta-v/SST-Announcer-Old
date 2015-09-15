//
//  FeedKit.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 4/7/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

public class FeedItem: NSObject, NSCoding {
    public var title: String
    public var link: String
    public var date: String
    public var author: String
    public var content: String // Originally known as description

    public init(title: String, link: String, date: String, author: String, content: String) {
        self.title = title
        self.link = link
        self.date = date
        self.author = author
        self.content = content
    }

    // MARK: NSCoding
    public required init?(coder aDecoder: NSCoder) {
        self.title = (aDecoder.decodeObjectForKey("title") as? String)!
        self.link = (aDecoder.decodeObjectForKey("link") as? String)!
        self.date = (aDecoder.decodeObjectForKey("date") as? String)!
        self.author = (aDecoder.decodeObjectForKey("author") as? String)!
        self.content = (aDecoder.decodeObjectForKey("content") as? String)!

        super.init()
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.title, forKey: "title")
        aCoder.encodeObject(self.link, forKey: "link")
        aCoder.encodeObject(self.date, forKey: "date")
        aCoder.encodeObject(self.author, forKey: "author")
        aCoder.encodeObject(self.content, forKey: "content")
    }
}

public class FeedHelper: NSObject {
    public static let sharedInstance = FeedHelper()

    private let defaults = NSUserDefaults.standardUserDefaults()

    private var element = ""
    private var tempItem: FeedItem
    private var feeds: [FeedItem]
    private let fullDateFormatter: NSDateFormatter
    private let longDateFormatter: NSDateFormatter
    private var parser: NSXMLParser
    private var parseFinished = false

    public override init() {
        let stdLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        fullDateFormatter = NSDateFormatter()
        fullDateFormatter.locale = stdLocale
        fullDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss ZZZ"
        longDateFormatter = NSDateFormatter()
        longDateFormatter.locale = stdLocale
        longDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm"

        tempItem = FeedItem(title: "", link: "", date: "", author: "", content: "")
        feeds = [FeedItem]()
        parser = NSXMLParser()

        super.init()
    }

    /**
        Gets a copy of the cached feeds from NSUserDefaults, deserializes it and returns it as an array of `FeedItem` s.

        - returns: An optional `FeedItem` array
    */
    public func getCachedFeeds() -> ([FeedItem]?) {
        if let feedsObj = defaults.objectForKey("cachedFeeds") as? NSData {
            NSKeyedUnarchiver.setClass(FeedItem.self, forClassName: "FeedItem")
            if let feeds = NSKeyedUnarchiver.unarchiveObjectWithData(feedsObj) as? [FeedItem] {
                return feeds
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    /**
        Stores a copy of the cached feeds to NSUserDefaults, serializes it and stores it as an NSData object.

        - parameter feeds: An array of `FeedItem` s.
    */
    public func setCachedFeeds(feeds: [FeedItem]) {
        NSKeyedArchiver.setClassName("FeedItem", forClass: FeedItem.self)
        let cachedData = NSKeyedArchiver.archivedDataWithRootObject(feeds)
        defaults.setObject(cachedData, forKey: "cachedFeeds")
    }

    /**
        Retrieves `FeedItem` s from the Internet synchronously.

        - returns: An optional `FeedItem` array
    */
    // requestFeedsSynchronous is DEPRECATED, due to WatchOS 2
    /*public func requestFeedsSynchronous() -> [FeedItem]? {
        let rqst = NSURLRequest(URL: NSURL(string: "https://node1.sstinc.org/api/cache/blogrss.csv")!)
        self.feeds = [FeedItem]()

        let task = NSURLSession.sharedSession().dataTaskWithRequest(rqst) { (data, rsp, err) -> () in
            /*if err == nil {
                return decodeResponseData(data?)
            }
            return nil*/
        }
        task.resume()
    }*/

    /**
        Retrieves `FeedItem` s from the Internet synchronously.

        - parameter completionClosure: A closure that returns an optional `FeedItem` array
    */
    public func requestFeedsSynchronous(completionClosure:(result: [FeedItem]?) -> Void) {
        let rqst = NSURLRequest(URL: NSURL(string: "https://node1.sstinc.org/api/cache/blogrss.csv")!)
        self.feeds = [FeedItem]()

        let task = NSURLSession.sharedSession().dataTaskWithRequest(rqst) { (data, rsp, err) -> () in
            if err == nil {
                guard let dataUnwrapped = data else {
                    completionClosure(result: nil)
                    return
                }
                completionClosure(result: self.decodeResponseData(dataUnwrapped))
            } else {
                completionClosure(result: nil)
            }
        }
        task.resume()
    }

    private func decodeResponseData(buffer: NSData) -> [FeedItem]? {
        parser = NSXMLParser(data: buffer)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        if parser.parse() == true {
            return self.feeds
        } else {
            print("parser dieded")
            return nil
        }
    }
}

extension FeedHelper : NSXMLParserDelegate {
    public func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        self.element = elementName
        if self.element == "item" { // If new item is retrieved, clear the temporary item object
            self.tempItem = FeedItem(title: "", link: "", date: "", author: "", content: "") //Reset tempItem
        }
    }

    public func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            self.feeds.append(self.tempItem)
        }
    }

    public func parser(parser: NSXMLParser, foundCharacters string: String) {
        if self.element == "title" {
            self.tempItem.title += string
        } else if self.element == "link" {
            self.tempItem.link += string
        } else if self.element == "pubDate" {
            if let currentDate = self.fullDateFormatter.dateFromString(string) {
                self.tempItem.date += longDateFormatter.stringFromDate(currentDate)
            }
        } else if self.element == "author" {
            self.tempItem.author += string.stringByReplacingOccurrencesOfString("noreply@blogger.com ", withString: "", options: .LiteralSearch, range: nil)
        } else if self.element == "description" {
            self.tempItem.content += string
        }
    }

    public func parserDidEndDocument(parser: NSXMLParser) {
        parseFinished = true
        self.setCachedFeeds(feeds)
    }

    public func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        parseFinished = true
    }
}
