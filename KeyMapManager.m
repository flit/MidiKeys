//
//  KeyMapManager.mm
//  MidiKeys
//
//  Created by Chris Reed on Sat Oct 26 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import "KeyMapManager.h"
#import "MidiKeyMap.h"


@implementation KeyMapManager

static KeyMapManager *sharedInstance = nil;

+ sharedInstance
{
	return sharedInstance ? sharedInstance : [[self alloc] init];
}

// always return the shared instance
- init
{
	if (sharedInstance)
	{
		[self release];
	}
	else if (self = [super init])
	{
		sharedInstance = self;
	}
	return sharedInstance;
}

// disallow disposing of the shared instance
- (void)dealloc
{
	if (self == sharedInstance)
		return;
	[mPlist release];
	[super dealloc];
}

// read the plist file and find all the keymaps
- (void)awakeFromNib
{
	// read the map from the the definition file
	NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"KeyMaps" ofType:@"plist"];
	mPlist = [[NSDictionary dictionaryWithContentsOfFile:plistPath] retain];
	if (!mPlist)
	{
		mPlist = [[NSDictionary dictionary] retain];
	}
}

// return the names sorted alphabetically
- (NSArray *)allKeyMapNames
{
	return [[mPlist allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (NSArray *)allKeyMapLocalisedNames
{
	NSArray *names = [self allKeyMapNames];
	id iterator;
	NSMutableArray *localisedNames = [NSMutableArray array];
	for (iterator in names)
	{
		[localisedNames addObject:[self localisedNameForKeyMapWithName:iterator]];
	}
	return [localisedNames sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (id)keyMapDefinitionWithName:(NSString *)name
{
	if (!name)
		return nil;
	return [mPlist objectForKey:name];
}

- (MidiKeyMap *)keyMapWithName:(NSString *)name
{
	if (!name)
		return nil;
	NSArray *def = [self keyMapDefinitionWithName:name];
	if (!def)
		return nil;
	return [[[MidiKeyMap alloc] initWithDefinition:def] autorelease];
}

- (NSString *)localisedNameForKeyMapWithName:(NSString *)name
{
	return NSLocalizedStringFromTable(name, @"KeyMapNames", nil);
}

- (NSString *)nameForKeyMapWithLocalisedName:(NSString *)localName
{
	NSArray *names = [self allKeyMapNames];
	id iterator;
	for (iterator in names)
	{
		if ([localName isEqualToString:[self localisedNameForKeyMapWithName:iterator]])
			return iterator;
	}
	// not found
	return nil;
}

@end
