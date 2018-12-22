//
//  AppController.m
//  MidiKeys
//
//  Created by Chris Reed on Tue Oct 15 2002.
//  Copyright (c) 2002-2003 Chris Reed. All rights reserved.
//

#import "AppController.h"
#import "MidiKeyView.h"
#import "EndpointDefaults.h"
#import "ColourDefaults.h"
#import "KeyMapManager.h"
#import "MidiKeyMap.h"
#import "PreferencesController.h"
#import "MidiParser.h"
#import "OverlayIndicator.h"
#import <CoreAudio/HostTime.h>

#define MAX_OCTAVE_OFFSET (4)
#define MIN_OCTAVE_OFFSET (-4)

@interface AppController ()

- (void)setupRegisteredDefaults;

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationWillTerminate:(NSNotification *)notification;
- (void)applicationDidBecomeActive:(NSNotification *)notification;
- (void)applicationDidResignActive:(NSNotification *)notification;

- (void)windowWillClose:(NSNotification *)notification;

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;

- (NSString *)uniqueTitle:(NSString *)title forMenu:(NSMenu *)menu;
- (void)updateDestinationMenu;
- (void)updateSourceMenu;

- (void)setWindowLevelFromPreferences;
- (void)preferencesDidChange:(NSNotification *)notification;

- (void)setClickThrough:(BOOL)clickThrough;

- (void)toggleMidiControls:(id)sender;

- (float)overlayTimeout;
- (void)overlayIndicatorDidClose:(OverlayIndicator *)theIndicator;

@end

@implementation AppController

- (void)dealloc
{
	[_indicator close];
	[keyMap release];
	MIDIPortDispose(outputPort);
	MIDIPortDispose(inputPort);
	MIDIEndpointDispose(virtualSourceEndpoint);
	MIDIClientDispose(clientRef);
	[midiKeys setDelegate:nil]; // we're no longer valid
	[super dealloc];
}

- (NSString *)uniqueTitle:(NSString *)title forMenu:(NSMenu *)menu
{
	if ([menu itemWithTitle:title] == nil)
		return title;
	
	int n;
	for (n=0;; ++n)
	{
		NSString *possibleTitle = [title stringByAppendingFormat:@" %d", n];
		if ([menu itemWithTitle:possibleTitle] == nil)
			return possibleTitle;
	}
	return nil;
}

- (void)updateDestinationMenu
{
	// get our endpoint's uid
	MIDIUniqueID selectedEndpointUID = 0;
	BOOL foundSelectedDestination = NO;
	if (isDestinationConnected)
	{
		MIDIObjectGetIntegerProperty(selectedDestination, kMIDIPropertyUniqueID, &selectedEndpointUID);
	}
	
	// clean menu
	[destinationPopup removeAllItems];
	
	// insert the virtual source item
	[destinationPopup addItemWithTitle:NSLocalizedString(@"Virtual source", @"Virtual source")];
	
	if (!isDestinationConnected)
	{
		[destinationPopup selectItemAtIndex:0];
		foundSelectedDestination = YES;
	}
	
	// now insert all available midi destinations
	long i;
	ItemCount numDevices = MIDIGetNumberOfDestinations();
	
	// add a separator if there are any destinations
	if (numDevices > 0)
		[[destinationPopup menu] addItem:[NSMenuItem separatorItem]];
	
	NSInteger iOffset = [destinationPopup numberOfItems];
	for (i=iOffset; i<numDevices+iOffset; ++i)	// so i is equal to the last menu item
	{
		MIDIUniqueID endpointUID;
		MIDIEndpointRef theEndpoint = MIDIGetDestination(i - iOffset);
		MIDIObjectGetIntegerProperty(theEndpoint, kMIDIPropertyUniqueID, &endpointUID);
		
		// find a unique menu item name for the endpoint. it's possible that
		// two or more endpoints end up with the same name through our formatting,
		// so check the menu before trying to add the new item.
		NSString *endpointTitle = [self uniqueTitle:[self nameForMidiEndpoint:theEndpoint] forMenu:[destinationPopup menu]];
		[destinationPopup addItemWithTitle:endpointTitle];
		[[destinationPopup itemAtIndex:i] setRepresentedObject:[NSData dataWithBytes:&theEndpoint length:sizeof theEndpoint]];
		
		// if this endpoint matches the currently selected one, set the popup's selection
		if (isDestinationConnected && endpointUID == selectedEndpointUID && !foundSelectedDestination)
		{
			[destinationPopup selectItemAtIndex:i];
			foundSelectedDestination = YES;
		}
	}
	
	// the selected destination went away!
	if (!foundSelectedDestination && isDestinationConnected)
	{
		// go back to the virtual source
		[destinationPopup selectItemAtIndex:0];
		isDestinationConnected = NO;
	}
}

