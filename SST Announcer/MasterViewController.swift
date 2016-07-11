//
//  MasterTableViewController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 2/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController {

    // MARK: - Private variables declaration

    // MARK: Basic structure
    private var parser: NSXMLParser!
    private var tempItem: FeedItem
    private var feeds: [FeedItem]
    private var newFeeds: [FeedItem] // NewFeeds is actually to "cache" a copy of the new feeds, and synchronise it to the old feeds
    private var element: String = ""
    private var searchResults: [FeedItem]
    private let fullDateFormatter: NSDateFormatter
    private let longDateFormatter: NSDateFormatter
    private let helper = GlobalSingleton.sharedInstance
    private let feedHelper = FeedHelper.sharedInstance
    private var handoffActivated = false
    private var handoffIndex = -1
    private var progressCancelled = false

    // MARK: UI Structure related variables
    private var collapseDetailViewController = true

    // MARK: NSURLSession Variables
    private var progress: Float = 0.0
    private var buffer: NSMutableData? = NSMutableData()
    private var expectedContentLength = 0

    // MARK: Handoff Variables
    private var handoffTitle: String?
    private var goForHandoff: Bool = false

    // MARK: - Lifecycle

    required init!(coder aDecoder: NSCoder) {
        // Variables initialization
        feeds = [FeedItem]()
        newFeeds = [FeedItem]()
        tempItem = FeedItem(title: "", link: "", date: "", author: "", content: "")
        searchResults = [FeedItem]()

        let stdLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        fullDateFormatter = NSDateFormatter()
        fullDateFormatter.locale = stdLocale
        fullDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss ZZZ"

        longDateFormatter = NSDateFormatter()
        longDateFormatter.locale = stdLocale
        longDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm"

        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Init refresh controls
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(MasterViewController.refresh(_:)), forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl = refreshControl

        self.tableView.estimatedRowHeight = 55
        self.tableView.rowHeight = UITableViewAutomaticDimension
        // Add observer for push to catch push notification messages
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MasterViewController.pushNotificationsReceived), name: "pushReceived", object: nil)

        // Assign UISplitViewControllerDelegate to ownself
        self.splitViewController?.delegate = self
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        getFeedsOnce()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        progressCancelled = false

        // Check for push notifications
        if helper.getDidReceivePushNotification() == true {
            self.performSegueWithIdentifier("MasterToDetail", sender: self)
        }
    }

    override func viewWillDisappear(animated: Bool) {
        progressCancelled = true
        self.navigationController?.cancelSGProgress()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Private methods

    struct TokenHolder {
        static var token: dispatch_once_t = 0
    }

    private func getFeedsOnce() {
        dispatch_once(&TokenHolder.token) {
            // Getfeeds uses a proper Swift implementation of dispatch once
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true

            // Start the refresher
            dispatch_async(dispatch_get_main_queue()) {
                if let refreshCtrl = self.refreshControl {
                    refreshCtrl.beginRefreshing()
                    let point = CGPoint(x: 0, y: self.tableView.contentOffset.y - refreshCtrl.frame.size.height)
                    self.tableView.setContentOffset(point, animated: false)
                }
            }

            // Load cached version first, while checking for existence of the cached feeds
            if let feeds = self.feedHelper.getCachedFeeds() {
                self.feeds = feeds
                self.tableView.reloadData()
            }

            // Then load the web version on a seperate thread
            self.loadFeedWithURLString("https://node1.sstinc.org/api/cache/blogrss.csv")

            // Check if user enabled push, after a 5 second delay
            self.checkUserEnabledPush()
        }
    }

    private func checkUserEnabledPush() {
        #if !((arch(i386) || arch(x86_64)) && os(iOS)) // Preprocessor macro for checking iOS sims
            self.helper.delay(5) {
                let application = UIApplication.sharedApplication()
                if #available(iOS 8.0, *) {
                    if application.isRegisteredForRemoteNotifications() == false {
                        let alert = UIAlertController(title: "You disabled push!", message: "This app relies heavily on push notifications for time-specific delivery of feeds.", preferredStyle: .Alert)
                        let okay = UIAlertAction(title: "Okay", style: UIAlertActionStyle.Cancel, handler: nil)
                        alert.addAction(okay)
                        self.presentViewController(alert, animated: true, completion: nil)
                    }
                } else {
                    let types = application.enabledRemoteNotificationTypes()
                    if types == UIRemoteNotificationType.None {
                        let alert = UIAlertView(title:"You disabled push!", message:"This app relies on push notifications for time-specific delivery of feeds.", delegate: nil, cancelButtonTitle:"Okay")
                        alert.show()
                    }
                }
            }
        #endif
    }

    private func loadFeedWithURLString(urlString: String!) {
        self.newFeeds = [FeedItem]() //Sort of like alloc init, it clears the array
        let url = NSURL(string: urlString)

        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.HTTPAdditionalHeaders = ["Accept-Encoding":""]
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
        let dataTask = session.dataTaskWithRequest(NSURLRequest(URL: url!))
        // Show progress
        dispatch_async(dispatch_get_main_queue(), {
            self.navigationController?.setSGProgressPercentage(5)
        })
        dataTask.resume()
        session.finishTasksAndInvalidate()
    }

    internal func pushNotificationsReceived() {
        if self.navigationController!.viewControllers.count < 2 {
            self.performSegueWithIdentifier("MasterToDetail", sender: self)
        }
    }

    private func synchroniseFeedArrayAndTable() {
        self.feeds = self.newFeeds
        self.tableView.reloadData()
    }

    internal func refresh(sender: UIRefreshControl) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        buffer = NSMutableData()

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            self.loadFeedWithURLString("https://node1.sstinc.org/api/cache/blogrss.csv")
        })
    }

    private func checkForNewVersion() {
        let defaults = NSUserDefaults.standardUserDefaults()
        let versionNumber = defaults.floatForKey("Announcer.version")

        if versionNumber < 8.0 { // Keep in mind this also checks if the key does not exist
            displayUpdateForNewVersion(defaults)
        }
    }

    private func displayUpdateForNewVersion(defaults: NSUserDefaults) {
        // TODO: Update this number whenever the version number changes
        defaults.setFloat(8.1, forKey: "Announcer.version")
        let titleString = "Announcer 8.1 WatchKit fix:"
        let messageString = "Advanced, uncompromising performance in a slimmer package.\n- Fully updated for iOS 9 and WatchOS 2 (and yes, updated with Swift 2.0)!\n- Fully loaded for App Transport Security, which means almost all of your communications will be encrypted.\n- Slimmer app as a result of App Thinning, with only device-specific code & assets running on your device.\n- Removed the About tab (and moved the credits to the app's Settings page)\n- iPad version fully supports slide over view AND split view for better multitasking!\n- Apple Watch now displays the correct date and time for post timings.\n- Some under-the-hood fixes to enhance code security.\n- Apple Watch can now browse Announcer without tethering to a phone!\n- Fixed a small bug related to the Watch not loading names and other metadata properly."
        let controller = UIAlertController(title: titleString, message: messageString, preferredStyle: .Alert)
        controller.addAction(UIAlertAction(title: "Okay", style: .Cancel, handler: nil))
        controller.view.frame = UIScreen.mainScreen().applicationFrame
        self.presentViewController(controller, animated: true, completion: nil)
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.

        if segue.identifier == "MasterToDetail" {
            if helper.getDidReceivePushNotification() {
                NSNotificationCenter.defaultCenter().removeObserver(self)
                (segue.destinationViewController as? WebViewController)?.receivedFeedItem = FeedItem(title: "", link: helper.getRemoteNotificationURL(), date: "", author: "", content: "")
                helper.setDidReceivePushNotificationWithBool(false)
            } else if handoffActivated == true {
                if self.feeds.isEmpty {
                    (segue.destinationViewController as? WebViewController)?.receivedFeedItem = FeedItem(title: "Error", link: "", date: "", author: "", content: "<p align=\"center\">Woops! The Handoff feature of the app has encountered an error. No worries, just go back, refresh and reselect the page.</p>")
                    handoffActivated = false
                    handoffIndex = -1
                } else {
                    (segue.destinationViewController as? WebViewController)?.receivedFeedItem = self.feeds[handoffIndex]
                    handoffActivated = false
                    handoffIndex = -1
                }
            } else {
                if self.searchDisplayController?.active == true {
                    if let indexPath = self.searchDisplayController?.searchResultsTableView.indexPathForSelectedRow {
                        (segue.destinationViewController as? WebViewController)?.receivedFeedItem = self.searchResults[indexPath.row]
                    } else {
                        (segue.destinationViewController as? WebViewController)?.receivedFeedItem = FeedItem(title: "Error", link: "", date: "", author: "", content: "<p align=\"center\">Woops! The search feature of the app has encountered an error. No worries, just go back, refresh and reselect the page.</p>")
                    }
                } else {
                    if let indexPath = self.tableView.indexPathForSelectedRow {
                        (segue.destinationViewController as? WebViewController)?.receivedFeedItem = self.feeds[indexPath.row]
                        //(segue.destinationViewController as? WebViewController)?.receivedFeedItem = FeedItem(title: "", link: "http://studentsblog.sst.edu.sg/2015/10/student-travel-declaration-novdec-2015.html", date: "", author: "", content: "")
                    } else {
                        (segue.destinationViewController as? WebViewController)?.receivedFeedItem = FeedItem(title: "Error", link: "", date: "", author: "", content: "<p align=\"center\">Woops! The app has encountered an error. No worries, just go back, refresh and reselect the page.</p>")
                    }
                }
            }
        }
    }

    // MARK: - Handoff

    @available(iOS 8.0, *)
    override func restoreUserActivityState(activity: NSUserActivity) {
        if let titleString = activity.userInfo?["title"] as? String {
            if feeds.count <= 10 {
                self.goForHandoff = true
                self.handoffTitle = titleString
            } else {
                self.initiateHandoffAction(titleString)
            }
        }
    }

    func initiateHandoffAction(titleString: String) {
        for i in 0..<feeds.count {
            if feeds[i].title == titleString {
                handoffActivated = true
                handoffIndex = i
                self.performSegueWithIdentifier("MasterToDetail", sender: self)
                break
            }
        }
    }
}

