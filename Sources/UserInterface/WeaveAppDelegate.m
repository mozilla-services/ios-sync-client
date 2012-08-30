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

#include <unistd.h>

#import "Store.h"
#import "Stockboy.h"
#import "WeaveAppDelegate.h"
#import "LogoutController.h"
#import "Reachability.h"
#import "CryptoUtils.h"
#import "Fetcher.h"
#import "WelcomePage.h"
#import "WebPageController.h"

#import "NSString+SHA.h"

@implementation UINavigationBar (CustomImage)
- (void)drawRect:(CGRect)rect
{
  UIImage *image = [UIImage imageNamed: @"header.png"];
  [image drawInRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
}
@end

@implementation WeaveAppDelegate

@synthesize window;

@synthesize tabBarController;
@synthesize searchResults;
@synthesize tabBrowser;
@synthesize bookmarkNav;
@synthesize settings;
@synthesize webController;
@synthesize currentOrientation;

- (void)fadeToMainPage 
{
  // add the new image to fade out
  UIImageView* defaultFadeImage = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Default.png"]] autorelease];
  [window addSubview:defaultFadeImage];
  
  // and start the default fadeout
  [UIView beginAnimations:@"InitialFadeIn" context:nil];
  [UIView setAnimationDelegate:defaultFadeImage];
  [UIView setAnimationDidStopSelector:@selector( removeFromSuperview )];
  [UIView setAnimationDelay:0.0]; // stay on this long extra
  [UIView setAnimationDuration:0.6]; // transition speed
  [defaultFadeImage setAlpha:0.0];
  [UIView commitAnimations];
}


///REACHABILITY NOTIFICATIONS

- (BOOL) canConnectToInternet
{
  return hasInternetConnectivity;
}


//we're just making sure the answer is not 'no', for now.  
// there are more elaborate things we can check if we like
- (void) updateConnectivityWith:(Reachability*) reacher
{
  NetworkStatus netStatus = [reacher currentReachabilityStatus];
  hasInternetConnectivity = (netStatus != NotReachable);
}


//Called by Reachability whenever status changes.
- (void) reachabilityChanged: (NSNotification* )note
{
	Reachability* curReach = [note object];
	if ([curReach isKindOfClass: [Reachability class]])
  {
    [self updateConnectivityWith: curReach];
  }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// This sleep is totally here to just show the new awesome Default.png. But only once after
	// the app is installed.
	
	if ([[NSUserDefaults standardUserDefaults] objectForKey: @"FFH_VERS"] == nil) {
		sleep(3);
	}

	// Setup the defaults
  
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	if (userDefaults != nil)
	{
		NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
		if (dictionary != nil)
		{
			[dictionary setObject: [NSNumber numberWithBool: NO] forKey: @"useCustomServer"];
			[dictionary setObject: [NSNumber numberWithBool: YES] forKey: @"useNativeApps"];
			[dictionary setObject: [NSNumber numberWithBool: NO] forKey: @"useSafari"];
			
			[[NSUserDefaults standardUserDefaults] registerDefaults: dictionary];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}

	// Workaround for #602419 - If the wifi is turned off, it acts as if a blank account is signed in
	// See a more detailed description in LogoutController

	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"needsFullReset"]) {
		[self eraseAllUserData];
	}
    
#ifdef TESTING 
  [Fetcher testBasicAuthHeaderGen];
  [CryptoUtils testHmacSha256];
#endif
  
  //update the version number in the Settings Pane
  [[NSUserDefaults standardUserDefaults] setValue:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] forKey:@"FFH_VERS"];

  [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:) name: kReachabilityChangedNotification object: nil];

  currentOrientation = UIInterfaceOrientationPortrait;
    
  //set up the thread condition, etc.
  [Stockboy prepare];
  
  internetReach = [[Reachability reachabilityForInternetConnection] retain];
	[internetReach startNotifier];
	[self updateConnectivityWith: internetReach];
  
  //a bit too many globals, but I want a handle to these guys so I can poke them
  searchResults = [[tabBarController viewControllers] objectAtIndex:0];
  tabBrowser = [[tabBarController viewControllers] objectAtIndex:1];
  bookmarkNav = [[tabBarController viewControllers] objectAtIndex:2];
  settings = [[tabBarController viewControllers] objectAtIndex:3];
  
  
  //force our view to load
  // we need it to be ready to accept urls to display
  [tabBrowser view];
  [bookmarkNav view];
  [settings view];
  [webController view];
  
	// Show window
  [window addSubview:tabBarController.view];
  
	//I need to do this to at least get my hierarchy of viewControllers to get the viewWillAppear method.
	// unexpectedly, this seems to wire everything up, and all my subviews get the viewDidAppear methods as well.
	[tabBarController viewWillAppear:YES];    
	
  [window makeKeyAndVisible];

  
  //check to see if we need to show them the "Hello!" page
  // We will set this to true once the user has logged in successfully at least once
	BOOL showedFirstRunPage = [[NSUserDefaults standardUserDefaults] boolForKey:@"showedFirstRunPage"];
	
  if (!showedFirstRunPage)
  {
    //now show them the first launch page, which asks them if they have an account, or need to find out how to get one
    // afterwards, they will be taken to the login page, one way or ther other
    WelcomePage* welcomePage = [[WelcomePage new] autorelease];
	if (welcomePage != nil) {
		[tabBarController presentModalViewController: welcomePage animated: NO];
	}
  }
  else
  {
    //show the main page, and start up the Stockboy to get fresh data
    [Stockboy restock];
  }
  
  [self fadeToMainPage];
  
  return NO;
}

