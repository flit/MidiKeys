//
//  MidiKeyView.m
//  MidiKeys
//
//  Created by Chris Reed on Tue Oct 15 2002.
//  Copyright (c) 2002,2018 Chris Reed. All rights reserved.
//

#import "MidiKeyView.h"
#import "AppController.h"
#import "Preferences.h"

//! Maximum number of keys to show.
#define MAX_KEY_COUNT 120

// image file name
#define kOctaveDownImageFile @"OctaveDown.png"
#define kOctaveUpImageFile @"OctaveUp.png"

// view sizes for computations
#define kNominalViewHeight (57.0)
#define kNominalViewWidth (371.0)

// key sizes
#define kWhiteKeyHeight (kNominalViewHeight)
#define kWhiteKeyWidth (12.0)
#define kBlackKeyInset (4.0)
#define kBlackKeyWidth (8.0)
#define kBlackKeyHeight (32.0)

#define kWhiteKeysPerOctave (7)

/*!
 * @brief Information about a key on a musical keyboard.
 */
typedef struct _key_info {
    int theOctave;
    int octaveFirstNote;
    int noteInOctave;
    int precedingWhiteKeysInOctave;
    int precedingBlackKeysInOctave;
    BOOL isBlackKey;
    BOOL rightIsInset;
    BOOL leftIsInset;
} key_info_t;

/*!
 * @brief Information about sizes of the keyboard and keys.
 */
typedef struct _keyboard_size_info {
    double scale;
    int numWhiteKeys;
    int numOctaves;
    int leftOctaves;
    int firstMidiNote;
    int lastMidiNote;
} keyboard_size_info_t;

//! Table to map note number within octave to details about that key.
static const key_info_t kNoteInOctaveInfo[] = {
        [0] = { // C
            .isBlackKey = NO,
            .rightIsInset = YES
        },
        [1] = { // C#
            .isBlackKey = YES,
            .precedingWhiteKeysInOctave = 1
        },
        [2] = { // D
            .isBlackKey = NO,
            .precedingWhiteKeysInOctave = 1,
            .precedingBlackKeysInOctave = 1,
            .rightIsInset = YES,
            .leftIsInset = YES,
        },
        [3] = { // D#
            .isBlackKey = YES,
            .precedingWhiteKeysInOctave = 2,
            .precedingBlackKeysInOctave = 1,
        },
        [4] = {// E
            .isBlackKey = NO,
            .precedingWhiteKeysInOctave = 2,
            .precedingBlackKeysInOctave = 2,
            .leftIsInset = YES,
        },
        [5] = { // F
            .isBlackKey = NO,
            .precedingWhiteKeysInOctave = 3,
            .precedingBlackKeysInOctave = 2,
            .rightIsInset = YES,
        },
        [6] = { // F#
            .isBlackKey = YES,
            .precedingWhiteKeysInOctave = 4,
            .precedingBlackKeysInOctave = 2,
        },
        [7] = { // G
            .isBlackKey = NO,
            .precedingWhiteKeysInOctave = 4,
            .precedingBlackKeysInOctave = 3,
            .rightIsInset = YES,
            .leftIsInset = YES,
        },
        [8] = { // G#
            .isBlackKey = YES,
            .precedingWhiteKeysInOctave = 5,
            .precedingBlackKeysInOctave = 3,
        },
        [9] = { // A
            .isBlackKey = NO,
            .precedingWhiteKeysInOctave = 5,
            .precedingBlackKeysInOctave = 4,
            .rightIsInset = YES,
            .leftIsInset = YES,
        },
        [10] = { // A#
            .isBlackKey = YES,
            .precedingWhiteKeysInOctave = 6,
            .precedingBlackKeysInOctave = 4,
        },
        [11] = { // B
            .isBlackKey = NO,
            .precedingWhiteKeysInOctave = 6,
            .precedingBlackKeysInOctave = 5,
            .leftIsInset = YES,
        },
};

