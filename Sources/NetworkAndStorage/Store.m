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

#import "Store.h"
#import "Fetcher.h"
#import "Utility.h"
#import "JSON.h"

//need to include Stockboy for now, to be able to interrupt the lengthy refresh when the thread is cancelled
#import "Stockboy.h"
//sigh, need to tell the app to refresh views
#import "WeaveAppDelegate.h"

#define TABS_URL_COLUMN       0
#define TABS_TITLE_COLUMN     1
#define TABS_FAVICON_COLUMN   2
#define TABS_CLIENT_COLUMN    3
#define TABS_MODIFIED_COLUMN  4
#define TABS_SORTINDEX_COLUMN 5

#define HISTORY_ID_COLUMN         0
#define HISTORY_URL_COLUMN        1
#define HISTORY_TITLE_COLUMN      2
#define HISTORY_FAVICON_COLUMN    3
#define HISTORY_MODIFIED_COLUMN   4
#define HISTORY_SORTINDEX_COLUMN  5

#define BOOKMARKS_ID_COLUMN               0
#define BOOKMARKS_URL_COLUMN              1
#define BOOKMARKS_TITLE_COLUMN            2
#define BOOKMARKS_FAVICON_COLUMN          3
#define BOOKMARKS_TYPE_COLUMN             4
#define BOOKMARKS_PARENTID_COLUMN         5
#define BOOKMARKS_PREDECESSORID_COLUMN    6
#define BOOKMARKS_DESCRIPTION_COLUMN      7
#define BOOKMARKS_MODIFIED_COLUMN         8
#define BOOKMARKS_SORTINDEX_COLUMN        9



#define DATABASE_NAME @"/ffhomeDB.sq3"



@interface Store (Private)
-(Store *) initWithDBFile:(NSString *)filePath;
- (void) loadTabsFromDB;
- (void) loadHistoryFromDB;
- (void) loadBookmarksFromDB;
- (void) initializeFaviconDictionary;


- (BOOL) addBookmarkRecord:(NSDictionary *)bookmark;
- (BOOL) removeBookmarkRecord: (NSDictionary*)bookmark;

- (BOOL) addHistoryItem:(NSDictionary *)historyItem;
- (BOOL) removeHistoryItem:(NSDictionary *)historyItem;

@end

@implementation Store

// The singleton instance
static Store* _gStore = nil;

//CLASS METHODS////////
+ (Store*)getStore
{
	if (_gStore == nil) {
		_gStore = [[[Store alloc] init] retain];
	}

	return _gStore;
}

+ (void) deleteStore
{
	[_gStore release];
	_gStore = nil;

	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDir = [paths objectAtIndex:0];
	NSString *databasePath = [documentsDir stringByAppendingString:DATABASE_NAME];

	NSError* err = nil;
	BOOL success = [fileManager removeItemAtPath:databasePath error:&err];
	if (!success && err != nil) {
		NSLog(@"database delete failed: %@", err);
	}
}

#pragma mark -

-(Store *) init 
{
	self = [super init];
	
	if (self) 
	{
		BOOL success;
		NSError *error = nil;
						
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDir = [paths objectAtIndex:0];
		NSString *databasePath = [documentsDir stringByAppendingString:DATABASE_NAME];
		
		/* DB already exists */
		success = [fileManager fileExistsAtPath:databasePath];
		if (success) 
		{
			NSLog(@"Existing DB found, using");
			if (sqlite3_open([databasePath UTF8String], &sqlDatabase) == SQLITE_OK) 
			{
				[self loadTabsFromDB];
				[self loadHistoryFromDB];
				[self loadBookmarksFromDB];
				return self;
			} 
			else 
			{
				NSLog(@"Could not open database!");
				// TODO this should be a fatal
				return nil;
			}
		}
		
		/* DB doesn't exist, copy from resource bundle */
		NSString *defaultDB = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:DATABASE_NAME];
		
		success = [fileManager copyItemAtPath:defaultDB toPath:databasePath error:&error];
		if (success) {
			if (sqlite3_open([databasePath UTF8String], &sqlDatabase) == SQLITE_OK) {
				tabs = [[NSMutableArray array] retain];
				history = [[NSMutableArray array] retain];
				bookmarkListSortedByFrecency = [[NSMutableArray array] retain];
				return self;
			} else {
				NSLog(@"Could not open database!");
			}
		} else {
			NSLog(@"Could not create database!");
			NSLog(@"%@", [error localizedDescription]);
		}
	}
	return NULL;
}

