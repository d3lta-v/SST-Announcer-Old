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
    @IBOutlet weak var animationView: WKInterfaceImage!
    private let helper = FeedHelper.sharedInstance
    private var feeds: [FeedItem]!
    private let longDateFormatter = NSDateFormatter()
    private let shortDateFormatter = NSDateFormatter()
    private var recursionLength = 0

    // MARK: - Lifecycle

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)

        // Configure interface objects here.
        // Configure dateFormatter
        let standardLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        longDateFormatter.locale = standardLocale
        longDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm"
        shortDateFormatter.locale = standardLocale
        shortDateFormatter.dateFormat = "dd/MM/yy HH:mm"

        invalidateUserActivity() // we don't want handoff, YET

        setTitle("Announcer")
        if let feedsUnwrapped = helper.getCachedFeeds() {
            feeds = feedsUnwrapped
            reloadTable()
        }

        // Attempt to load new data from parent application
        networkRefreshAnimated(false, pushPayload: nil, recursive: false)
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
                        // Load feeds if the previous one fails (most of the case it will)
                        //refreshForPushNotification(remoteNotification, animated: true)
                        networkRefreshAnimated(true, pushPayload: remoteNotification, recursive: false)
                    }
                }
            }
        }
    }

    // MARK: - Private functions

    func initiatePushNotificationReading(payload: String) -> Bool {
        for var i = 0; i<self.feeds.count; i++ {
            if self.feeds[i].link == payload {
                stopLoadingAnimation()
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

    // Note: recursive flag must NOT be on when calling this function from outside this function
    func networkRefreshAnimated(animated: Bool, pushPayload: [NSObject: AnyObject]?, recursive: Bool) {
        if animated && !recursive {
            startLoadingAnimation()
        }
        WKInterfaceController.openParentApplication(["request": "refreshData"], reply: { (replyInfo, error) -> Void in
            if error == nil {
                if let reply = replyInfo, feedData = reply["feedData"] as? NSData {
                    NSKeyedUnarchiver.setClass(FeedItem.self, forClassName: "FeedItem")
                    if let feeds = NSKeyedUnarchiver.unarchiveObjectWithData(feedData) as? [FeedItem] {
                        if feeds.count != 0 {
                            self.helper.setCachedFeeds(feeds)
                            self.feeds = feeds
                            if animated {
                                self.stopLoadingAnimation()
                            }
                            self.reloadTable()
                            // Check if this is a push notification
                            if let payload = pushPayload, urlPayload = payload["url"] as? String { // Get the "url" json key from remoteNotification
                                self.initiatePushNotificationReading(urlPayload) // Start scanning through current list of posts
                            }
                        }
                    }
                } else if let payload = pushPayload, urlPayload = payload["url"] as? String {
                    // Force re-check for push notification in the current table
                    self.initiatePushNotificationReading(urlPayload)
                }
            } else {
                println(error)
                if self.recursionLength < 3 { // allow for further recursion if length less than 3
                    self.recursionLength++
                    self.networkRefreshAnimated(false, pushPayload: pushPayload, recursive: true) // recursion m8
                } else {
                    self.recursionLength = 0 // Reset recursion length indicator
                    self.stopLoadingAnimation() // terminate loading animation if error persists
                }
            }
        })
    }

    func startLoadingAnimation() {
        feedsTable.setHidden(true)
        animationView.setHidden(false)
        animationView.setImageNamed("wave_")
        animationView.startAnimating()
    }

    func stopLoadingAnimation() {
        self.animationView.stopAnimating()
        self.animationView.setHidden(true)
        self.feedsTable.setHidden(false)
    }

    // MARK: - Table View

    func reloadTable() {
        if feedsTable.numberOfRows != feeds.count {
            feedsTable.setNumberOfRows(feeds.count, withRowType: "FeedRow")
        }
        for (index, feed) in enumerate(feeds) {
            if let row = feedsTable.rowControllerAtIndex(index) as? FeedRow {
                if feed.title == "" {
                    feed.title = "<No Title>"
                }
                row.titleLabel.setText(feed.title)
                row.author.setText(feed.author)
                if let shortDate = longDateFormatter.dateFromString(feed.date) {
                    let correctDate = shortDate.dateByAddingTimeInterval(Double(NSTimeZone.systemTimeZone().secondsFromGMT))
                    let shortDateString = shortDateFormatter.stringFromDate(correctDate)
                    row.date.setText(shortDateString)
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
        networkRefreshAnimated(true, pushPayload: nil, recursive: false)
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