@interface MidiKeyView ()

- (const key_info_t * _Nonnull)getKeyInfoForMidiNote:(int)note;
- (const key_info_t * _Nonnull)getKeyInfoForMidiNote:(int)note usingSizeInfo:(keyboard_size_info_t * _Nonnull)sizing;
- (void)computeSizeInfo:(keyboard_size_info_t * _Nonnull)info forSize:(NSSize)frameSize;
- (void)computeKeyValues;
- (NSBezierPath *)bezierPathForMidiNote:(int)note;
- (NSBezierPath *)bezierPathForMidiNote:(int)note withInset:(double)inset;
- (NSBezierPath *)bezierPathForMidiNote:(int)note withInset:(double)inset usingSizeInfo:(keyboard_size_info_t * _Nonnull)sizing;
- (void)drawKeyForNote:(int)note;
- (void)drawKeyCapForNote:(int)note;
- (void)highlightMidiKey:(int)note;
- (int)midiNoteForMouse:(NSPoint)location;
- (void)drawOctaveOffsetIndicator;
- (BOOL)drawDark;
- (void)forceDisplay;

@end

@implementation MidiKeyView
{
    id<MidiKeyViewDelegate> mDelegate;
    uint8_t midiKeyStates[MAX_KEY_COUNT];
    BOOL inited;
    keyboard_size_info_t _sizing;
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
    int _lastAftertouchPressure;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
		mOctaveUpImage = [[NSImage imageNamed:kOctaveUpImageFile] retain];
		mOctaveDownImage = [[NSImage imageNamed:kOctaveDownImageFile] retain];
		mHighlightColour = [NSColor greenColor];
        mClickedNote = -1;
        _lastKeyPathNote = -1;
        _lastAftertouchPressure = -1;

        // Set the view to respond to pressure with a large dynamic range and
        // with deep click turned off.
        self.pressureConfiguration = [[[NSPressureConfiguration alloc]
            initWithPressureBehavior:NSPressureBehaviorPrimaryGeneric] autorelease];
    }
    return self;
}

- (void)dealloc
{
	if (mClickedNote != -1)
	{
		// i don't know if this can happen, but no reason to take the chance
		[mDelegate processMidiKeyClickWithNote:mClickedNote turningOn:NO];
	}
	[mHighlightColour release];
	[mOctaveDownImage release];
	[mOctaveUpImage release];
	[super dealloc];
}

- (void)setDelegate:(id)delegate
{
	mDelegate = delegate;
}

- delegate
{
	return mDelegate;
}

- (void)computeSizeInfo:(keyboard_size_info_t * _Nonnull)info forSize:(NSSize)frameSize
{
    info->scale = frameSize.height / kNominalViewHeight;

    double scaledWhiteKeyWidth = round(kWhiteKeyWidth * info->scale);
    info->numWhiteKeys = round(frameSize.width / scaledWhiteKeyWidth);
    info->numOctaves = MIN(10, frameSize.width / ((scaledWhiteKeyWidth * kWhiteKeysPerOctave) - 1.0));

	// put middle c=60 in approx. center octave
	info->leftOctaves = info->numOctaves/2;

	info->firstMidiNote = MAX(0, 60 - (info->leftOctaves * 12));

    info->lastMidiNote = MIN(MAX_KEY_COUNT, info->firstMidiNote + (info->numOctaves + 1) * 12);
}

- (void)computeKeyValues
{
    [self computeSizeInfo:&_sizing forSize:self.bounds.size];

    _lastKeyPathNote = -1;
}

- (const key_info_t * _Nonnull)getKeyInfoForMidiNote:(int)note
{
    return [self getKeyInfoForMidiNote:note usingSizeInfo:&_sizing];
}

