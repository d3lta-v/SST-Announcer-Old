//
//  WebViewController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 4/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

class WebViewController: UIViewController, DTAttributedTextContentViewDelegate, DTLazyImageViewDelegate, UIWebViewDelegate, WebViewProgressDelegate , DTWebVideoViewDelegate {

    // MARK: - Variables declaration
    var receivedUrl: String = String()
    @IBOutlet var exportBarButton: UIBarButtonItem!
    @IBOutlet var webView: UIWebView!
    @IBOutlet var textView: DTAttributedTextView!
    private var progressView: WebViewProgressView!
    private var progressProxy: WebViewProgress!
    private var linkUrl = NSURL(string: "")!

    // MARK: - Lifecycle

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        // Back button
        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffsetMake(0, -60), forBarMetrics: UIBarMetrics.Default)

        // Progress
        self.navigationController?.showProgress()
        self.navigationController?.setProgress(0, animated: false)

        // Init web view loading bar
        progressProxy = WebViewProgress()
        webView.delegate = progressProxy
        progressProxy.webViewProxyDelegate = self
        progressProxy.progressDelegate = self
        let progressBarHeight: CGFloat = 2.5
        let navigationBarBounds = self.navigationController!.navigationBar.bounds
        let barFrame = CGRect(x: 0, y: navigationBarBounds.size.height - progressBarHeight, width: navigationBarBounds.width, height: progressBarHeight)
        progressView = WebViewProgressView(frame: barFrame)
        progressView.autoresizingMask = .FlexibleWidth | .FlexibleTopMargin

        loadFeed(self.receivedUrl)
    }

    override func viewWillDisappear(animated: Bool) {
        progressView.removeFromSuperview()

        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Private functions

    private func loadFeed(url: String!) {
        // NOTE: URL is not actually an URL and only under some circumstances (i.e. retrieving from push notification) it IS an URL

        var htmlString = ""
        var useSIMUX = false

        if url == "error" {
            self.title = "Error"
            htmlString = "<p align=\"center\">Woops! The app has encountered an error. No worries, just go back, refresh and reselect the page.</p>"
        } else if url.hasPrefix("h") { //First letter of http, to reduce memory usage
            self.navigationController?.setIndeterminate(true)
            useSIMUX = true
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true

            var title: String!
            var description: String!
            SIMUXCRParser().convertHTML(url) { (title: String, description: String) in
                let editedDescription = description.stringByReplacingOccurrencesOfString("<div><br></div>", withString: "<div></div>", options: NSStringCompareOptions.LiteralSearch, range: nil)

                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                println(title)
                dispatch_sync(dispatch_get_main_queue(), {
                    self.title = title

                    htmlString = editedDescription
                    self.initAttributedTextViewWithString(htmlString)
                })
            }
        } else {
            htmlString = useDirect()
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
            if useSIMUX == false {
                initAttributedTextViewWithString(htmlString)
            }
        }
    }

    private func useDirect() -> (String) {
        var title = ""
        var actualUrl = ""
        var description = ""

        // Get title range
        if let index1 = self.receivedUrl.rangeOfString("{")?.endIndex, index2 = self.receivedUrl.rangeOfString("}")?.startIndex {
            let range = Range(start: index1, end: index2)
            title = self.receivedUrl.substringWithRange(range)
        }

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
        return description
    }

    private func initAttributedTextViewWithString(string: String!) {
        let builderOptions = [
            DTDefaultFontFamily: "Helvetica Neue",
            DTDefaultFontSize: "16.4px",
            DTDefaultLineHeightMultiplier: "1.43",
            DTDefaultLinkColor: "#146FDF",
            DTDefaultLinkDecoration: ""
        ]
        let stringBuilder = DTHTMLAttributedStringBuilder(HTML: string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false), options: builderOptions, documentAttributes: nil)
        self.textView.textDelegate = self
        self.textView.shouldDrawImages = true
        self.textView.attributedString = stringBuilder.generatedAttributedString()
        self.textView.contentInset = UIEdgeInsetsMake(85, 15, 40, 15)

        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        self.navigationController?.setIndeterminate(false)
    }

    private func useBrowser(url: String!, usedTable: Bool!) {
        self.navigationController!.navigationBar.addSubview(progressView)
        progressView.setProgress(0, animated: true)

        textView.alpha = 0
        if usedTable == true {
            webView.loadRequest(NSURLRequest(URL: NSURL(string: url)!))
        } else {
            webView.loadRequest(NSURLRequest(URL: NSURL(string: url+"?m=0")!))
        }
    }

    private func cleanHtml(html: String!) -> String! {
        var htmlVariable: String = html

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

    private func delay(delay: Double, closure:()->()) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay * Double(NSEC_PER_SEC))
            ),
            dispatch_get_main_queue(), closure)
    }

    func linkPushed(button: DTLinkButton) {
        let url = button.URL

        if UIApplication.sharedApplication().canOpenURL(url.absoluteURL!) {
            self.linkUrl = url
            self.performSegueWithIdentifier("ToBrowser", sender: self)
        } else {
            if url.host == nil && url.path == nil {
                let fragment = url.fragment

                if fragment != nil {
                    self.textView.scrollToAnchorNamed(fragment, animated: false)
                }
            }
        }
    }

    // MARK: - DTAttributedTextContentViewDelegate
    func attributedTextContentView(attributedTextContentView: DTAttributedTextContentView!, viewForLink url: NSURL!, identifier: String!, frame: CGRect) -> UIView! {
        let linkButton: DTLinkButton = DTLinkButton(frame: frame)
        linkButton.URL = url
        linkButton.addTarget(self, action: "linkPushed:", forControlEvents: .TouchUpInside)

        return linkButton
    }

    func attributedTextContentView(attributedTextContentView: DTAttributedTextContentView!, viewForAttachment attachment: DTTextAttachment!, frame: CGRect) -> UIView! {
        if attachment.isKindOfClass(DTImageTextAttachment) {
            let imageView: DTLazyImageView = DTLazyImageView(frame: frame)
            imageView.delegate = self
            //TODO: Use a placeholder image if the image is not properly initialized
            if let attachmentImage = (attachment as? DTImageTextAttachment)?.image {
                imageView.image = attachmentImage
            }
            imageView.url = attachment.contentURL

            if attachment.hyperLinkURL != nil {
                imageView.userInteractionEnabled = true
                let button = DTLinkButton(frame: imageView.bounds)
                button.URL = attachment.hyperLinkURL
                button.minimumHitSize = CGSizeMake(25, 25)
                button.GUID = attachment.hyperLinkGUID

                button.addTarget(self, action: "linkPushed:", forControlEvents: .TouchUpInside)
                imageView.addSubview(button)
            }

            return imageView
        } else if attachment.isKindOfClass(DTIframeTextAttachment) {
            let videoView = DTWebVideoView(frame: frame)
            videoView.attachment = attachment

            return videoView
        } else if attachment.isKindOfClass(DTObjectTextAttachment) {
            let colorName: AnyObject? = attachment.attributes["somecolorparameter"]
            if let someColor = DTColorCreateWithHTMLName(colorName as? String) {
                let someView = UIView(frame: frame)
                someView.backgroundColor = someColor
                someView.layer.borderWidth = 1
                someView.layer.borderColor = UIColor.blackColor().CGColor
                someView.accessibilityLabel = colorName as? String
                someView.isAccessibilityElement = true

                return someView
            } else {
                return nil
            }
        }
        return nil
    }


    // MARK: - DTLazyImageViewDelegate

    func lazyImageView(lazyImageView: DTLazyImageView!, didChangeImageSize size: CGSize) {
        let url = lazyImageView.url
        var imageSize = size
        let screenSize = CGSizeMake(UIScreen.mainScreen().bounds.size.width - 30, UIScreen.mainScreen().bounds.size.height) //minus 30 for inset of 15px on two sides

        if size.width > screenSize.width {
            let ratio = screenSize.width/size.width
            imageSize.width = size.width*ratio
            imageSize.height = size.height*ratio
        }

        let pred = NSPredicate(format: "contentURL == %@", url)

        var didUpdate = false

        var predicateArray = self.textView.attributedTextContentView.layoutFrame.textAttachmentsWithPredicate(pred)

        for index in 0..<predicateArray.count {
            if CGSizeEqualToSize(predicateArray[index].originalSize, CGSizeZero) {
                (predicateArray[index] as? DTTextAttachment)?.originalSize = imageSize
                didUpdate = true
            }
        }

        if didUpdate {
            self.textView.relayoutText()
        }
    }

    // MARK: - UIWebViewDelegate Methods

    func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        if error.code != -999 {
            ProgressHUD.showError("Loading failed!")
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }

    func webViewDidFinishLoad(webView: UIWebView) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }

    // MARK: - WebViewProgressDelegate Methods

    func webViewProgress(webViewProgress: WebViewProgress, updateProgress progress: Float) {
        progressView.setProgress(progress, animated: true)
    }

    // MARK: - IBActions

    @IBAction func exportButton(sender: AnyObject) {
        let safariActivity = TUSafariActivity()
        var activity = UIActivityViewController()

        if self.receivedUrl.hasPrefix("h") {
            activity = UIActivityViewController(activityItems: [NSURL(string: self.receivedUrl)!], applicationActivities: [safariActivity])
        } else {
            // First few times I'm using Swift optional checking!1!1
            if let index1 = self.receivedUrl.rangeOfString("[")?.endIndex, index2 = self.receivedUrl.rangeOfString("]")?.startIndex {
                let range = Range(start: index1, end: index2)

                activity = UIActivityViewController(activityItems: [NSURL(string: self.receivedUrl.substringWithRange(range))!], applicationActivities: [safariActivity])
            }
        }

        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
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
        let vc = segue.destinationViewController.topViewController as? InAppBrowserViewController

        vc?.receivedUrl = linkUrl
    }

}
