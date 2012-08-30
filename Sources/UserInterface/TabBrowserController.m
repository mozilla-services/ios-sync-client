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
#import "TabBrowserController.h"
#import "WebPageController.h"
#import "Store.h"
#import "TapActionController.h"

@implementation TabBrowserController

@synthesize myTable;
@synthesize titleString;
@synthesize topHeader;
@synthesize headerView;

/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if (self = [super initWithStyle:style]) {
    }
    return self;
}
*/

- (void)viewDidLoad {
  [super viewDidLoad];
  
  //magic incantation that fixes resizing on rotate
  self.view.autoresizesSubviews = YES;
  self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}


//- (void)viewWillAppear:(BOOL)animated {
//    [super viewWillAppear:animated];
//}



//- (void)viewDidAppear:(BOOL)animated
//{
//}

- (void) refresh
{ 
  [myTable reloadData];
}

/*
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return YES;
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


#pragma mark Table view methods

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [[retainedTabs objectAtIndex:section] objectForKey:@"client"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
  [retainedTabs release];
  retainedTabs = [[[Store getStore] getTabs] retain];
  return [retainedTabs count];
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [[[retainedTabs objectAtIndex:section] objectForKey:@"tabs"] count];
}


//Note: this table cell code is nearly identical to the same method in searchresults and bookmarks,
// but we want to be able to easily make them display differently, so it is replicated
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
  //NOTE: I'm now sharing table view cells across the app
  static NSString *CellIdentifier = @"URL_CELL";
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
  }
  
  NSDictionary* tabItem = [[[retainedTabs objectAtIndex:indexPath.section] objectForKey:@"tabs"] objectAtIndex:indexPath.row];
    
  cell.textLabel.text = [tabItem objectForKey:@"title"];
  cell.detailTextLabel.text = [tabItem objectForKey:@"url"];
  cell.accessoryType = UITableViewCellAccessoryNone;

  //set it to the default to start
  cell.imageView.image = [UIImage imageNamed:[tabItem objectForKey:@"icon"]];
  
  return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
	
	WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
	if ([appDelegate canConnectToInternet])
	{
		[WebPageController openURL: cell.detailTextLabel.text withTitle: cell.textLabel.text];		
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



- (void)dealloc 
{
  [super dealloc];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

//we are going to some effort here for UI consistency.
// I'm sizing some UI elements when we rotate, so they match the size and font of the System widgets, 
// so that all our pages look as much alike as possible
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
  CGRect f, newFrame;

  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
  BOOL fromVertical = (appDelegate.currentOrientation == UIInterfaceOrientationPortrait || appDelegate.currentOrientation == UIInterfaceOrientationPortraitUpsideDown);
  
  if (!fromVertical && (toInterfaceOrientation == UIInterfaceOrientationPortrait || toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown))
  {
      //set the title font to 20
      titleString.font = [UIFont boldSystemFontOfSize:20];
      //load the big header
      topHeader.image = [UIImage imageNamed:@"header.png"];
    
    
    f = headerView.frame;
    newFrame = CGRectMake(f.origin.x,
                          f.origin.y,
                          f.size.width,
                          f.size.height + 12);
    headerView.frame = newFrame;
    
    //resize the table
    f = myTable.frame;
    newFrame = CGRectMake(f.origin.x,
                          f.origin.y + 12,
                          f.size.width,
                          f.size.height - 12);

    myTable.frame = newFrame;
    
    
  }
  else if (fromVertical && (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight))
  {
    //set the title font to 16
    titleString.font = [UIFont boldSystemFontOfSize:16];
    //load the small header
    topHeader.image = [UIImage imageNamed:@"short_header.png"];
    
    
    f = headerView.frame;
    newFrame = CGRectMake(f.origin.x,
                                 f.origin.y,
                                 f.size.width,
                                 f.size.height - 12);
    headerView.frame = newFrame;
    
    
    
    //resize the table
    f = myTable.frame;
    newFrame = CGRectMake(f.origin.x,
                          f.origin.y - 12,
                          f.size.width,
                          f.size.height + 12);
    
    myTable.frame = newFrame;
  }
}


@end

