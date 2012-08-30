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

#import "AccountHelp.h"
#import "Stockboy.h"
#import "WeaveAppDelegate.h"

@implementation AccountHelp

@synthesize emailAddr;

//I most likely need to do this http request in a background thread, in case the network is slow, so that I can put up a spinner
- (IBAction) sendEmail:(id)sender
{
  WeaveAppDelegate *delegate = (WeaveAppDelegate*)[[UIApplication sharedApplication] delegate];

  if ([delegate canConnectToInternet])
  {
    //send the email address to Mozilla
    NSString* email = [emailAddr text];  //perhaps we should check to see if this looks like a valid email address
                   
    NSString* currentLocale = [[NSLocale currentLocale] localeIdentifier];

    NSString* destString = [Stockboy getURIForKey:@"Email Submit"];
        
    NSURL* destURL = [NSURL URLWithString:destString];
    NSMutableURLRequest* postRequest = [NSMutableURLRequest requestWithURL:destURL];
    [postRequest setHTTPMethod:@"POST"];
    
    NSString *stringBoundary = [NSString stringWithFormat:@"FFH%@HFF", [NSDate date]];

    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",stringBoundary];
    [postRequest addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    NSMutableData* postBody = [NSMutableData data];
    [postBody appendData:[[NSString stringWithFormat:@"\r\n\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"email\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithString:email] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"locale\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithString:currentLocale] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"campaign\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithString:@"firefox-home-instructions"] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [postBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [postRequest setHTTPBody:postBody];
    
    
    //now submit it
    NSHTTPURLResponse* response = nil;
    NSError* error = nil;
      
    [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];    
    NSDictionary* errInfo = nil;
    
    if ([response statusCode] == 201)
    {
      errInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Thank you!", @"thank you for submitting"), @"title", 
                 NSLocalizedString(@"Instructions are on the way", @"we will send instructions"), @"message", nil];
    }
    else if ([response statusCode] == 409)
    {
      errInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Duplicate", @"duplicate email address"), @"title", 
                 NSLocalizedString(@"That email address has already been submitted", @"the email address already exists in our database"), @"message", nil];
    }    
    else 
    {
      NSString* errMsg = [NSString stringWithFormat:NSLocalizedString(@"Unable to submit your email, please try again later (%d)", @"unable to submit email"), [response statusCode]]; 
      errInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Problem", @"title", errMsg, @"message", nil];
    }
    
    [delegate performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];

  }
  else 
  {
    //no connectivity, put up alert
    NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Cannot Submit", @"cannot submit email"), @"title", 
                             NSLocalizedString(@"No internet connection available", "no internet connection"), @"message", nil];
    [delegate performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];
  }

  [self dismissModalViewControllerAnimated:YES];
}

- (IBAction) cancel:(id) sender
{
	[self dismissModalViewControllerAnimated: YES];
}

@end