// MARK: - UISearch Delegates

extension MasterViewController : UISearchDisplayDelegate, UISearchBarDelegate {
    func filterContentForSearchText(searchText: String) {
        self.searchResults = self.feeds.filter({(post: FeedItem) -> Bool in
            let stringMatch = post.title.lowercaseString.rangeOfString(searchText.lowercaseString)
            return stringMatch != nil
        })
    }

    func searchDisplayController(controller: UISearchDisplayController, shouldReloadTableForSearchString searchString: String?) -> Bool {
        guard let searchStr = searchString else {
            return false
        }
        self.filterContentForSearchText(searchStr)
        return true
    }
}

// MARK: - UITableView Delegates

extension MasterViewController {
    // MARK: Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        if tableView == self.searchDisplayController!.searchResultsTableView {
            return self.searchResults.count
        } else {
            return self.feeds.count
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        var cellItem: FeedItem = FeedItem(title: "", link: "", date: "", author: "", content: "")

        // Configure the cell...
        if tableView == self.searchDisplayController!.searchResultsTableView {
            cellItem = self.searchResults[indexPath.row]
            //cell.textLabel?.text = self.searchResults[indexPath.row].title
        } else {
            if !feeds.isEmpty {
                cellItem = self.feeds[indexPath.row]
                if cellItem.title == "" {
                    cellItem.title = "<No Title>"
                }
            }
        }

        cell.textLabel?.text = cellItem.title
        cell.detailTextLabel?.text = "\(cellItem.date) \(cellItem.author)"
        cell.accessoryType = .DisclosureIndicator
        return cell
    }

    // MARK: Table view delegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        //self.performSegueWithIdentifier("MasterToDetail", sender: self)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        guard let detailViewNavigationController = splitViewController?.viewControllers.last as? UINavigationController else {
            // TODO: Fail gracefully
            return
        }
        if let detailViewController = detailViewNavigationController.viewControllers.first as? WebViewController {
            if helper.getDidReceivePushNotification() {
                NSNotificationCenter.defaultCenter().removeObserver(self)
                detailViewController.receivedFeedItem = FeedItem(title: "", link: helper.getRemoteNotificationURL(), date: "", author: "", content: "")
                helper.setDidReceivePushNotificationWithBool(false)
            } else if handoffActivated == true {
                if self.feeds.isEmpty {
                    detailViewController.receivedFeedItem = FeedItem(title: "Error", link: "", date: "", author: "", content: "<p align=\"center\">Woops! The Handoff feature of the app has encountered an error. No worries, just go back, refresh and reselect the page.</p>")
                    handoffActivated = false
                    handoffIndex = -1
                } else {
                    detailViewController.receivedFeedItem = self.feeds[handoffIndex]
                    handoffActivated = false
                    handoffIndex = -1
                }
            } else {
                if self.searchDisplayController?.active == true {
                    if let indexPath = self.searchDisplayController?.searchResultsTableView.indexPathForSelectedRow {
                        detailViewController.receivedFeedItem = self.searchResults[indexPath.row]
                    } else {
                        detailViewController.receivedFeedItem = FeedItem(title: "Error", link: "", date: "", author: "", content: "<p align=\"center\">Woops! The search feature of the app has encountered an error. No worries, just go back, refresh and reselect the page.</p>")
                    }
                } else {
                        detailViewController.receivedFeedItem = self.feeds[indexPath.row]
                        //(segue.destinationViewController as? WebViewController)?.receivedFeedItem = FeedItem(title: "", link: "http://studentsblog.sst.edu.sg/2015/10/student-travel-declaration-novdec-2015.html", date: "", author: "", content: "")
                }
            }
        } else {
            //TODO: Fail gracefully
        }
        collapseDetailViewController = false
    }

}

