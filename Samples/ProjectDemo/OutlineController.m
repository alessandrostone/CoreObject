#import "OutlineController.h"
#import "SharingController.h"
#import "ItemReference.h"

@implementation OutlineController

- (id)initWithDocument: (id)document isSharing: (BOOL)sharing;
{
	self = [super initWithWindowNibName: @"OutlineWindow"];
	
	if (!self) { [self release]; return nil; }
	
	doc = document; // weak ref
	isSharing = sharing;
	
	assert([self rootObject] != nil);
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector: @selector(didCommit:)
												 name: COEditingContextBaseHistoryGraphNodeDidChangeNotification 
											   object: nil];
	
	return self;
}

- (id)initWithDocument: (id)document
{
	return [self initWithDocument:document isSharing: NO];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (void)didCommit: (NSNotification*)notif
{
	COHistoryNode *node = [notif userInfo];
	NSMutableSet *updateObjectUUIDs = [NSMutableSet setWithArray: [[node uuidToObjectVersionMaping] allKeys]];
	NSArray *allObjectsUUIDsInDocument = 
    [[[[doc allStronglyContainedObjects] mappedCollection] uuid]
	 arrayByAddingObject: [doc uuid]];
	//  NSLog(@"Did commit. update %@, all %@", updateObjectUUIDs, allObjectsUUIDsInDocument);
	[updateObjectUUIDs intersectSet: [NSSet setWithArray: allObjectsUUIDsInDocument]];
	//  NSLog(@"intersect %@", updateObjectUUIDs);
    
	if ([updateObjectUUIDs count] > 0)
	{
		NSLog(@"Reloading outline for %@", doc);
		[outlineView reloadData];  
	}
}

- (Document*)projectDocument
{
	return doc;
}
- (OutlineItem*)rootObject
{
	return [[self projectDocument] rootObject];
} 
- (void) commitWithType: (NSString*)type
       shortDescription: (NSString*)shortDescription
        longDescription: (NSString*)longDescription;
{
	[[[self rootObject] objectContext] commitWithType:type shortDescription:shortDescription longDescription:longDescription];
}

- (void)windowDidLoad
{
	[outlineView registerForDraggedTypes:
		[NSArray arrayWithObject:@"org.etoile.outlineItem"]];
	[outlineView setDelegate: self];
	[outlineView setTarget: self];
	[outlineView setDoubleAction: @selector(doubleClick:)];
	
	//NSLog(@"Got rect %@ for doc %@", NSStringFromRect([doc screenRectValue]), [doc uuid]);
	
	if (!NSIsEmptyRect([doc screenRectValue]))
	{
		// Disable automatic positioning
		[self setShouldCascadeWindows: NO];
		[[self window] setFrame: [doc screenRectValue] display: NO];		
	}

	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(windowFrameDidChange:)
												 name: NSWindowDidMoveNotification 
											   object: [self window]];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(windowFrameDidChange:)
												 name: NSWindowDidEndLiveResizeNotification 
											   object: [self window]];	
	
	if ([doc documentName])
	{
		NSString *title;
		if (isSharing)
		{
			title = [NSString stringWithFormat: @"Shared Document %@ From %@",
					 [doc documentName],
					 [[SharingController sharedSharingController] fullNameOfUserSharingDocument: doc]];
		}
		else
		{
			title = [doc documentName];
		}
		[[self window] setTitle: title]; 
	}
	
	// Disable the share button if it is a shared document
	if (isSharing)
	{
		for (NSToolbarItem *item in [[[self window] toolbar] items])
		{
			if ([[item itemIdentifier] isEqual: @"share"])
			{
				[item setEnabled: NO];
			}
		}
	}
}

- (void)windowFrameDidChange:(NSNotification*)notification
{
	[doc setScreenRectValue: [[self window] frame]];
	
	assert([[doc objectContext] objectHasChanges: [doc uuid]]);
	assert([[doc valueForProperty: @"screenRect"] isEqual: NSStringFromRect([[self window] frame])]);
	
	[self commitWithType: kCOTypeMinorEdit
		shortDescription: @"Move Window"
		 longDescription: [NSString stringWithFormat: @"Move to %@", NSStringFromRect([doc screenRectValue])]];	
}