- (const key_info_t * _Nonnull)getKeyInfoForMidiNote:(int)note usingSizeInfo:(keyboard_size_info_t * _Nonnull)sizing
{
	int theNote = note;
	int theOctave = (theNote - sizing->firstMidiNote) / 12;
	int octaveFirstNote = sizing->firstMidiNote + theOctave * 12;
	unsigned noteInOctave = theNote - octaveFirstNote;

    assert(noteInOctave < (sizeof(kNoteInOctaveInfo) / sizeof(key_info_t)));
    const key_info_t * octaveNoteInfo = &kNoteInOctaveInfo[noteInOctave];

    // Copy const key info, then set a few other fields.
    _keyInfo = *octaveNoteInfo;
	_keyInfo.theOctave = theOctave;
	_keyInfo.octaveFirstNote = octaveFirstNote;
	_keyInfo.noteInOctave = noteInOctave;

	return &_keyInfo;
}

- (NSBezierPath *)bezierPathForMidiNote:(int)note
{
    return [self bezierPathForMidiNote:note withInset:0.0];
}

- (NSBezierPath *)bezierPathForMidiNote:(int)note withInset:(double)inset
{
    return [self bezierPathForMidiNote:note withInset:inset usingSizeInfo:&_sizing];
}

- (NSBezierPath *)bezierPathForMidiNote:(int)note withInset:(double)inset usingSizeInfo:(keyboard_size_info_t * _Nonnull)sizing
{
//    if (_lastKeyPathNote == note && _lastKeyPath)
//    {
//        return _lastKeyPath;
//    }
//    else if (_lastKeyPath)
//    {
//        [_lastKeyPath release];
//    }

    double scaledKeyHeight = kWhiteKeyHeight * sizing->scale;
    double scaledWhiteKeyWidth = kWhiteKeyWidth * sizing->scale;
    double scaledBlackKeyWidth = kBlackKeyWidth * sizing->scale;
    double scaledBlackKeyInset = kBlackKeyInset * sizing->scale;
    double scaledBlackKeyHeight = kBlackKeyHeight * sizing->scale;

	// get key info for the note
	const key_info_t * _Nonnull info = [self getKeyInfoForMidiNote:note usingSizeInfo:sizing];

	int theOctave = info->theOctave;
    double octaveLeft = (double)theOctave * (scaledWhiteKeyWidth * kWhiteKeysPerOctave);// - 1.0);
	int numWhiteKeys = info->precedingWhiteKeysInOctave;
	BOOL isBlackKey = info->isBlackKey;
	BOOL leftIsInset = info->leftIsInset;
	BOOL rightIsInset = info->rightIsInset; // black key insets on white keys

	NSRect keyRect;

	if (isBlackKey)
	{
		keyRect.origin.x = octaveLeft + numWhiteKeys * scaledWhiteKeyWidth - scaledBlackKeyInset + inset;
		keyRect.origin.y = scaledKeyHeight - scaledBlackKeyHeight + inset;
		keyRect.size.width = scaledBlackKeyWidth - (inset * 2.0);
		keyRect.size.height = scaledBlackKeyHeight;

		return [NSBezierPath bezierPathWithRect:keyRect];
	}

	// lower half of white key
	double x, y, w, h;
	x = octaveLeft + numWhiteKeys * scaledWhiteKeyWidth /*- 1.0*/ + inset;
	y = inset;
	w = scaledWhiteKeyWidth /*+ 1.0*/ - (inset * 2.0);
	h = scaledKeyHeight - scaledBlackKeyHeight - inset * 2;// - 1;

	NSBezierPath *keyPath = [NSBezierPath bezierPath];
	[keyPath moveToPoint:NSMakePoint(x+0.5, y+h-0.5)];
	[keyPath lineToPoint:NSMakePoint(x+0.5, y)];
	[keyPath lineToPoint:NSMakePoint(x+w, y)];
	[keyPath lineToPoint:NSMakePoint(x+w, y+h)];
	if (rightIsInset)
	{
		[keyPath lineToPoint:NSMakePoint(x+w - scaledBlackKeyInset + 1, y+h)];
	}

    // upper half of white key
	y = scaledKeyHeight - scaledBlackKeyHeight - 1 - inset;
	h = scaledBlackKeyHeight;
	if (!rightIsInset && leftIsInset)
	{
		x += scaledBlackKeyInset - 1;
		w -= scaledBlackKeyInset - 1;
	}
	else if (rightIsInset && !leftIsInset)
	{
		w -= scaledBlackKeyInset - 1;
	}
	else if (rightIsInset && leftIsInset)
	{
		x += scaledBlackKeyInset - 1;
		w -= (scaledBlackKeyInset - 1) * 2;
	}
	[keyPath lineToPoint:NSMakePoint(x+w, y+h)];
	[keyPath lineToPoint:NSMakePoint(x+0.5, y+h)];
	[keyPath lineToPoint:NSMakePoint(x+0.5, y+0.5)];
	[keyPath closePath];

    // Cache the bezier path.
//    _lastKeyPath = [keyPath retain];
//    _lastKeyPathNote = note;

	return keyPath;
}

