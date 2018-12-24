//
//  MidiKeyView.h
//  MidiKeys
//
//  Created by Chris Reed on Tue Oct 15 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import <AppKit/AppKit.h>

//! Maximum number of keys to show.
#define KEY_COUNT 120

/*!
 * @brief Information about a key on a musical keyboard.
 */
typedef struct _key_info {
	int theOctave;
	int octaveFirstNote;
	int noteInOctave;
    int numWhiteKeys;
    int numBlackKeys;
	BOOL isBlackKey;
    BOOL rightIsInset;
    BOOL leftIsInset;
} key_info_t;

@protocol MidiKeyViewDelegate;

/*!
 * @brief View class that displays a musical keyboard.
 */
@interface MidiKeyView : NSView
{
	id<MidiKeyViewDelegate> mDelegate;
	uint8_t midiKeyStates[KEY_COUNT];
	BOOL inited;
    double _scale;
	int numOctaves;
	int leftOctaves;
	int firstMidiNote;
	int lastMidiNote;
	NSColor *mHighlightColour;
	int mClickedNote;
	NSImage *mOctaveDownImage;
	NSImage *mOctaveUpImage;
	int mOctaveOffset;
	BOOL _showKeycaps;
    BOOL _showCNotes;
    key_info_t _keyInfo; //!< Shared key info struct.
    NSBezierPath * _lastKeyPath;
    int _lastKeyPathNote;
}

@property (assign, nullable, weak) id<MidiKeyViewDelegate> delegate;

@property (retain, nonnull) NSColor * highlightColour;
@property int octaveOffset;
@property BOOL showKeycaps;
@property BOOL showCNotes;

- (void)turnMidiNoteOn:(int)note;
- (void)turnMidiNoteOff:(int)note;
- (void)turnAllNotesOff;

@end

@protocol MidiKeyViewDelegate

- (void)processMidiKeyWithCode:(int)keycode turningOn:(BOOL)isTurningOn;
- (void)processMidiKeyClickWithNote:(int)note turningOn:(BOOL)isTurningOn;

- (NSString * _Nonnull)characterForMidiNote:(int)note;

@end