- (void)updateSourceMenu
{	
	// find selected source's uid
	MIDIUniqueID selectedEndpointUID = 0;
	if (isSourceConnected)
	{
		MIDIObjectGetIntegerProperty(selectedSource, kMIDIPropertyUniqueID, &selectedEndpointUID);
	}
	BOOL foundSelectedSource = NO;

	// clean menu
	[sourcePopup removeAllItems];
	[sourcePopup setEnabled:YES];
	
	[sourcePopup addItemWithTitle:NSLocalizedString(@"None", @"None")];
	[[sourcePopup menu] addItem:[NSMenuItem separatorItem]];
	
	// fill in menu with available sources
	ItemCount i, numDevices = MIDIGetNumberOfSources();
	for (i=0; i<numDevices; ++i)
	{
		MIDIUniqueID endpointUID;
		MIDIEndpointRef theEndpoint = MIDIGetSource(i);
		MIDIObjectGetIntegerProperty(theEndpoint, kMIDIPropertyUniqueID, &endpointUID);
		
		// don't show our own virtual source
		if (endpointUID == virtualSourceUID)
			continue;
			
		NSString *endpointTitle = [self uniqueTitle:[self nameForMidiEndpoint:theEndpoint] forMenu:[sourcePopup menu]];
		[sourcePopup addItemWithTitle:endpointTitle];
		NSInteger itemIndex = [sourcePopup numberOfItems] - 1;	// the last item in the menu
		[[sourcePopup itemAtIndex:itemIndex] setRepresentedObject:[NSData dataWithBytes:&theEndpoint length:sizeof theEndpoint]];
		
		// if this endpoint matches the currently selected one, set the popup's selection
		if (isSourceConnected && endpointUID == selectedEndpointUID && !foundSelectedSource)
		{
			[sourcePopup selectItemAtIndex:itemIndex];
			foundSelectedSource = YES;
		}
	}
	// handle empty source menu
	if ([sourcePopup numberOfItems] == 2)	// just None and separator
	{
		// disable menu, but make the None item show as selected
		[sourcePopup setEnabled:NO];
		[sourcePopup selectItemAtIndex:0];
		isSourceConnected = NO;
		
		// also disable the midi thru checkbox
		[midiThruCheckbox setEnabled:NO];
	}
	else if (isSourceConnected && !foundSelectedSource)
	{
		// if we couldn't find the connected source, select the first one
		[sourcePopup selectItemAtIndex:0];
		[self sourceSelected:nil];
		
		// also disable the midi thru checkbox
		[midiThruCheckbox setEnabled:NO];
	}
	else
	{
		// there was a selected item so enable the midi thru checkbox
		[midiThruCheckbox setEnabled:isSourceConnected];
	}
}

- (void)setupRegisteredDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// Build up the registered defaults dictionary.
	NSDictionary * defaultsDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
//		[NSColor /*colorWithCalibratedRed:kDefaultHighlightRed green:kDefaultHighlightGreen blue:kDefaultHighlightBlue alpha:1.0*/ greenColor], kHighlightColourPrefKey,
		[NSNumber numberWithFloat:(maxVelocity * 3.0 / 4.0)], kVelocityPrefKey, // 3/4 max velocity
		[NSNumber numberWithInt:1], kChannelPrefKey,
		[NSNumber numberWithInt:0], kOctaveOffsetPrefKey,
		[NSNumber numberWithFloat:kDefaultWindowTransparency], kWindowTransparencyPrefKey,
		[NSNumber numberWithInt:0], kHotKeysModifiersPrefKey,
		[NSNumber numberWithBool:NO], kUseHotKeysPrefKey,
		[NSNumber numberWithFloat:kDefaultVelocityHotKeyDelta], kVelocityHotKeyDeltaPrefKey,
		[NSNumber numberWithFloat:kDefaultVelocityRepeatInterval], kVelocityRepeatIntervalPrefKey,
		[NSNumber numberWithFloat:1.0], kOverlayTimeoutPrefKey,
		[NSNumber numberWithBool:YES], SHOW_HOT_KEYS_OVERLAYS_PREF_KEY,
		[NSNumber numberWithBool:YES], SHOW_OCTAVE_SHIFT_OVERLAYS_PREF_KEY,
		[NSNumber numberWithBool:YES], SHOW_VELOCITY_OVERLAYS_PREF_KEY,
		[NSNumber numberWithBool:YES], kShowKeyCapsPrefKey,
		nil, nil];
	
	[defaults registerDefaults:defaultsDefaults];
}