-(void) dealloc
{
	sqlite3_close(sqlDatabase);
	[tabs release];
	tabs = nil;
	[bookmarkListSortedByFrecency release];
	bookmarkListSortedByFrecency = nil;
	[hierarchicalBookmarks release];
	hierarchicalBookmarks = nil;
	[history release];
	history = nil;
	[super dealloc];
}

#pragma mark -

-(double) getTimestamp: (NSString*)label
{
	double time = 0;
	sqlite3_stmt *stmnt = nil;
	const char *sql = "SELECT timestamp FROM timestamps WHERE type = ?";

	if (sqlite3_prepare_v2(sqlDatabase, sql, -1, &stmnt, NULL) != SQLITE_OK) 
	{
		const char *errorStr = sqlite3_errmsg(sqlDatabase);
		NSLog(@"getTimestamp (%@) prepare: %s", label, errorStr);
		return 0;
	} 
	else 
	{
		sqlite3_bind_text(stmnt, 1, [label UTF8String], -1, SQLITE_TRANSIENT);

		if (sqlite3_step(stmnt) == SQLITE_ROW) 
		{
			time = sqlite3_column_double(stmnt, 0);
		} 
		else 
		{
			const char *errorStr = sqlite3_errmsg(sqlDatabase);
			NSLog(@"getTimestamp (%@) step: %s", label, errorStr);
			sqlite3_finalize(stmnt);
			return 0;
		}		
	}

	return time;
}


- (BOOL) updateTimestamp: (NSString*)label
{
	sqlite3_stmt *stmnt = nil;
	const char *sql = "INSERT OR REPLACE INTO timestamps ('timestamp', 'type') VALUES (?, ?)";

	if (sqlite3_prepare_v2(sqlDatabase, sql, -1, &stmnt, NULL) != SQLITE_OK) 
	{
		const char *errorStr = sqlite3_errmsg(sqlDatabase);
		NSLog(@"updateTimestamp (%@) prepare: %s", label, errorStr);
		return NO;
	} 
	else 
	{
		sqlite3_bind_double(stmnt, 1, [[NSDate date] timeIntervalSince1970]);
		sqlite3_bind_text(stmnt, 2, [label UTF8String], -1, SQLITE_TRANSIENT);

		if (sqlite3_step(stmnt) != SQLITE_DONE) 
		{
			const char *errorStr = sqlite3_errmsg(sqlDatabase);
			NSLog(@"updateTimestamp (%@) step: %s", label, errorStr);
			sqlite3_finalize(stmnt);
			return NO;
		}
	}

	sqlite3_finalize(stmnt);

	return YES;	
}
  

-(BOOL) beginTransaction
{
	sqlite3_stmt *stmnt = nil;
	const char *sql = "BEGIN IMMEDIATE TRANSACTION";
	int err = 0;

	if ((err = sqlite3_prepare_v2(sqlDatabase, sql, -1, &stmnt, NULL)) != SQLITE_OK) 
	{
		NSLog(@"Could not prepare open transaction statement: %d", err);
		return NO;
	} 
	else 
	{
		if ((err = sqlite3_step(stmnt)) != SQLITE_DONE) 
		{
			NSLog(@"Could not open transaction: %d", err);
			sqlite3_finalize(stmnt);
			return NO;
		}
	}

	sqlite3_finalize(stmnt);

	return YES;	
}

-(BOOL) endTransaction
{
	sqlite3_stmt *stmnt = nil;
	const char *sql = "COMMIT TRANSACTION";
	int err = 0;

	if ((err = sqlite3_prepare_v2(sqlDatabase, sql, -1, &stmnt, NULL)) != SQLITE_OK) 
	{
		NSLog(@"Could not prepare commit transaction statement: %d", err);
		return NO;
	} 
	else 
	{
		if ((err = sqlite3_step(stmnt)) != SQLITE_DONE) 
		{
			NSLog(@"Could not commit transaction: %d", err);
			sqlite3_finalize(stmnt);
			return NO;
		}
	}

	sqlite3_finalize(stmnt);

	return YES;	
}

- (NSArray*)  getTabs
{
	return tabs;
}

- (NSArray*) getHistory
{
	return history;
}

- (NSArray*) getBookmarks
{
	return bookmarkListSortedByFrecency;
}

//deletes every item in the tabs table, clearing it
-(void) deleteTabs
{
	const char *sql;
	sqlite3_stmt *stmnt = nil;

	sql = "DELETE FROM tabs";
	if (sqlite3_prepare_v2(sqlDatabase, sql, -1, &stmnt, NULL) != SQLITE_OK) 
	{
		NSLog(@"Could not prepare statement!");
	} 
	else 
	{
		if (sqlite3_step(stmnt) != SQLITE_DONE) 
		{
			NSLog(@"failed to delete tabs");
			sqlite3_finalize(stmnt);
		}
	}
	
	sqlite3_finalize(stmnt);
}

