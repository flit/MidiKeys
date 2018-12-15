//
//  MidiKeyView.m
//  MidiKeys
//
//  Created by Chris Reed on Tue Oct 15 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import "MidiKeyView.h"
#import "AppController.h"
#import "CTGradient.h"

// image file name
#define kOctaveImageFile @"Octave.png"
#define kOctaveDownImageFile @"OctaveDown.png"
#define kOctaveUpImageFile @"OctaveUp.png"

// key sizes
#define kWhiteKeyWidth 12.0
#define kBlackKeyInset 4.0
#define kBlackKeyWidth 6.0
#define kBlackKeyHeight 32.0

@interface MidiKeyView (PrivateMethods)

- (key_info_t)getKeyInfoForMidiNote:(int)note;
- (void)computeKeyValues;
- (NSBezierPath *)bezierPathForMidiNote:(int)note;
- (void)highlightMidiKey:(int)note;
- (int)midiNoteForMouse:(NSPoint)location;
- (void)drawOctaveOffsetIndicator;

@end

@implementation MidiKeyView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
        octaveImage = [[NSImage imageNamed:kOctaveImageFile] retain];
		mOctaveUpImage = [[NSImage imageNamed:kOctaveUpImageFile] retain];
		mOctaveDownImage = [[NSImage imageNamed:kOctaveDownImageFile] retain];
		mHighlightColour = [NSColor greenColor];
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
	[octaveImage release];
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

- (void)computeKeyValues
{
	NSSize octaveSize = [octaveImage size];
	NSRect bounds = [self frame];
	numOctaves = (int)(bounds.size.width / (octaveSize.width - 1));
	
//	NSLog(@"numOctaves = %d", numOctaves);
	
	// put middle c=60 in approx. center octave
	leftOctaves = numOctaves/2;
	firstMidiNote = 60 - (leftOctaves * 12);
	
//	NSLog(@"firstMidiNote = %d", firstMidiNote);

	// XXX really compute lastMidiNote
	lastMidiNote = KEY_COUNT; //firstMidiNote + int(bounds.size.width / kWhiteKeyWidth);
}

- (key_info_t)getKeyInfoForMidiNote:(int)note
{
	key_info_t info;
	int theNote = note;
	int theOctave = (theNote - firstMidiNote) / 12;
	int octaveFirstNote = firstMidiNote + theOctave * 12;
	int noteInOctave = theNote - octaveFirstNote;
	int numWhiteKeys = 0;
	int numBlackKeys = 0;
	int isWhiteKey = 0;
	int isBlackKey = 0;
	BOOL leftIsInset = NO;
	BOOL rightIsInset = NO; // black key insets on white keys
	
	switch (noteInOctave)
	{
		case 0: // C
			isWhiteKey = 1;
			rightIsInset = YES;
			break;
		case 1:	// C#
			isBlackKey = 1;
			numWhiteKeys = 1;
			break;
		case 2:	// D
			isWhiteKey = 1;
			numWhiteKeys = 1;
			numBlackKeys = 1;
			rightIsInset = YES;
			leftIsInset = YES;
			break;
		case 3:	// D#
			isBlackKey = 1;
			numWhiteKeys = 2;
			numBlackKeys = 1;
			break;
		case 4:	// E
			isWhiteKey = 1;
			numWhiteKeys = 2;
			numBlackKeys = 2;
			leftIsInset = YES;
			break;
		case 5: // F
			isWhiteKey = 1;
			numWhiteKeys = 3;
			numBlackKeys = 2;
			rightIsInset = YES;
			break;
		case 6: // F#
			isBlackKey = 1;
			numWhiteKeys = 4;
			numBlackKeys = 2;
			break;
		case 7: // G
			isWhiteKey = 1;
			numWhiteKeys = 4;
			numBlackKeys = 3;
			rightIsInset = YES;
			leftIsInset = YES;
			break;
		case 8: // G#
			isBlackKey = 1;
			numWhiteKeys = 5;
			numBlackKeys = 3;
			break;
		case 9: // A
			isWhiteKey = 1;
			numWhiteKeys = 5;
			numBlackKeys = 4;
			rightIsInset = YES;
			leftIsInset = YES;
			break;
		case 10: // A#
			isBlackKey = 1;
			numWhiteKeys = 6;
			numBlackKeys = 4;
			break;
		case 11: // B
			isWhiteKey = 1;
			numWhiteKeys = 6;
			numBlackKeys = 5;
			leftIsInset = YES;
			break;
		default:
			NSLog(@"bad note to key mapping!!! note=%d", note);
	}
	
	info.theOctave = theOctave;
	info.octaveFirstNote = octaveFirstNote;
	info.noteInOctave = noteInOctave;
	info.isWhiteKey = isWhiteKey;
	info.isBlackKey = isBlackKey;
	info.numWhiteKeys = numWhiteKeys;
	info.numBlackKeys = numBlackKeys;
	info.rightIsInset = rightIsInset;
	info.leftIsInset = leftIsInset;
	
	return info;
}

