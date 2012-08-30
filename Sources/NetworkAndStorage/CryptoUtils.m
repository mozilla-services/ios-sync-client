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



#import "WeaveAppDelegate.h"
#import "CryptoUtils.h"
#import "Stockboy.h"
#import "Fetcher.h"
#import "Store.h"

#import "NSObject+SBJSON.h"
#import "NSString+SBJSON.h"

#import "NSData+AES.h"
#import "NSData+SHA.h"
#import "NSData+Encoding.h"
#import "NSString+SHA.h"
#import "NSString+Decoding.h"
#import "NSData+WeaveKeys.h"
#import "WeaveKeys.h"

#import "RegexKitLite.h"

#import <openssl/evp.h>


@interface CryptoUtils (PRIVATE)

- (NSDictionary*) downloadPrivateKeyBundle;
- (BOOL) fetchAndUpdateClientRecord;
- (SecKeyRef)_getKeyNamed:(NSData *)keyNameUTF8;
- (int) installPrivateKeyIntoKeychain:(NSData *)keyData withName:(NSData *)keyNameUTF8;
- (NSData*) decryptPrivateKey:(NSDictionary *)payload withPassphrase:(NSString*)passphrase;
- (NSData*) getSymmetricKeyForUrl:(NSString*)keyUrl;
- (NSData *) unpackSymmetricKey:(NSData*)symmetricKeyData withURL:(NSString*)keyURL andPrivateKey:(SecKeyRef)privateKey;
- (NSData *) decryptSymmetricKey:(NSData *)symKey withPrivateKey:(SecKeyRef)privateKey;
- (NSData*) makeRandomBytesOfLength:(NSUInteger)length;
- (NSString*) encodeEmailAddress: (NSString*) emailAddress;
- (BOOL) getServerStorageVersion;

#pragma mark -
#pragma mark Stuff for Storage Version 3

- (NSString*) deriveSyncKeyFromPassphrase: (NSString*) passphrase salt: (NSString*) salt;
- (NSData*) encryptionKeyForCollection: (NSString*) collection;
- (NSData*) hmacKeyForCollection: (NSString*) collection;
- (NSMutableDictionary*) encryptDataObject: (NSDictionary*) dataObject withID: (NSString*) objectID;

@end


@implementation CryptoUtils

// The singleton instance
static CryptoUtils* _cryptoManager = nil;

+ (void) discardManager
{
  [_cryptoManager release];
  _cryptoManager = nil;
}

+ (void) assignManager:(CryptoUtils*)newManager
{
  [CryptoUtils discardManager];
  _cryptoManager = newManager;
}


//NOTE: this will either return a valid cryptoutils or nil!
// nil means try again later!
+ (CryptoUtils*) getManager
{
  return _cryptoManager;
}

+ (void) createManager
{
  if (_cryptoManager != nil) return;
  
  WeaveAppDelegate *delegate = (WeaveAppDelegate*)[[UIApplication sharedApplication] delegate];

  //otherwise, construct the singleton
  if ([delegate canConnectToInternet])
  {
    //default initializer tries to locate everything it needs from disk.
    // if it fails, it will return nil, meaning we need to ask the user to log in
    @try 
    {
      _cryptoManager = [[CryptoUtils alloc] init];
    }
    @catch (NSException * e) 
    {
      //first check for an auth exception (401)
      if ([e.name isEqualToString:AUTH_EXCEPTION_STRING])
      {
        //ask the user what to do.  try again?  go to login screen?
        NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Cannot Sync", @"unable to refresh data"), @"title", 
                                 NSLocalizedString(@"Incorrect Password", "incorrect password"), @"message", nil];
        
        [delegate performSelectorOnMainThread:@selector(reportAuthErrorWithMessage:) withObject:errInfo waitUntilDone:NO];
      }
      else if ([e.name isEqualToString:PASSPHRASE_EXCEPTION_STRING])
      {
        
        //ask the user what to do.  try again?  go to login screen?
        NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Cannot Sync", @"unable to refresh data"), @"title", 
                                 NSLocalizedString(@"Incorrect Secret Phrase", "incorrect secret phrase"), @"message", nil];
        
        [delegate performSelectorOnMainThread:@selector(reportAuthErrorWithMessage:) withObject:errInfo waitUntilDone:NO];
      }
      else 
      {
        //some non-crypto related exception, like server unreachable, etc.
        //just alert the user to the problem, and tell them to try again later
        NSString *message = NSLocalizedString(@"Unable to contact server", "server unavailable");
        if ([e reason]) message = [e reason];
        NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Cannot Sync", @"unable to refresh data"), @"title", 
                                 message, @"message", nil];
        
        [delegate performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];
      }
      
      //we always return after handling the exception, we don't force them to logout
      return;
    }
    
    //if ther was no exception, but the cryptomanager was nil, then the local credentials are incomplete, and must be entered
    if (_cryptoManager == nil)
    {   
      [delegate performSelectorOnMainThread:@selector(login) withObject:nil waitUntilDone:NO];
    } 
  }
  else //no network
  {
    //no connectivity, put up alert
    NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Cannot Sync", @"unable to refresh data"), @"title", 
                             NSLocalizedString(@"No internet connection available", "no internet connection"), @"message", nil];
    
    [delegate performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];
  }
}


//wanted to be explicit about these accessors
- (int) storageVersion
{
  return _storageVersion;
}

- (NSString*) cluster
{
  return _cluster;
}

//I want these to return nil if they are empty, not an empty string.

/**
 * Returns the current account name. The account name is whatever the user has
 * filled in. Either a username or an email address. This is only used for display
 * purposes.
 */

- (NSString*) accountName
{
	NSString* accountName = [_credentials objectForKey:(id)kSecAttrAccount];
	return [accountName length] == 0? nil : accountName;
}

/**
 * Returns the username based on the account name. If the account name is a
 * simple username then that is returned. If the account name is an email
 * address then we return a hashed and encoded version for it. This is only
 * used for API calls.
 */

- (NSString*) username
{
	NSString* username = [self accountName];

	if (username != nil) {
		NSRange range = [username rangeOfString: @"@"];
		if (range.location != NSNotFound) {
			username = [self encodeEmailAddress: username];
		}
	}
	
	return username;
}

- (NSString*) password
{
  NSString* password = [_credentials objectForKey:(id)kSecValueData];
  return [password length] == 0? nil : password;
}

- (SecKeyRef) privateKey
{
  return _privateKey;
}

- (NSString*) absoluteURL: (NSString*) path
{
	return [NSString stringWithFormat:@"%s1.0/%s/%s", [[self cluster] UTF8String], [[self username] UTF8String], [path UTF8String]];
}

