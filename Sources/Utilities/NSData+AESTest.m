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

#import "NSData+AES.h"
#import "NSData+AESTest.h"

@implementation NSData_AESTest

- (void) testEncryption
{
	NSData* plaintext = [NSData dataWithBytes: "ThisStringIsExactlyThirtyTwoByte" length: 32];

	NSData* key = [NSData dataWithBytes: "0123456789abcdef0123456789abcdef" length: 32];

	NSData* iv = [NSData dataWithBytes: "0123456789abcdef" length: 16];
	
	unsigned char expectedCiphertextBytes[48] = {
		0x26, 0xfc, 0x3a, 0x9c, 0x95, 0x76, 0x53, 0x36, 0x12, 0x3d, 0xed, 0xcb, 0xeb, 0xcc, 0x0c, 0x3f,
		0x65, 0x2c, 0xc4, 0x47, 0x3c, 0x6c, 0x6f, 0x0d, 0xfe, 0x27, 0xc1, 0xd4, 0xcf, 0x04, 0xc3, 0xae,
		0x32, 0xbe, 0xa9, 0xf6, 0xe1, 0x94, 0x0a, 0x15, 0xf4, 0x46, 0xf4, 0xcb, 0xf5, 0x16, 0x14, 0x1f
	};
	NSData* expectedCiphertext = [NSData dataWithBytes: expectedCiphertextBytes length: 48];
	
	//
	
	NSData* ciphertext = [NSData ciphertextDataByAES256EncrypingPlaintextData: plaintext key: key iv: iv padding: YES];
		
	STAssertNotNil(ciphertext, @"");
	STAssertEqualObjects(expectedCiphertext, ciphertext, @"");
}

- (void) testDecryption
{
	unsigned char ciphertextBytes[48] = {
		0x26, 0xfc, 0x3a, 0x9c, 0x95, 0x76, 0x53, 0x36, 0x12, 0x3d, 0xed, 0xcb, 0xeb, 0xcc, 0x0c, 0x3f,
		0x65, 0x2c, 0xc4, 0x47, 0x3c, 0x6c, 0x6f, 0x0d, 0xfe, 0x27, 0xc1, 0xd4, 0xcf, 0x04, 0xc3, 0xae,
		0x32, 0xbe, 0xa9, 0xf6, 0xe1, 0x94, 0x0a, 0x15, 0xf4, 0x46, 0xf4, 0xcb, 0xf5, 0x16, 0x14, 0x1f
	};
	NSData* ciphertext = [NSData dataWithBytes: ciphertextBytes length: 48];

	NSData* key = [NSData dataWithBytes: "0123456789abcdef0123456789abcdef" length: 32];

	NSData* iv = [NSData dataWithBytes: "0123456789abcdef" length: 16];
	
	NSData* expectedPlaintext = [NSData dataWithBytes: "ThisStringIsExactlyThirtyTwoByte" length: 32];
	
	//
	
	NSData* plaintext = [NSData plaintextDataByAES256DecryptingCiphertextData: ciphertext key: key iv: iv padding: YES];
	
	STAssertNotNil(plaintext, @"");
	STAssertEqualObjects(expectedPlaintext, plaintext, @"");
	
}

@end
