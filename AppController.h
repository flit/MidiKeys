//
//  AppController.h
//  MidiKeys
//
//  Created by Chris Reed on Tue Oct 15 2002.
//  Copyright (c) 2002-2003 Chris Reed. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Carbon/Carbon.h>
#import "MidiKeyView.h"

@class KeyMapManager;
@class MidiKeyMap;
@class OverlayIndicator;

//! The name we use for our CoreMIDI client and virtual source
#define kMyClientName CFSTR("MidiKeys")

//! Name of the octave up overlay image.
#define kOctaveUpOverlayImage @"OctaveUp"

//! Name of the octave down overlay image.
#define kOctaveDownOverlayImage @"OctaveDown"

//! \name Keycodes for arrow keys
//@{
#define kRightArrowKeycode 124
#define kLeftArrowKeycode 123
#define kUpArrowKeycode 126
#define kDownArrowKeycode 125
//@}

//! Direction of velocity adjustment.
enum _velocity_up_or_down
{
	kVelocityUp,
	kVelocityDown
};

/*!
 * @brief Main controller class for Midi Keys.
 *
 * Manages the keyboard window, all MIDI events, hot keys, menu items, and pretty much every
 * thing else except for preferences.
 */
@interface AppController : NSObject <NSWindowDelegate, NSApplicationDelegate, MidiKeyViewDelegate>
{
	IBOutlet NSPopUpButton *destinationPopup;
	IBOutlet NSPopUpButton *sourcePopup;
	IBOutlet MidiKeyView *midiKeys;
	IBOutlet NSSlider *velocitySlider;
    IBOutlet NSPopUpButton * channelPopup;
	IBOutlet KeyMapManager *keyMapManager;
	IBOutlet NSView *toggleView;
	IBOutlet NSView *hiddenItemsView;
	IBOutlet NSButton *midiThruCheckbox;
    IBOutlet NSMenuItem * _toggleHotKeysMenuItem;
    
	MIDIClientRef clientRef;
	MIDIPortRef outputPort;
	MIDIPortRef inputPort;
	MIDIEndpointRef virtualSourceEndpoint;
	MIDIUniqueID virtualSourceUID;
	MIDIEndpointRef selectedSource;
	BOOL isSourceConnected;
	MIDIEndpointRef selectedDestination;
	BOOL isDestinationConnected;	// if YES, we're not using the virtual source
	BOOL performMidiThru;
	float currentVelocity;
    float maxVelocity;
	int currentChannel;
	int octaveOffset;
	MidiKeyMap *keyMap;
    EventHotKeyRef _toggleHotKeyRef;
	EventHotKeyRef octaveUpHotKeyRef;
	EventHotKeyRef octaveDownHotKeyRef;
	EventHotKeyRef velocityUpHotKeyRef;
	EventHotKeyRef velocityDownHotKeyRef;
	BOOL hotKeysAreRegistered;
	BOOL makeWindowSolidWhenOnTop;
	BOOL isWindowToggled;
	float toggleDelta;
	NSTimer *velocityHotKeyTimer;
	OverlayIndicator *_indicator;
//    NSStatusItem * _hotKeysStatusItem;
}

- (IBAction)destinationSelected:(id)sender;
- (IBAction)sourceSelected:(id)sender;
- (IBAction)velocitySliderChanged:(id)sender;
- (IBAction)channelDidChange:(id)sender;
- (IBAction)toggleMidiThru:(id)sender;
- (IBAction)toggleMidiControls:(id)sender;
- (IBAction)octaveUp:(id)sender;
- (IBAction)octaveDown:(id)sender;
- (IBAction)clearStuckKeys:(id)sender;

@end

@interface AppController (HotKeys)

- (IBAction)toggleHotKeys:(id)sender;
- (void)enableHotKeys;
- (void)disableHotKeys;

- (void)registerOctaveHotKeysWithModifiers:(int)modifiers;
- (void)unregisterOctaveHotKeys;

- (void)handleVelocityKeyPressedUpOrDown:(int)upOrDown;
- (void)velocityHotKeyTimerFired:(NSTimer *)timer;
- (void)handleVelocityKeyReleased;

- (void)hotKeyPressed:(uintptr_t)identifier;
- (void)hotKeyReleased:(uintptr_t)identifier;

- (void)registerToggleHotKey;
- (void)unregisterToggleHotKey;

- (void)registerHotKeys;
- (void)unregisterHotKeys;

- (void)displayHotKeysOverlay;

@end

@interface AppController (MIDI)

- (NSString *)nameForMidiEndpoint:(MIDIEndpointRef)theEndpoint;

// use vel=0 for off
- (void)sendMidiNote:(int)midiNote channel:(int)channel velocity:(int)velocity;
- (void)handleMidiNotification:(const MIDINotification *)message;
- (void)receiveMidiPacketList:(const MIDIPacketList *)packetList;

- (void)adjustVelocity:(float)delta;

- (IBAction)sendAllNotesOff:(id)sender;

- (NSString *)characterForMidiNote:(int)note;

@end

void MyNotifyProc(const MIDINotification *message, void *refCon);
void MyMidiReadProc(const MIDIPacketList *pktlist, void *refCon, void *connRefCon);