// MARK: - UISplitViewControllerDelegate

extension MasterViewController : UISplitViewControllerDelegate {

    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController: UIViewController, ontoPrimaryViewController primaryViewController: UIViewController) -> Bool {
        return collapseDetailViewController
    }

}

// MARK: - NSXMLParserDelegate

extension MasterViewController : NSXMLParserDelegate {
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        self.element = elementName
        if self.element == "item" { // If new item is retrieved, clear the temporary item object
            self.tempItem = FeedItem(title: "", link: "", date: "", author: "", content: "") //Reset tempItem
        }
    }

    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            self.newFeeds.append(self.tempItem)
        }
    }

    func parser(parser: NSXMLParser, foundCharacters string: String) {
            if self.element == "title" {
                self.tempItem.title += string
            } else if self.element == "link" {
                self.tempItem.link += string
            } else if self.element == "pubDate" {
                if let currentDate = self.fullDateFormatter.dateFromString(string) {
                    self.tempItem.date += longDateFormatter.stringFromDate(currentDate)
                }
            } else if self.element == "author" {
                self.tempItem.author += string.stringByReplacingOccurrencesOfString("noreply@blogger.com ", withString: "", options: .LiteralSearch, range: nil)
            } else if self.element == "description" {
                self.tempItem.content += string
            }
    }

    func parserDidEndDocument(parser: NSXMLParser) {
        self.synchroniseFeedArrayAndTable()

        UIApplication.sharedApplication().networkActivityIndicatorVisible = false

        // For UIRefreshControl
        self.refreshControl?.endRefreshing()

        // Archive and cache feeds into persistent storage (cool beans)
        self.feedHelper.setCachedFeeds(self.feeds)

        if helper.getDidReceivePushNotification() && self.navigationController?.viewControllers.count < 2 {
            self.performSegueWithIdentifier("MasterToDetail", sender: self)
        }

        if self.goForHandoff {
            if let handoffString = self.handoffTitle {
                self.initiateHandoffAction(handoffString)
                self.goForHandoff = false
            }
        }

        // Check for new app version once the app is finished
        helper.delay(1) {
            self.checkForNewVersion()
        }
    }

    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        ProgressHUD.showError("Error Parsing!")
    }
}

