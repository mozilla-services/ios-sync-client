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

//This is certainly not my best code.  It needs cleanup and refactoring.
// The current state is a result of a number of rapid fixes to page handling,
// working around several bugs in UIWebView, introduced by Apple in OS 3.2/4.0

#import "WebPageController.h"
#import "WeaveAppDelegate.h"
#import "TapActionController.h"
#import "NSURL+IFUnicodeURL.h"


/**
 * Returns TRUE for links that MUST be opened with a native application.
 */

static BOOL IsNativeAppURLWithoutChoice(NSString* link)
{
	if (link != nil)
	{
		NSURL* url = [NSURL URLWithUnicodeString: link];
		if (url != nil)
		{
			// Basic case where it is a link to one of the native apps that is the only handler.
		
			static NSSet* nativeSchemes = nil;
			if (nativeSchemes == nil)
			{
				nativeSchemes = [[NSSet setWithObjects: @"mailto", @"tel", @"sms", @"itms", nil] retain];
			}

			if ([nativeSchemes containsObject: [url scheme]])
			{
				return YES;
			}
			
			// Special case for handling links to the app store. See  http://developer.apple.com/library/ios/#qa/qa2008/qa1629.html
			// and http://developer.apple.com/library/ios/#qa/qa2008/qa1633.html for more info. Note that we do this even is
			// Use Native Apps is turned off. I think that is the right choice here since there is no web alternative for the
			// store.
					
			else if ([[url scheme] isEqual:@"http"] || [[url scheme] isEqual:@"https"])
			{
			
				// Disabled this case. We now simply trigger on itunes.apple.com or phobos.apple.com. The worst thing
				// that can happen is that Safari is launched. We can live with that.
			
	//			if ([[url host] isEqualToString: @"phobos.apple.com"] || [[url host] isEqualToString: @"itunes.apple.com"])
	//			{
	//				if ([[url path] isEqualToString: @"/WebObjects/MZStore.woa/wa/viewSoftware"])
	//				{
	//					[[UIApplication sharedApplication] openURL: url];
	//					return NO;
	//				}
	//			}

				if ([[url host] isEqualToString: @"itunes.com"])
				{
					if ([[url path] hasPrefix: @"/apps/"])
					{
						return YES;				
					}
				}
				else if ([[url host] isEqualToString: @"phobos.apple.com"] || [[url host] isEqualToString: @"itunes.apple.com"])
				{
					return YES;				
				}
			}
		}
	}
	
	return NO;
}

/**
 * Returns TRUE is the url is one that can be opened with a native application.
 */

static BOOL IsNativeAppURL(NSString* link)
{
	if (link != nil)
	{
		NSURL* url = [NSURL URLWithUnicodeString: link];
		if (url != nil)
		{
			if ([[url scheme] isEqualToString: @"http"] || [[url scheme] isEqualToString: @"https"])
			{
				// Try to recognize Google Maps URLs. We are a bit relaxed with google urls because it seems that iOS also
				// recogizes maps.google.nl. Apple says ditu.google.com is also valid but I have never seen that used.
				
				if ([[url host] hasPrefix: @"maps.google."] || [[url host] hasPrefix: @"ditu.google."])
				{
					if ([[url path] isEqualToString: @"/maps"] || [[url path] isEqualToString: @"/local"] || [[url path] isEqualToString: @"/m"])
					{
						return YES;
					}
				}

				// Try to recognize YouTube URLs
				
				if ([[url host] isEqualToString: @"www.youtube.com"])
				{
					if ([[url path] isEqualToString: @"/watch"] || [[url path] hasPrefix: @"/v/"])
					{
						return YES;
					}
				}
			}
		}
	}

	return NO;
}

/**
 * Returns TRUE is the url is one that should be opened in Safari. These are HTTP URLs that we do not
 * recogize as URLs to native applications.
 */

static BOOL IsSafariURL(NSString* url)
{
	return (url != nil) && IsNativeAppURL(url) == NO && ([url hasPrefix: @"http://"] || [url hasPrefix: @"https://"]);
}

