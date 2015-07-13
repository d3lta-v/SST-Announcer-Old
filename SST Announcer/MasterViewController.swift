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
    private let dateFormatter: NSDateFormatter
    private let helper = FeedHelper()
    private var handoffActivated = false
    private var handoffIndex = -1

    // MARK: NSURLSession Variables
    private var progress: Float = 0.0
    private var buffer: NSMutableData? = NSMutableData()
    private var expectedContentLength = 0

    // MARK: - Lifecycle

    required init!(coder aDecoder: NSCoder!) {
        // Variables initialization
        feeds = [FeedItem]()
        newFeeds = [FeedItem]()
        tempItem = FeedItem(title: "", link: "", date: "", author: "", content: "")
        searchResults = [FeedItem]()

        dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm"

        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Init refresh controls
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl = refreshControl

        if NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1 {
            self.tableView.estimatedRowHeight = 55
            self.tableView.rowHeight = UITableViewAutomaticDimension
        } else {
            // Manually set ALL the cell heights
            self.tableView.rowHeight = helper.getTableRowHeight(UIApplication.sharedApplication())
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        // Add observer for push to catch push notification messages
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "pushNotificationsReceived", name: "pushReceived", object: nil)

        getFeedsOnce()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        // Check for push notifications
        let singleton = GlobalSingleton.sharedInstance
        if singleton.getDidReceivePushNotification() == true {
            self.performSegueWithIdentifier("MasterToDetail", sender: self)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Private methods

    struct TokenHolder {
        static var token: dispatch_once_t = 0;
    }

    private func getFeedsOnce() {
        dispatch_once(&TokenHolder.token) {
            // Getfeeds uses a proper Swift implementation of dispatch once

            UIApplication.sharedApplication().networkActivityIndicatorVisible = true

            // Start the refresher
            self.refreshControl?.beginRefreshing()
            let pt = CGPointMake(0, self.tableView.contentOffset.y - (self.refreshControl?.frame.size.height)!)
            self.tableView.setContentOffset(pt, animated: false)

            // Load cached version first, while checking for existence of the cached feeds
            if let feeds = self.helper.getCachedFeeds() {
                self.feeds = feeds
                self.tableView.reloadData()
            }

            // Then load the web version on a seperate thread
            self.loadFromReliableServer()

            // Check if user enabled push, after a 5 second delay
            #if !((arch(i386) || arch(x86_64)) && os(iOS)) // Preprocessor macro for checking iOS sims
            self.delay(5) {
                let application = UIApplication.sharedApplication()
                if application.respondsToSelector("isRegisteredForRemoteNotifications") { // iOS 8 feature
                    if application.isRegisteredForRemoteNotifications() == false {
                        let alert = UIAlertController(title: "You disabled push!",message: "This app relies heavily on push notifications for time-specific delivery of feeds.", preferredStyle: .Alert)
                        let okay = UIAlertAction(title: "Okay", style: UIAlertActionStyle.Cancel, handler: nil)
                        alert.addAction(okay)
                        self.presentViewController(alert, animated: true, completion: nil)
                    }
                } else {
                    let types = application.enabledRemoteNotificationTypes()
                    if types == UIRemoteNotificationType.None {
                        let alert = UIAlertView(title:"You disabled push!",message:"This app relies on push notifications for time-specific delivery of feeds.",delegate: nil,cancelButtonTitle:"Okay")
                        alert.show()
                    }
                }
            }
            #endif
        }
    }

    private func loadFeedWithURLString(urlString: String!){
        self.newFeeds = [FeedItem]() //Sort of like alloc init, it clears the array
        let url = NSURL(string: urlString)

        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.HTTPAdditionalHeaders = ["Accept-Encoding":""]
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
        let dataTask = session.dataTaskWithRequest(NSURLRequest(URL: url!))
        self.navigationController?.setProgress(0, animated: false) // force set progress to zero to avoid weird UI
        // Show progress
        self.navigationController?.showProgress()
        self.navigationController?.setProgress(0.05, animated: true)
        dataTask.resume()
        session.finishTasksAndInvalidate()
    }

    func pushNotificationsReceived() {
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
            self.loadFromReliableServer()
        })
    }

    private func chooseServerForReliability() -> (urlString: String, serverError: Bool) {
        let testUrl = NSURL(string: "https://simux.org/api/check.json")
        var errorPgm = false
        var useFallback = false
        let test = NSURLSession.sharedSession().dataTaskWithURL(testUrl!){(data, response, error) in
            if error == nil {
                if let rsp = response as? NSHTTPURLResponse {
                    if rsp.statusCode != 200 { // Use fallback here
                        useFallback = true
                    } else {
                        useFallback = false
                    }
                } else {
                    errorPgm = true
                }
            } else {
                useFallback = true
            }
        }

        if useFallback {
            return ("https://api.statixind.net/cache/blogrss.xml", errorPgm)
        } else {
            return ("https://simux.org/api/cache/blogrss.xml", errorPgm)
        }
    }

    private func loadFromReliableServer() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            let server = self.chooseServerForReliability()
            if server.serverError {
                dispatch_sync(dispatch_get_main_queue(), {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    ProgressHUD.showError("Error Parsing!")
                })
            } else {
                self.loadFeedWithURLString(server.urlString)
            }
        })
    }

    private func delay(delay: Double, closure:()->()) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay * Double(NSEC_PER_SEC))
            ),
            dispatch_get_main_queue(), closure)
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.

        if segue.identifier == "MasterToDetail" {
            let singleton: GlobalSingleton = GlobalSingleton.sharedInstance
            if singleton.getDidReceivePushNotification() {
                NSNotificationCenter.defaultCenter().removeObserver(self)
                (segue.destinationViewController as? WebViewController)?.receivedFeedItem = FeedItem(title: "", link: singleton.getRemoteNotificationURL(), date: "", author: "", content: "")
                singleton.setDidReceivePushNotificationWithBool(false)
            } else if handoffActivated == true {
                if self.feeds.isEmpty {
                    (segue.destinationViewController as? WebViewController)?.receivedFeedItem = FeedItem(title: "Error", link: "", date: "", author: "", content: "")
                    handoffActivated = false
                    handoffIndex = -1
                } else {
                    (segue.destinationViewController as? WebViewController)?.receivedFeedItem = self.feeds[handoffIndex]
                    handoffActivated = false
                    handoffIndex = -1
                }
            } else {
                if self.searchDisplayController?.active == true {
                    if let indexPath = self.searchDisplayController?.searchResultsTableView.indexPathForSelectedRow() {
                        (segue.destinationViewController as? WebViewController)?.receivedFeedItem = self.searchResults[indexPath.row]
                    } else {
                        (segue.destinationViewController as? WebViewController)?.receivedFeedItem = FeedItem(title: "Error", link: "", date: "", author: "", content: "")
                    }
                } else {
                    if let indexPath = self.tableView.indexPathForSelectedRow() {
                        (segue.destinationViewController as? WebViewController)?.receivedFeedItem = self.feeds[indexPath.row]
                    } else {
                        (segue.destinationViewController as? WebViewController)?.receivedFeedItem = FeedItem(title: "Error", link: "", date: "", author: "", content: "")
                    }
                }
            }
        }
    }

    // MARK: - Handoff

    override func restoreUserActivityState(activity: NSUserActivity) {
        if let titleString = activity.userInfo?["title"] as? String {
            println(titleString)
            if feeds.count <= 5 {
                delay(0.1) {
                    self.initiateHandoffAction(titleString)
                }
            } else {
                self.initiateHandoffAction(titleString)
            }
        }
    }

    func initiateHandoffAction(titleString: String) {
        for var i = 0; i < feeds.count; i++ {
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

    func searchDisplayController(controller: UISearchDisplayController, shouldReloadTableForSearchString searchString: String!) -> Bool {
        self.filterContentForSearchText(searchString)
        return true
    }
}

// MARK: - UITableView Delegates

extension MasterViewController : UITableViewDelegate, UITableViewDataSource {
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
        let cell = self.tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as? UITableViewCell

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

        if let cellUnwrapped = cell {
            cellUnwrapped.textLabel?.text = cellItem.title
            cellUnwrapped.detailTextLabel?.text = "\(cellItem.date) \(cellItem.author)"
            cellUnwrapped.accessoryType = .DisclosureIndicator
            return cellUnwrapped
        } else {
            cell!.textLabel?.text = cellItem.title
            cell!.detailTextLabel?.text = "\(cellItem.date) \(cellItem.author)"
            return cell!
        }
    }

    // MARK: Table view delegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier("MasterToDetail", sender: self)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}

// MARK: - NSXMLParserDelegate

extension MasterViewController : NSXMLParserDelegate {
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [NSObject : AnyObject]) {
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

    func parser(parser: NSXMLParser, foundCharacters string: String?) {
        if var testString = string { // Unwrap string? to check if it is safe
            if self.element == "title" {
                self.tempItem.title = self.tempItem.title + testString
            } else if self.element == "link" {
                self.tempItem.link = self.tempItem.link + testString
            } else if self.element == "pubDate" {
                let currentDate = self.dateFormatter.dateFromString(testString.stringByReplacingOccurrencesOfString(":00 +0000", withString: ""))!
                let newDate = currentDate.dateByAddingTimeInterval(Double(NSTimeZone.systemTimeZone().secondsFromGMT))
                self.tempItem.date = dateFormatter.stringFromDate(newDate) //Depends on current difference in timestamp to calculate intellegiently what timezone it should apply to the posts
            } else if self.element == "author" {
                self.tempItem.author = testString.stringByReplacingOccurrencesOfString("noreply@blogger.com ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
            } else if self.element == "description" {
                self.tempItem.content = self.tempItem.content + testString
            }
        }
    }

    func parserDidEndDocument(parser: NSXMLParser) {
        self.synchroniseFeedArrayAndTable()

        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        self.navigationController?.finishProgress()

        // For UIRefreshControl
        self.refreshControl?.endRefreshing()

        // Archive and cache feeds into persistent storage (cool beans)
        self.helper.setCachedFeeds(self.feeds)

        let singleton: GlobalSingleton = GlobalSingleton.sharedInstance
        if singleton.getDidReceivePushNotification() && self.navigationController?.viewControllers.count < 2 {
            self.performSegueWithIdentifier("MasterToDetail", sender: self)
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

            let percentDownload = Float(bufferUnwrapped.length) / Float(expectedContentLength)
            self.navigationController?.setProgress(CGFloat(percentDownload), animated: true)
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
                    self.navigationController?.finishProgress()
                    self.refreshControl?.endRefreshing()
                    ProgressHUD.showError("Error loading!")
                })
            }
        } else {
            // Clear buffer
            buffer = NSMutableData()
            println(error)
            dispatch_sync(dispatch_get_main_queue(), {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                self.navigationController?.finishProgress()
                self.refreshControl?.endRefreshing()
                ProgressHUD.showError("Error loading!")
            })
        }
    }
}