// MARK: - NSURLSession Delegates

extension MasterViewController : NSURLSessionDelegate, NSURLSessionDataDelegate {
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        expectedContentLength = Int(response.expectedContentLength)
        completionHandler(NSURLSessionResponseDisposition.Allow)
    }

    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        if let bufferUnwrapped = buffer {
            bufferUnwrapped.appendData(data)

            let percentDownload = (Float(bufferUnwrapped.length) / Float(expectedContentLength)) * 100
            if !progressCancelled {
                dispatch_async(dispatch_get_main_queue(), {
                    self.navigationController?.setSGProgressPercentage(percentDownload)
                })
            }
        }
    }

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if error == nil { // If no error
            if let data = buffer {
                dispatch_sync(dispatch_get_main_queue(), {
                    self.parser = NSXMLParser(data: data)
                    self.parser.delegate = self
                    self.parser.shouldResolveExternalEntities = false
                    self.parser.parse()
                })
            } else {
                buffer = NSMutableData()
                dispatch_sync(dispatch_get_main_queue(), {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    self.navigationController?.cancelSGProgress()
                    self.refreshControl?.endRefreshing()
                    ProgressHUD.showError("Error loading!")
                })
            }
        } else {
            // Clear buffer
            buffer = NSMutableData()
            print(error)
            dispatch_sync(dispatch_get_main_queue(), {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                self.navigationController?.cancelSGProgress()
                self.refreshControl?.endRefreshing()
                ProgressHUD.showError("Error loading!")
            })
        }
    }
}
