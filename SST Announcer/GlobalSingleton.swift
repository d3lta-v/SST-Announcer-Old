//
//  GlobalSingleton.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 2/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

class GlobalSingleton: NSObject {
    static let sharedInstance = GlobalSingleton()

    // MARK: Variables / initializers
    private var remoteNotificationURL: String = ""
    private var didReceivePushNotification: Bool = false

    override init() {
        //println("__INIT__")
    }

    // MARK: Data retrieval methods
    func getRemoteNotificationURL() -> String {
        return remoteNotificationURL
    }

    func getDidReceivePushNotification() -> Bool {
        return didReceivePushNotification
    }

    // MARK: Data input methods
    func setRemoteNotificationURLWithString(urlString: String) {
        remoteNotificationURL = urlString
    }

    func setDidReceivePushNotificationWithBool(pushNotifcationReceivedBool: Bool) {
        didReceivePushNotification = pushNotifcationReceivedBool;
    }

    // MARK: Misc UI methods
    func getTableRowHeight(currentApplication: UIApplication) -> CGFloat {
        let preferredSizeCategory = currentApplication.preferredContentSizeCategory
        switch preferredSizeCategory {
        case UIContentSizeCategoryExtraSmall:
            return 40;
        case UIContentSizeCategorySmall:
            return 45;
        case UIContentSizeCategoryMedium:
            return 50;
        case UIContentSizeCategoryLarge:
            return 55;
        case UIContentSizeCategoryExtraLarge:
            return 60;
        case UIContentSizeCategoryExtraExtraLarge:
            return 65;
        case UIContentSizeCategoryExtraExtraExtraLarge:
            return 70;
        case UIContentSizeCategoryAccessibilityMedium:
            return 75;
        case UIContentSizeCategoryAccessibilityLarge:
            return 80;
        case UIContentSizeCategoryAccessibilityExtraLarge:
            return 85;
        case UIContentSizeCategoryAccessibilityExtraExtraLarge:
            return 90;
        case UIContentSizeCategoryAccessibilityExtraExtraExtraLarge:
            return 95;
        default:
            return 55
        }
    }

    // MARK: Misc methods
    func delay(delay: Double, closure:()->()) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay * Double(NSEC_PER_SEC))
            ),
            dispatch_get_main_queue(), closure)
    }
}
