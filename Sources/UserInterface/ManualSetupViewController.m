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

#import "ManualSetupViewController.h"
#import "WeaveAppDelegate.h"
#import "Stockboy.h"

@implementation ManualSetupViewController

@synthesize loginButton = _loginButton;
@synthesize cancelButton = _cancelButton;
@synthesize spinnerView = _spinnerView;
@synthesize spinner = _spinner;
@synthesize tableView = _tableView;
@synthesize delegate = _delegate;

#define UsernameTextFieldTag 1
#define PasswordTextFieldTag 2
#define SyncKeyTextFieldTag 3
#define CustomServerTextFieldTag 4

- (void) dealloc
{
	[_newCryptoManager release];
	[super dealloc];
}

- (void) startLoginSpinner
{
	[_spinner startAnimating];
	_spinnerView.hidden = NO;
	_cancelButton.enabled = NO;
}

- (void) stopLoginSpinner
{
	_spinnerView.hidden = YES;
	[_spinner stopAnimating];
	_cancelButton.enabled = YES;
}

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

	[_delegate manualSetupViewControllerDidLogin: self];
}

#pragma mark -

- (IBAction) cancel
{
	[_delegate manualSetupViewControllerDidCancel: self];
}

- (IBAction) login
{
}

#pragma mark -

- (UITextField*) usernameTextField
{
	UITableViewCell* cell = [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow: 0 inSection: 0]];
	return (UITextField*) [cell viewWithTag: 2];
}

- (UITextField*) passwordTextField
{
	UITableViewCell* cell = [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow: 1 inSection: 0]];
	return (UITextField*) [cell viewWithTag: 2];
}

- (UITextField*) syncKeyTextField
{
	UITableViewCell* cell = [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow: 2 inSection: 0]];
	return (UITextField*) [cell viewWithTag: 2];
}

- (UITextField*) customServerTextField
{
	UITableViewCell* cell = [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow: 1 inSection: 1]];
	return (UITextField*) [cell viewWithTag: 2];
}

- (UISwitch*) customServerSwitch
{
	UITableViewCell* cell = [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow: 0 inSection: 1]];
	return (UISwitch*) [cell viewWithTag: 2];
}

#pragma mark -

- (void) keyboardDidShow: (NSNotification*) notification
{
	CGFloat keyboardHeight = 216;

	NSValue* value = [[notification userInfo] objectForKey: UIKeyboardBoundsUserInfoKey];
	if (value != nil) {
		CGRect frameEnd;
		[value getValue: &frameEnd];
		keyboardHeight = frameEnd.size.height;
	}

	CGRect frame = self.tableView.frame;
	frame.size.height -= keyboardHeight;
	self.tableView.frame = frame;
	
	if ([[self customServerTextField] isFirstResponder]) {
		[self.tableView scrollToRowAtIndexPath: [NSIndexPath indexPathForRow: 1 inSection: 1]
			atScrollPosition: UITableViewScrollPositionNone animated: YES];
	}
}

- (void) keyboardDidHide: (NSNotification*) notification
{
	CGFloat keyboardHeight = 216;

	NSValue* value = [[notification userInfo] objectForKey: UIKeyboardBoundsUserInfoKey];
	if (value != nil) {
		CGRect frameBegin;
		[value getValue: &frameBegin];
		keyboardHeight = frameBegin.size.height;
	}

	CGRect frame = self.tableView.frame;
	frame.size.height += keyboardHeight;
	self.tableView.frame = frame;
}

#pragma mark -

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	_tableView.allowsSelection = NO;
	//_tableView.backgroundView = [[[UIImageView alloc] initWithImage: [UIImage imageNamed: @"Background.png"]] autorelease];
	_tableView.backgroundColor = [UIColor clearColor];
}

- (void) viewDidAppear:(BOOL)animated
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(keyboardDidShow:)
		name:UIKeyboardDidShowNotification object:nil];
		
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(keyboardDidHide:)
		name:UIKeyboardWillHideNotification object:nil];
}

- (void) viewDidDisappear:(BOOL)animated
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark -

- (void) textFieldDidBeginEditing:(UITextField *)textField
{
}

- (void) textFieldDidEndEditing:(UITextField *)textField
{
	if (textField == [self usernameTextField]) {
		[_username release];
		_username = [textField.text copy];
	}
	
	if (textField == [self passwordTextField]) {
		[_password release];
		_password = [textField.text copy];
	}
	
	if (textField == [self syncKeyTextField]) {
		[_secret release];
		_secret = [textField.text copy];
	}
	
	if (textField == [self customServerTextField]) {
		[_customServerURL release];
		_customServerURL = [textField.text copy];
	}
}