- (void)windowWillClose:(NSNotification *)notification
{
	NSLog(@"TODO: handle outline closing");
}

static int i = 0;

- (OutlineItem *) newItem
{
	OutlineItem *item = [[OutlineItem alloc] initWithParent: nil
													context: [[self rootObject] objectContext]];
	[item autorelease];
	[item setLabel: [NSString stringWithFormat: @"Item %d", i++]];
	return item;
}

- (OutlineItem *) selectedItem
{
	OutlineItem *dest = [outlineView itemAtRow: [outlineView selectedRow]];
	if (dest == nil) { dest = [self rootObject]; }
	return dest;
}

- (OutlineItem *) selectedItemParent
{
	OutlineItem *dest = [[self selectedItem] parent];
	if (dest == nil) { dest = [self rootObject]; }
	return dest;
}

/* IB Actions */

- (IBAction) addItem: (id)sender;
{
	OutlineItem *dest = [self selectedItemParent];
	OutlineItem *item = [self newItem];
	[dest addItem: item];
	
	[outlineView expandItem: dest];
	
	[self commitWithType: kCOTypeMinorEdit
		shortDescription: @"Add Item"
		 longDescription: [NSString stringWithFormat: @"Add item %@", [item label]]];
}

- (IBAction) addChildItem: (id)sender;
{
	OutlineItem *dest = [self selectedItem];
	
	if ([dest isKindOfClass: [OutlineItem class]])
	{
		OutlineItem *item = [self newItem];
		[dest addItem: item];
		
		[outlineView expandItem: dest];
		
		[self commitWithType: kCOTypeMinorEdit
			shortDescription: @"Add Child Item"
			 longDescription: [NSString stringWithFormat: @"Add child item %@ to %@", [item label], [dest label]]];
	}
}

- (IBAction) shiftLeft: (id)sender
{
	OutlineItem *item = [self selectedItem];
	OutlineItem *parent = [item parent];
	OutlineItem *grandparent = [parent parent];
	
	NSInteger indexOfItemInParent = [[parent contents] indexOfObject: item];
	assert(indexOfItemInParent != NSNotFound);
	if (grandparent != nil)
	{
		[item retain];
		[parent removeItemAtIndex: indexOfItemInParent];
		[grandparent addItem: item atIndex: [[grandparent contents] indexOfObject: parent] + 1];
		[item release];
		
		[self commitWithType: kCOTypeMinorEdit
			shortDescription: @"Shift Left"
			 longDescription: [NSString stringWithFormat: @"Shift left item %@", [item label]]];
		
		[outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex:[outlineView rowForItem: item]]
				 byExtendingSelection: NO];
	}
}
- (IBAction) shiftRight: (id)sender
{
	OutlineItem *item = [self selectedItem];
	OutlineItem *parent = [item parent];
	NSInteger indexOfItemInParent = [[parent contents] indexOfObject: item];
	assert(indexOfItemInParent != NSNotFound);
	if (parent != nil && indexOfItemInParent > 0)
	{
		NSLog(@"Requesting object at %d in collection of %d", indexOfItemInParent - 1, [[parent contents] count]);
		OutlineItem *newParent = [[parent contents] objectAtIndex: (indexOfItemInParent - 1)];
		
		if ([newParent isKindOfClass: [OutlineItem class]])
		{		
			[item retain];
			[parent removeItemAtIndex: [[parent contents] indexOfObject: item]];
			[newParent addItem: item];
			[item release];
			
			[self commitWithType: kCOTypeMinorEdit
				shortDescription: @"Shift Right"
				 longDescription: [NSString stringWithFormat: @"Shift right item %@", [item label]]];
			
			[outlineView expandItem: newParent];
			
			[outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex:[outlineView rowForItem: item]]
					 byExtendingSelection: NO];
		}
	}  
}

- (IBAction) shareWith: (id)sender
{
	[[[NSApplication sharedApplication] delegate] shareWithInspectorForDocument: doc];
}

/* History stuff */

- (IBAction) undo: (id)sender
{
	NSLog(@"Undo");
}
- (IBAction) redo: (id)sender
{
	NSLog(@"Redo");	
}
- (IBAction) history: (id)sender
{
	[[[NSApp delegate] historyController] showHistoryForDocument: doc];
}

/* NSResponder */

