// PAKEPartyTest.m

#import "JPAKEPartyTest.h"
#import "JPAKEParty.h"

@implementation JPAKEPartyTest

- (void) runPasswordExchangeWithLeftParty: (JPAKEParty*) a rightParty: (JPAKEParty*) b keysShouldBeDifferent: (BOOL) keysShouldBeDifferent
{
	NSDictionary* a1 = [a generateMessageOne];
	STAssertNotNil(a1, @"a1 should not be nil");
	STAssertNotNil([a1 objectForKey: @"gx1"], @"gx1 is missing in a1");
	STAssertNotNil([a1 objectForKey: @"gx2"], @"gx2 is missing in a1");
	STAssertNotNil([[a1 objectForKey: @"zkp_x1"] objectForKey: @"gr"], @"zkp_x1.gr is missing in a1");
	STAssertNotNil([[a1 objectForKey: @"zkp_x1"] objectForKey: @"b"], @"zkp_x1.b is missing in a1");
	STAssertNotNil([[a1 objectForKey: @"zkp_x1"] objectForKey: @"id"], @"zkp_x1.id is missing in a1");
	STAssertNotNil([a1 objectForKey: @"zkp_x1"], @"zkp_x1 is missing in a1");
	STAssertNotNil([a1 objectForKey: @"zkp_x2"], @"zkp_x2 is missing in a1");
	STAssertNotNil([[a1 objectForKey: @"zkp_x2"] objectForKey: @"gr"], @"zkp_x2.gr is missing in a1");
	STAssertNotNil([[a1 objectForKey: @"zkp_x2"] objectForKey: @"b"], @"zkp_x2.b is missing in a1");
	STAssertNotNil([[a1 objectForKey: @"zkp_x2"] objectForKey: @"id"], @"zkp_x2.id is missing in a1");

	NSDictionary* b1 = [b generateMessageOne];
	STAssertNotNil(b1, @"b1 should not be nil");
	STAssertNotNil([b1 objectForKey: @"gx1"], @"gx1 is missing in b1");
	STAssertNotNil([b1 objectForKey: @"gx2"], @"gx2 is missing in b1");
	STAssertNotNil([[b1 objectForKey: @"zkp_x1"] objectForKey: @"gr"], @"zkp_x1.gr is missing in b1");
	STAssertNotNil([[b1 objectForKey: @"zkp_x1"] objectForKey: @"b"], @"zkp_x1.b is missing in b1");
	STAssertNotNil([[b1 objectForKey: @"zkp_x1"] objectForKey: @"id"], @"zkp_x1.id is missing in b1");
	STAssertNotNil([b1 objectForKey: @"zkp_x1"], @"zkp_x1 is missing in b1");
	STAssertNotNil([b1 objectForKey: @"zkp_x2"], @"zkp_x2 is missing in b1");
	STAssertNotNil([[b1 objectForKey: @"zkp_x2"] objectForKey: @"gr"], @"zkp_x2.gr is missing in b1");
	STAssertNotNil([[b1 objectForKey: @"zkp_x2"] objectForKey: @"b"], @"zkp_x2.b is missing in b1");
	STAssertNotNil([[b1 objectForKey: @"zkp_x2"] objectForKey: @"id"], @"zkp_x2.id is missing in b1");

	NSDictionary* a2 = [a generateMessageTwoFromMessageOne: b1];
	STAssertNotNil(a2, @"a2 should not be nil");
	STAssertNotNil([a2 objectForKey: @"A"], @"A is missing in a2");
	STAssertNotNil([a2 objectForKey: @"zkp_A"], @"zkp_A is missing in a2");

	NSDictionary* b2 = [b generateMessageTwoFromMessageOne: a1];
	STAssertNotNil(b2, @"b2 should not be nil");
	STAssertNotNil([b2 objectForKey: @"A"], @"A is missing in b2");
	STAssertNotNil([b2 objectForKey: @"zkp_A"], @"zkp_A is missing in b2");
	
	NSData* ak = [a generateKeyFromMessageTwo: b2];
	STAssertNotNil(ak, @"ak should not be nil");
	STAssertFalse([ak length] == 0, @"ak length is zero");

	NSData* bk = [b generateKeyFromMessageTwo: a2];
	STAssertNotNil(bk, @"ak should not be nil");
	STAssertFalse([bk length] == 0, @"bk length is zero");
	
	if (keysShouldBeDifferent) {
		STAssertFalse([ak isEqualToData: bk], @"keys should be different");
	} else {
		STAssertTrue([ak isEqualToData: bk], @"keys should be the same");
	}
}

