Change Log
==========

This is the history of version updates.

**Version 1.7.7**

- FIXED: [DTSidePanelController] Panel might get stuck half way opened
- CHANGED: DTSmartPagingScrollView can now be instantiated from NIB / Storyboard
- FIXED: Warnings from XCode7
- FIXED: Some warnings from OClint

**Version 1.7.6**

- FIXED [DTASN1Parser] 2 Bugs
- ADDED: Method for SHA1 generation
- ADDED: iOS Framework

**Version 1.7.5**

- FIXED: [DTHTMLParser] Implemented check for invalid encoding when auto-detecting HTML encoding
- FIXED: [DTHTMLParser] Added missing deployment target in pod spec to allow usage of parser under OS X
- FIXED: [DTASN1Parser] Crash when parsing ASN.1 data containing Latin1 string, instead ignore the string contents
- FIXED: Improved 64-bit handling in DTCoreGraphicsUtils, DTPieProgressIndicator and UIImage+DTFoundation
- FIXED: DTPieProgressIndicator would not display properly when instantiated from XIB

**Version 1.7.4**

- FIXED: Added armv7s to static library targets (iOS)
- FIXED: [DTZipArchive] unit test would sometimes fail
- FIXED: Analyzer warnings
- FIXED: Log message of main thread checker would mention incorrect symbol for debugging
- ADDED: CocoaPods specs for DTScripting, Debug and Runtime
- ADDED: Dynamic framework for iOS8
- REMOVED: Deprecated static framework for iOS

**Version 1.7.3**

- FIXED: [DTAlertView] Completion blocks for the buttons are not executed on iOS 8 GM
- FIXED: [DTActionSheet] Completion blocks for the buttons are not executed on iOS 8 GM

**Version 1.7.2**

- FIXED: [DTAlertView] Completion blocks for the buttons are not executed on iOS 8
- FIXED: [DTLog] Deprecation warnings with iOS 8 deployment target
- FIXED: [DTProgressHUD] Warning about no rootViewController might show if instantiated in app's first run loop (<= iOS 7)
- FIXED: [DTSidePanelController] Horizontal swipe gesture interfering with edit gesture on table view
- FIXED: [DTSidePanelController] Panel sizing issue resulting in black areas showing
- ADDED: [DTSidePanelController] Support for creation via storyboard

**Version 1.7.1**

- ADDED: DTAnimatedGIF in separate static lib / subspec
- FIXED: DTActionSheet "noticeable delay" choosing an action

**Version 1.7.0**

- ADDED: DTProgressHUD
- FIXED: Deprecation warning in DTActivityTitleView when compiling >= iOS 7
- FIXED: Some targets where built only for 64-bit
- FIXED: Warning about weak variable being accessed multiple times

**Version 1.6.3**

- FIXED: DTFolderMonitor might cause exception if monitoring is started and stopped quickly in succession
- CHANGED: Migrated unit testing to XCTest

**Version 1.6.2**

- ADDED: DTCustomColoredAccessory gains DTCustomColoredAccessoryTypeSquare
- CHANGED: Made DTASN1Parser usable as stand-alone library
- FIXED: DTHTMLParser pod build problem if Xcode installed in path containing spaces
- FIXED: Xcode 5.1 warnings

**Version 1.6.1**

- FIXED: Typo in DTFolderMonitor causing build to fail in some build scenarios
- FIXED: DTSidePanelController panel jumping in rare cases
- FIXED: DTReachability exception when specifying an invalid domain for monitoring

**Version 1.6.0**

- CHANGED: DTReachability now passes DTReachabilityInformation to observers
- CHANGED: DTReachability revamped to allow monitoring custom hosts, no longer a singleton
- FIXED: Missing Code Coverage monitoring
- CHANGED: Refactored DTZipArchive and added more unit tests for GZip
- CHANGED: Prefixed some C-functions to avoid conflicts
- FIXED: Analyze Warnings
- FIXED: Some 64-bit and Xcode 4/5 build issues

**Version 1.5.4**

- ADDED: Coverage Monitoring via Coveralls
- ADDED: DTBlockFunctions
- FIXED: DTZipArchive: completion block would be called twice if uncompressing has error
- FIXED: Warning in minizip
- CHANGED: Removed shadow from PieProgressIndicator to fit iOS7 style

**Version 1.5.3**

- FIXED: Warnings on DTZipArchive
- FIXED: GZ file handle error
- CHANGED: Updated build flags for static libs and frameworks
- ADDED: Continuous Integration via Travis-CI

