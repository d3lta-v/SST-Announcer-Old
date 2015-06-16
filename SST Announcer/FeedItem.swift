//
//  FeedItem.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 16/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import Foundation

class FeedItem: NSObject, NSCoding {
    var title : String
    var link : String
    var date : String
    var author : String
    var content : String // Originally known as description
    
    init(title: String, link: String, date: String, author: String, content: String) {
        self.title = title
        self.link = link
        self.date = date
        self.author = author
        self.content = content
    }
    
    // MARK: NSCoding
    required init(coder aDecoder: NSCoder) {
        self.title = aDecoder.decodeObjectForKey("title") as! String
        self.link = aDecoder.decodeObjectForKey("link") as! String
        self.date = aDecoder.decodeObjectForKey("date") as! String
        self.author = aDecoder.decodeObjectForKey("author") as! String
        self.content = aDecoder.decodeObjectForKey("content") as! String
        
        super.init()
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.title, forKey: "title")
        aCoder.encodeObject(self.link, forKey: "link")
        aCoder.encodeObject(self.date, forKey: "date")
        aCoder.encodeObject(self.author, forKey: "author")
        aCoder.encodeObject(self.content, forKey: "content")
    }
}
