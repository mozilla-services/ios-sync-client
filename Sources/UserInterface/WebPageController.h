/***** BEGIN LICENSE BLOCK *****
 Version: MPL 1.1/GPL 2.0/LGPL 2.1
 
 The contents of this file are subject to the Mozilla Public License Version 
 1.1 (the "License"); you may not use this file except in compliance with 
 the License. You may obtain a copy of the License at 
 http://www.mozilla.org/MPL/
 
 Software distributed under the License is distributed on an "AS IS" basis,
 WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 for the specific language governing rights and limitations under the
 License.
 
 The Original Code is weave-iphone.
 
 The Initial Developer of the Original Code is Mozilla Labs.
 Portions created by the Initial Developer are Copyright (C) 2009
 the Initial Developer. All Rights Reserved.
 
 Contributor(s):
 Anant Narayanan <anant@kix.in>
 Dan Walkowski <dwalkowski@mozilla.com>

 Alternatively, the contents of this file may be used under the terms of either
 the GNU General Public License Version 2 or later (the "GPL"), or the GNU
 Lesser General Public License Version 2.1 or later (the "LGPL"), in which case
 the provisions of the GPL or the LGPL are applicable instead of those above.
 If you wish to allow use of your version of this file only under the terms of
 either the GPL or the LGPL, and not to allow others to use your version of
 this file under the terms of the MPL, indicate your decision by deleting the
 provisions above and replace them with the notice and other provisions
 required by the GPL or the LGPL. If you do not delete the provisions above, a
 recipient may use your version of this file under the terms of any one of the
 MPL, the GPL or the LGPL.
 
 ***** END LICENSE BLOCK *****/

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "AuthDialog.h"


@interface WebPageController : UIViewController <UIWebViewDelegate>
{
  UIWebView*  webView;
  UIView*     headerView;
  UIView*     footerView;
  
  UIActivityIndicatorView *spinner;
  
  UILabel*                  titleString;
  UIImageView*              topHeader;
  UIBarButtonItem*          forwardButton;
  UIBarButtonItem*          backButton;
  UIBarButtonItem*          actionButton;
  
  //this is used to store the current orientation of the web view controller.
  //Sometimes it is off-screen, and the [controller interfaceOrientation] is not updated in that case,
  // so I must keep track of it on my own.
  UIInterfaceOrientation currentOrientation;
  
  NSURLAuthenticationChallenge* _challenge;
  NSURLRequest*                 _location;
  NSURLConnection*              _connection;
  NSURL*                        _basicAuthEnhancedDestinationURL;

  NSURL* _locationURL; // The original URL that we were asked to load. We keep it around for the Share functionality.
}

@property (nonatomic, retain) IBOutlet UIView *headerView;
@property (nonatomic, retain) IBOutlet UIView *footerView;


@property (nonatomic, retain) IBOutlet UILabel *titleString;
@property (nonatomic, retain) IBOutlet UIImageView *topHeader;

@property (nonatomic, retain) IBOutlet UIWebView *webView;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *spinner;

@property (nonatomic, retain) IBOutlet UIBarButtonItem* forwardButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* backButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* actionButton;

@property UIInterfaceOrientation currentOrientation;


- (void) loadLocation:(NSString*)location withTitle: (NSString*)title;
- (void) stopLoadingAndAnimation;

- (IBAction) done: (id)sender;
- (IBAction) forward:(id)sender;
- (IBAction) back: (id)sender;
- (IBAction) reload: (id)sender;
- (IBAction) exportURL: (id)sender;

// Helper function that either opens the URL in the built-in browser or in a native app
+ (void) openURL: (NSString*) destination withTitle: (NSString*) title;

@end
