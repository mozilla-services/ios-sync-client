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

#import <UIKit/UIKit.h>
#import "CryptoUtils.h"

@class ManualSetupViewController;

@protocol ManualSetupViewControllerDelegate
- (void) manualSetupViewControllerDidLogin: (ManualSetupViewController*) vc;
- (void) manualSetupViewControllerDidCancel: (ManualSetupViewController*) vc;
@end

@interface ManualSetupViewController : UIViewController <UITableViewDelegate,UITableViewDataSource,UITextFieldDelegate> {
  @private
	UIBarButtonItem* _cancelButton;
	UIBarButtonItem* _loginButton;
	UIView* _spinnerView;
	UIActivityIndicatorView* _spinner;
	UITableView* _tableView;
  @private
	id<ManualSetupViewControllerDelegate> _delegate;
  @private
	CryptoUtils* _newCryptoManager;
  @private
	NSString* _username;
	NSString* _password;
	NSString* _secret;
	BOOL _customServerEnabled;
	NSString* _customServerURL;
}

@property (nonatomic,assign) IBOutlet UIBarButtonItem* loginButton;
@property (nonatomic,assign) IBOutlet UIBarButtonItem* cancelButton;
@property (nonatomic, assign) IBOutlet UIView *spinnerView;
@property (nonatomic, assign) IBOutlet UIActivityIndicatorView* spinner;
@property (nonatomic, assign) IBOutlet UITableView* tableView;

@property (nonatomic,assign) id<ManualSetupViewControllerDelegate> delegate;

- (IBAction) cancel;
- (IBAction) login;

@end

//@interface ManualSetupViewController : UIViewController <UITextFieldDelegate> {
//  @private
//	UITextField* _usernameTextField;
//	UITextField* _passwordTextField;
//	UITextField* _syncKeyTextField;
//	UIBarButtonItem* _cancelButton;
//	UIView* _spinnerView;
//	UIActivityIndicatorView* _spinner;
//  @private
//	id<ManualSetupViewControllerDelegate> _delegate;
//  @private
//	CryptoUtils* _newCryptoManager;
//}
//
//@property (nonatomic,assign) IBOutlet UITextField* usernameTextField;
//@property (nonatomic,assign) IBOutlet UITextField* passwordTextField;
//@property (nonatomic,assign) IBOutlet UITextField* syncKeyTextField;
//@property (nonatomic,assign) IBOutlet UIBarButtonItem* cancelButton;
//@property (nonatomic, assign) IBOutlet UIView *spinnerView;
//@property (nonatomic, assign) IBOutlet UIActivityIndicatorView* spinner;
//
//@property (nonatomic,assign) id<ManualSetupViewControllerDelegate> delegate;
//
//- (IBAction) cancel;
//
//@end
