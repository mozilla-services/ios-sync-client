#import "KeyDerivationTest.h"
#import "NSString+Decoding.h"
#import "NSData+SHA.h"
#import "NSData+WeaveKeys.h"
#import "WeaveKeys.h"

@implementation KeyDerivationTest

- (void) testSimplifiedCryptoKeyDerivation
{
	NSString* username = @"stefan@arentz.ca";
	NSString* secret = @"p5zmnhdhc4v2ek5mfvzkzvb23i";

	const unsigned char correctEncrKeyBytes[32] = {
		0x19, 0xe4, 0x95, 0x74, 0x18, 0x25, 0x68, 0x9b, 0x2a, 0xe2, 0x94, 0xc4, 0xa2, 0xc8, 0x36, 0x1c,
        0xae, 0x31, 0x39, 0x78, 0x35, 0x24, 0xbe, 0xfd, 0xad, 0xaa, 0xff, 0x80, 0xe7, 0x5a, 0x36, 0xc0
	};

	NSData* correctEncrKeyData = [NSData dataWithBytes: correctEncrKeyBytes length: sizeof correctEncrKeyBytes];

	const unsigned char correctHmacKeyBytes[32] = {
		0xa5, 0x1c, 0xf1, 0x2f, 0xf3, 0xb0, 0x08, 0xf7, 0xff, 0x07, 0x28, 0x5e, 0x10, 0x34, 0x02, 0x4d,
        0x25, 0x2b, 0x2e, 0x89, 0xf2, 0x20, 0xd4, 0xca, 0x84, 0x4e, 0x29, 0x1a, 0x2a, 0x11, 0x12, 0x36
	};

	NSData* correctHmacKeyData = [NSData dataWithBytes: correctHmacKeyBytes length: sizeof correctHmacKeyBytes];

	//
	
	NSLog(@"Secret is %@", [secret userfriendlyBase32Decoding]);
	
	WeaveKeys* weaveKeys = [[WeaveKeys alloc] initWithMasterKey: [secret userfriendlyBase32Decoding] username: username];
	STAssertNotNil(weaveKeys, @"");

	NSData* cryptoKey = weaveKeys.cryptoKey;
	STAssertNotNil(cryptoKey, @"");
	
	NSData* hmacKey = weaveKeys.hmacKey;
	STAssertNotNil(hmacKey, @"");

	STAssertEqualObjects(correctEncrKeyData, weaveKeys.cryptoKey, @"Incorrect AES Key. Expected %@ but got %@", correctEncrKeyData, cryptoKey);
	STAssertEqualObjects(correctHmacKeyData, weaveKeys.hmacKey, @"Incorrect HMAC Key. Expected %@ but got %@", correctHmacKeyData, hmacKey);
}

- (void) testDeriveKeyFromPassphraseAndSyncID
{
	NSString* passphrase = @"secret phrase";
	NSString* salt = @"DNXPzPpiwn";
	
	const unsigned char correctKeyBytes[16] = {
		0x77, 0x6c, 0xc6, 0xd1, 0xdd, 0x9c, 0x05, 0xf5, 0xe7, 0x47, 0x03, 0x14, 0x1b, 0x23, 0x30, 0xca
	};
	
	NSData* derivedKey = [NSData weaveKeyDataFromPassphrase: passphrase salt: salt];
	NSData* correctKey = [NSData dataWithBytes: correctKeyBytes length: 16];
	
	STAssertEqualObjects(correctKey, derivedKey, @"Incorrect derived key. Expected %@ but got %@", correctKey, derivedKey);
}

@end
