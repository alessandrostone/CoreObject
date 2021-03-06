/**
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/COCommand.h>

@interface COCommandDeleteBranch : COCommand
{
    ETUUID *_branchUUID;
}

@property (nonatomic, copy) ETUUID *branchUUID;

@end