- (NSString*)absoluteURLForEngine:(NSString*)engineAndQuery
{
  return [NSString stringWithFormat:@"%s1.0/%s/storage/%s", [[self cluster] UTF8String], [[self username] UTF8String], [engineAndQuery UTF8String]];
}

- (NSString*)cryptoKeyURLForEngine:(NSString*)engine
{
  return [NSString stringWithFormat:@"%s1.0/%s/storage/crypto/%s", [[self cluster] UTF8String], [[self username] UTF8String], [engine UTF8String]];
}


//we are now going to update this before every sync, and check the custom server every time

- (BOOL) updateCluster
{
	NSMutableString *nodeQueryBase = [NSMutableString stringWithString:[Stockboy getURIForKey:@"Node Query Base URL"]];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomServer"])
	{
		if ([[NSUserDefaults standardUserDefaults] stringForKey:@"customServerURL"])
		{
			nodeQueryBase = [NSMutableString stringWithString: [[NSUserDefaults standardUserDefaults] stringForKey: @"customServerURL"]];

			//make sure it has a schema prefix, add https:// if not
			if (!([nodeQueryBase hasPrefix:@"http://"] || [nodeQueryBase hasPrefix:@"https://"])) {
				[nodeQueryBase insertString:@"https://" atIndex:0];
			}

			//make sure it ends with a slash, add one if not
			if (![nodeQueryBase hasSuffix:@"/"]) {
				[nodeQueryBase appendString:@"/"];
			}

			NSLog(@"using custom server: %@", nodeQueryBase);
		}
		else //they turned on custom server but didn't specify a url
		{
			NSLog(@"empty custom server url, ignoring and redirecting to mozilla server");
		}
	}

	NSString *nodeQuerySuffix = [NSString stringWithFormat:[Stockboy getURIForKey:@"Node Query Suffix"], [[self username] UTF8String]];

	NSString *clusterURL = [NSString stringWithFormat:@"%@%@", nodeQueryBase, nodeQuerySuffix];
	NSData* clusterBytes = [Fetcher getBytesFromURL:clusterURL authenticatingWith:self];
	
	if (clusterBytes == nil) {
		// If getBytesFromURL returns nil then it got a 404, which means user name not found here
		NSException *e = [NSException exceptionWithName:@"Initialization Failed"
			reason:NSLocalizedString(@"User Name Not Found", @"username not found") userInfo:nil];
		@throw e;		
	}

	_cluster = [[NSString alloc] initWithData:clusterBytes encoding:NSUTF8StringEncoding];
	
	return (_cluster != nil);
}


//initializer for all launches after the first.
// loads the information it needs from local storage.
// results:
// 1. a valid CryptoUtils object, continue with execution as planned. (valid local credentials and was able to get valid cluster)  RETURN VALID OBJECT
// 2. go directly to login screen, do not pass Go.  (missing local credentials)  RETURN NIL
// 3. tell the user there was a network problem, try again later  (non-auth related exeption while getting cluster)  THROW EXCEPTION
// 4. ask the user if they want to try different credentials or just try again later (auth-related exception while getting cluster)  THROW EXCEPTION

- (id) init
{
	if (self = [super init]) 
	{
		_credentials = [[KeychainItemWrapper alloc] initWithIdentifier:CREDENTIALS_NAME accessGroup:nil];
		_symmetricKeyCache = [[NSMutableDictionary alloc] initWithCapacity:10];

		if ([self username] == nil || [self password] == nil)
		{
			NSLog(@"Crypto initialization failed: username or password was empty");
			[self release];
			return nil;
		}    

		// Load the private key. We do not know our storage version here so we try to grab both. If they
		// are both missing then we know that we have not been initialized correctly.

		_privateKey = [self _getKeyNamed:[PRIV_KEY_NAME dataUsingEncoding:NSUTF8StringEncoding]];
		_defaultAESKey = [[KeychainItemWrapper alloc] initWithIdentifier: @"DefaultAESKey" accessGroup: nil];
		_defaultHMACKey = [[KeychainItemWrapper alloc] initWithIdentifier: @"DefaultHMACKey" accessGroup: nil];
		
		if (_privateKey == nil && _defaultAESKey == nil)
		{
			NSLog(@"Crypto initialization failed: private key was empty");
			[self release];
			return nil;
		}    

		// if the cluster was nil, but no exception was thrown, then our data was bad for some reason, but it might
		// be a transient network problem, so we will let the user decide what to do.

		if (![self updateCluster])
		{
			NSLog(@"Crypto initialization failed: unable to retrieve cluster");
			[self release];
			NSException *e = [NSException exceptionWithName:@"Initialization Failed"
				reason:NSLocalizedString(@"Failed Server Lookup", @"Failed Server Lookup") userInfo:nil];
			@throw e;
		}
		
		// Check the server storage version. This may throw AuthException (incorrect password)

		if (![self getServerStorageVersion])
		{
			NSLog(@"Crypto initialization failed: unable to retrieve the meta global for the storage version");
			[self release];
			NSException *e = [NSException exceptionWithName:@"Initialization Failed"
				reason:NSLocalizedString(@"Failed Server Lookup", @"Failed Server Lookup") userInfo:nil];
			@throw e;
		}

		if (_storageVersion < 2 || _storageVersion == 4)
		{
			NSLog(@"Crypto initialization failed: incompatible storage version (< 2 || 4)");
			[self release];

			NSException *e = [NSException exceptionWithName:@"Initialization Failed"
				reason: NSLocalizedString(@"Data on the server is in an old and unsupported format. Please update Firefox Sync on your computer.", @"update Firefox Sync") userInfo:nil];
			@throw e;
		}

		else if (_storageVersion > 5)
		{
			NSLog(@"Crypto initialization failed: incompatible storage version (> 5)");
			[self release];

			NSException *e = [NSException exceptionWithName:@"Initialization Failed"
				reason: NSLocalizedString(@"Data on the server is in a new and unrecognized format. Please update SyncClient.", @"update SyncClient") userInfo:nil];
			@throw e;
		}
		
		//IMPORTANT NOTE: 
		// this call is the first BASIC AUTH required network request on startup, and will be the one to fail with 401
		// if the password is wrong.  We are letting Exceptions fall up to createManager, which will handle them correctly. 
		//THIS MAY THROW AN INCORRECT PASSPHRASE EXCEPTION, handle it outside, because the meaning depends on context

		if (![self fetchAndUpdateClientRecord])
		{
			NSLog(@"Non fatal error: could not install or update client record");
		}
	}

	return self;
}

