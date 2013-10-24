#import "ApplicationDelegate.h"
#import "OutlineItem.h"
#import "TextItem.h"
#import "OutlineController.h"
#import "DrawingController.h"
#import "TextController.h"
#import "Document.h"
#import "HistoryInspectorController.h"
#import "SharingServer.h"
#import "SKTDrawDocument.h"
#import "Project.h"
#import <CoreObject/CoreObject.h>

#define STORE_URL [NSURL URLWithString: [@"~/ProjectDemoStore" stringByExpandingTildeInPath]]

@implementation ApplicationDelegate

- (void)globalForward: (id)sender
{
	NSLog(@"Forward");
}

- (void)globalBack: (id)sender
{
	NSLog(@"Back");	
}

- (void)addStatusBarButtons
{
    NSStatusBar *bar = [NSStatusBar systemStatusBar];

    NSStatusItem *forwardButton = [bar statusItemWithLength:NSSquareStatusItemLength];
	[forwardButton setImage: [NSImage imageNamed: NSImageNameGoRightTemplate]];
    [forwardButton setHighlightMode:YES];
	[forwardButton setTarget: self];
	[forwardButton setAction: @selector(globalForward:)];
	[forwardButton retain];	
	
    NSStatusItem *backButton = [bar statusItemWithLength:NSSquareStatusItemLength];
	[backButton setImage: [NSImage imageNamed: NSImageNameGoLeftTemplate]];
    [backButton setHighlightMode:YES];
	[backButton setTarget: self];
	[backButton setAction: @selector(globalBack:)];
	[backButton retain];
}

- (void)showShelf: (id)sender
{
	[overlayShelf setIgnoresMouseEvents: NO];
	[overlayShelf setAlphaValue:0.0];
	[overlayShelf orderFront: sender];
	[[overlayShelf animator] setAlphaValue:1.0];
}

- (void)hideShelf: (id)sender
{
	[overlayShelf setIgnoresMouseEvents: YES];
	[[overlayShelf animator] setAlphaValue:0.0];

}

- (void)toggleShelf: (id)sender
{
    if ([overlayShelf alphaValue] == 1.0)
    {
        [self hideShelf: sender];
    }
    else
    {
        [self showShelf: sender];
    }
}

- (NSSet *)projects
{
	NSSet *projects = [[[context persistentRoots]
						mappedCollectionWithBlock: ^(id obj) {
							return [obj rootObject];
						}] filteredCollectionWithBlock: ^(id obj) {
							return [[[obj entityDescription] name] isEqualToString: @"Project"];
						}];
	return projects;
}

- (void)awakeFromNib
{
	context = [[COEditingContext alloc] initWithStore:
			   [[[COSQLiteStore alloc] initWithURL: STORE_URL] autorelease]];
	
	// TODO: Use NSUserDefaults to remember open documents
	//ETUUID *uuid = [[NSUserDefaults standardUserDefaults] UUIDForKey: @"projectDemoProjectUUID"];
	

	NSSet *projects = [self projects];
	
	if (![projects isEmpty])
	{
		NSLog(@"Loaded projects: %@", projects);
	}
	else
	{
        COPersistentRoot *proot = [context insertNewPersistentRootWithEntityName: @"Anonymous.Project"];
		[[proot rootObject] setName: @"Untitled project"];
		[context commit];
		
		NSLog(@"Creating a new project %@", [proot UUID]);
	}
		
	controllerForDocumentUUID = [[NSMutableDictionary alloc] init];
	
	//[historyController setContext: context];
	
	// UI Setup
	[self addStatusBarButtons];
//	desktopWindow = [[DesktopWindow alloc] init];
	//projectNavWindow = [[ProjectNavWindow alloc] init];
	overlayShelf = [[OverlayShelf alloc] init];

	projects = [self projects];
	for (Project *project in projects)
	{
		// Show existing documents
		[self projectDocumentsDidChange: project];
	}
}

- (COEditingContext*)editingContext
{
	return context;
}

- (HistoryInspectorController*)historyController
{
	return historyController;
}

- (void)dealloc
{
	[controllerForDocumentUUID release];
	[desktopWindow release];
	[super dealloc];
}

- (void) newDocumentWithType: (NSString*)type rootObjectEntity: (NSString*)rootObjEntity
{
    COPersistentRoot *persistentRoot = [context insertNewPersistentRootWithEntityName: @"Anonymous.Document"];
    assert(persistentRoot != nil);
    
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
	ETEntityDescription *desc = [repo descriptionForName: rootObjEntity];
    COObject *rootObj = [[[repo classForEntityDescription: desc] alloc] initWithEntityDescription:desc
																			   objectGraphContext: [persistentRoot objectGraphContext]];
    
	Document *document = [persistentRoot rootObject];
	[document setRootDocObject: rootObj];
    assert([document rootDocObject] == rootObj);
	[document setDocumentName: [NSString stringWithFormat: @"Document %@", [[persistentRoot UUID] stringValue]]];
	[document setDocumentType: type];
	
	// FIXME: Total hack
	Project *proj = [[self projects] anyObject];
	[proj addDocument_hack: document];
	
	NSLog(@"Added a document model object %@, outline item %@", document, rootObj);
	NSLog(@"Changed objects %@", [context changedObjects]);
	[context commit];
	
	[newDocumentTypeWindow orderOut: nil];
    
    // FIXME: Hack
    [self projectDocumentsDidChange: proj];
}