- (NSBezierPath *)bezierPathForMidiNote:(int)note
{
	NSSize octaveSize = [octaveImage size];

	// invert middle c
	int theNote = note;
	key_info_t info = [self getKeyInfoForMidiNote:theNote];
	
	int theOctave = info.theOctave;
	float octaveLeft = theOctave * (octaveSize.width - 1);
	int numWhiteKeys = info.numWhiteKeys;
	int isBlackKey = info.isBlackKey;
	BOOL leftIsInset = info.leftIsInset;
	BOOL rightIsInset = info.rightIsInset; // black key insets on white keys
	
	NSRect keyRect;
	
	if (isBlackKey)
	{
		keyRect.origin.x = octaveLeft + numWhiteKeys * kWhiteKeyWidth - kBlackKeyInset;
		keyRect.origin.y = octaveSize.height - kBlackKeyHeight;
		keyRect.size.width = kBlackKeyWidth + 1.0;
		keyRect.size.height = kBlackKeyHeight - 1;
		
		return [NSBezierPath bezierPathWithRect:keyRect];
	}
	
	// white key
	float x, y, w, h;
	x = octaveLeft + numWhiteKeys * kWhiteKeyWidth - 1.0;
	y = 0.;
	w = kWhiteKeyWidth + 1.0;
	h = octaveSize.height - kBlackKeyHeight;
	
	NSBezierPath *keyPath = [NSBezierPath bezierPath];
	[keyPath moveToPoint:NSMakePoint(x+0.5, y+h-0.5)];
	[keyPath lineToPoint:NSMakePoint(x+0.5, y)];
	[keyPath lineToPoint:NSMakePoint(x+w, y)];
	[keyPath lineToPoint:NSMakePoint(x+w, y+h)];
	if (rightIsInset)
	{
		[keyPath lineToPoint:NSMakePoint(x+w - kBlackKeyInset + 1, y+h)];
	}
	
	// start with white key part below the black keys
	y = octaveSize.height - kBlackKeyHeight - 1;
	h = kBlackKeyHeight;
	if (!rightIsInset && leftIsInset)
	{
		x += kBlackKeyInset - 1;
		w -= kBlackKeyInset - 1;
	}
	else if (rightIsInset && !leftIsInset)
	{
		w -= kBlackKeyInset - 1;
	}
	else if (rightIsInset && leftIsInset)
	{
		x += kBlackKeyInset - 1;
		w -= (kBlackKeyInset - 1) * 2;
	}
	[keyPath lineToPoint:NSMakePoint(x+w, y+h)];
	[keyPath lineToPoint:NSMakePoint(x+0.5, y+h)];
	[keyPath lineToPoint:NSMakePoint(x+0.5, y+0.5)];
	[keyPath closePath];
	
	return keyPath;
}

