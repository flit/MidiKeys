//
//  MIDI.h
//  MidiKeys
//
//  Created by Chris Reed on 1/1/19.
//

#ifndef MIDI_h
#define MIDI_h

#include <stdint.h>

//! MIDI channel message values.
enum _midi_channel_messages : uint8_t {
    kMIDIChannelMessageStatusMask = 0xf0,
    kMIDINoteOff = 0x80, //!< Data bytes: 0kkkkkkk 0vvvvvvv
    kMIDINoteOn = 0x90, //!< Data bytes: 0kkkkkkk 0vvvvvvv
    kMIDIPolyphonicPressure = 0xa0, //!< Data bytes: 0kkkkkkk 0vvvvvvv
    kMIDIControlChange = 0xb0, //!< Data bytes: 0ccccccc 0vvvvvvv
    kMIDIProgramChange = 0xc0, //!< Data bytes: 0ppppppp
    kMIDIChannelPressure = 0xd0, //!< Data bytes: 0vvvvvvv
    kMIDIPitchBend = 0xe0, //!< Data bytes: 0lllllll 0mmmmmmm
};

//! MIDI channel mode message values.
enum _midi_channel_mode_messages : uint8_t {
    kMIDIAllSoundOff = 0x78, //!< v=0
    kMIDIResetAllControllers = 0x79, //!< v=0
    kMIDILocalControl = 0x7a, //!< v=0 (local control off), v=127 (local control on)
    kMIDIAllNotesOff = 0x7b, //!< v=0
    kMIDIOmniModeOff = 0x7c, //!< v=0
    kMIDIOmniModeOn = 0x7d, //!< v=0
    kMIDIMonoModeOn = 0x7e, //!< v=M; M=channel count (Omni off) or 0 (Omni on)
    kMIDIPolyModeOn = 0x7f, //!< v=0
};

//! MIDI system common message values.
enum _midi_system_common_messages : uint8_t {
    kMIDISysExStart = 0xf0,
    kMIDITimeCodeQuarterFrame = 0xf1,
    kMIDISongPositionPointer = 0xf2,
    kMIDISongSelect = 0xf3,
    kMIDISystemCommonUndefined1 = 0xf4,
    kMIDISystemCommonUndefined2 = 0xf5,
    kMIDITuneRequest = 0xf6,
    kMIDISysExEnd = 0xf7,
};

//! MIDI system real time message values.
enum _midi_system_real_time_messages : uint8_t {
    kMIDIRealTimeClock = 0xf8,
    kMIDIRealTimeStart = 0xfa,
    kMIDIRealTimeContinue = 0xfb,
    kMIDIRealTimeStop = 0xfc,
    kMIDIRealTimeActiveSensing = 0xfe,
    kMIDIRealTimeSystemReset = 0xff,
    kMIDIFirstRealTimeMessage = kMIDIRealTimeClock,
};

#endif /* MIDI_h */