- (void)awakeFromNib
{
	// Need to tell Cocoa that we want to support alpha in colors.
	[NSColor setIgnoresAlpha:NO];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// Build up the registered defaults dictionary.
	maxVelocity = [velocitySlider maxValue];
	[self setupRegisteredDefaults];
	
	// set up midi
	MIDIClientCreate(kMyClientName, MyNotifyProc, (void *)self, &clientRef);
	MIDIOutputPortCreate(clientRef, kMyClientName, &outputPort);
	MIDIInputPortCreate(clientRef, kMyClientName, MyMidiReadProc, self, &inputPort);
	MIDISourceCreate(clientRef, kMyClientName, &virtualSourceEndpoint);
	
	// get the uid of our virtual source
	MIDIObjectGetIntegerProperty(virtualSourceEndpoint, kMIDIPropertyUniqueID, &virtualSourceUID);
	
	// MIDI thru
	performMidiThru = [defaults boolForKey:kMidiThruPrefKey];
	if (performMidiThru)
	{
		[midiThruCheckbox setIntValue:1];
	}
	
	// read selected destination and source from prefs
	selectedDestination = [defaults endpointForKey:kDestinationPrefKey];
	if (selectedDestination)
	{
		isDestinationConnected = YES;
	}
	selectedSource = [defaults endpointForKey:kSourcePrefKey];
	if (selectedSource)
	{
		// if connecting the source fails, fall back to our virtual source
		OSStatus err = MIDIPortConnectSource(inputPort, selectedSource, 0);
		if (err == noErr)
		{
			isSourceConnected = YES;
		}
		else
		{
			selectedSource = 0;
		}
	}
	
	// fill in popup menus
	[self updateDestinationMenu];
	[self updateSourceMenu];
	
	// set up the keys view
	midiKeys.delegate = self;
	NSColor *highlightColour = [defaults colorForKey:kHighlightColourPrefKey];
	if (!highlightColour)
	{
		highlightColour = [NSColor colorWithCalibratedRed:kDefaultHighlightRed green:kDefaultHighlightGreen blue:kDefaultHighlightBlue alpha:kDefaultHighlightTransparency];
		[defaults setColor:highlightColour forKey:kHighlightColourPrefKey];
	}
	
	[midiKeys setHighlightColour:highlightColour];
	[midiKeys setShowKeycaps:[defaults boolForKey:kShowKeyCapsPrefKey]];
	
	// set current velocity and channel
	currentVelocity = [defaults floatForKey:kVelocityPrefKey];
	[velocitySlider setFloatValue:currentVelocity];
	
	currentChannel = (int)[defaults integerForKey:kChannelPrefKey];
	[channelPopup selectItemWithTag:currentChannel - 1];
	
	octaveOffset = (int)[defaults integerForKey:kOctaveOffsetPrefKey];
	[midiKeys setOctaveOffset:octaveOffset];
	
	// set up the midi keys window
	[[midiKeys window] setDelegate:self];
	[[midiKeys window] setHidesOnDeactivate:NO];
	[[[midiKeys window] standardWindowButton:NSWindowMiniaturizeButton] setEnabled:YES];
	float windowTransparency = [defaults floatForKey:kWindowTransparencyPrefKey];

	// but don't actually set the window transparency if we're active (which we probably are at this time)
	if (!(makeWindowSolidWhenOnTop && [NSApp isActive]))
	{
	    [[midiKeys window] setAlphaValue:windowTransparency];
	}
	[self setWindowLevelFromPreferences];
	
	// toggled pref
	BOOL toggledPref = [defaults boolForKey:kIsWindowToggledPrefKey];
	if (toggledPref)
	{
		[self toggleMidiControls:nil];
	}
	
	makeWindowSolidWhenOnTop = [defaults boolForKey:kSolidOnTopPrefKey];
}

//! Finish the initialization that needs to be done after all the
//! -awakeFromNib calls have been made.
- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// create our key map object
	NSString *selectedKeyMap = [defaults stringForKey:kKeyMapPrefKey];
	if (!selectedKeyMap)
	{
		// no keymap preference, so select the first one and save it
		selectedKeyMap = [[keyMapManager allKeyMapNames] objectAtIndex:0];
		[defaults setObject:selectedKeyMap forKey:kKeyMapPrefKey];
	}
	keyMap = [[keyMapManager keyMapWithName:selectedKeyMap] retain];
	
	// now, with the keymap ready we can enable hotkeys
	[self registerToggleHotKey];
	if ([defaults boolForKey:kUseHotKeysPrefKey])
	{
		[self enableHotKeys];
	}
	
	// we're finally ready to show the window
	[[midiKeys window] setIsVisible:YES];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	// If hot keys are on by default, show the hot keys enabled overlay.
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kUseHotKeysPrefKey])
	{
		[self displayHotKeysOverlay];
	}
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	// remove hotkeys just to be safe
	if (hotKeysAreRegistered)
	{
		[keyMap unregisterHotKeys];
		[self unregisterOctaveHotKeys];
	}
	
	[self unregisterToggleHotKey];
	
	[velocityHotKeyTimer invalidate];
}

//! @brief The application has become the frontmost app.
- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if (makeWindowSolidWhenOnTop)
    {
		[[midiKeys window] setAlphaValue:1.0];
    }
	
	BOOL clickThrough = [[NSUserDefaults standardUserDefaults] boolForKey:kClickThroughPrefKey];
	if (clickThrough)
	{
		[self setClickThrough:NO];
	}

	// We set the keyboard window to the normal window level so that the preferences window can
	// be ordered in front of it when it's open. If the keyboard window was left floating, then
	// the prefs window could be obscured by the keyboard.
	NSWindow *mainWindow = [midiKeys window];
	[mainWindow setLevel:NSNormalWindowLevel];
}

//! @brief Another application has become the frontmost application.
- (void)applicationDidResignActive:(NSNotification *)notification
{
    if (makeWindowSolidWhenOnTop)
    {
		[[midiKeys window] setAlphaValue:[[NSUserDefaults standardUserDefaults] floatForKey:kWindowTransparencyPrefKey]];
	}
	
	BOOL clickThrough = [[NSUserDefaults standardUserDefaults] boolForKey:kClickThroughPrefKey];
	if (clickThrough)
	{
		[self setClickThrough:YES];
	}

	// Here we set the keyboard window's  window level to either normal or floating, depending
	// on the preferences. This ensures that the keyboard will float above other windows while
	// we're in the background (if that pref is set).
	[self setWindowLevelFromPreferences];
}

//! Closing the window quits the application.
//!
- (void)windowWillClose:(NSNotification *)notification
{
	[[NSApplication sharedApplication] terminate:self];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([[menuItem title] isEqualToString:NSLocalizedString(@"Octave Up", @"Octave Up")])
	{
		return octaveOffset < MAX_OCTAVE_OFFSET;
	}
	else if ([[menuItem title] isEqualToString:NSLocalizedString(@"Octave Down", @"Octave Down")])
	{
		return octaveOffset > MIN_OCTAVE_OFFSET;
	}
	
	return YES;
}

