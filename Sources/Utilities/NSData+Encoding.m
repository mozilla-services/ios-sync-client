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
 *  Dan Walkowski <dwalkowski@mozilla.com>
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

#import "NSData+Encoding.h"
#include <openssl/bn.h>

// NSData (Base64) Additions adapted from:
// Copyright (c) 2001 Kyle Hammond. All rights reserved.
// Formatted by Timothy Hatcher on Sun Jul 4 2004.
// Original development by Dave Winer.

static char encodingTable[64] = {
		'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
		'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
		'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
		'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/' };

@implementation NSData (AlternateBaseStringEncodings)

-(id) initWithBase64EncodedString:(NSString *)string {
	NSMutableData *mutableData = nil;

	if (string) {
		unsigned long ixtext = 0;
		unsigned long lentext = 0;
		unsigned char ch = 0;
		unsigned char inbuf[4], outbuf[3];
		short i = 0, ixinbuf = 0;
		BOOL flignore = NO;
		BOOL flendtext = NO;
		NSData *base64Data = nil;
		const unsigned char *base64Bytes = nil;

		// Convert the string to ASCII data.
		base64Data = [string dataUsingEncoding:NSASCIIStringEncoding];
		base64Bytes = [base64Data bytes];
		mutableData = [NSMutableData dataWithCapacity:[base64Data length]];
		lentext = [base64Data length];

		while (YES) {
			if (ixtext >= lentext) break;
			ch = base64Bytes[ixtext++];
			flignore = NO;

			if ((ch >= 'A') && (ch <= 'Z')) ch = ch - 'A';
			else if ((ch >= 'a') && (ch <= 'z')) ch = ch - 'a' + 26;
			else if ((ch >= '0') && (ch <= '9')) ch = ch - '0' + 52;
			else if (ch == '+') ch = 62;
			else if (ch == '=') flendtext = YES;
			else if (ch == '/') ch = 63;
			else flignore = YES;

			if (!flignore) {
				short ctcharsinbuf = 3;
				BOOL flbreak = NO;

				if (flendtext) {
					if(!ixinbuf) break;
					if((ixinbuf == 1) || (ixinbuf == 2)) ctcharsinbuf = 1;
					else ctcharsinbuf = 2;
					ixinbuf = 3;
					flbreak = YES;
				}

				inbuf[ixinbuf++] = ch;

				if (ixinbuf == 4) {
					ixinbuf = 0;
					outbuf [0] = (inbuf[0] << 2) | ((inbuf[1] & 0x30) >> 4);
					outbuf [1] = ((inbuf[1] & 0x0F) << 4) | ((inbuf[2] & 0x3C) >> 2);
					outbuf [2] = ((inbuf[2] & 0x03) << 6) | (inbuf[3] & 0x3F);

					for (i = 0; i < ctcharsinbuf; i++)
						[mutableData appendBytes:&outbuf[i] length:1];
				}

				if (flbreak) break;
			}
		}
	}

	self = [self initWithData:mutableData];
	return self;
}

-(id) initWithBase16EncodedString:(NSString *) string
{
	if (string == nil || ([string length] % 2) != 0) {
		[self release];
		return nil;
	}
	
	if ([string length] == 0) {
		return [super init];
	}

	size_t length = [string length] / 2;
	unsigned char* data = malloc(length);
	if (data != nil)
	{
		const char* src = [string cStringUsingEncoding: NSASCIIStringEncoding];
		unsigned char* dst = data;
	
		for (size_t i = 0; i < length; i++)
		{
			unsigned char result = 0;

			if (*src >= '0' && *src <= '9') {
				result = (*src++ - '0') << 4;
			} else if (*src >= 'a' && *src <= 'f') {
				result = (*src++ - 'a' + 10) << 4;
			} else if (*src >= 'A' && *src <= 'F') {
				result = (*src++ - 'A' + 10) << 4;
			} else {
				free(data);
				[self release];
				return nil;
			}

			if (*src >= '0' && *src <= '9') {
				result |= (*src++ - '0');
			} else if (*src >= 'a' && *src <= 'f') {
				result |= (*src++ - 'a' + 10);
			} else if (*src >= 'A' && *src <= 'F') {
				result |= (*src++ - 'A' + 10);
			} else {
				free(data);
				[self release];
				return nil;
			}
			
			*dst++ = result;
		}
	}
	
	self = [self initWithBytesNoCopy: data length: length freeWhenDone: YES];
	return self;
}

/**
 * Interpret the current data as a big number and convert it to base36 encoding. This
 * was specifically written with short strings in mind and is probably not great to
 * encode large blobs of data.
 */

-(NSString *) base36Encoding
{
	static char digits[37] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

	NSMutableString* result = nil;

	BIGNUM* n = BN_bin2bn([self bytes], [self length], NULL);
	if (n != NULL)
	{
		result = [[NSMutableString new] autorelease];
		
		while (1)
		{
			unichar c = digits[BN_mod_word(n, 36)];
			BN_div_word(n, 36);

			[result insertString: [NSString stringWithCharacters: &c length: 1] atIndex: 0];

			if (BN_is_zero(n)) {
				break;
			}
		}
		
		BN_free(n);
	}

	return result;
}

