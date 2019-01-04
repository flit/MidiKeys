//
//  PreferencesController.h
//  MidiKeys
//
//  Created by Chris Reed on Sat Oct 26 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Preferences.h"
#import <ShortcutRecorder/SRRecorderControl.h>

/*!
 * @brief Manages the preferences panel.
 */
@interface PreferencesController : NSWindowController <SRRecorderControlDelegate>
{
	IBOutlet NSWindow * _prefsWindow;
	IBOutlet NSPopUpButton *keymapPopup;
	IBOutlet NSColorWell *highlightColourWell;
	IBOutlet NSButton *useHotKeysCheckbox;
	IBOutlet NSButton *floatWindowCheckbox;
	IBOutlet NSSlider *windowTransparencySlider;
	IBOutlet NSButton *controlModifierCheckbox;
	IBOutlet NSButton *shiftModifierCheckbox;
	IBOutlet NSButton *optionModifierCheckbox;
	IBOutlet NSButton *commandModifierCheckbox;
	IBOutlet NSButton *solidOnTopCheckbox;
	IBOutlet NSButton * showKeyCapsCheckbox;
    IBOutlet NSButton * _showCNotesCheckbox;
    IBOutlet NSButton * _forceLightModeCheckbox;
	IBOutlet NSButton * _clickThroughCheckbox;
	IBOutlet SRRecorderControl * _toggleHotKeysShortcut;
    IBOutlet NSButton * _hotKeysOverlaysCheckbox;
    IBOutlet NSButton * _octaveShiftOverlaysCheckbox;
    IBOutlet NSButton * _velocityOverlaysCheckbox;
    IBOutlet id delegate;   //!< Preferences controller delegate.
}

@property(nonatomic, assign) id delegate;   //!< Preferences controller delegate.

+ sharedInstance;

- init;

- (void)showPanel:(id)sender;
- (void)updateWindow;
- (BOOL)commitChanges;

- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;

- (IBAction)keyboardFloatsDidChange:(id)sender;

@end

@protocol PreferencesControllerDelegate

- (void)preferencesDidChange:(id)sender;

@end

// Notification
extern NSString *kPreferencesChangedNotification;