- (BOOL) textFieldShouldReturn: (UITextField*) textField 
{
	// Update the data model

	if (textField == [self usernameTextField]) {
		[_username release];
		_username = [textField.text copy];
	}
	
	if (textField == [self passwordTextField]) {
		[_password release];
		_password = [textField.text copy];
	}
	
	if (textField == [self syncKeyTextField]) {
		[_secret release];
		_secret = [textField.text copy];
	}
	
	if (textField == [self customServerTextField]) {
		[_customServerURL release];
		_customServerURL = [textField.text copy];
	}
	
	// Check if we are good to go

	if (_username == nil || [_username length] == 0) {
		return NO;
	}

	if (_password == nil || [_password length] == 0) {
		return NO;
	}
	
	if (_secret == nil || [_secret length] == 0) {
		return NO;
	}
	
	if (_customServerEnabled && (_customServerURL == nil || [_customServerURL length] == 0)) {
		return NO;
	}
	
	[[self usernameTextField] resignFirstResponder];
	[[self passwordTextField] resignFirstResponder];
	[[self syncKeyTextField] resignFirstResponder];
	[[self customServerTextField] resignFirstResponder];

//	NSLog(@"LOGGING IN WITH THE FOLLOWING:");
//	
//	NSLog(@" _username            = %@", _username);
//	NSLog(@" _password            = %@", _password);
//	NSLog(@" _secret              = %@", _secret);
//	NSLog(@" _customServerEnabled = %d", _customServerEnabled);
//	NSLog(@" _customServerURL     = %@", _customServerURL);
	
	WeaveAppDelegate *delegate = (WeaveAppDelegate*)[[UIApplication sharedApplication] delegate];

	//do we have an internet connection?
	if (![delegate canConnectToInternet])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Login Failure", @"unable to login")
			message: NSLocalizedString(@"No internet connection available", "no internet connection") delegate: self
				cancelButtonTitle: NSLocalizedString(@"OK", @"ok") otherButtonTitles: nil];
		[alert show];
		[alert release];  
		return NO;    
	}

	//start spinner
	[self startLoginSpinner];

	// If we got a custom server then we configure it right away
	
	if (_customServerEnabled && [_customServerURL length] != 0) {
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"useCustomServer"];
		[[NSUserDefaults standardUserDefaults] setObject: _customServerURL forKey: @"customServerURL"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	} else {
		[[NSUserDefaults standardUserDefaults] setBool: NO forKey: @"useCustomServer"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"customServerURL"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}

	//we require the username to be lowercase, so we do it here on the way out
	NSDictionary* authDict = [NSDictionary dictionaryWithObjectsAndKeys:
		[[self usernameTextField].text lowercaseString], @"user",
		[self passwordTextField].text, @"pass",
		[self syncKeyTextField].text, @"secret",
		nil];

	NSThread* authorizer = [[[NSThread alloc] initWithTarget:self selector:@selector(authorize:) object:authDict] autorelease];
	[authorizer start];
	
	return YES;
}

#pragma mark -