- (IBAction)destinationSelected:(id)sender
{
	// handle virtual source being selected
	if ([destinationPopup indexOfSelectedItem] == 0)
	{
		isDestinationConnected = NO;
		[[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kDestinationPrefKey];
		return;
	}
	
	// other endpoint was selected
	const MIDIEndpointRef *sourcePtr = (const MIDIEndpointRef *)[[[destinationPopup selectedItem] representedObject] bytes];
	if (sourcePtr == NULL)
		return;
	selectedDestination = *sourcePtr;
	isDestinationConnected = YES;
	
	// save destination in prefs
	[[NSUserDefaults standardUserDefaults] setEndpoint:selectedDestination forKey:kDestinationPrefKey];
}

- (IBAction)sourceSelected:(id)sender
{
	// disconnect previous source
	OSStatus err;
	if (isSourceConnected)
	{
		err = MIDIPortDisconnectSource(inputPort, selectedSource);
		if (err)
			NSLog(@"error disconnecting previous source from input port: %d", err);
	}
	
	id sourceObject = [[sourcePopup selectedItem] representedObject];
	if (sourceObject == nil)
	{
		// the None item
		[midiThruCheckbox setEnabled:NO];
		isSourceConnected = NO;
		selectedSource = 0;
		
		// get rid of the source preference
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:kSourcePrefKey];
		return;
	}
	
	const MIDIEndpointRef *sourcePtr = (const MIDIEndpointRef *)[sourceObject bytes];
	if (sourcePtr == NULL)
		return;
	selectedSource = *sourcePtr;
	
	err = MIDIPortConnectSource(inputPort, selectedSource, 0);
	if (err)
		return;
	isSourceConnected = YES;
	
	// make sure the thru checkbox is enabled
	[midiThruCheckbox setEnabled:YES];
	
	// save destination in prefs
	[[NSUserDefaults standardUserDefaults] setEndpoint:selectedSource forKey:kSourcePrefKey];
}

- (IBAction)velocitySliderChanged:(id)sender
{
	currentVelocity = [velocitySlider floatValue];
	// we don't want to ever actually play a velocity of 0
	if (currentVelocity == 0.0)
		currentVelocity = 1.0;
	// and setting the velocity in prefs to 0 will reset it to 3/4 on restart
	[[NSUserDefaults standardUserDefaults] setFloat:currentVelocity forKey:kVelocityPrefKey];
}

- (IBAction)channelDidChange:(id)sender
{
	currentChannel = (int)[channelPopup selectedTag] + 1;
	[[NSUserDefaults standardUserDefaults] setInteger:currentChannel forKey:kChannelPrefKey];
}

- (IBAction)toggleMidiThru:(id)sender
{
	performMidiThru = !performMidiThru;
	[midiThruCheckbox setIntValue:performMidiThru];
	
	// save preference
	[[NSUserDefaults standardUserDefaults] setBool:performMidiThru forKey:kMidiThruPrefKey];
}

- (float)overlayTimeout
{
	return [[NSUserDefaults standardUserDefaults] floatForKey:kOverlayTimeoutPrefKey];
}

- (void)overlayIndicatorDidClose:(OverlayIndicator *)theIndicator
{
	if (_indicator == theIndicator)
	{
		_indicator = nil;
	}
}

- (IBAction)octaveUp:(id)sender
{
	if (octaveOffset < MAX_OCTAVE_OFFSET)
	{
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
		
		octaveOffset++;
		[defaults setInteger:octaveOffset forKey:kOctaveOffsetPrefKey];
	
		[midiKeys setOctaveOffset:octaveOffset];
		
		if ([defaults boolForKey:SHOW_OCTAVE_SHIFT_OVERLAYS_PREF_KEY])
		{
			[_indicator close];
			_indicator = [[OverlayIndicator alloc] initWithImage:[NSImage imageNamed:kOctaveUpOverlayImage]];
			[_indicator setMessage:NSLocalizedString(@"Octave Up", nil)];
			[_indicator setDelegate:self];
			[_indicator showUntilDate:[NSDate dateWithTimeIntervalSinceNow:[self overlayTimeout]]];
		}
	}
}

- (IBAction)octaveDown:(id)sender
{
	if (octaveOffset > MIN_OCTAVE_OFFSET)
	{
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
		
		octaveOffset--;
		[defaults setInteger:octaveOffset forKey:kOctaveOffsetPrefKey];
		
		[midiKeys setOctaveOffset:octaveOffset];
		
		if ([defaults boolForKey:SHOW_OCTAVE_SHIFT_OVERLAYS_PREF_KEY])
		{
			[_indicator close];
			_indicator = [[OverlayIndicator alloc] initWithImage:[NSImage imageNamed:kOctaveDownOverlayImage]];
			[_indicator setMessage:NSLocalizedString(@"Octave Down", nil)];
			[_indicator setDelegate:self];
			[_indicator showUntilDate:[NSDate dateWithTimeIntervalSinceNow:[self overlayTimeout]]];
		}
	}
}

- (void)setWindowLevelFromPreferences
{
	int level;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kFloatWindowPrefKey])
	{
		level = NSModalPanelWindowLevel;
	}
	else
	{
		level = NSNormalWindowLevel;
	}
	[[midiKeys window] setLevel:level];
}

