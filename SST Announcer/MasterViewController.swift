//
//  MasterTableViewController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 2/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//


import UIKit

class MasterViewController: UITableViewController, NSXMLParserDelegate, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UISearchDisplayDelegate {
    
    // Variables Declaration
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
    
    required init!(coder aDecoder: NSCoder!) {
        // Variables initialization
        parser = NSXMLParser()
        
        feeds = [Item]()
        tempItem = Item(title: "", link: "", date: "", author: "", description: "")
        //item = Dictionary<String, String>()
        searchResults = [Item]()
        
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
        
        // Feed parsing contained inside a dispatch_once
        var token : dispatch_once_t = 0
        dispatch_once(&token, {
            MRProgressOverlayView.showOverlayAddedTo(self.tabBarController?.view, title: "Loading...", mode: .IndeterminateSmall, animated: true)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                self.feeds = [Item]() //Sort of like alloc init
                let url = NSURL(string: "http://feeds.feedburner.com/SSTBlog")
                self.parser = NSXMLParser(contentsOfURL: url)!
                self.parser.delegate = self
                self.parser.shouldResolveExternalEntities = false
                let success = self.parser.parse()
                if !success {
                    dispatch_sync(dispatch_get_main_queue(), {
                        MRProgressOverlayView.showOverlayAddedTo(self.tabBarController?.view, title: "Error Loading!", mode: .Cross, animated: true)
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    })
                }
            })
        })
    }
    
    func pushNotificationsReceived() {
        if self.navigationController!.viewControllers.count < 2 {
            self.performSegueWithIdentifier("MasterToDetail", sender: self)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
            println(self.tempItem) // TODO: remove this line of debug code
            self.feeds.append(self.tempItem)
        }
    }
    
    func parser(parser: NSXMLParser, foundCharacters string: String?) {
        if let testString = string { // Unwrap string? to check if it really works
            if self.element == "title" {
                self.tempItem.title = testString
            } else if self.element == "link" {
                self.tempItem.link = testString
            } else if self.element == "pubDate" {
                let newDate = self.dateFormatter.dateFromString(testString.stringByReplacingOccurrencesOfString(":00 +0000", withString: ""))!.dateByAddingTimeInterval(8*60*60) // 8 hours
                self.tempItem.date = dateFormatter.stringFromDate(newDate)
            } else if self.element == "author" {
                self.tempItem.author = testString.stringByReplacingOccurrencesOfString("noreply@blogger.com ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
            } else if self.element == "description" {
                self.tempItem.description = testString
            }
        }
    }
    
    func parserDidEndDocument(parser: NSXMLParser) {
        dispatch_sync(dispatch_get_main_queue(), {
            self.tableView.reloadData()
            MRProgressOverlayView.dismissOverlayForView(self.tabBarController?.view, animated: true)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            
            let singleton : GlobalSingleton = GlobalSingleton.sharedInstance
            if singleton.didReceivePushNotification && self.navigationController?.viewControllers.count < 2 {
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
        // #warning Potentially incomplete method implementation.
        // Return the number of sections.
        return 0
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete method implementation.
        // Return the number of rows in the section.
        return 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as! UITableViewCell

        // Configure the cell...

        return cell
    }
    
    // MARK: - VC Specific Functions
    func refresh(sender: UIRefreshControl) {
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
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }

}