//deletes every item in the history table, clearing it
-(void) deleteHistory
{
	const char *sql;
	sqlite3_stmt *stmnt = nil;

	sql = "DELETE FROM history";
	if (sqlite3_prepare_v2(sqlDatabase, sql, -1, &stmnt, NULL) != SQLITE_OK) 
	{
		NSLog(@"Could not prepare statement!");
	} 
	else 
	{
		if (sqlite3_step(stmnt) != SQLITE_DONE) 
		{
			NSLog(@"failed to delete history");
			sqlite3_finalize(stmnt);
		}
	}

	sqlite3_finalize(stmnt);
}

///////////////////////////////////////////////////////////////////////
//LOADS TABS SORTED BY FRECENCY INTO MEMORY

-(void)loadTabsFromDB
{
	//ok, for easier use with the UI code, we're going to load the tabs into a structure with the following shape:
	// * Array, one slot for each client, which is a:
	//   * Dictionary, containing:
	//     * String (the client guid) with key 'guid'
	//     * String (the client name) with key 'client'
	//     * Array (the tabs) with key 'tabs', containing:
	//       * Dictionary (the tab properties) containing:
	//         * String (the title) with key 'title'
	//         * String (the url) with key 'url'
	//         * String (the icon) with key 'icon'

	sqlite3_stmt *dbStatement = nil;
	const char *tabQuery = "SELECT * FROM tabs";
	NSString* icon;

	if (sqlite3_prepare_v2(sqlDatabase, tabQuery, -1, &dbStatement, NULL) == SQLITE_OK) 
	{
		//ok, this is a temporary dictionary to build our data structure.
		NSMutableDictionary* temporaryTabIndex = [[NSMutableDictionary alloc] initWithCapacity:20];

		while (sqlite3_step(dbStatement) == SQLITE_ROW) 
		{
			icon = @"tab.png";

			NSString *client = [NSString stringWithUTF8String:(char *)sqlite3_column_text(dbStatement, TABS_CLIENT_COLUMN)];

			NSMutableDictionary* thisClient = [temporaryTabIndex objectForKey:client];

			if (thisClient == nil)
			{
				thisClient = [NSMutableDictionary dictionary];
				[thisClient setObject:client forKey:@"client"];
				[thisClient setObject:[NSMutableArray array] forKey:@"tabs"];
				[temporaryTabIndex setObject:thisClient forKey:client];
			}

			[[thisClient objectForKey:@"tabs"] addObject:
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSString stringWithUTF8String:(char *)sqlite3_column_text(dbStatement, TABS_TITLE_COLUMN)], @"title",
					[NSString stringWithUTF8String:(char *)sqlite3_column_text(dbStatement, TABS_URL_COLUMN)], @"url",
					[NSNumber numberWithDouble:(double)sqlite3_column_double(dbStatement, TABS_SORTINDEX_COLUMN)], @"sortindex",
					icon, @"icon",
					nil]];
		}

		sqlite3_finalize(dbStatement);

		NSMutableArray* newTabs = [[NSMutableArray alloc] initWithCapacity:20];

		id key;
		NSEnumerator *enumerator = [temporaryTabIndex keyEnumerator];

		while ((key = [enumerator nextObject])) {
			[newTabs addObject:[temporaryTabIndex objectForKey:key]];
		}

		[temporaryTabIndex release];

		//now sort the new tabs by frecency
		[newTabs sortUsingFunction:compareSearchResults context:NULL];

		NSMutableArray* temp = tabs;
		tabs = newTabs;
		[temp release];
	} 
}