//! The prefs controller sends this when the prefs panel is closed.
//!
- (void)preferencesDidChange:(NSNotification *)notification
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// change window preferences
	makeWindowSolidWhenOnTop = [defaults boolForKey:kSolidOnTopPrefKey];
	
	[self setWindowLevelFromPreferences];
	if (!(makeWindowSolidWhenOnTop && [NSApp isActive]))
	{
	    [[midiKeys window] setAlphaValue:[defaults floatForKey:kWindowTransparencyPrefKey]];
	}
	else if (makeWindowSolidWhenOnTop && [NSApp isActive])
	{
		[[midiKeys window] setAlphaValue:1.0f];
	}
	
	// update key caps
	[midiKeys setShowKeycaps:[defaults boolForKey:kShowKeyCapsPrefKey]];
	
	// reload key map
	[keyMap release]; // will unregister this keymaps hotkeys
	keyMap = [[keyMapManager keyMapWithName:[defaults stringForKey:kKeyMapPrefKey]] retain];
	[midiKeys setNeedsDisplay:YES]; // redraw midi keys
	
	// Re-register hotkeys.
	[self unregisterToggleHotKey];
	[self registerToggleHotKey];
	
	if (hotKeysAreRegistered)
	{
		[self unregisterOctaveHotKeys];
	}
	
	if ([defaults boolForKey:kUseHotKeysPrefKey])
	{
		[self enableHotKeys];
	}
	
	// highlight colour
	NSColor *highlightColour = [defaults colorForKey:kHighlightColourPrefKey];
	[midiKeys setHighlightColour:highlightColour];
}

- (void)setClickThrough:(BOOL)clickThrough
{
	NSWindow *mainWindow = [midiKeys window];
	
	// carbon
	void *ref = [mainWindow windowRef];
	if (clickThrough)
	{
		ChangeWindowAttributes(ref, kWindowIgnoreClicksAttribute, kWindowNoAttributes);
	}
	else
	{
		ChangeWindowAttributes(ref, kWindowNoAttributes, kWindowIgnoreClicksAttribute);
	}
	
	// cocoa
	[mainWindow setIgnoresMouseEvents:clickThrough];
}

- (IBAction)toggleMidiControls:(id)sender
{
	// resize window
	NSWindow *window = [toggleView window];
	NSRect newFrame = [window frame];
	NSPoint newOrigin = [hiddenItemsView frame].origin;
	if (isWindowToggled)
	{
		// move items back into place first, so they appear as the window
		// is animated
		newOrigin.x = 0;
		[hiddenItemsView setFrameOrigin:newOrigin];
		
		// increase window size
		newFrame.size.height += toggleDelta;
		[window setFrame:newFrame display:YES animate:YES];
		
		isWindowToggled = NO;
	}
	else
	{
		// shrink window size
		toggleDelta = NSHeight([[window contentView] frame]) - NSHeight([toggleView frame]);
		
		newFrame.size.height -= toggleDelta;
		[window setFrame:newFrame display:YES animate:YES];
		
		// move items out of the way so they don't interfere with the title
		// bar when used for dragging (they will trap clicks in the title)
		newOrigin.x = NSWidth([window frame]);
		[hiddenItemsView setFrameOrigin:newOrigin];
		
		isWindowToggled = YES;
	}
	
	// save toggle preference
	[[NSUserDefaults standardUserDefaults] setBool:isWindowToggled forKey:kIsWindowToggledPrefKey];
}

@end

@implementation AppController (HotKeys)

- (IBAction)toggleHotKeys:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	// Enable or disable hot keys.
	BOOL isActive = [defaults boolForKey:kUseHotKeysPrefKey];
	if (isActive)
	{
		[self disableHotKeys];
	}
	else
	{
		[self enableHotKeys];
	}
	
	// Toggle defaults setting.
	[defaults setBool:!isActive forKey:kUseHotKeysPrefKey];
}

//! @brief Enables hot keys and updates UI to match.
- (void)enableHotKeys
{
	[self registerHotKeys];
	
	// Put a check mark on the hot keys menu item.
	[_toggleHotKeysMenuItem setState:NSOnState];
	
	// Add a status item indicating that hot keys are currently enabled.
//	NSStatusBar * bar = [NSStatusBar systemStatusBar];
//	NSImage * statusImage = [NSImage imageNamed:@"RemoveShortcutPressed.tif"];
//	_hotKeysStatusItem = [[bar statusItemWithLength:[statusImage size].width + 10.0] retain];
//	[_hotKeysStatusItem setImage:statusImage];
//	[_hotKeysStatusItem setToolTip:@"MidiKeys hot keys are enabled."];
//	[_hotKeysStatusItem setTarget:self];
//	[_hotKeysStatusItem setAction:@selector(toggleHotKeys:)];
	
	// Set a badge on the app icon in the dock.
	[[NSApp dockTile] setBadgeLabel:NSLocalizedString(@"HotKeyDockBadge", nil)];
}

//! @brief Disables hot keys are updates the UI to match.
- (void)disableHotKeys
{
	// Unregister hot keys.
	[self unregisterHotKeys];
	
	// Remove the check mark from the hot keys menu item.
	[_toggleHotKeysMenuItem setState:NSOffState];
	
	// Remove the status item.
//	if (_hotKeysStatusItem)
//	{
//		[[NSStatusBar systemStatusBar] removeStatusItem:_hotKeysStatusItem];
//		[_hotKeysStatusItem release];
//		_hotKeysStatusItem = nil;
//	}
	
	// Clear the app icon badge.
	[[NSApp dockTile] setBadgeLabel:nil];
}