-(NSString *) base64Encoding {
	return [self base64EncodingWithLineLength:0];
}

-(NSString *) base64EncodingWithLineLength:(unsigned int) lineLength {
	const unsigned char	*bytes = [self bytes];
	NSMutableString *result = [NSMutableString stringWithCapacity:[self length]];
	unsigned long ixtext = 0;
	unsigned long lentext = [self length];
	long ctremaining = 0;
	unsigned char inbuf[3], outbuf[4];
	unsigned short i = 0;
	unsigned short charsonline = 0, ctcopy = 0;
	unsigned long ix = 0;

	while (YES) {
		ctremaining = lentext - ixtext;
		if (ctremaining <= 0) break;

		for (i = 0; i < 3; i++) {
			ix = ixtext + i;
			if (ix < lentext) inbuf[i] = bytes[ix];
			else inbuf [i] = 0;
		}

		outbuf [0] = (inbuf [0] & 0xFC) >> 2;
		outbuf [1] = ((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4);
		outbuf [2] = ((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6);
		outbuf [3] = inbuf [2] & 0x3F;
		ctcopy = 4;

		switch (ctremaining) {
			case 1:
				ctcopy = 2;
				break;
			case 2:
				ctcopy = 3;
				break;
		}

		for (i = 0; i < ctcopy; i++)
			[result appendFormat:@"%c", encodingTable[outbuf[i]]];

		for (i = ctcopy; i < 4; i++)
			[result appendString:@"="];

		ixtext += 3;
		charsonline += 4;

		if (lineLength > 0) {
			if (charsonline >= lineLength) {
				charsonline = 0;
				[result appendString:@"\n"];
			}
		}
	}

	return [NSString stringWithString:result];
}


- (NSString*)base16Encoding 
{
	static const char hexdigits[] = "0123456789abcdef";
	const size_t numBytes = [self length];
	const unsigned char* bytes = [self bytes];
	char *strbuf = (char *)malloc(numBytes * 2 + 1);
	char *hex = strbuf;
	NSString *hexBytes = nil;
  
	for (int i = 0; i<numBytes; ++i) 
  {
		const unsigned char c = *bytes++;
		*hex++ = hexdigits[(c >> 4) & 0xF];
		*hex++ = hexdigits[(c ) & 0xF];
	}
	*hex = 0;
	hexBytes = [NSString stringWithUTF8String:strbuf];
	free(strbuf);
	return hexBytes;
}

#pragma mark -

// Public domain Base32 code taken from http://bitzi.com/publicdomain

static char *base32Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

static int base32_encode_length(int rawLength)
{
    return ((rawLength * 8) / 5) + ((rawLength % 5) != 0) + 1;
}

static void base32_encode_into(const void *_buffer, unsigned int bufLen, char *base32Buffer)
{
    unsigned int i, index;
    unsigned char word;
    const unsigned char *buffer = _buffer;

    for(i = 0, index = 0; i < bufLen;)
    {
        /* Is the current word going to span a byte boundary? */
        if (index > 3)
        {
            word = (buffer[i] & (0xFF >> index));
            index = (index + 5) % 8;
            word <<= index;
            if (i < bufLen - 1)
                word |= buffer[i + 1] >> (8 - index);

            i++;
        }
        else
        {
            word = (buffer[i] >> (8 - (index + 5))) & 0x1F;
            index = (index + 5) % 8;
            if (index == 0)
                i++;
        }

        assert(word < 32);
        *(base32Buffer++) = (char)base32Chars[word];
    }

    *base32Buffer = 0;
}

static char *base32_encode(const void *buf, unsigned int len)
{
    char *tmp = malloc(base32_encode_length(len));
    base32_encode_into(buf, len, tmp);
    return tmp;
}

/**
 * Base32 encode (RFC 4648) the current data. Returns a string with encoded and
 * padded data. Returns an empty string if the input length was zero.
 */

- (NSString*) base32Encoding
{
	NSMutableString* result = nil;

	if ([self length] == 0) {
		return @"";
	}

	char* encoded = base32_encode([self bytes], [self length]);
	
	result = [[[NSMutableString alloc] initWithBytesNoCopy: encoded length: strlen(encoded)
		encoding: NSASCIIStringEncoding freeWhenDone: YES] autorelease];

	switch ([self length] % 5) {
		case 1:
			[result appendString: @"======"];
			break;
		case 2:
			[result appendString: @"===="];
			break;
		case 3:
			[result appendString: @"==="];
			break;
		case 4:
			[result appendString: @"="];
			break;
	}
		
	return result;
}

- (NSString*) userfriendlyBase32Encoding
{
	return [[[self base32Encoding]
		stringByReplacingOccurrencesOfString: @"L" withString: @"8"]
			stringByReplacingOccurrencesOfString: @"O" withString: @"9"];
}

@end
