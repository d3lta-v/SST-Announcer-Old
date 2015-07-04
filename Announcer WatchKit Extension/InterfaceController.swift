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
    /*
This message contains elements Apple Watch can't display. You can read a text version below. <in blue>
    */

    // MARK: - Private variables
    @IBOutlet weak var feedsTable: WKInterfaceTable!
    private let helper = FeedHelper()
    private var feeds: [FeedItem]!

    // MARK: - Lifecycle
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)

        // Configure interface objects here.
        setTitle("Announcer")
        if let feedsUnwrapped = helper.getCachedFeeds() {
            feeds = feedsUnwrapped
            reloadTable()
        }

        // Attempt to load new data from parent application
        WKInterfaceController.openParentApplication(["request": "refreshData"], reply: { (replyInfo, error) -> Void in
                println("Reply: \(replyInfo)") // called when parent app is finished
                if let feedData = replyInfo["feedData"] as? NSData {
                    NSKeyedUnarchiver.setClass(FeedItem.self, forClassName: "FeedItem")
                    if let feeds = NSKeyedUnarchiver.unarchiveObjectWithData(feedData) as? [FeedItem] {
                        self.helper.setCachedFeeds(feeds)
                        self.feeds = feeds
                        self.reloadTable()
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
