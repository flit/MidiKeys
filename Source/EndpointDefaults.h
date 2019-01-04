//
//  EndpointDefaults.h
//  MidiKeys
//
//  Created by Chris Reed on Wed Oct 23 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreMIDI/CoreMIDI.h>

@interface NSUserDefaults (EndpointDefaults)

- (MIDIEndpointRef)endpointForKey:(NSString *)key;
- (void)setEndpoint:(MIDIEndpointRef)endpoint forKey:(NSString *)key;
 
@end

