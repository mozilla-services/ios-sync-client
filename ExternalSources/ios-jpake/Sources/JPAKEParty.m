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

#include <openssl/evp.h>
#include <openssl/sha.h>
#include <openssl/hmac.h>
#import "JPAKEParty.h"

/**
 * Convert an OpenSSL BIGNUM to a Cocoa NSString in hex form. The resulting string is
 * lowercase hex without 0x in front.
 */

static NSString* BIGNUM2NSString(const BIGNUM* bn)
{
	NSString* result = nil;

	const char* s = BN_bn2hex(bn);
	if (s != nil) {
		result = [[NSString stringWithCString: s encoding: NSASCIIStringEncoding] lowercaseString];
		OPENSSL_free((void*) s);
	}
	
	return result;
}

/**
 * Get the binary representation of an OpenSSL BIGNUM in a Cocoa NSData instance.
 */

static NSData* BIGNUM2NSData(const BIGNUM* bn)
{
	NSData* result = nil;

	void* buffer = malloc(BN_num_bytes(bn));
	if (buffer != NULL) {
		BN_bn2bin(bn, buffer);
		result = [NSData dataWithBytesNoCopy: buffer length: BN_num_bytes(bn) freeWhenDone: YES];
	}
	
	return result;
}

/**
 * Create an OpenSSL BIGNUM from a Cocoa NSString. The String is a hex encoded big number
 * without the 0x in front.
 */

static void NSString2BIGNUM(NSString* s, BIGNUM** bn)
{
	BN_hex2bn(bn, [s cStringUsingEncoding: NSASCIIStringEncoding]);
}

/**
 * Calculate the hashed password like the J-PAKE Python code does. First make a SHA256 hash
 * from the textual password. Then Calculate 1 + (hashed_password % (q-1)).
 */

static BIGNUM* HashPassword(NSString* password, BIGNUM* q)
{
	BIGNUM* secret = BN_new();
	if (secret != NULL) {
		NSData* passwordData = [password dataUsingEncoding: NSASCIIStringEncoding];
		if (passwordData != nil) {
			BN_bin2bn([passwordData bytes], [passwordData length], secret);
		}
	}
	return secret;
}

@implementation JPAKEParty

+ (id) partyWithPassword: (NSString*) password modulusLength: (NSUInteger) modulusLength signerIdentity: (NSString*) signerIdentity peerIdentity: (NSString*) peerIdentity
{
	return [[[self alloc] initWithPassword: password modulusLength: modulusLength signerIdentity: signerIdentity peerIdentity: peerIdentity] autorelease];
}

