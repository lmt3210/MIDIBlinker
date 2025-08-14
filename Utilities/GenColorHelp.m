
#import <Foundation/Foundation.h>
#import "../../LTCommon/LTColors.h"

#define kNumNotes  12

int main(int argc, char const *argv[])
{
    NSMutableString *tableString = [[NSMutableString alloc] init];
    NSMutableString *textString =
        [[NSMutableString alloc] initWithString:
         @"Note Number\tNote Name\tColor\t\tHex Color Code\n"];
    NSString * _Nonnull noteNamesSharp[kNumNotes] =
        { @"C", @"C#", @"D", @"D#", @"E", @"F", @"F#",
          @"G", @"G#", @"A", @"A#", @"B" };
    int octave = 0;
    int noteNum = 13;
    
    for (int i = 1; i < (sizeof(colorList) / sizeof(colorList[0])); i++)
    {
        if ([noteNamesSharp[noteNum % kNumNotes] isEqualToString:@"C"] == YES)
        {
            ++octave;
        }
        
        [tableString appendFormat:
         @"  <tr><td>%i</td><td>%@%i</td><td>%@</td><td>#%06x</td></tr>\n",
         noteNum, noteNamesSharp[noteNum % kNumNotes], octave,
         colorList[i].name, colorList[i].rgb];
        [textString appendFormat:@"\t%i\t\t\t%@%i\t\t%@\t\t\t#%06x\n",
         noteNum, noteNamesSharp[noteNum % kNumNotes], octave,
         colorList[i].name, colorList[i].rgb];
         ++noteNum;
    }
    
    [tableString writeToFile:@"table.html"
     atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [textString writeToFile:@"table.txt"
     atomically:YES encoding:NSUTF8StringEncoding error:nil];

    return 0;
}
