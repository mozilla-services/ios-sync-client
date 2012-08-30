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

#import "NSURL+IFUnicodeURL.h"
#import "WeaveAppDelegate.h"
#import "SearchResultsController.h"
#import "WebPageController.h"
#import "Store.h"
#import "TapActionController.h"
#import "Stockboy.h"

@interface SearchResultsController (private)
- (void)refreshHits:(NSString*)searchString;
- (void)startSearchThreadWithQuery:(NSString*)query;

@end


@implementation SearchResultsController

@synthesize spinner;
@synthesize spinBG;
@synthesize searchAndLogoView;
@synthesize statusLabel = _statusLabel;


// The search results refresh delay timer, delay thread, and intermediate results
static NSTimer* gRefreshTimer = nil;
static NSThread* gRefreshThread = nil;
static NSMutableArray* gFreshSearchHits = nil;



- (void)viewDidLoad 
{
  [super viewDidLoad];
  
  //magic incantation that fixes resizing on rotate
  self.view.autoresizesSubviews = YES;
  self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  
  
  //Kludgy way to change the 'Search' button on the keyboard for the search page to 'Done'
  for (UIView *searchBarSubview in [self.searchDisplayController.searchBar subviews]) 
  {
    if ([searchBarSubview conformsToProtocol:@protocol(UITextInputTraits)]) 
    {
      @try 
      {
        [(UITextField *)searchBarSubview setReturnKeyType:UIReturnKeyDone];
        [(UITextField *)searchBarSubview setKeyboardAppearance:UIKeyboardAppearanceAlert];
      }
      @catch (NSException * e) 
      {
        // ignore exception
      }
    }
  }
  
  
  searchHits = nil;
}

- (void) refresh
{
  [self startSearchThreadWithQuery:self.searchDisplayController.searchBar.text];
  [self.searchDisplayController.searchResultsTableView reloadData];
}

#pragma mark -

- (void) syncStatusChanged: (NSNotification*) notification
{
	_statusLabel.text = [[notification userInfo] objectForKey: @"Message"];
}

#pragma mark -

- (void) viewDidAppear: (BOOL) animated
{
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(syncStatusChanged:)
		name: @"SyncStatusChanged" object: nil];
}

- (void) viewDidDisappear: (BOOL) animated
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark Table view methods

//from experience, this is the first delegate method called when the table refreshes its data, so we'll grab and retain the current best search results
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
  [searchHits release];
  searchHits = [gFreshSearchHits retain];
  return 2;
}



// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
  //first section is normal sync results, the final section has magic "goto" behavior
  if (section == 0)
  {
    if (self.searchDisplayController.searchBar.text != nil && self.searchDisplayController.searchBar.text.length != 0 && [searchHits count])
    {
      return [searchHits count];
    }
    return 0;
  }
  else return 1;
}


