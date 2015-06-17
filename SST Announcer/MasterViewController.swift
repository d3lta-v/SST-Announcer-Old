//
//  MasterTableViewController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 2/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//


import UIKit

class MasterViewController: UITableViewController, NSXMLParserDelegate, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UISearchDisplayDelegate, NSURLSessionDelegate, NSURLSessionDataDelegate {
    
    // MARK: - Private variables declaration
    
    // MARK: Basic structure
    private var parser : NSXMLParser
    private var tempItem : FeedItem
    private var feeds : [FeedItem]
    private var newFeeds : [FeedItem] // NewFeeds is actually to "cache" a copy of the new feeds, and synchronise it to the old feeds
    private var element : String = ""
    private var searchResults : [FeedItem]
    private let dateFormatter : NSDateFormatter
    
    // MARK: NSURLSession Variables
    private var progress : Float = 0.0
    private var buffer : NSMutableData = NSMutableData()
    private var expectedContentLength = 0
    
    // MARK: - Lifecycle
    
    required init!(coder aDecoder: NSCoder!) {
        // Variables initialization
        parser = NSXMLParser()
        
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
        let refreshControl : UIRefreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl = refreshControl
    }
    
    override func viewWillAppear(animated: Bool) {
        // Add observer for push to catch push notification messages
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "pushNotificationsReceived", name: "pushReceived", object: nil)
        
        getFeedsOnce()
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.navigationController?.cancelProgress()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Private methods
    
