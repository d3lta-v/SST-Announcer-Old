//
//  CategoriesViewController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 16/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

class CategoriesViewController: UITableViewController {

    // MARK: - Private variables declaration

    // MARK: Basic structure
    private var parser: NSXMLParser!
    private var tempItem: FeedItem
    private var feeds: [FeedItem]
    private var newFeeds: [FeedItem] // NewFeeds is actually to "cache" a copy of the new feeds, and sync it to the old feeds
    private var element = ""
    private var searchResults: [FeedItem]
    private var progressCancelled = false
    private let helper = GlobalSingleton.sharedInstance

    // MARK: NSURLSession Variables
    private var progress: Float = 0.0
    private var buffer: NSMutableData? = NSMutableData()
    private var expectedContentLength = 0

    // MARK: - Lifecycle

    required init!(coder aDecoder: NSCoder) {
        // Variables initialization
        feeds = [FeedItem]()
        newFeeds = [FeedItem]()
        tempItem = FeedItem(title: "", link: "", date: "", author: "", content: "")
        searchResults = [FeedItem]()

        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Init refresh controls
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "refresh:", forControlEvents: .ValueChanged)
        self.refreshControl = refreshControl

        if NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1 {
            self.tableView.estimatedRowHeight = 44
            self.tableView.rowHeight = UITableViewAutomaticDimension
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        progressCancelled = false
        getFeedsOnce()
    }

    override func viewWillDisappear(animated: Bool) {
        progressCancelled = true
        self.navigationController?.cancelSGProgress()

        super.viewWillDisappear(animated)
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
            let userDefaults = NSUserDefaults.standardUserDefaults()
            if let feedsObject = userDefaults.objectForKey("cachedCategories") as? NSData {
                NSKeyedUnarchiver.setClass(FeedItem.self, forClassName: "FeedItem")
                if let feeds = NSKeyedUnarchiver.unarchiveObjectWithData(feedsObject) as? [FeedItem] {
                    self.feeds = feeds
                    self.tableView.reloadData()
                }
            }

            // Then load the web version on a seperate thread
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                self.loadFeedWithURLString("https://node1.sstinc.org/api/cache/categories.csv")
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
        dataTask.resume()
        session.finishTasksAndInvalidate()
    }

    private func synchroniseFeedArrayAndTable() {
        self.newFeeds.sortInPlace({$0.title.localizedCaseInsensitiveCompare($1.title) == NSComparisonResult.OrderedAscending})
        self.feeds = self.newFeeds
        self.tableView.reloadData()
    }

    internal func refresh(sender: UIRefreshControl) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        buffer = NSMutableData()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            self.loadFeedWithURLString("https://node1.sstinc.org/api/cache/categories.csv")
        })
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
        if let indexPath = self.tableView.indexPathForSelectedRow {
            let modString = (self.feeds[indexPath.row].title).stringByReplacingOccurrencesOfString(" ", withString: "%20").stringByReplacingOccurrencesOfString(";", withString: "%3B")
            (segue.destinationViewController as? CategoryViewController)?.inputURL = "http://studentsblog.sst.edu.sg/feeds/posts/default/-/\(modString)?alt=rss"
            (segue.destinationViewController as? CategoryViewController)?.title = self.feeds[indexPath.row].title
        }
    }

}

// MARK: - UISearch Delegates

extension CategoriesViewController : UISearchControllerDelegate, UISearchDisplayDelegate {
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

// MARK: - Table view Delegates

extension CategoriesViewController {
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
                    cellItem.title = "<No Name>"
                }
            }
        }

        cell.textLabel?.text = cellItem.title
        cell.accessoryType = .DisclosureIndicator
        return cell
    }

    // MARK: Table view delegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier("CategoryToDetail", sender: self)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}

// MARK: - NSXMLParser Delegate

extension CategoriesViewController : NSXMLParserDelegate {
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        self.element = elementName
        if self.element == "category" { // If new item is retrieved, clear the temporary item object
            self.tempItem = FeedItem(title: "", link: "", date: "", author: "", content: "") //Reset tempItem
        }
    }

    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "category" {
            self.newFeeds.append(self.tempItem)
        }
    }

    func parser(parser: NSXMLParser, foundCharacters string: String) {
        if self.element == "category" {
            self.tempItem.title = self.tempItem.title + string
        }
    }

    func parserDidEndDocument(parser: NSXMLParser) {
        self.synchroniseFeedArrayAndTable()

        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        //self.navigationController?.finishProgress()
        self.refreshControl?.endRefreshing()

        // Archive and cache feeds into persistent storage (cool beans)
        NSKeyedArchiver.setClassName("FeedItem", forClass: FeedItem.self)
        let cachedData = NSKeyedArchiver.archivedDataWithRootObject(self.feeds)
        NSUserDefaults.standardUserDefaults().setObject(cachedData, forKey: "cachedCategories")

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

// MARK: - NSURLSession Delegate

extension CategoriesViewController : NSURLSessionDelegate, NSURLSessionDataDelegate {
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
