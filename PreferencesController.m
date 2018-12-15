//
//  PreferencesController.mm
//  MidiKeys
//
//  Created by Chris Reed on Sat Oct 26 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import "PreferencesController.h"
#import "ColourDefaults.h"
#import "KeyMapManager.h"
#import <Carbon/Carbon.h>

//! The name of the notification sent when preferences changes have been committed.
NSString *kPreferencesChangedNotification = @"PreferencesChanged";

//! Storage for the singleton preferences controller object.
static PreferencesController *_sharedPrefsController = nil;

@implementation PreferencesController

@synthesize delegate;

+ sharedInstance
{
	if (_sharedPrefsController == nil)
	{
		_sharedPrefsController = [[self alloc] init];
	}
	return _sharedPrefsController;
}

- init
{
	self = [super initWithWindowNibName:@"Preferences"];
	if (self)
	{
		if (_sharedPrefsController == nil)
		{
			_sharedPrefsController = self;
		}
	}
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (void)windowDidLoad
{
    // Configure the window a little.
    _prefsWindow = [self window];
    [_prefsWindow setExcludedFromWindowsMenu:YES];
    [_prefsWindow setMenu:nil];
    [_prefsWindow center];

    // Add our delegate as an observer for some notifications.
    NSNotificationCenter * center = [NSNotificationCenter defaultCenter];
    [center addObserver:delegate selector:@selector(preferencesDidChange:) name:kPreferencesChangedNotification object:nil];
    
    [_toggleHotKeysShortcut setCanCaptureGlobalHotKeys:YES];
}

- (void)showPanel:(id)sender
{
    // Force the window to load if it hasn't already been loaded so we can set up the
    // controls properly.
    [self window];

    // Refresh controls to match current prefs.
	[self updateWindow];
    
    // Bring the window to front and show it.
    [self showWindow:nil];
}

//! Set values of window widgets based on preferences. Default preference
//! values have already been set by AppController.
- (void)updateWindow
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// set keymap popup
	KeyMapManager *keyMgr = [KeyMapManager sharedInstance];
	[keymapPopup removeAllItems];
	[keymapPopup addItemsWithTitles:[keyMgr allKeyMapLocalisedNames]];
	NSString *keymapPref = [defaults stringForKey:kKeyMapPrefKey];
	
	// fill in nonlocalised/global names as the represented object
	int i;
	for (i=0; i < [keymapPopup numberOfItems]; ++i)
	{
		NSMenuItem * thisItem = [keymapPopup itemAtIndex:i];
		id globalName = [keyMgr nameForKeyMapWithLocalisedName:[thisItem title]];
		[thisItem setRepresentedObject:globalName];
		// select the keymap whose global name matches the pref
		if ([globalName isEqualToString:keymapPref])
		{
			[keymapPopup selectItemAtIndex:i];
		}
	}
	
	// other widgets
	[highlightColourWell setColor:[defaults colorForKey:kHighlightColourPrefKey]];
	[floatWindowCheckbox setIntValue:[defaults boolForKey:kFloatWindowPrefKey]];
	BOOL isUsingHotKeys = [defaults boolForKey:kUseHotKeysPrefKey];
	[useHotKeysCheckbox setIntValue:isUsingHotKeys];
	[windowTransparencySlider setFloatValue:(1.0 - [defaults floatForKey:kWindowTransparencyPrefKey]) * 100.];
	[solidOnTopCheckbox setIntValue:[defaults boolForKey:kSolidOnTopPrefKey]];
	[showKeyCapsCheckbox setIntValue:[defaults boolForKey:kShowKeyCapsPrefKey]];
	[_clickThroughCheckbox setIntValue:[defaults boolForKey:kClickThroughPrefKey]];
    [self keyboardFloatsDidChange:nil];

    [_hotKeysOverlaysCheckbox setIntValue:[defaults boolForKey:SHOW_HOT_KEYS_OVERLAYS_PREF_KEY]];
    [_octaveShiftOverlaysCheckbox setIntValue:[defaults boolForKey:SHOW_OCTAVE_SHIFT_OVERLAYS_PREF_KEY]];
    [_velocityOverlaysCheckbox setIntValue:[defaults boolForKey:SHOW_VELOCITY_OVERLAYS_PREF_KEY]];
    
	// modifier checkboxes
	long modifiers = [defaults integerForKey:kHotKeysModifiersPrefKey];
	BOOL controlChecked = (modifiers & controlKey) > 0;
	BOOL shiftChecked = (modifiers & shiftKey) > 0;
	BOOL optionChecked = (modifiers & optionKey) > 0;
	BOOL commandChecked = (modifiers & cmdKey) > 0;
	[controlModifierCheckbox setIntValue:controlChecked];
	[shiftModifierCheckbox setIntValue:shiftChecked];
	[optionModifierCheckbox setIntValue:optionChecked];
	[commandModifierCheckbox setIntValue:commandChecked];
	
    // Update toggle hot keys key combo.
    NSDictionary * toggleDict = [defaults dictionaryForKey:kToggleHotKeysShortcutPrefKey];
    KeyCombo combo;
    if (toggleDict)
    {
        combo.flags = [_toggleHotKeysShortcut carbonToCocoaFlags:[[toggleDict objectForKey:SHORTCUT_FLAGS_KEY] intValue]];
        combo.code = [[toggleDict objectForKey:SHORTCUT_KEYCODE_KEY] intValue];
    }
    else
    {
        combo.flags = 0;
        combo.code = -1;
    }
    [_toggleHotKeysShortcut setKeyCombo:combo];
}

