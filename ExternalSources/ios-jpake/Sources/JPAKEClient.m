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

#import "NSData+AES.h"
#import "NSData+Encoding.h"
#import "NSData+SHA.h"
#import "NSData+Random.h"

#import "JPAKEClient.h"
#import "JPAKEReporter.h"
#import "JPAKEKeys.h"

#import "JSON.h"

NSString* JPAKEClientErrorDomain = @"JPAKEClientErrorDomain";

@implementation NSString (JPAKE)

/**
 * Generate a JPAKE Secret. Currently implemented as 4 random characters.
 */

+ (NSString*) stringWithJPAKESecret
{
	static char* permittedCharacters = "abcdefghijkmnpqrstuvwxyz23456789";

	NSMutableString* secret = [NSMutableString stringWithCapacity: 8];
		
	srandomdev();

	int n = strlen(permittedCharacters);
	
	for (int i = 0; i < 8; i++) {
		[secret appendFormat: @"%c", permittedCharacters[random() % n]];
	}
	
	return secret;
}

/**
 * Generate a session id, which currently is 256 random characters. Using hex here.
 */

+ (NSString*) stringWithJPAKEClientIdentifier
{
	NSMutableString* identifier = [NSMutableString stringWithCapacity: 16];
	
	srandomdev();
	
	for (int i = 0; i < 256; i++) {
		[identifier appendFormat: @"%x", (random() % 16)];
	}
	
	return identifier;
}

@end

@implementation JPAKEClient

@synthesize initialPollRetries = _initialPollRetries;
@synthesize pollRetries = _pollRetries;
@synthesize pollInterval = _pollInterval;
@synthesize pollDelay = _pollDelay;

#pragma mark -

- (id) initWithServer: (NSURL*) server delegate: (id<JPAKEClientDelegate>) delegate reporter: (JPAKEReporter*) reporter
{
	if ((self = [super init]) != nil) {
		_server = [server retain];
		_delegate = delegate;
		_reporter = [reporter retain];
		_clientIdentifier = [[NSString stringWithJPAKEClientIdentifier] retain];
		_initialPollRetries = 300;
		_pollRetries = 10;
		_pollDelay = 2000;
		_pollInterval = 1000;
		_queue = [ASINetworkQueue new];
		[_queue go];
	}
	
	return self;
}

- (void) dealloc
{
	[_reporter release];
	
	[_queue reset];
	[_queue release];

	if (_timer != nil) {
		[_timer invalidate];
		[_timer release];
		_timer = nil;
	}

	[_channel release];
	[_secret release];
	[_clientIdentifier release];
	[_party release];
	[_etag release];
	[_key release];
	[_server release];

	[super dealloc];
}

#pragma mark -

- (NSDictionary*) messageWithType: (NSString*) type payload: (id) payload
{
	return [NSDictionary dictionaryWithObjectsAndKeys: type, @"type", payload, @"payload", nil];
}

#pragma mark -

- (NSError*) errorWithCode: (NSInteger) code localizedDescriptionKey: (NSString*) localizedDescriptionKey
{
	NSDictionary* userInfo = [NSDictionary dictionaryWithObject: localizedDescriptionKey forKey: @"NSLocalizedDescriptionKey"];
	return [NSError errorWithDomain: JPAKEClientErrorDomain code: code userInfo: userInfo];
}

- (NSError*) unexpectedServerResponseError
{
	return [self errorWithCode: kJPAKEClientErrorUnexpectedServerResponse
		localizedDescriptionKey: @"The server returned an unexpected response"];
}

- (NSError*) invalidServerResponseError
{
	return [self errorWithCode: kJPAKEClientErrorInvalidServerResponse
		localizedDescriptionKey: @"The server returned an invalid response"];
}

- (NSError*) timeoutError
{
	return [self errorWithCode: kJPAKEClientErrorPeerTimeout
		localizedDescriptionKey: @"Timeout while waiting for the peer response"];
}

- (BOOL) requestWasCancelled: (ASIHTTPRequest*) request
{
	return request.error != nil
		&& [request.error.domain isEqualToString: NetworkRequestErrorDomain]
			&& request.error.code == ASIRequestCancelledErrorType;
}

#pragma mark -