/**
 * Returns TRUE if the url is one that should not be opened at all. Currently just used to
 * prevent file:// and javascript: URLs.
 */

static BOOL IsBlockedURL(NSString* url)
{
	return [url hasPrefix: @"file:"] || [url hasPrefix: @"javascript:"];
}

@interface WebPageController (Private)
- (void) displayCredentialRequestScreen;
@end


@implementation WebPageController

@synthesize headerView;
@synthesize footerView;

@synthesize titleString;
@synthesize topHeader;
@synthesize forwardButton;
@synthesize backButton;
@synthesize actionButton;

@synthesize webView;
@synthesize spinner;
@synthesize currentOrientation;


- (void) updateForwardBackButtons
{
  if ([webView canGoBack]) [backButton setEnabled:YES];
  else [backButton setEnabled:NO];
  
  if ([webView canGoForward]) [forwardButton setEnabled:YES];
  else [forwardButton setEnabled:NO];
  
  NSString* newTitle = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
  if ([newTitle length] > 0) titleString.text = newTitle; 
}

- (void) setUIForLoading
{
  [actionButton setEnabled:NO];
  [backButton setEnabled:NO];
  [forwardButton setEnabled:NO];
  
  [spinner startAnimating];
  [spinner setHidden:NO];
}

- (void) setUIForStopped
{
  [actionButton setEnabled:YES];
  [self updateForwardBackButtons];
  
  [spinner setHidden:YES];
  [spinner stopAnimating];
}


- (void) stopLoadingAndAnimation
{
  [webView stopLoading];
  [self setUIForStopped];
}



- (void) loadLocation:(NSString*)location withTitle:(NSString*)title
{  
  [actionButton setEnabled:NO];
  
  [webView stringByEvaluatingJavaScriptFromString:@"document.documentElement.innerHTML = ''"];
  titleString.text = title;
  
  [self setUIForLoading];

	// Keep the original location around. We might need it later for the Share functionality.

	[_locationURL release];
	_locationURL = nil;
	
	_locationURL = [[NSURL URLWithUnicodeString:location] retain];

  if (_locationURL == nil)
  {
    [self stopLoadingAndAnimation];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error Loading Page", @"error loading page") message:NSLocalizedString(@"Invalid URL", @"invalid url")
                                                   delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"ok") otherButtonTitles: nil];
    [alert show];
    [alert release];   
  }
  else 
  {
    [webView loadRequest:[NSURLRequest requestWithURL:_locationURL]];
  }

}


//Handlers for the buttons
- (IBAction)done:(id)sender 
{
  [webView stopLoading];
  
  _challenge = nil;
  [_location release];
  _location = nil;
  
  [_connection cancel];
  [_connection release];
  _connection = nil;
  
  
  [TapActionController slideWebBrowserOut];
}

- (IBAction) forward:(id)sender
{
  titleString.text = NSLocalizedString(@"loading...", @"loading web page");
  [webView goForward];
}

- (IBAction) back:(id)sender
{
  titleString.text = NSLocalizedString(@"loading...", @"loading web page");
  [webView goBack];
}


- (IBAction) reload:(id)sender
{
  [webView stopLoading];
  if (_location) 
  {
    NSURLRequest* temp = _location;
    _location = nil;
    [webView loadRequest:temp];
    [temp release];
  }
  else [webView reload];
}


- (IBAction) exportURL: (id)sender
{
	NSURL* rawURL = webView.request.URL;
		
	// After the page failed to load the URL is actually invalid. So check for that and fall back to the
	// original URL that we were asked to open. Not sure if this check is good enough.
	
	if ([[rawURL absoluteString] length] == 0) {
		rawURL = _locationURL;
	}
	
	// The URL might have a username:password embedded in it. So reconstruct it.

	NSMutableString* safeURLString = [NSMutableString stringWithFormat:@"%@://%@", [rawURL scheme], [rawURL host]];
	
	if ([rawURL port] != nil) {
		[safeURLString appendFormat: @":%@", [rawURL port]];
	}
	
	[safeURLString appendString: [rawURL path]];
	
	if ([rawURL query] != nil) {
		[safeURLString appendFormat: @"?%@", [rawURL query]];
	}
	
	if ([rawURL fragment] != nil) {
		[safeURLString appendFormat: @"#%@", [rawURL fragment]];
	}

	TapActionController* tap = [[TapActionController alloc] initWithLocation:safeURLString];
	if (tap != nil) {
		[tap chooseAction];
		[tap release];
	}
}