//! @brief Save preferences to defaults and send prefs changed notification.
//! @return A boolean indicating if the window should be closed.
- (BOOL)commitChanges
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// hotkeys
	BOOL isUsingHotKeys = [useHotKeysCheckbox intValue];
	[defaults setBool:isUsingHotKeys forKey:kUseHotKeysPrefKey];
	
	// modifiers
	BOOL controlChecked = [controlModifierCheckbox intValue];
	BOOL shiftChecked = [shiftModifierCheckbox intValue];
	BOOL optionChecked = [optionModifierCheckbox intValue];
	BOOL commandChecked = [commandModifierCheckbox intValue];
	
	int newModifiers = 0;
	if (controlChecked)
	{
		newModifiers += controlKey;
	}
	if (shiftChecked)
	{
		newModifiers += shiftKey;
	}
	if (optionChecked)
	{
		newModifiers += optionKey;
	}
	if (commandChecked)
	{
		newModifiers += cmdKey;
	}
    // Default to the Fn key if no other modifiers are set.
	if (newModifiers == 0)
	{
		newModifiers = kEventKeyModifierFnMask;
	}
	[defaults setInteger:newModifiers forKey:kHotKeysModifiersPrefKey];
	
	// show keycaps
	[defaults setBool:[showKeyCapsCheckbox intValue] forKey:kShowKeyCapsPrefKey];
	
	// float window checkbox
	[defaults setBool:[floatWindowCheckbox intValue] forKey:kFloatWindowPrefKey];
        
	// solid on top checkbox
    [defaults setBool:[solidOnTopCheckbox intValue] forKey:kSolidOnTopPrefKey];
	
	// click through checkbox
	[defaults setBool:[_clickThroughCheckbox intValue] forKey:kClickThroughPrefKey];
	
	// keymap -- the represented object is the nonlocalised keymap name
	[defaults setObject:[[keymapPopup selectedItem] representedObject] forKey:kKeyMapPrefKey];
	
	// colour
	[defaults setColor:[highlightColourWell color] forKey:kHighlightColourPrefKey];
	[defaults setFloat:(1.0 - [windowTransparencySlider floatValue] / 100.) forKey:kWindowTransparencyPrefKey];
	
	// overlays
    [defaults setBool:[_hotKeysOverlaysCheckbox intValue] forKey:SHOW_HOT_KEYS_OVERLAYS_PREF_KEY];
    [defaults setBool:[_octaveShiftOverlaysCheckbox intValue] forKey:SHOW_OCTAVE_SHIFT_OVERLAYS_PREF_KEY];
    [defaults setBool:[_velocityOverlaysCheckbox intValue] forKey:SHOW_VELOCITY_OVERLAYS_PREF_KEY];
    
    // Toggle hot keys shortcut.
    KeyCombo combo = [_toggleHotKeysShortcut keyCombo];
    int carbonFlags = (int) [_toggleHotKeysShortcut cocoaToCarbonFlags:combo.flags];
    NSDictionary * comboDict = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt:carbonFlags], SHORTCUT_FLAGS_KEY,
        [NSNumber numberWithInteger:combo.code], SHORTCUT_KEYCODE_KEY,
        nil, nil];
    [defaults setObject:comboDict forKey:kToggleHotKeysShortcutPrefKey];
	
	// send notification that the prefs have changed
	[[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
	
	return YES;
}

- (IBAction)ok:(id)sender
{
	if ([self commitChanges])
	{
		[self close];
	}
}

- (IBAction)cancel:(id)sender
{
	[self close];
}

- (IBAction)keyboardFloatsDidChange:(id)sender
{
    [_clickThroughCheckbox setEnabled:(BOOL)[floatWindowCheckbox intValue]];
}

@end

