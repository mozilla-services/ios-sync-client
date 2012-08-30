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

// The stockboy, a singleton, is responsible for checking to see
// if the user's data is fresh, and if not, downloading the latest
// info from the server and installing it in the Store.  

@interface Stockboy : NSObject 
{
  // our thread of execution. we need to be able to cancel it, so we save it here.
  NSThread* _stockboyThread;
      
  //a flag we use to set that something went wrong during a sync, so we can display some ui to that effect
  BOOL syncCompletedSuccessfully;
}

// initialize the nscondition
+ (void) prepare;

//tells the Stockboy to begin restocking
+ (void) restock;

// tells ths Stockboy to quit as soon as possible
+ (void) cancel;

// test to see if a sync is in progress and a Condition to protect access and allow waiting on it
+ (NSCondition*) syncLock;
+ (BOOL) syncInProgress;


//returns the isCancelled flag of the stockboy's thread
// called as often as possible, so we can exit gracefully
+ (BOOL) isCancelled;


// global dictionary for finding locations of canonical weave objects
+ (NSString *) getURIForKey:(NSString*)name;

@end