- (IBAction) newTextDocument: (id)sender
{
	[self newDocumentWithType: @"text" rootObjectEntity: @"TextItem"];
}
- (IBAction) newOutline: (id)sender
{
	[self newDocumentWithType: @"outline" rootObjectEntity: @"OutlineItem"];
}
- (IBAction) newDrawing: (id)sender
{
	[self newDocumentWithType: @"drawing" rootObjectEntity: @"SKTDrawDocument"];
}

/* Convenience */

- (NSWindowController*) keyDocumentController
{
	for (NSWindowController *controller in [controllerForDocumentUUID allValues])
	{
		if ([[controller window] isKeyWindow])
		{
			return controller;
		}
	}
	return nil;
}

- (Document *)keyDocument
{
	return [[self keyDocumentController] projectDocument];
}

/* NSResponder */

- (void)saveDocument: (id)sender
{
	[self checkpointWithName: nil];
}

- (void)saveDocumentAs: (id)sender
{
	NSString *name = [checkpointAsSheetController showSheet];
	if (name != nil)
	{
		[self checkpointWithName: name];
	}
}

- (void)checkpointWithName: (NSString*)name
{
	if ([name length] == 0)
	{
		name = @"Untitled Checkpoint";
	}
    
//    [[[doc objectGraphContext] editingContext] commit];
//    
//	[context commitWithType: kCOTypeCheckpoint
//		   shortDescription: @"Checkpoint"
//			longDescription: name];
    [context commit];
}

- (IBAction)newProject: (id)sender
{
	Project *newProject = [[Project alloc] initWithObjectGraphContext: context];
	[context commit];
	NSLog(@"Creating a new project %@ = %@", [newProject uuid], newProject); 
	[newProject setDelegate: self];

	
}

- (IBAction)deleteProject: (id)sender
{
	
	
}



- (OutlineController*)controllerForDocumentRootObject: (COObject*)rootObject;
{
	for (Project *project in [self projects])
	{
		for (Document *doc in [project documents])
		{
			if ([[[doc rootObject] UUID] isEqual: [rootObject UUID]])
			{
				return [controllerForDocumentUUID objectForKey: [doc UUID]];
			}
		}
	}
	return nil;
}

/* Project delegate */

- (void)keyDocumentChanged: (NSNotification*)notif
{
	NSLog(@"Key document changed to: %@", [self keyDocumentController]);
	
	[tagWindowController setDocument: [self keyDocument]];
	
	// FIXME: update inspectors	
}

- (void)projectDocumentsDidChange: (Project*)p
{
	NSLog(@"projectDocumentsDidChange: called, loading %d documents", (int)[[p documents] count]);
	
	static NSDictionary *classForType;
	if (classForType == nil)
	{
		classForType = [[NSDictionary alloc] initWithObjectsAndKeys:
			[OutlineController class], @"outline",
			[DrawingController class], @"drawing",
			[TextController class], @"text",
			nil];
	}
	
	NSMutableSet *unwantedDocumentUUIDs = [NSMutableSet setWithArray:
										   [controllerForDocumentUUID allKeys]];
	
	for (Document *doc in [p documents])
	{
		[unwantedDocumentUUIDs removeObject: [doc UUID]];
		
		OutlineController *controller = [controllerForDocumentUUID objectForKey: [doc UUID]];
		if (controller == nil)
		{
			Class cls = [classForType objectForKey: [doc documentType]];
			assert(cls != Nil);
			
			// Create a new document controller
			controller = [[[cls alloc] initWithDocument: doc] autorelease];
			[controller showWindow: nil];
			[controllerForDocumentUUID setObject: controller forKey: [doc UUID]];
			// Observe key document changes
			[[NSNotificationCenter defaultCenter] addObserver: self
													 selector: @selector(keyDocumentChanged:)
														 name: NSWindowDidBecomeKeyNotification
													   object: [controller window]];
		}
	}
	
	for (ETUUID *unwanted in unwantedDocumentUUIDs)
	{
		NSWindow *window = [[controllerForDocumentUUID objectForKey: unwanted] window];
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: NSWindowDidBecomeKeyNotification
													  object: window];
		[window orderOut: nil];
		[controllerForDocumentUUID removeObjectForKey: unwanted];
	}
}

- (void) shareWithInspectorForDocument: (Document*)doc
{
	[sharingController shareWithInspectorForDocument: doc];
}

- (void)showSearchResults: (id)sender
{
	[searchWindow orderFront: self];
}

@end
