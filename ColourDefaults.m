//
//  ColourDefaults.mm
//  MidiKeys
//
//  Created by Chris Reed on Sat Oct 26 2002.
//  Copyright (c) 2002 Chris Reed. All rights reserved.
//

#import "ColourDefaults.h"


@implementation NSUserDefaults (ColourDefaults)

// save color as a string with the components separated by spaces
- (NSColor *)colorForKey:(NSString *)key
{
	NSString *colorString = [self stringForKey:key];
	if (!colorString)
		return nil;
		
	NSArray *componentArray = [colorString componentsSeparatedByString:@" "];
	if ([componentArray count] != 4)
		return nil;
	
	id components[4];
	[componentArray getObjects:(id *)&components]; // we know the length is 4
	return [NSColor colorWithCalibratedRed:[components[0] floatValue] green:[components[1] floatValue] blue:[components[2] floatValue] alpha:[components[3] floatValue]];
}

- (void)setColor:(NSColor *)theColor forKey:(NSString *)key
{
	NSString *colorString = [NSString stringWithFormat:@"%g %g %g %g", [theColor redComponent], [theColor greenComponent], [theColor blueComponent], [theColor alphaComponent]];
	[self setObject:colorString forKey:key];
}

@end

