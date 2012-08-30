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

#import <QuartzCore/QuartzCore.h>

#import "EasySetupViewController.h"
#import "WeaveAppDelegate.h"
#import "Stockboy.h"

@implementation EasySetupViewController

@synthesize statusLabel = _statusLabel;
@synthesize passwordLabel1 = _passwordLabel1;
@synthesize passwordLabel2 = _passwordLabel2;
@synthesize passwordLabel3 = _passwordLabel3;
@synthesize passwordView1 = _passwordView1;
@synthesize passwordView2 = _passwordView2;
@synthesize passwordView3 = _passwordView3;
@synthesize activityIndicator = _activityIndicator;
@synthesize navigationBar = _navigationBar;
@synthesize passcodeLabel = _passcodeLabel;
@synthesize manualSetupButton = _manualSetupButton;

@synthesize server = _server;
@synthesize delegate = _delegate;
@synthesize reporter = _reporter;

#pragma mark -

- (void) startLoginSpinner
{
//	[_spinner startAnimating];
//	_spinnerView.hidden = NO;
//	_cancelButton.enabled = NO;
}

- (void) stopLoginSpinner
{
//	_spinnerView.hidden = YES;
//	[_spinner stopAnimating];
//	_cancelButton.enabled = YES;
}

#pragma mark -

- (void) authorize: (NSDictionary*)authDict
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	_newCryptoManager = nil;

	//any sort of auth failure just means we catch it here and make them reenter the password
	@try
	{
		_newCryptoManager = [[[CryptoUtils alloc ] initWithAccountName:[authDict objectForKey:@"user"]
			password: [authDict objectForKey:@"pass"] andPassphrase:[authDict objectForKey:@"secret"]] retain];
		if (_newCryptoManager) {
			[self performSelectorOnMainThread:@selector(dismissLoginScreen) withObject:nil waitUntilDone:YES];
		} else  {
			@throw [NSException exceptionWithName:@"CryptoInitException" reason:@"unspecified failure" userInfo:nil];
		}
	}
	
	@catch (NSException *e) 
	{
		//I don't need to take different actions for different bad outcomes, at least in this case,
		// because they all mean "failed to log in".  So I just report them.  In other situations,
		// I might certainly need to do different things for different error conditions
		[self performSelectorOnMainThread:@selector(authFailed:) withObject:[e reason] waitUntilDone:YES];
		NSLog(@"Failed to initialize CryptoManager");
	}
	
	@finally 
	{
		//stop the spinner, regardless
		[self performSelectorOnMainThread:@selector(stopLoginSpinner) withObject:nil waitUntilDone:YES];
		[pool drain];
	}
}

- (void) authFailed:(NSString*)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Login Failure", @"unable to login")
		message:message delegate: self cancelButtonTitle: NSLocalizedString(@"OK", @"ok") otherButtonTitles: nil];
	[alert show];
	[alert release];    
}
  
/**
 * This is called when we have succesfully logged in. Call back to the delegate.
 */
  
- (void) dismissLoginScreen
{
	[CryptoUtils assignManager:_newCryptoManager];

	//The user has now logged in successfully at least once, so set the flag to prevent
	// showing the Welcome page from now on

	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"showedFirstRunPage"];
	[Stockboy restock];

	[_delegate easySetupViewControllerDidLogin: self];
}

#pragma mark -

- (void) viewDidLoad
{
	_passwordView1.layer.cornerRadius = 7;
	_passwordView2.layer.cornerRadius = 7;
	_passwordView3.layer.cornerRadius = 7;
	
	// This is not the right way to do this but because we are under time pressure
	// I am just setting the Passcode text directly here.
	_passcodeLabel.text = NSLocalizedString(@"Passcode", @"Passcode");



	// Adjust the button for some specific languages

	NSString* language = [[NSLocale preferredLanguages] objectAtIndex: 0];
	
	NSSet* languagesThatNeedMoreSpace = [NSSet setWithObjects: @"fr", @"id", @"pt" , nil];
	NSSet* languagesThatNeedSmallerFont = [NSSet setWithObjects: @"tr", @"ru", nil];

	if ([languagesThatNeedSmallerFont containsObject: language]) {
		_manualSetupButton.titleLabel.font = [UIFont fontWithName: _manualSetupButton.titleLabel.font.fontName size: _manualSetupButton.titleLabel.font.pointSize - 1.5];
		CGRect frame = _manualSetupButton.frame; frame.origin.x -= 4; frame.size.width += 8;
		_manualSetupButton.frame = frame;
	}
	
	else if ([languagesThatNeedMoreSpace containsObject: language]) {
		_manualSetupButton.titleLabel.font = [UIFont fontWithName: _manualSetupButton.titleLabel.font.fontName size: _manualSetupButton.titleLabel.font.pointSize - 1.5];
		_manualSetupButton.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
		_manualSetupButton.titleLabel.textAlignment = UITextAlignmentCenter;
		_manualSetupButton.titleLabel.numberOfLines = 2;
		CGRect frame = _manualSetupButton.frame; frame.origin.y -= 4; frame.size.height += 8;
		if ([language isEqualToString: @"fr"]) {
			frame.origin.x -= 4; frame.size.width += 8;
		}
		_manualSetupButton.frame = frame;
	}

	_client = [[JPAKEClient alloc] initWithServer: _server delegate: self reporter: _reporter];
	[_client start];
}

