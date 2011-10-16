/* 
 * Copyright (c) 2011, salesforce.com, inc.
 * Author: Jonathan Hersh jhersh@salesforce.com
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided 
 * that the following conditions are met:
 * 
 *    Redistributions of source code must retain the above copyright notice, this list of conditions and the 
 *    following disclaimer.
 *  
 *    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and 
 *    the following disclaimer in the documentation and/or other materials provided with the distribution. 
 *    
 *    Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or 
 *    promote products derived from this software without specific prior written permission.
 *  
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import "RelatedListGridView.h"
#import "AccountGridCell.h"
#import "DSActivityView.h"
#import "AccountUtil.h"
#import "PRPAlertView.h"
#import "DetailViewController.h"

@implementation RelatedListGridView

@synthesize relatedList, gridView, records, noResultsLabel, sortColumn, sortAscending;

static float cellHeight = 65.0f;
static NSString *upArrow = @"▲";
static NSString *downArrow = @"▼";
static NSString *nameField = nil;
BOOL canViewRecordDetail = NO;
BOOL canSortGridColumns = NO;

- (id) initWithRelatedList:(ZKRelatedList *)list inFrame:(CGRect)frame {
    if(( self = [super initWithFrame:frame] )) {
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"panelBG.png"]];
                
        self.relatedList = list;        
        self.records = [NSMutableArray array];
        nameField = [[AccountUtil sharedAccountUtil] nameFieldForsObject:[self sObjectNameForRelatedList:sObjectForDescribe]];
        
        ZKDescribeGlobalSObject *desc = [[AccountUtil sharedAccountUtil] describeGlobalsObject:[self sObjectNameForRelatedList:sObjectForDescribe]];
        canViewRecordDetail = desc && [desc queryable] && [desc layoutable];
        canSortGridColumns = ![[self sObjectNameForRelatedList:sObjectForDescribe] isEqualToString:@"Task"];
        
        self.gridView = [[[AQGridView alloc] initWithFrame:CGRectMake( 0, self.navBar.frame.size.height, 
                                                                      frame.size.width, 
                                                                      frame.size.height - self.navBar.frame.size.height )] autorelease];
        self.gridView.delegate = self;
        self.gridView.dataSource = self;
        self.gridView.separatorStyle = AQGridViewCellSeparatorStyleSingleLine;
        self.gridView.separatorColor = [UIColor lightGrayColor];
        self.gridView.scrollEnabled = YES;
        self.gridView.resizesCellWidthToFit = NO;
        self.gridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleHeight;
        self.gridView.backgroundColor = [UIColor clearColor];
        
        [self.view addSubview:self.gridView];
                
        self.noResultsLabel = [[[UILabel alloc] initWithFrame:CGRectMake( 0, lroundf( ( frame.size.height - self.navBar.frame.size.height - 30 ) / 2.0f), 
                                                                         frame.size.width, 30 )] autorelease];
        noResultsLabel.text = NSLocalizedString(@"No Results", @"No Results");
        noResultsLabel.font = [UIFont boldSystemFontOfSize:20];
        noResultsLabel.textColor = [UIColor lightGrayColor];
        noResultsLabel.textAlignment = UITextAlignmentCenter;
        noResultsLabel.backgroundColor = [UIColor clearColor];
        noResultsLabel.hidden = YES;
        
        [self.view addSubview:self.noResultsLabel];        
    }
    
    return self;
}

- (void)dealloc {
    [records release];
    [relatedList release];
    [gridView release];
    [noResultsLabel release];
    [sortColumn release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void) setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    [self.gridView reloadData];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.gridView = nil;
    self.noResultsLabel = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (NSString *) sObjectNameForRelatedList:(enum sObjectNames)nameType {
    if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] ) {
        if( nameType == sObjectForQuery )
            return @"Account";
        else if( nameType == sObjectForDescribe )
            return @"Task";
        else
            return @"OpenActivities";
    } else if( [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] ) {
        if( nameType == sObjectForQuery )
            return @"Account";
        else if( nameType == sObjectForDescribe )
            return @"Task";
        else
            return @"ActivityHistories";
    }
    
    return [self.relatedList sobject];
}

- (NSString *) orderingClauseForRelatedList {    
    if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] ||
        [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] )
        return @"";
    
    NSMutableString *ret = [NSMutableString stringWithString:@"ORDER BY "];
    
    // If there's a user-selected sort, use that one first
    if( self.sortColumn )
        return [ret stringByAppendingFormat:@"%@ %@",
                self.sortColumn,
                ( self.sortAscending ? @"asc" : @"desc" )];
    
    if( ![self.relatedList sort] || [[self.relatedList sort] count] == 0 )
        return @"";
    
    for( int x = 0; x < [[self.relatedList sort] count]; x++ ) {
        ZKRelatedListSort *sort = [[self.relatedList sort] objectAtIndex:x];
        
        if( x == 0 ) {
            self.sortColumn = [[self class] sanitizeFieldName:[sort column]];
            self.sortAscending = [sort ascending];
        }
        
        [ret appendFormat:@"%@ %@",
         [sort column],
         ( [sort ascending] ? @"asc" : @"desc" )];
        
        if( x < [[self.relatedList sort] count] - 1 )
            [ret appendString:@", "];
    }
    
    return ret;
}

- (NSUInteger) limitAmountForRelatedList {
    if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] ||
        [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] )
        return 1;
    
    return 999;
}

- (NSString *) fieldsToQuery {
    NSMutableArray *fields = [NSMutableArray array];
    BOOL hasId = NO;
    BOOL hasRT = NO;
    BOOL hasCreatedDate = NO;
    
    for( ZKRelatedListColumn *col in [self.relatedList columns] ) {
        NSString *colName = [[self class] sanitizeFieldName:[col name]];
        
        if( [colName isEqualToString:@"Id"] )
            hasId = YES;
        
        if( [colName isEqualToString:@"RecordTypeId"] )
            hasRT = YES;
        
        if( [colName isEqualToString:@"CreatedDate"] )
            hasCreatedDate = YES;
        
        [fields addObject:colName];
    }   
    
    if( !hasId )
        [fields addObject:@"Id"];
    
    if( !hasCreatedDate )
        [fields addObject:@"CreatedDate"];
        
    // Special handling for openactivity and activityhistory, which require a subquery
    if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] )
        return [NSString stringWithFormat:@"(select %@ from %@ order by ActivityDate ASC, LastModifiedDate DESC limit 500)",
                [fields componentsJoinedByString:@","],
                [self sObjectNameForRelatedList:sObjectNormal]];
    else if( [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] )
        return [NSString stringWithFormat:@"(select %@ from %@ order by ActivityDate DESC, LastModifiedDate DESC limit 500)",
                [fields componentsJoinedByString:@","],
                [self sObjectNameForRelatedList:sObjectNormal]];
    else {
        if( !hasRT && [[AccountUtil sharedAccountUtil] isObjectRecordTypeEnabled:[self sObjectNameForRelatedList:sObjectForDescribe]] )
            [fields addObject:@"RecordTypeId"];
        
        return [fields componentsJoinedByString:@","];
    }
}

- (NSString *) relatedFieldForRelatedList {
    if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] ||
        [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] )
        return @"Id";
    
    return [self.relatedList field];
}

- (void) selectAccount:(NSDictionary *)acc {
    [super selectAccount:acc];
    
    // Describe our related object and load records when complete
    [DSBezelActivityView newActivityViewForView:self.view];
    [[AccountUtil sharedAccountUtil] describesObject:[self sObjectNameForRelatedList:sObjectForDescribe]
                                       completeBlock:^(ZKDescribeSObject * sObject) {
                                           [self loadRecords];
                                       }];
}

#pragma mark - loading records

- (void) loadRecords {  
    NSString *query = [NSString stringWithFormat:@"select %@ from %@ where %@ = '%@' %@ limit %i",
                       [self fieldsToQuery],
                       [self sObjectNameForRelatedList:sObjectForQuery],
                       [self relatedFieldForRelatedList],
                       [self.account objectForKey:@"Id"],
                       [self orderingClauseForRelatedList],
                       [self limitAmountForRelatedList]
                       ];
    
    NSLog(@"SOQL: %@", query);
        
    [[AccountUtil sharedAccountUtil] startNetworkAction];
    [self.records removeAllObjects];
    
    self.gridView.hidden = YES;
    self.noResultsLabel.hidden = YES;
    
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ %@...",
                                                                      NSLocalizedString(@"Loading",nil),
                                                                      [self.relatedList label]]];
    item.hidesBackButton = YES;
    [self.navBar pushNavigationItem:item animated:NO];
    [item release];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
        ZKQueryResult *results = nil;
        
        @try {
            results = [[[AccountUtil sharedAccountUtil] client] query:query];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            [[AccountUtil sharedAccountUtil] receivedException:e];
            [DSBezelActivityView removeViewAnimated:NO];
            
            self.noResultsLabel.hidden = NO;
            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            [DSBezelActivityView removeViewAnimated:YES];
            
            NSArray *sObjects = nil;
            
            if( results && [results records] && [[results records] count] > 0 ) {
                if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] ||
                   [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] ) {
                    ZKSObject *ob = [[results records] objectAtIndex:0];
                    
                    if( ob && [ob fieldValue:[self sObjectNameForRelatedList:sObjectNormal]] )
                        sObjects = [[ob fieldValue:[self sObjectNameForRelatedList:sObjectNormal]] records];
                    
                    if( sObjects )
                        sObjects = [AccountUtil filterRecords:sObjects
                                                    dateField:@"CreatedDate"
                                                     withDate:[NSDate dateWithTimeIntervalSinceNow:-( 60 * 60 * 24 * 365 )]
                                                 createdAfter:YES];
                } else
                    sObjects = [results records];
                
                if( sObjects && [sObjects count] > 0 ) {
                    [self.records addObjectsFromArray:sObjects];
                    [self.gridView reloadData];
                    self.gridView.hidden = NO;
                } else
                    self.noResultsLabel.hidden = NO;
            } else
                self.noResultsLabel.hidden = NO;
            
            UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ — %@ (%i)",
                                                                              [self.account objectForKey:@"Name"],
                                                                              [self.relatedList label],
                                                                              [self.records count]]];
            item.hidesBackButton = YES;
            
            [self.navBar pushNavigationItem:item animated:YES];
            [item release];
        });
    });
}

// Working around a weird bug in zksforce where the 'name' field on ZKRelatedListColumn
// occasionally is something like "toLabel(StageName)" instead of just plain "StageName"
+ (NSString *) sanitizeFieldName:(NSString *)field {
    if( [field hasPrefix:@"toLabel("] ) {
        field = [field stringByReplacingOccurrencesOfString:@"toLabel(" withString:@""];
        field = [field stringByReplacingOccurrencesOfString:@")" withString:@""];
    }
    
    return field;
}

#pragma mark - grid view delegate

- (NSUInteger) numberOfItemsInGridView:(AQGridView *) aGridView {
    return ( 1 + [self.records count] ) * [[self.relatedList columns] count];
}

- (CGSize) portraitGridCellSizeForGridView:(AQGridView *) aGridView {
    return CGSizeMake( lroundf( self.gridView.frame.size.width / [[self.relatedList columns] count] ) - 1, 
                      cellHeight );
}

- (AQGridViewCell *) gridView:(AQGridView *)aGridView cellForItemAtIndex:(NSUInteger)index {    
    AccountGridCell *cell = [AccountGridCell cellForGridView:aGridView];
    
    cell.selectionStyle = AQGridViewCellSelectionStyleNone;
    cell.gridLabel.numberOfLines = 3;
    
    NSArray *colFields = [self.relatedList columns];
    
    int recordRow = index / [colFields count];
    int recordCol = index % [colFields count];
    
    ZKRelatedListColumn *col = [colFields objectAtIndex:recordCol];
    
    // header row
    if( recordRow == 0 ) {
        NSString *gridText = [col label];
        
        // Is this column being sorted? Indicate with an arrow.
        if( self.sortColumn && [self.sortColumn isEqualToString:[[self class] sanitizeFieldName:[col name]]] )
            gridText = [gridText stringByAppendingString:( self.sortAscending ? upArrow : downArrow )];
        
        cell.gridLabel.text = gridText;
        cell.gridLabel.textColor = ( canSortGridColumns ? AppLinkColor : [UIColor darkTextColor] );
        cell.gridLabel.textAlignment = UITextAlignmentCenter;
        [cell.gridLabel setFont:[UIFont boldSystemFontOfSize:16]];
        cell.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"gridGradient.png"]];
    } else {
        ZKSObject *record = [self.records objectAtIndex:( recordRow - 1 )];
        NSString *field = [[self class] sanitizeFieldName:[col name]];
        NSString *type = [record type];
        
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[record fields]];
        
        if( [type isEqualToString:@"ActivityHistory"] || [type isEqualToString:@"OpenActivity"] )
            type = @"Task";
        
        [d setObject:type forKey:@"sObjectType"];
                        
        cell.gridLabel.text = [[AccountUtil sharedAccountUtil] textValueForField:field
                                                                  withDictionary:d];
        
        if( canViewRecordDetail && ( [field isEqualToString:nameField] || ( recordCol == 0 && ![record fieldValue:nameField] ) ) ) {
            cell.gridLabel.textColor = AppLinkColor;
            [cell.gridLabel setFont:[UIFont boldSystemFontOfSize:15]];
        } else {
            cell.gridLabel.textColor = [UIColor darkGrayColor];
            [cell.gridLabel setFont:[UIFont systemFontOfSize:14]];
        }
        
        cell.gridLabel.textAlignment = UITextAlignmentCenter;
        cell.backgroundColor = [UIColor clearColor];
    }
    
    CGSize s = [self portraitGridCellSizeForGridView:aGridView];
    [cell setFrame:CGRectMake(0, 0, s.width, s.height)];
    
    [cell.gridLabel setFrame:CGRectMake( 3, 3, s.width - 6, s.height - 6 )];
        
    return cell;
}

- (void) gridView:(AQGridView *)gv didSelectItemAtIndex:(NSUInteger)index {  
    NSArray *columns = [self.relatedList columns];
    
    int recordRow = index / [columns count];
    int recordCol = index % [columns count];
    
    [gv deselectItemAtIndex:index animated:NO];
    
    ZKRelatedListColumn *col = [columns objectAtIndex:recordCol];
    
    if( recordRow > [self.records count] )
        return;
    
    if( recordRow == 0 ) {     
        // Activity History and Open Activities can't be sorted
        if( !canSortGridColumns )
            return;
        
        // Did we select a new column? default to descending
        if( ![self.sortColumn isEqualToString:[[self class] sanitizeFieldName:[col name]]] ) {
            self.sortColumn = [[self class] sanitizeFieldName:[col name]];
            self.sortAscending = NO;
        } else
            self.sortAscending = !self.sortAscending;
                
        [DSBezelActivityView newActivityViewForView:self.view];
        [self loadRecords];
    } else if( recordCol == 0 ) {
        ZKSObject *record = [self.records objectAtIndex:( recordRow - 1 )];
        
        if( canViewRecordDetail ) {
            [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:NO];
            [self.detailViewController addFlyingWindow:FlyingWindowRelatedRecordView withArg:record];  
        } else
            NSLog(@"invalid sObject for layout/query: %@", [self sObjectNameForRelatedList:sObjectNormal]);
    }
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    [self flyingWindowDidTap:nil];
}


@end