- (void)registerToggleHotKey
{
	// Read the toggle hot key info from preferences.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary * toggleDict = [defaults dictionaryForKey:kToggleHotKeysShortcutPrefKey];
    if (!toggleDict)
    {
		return;
	}
	
	int modifiers = [[toggleDict objectForKey:SHORTCUT_FLAGS_KEY] intValue];
	int keycode = [[toggleDict objectForKey:SHORTCUT_KEYCODE_KEY] intValue];
	
	EventHotKeyID hotKeyID = { 0, 0 };
	OSStatus err = RegisterEventHotKey(keycode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &_toggleHotKeyRef);
	if (err)
	{
		NSLog(@"unable to register toggle hot key shortcut (err=%d)", err);
	}
}

- (void)unregisterToggleHotKey
{
	if (_toggleHotKeyRef)
	{
		UnregisterEventHotKey(_toggleHotKeyRef);
		_toggleHotKeyRef = NULL;
	}
}

- (void)registerHotKeys
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	// Get the modifier key.
	int modifiers = (int)[defaults integerForKey:kHotKeysModifiersPrefKey];
	
	// Register both note keys and control keys.
	[keyMap registerHotKeysWithModifiers:modifiers];
	[self registerOctaveHotKeysWithModifiers:modifiers];
}

- (void)unregisterHotKeys
{
	[self unregisterOctaveHotKeys];
	[keyMap unregisterHotKeys];
}

- (void)registerOctaveHotKeysWithModifiers:(int)modifiers
{
	OSStatus err1, err2, err3, err4;
	EventHotKeyID hotKeyID = { 0, 0 };
	
	// unregister previous hot keys if present, otherwise registering will fail
	[self unregisterOctaveHotKeys];
	
	err1 = RegisterEventHotKey(kRightArrowKeycode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &octaveUpHotKeyRef);
	if (err1)
		NSLog(@"octave up hot key could not be registered (err = %d)", err1);
		
	err2 = RegisterEventHotKey(kLeftArrowKeycode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &octaveDownHotKeyRef);
	if (err2)
		NSLog(@"octave down hot key could not be registered (err = %d)", err2);
	
	err3 = RegisterEventHotKey(kUpArrowKeycode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &velocityUpHotKeyRef);
	if (err3)
		NSLog(@"velocity up hot key could not be registered (err = %d)", err3);
	
	err4 = RegisterEventHotKey(kDownArrowKeycode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &velocityDownHotKeyRef);
	if (err4)
		NSLog(@"velocity down hot key could not be registered (err = %d)", err4);
	
	// only mark hot keys as registered if one of the keys was actually registered
	if (err1 == noErr || err2 == noErr || err3 == noErr || err4 == noErr)
		hotKeysAreRegistered = YES;
}

- (void)unregisterOctaveHotKeys
{
	if (octaveUpHotKeyRef)
	{
		UnregisterEventHotKey(octaveUpHotKeyRef);
		octaveUpHotKeyRef = NULL;
	}
	if (octaveDownHotKeyRef)
	{
		UnregisterEventHotKey(octaveDownHotKeyRef);
		octaveDownHotKeyRef = NULL;
	}
	if (velocityUpHotKeyRef)
	{
		UnregisterEventHotKey(velocityUpHotKeyRef);
		velocityUpHotKeyRef = NULL;
	}
	if (velocityDownHotKeyRef)
	{
		UnregisterEventHotKey(velocityDownHotKeyRef);
		velocityDownHotKeyRef = NULL;
	}
	
	hotKeysAreRegistered = NO;
}

- (void)handleVelocityKeyPressedUpOrDown:(int)upOrDown
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	float delta = [defaults floatForKey:kVelocityHotKeyDeltaPrefKey];
	
	// invert delta for down
	if (upOrDown == kVelocityDown)
	{
		delta *= -1.0;
	}
	
	[self adjustVelocity:delta];
	
	float interval = [defaults floatForKey:kVelocityRepeatIntervalPrefKey];
	
	// If we receive another velocity hot key down message before the
	// key up message, kill any previous timer.
	if (velocityHotKeyTimer)
	{
		[velocityHotKeyTimer invalidate];
	}
	velocityHotKeyTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(velocityHotKeyTimerFired:) userInfo:[NSMutableDictionary dictionaryWithObject:[NSNumber numberWithFloat:delta] forKey:@"Delta"] repeats:YES];
}

- (void)velocityHotKeyTimerFired:(NSTimer *)timer
{
	float delta = [[[timer userInfo] objectForKey:@"Delta"] floatValue];
	[self adjustVelocity:delta];
	
	// Increment delta every time the timer fires
	delta *= 1.3f;
	[[timer userInfo] setObject:[NSNumber numberWithFloat:delta] forKey:@"Delta"];
}

- (void)handleVelocityKeyReleased
{
	[velocityHotKeyTimer invalidate];
	velocityHotKeyTimer = nil;
}

//! @brief Present the hot keys enabled/disabled notification overlay.
//!
//! Whether the message says "Enabled" or "Disabled" depends on the current state of the @a
//! #hotKeysAreRegistered member variable, with true causing the message to say "Enabled".
//! This means that this method should be called after changing the hot keys state.
- (void)displayHotKeysOverlay
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SHOW_HOT_KEYS_OVERLAYS_PREF_KEY])
	{
		[_indicator close];
		_indicator = [[OverlayIndicator alloc] initWithImage:[NSImage imageNamed:@"Octave.png"]];
		[_indicator setMessage:hotKeysAreRegistered ? NSLocalizedString(@"Hot Keys Enabled", nil) : NSLocalizedString(@"Hot Keys Disabled", nil)];
		[_indicator setDelegate:self];
		[_indicator showUntilDate:[NSDate dateWithTimeIntervalSinceNow:[self overlayTimeout]]];
	}
}

