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

#import <Foundation/Foundation.h>

#import "JPAKEParty.h"
#import "ASIHTTPRequest.h"
#import "ASINetworkQueue.h"

@class JPAKEClient;
@class JPAKEReporter;

@protocol JPAKEClientDelegate
- (void) client: (JPAKEClient*) client didGenerateSecret: (NSString*) secret;
- (void) client: (JPAKEClient*) client didFailWithError: (NSError*) error;
- (void) client: (JPAKEClient*) client didReceivePayload: (id) payload;
- (void) clientDidCancel: (JPAKEClient*) client;
@end

@interface NSString (JPAKE)
+ (NSString*) stringWithJPAKESecret;
+ (NSString*) stringWithJPAKEClientIdentifier;
@end

extern NSString* JPAKEClientErrorDomain;

enum {
	kJPAKEClientErrorUnexpectedServerResponse = 1,
	kJPAKEClientErrorInvalidServerResponse,
	kJPAKEClientErrorPeerTimeout,
	kJPAKEClientErrorInvalidCryptoPayload,
	kJPAKEClientErrorUnableToRequestChannel
};

@interface JPAKEClient : NSObject {
  @private
	NSURL* _server;
	id<JPAKEClientDelegate> _delegate;
	JPAKEReporter* _reporter;
  @private
	NSUInteger _pollRetryCount;
	NSTimer* _timer;
	NSString* _channel;
	NSString* _secret;
	NSString* _clientIdentifier;
	JPAKEParty* _party;
	NSString* _etag;
	NSData* _key;
	NSUInteger _initialPollRetries;
	NSUInteger _pollRetries;
	NSUInteger _pollDelay;
	NSUInteger _pollInterval;
	ASINetworkQueue* _queue;
}

/**
 * The number of retries while polling for the first message. Default is 300.
 */

@property (nonatomic,assign) NSUInteger initialPollRetries;

/**
 * The number of retries while polling for the next message. Default 10 tries. This is lower
 * than the initialPollRetries becsause at this point the PAKE exchange has been started so
 * if messages not appear, we can fail soon.
 */

@property (nonatomic,assign) NSUInteger pollRetries;

/**
 * The delay between posting something and polling for a response. Default 2 seconds.
 */

@property (nonatomic,assign) NSUInteger pollDelay;

/**
 * The interval in milliseconds between polls for the next message. Default 1 second.
 */

@property (nonatomic,assign) NSUInteger pollInterval;

- (id) initWithServer: (NSURL*) server delegate: (id<JPAKEClientDelegate>) delegate reporter: (JPAKEReporter*) reporter;

- (void) start;
- (void) restart;
- (void) cancel;
- (void) abort;

@end