- (void) reportTimeoutError
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#reportTimeoutError");
#endif
	[_reporter reportMessage: @"jpake.error.timeout" session: _clientIdentifier channel: _channel];
}

- (void) reportInvalidMessageError
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#reportInvalidMessageError");
#endif
	[_reporter reportMessage: @"jpake.error.invalid" session: _clientIdentifier channel: _channel];
}

- (void) reportWrongMessageError
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#reportWrongMessageError");
#endif
	[_reporter reportMessage: @"jpake.error.wrongmessage" session: _clientIdentifier channel: _channel];
}

- (void) reportKeyMismatchError
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#reportKeyMismatchError");
#endif
	[_reporter reportMessage: @"jpake.error.keymismatch" session: _clientIdentifier channel: _channel];
}

- (void) reportUnexpectedServerResponse
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#reportUnexpectedServerResponse");
#endif
	[_reporter reportMessage: @"jpake.error.server" session: _clientIdentifier channel: _channel];
}

#pragma mark -

/**
 * Check if the basics are correct. The message should be a dictionary, it should have
 * a string field named 'type' and it should have a 'payload' field that is not nil.
 *
 * If we find an error then we call the reporter and return NO. Otherwise YES.
 */

- (BOOL) validateBasicMessage :(NSDictionary*) message
{
	if (message == nil) {
		return NO;
	}
	
	if ([message isKindOfClass: [NSDictionary class]] == NO) {
		return NO;
	}
	
	NSString* type = [message objectForKey: @"type"];
	if (type == nil || [type isKindOfClass: [NSString class]] == NO) {
		return NO;
	}
	
	if ([message objectForKey: @"payload"] == nil) {
		return NO;
	}
	
	return YES;
}