//! @brief Handle a hot key event.
- (void)hotKeyPressed:(uintptr_t)identifier
{
	if (identifier == (uintptr_t)_toggleHotKeyRef)
	{
		[self toggleHotKeys:self];

		// Show an overlay indicator to tell the user that hot keys were toggled.
		// This isn't done in toggleHotKeys because we only want to show the overlay
		// in response to the toggle hot key itself, not the hot keys menu item.
		[self displayHotKeysOverlay];
	}
	else if (identifier == (uintptr_t)octaveUpHotKeyRef)
	{
		[self octaveUp:nil];
	}
	else if (identifier == (uintptr_t)octaveDownHotKeyRef)
	{
		[self octaveDown:nil];
	}
	else if (identifier == (uintptr_t)velocityUpHotKeyRef)
	{
		[self handleVelocityKeyPressedUpOrDown:kVelocityUp];
	}
	else if (identifier == (uintptr_t)velocityDownHotKeyRef)
	{
		[self handleVelocityKeyPressedUpOrDown:kVelocityDown];
	}
	else
	{
		// look up note number
		int midiNote = (int)[keyMap midiNoteForHotKeyWithIdentifier:identifier] + octaveOffset * 12;
		
		// send the note
		int channel = currentChannel - 1;
		int velocity = (unsigned char)(0x7f * currentVelocity / maxVelocity);
		[self sendMidiNote:midiNote channel:channel velocity:velocity];
		
		// update the key view
		[midiKeys turnMidiNoteOn:midiNote];
	}
}

- (void)hotKeyReleased:(uintptr_t)identifier
{
	if (identifier == (uintptr_t)octaveUpHotKeyRef || identifier == (uintptr_t)octaveDownHotKeyRef)
	{
		// do nothing
	}
	else if (identifier == (uintptr_t)velocityUpHotKeyRef)
	{
		[self handleVelocityKeyReleased];
	}
	else if (identifier == (uintptr_t)velocityDownHotKeyRef)
	{
		[self handleVelocityKeyReleased];
	}
	else
	{
		// look up note number
		int midiNote = [keyMap midiNoteForHotKeyWithIdentifier:identifier] + octaveOffset * 12;
		
		// send the note
		int channel = currentChannel - 1;
		[self sendMidiNote:midiNote channel:channel velocity:0];
		
		// update the key view
		[midiKeys turnMidiNoteOff:midiNote];
	}
}

@end

@implementation AppController (MIDI)

- (NSString *)nameForMidiEndpoint:(MIDIEndpointRef)theEndpoint
{
	MIDIEntityRef theEntity = 0;
	MIDIDeviceRef theDevice = 0;
	NSString *endpointName = nil;
	NSString *deviceName = nil;
	NSString *entityName = nil;
	
	if (theEndpoint)
	{
		MIDIObjectGetStringProperty(theEndpoint, kMIDIPropertyName, (CFStringRef *)&endpointName);
		MIDIEndpointGetEntity(theEndpoint, &theEntity);
		if (theEntity)
		{
			MIDIObjectGetStringProperty(theEntity, kMIDIPropertyName, (CFStringRef *)&entityName);
			MIDIEntityGetDevice(theEntity, &theDevice);
			if (theDevice)
				MIDIObjectGetStringProperty(theDevice, kMIDIPropertyName, (CFStringRef *)&deviceName);
		}
	}
	
	NSString *name = nil;
	if (endpointName)
	{
		if (deviceName)
			name = [NSString stringWithFormat:@"%@: %@", deviceName, endpointName];
		else if (entityName)
			name = [NSString stringWithFormat:@"%@: %@", entityName, endpointName];
		else
			name = [[endpointName retain] autorelease];
	}
	else if (deviceName)
		name = [[deviceName retain] autorelease];
	else if (entityName)
		name = [[entityName retain] autorelease];
	
	// these aren't autoreleased since we got them from CoreMIDI
	[endpointName release];
	[deviceName release];
	[entityName release];
	return name;
}

- (void)handleMidiNotification:(const MIDINotification *)message
{
//	NSLog(@"midi noticfication: %d", message->messageID);
	// update popup menus when the sources or destinations change
	switch(message->messageID)
	{
		case kMIDIMsgSetupChanged:
			[self updateDestinationMenu];
			[self updateSourceMenu];
			break;
		case kMIDIMsgObjectAdded:
		case kMIDIMsgObjectRemoved:
		case kMIDIMsgPropertyChanged:
		case kMIDIMsgSerialPortOwnerChanged:
		case kMIDIMsgThruConnectionsChanged:
		default:
		{
			// ignore
		}
	}
}

//! Use the key map object to map keypresses to MIDI notes, which are
//! then sent out the selected MIDI port.
- (void)processMidiKeyWithCode:(int)keycode turningOn:(BOOL)isTurningOn
{
	// map the key
	int midiNote = [keyMap midiNoteForKeyCode:keycode];
	if (midiNote == -1)	// the key did not match
	{
		// handle arrow keys
		switch (keycode)
		{
			case kRightArrowKeycode:
				if (isTurningOn)
				{
					[self octaveUp:nil];
				}
				break;
				
			case kLeftArrowKeycode:
				if (isTurningOn)
				{
					[self octaveDown:nil];
				}
				break;
			
			case kUpArrowKeycode:
				if (isTurningOn)
				{
					[self handleVelocityKeyPressedUpOrDown:kVelocityUp];
				}
				else
				{
					[self handleVelocityKeyReleased];
				}
				break;
			
			case kDownArrowKeycode:
				if (isTurningOn)
				{
					[self handleVelocityKeyPressedUpOrDown:kVelocityDown];
				}
				else
				{
					[self handleVelocityKeyReleased];
				}
				break;
		}
		return;
	}
	midiNote += octaveOffset * 12;	// adjust octave
//	NSLog(@"midiNote = %d\n", (int)midiNote);
	
	// send the note
	int channel = currentChannel - 1;
	int velocity;
	if (isTurningOn)
		velocity = (unsigned char)(0x7f * currentVelocity / maxVelocity);
	else
		velocity = 0;
	[self sendMidiNote:midiNote channel:channel velocity:velocity];
	
	// update the key view
	if (isTurningOn)
		[midiKeys turnMidiNoteOn:midiNote];
	else
		[midiKeys turnMidiNoteOff:midiNote];
}

