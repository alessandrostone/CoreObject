/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import "OutlineItem.h"

@implementation OutlineItem

+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [OutlineItem className]])
		return entity;

	ETPropertyDescription *isShared = [ETPropertyDescription descriptionWithName: @"isShared"
                                                                                 type: (id)@"BOOL"];
    [isShared setPersistent: YES];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
    
    ETPropertyDescription *contentsProperty =
    [ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.OutlineItem"];
	
    [contentsProperty setPersistent: YES];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: YES];
    
    ETPropertyDescription *parentContainerProperty =
    [ETPropertyDescription descriptionWithName: @"parentContainer" type: (id)@"Anonymous.OutlineItem"];
    
    [parentContainerProperty setMultivalued: NO];
	[parentContainerProperty setDerived: YES];
    [parentContainerProperty setOpposite: (id)@"Anonymous.OutlineItem.contents"];
    
    ETPropertyDescription *parentCollectionsProperty =
    [ETPropertyDescription descriptionWithName: @"parentCollections" type: (id)@"Anonymous.Tag"];
    
    [parentCollectionsProperty setMultivalued: YES];
	[parentCollectionsProperty setDerived: YES];
    [parentCollectionsProperty setOpposite: (id)@"Anonymous.Tag.contents"];
	
	ETPropertyDescription *attachmentProperty =
    [ETPropertyDescription descriptionWithName: @"attachmentID" type: (id)@"Anonymous.COAttachmentID"];
	[attachmentProperty setPersistent: YES];
    
    [entity setPropertyDescriptions: A(isShared, labelProperty, contentsProperty, parentContainerProperty, parentCollectionsProperty, attachmentProperty)];

    return entity;
}

- (NSString *)contentKey
{
	return @"contents";
}

- (BOOL)isShared
{
	return [[self valueForVariableStorageKey: @"isShared"] boolValue];
}

- (void)setIsShared:(BOOL)isShared
{
	[self willChangeValueForProperty: @"isShared"];
	[self setValue: @(isShared) forVariableStorageKey: @"isShared"];
	[self didChangeValueForProperty: @"isShared"];
}

// FIXME: Fix COObject+Accessors to support overriding read-only properties as read-write
//@dynamic isShared;
@dynamic label;
@dynamic contents;
@dynamic parentContainer;
@dynamic parentCollections;
@dynamic checked;
@dynamic attachmentID;

@end


@implementation TransientOutlineItem

+ (ETEntityDescription *)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [TransientOutlineItem className]])
		return entity;

    ETPropertyDescription *contentsProperty =
		[ETPropertyDescription descriptionWithName: @"contents" type: (id)@"TransientOutlineItem"];

    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: YES];
    
    ETPropertyDescription *parentContainerProperty =
    	[ETPropertyDescription descriptionWithName: @"parentContainer" type: (id)@"TransientOutlineItem"];
    
	// NOTE: For a non-persistent relationship, 'container' doesn't necessarily imply 'derived'
    [parentContainerProperty setMultivalued: NO];
    [parentContainerProperty setOpposite: (id)@"TransientOutlineItem.contents"];
       
    [entity setPropertyDescriptions: A(contentsProperty, parentContainerProperty)];

    return entity;
}

- (NSString *)contentKey
{
	return @"contents";
}

@dynamic contents, parentContainer;

@end
