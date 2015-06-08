//
//  MasterTableViewController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 2/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//


import UIKit

class MasterViewController: UITableViewController, NSXMLParserDelegate, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UISearchDisplayDelegate {
    
    // MARK: - Private variables declaration
    
    private var parser : NSXMLParser
    private struct Item {
        var title : String
        var link : String
        var date : String
        var author : String
        var description :String
    }
    private var tempItem : Item
    private var feeds : [Item]
    private var element : String = ""
    private var searchResults : [Item]
    private let dateFormatter : NSDateFormatter
    private let searchController : UISearchController
    
    // MARK: - Lifecycle
    
    required init!(coder aDecoder: NSCoder!) {
        // Variables initialization
        parser = NSXMLParser()
        
        feeds = [Item]()
        tempItem = Item(title: "", link: "", date: "", author: "", description: "")
        searchResults = [Item]()
        
        dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm"
        
        searchController = UISearchController()
        
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
        
        getFeeds()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Private methods
    
    private func getFeeds() {
        struct TokenHolder {
            static var token: dispatch_once_t = 0;
        }
        
        dispatch_once(&TokenHolder.token) {
            // Getfeeds uses a proper Swift implementation of dispatch once
            MRProgressOverlayView.showOverlayAddedTo(self.tabBarController?.view, title: "Loading...", mode: .IndeterminateSmall, animated: true)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                self.feeds = [Item]() //Sort of like alloc init
                let url = NSURL(string: "http://feeds.feedburner.com/SSTBlog")
                let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
                    if error == nil {
                        //let dataString = String.dataUsingEncoding(data)
                        let dataString = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
                        self.parser = NSXMLParser(data: (dataString).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
                        self.parser.delegate = self
                        self.parser.shouldResolveExternalEntities = false
                        self.parser.parse()
                    } else {
                        dispatch_sync(dispatch_get_main_queue(), {
                            MRProgressOverlayView.showOverlayAddedTo(self.tabBarController?.view, title: "Error Loading!", mode: .Cross, animated: true)
                            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                        })
                    }
                }
                task.resume() // Start NSURLSession Connection
            })
        }
    }
    
    private func pushNotificationsReceived() {
        if self.navigationController!.viewControllers.count < 2 {
            self.performSegueWithIdentifier("MasterToDetail", sender: self)
        }
    }
    
    private func refresh(sender: UIRefreshControl) {
        self.tableView.userInteractionEnabled = false
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            self.tableView.reloadData()
            self.feeds = [Item]()
            let url = NSURL(string: "http://studentsblog.sst.edu.sg/feeds/posts/default?alt=rss")
            self.parser = NSXMLParser(contentsOfURL: url)!
            self.parser.delegate = self
            self.parser.shouldResolveExternalEntities = false
            let success = self.parser.parse()
            
            dispatch_sync(dispatch_get_main_queue(), {
                sender.endRefreshing()
                self.tableView.userInteractionEnabled = true
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            })
        })
    }
    
    // MARK: - Search functionality
    
    func filterContentForSearchText(searchText: String) {
        self.searchResults = self.feeds.filter({(post: Item) -> Bool in
            let stringMatch = post.title.rangeOfString(searchText)
            return stringMatch != nil
        })
    }
    
    func shouldReloadTableForSearchString(controller: UISearchDisplayController, searchString: String) -> (Bool) {
        self.filterContentForSearchText(searchString)
        return true
    }
    
    func searchDisplayController(controller: UISearchDisplayController, shouldReloadTableForSearchScope searchOption: Int) -> Bool {
        self.filterContentForSearchText(self.searchDisplayController!.searchBar.text)
        return true
    }
    
    // MARK: - NSXMLParser delegate
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [NSObject : AnyObject]) {
        self.element = elementName
        if self.element == "item" { // If new item is retrieved, clear the temporary item struct
            self.tempItem = Item(title: "", link: "", date: "", author: "", description: "") //Reset tempItem
        }
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            self.feeds.append(self.tempItem)
        }
    }
    
    func parser(parser: NSXMLParser, foundCharacters string: String?) {
        if var testString = string { // Unwrap string? to check if it really works
            // Get rid of pesky "&" (ampersand) issue
            testString = testString.stringByReplacingOccurrencesOfString("%", withString: "&", options: NSStringCompareOptions.LiteralSearch, range: nil)
            
            if self.element == "title" {
                self.tempItem.title = self.tempItem.title + testString
            } else if self.element == "link" {
                self.tempItem.link = self.tempItem.link + testString
            } else if self.element == "pubDate" {
                self.tempItem.date = dateFormatter.stringFromDate(self.dateFormatter.dateFromString(testString.stringByReplacingOccurrencesOfString(":00 +0000", withString: ""))!.dateByAddingTimeInterval(Double(NSTimeZone.systemTimeZone().secondsFromGMT))) //Depends on current difference in timestamp to calculate intellegiently what timezone it should apply to the posts
            } else if self.element == "author" {
                self.tempItem.author = testString.stringByReplacingOccurrencesOfString("noreply@blogger.com ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
            } else if self.element == "description" {
                self.tempItem.description = self.tempItem.description + testString
            }
        }
    }
    
    func parserDidEndDocument(parser: NSXMLParser) {
        dispatch_sync(dispatch_get_main_queue(), {
            self.tableView.reloadData()
            MRProgressOverlayView.dismissOverlayForView(self.tabBarController?.view, animated: true)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            
            let singleton : GlobalSingleton = GlobalSingleton.sharedInstance
            if singleton.getDidReceivePushNotification() && self.navigationController?.viewControllers.count < 2 {
                self.performSegueWithIdentifier("MasterToDetail", sender: self)
            }
        })
    }
    
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        dispatch_sync(dispatch_get_main_queue(), {
            MRProgressOverlayView.dismissOverlayForView(self.tabBarController?.view, animated: true)
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
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! UITableViewCell
        
        var cellItem : Item = Item(title: "", link: "", date: "", author: "", description: "")

        // Configure the cell...
        if tableView == self.searchDisplayController!.searchResultsTableView {
            cellItem = self.searchResults[indexPath.row]
            //cell.textLabel?.text = self.searchResults[indexPath.row].title
        } else {
            if !feeds.isEmpty {
                /*if self.feeds[indexPath.row].title == "" {
                    cell.textLabel?.text = "<No Title>"
                } else {
                    cell.textLabel?.text = self.feeds[indexPath.row].title
                }
                cell.detailTextLabel?.text = "\(self.feeds[indexPath.row].date) \(self.feeds[indexPath.row].author)"*/
                cellItem = self.feeds[indexPath.row]
            }
        }
        
        cell.textLabel!.text = cellItem.title
        cell.detailTextLabel!.text = "\(cellItem.date) \(cellItem.author)"

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
                        let passedString : String = "{\(self.searchResults[indexPath.row].title)}[\(self.searchResults[indexPath.row].link)]\(self.searchResults[indexPath.row].description)"
                        (segue.destinationViewController as! WebViewController).receivedUrl = passedString
                    } else {
                        (segue.destinationViewController as! WebViewController).receivedUrl = "error"
                    }
                } else {
                    if let indexPath = self.tableView.indexPathForSelectedRow() {
                        let passedString : String = "{\(self.feeds[indexPath.row].title)}[\(self.feeds[indexPath.row].link)]\(self.feeds[indexPath.row].description)"
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