//USED WHEN LOGGING IN FOR THE FIRST TIME, AND ASSUMES THE DATABASE HAS BEEN CLEARED
//this initializer does a lot of heavy lifting.  it gets the cluster, retrieves the private key, checks it and puts it in the keychain if necessary,
// checks the server-side client list to make sure we are listed and updates it if necessary, (which requires crypto), initializes the symmetric key cache, 
// and gets ready to decrypt objects

//NOTE: though this method makes several network calls, which throw exceptions in error cases,
// we do NOT handle any of the exceptions here, because the action to take as a result might vary by the caller

- (id) initWithAccountName:(NSString*)accountName password:(NSString*)password andPassphrase:(NSString*)passphrase
{
	if (self = [super init]) 
	{
		if (accountName == nil || password == nil || passphrase == nil)
		{
			NSLog(@"Crypto initialization failed: username or password was empty");
			[self release];
			return nil;
		}

		//clean out any old stale private key
		[CryptoUtils deletePrivateKeys];

		//ok, we have good data, let's get initialized!

		//this actually writes the data into the keychain, using the KeychainItemWrapper utility code fomr Apple
		_credentials = [[KeychainItemWrapper alloc] initWithIdentifier:CREDENTIALS_NAME accessGroup:nil];
		[_credentials setObject:accountName forKey:(id)kSecAttrAccount];
		[_credentials setObject:password forKey:(id)kSecValueData];

		_symmetricKeyCache = [[NSMutableDictionary alloc] initWithCapacity:10];

		if (![self updateCluster])
		{
			NSLog(@"Crypto initialization failed: unable to retrieve cluster");
			[self release];
			NSException *e = [NSException exceptionWithName:@"Initialization Failed"
				reason:NSLocalizedString(@"Failed Server Lookup", @"Failed Server Lookup") userInfo:nil];
			@throw e;
		}
		
		if (![self getServerStorageVersion])
		{
			NSLog(@"Crypto initialization failed: unable to retrieve the meta global for the storage version");
			[self release];
			NSException *e = [NSException exceptionWithName:@"Initialization Failed"
				reason:NSLocalizedString(@"Failed Server Lookup", @"Failed Server Lookup") userInfo:nil];
			@throw e;
		}

		if (_storageVersion < 2 || _storageVersion == 4)
		{
			NSLog(@"Crypto initialization failed: incompatible storage version (< 2 || 4)");
			[self release];

			NSException *e = [NSException exceptionWithName:@"Initialization Failed"
				reason: NSLocalizedString(@"Data on the server is in an old and unsupported format. Please update Firefox Sync on your computer.", @"update Firefox Sync") userInfo:nil];
			@throw e;
		}

		else if (_storageVersion > 5)
		{
			NSLog(@"Crypto initialization failed: incompatible storage version (> 5)");
			[self release];

			NSException *e = [NSException exceptionWithName:@"Initialization Failed"
				reason: NSLocalizedString(@"Data on the server is in a new and unrecognized format. Please update SyncClient.", @"update SyncClient") userInfo:nil];
			@throw e;
		}

		//if the user can't be found on the servers, we get back "No Location"
		if (![_cluster hasPrefix:@"https"] && ![_cluster hasPrefix:@"http"])
		{
			NSLog(@"Unable to retrieve cluster");
			[self release];
			NSException *e = [NSException exceptionWithName:@"Initialization Failed"
				reason:NSLocalizedString(@"User Name Not Found", @"username not found") userInfo:nil];
			@throw e;
			return nil;
		}

		// We do different things for the storage versions we support

		switch (_storageVersion)
		{
			case 2:
			case 3:
			{
				// Check if the passphrase is a new style sync key. If so then we remove the dashes.

				if ([passphrase length] == 23) {
					if ([passphrase characterAtIndex: 5] == '-' && [passphrase characterAtIndex: 11] == '-' && [passphrase characterAtIndex: 17] == '-') {
						passphrase = [NSString stringWithFormat: @"%@%@%@%@",
							[passphrase substringWithRange: NSMakeRange(0, 5)],
							[passphrase substringWithRange: NSMakeRange(6, 5)],
							[passphrase substringWithRange: NSMakeRange(12, 5)],
							[passphrase substringWithRange: NSMakeRange(18, 5)]];
					}
				}

				//*******
				//get the private key data
				NSDictionary* privKeyPayload = [self downloadPrivateKeyBundle];
				if (!privKeyPayload)
				{
					NSLog(@"Unable to retrieve private key");
					[self release];
					NSException *e = [NSException exceptionWithName:@"Initialization Failed"
						reason:NSLocalizedString(@"Error Retrieving Data", @"error retrieving data") userInfo:nil];
					@throw e;
					return nil;
				}

				NSData* keyBytes = [self decryptPrivateKey:privKeyPayload withPassphrase: passphrase];
				if (!keyBytes)
				{
					NSLog(@"Unable to decrypt private key");
					[self release];
					NSException *e = [NSException exceptionWithName:PASSPHRASE_EXCEPTION_STRING
						reason:NSLocalizedString(@"Incorrect Secret Phrase", @"incorrect secret phrase") userInfo:nil];
					@throw e;
					return nil;
				}

				//*******
				//install the private key
				int privInstall = [self installPrivateKeyIntoKeychain:keyBytes withName:[PRIV_KEY_NAME dataUsingEncoding:NSUTF8StringEncoding]];
				if (privInstall != 0)
				{
					NSLog(@"Unable to install private key into keychain");
					[self release];
					NSException *e = [NSException exceptionWithName:@"Initialization Failed"
						reason:[NSString stringWithFormat:NSLocalizedString(@"Failed To Install Private Key Into Keychain (%d)",
							@"failed to install private key into keychain"), privInstall] userInfo:nil];
					@throw e;
					return nil;
				}

				//now load it from the keychain, to get a SecRef
				_privateKey = [self _getKeyNamed:[PRIV_KEY_NAME dataUsingEncoding:NSUTF8StringEncoding]];
				if (!_privateKey)
				{
					NSLog(@"Unable to load private key from keychain");
					[self release];
					NSException *e = [NSException exceptionWithName:@"Initialization Failed"
						reason:NSLocalizedString(@"Cannot Load Private Key From Keychain",
							@"cannot load private key from keychain") userInfo:nil];
					@throw e;
					return nil;
				}
				
				break;
			}
			
			// Storage version 5 is a lot simpler. We simply generate the initial crypto and hmac keys from the
			// sync key. Which is possibly derived from the passphrase. We then download the crypto/keys from
			// the server and keep those around.
			
			case 5:
			{
				// We accept three types of passwords for v4. Hyphenated or plain sync keys and a passphrase.
			
				NSData* passphraseData = nil;
				
				if ([passphrase length] == 26) {
					passphraseData = [passphrase userfriendlyBase32Decoding];
				} else if ([passphrase isMatchedByRegex: @"^(?i)[A-Z2-9]{1}-[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{5}$"]) {
					passphrase = [passphrase stringByReplacingOccurrencesOfString: @"-" withString: @""];
					passphraseData = [passphrase userfriendlyBase32Decoding];
				} else {
					passphraseData = [NSData weaveKeyDataFromPassphrase: passphrase salt: _syncID];
				}
				
				// Load the keys
				
				NSDictionary* keys = [[self downloadKeysWithUsername: accountName passphraseData: passphraseData] retain];
				if (keys == nil) {
					[self release];
					NSException *e = [NSException exceptionWithName:PASSPHRASE_EXCEPTION_STRING
						reason:NSLocalizedString(@"Incorrect Secret Phrase", @"incorrect secret phrase") userInfo:nil];
					@throw e;
					return nil;
				}
				
				// Store the keys in the keychain

				_defaultAESKey = [[KeychainItemWrapper alloc] initWithIdentifier: @"DefaultAESKey" accessGroup:nil];
				[_defaultAESKey setObject: @"DefaultAESKey" forKey: (id) kSecAttrAccount];
				[_defaultAESKey setObject: [[keys objectForKey: @"default"] objectAtIndex: 0] forKey: (id) kSecValueData];

				_defaultHMACKey = [[KeychainItemWrapper alloc] initWithIdentifier: @"DefaultHMACKey" accessGroup:nil];
				[_defaultHMACKey setObject: @"DefaultHMACKey" forKey: (id) kSecAttrAccount];
				[_defaultHMACKey setObject: [[keys objectForKey: @"default"] objectAtIndex: 1] forKey: (id) kSecValueData];
				
				// Store the passphrase in the keychain. We do not need it, but we might later and it will allow
				// us to do migrations more easily.

				KeychainItemWrapper* passphraseItemWrapper = [[KeychainItemWrapper alloc] initWithIdentifier: @"Passphrase" accessGroup:nil];
				[passphraseItemWrapper setObject: @"Passphrase" forKey: (id) kSecAttrAccount];
				[passphraseItemWrapper setObject: passphrase forKey: (id) kSecValueData];
				[passphraseItemWrapper release];
				
				break;
			}
		}
		
		@try  {
			if (![self fetchAndUpdateClientRecord]) {
				NSLog(@"Non fatal error: could not install or update client record");
			}
		} @catch (NSException * e)  {
			//ignored, bad passphrase would have been handled up above
		}

	}

	return self;
}


