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
    private let helper = FeedHelper.sharedInstance
    private var feeds: [FeedItem]!
    private let longDateFormatter = NSDateFormatter()
    private let shortDateFormatter = NSDateFormatter()

    // MARK: - Lifecycle

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)

        // Configure interface objects here.
        // Configure dateFormatter
        let standardLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        longDateFormatter.locale = standardLocale
        longDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm"
        shortDateFormatter.locale = standardLocale
        shortDateFormatter.dateFormat = "dd/MM/yy"

        invalidateUserActivity() // we don't want handoff, YET

        setTitle("Announcer")
        if let feedsUnwrapped = helper.getCachedFeeds() {
            feeds = feedsUnwrapped
            reloadTable()
        }

        // Attempt to load new data from parent application
        WKInterfaceController.openParentApplication(["request": "refreshData"], reply: { (replyInfo, error) -> Void in
            if error == nil {
                if let reply = replyInfo, feedData = reply["feedData"] as? NSData {
                    NSKeyedUnarchiver.setClass(FeedItem.self, forClassName: "FeedItem")
                    if let feeds = NSKeyedUnarchiver.unarchiveObjectWithData(feedData) as? [FeedItem] {
                        if feeds.count != 0 {
                            self.helper.setCachedFeeds(feeds)
                            self.feeds = feeds
                            self.reloadTable()
                        }
                    }
                }
            } else {
                println(error)
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
            if notifIdentifier == "viewFeed" {
                // Execute actions from payload

                // First attempt (with only the current feeds cache)
                if let urlPayload = remoteNotification["url"] as? String { // Get the "url" json key from remoteNotification
                    let success = self.initiatePushNotificationReading(urlPayload)
                    if !success {
                        // Load feeds if the previous one fails
                        WKInterfaceController.openParentApplication(["request": "refreshData"], reply: { (replyInfo, error) -> Void in
                            if let reply = replyInfo, feedData = reply["feedData"] as? NSData {
                                NSKeyedUnarchiver.setClass(FeedItem.self, forClassName: "FeedItem")
                                if let feeds = NSKeyedUnarchiver.unarchiveObjectWithData(feedData) as? [FeedItem] {
                                    self.helper.setCachedFeeds(feeds)
                                    self.feeds = feeds
                                    self.reloadTable()

                                    // Start going through the table for data
                                    if let urlPayload = remoteNotification["url"] as? String { // Get the "url" json key from remoteNotification
                                        self.initiatePushNotificationReading(urlPayload)
                                    }
                                }
                            } else {
                                // Try again, this time with only the current cached table
                                if let urlPayload = remoteNotification["url"] as? String { // Get the "url" json key from remoteNotification
                                    self.initiatePushNotificationReading(urlPayload)
                                }
                            }
                        })
                    }
                }
            }
        }
    }

    // MARK: - Private functions

    func initiatePushNotificationReading(payload: String) -> Bool {
        for var i = 0; i<self.feeds.count; i++ {
            if self.feeds[i].link == payload {
                let context = FeedItem(
                    title: self.feeds[i].title,
                    link: self.feeds[i].link,
                    date: self.feeds[i].date,
                    author: self.feeds[i].author,
                    content: self.feeds[i].content)
                self.pushControllerWithName("DetailInterfaceController", context: context)
                return true
            }
        }
        return false
    }

    // MARK: - Table View

    func reloadTable() {
        if feedsTable.numberOfRows != feeds.count {
            feedsTable.setNumberOfRows(feeds.count, withRowType: "FeedRow")
        }
        for (index, feed) in enumerate(feeds) {
            if let row = feedsTable.rowControllerAtIndex(index) as? FeedRow {
                if feeds[index].title == "" {
                    feeds[index].title = "<No Title>"
                }
                row.titleLabel.setText(feed.title)
                if let shortDate = longDateFormatter.dateFromString(feed.date) {
                    let shortDateString = shortDateFormatter.stringFromDate(shortDate)
                    row.detailLabel.setText("\(shortDateString) \(feed.author)")
                }
            }
        }
    }

    // MARK: - Actions

    @IBAction func refresh() {
        // Attempt a initial forced data refresh
        if let feedsUnwrapped = helper.getCachedFeeds() {
            feeds = feedsUnwrapped
            reloadTable()
        }

        // Then try a network refresh
        WKInterfaceController.openParentApplication(["request": "refreshData"], reply: { (replyInfo, error) -> Void in
            if let reply = replyInfo {
                if let feedData = reply["feedData"] as? NSData {
                    NSKeyedUnarchiver.setClass(FeedItem.self, forClassName: "FeedItem")
                    if let feeds = NSKeyedUnarchiver.unarchiveObjectWithData(feedData) as? [FeedItem] {
                        if feeds.count != 0 {
                            self.helper.setCachedFeeds(feeds)
                            self.feeds = feeds
                            self.reloadTable()
                        }
                    }
                }
            }
        })
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
