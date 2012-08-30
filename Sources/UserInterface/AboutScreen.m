//
//  AboutScreen.m
//  Weave
//
//  Created by Dan Walkowski on 6/24/10.
//  Copyright 2010 ClownWare. All rights reserved.
//

#import "AboutScreen.h"
#import "WeaveAppDelegate.h"
#import "Stockboy.h"
#import "TapActionController.h"


@implementation AboutScreen

- (IBAction) done
{
  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
  [[appDelegate settings] dismissModalViewControllerAnimated:YES];
}

- (IBAction) termsOfService
{
  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
  
  if ([appDelegate canConnectToInternet])
  {
    [[appDelegate settings] dismissModalViewControllerAnimated:NO];

    NSString* destString = [Stockboy getURIForKey:@"TOS URL"];

    WebPageController* web = [appDelegate webController];
    [TapActionController slideWebBrowserIn]; 
    [web loadLocation: destString withTitle: NSLocalizedString(@"Terms Of Service", @"terms of service")];
  }
  else 
  {
    //no connectivity, put up alert
    NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Cannot Load Page", @"unable to load page"), @"title", 
                             NSLocalizedString(@"No internet connection available", "no internet connection"), @"message", nil];
    [appDelegate performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];      
  }
}

- (IBAction) privacyPolicy
{
  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
  
  if ([appDelegate canConnectToInternet])
  {
    [[appDelegate settings] dismissModalViewControllerAnimated:NO];
    
    NSString* destString = [Stockboy getURIForKey:@"PP URL"];
    
    WebPageController* web = [appDelegate webController];
    [TapActionController slideWebBrowserIn]; 
    [web loadLocation: destString withTitle: NSLocalizedString(@"Privacy Policy", @"privacy policy")];
  }
  else 
  {
    //no connectivity, put up alert
    NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Cannot Load Page", @"unable to load page"), @"title", 
                             NSLocalizedString(@"No internet connection available", "no internet connection"), @"message", nil];
    [appDelegate performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];      
  }  
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
  hasRotatedOnce = NO;
}



// Override to allow orientations other than the default portrait orientation.
//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
//{
//  return NO;
//}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end