//Note: this table cell code is nearly identical to the same method in bookmarks and tabs,
// but we want to be able to easily make them display differently, so it is replicated
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
  if (indexPath.section == 1 && gLastSearchString != nil) //special goto cell, which goes to a website directly, independent of your synced items
  {
    static NSString *CellIdentifier = @"GOTO_CELL";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) 
    {
      cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor blueColor];
    cell.textLabel.textAlignment = UITextAlignmentLeft;
    cell.textLabel.text = [NSString stringWithFormat:@"%@", gLastSearchString];
    cell.imageView.image = [UIImage imageNamed:@"goto"];
    cell.accessoryType = UITableViewCellAccessoryNone;

    return cell;
  }
  else //regular title/url cell
  {
    //NOTE: I'm now sharing the table cell cache between all my tables to save memory
    static NSString *CellIdentifier = @"URL_CELL";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
      cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
    cell.accessoryType = UITableViewCellAccessoryNone;

    @try 
    {
      if (searchHits)
      {
        if ([searchHits count])
        {
          cell.textLabel.textColor = [UIColor blackColor];
          cell.textLabel.textAlignment = UITextAlignmentLeft;

          NSDictionary* matchItem = [searchHits objectAtIndex:[indexPath row]];
          // Set up the cell...
          cell.textLabel.text = [matchItem objectForKey:@"title"];
          cell.detailTextLabel.text = [matchItem objectForKey:@"url"];
          //the item tells us which icon to use
          cell.imageView.image = [UIImage imageNamed:[matchItem objectForKey:@"icon"]];
        }
        else //empty list, means no matches
        {
          cell.textLabel.textColor = [UIColor grayColor];
          cell.textLabel.text = NSLocalizedString(@"No Matches", @"no matching items found");
          cell.detailTextLabel.text = nil;
          cell.imageView.image = nil;
        }

      }
      else //no list at all, means searching
      {
        cell.textLabel.textColor = [UIColor grayColor];
        cell.textLabel.text = NSLocalizedString(@"Searching...", @"searching for matching items");
        cell.detailTextLabel.text = nil;
        cell.imageView.image = nil;
      }

    }
    @catch (NSException * e) 
    {
      NSLog(@"item to display missing from searchhits");
      cell.textLabel.textColor = [UIColor blackColor];
      cell.textLabel.text = nil;
      cell.detailTextLabel.text = nil;
      cell.imageView.image = nil;
      
    }
    
    return cell;
  }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (gRefreshThread != nil)
	{
		[gRefreshThread cancel];
		gRefreshThread = nil;
	}

	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
	WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];

	if ([appDelegate canConnectToInternet])
	{
		NSString* destination = nil;
		NSString* title = cell.textLabel.text;

		if (indexPath.section == 1)
		{
			BOOL hasSpace = ([gLastSearchString rangeOfString:@" "].location != NSNotFound);
			BOOL hasDot = ([gLastSearchString rangeOfString:@"."].location != NSNotFound);
			BOOL hasScheme = ([gLastSearchString rangeOfString:@"://"].location != NSNotFound);

			if (hasDot && !hasSpace) { 
				if (hasScheme) {
					destination = gLastSearchString;
				} else {
					destination = [NSString stringWithFormat:@"http://%@", gLastSearchString];
				}
			} else  {
				destination = [NSString stringWithFormat:[Stockboy getURIForKey:@"Google URL"], gLastSearchString];
			}
		}
		else 
		{
			destination = cell.detailTextLabel.text;
		}
		
		[WebPageController openURL: destination withTitle: title];
	}
	else 
	{
		//no connectivity, put up alert
		NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Cannot Load Page", @"unable to load page"), @"title", 
			NSLocalizedString(@"No internet connection available", "no internet connection"), @"message", nil];
		[appDelegate performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];          
	}

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}



- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText 
{
  //WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
  //[appDelegate.searchResults.view performSelectorOnMainThread:@selector(bringSubviewToFront:) withObject:spinner waitUntilDone:NO];
  //[appDelegate.searchResults.view bringSubviewToFront:spinBG];
  
  if (searchText != nil && [searchText length] > 0)
  {
    [spinner startAnimating];
    [spinner setHidden:NO];
    [spinBG setHidden:NO];
  }
  else 
  {
    [spinner setHidden:YES];
    [spinBG setHidden:YES];
    [spinner stopAnimating];    
  }

  
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
  self.searchDisplayController.searchBar.text = nil;
  [self refreshHits:nil];
  [self startSearchThreadWithQuery:nil];
  [self.searchDisplayController.searchResultsTableView reloadData];
}


#pragma mark UISearchDisplayDelegate methods
/////////////////////////////////

- (void) threadRefreshHits:(NSString*)searchText
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  
  @try 
  {
    [self refreshHits:searchText];
    if ([[NSThread currentThread] isCancelled])  //we might be cancelled, because a better search came along, so don't display our results
    {
      NSLog(@"search thread was cancelled and replaced");
    }
    else
    {
      [self.searchDisplayController.searchResultsTableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
    }
  }
  @catch (NSException *e) 
  {
    NSLog(@"Failed to update search results");
  }
  @finally 
  {
    //stop the spinner
    [spinner setHidden:YES];
    [spinBG setHidden:YES];
    [spinner stopAnimating];
    [pool drain];
    gRefreshThread = nil;
  }
}


- (void)startSearchThreadWithQuery:(NSString*)query
{
  //if there is a thread running, we need to stop it. it will autorelease
  if (gRefreshThread != nil)
  {
    [gRefreshThread cancel];
    gRefreshThread = nil;
  }
  
  //now fire up a new search thread
  gRefreshThread = [[[NSThread alloc] initWithTarget:self selector:@selector(threadRefreshHits:) object:query] autorelease];
  [gRefreshThread start];
}


