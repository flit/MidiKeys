//
//  OverlayIndicator.m
//  MidiKeys
//
//  Created by Chris Reed on Tue Jun 17 2003.
//  Copyright (c) 2003 Chris Reed. All rights reserved.
//

#import "OverlayIndicator.h"
#import <Quartz/Quartz.h>
#import <QuartzCore/QuartzCore.h>

//! Font size of the overlay message.
#define OVERLAY_MESSAGE_FONT_SIZE 32.0

// Internal methods.
@interface OverlayIndicator ()

- (void)buildOverlayWindow;
- (void)hideOverlay:(NSTimer *)theTimer;

@end

@interface OverlayBackgroundView : NSView

@end

@implementation OverlayIndicator

- initWithView:(NSView *)theView
{
	self = [super init];
	if (self)
	{
        _contentView = [theView retain];
	}
    
	return self;
}

- initWithImage:(NSImage *)theImage
{
	NSRect viewFrame;
	viewFrame.origin.x = 0.0f;
	viewFrame.origin.y = 0.0f;
	viewFrame.size = [theImage size];
	
    // Create an image view to hold the given image.
	NSImageView *imageView = [[[NSImageView alloc] initWithFrame:viewFrame] autorelease];
	[imageView setImage:theImage];
	[imageView setImageAlignment:NSImageAlignCenter];
	[imageView setImageFrameStyle:NSImageFrameNone];
	[imageView setEditable:NO];
    [imageView setWantsLayer:YES];
    
    // Apply a shadow to the image.
    NSShadow * shadow = [[[NSShadow alloc] init] autorelease];
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.85]];
    [shadow setShadowOffset:NSMakeSize(1.0, -1.0)];
    [shadow setShadowBlurRadius:2.0];
    [imageView setShadow:shadow];
	
	return [self initWithView:imageView];
}

- (void)dealloc
{
	[self close];
	[_overlayWindow release];
    [_contentView release];
	
	[super dealloc];
}

- (void)setDelegate:(id)theDelegate
{
	_delegate = theDelegate;
}

- (id)delegate
{
	return _delegate;
}

- (NSString *)message
{
    return _message;
}

- (void)setMessage:(NSString *)theMessage
{
    [_message autorelease];
    _message = [theMessage copy];
}

- (void)buildOverlayWindow
{
    NSTextField * messageView = nil;
    NSSize messageSize= {0};
    if (_message)
    {
        NSShadow * shadow = [[[NSShadow alloc] init] autorelease];
        [shadow setShadowOffset:NSMakeSize(2.0, -2.0)];
        [shadow setShadowBlurRadius:1.0];
        
        // Build the attributes dictionary.
        NSDictionary * attrs = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSFont boldSystemFontOfSize:OVERLAY_MESSAGE_FONT_SIZE], NSFontAttributeName,
            shadow, NSShadowAttributeName,
            [NSColor whiteColor], NSForegroundColorAttributeName,
            [NSColor blackColor], NSStrokeColorAttributeName,
            [NSNumber numberWithFloat:-1.0], NSStrokeWidthAttributeName,
//            [NSNumber numberWithFloat:0.12], NSExpansionAttributeName,
            nil, nil];
        
        NSAttributedString * attributedMessage = [[NSAttributedString alloc] initWithString:_message attributes:attrs];
        
        // Compute the bounding rect of the message.
        NSRect messageFrame;
        messageSize = [attributedMessage size];
        messageFrame.size = messageSize;
        messageFrame.size.width += 5;
        messageFrame.origin.x = 0;
        messageFrame.origin.y = 0;
        
        messageView = [[[NSTextField alloc] initWithFrame:messageFrame] autorelease];
        [messageView setAttributedStringValue:attributedMessage];
        [messageView setBordered:NO];
        [messageView setBezeled:NO];
        [messageView setEditable:NO];
        [messageView setSelectable:NO];
        [messageView setDrawsBackground:NO];
    }
    
    // Calculate window rect.
    NSScreen *mainScreen = [NSScreen mainScreen];
    NSRect screenFrame = [mainScreen visibleFrame];
    NSRect viewFrame = [_contentView frame];
    
    float width = NSWidth(viewFrame) + kOverlayIndicatorMargin * 2.0f;
    float height = NSHeight(viewFrame) + kOverlayIndicatorMargin * 2.0f;
    
    if (messageView)
    {
        if (width < messageSize.width + kOverlayIndicatorMargin * 2.0f)
        {
            width = messageSize.width + kOverlayIndicatorMargin * 2.0f;
        }
        
        height += messageSize.height + kOverlayIndicatorMargin / 2.0;
    }
    
    NSRect contentRect = NSMakeRect((NSWidth(screenFrame) - width) / 2.0f, (NSHeight(screenFrame) - height) / 2.0f, width, height);
    
    // create overlay window
    _overlayWindow = [[NSWindow alloc] initWithContentRect:contentRect styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES screen:mainScreen];
    [_overlayWindow setOpaque:NO];
    [_overlayWindow setHasShadow:NO];