- (void)dealloc
{
  [_credentials release];
  [_defaultAESKey release];
  [_defaultHMACKey release];
  _privateKey = nil;  //not positive this is the correct way to release a SecRef
  [_syncID release];
  [super dealloc];
}



- (NSDictionary*) downloadPrivateKeyBundle
{
  NSData* privKeyData = [Fetcher getWeaveBasicObject:[Stockboy getURIForKey:@"Private Key Path"] authenticatingWith: self];
  if (!privKeyData) return nil;
  
	NSString* privKeyString = [[NSString alloc] initWithData:privKeyData encoding:NSUTF8StringEncoding];
	NSDictionary *privKeyJSON = [privKeyString JSONValue];
  [privKeyString release];
  if (!privKeyJSON) return nil;

	return [[privKeyJSON objectForKey:@"payload"] JSONValue];  
}

//The Exeptions thrown by this method must be handled by the CALLER
//check to see if there is a client record for us, and if not, make one.
// the new format requires the record to be encrypted with random salt and sent with an HMAC-SHA256
//This can throw AUTH_EXCEPTION and PASSPHRASE EXCEPTION

- (BOOL) fetchAndUpdateClientRecord
{
	NSString *myID = [[UIDevice currentDevice] uniqueIdentifier];
	NSString *clientURL = [NSString stringWithFormat:[Stockboy getURIForKey:@"Client Path"], [myID UTF8String]];
	NSData* myClientData = [Fetcher getWeaveBasicObject:clientURL authenticatingWith:self];
	NSString* myClientString = [[[NSString alloc] initWithData:myClientData encoding:NSUTF8StringEncoding] autorelease];
	NSDictionary* myClient = [myClientString JSONValue];

	if (myClient == nil) 
	{
		NSLog(@"did not find matching mobile client record, adding.");
		
		// This check that can happen if we upgraded to new crypto but we are still logged in with the 'old'
		// account. In that case we do not have new style crypto/hmac keys, which means that we also cannot
		// encrypt and upload a new client record. So we bail out asap.
		
		if (_storageVersion == 5 && [self encryptionKeyForCollection: @"clients"] == nil) {
			NSLog(@"Not updating client record because we don't have an encryption key");
			return NO;
		}
	}
	else
	{
		NSMutableDictionary* clientObject = nil;
		
		@try {
			clientObject = [self decryptDataObject:myClient mustVerify:YES];
			if (clientObject == nil) {
				return NO;
			}
		} @catch (...) {
			// Workaround for 622046 - Decryption failure on client record
			// If decryptDataObject:mustVerify: throws an exception then we are using the incorrect
			// sync key. We should handle this better, but for now we are simply going to ignore this
			// exception so that the code below will upload a new client record. We will still fail
			// later on when we try to decrypt a collection, but at least we will not leave incorrect
			// client records on the server from which Home cannot recover.
		}

		//if we find one that matches, and decrypts, and the ID matches, then we're golden, and we get out.
		
		if (clientObject && [[clientObject objectForKey:@"id"] isEqualToString:myID]) {
			NSLog(@"found matching mobile client record");
			return YES;
		} else {
			NSLog(@"found incorrect or stale mobile client record, updating");
		}
	}

	NSMutableDictionary* payload = [NSMutableDictionary dictionary];
	[payload setObject:myID forKey:@"id"];
	[payload setObject:@"iPhone" forKey:@"name"];
	[payload setObject:@"mobile" forKey:@"type"];

	NSDictionary* encryptedPayload = nil;
	
	switch (_storageVersion)
	{
		case 2:
		case 3:
		{
			NSString* symKeyUrl = [self cryptoKeyURLForEngine:[Stockboy getURIForKey:@"Client Symkey Path"]];
			encryptedPayload = [self encryptDataObject:payload withID:myID amdSymmetricKeyURL:symKeyUrl];
			if (encryptedPayload == nil) {
				return NO; //unclear, but not bad passphrase, which will be thrown out of here and handled externally
			}
			break;
		}
			
		case 5:
		{
			encryptedPayload = [self encryptDataObject: payload withID: myID];
			if (encryptedPayload == nil) {
				return NO; //unclear, but not bad passphrase, which will be thrown out of here and handled externally
			}
			break;
		}
	}

	NSString *newJSON = [encryptedPayload JSONRepresentation];

	@try
	{
		[Fetcher putWeaveBasicObject:[newJSON dataUsingEncoding:NSUTF8StringEncoding] 
			toURL:[NSString stringWithFormat:[Stockboy getURIForKey:@"Client Path"], [myID UTF8String]]
				authenticatingWith:self];
	}

	@catch (NSException *exception)
	{
		NSLog(@"Unable to register mobile client with server: %@", exception);
		return NO;
	}

	return YES;
}