//LOADS HISTORY SORTED BY FRECENCY INTO MEMORY
- (void) loadHistoryFromDB
{
	sqlite3_stmt *dbStatement = nil;
	const char *historyQuery = "SELECT * FROM history";
	NSString* icon;

	NSMutableArray* newHistory = [[NSMutableArray alloc] init];

	/* Load existing history */
	if (sqlite3_prepare_v2(sqlDatabase, historyQuery, -1, &dbStatement, NULL) == SQLITE_OK) 
	{
		while (sqlite3_step(dbStatement) == SQLITE_ROW) 
		{
			icon = @"history.png";

			NSMutableDictionary *historyItem = [[NSMutableDictionary alloc] initWithCapacity:5];

			NSString *id_col = [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(dbStatement, HISTORY_ID_COLUMN)];
			NSString *url_col = [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(dbStatement, HISTORY_URL_COLUMN)];
			NSString *title_col = [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(dbStatement, HISTORY_TITLE_COLUMN)];
			NSNumber *sort_col = [[NSNumber alloc] initWithDouble:(double)sqlite3_column_double(dbStatement, BOOKMARKS_SORTINDEX_COLUMN)];

			[historyItem setObject:id_col forKey:@"id"];
			[historyItem setObject:url_col forKey:@"url"];
			[historyItem setObject:title_col forKey:@"title"];
			[historyItem setObject:sort_col forKey:@"sortindex"];
			[historyItem setObject:icon forKey:@"icon"];

			[newHistory addObject:historyItem];
													 
			[id_col release];  
			[url_col release];
			[title_col release];
			[sort_col release];

			[historyItem release];
		}

		sqlite3_finalize(dbStatement);
	} 

	//now sort the history by frecency
	[newHistory sortUsingFunction:compareSearchResults context:NULL];

	NSMutableArray* temp = history;
	history = newHistory;
	[temp release];
}



- (NSArray*) getBookmarksWithParent:(NSString*) parentid
{
	//this is now a one-liner, with no database calls.
	// we can't have multiple threads hitting the database or Bad Things happen sometimes
	NSArray* result = [hierarchicalBookmarks objectForKey:parentid];
	if (!result) {
		result = [NSArray array];
	}
	
	return result;
}


//input: all items in the folder, in a dictionary keyed by their unique id, for easy lookup
- (NSArray*) sortFolderBookmarks:(NSMutableDictionary*)bookmarksKeyedById
{
	//ok, now sort the list according to the predecessor references.  HA!  how naive.
	// It turns out that the places DB in most instances of Firefox is completely borked,
	// but the Firefox code that reads it out and renders it into nice menus is basically a heuristic,
	// and doesn't really care if the data is discontigous, missing, or just broken.  It makes a good guess, and displays it.

	//So, sadly I must do the same.

	//I'm going to do a kind of multi-insertion sort
	// First, find all [0-n] items that have a predecessor that's not in the list.  They are the starting points of linked lists. 
	// insert them into my 'sorted' array in the order I find them.

	NSMutableArray* listHeads = [NSMutableArray array];
	NSMutableDictionary* bookmarksKeyedByPred = [NSMutableDictionary dictionary];

	//collect up all the starts of lists
	for (NSDictionary* item in [bookmarksKeyedById allValues])
	{
		NSString* predecessor = [item objectForKey:@"predecessorid"];
		if ([bookmarksKeyedById objectForKey:predecessor] == nil)
		{
			//we've found an item who's predecessor isn't in our list of all items in this folder, so it must be one of the 1..n sortedlist heads
			[listHeads addObject:item];
		}
		else //created a list of the rest indexed by predecessor for building the chains
		{
			[bookmarksKeyedByPred setObject:item forKey:predecessor];
		}
	}


	NSMutableDictionary* bookmark;

	NSMutableArray* sortedResults = [NSMutableArray array];
	for (NSMutableDictionary* head in listHeads)
	{
		[sortedResults addObject:head];
		NSString* nextid = [head objectForKey:@"id"];
		while ((bookmark = [bookmarksKeyedByPred objectForKey:nextid]) != nil) 
		{
			[sortedResults addObject:bookmark];
			nextid = [bookmark objectForKey:@"id"];
		}
	}

	//now strip out anything that isn't a bookmark or folder
	NSPredicate* onlyFoldersAndBookmarks = [NSPredicate predicateWithFormat:@"(type == %@ || type == %@)", @"bookmark", @"folder"];  
	[sortedResults filterUsingPredicate:onlyFoldersAndBookmarks];
	return sortedResults;
}



//LOADS BOOKMARKS SORTED BY FRECENCY INTO MEMORY

