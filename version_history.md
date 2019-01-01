### Version 1.9
- MidiKeys is now 64-bit compliant. (And no longer a universal binary.)
- Minimum system version is 10.9.
- Keys window is resizable (probably the most asked-for feature request).
- Support for dark mode in Mojave, including a dark mode keyboard. A "force light keyboard" preference is visible in Mojave to allow you to revert the keyboard to a traditional appearance.
- Added Clear Stuck Keys command.
- On systems with a trackpad or mouse that reports pressure, MidiKeys will send channel aftertouch when keys are clicked and held.
- New "show C notes" feature that draws "Cn" where "n" is the octave (i.e., C3, C4, etc) on the keyboard.
- Fixed an issue with key caps where certain keys like tab and delete were not shown; they will now appear as the standard key icons.
- Enabled app sandbox and the hardened runtime.
- Changed version update feed URL to https.
- Updated Sparkle and ShortcutRecorder frameworks to modern versions.

### Version 1.8
- MidiKeys is now a universal binary.
- Minimum system is now 10.5.
- Changed ownership to Immo Software.
- New configurable hot key to toggle global hot keys.
- Support for automatic software updates using the Sparkle framework.
- New option to show the key caps on the on-screen keyboard.
- The MIDI channel field has been changed to a pop-up menu.
- The disclosure button to show the destination and listen menus is now a normal button instead of being a repurposed toolbar toggle button.
- Pressed key highlights are drawn with a slight gradient.
- New Global Hot Keys menu item.
- New preferences to control the visibility of overlay notifications.
- It is now possible to have no modifier key for global hot keys, so you only have to press the key corresponding to the note.
- Key maps were extended to use more keys on the keyboard.
- Non-English localisations have been disabled for this release due to the number of UI changes.
- Added a preference to make the keyboard window transparent to mouse clicks when MidiKeys is in the background.
- Made the keyboard window minimizable.
- Reorganized the preferences window with several tabs.
- Added preferences to control software updates.

### Version 1.7b1
- Support for 10.4.

### Version 1.6b3
- Increased the octave offset range to -4 through +4 to encompass more MIDI notes
- Added Spanish localisation
- MIDI through should work now (it works on my system)

### Version 1.6b2
- The previous beta accidentally had all but the Japanese localisations included but turned off.
- Fixed a bug where the velocity hotkey could get stuck.
- Updated the LiesMich and Lisez-Moi.

### Version 1.6b1
- Added a button to the keyboard window's title bar that will hide and show the MIDI options (destination and source).
- The octave offset is shown visually through up and down arrow icons.
- Added a MIDI through option for the source. (May be broken in this release.)
- New icon! This one is much better. To see it, you have to log out and log back in.
- French and Japanese localisations.
- A preference to make the keyboard window opaque when MidiKeys is the frontmost application.
- The keyboard window will not float above other windows while the Preferences panel is open.
- Added Full Reversed and Upper Single keymaps.
- Added Send All Notes Off command to Keys menu.
- The left and right arrow keys in combination with the modifier keys set in the preferences now work as hot keys for octave up and octave down.
- Similiarly, the up and down arrow keys are hot keys for increasing and decreasing the velocity.
- Added a "None" option to the Listen to port popup menu.
- Fixed the black keys, the number keys on the computer keyboard, for the upper octave of the Full keymap.

### Version 1.5
- Added preferences panel.
- Global hot keys option.
- Option to float window above all applications.
- Changed how keypresses are detected, so it works with non-US keyboards.
- Added German localisation.
- Supports clicking on the keyboard!
- Many more new features and changes...

### Version 1.1.1
- Fixed a problem with the name of the first destination in the destination popup.

### Version 1.1
- Changed to textured window style.
- Added destination menu.
- Saves source and destination in prefs.
- Saves window position in prefs.
- Fixed many bugs.

### Version 1.0.1
- Oops! I forgot to support NoteOff events, since the controller I was testing with, an Oxygen8, sends NoteOn with velocity instead.
