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
#import <QuartzCore/QuartzCore.h>
#import "TapActionController.h"
#import "WeaveAppDelegate.h"
#import "WebPageController.h"
#import "Stockboy.h"
#import "NSURL+IFUnicodeURL.h"


@implementation TapActionController

- (id) initWithLocation:(NSString*)loc
{
  if ((self = [super init])) 
  {
    location = [loc retain];
		[self retain]; // I am responsible for cleaning up after myself
  }
  return self;
}

//View sliding methods
+ (void) slideWebBrowserIn
{
  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];

  
  // get the root view, so we can slide things in and out of it
  UIView *parentView = appDelegate.window;
  
  // get the normal content view, rootview
  UIView *contentView = appDelegate.tabBarController.view;
  
  //get the web browser view
  UIView *webView = appDelegate.webController.view;
  
  
  // remove the tab bar view, and insert the web view
  [contentView removeFromSuperview];
  
  [parentView addSubview:webView];

  NSString *direction = kCATransitionFromLeft;
  
  switch (appDelegate.currentOrientation) {
    case UIInterfaceOrientationPortrait:
      direction = kCATransitionFromRight;
      break;
    case UIInterfaceOrientationPortraitUpsideDown:
      direction = kCATransitionFromLeft;
      break;        
    case UIInterfaceOrientationLandscapeLeft:
      direction = kCATransitionFromBottom;
      break;
    case UIInterfaceOrientationLandscapeRight:
      direction = kCATransitionFromTop;
      break;
  }
  
  // animate the change we just made
  CATransition *animation = [CATransition animation];
  [animation setDuration:0.25];
  [animation setType:kCATransitionPush];
  [animation setSubtype:direction];
  [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
  
  [[parentView layer] addAnimation:animation forKey:@"showWebView"];

}  

+ (void) slideWebBrowserOut
{
  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
  
  // get the root view, so we can slide things in and out of it
  UIView *parentView = appDelegate.window;

  // get the normal content view, the tab bar controller
  UIView *contentView = appDelegate.tabBarController.view;
  
  //get the web browser view
  UIView *webView = appDelegate.webController.view;
  
  
  // remove the web view, and insert the tab bar view
  [webView removeFromSuperview];
  
  [parentView addSubview:contentView];

  NSString *direction = kCATransitionFromLeft;

  switch (appDelegate.webController.currentOrientation) {
    case UIInterfaceOrientationPortrait:
      direction = kCATransitionFromLeft;
      break;
    case UIInterfaceOrientationPortraitUpsideDown:
      direction = kCATransitionFromRight;
      break;      
    case UIInterfaceOrientationLandscapeLeft:
      direction = kCATransitionFromTop;
      break;
    case UIInterfaceOrientationLandscapeRight:
      direction = kCATransitionFromBottom;
      break;
  }
  
  
  // animate the change we just made
  CATransition *animation = [CATransition animation];
  [animation setDuration:0.25];
  [animation setType:kCATransitionPush];
  [animation setSubtype:direction];
  [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
  
  [[parentView layer] addAnimation:animation forKey:@"showTabBar"];
}  


//ActionSheet methods
//this presents the 'what do you want to do now?' sheet that slides up when you choose a web destination from any of the lists
- (void) chooseAction
{
    UIActionSheet *action = [[UIActionSheet alloc]initWithTitle:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"cancel") 
                                         destructiveButtonTitle:nil 
                                              otherButtonTitles:NSLocalizedString(@"View in Safari", @"launch safari to display the url"), 
                                                                NSLocalizedString(@"Email URL", @"send the url via email"), 
                                                                NSLocalizedString(@"Copy URL", @"copy the url to the clipboard"), nil];
    

    WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
    [action showFromTabBar:appDelegate.tabBarController.tabBar];
    [action release];
}



- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	// Incorrectly using URLWithUncodeString here. Fix for #575888 - "FF Home unable to open double-byte"
	// pages in Safari. This is a workaround and can be taken out when the desktop correctly encoded urls as
	// noted in #586082.
  
	NSURL* url = [NSURL URLWithUnicodeString: location];
  
	switch (buttonIndex)
	{
		case 0: //safari
    {
			if (![[UIApplication sharedApplication] openURL: url]) {
				NSLog(@"Unable to open url '%@'", location);
			}
			break;
    }
		case 1: //email
		{
			NSString *emailSubject = NSLocalizedString(@"Sending you a link", @"email subject");
			NSString *emailContent = NSLocalizedString(@"Here is that site we talked about:", @"email content");
			NSString *content = [NSString stringWithFormat:@"subject=%@&body=%@\n%@", emailSubject, emailContent, [url absoluteString]];  
			NSString *mailto = [NSString stringWithFormat:@"mailto:?%@", [content stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];  
      
			NSURL* mailtoURL = [NSURL URLWithString: mailto];  
			if ([[UIApplication sharedApplication] canOpenURL: mailtoURL]) {
				[[UIApplication sharedApplication] openURL: mailtoURL];
			} else {
				NSLog(@"Cannot send email: unavailable or unconfigured");
			}
      
			break;
		}
		case 2: //copy 
		{
			UIPasteboard *pboard = [UIPasteboard generalPasteboard];
			pboard.URL = url;
			pboard.string = [url absoluteString];
			break;	
		}
		case 3: //cancel, do nothing
		{
			break;
		}
	}
  [self release];
}



- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc 
{
  [location release];
  [super dealloc];
}


@end
