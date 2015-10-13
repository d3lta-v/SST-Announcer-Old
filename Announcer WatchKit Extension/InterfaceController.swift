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

    // MARK: IBOutlets
    @IBOutlet var feedsTable: WKInterfaceTable!
    @IBOutlet var animationView: WKInterfaceImage!
    @IBOutlet var errorTitle: WKInterfaceLabel!
    @IBOutlet var errorMessage: WKInterfaceLabel!

    // MARK: Variables
    private let helper = FeedHelper.sharedInstance
    private var feeds: [FeedItem]!
    private let longDateFormatter = NSDateFormatter()
    private let shortDateFormatter = NSDateFormatter()
    private var recursionLength = 0
    private var pushPayload: String? = nil
    private var currentlyRefreshing = false

    // MARK: - Lifecycle

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)

        // Configure interface objects here.
        // Configure dateFormatter
        let standardLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        longDateFormatter.locale = standardLocale
        longDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm"
        shortDateFormatter.locale = standardLocale
        shortDateFormatter.dateFormat = "dd/MM/yy h:mm a"

        invalidateUserActivity() // we don't want handoff, YET
        setTitle("Announcer")

        // Attempt to load new data from parent application
        networkRefreshAnimated(true, pushPayload: pushPayload, recursive: false)
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
                guard let urlPayload = remoteNotification["url"] as? String else {return}
                if self.currentlyRefreshing {
                    self.pushPayload = urlPayload
                } else {
                    networkRefreshAnimated(true, pushPayload: urlPayload, recursive: false)
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
    func networkRefreshAnimated(animated: Bool, pushPayload: String?, recursive: Bool) {
        self.currentlyRefreshing = true
        if animated && !recursive {
            hideTable()
            startLoadingAnimation()
        }
        helper.requestFeedsSynchronous({ (result) -> Void in
            guard let resultUnwrapped = result else {
                self.hideTable()
                self.showError()
                if animated {self.stopLoadingAnimation()}
                self.currentlyRefreshing = false
                return
            }
            guard resultUnwrapped.count > 0 else {
                self.hideTable()
                self.showError()
                if animated {self.stopLoadingAnimation()}
                self.currentlyRefreshing = false
                return
            }
            self.feeds = resultUnwrapped
            self.reloadTable()
            if animated {self.stopLoadingAnimation()}
            self.showTable()
            self.currentlyRefreshing = false
            if let urlString = pushPayload { // Get the "url" json key from remoteNotification
                self.initiatePushNotificationReading(urlString) // Start scanning through current list of posts
            }
        })
    }

    func showError() {
        errorTitle.setHidden(false)
        errorMessage.setHidden(false)
    }

    func hideError() {
        errorTitle.setHidden(true)
        errorMessage.setHidden(true)
    }

    // MARK: Loading animations
    func startLoadingAnimation() {
        animationView.setHidden(false)
        animationView.setImageNamed("wave_")
        animationView.startAnimating()
    }

    func stopLoadingAnimation() {
        self.animationView.stopAnimating()
        self.animationView.setHidden(true)
    }

    // MARK: Convenience animation methods
    func showTable() {
        self.feedsTable.setHidden(false)
        self.addMenuItemWithItemIcon(WKMenuItemIcon.Repeat, title: "Refresh", action: "refresh")
    }

    func hideTable() {
        feedsTable.setHidden(true)
        self.clearAllMenuItems()
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