- (void)triggerRefresh:(NSTimer*)theTimer
{
  //clean up
  gRefreshTimer = nil;
  
  NSString* searchText = [theTimer userInfo];
  [self startSearchThreadWithQuery:searchText];
}



- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{  
  if (gRefreshTimer != nil)
  {
    [gRefreshTimer invalidate];
    gRefreshTimer = nil;
  }
  gRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(triggerRefresh:) userInfo:searchString repeats:NO];
  return NO;
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didShowSearchResultsTableView:(UITableView *)tableView
{
  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
  [appDelegate.searchResults.view bringSubviewToFront:spinBG];
}

#define MAXPERLIST 12

//This method works by side-effect.  It's complicated and rather ugly, but it was important not to have to
// duplicate it for each of the three lists

//This search function iterates a sorted list of WBO dictionaries, checking the title and url of the objects.

//it first checks to see if the title or the url of an item contain all the search terms as substrings.
// if it does, then it is at least a substring match
//it then checks to see if it matches them all at the beginnings of 'words', using a regex inside an NSPredicate,
// which qualifies it as a high-quality match, and goes at the top of the list.

- (void) searchWeaveObjects:(NSArray*)items 
            withSearchTerms:(NSArray*)terms
              andPredicates:(NSArray*)predicateList 
             wordHitResults:(NSMutableDictionary*)wordHits 
           substringResults:(NSMutableDictionary*)substrHits
            returningAtMost:(NSInteger)maxHits

{
  int wordHitCount = 0;
  int substrHitCount = 0;

  for (NSDictionary* item in items)
  {
    NSRange titleRange;
    NSRange urlRange;
    BOOL skip = NO;
    //rangeOfString is incredibly fast, so we use it to prefilter. if an item doesn't even contain all the search terms as substrings,
    // it obviously can't have them as the start of words
    for (NSString* term in terms) 
    {
      titleRange = [[item objectForKey:@"title"] rangeOfString:term options:NSCaseInsensitiveSearch];
      urlRange = [[item objectForKey:@"url"] rangeOfString:term options:NSCaseInsensitiveSearch];
      if (titleRange.location == NSNotFound && urlRange.location == NSNotFound)
      {
        skip = YES;
        break;
      }
    }
    if (skip) continue;  //we didn't find all the search terms as substrings, so go on to the next item
    
    //at this point, we know we have at least a substring hit!
    // but now we check to see if the terms are all at the beginnings of words,
    // which makes it a SUPER DELUXE SPARKLE HIT!!
    
    BOOL isSuperDeluxeSparkleHit = YES;  //flips to NO if all the predicates don't match

    for (NSPredicate* pred in predicateList)
    {
      @try 
      {
        isSuperDeluxeSparkleHit = isSuperDeluxeSparkleHit && ([pred evaluateWithObject:[item objectForKey:@"title"]] || [pred evaluateWithObject:[item objectForKey:@"url"]]);
      }
      @catch (NSException * e) 
      {
        isSuperDeluxeSparkleHit = NO;
        break; //just get out
      }
      
      if (!isSuperDeluxeSparkleHit) break;  //don't check any more predicates
    }
    
    if (isSuperDeluxeSparkleHit)
    {
      wordHitCount++;
      [wordHits setObject:item forKey:[item objectForKey:@"url"]];
    }
    else if (substrHitCount < maxHits)
    {
      substrHitCount++;
      [substrHits setObject:item forKey:[item objectForKey:@"url"]];
    }

    //now bail if we already have enough word hits.  if we have a fulllist of word hits, we don't care how many substr hits we have
    if (wordHitCount >= maxHits) break;
  }
}


//OK, this has gotten a lot easier.  the lists of tabs, bookmarks, and history are already sorted by frecency,
// so I can start at the beginning and stop when I get MAXPERLIST hits from each 