- (BOOL)drawDark
{
    if (@available(macOS 10.14, *))
    {
        return [[[NSAppearance currentAppearance] name] isEqualToString:NSAppearanceNameDarkAqua]
            && ![[NSUserDefaults standardUserDefaults] boolForKey:kForceLightKeyboardPrefKey];
    }
    else
    {
        return NO;
    }
}

- (void)drawKeyForNote:(int)note
{
    BOOL drawDark = [self drawDark];

    const key_info_t * _Nonnull keyInfo = [self getKeyInfoForMidiNote:note];

    NSColor * keyOutlineColor;
    NSColor * keyInlineColor;
    NSColor * keyFillTopColor;
    NSColor * keyFillBottomColor;
    double maxLineWidth;
    double insetAmount = (_sizing.scale - 1.0) * 0.6 + 1.0;
    if (drawDark)
    {
        keyOutlineColor = NSColor.blackColor;
        keyInlineColor = keyInfo->isBlackKey
                        ? [NSColor colorWithWhite:0.55 alpha:1.0]
                        : [NSColor colorWithWhite:0.15 alpha:1.0];
        keyFillTopColor = keyInfo->isBlackKey
                        ? [NSColor colorWithWhite:0.5 alpha:1.0]
                        : [NSColor colorWithWhite:0.2 alpha:1.0];
        keyFillBottomColor = keyInfo->isBlackKey
                        ? [NSColor colorWithWhite:0.75 alpha:1.0]
                        : [NSColor colorWithWhite:0.35 alpha:1.0];
        maxLineWidth = 4.0;
    }
    else
    {
        keyOutlineColor = NSColor.blackColor;
        keyInlineColor = keyInfo->isBlackKey
                        ? [NSColor colorWithWhite:0.25 alpha:1.0]
                        : NSColor.grayColor;
        keyFillTopColor = keyInfo->isBlackKey
                        ? NSColor.blackColor
                        : [NSColor colorWithWhite:0.65 alpha:1.0];
        keyFillBottomColor = keyInfo->isBlackKey
                        ? [NSColor colorWithWhite:0.35 alpha:1.0]
                        : NSColor.whiteColor;
        maxLineWidth = keyInfo->isBlackKey
                        ? 2.0
                        : 4.0;
    }

    [NSGraphicsContext saveGraphicsState];

    // Draw frame around the key
    NSBezierPath *keyPath = [self bezierPathForMidiNote:note];
    NSBezierPath *insetPath = [self bezierPathForMidiNote:note withInset:insetAmount];

    [keyOutlineColor set];
    [keyPath stroke];

    [NSGraphicsContext saveGraphicsState];

    [insetPath setClip];

    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor: keyFillTopColor endingColor:keyFillBottomColor];
    [gradient drawInRect: [insetPath bounds] angle: 330.0];
    [gradient release];

    [NSGraphicsContext restoreGraphicsState];

    [keyInlineColor set];
    insetPath.lineWidth = MIN(maxLineWidth, (_sizing.scale - 1.0) * 0.7 + 1.0);
    [insetPath stroke];

    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawKeyCapForNote:(int)note
{
    BOOL drawDark = [self drawDark];
    int offsetNote = note - mOctaveOffset * 12;
    const key_info_t * _Nonnull info = [self getKeyInfoForMidiNote:note];
    NSRect pathBounds = [[self bezierPathForMidiNote:note] bounds];
    double fontSize = 9.0 * MAX(1.0, _sizing.scale / 1.2);
    NSMutableDictionary * attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSFont labelFontOfSize:fontSize], NSFontAttributeName, nil];
    if (info->isBlackKey && !drawDark)
    {
        [attributes setValue:NSColor.whiteColor forKey:NSForegroundColorAttributeName];
    }
    else if (!info->isBlackKey && drawDark)
    {
        [attributes setValue:[NSColor colorWithWhite:0.75 alpha:1.0]
            forKey:NSForegroundColorAttributeName];
    }

    NSString * c = [mDelegate characterForMidiNote:offsetNote];
    NSSize capSize = [c sizeWithAttributes:attributes];
    double xOffset = ((pathBounds.size.width - capSize.width) / 2.0) - 0.5;
    NSPoint drawPoint = pathBounds.origin;
    drawPoint.x += xOffset;

    if (!info->isBlackKey)
    {
        drawPoint.y += 4.0;
    }
    else
    {
        drawPoint.y += 3.0;
    }

    if (_showKeycaps && [c length] > 0)
    {
        [c drawAtPoint:drawPoint withAttributes:attributes];
    }

    if (_showCNotes && info->noteInOctave == 0)
    {
        [attributes setValue:[NSFont labelFontOfSize:(fontSize * 2) / 3] forKey:NSFontAttributeName];
        c = [NSString stringWithFormat:@"C%d", (note / 12) - 2];
        NSSize noteCapSize = [c sizeWithAttributes:attributes];
        xOffset = ((pathBounds.size.width - noteCapSize.width) / 2.0) - 0.5;
        drawPoint = pathBounds.origin;
        drawPoint.x += xOffset;
        drawPoint.y += capSize.height + 3.0;

        [c drawAtPoint:drawPoint withAttributes:attributes];
    }
}

