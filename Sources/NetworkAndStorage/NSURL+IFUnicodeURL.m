//  Created by Sean Heber on 4/22/10.
#import "NSURL+IFUnicodeURL.h"
#import "IDNSDK/xcode.h"

@interface NSString (IFUnicodeURLHelpers)
- (NSArray *)IFUnicodeURL_splitAfterString:(NSString *)string;
- (NSArray *)IFUnicodeURL_splitBeforeCharactersInSet:(NSCharacterSet *)chars;
@end


@implementation NSString (IFUnicodeURLHelpers)
- (NSArray *)IFUnicodeURL_splitAfterString:(NSString *)string
{
	NSString *firstPart;
	NSString *secondPart;
	NSRange range = [self rangeOfString:string];
	
	if (range.location != NSNotFound) {
		NSUInteger index = range.location+range.length;
		firstPart = [self substringToIndex:index];
		secondPart = [self substringFromIndex:index];
	} else {
		firstPart = @"";
		secondPart = self;
	}
	
	return [NSArray arrayWithObjects:firstPart, secondPart, nil];
}

- (NSArray *)IFUnicodeURL_splitBeforeCharactersInSet:(NSCharacterSet *)chars
{
	NSUInteger index=0;
	for (; index<[self length]; index++) {
		if ([chars characterIsMember:[self characterAtIndex:index]]) {
			break;
		}
	}
	
	return [NSArray arrayWithObjects:[self substringToIndex:index], [self substringFromIndex:index], nil];
}
@end

static NSString *ConvertUnicodeDomainString(NSString *hostname, BOOL toAscii)
{
	const UTF16CHAR *inputString = (const UTF16CHAR *)[hostname cStringUsingEncoding:NSUTF16StringEncoding];
	int inputLength = [hostname lengthOfBytesUsingEncoding:NSUTF16StringEncoding] / sizeof(UTF16CHAR);
	
	if (toAscii) {
		int outputLength = MAX_DOMAIN_SIZE_8;
		UCHAR8 outputString[outputLength];
		
		if (XCODE_SUCCESS == Xcode_DomainToASCII(inputString, inputLength, outputString, &outputLength)) {
			hostname = [[[NSString alloc] initWithBytes:outputString length:outputLength encoding:NSASCIIStringEncoding] autorelease];
		}
	} else {
		int outputLength = MAX_DOMAIN_SIZE_16;
		UTF16CHAR outputString[outputLength];
		if (XCODE_SUCCESS == Xcode_DomainToUnicode16(inputString, inputLength, outputString, &outputLength)) {
			hostname = [[[NSString alloc] initWithCharacters:outputString length:outputLength] autorelease];
		}
	}
	
	return hostname;
}

static NSString *ConvertUnicodeURLString(NSString *str, BOOL toAscii)
{
	NSMutableArray *urlParts = [[NSMutableArray new] autorelease];
	NSString *hostname = nil;
	NSArray *parts = nil;
	
	parts = [str IFUnicodeURL_splitAfterString:@":"];
	hostname = [parts objectAtIndex:1];
	[urlParts addObject:[parts objectAtIndex:0]];
	
	parts = [hostname IFUnicodeURL_splitAfterString:@"//"];
	hostname = [parts objectAtIndex:1];
	[urlParts addObject:[parts objectAtIndex:0]];
	
	parts = [hostname IFUnicodeURL_splitBeforeCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/?#"]];
	hostname = [parts objectAtIndex:0];
	[urlParts addObject:[parts objectAtIndex:1]];
	
	parts = [hostname IFUnicodeURL_splitAfterString:@"@"];
	hostname = [parts objectAtIndex:1];
	[urlParts addObject:[parts objectAtIndex:0]];
	
	parts = [hostname IFUnicodeURL_splitBeforeCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":"]];
	hostname = [parts objectAtIndex:0];
	[urlParts addObject:[parts objectAtIndex:1]];
	
	// Now that we have isolated just the hostname, do the magic decoding...
	hostname = ConvertUnicodeDomainString(hostname, toAscii);
	
	// This will try to clean up the stuff after the hostname in the URL by making sure it's all encoded properly.
	// NSURL doesn't normally do anything like this, but I found it useful for my purposes to put it in here.
	NSString *afterHostname = [[urlParts objectAtIndex:4] stringByAppendingString:[urlParts objectAtIndex:2]];
	CFStringRef cleanedAfterHostname = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault, (CFStringRef)afterHostname, CFSTR(""), kCFStringEncodingUTF8);
	NSString *processedAfterHostname = (NSString *)cleanedAfterHostname ?: afterHostname;
	CFStringRef finalAfterHostname = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)processedAfterHostname, CFSTR("#[]"), NULL, kCFStringEncodingUTF8);
	
	// Now recreate the URL safely with the new hostname (if it was successful) instead...
	NSArray *reconstructedArray = [NSArray arrayWithObjects:[urlParts objectAtIndex:0], [urlParts objectAtIndex:1], [urlParts objectAtIndex:3], hostname, (NSString *)finalAfterHostname, nil];
	NSString *reconstructedURLString = [reconstructedArray componentsJoinedByString:@""];

	if (cleanedAfterHostname) CFRelease(cleanedAfterHostname);
	CFRelease(finalAfterHostname);

	return reconstructedURLString;
}

@implementation NSURL (IFUnicodeURL)
+ (NSURL *)URLWithUnicodeString:(NSString *)str
{
	return [[[self alloc] initWithUnicodeString:str] autorelease];
}

- (id)initWithUnicodeString:(NSString *)str
{
	return [self initWithString:ConvertUnicodeURLString(str, YES)];
}

- (NSString *)unicodeAbsoluteString
{
	return ConvertUnicodeURLString([self absoluteString], NO);
}

- (NSString *)unicodeHost
{
	return ConvertUnicodeDomainString([self host], NO);
}

@end