- (void)applicationWillTerminate:(UIApplication *)application 
{
  //we might need cleanup, or state saving (launch back to the same page?)
  
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  //stop timers, threads, spinner animations, etc.
  // note the time we were suspended, so we can decide whether to do a refresh when we are resumed
  [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"backgroundedAtTime"];
  [self stopProgressSpinners];
  [Stockboy cancel];
  [webController stopLoadingAndAnimation];
}

#define FIVE_MINUTES_ELAPSED (60 * 5)

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Workaround for #602419 - If the wifi is turned off, it acts as if a blank account is signed in
	// See a more detailed description in LogoutController

	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"needsFullReset"]) {
		[self eraseAllUserData];
		return;
	}

  //check to see if we were suspended for 5 minutes or more, and refresh if true
  double slept = [[NSUserDefaults standardUserDefaults] doubleForKey:@"backgroundedAtTime"];
  double now =[[NSDate date] timeIntervalSince1970];
  
  if ((now - slept) >= FIVE_MINUTES_ELAPSED)
  {
    [Stockboy restock];
  }
}

- (void) login
{
	[self eraseAllUserData];
	
	WelcomePage* welcomePage = [[WelcomePage new] autorelease];
	if (welcomePage != nil) {
		[tabBarController presentModalViewController: welcomePage animated: NO];
	}
}

- (void) deleteCookies
{
	NSHTTPCookieStorage* storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
	NSHTTPCookie *cookie;
	for (cookie in [storage cookies])  {
		[storage deleteCookie: cookie];
	}
}
   

- (void) eraseAllUserData
{		
  //erase the local database
  [Store deleteStore];
  //toss the crypto stuff we have
  [CryptoUtils discardManager];
  //delete the private key from the keychain
  [CryptoUtils deletePrivateKeys];
  //delete the web browser cookies
  [self deleteCookies];

	// Workaround for #602419 - If the wifi is turned off, it acts as if a blank account is signed in
	// See a more detailed description in LogoutController
	
//	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"useCustomServer"];
//	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"customServerURL"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"showedFirstRunPage"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"needsFullReset"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"backgroundedAtTime"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"useSafari"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"useNativeApps"];
	[[NSUserDefaults standardUserDefaults] synchronize];

  //delete the web browser view, because there's no way to clear the history
  [webController release];
  webController = nil;
  //reload a new web browser view
  webController = [[WebPageController alloc] initWithNibName:nil bundle:nil];
  //redraw everything
  [self refreshViews];  //make them all ditch their data
}


//this alert has no other button than cancel, so it needs no delegate
- (void) reportErrorWithInfo: (NSDictionary*)errInfo
{
  UIAlertView* alert = [[UIAlertView alloc] initWithTitle:[errInfo objectForKey:@"title"] message:[errInfo objectForKey:@"message"] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"ok") otherButtonTitles:nil];
  [alert show];
  [alert release];
}



