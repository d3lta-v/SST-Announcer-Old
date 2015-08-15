//
//  InAppBrowserViewController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 9/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

class InAppBrowserViewController: UIViewController, UIWebViewDelegate, NJKWebViewProgressDelegate {

    // MARK: - Private variables declaration

    @IBOutlet weak var mainWebView: UIWebView!

    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var forwardButton: UIBarButtonItem!
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBOutlet weak var exportButton: UIBarButtonItem!

    @IBOutlet weak var fixedSpace1: UIBarButtonItem!
    @IBOutlet weak var fixedSpace2: UIBarButtonItem!
    @IBOutlet weak var flexSpace3: UIBarButtonItem!
    @IBOutlet weak var fixedSpace4: UIBarButtonItem!
    @IBOutlet weak var fixedSpace5: UIBarButtonItem!

    private var progressProxy: NJKWebViewProgress!
    var receivedUrl: NSURL? = NSURL() // Public variable, to be exposed to previous view controller

    private var stopBool = false

    // MARK: - Lifecycle

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        // Init web view loading bar
        progressProxy = NJKWebViewProgress()
        mainWebView.delegate = progressProxy
        progressProxy.webViewProxyDelegate = self
        progressProxy.progressDelegate = self

        if let url = receivedUrl {
            mainWebView.loadRequest(NSURLRequest(URL: url))
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        backButton.enabled = mainWebView.canGoBack
        forwardButton.enabled = mainWebView.canGoForward
        self.navigationController?.setToolbarHidden(false, animated: false)
        let toolbarArray = [fixedSpace1, backButton, fixedSpace2, forwardButton, flexSpace3, refreshButton, fixedSpace4, exportButton, fixedSpace5]
        self.setToolbarItems(toolbarArray, animated: false)
    }

    override func viewWillDisappear(animated: Bool) {
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

    func webViewProgress(webViewProgress: NJKWebViewProgress!, updateProgress progress: Float) {
        self.navigationController?.setSGProgressPercentage(progress * 100)

        if progress > 0.3 { // prevent unnecessary calls
            self.navigationItem.title = mainWebView.stringByEvaluatingJavaScriptFromString("document.title")
        }
    }

    // MARK: - UIWebView delegate

    func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        if error.code != -999 {
            ProgressHUD.showError("Error loading!")
            println(error.localizedDescription)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }

    func webViewDidStartLoad(webView: UIWebView) {
        backButton.enabled = mainWebView.canGoBack
        forwardButton.enabled = mainWebView.canGoForward
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }

    func webViewDidFinishLoad(webView: UIWebView) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }

    // MARK: - IBActions

    @IBAction func goBack(sender: AnyObject) {
        if mainWebView.canGoBack {
            mainWebView.goBack()
        }
    }

    @IBAction func goForward(sender: AnyObject) {
        if mainWebView.canGoForward {
            mainWebView.goForward()
        }
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