- (void)highlightMidiKey:(int)note
{
	NSBezierPath *keyPath = [self bezierPathForMidiNote:note withInset:1.0];
	NSColor * darkerHighlightColor = [NSColor colorWithCalibratedHue:[mHighlightColour hueComponent] saturation:[mHighlightColour saturationComponent]/2.0 brightness:[mHighlightColour brightnessComponent]*0.7 alpha:[mHighlightColour alphaComponent]];
	NSColor * lighterHighlightColor = [NSColor colorWithCalibratedHue:[mHighlightColour hueComponent] saturation:[mHighlightColour saturationComponent] brightness:[mHighlightColour brightnessComponent]*1.2 alpha:[mHighlightColour alphaComponent]];

	// Draw the highlight
	[NSGraphicsContext saveGraphicsState];

	[keyPath setClip];

        NSGradient *gradient = [[NSGradient alloc] initWithStartingColor: darkerHighlightColor endingColor:lighterHighlightColor];
        [gradient drawInRect: [keyPath bounds] angle: 330.0];
        [gradient release];

	[NSGraphicsContext restoreGraphicsState];

	// Draw frame around the highlighted key
	[NSGraphicsContext saveGraphicsState];

	[[NSColor colorWithCalibratedHue:[mHighlightColour hueComponent] saturation:[mHighlightColour saturationComponent] brightness:[mHighlightColour brightnessComponent]/3. alpha:[mHighlightColour alphaComponent]] set];
	[keyPath stroke];

	[NSGraphicsContext restoreGraphicsState];
}