///////////////////////

// Get the server storage version

- (BOOL) getServerStorageVersion
{
	_storageVersion = -1;

	NSData *globalData = [Fetcher getWeaveBasicObject:[Stockboy getURIForKey:@"Meta Global Path"] authenticatingWith:self];

	NSString *globalString = [[[NSString alloc] initWithData:globalData encoding:NSUTF8StringEncoding] autorelease];
	NSDictionary *globalDict = [globalString JSONValue];

	NSString* payload = [globalDict objectForKey:@"payload"];
	NSDictionary* payloadDict = [payload JSONValue];

	_syncID = [[payloadDict objectForKey: @"syncID"] retain];
	_storageVersion = [[payloadDict objectForKey:@"storageVersion"] intValue];
	
	return (_storageVersion != 0);
}

#pragma mark -
#pragma mark Stuff for Storage Version 3

/**
 * Download the crypto/keys object from the server. Then decrypt and verify it using the crypto and hmac
 * keys that were generated from the sync key. Returns nil if any error occurs. There is currently no way
 * to see the difference between a network error or a crypto error.
 */

- (NSDictionary*) downloadKeysWithUsername: (NSString*) username passphraseData: (NSData*) passphraseData
{
	// If the username is an email address then hash it to a base32 name
	
	NSRange range = [username rangeOfString: @"@"];
	if (range.location != NSNotFound) {
		username = [self encodeEmailAddress: username];
	}

	// Download the keys record

	NSData* data = [Fetcher getWeaveBasicObject:[Stockboy getURIForKey:@"Keys Path"] authenticatingWith: self];
	if (data == nil) {
		return nil;
	}
	
	NSString* string = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
	if (string == nil) {
		return nil;
	}
	
	NSDictionary* json = [string JSONValue];
	if (json == nil) {
		return nil;
	}

	NSDictionary* payload = [[json objectForKey: @"payload"] JSONValue];
	if (payload == nil) {
		return nil;
	}
	
	// Generate the keys

	WeaveKeys* keys = [[[WeaveKeys alloc] initWithMasterKey: passphraseData username: username] autorelease];
	
	// Check the HMAC value to see if the data is authentic
	
	NSString* hmacReceived = [payload objectForKey: @"hmac"];
	NSString* hmacCalculated = [[[payload objectForKey: @"ciphertext"] HMACSHA256WithKey: keys.hmacKey] base16Encoding];

	if ([hmacReceived isEqualToString: hmacCalculated] == NO) {
		//return nil;
	}
	
	// Decrypt the payload
	
	NSData* iv = [[[NSData alloc] initWithBase64EncodedString: [payload objectForKey: @"IV"]] autorelease];
	NSData* ciphertext = [[[NSData alloc] initWithBase64EncodedString: [payload objectForKey: @"ciphertext"]] autorelease];
	NSData* plaintext = [NSData plaintextDataByAES256DecryptingCiphertextData: ciphertext key: keys.cryptoKey iv: iv padding: YES];
	NSString* plaintextString = [[[NSString alloc] initWithData: plaintext encoding: NSUTF8StringEncoding] autorelease];

	return [plaintextString JSONValue];
}

- (NSString*) deriveSyncKeyFromPassphrase: (NSString*) passphrase salt: (NSString*) salt
{
	unsigned char final[16];

	PKCS5_PBKDF2_HMAC_SHA1(
		[passphrase UTF8String],
		-1,
		(void*) [salt UTF8String],
		[salt length],
		4096,
		16,
		final
	);
	
	NSData* keyData = [NSData dataWithBytes: final length: 16];
	//NSLog(@"Key Data : %@", keyData);
	
	NSString* key = [keyData userfriendlyBase32Encoding];
	//NSLog(@"From %@ to %@", passphrase, key);
	
	key = [key substringToIndex: 26];
	//NSLog(@"Without padding %@", key);
	
//	return [NSString stringWithFormat: @"%@-%@-%@-%@-%@-%@-%@",
//		[key substringWithRange: NSMakeRange(0, 2)],
//		[key substringWithRange: NSMakeRange(2, 4)],
//		[key substringWithRange: NSMakeRange(6, 4)],
//		[key substringWithRange: NSMakeRange(10, 4)],
//		[key substringWithRange: NSMakeRange(14, 4)],
//		[key substringWithRange: NSMakeRange(18, 4)],
//		[key substringWithRange: NSMakeRange(22, 4)]];

	return key;
}

/**
 * Return the key to be used for AES encryption. Currently simply returns the default key
 * since that is all we will support for this first release.
 */

- (NSData*) encryptionKeyForCollection: (NSString*) collection
{
	NSData* key = [[[NSData alloc] initWithBase64EncodedString:
		[_defaultAESKey objectForKey:(id)kSecValueData]] autorelease];
	return [key length] ? key : nil;
}

/**
 * Return the key to be used for HMAC-SHA256 generation. Currently simply returns the default key
 * since that is all we will support for this first release.
 */

- (NSData*) hmacKeyForCollection: (NSString*) collection
{
	NSData* key = [[[NSData alloc] initWithBase64EncodedString:
		[_defaultHMACKey objectForKey:(id)kSecValueData]] autorelease];
	return [key length] ? key : nil;
}

