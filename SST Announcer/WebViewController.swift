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
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // Init web view proxies
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
    
    private func loadFeed(url: String!) {
        var htmlString = ""
        
        if url == "error" {
            self.title = "Error"
            
            htmlString = "<p align=\"center\">Woops! The app has encountered an error. No worries, just go back and reselect the page.</p>"
        }
        
        // Custom settings for our builder
        let builderOptions = [
            DTDefaultFontFamily: "Helvetica Neue",
            DTDefaultFontSize: "16.4px",
            DTDefaultLineHeightMultiplier: "1.43",
            DTDefaultLinkColor: "#146FDF",
            DTDefaultLinkDecoration: ""
        ]
        let stringBuilder : DTHTMLAttributedStringBuilder = DTHTMLAttributedStringBuilder(HTML: htmlString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true), options: builderOptions, documentAttributes: nil)
        self.textView.shouldDrawImages = true
        self.textView.attributedString = stringBuilder.generatedAttributedString()
        self.textView.contentInset = UIEdgeInsetsMake(85, 15, 40, 15)
        
        self.textView.textDelegate = self
        
        MRProgressOverlayView.dismissOverlayForView(self.tabBarController!.view, animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UIWebViewDelegate Methods
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        if error.code != -999 {
            MRProgressOverlayView.showOverlayAddedTo(self.tabBarController!.view, title: "Loading failed!", mode: .Cross, animated: true)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }
    
    // MARK: - WebViewProgressDelegate Methods
    
    func webViewProgress(webViewProgress: WebViewProgress, updateProgress progress: Float) {
        if progress > 0.1 {
            MRProgressOverlayView.dismissOverlayForView(self.tabBarController!.view, animated: true)
        }
        
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
