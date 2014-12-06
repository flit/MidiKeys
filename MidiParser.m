//
//  MidiParser.m
//  MidiKeys
//
//  Created by Chris Reed on Thu Oct 31 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import "MidiParser.h"

#define kInSysEx -1

@interface MidiParser (PrivateMethods)

- (MIDIPacket *)processByte:(Byte)theByte;

@end

@implementation MidiParser

+ parserWithMidiPacketList:(const MIDIPacketList *)packetList
{
	return [[[self alloc] initWithMidiPacketList:packetList] autorelease];
}

// Designated initialiser.
- initWithMidiPacketList:(const MIDIPacketList *)packetList
{
	self = [super init];
	if (self)
	{
		_packetList = packetList;
		_packetCount = _packetList->numPackets;
		_packet = (MIDIPacket *)_packetList->packet;	// remove const (!)
		_byteNum = 0;
	}
	return self;
}

// Figure out what to do with a single byte. If the byte completes a packet, then the
// packet description is filled in and a pointer to it is returned. Otherwise, this
// method quietly processes the byte and returns NULL.
- (MIDIPacket *)processByte:(Byte)theByte
{
	if (theByte & 0x80)
	{
		// status byte
		if (theByte >= 0xf8)
		{
			// realtime message
			switch (theByte)
			{
				case 0xf8:	// clock
				case 0xfa:	// start
				case 0xfb:	// continue
				case 0xfc:	// stop
				case 0xff:	// system reset
					// fill in the realtime packet and return it
					_realtimePacket.timeStamp = _packet->timeStamp;
					_realtimePacket.length = 1;
					_realtimePacket.data[0] = theByte;
					++_byteNum; // start at next byte next time through
					return &_realtimePacket;
					
				case 0xfe:	// active sensing (ignored)
				default:
					break;
			}
		}
		else
		{
			// non realtime message. always begins packet
			
			// XXX handle status cancleling sysex
			
			// set up resulting packet
			_resultPacket.timeStamp = _packet->timeStamp;
			_resultPacket.length = 1;
			_resultPacket.data[0] = theByte;
			
			if (theByte < 0xf0)
			{
				// channel message
				_dataBytesRequired = ((theByte & 0xe0) == 0xc0) ? 1 : 2;
			}
			else
			{
				// system message
				switch (theByte)
				{
					case 0xf0:
						_dataBytesRequired = kInSysEx;
						break;
					case 0xf1:	// MTC quarter frame
					case 0xf3:	// song select
						_dataBytesRequired = 1;
						break;
					case 0xf2:	// song ptr
						_dataBytesRequired = 2;
						break;
					case 0xf6:	// tune request
						_dataBytesRequired = 0;
						++_byteNum;
						return &_resultPacket;
					case 0xf4:	// undefined
					case 0xf5:	// undefined
					case 0xf7:	// EOX handled above
						_dataBytesRequired = 0;
						break;
				}
			}
		}
	}
	else
	{
		// data byte
		if (_dataBytesRequired > 0)
		{
			_resultPacket.data[_resultPacket.length++] = theByte;
			if (--_dataBytesRequired == 0)
			{
				++_byteNum; // start at next byte the next time through
				return &_resultPacket;
			}
		}
		else if (_dataBytesRequired == kInSysEx)
		{
			// XXX handle sysex
		}
	}
	return NULL;
}

// This method fills in our standalone packet while parsing the packet list we were initialised
// with. The spec for MIDIPackets as defined in the MIDIServices.h header says that a packet
// may contain more than one event, but it will always contain whole events. Unless it's sysex,
// which may be split across packets.
- (MIDIPacket *)nextMidiPacket
{
	// have we parsed all the packets?
	if (_packetCount <= 0)
		return NULL;
	
	// check byte num. this the normal way we advance to the next packet in the list.
	if (_packet && _byteNum >= _packet->length)
	{
		_packet = (--_packetCount > 0) ? MIDIPacketNext(_packet) : NULL;
		_byteNum = 0;
	}
	
	// bail if there's still not a packet
	if (!_packet)
		return NULL;
	
	// process bytes in this packet
	do {
		_dataBytesRequired = 0;
		for (; _byteNum < _packet->length; ++_byteNum)
		{
			MIDIPacket *result = [self processByte:_packet->data[_byteNum]];
			if (result != NULL)
				return result;
		}
		
		// we have exited the loop (process all bytes in the packet) without sending
		// a packet out. so advance to the next packet and try again.
		_packet = (--_packetCount > 0) ? MIDIPacketNext(_packet) : NULL;
		_byteNum = 0;
	} while (_packet);
	
	// there is no next packet
	return NULL;
}

@end

