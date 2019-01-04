//
//  MidiParser.m
//  MidiKeys
//
//  Created by Chris Reed on Thu Oct 31 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import "MidiParser.h"
#import "MIDI.h"

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
		if (theByte >= kMIDIFirstRealTimeMessage)
		{
			// realtime message
			switch (theByte)
			{
				case kMIDIRealTimeClock:	// clock
				case kMIDIRealTimeStart:	// start
				case kMIDIRealTimeContinue:	// continue
				case kMIDIRealTimeStop:	// stop
				case kMIDIRealTimeSystemReset:	// system reset
					// fill in the realtime packet and return it
					_realtimePacket.timeStamp = _packet->timeStamp;
					_realtimePacket.length = 1;
					_realtimePacket.data[0] = theByte;
					++_byteNum; // start at next byte next time through
					return &_realtimePacket;
					
				case kMIDIRealTimeActiveSensing:	// active sensing (ignored)
				default:
					break;
			}
		}
		else
		{
			// non realtime message. always begins packet
			
			// XXX handle status canceling sysex
			
			// set up resulting packet
			_resultPacket.timeStamp = _packet->timeStamp;
			_resultPacket.length = 1;
			_resultPacket.data[0] = theByte;

			if (theByte < 0xf0)
			{
				// channel message
                uint8_t status = theByte & kMIDIChannelMessageStatusMask;
				_dataBytesRequired = (status == kMIDIProgramChange || status == kMIDIChannelPressure)
                                        ? 1 : 2;
			}
			else
			{
				// system message
				switch (theByte)
				{
					case kMIDISysExStart:
						_dataBytesRequired = kInSysEx;
						break;
					case kMIDITimeCodeQuarterFrame:	// MTC quarter frame
					case kMIDISongSelect:	// song select
						_dataBytesRequired = 1;
						break;
					case kMIDISongPositionPointer:	// song ptr
						_dataBytesRequired = 2;
						break;
					case kMIDITuneRequest:	// tune request
						_dataBytesRequired = 0;
						++_byteNum;
						return &_resultPacket;
					case kMIDISystemCommonUndefined1:	// undefined
					case kMIDISystemCommonUndefined2:	// undefined
					case kMIDISysExEnd:	// EOX handled above
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