- (BOOL) validateDesktopMessageOne: (NSDictionary*) message
{
	if ([self validateBasicMessage: message] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}
	
	// Check if the message is of the correct type
	
	NSString* type = [message objectForKey: @"type"];
	if ([type isEqualToString: @"sender1"] == NO) {
		[self reportWrongMessageError];
		return NO;
 	}
	
	// Check for the existence of a payload dictionary
	
	NSDictionary* payload = [message objectForKey: @"payload"];
	if (payload == nil || [payload isKindOfClass: [NSDictionary class]] == NO) {
		return NO;
	}
	
	// Check if the payload has the two zkp dictionaries
	
	NSDictionary* zkp_x1 = [payload objectForKey: @"zkp_x1"];
	if (zkp_x1 == nil || [zkp_x1 isKindOfClass: [NSDictionary class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}

	NSDictionary* zkp_x2 = [payload objectForKey: @"zkp_x1"];
	if (zkp_x2 == nil || [zkp_x2 isKindOfClass: [NSDictionary class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}
	
	// Check for the presence of the numbers .. we just check if they are strings

	if ([[payload objectForKey: @"gx1"] isKindOfClass: [NSString class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}

	if ([[payload objectForKey: @"gx2"] isKindOfClass: [NSString class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}

	if ([[zkp_x1 objectForKey: @"gr"] isKindOfClass: [NSString class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}

	if ([[zkp_x1 objectForKey: @"b"] isKindOfClass: [NSString class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}

	if ([[zkp_x2 objectForKey: @"gr"] isKindOfClass: [NSString class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}

	if ([[zkp_x2 objectForKey: @"b"] isKindOfClass: [NSString class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}
	
	return YES;
}

- (BOOL) validateDesktopMessageTwo: (NSDictionary*) message
{
	if ([self validateBasicMessage: message] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}

	// Check if the message is of the correct type
	
	NSString* type = [message objectForKey: @"type"];
	if ([type isEqualToString: @"sender2"] == NO) {
		[self reportWrongMessageError];
		return NO;
 	}

	// Check for the existence of a payload dictionary
	
	NSDictionary* payload = [message objectForKey: @"payload"];
	if (payload == nil || [payload isKindOfClass: [NSDictionary class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}
	
	// Check if the payload has the zkp dictionary
	
	NSDictionary* zkp_A = [payload objectForKey: @"zkp_A"];	
	if (zkp_A == nil || [zkp_A isKindOfClass: [NSDictionary class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}
	
	// Check for the presence of the numbers .. we just check if they are strings

	if ([[payload objectForKey: @"A"] isKindOfClass: [NSString class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}

	if ([[zkp_A objectForKey: @"gr"] isKindOfClass: [NSString class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}

	if ([[zkp_A objectForKey: @"b"] isKindOfClass: [NSString class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}

	return YES;
}

- (BOOL) validateDesktopMessageThree: (NSDictionary*) message
{
	if ([self validateBasicMessage: message] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}

	// Check if the message is of the correct type
	
	NSString* type = [message objectForKey: @"type"];
	if ([type isEqualToString: @"sender3"] == NO) {
		[self reportWrongMessageError];
		return NO;
 	}
	
	// Check for the existence of a payload dictionary
	
	NSDictionary* payload = [message objectForKey: @"payload"];
	if (payload == nil || [payload isKindOfClass: [NSDictionary class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}

	// Check if the crypto fields are there
	
	if ([[payload objectForKey: @"ciphertext"] isKindOfClass: [NSString class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}	

	if ([[payload objectForKey: @"IV"] isKindOfClass: [NSString class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}	

	if ([[payload objectForKey: @"hmac"] isKindOfClass: [NSString class]] == NO) {
		[self reportInvalidMessageError];
		return NO;
	}	

	return YES;
}

#pragma mark -

- (void) logResponse: (ASIHTTPRequest*) request
{
	NSLog(@"JPAKEClient#logResponse: %@", request);
	NSLog(@"  request.responseStatusCode = %d", request.responseStatusCode);
	NSLog(@"  request.responseStatusMessage = %@", request.responseStatusMessage);
	NSLog(@"  request.responseString = %@", [request responseString]);
	NSLog(@"  request.responseHeaders = %@", request.responseHeaders);
}

- (void) logFailedRequest: (ASIHTTPRequest*) request
{
	NSLog(@"JPAKEClient#logFailedRequest: %@", request);
	NSLog(@"  request.error = %@", request.error);
	NSLog(@"  request.responseStatusCode = %d", request.responseStatusCode);
	NSLog(@"  request.responseStatusMessage = %@", request.responseStatusMessage);
	NSLog(@"  request.responseString = %@", [request responseString]);
}

- (void) queueRequest: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#queueRequest: %@", request);
	NSLog(@"  request.url = %@", [request.url absoluteString]);
	NSLog(@"  request.requestMethod = %@", request.requestMethod);
	NSLog(@"  request.requestHeaders = %@", request.requestHeaders);
	if (request.postBody != nil) {
		NSLog(@"  request.postBody = %@", [[[NSString alloc] initWithData: request.postBody encoding: NSUTF8StringEncoding] autorelease]);
	}
#endif

	[_queue addOperation: request];
}

//#pragma mark -
//
//- (void) deleteChannelDidFinish: (ASIHTTPRequest*) request
//{
//	NSLog(@"JPAKEClient#deleteChannelDidFinish");
//}
//
//- (void) deleteChannelDidFail: (ASIHTTPRequest*) request
//{
//	NSLog(@"JPAKEClient#deleteChannelDidFail");
//	[self logFailedRequest: request];
//}
//
//- (void) deleteChannel
//{
//	NSLog(@"JPAKEClient#deleteChannel");
//	
//	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL: [NSURL URLWithString: [NSString stringWithFormat: @"/%@", _channel] relativeToURL: _server]];
//	if (request != nil) {
//		[request setShouldAttemptPersistentConnection: NO];
//		[request setRequestMethod: @"DELETE"];
//		[request addRequestHeader: @"X-KeyExchange-Id" value: _clientIdentifier];
//		[request setDelegate: self];
//		[request setDidFinishSelector: @selector(deleteChannelDidFinish:)];
//		[request setDidFailSelector: @selector(deleteChannelDidFail:)];
//		[self queueRequest: request];
//	}		
//}

#pragma mark -

- (NSString*) decryptPayload: (NSDictionary*) payload withKey: (NSData*) key error: (NSError**) error
{
	JPAKEKeys* keys = [[[JPAKEKeys alloc] initWithMasterKey: _key] autorelease];

	//

	NSData* iv = [[[NSData alloc] initWithBase64EncodedString: [payload objectForKey: @"IV"]] autorelease];
	if (iv == nil || [iv length] != 16) {
		if (error != NULL) {
			[self reportInvalidMessageError];
			*error = [self errorWithCode: kJPAKEClientErrorInvalidCryptoPayload localizedDescriptionKey: @"The message contains invalid crypto payload"];
		}
		return nil;
	}
	
	NSData* ciphertext = [[[NSData alloc] initWithBase64EncodedString: [payload objectForKey: @"ciphertext"]] autorelease];
	if (ciphertext == nil || [ciphertext length] == 0) {
		if (error != NULL) {
			[self reportInvalidMessageError];
			*error = [self errorWithCode: kJPAKEClientErrorInvalidCryptoPayload localizedDescriptionKey: @"The message contains invalid crypto payload"];
		}
		return nil;
	}
	
	NSData* hmac = [[[NSData alloc] initWithBase16EncodedString: [payload objectForKey: @"hmac"]] autorelease];
	if (hmac == nil || [hmac length] != 32) {
		if (error != NULL) {
			[self reportInvalidMessageError];
			*error = [self errorWithCode: kJPAKEClientErrorInvalidCryptoPayload localizedDescriptionKey: @"The message contains invalid crypto payload"];
		}
		return nil;
	}

	NSData* cipherTextData = [[payload objectForKey: @"ciphertext"] dataUsingEncoding: NSASCIIStringEncoding];

	NSData* hmacValue = [cipherTextData HMACSHA256WithKey: keys.hmacKey];
	if (hmacValue == nil || [hmac isEqualToData: hmacValue] == NO) {
		if (error != NULL) {
			[self reportKeyMismatchError];
			*error = [self errorWithCode: kJPAKEClientErrorInvalidCryptoPayload localizedDescriptionKey: @"The message contains invalid crypto payload"];
		}
		return nil;
	}
	
	NSData* plaintext = [NSData plaintextDataByAES256DecryptingCiphertextData: ciphertext key: keys.cryptoKey iv: iv padding: YES];
	if (plaintext == nil) {
		if (error != NULL) {
			[self reportKeyMismatchError];
			*error = [self errorWithCode: kJPAKEClientErrorInvalidCryptoPayload localizedDescriptionKey: @"The message contains invalid crypto payload"];
		}
		return nil;
	}

	NSString* json = [[[NSString alloc] initWithData: plaintext encoding: NSUTF8StringEncoding] autorelease];
	if (json == nil) {
		if (error != NULL) {
			[self reportInvalidMessageError];
			*error = [self errorWithCode: kJPAKEClientErrorInvalidCryptoPayload localizedDescriptionKey: @"The message contains invalid crypto payload"];
		}
		return nil;
	}
	
	return json;
}

- (void) getDesktopMessageThreeDidFinish: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#getDesktopMessageThreeDidFinish: %@", request);
	[self logResponse: request];
#endif

	[_timer release];
	_timer = nil;

	switch ([request responseStatusCode]) {
		case 304: {
			if (_pollRetryCount < _pollRetries) {
				_timer = [[NSTimer scheduledTimerWithTimeInterval: ((NSTimeInterval) _pollInterval) / 1000.0 target: self
					selector: @selector(getDesktopMessageThree) userInfo: nil repeats: NO] retain];
			} else {
				[self reportTimeoutError];
				[_delegate client: self didFailWithError: [self timeoutError]];
			}
			break;
		}
		
		case 200: {
			NSDictionary* message = [[request responseString] JSONValue];
			if ([self validateDesktopMessageThree: message] == NO) {
				[self reportInvalidMessageError];
				[_delegate client: self didFailWithError: [self invalidServerResponseError]];
			} else {
				NSError* error = nil;
				NSString* json = [self decryptPayload: [message objectForKey: @"payload"] withKey: _key error: &error];
				if (error != nil) {
					[_delegate client: self didFailWithError: error];
				} else {
					[_delegate client: self didReceivePayload: [json JSONValue]];
				}
			}
			break;
		}
		
		default: {
			[self reportUnexpectedServerResponse];
			[_delegate client: self didFailWithError: [self unexpectedServerResponseError]];
		}
	}
}

- (void) getDesktopMessageThreeDidFail: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#getDesktopMessageThreeDidFail: %@", request);
#endif

	if ([self requestWasCancelled: request] == NO) {
		[_delegate client: self didFailWithError: [request error]];
	}
}

- (void) getDesktopMessageThree
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#getDesktopMessageThree");
#endif
	
	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL: [NSURL URLWithString: [NSString stringWithFormat: @"/%@", _channel] relativeToURL: _server]];
	if (request != nil) {
		[request setNumberOfTimesToRetryOnTimeout: 3];
		[request setShouldAttemptPersistentConnection: NO];
		[request addRequestHeader: @"X-KeyExchange-Id" value: _clientIdentifier];
		[request addRequestHeader: @"If-None-Match" value: _etag];
		[request setDelegate: self];
		[request setDidFinishSelector: @selector(getDesktopMessageThreeDidFinish:)];
		[request setDidFailSelector: @selector(getDesktopMessageThreeDidFail:)];
		[self queueRequest: request];
	}	

	_pollRetryCount++;
}

#pragma mark -

- (void) putMobileMessageThreeDidFinish: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#putMobileMessageThreeDidFinish: %@", request);
	[self logResponse: request];
#endif

	if ([request responseStatusCode] != 200 && [request responseStatusCode] != 412) {
		[self reportUnexpectedServerResponse];
		[_delegate client: self didFailWithError: [self unexpectedServerResponseError]];
		return;
	}

	// Remember the etag
	[_etag release];
	_etag = [[[request responseHeaders] objectForKey: @"Etag"] retain];

	// Poll for the desktop's message three
	_pollRetryCount = 0;
	_timer = [[NSTimer scheduledTimerWithTimeInterval: ((NSTimeInterval) _pollDelay) / 1000.0
		target: self selector: @selector(getDesktopMessageThree) userInfo: nil repeats: NO] retain];
}

- (void) putMobileMessageThreeDidFail: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#putMobileMessageThreeDidFail: %@", request);
	[self logFailedRequest: request];
#endif

	if ([self requestWasCancelled: request] == NO) {
		[_delegate client: self didFailWithError: [request error]];
	}
}

- (void) putMobileMessageThree
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#putMobileMessageThree");
#endif

	JPAKEKeys* keys = [[[JPAKEKeys alloc] initWithMasterKey: _key] autorelease];

#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#putMobileMessageThree keys.cryptoKey = %@", keys.cryptoKey);
	NSLog(@"JPAKEClient#putMobileMessageThree keys.hmacKey = %@", keys.hmacKey);
#endif

	NSData* knownValue = [@"0123456789ABCDEF" dataUsingEncoding: NSASCIIStringEncoding];
	NSData* iv = [NSData randomDataWithLength: kCCBlockSizeAES128];
	NSData* ciphertext = [NSData ciphertextDataByAES256EncrypingPlaintextData: knownValue key: keys.cryptoKey iv: iv padding: YES];
	NSDictionary* payload = [NSDictionary dictionaryWithObjectsAndKeys: [ciphertext base64Encoding], @"ciphertext", [iv base64Encoding], @"IV", nil];
	
	NSDictionary* message = [self messageWithType: @"receiver3" payload: payload];
	NSString* json = [message JSONRepresentation];
	NSMutableData* data = [NSMutableData dataWithData: [json dataUsingEncoding: NSUTF8StringEncoding]];
	
	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL: [NSURL URLWithString: [NSString stringWithFormat: @"/%@", _channel] relativeToURL: _server]];
	if (request != nil) {
		[request setNumberOfTimesToRetryOnTimeout: 3];
		[request setShouldAttemptPersistentConnection: NO];
		[request addRequestHeader: @"X-KeyExchange-Id" value: _clientIdentifier];
		[request addRequestHeader: @"If-Match" value: _etag];
		[request setRequestMethod: @"PUT"];
		[request setPostBody: data];
		[request setDelegate: self];
		[request setDidFinishSelector: @selector(putMobileMessageThreeDidFinish:)];
		[request setDidFailSelector: @selector(putMobileMessageThreeDidFail:)];
		[self queueRequest: request];
	}	
}

#pragma mark -

- (void) getDesktopMessageTwoDidFinish: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#getDesktopMessageTwoDidFinish: %@", request);
#endif
	
	[_timer release];
	_timer = nil;

	switch ([request responseStatusCode]) {
		case 304: {
			if (_pollRetryCount < _pollRetries) {
				_timer = [[NSTimer scheduledTimerWithTimeInterval: ((NSTimeInterval) _pollInterval) / 1000.0
					target: self selector: @selector(getDesktopMessageTwo) userInfo: nil repeats: NO] retain];
			} else {
				[self reportTimeoutError];
				[_delegate client: self didFailWithError: [self timeoutError]];
			}
			break;
		}
		
		case 200: {
			NSDictionary* message = [[request responseString] JSONValue];
			if ([self validateDesktopMessageTwo: message] == NO) {
				[self reportInvalidMessageError];
				[_delegate client: self didFailWithError: [self invalidServerResponseError]];
				return;
			}
			NSDictionary* payload = [message objectForKey: @"payload"];
			_key = [[_party generateKeyFromMessageTwo: payload] retain];

			//NSLog(@"MOO _key = %@", _key);

			if (_key == nil) {
				[_delegate client: self didFailWithError: [self errorWithCode: -1 localizedDescriptionKey: @""]]; // TODO: What to report here?
			} else {
				if ([[request responseHeaders] objectForKey: @"Etag"]) {
					[_etag release];
					_etag = [[[request responseHeaders] objectForKey: @"Etag"] retain];
				}
				[self putMobileMessageThree];
			}
			break;
		}
		
		default: {
			[self reportUnexpectedServerResponse];
			[_delegate client: self didFailWithError: [self unexpectedServerResponseError]];
		}
	}
}

- (void) getDesktopMessageTwoDidFail: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#getDesktopMessageTwoDidFail: %@", request);
	[self logFailedRequest: request];
#endif

	if ([self requestWasCancelled: request] == NO) {
		[_delegate client: self didFailWithError: [request error]];
	}
}

- (void) getDesktopMessageTwo
{
	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL: [NSURL URLWithString: [NSString stringWithFormat: @"/%@", _channel] relativeToURL: _server]];
	if (request != nil) {
		[request setNumberOfTimesToRetryOnTimeout: 3];
		[request setShouldAttemptPersistentConnection: NO];
		[request addRequestHeader: @"X-KeyExchange-Id" value: _clientIdentifier];
		[request setDelegate: self];
		[request addRequestHeader: @"If-None-Match" value: _etag];
		[request setDidFinishSelector: @selector(getDesktopMessageTwoDidFinish:)];
		[request setDidFailSelector: @selector(getDesktopMessageTwoDidFail:)];
		[self queueRequest: request];
	}

	_pollRetryCount++;
}

#pragma mark -

- (void) putMobileMessageTwoDidFinish: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#putMobileMessageTwoDidFinish: %@", request);
	[self logResponse: request];
#endif

	if ([request responseStatusCode] != 200 && [request responseStatusCode] != 412) {
		[self reportUnexpectedServerResponse];
		[_delegate client: self didFailWithError: [self unexpectedServerResponseError]];
		return;
	}

	// Remember the etag
	[_etag release];
	_etag = [[[request responseHeaders] objectForKey: @"Etag"] retain];

	// Poll for the desktop's message two
	_pollRetryCount = 0;
	_timer = [[NSTimer scheduledTimerWithTimeInterval: ((NSTimeInterval) _pollDelay) / 1000.0
		target: self selector: @selector(getDesktopMessageTwo) userInfo: nil repeats: NO] retain];
}

- (void) putMobileMessageTwoDidFail: (ASIHTTPRequest*) request
{
	//NSLog(@"JPAKEClient#putMobileMessageTwoDidFail: %@", request);
	if ([self requestWasCancelled: request] == NO) {
		[_delegate client: self didFailWithError: [request error]];
	}
}

- (void) putMobileMessageTwo: (NSDictionary*) one
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#putMobileMessageTwo");
#endif

	NSDictionary* message = [self messageWithType: @"receiver2" payload: [_party generateMessageTwoFromMessageOne: one]];
	NSString* json = [message JSONRepresentation];

	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL: [NSURL URLWithString: [NSString stringWithFormat: @"/%@", _channel] relativeToURL: _server]];
	if (request != nil) {
		[request setNumberOfTimesToRetryOnTimeout: 3];
		[request setShouldAttemptPersistentConnection: NO];
		[request addRequestHeader: @"X-KeyExchange-Id" value: _clientIdentifier];
		[request addRequestHeader: @"If-Match" value: _etag];
		[request setRequestMethod: @"PUT"];
		[request setPostBody: [NSMutableData dataWithData: [json dataUsingEncoding: NSUTF8StringEncoding]]];
		[request setDelegate: self];
		[request setDidFinishSelector: @selector(putMobileMessageTwoDidFinish:)];
		[request setDidFailSelector: @selector(putMobileMessageTwoDidFail:)];
		[self queueRequest: request];
	}	
}

#pragma mark -

- (void) getDesktopMessageOneDidFinish: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#getDesktopMessageOneDidFinish: %@", request);
	[self logResponse: request];
#endif
	
	[_timer release];
	_timer = nil;

	switch ([request responseStatusCode]) {
		case 304: {
			if (_pollRetryCount < _initialPollRetries) {
				_timer = [[NSTimer scheduledTimerWithTimeInterval: ((NSTimeInterval) _pollInterval) / 1000.0
					target: self selector: @selector(getDesktopMessageOne) userInfo: nil repeats: NO] retain];
			} else {
				[self reportTimeoutError];
				[_delegate client: self didFailWithError: [self timeoutError]];
			}
			break;
		}
		
		case 200: {
			NSDictionary* message = [[request responseString] JSONValue];
			if ([self validateDesktopMessageOne: message] == NO) {
				[self reportInvalidMessageError];
				[_delegate client: self didFailWithError: [self invalidServerResponseError]];
			} else {
				if ([[request responseHeaders] objectForKey: @"Etag"]) {
					[_etag release];
					_etag = [[[request responseHeaders] objectForKey: @"Etag"] retain];
				}
				NSDictionary* payload = [message objectForKey: @"payload"];
				[self putMobileMessageTwo: payload];
			}
			break;
		}
		
		default: {
			[self reportUnexpectedServerResponse];
			[_delegate client: self didFailWithError: [self unexpectedServerResponseError]];
		}
	}
}

- (void) getDesktopMessageOneDidFail: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#getDesktopMessageOneDidFail: %@", request);
	[self logFailedRequest: request];
#endif

	if ([self requestWasCancelled: request] == NO) {
		[_delegate client: self didFailWithError: [request error]];
	}
}

- (void) getDesktopMessageOne
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#getDesktopMessageOne");
#endif

	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL: [NSURL URLWithString: [NSString stringWithFormat: @"/%@", _channel] relativeToURL: _server]];
	if (request != nil) {
		[request setNumberOfTimesToRetryOnTimeout: 3];
		[request setShouldAttemptPersistentConnection: NO];
		[request addRequestHeader: @"X-KeyExchange-Id" value: _clientIdentifier];
		[request setDelegate: self];
		[request addRequestHeader: @"If-None-Match" value: _etag];
		[request setDidFinishSelector: @selector(getDesktopMessageOneDidFinish:)];
		[request setDidFailSelector: @selector(getDesktopMessageOneDidFail:)];
		[self queueRequest: request];
	}
	_pollRetryCount++;
}

#pragma mark -

- (void) putMessageOneDidFinish: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#putMessageOneDidFinish: %@", request);
	[self logResponse: request];
#endif

	if ([request responseStatusCode] != 200 && [request responseStatusCode] != 412) {
		[_delegate client: self didFailWithError: [self unexpectedServerResponseError]];
		return;
	}

	[_delegate client: self didGenerateSecret: [NSString stringWithFormat: @"%@-%@-%@",
		[_secret substringToIndex: 4], [_secret substringFromIndex: 4], _channel]];

	// Remember the etag
	[_etag release];
	_etag = [[[request responseHeaders] objectForKey: @"Etag"] retain];
	
	// We have generated a secret and uploaded our message one. So now periodically poll to see if the other side has uploaded their message one.
	_pollRetryCount = 0;
	_timer = [[NSTimer scheduledTimerWithTimeInterval: ((NSTimeInterval) _pollDelay) / 1000.0
		target: self selector: @selector(getDesktopMessageOne) userInfo: nil repeats: NO] retain];
}

- (void) putMessageOneDidFail: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#putMessageOneDidFail: %@", request);
	[self logFailedRequest: request];
#endif

	if ([self requestWasCancelled: request] == NO) {
		[_delegate client: self didFailWithError: [request error]];
	}
}

- (void) putMessageOne
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#putMessageOne");
#endif

	_party = [[JPAKEParty partyWithPassword: _secret modulusLength: 3072 signerIdentity: @"receiver" peerIdentity: @"sender"] retain];
	if (_party == nil) {
		[_delegate client: self didFailWithError: [self errorWithCode: -1 localizedDescriptionKey: @""]]; // TODO: What to report here?
		return;
	}
	
	NSDictionary* message = [self messageWithType: @"receiver1" payload: [_party generateMessageOne]];
	NSString* json = [message JSONRepresentation];

	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL: [NSURL URLWithString: [NSString stringWithFormat: @"/%@", _channel] relativeToURL: _server]];
	if (request != nil) {
		[request setNumberOfTimesToRetryOnTimeout: 3];
		[request setShouldAttemptPersistentConnection: NO];
		[request addRequestHeader: @"X-KeyExchange-Id" value: _clientIdentifier];
		[request addRequestHeader: @"If-None-Match" value: @"*"];
		[request setRequestMethod: @"PUT"];
		[request setPostBody: [NSMutableData dataWithData: [json dataUsingEncoding: NSUTF8StringEncoding]]];
		[request setDelegate: self];
		[request setDidFinishSelector: @selector(putMessageOneDidFinish:)];
		[request setDidFailSelector: @selector(putMessageOneDidFail:)];
		[self queueRequest: request];
	}	
}

#pragma mark -

- (void) requestChannelDidFinish: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#requestChannelDidFinish: %@", request);
	[self logResponse: request];
#endif

	if ([request responseStatusCode] != 200) {
		[self reportUnexpectedServerResponse];
		[_delegate client: self didFailWithError: [self unexpectedServerResponseError]];
		return;
	}

	_channel = [[request.responseString substringWithRange: NSMakeRange(1, [request.responseString length] - 2)] retain];
	_secret = [[NSString stringWithJPAKESecret] retain];
	
	// Generate message one and put it to the channel
	
	[self putMessageOne];
}

- (void) requestChannelDidFail: (ASIHTTPRequest*) request
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#requestChannelDidFail: %@", request);
	[self logFailedRequest: request];
#endif
	
	if ([self requestWasCancelled: request] == NO) {
		[_delegate client: self didFailWithError:
			[self errorWithCode: kJPAKEClientErrorUnableToRequestChannel localizedDescriptionKey: @"Unable to request channel"]];
	}
}

- (void) requestChannel
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#requestChannel");
#endif

	NSURL* url = [NSURL URLWithString: @"/new_channel" relativeToURL: _server];

	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL: url];
	if (request != nil) {
		[request setNumberOfTimesToRetryOnTimeout: 3];
		[request setShouldAttemptPersistentConnection: NO];
		[request addRequestHeader: @"X-KeyExchange-Id" value: _clientIdentifier];
		[request setDelegate: self];
		[request setDidFinishSelector: @selector(requestChannelDidFinish:)];
		[request setDidFailSelector: @selector(requestChannelDidFail:)];
		[self queueRequest: request];
	}
}

#pragma mark -

- (void) start
{
	[ASIHTTPRequest setShouldUpdateNetworkActivityIndicator:NO];
	[self requestChannel];
}

- (void) restart
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#restart");
#endif

	[_queue reset];

	[_channel release];
	_channel = nil;
	
	[_secret release];
	_secret = nil;
	
	[_clientIdentifier release];
	_clientIdentifier = nil;
	
	[_party release];
	_party = nil;
	
	[_etag release];
	_etag = nil;
	
	[_key release];
	_key = nil;

	[self start];
}

- (void) cancel
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#cancel");
#endif

	[_queue reset];
	
	if (_timer != nil) {
		[_timer invalidate];
		[_timer release];
		_timer = nil;
	}

	[_delegate clientDidCancel: self];
}

- (void) abort
{
#if defined(JPAKE_DEBUG)
	NSLog(@"JPAKEClient#abort");
#endif

	[_queue reset];
	
	if (_timer != nil) {
		[_timer invalidate];
		[_timer release];
		_timer = nil;
	}
}

@end
