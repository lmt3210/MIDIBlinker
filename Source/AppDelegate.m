//
// AppDelegate.m
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
//

#import <CoreMIDI/CoreMIDI.h>

#import "AppDelegate.h"

#define UDKEY_SETTINGS_LIST   @"MIDIBlinkerSettings"

// This callback happens on the main thread, so ok to use notifications
void midiNotifyProc(const MIDINotification *message, void *refCon)
{
    if (message->messageID == kMIDIMsgSetupChanged)
    {
        [[NSNotificationCenter defaultCenter]
          postNotificationName:@"MIDINotification" object:nil];
    }
}

// This callback happens on a separate, high-priority thread
void midiReadProc(const MIDIPacketList *inPktList, void *refCon,
                  void *connRefCon)
{
    struct midiControl *mc = (struct midiControl *)refCon;
    MIDIPacket *inPacket = (MIDIPacket *)inPktList->packet;
    
    for (int i = 0; i < inPktList->numPackets; i++)
    {
        UInt16 inPacketLength = inPacket->length;
        
        for (int j = 0; j < inPacketLength;)
        {
            Byte status = inPacket->data[j];
            Byte message = status & 0xF0;
            Byte channel = status & 0x0F;
            UInt16 eventLength = inPacketLength;
            
            switch (message)
            {
                case MIDI_NOTE_OFF:
                    
                    if ((channel == mc->channel) || (mc->channel == -1))
                    {
                        mc->midiData[mc->writeIndex].data[1] = 0;
                        mc->midiData[mc->writeIndex].data[2] = 0;
                        mc->writeIndex++;
                
                        if (mc->writeIndex == kMaximumEvents)
                        {
                            mc->writeIndex = 0;
                        }
                    }
        
                    eventLength = 3;
                    break;
                case MIDI_AFTER_TOUCH:
                    eventLength = 3;
                    break;
                case MIDI_NOTE_ON:
                    
                    if ((channel == mc->channel) || (mc->channel == -1))
                    {
                        mc->midiData[mc->writeIndex].data[1] =
                            inPacket->data[j + 1];
                        mc->midiData[mc->writeIndex].data[2] =
                            inPacket->data[j + 2];
                        mc->writeIndex++;
                
                        if (mc->writeIndex == kMaximumEvents)
                        {
                            mc->writeIndex = 0;
                        }
                    }
        
                    eventLength = 3;
                    break;
                case MIDI_SET_PARAMETER:
                case MIDI_PITCH_WHEEL:
                    eventLength = 3;
                    break;
                case MIDI_SET_PROGRAM:
                case MIDI_SET_PRESSURE:
                    eventLength = 2;
                    break;
                case MIDI_SYSTEM_MSG:

                    switch (status)
                    {
                        case MIDI_SYSEX:
                            eventLength = inPacketLength;
                            break;
                        case MIDI_TCQF:
                        case MIDI_SONG_SELECT:
                            eventLength = 2;
                            break;
                        case MIDI_SONG_POS:
                            eventLength = 3;
                            break;
                        case MIDI_CLOCK:
                        case MIDI_ACTIVE_SENSE:
                        case MIDI_EOX:
                        case MIDI_TUNE_REQ:
                        case MIDI_SEQ_START:
                        case MIDI_SEQ_CONTINUE:
                        case MIDI_SEQ_STOP:
                        case MIDI_SYS_RESET:
                            eventLength = 1;
                            break;
                    }

                    break;
             }
            
             j += eventLength;
        }
            
        inPacket = MIDIPacketNext(inPacket);
    }
}

@implementation AppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
     // Create a log object
      mLog = os_log_create("com.larrymtaylor.MIDIBlinker", "AppDelegate");

     // Create the preferences controller
     mPreferences = [[LTPrefs alloc] init];
     
     // Watch for preferences panel close
     [[NSNotificationCenter defaultCenter] addObserver:self
         selector:@selector(preferencesPanelClose:)
         name:NSWindowWillCloseNotification object:[mPreferences window]];
    
    // Set up for handling MIDI events
    mMIDIControl.readIndex = 0;
    mMIDIControl.writeIndex = 0;
    mMIDITimer = [NSTimer scheduledTimerWithTimeInterval:0.001
                  target:self selector:@selector(MIDITimer:)
                  userInfo:nil repeats:YES];
    
    // Initialize variables
    mMIDIInputName = [[NSString alloc] init];
    mMIDIChannel = [NSNumber numberWithInteger:1];
    
    // Initialize colors
    [self setColors];
    
    // Load the last setup
    [self loadSettings];
    
    // Setup MIDI
    [self setupMIDI];
    [self setMIDIInput];
    
    // Watch for main window close
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(blinkWillClose:)
        name:NSWindowWillCloseNotification object:[self window]];
    
    // Set starting background color
    [window setBackgroundColor:mColors[0]];
    
    // Version check
    NSBundle *appBundle = [NSBundle mainBundle];
    NSDictionary *appInfo = [appBundle infoDictionary];
    NSString *appVersion =
        [appInfo objectForKey:@"CFBundleShortVersionString"];
    mVersionCheck = [[LTVersionCheck alloc] initWithAppName:@"MIDIBlinker"
                     withAppVersion:appVersion
                     withLogHandle:mLog withLogFile:@""];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)inSender
{
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self cleanup];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    return TRUE;
}

- (void)blinkWillClose:(NSNotification *)aNotification
{
    [self cleanup];
}