//we load all the bookmarks into memory, and index them two ways:  a full list, in no particular order, of just bookmark objects
// and also a dictionary that has keys for every folder in the tree, mapped to an array of all the items (bookmarks and folders) in that folder, in the proper order
-(void) loadBookmarksFromDB
{
	sqlite3_stmt *dbStatement = nil;
	const char *bookmarkQuery = "SELECT * FROM bookmarks";

	NSMutableArray* newBookmarkListSortedByFrecency = [[NSMutableArray alloc] initWithCapacity:200];
	NSMutableDictionary* newHierarchicalBookmarks = [[NSMutableDictionary alloc] initWithCapacity:200];

	int predKey = 0;

	//load any bookmarks we can find in the db
	if (sqlite3_prepare_v2(sqlDatabase, bookmarkQuery, -1, &dbStatement, NULL) == SQLITE_OK) 
	{
		while (sqlite3_step(dbStatement) == SQLITE_ROW) 
		{
			NSMutableDictionary* bmkEntry = [[NSMutableDictionary alloc] initWithCapacity:10];

			NSString* icon = @"bookmark.png";  //use default icon

			NSString* url = @"";
			if ((char *)sqlite3_column_text(dbStatement, BOOKMARKS_URL_COLUMN)) 
			{
				NSString* temp = [NSString stringWithUTF8String:(char *)sqlite3_column_text(dbStatement, BOOKMARKS_URL_COLUMN)]; 
				if ((id)temp != [NSNull null]) url = temp;
			}

			//I need to make unique 'fake' predecessor ids for objects that have none, and therefore are the starting point of a (sub)list of bookmarks.
			predKey++;
			NSString* predecessor = [NSString stringWithFormat:@"HEAD_%d", predKey];

			if ((char *)sqlite3_column_text(dbStatement, BOOKMARKS_PREDECESSORID_COLUMN)) 
			{
				NSString* temp = [NSString stringWithUTF8String:(char *)sqlite3_column_text(dbStatement, BOOKMARKS_PREDECESSORID_COLUMN)]; 
				if ((id)temp != [NSNull null]) predecessor = temp;
			}

			NSString* title = @"";
			if ((char *)sqlite3_column_text(dbStatement, BOOKMARKS_TITLE_COLUMN)) 
			{
				NSString* temp = [NSString stringWithUTF8String:(char *)sqlite3_column_text(dbStatement, BOOKMARKS_TITLE_COLUMN)]; 
				if ((id)temp != [NSNull null]) title = temp;
			}

			//add the unchecked fields
			[bmkEntry setObject:[NSString stringWithUTF8String:(char *)sqlite3_column_text(dbStatement, BOOKMARKS_ID_COLUMN)] forKey:@"id"];
			[bmkEntry setObject:[NSString stringWithUTF8String:(char *)sqlite3_column_text(dbStatement, BOOKMARKS_PARENTID_COLUMN)] forKey:@"parentid"];
			[bmkEntry setObject:[NSString stringWithUTF8String:(char *)sqlite3_column_text(dbStatement, BOOKMARKS_TYPE_COLUMN)] forKey:@"type"];
			[bmkEntry setObject:[NSNumber numberWithDouble:(double)sqlite3_column_double(dbStatement, BOOKMARKS_SORTINDEX_COLUMN)] forKey:@"sortindex"];

			//add the checked fields
			[bmkEntry setObject:predecessor forKey:@"predecessorid"];
			[bmkEntry setObject:url forKey:@"url"];
			[bmkEntry setObject:icon forKey:@"icon"];
			[bmkEntry setObject:title forKey:@"title"];


			//ok, now if it's a bookmark object, then add it to the big list used for searching
			if ([[bmkEntry objectForKey:@"type"] isEqualToString:@"bookmark"]) {
				[newBookmarkListSortedByFrecency addObject:bmkEntry];
			}

			//and add all entries to the appropriate parent dictionary in the sorted list/tree thingie
			NSMutableDictionary* parentList = [newHierarchicalBookmarks objectForKey:[bmkEntry objectForKey:@"parentid"]];
			if (parentList == nil)
			{
				parentList = [[NSMutableDictionary alloc] init];
				[newHierarchicalBookmarks setObject:parentList forKey:[bmkEntry objectForKey:@"parentid"]];
				[parentList release];
			}

			[parentList setObject:bmkEntry forKey:[bmkEntry objectForKey:@"id"]];
			[bmkEntry release];
		}

		sqlite3_finalize(dbStatement);
	} 


	//now I just need to sort the sorted list(s) by predecessor
	for (NSString* folderid in [newHierarchicalBookmarks allKeys])
	{
		NSMutableDictionary* itemsInFolder = [newHierarchicalBookmarks objectForKey:folderid];
		NSArray* result = [self sortFolderBookmarks:itemsInFolder];
		[newHierarchicalBookmarks setObject:result forKey:folderid];
	}

	NSMutableDictionary* tempSorted = hierarchicalBookmarks;
	hierarchicalBookmarks = newHierarchicalBookmarks;
	[tempSorted release];

	//now sort the bookmark _list_ by frecency
	[newBookmarkListSortedByFrecency sortUsingFunction:compareSearchResults context:NULL];
	NSMutableArray* temp = bookmarkListSortedByFrecency;
	bookmarkListSortedByFrecency = newBookmarkListSortedByFrecency;
	[temp release];
}



