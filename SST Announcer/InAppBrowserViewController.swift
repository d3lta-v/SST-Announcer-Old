//
//  InAppBrowserViewController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 9/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

class InAppBrowserViewController: UIViewController, UIWebViewDelegate, WebViewProgressDelegate {
    
    // MARK: - Private variables declaration
    
    @IBOutlet var mainWebView: UIWebView!

    @IBOutlet var backButton: UIBarButtonItem!
    @IBOutlet var forwardButton: UIBarButtonItem!
    @IBOutlet var refreshButton: UIBarButtonItem!
    @IBOutlet var exportButton: UIBarButtonItem!
    
    @IBOutlet var fixedSpace1: UIBarButtonItem!
    @IBOutlet var fixedSpace2: UIBarButtonItem!
    @IBOutlet var flexSpace3: UIBarButtonItem!
    @IBOutlet var fixedSpace4: UIBarButtonItem!
    @IBOutlet var fixedSpace5: UIBarButtonItem!
    
    private var progressView : WebViewProgressView!
    private var progressProxy : WebViewProgress!
    var receivedUrl : NSURL? = NSURL() // Public variable, to be exposed to previous view controller
    
    private var stopBool : Bool = false
    
    // MARK: - Lifecycle
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // Init web view loading bar
        progressProxy = WebViewProgress()
        mainWebView.delegate = progressProxy
        progressProxy.webViewProxyDelegate = self
        progressProxy.progressDelegate = self
        let progressBarHeight: CGFloat = 2.0
        let navigationBarBounds = self.navigationController!.navigationBar.bounds
        let barFrame = CGRect(x: 0, y: navigationBarBounds.size.height - progressBarHeight, width: navigationBarBounds.width, height: progressBarHeight)
        progressView = WebViewProgressView(frame: barFrame)
        progressView.autoresizingMask = .FlexibleWidth | .FlexibleTopMargin
        
        if let url = receivedUrl {
            mainWebView.loadRequest(NSURLRequest(URL: url))
        }
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setToolbarHidden(false, animated: false)
        let toolbarArray = [fixedSpace1, backButton, fixedSpace2, forwardButton, flexSpace3, refreshButton, fixedSpace4, exportButton, fixedSpace5]
        self.setToolbarItems(toolbarArray, animated: false)
        self.navigationController?.navigationBar.addSubview(progressView)
        progressView.setProgress(0, animated: true)
    }
    
    override func viewWillDisappear(animated: Bool) {
        progressView.removeFromSuperview()
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Private functions
    
    func stopAction() {
        mainWebView.stopLoading()
    }
    
    func refreshAction() {
        mainWebView.reload()
    }
    
    // MARK: - WebViewProgress delegates
    
    func webViewProgress(webViewProgress: WebViewProgress, updateProgress progress: Float) {
        progressView.setProgress(progress, animated: true)
        
        if progress < 1 { // Have not finished loading
            let bttn = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Stop, target: self, action: "stopAction")
            refreshButton = bttn
            stopBool = true
        } else if progress == 1 {
            let bttn = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Refresh, target: self, action: "refreshAction")
            refreshButton = bttn
            stopBool = false
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
        
        self.navigationItem.title = mainWebView.stringByEvaluatingJavaScriptFromString("document.title")
        
        backButton.enabled = mainWebView.canGoBack
        forwardButton.enabled = mainWebView.canGoForward
    }
    
    // MARK: - UIWebView delegate
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        if error.code != -999 {
            ProgressHUD.showError("Error loading!")
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }

    // MARK: - IBActions
    
    @IBAction func goBack(sender: AnyObject) {
        mainWebView.goBack()
    }
    
    @IBAction func goForward(sender: AnyObject) {
        mainWebView.goForward()
    }
    
    @IBAction func exportAction(sender: AnyObject) {
        if let url = receivedUrl { // Better idea to unwrap optional
            let safariActivity = TUSafariActivity()
            let actViewController = UIActivityViewController(activityItems: [url], applicationActivities: [safariActivity])
            if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
                self.presentViewController(actViewController, animated: true, completion: nil)
            } else {
                let popup = UIPopoverController(contentViewController: actViewController)
                popup.presentPopoverFromBarButtonItem(exportButton, permittedArrowDirections: .Any, animated: true)
            }
        }
    }
    
    @IBAction func refreshOrStop(sender: AnyObject) {
        if stopBool {
            mainWebView.stopLoading()
        } else {
            mainWebView.reload()
        }
    }
    
    
    @IBAction func exitNavigationVC(sender: AnyObject) {
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }

}