- (void)cleanup
{
    [self saveSettings];
    
    // Stop notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Stop timer
    if (mMIDITimer)
    {
        [mMIDITimer invalidate];
        mMIDITimer = nil;
    }
    
    // Disconnect MIDI input
    if (mMIDIInPort && mMIDISource)
    {
        OSStatus err = MIDIPortDisconnectSource(mMIDIInPort, mMIDISource);

        if (err != noErr)
        {
            LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
                  @"MIDIPortDisconnectSource error = %i (%@)",
                  err, statusToString(err));
        }
    }
}

- (IBAction)showPreferencePanel:(id)sender
{
    [mPreferences showWindow:self];
}

- (void)preferencesPanelClose:(NSNotification *)aNotification
{
    NSDictionary *settings = [mPreferences settings];
    mMIDIInputName = [settings objectForKey:@"MIDI Input"];
    mMIDIChannel = [settings objectForKey:@"MIDI Channel"];
    mMIDIControl.channel = [mMIDIChannel intValue] - 1;
    [self setMIDIInput];
    [self saveSettings];
}

- (void)loadSettings
{
    NSUserDefaults *userDefaults =
          [[NSUserDefaultsController sharedUserDefaultsController] values];

    if ([userDefaults valueForKey:UDKEY_SETTINGS_LIST] != nil)
    {
        NSDictionary *settings = [userDefaults
                                  valueForKey:UDKEY_SETTINGS_LIST];
        mMIDIInputName = [settings objectForKey:@"MIDI Input"];
        mMIDIInputName = (mMIDIInputName == nil) ? @"None" : mMIDIInputName;
        mMIDIChannel = [settings objectForKey:@"MIDI Channel"];
        mMIDIChannel = (mMIDIChannel == nil) ? [NSNumber numberWithInteger:1] :
                       mMIDIChannel;
        mMIDIControl.channel = [mMIDIChannel intValue] - 1;
        [mPreferences setSettings:settings];
    }
}

- (void)saveSettings
{
    NSUserDefaults *userDefaults =
        [[NSUserDefaultsController sharedUserDefaultsController] values];
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
        mMIDIInputName, @"MIDI Input", mMIDIChannel, @"MIDI Channel", nil];
    [userDefaults setValue:settings forKey:UDKEY_SETTINGS_LIST];
}

- (void)setupMIDI
{
    OSStatus err = statusErr;
    
    err = MIDIClientCreate(CFSTR("MIDIBlinkerMIDI"), midiNotifyProc,
                           &mMIDIControl, &mMIDIClient);
    
    if (err != noErr)
    {
        LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
              @"MIDIClientCreate error = %i (%@)", err, statusToString(err));
    }
    
    err = MIDIInputPortCreate(mMIDIClient, CFSTR("Input port"), midiReadProc,
                              &mMIDIControl, &mMIDIInPort);
    
    if (err != noErr)
    {
        LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
              @"MIDIInputPortCreate error = %i (%@)",
              err, statusToString(err));
    }
}

- (void)setMIDIInput
{
    long index = [mPreferences midiIndex];
    
    if (index != -1)
    {
        OSStatus err = statusErr;
        
        if (mMIDIInPort && mMIDISource)
        {
            err = MIDIPortDisconnectSource(mMIDIInPort, mMIDISource);
            
            if (err != noErr)
            {
                LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
                      @"MIDIPortDisconnectSource error = %i (%@)", err,
                      statusToString(err));
            }
        }
        
        if (mMIDIInPort)
        {
            mMIDISource = MIDIGetSource(index);
            err = MIDIPortConnectSource(mMIDIInPort, mMIDISource, NULL);
            
            if (err != noErr)
            {
                LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
                      @"MIDIPortConnectSource error = %i (%@)",
                      err, statusToString(err));
            }
        }
    }
}

- (void)MIDITimer:(NSTimer *)timer
{
    while (mMIDIControl.readIndex != mMIDIControl.writeIndex)
    {
        Byte data1 = mMIDIControl.midiData[mMIDIControl.readIndex].data[1];
        Byte data2 = mMIDIControl.midiData[mMIDIControl.readIndex].data[2];
        
        if ((data1 == 0) || (data2 == 0))
        {
            [window setBackgroundColor:mColors[0]];
        }
        else
        {
            // Adjust for change to C4 = note 60
            data1 -= 12;
            
            if ((data1 >= 0) &&
                (data1 < (sizeof(colorList) / sizeof(colorList[0]))))
            {
                [window setBackgroundColor:mColors[data1]];
            }
            else
            {
                [window setBackgroundColor:mColors[0]];
            }
        }
            
        mMIDIControl.readIndex++;
            
        if (mMIDIControl.readIndex == kMaximumEvents)
        {
            mMIDIControl.readIndex = 0;
        }
    }
}

- (void)receiveMIDINotification:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:@"MIDINotification"] == YES)
    {
        [mPreferences updateMIDIInputs];
    }
}

- (void)setColors
{
    mColors = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < (sizeof(colorList) / sizeof(colorList[0])); i++)
    {
        unsigned char redByte = (unsigned char) (colorList[i].rgb >> 16);
        unsigned char greenByte = (unsigned char) (colorList[i].rgb >> 8);
        unsigned char blueByte = (unsigned char) (colorList[i].rgb);

        NSColor *color = [NSColor colorWithRed:((float)redByte / 0xff)
                          green:((float)greenByte / 0xff)
                          blue:((float)blueByte / 0xff) alpha:1.0];
        [mColors addObject:color];
    }
}

@end
