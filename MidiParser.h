//
//  MidiParser.h
//  MidiKeys
//
//  Created by Chris Reed on Thu Oct 31 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@interface MidiParser : NSObject
{
	const MIDIPacketList *_packetList;
	MIDIPacket *_packet;
	int _packetCount;
	int _byteNum;
	int _dataBytesRequired;
	MIDIPacket _resultPacket;
	MIDIPacket _realtimePacket;
}

+ parserWithMidiPacketList:(const MIDIPacketList *)packetList;
- initWithMidiPacketList:(const MIDIPacketList *)packetList;

// Returns a pointer to the next complete packet, or NULL.
- (MIDIPacket *)nextMidiPacket;

@end
