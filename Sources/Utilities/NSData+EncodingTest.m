#import "NSData+EncodingTest.h"
#import "NSData+Encoding.h"

@implementation NSData_EncodingTest

- (void) testBase32Encoding;
{
	NSData* data = [@"foobarbafoobarba" dataUsingEncoding: NSUTF8StringEncoding];
	NSString* encoded = [data base32Encoding];

    STAssertEqualObjects(@"MZXW6YTBOJRGCZTPN5RGC4TCME======", encoded,
		@"base32encoding failed");
}

- (void) testUserfriendlyBase32Encoding
{
	NSData* data = [@"foobarbafoobarba" dataUsingEncoding: NSUTF8StringEncoding];
	NSString* encoded = [data userfriendlyBase32Encoding];

    STAssertEqualObjects(@"MZXW6YTB9JRGCZTPN5RGC4TCME======", encoded,
		@"userfriendlyBase32encoding failed");
}

@end
