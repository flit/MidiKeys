//
//  KeyMapManager.h
//  MidiKeys
//
//  Created by Chris Reed on Sat Oct 26 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MidiKeyMap;

@interface KeyMapManager : NSObject
{
	NSDictionary *mPlist;
}

+ sharedInstance;
- init;

- (NSArray *)allKeyMapNames;
- (NSArray *)allKeyMapLocalisedNames;
- (id)keyMapDefinitionWithName:(NSString *)name;
- (MidiKeyMap *)keyMapWithName:(NSString *)name;

- (NSString *)localisedNameForKeyMapWithName:(NSString *)name;
- (NSString *)nameForKeyMapWithLocalisedName:(NSString *)localName;

@end