//    [_overlayWindow setAlphaValue:0.75f];
    [_overlayWindow setLevel:NSStatusWindowLevel];
    [_overlayWindow setIgnoresMouseEvents:YES];
    [_overlayWindow setBackgroundColor:[NSColor clearColor]];
    
    // add background view to window
    NSRect backFrame = NSMakeRect(0.0f, 0.0f, width, height);
    OverlayBackgroundView *backView = [[[OverlayBackgroundView alloc] initWithFrame:backFrame] autorelease];
    [backView setWantsLayer:YES];
    [_overlayWindow setContentView: backView];
    
    // Add subviews to background view and reposition it.
    [backView addSubview:_contentView];
    
    NSPoint newOrigin;
    newOrigin.x = (width - NSWidth(viewFrame)) / 2.0;
    newOrigin.y = height - NSHeight(viewFrame) - kOverlayIndicatorMargin;
    [_contentView setFrameOrigin:newOrigin];
    
    if (messageView)
    {
        [backView addSubview:messageView];
        
        newOrigin.x = (width - messageSize.width) / 2.0;
        newOrigin.y = kOverlayIndicatorMargin / 2.0;
        [messageView setFrameOrigin:newOrigin];
    }
}

- (void)showUntilDate:(NSDate *)hideDate
{
    [self buildOverlayWindow];
	[_overlayWindow makeKeyAndOrderFront:nil];
	
	// schedule timer
	_timer = [NSTimer scheduledTimerWithTimeInterval:[hideDate timeIntervalSinceNow] target:self selector:@selector(hideOverlay:) userInfo:nil repeats:NO];
}

- (void)hideOverlay:(NSTimer *)theTimer
{
	// Fade window out
    CALayer * theLayer = [[_overlayWindow contentView] layer];

//    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"opacity"];
//    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
//    anim.fromValue = [NSNumber numberWithFloat:1];
//    anim.toValue = [NSNumber numberWithFloat:0];
//    anim.duration = 0.4;
//    // We make ourselves the delegate to get notified when the animation ends
//    anim.delegate = self;
//    
//    [theLayer addAnimation:anim forKey:@"alpha"];

    // Create an explicit transaction to animate the opacity change.
    [CATransaction begin];
    [CATransaction setValue:[NSNumber numberWithFloat:0.5f] forKey:kCATransactionAnimationDuration];
    theLayer.opacity=0.0;
    [CATransaction commit];
	
	_timer = nil;
	
	// inform delegate
	if (_delegate && [_delegate respondsToSelector:@selector(overlayIndicatorDidClose:)])
	{
		[_delegate overlayIndicatorDidClose:self];
	}
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    NSLog(@"anim did stop: %@ flag:%d", anim, (int)flag);
	[_overlayWindow close];
//    [self close];
}

- (void)close
{
	if (_timer)
	{
		[_timer invalidate];
		_timer = nil;
	}

    [[[_overlayWindow contentView] layer] removeAllAnimations];
	[_overlayWindow close];
	
	// inform delegate
	if (_delegate && [_delegate respondsToSelector:@selector(overlayIndicatorDidClose:)])
	{
		[_delegate overlayIndicatorDidClose:self];
	}
}

@end

// These values produce a background that exactly matches Apple's bezel overlays.
#define OVERLAY_BACKGROUND_GRAYSCALE 0.2f
#define OVERLAY_BACKGROUND_RADIUS 20.0f
#define OVERLAY_BACKGROUND_ALPHA 0.2f
	
@implementation OverlayBackgroundView

- (BOOL)isOpaque
{
	return NO;
}

- (void)drawRect:(NSRect)rect
{
	[[NSColor colorWithCalibratedWhite:OVERLAY_BACKGROUND_GRAYSCALE alpha:OVERLAY_BACKGROUND_ALPHA] set];
	[[NSBezierPath bezierPathWithRoundedRect:[self bounds] xRadius:OVERLAY_BACKGROUND_RADIUS yRadius:OVERLAY_BACKGROUND_RADIUS] fill];
}

@end

