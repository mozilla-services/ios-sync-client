/***** BEGIN LICENSE BLOCK *****
 Version: MPL 1.1/GPL 2.0/LGPL 2.1
 
 The contents of this file are subject to the Mozilla Public License Version 
 1.1 (the "License"); you may not use this file except in compliance with 
 the License. You may obtain a copy of the License at 
 http://www.mozilla.org/MPL/
 
 Software distributed under the License is distributed on an "AS IS" basis,
 WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 for the specific language governing rights and limitations under the
 License.
 
 The Original Code is weave-iphone.
 
 The Initial Developer of the Original Code is Mozilla Labs.
 Portions created by the Initial Developer are Copyright (C) 2009
 the Initial Developer. All Rights Reserved.
 
 Contributor(s):
 Anant Narayanan <anant@kix.in>
 Dan Walkowski <dwalkowski@mozilla.com>
 Stefan Arentz <stefan@arentz.ca>
 
 Alternatively, the contents of this file may be used under the terms of either
 the GNU General Public License Version 2 or later (the "GPL"), or the GNU
 Lesser General Public License Version 2.1 or later (the "LGPL"), in which case
 the provisions of the GPL or the LGPL are applicable instead of those above.
 If you wish to allow use of your version of this file only under the terms of
 either the GPL or the LGPL, and not to allow others to use your version of
 this file under the terms of the MPL, indicate your decision by deleting the
 provisions above and replace them with the notice and other provisions
 required by the GPL or the LGPL. If you do not delete the provisions above, a
 recipient may use your version of this file under the terms of any one of the
 MPL, the GPL or the LGPL.

 ***** END LICENSE BLOCK *****/

#include <unistd.h>

#import <UIKit/UIKit.h>

int main(int argc, char *argv[])
{
	int retVal = 0;

    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	{
#if FXHOME_DEBUG_LOG
		// Redirect stdout to a file in ~/Documents
		
		NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
		[dateFormatter setDateFormat: @"yyyyMMd-Hms"];
		
		NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		if (paths && [paths count] != 0) {
			NSString* path = [[paths objectAtIndex: 0] stringByAppendingPathComponent:
				[NSString stringWithFormat: @"/FirefoxHome-%@.txt", [dateFormatter stringFromDate: [NSDate date]]]];
			if ([[NSFileManager defaultManager] createFileAtPath: path contents: [NSData data] attributes: nil] == NO) {
				NSLog(@"Could create %@: %s", path, strerror(errno));
			} else {
				NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath: path];
				if (fileHandle != nil) {
					if (dup2([fileHandle fileDescriptor], STDERR_FILENO) == -1) {
						NSLog(@"Unable to redirect stderr to %@: %s", path, strerror(errno));
					} else {
						NSLog(@"This is the start of the log file for SyncClient");
					}
				}
			}
		}
#endif

		// Start the application
	
		retVal = UIApplicationMain(argc, argv, nil, nil);
	}
    [pool release];
	
    return retVal;
}
