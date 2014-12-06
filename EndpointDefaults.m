//
//  EndpointDefaults.m
//  MidiKeys
//
//  Created by Chris Reed on Wed Oct 23 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import "EndpointDefaults.h"


@implementation NSUserDefaults (EndpointDefaults)

- (MIDIEndpointRef)endpointForKey:(NSString *)key
{
	MIDIUniqueID endpointUID = [self integerForKey:key];
	if (endpointUID != 0)
	{
		MIDIObjectType objType;
		MIDIObjectRef obj;
		OSStatus err = MIDIObjectFindByUniqueID(endpointUID, &obj, &objType);
		if (err == noErr && (objType == kMIDIObjectType_Destination
				|| objType == kMIDIObjectType_ExternalDestination
				|| objType == kMIDIObjectType_Source
				|| objType == kMIDIObjectType_ExternalSource))
		{
			return (MIDIEndpointRef)obj;
		}
	}
	return 0;
}

- (void)setEndpoint:(MIDIEndpointRef)endpoint forKey:(NSString *)key
{
	MIDIUniqueID endpointUID;
	OSStatus err = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &endpointUID);
	if (err == noErr)
	{
		[self setInteger:endpointUID forKey:key];
	}
}

@end



