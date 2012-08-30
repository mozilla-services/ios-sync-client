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
	Stefan Arentz <stefan@arentz.ca>

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

#import "Fetcher.h"
#import "JSON.h"
#import "Utility.h"
#import "ASIHTTPRequest.h"


@implementation Fetcher

+ (NSData*) getBytesFromPublicURL: (NSString*) url
{
	if (url == nil) {
		NSLog(@"Fetcher was called with nil URL!");
		return nil;
	}
	
	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL: [NSURL URLWithString:url]];
	//[request setValidatesSecureCertificate: NO];
	[request startSynchronous];

	if ([request error] != nil || [request responseStatusCode] != 200) {
		return nil;
	}
	
	return [request responseData];
}  

+ (NSData*) getWeaveBasicObject:(NSString*)url authenticatingWith:(CryptoUtils*)cryptoManager
{	
	NSString *full = [cryptoManager absoluteURLForEngine: url];
	return [Fetcher getBytesFromURL:full authenticatingWith:cryptoManager];
}

//expects UTF8 encoded strings in the user and password data objects
+ (NSData *)getBytesFromURL:(NSString*)url authenticatingWith:(CryptoUtils*)cryptoManager
{
	//NSLog(@"Fetcher#getBytesFromURL:authenticatingWith: url=%@", url);

	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL: [NSURL URLWithString: url]];
	//[request setValidatesSecureCertificate: NO];
	[request setTimeOutSeconds: 60.0];
	[request setUsername: [cryptoManager username]];
	[request setPassword: [cryptoManager password]];
	[request startSynchronous];

	NSError* error = [request error];

	if (request.responseStatusCode != 0)
	{
		switch (request.responseStatusCode) 
		{
			case 200: //if it's 200, then everything is fine, and we continue
				break;

			case 401:
				[NSException raise:AUTH_EXCEPTION_STRING format:NSLocalizedString(@"Incorrect Password", @"incorrect password"), nil];
				return nil;
				break;

			case 500:
			case 501:
			case 502:
			case 503:
			case 504:
			case 505:
				[NSException raise:@"ConnectFail" format: NSLocalizedString(@"Unable To Communicate With Server (%d)", @"unable to communicate with server"), request.responseStatusCode];
				return nil;
				break;

			default:
				NSLog(@"### unexpected http error: %d", request.responseStatusCode);
				return nil;
				break;
		}
	}
	else if (error != nil)
	{
		[NSException raise:@"ConnectFail" format:NSLocalizedString(@"Failed To Communicate With Server (%d)", @"failed to communicate with server"), error.code];
		return nil;
	}
	
	return [request responseData];
}

+ (NSData*) putWeaveBasicObject:(NSData*)object toURL:(NSString*)url authenticatingWith:(CryptoUtils*)cryptoManager
{	
	return [Fetcher putBytes: object toURL: [cryptoManager absoluteURLForEngine:url] authenticatingWith:cryptoManager];
}

+ (NSData *)putBytes:(NSData *)data toURL:(NSString *)url authenticatingWith:(CryptoUtils*)cryptoManager
{
	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL: [NSURL URLWithString: url]];
	//[request setValidatesSecureCertificate: NO];
	[request setTimeOutSeconds: 60.0];
	[request setUsername: [cryptoManager username]];
	[request setPassword: [cryptoManager password]];
	[request appendPostData: data];
	[request setRequestMethod:@"PUT"];
	[request startSynchronous];

	NSError* error = [request error];

	if (request.responseStatusCode != 0)
	{
		switch (request.responseStatusCode) 
		{
			case 200: //if it's 200, then everything is fine, and we continue
				break;

			case 401:
				[NSException raise:AUTH_EXCEPTION_STRING format:NSLocalizedString(@"Incorrect Password", @"incorrect password"), nil];
				return nil;
				break;

			case 500:
			case 501:
			case 502:
			case 503:
			case 504:
			case 505:
				[NSException raise:@"ConnectFail" format: NSLocalizedString(@"Unable To Communicate With Server (%d)", @"unable to communicate with server"), request.responseStatusCode];
				return nil;
				break;

			default:
				NSLog(@"### unexpected http error: %d", request.responseStatusCode);
				return nil;
				break;
		}
	}
	else if (error != nil)
	{
		[NSException raise:@"ConnectFail" format:NSLocalizedString(@"Failed To Communicate With Server (%d)", @"failed to communicate with server"), error.code];
		return nil;
	}
	
	return [request responseData];
}

@end
