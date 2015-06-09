//
//  WebViewController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 4/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

class WebViewController: UIViewController, DTAttributedTextContentViewDelegate, DTLazyImageViewDelegate, UIWebViewDelegate, WebViewProgressDelegate , DTWebVideoViewDelegate{
    
    // MARK: - Variables declaration
    var receivedUrl : String = String()
    @IBOutlet weak var exportBarButton: UIBarButtonItem!
    @IBOutlet var webView: UIWebView!
    @IBOutlet var textView: DTAttributedTextView!
    private var progressView : WebViewProgressView!
    private var progressProxy : WebViewProgress!
    
    // MARK: - Lifecycle
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // Init web view loading bar
        progressProxy = WebViewProgress()
        webView.delegate = progressProxy
        progressProxy.webViewProxyDelegate = self
        progressProxy.progressDelegate = self
        
        let progressBarHeight: CGFloat = 2.0
        let navigationBarBounds = self.navigationController!.navigationBar.bounds
        let barFrame = CGRect(x: 0, y: navigationBarBounds.size.height - progressBarHeight, width: navigationBarBounds.width, height: progressBarHeight)
        progressView = WebViewProgressView(frame: barFrame)
        progressView.autoresizingMask = .FlexibleWidth | .FlexibleTopMargin
        