- (void) viewDidAppear:(BOOL)animated
{
	[[UIApplication sharedApplication] setIdleTimerDisabled: YES];
}

- (void) viewDidDisappear:(BOOL)animated
{
	[[UIApplication sharedApplication] setIdleTimerDisabled: NO];
}

#pragma mark -

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

- (IBAction) manualSetup
{
	[_client abort];
	[_delegate easySetupViewControllerDidRequestManualSetup: self];
}

#pragma mark -

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	switch (buttonIndex)
	{
		case 0: // Cancel
			[_delegate easySetupViewControllerDidCancel: self];
			break;
		case 1: // Try Again
			_passwordLabel1.text = nil;
			_passwordLabel2.text = nil;
			_passwordLabel3.text = nil;
			_activityIndicator.hidden = NO;
			[_activityIndicator startAnimating];
			[_client start];
			break;
		case 2: // Manual Setup
			[_delegate easySetupViewControllerDidRequestManualSetup: self];
			break;
	}
}

#pragma mark -

- (NSString*) formatCode: (NSString*) code
{
	return [NSString stringWithFormat: @"%c %c %c %c",
		[code characterAtIndex: 0],
		[code characterAtIndex: 1],
		[code characterAtIndex: 2],
		[code characterAtIndex: 3]];
}

- (void) client: (JPAKEClient*) client didGenerateSecret: (NSString*) secret
{
	_activityIndicator.hidden = YES;

	NSArray* components = [secret componentsSeparatedByString: @"-"];
	_passwordLabel1.text = [self formatCode: [components objectAtIndex: 0]];
	_passwordLabel2.text = [self formatCode: [components objectAtIndex: 1]];
	_passwordLabel3.text = [self formatCode: [components objectAtIndex: 2]];
}

/**
 * The JPAKE Transaction failed. We don't care about the error, we simply show the user
 * a high level error message and give him a change of retry, cancel and manual setup.
 */

- (void) client: (JPAKEClient*) client didFailWithError: (NSError*) error
{
	[_activityIndicator stopAnimating];

	UIAlertView* alertView = [[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Cannot Setup Sync", @"Cannot Setup Sync")
		message: NSLocalizedString(@"SyncClient could not connect to Sync. Would you like to try again?", @"SyncClient could not connect to Sync. Would you like to try again?")
			delegate: self cancelButtonTitle: NSLocalizedString(@"Cancel", @"Cancel") 
				otherButtonTitles: NSLocalizedString(@"Try Again", @"Try Again"), NSLocalizedString(@"Manual Setup", @"Manual Setup"), nil] autorelease];

	[alertView show];
}

- (void) client: (JPAKEClient*) client didReceivePayload: (id) payload
{
	[self startLoginSpinner];

	// If we got a custom server then we configure it right away
	
	NSString* server = [payload objectForKey: @"serverURL"];
	if (server != nil && [server length] != 0) {
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"useCustomServer"];
		[[NSUserDefaults standardUserDefaults] setObject: server forKey: @"customServerURL"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	} else {
		[[NSUserDefaults standardUserDefaults] setBool: NO forKey: @"useCustomServer"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"customServerURL"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}

	NSDictionary* authDict = [NSDictionary dictionaryWithObjectsAndKeys:
		[payload objectForKey: @"account"], @"user",
		[payload objectForKey: @"password"], @"pass",
		[payload objectForKey: @"synckey"], @"secret",
		nil];

	NSThread* authorizer = [[[NSThread alloc] initWithTarget:self selector:@selector(authorize:) object:authDict] autorelease];
	[authorizer start];
}

- (void) clientDidCancel: (JPAKEClient*) client
{
	[_delegate easySetupViewControllerDidCancel: self];
}

@end
	