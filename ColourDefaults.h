//
//  ColourDefaults.h
//  MidiKeys
//
//  Created by Chris Reed on Sat Oct 26 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSUserDefaults (ColourDefaults)

- (NSColor *)colorForKey:(NSString *)key;
- (void)setColor:(NSColor *)theColor forKey:(NSString *)key;

@end