// composite the up or down images into the view
- (void)drawOctaveOffsetIndicator
{
	if (mOctaveOffset == 0)
		return;

	NSRect bounds = [self bounds];
	NSPoint drawPoint;
	NSSize imageSize;
	NSImage *image;

	if (mOctaveOffset > 0)
	{
		// octave up
		image = mOctaveUpImage;
		imageSize = [image size];
		drawPoint = NSMakePoint(NSMaxX(bounds) - imageSize.width - 5.0, (NSHeight(bounds) - imageSize.height) / 2.0);
	}
	else
	{
		// octave down
		image = mOctaveDownImage;
		imageSize = [image size];
		drawPoint = NSMakePoint(5.0, (NSHeight(bounds) - imageSize.height) / 2.0);
	}

	float indicatorCompositeFraction = [[NSUserDefaults standardUserDefaults] floatForKey:@"OctaveOffsetIndicatorCompositeFraction"];
	if (indicatorCompositeFraction == 0.0)
	{
		[[NSUserDefaults standardUserDefaults] setFloat:0.25 forKey:@"OctaveOffsetIndicatorCompositeFraction"];
		indicatorCompositeFraction = 0.25;
	}

    [image drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:indicatorCompositeFraction];

	if (abs(mOctaveOffset) > 1)
	{
		int offsets = abs(mOctaveOffset) - 1;
		while (offsets--)
		{
			if (mOctaveOffset > 0)
            {
				drawPoint.x -= imageSize.width * 0.5;
            }
			else
            {
				drawPoint.x += imageSize.width * 0.5;
            }
            [image drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:indicatorCompositeFraction];
		}
	}
}

// This is really quite inefficient, but it works out, and draws flicker-free
// thanks to the WindowServer's double buffering.
- (void)drawRect:(NSRect)rect
{
	if (!inited)
	{
		[self computeKeyValues];
		inited = YES;
	}

	// draw the keyboard one key at a time, starting with the leftmost visible note
	int i;
	for (i = _sizing.firstMidiNote; i < _sizing.lastMidiNote; ++i)
	{
        // Draw frame around the key
        [self drawKeyForNote:i];

		// highlight the key if it is on
		if (midiKeyStates[i])
		{
			[self highlightMidiKey:i];
		}

		// Draw the key caps for this key.
        [self drawKeyCapForNote:i];
	}

	[self drawOctaveOffsetIndicator];
}

// recompute key values
- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
    // force recomputation of notes and sizes
    inited = NO;
    [self setNeedsDisplay:YES];
	[super resizeWithOldSuperviewSize:oldBoundsSize];
}

- (double)maxKeyboardWidthForSize:(NSSize)proposedSize
{
    keyboard_size_info_t sizing;
    [self computeSizeInfo:&sizing forSize:proposedSize];
    NSBezierPath * path = [self bezierPathForMidiNote:MAX_KEY_COUNT-1 withInset:0.0 usingSizeInfo:&sizing];
    return NSMaxX(path.bounds);
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)mouseDownCanMoveWindow
{
	return NO;
}

//! Just tests if the point is within every key which is inefficient.
//!
//! @retval -1 on failure
- (int)midiNoteForMouse:(NSPoint)location
{
	int note;
	for (note = _sizing.firstMidiNote; note < _sizing.lastMidiNote; ++note)
	{
		NSBezierPath *keyPath = [self bezierPathForMidiNote:note];
		if ([keyPath containsPoint:location])
		{
			return note;
		}
	}

	return -1;
}

