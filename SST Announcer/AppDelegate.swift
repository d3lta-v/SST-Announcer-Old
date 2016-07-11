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
        //setenv("CFNETWORK_DIAGNOSTICS", "3", 1); // Uncomment to enable logging for CFNetwork
        // Fabric Init
        Fabric.with([Crashlytics()])

        // Parse Init
        //Parse.setApplicationId("5OtbHnpgcIWBOOBSDsN75dbLGYyD1zYrbK1NtUsI", clientKey: "c3KRrAwmvY8GGLR7iNh9WwhNRMLKiew0YOa5gqv6")

        // OneSignal push notifications initialisation
        _ = OneSignal(launchOptions: launchOptions, appId: "b2f7f966-d8cc-11e4-bed1-df8f05be55ba") { (message, additionalData, isActive) in
            print("Push notification opened: \(message)")

            if additionalData != nil {
                // Check for and read any custom values you added to the notification
                // This done with the "Additonal Data" section the dashbaord.
                // OR setting the 'data' field on our REST API.
                if let customKey = additionalData["url"] as? String {
                    print("url: \(customKey)")
                    self.globalSingletonPushReceivedWith(customKey)
                }
            }
        }

        // Configure Split View Controller properly
        //let rightNavController = WebViewController.viewControllers.last as! UINavigationController
        //let detailViewController = rightNavController.topViewController as! DetailViewController

//        // Register for Push Notitications
//        if application.applicationState != UIApplicationState.Background {
//            // Track an app open here if we launch with a push, unless
//            // "content_available" was used to trigger a background push (introduced in iOS 7).
//            // In that case, we skip tracking here to avoid double counting the app-open.
//            let preBackgroundPush = !application.respondsToSelector("backgroundRefreshStatus")
//            let oldPushHandlerOnly = !self.respondsToSelector("application:didReceiveRemoteNotification:fetchCompletionHandler:")
//            var pushPayload = false
//            if let options = launchOptions {
//                pushPayload = options[UIApplicationLaunchOptionsRemoteNotificationKey] != nil
//            }
//            if preBackgroundPush || oldPushHandlerOnly || pushPayload {
//                PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
//            }
//        }
//        let userNotificationTypes: UIUserNotificationType = [.Alert, .Badge, .Sound]
//        let settings = UIUserNotificationSettings(forTypes: userNotificationTypes, categories: getCategory())
//        application.registerUserNotificationSettings(settings)
//        application.registerForRemoteNotifications()
//        // Push notification handling when app is not running, with really tight checking. Nothing gets left!
//        if let notificationPayload = launchOptions?[UIApplicationLaunchOptionsRemoteNotificationKey] as? NSDictionary {
//            if let urlString = notificationPayload["url"] as? String {
//                globalSingletonPushReceivedWith(urlString)
//            }
//        }

        return true
    }

//    func application(application: UIApplication, supportedInterfaceOrientationsForWindow window: UIWindow?) -> UIInterfaceOrientationMask {
//        // Override customisation for iPhone 6+ screen sizes checking for rotation
//        var rv = UIInterfaceOrientationMask.Portrait
//        if rv == .Portrait {
//            if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
//                if let s = window?.bounds.size {
//                    if max(s.width, s.height) >= 700 {
//                        rv = .AllButUpsideDown
//                    } else {
//                        rv = .Portrait
//                    }
//                }
//            } else {
//                rv = .All
//            }
//        }
//        return rv
//    }

    // MARK: - Push notifications

//    func application(application: UIApplication, didRegisterUserNotificationSettings notificationSettings: UIUserNotificationSettings) {
//        application.registerForRemoteNotifications()
//    }
//
//    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
//        let installation = PFInstallation.currentInstallation()
//        installation.setDeviceTokenFromData(deviceToken)
//        installation.saveInBackground()
//        let tokenChars = UnsafePointer<CChar>(deviceToken.bytes)
//        var tokenString = ""
//        for i in 0..<deviceToken.length {
//            tokenString += String(format: "%02.2hhx", arguments: [tokenChars[i]])
//        }
//        print("DeviceToken:\(tokenString)")
//    }
//
//    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
//        if error.code != 3010 {
//            print("Failed to register for push: \(error.localizedDescription)")
//        }
//    }

    // Note to self: didReceiveRemoteNotification is called when app is still running
//    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
//        if let url: AnyObject = userInfo["url"] {
//            if let urlString = url as? String {
//                globalSingletonPushReceivedWith(urlString)
//                NSNotificationCenter.defaultCenter().postNotificationName("pushReceived", object: self)
//            }
//        }
//
//        if application.applicationState == .Inactive || application.applicationState == .Background {
//            PFAnalytics.trackAppOpenedWithRemoteNotificationPayload(userInfo)
//        }
//    }

    func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [NSObject : AnyObject], completionHandler: () -> Void) {
        if identifier == "viewFeed" {
            if let urlString = userInfo["url"] as? String {
                self.globalSingletonPushReceivedWith(urlString)
                resetBadges()
                if application.applicationState == .Inactive || application.applicationState == .Background {
                    PFAnalytics.trackAppOpenedWithRemoteNotificationPayload(userInfo)
                }
            }
        }
    }

    // MARK: - Application Lifecycle

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
        resetBadges()
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate
    }

    // MARK: - Private functions

    private func globalSingletonPushReceivedWith(urlString: String) {
        let singleton = GlobalSingleton.sharedInstance
        singleton.setRemoteNotificationURLWithString(urlString)
        singleton.setDidReceivePushNotificationWithBool(true)
    }

    private func resetBadges() {
        let currentInstallation: PFInstallation = PFInstallation.currentInstallation()
        if currentInstallation.badge != 0 {
            currentInstallation.badge = 0
            currentInstallation.saveEventually()
        }
    }

    // MARK: - WatchKit, custom notifications and Handoff

    @available(iOS 8.0, *)
    func application(application: UIApplication, continueUserActivity userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> Void) -> Bool {
        if let window = self.window, rvc = window.rootViewController as? UITabBarController {
            rvc.selectedIndex = 0
            if let navControl = rvc.selectedViewController as? UINavigationController {
                navControl.popToRootViewControllerAnimated(true)
                navControl.childViewControllers.first?.restoreUserActivityState(userActivity)
            }
        }
        return true
    }

    @available(iOS 8.0, *)
    func getCategory() -> Set<UIMutableUserNotificationCategory> {
        var categories = Set<UIMutableUserNotificationCategory>()

        let viewAction = UIMutableUserNotificationAction()
        viewAction.title = "View Article"
        viewAction.identifier = "viewFeed"
        viewAction.activationMode = UIUserNotificationActivationMode.Foreground

        let defaultCategory = UIMutableUserNotificationCategory()
        defaultCategory.setActions([viewAction], forContext: .Default)
        defaultCategory.identifier = "viewFeed"

        categories.insert(defaultCategory)

        return categories
    }

}
