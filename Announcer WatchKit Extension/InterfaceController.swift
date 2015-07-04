//
//  InterfaceController.swift
//  Announcer WatchKit Extension
//
//  Created by Pan Ziyue on 3/7/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import WatchKit
import Foundation

class InterfaceController: WKInterfaceController {

    // MARK: - Private variables

    @IBOutlet weak var feedsTable: WKInterfaceTable!
    private let helper = FeedHelper()
    private var feeds: [FeedItem]!

    // MARK: - Lifecycle

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)

        // Configure interface objects here.
        invalidateUserActivity() // we don't want handoff, YET

        setTitle("Announcer")
        if let feedsUnwrapped = helper.getCachedFeeds() {
            feeds = feedsUnwrapped
            reloadTable()
        }

        // Attempt to load new data from parent application
        WKInterfaceController.openParentApplication(["request": "refreshData"], reply: { (replyInfo, error) -> Void in
                //println("Reply: \(replyInfo)") // called when parent app is finished
            if let reply = replyInfo {
                if let feedData = reply["feedData"] as? NSData {
                    NSKeyedUnarchiver.setClass(FeedItem.self, forClassName: "FeedItem")
                    if let feeds = NSKeyedUnarchiver.unarchiveObjectWithData(feedData) as? [FeedItem] {
                        self.helper.setCachedFeeds(feeds)
                        self.feeds = feeds
                        self.reloadTable()
                    }
                }
            }
        })
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    override func handleActionWithIdentifier(identifier: String?, forRemoteNotification remoteNotification: [NSObject : AnyObject]) {
        if let notifIdentifier = identifier {
            if notifIdentifier == "viewFeedAction" {
                // Execute actions from payload

                // Load feeds first.
                WKInterfaceController.openParentApplication(["request": "refreshData"], reply: { (replyInfo, error) -> Void in
                    if let reply = replyInfo {
                        if let feedData = reply["feedData"] as? NSData {
                            NSKeyedUnarchiver.setClass(FeedItem.self, forClassName: "FeedItem")
                            if let feeds = NSKeyedUnarchiver.unarchiveObjectWithData(feedData) as? [FeedItem] {
                                self.helper.setCachedFeeds(feeds)
                                self.feeds = feeds
                                self.reloadTable()
                                
                                // Start going through the table for data
                                if let urlPayload = remoteNotification["url"] as? String { // Get the "url" json key from remoteNotification
                                    for var i = 0; i<self.feeds.count; i++ {
                                        if self.feeds[i].link == urlPayload {
                                            self.pushControllerWithName("DetailInterfaceController", context: FeedItem(title: self.feeds[i].title, link: self.feeds[i].link, date: self.feeds[i].date, author: self.feeds[i].author, content: self.feeds[i].content))
                                            break
                                        }
                                    }
                                }
                            }
                        } else {
                            // Try again, this time with only the current cached table
                            if let urlPayload = remoteNotification["url"] as? String { // Get the "url" json key from remoteNotification
                                for var i = 0; i<self.feeds.count; i++ {
                                    if self.feeds[i].link == urlPayload {
                                        self.pushControllerWithName("DetailInterfaceController", context: FeedItem(title: self.feeds[i].title, link: self.feeds[i].link, date: self.feeds[i].date, author: self.feeds[i].author, content: self.feeds[i].content))
                                        break
                                    }
                                }
                            }
                        }
                    }
                })
            }
        }
    }

    // MARK: - Table View

    func reloadTable() {
        if feedsTable.numberOfRows != feeds.count {
            feedsTable.setNumberOfRows(feeds.count, withRowType: "FeedRow")
        }
        for (index, feed) in enumerate(feeds) {
            if let row = feedsTable.rowControllerAtIndex(index) as? FeedRow {
                row.titleLabel.setText(feed.title)
                row.detailLabel.setText("\(feed.date) \(feed.author)")
            }
        }
    }

    // MARK: - Navigation

    override func contextForSegueWithIdentifier(segueIdentifier: String, inTable table: WKInterfaceTable, rowIndex: Int) -> AnyObject? {
        if segueIdentifier == "toDetail" {
            let fdItem = feeds[rowIndex]
            return fdItem
        }
        return nil
    }
}