- (id) initWithPassword: (NSString*) password modulusLength: (NSUInteger) modulusLength signerIdentity: (NSString*) signerIdentity peerIdentity: (NSString*) peerIdentity
{
	if ((self = [super init]) != nil)
	{
		_signerIdentity = [signerIdentity retain];
	
		BIGNUM* p = NULL;
		BIGNUM* g = NULL;
		BIGNUM* q = NULL;

		switch (modulusLength)
		{
			case 1024:
				BN_hex2bn(&p, "fd7f53811d75122952df4a9c2eece4e7f611b7523cef4400c31e3f80b6512669455d402251fb593d8d58fabfc5f5ba30f6cb9b556cd7813b801d346ff26660b76b9950a5a49f9fe8047b1022c24fbba9d7feb7c61bf83b57e7c6a8a6150f04fb83f6d3c51ec3023554135a169132f675f3ae2b61d72aeff22203199dd14801c7");
				BN_hex2bn(&q, "9760508f15230bccb292b982a2eb840bf0581cf5");
				BN_hex2bn(&g, "f7e1a085d69b3ddecbbcab5c36b857b97994afbbfa3aea82f9574c0b3d0782675159578ebad4594fe67107108180b449167123e84c281613b7cf09328cc8a6e13c167a8b547c8d28e0a3ae1e2bb3a675916ea37f0bfa213562f1fb627a01243bcca4f1bea8519089a883dfe15ae59f06928b665e807b552564014c3bfecf492a");
				break;
			case 2048:
				BN_hex2bn(&p, "C196BA05AC29E1F9C3C72D56DFFC6154A033F1477AC88EC37F09BE6C5BB95F51C296DD20D1A28A067CCC4D4316A4BD1DCA55ED1066D438C35AEBAABF57E7DAE428782A95ECA1C143DB701FD48533A3C18F0FE23557EA7AE619ECACC7E0B51652A8776D02A425567DED36EABD90CA33A1E8D988F0BBB92D02D1D20290113BB562CE1FC856EEB7CDD92D33EEA6F410859B179E7E789A8F75F645FAE2E136D252BFFAFF89528945C1ABE705A38DBC2D364AADE99BE0D0AAD82E5320121496DC65B3930E38047294FF877831A16D5228418DE8AB275D7D75651CEFED65F78AFC3EA7FE4D79B35F62A0402A1117599ADAC7B269A59F353CF450E6982D3B1702D9CA83");
				BN_hex2bn(&q, "90EAF4D1AF0708B1B612FF35E0A2997EB9E9D263C9CE659528945C0D");
				BN_hex2bn(&g, "A59A749A11242C58C894E9E5A91804E8FA0AC64B56288F8D47D51B1EDC4D65444FECA0111D78F35FC9FDD4CB1F1B79A3BA9CBEE83A3F811012503C8117F98E5048B089E387AF6949BF8784EBD9EF45876F2E6A5A495BE64B6E770409494B7FEE1DBB1E4B2BC2A53D4F893D418B7159592E4FFFDF6969E91D770DAEBD0B5CB14C00AD68EC7DC1E5745EA55C706C4A1C5C88964E34D09DEB753AD418C1AD0F4FDFD049A955E5D78491C0B7A2F1575A008CCD727AB376DB6E695515B05BD412F5B8C2F4C77EE10DA48ABD53F5DD498927EE7B692BBBCDA2FB23A516C5B4533D73980B2A3B60E384ED200AE21B40D273651AD6060C13D97FD69AA13C5611A51B9085");
				break;
			case 3072:
				BN_hex2bn(&p, "90066455B5CFC38F9CAA4A48B4281F292C260FEEF01FD61037E56258A7795A1C7AD46076982CE6BB956936C6AB4DCFE05E6784586940CA544B9B2140E1EB523F009D20A7E7880E4E5BFA690F1B9004A27811CD9904AF70420EEFD6EA11EF7DA129F58835FF56B89FAA637BC9AC2EFAAB903402229F491D8D3485261CD068699B6BA58A1DDBBEF6DB51E8FE34E8A78E542D7BA351C21EA8D8F1D29F5D5D15939487E27F4416B0CA632C59EFD1B1EB66511A5A0FBF615B766C5862D0BD8A3FE7A0E0DA0FB2FE1FCB19E8F9996A8EA0FCCDE538175238FC8B0EE6F29AF7F642773EBE8CD5402415A01451A840476B2FCEB0E388D30D4B376C37FE401C2A2C2F941DAD179C540C1C8CE030D460C4D983BE9AB0B20F69144C1AE13F9383EA1C08504FB0BF321503EFE43488310DD8DC77EC5B8349B8BFE97C2C560EA878DE87C11E3D597F1FEA742D73EEC7F37BE43949EF1A0D15C3F3E3FC0A8335617055AC91328EC22B50FC15B941D3D1624CD88BC25F3E941FDDC6200689581BFEC416B4B2CB73");
				BN_hex2bn(&q, "CFA0478A54717B08CE64805B76E5B14249A77A4838469DF7F7DC987EFCCFB11D");
				BN_hex2bn(&g, "5E5CBA992E0A680D885EB903AEA78E4A45A469103D448EDE3B7ACCC54D521E37F84A4BDD5B06B0970CC2D2BBB715F7B82846F9A0C393914C792E6A923E2117AB805276A975AADB5261D91673EA9AAFFEECBFA6183DFCB5D3B7332AA19275AFA1F8EC0B60FB6F66CC23AE4870791D5982AAD1AA9485FD8F4A60126FEB2CF05DB8A7F0F09B3397F3937F2E90B9E5B9C9B6EFEF642BC48351C46FB171B9BFA9EF17A961CE96C7E7A7CC3D3D03DFAD1078BA21DA425198F07D2481622BCE45969D9C4D6063D72AB7A0F08B2F49A7CC6AF335E08C4720E31476B67299E231F8BD90B39AC3AE3BE0C6B6CACEF8289A2E2873D58E51E029CAFBD55E6841489AB66B5B4B9BA6E2F784660896AFF387D92844CCB8B69475496DE19DA2E58259B090489AC8E62363CDF82CFD8EF2A427ABCD65750B506F56DDE3B988567A88126B914D7828E2B63A6D7ED0747EC59E0E0A23CE7D8A74C1D2C2A7AFB6A29799620F00E11C33787F7DED3B30E1A22D09F1FBDA1ABBBFBF25CAE05A13F812E34563F99410E73B");
				break;
			default:
				[self release];
				return nil;
		}
		
		if (p != NULL && g != NULL && q != NULL)
		{
			_secret = HashPassword(password, q);
			if (_secret != NULL)
			{
				_ctx = JPAKE_CTX_new(
					[signerIdentity cStringUsingEncoding: NSASCIIStringEncoding],
					[peerIdentity cStringUsingEncoding: NSASCIIStringEncoding],
					p, g, q, _secret
				);
			}
		}
		
		if (q != NULL) {
			BN_free(q);
		}
		
		if (g != NULL) {
			BN_free(g);
		}
		
		if (p != NULL) {
			BN_free(p);
		}
		
		// If we were unable to create the JPAKE_CTX then something went wrong and we fail.
		
		if (_ctx == NULL) {
			[self release];
			return nil;
		}
	}
	return self;
}

- (void) dealloc
{
	[_signerIdentity release];
	if (_ctx != NULL) {
		JPAKE_CTX_free(_ctx);
	}
	if (_secret != NULL) {
		BN_free(_secret);
	}
	[super dealloc];
}

