//
//  Preferences.h
//  MidiKeys
//
//  Created by Chris Reed on Thu Jan 09 2003.
//  Copyright (c) 2002-2003 Chris Reed. All rights reserved.
//

#import <ShortcutRecorder/SRRecorderControl.h>

//! @name Preference Keys
//@{

// Preferences without direct user control
#define kVelocityPrefKey @"Velocity"
#define kChannelPrefKey @"Channel"
#define kOctaveOffsetPrefKey @"OctaveOffset"
#define kDestinationPrefKey @"DestinationUID"
#define kSourcePrefKey @"SourceUID"
#define kIsWindowToggledPrefKey @"IsWindowToggled"
#define kMidiThruPrefKey @"MidiThru"
#define kOverlayTimeoutPrefKey @"OverlayTimeout"

// Preferences set in the Preferences panel
#define kKeyMapPrefKey @"KeyMap"
#define kHighlightColourPrefKey @"HighlightColour"
#define kUseHotKeysPrefKey @"UseHotKeys"
#define kFloatWindowPrefKey @"Floating"
#define kWindowTransparencyPrefKey @"WindowTransparency"
#define kHotKeysModifiersPrefKey @"HotKeysModifiers"
#define kSolidOnTopPrefKey @"SolidOnTop"
#define kClickThroughPrefKey @"ClickThrough"
#define SHOW_HOT_KEYS_OVERLAYS_PREF_KEY @"ShowHotKeysTogglingOverlays"
#define SHOW_OCTAVE_SHIFT_OVERLAYS_PREF_KEY @"ShowOctaveShiftOverlays"
#define SHOW_VELOCITY_OVERLAYS_PREF_KEY @"ShowVelocityOverlays"
#define kShowKeyCapsPrefKey @"ShowKeyCaps"

#define kToggleHotKeysShortcutPrefKey @"ToggleHotKeysShortcut"

// Dictionary keys for shortcut preferences.
#define SHORTCUT_FLAGS_KEY SRShortcutModifierFlagsKey //@"flags"
#define SHORTCUT_KEYCODE_KEY SRShortcutKeyCode //@"keycode"

// Hidden preferences
#define kVelocityRepeatIntervalPrefKey @"VelocityRepeatInterval"
#define kVelocityHotKeyDeltaPrefKey @"VelocityHotKeyDelta"

//@}

//! @name Preference Defaults
//@{

// Default values for preferences
#define kDefaultHighlightRed 0.0
#define kDefaultHighlightGreen 1.0
#define kDefaultHighlightBlue 0.0

#define kDefaultHighlightTransparency 0.75
#define kDefaultWindowTransparency 1.0

#define kDefaultHotKeysModifiers 0

#define kDefaultVelocityRepeatInterval 0.25
#define kDefaultVelocityHotKeyDelta 10.0

//@}

