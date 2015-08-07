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
            var finalAttrString = NSMutableAttributedString()
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
            return processedString.stringByDecodingHTMLEntities
        }
        return nil
    }

}

extension String {

    /// Returns a new string made by replacing in the `String`
    /// all HTML character entity references with the corresponding
    /// character.

    var stringByDecodingHTMLEntities: String {

        let characterEntities : [String:Character] = [
            // XML predefined entities:
            "&quot;"    : "\"",
            "&amp;"     : "&",
            "&apos;"    : "'",
            "&lt;"      : "<",
            "&gt;"      : ">",

            // HTML character entity references:
            "&nbsp;"    : "\u{00a0}",
            // ...
            "&diams;"   : "♦",
        ]

        // ===== Utility functions =====
        // Convert the number in the string to the corresponding
        // Unicode character, e.g.
        //    decodeNumeric("64", 10)   --> "@"
        //    decodeNumeric("20ac", 16) --> "€"
        func decodeNumeric(string: String, base: Int32) -> Character? {
            let code = UInt32(strtoul(string, nil, base))
            return Character(UnicodeScalar(code))
        }

        // Decode the HTML character entity to the corresponding
        // Unicode character, return `nil` for invalid input.
        //     decode("&#64;")    --> "@"
        //     decode("&#x20ac;") --> "€"
        //     decode("&lt;")     --> "<"
        //     decode("&foo;")    --> nil
        func decode(entity: String) -> Character? {
            if entity.hasPrefix("&#x") || entity.hasPrefix("&#X"){
                return decodeNumeric(entity.substringFromIndex(advance(entity.startIndex, 3)), 16)
            } else if entity.hasPrefix("&#") {
                return decodeNumeric(entity.substringFromIndex(advance(entity.startIndex, 2)), 10)
            } else {
                return characterEntities[entity]
            }
        }

        // ===== Method starts here =====

        var result = ""
        var position = startIndex

        // Find the next '&' and copy the characters preceding it to `result`:
        while let ampRange = self.rangeOfString("&", range: position ..< endIndex) {
            result.extend(self[position ..< ampRange.startIndex])
            position = ampRange.startIndex

            // Find the next ';' and copy everything from '&' to ';' into `entity`
            if let semiRange = self.rangeOfString(";", range: position ..< endIndex) {
                let entity = self[position ..< semiRange.endIndex]
                position = semiRange.endIndex

                if let decoded = decode(entity) {
                    // Replace by decoded character:
                    result.append(decoded)
                } else {
                    // Invalid entity, copy verbatim:
                    result.extend(entity)
                }
            } else {
                // No matching ';'.
                break
            }
        }
        // Copy remaining characters to `result`:
        result.extend(self[position ..< endIndex])
        return result
    }
}
