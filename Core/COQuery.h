/**
	Copyright (C) 2011 Quentin Mathe

	Date:  November 2011
	License:  MIT  (see COPYING)

	COObjectMatching protocol is based on MIT-licensed code by Yen-Ju Chen 
	<yjchenx gmail> from the previous CoreObject.
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

/** 
 * @group Query
 * @abstract A NSPredicate-based query to be run in memory or in store as a SQL 
 * statement.
 *
 * COQuery is provided to search the core objects either in store through 
 * -[COStore resultDictionariesForQuery:] or in memory through the 
 * COObjectMatching protocol. 
 *
 * It allows to combine a predicate or a raw SQL query with various additional 
 * constraints, and control how the search results are returned.
 *
 * NOTE: This API is unstable and incomplete, and SQL query support is not 
 * implemented.
 */
@interface COQuery : NSObject
{
	@private
	NSPredicate *predicate;
	NSString *SQLString;
	BOOL matchesAgainstObjectsInMemory;
}


/** @taskunit Initialization */


/**
 * Returns a new autoreleased query that uses a predicate.
 */
+ (COQuery *)queryWithPredicate: (NSPredicate *)aPredicate;
#ifndef GNUSTEP
/**
 * Returns a new autoreleased query that uses a predicate based on a block.
 *
 * See -[NSPredicate predicateWithBlock:].
 */
+ (COQuery *)queryWithPredicateBlock: (BOOL (^)(id object, NSDictionary *bindings))aBlock;
#endif
/**
 * Returns a new autoreleased query that uses a SQL request.
 *
 * Note: To search the store based on the returned query is not implemented, so 
 * this method is useless presently.
 */
+ (COQuery *)queryWithSQLString: (NSString *)aSQLString;


/** @taskunit Query Representations */


/**
 * The predicate that expresses the query.
 */
@property (nonatomic, strong) NSPredicate *predicate;
/**
 * Returns a SQL representation that can be passed to the COStore API.
 */
@property (nonatomic, readonly, strong) NSString *SQLString;


/** @taskunit Query Constraints */


/**
 * Determines whether the objects in memory should be searched directly, rather 
 * than turning the predicate into a SQL query and evaluates it against the store.
 *
 * When set to YES, the objects are loaded lazily while traversing the object 
 * graph bound the object on which the query was started with 
 * -[COObjectMatching objectsMatchingQuery:].
 *
 * If no predicate is set, this property is ignored.
 *
 * By default, returns NO.
 *
 * See also -[COObjectMatching matchesPredicate:].
 */
@property (nonatomic, assign) BOOL matchesAgainstObjectsInMemory;


@end


/**
 * @group Query
 * @abstract Protocol to search objects directly in memory with COQuery.
 */
@protocol COObjectMatching
/**
 * Returns the objects matching the query conditions.
 *
 * Must be implemented by recursively traversing the object graph each time 
 * the receiver has a relationship which makes sense to search.
 */
- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery;
@end
