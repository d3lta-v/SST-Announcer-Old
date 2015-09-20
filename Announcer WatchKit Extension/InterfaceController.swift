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
        self.addMenuItemWithItemIcon(WKMenuItemIcon.Repeat, title: "Refresh", action: "refresh")

        setTitle("Announcer")

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
        helper.requestFeedsSynchronous({ (result) -> Void in
            guard let resultUnwrapped = result else {
                if animated {self.stopLoadingAnimation()}
                let errorObject = FeedItem(title: "Error Loading", link: "", date: "It seems like you are either not connected to the Internet or something is wrong with your Watch's connectivity. Try Force Touching the display and press Refresh to force a refresh", author: "Sorry about this: ", content: "It seems like you are either not connected to the Internet or something is wrong with your Watch's connectivity. Try going back to the previous menu and Force Touching the display and press Refresh to force a refresh")
                self.feeds = [errorObject]
                self.reloadTable()
                return
            }
            if animated {self.stopLoadingAnimation()}
            self.feeds = resultUnwrapped
            self.reloadTable()
            if let payload = pushPayload, urlPayload = payload["url"] as? String { // Get the "url" json key from remoteNotification
                self.initiatePushNotificationReading(urlPayload) // Start scanning through current list of posts
            }
        })
    }

    // MARK: Loading animations
    func startLoadingAnimation() {
        feedsTable.setHidden(true)
        self.clearAllMenuItems()
        animationView.setHidden(false)
        animationView.setImageNamed("wave_")
        animationView.startAnimating()
    }

    func stopLoadingAnimation() {
        self.animationView.stopAnimating()
        self.animationView.setHidden(true)
        self.feedsTable.setHidden(false)
        self.addMenuItemWithItemIcon(WKMenuItemIcon.Repeat, title: "Refresh", action: "refresh")
    }

    // MARK: - Table View

    func reloadTable() {
        if feedsTable.numberOfRows != feeds.count {
            feedsTable.setNumberOfRows(feeds.count, withRowType: "FeedRow")
        }
        for (index, feed) in feeds.enumerate() {
            if let row = feedsTable.rowControllerAtIndex(index) as? FeedRow {
                if feed.title == "" {
                    feed.title = "<No Title>"
                }
                row.titleLabel.setText(feed.title)
                row.author.setText(feed.author)
                if let longDate = longDateFormatter.dateFromString(feed.date) {
                    let shortDateString = shortDateFormatter.stringFromDate(longDate)
                    row.date.setText(shortDateString)
                } else {
                    row.date.setText(feed.date)
                }
            }
        }
    }

    // MARK: - Actions

    func refresh() {
        // Network refresh
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