- (void)viewDidLoad 
{
  [super viewDidLoad];
  self.view.autoresizesSubviews = YES;
  self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  currentOrientation = UIInterfaceOrientationPortrait;
  _challenge = nil;
  _location = nil;
  _connection = nil;
}

#pragma mark -

//WEB VIEW DELEGATE METHODS

- (void)webViewDidStartLoad:(UIWebView *)wv 
{
  [self setUIForLoading];
}

- (void)webViewDidFinishLoad:(UIWebView *)wv 
{
  [self setUIForStopped];
  [_location release];
  _location = nil;
}


//there are too many spurious warnings, so I'm going to just ignore or log them all for now.
- (void)webView:(UIWebView *)theWebView didFailLoadWithError:(NSError *)error
{
  //ignore these
  if (error.code == NSURLErrorCancelled || [error.domain isEqualToString:@"WebKitErrorDomain"]) return;
  
  if ([error.domain isEqualToString:@"NSURLErrorDomain"])
  {
    [self stopLoadingAndAnimation];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error Loading Page", @"error loading page") message:[error localizedDescription]
                                                   delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"ok") otherButtonTitles: nil];
    [alert show];
    [alert release]; 
    return;
  }
}


/////////////////////////////////////
///////////////////////////////////////////////////////////
//Crazy basic-auth handling stuff
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	// We don't want to render some URLs like for example file URLs. Note that file URLs do not
	// actually go through this method. It seems that at least on iOS 4 the UIWebView does not
	// load them at all. But just to be on the safe side we do the check.

	if (IsBlockedURL([[request URL] absoluteString])) {
		return NO;
	}

	// When an application implements this UIWebView delegate method, it loses automatic handling of
	// 'special' urls. Like mailto: or app store links. We try to compensate for that here.

	if (IsNativeAppURLWithoutChoice([[request URL] absoluteString])) {
		[[UIApplication sharedApplication] openURL: [request URL]];
		return NO;
	}
	
	// If the link is to a native app and we have turned that on, let the OS open the link

	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey: @"useNativeApps"] && IsNativeAppURL([[request URL] absoluteString])) {
		[[UIApplication sharedApplication] openURL: [request URL]];
		return NO;
	}

	// This code is all wrong but I'm leaving it like this because we do not want to change the behaviour
	// at this moment. (Authenticated sites only work if they are https)

	if (_location == nil && [[[request URL] scheme] isEqualToString:@"https"] && ([[request HTTPMethod] isEqualToString:@"GET"]))
	{
		//NSLog(@"%@ to load (CHECK FOR AUTH): %@ has body:%@", [request HTTPMethod], [request URL], ([request HTTPBody]?@"YES":@"NO"));
		_location = [request retain];
		NSMutableURLRequest* authReq = [[request copy] autorelease];
		[authReq setHTTPMethod:@"HEAD"];
		_connection = [[NSURLConnection alloc] initWithRequest:authReq delegate:self];
		return NO;
	}
	else
	{
		//NSLog(@"%@ to load: %@ has body:%@", [request HTTPMethod], [request URL], ([request HTTPBody]?@"YES":@"NO"));
		return YES;
	}
}



- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
  //NSLog(@"challenged for %@", connection);
  _challenge = challenge;
  [self performSelector:@selector(displayCredentialRequestScreen) withObject: nil afterDelay:0.5];
}


- (void) displayCredentialRequestScreen
{
  AuthDialog* authingie = [[AuthDialog alloc] init];
  [self presentModalViewController: authingie animated:YES];
  [authingie release];
}


