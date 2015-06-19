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
    
    // Variables
    private var remoteNotificationURL : String = ""
    private var didReceivePushNotification : Bool = false
    
    override init() {
        //println("__INIT__")
    }
    
    // Data retrieval methods
    func getRemoteNotificationURL() -> String {
        return remoteNotificationURL
    }
    
    func getDidReceivePushNotification() -> Bool {
        return didReceivePushNotification
    }
    
    // Data input methods
    func setRemoteNotificationURLWithString(urlString: String) {
        remoteNotificationURL = urlString
    }
    
    func setDidReceivePushNotificationWithBool(pushNotifcationReceivedBool: Bool) {
        didReceivePushNotification = pushNotifcationReceivedBool;
    }
}