- (void)refreshHits:(NSString*)searchString
{
  //empty string means no hits
  if (searchString == nil || [searchString length] == 0)
  {
    [gFreshSearchHits release];
    gFreshSearchHits = nil;
    [gLastSearchString release];
    gLastSearchString = nil;
    return;
  }
   
  gLastSearchString = [searchString retain];
  
  //make the list of strict predicates to match.  usually only 1, but if the user separates strings with spaces, we must match them all,
  // on different word boundaries, to be a hit
  NSMutableArray* predicates = [[NSMutableArray array] retain];

  //break up the search string by spaces
  NSArray *rawTokens = [searchString componentsSeparatedByString:@" "];
  //now strip out the empty strings, duh
  NSMutableArray* searchTokens = [NSMutableArray array];
  for (NSString* token in rawTokens)
  {
    if ([token length]) [searchTokens addObject:token];
  }
    
  //for each token, make a match predicate
  for (NSString* token in searchTokens)
  {
    NSString *regex = [NSString stringWithFormat:@".*\\b(?i)%@.*", token];
    //put the predicates in a list
    [predicates addObject:[NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex]];
  }

  
 
  //see above, at the function definition of searchWeaveObjects, for an explanation of its complexities

  NSMutableDictionary* newWordHits = [NSMutableDictionary dictionary];
  NSMutableDictionary* newSubstringHits = [NSMutableDictionary dictionary];
    
  // PLEASE NOTE: I AM SEARCHING THE DATA IN THIS ORDER (history, bookmarks, tabs) ON PURPOSE!
  // DO NOT CHANGE THE ORDER.  This works in tandem with keeping them in a dictionary keyed by url
  // to remove duplicates, but prefer tabs over bookmarks, and bookmarks over history
  
  NSArray*  history = [[[Store getStore] getHistory] retain];
  [self searchWeaveObjects:history
           withSearchTerms:searchTokens
             andPredicates:predicates 
            wordHitResults:newWordHits 
          substringResults:newSubstringHits 
           returningAtMost:MAXPERLIST];
  [history release];
  
  
  NSArray* bookmarks = [[[Store getStore] getBookmarks] retain];
  [self searchWeaveObjects:bookmarks
           withSearchTerms:searchTokens
             andPredicates:predicates 
            wordHitResults:newWordHits 
          substringResults:newSubstringHits 
           returningAtMost:MAXPERLIST];
  [bookmarks release];
  
  
  NSDictionary* tabs = [[[Store getStore] getTabs] retain];
  for (NSDictionary* client in tabs)
  {
    [self searchWeaveObjects:[client objectForKey:@"tabs"] 
             withSearchTerms:searchTokens
               andPredicates:predicates 
              wordHitResults:newWordHits 
            substringResults:newSubstringHits 
             returningAtMost:MAXPERLIST];
  }
  [tabs release];
  

  //free the predicate objects
  [predicates release];
  
  //sort them by sortIndex (frecency)
  NSMutableArray* WORD_matches = [NSMutableArray arrayWithArray:[newWordHits allValues]];  
  [WORD_matches sortUsingFunction:compareSearchResults context:NULL];  

  //OK!!  Now we have at least 0 and at most N * MAXPERLIST, sorted by frecency
  //but wait, if we don't have at least MAXPERLIST, then let's try doing a plain old substring match
  if ([WORD_matches count] < MAXPERLIST)
  {
    //we will tack the substring matches, themselves sorted, onto the end of the list, to make MAXPERLIST
    NSMutableArray* SUBSTRING_matches = [NSMutableArray arrayWithArray:[newSubstringHits allValues]];   
    [SUBSTRING_matches sortUsingFunction:compareSearchResults context:NULL];
    
    int needed = MAXPERLIST - [WORD_matches count];
    
    //we need more than we have, so add them all
    if (needed > [newSubstringHits count])
    {
      [WORD_matches addObjectsFromArray:SUBSTRING_matches];
    }
    else //we have more than we need, so just add the right amount to reach MAXPERLIST
    {
      NSRange addHits;
      addHits.location = 0;
      addHits.length = needed;
      [WORD_matches addObjectsFromArray:[SUBSTRING_matches subarrayWithRange:addHits]];
    }
    [gFreshSearchHits release];
    gFreshSearchHits = [WORD_matches retain];
  }
  else if ([newWordHits count] > MAXPERLIST) //otherwise if we have too many, then trim
  {
    NSRange maxHitCount;
    maxHitCount.location = 0;
    maxHitCount.length = MAXPERLIST;
    
    NSArray* temp = [WORD_matches subarrayWithRange:maxHitCount];
    [gFreshSearchHits release];
    gFreshSearchHits = [temp retain];
  }
  else 
  {
    [gFreshSearchHits release];
    gFreshSearchHits = [WORD_matches retain]; 
  }
  
  
}




- (void)dealloc {
  [searchHits release];
  [gFreshSearchHits release];
  [super dealloc];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

@end

