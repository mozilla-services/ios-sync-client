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
#import <sqlite3.h>

//Changing this class to be a write-through cache.
// asking for data causes the encrypted data to be read from disk, decrypted, and cached in memory, for subsequent reads.
// setting new (encrypted) data flushes the cache, and overwrites the data on disk.  next read will cause a decrypt and cache.


@interface Store : NSObject {
  @private
	sqlite3             *sqlDatabase;
	NSMutableArray      *tabs;
	NSMutableArray      *history;
	NSMutableArray      *bookmarkListSortedByFrecency;
	NSMutableDictionary *hierarchicalBookmarks;
}

//if the global is null, it loads the default store
+ (Store*) getStore;
+ (void) deleteStore;

//these three return a frecency-sorted list, for fast searching
- (NSArray*)getTabs;
- (NSArray*)getHistory;
- (NSArray*)getBookmarks;

//uses instance var 'sortedBookmarks', which is a dictionary mapping folderid to sorted list of items in that folder
- (NSArray*)getBookmarksWithParent:(NSString*) parentid;

- (BOOL) installTabSetDictionary:(NSDictionary*)tabSetDict;

//these take an array of dictionaries for the added items, and a list of dictionaries for the deleted ones
- (void) updateBookmarksAdding: (NSArray*) addedBmarks andRemoving: (NSArray*) removedBmarks;
- (void) updateHistoryAdding: (NSArray*) addedHistory andRemoving: (NSArray*) removedHistory fullRefresh:(BOOL)full;

//used for storing timestamps to keep track of latest updates to other tables
-(double) getTimestamp: (NSString*)label;
- (BOOL) updateTimestamp: (NSString*)label;

@end