- (void) customServerSwitchChangedValue: (UISwitch*) sender
{
	if (sender.on) {
		[self customServerTextField].placeholder = NSLocalizedString(@"Required", @"Required");
	} else {
		[self customServerTextField].placeholder = nil;
	}
	
	_customServerEnabled = sender.on;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView: (UITableView*) tableView
{
    return 2;
}

- (NSInteger) tableView: (UITableView*) tableView numberOfRowsInSection: (NSInteger) section
{
	NSInteger numberOfRows = 0;

	switch (section) {
		case 0:
			numberOfRows = 3;
			break;
		case 1:
			numberOfRows = 2;
			break;
	}

    return numberOfRows;
}


- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
	return 36;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
	UILabel* label = nil;
	
	if (section == 1) {
		label = [[[UILabel alloc] initWithFrame: CGRectMake(0, 0, 320, 36)] autorelease];
		label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
		label.backgroundColor = [UIColor clearColor];
		label.textAlignment = UITextAlignmentCenter;
		label.textColor = [UIColor whiteColor];
		label.font = [UIFont boldSystemFontOfSize: 13];
		label.text = NSLocalizedString(@"Caution: use at own risk", @"Caution: use at own risk");
	}
	return label;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	return 36;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	UILabel* label = nil;
	
	if (section == 0) {
		label = [[[UILabel alloc] initWithFrame: CGRectMake(0, 0, 320, 36)] autorelease];
		label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
		label.backgroundColor = [UIColor clearColor];
		label.textAlignment = UITextAlignmentCenter;
		label.textColor = [UIColor whiteColor];
		label.font = [UIFont boldSystemFontOfSize: 13];
		label.text = NSLocalizedString(@"Enter your Sync account information", @"Enter your Sync account information");
	}
	return label;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString* cellIdentifier = @"LabelAndTextFieldCell";
	if (indexPath.section == 1 && indexPath.row == 0) {
		cellIdentifier = @"LabelAndSwitchCell";
	} else if (indexPath.section == 0 && indexPath.row == 1) {
		cellIdentifier = @"LabelAndSecureTextFieldCell";
	}
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: cellIdentifier];
    if (cell == nil)
	{
		cell = [[[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: cellIdentifier] autorelease];
		
		if ([cellIdentifier isEqualToString: @"LabelAndTextFieldCell"] || [cellIdentifier isEqualToString: @"LabelAndSecureTextFieldCell"])
		{
			UILabel* label = [[[UILabel alloc] initWithFrame: CGRectMake(20, 7, 100, 30)] autorelease];
			label.adjustsFontSizeToFitWidth = YES;
			label.font = [UIFont boldSystemFontOfSize: 15.0];
			label.text = @"Label";
			label.tag = 1;
			label.adjustsFontSizeToFitWidth = YES;
			[cell addSubview: label];
			
			UITextField* textField = [[[UITextField alloc] initWithFrame:CGRectMake(124, 13, 170, 24)] autorelease];
			textField.font = [UIFont boldSystemFontOfSize: 15];
			textField.textColor = [UIColor blackColor];
			textField.placeholder = NSLocalizedString(@"Required", @"Required");
			textField.keyboardType = UIKeyboardTypeDefault;
			textField.returnKeyType = UIReturnKeyDone;
			textField.backgroundColor = [UIColor whiteColor];
			textField.autocorrectionType = UITextAutocorrectionTypeNo;
			textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			textField.textAlignment = UITextAlignmentLeft;
			textField.tag = 2;
			textField.clearButtonMode = UITextFieldViewModeNever;
			textField.enabled;
			textField.delegate = self;
			textField.secureTextEntry = [cellIdentifier isEqualToString: @"LabelAndSecureTextFieldCell"];
			[cell addSubview: textField];
		}
		
		if ([cellIdentifier isEqualToString: @"LabelAndSwitchCell"])
		{			
			UILabel* label = [[[UILabel alloc] initWithFrame: CGRectMake(20, 9, 170, 30)] autorelease];
			label.font = [UIFont boldSystemFontOfSize: 15.0];
			label.adjustsFontSizeToFitWidth = YES;
			label.text = @"Label";
			label.tag = 1;
			[cell addSubview: label];

			UISwitch* schwitch = [[[UISwitch alloc] initWithFrame: CGRectMake(200, 10, 20, 20)] autorelease];
			schwitch.tag = 2;
			[cell addSubview: schwitch];
		}
    }
    
	// Configure the cell
	
	switch (indexPath.section)
	{
		case 0:
		{
			switch (indexPath.row)
			{
				case 0: {
					UILabel* label = (UILabel*) [cell viewWithTag: 1];
					label.text = NSLocalizedString(@"Account", @"Account");
					UITextField* textField = (UITextField*) [cell viewWithTag: 2];
					textField.text = _username;
					break;
				}
				case 1: {
					UILabel* label = (UILabel*) [cell viewWithTag: 1];
					label.text = NSLocalizedString(@"Password", @"Password");
					UITextField* textField = (UITextField*) [cell viewWithTag: 2];
					textField.text = _password;
					break;
				}
				case 2: {
					UILabel* label = (UILabel*) [cell viewWithTag: 1];
					label.text = NSLocalizedString(@"Sync Key", @"Sync Key");
					UITextField* textField = (UITextField*) [cell viewWithTag: 2];
					textField.text = _secret;
					break;
				}
			}
			
			break;
		}
		
		case 1:
		{
			switch (indexPath.row)
			{
				case 0: {
					UILabel* label = (UILabel*) [cell viewWithTag: 1];
					label.text = NSLocalizedString(@"Use Custom Server", @"Use Custom Server");
					UISwitch* schwitch = (UISwitch*) [cell viewWithTag: 2];
					schwitch.on = _customServerEnabled;
					[schwitch addTarget: self action: @selector(customServerSwitchChangedValue:) forControlEvents: UIControlEventValueChanged];
					break;
				}
				case 1: {
					UILabel* label = (UILabel*) [cell viewWithTag: 1];
					label.text = NSLocalizedString(@"Server URL", @"Server URL");
					UITextField* textField = (UITextField*) [cell viewWithTag: 2];
					textField.placeholder = nil;
					textField.text = _customServerURL;
					[textField addTarget: self action: @selector(customServerTextFieldChangedValue:) forControlEvents: UIControlEventValueChanged];
					break;
				}
			}

			break;
		}
	}
	
    return cell;
}

@end
