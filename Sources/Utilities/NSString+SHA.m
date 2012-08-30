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

#import "NSString+SHA.h"

#include <openssl/evp.h>
#include <openssl/hmac.h>

@implementation NSString (SHA)

- (NSData*) SHA256Hash
{
	NSData* result = nil;

	const EVP_MD* md = EVP_sha256();
	if (md != NULL)
	{
		unsigned char md_value[EVP_MAX_MD_SIZE];
		unsigned int md_len;	
		EVP_MD_CTX mdctx;

		const char* s = [self UTF8String];

		EVP_MD_CTX_init(&mdctx);
		EVP_DigestInit_ex(&mdctx, md, NULL);
		EVP_DigestUpdate(&mdctx, (const void*) s, strlen(s));
		EVP_DigestFinal_ex(&mdctx, md_value, &md_len);
		EVP_MD_CTX_cleanup(&mdctx);
		
		result = [NSData dataWithBytes: md_value length: md_len];
	}
	
	return result;
}

- (NSData*) HMACSHA256WithKey: (NSData*) key
{
	NSData* result = nil;

	const EVP_MD* evp_md = EVP_sha256();
	if (evp_md != NULL)
	{
		unsigned char hmac_value[EVP_MAX_MD_SIZE];
		unsigned int hmac_length;
	
		const char* s = [self UTF8String];
	
		if (HMAC(evp_md, [key bytes], [key length], (const void*) s, strlen(s), hmac_value, &hmac_length) != NULL) {
			result = [NSData dataWithBytes: hmac_value length: hmac_length];
		}
	}
	
	return result;
}

@end