- (NSMutableDictionary*) encryptDataObject: (NSDictionary*) dataObject withID: (NSString*) objectID
{
	//Step 1: turn the dictionary of properties into JSON, then into a utf8 string, then bytes
	NSString* plaintext = [dataObject JSONRepresentation];
	const char* utf8String = [plaintext UTF8String];
	int len = strlen(utf8String);
	NSData* plaintextBytes = [NSData dataWithBytes:utf8String length:len];
	//Step 3: get the appropriate symmetric key to encrypt this data type with.
	// this is up to the caller to get correct, by passing in the proper Url

	NSData *encryptionKey = [self encryptionKeyForCollection: nil]; // TODO: New Crypto
	if (encryptionKey == nil) {
		return nil;
	}

	NSData *hmacKey = [self hmacKeyForCollection: nil]; // TODO: New Crypto
	if (hmacKey == nil) {
		return nil;
	}

	//Step 4: encrypt the data to create the ciphertext
	// we need to make an init vector. ugh.
	NSData* initVector = [self makeRandomBytesOfLength: 16];
	NSData* ciphertext = [NSData ciphertextDataByAES256EncrypingPlaintextData: plaintextBytes key: encryptionKey iv: initVector padding: YES];
	
	NSData* HMAC = [[[ciphertext base64Encoding] dataUsingEncoding: NSASCIIStringEncoding] HMACSHA256WithKey: hmacKey];


	NSMutableDictionary* payload = [NSMutableDictionary dictionary];
	[payload setObject:[ciphertext base64Encoding] forKey:@"ciphertext"];
	[payload setObject:[initVector base64Encoding] forKey:@"IV"];
	[payload setObject:[HMAC base16Encoding] forKey:@"hmac"];

	NSString* JSONPayload = [payload JSONRepresentation];

	//now we need to add 'id', 'modified', 'sortIndex' (?), and the payload to the final EDO object
	NSMutableDictionary* EDO = [NSMutableDictionary dictionary];
	[EDO setObject:JSONPayload forKey:@"payload"];
	[EDO setObject:objectID forKey:@"id"];
	[EDO setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"modified"];

	return EDO;
}

#pragma mark -

////////////////////////


- (int) installPrivateKeyIntoKeychain:(NSData *)keyData withName:(NSData *)keyNameUTF8
{
	CFBooleanRef    kBoolToCF[2] = { kCFBooleanFalse, kCFBooleanTrue };
	    
	OSStatus err = SecItemAdd((CFDictionaryRef)
                   [NSDictionary dictionaryWithObjectsAndKeys:
                    (id)
                    kSecClassKey,                       kSecClass,
                    kSecAttrKeyTypeRSA,                 kSecAttrKeyType, 
                    keyNameUTF8,                        kSecAttrApplicationTag,
 //                 keyAppLabel,                        kSecAttrApplicationLabel,  //this was being used incorrectly, and is unneeded, since we lookup by name
                    kSecAttrKeyClassPrivate,            kSecAttrKeyClass, 
                    keyData,                            kSecValueData,
                    [NSNumber numberWithInt:KEY_SIZE],  kSecAttrKeySizeInBits,
                    [NSNumber numberWithInt:KEY_SIZE],  kSecAttrEffectiveKeySize,
                    kBoolToCF[YES],               kSecAttrCanDerive,
                    kBoolToCF[NO],                kSecAttrCanEncrypt,
                    kBoolToCF[YES],               kSecAttrCanDecrypt,
                    kBoolToCF[NO],                kSecAttrCanVerify,
                    kBoolToCF[YES],               kSecAttrCanSign,
                    kBoolToCF[NO],                kSecAttrCanWrap,
                    kBoolToCF[YES],               kSecAttrCanUnwrap,
                    nil
                    ],
                   NULL
	);

	if (err != noErr) 
  {
    NSString* name = [[NSString alloc] initWithData:keyNameUTF8 encoding:NSUTF8StringEncoding];
		NSLog(@"failed to add key \"%@\"   error: %d", name, err);
    [name release];
	}
	
	return err;
}

//assumes utf8 encoded string
- (SecKeyRef)_getKeyNamed:(NSData *)keyNameUTF8
{
	OSStatus    err;
	SecKeyRef   keyRef = NULL;
  
	err = SecItemCopyMatching((CFDictionaryRef)
                            [NSDictionary dictionaryWithObjectsAndKeys:
                             (id)
                             kSecClassKey,           kSecClass,
                             keyNameUTF8,             kSecAttrApplicationTag,
                             kCFBooleanTrue,         kSecReturnRef,
                             nil
                             ],
                            (CFTypeRef *) &keyRef
	);
	assert( (err == noErr) == (keyRef != NULL) );
	return keyRef;
}

+ (void)deletePrivateKeys
{
	OSStatus  err;
	NSData		*keyTagData;
  
	keyTagData = [PRIV_KEY_NAME dataUsingEncoding:NSUTF8StringEncoding];
	assert(keyTagData != nil);
  
	err = SecItemDelete((CFDictionaryRef)
                            [NSDictionary dictionaryWithObjectsAndKeys:
                             (id)
                             kSecClassKey,           kSecClass,
                             keyTagData,             kSecAttrApplicationTag,
                             nil
                             ]);

  if (err == errSecItemNotFound) {
    NSLog(@"unable to delete private key, already deleted");
  }
  else if (err) {
    NSLog(@"unable to delete private key, error: %d", err);
  }
  
  KeychainItemWrapper* creds = [[KeychainItemWrapper alloc] initWithIdentifier:CREDENTIALS_NAME accessGroup:nil];
  [creds resetKeychainItem];
  [creds release];

  KeychainItemWrapper* defaultAESKey = [[KeychainItemWrapper alloc] initWithIdentifier: @"DefaultAESKey" accessGroup:nil];
  [defaultAESKey resetKeychainItem];
  [defaultAESKey release];

  KeychainItemWrapper* defaultHMACKey = [[KeychainItemWrapper alloc] initWithIdentifier: @"DefaultHMACKey" accessGroup:nil];
  [defaultHMACKey resetKeychainItem];
  [defaultHMACKey release];

  KeychainItemWrapper* passphraseItemWrapper = [[KeychainItemWrapper alloc] initWithIdentifier: @"Passphrase" accessGroup:nil];
  [passphraseItemWrapper resetKeychainItem];
  [passphraseItemWrapper release];
  
	return;
}


