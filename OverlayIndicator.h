//
//  OverlayIndicator.h
//  MidiKeys
//
//  Created by Chris Reed on Tue Jun 17 2003.
//  Copyright (c) 2003 Chris Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//! Margin around the image.
#define kOverlayIndicatorMargin 40.0f

/*!
 * @brief Manages an indicator popup window.
 *
 * This class manages a one-shot overlay window that displays an arbitrary
 * image. It is very similar to the overlay that appears when you adjust
 * volume or contrast from the keyboard.
 */
@interface OverlayIndicator : NSObject
{
    NSView * _contentView;
	NSWindow *_overlayWindow;
	NSTimer *_timer;
	id _delegate;
    NSString * _message;
}

//! @brief Designated initializer.
- initWithView:(NSView *)theView;

//! @brief Create an overlay showing an image.
- initWithImage:(NSImage *)theImage;

- (void)setDelegate:(id)theDelegate;
- (id)delegate;

- (NSString *)message;
- (void)setMessage:(NSString *)theMessage;

- (void)showUntilDate:(NSDate *)hideDate;
- (void)close;

@end

@interface NSObject (OverlayIndicatorDelegate)

- (void)overlayIndicatorDidClose:(OverlayIndicator *)theIndicator;

@end
