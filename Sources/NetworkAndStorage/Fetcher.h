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

#import <Foundation/Foundation.h>
#import "CryptoUtils.h"

#define AUTH_EXCEPTION_STRING @"AuthFail"

@interface Fetcher : NSObject 
{
}

//ALL OF THESE CALLS ARE SYNCHRONOUS, and WILL block, so must not be called from the main (UI) thread.
// They are currently called only from the Stockboy background thread
// ALL NSDATA ARGS ARE EXPECTED TO BE UTF8 ENCODED STRINGS

+ (NSData*) getWeaveBasicObject:(NSString*)url authenticatingWith:(CryptoUtils*)cryptoManager;
+ (NSData*) putWeaveBasicObject:(NSData*)object toURL:(NSString*)url authenticatingWith:(CryptoUtils*)cryptoManager;


//Called by the above routines after they construct the proper Weave url path.
// can also be called directly if you already have the full path to something, of course
+ (NSData *)getBytesFromURL:(NSString*)url authenticatingWith:(CryptoUtils*)cryptoManager;
+ (NSData *)putBytes:(NSData *)data toURL:(NSString *)url authenticatingWith:(CryptoUtils*)cryptoManager;

//synchronous unauthenticated url retrieval
+ (NSData *) getBytesFromPublicURL:(NSString *)url;

@end