// given a payload containing the user's private RSA key,
// decrypt it and return the key bytes
- (NSData*) decryptPrivateKey:(NSDictionary *)payload withPassphrase:(NSString*)passphrase
{
	/* Let's try to decrypt the user's private key */
	unsigned char final[32];
	unsigned char tsalt[50];
	NSData *salt = [[NSData alloc] initWithBase64EncodedString:
                  [payload objectForKey:@"salt"]];
	
	[salt getBytes: tsalt length: sizeof tsalt];
	
  const char* secretBytes = [passphrase UTF8String];
	PKCS5_PBKDF2_HMAC_SHA1(secretBytes,
                          -1, 
                         (void*)tsalt, 
                         [salt length], 
                         4096, 
                         32, 
                         final);
	[salt release];
	
	NSData *iv = [[[NSData alloc] initWithBase64EncodedString:[payload objectForKey:@"iv"]] autorelease];
	NSData *aesKey = [[[NSData alloc] initWithBytes:final length:32] autorelease];
	NSData *rawKey = [[[NSData alloc] initWithBase64EncodedString:[payload objectForKey:@"keyData"]] autorelease];
	NSData* rsaKey = [NSData plaintextDataByAES256DecryptingCiphertextData: rawKey key: aesKey iv: iv padding: YES];
	
  if (!rsaKey || [rsaKey length] < 23) return nil;  //probably wrong password
  
  //FIX FIX?  should this all be using NSData calls?  then we'd get exception
	
	/* Hmm, some ASN.1 parsing. YUCK */
	unsigned char *rsaKeyBytes = (unsigned char *)[rsaKey bytes];
	
	/* Is offset 22 a OCTET tag? */
  //This is some crazy magic byte that indicates it's actually ASN.1?
	int off = 22;  //it appears this is skipping over the OID header
	if (0x04 != (int)rsaKeyBytes[off++]) //0x04 is the DER indicator for an octet string
  {
		NSLog(@"No OCT tag found at offset 22 in RSA key!");
		return nil;
	}
	
	//now we need to find out how long the key is, so we can extract the correct hunk
  // of bytes from the buffer.
	int len = (int)rsaKeyBytes[off++];
  //is the high bit set?
	int det = len & 0x80;
  // no?  then the length of the key is a number that fits in one byte, (< 128)
	if (!det) 
  {
		len = len & 0x7f;
	} 
  else 
  { //otherwise, the length of the key is a number that doesn't fit in one byte (> 127)
		int byteCount = len & 0x7f;

    //if bytecount is longer than the bytes we have, we must bail
    if (byteCount + off > [rsaKey length])
    {
      NSLog(@"rsa length field longer than buffer");
      return nil;
    }
    
    //so we need to snip off byteCount bytes from the front, and reverse their order
    unsigned int accum = 0;
    unsigned char *ptr = &rsaKeyBytes[off];
    off += byteCount;
    //after each byte, we shove it over, accumulating the value into accum
    while (byteCount) 
    {
      accum = (accum << 8) + *ptr;
      ptr++;
      byteCount--;
    }
    
    //now we have read all the bytes of the key length, and converted them to a number,
    // which is the number of bytes in the actual key.  we use this below to extract the
    // key bytes and operate on them
    len = accum;
	}
  
	/* Now extract actual key */
  NSData* result = nil;
  @try {
    result = [rsaKey subdataWithRange:NSMakeRange(off, len)];
  }
  @catch (NSException * e) {
    NSLog(@"rsa key longer than buffer");
    result = nil;
  }

  return result;
}



- (NSData*) getSymmetricKeyForUrl:(NSString*)keyUrl
{
  //do we already have the symmetric key in the cache?
  NSData *theKey = nil;
  NSData *keyRing = nil;
  NSString* keyIndex = nil;
  
  if ((theKey = [_symmetricKeyCache objectForKey:keyUrl]) == nil) 
  {
    NSString* symmetricKeyPath = [self cryptoKeyURLForEngine:[[[NSURL URLWithString:keyUrl] path] lastPathComponent]];
    
    keyRing = [Fetcher getBytesFromURL:symmetricKeyPath authenticatingWith:self];

    if (_storageVersion == 2)
    {
      //the key into the dictionary is the full url
      keyIndex = [self absoluteURLForEngine:[Stockboy getURIForKey:@"Public Key Path"]];
    }
    else if (_storageVersion == 3)
    {
      //the key into the dictionary is just the relative url
      keyIndex = [NSString stringWithFormat:@"../%@", [Stockboy getURIForKey:@"Public Key Path"]];
    }
    
    theKey = [self unpackSymmetricKey:keyRing withURL:keyIndex andPrivateKey:_privateKey];
    if (theKey != nil)
      [_symmetricKeyCache setObject:theKey forKey:keyUrl];
    else 
    {
      NSException *e = [NSException exceptionWithName:PASSPHRASE_EXCEPTION_STRING
		reason:NSLocalizedString(@"Incorrect Secret Phrase", @"incorrect secret phrase") userInfo:nil];
      @throw e;
    }
  }
  
  return theKey;  
}

- (NSData *) unpackSymmetricKey:(NSData*)symmetricKeyData withURL:(NSString*)keyURL andPrivateKey:(SecKeyRef)privateKey
{
	NSString* symKeyString = [[[NSString alloc] initWithData:symmetricKeyData encoding:NSUTF8StringEncoding] autorelease];
	NSDictionary *symKeyDict = [symKeyString JSONValue];
  
	NSDictionary *payload = [[symKeyDict objectForKey:@"payload"] JSONValue];
	NSDictionary *keyring = [payload objectForKey:@"keyring"];
  NSDictionary *selectedKey = [keyring objectForKey:keyURL];
	
	NSData *wrappedKey = [[NSData alloc] initWithBase64EncodedString:[selectedKey objectForKey:@"wrapped"]];
	NSData *unwrappedKey = [self decryptSymmetricKey:wrappedKey withPrivateKey: privateKey];
  
	return unwrappedKey;
}

- (NSData *) decryptSymmetricKey:(NSData *)symKey withPrivateKey:(SecKeyRef) privateKey
{
	OSStatus err = noErr;
	size_t cipherBufferSize = 0;
	size_t keyBufferSize = 0;
	
	NSData *key = nil;
	uint8_t *keyBuffer = NULL;
	
	cipherBufferSize = SecKeyGetBlockSize(privateKey);
	keyBufferSize = [symKey length];
	
	// Allocate some buffer space. I don't trust calloc.
	keyBuffer = malloc( keyBufferSize * sizeof(uint8_t) );
	memset((void *)keyBuffer, 0x0, keyBufferSize);
	
	err = SecKeyDecrypt(
                      privateKey,
                      kSecPaddingPKCS1,
                      (const uint8_t *)[symKey bytes],
                      cipherBufferSize,
                      keyBuffer,
                      &keyBufferSize
                      );
	
	if (err != noErr) 
  {
		NSLog(@"Failed to decrypt symmetric key, error: %d", err);
    if (keyBuffer) free(keyBuffer);
    return nil;
	}
	
	key = [NSData dataWithBytes:(const void *)keyBuffer length:(NSUInteger)keyBufferSize];
	if (keyBuffer) free(keyBuffer);
	
	return key;
}