#pragma mark -

- (NSDictionary*) generateMessageOne
{
	JPAKE_STEP1 step1;
	JPAKE_STEP1_init(&step1);

	JPAKE_STEP1_generate(&step1, _ctx);
	
	NSDictionary* zkp_x1 = [NSDictionary dictionaryWithObjectsAndKeys:
		BIGNUM2NSString(step1.p1.zkpx.gr), @"gr",
		BIGNUM2NSString(step1.p1.zkpx.b), @"b",
		_signerIdentity, @"id",
		nil];

	NSDictionary* zkp_x2 = [NSDictionary dictionaryWithObjectsAndKeys:
		BIGNUM2NSString(step1.p2.zkpx.gr), @"gr",
		BIGNUM2NSString(step1.p2.zkpx.b), @"b",
		_signerIdentity, @"id",
		nil];
	
	NSDictionary* result = [NSDictionary dictionaryWithObjectsAndKeys:
		BIGNUM2NSString(step1.p1.gx), @"gx1",
		BIGNUM2NSString(step1.p2.gx), @"gx2",
		zkp_x1, @"zkp_x1",
		zkp_x2, @"zkp_x2",
		nil];
		
	JPAKE_STEP1_release(&step1);
	
	return result;
}

- (NSDictionary*) generateMessageTwoFromMessageOne: (NSDictionary*) one
{
	JPAKE_STEP1 step1;
	JPAKE_STEP1_init(&step1);
	
	NSString2BIGNUM([one objectForKey: @"gx1"], &step1.p1.gx);
	NSString2BIGNUM([[one objectForKey: @"zkp_x1"] objectForKey: @"b"], &step1.p1.zkpx.b);
	NSString2BIGNUM([[one objectForKey: @"zkp_x1"] objectForKey: @"gr"], &step1.p1.zkpx.gr);
	NSString2BIGNUM([one objectForKey: @"gx2"], &step1.p2.gx);
	NSString2BIGNUM([[one objectForKey: @"zkp_x2"] objectForKey: @"b"], &step1.p2.zkpx.b);
	NSString2BIGNUM([[one objectForKey: @"zkp_x2"] objectForKey: @"gr"], &step1.p2.zkpx.gr);
	
	NSDictionary* result = nil;
	
	if (JPAKE_STEP1_process(_ctx, &step1))
	{
		JPAKE_STEP2 step2;
		JPAKE_STEP2_init(&step2);
		
		JPAKE_STEP2_generate(&step2, _ctx);
		
		NSDictionary* zkp_A = [NSDictionary dictionaryWithObjectsAndKeys:
			BIGNUM2NSString(step2.zkpx.gr), @"gr",
			BIGNUM2NSString(step2.zkpx.b), @"b",
			_signerIdentity, @"id",
			nil];
	
		result = [NSDictionary dictionaryWithObjectsAndKeys:
			BIGNUM2NSString(step2.gx), @"A",
			zkp_A, @"zkp_A",
			nil];
			
		JPAKE_STEP2_release(&step2);
	}
	
	JPAKE_STEP1_release(&step1);
	
	return result;
}

- (NSData*) generateKeyFromMessageTwo: (NSDictionary*) two
{
	JPAKE_STEP2 step2;
	JPAKE_STEP2_init(&step2);
	
	NSString2BIGNUM([two objectForKey: @"A"], &step2.gx);
	NSString2BIGNUM([[two objectForKey: @"zkp_A"] objectForKey: @"b"], &step2.zkpx.b);
	NSString2BIGNUM([[two objectForKey: @"zkp_A"] objectForKey: @"gr"], &step2.zkpx.gr);

	NSData* result = nil;

	if (JPAKE_STEP2_process(_ctx, &step2))
	{
		const BIGNUM* key = JPAKE_get_shared_key(_ctx);
		if (key != nil)
		{
			NSData* keyData = BIGNUM2NSData(key);
			if (keyData != nil)
			{
				const EVP_MD* md = EVP_sha256();
				if (md != NULL)
				{
					unsigned char hmac_value[EVP_MAX_MD_SIZE];
					unsigned int hmac_length;
					
					unsigned char extraction_key[32];
					memset(extraction_key, 0x00, sizeof extraction_key);
				
					if (HMAC(md, extraction_key, sizeof extraction_key, (const void*) [keyData bytes], [keyData length], hmac_value, &hmac_length) != NULL) {
						result = [NSData dataWithBytes: hmac_value length: hmac_length];
					}
				}
			}
		}
	}
	
	JPAKE_STEP2_release(&step2);

	return result;
}

#pragma mark -

/**
 * Returns the hashed password as a NSString encoded big number. This method is here so that we can
 * properly unit test the hashing of the password and compare the values to what the Python code
 * generates.
 */

- (NSString*) hashedPassword
{
	NSString* result = nil;

	const char* s = BN_bn2dec(_secret);
	if (s != nil) {
		result = [NSString stringWithCString: s encoding: NSASCIIStringEncoding];
		OPENSSL_free((void*) s);
	}
	
	return result;
}

@end