**Version 1.5.2**

- ADDED: Method for duplicating template image tinting under iOS 6
- ADDED: DTLog function for retrieving current app log messages
- ADDED: DTLog function for duplicating NSLog but using ASL and specifying severity level
- FIXED: DTLog issue when being called from C-function
- FIXED: DTHTMLParser would not accumulate characters if no tag start and end delegate methods were set

**Version 1.5.1**

- ADDED: Ability to uncompress individual files in DTZipArchive
- ADDED: DTFolderMonitor for watching a folder for changes
- ADDED: DTZipArchive Demo demonstrating DTZipArchive and DTFolderMonitor on iOS
- ADDED: DTLog logging hooks
- CHANGED: DTHTMLParser now aggregates parsed characters into a single delegate call-back
- CHANGED: Removed UIKit dependency for DTAsyncFileDeleter so that it can be moved to Core sub-spec

**Version 1.5.0**

- CHANGED: DTASN1 Moved to sub-spec, out of Core
- CHANGED: DTScripting classes moved to sub-spec, out of Core
- CHANGED: DTAlertView, DTActionSheet, UIView+DTActionHandlers moved to UIKit_BlocksAdditions sub-spec, out of UIKit
- CHANGED: Moved DTDebug methods for UIColor and UIView into sub-folder, no spec
- CHANGED: Moved Obj-C runtime methods to sub-folder, no spec
- ADDED: DTAWS for communicating with Amazon Web Services
- ADDED: Method on DTSmartPagingScrollView for accessing a specific page's view
- FIXED: Typo on DTHTMLParser sub-spec
- FIXED: Parsing the OS X version string was incorrect in DTVersion
- FIXED: DTExtendedFileAttributes was using hard-coded length for buffer

Note: While there are no breaking API changes the podspec cleanup will probably require updating your dependencies if you use projects that directly or indirectly depend on DTFoundation.

**Version 1.4.4**

- FIXED: Warning for incomplete section pragma in DTActionSheet
- FIXED: Added missing zLib dependency to PodSpec
- FIXED: DTWeakSupport.h can now also be imported into non-ARC source files
- FIXED: DTWeakSupport header missing from public headers for iOS Static Framework target
- FIXED: Removed duplicate classes from side panel demo which are already included in lib

**Version 1.4.3**

- FIXED: Removed Error in DTWeakSupport, as including this in non-ARC project is legitimate use

**Version 1.4.2**

- ADDED: DTWeakSupport.h for tagging variables and properties to use weak refs if supported
- FIXED: [DTSidePanel] classes missing from static library target
- CHANGED: Implemented conditional weak support in DTSidePanelController, DTActionSheet, DTAlertView,
DTSmartPagingScrollView, DTHTMLParser, DTASN1Parser

**Version 1.4.1**

- ADDED: [DTCustomColoredAccessory] Added left arrow disclosure indicator
- ADDED: [DTReachability] Demo App
- CHANGED: [DTReachability] to observe reachability to apple.com instead of general IP connectivity as this addresses some issues where DNS resolving might lag behind
- FIXED: [DTSidePanel] Appearance Notifications not sent to replaced panels

**Version 1.4**

- ADDED: [DTSidePanel] Container Controller
- ADDED: [DTSQLite] Wrapper class for SQLite3 Databases
- ADDED: [DTAlertView] Method to create a cancel button and/or set a cancelBlock.
- CHANGED: Moved experimental striped layer into Experimental folder

**Version 1.3**

- ADDED: [DTReachability]
- FIXED: [DTZipArchive] Incorrect Define

**Version 1.2**

- ADDED: [DTASN1] BitString support
- ADDED: [DTASN1] DTASN1Serialization
- ADDED: [DTASN1] IA5 String support
- FIXED: [DTZipArchive] Unit Tests

**Version 1.1**

- CHANGED: Refactored base64 methods into DTBase64Coding
- ADDED: UIView Debug methods to catch errors where UIView methods are called on background thread
- ADDED: [Experimental] DTStripedLayer
- ADDED: Method to produce random color
- ADDED: DTTiledLayerWithoutFade
- ADDED: CGRectCenter
- FIXED: [AppKit] Fixed bugs in panel presenting
- CHANGED: [DTZipArchive] Various Improvements
- CHANGED: [DTUTI] Moved to separate library/subspec
- REMOVED: DTDownload and DTBonjour, they become their own repositories