- (void)insertTab:(id)sender
{
	[self shiftRight: sender];
}

- (void)insertBacktab:(id)sender
{
	[self shiftLeft: sender];
}

- (void)deleteForward:(id)sender
{
	id itemToDelete = [self selectedItem];
	if (itemToDelete != nil && itemToDelete != [self rootObject])
	{
		NSInteger index = [[[itemToDelete parent] contents] indexOfObject: itemToDelete];
		assert(index != NSNotFound);
		NSString *label = [[itemToDelete label] retain];
		[[itemToDelete parent] removeItemAtIndex: index];
		
		[self commitWithType: kCOTypeMinorEdit
			shortDescription: @"Delete Item"
			 longDescription: [NSString stringWithFormat: @"Delete Item %@", label]];

		[label release];
	}
}

- (void)delete:(id)sender
{
	[self deleteForward: sender];
}

- (void)keyDown:(NSEvent *)theEvent
{
	[self interpretKeyEvents: [NSArray arrayWithObject:theEvent]];
}

/* NSOutlineView Target/Action */

- (void)doubleClick: (id)sender
{
	if (sender == outlineView)
	{
		id item = [self selectedItem];
		if ([item isKindOfClass: [ItemReference class]])
		{
			// User double clicked on an item reference / link
			// so order-front the link target's document window and select it.
			id target = [item referencedItem];
			
			id root = [target root];
			OutlineController *otherController = [[[NSApplication sharedApplication] delegate]
												  controllerForDocumentRootObject: root];
			assert(otherController != nil);
			
			// FIXME: ugly
			
			[[otherController window] makeKeyAndOrderFront: nil];
			[otherController->outlineView expandItem: nil expandChildren: YES];
			[otherController->outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex:[otherController->outlineView rowForItem: target]]
					 byExtendingSelection: NO];
		}
		else if ([item isKindOfClass: [OutlineItem class]])
		{
			// setting a double action on an outline view seems to break normal editing
			// so we hack it in here.
			
			[outlineView editColumn: 0
								row: [outlineView selectedRow]
						  withEvent: nil
							 select: YES];
		}
	}
}

/* NSOutlineView delegate */

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([item isKindOfClass: [OutlineItem class]])
	{
		return YES;
	}
	return NO;
}

/* NSOutlineView data source */

- (id) outlineView: (NSOutlineView *)outlineView child: (NSInteger)index ofItem: (id)item
{
	if (nil == item) { item = [self rootObject]; }
	return [[item contents] objectAtIndex: index];
}

- (BOOL) outlineView: (NSOutlineView *)outlineView isItemExpandable: (id)item
{
	return [self outlineView: outlineView numberOfChildrenOfItem: item] > 0;
}

- (NSInteger) outlineView: (NSOutlineView *)outlineView numberOfChildrenOfItem: (id)item
{
	if (nil == item) { item = [self rootObject]; }
	if ([item isKindOfClass: [OutlineItem class]])
	{
		return [[item contents] count];
	}
	else
	{
		return 0;
	}
}

