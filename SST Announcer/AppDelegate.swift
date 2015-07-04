//
//  AppDelegate.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 2/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

import Parse
import Bolts
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.

        // Fabric Init
        Fabric.with([Crashlytics()])

        // Parse Init
        Parse.setApplicationId("5OtbHnpgcIWBOOBSDsN75dbLGYyD1zYrbK1NtUsI", clientKey: "c3KRrAwmvY8GGLR7iNh9WwhNRMLKiew0YOa5gqv6")

        // Register for Push Notitications
        if application.applicationState != UIApplicationState.Background {
            // Track an app open here if we launch with a push, unless
            // "content_available" was used to trigger a background push (introduced in iOS 7).
            // In that case, we skip tracking here to avoid double counting the app-open.

            let preBackgroundPush = !application.respondsToSelector("backgroundRefreshStatus")
            let oldPushHandlerOnly = !self.respondsToSelector("application:didReceiveRemoteNotification:fetchCompletionHandler:")
            var pushPayload = false
            if let options = launchOptions {
                pushPayload = options[UIApplicationLaunchOptionsRemoteNotificationKey] != nil
            }
            if preBackgroundPush || oldPushHandlerOnly || pushPayload {
                PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
            }
        }
        if application.respondsToSelector("registerUserNotificationSettings:") {
            let userNotificationTypes = UIUserNotificationType.Alert | UIUserNotificationType.Badge | UIUserNotificationType.Sound
            let settings = UIUserNotificationSettings(forTypes: userNotificationTypes, categories: nil)
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        } else {
            let types = UIRemoteNotificationType.Badge | UIRemoteNotificationType.Alert | UIRemoteNotificationType.Sound
            application.registerForRemoteNotificationTypes(types)
        }

        // Push notification handling when app is not running, with really tight checking. Nothing gets left!
        if let notificationPayload = launchOptions?[UIApplicationLaunchOptionsRemoteNotificationKey] as? NSDictionary {
            if let urlString = notificationPayload["url"] as? String {
                let singleton = GlobalSingleton.sharedInstance
                singleton.setDidReceivePushNotificationWithBool(true)
                singleton.setRemoteNotificationURLWithString(urlString)
            }
        }

        return true
    }

    func application(application: UIApplication, didRegisterUserNotificationSettings notificationSettings: UIUserNotificationSettings) {
        application.registerForRemoteNotifications()
    }

    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        let installation = PFInstallation.currentInstallation()
        installation.setDeviceTokenFromData(deviceToken)
        installation.saveInBackground()
    }

    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        if error.code == 3010 {
            println("Push notifications are not supported in the iOS Simulator.")
        } else {
            println("Failed to register for push: \(error.description)")
        }
    }

    // Note to self: didReceiveRemoteNotification is called when app is still running
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        if let url: AnyObject = userInfo["url"] {
            if let urlString = url as? String {
                let singleton = GlobalSingleton.sharedInstance
                singleton.setRemoteNotificationURLWithString(urlString)
                singleton.setDidReceivePushNotificationWithBool(true)
                NSNotificationCenter.defaultCenter().postNotificationName("pushReceived", object: self)
            }
        }

        if application.applicationState == .Inactive || application.applicationState == .Background {
            PFAnalytics.trackAppOpenedWithRemoteNotificationPayload(userInfo)
        }
    }

    func applicationWillResignActive(application: UIApplication) {
        // Force sync NSUserDefaults, to prevent data loss
        NSUserDefaults.standardUserDefaults().synchronize()
    }

    func applicationDidEnterBackground(application: UIApplication) {
    }

    func applicationWillEnterForeground(application: UIApplication) {
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the app was inactive.
        let currentInstallation: PFInstallation = PFInstallation.currentInstallation()
        if currentInstallation.badge != 0 {
            currentInstallation.badge = 0
            currentInstallation.saveEventually()
        }

        UIApplication.sharedApplication().applicationIconBadgeNumber = 0
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate
    }

    func application(application: UIApplication, handleWatchKitExtensionRequest userInfo: [NSObject:AnyObject]?, reply: (([NSObject : AnyObject]!) -> Void)!) {
        if let userInfo = userInfo, request = userInfo["request"] as? String {
            if request == "refreshData" {
                let helper = FeedHelper()
                if let feeds = helper.requestFeedsSynchronous() {
                    NSKeyedArchiver.setClassName("FeedItem", forClass: FeedItem.self)
                    reply(["feedData": NSKeyedArchiver.archivedDataWithRootObject(feeds)])
                } else {
                    reply([:])
                }
                return
            }
        }
        reply([:])
    }

}
