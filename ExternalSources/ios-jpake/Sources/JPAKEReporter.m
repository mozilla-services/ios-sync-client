/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Firefox Home.
 *
 * The Initial Developer of the Original Code is the Mozilla Foundation.
 *
 * Portions created by the Initial Developer are Copyright (C) 2010
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 *  Stefan Arentz <stefan@arentz.ca>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#import "JPAKEReporter.h"
#import "ASIHTTPRequest.h"

@implementation JPAKEReporter

- (id) initWithServer: (NSURL*) server
{
	if ((self = [super init]) != nil) {
		_server = [server retain];
		_queue = [ASINetworkQueue new];
		[_queue go];
	}
	return self;
}

- (void) dealloc
{
	[_queue reset];
	[_queue release];
	[super dealloc];
}

#pragma mark -

- (void) requestFinished: (ASIHTTPRequest*) request
{
}
 
- (void) requestFailed: (ASIHTTPRequest*) request
{
}

- (void) reportMessage: (NSString*) message session: (NSString*) session channel: (NSString*) channel;
{
	NSURL* url = [NSURL URLWithString: @"/report" relativeToURL: _server];

	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL: url];
	if (request != nil)
	{
		[request setRequestMethod: @"POST"];
		[request setShouldAttemptPersistentConnection: NO];
		[request setDelegate: self];
		[request setNumberOfTimesToRetryOnTimeout: 3];
		if (session != nil) {
			[request addRequestHeader: @"X-KeyExchange-Id" value: session];
		}
		if (channel != nil) {
			[request addRequestHeader: @"X-KeyExchange-Cid" value: channel];
		}
		if (message != nil) {
			[request addRequestHeader: @"X-KeyExchange-Log" value: message];
		}
		[_queue addOperation: request];
	}
}

@end
