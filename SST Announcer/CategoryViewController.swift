//
//  CategoryViewController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 16/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

class CategoryViewController: UITableViewController {

    // MARK: - Private variables declaration

    // MARK: Basic structure
    private var parser: NSXMLParser!
    private var tempItem: FeedItem
    private var feeds: [FeedItem]
    private var newFeeds: [FeedItem] // NewFeeds is actually to "cache" a copy of the new feeds, and synchronise it to the old feeds
    private var element: String = ""
    private var searchResults: [FeedItem]
    private let dateFormatter: NSDateFormatter
    private let helper = FeedHelper.sharedInstance

    // MARK: NSURLSession Variables
    private var progress: Float = 0.0
    private var buffer: NSMutableData? = NSMutableData()
    private var expectedContentLength = 0

    // MARK: New variable: the URL variable for inputting a URL from previous view controller
    var inputURL: String?

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

        // UIBar Back button settings
        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffsetZero, forBarMetrics: UIBarMetrics.Default)

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

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        UIApplication.sharedApplication().networkActivityIndicatorVisible = true

        self.navigationController?.showProgress()
        self.navigationController?.setIndeterminate(true)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            if let url = self.inputURL {
                self.loadFeedWithURLString(url)
            }
        })
    }

    override func viewWillDisappear(animated: Bool) {
        if self.navigationController?.isShowingProgressBar() == true {
            self.navigationController?.setIndeterminate(false)
            self.navigationController?.cancelProgress()
        }
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Private methods

    private func loadFeedWithURLString(urlString: String!){
        self.newFeeds = [FeedItem]() //Sort of like alloc init, it clears the array
        let url = NSURL(string: urlString)

        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.HTTPAdditionalHeaders = ["Accept-Encoding":""]
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
        let dataTask = session.dataTaskWithRequest(NSURLRequest(URL: url!))
        self.navigationController?.showProgress()
        dataTask.resume()
        session.finishTasksAndInvalidate()
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
            if let url = self.inputURL {
                self.loadFeedWithURLString(url)
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

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.

        if segue.identifier == "MasterToDetail" {
            if self.searchDisplayController?.active == true {
                let indexPath = self.searchDisplayController?.searchResultsTableView.indexPathForSelectedRow()
                if let indexPth = indexPath {
                    (segue.destinationViewController as? WebViewController)?.receivedFeedItem = searchResults[indexPth.row]
                } else {
                    (segue.destinationViewController as? WebViewController)?.receivedFeedItem = FeedItem(title: "Error", link: "", date: "", author: "", content: "")
                }
            } else {
                if let indexPath = self.tableView.indexPathForSelectedRow() {
                    (segue.destinationViewController as? WebViewController)?.receivedFeedItem = feeds[indexPath.row]
                } else {
                    (segue.destinationViewController as? WebViewController)?.receivedFeedItem = FeedItem(title: "Error", link: "", date: "", author: "", content: "")
                }
            }
        }
    }
}

// MARK: - UISearch Delegates

extension CategoryViewController : UISearchBarDelegate, UISearchControllerDelegate {
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

extension CategoryViewController : UITableViewDelegate, UITableViewDataSource {
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

        var cellItem = FeedItem(title: "", link: "", date: "", author: "", content: "")

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

// MARK: - NSXMLParser Delegate Methods

extension CategoryViewController : NSXMLParserDelegate {
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
        self.navigationController?.setIndeterminate(false)
        self.navigationController?.cancelProgress()

        // For UIRefreshControl
        self.refreshControl?.endRefreshing()
    }

    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }
}

// MARK: - NSURLSession Delegates

extension CategoryViewController : NSURLSessionDelegate, NSURLSessionDataDelegate {
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        expectedContentLength = Int(response.expectedContentLength)
        completionHandler(NSURLSessionResponseDisposition.Allow)
    }

    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        if let buffer = self.buffer {
            buffer.appendData(data)
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
                self.navigationController?.setIndeterminate(false)
                self.refreshControl?.endRefreshing()
                ProgressHUD.showError("Error loading!")
            })
        }
    }
}
