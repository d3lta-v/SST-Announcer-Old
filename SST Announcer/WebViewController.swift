//
//  WebViewController.swift
//  SST Announcer
//
//  Created by Pan Ziyue on 4/6/15.
//  Copyright (c) 2015 StatiX Industries. All rights reserved.
//

import UIKit

class WebViewController: UIViewController, DTAttributedTextContentViewDelegate, DTLazyImageViewDelegate, UIWebViewDelegate, WebViewProgressDelegate {
    
    // Variables declaration
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UIWebViewDelegate Methods
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        if error.code != -999 {
            MRProgressOverlayView.showOverlayAddedTo(self.tabBarController?.view, title: "Loading failed!", mode: .Cross, animated: true)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        MRProgressOverlayView.dismissOverlayForView(self.tabBarController?.view, animated: true)
        
    }
    
    // MARK: WebViewProgressDelegate Methods
    
    func webViewProgress(webViewProgress: WebViewProgress, updateProgress progress: Float) {
        
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    
}
