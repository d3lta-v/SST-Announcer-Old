//
//  DetailInterfaceController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 4/7/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import WatchKit
import Foundation

class DetailInterfaceController: WKInterfaceController {

    // MARK: - Private variables

    @IBOutlet weak var titleLabel: WKInterfaceLabel!
    @IBOutlet weak var descriptionLabel: WKInterfaceLabel!
    @IBOutlet weak var authorLabel: WKInterfaceLabel!
    private var feedItem: FeedItem!

    // MARK: - Lifecycle

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)

        // Configure interface objects here.
        if let fdItem = context as? FeedItem {
            self.feedItem = fdItem
            setupView()
        }
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        updateUserActivity("net.statixind.Announcer.article", userInfo: ["title": self.feedItem.title], webpageURL: nil)
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    // MARK: - Private functions

    func setupView() {
        titleLabel.setText(feedItem.title)
        authorLabel.setText(feedItem.author)
        if checkIfStringHasIncompatibleViews(feedItem.content) {
            let ios7Color = UIColor(red: 0, green: 122/255, blue: 1, alpha: 1)
            let attributedWarning = NSAttributedString(string: "This post contains elements Apple Watch can't display. You can read a text version below, or handoff to your iPhone to read the full version.\n\n", attributes: [NSForegroundColorAttributeName:ios7Color])
            var processedAttributedText = NSAttributedString(string: "Error", attributes: [NSForegroundColorAttributeName: UIColor.whiteColor()])
            if let processedText = stripAndProcessHTMLString(feedItem.content) {
                let attr = [NSForegroundColorAttributeName:UIColor.whiteColor()]
                processedAttributedText = NSAttributedString(string:processedText, attributes:attr)
            }
            let finalAttrString = NSMutableAttributedString()
            finalAttrString.appendAttributedString(attributedWarning)
            finalAttrString.appendAttributedString(processedAttributedText)
            descriptionLabel.setAttributedText(finalAttrString)
        } else {
            descriptionLabel.setText(stripAndProcessHTMLString(feedItem.content))
        }
    }

    func checkIfStringHasIncompatibleViews(string: String) -> Bool {
        if string.rangeOfString("<img") != nil || string.rangeOfString("<iframe") != nil || string.rangeOfString("<table") != nil {
            return true
        }
        return false
    }

    func stripAndProcessHTMLString(string: String) -> String? {
        if !string.isEmpty { // if string is not empty
            var processedString = string.stringByReplacingOccurrencesOfString("<div[^>]*>", withString: "<div>", options: .RegularExpressionSearch, range: nil)
            processedString = processedString.stringByReplacingOccurrencesOfString("<div><br /></div>", withString: "\n")
            processedString = processedString.stringByReplacingOccurrencesOfString("<br />", withString: "\n")
            processedString = processedString.stringByReplacingOccurrencesOfString("</div>", withString: "\n")
            processedString = processedString.stringByReplacingOccurrencesOfString("<iframe[\\s\\S]*?/iframe>", withString: "", options: .RegularExpressionSearch, range: nil)
            processedString = processedString.stringByReplacingOccurrencesOfString("<img[\\s\\S]*? />", withString: "", options: .RegularExpressionSearch, range: nil)
            processedString = processedString.stringByReplacingOccurrencesOfString("<[^>]+>", withString: "", options: .RegularExpressionSearch, range: nil)
            processedString = processedString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            return String(htmlEncodedString: processedString)
        }
        return nil
    }

}

extension String {
    init(htmlEncodedString: String) {
        let encodedData = htmlEncodedString.dataUsingEncoding(NSUTF8StringEncoding)!
        let attributedOptions: [String: AnyObject] = [
            NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
            NSCharacterEncodingDocumentAttribute: NSUTF8StringEncoding
        ]
        var attrStr = NSAttributedString()
        do {
            attrStr = try NSAttributedString(data: encodedData, options: attributedOptions, documentAttributes: nil)
        } catch let error as NSError {
            print(error.description)
        }
        self.init(attrStr.string)
    }
}