//this is the callback that will be called by the method just below this one, when a button is clicked.
// it only has two buttons, '0' = Cancel (so we do nothing) or '1' = sign in
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
  //this handler is only called by the alert made directly below, so we know that button 1 is the signout button
  if (buttonIndex == 1) //sign out
  {
    [self login]; //also erases user data
  }
}


//this alert has a cancel and a 'sign in' button, so it needs a delegate
- (void) reportAuthErrorWithMessage: (NSDictionary*)errInfo
{
	UIAlertView* alert = [[UIAlertView alloc] initWithTitle: [errInfo objectForKey:@"title"]
		message:[errInfo objectForKey:@"message"] delegate:self 
			cancelButtonTitle:NSLocalizedString(@"Not Now", @"Not Now")
				otherButtonTitles:NSLocalizedString(@"Sign In", @"re-authenticate"), nil];
	[alert show];
	[alert release];
}


//called on main thread by the stockboy background thread
- (void) startProgressSpinnersWithMessage:(NSString*)msg
{
	[settings startSpinnerWithMessage:msg];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"SyncStatusChanged"
		object: nil userInfo: [NSDictionary dictionaryWithObject: msg forKey: @"Message"]];
}

- (void) changeProgressSpinnersMessage:(NSString*)msg
{
  [settings changeSpinnerMessage:msg];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"SyncStatusChanged"
		object: nil userInfo: [NSDictionary dictionaryWithObject: msg forKey: @"Message"]];
}

//called on main thread by the stockboy background thread
- (void) stopProgressSpinners
{
  [settings stopSpinner];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"SyncStatusChanged"
		object: nil userInfo: [NSDictionary dictionaryWithObject: @"" forKey: @"Message"]];
}


- (void) refreshViews
{
  [searchResults refresh];
  [tabBrowser refresh];
  [bookmarkNav refresh];
  [settings refresh];
}

-(void) dealloc 
{
  [internetReach release];
  [tabBarController release];
  [window release];
	[super dealloc];
}

#define deg0 0
#define deg90 (3.14159/2.0)
#define deg180 (deg90 * 2)
#define deg270 (deg90 * 3)


//No, this obviously won't work on a phone with a different resolution screen.
- (void) rotateFullscreenView: (UIView*)theView toOrientation: (UIInterfaceOrientation)orientation
{
  CGFloat angle = deg0;
  CGPoint newCenter; 
  CGRect newBounds;
  
  switch (orientation)
  {
    case UIInterfaceOrientationPortrait:
      angle = deg0;
      newBounds = CGRectMake(0, 0, 320, 460);
      newCenter = CGPointMake(320/2, (460/2)+20);
      break;
    case UIInterfaceOrientationPortraitUpsideDown:
      angle = deg180;
      newBounds = CGRectMake(0, 0, 320, 460);
      newCenter = CGPointMake(320/2, (460/2));
      break;
    case UIInterfaceOrientationLandscapeLeft:
      angle = deg270;
      newBounds = CGRectMake(0, 0, 480, 300);
      newCenter = CGPointMake((300/2)+20, 480/2);
      break;
    case UIInterfaceOrientationLandscapeRight:
      angle = deg90;
      newBounds = CGRectMake(0, 0, 480, 300);
      newCenter = CGPointMake((300/2), 480/2);
      break;
  }
  
  CGAffineTransform transform = CGAffineTransformMakeRotation(angle);
  theView.transform = transform;
  theView.bounds = newBounds;  
  theView.center = newCenter;
}



@end


@implementation UITabBarController (Rotation)

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
  //this isn't being called on my subviews, for reasons I don't understand, so I pass it along explicitly here
  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
  [[appDelegate settings] willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
  [[appDelegate searchResults] willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
  [[appDelegate tabBrowser] willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
  appDelegate.currentOrientation = toInterfaceOrientation;
}


- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
  
  [appDelegate.webController willRotateToInterfaceOrientation: appDelegate.currentOrientation duration:0];
  [appDelegate rotateFullscreenView:appDelegate.webController.view toOrientation: appDelegate.currentOrientation];
}
@end
