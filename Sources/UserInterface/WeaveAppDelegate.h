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

#import "Store.h";
#import "CryptoUtils.h"
#import "Reachability.h"

#import "SearchResultsController.h"
#import "TabBrowserController.h"
#import "BookmarkNav.h"
#import "WebPageController.h"
#import "SettingsController.h"

//#define TESTING

@interface WeaveAppDelegate : NSObject <UIApplicationDelegate, UIAlertViewDelegate> 
{
  UIWindow*                 window;
  UITabBarController*       tabBarController;
  SearchResultsController*  searchResults;
  TabBrowserController*     tabBrowser;
  BookmarkNav*              bookmarkNav;
  WebPageController*        webController;
  SettingsController*       settings;
    
  BOOL                      hasInternetConnectivity;
  Reachability*             internetReach;

  //this is used to store the current orientation of the TabBarController.
  //Sometimes it is off-screen, and the [controller interfaceOrientation] is not updated in that case,
  // so I must keep track of it on my own.
  UIInterfaceOrientation currentOrientation;
}

//put up an alert explaining what just went wrong
- (void) reportErrorWithInfo: (NSDictionary*)errInfo;

//put up an alert view specific to authentication issues, allowing the user to either ignore the problem, or sign out
- (void) reportAuthErrorWithMessage: (NSDictionary*)errInfo;

- (BOOL) canConnectToInternet;

- (void) startProgressSpinnersWithMessage:(NSString*)msg;
- (void) changeProgressSpinnersMessage:(NSString*)msg;
- (void) stopProgressSpinners;


- (void) refreshViews;
- (void) login;
- (void) eraseAllUserData;

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;

//we need to keep views that aren't currently displayed in the proper orientation so we _can_ display them
- (void) rotateFullscreenView: (UIView*)theView toOrientation: (UIInterfaceOrientation)orientation;


@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet UITabBarController *tabBarController;
@property (nonatomic, retain) IBOutlet WebPageController *webController;

@property (nonatomic, retain)  SearchResultsController *searchResults;
@property (nonatomic, retain)  TabBrowserController *tabBrowser;
@property (nonatomic, retain)  BookmarkNav *bookmarkNav;
@property (nonatomic, retain)  SettingsController *settings;

@property UIInterfaceOrientation currentOrientation;

@end


@interface UITabBarController (Rotation)
- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration;
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation;
@end