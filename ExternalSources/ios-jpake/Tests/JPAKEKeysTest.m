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

#import "JPAKEKeysTest.h"
#import "JPAKEKeys.h"

@implementation JPAKEKeysTest

- (void) testKeyDerivation
{
	NSData* key = [@"0123456789abcdef0123456789abcdef" dataUsingEncoding: NSASCIIStringEncoding];
		
	const unsigned char expectedCryptoKeyBytes[32] = {
		0x53, 0x00, 0x84, 0x3c, 0xc2, 0x0d, 0x56, 0x88, 0x81, 0x47, 0x15, 0x97, 0x52, 0x4f, 0x12, 0x5c,
		0x8f, 0xe3, 0xf8, 0x06, 0xa5, 0x48, 0xce, 0xfd, 0x05, 0x32, 0x26, 0xdd, 0xb5, 0xf4, 0x0f, 0xe8
	};

	NSData* expectedCryptoKey = [NSData dataWithBytes: expectedCryptoKeyBytes length: 32];

	const unsigned char expectedHmacKeyBytes[32] = {
		0x1f, 0x1f, 0x0b, 0x85, 0xc3, 0x41, 0x8c, 0x2b, 0x26, 0xa6, 0x8a, 0x0a, 0x40, 0x49, 0xe2, 0x92,
		0x58, 0x5a, 0x05, 0x68, 0xbd, 0x1c, 0x8a, 0xdd, 0x97, 0xe6, 0x6d, 0xbb, 0x65, 0xb8, 0xbe, 0x99
	};

	NSData* expectedHmacKey = [NSData dataWithBytes: expectedHmacKeyBytes length: 32];

	//

	JPAKEKeys* keys = [[[JPAKEKeys alloc] initWithMasterKey: key] autorelease];

	STAssertNotNil(keys, @"");	
	STAssertEqualObjects(expectedCryptoKey, keys.cryptoKey, @"");
	STAssertEqualObjects(expectedHmacKey, keys.hmacKey, @"");
}

@end