- (void) authenticateWith:(NSDictionary*)nameAndPass
{
  [self dismissModalViewControllerAnimated:YES];
  
  //NSLog(@"authenticating");
  
  /////////////
//  NSURLProtectionSpace *pSpace = [[NSURLProtectionSpace alloc]
//                                 initWithHost:[_location host]
//                                 port:80
//                                 protocol:@"http"
//                                 realm:nil
//                                 authenticationMethod:nil];
  /////////////
  
  
  NSURLCredential* cred = [NSURLCredential credentialWithUser:[nameAndPass objectForKey:@"name"] 
                                                     password:[nameAndPass objectForKey:@"pass"] 
                                                  persistence:NSURLCredentialPersistenceForSession];
  
  NSURL* locURL = [_location URL];
  NSString* escapedName = [NSString urlEncodeValue:[nameAndPass objectForKey:@"name"]];
  NSString* escapedPass = [NSString urlEncodeValue:[nameAndPass objectForKey:@"pass"]];
  NSString* authString = [NSString stringWithFormat:@"%@:%@", escapedName, escapedPass];
  NSString* doctoredURLString = [NSString stringWithFormat:@"%@://%@@%@%@", 
                                 [locURL scheme],
                                 authString,
                                 [locURL host],
                                 [locURL path]];
                                 
  _basicAuthEnhancedDestinationURL = [[NSURL URLWithString:doctoredURLString] retain];
  
  ///////////
//  [[NSURLCredentialStorage sharedCredentialStorage]
//   setDefaultCredential:cred
//   forProtectionSpace:pSpace];
  /////////////
  
  [[_challenge sender] useCredential:cred forAuthenticationChallenge:_challenge];
  _challenge = nil;
}


- (void) cancelAuth
{
  [self dismissModalViewControllerAnimated:YES];
  
  //NSLog(@"authentication cancelled");
  [[_challenge sender] cancelAuthenticationChallenge:_challenge];
  _challenge = nil;
  
  [_connection cancel];
  [_connection release];
  _connection = nil;
    
  
  [spinner setHidden:YES];
  [spinner stopAnimating];
  
}


//302 redirect
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)redirectRequest redirectResponse:(NSURLResponse *)redirectResponse
{
  
  if (connection == _connection)
  {
    if ([[redirectRequest URL] isEqual:[_location URL]])
    {
      //NSLog(@"REDIRECT %@ to (SAME): %@ has body:%@", [redirectRequest HTTPMethod], [redirectRequest URL], ([redirectRequest HTTPBody]?@"YES":@"NO"));

      return redirectRequest;
    }
    else 
    {
      //NSLog(@"REDIRECT %@ to (DIFFERENT): %@ has body:%@", [redirectRequest HTTPMethod], [redirectRequest URL], ([redirectRequest HTTPBody]?@"YES":@"NO"));

      if ([_location HTTPBody] && [[redirectRequest HTTPMethod] isEqualToString:@"POST"])
      {
        //make a new redirect, copy the body, and send that instead
        NSMutableURLRequest* redirectWithBody = [redirectRequest copy];
        [redirectWithBody setHTTPBody:[_location HTTPBody]];
        [webView loadRequest:redirectWithBody];
      }
      else 
      {
        [webView loadRequest:redirectRequest];
      }

      
      [_location release];
      _location = nil;

      return nil;
    } 
  }
  return redirectRequest;
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
  if (connection == _connection)
  {
    if (_basicAuthEnhancedDestinationURL)
    {
      [webView loadRequest:[NSURLRequest requestWithURL:_basicAuthEnhancedDestinationURL]];
      [_basicAuthEnhancedDestinationURL release];
      _basicAuthEnhancedDestinationURL = nil;
    }
    else 
    {
      [webView loadRequest:_location];
    }

  }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
  if (connection == _connection)
  {
    [_connection cancel];
    [_connection release];
    _connection = nil;
        
  }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  if (connection == _connection)
  {
    [_connection cancel];
    [_connection release];
    _connection = nil;
        
  }
}



////////////////////////////////////

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}



- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
  CGRect f, newFrame;
  BOOL fromVertical = (currentOrientation == UIInterfaceOrientationPortrait || currentOrientation == UIInterfaceOrientationPortraitUpsideDown);
  

  //This next block of code adjusts the sizes of some of the views when we are in landscape mode, to make themn fit better.
  // It changes them back when we go back to portrait mode
  if (!fromVertical && (toInterfaceOrientation == UIInterfaceOrientationPortrait || toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown))
  {
    //set the title font to 20
    titleString.font = [UIFont boldSystemFontOfSize:20];
    
    //change the background image in the header
    topHeader.image = [UIImage imageNamed:@"header.png"];
    
    f = headerView.frame;
    newFrame = CGRectMake(f.origin.x,
                          f.origin.y,
                          f.size.width,
                          f.size.height + 12);
    headerView.frame = newFrame;
    
    
    f = webView.frame;
    newFrame = CGRectMake(f.origin.x,
                          f.origin.y + 12,
                          f.size.width,
                          f.size.height - 12);
    webView.frame = newFrame;
        
  }
  else if (fromVertical && (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight))
  {
    //set the title font to 16
    titleString.font = [UIFont boldSystemFontOfSize:16];
    //change the background image in the header
    topHeader.image = [UIImage imageNamed:@"short_header.png"];
    
    
    f = headerView.frame;
    newFrame = CGRectMake(f.origin.x,
                          f.origin.y,
                          f.size.width,
                          f.size.height - 12);
    headerView.frame = newFrame;
    
    
    f = webView.frame;
    newFrame = CGRectMake(f.origin.x,
                          f.origin.y - 12,
                          f.size.width,
                          f.size.height + 12);
    webView.frame = newFrame;
    
  }
  
  //always update our current orientation, even if it didn't require adjusting the views
  currentOrientation = toInterfaceOrientation;

}

- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];

  [appDelegate.tabBarController willRotateToInterfaceOrientation:  currentOrientation duration:0];
  [appDelegate rotateFullscreenView:appDelegate.tabBarController.view toOrientation: currentOrientation];
}



- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
  webView = nil;
  headerView = nil;
  footerView = nil;
  spinner = nil;
  titleString = nil;
  topHeader = nil;
  forwardButton = nil;
  backButton = nil;
  actionButton = nil;
  
}


- (void)dealloc 
{
  webView.delegate = nil;
  [_locationURL release];
  _locationURL = nil;
  [super dealloc];
}

#pragma mark -

/**
 * Open the specified URL. Based on the type of URL and the user's settings, the URL is either
 * opened in the in-app browser, in a native app or in Safari.
 */

+ (void) openURL: (NSString*) destination withTitle: (NSString*) title
{
	if (IsBlockedURL(destination)) {
		WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
		NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Cannot Load Page", @"unable to load page"),
			@"title", NSLocalizedString(@"SyncClient cannot load the page because it is of an unsupported type.", "SyncClient cannot load the page because it is of an unsupported type."), @"message", nil];
		[appDelegate performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];      		
		return;
	}

	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	// We ask the system to open the URL if any of these cases is true:
	//  1) It is a link to a native app for which we have no choice (itms, tel, mailto)
	//  2) "Use Native Apps" is ON and this link is for Maps or YouTube
	//  3) "Open Pages in Safari" is ON
	// Otherwise we open the link in the built-in browser
	
	if (IsNativeAppURLWithoutChoice(destination) || ([defaults boolForKey: @"useNativeApps"] && IsNativeAppURL(destination)) || ([defaults boolForKey: @"useSafari"] && IsSafariURL(destination))) {
		[[UIApplication sharedApplication] openURL: [NSURL URLWithUnicodeString: destination]];
	} else {
		WeaveAppDelegate* appDelegate = (WeaveAppDelegate*) [[UIApplication sharedApplication] delegate];
		WebPageController* web = [appDelegate webController];
		[TapActionController slideWebBrowserIn];
		[web loadLocation: destination withTitle: title];
	}
}

@end
