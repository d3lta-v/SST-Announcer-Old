//
//  WebViewController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 4/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit
import SafariServices

class WebViewController: UIViewController {

    // MARK: - Variables declaration
    var receivedFeedItem: FeedItem?
    @IBOutlet weak var exportBarButton: UIBarButtonItem!
    @IBOutlet weak var webView: UIWebView!
    @IBOutlet weak var textView: DTAttributedTextView!
    private var progressProxy: NJKWebViewProgress!
    private var linkUrl = NSURL(string: "")!
    private var progressCancelled = false
    private let indeterminateProgressBar = JDFNavigationBarActivityIndicator()

    // MARK: - Lifecycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        // Init web view loading bar
        progressProxy = NJKWebViewProgress()
        webView.delegate = progressProxy
        progressProxy.webViewProxyDelegate = self
        progressProxy.progressDelegate = self
        loadFeed(self.receivedFeedItem)
    }

    override func viewWillDisappear(animated: Bool) {
        progressCancelled = true
        self.navigationController?.cancelSGProgress()
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false

        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Private functions

    private func loadFeed(item: FeedItem!) {
        var htmlString = ""
        var useSIMUX = false

        if item.title == "Error" {
            self.title = item.title
            htmlString = item.content
        } else if item.title.isEmpty { // Nothing in the title, since it came from a push
            indeterminateProgressBar.addToNavigationBar(self.navigationController?.navigationBar, startAnimating: true)
            useSIMUX = true
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            SIMUXCRParser().convertHTML(item.link) { (title: String, description: String) in
                var editedDescription = description.stringByReplacingOccurrencesOfString("<div><br></div>", withString: "<div></div>", options: NSStringCompareOptions.LiteralSearch, range: nil)
                print(editedDescription)
                editedDescription = editedDescription.stringByReplacingOccurrencesOfString("<p>Loading...</p>", withString: "<b>This article contains a Google Document, form, or some other iframe based content. Please use the button on the top right to view the full webpage.</b>")

                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                dispatch_sync(dispatch_get_main_queue(), {
                    self.title = title

                    htmlString = editedDescription
                    self.initAttributedTextViewWithString(htmlString)
                })
            }
        } else {
            self.title = item.title
            htmlString = item.content
        }

        // Check for iframes and other special content before calling the builder, for better performance
        if htmlString.rangeOfString("<iframe") != nil {
            useBrowser(item.link, usedTable: false)
        } else if htmlString.rangeOfString("<table") != nil {
            useBrowser(item.link, usedTable: true)
        } else {
            if useSIMUX == false {
                htmlString = cleanHtml(htmlString)
                initAttributedTextViewWithString(htmlString)
            }
        }
    }

    private func initAttributedTextViewWithString(string: String!) {
        let builderOptions = [
            DTDefaultFontFamily: UIFont.systemFontOfSize(UIFont.systemFontSize()).familyName,
            DTDefaultFontSize: getPixelSizeForDynamicType(),
            DTDefaultLineHeightMultiplier: "1.43",
            DTDefaultLinkColor: "#146FDF",
            DTDefaultLinkDecoration: ""
        ]
        let strData = string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
        let stringBuilder = DTHTMLAttributedStringBuilder(HTML: strData, options: builderOptions, documentAttributes: nil)
        self.textView.textDelegate = self
        self.textView.shouldDrawImages = true
        self.textView.attributedString = stringBuilder.generatedAttributedString()
        self.textView.contentInset = UIEdgeInsetsMake(85, 15, 70, 15)

        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        indeterminateProgressBar.stopAnimating()
    }

    private func getPixelSizeForDynamicType() -> (String) {
        // Support for Dynamic Type for DTCoreText!!!
        let preferredSizeCategory = UIApplication.sharedApplication().preferredContentSizeCategory
        var size = "" // Font size
        switch preferredSizeCategory {
        case UIContentSizeCategoryExtraSmall:
            size = "13.5px"; break
        case UIContentSizeCategorySmall:
            size = "14px"; break
        case UIContentSizeCategoryMedium:
            size = "15.5px"; break
        case UIContentSizeCategoryLarge:
            size = "17px"; break
        case UIContentSizeCategoryExtraLarge:
            size = "18.5px"; break
        case UIContentSizeCategoryExtraExtraLarge:
            size = "20px"; break
        case UIContentSizeCategoryExtraExtraExtraLarge:
            size = "21.5px"; break
        case UIContentSizeCategoryAccessibilityMedium:
            size = "24px"; break
        case UIContentSizeCategoryAccessibilityLarge:
            size = "27px"; break
        case UIContentSizeCategoryAccessibilityExtraLarge:
            size = "30px"; break
        case UIContentSizeCategoryAccessibilityExtraExtraLarge:
            size = "33px"; break
        case UIContentSizeCategoryAccessibilityExtraExtraExtraLarge:
            size = "36px"; break
        default:
            size = "16.4px"
        }
        return size
    }

    private func useBrowser(url: String!, usedTable: Bool!) {
        textView.alpha = 0
        guard let urlUnwrapped = NSURL(string: url) else {return}
        if usedTable == true {
            webView.loadRequest(NSURLRequest(URL: urlUnwrapped))
        } else {
            webView.loadRequest(NSURLRequest(URL: urlUnwrapped))
        }
    }

    // The super cleanHtml REGEX engine
    private func cleanHtml(html: String!) -> String! {
        var htmlVariable: String = html
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString(" style=\"[\\s\\S]*?\"", withString: "", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString(" height=\"[\\s\\S]*?\"", withString: "", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString(" width=\"[\\s\\S]*?\"", withString: "", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString(" border=\"[\\s\\S]*?\"", withString: "", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<div><br /></div>", withString: "<br>")
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<b[r][^>]*/>", withString: "<br \\>", options: .RegularExpressionSearch, range: nil)
        htmlVariable = htmlVariable.stringByReplacingOccurrencesOfString("<!--(.*?)-->", withString: "", options: .RegularExpressionSearch, range: nil)
        return htmlVariable
    }

    // MARK: - IBActions

    @IBAction func exportButton(sender: AnyObject) {
        if let feedItem = self.receivedFeedItem {
            guard let url = NSURL(string: feedItem.link) else {
                return
            }
            if #available(iOS 9.0, *) {
                let svc = SFSafariViewController(URL: url)
                self.presentViewController(svc, animated: true, completion: nil)
            } else {
                let safariActivity = TUSafariActivity()
                // Guard-based null checking
                let validUrlString = feedItem.link.stringByAddingPercentEncodingWithAllowedCharacters(.URLQueryAllowedCharacterSet())
                guard let validUrlStringUnwrapped = validUrlString else {return}
                guard let url = NSURL(string: validUrlStringUnwrapped) else {return}

                let activity = UIActivityViewController(activityItems: [url], applicationActivities: [safariActivity])
                if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
                    self.presentViewController(activity, animated: true, completion: nil)
                } else {
                    let popup = UIPopoverController(contentViewController: activity)
                    popup.presentPopoverFromBarButtonItem(exportBarButton, permittedArrowDirections: .Any, animated: true)
                }
            }
        }
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        guard let destinationVC = segue.destinationViewController as? UINavigationController else {
            return
        }
        let vc = destinationVC.topViewController as? InAppBrowserViewController

        vc?.receivedUrl = linkUrl
    }

}

// MARK: - UIWebViewDelegate, WebViewProgressDelegate Methods

extension WebViewController : UIWebViewDelegate, NJKWebViewProgressDelegate {
    func webViewDidStartLoad(webView: UIWebView) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }

    func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
        guard let err = error else {
            return
        }
        if err.code != -999 {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            guard let errorFile = NSBundle.mainBundle().pathForResource("MobileSafariError", ofType: "html") else {
                ProgressHUD.showError("Loading failed!")
                return
            }
            do {
                var errorHtml = try String(contentsOfFile: errorFile)
                guard let errorDescription = error?.localizedDescription else {return}
                errorHtml = errorHtml.stringByReplacingOccurrencesOfString("errMsg", withString: errorDescription)
                self.title = "Cannot Open Page"
                webView.loadHTMLString(errorHtml, baseURL: nil)
            } catch {
                ProgressHUD.showError("Internal error")
                return
            }
        }
    }

    func webViewDidFinishLoad(webView: UIWebView) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }

    func webViewProgress(webViewProgress: NJKWebViewProgress!, updateProgress progress: Float) {
        if !progressCancelled {
            self.navigationController?.setSGProgressPercentage(progress * 100)
        }
    }
}

// MARK: - DTCoreText Delegates

extension WebViewController : DTAttributedTextContentViewDelegate, DTLazyImageViewDelegate, DTWebVideoViewDelegate {
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


    func linkPushed(button: DTLinkButton) {
        let url = button.URL

        if UIApplication.sharedApplication().canOpenURL(url.absoluteURL) {
            let urlString = url.absoluteString
            if urlString.hasPrefix("http") == true {
                self.linkUrl = url
                if #available(iOS 9.0, *) {
                    let svc = SFSafariViewController(URL: self.linkUrl)
                    self.presentViewController(svc, animated: true, completion: nil)
                } else {
                    self.performSegueWithIdentifier("ToBrowser", sender: self)
                }
            } else if urlString.hasPrefix("mailto") == true || urlString.hasPrefix("tel") == true {
                UIApplication.sharedApplication().openURL(url)
            }
        } else {
            if url.host == nil && url.path == nil {
                let fragment = url.fragment

                if fragment != nil {
                    self.textView.scrollToAnchorNamed(fragment, animated: false)
                }
            }
        }
    }
}