- (id) outlineView: (NSOutlineView *)outlineView objectValueForTableColumn: (NSTableColumn *)column byItem: (id)item
{
	if (nil == item) { item = [self rootObject]; }
	return [item label];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (nil == item) { item = [self rootObject]; }

	if ([item isKindOfClass: [OutlineItem class]])
	{
		NSString *oldLabel = [[item label] retain];
		[item setLabel: object];
	
		[self commitWithType: kCOTypeMinorEdit
			shortDescription: @"Edit Label"
			 longDescription: [NSString stringWithFormat: @"Edit label from %@ to %@", oldLabel, [item label]]];
	
		[oldLabel release];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pb
{
	NSMutableArray *pbItems = [NSMutableArray array];
	
	for (OutlineItem *outlineItem in items)
	{    
		NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
		[item setPropertyList: [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithInteger: (NSInteger)outlineItem], @"outlineItemPointer",
                                [NSNumber numberWithInteger: (NSInteger)outlineView], @"outlineViewPointer",
                                nil]
					  forType: @"org.etoile.outlineItem"];
		[pbItems addObject: item];
	}
	
	[pb clearContents];
	return [pb writeObjects: pbItems];
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
	if (item != nil && ![item isKindOfClass: [OutlineItem class]])
	{
		return NSDragOperationNone;
	}
	for (NSPasteboardItem *pbItem in [[info draggingPasteboard] pasteboardItems])
	{
		OutlineItem *srcItem = (OutlineItem*)[[[pbItem propertyListForType: @"org.etoile.outlineItem"] valueForKey:@"outlineItemPointer"] integerValue];
		
		// Ensure the destination isn't a child of, or equal to, the source    
		for (OutlineItem *tempDest = item; tempDest != nil; tempDest = [tempDest parent])
		{
			if ([tempDest isEqual: srcItem])
			{
				return NSDragOperationNone;
			}
		}
	}
	return NSDragOperationPrivate;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)newParent childIndex:(NSInteger)index
{
	if (nil == newParent) { newParent = [self rootObject]; }
	
	NSUInteger insertionIndex = index;
	NSLog(@" Drop on to %@ at %d", [newParent label], (int)index);
	
	NSMutableIndexSet *newSelectedRows = [NSMutableIndexSet indexSet];
	NSMutableArray *outlineItems = [NSMutableArray array];
	
	for (NSPasteboardItem *pbItem in [[info draggingPasteboard] pasteboardItems])
	{
		[outlineItems addObject: (OutlineItem*)[[[pbItem propertyListForType: @"org.etoile.outlineItem"] valueForKey:@"outlineItemPointer"] integerValue]];
	}
	
	
	/* Make a link if the user is holding control */
	
	if ([info draggingSourceOperationMask] == NSDragOperationLink &&
		![[outlineItems objectAtIndex: 0] isKindOfClass: [ItemReference class]]) // Don't make links to link objects
	{
		OutlineItem *itemToLinkTo = [outlineItems objectAtIndex: 0];
		
		if (insertionIndex == -1) { insertionIndex = [[newParent contents] count]; }
		
		ItemReference *ref = [[ItemReference alloc] initWithParent: newParent
													referencedItem: itemToLinkTo
														   context: [[self rootObject] objectContext]];
		[ref autorelease];
		
		[newParent addItem: ref 
				   atIndex: insertionIndex]; 
		
		[self commitWithType: kCOTypeMinorEdit
			shortDescription: @"Drop Link"
			 longDescription: [NSString stringWithFormat: @"Drop Link to %@ on %@", [itemToLinkTo label], [newParent label]]];
		
		return;
	}
	
	// Here we only work on the model.
	
	for (OutlineItem *outlineItem in outlineItems)
	{
		OutlineItem *oldParent = [outlineItem parent];
		NSUInteger oldIndex = [[oldParent contents] indexOfObject: outlineItem];
		
		NSLog(@"Dropping %@ from %@", [outlineItem label], [oldParent label]);
		if (insertionIndex == -1) { insertionIndex = [[newParent contents] count]; }
		
		if (oldParent == newParent && insertionIndex > oldIndex)
		{
			[oldParent removeItemAtIndex: oldIndex];
			[newParent addItem: outlineItem atIndex: insertionIndex-1]; 
		}
		else
		{
			[oldParent removeItemAtIndex: oldIndex];
			[newParent addItem: outlineItem atIndex: insertionIndex++]; 
		}
	}
	
	[self commitWithType: kCOTypeMinorEdit
		shortDescription: @"Drop Items"
		 longDescription: [NSString stringWithFormat: @"Drop %d items on %@", (int)[outlineItems count], [newParent label]]];
	
	[outlineView expandItem: newParent];
	
	for (OutlineItem *outlineItem in outlineItems)
	{
		[newSelectedRows addIndex: [outlineView rowForItem: outlineItem]];
	}  
	[outlineView selectRowIndexes: newSelectedRows byExtendingSelection: NO];
	
	return YES;
}

/* OutlineItem delegate */

- (void)outlineItemDidChange: (OutlineItem*)item
{
	/*OutlineItem *parent = [item parent];
	 if (parent != nil)
	 {
	 [outlineView reloadItem: parent];
	 }*/
	
	/*
	 if (item == [self rootObject])
	 {
	 NSLog(@"root didchange");
	 [outlineView reloadData];  
	 }
	 else
	 {
	 NSLog(@"%@ didchange", [item label]);
	 [outlineView reloadItem: item reloadChildren: YES];  
	 }*/
}

@end