- (void)highlightMidiKey:(int)note
{
	NSBezierPath *keyPath = [self bezierPathForMidiNote:note];
	NSColor * darkerHighlightColor = [NSColor colorWithCalibratedHue:[mHighlightColour hueComponent] saturation:[mHighlightColour saturationComponent]/2.0f brightness:[mHighlightColour brightnessComponent] alpha:[mHighlightColour alphaComponent]];
	NSColor * lighterHighlightColor = [NSColor colorWithCalibratedHue:[mHighlightColour hueComponent] saturation:[mHighlightColour saturationComponent] brightness:[mHighlightColour brightnessComponent] alpha:[mHighlightColour alphaComponent]];

	// Draw the highlight
	[NSGraphicsContext saveGraphicsState];

	[keyPath setClip];
	
	CTGradient * gradient = [CTGradient gradientWithBeginningColor:darkerHighlightColor endingColor:lighterHighlightColor];
	[gradient fillRect:[keyPath bounds] angle:330.0f];
	
	[NSGraphicsContext restoreGraphicsState];

//	[mHighlightColour set];
//	[keyPath fill];

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
	
    [image drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:indicatorCompositeFraction];
	
	if (abs(mOctaveOffset) > 1)
	{
		int offsets = abs(mOctaveOffset) - 1;
		while (offsets--)
		{
			if (mOctaveOffset > 0)
				drawPoint.x -= imageSize.width * 0.5;
			else
				drawPoint.x += imageSize.width * 0.5;
            [image drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:indicatorCompositeFraction];
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
	
	NSRect bounds = [self frame];
	NSDrawWhiteBezel(bounds, rect);
	
	// draw the keyboard an octave at a time
	NSSize octaveSize = [octaveImage size];
	float frameWidth = bounds.size.width;
	NSPoint drawPoint;
	drawPoint.x = -1.;
	drawPoint.y = 0.;
	
	do {
        [octaveImage drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0f];
        drawPoint.x += octaveSize.width - 1.;
	} while (drawPoint.x < frameWidth);
	
	BOOL drawKeyCaps = _showKeycaps && mDelegate && [mDelegate respondsToSelector:@selector(characterForMidiNote:)];
	
	// draw each key that is currently pressed
	int i;
	for (i = firstMidiNote; i < lastMidiNote; ++i)
	{
		// draw only if the key is on
		if (midiKeyStates[i])
		{
			[self highlightMidiKey:i];
		}
		
		// Draw the key cap for this key.
		if (drawKeyCaps)
		{
			int offsetNote = i + mOctaveOffset * 12;
			if (offsetNote >= firstMidiNote && offsetNote < lastMidiNote)
			{
				key_info_t info = [self getKeyInfoForMidiNote:offsetNote];
				NSRect pathBounds = [[self bezierPathForMidiNote:offsetNote] bounds];
				NSMutableDictionary * attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSFont labelFontOfSize:9.0f], NSFontAttributeName, nil];
				if (info.isWhiteKey)
				{
					drawPoint.y = pathBounds.origin.y + 3.0f;
					drawPoint.x = pathBounds.origin.x + 4.0f;
				}
				else
				{
					drawPoint.x = pathBounds.origin.x + 1.0f;
					drawPoint.y = pathBounds.origin.y + 3.0f;
					[attributes setValue:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
				}
				
				NSString * c = [mDelegate characterForMidiNote:i];
				[c drawAtPoint:drawPoint withAttributes:attributes];
			}
		}
	}
	
	[self drawOctaveOffsetIndicator];
}

// recompute key values
- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
	[self computeKeyValues];
	inited = YES;
	
	[super resizeWithOldSuperviewSize:oldBoundsSize];
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
	for (note = firstMidiNote; note < lastMidiNote; ++note)
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
		[mDelegate processMidiKeyClickWithNote:mClickedNote turningOn:YES];
}

// get the key the mouse is currently over. if it's changed, send a note off
// for the old one, note on for the new one, save it and continue
- (void)mouseDragged:(NSEvent *)theEvent
{
	int currentNote = [self midiNoteForMouse:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
	if (currentNote != mClickedNote)
	{
		if (mClickedNote != -1)
			[mDelegate processMidiKeyClickWithNote:mClickedNote turningOn:NO];
		if (currentNote != -1)
			[mDelegate processMidiKeyClickWithNote:currentNote turningOn:YES];
		mClickedNote = currentNote;
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if (mClickedNote != -1)
	{
		[mDelegate processMidiKeyClickWithNote:mClickedNote turningOn:NO];
		mClickedNote = -1;
	}
}

// let the mDelegate object handle all the midi logic
- (void)keyDown:(NSEvent *)theEvent
{
//	NSLog(@"keyDown: %@; keycode = %d; timestamp = %g", [theEvent charactersIgnoringModifiers], [theEvent keyCode], (float)[theEvent timestamp]);
	// ignore keydowns generated by auto-key
	if ([theEvent isARepeat])
		return;
	[mDelegate processMidiKeyWithCode:[theEvent keyCode] turningOn:YES];
}

// send note offs
- (void)keyUp:(NSEvent *)theEvent
{
	[mDelegate processMidiKeyWithCode:[theEvent keyCode] turningOn:NO];
}

// we use counting for these methods instead of setting the states
// to boolean values because it is easily conceivable that multiple input
// sources would hit the same notes
- (void)turnMidiNoteOn:(int)note
{
	if (note < 0 || note > KEY_COUNT-1)
		return;
	if (midiKeyStates[note] < 127)
		midiKeyStates[note]++;
	[self setNeedsDisplay:YES];
}

- (void)turnMidiNoteOff:(int)note
{
	if (note < 0 || note > KEY_COUNT-1)
		return;
	if (midiKeyStates[note] > 0)
		midiKeyStates[note]--;
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