- (void)processMidiKeyClickWithNote:(int)note turningOn:(BOOL)isTurningOn
{
//	NSLog(@"note=%d", note);

	// send the note
	int midiNote = note;// + octaveOffset * 12;	// adjust octave
	int channel = currentChannel - 1;
	int velocity;
	if (isTurningOn)
		velocity = (unsigned char)(0x7f * currentVelocity / maxVelocity);
	else
		velocity = 0;
	[self sendMidiNote:midiNote channel:channel velocity:velocity];
	
	// update the key view
	if (isTurningOn)
		[midiKeys turnMidiNoteOn:note];
	else
		[midiKeys turnMidiNoteOff:note];
}

//! Send a MIDI note on event out the virtual source or our output port.
//! A velocity of 0 is used to send a note off event.
- (void)sendMidiNote:(int)midiNote channel:(int)channel velocity:(int)velocity
{
	// send the midi note on out our virtual source
	MIDIPacketList packetList;
	MIDIPacket *packetPtr = MIDIPacketListInit(&packetList);
	unsigned char midiData[3];
	midiData[0] = 0x90 | channel;
	midiData[1] = midiNote;
	midiData[2] = velocity;
	packetPtr = MIDIPacketListAdd(&packetList, sizeof packetList, packetPtr, AudioGetCurrentHostTime(), 3, (const Byte *)&midiData);
	if (packetPtr)
	{
		if (isDestinationConnected)
		{
			// send over output port
			MIDISend(outputPort, selectedDestination, &packetList);
		}
		else
		{
			// send over virtual source
			MIDIReceived(virtualSourceEndpoint, &packetList);
		}
	}
}

//! We need an autorelease pool because this method can be called from a CoreMIDI thread
//! where no pool has previously been set up. The exception handler is just in case, so
//! we can always dispose of the pool, and to keep Cocoa exceptions from travelling up
//! into the CoreMIDI thread.
- (void)receiveMidiPacketList:(const MIDIPacketList *)packetList
{
	NSAutoreleasePool *pool = nil;
	@try
	{
		pool = [[NSAutoreleasePool alloc] init];
		
		// handle MIDI thru
		if (performMidiThru)
		{
			if (isDestinationConnected)
			{
				// send over output port
				MIDISend(outputPort, selectedDestination, packetList);
			}
			else
			{
				// send over virtual source
				MIDIReceived(virtualSourceEndpoint, packetList);
			}
		}
		
		// process the received packet
		MidiParser *parser = [MidiParser parserWithMidiPacketList:packetList];
		MIDIPacket *packet;
		while ((packet = [parser nextMidiPacket]))
		{
			// handle note on and off for any channel
			if (packet->length == 3)
			{
				int note = packet->data[1];
				switch (packet->data[0] & 0xf0)
				{
					case 0x90:
						if (packet->data[2] > 0)
						{
							// note on
							[midiKeys turnMidiNoteOn:note];
						}
						else
						{
							// velocity 0 == note off
							[midiKeys turnMidiNoteOff:note];
						}
						break;
						
					case 0x80:
						[midiKeys turnMidiNoteOff:note];
						break;
				}
			}
		}
	}
	@finally
	{
		[pool release];
	}
}

- (void)adjustVelocity:(float)delta
{
	float newVelocity = currentVelocity;
	newVelocity += delta;
	if (newVelocity < 0.0)
	{
		newVelocity = 0.0;
	}
	else if (newVelocity > maxVelocity)
	{
		newVelocity = maxVelocity;
	}
	[velocitySlider setFloatValue:newVelocity];
	[self velocitySliderChanged:nil];
}

//! Send note off commands for every MIDI note, on every channel.
//!
- (IBAction)sendAllNotesOff:(id)sender
{
	int note;
	int channel;
	for (channel=0; channel < 16; ++channel)
	{
		for (note=0; note < 128; ++note)
		{
			[self sendMidiNote:note channel:channel velocity:0];
		}
	}
}

//! Uses the key map to convert a MIDI note into the Unicode character that
//! must be typed to play that note. The actual character depends on the
//! currently selected keyboard in the system Keyboard menu.
- (NSString *)characterForMidiNote:(int)note
{
	return [keyMap characterForMidiNote:note];
}

@end


//! Just pass the notification along to the objc method.
//!
void MyNotifyProc(const MIDINotification *message, void *refCon)
{
	AppController *controller = (AppController *)refCon;
	[controller handleMidiNotification:message];
}

void MyMidiReadProc(const MIDIPacketList *pktlist, void *refCon, void *connRefCon)
{
	AppController *controller = (AppController *)refCon;
	[controller receiveMidiPacketList:pktlist];
}

