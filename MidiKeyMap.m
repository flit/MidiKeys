//
//  MidiKeyMap.mm
//  MidiKeys
//
//  Created by Chris Reed on Sat Oct 26 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import "MidiKeyMap.h"
#import <Carbon/Carbon.h>

@interface MidiKeyMap (InternalMethods)

- (void)constructMaps;

@end

@implementation MidiKeyMap

- initWithDefinition:(id)def
{
	self = [super init];
	if (self)
	{
		mDefinition = [def retain];
		mRanges = [[mDefinition objectForKey:@"Ranges"] retain];
		[self constructMaps];
	}
	return self;
}

- (void)dealloc
{
	// can't leave hotkeys sitting around without a way to remove them
	if (mHotKeysAreRegistered)
	{
		[self unregisterHotKeys];
	}
	
	[mRegisteredHotKeys release];
	[mRanges release];
	[mDefinition release];
	[super dealloc];
}

- (void)constructMaps
{
	for (int i=0; i < MAX_KEY_CODES; ++i)
	{
		mKeyCodeToNoteMap[i] = -1;
	}
	
	for (int i=0; i < MAX_MIDI_NOTES; ++i)
	{
		mNoteToKeyCodeMap[i] = -1;
	}
	
	id range;
	for (range in mRanges)
	{
		@try
		{
			NSArray *rangeKeys = [range objectForKey:@"KeyCodes"];
			int rangeStartNote = [[range objectForKey:@"FirstMidiNote"] intValue];
			NSUInteger numKeyCodes = [rangeKeys count];
			for (NSUInteger i=0; i < numKeyCodes; ++i)
			{
				id thisKey = [rangeKeys objectAtIndex:i];
				int keycode = [thisKey intValue];
				int note = rangeStartNote + i;
				mKeyCodeToNoteMap[keycode] = note;
				mNoteToKeyCodeMap[note] = keycode;
			}
		}
		@catch (NSException * e)
		{
			// a key was missing from the range dictionary (or something)
			NSLog(@"invalid range definition");
			// move on to the next range
			// @todo remove the offending range from the key map
		}
	}
}

//! @return The MIDI note number that corresponds to the given key code.
//! @retval -1 There is no mapping for the given key code.
- (int)midiNoteForKeyCode:(int)keycode
{
	if (keycode < 0 || keycode >= MAX_KEY_CODES)
	{
		return -1;
	}
	else
	{
		return mKeyCodeToNoteMap[keycode];
	}
}

// look up the hot key in our dictionary
- (int)midiNoteForHotKeyWithIdentifier:(UInt32)identifier
{
	// return -1 if there are no hotkeys installed
	if (!mHotKeysAreRegistered || [mRegisteredHotKeys count]==0)
		return -1;
	
	int note = [[mRegisteredHotKeys objectForKey:[NSValue valueWithPointer:(void *)identifier]] intValue];
	return note;
}

- (int)keyCodeForMidiNote:(int)note
{
	if (note < 0 || note >= MAX_MIDI_NOTES)
	{
		return -1;
	}
	else
	{
		return mNoteToKeyCodeMap[note];
	}
}