        loadFeed(self.receivedUrl)
    }
    
    override func viewWillAppear(animated: Bool) {
        self.navigationController!.navigationBar.addSubview(progressView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Private functions
    
    private func loadFeed(url: String!) {
        // NOTE: URL is not actually an URL, and only under some circumstances (i.e. retrieving from push notification) it IS an URL
        
        var htmlString = ""
        
        if url == "error" {
            self.title = "Error"
            htmlString = "<p align=\"center\">Woops! The app has encountered an error. No worries, just go back and reselect the page.</p>"
        } else if url.hasPrefix("h") { //First letter of http, to reduce memory usage
            MRProgressOverlayView.showOverlayAddedTo(self.tabBarController?.view, title: "Loading...", mode: .IndeterminateSmall, animated: true)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            
            delay(0.2) {
                let simuxCRParser = SIMUXCRParser()
                let crOptimised = simuxCRParser.convertHTML(url)
                let title = crOptimised.title
                var description = crOptimised.description
                
                if description.isEmpty {
                    description = "<p align=\"center\">There was a problem loading this article, please check your Internet connection, or try opening the URL in Safari via the share button above.</p>"
                    self.title = "Error"
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                } else {
                    description = description.stringByReplacingOccurrencesOfString("<div><br></div>", withString: "<div></div>", options: NSStringCompareOptions.LiteralSearch, range: nil)
                }
                
                self.title = title
                htmlString = description
            }
        } else {
            var title : String = ""
            var actualUrl : String = ""
            var description : String = ""
            
            // Get title range
            if let index1 = self.receivedUrl.rangeOfString("{")?.endIndex, index2 = self.receivedUrl.rangeOfString("}")?.startIndex {
                let range = Range(start: index1, end: index2)
                title = self.receivedUrl.substringWithRange(range)
            }
            
            // Get link
            /*if let index1 = self.receivedUrl.rangeOfString("[")?.endIndex, index2 = self.receivedUrl.rangeOfString("]")?.startIndex {
                let range = Range(start: index1, end: index2)
                
                actualUrl = self.receivedUrl.substringWithRange(range)
            }*/
            
            // Get description
            if let startDescriptionIndex = self.receivedUrl.rangeOfString("]")?.endIndex {
                description = self.receivedUrl.substringFromIndex(startDescriptionIndex)
                // String replacing, this is going to get messy, thank god for OOP
                description = cleanHtml(description)
            } else {
                title = "error"
                description = "<p align=\"center\">Woops! The app has encountered an error. No worries, just go back and reselect the page.</p>"
            }
            
            // Putting the variables into action
            self.title = title
            htmlString = description
        }
        
        // Check for iframes before calling the builder, for better performance
        if htmlString.rangeOfString("<iframe") != nil {
            if url.hasPrefix("h") {
                useBrowser(url, usedTable: false)
            } else {
                if let index1 = url.rangeOfString("[")?.endIndex, index2 = url.rangeOfString("]")?.startIndex {
                    let range = Range(start: index1, end: index2)
                    useBrowser(url.substringWithRange(range), usedTable: false)
                }
            }
        } else if htmlString.rangeOfString("<table") != nil {
            if url.hasPrefix("h") {
                useBrowser(url, usedTable: true)
            } else {
                if let index1 = url.rangeOfString("[")?.endIndex, index2 = url.rangeOfString("]")?.startIndex {
                    let range = Range(start: index1, end: index2)
                    useBrowser(url.substringWithRange(range), usedTable: true)
                }
            }
        } else {
            initAttributedTextViewWithString(htmlString)
        }
    }
    
    private func initAttributedTextViewWithString(string: String!) {
        let builderOptions = [
            DTDefaultFontFamily: "Helvetica Neue",
            DTDefaultFontSize: "16.4px",
            DTDefaultLineHeightMultiplier: "1.43",
            DTDefaultLinkColor: "#146FDF",
            DTDefaultLinkDecoration: ""
        ]
        let stringBuilder : DTHTMLAttributedStringBuilder = DTHTMLAttributedStringBuilder(HTML: string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false), options: builderOptions, documentAttributes: nil)
        self.textView.textDelegate = self
        self.textView.shouldDrawImages = true
        self.textView.attributedString = stringBuilder.generatedAttributedString()
        self.textView.contentInset = UIEdgeInsetsMake(85, 15, 40, 15)
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        MRProgressOverlayView.dismissOverlayForView(self.tabBarController?.view, animated: true)
    }
    
    private func useBrowser(url: String!, usedTable: Bool!) {
        textView.alpha = 0
        if usedTable == true {
            webView.loadRequest(NSURLRequest(URL: NSURL(string: url)!))
        } else {
            webView.loadRequest(NSURLRequest(URL: NSURL(string: url+"?m=0")!))
        }
    }
    
    private func cleanHtml(html: String!) -> String! {
        var htmlVariable : String = html
        
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<div><br></div>", withString: "<div></div>")
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<br \\>", withString: "<div></div>")
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<div[^>]*>", withString: "<div>", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<span[^>]*>", withString: "<span>", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<b[r][^>]*/>", withString: "<br \\>", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("width=[^ ]*", withString: "", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("height=[^ ]*", withString: "", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<img src=\"//[^>]*>", withString: "", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<!--(.*?)-->", withString: "", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<div><br ></div>", withString: "<br>", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<b>", withString: "")
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("</b>", withString: "")
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<br><div>", withString: "<div>")
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<span><br ></span>", withString: "")
        
        return htmlVariable
    }
    
    private func delay(delay:Double, closure:()->()) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay * Double(NSEC_PER_SEC))
            ),
            dispatch_get_main_queue(), closure)
    }
    
    // MARK: - UIWebViewDelegate Methods
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        if error.code != -999 {
            MRProgressOverlayView.showOverlayAddedTo(self.tabBarController?.view, title: "Loading failed!", mode: .Cross, animated: true)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }
    
    // MARK: - WebViewProgressDelegate Methods
    
    func webViewProgress(webViewProgress: WebViewProgress, updateProgress progress: Float) {
        if progress > 0.1 {
            MRProgressOverlayView.dismissOverlayForView(self.tabBarController?.view, animated: true)
        }
        progressView.setProgress(progress, animated: true)
    }
    
    // MARK: - IBActions
    
    @IBAction func exportButton(sender: AnyObject) {
        let safariActivity : TUSafariActivity = TUSafariActivity()
        var activity : UIActivityViewController = UIActivityViewController()
        
        if self.receivedUrl.hasPrefix("http://") {
            activity = UIActivityViewController(activityItems: [NSURL(string: self.receivedUrl)!], applicationActivities: [safariActivity])
        } else {
            // First few times I'm using Swift optional checking!1!1
            if let index1 = self.receivedUrl.rangeOfString("[")?.endIndex, index2 = self.receivedUrl.rangeOfString("]")?.startIndex {
                let range = Range(start: index1, end: index2)
                
                activity = UIActivityViewController(activityItems: [self.receivedUrl.substringWithRange(range)], applicationActivities: [safariActivity])
            }
        }
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.Phone) {
            self.presentViewController(activity, animated: true, completion: nil)
        } else {
            let popup = UIPopoverController(contentViewController: activity)
            popup.presentPopoverFromBarButtonItem(exportBarButton, permittedArrowDirections: .Any, animated: true)
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    
}
