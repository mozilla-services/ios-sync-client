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

#import "NSString+Decoding.h"

static unsigned char strToChar (char a, char b)
{
  char encoder[3] = {'\0','\0','\0'};
  encoder[0] = a;
  encoder[1] = b;
  return (char) strtol(encoder,NULL,16);
}

@implementation NSString (Decoding)

- (NSData *) base16Decoding
{
  const char * bytes = [self cStringUsingEncoding: NSUTF8StringEncoding];
  NSUInteger length = strlen(bytes);
  unsigned char * r = (unsigned char *) malloc(length / 2 + 1);
  unsigned char * index = r;
  
  while ((*bytes) && (*(bytes +1))) {
    *index = strToChar(*bytes, *(bytes +1));
    index++;
    bytes+=2;
  }
  *index = '\0';
  
  NSData * result = [NSData dataWithBytes: r length: length / 2];
  free(r);
  
  return result;
}

#pragma mark -

// Public domain Base32 code taken from http://bitzi.com/publicdomain

#define BASE32_LOOKUP_MAX 43

static unsigned char base32Lookup[BASE32_LOOKUP_MAX][2] =
{
    { '0', 0xFF },
    { '1', 0xFF },
    { '2', 0x1A },
    { '3', 0x1B },
    { '4', 0x1C },
    { '5', 0x1D },
    { '6', 0x1E },
    { '7', 0x1F },
    { '8', 0xFF },
    { '9', 0xFF },
    { ':', 0xFF },
    { ';', 0xFF },
    { '<', 0xFF },
    { '=', 0xFF },
    { '>', 0xFF },
    { '?', 0xFF },
    { '@', 0xFF },
    { 'A', 0x00 },
    { 'B', 0x01 },
    { 'C', 0x02 },
    { 'D', 0x03 },
    { 'E', 0x04 },
    { 'F', 0x05 },
    { 'G', 0x06 },
    { 'H', 0x07 },
    { 'I', 0x08 },
    { 'J', 0x09 },
    { 'K', 0x0A },
    { 'L', 0x0B },
    { 'M', 0x0C },
    { 'N', 0x0D },
    { 'O', 0x0E },
    { 'P', 0x0F },
    { 'Q', 0x10 },
    { 'R', 0x11 },
    { 'S', 0x12 },
    { 'T', 0x13 },
    { 'U', 0x14 },
    { 'V', 0x15 },
    { 'W', 0x16 },
    { 'X', 0x17 },
    { 'Y', 0x18 },
    { 'Z', 0x19 }
};

static int base32_decode_length(int base32Length)
{
    return ((base32Length * 5) / 8);
}

static int base32_decode_into(const char *base32Buffer, unsigned int base32BufLen, void *_buffer)
{
    int i, index, max, lookup, offset;
    unsigned char  word;
    unsigned char *buffer = _buffer;

    memset(buffer, 0, base32_decode_length(base32BufLen));
    max = strlen(base32Buffer);
    for(i = 0, index = 0, offset = 0; i < max; i++)
    {
        lookup = toupper(base32Buffer[i]) - '0';
        /* Check to make sure that the given word falls inside
           a valid range */
        if ( lookup < 0 && lookup >= BASE32_LOOKUP_MAX)
            word = 0xFF;
        else
            word = base32Lookup[lookup][1];

        /* If this word is not in the table, ignore it */
        if (word == 0xFF)
            continue;

        if (index <= 3)
        {
            index = (index + 5) % 8;
            if (index == 0)
            {
                buffer[offset] |= word;
                offset++;
            }
            else
                buffer[offset] |= word << (8 - index);
        }
        else
        {
            index = (index + 5) % 8;
            buffer[offset] |= (word >> index);
            offset++;

            buffer[offset] |= word << (8 - index);
        }
    }
    return offset;
}

static void *base32_decode(const char *buf, unsigned int *outlen)
{
    unsigned int len = strlen(buf);
    char *tmp = malloc(base32_decode_length(len));
    unsigned int x = base32_decode_into(buf, len, tmp);
    if(outlen)
        *outlen = x;
    return tmp;
}

- (NSData*) base32Decoding
{
	NSData* result = nil;

	unsigned int length = 0;
	void* bytes = base32_decode([self UTF8String], &length);

	if (bytes != NULL) {
		result = [NSData dataWithBytesNoCopy: bytes length: length freeWhenDone: YES];
	}
	
	return result;
}

- (NSData*) userfriendlyBase32Decoding
{
	NSData* result = nil;

	NSString* s = [[[self uppercaseString]
		stringByReplacingOccurrencesOfString: @"8" withString: @"l"]
			stringByReplacingOccurrencesOfString: @"9" withString: @"o"];

	if (s != nil)
	{
		unsigned int length = 0;
		void* bytes = base32_decode([s UTF8String], &length);

		if (bytes != NULL) {
			result = [NSData dataWithBytesNoCopy: bytes length: length freeWhenDone: YES];
		}
	}
	
	return result;
}

+ (NSString *)urlEncodeValue:(NSString *)str
{
  NSString *result = (NSString *) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)str, NULL, CFSTR(":/?#[]@!$&’()*+,;="), kCFStringEncodingUTF8);
  return [result autorelease];
}

@end
