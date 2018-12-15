//
//  MidiKeyMap.h
//  MidiKeys
//
//  Created by Chris Reed on Sat Oct 26 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Maximum number of key codes.
#define MAX_KEY_CODES (256)

//! Maximum number of MIDI notes.
#define MAX_MIDI_NOTES (128)

/*!
 * @brief Maps key codes to MIDI notes.
 */
@interface MidiKeyMap : NSObject
{
	id mDefinition;
	NSArray *mRanges;
	int mKeyCodeToNoteMap[MAX_KEY_CODES];
	int mNoteToKeyCodeMap[MAX_MIDI_NOTES];
	BOOL mHotKeysAreRegistered;
	NSMutableDictionary *mRegisteredHotKeys;
}

// Definition is currently an array of range dictionaries
- initWithDefinition:(id)def;

//! Returns -1 if the key was not found
- (int)midiNoteForKeyCode:(int)keycode;
- (int)midiNoteForHotKeyWithIdentifier:(uintptr_t)identifier;

//! @brief Returns the key code for a MIDI note.
- (int)keyCodeForMidiNote:(int)note;

//! @brief Returns the Unicode character for a MIDI note value.
- (NSString *)characterForMidiNote:(int)midiNote;

//! @brief Registers all keys handled by the key map as system hot keys.
- (void)registerHotKeysWithModifiers:(int)modifiers;
- (void)unregisterHotKeys;

@end