// find the note of the clicked key, send note on, and save the note
- (void)mouseDown:(NSEvent *)theEvent
{
	mClickedNote = [self midiNoteForMouse:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
	if (mClickedNote != -1)
    {
        _lastAftertouchPressure = -1;
		[mDelegate processMidiKeyClickWithNote:mClickedNote turningOn:YES];
    }
}

// get the key the mouse is currently over. if it's changed, send a note off
// for the old one, note on for the new one, save it and continue
- (void)mouseDragged:(NSEvent *)theEvent
{
	int currentNote = [self midiNoteForMouse:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
	if (currentNote != mClickedNote)
	{
		if (mClickedNote != -1)
        {
			[mDelegate processMidiKeyClickWithNote:mClickedNote turningOn:NO];
        }
		if (currentNote != -1)
        {
			[mDelegate processMidiKeyClickWithNote:currentNote turningOn:YES];
        }
		mClickedNote = currentNote;
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if (mClickedNote != -1)
	{
		[mDelegate processMidiKeyClickWithNote:mClickedNote turningOn:NO];
		mClickedNote = -1;
        _lastAftertouchPressure = -1;
	}
}

- (void)pressureChangeWithEvent:(NSEvent *)event
{
//    NSLog(@"pressureChangeWithEvent: %@", event);
    if (mClickedNote != -1)
    {
        uint8_t intPressure = MIN(127, (uint8_t)(event.pressure * 127.0));
        if (intPressure != _lastAftertouchPressure)
        {
            [mDelegate processMidiChannelAftertouch:intPressure];
            _lastAftertouchPressure = intPressure;
        }
    }
}

// let the mDelegate object handle all the midi logic
- (void)keyDown:(NSEvent *)theEvent
{
//	NSLog(@"keyDown: %@; keycode = %d; timestamp = %g", [theEvent charactersIgnoringModifiers], [theEvent keyCode], (float)[theEvent timestamp]);
	// ignore keydowns generated by auto-key
	if ([theEvent isARepeat])
    {
		return;
    }
	[mDelegate processMidiKeyWithCode:[theEvent keyCode] turningOn:YES];
}

// send note offs
- (void)keyUp:(NSEvent *)theEvent
{
	[mDelegate processMidiKeyWithCode:[theEvent keyCode] turningOn:NO];
}

- (void)forceDisplay
{
    [self setNeedsDisplay:YES];
}

// we use counting for these methods instead of setting the states
// to boolean values because it is easily conceivable that multiple input
// sources would hit the same notes
- (void)turnMidiNoteOn:(int)note
{
    if (note < 0 || note > MAX_KEY_COUNT-1)
    {
        return;
    }
    if (midiKeyStates[note] < 254)
    {
        midiKeyStates[note]++;
    }
    [self performSelectorOnMainThread:@selector(forceDisplay) withObject:nil waitUntilDone:NO];
}

- (void)turnMidiNoteOff:(int)note
{
	if (note < 0 || note > MAX_KEY_COUNT-1)
    {
		return;
    }
	if (midiKeyStates[note] > 0)
    {
		midiKeyStates[note]--;
    }
    [self performSelectorOnMainThread:@selector(forceDisplay) withObject:nil waitUntilDone:NO];
}

- (void)turnAllNotesOff
{
    memset(&midiKeyStates, 0, sizeof(midiKeyStates));
    [self setNeedsDisplay:YES];
}

- (NSColor *)highlightColour
{
	return mHighlightColour;
}

- (void)setHighlightColour:(NSColor *)theColour
{
	if (theColour)
	{
		[mHighlightColour release];
		mHighlightColour = [theColour retain];
	}
}

- (int)octaveOffset
{
	return mOctaveOffset;
}

- (void)setOctaveOffset:(int)offset
{
	mOctaveOffset = offset;
	[self setNeedsDisplay:YES];
}

- (BOOL)showKeycaps
{
	return _showKeycaps;
}

- (void)setShowKeycaps:(BOOL)show
{
	if (show != _showKeycaps)
	{
		_showKeycaps = show;
		[self setNeedsDisplay:YES];
	}
}

@end
