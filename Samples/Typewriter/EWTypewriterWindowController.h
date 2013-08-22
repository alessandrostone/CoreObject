#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>

#import "EWTextStorage.h"
#import "EWTextView.h"

@interface EWTypewriterWindowController : NSWindowController
{
    IBOutlet EWTextView *textView_;
    
    EWTextStorage *textStorage_;
    
    BOOL isLoading_;
    
    CORevisionID *displayedRevision_;
}

- (void) displayRevision: (CORevisionID*)aRev;

@end