- (void) updateBookmarksAdding: (NSArray*) addedBmarks andRemoving: (NSArray*) removedBmarks
{
	// Use a transaction to put them in the database safely
	[self beginTransaction];

	// First, delete all the dead bookmarks.
	for (NSDictionary* deadBookmark in removedBmarks) {
		[self removeBookmarkRecord:deadBookmark];
	}

	// Second, insert all the new bookmarks 
	for (NSDictionary* bookmark in addedBmarks) {
		[self addBookmarkRecord:bookmark];
	}

	// For Bookmarks v2 the predecessorid is dropped in favor of a children array on the
	// parent folder. Since we do not want to maintain two copies of the storage format
	// here in Home, we simply turn those child ids into predecessorids. We don't check
	// for the storage format version. Instead we simply assume that the presence of the
	// children array means that we are on v2 or higher.
	
	for (NSDictionary* record in addedBmarks)
	{
		if ([[record objectForKey: @"type"] isEqualToString: @"folder"])
		{
			NSArray* children = [record objectForKey: @"children"];
			if (children != nil)
			{					
				for (NSUInteger i = 0; i < [children count]; i++)
				{
					NSString* recordid = [children objectAtIndex: i];
					id predecessorid = (i > 0) ? [children objectAtIndex: i - 1] : @"";
					
					const char* sql = "UPDATE bookmarks SET predecessorid = ? where id = ?";
					sqlite3_stmt *stmnt = NULL;

					if (sqlite3_prepare_v2(sqlDatabase, sql, -1, &stmnt, NULL) != SQLITE_OK) {
						NSLog(@"Could not prepare statement: %s", sql);
					} else {					
						sqlite3_bind_text(stmnt, 1, [predecessorid UTF8String], -1, SQLITE_TRANSIENT);
						sqlite3_bind_text(stmnt, 2, [recordid UTF8String], -1, SQLITE_TRANSIENT);
					
						int stepErr = sqlite3_step(stmnt);
						if (stepErr != SQLITE_DONE) {
							NSLog(@"sqlite3_step failed: %s", sqlite3_errmsg(sqlDatabase));
						}
						
						int finalizeErr = sqlite3_finalize(stmnt);
						if (finalizeErr != SQLITE_OK) {
							NSLog(@"sqlite3_finalize failed: %s", sqlite3_errmsg(sqlDatabase));
						}
					}
				}
			}
		}
	}

	[self updateTimestamp:@"bookmarks"];
	[self endTransaction];
	[self loadBookmarksFromDB];
}


