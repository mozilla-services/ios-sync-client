#import <SenTestingKit/SenTestingKit.h>
#import <UIKit/UIKit.h>

@interface KeyDerivationTest : SenTestCase {

}

- (void) testSimplifiedCryptoKeyDerivation;
- (void) testDeriveKeyFromPassphraseAndSyncID;

@end