- (void) testPasswordExchange1024
{
	JPAKEParty* a = [JPAKEParty partyWithPassword: @"abcd1234" modulusLength: 1024 signerIdentity: @"Alice" peerIdentity: @"Bob"];
	STAssertNotNil(a, @"a should not be nil");
	
	JPAKEParty* b = [JPAKEParty partyWithPassword: @"abcd1234" modulusLength: 1024 signerIdentity: @"Bob" peerIdentity: @"Alice"];
	STAssertNotNil(a, @"b should not be nil");
	
	[self runPasswordExchangeWithLeftParty: a rightParty: b keysShouldBeDifferent: NO];
}

- (void) testPasswordExchangeWithWrongPasswords1024
{
	JPAKEParty* a = [JPAKEParty partyWithPassword: @"all you need is cheese" modulusLength: 1024 signerIdentity: @"Alice" peerIdentity: @"Bob"];
	STAssertNotNil(a, @"a should not be nil");
	
	JPAKEParty* b = [JPAKEParty partyWithPassword: @"all you need is bacon" modulusLength: 1024 signerIdentity: @"Bob" peerIdentity: @"Alice"];
	STAssertNotNil(a, @"b should not be nil");
	
	[self runPasswordExchangeWithLeftParty: a rightParty: b keysShouldBeDifferent: YES];
}

- (void) testPasswordExchange2048
{
	JPAKEParty* a = [JPAKEParty partyWithPassword: @"all you need is cheese" modulusLength: 2048 signerIdentity: @"Alice" peerIdentity: @"Bob"];
	STAssertNotNil(a, @"a should not be nil");
	
	JPAKEParty* b = [JPAKEParty partyWithPassword: @"all you need is cheese" modulusLength: 2048 signerIdentity: @"Bob" peerIdentity: @"Alice"];
	STAssertNotNil(a, @"b should not be nil");
	
	[self runPasswordExchangeWithLeftParty: a rightParty: b keysShouldBeDifferent: NO];
}

- (void) testPasswordExchangeWithWrongPasswords2048
{
	JPAKEParty* a = [JPAKEParty partyWithPassword: @"all you need is cheese" modulusLength: 2048 signerIdentity: @"Alice" peerIdentity: @"Bob"];
	STAssertNotNil(a, @"a should not be nil");
	
	JPAKEParty* b = [JPAKEParty partyWithPassword: @"all you need is bacon" modulusLength: 2048 signerIdentity: @"Bob" peerIdentity: @"Alice"];
	STAssertNotNil(a, @"b should not be nil");
	
	[self runPasswordExchangeWithLeftParty: a rightParty: b keysShouldBeDifferent: YES];
}

- (void) testPasswordExchange3072
{
	JPAKEParty* a = [JPAKEParty partyWithPassword: @"all you need is cheese" modulusLength: 3072 signerIdentity: @"Alice" peerIdentity: @"Bob"];
	STAssertNotNil(a, @"a should not be nil");
	
	JPAKEParty* b = [JPAKEParty partyWithPassword: @"all you need is cheese" modulusLength: 3072 signerIdentity: @"Bob" peerIdentity: @"Alice"];
	STAssertNotNil(a, @"b should not be nil");
	
	[self runPasswordExchangeWithLeftParty: a rightParty: b keysShouldBeDifferent: NO];
}

- (void) testPasswordExchangeWithWrongPasswords3072
{
	JPAKEParty* a = [JPAKEParty partyWithPassword: @"all you need is cheese" modulusLength: 3072 signerIdentity: @"Alice" peerIdentity: @"Bob"];
	STAssertNotNil(a, @"a should not be nil");
	
	JPAKEParty* b = [JPAKEParty partyWithPassword: @"all you need is bacon" modulusLength: 3072 signerIdentity: @"Bob" peerIdentity: @"Alice"];
	STAssertNotNil(a, @"b should not be nil");
	
	[self runPasswordExchangeWithLeftParty: a rightParty: b keysShouldBeDifferent: YES];
}

- (void) testPasswordHashing1024
{
	JPAKEParty* party = [JPAKEParty partyWithPassword: @"Cheese" modulusLength: 1024 signerIdentity: @"Alice" peerIdentity: @"Bob"];
	STAssertNotNil(party, @"party is nil");
	STAssertEqualObjects(party.hashedPassword, @"74115656807269", @"hashed password is incorrect");
}

- (void) testPasswordHashing2048
{
	JPAKEParty* party = [JPAKEParty partyWithPassword: @"Cheese" modulusLength: 2048 signerIdentity: @"Alice" peerIdentity: @"Bob"];
	STAssertNotNil(party, @"party is nil");
	STAssertEqualObjects(party.hashedPassword, @"74115656807269", @"hashed password is incorrect");
}

- (void) testPasswordHashing3072
{
	JPAKEParty* party = [JPAKEParty partyWithPassword: @"Cheese" modulusLength: 3072 signerIdentity: @"Alice" peerIdentity: @"Bob"];
	STAssertNotNil(party, @"party is nil");
	STAssertEqualObjects(party.hashedPassword, @"74115656807269", @"hashed password is incorrect");
}

@end
