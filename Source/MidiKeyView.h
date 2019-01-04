//
//  MidiKeyView.h
//  MidiKeys
//
//  Created by Chris Reed on Tue Oct 15 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import <AppKit/AppKit.h>

@protocol MidiKeyViewDelegate;

/*!
 * @brief View class that displays a musical keyboard.
 */
@interface MidiKeyView : NSView

@property (assign, nullable, weak) id<MidiKeyViewDelegate> delegate;

@property (retain, nonnull) NSColor * highlightColour;
@property int octaveOffset;
@property BOOL showKeycaps;
@property BOOL showCNotes;

- (double)maxKeyboardWidthForSize:(NSSize)proposedSize;

- (void)turnMidiNoteOn:(int)note;
- (void)turnMidiNoteOff:(int)note;
- (void)turnAllNotesOff;

@end

@protocol MidiKeyViewDelegate

- (void)processMidiKeyWithCode:(int)keycode turningOn:(BOOL)isTurningOn;
- (void)processMidiKeyClickWithNote:(int)note turningOn:(BOOL)isTurningOn;
- (void)processMidiChannelAftertouch:(int)pressure;

- (NSString * _Nonnull)characterForMidiNote:(int)note;

@end


