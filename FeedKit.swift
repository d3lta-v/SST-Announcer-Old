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
    public required init(coder aDecoder: NSCoder) {
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

    private let defaults = NSUserDefaults(suiteName: "group.Announcer")

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

    public func getCachedFeeds() -> ([FeedItem]?) {
        if let feedsObj = defaults?.objectForKey("cachedFeeds") as? NSData {
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

    public func setCachedFeeds(feeds: [FeedItem]) {
        NSKeyedArchiver.setClassName("FeedItem", forClass: FeedItem.self)
        let cachedData = NSKeyedArchiver.archivedDataWithRootObject(feeds)
        defaults?.setObject(cachedData, forKey: "cachedFeeds")
    }

    public func requestFeedsSynchronous() -> [FeedItem]? {
        let rqst = NSURLRequest(URL: NSURL(string: "http://node1.sstinc.org/api/cache/blogrss.xml")!)
        var rsp: NSURLResponse?
        var err: NSError?
        self.feeds = [FeedItem]()

        if let data = NSURLConnection.sendSynchronousRequest(rqst, returningResponse: &rsp, error: &err) {
            if err == nil {
                return decodeResponseData(data)
            }
        }
        return nil
    }

    private func decodeResponseData(buffer: NSData) -> [FeedItem]? {
        parser = NSXMLParser(data: buffer)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        if parser.parse() == true {
            return self.feeds
        } else {
            println("parser dieded")
            return nil
        }
    }
}

extension FeedHelper : NSXMLParserDelegate {
    public func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [NSObject : AnyObject]) {
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

    public func parser(parser: NSXMLParser, foundCharacters string: String?) {
        if var testString = string { // Unwrap string? to check if it is safe
            if self.element == "title" {
                self.tempItem.title = self.tempItem.title + testString
            } else if self.element == "link" {
                self.tempItem.link = self.tempItem.link + testString
            } else if self.element == "pubDate" {
                if let currentDate = self.fullDateFormatter.dateFromString(testString) {
                    self.tempItem.date += longDateFormatter.stringFromDate(currentDate)
                } else {
                    self.tempItem.date += "<No Date>"
                }
            } else if self.element == "author" {
                self.tempItem.author = testString.stringByReplacingOccurrencesOfString("noreply@blogger.com ", withString: "", options: .LiteralSearch, range: nil)
            } else if self.element == "description" {
                self.tempItem.content = self.tempItem.content + testString
            }
        }
    }

    public func parserDidEndDocument(parser: NSXMLParser) {
        parseFinished = true
    }

    public func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        parseFinished = true
    }
}
