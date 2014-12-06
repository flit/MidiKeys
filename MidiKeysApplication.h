//
//  MidiKeysApplication.h
//  MidiKeys
//
//  Created by Chris Reed on Sun Oct 27 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MidiKeysApplication : NSApplication

@end

@interface NSObject (HotKeysDelegateMethods)

- (void)hotKeyPressed:(UInt32)identifier;
- (void)hotKeyReleased:(UInt32)identifier;

@end