    private func getFeedsOnce() {
        struct TokenHolder {
            static var token: dispatch_once_t = 0;
        }
        
        dispatch_once(&TokenHolder.token) {
            // Getfeeds uses a proper Swift implementation of dispatch once
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            
            // Start the refresher
            self.delay(0.05) {
                self.refreshControl?.beginRefreshing()
                self.tableView.setContentOffset(CGPointMake(0, self.tableView.contentOffset.y - (self.refreshControl?.frame.size.height)!), animated: true)
            }
            
            // Load cached version first, while checking for existence of the cached feeds
            let userDefaults = NSUserDefaults.standardUserDefaults()
            if let feedsObject : AnyObject = userDefaults.objectForKey("cachedFeeds") {
                self.feeds = NSKeyedUnarchiver.unarchiveObjectWithData(feedsObject as! NSData) as! [FeedItem]
                self.tableView.reloadData()
            }
            
            // Then load the web version on a seperate thread
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                //self.loadFeedWithURLString("http://feeds.feedburner.com/SSTBlog")
                //self.loadFeedWithURLString("https://api.statixind.net/cache/blogrss.xml")
                self.loadFeedWithURLString("https://simux.org/api/cache/blogrss.xml")
            })
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
        self.navigationController?.showProgress()
        self.navigationController?.setProgress(0.05, animated: true)
        dataTask.resume()
        session.finishTasksAndInvalidate()
    }
    
    private func pushNotificationsReceived() {
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
            //self.loadFeedWithURLString("https://api.statixind.net/cache/blogrss.xml")
            self.loadFeedWithURLString("https://simux.org/api/cache/blogrss.xml")
        })
    }
    
    private func delay(delay:Double, closure:()->()) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay * Double(NSEC_PER_SEC))
            ),
            dispatch_get_main_queue(), closure)
    }
    
    // MARK: - NSURLSession delegates
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        expectedContentLength = Int(response.expectedContentLength)
        completionHandler(NSURLSessionResponseDisposition.Allow)
    }
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        buffer.appendData(data)
        
        let percentDownload = Float(buffer.length) / Float(expectedContentLength)
        self.navigationController?.setProgress(CGFloat(percentDownload), animated: true)
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if error == nil { // If no error
            let dataString = NSString(data: buffer, encoding: NSUTF8StringEncoding) as! String
            self.parser = NSXMLParser(data: (dataString).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
            self.parser.delegate = self
            self.parser.shouldResolveExternalEntities = false
            self.parser.parse()
        } else {
            // Clear buffer
            buffer = NSMutableData()
            println(error)
            self.navigationController?.finishProgress()
            self.refreshControl?.endRefreshing()
            MRProgressOverlayView.showOverlayAddedTo(self.tabBarController?.view, title: "Error loading!", mode: MRProgressOverlayViewMode.Cross, animated: true)
        }
    }
    
    // MARK: - Search functionality
    
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
    
    // MARK: - NSXMLParser delegate
    
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
        if var testString = string { // Unwrap string? to check if it really works
            if self.element == "title" {
                self.tempItem.title = self.tempItem.title + testString
            } else if self.element == "link" {
                self.tempItem.link = self.tempItem.link + testString
            } else if self.element == "pubDate" {
                self.tempItem.date = dateFormatter.stringFromDate(self.dateFormatter.dateFromString(testString.stringByReplacingOccurrencesOfString(":00 +0000", withString: ""))!.dateByAddingTimeInterval(Double(NSTimeZone.systemTimeZone().secondsFromGMT))) //Depends on current difference in timestamp to calculate intellegiently what timezone it should apply to the posts
            } else if self.element == "author" {
                self.tempItem.author = testString.stringByReplacingOccurrencesOfString("noreply@blogger.com ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
            } else if self.element == "description" {
                self.tempItem.content = self.tempItem.content + testString
            }
        }
    }
    
    func parserDidEndDocument(parser: NSXMLParser) {
        dispatch_sync(dispatch_get_main_queue(), {
            self.synchroniseFeedArrayAndTable()
            
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            self.navigationController?.finishProgress()
            
            // For UIRefreshControl
            self.refreshControl?.endRefreshing()
            
            // Archive and cache feeds into persistent storage (cool beans)
            let cachedData = NSKeyedArchiver.archivedDataWithRootObject(self.feeds)
            NSUserDefaults.standardUserDefaults().setObject(cachedData, forKey: "cachedFeeds")
            
            let singleton : GlobalSingleton = GlobalSingleton.sharedInstance
            if singleton.getDidReceivePushNotification() && self.navigationController?.viewControllers.count < 2 {
                self.performSegueWithIdentifier("MasterToDetail", sender: self)
            }
        })
    }
    
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        dispatch_sync(dispatch_get_main_queue(), {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            MRProgressOverlayView.showOverlayAddedTo(self.tabBarController?.view, title: "Error Loading!", mode: .Cross, animated: true)
        })
    }

    // MARK: - Table view data source

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
        let cell = self.tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! UITableViewCell
        
        var cellItem : FeedItem = FeedItem(title: "", link: "", date: "", author: "", content: "")

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
        
        cell.textLabel!.text = cellItem.title
        cell.detailTextLabel!.text = "\(cellItem.date) \(cellItem.author)"
        
        cell.accessoryType = .DisclosureIndicator

        return cell
    }
    
    // MARK: - Table view delegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier("MasterToDetail", sender: self)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 50 // Constant 50pts height for row
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
        
        if segue.identifier == "MasterToDetail" {
            let singleton : GlobalSingleton = GlobalSingleton.sharedInstance
            if singleton.getDidReceivePushNotification() {
                (segue.destinationViewController as! WebViewController).receivedUrl = singleton.getRemoteNotificationURL()
                singleton.setDidReceivePushNotificationWithBool(false)
            } else {
                if (self.searchDisplayController?.active == true) {
                    if let indexPath = self.searchDisplayController?.searchResultsTableView.indexPathForSelectedRow() {
                        let passedString : String = "{\(self.searchResults[indexPath.row].title)}[\(self.searchResults[indexPath.row].link)]\(self.searchResults[indexPath.row].content)"
                        (segue.destinationViewController as! WebViewController).receivedUrl = passedString
                    } else {
                        (segue.destinationViewController as! WebViewController).receivedUrl = "error"
                    }
                } else {
                    if let indexPath = self.tableView.indexPathForSelectedRow() {
                        let passedString : String = "{\(self.feeds[indexPath.row].title)}[\(self.feeds[indexPath.row].link)]\(self.feeds[indexPath.row].content)"
                        //let passedString = "http://studentsblog.sst.edu.sg/2015/05/info-hub-closed-for-open-house-rehearsal.html"
                        (segue.destinationViewController as! WebViewController).receivedUrl = passedString
                    } else {
                        (segue.destinationViewController as! WebViewController).receivedUrl = "error"
                    }
                }
            }
        }
    }
}