///////////////////////////////////////////////////////////////////////
-(BOOL) addBookmarkRecord:(NSDictionary*)bookmark 
{
	//Insert the bookmark directly into the bookmarks table.
	// we don't need to check the type, just stuff them in, putting in all the fields we have
	const char *sql = "INSERT OR REPLACE INTO bookmarks ('id', 'url', 'title', 'favicon', 'type', 'parentid', 'predecessorid', 'description', 'modified', 'sortindex') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
	sqlite3_stmt *stmnt = nil;
	BOOL result = NO;
	int stepErr = 0;

	if (sqlite3_prepare_v2(sqlDatabase, sql, -1, &stmnt, NULL) != SQLITE_OK) 
	{
		NSLog(@"Could not prepare statement!");
	}
	else  //we're handling bookmarks and folders of bookmarks here, which only mostly overlap fields, so some fiddling is required
	{    
		@try
		{
			//LOTS of error checking
			NSString* faviconPath = @""; //unused
			NSString* url = [bookmark objectForKey:@"bmkUri"];
			if (url == nil || (id)url == [NSNull null]) {
				url = @"";
			}

			//sometimes, title is empty.  if it is a folder, then we have no choice but to call it "Unnamed"
			// if it's a bookmark, then we can name it the URL, if it has one, which is the expected case
			NSString* title = [bookmark objectForKey:@"title"];
			if (title == nil || (id)title == [NSNull null]) {
				title = url;
			}

			NSString* predecessorID = [bookmark objectForKey:@"predecessorid"];
			if (predecessorID == nil || (id)predecessorID == [NSNull null]) {
				predecessorID = @"";
			}

			NSString* desc = [bookmark objectForKey:@"description"];
			if (desc == nil || (id)desc == [NSNull null]) {
				desc = @"";
			}

			sqlite3_bind_text(stmnt, 1, [[bookmark objectForKey:@"id"] UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmnt, 2, [url UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmnt, 3, [title UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmnt, 4, [faviconPath UTF8String], -1, SQLITE_TRANSIENT);

			sqlite3_bind_text(stmnt, 5, [[bookmark objectForKey:@"type"] UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmnt, 6, [[bookmark objectForKey:@"parentid"] UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmnt, 7, [predecessorID UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmnt, 8, [desc UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_double(stmnt, 9, [[bookmark objectForKey:@"modified"] doubleValue]);
			sqlite3_bind_int(stmnt, 10, [[bookmark objectForKey:@"sortindex"] intValue]);

			stepErr = sqlite3_step(stmnt);
		}

		@catch (NSException *exception) 
		{
			NSLog(@"Malformed bookmark data: %@",[exception name], [exception reason]);
		}

		@finally 
		{
			int resultCode = sqlite3_finalize(stmnt);
			if (resultCode != SQLITE_OK || stepErr != SQLITE_DONE)
			{
				NSLog(@"Error storing bookmark: %d  %d)", stepErr, resultCode);
				result = NO;
			}
		}
	}

	return result;
}


//SHOULD REMOVE THE FAVICON TOO
- (BOOL) removeBookmarkRecord: (NSDictionary*)bookmark
{
	const char *sql;
	sqlite3_stmt *stmnt = nil;
	NSString* id = [bookmark objectForKey:@"id"];

	sql = "DELETE FROM bookmarks where id = ?";
	if (sqlite3_prepare_v2(sqlDatabase, sql, -1, &stmnt, NULL) != SQLITE_OK) {
		NSLog(@"Could not prepare bookmark deletion statement");
		return NO;
	} else {
		sqlite3_bind_text(stmnt, 1, [id UTF8String], -1, SQLITE_TRANSIENT);
		if (sqlite3_step(stmnt) != SQLITE_DONE) {
			NSLog(@"Could not remove bookmark from db");
			sqlite3_finalize(stmnt);
			return NO;
		}
	}

	sqlite3_finalize(stmnt);

	return YES;
}


///////////////////////////////////////////
// if we are doing a full refresh, then we clear the database first.
// otherwise we do an incremental update, adding and deleting

- (void) updateHistoryAdding: (NSArray*) addedHistory andRemoving: (NSArray*) removedHistory fullRefresh:(BOOL)full
{
	// Use a transaction to put them in the database safely
	// This can easily all be moved into the Store, and just pass in both lists
	[self beginTransaction];

	//if we were told that this was a full refresh, then empty the database
	if (full)
	{
		[self deleteHistory];
	}

	//if we are _not_ doing a complete refresh, delete all the dead history entries, before adding the new ones
	if (!full)
	{
		for (NSDictionary* deletedHistoryItem in removedHistory) 
		{
			[self removeHistoryItem: deletedHistoryItem];
		}
	}

	// Second, insert all the new history entries 
	for (NSDictionary* historyItem in addedHistory) 
	{
		[self addHistoryItem:historyItem];
	}

	if (full) {
		[self updateTimestamp:@"fullhistory"];
	}
	
	[self updateTimestamp:@"history"];
	[self endTransaction];
	[self loadHistoryFromDB];
}

 
-(BOOL) addHistoryItem:(NSDictionary *)historyItem 
{
	const char *sql = "INSERT OR REPLACE INTO history ('id', 'url', 'title', 'favicon', 'modified', 'sortindex') VALUES (?, ?, ?, ?, ?, ?)";
	sqlite3_stmt *stmnt = nil;
	BOOL result = NO;

	if (sqlite3_prepare_v2(sqlDatabase, sql, -1, &stmnt, NULL) != SQLITE_OK) 
	{
		NSLog(@"Could not prepare history item statement");
	}
	else
	{    
		@try
		{
			//if it has a url, then create and save the expected path to its favicon
			NSString* faviconPath = @""; //unused

			//if it doesn't have a title, use the uri again
			NSString* title = [historyItem objectForKey:@"title"];

			if (title == nil || (id)title == [NSNull null])
			{
				title = [historyItem objectForKey:@"histUri"];
			}

			sqlite3_bind_text(stmnt, 1, [[historyItem objectForKey:@"id"] UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmnt, 2, [[historyItem objectForKey:@"histUri"] UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmnt, 3, [title UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmnt, 4, [faviconPath UTF8String], -1, SQLITE_TRANSIENT);

			sqlite3_bind_double(stmnt, 5, [[historyItem objectForKey:@"modified"] doubleValue]);
			sqlite3_bind_int(stmnt, 6, [[historyItem objectForKey:@"sortindex"] intValue]);

			if (sqlite3_step(stmnt) == SQLITE_DONE) 
			{
				result = YES;
			}
		}

		@catch (NSException *exception) 
		{
			NSLog(@"Malformed history item data: %@",[exception name], [exception reason]);
		}

		@finally 
		{
			int resultCode = sqlite3_finalize(stmnt);
			if (resultCode != SQLITE_OK)
			{
				NSLog(@"Error storing history item: %d)", resultCode);
				result = NO;
			}
		}
	}

	return result;
}

//SHOULD REMOVE THE FAVICON TOO
- (BOOL) removeHistoryItem: (NSDictionary*)historyItem
{
	const char *sql;
	sqlite3_stmt *stmnt = nil;
	NSString* id = [historyItem objectForKey:@"id"];

	sql = "DELETE FROM history where id = ?";
	if (sqlite3_prepare_v2(sqlDatabase, sql, -1, &stmnt, NULL) != SQLITE_OK) {
		NSLog(@"Could not prepare history deletion statement");
		return NO;
	} else {
		sqlite3_bind_text(stmnt, 1, [id UTF8String], -1, SQLITE_TRANSIENT);
		if (sqlite3_step(stmnt) != SQLITE_DONE) {
			NSLog(@"Could not remove history item from db");
			sqlite3_finalize(stmnt);
			return NO;
		}
	}

	sqlite3_finalize(stmnt);

	return YES;
}

#define FAKE_TAB_FRECENCY 2200

- (BOOL) addTabSet:(NSDictionary *)clientTabSet withClientID:(NSString*)theID
{	
	//pick out the values we need, rename some of them, and store them in the database in the 'tabs' table
	NSArray *clientTabs = [clientTabSet objectForKey:@"tabs"];
	NSString *clientName = [clientTabSet objectForKey:@"clientName"];

	for (NSDictionary* tab in clientTabs)
	{
		//put it in the table
		const char *sql = "INSERT OR REPLACE INTO tabs ('url', 'title', 'favicon', 'client', 'modified', 'sortindex') VALUES (?, ?, ?, ?, ?, ?)";
		sqlite3_stmt *stmnt = nil;
		BOOL result = NO;

		if (sqlite3_prepare_v2(sqlDatabase, sql, -1, &stmnt, NULL) != SQLITE_OK) 
		{
			NSLog(@"Could not prepare statement tab insertion statement");
		}
		else
		{    
			@try
			{
				NSString *url = [[tab objectForKey:@"urlHistory"] objectAtIndex:0];

				NSString *title = [tab objectForKey:@"title"];
				if (title == nil || (id)title == [NSNull null])
				{
					title = url;
				}

				NSString* favicon = @""; //unused

				sqlite3_bind_text(stmnt, 1, [url UTF8String], -1, SQLITE_TRANSIENT);
				sqlite3_bind_text(stmnt, 2, [title UTF8String], -1, SQLITE_TRANSIENT);
				sqlite3_bind_text(stmnt, 3, [favicon UTF8String], -1, SQLITE_TRANSIENT);
				sqlite3_bind_text(stmnt, 4, [clientName UTF8String], -1, SQLITE_TRANSIENT);

				sqlite3_bind_double(stmnt, 5, [[tab objectForKey:@"lastUsed"] doubleValue]);
				sqlite3_bind_int(stmnt, 6, FAKE_TAB_FRECENCY);

				if (sqlite3_step(stmnt) == SQLITE_DONE) 
				{
					result = YES;
				}
			}

			@catch (NSException *exception) 
			{
				NSLog(@"Malformed tab data: %@",[exception name], [exception reason]);
			}

			@finally 
			{
				int resultCode = sqlite3_finalize(stmnt);
				if (resultCode != SQLITE_OK)
				{
					NSLog(@"Error storing tab: %d)", resultCode);
					result = NO;
				}
			}
		}
	}

	return YES;
}


- (BOOL) installTabSetDictionary:(NSDictionary *)tabSetDict
{
	// Use a transaction to put them in the database safely
	[self beginTransaction];

	// First, delete all the existing tabs.
	// they all come in a monolithic set, with every open tab in it
	[self deleteTabs];  

	// Second, insert all the new tabs 

	for (NSString* anID in [tabSetDict allKeys]) 
	{
		[self addTabSet:[tabSetDict objectForKey:anID] withClientID:anID];
	}

	[self endTransaction];
	[self loadTabsFromDB];

	return YES;
}

@end