//Takes an EDO and returns a dictionary of the decrypted data object (WBO)
//MAY THROW PASSPHRASE_EXCEPTION_STRING!
- (NSMutableDictionary*) decryptDataObject:(NSDictionary*)dataObject mustVerify:(BOOL)verify
{
	// get the payload    
	NSDictionary *payload = [[dataObject objectForKey:@"payload"] JSONValue];
	//get the url for the symmetric key
	NSString *symKeyUrl = [payload objectForKey:@"encryption"];

	//reject non-EDOs, and storageFormat 1 EDO's
	if (_storageVersion == 2 && symKeyUrl == nil) {
		return nil; 
	}

	//get the IV
	NSData *initVector = [[[NSData alloc] initWithBase64EncodedString:[payload objectForKey:@"IV"]] autorelease];

	//get the ciphertext
	NSData *ciphertext = [[[NSData alloc] initWithBase64EncodedString:[payload objectForKey:@"ciphertext"]] autorelease];

	//get the correct symmetric key
	NSData *theKey = nil;

	switch (_storageVersion) {
		case 2:
		case 3:
			//can throw various exceptions, most notably PASSPHRASE_EXCEPTION_STRING
			theKey = [self getSymmetricKeyForUrl:symKeyUrl];
			break;
		case 5:
			theKey = [self encryptionKeyForCollection: nil]; // TODO New Crypto: We should pass the the collection name here eventually
			break;
	}

	//double-check we have good data
	if (initVector == nil || ciphertext == nil || theKey == nil) {
		return nil;
	}

	//decrypt, if it fails, we probably got our private and symmetric keys yanked out from under us
	NSString *plainText = [[NSString alloc] initWithData: [NSData plaintextDataByAES256DecryptingCiphertextData: ciphertext key: theKey iv: initVector padding: YES] encoding:NSUTF8StringEncoding];
	if (plainText == nil || [plainText length] == 0) {
		[plainText release];
		NSLog(@"Ignoring record: unable to decrypt");
		return nil;
//		NSException *e = [NSException exceptionWithName:PASSPHRASE_EXCEPTION_STRING
//			reason:NSLocalizedString(@"Incorrect Secret Phrase", @"incorrect secret phrase") userInfo:nil];
//		@throw e;
	}
	
	NSMutableDictionary* WBO = [plainText JSONValue];
	[plainText release]; //free immediately
	
	if (WBO == nil) {
		NSLog(@"Ignoring record: unable to decrypt WBO JSON");
		return nil;
	}

	//now do a few basic checks
	if (![[WBO objectForKey:@"id"] isEqualToString:[dataObject objectForKey:@"id"]]) {
		NSLog(@"Ignoring record: object id does not match encryptyed object id!");
		return nil;
	}

	//we do hmac verifications against all deleted objects
	if ([[WBO objectForKey:@"deleted"] boolValue] == YES || verify)
	{
		//get the hmac
		NSString* originalHmac = [payload objectForKey:@"hmac"];

		NSData* hmacKey = nil;

		switch (_storageVersion) {
			case 2:
			case 3:
				hmacKey = [[theKey base64Encoding] dataUsingEncoding: NSASCIIStringEncoding];
				break;
			case 5:
				hmacKey = [self hmacKeyForCollection: nil];
				break;
		}

		NSData* newHmacData = [[payload objectForKey:@"ciphertext"] HMACSHA256WithKey: hmacKey];
		NSString* newHmac = [newHmacData base16Encoding];
		if (![originalHmac isEqualToString:newHmac]) {
			NSLog(@"Ignoring record: hmac does not verify encrypted object!");
			return nil;
		}
	}

	return WBO;
}

- (NSData*) makeRandomBytesOfLength:(NSUInteger)length
{
  srandomdev();
  unsigned char* bytes = malloc(length);
  for (int i=0; i<length; i++)
  {
    bytes[i] = random()&0xFF;
  }
  NSData* iv = [NSData dataWithBytes:bytes length:length];
  return iv;
}

/**
 * Encode an email address so that it can be used as the username for the API. The
 * encoding is LowerCase(Base32(SHA1(LowerCase(emailaddresss))))
 */

- (NSString*) encodeEmailAddress: (NSString*) emailAddress
{
	return [[[[[emailAddress lowercaseString] dataUsingEncoding: NSUTF8StringEncoding] SHA160Hash]
		base32Encoding] lowercaseString];
}

//make sure all the properties you wish, and none that you don't, are in the dataObject before calling this
//Takes a dictionary of properties, encrypts it, and returns an properly constructed EDO as a dictionary
//MAY THROW PASSPHRASE_EXCEPTION_STRING, or other network related exceptions

- (NSMutableDictionary*) encryptDataObject:(NSDictionary*)dataObject withID:(NSString*)objectID amdSymmetricKeyURL:(NSString*)symKeyUrl
{
	//Step 1: turn the dictionary of properties into JSON, then into a utf8 string, then bytes
	NSString* plaintext = [dataObject JSONRepresentation];
	const char* utf8String = [plaintext UTF8String];
	int len = strlen(utf8String);
	NSData* plaintextBytes = [NSData dataWithBytes:utf8String length:len];
	//Step 3: get the appropriate symmetric key to encrypt this data type with.
	// this is up to the caller to get correct, by passing in the proper Url
	NSData *theKey = nil;

	theKey = [self getSymmetricKeyForUrl:symKeyUrl];

	//if the key is nil, then we probably have the wrong private key, so we have to ask the user if they want to re-login
	if (theKey == nil) {
		return nil;
	}

	//Step 4: encrypt the data to create the ciphertext
	// we need to make an init vector. ugh.
	NSData* initVector = [self makeRandomBytesOfLength:16];
	NSData* ciphertext = [NSData ciphertextDataByAES256EncrypingPlaintextData: plaintextBytes key: theKey iv: initVector padding: YES];
	NSData* HMAC = [[ciphertext base64Encoding] HMACSHA256WithKey: [[theKey base64Encoding] dataUsingEncoding: NSASCIIStringEncoding]];

	NSMutableDictionary* payload = [NSMutableDictionary dictionary];
	[payload setObject:symKeyUrl forKey:@"encryption"];
	[payload setObject:[ciphertext base64Encoding] forKey:@"ciphertext"];
	[payload setObject:[initVector base64Encoding] forKey:@"IV"];
	[payload setObject:[HMAC base16Encoding] forKey:@"hmac"];

	NSString* JSONPayload = [payload JSONRepresentation];

	//now we need to add 'id', 'modified', 'sortIndex' (?), and the payload to the final EDO object
	NSMutableDictionary* EDO = [NSMutableDictionary dictionary];
	[EDO setObject:JSONPayload forKey:@"payload"];
	[EDO setObject:objectID forKey:@"id"];
	[EDO setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"modified"];

	return EDO;
}

@end