//! @return An NSString containing the character value. Will be an empty string if
//!			the key map doesn't have an entry for the given note value.
- (NSString *)characterForMidiNote:(int)midiNote
{
	int keyCode = [self keyCodeForMidiNote:midiNote];
	
	NSString *result = nil;
	TISInputSourceRef t = TISCopyCurrentKeyboardLayoutInputSource();
	if (t)
	{
		void* v = TISGetInputSourceProperty(t, kTISPropertyUnicodeKeyLayoutData);
		
		if (v)
		{
			CFDataRef d = (CFDataRef)v;
			
			UCKeyboardLayout *uchrData = (UCKeyboardLayout*) CFDataGetBytePtr(d);
			
			// Get Unicode characters for this keycode.
			UInt32 deadKeyState = 0;
			UniChar keyChars[16] = {0};
			UniCharCount keyCharsCount = 0;
			OSStatus status = UCKeyTranslate(uchrData, keyCode, kUCKeyActionDisplay, 0, LMGetKbdType(), kUCKeyTranslateNoDeadKeysMask, &deadKeyState, sizeof(keyChars), &keyCharsCount, keyChars);
			if (status)
			{
				return nil;
			}
			
			// Return NSString with the Unicode characters.
			result = [NSString stringWithCharacters:(const unichar *)&keyChars length:keyCharsCount];
		}
		
		CFRelease(t);
	}
	return result;

	#if oldCode
	
	// Get current key layout selected in Keyboard menu.
	KeyboardLayoutRef layout;
//	TISInputSourceRef inputSource;
	OSStatus status;
//	inputSource = TISCopyCurrentKeyboardInputSource();
	
	status = KLGetCurrentKeyboardLayout(&layout);
	if (status)
	{
		return nil;
	}
	
	// Get the type of available layout data.
	KeyboardLayoutKind layoutKind;
	status = KLGetKeyboardLayoutProperty(layout, kKLKind, (const void **)&layoutKind);
	if (status)
	{
		return nil;
	}
	
	UInt32 deadKeyState = 0;
	switch (layoutKind)
	{
		// Use the Unicode layout if available.
		case kKLKCHRuchrKind:
		case kKLuchrKind:
		{
			// Get the Unicode 'uchr' key layout data.
			UCKeyboardLayout * uchrData;
			status = KLGetKeyboardLayoutProperty(layout, kKLuchrData, (const void **)&uchrData);
			if (status)
			{
				return nil;
			}
			
			// Get Unicode characters for this keycode.
			UniChar keyChars[16];
			UniCharCount keyCharsCount;
			status = UCKeyTranslate(uchrData, keyCode, kUCKeyActionDisplay, 0, LMGetKbdType(), kUCKeyTranslateNoDeadKeysMask, &deadKeyState, sizeof(keyChars), &keyCharsCount, keyChars);
			if (status)
			{
				return nil;
			}
			
			// Return NSString with the Unicode characters.
			return [NSString stringWithCharacters:(const unichar *)&keyChars length:keyCharsCount];
		}
		
		// Otherwise fall back to the old format.
		case kKLKCHRKind:
		{
			// Get the 'KCHR' resource data.
			void * kchrData;
			status = KLGetKeyboardLayoutProperty(layout, kKLKCHRData, (const void **)&kchrData);
			if (status)
			{
				return nil;
			}
			
			// Put a 1 in bit 7 of the keycode param to indicate a down stroke.
			UInt32 resultChars = KeyTranslate(kchrData, (keyCode & 0x3f) | (1 << 7), &deadKeyState);
			if (status)
			{
				return nil;
			}
			
			// Return the key char as a string.
			char keyCharString[2] = {0};
			keyCharString[0] = resultChars & 0xff;
			return [NSString stringWithUTF8String:keyCharString];
		}
	}
	#endif
	return nil;
}

- (void)registerHotKeysWithModifiers:(int)modifiers;
{
	// must have a modifier set to install hotkeys
	if (modifiers == 0)
    {
		return;
    }
	
	OSStatus err;
	EventHotKeyID hotKeyID = { 0, 0 };
	EventHotKeyRef hotKeyRef;
	
	[mRegisteredHotKeys release];
	mRegisteredHotKeys = [[NSMutableDictionary dictionary] retain];
	
	id range;
	for (range in mRanges)
	{
		@try
		{
			NSArray *rangeKeys = [range objectForKey:@"KeyCodes"];
			int rangeStartNote = [[range objectForKey:@"FirstMidiNote"] intValue];
			NSUInteger numKeyCodes = [rangeKeys count];
			for (NSUInteger i=0; i < numKeyCodes; ++i)
			{
				id thisKey = [rangeKeys objectAtIndex:i];
				int midiNote = rangeStartNote + (int) i;
				err = RegisterEventHotKey([thisKey intValue], modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef);
				if (err)
				{
					NSLog(@"error %ld installing hotkey (keycode = %ld)", (long) err, (long) [thisKey intValue]);
					continue;
				}
				mHotKeysAreRegistered = YES;
				
				// save the hotKeyRef as the key in a dictionary, with its keycode as the value
				[mRegisteredHotKeys setObject:[NSNumber numberWithInt:midiNote] forKey:[NSValue valueWithPointer:hotKeyRef]];
			}
		}
		@catch (NSException * e)
		{
			// a key was missing from the range dictionary (or something)
			NSLog(@"invalid range definition");
			// move on to the next range
			// XXX remove the offending range from the key map
		}
	}
}

- (void)unregisterHotKeys
{
	if (!mHotKeysAreRegistered || [mRegisteredHotKeys count]==0)
    {
		return;
    }
	
	id iterator;
	for (iterator in mRegisteredHotKeys)
	{
		EventHotKeyRef hotKeyRef = (EventHotKeyRef)[iterator pointerValue];
		OSStatus err = UnregisterEventHotKey(hotKeyRef);
		if (err)
        {
			NSLog(@"err %ld unregistering hot key %p", (long) err, hotKeyRef);
        }
	}
	
	// clear hot keys dictionary
	[mRegisteredHotKeys removeAllObjects];
	
	mHotKeysAreRegistered = NO;
}

@end

