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

#import <Foundation/Foundation.h>
#import <Security/Security.h>

#import "KeychainItemWrapper.h"
#import "Utility.h"

#define KEY_SIZE			2048
#define PRIV_KEY_NAME		@"private"

#define CREDENTIALS_NAME @"credentials"
#define USERNAME_ITEM_KEY @"username"
#define PASSWORD_ITEM_KEY @"password"

#define PASSPHRASE_EXCEPTION_STRING @"CryptoFail"

@interface CryptoUtils : NSObject
{
	//this needs to be updated whenever the cluster is updated
	int _storageVersion;

	NSString* _syncID;

	//DO NOT FORGET TO UTF8 CONVERT THESE THREE STRINGS BEFORE SENDING THEM OVER THE WIRE
	KeychainItemWrapper* _credentials;
	//location against which to make all weave requests for the user
	NSString* _cluster;

	//The users private key. used to decrypt the symmetric keys used to encrypt their actual data.
	// note that we do  not store the passphrase anywhere
	SecKeyRef _privateKey;

	KeychainItemWrapper* _defaultAESKey;
	KeychainItemWrapper* _defaultHMACKey;

	//The users public key. not currently needed.
	// won't be needed until and unless we start creating new symmetric keys on the phone/pad
	// which aren't needed unless we start making new categories on the phone/pad
	//SecKeyRef _publicKey;

	//a list of the symmetric keys we've used, so that we don't have to fetch them from the server more than once
	NSMutableDictionary* _symmetricKeyCache;
}

//NOTE: this will either return a valid cryptoutils or nil!
// nil means try again later!
+ (CryptoUtils*) getManager;
//create one if we don't have one
+ (void) createManager;
//release one if we have it
+ (void) discardManager;
//NOTE: THIS IS ONLY USED BY THE LOGIN CONTROLLER, TO ASSIGN THE SINGLETON THAT WAS CREATED BY USER LOGIN
+ (void) assignManager:(CryptoUtils*)newManager;

//instance methods
- (NSString*) cluster;
- (NSString*) accountName;
- (NSString*) username;
- (NSString*) password;
- (SecKeyRef) privateKey;
- (int) storageVersion;

//this initializer does a lot of heavy lifting.  it gets the cluster, retrieves the private key, checks it and puts it in the keychain if necessary,
// checks the server-side client list to make sure we are listed and updates it if necessary, (which requires crypto), initializes the symmetric key cache, 
// and gets ready to decrypt objects
- (id) initWithAccountName:(NSString*)accountName password:(NSString*)password andPassphrase:(NSString*)passphrase;

//this retrieves the cluster again, which avoids a number of problems. We do it before every sync.
// returns true if a valid cluster was retrieved
- (BOOL) updateCluster;

// create an absolute url to a weave resource
- (NSString*) absoluteURL: (NSString*) path;

//create an absolute url to a weave engine (collection)
- (NSString*)absoluteURLForEngine:(NSString*)engineAndQuery;

//create an absolute url to the symmetric key for a weave engine (collection)
- (NSString*)cryptoKeyURLForEngine:(NSString*)engine;


//unpacks the EDO and gets the payload, which it then decrypts, and creates an NSDictionary from the JSON
// normally, only objects that are to be deleted have their HMAC verified, but you can override this, and
// force a verify on any individual object with the last argument
- (NSMutableDictionary*) decryptDataObject:(NSDictionary*)dataObject mustVerify:(BOOL)verify;

//Converts the data object to json, then encrypts it and makes it ready for shipping off to the server.  We must generate a random IV, and also provide an HMAC-SHA256.
- (NSMutableDictionary*) encryptDataObject:(NSDictionary*)dataObject withID:(NSString*)objectID amdSymmetricKeyURL:(NSString*)symKeyUrl;

//this is the only class method, and it simply wipes the keychain.
// no user information is necessary to do this, so no instance of this class need be involved
+ (void) deletePrivateKeys;

- (NSDictionary*) downloadKeysWithUsername: (NSString*) username passphraseData: (NSData*) passphraseData;

@end
