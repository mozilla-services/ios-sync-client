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

#import "JPAKEViewController.h"

@implementation JPAKEViewController

@synthesize statusLabel = _statusLabel;
@synthesize passwordLabel1 = _passwordLabel1;
@synthesize passwordLabel2 = _passwordLabel2;
@synthesize passwordLabel3 = _passwordLabel3;

@synthesize server = _server;
@synthesize delegate = _delegate;
@synthesize reporter = _reporter;

- (void) viewDidLoad
{
	_client = [[JPAKEClient alloc] initWithServer: _server delegate: self reporter: _reporter];
	[_client start];
}

- (void) dealloc
{
	[_client release];
	[_server release];
	[_reporter release];
	[super dealloc];
}

#pragma mark -

- (IBAction) cancel
{
	[_client cancel];
}

#pragma mark -

- (void) client: (JPAKEClient*) client didGenerateSecret: (NSString*) secret
{
	NSArray* components = [secret componentsSeparatedByString: @"-"];
	_passwordLabel1.text = [components objectAtIndex: 0];
	_passwordLabel2.text = [components objectAtIndex: 1];
	_passwordLabel3.text = [components objectAtIndex: 2];
}

- (void) client: (JPAKEClient*) client didFailWithError: (NSError*) error
{
	[_delegate JPAKEViewController: self didFailWithError: error];
}

- (void) client: (JPAKEClient*) client didReceivePayload: (id) payload
{
	[_delegate JPAKEViewController: self didFinishWithMessage: payload];
}

- (void) clientDidCancel: (JPAKEClient*) client
{
	[_delegate JPAKEViewControllerDidCancel: self];
}

@end
