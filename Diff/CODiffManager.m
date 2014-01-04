/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  January 2014
	License:  MIT  (see COPYING)
 */

#import "CODiffManager.h"
#import "COObjectGraphContext+Private.h"
#import <CoreObject/CoreObject.h>

@interface CODiffManager ()
@property (nonatomic, strong) NSMutableDictionary *subDiffsByAlgorithmName;
@end

@implementation CODiffManager

@synthesize subDiffsByAlgorithmName;

/**
 * Assert that the entity names are the same.
 * Currently (maybe always?), changing the entity name of an object is disallowed.
 */
+ (void) checkItem: (COItem *)commonItemA hasSameEntityNameAsItem: (COItem *)commonItemB
{
	if (commonItemA != nil && commonItemB != nil)
	{
		NSString *oldEntityName = [COObjectGraphContext entityNameForItem: commonItemA];
		NSString *newEntityName = [COObjectGraphContext entityNameForItem: commonItemB];
		ETAssert([oldEntityName isEqual: newEntityName]);
	}
}

+ (Class) diffAlgorithmClassForItem: (COItem *)anItem
		 modelDescriptionRepository: (ETModelDescriptionRepository *)aRepository
{
	ETEntityDescription *entity = [COObjectGraphContext descriptionForItem: anItem
												modelDescriptionRepository: aRepository];
	
	Class diffClass = Nil;
	if (entity.diffAlgorithm != nil)
	{
		diffClass = NSClassFromString(entity.diffAlgorithm);
		if (diffClass == Nil)
		{
			NSLog(@"WARNING: Item %@ (entity name %@) specified a diff algorithm (%@) for which there is no corresponding class",
				  [anItem UUID], [entity name], entity.diffAlgorithm);
		}
	}
	
	if (diffClass == Nil)
	{
		diffClass = [COItemGraphDiff class];
	}
	
	return diffClass;
}

+ (NSDictionary *) itemUUIDsPartitionedByDiffAlgorithmNameWithFirstItemGraph: (id <COItemGraph>)a
															 secondItemGraph: (id <COItemGraph>)b
												  modelDescriptionRepository: (ETModelDescriptionRepository *)aRepository
{
	NSMutableDictionary *itemUUIDsByDiffAlgorithmName = [NSMutableDictionary new];
	
	for (ETUUID *aUUID in [b itemUUIDs])
	{
		COItem *commonItemA = [a itemForUUID: aUUID]; // may be nil if the item was inserted in b
		COItem *commonItemB = [b itemForUUID: aUUID];
		
		ETAssert(commonItemB != nil);
		[self checkItem: commonItemA hasSameEntityNameAsItem: commonItemB];
		
		Class diffClass = [self diffAlgorithmClassForItem: commonItemB
							   modelDescriptionRepository: aRepository];
		
		// HACK: Use COItemGraphDiff if the item is being added
		if (commonItemA == nil)
		{
			diffClass = [COItemGraphDiff class];
		}
		
		NSMutableArray *itemsForDiffClass = itemUUIDsByDiffAlgorithmName[NSStringFromClass(diffClass)];
		if (itemsForDiffClass == nil)
		{
			itemsForDiffClass = [NSMutableArray new];
			itemUUIDsByDiffAlgorithmName[NSStringFromClass(diffClass)] = itemsForDiffClass;
		}
		[itemsForDiffClass addObject: aUUID];
	}
	
	return itemUUIDsByDiffAlgorithmName;
}

+ (CODiffManager *) diffItemGraph: (id <COItemGraph>)a
					withItemGraph: (id <COItemGraph>)b
	   modelDescriptionRepository: (ETModelDescriptionRepository *)aRepository
				 sourceIdentifier: (id)aSource
{
	NSDictionary *itemUUIDsByDiffAlgorithmName = [self itemUUIDsPartitionedByDiffAlgorithmNameWithFirstItemGraph: a
																								 secondItemGraph: b
																					  modelDescriptionRepository: aRepository];
	
	NSMutableDictionary *subDiffsByAlgorithmName = [NSMutableDictionary new];
	for (NSString *algorithmName in itemUUIDsByDiffAlgorithmName)
	{
		NSArray *itemUUIDs = itemUUIDsByDiffAlgorithmName[algorithmName];
		
		Class cls = NSClassFromString(algorithmName);
		id<CODiffAlgorithm> diff = [cls diffItemUUIDs: itemUUIDs fromGraph: a toGraph: b sourceIdentifier: aSource];
		subDiffsByAlgorithmName[algorithmName] = diff;
	}
	
	CODiffManager *result = [[CODiffManager alloc] init];
	result.subDiffsByAlgorithmName = subDiffsByAlgorithmName;
	return result;
}

- (CODiffManager *) diffByMergingWithDiff: (CODiffManager *)otherDiff
{
	CODiffManager *result = [[CODiffManager alloc] init];
	
	NSMutableDictionary *resultDict = [NSMutableDictionary new];
	for (NSString *algorithmName in otherDiff.subDiffsByAlgorithmName)
	{
		id<CODiffAlgorithm> otherSubDiff = otherDiff.subDiffsByAlgorithmName[algorithmName];
		id<CODiffAlgorithm> ourSubDiff = self.subDiffsByAlgorithmName[algorithmName];
		
		if (ourSubDiff == nil)
		{
			// FIXME: Breaks if 'otherDiff' is modified later
			resultDict[algorithmName] = otherSubDiff;
		}
		else
		{
			resultDict[algorithmName] = [ourSubDiff itemTreeDiffByMergingWithDiff: otherSubDiff];
		}
	}
	
	result->subDiffsByAlgorithmName = resultDict;
	return result;
}

- (void) applyTo: (id<COItemGraph>)dest
{
	for (NSString *algorithmName in self.subDiffsByAlgorithmName)
	{
		id<CODiffAlgorithm> ourSubDiff = self.subDiffsByAlgorithmName[algorithmName];
		
		[ourSubDiff applyTo: dest];
	}
}

- (BOOL) hasConflicts
{
	for (id<CODiffAlgorithm> diff in [subDiffsByAlgorithmName allValues])
	{
		if ([diff hasConflicts])
			return YES;
	}
	return NO;
}

- (void) resolveConflictsFavoringSourceIdentifier: (id)aSource
{
	for (id<CODiffAlgorithm> diff in [subDiffsByAlgorithmName allValues])
	{
		[diff resolveConflictsFavoringSourceIdentifier: aSource];
	}
}

@end
