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

#import "WeaveAppDelegate.h"
#import "AuthDialog.h"


@implementation AuthDialog

@synthesize nameField;
@synthesize passField;

-(void) viewDidLoad
{
  [super viewDidLoad];
}

- (void) viewDidAppear:(BOOL)animated
{
  [nameField becomeFirstResponder];
}


- (void) clearFields
{
  nameField.text = nil;
  passField.text = nil;
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
  if (textField == nameField)
  {
    [passField becomeFirstResponder];
  }
  else 
  {
    [self login:nil];
  }
  return NO;
}




- (IBAction) login:(id)sender
{
  NSString* name = nameField.text?nameField.text:[NSString string];
  NSString* pass = passField.text?passField.text:[NSString string];
  
  NSDictionary* result = [NSDictionary dictionaryWithObjectsAndKeys: name, @"name", pass, @"pass", nil];
    
  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
  [[appDelegate webController] performSelectorOnMainThread:@selector(authenticateWith:) withObject:result waitUntilDone:NO];
}


- (IBAction) cancel:(id)sender
{
  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
  [[appDelegate webController] performSelectorOnMainThread:@selector(cancelAuth) withObject:nil waitUntilDone:NO];
}


//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//  return YES;
//}

//- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
//{
//  WeaveAppDelegate* appDelegate = (WeaveAppDelegate *)[[UIApplication sharedApplication] delegate];
//  [[appDelegate webController] willRotateToInterfaceOrientation:toInterfaceOrientation duration:0];
//  [[appDelegate webController] didRotateFromInterfaceOrientation:[self interfaceOrientation]];
//}

//- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
//{
// // NSLog(@"auth dialog did rotate");
//}


- (void)didReceiveMemoryWarning 
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload 
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc 
{
    [super dealloc];
}


@end
