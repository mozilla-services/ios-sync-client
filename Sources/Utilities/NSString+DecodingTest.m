#import "NSString+DecodingTest.h"
#import "NSString+Decoding.h"

@implementation NSString_DecodingTest

- (NSString*) decode: (NSString*) encoded
{
	NSData* decodedData = [encoded base32Decoding];
	return [[[NSString alloc] initWithData: decodedData encoding: NSUTF8StringEncoding] autorelease];
}

- (void) testBase32DecodingRFC
{
	STAssertEqualObjects(@"", [self decode: @""], @"Decode of '' failed");
	STAssertEqualObjects(@"f", [self decode: @"MY======"], @"Decode of 'MY======' failed");
	STAssertEqualObjects(@"f", [self decode: @"MY"], @"Decode of 'MY' failed");
	STAssertEqualObjects(@"fo", [self decode: @"MZXQ===="], @"Decode of 'MZXQ====' failed");
	STAssertEqualObjects(@"fooba", [self decode: @"MZXW6YTB"], @"Decode of 'MZXW6YTB' failed");
	STAssertEqualObjects(@"foobar", [self decode: @"MZXW6YTBOI======"], @"Decode of 'MZXW6YTBOI======' failed");

	STAssertEqualObjects(@"foobar", [self decode: @"MZXW6YTBOI=="], @"Decode of 'MZXW6YTBOI==' failed");
	STAssertEqualObjects(@"foobar", [self decode: @"MZXW6YTBOI"], @"Decode of 'MZXW6YTBOI' failed");
}

- (void) testBase32Decoding
{
	NSString* expectedString = @"foobarbafoobarba";

	NSData* decodedData = [@"MZXW6YTBOJRGCZTPN5RGC4TCME" base32Decoding];
	NSString* decodedString = [[[NSString alloc] initWithData: decodedData encoding: NSASCIIStringEncoding] autorelease];
	STAssertEqualObjects(expectedString, decodedString, @"base32Decoding failed. Expected %@ but got %@", expectedString, decodedString);
}

- (void) testUserfriendlyBase32Decoding
{
	NSString* expectedString = @"foobarbafoobarba";

	NSData* decodedData = [@"mzxw6ytb9jrgcztpn5rgc4tcme" userfriendlyBase32Decoding];	
	NSString* decodedString = [[[NSString alloc] initWithData: decodedData encoding: NSASCIIStringEncoding] autorelease];
	STAssertEqualObjects(expectedString, decodedString, @"userfriendlyBase32Decoding failed. Expected %@ but got %@", expectedString, decodedString);
}

@end
