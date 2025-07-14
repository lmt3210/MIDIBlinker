//
// LTPrefs.m
//
// Copyright (c) 2020-2025 Larry M. Taylor
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software. Permission is granted to anyone to
// use this software for any purpose, including commercial applications, and to
// to alter it and redistribute it freely, subject to 
// the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source
//    distribution.
//

#import <CoreMIDI/CoreMIDI.h>

#import "LTPrefs.h"

@implementation LTPrefs

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Populate input list
    [self updateMIDIInputs];
}

- (id)init
{
    self = [super initWithWindowNibName:@"LTPrefs"];
    
    // Create a log object
    mLog = os_log_create("com.larrymtaylor.MIDIBlinker", "Prefs");
    
    // Initialize variables
    mMIDIInputName = [[NSString alloc] init];
    mMIDIInputName = @"None";
    mMIDIChannel = [NSNumber numberWithInteger:1];
    
    return self;
}

- (IBAction)iaMIDIInput:(id)sender
{
    NSString *inputName = (NSString *)[uiMIDIInput titleOfSelectedItem];
    mMIDIInputName = [inputName copy];
}

- (NSDictionary *)settings
{
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
        mMIDIInputName, @"MIDI Input", mMIDIChannel, @"MIDI Channel", nil];

    return settings;
}

- (void)setSettings:(NSDictionary *)settings
{
    mMIDIInputName = [settings objectForKey:@"MIDI Input"];
    mMIDIInputName = (mMIDIInputName == nil) ? @"None" : mMIDIInputName;
    [uiMIDIInput selectItemWithTitle:mMIDIInputName];
    mMIDIChannel = [settings objectForKey:@"MIDI Channel"];
    mMIDIChannel = (mMIDIChannel == nil) ? [NSNumber numberWithInteger:1] :
                   mMIDIChannel;
    [uiMIDIChannel setStringValue:[mMIDIChannel stringValue]];
}

- (long)midiIndex
{
    long index = ([uiMIDIInput indexOfItemWithTitle:mMIDIInputName] - 1);
    return index;
}

- (void)updateMIDIInputs
{
    [uiMIDIInput removeAllItems];
    [uiMIDIInput addItemWithTitle:@"None"];
    
    ItemCount sourceCount = MIDIGetNumberOfSources();
    
    for (ItemCount i = 0 ; i < sourceCount; i++)
    {
        MIDIEndpointRef source = MIDIGetSource(i);
        
        if (source != (MIDIEndpointRef)0)
        {
            CFStringRef name = nil;
            OSStatus err = MIDIObjectGetStringProperty(source,
                               kMIDIPropertyDisplayName, &name);
            
            if (err == (OSStatus)noErr)
            {
                [uiMIDIInput addItemWithTitle:(__bridge NSString *)name];
            }
        }
    }
    
    [uiMIDIInput selectItemWithTitle:mMIDIInputName];
}

@end
