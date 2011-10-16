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

#import "ListOfRelatedListsViewController.h"
#import "PRPSmartTableViewCell.h"
#import "RelatedListGridView.h"
#import "DetailViewController.h"
#import "AccountUtil.h"
#import "zkSforce.h"

@implementation ListOfRelatedListsViewController

@synthesize relatedLists, tableView, listRecordCounts;

static float rowHeight = 50.0f;

// Maximum number of child relationships we can subquery at once
static int maxRelationshipsInSingleQuery = 20;

int totalRelationshipQueriesExecuted;

- (id) initWithFrame:(CGRect)frame {
    if(( self = [super initWithFrame:frame] )) {
        float curY = self.navBar.frame.size.height;
        
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"panelBG.png"]];
        
        self.listRecordCounts = [NSMutableDictionary dictionary];
        totalRelationshipQueriesExecuted = 0;
                
        // table view
        self.tableView = [[[UITableView alloc] initWithFrame:CGRectMake( 0, curY, 
                                                                        frame.size.width, 
                                                                        frame.size.height - curY )
                                                       style:UITableViewStylePlain] autorelease];
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        // Table Footer            
        UIImage *i = [UIImage imageNamed:@"tilde.png"];
        UIImageView *iv = [[[UIImageView alloc] initWithImage:i] autorelease];
        iv.alpha = 0.25f;
        [iv setFrame:CGRectMake( lroundf( ( self.tableView.frame.size.width - i.size.width ) / 2.0f ), 10, i.size.width, i.size.height )];
        
        UIView *footerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 70 )] autorelease];
        [footerView addSubview:iv];
        self.tableView.tableFooterView = footerView;
        
        [self.view addSubview:self.tableView];
        
        UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:NSLocalizedString(@"Related Lists", @"Related Lists")];
        item.hidesBackButton = YES; 
        item.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Account News", nil)
                                                                    style:UIBarButtonItemStyleBordered
                                                                   target:self
                                                                   action:@selector(toggleNews)] autorelease];
        [self.navBar pushNavigationItem:item animated:YES];
        [item release];
    }
        
    return self;
}

- (void) selectAccount:(NSDictionary *)acc {
    [super selectAccount:acc];
    
    ZKDescribeLayout *layout = [[AccountUtil sharedAccountUtil] layoutForRecord:acc];
    
    self.relatedLists = [NSArray array];
    [self.listRecordCounts removeAllObjects];
    totalRelationshipQueriesExecuted = 0;
    
    // Apply a manual related list filter. Certain related lists are tied to sObjects that cannot be queried,
    // so we won't render them in the list.
    for( ZKRelatedList *list in [layout relatedLists] ) {
        ZKDescribeGlobalSObject *sObject = [[AccountUtil sharedAccountUtil] describeGlobalsObject:[list sobject]];
        
        if( ( sObject && [sObject queryable] && ![sObject deprecatedAndHidden] ) ||
            ( [[NSArray arrayWithObjects:@"ActivityHistory", @"OpenActivity", nil] containsObject:[list sobject]] ) )
            self.relatedLists = [self.relatedLists arrayByAddingObject:list];
        else
            NSLog(@"Unqueryable Related List %@, not displaying in table.", [list sobject]);        
    }    
    
    [self.tableView reloadData];
    [self loadListCounts];
}

- (void) loadListCounts {
    if( !self.relatedLists || [self.relatedLists count] == 0 )
        return;
    
    NSMutableString *soql = [NSMutableString stringWithString:@"select id"];
    int count = 0;
    
    for( int x = totalRelationshipQueriesExecuted; x < [self.relatedLists count]; x++ ) {
        if( count >= maxRelationshipsInSingleQuery )
            break;
        
        ZKRelatedList *list = [self.relatedLists objectAtIndex:x];
                        
        if( [[list sobject] isEqualToString:@"ActivityHistory"] )
            [soql appendString:@", (select id, createddate from ActivityHistories order by activitydate desc, lastmodifieddate desc limit 500)"];
        else if( [[list sobject] isEqualToString:@"OpenActivity"] )
            [soql appendString:@", (select id, createddate from OpenActivities order by activitydate asc, lastmodifieddate desc limit 500)"];
        else
            [soql appendFormat:@", (select id from %@ limit 200)", [list name]];
        
        count++;
    }
    
    totalRelationshipQueriesExecuted += count;
    
    [soql appendFormat:@" from Account where id='%@' limit 1", [self.account objectForKey:@"Id"]];
    
    NSLog(@"SOQL: %@", soql);
    
    [[AccountUtil sharedAccountUtil] startNetworkAction];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
        ZKQueryResult *results = nil;
        
        @try {
            results = [[[AccountUtil sharedAccountUtil] client] query:soql];
        } @catch( NSException *e ) { 
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            [[AccountUtil sharedAccountUtil] receivedException:e];
            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            
            if( results && [results records] && [[results records] count] > 0 ) {
                ZKSObject *accResult = [[results records] objectAtIndex:0];
                
                for( NSString *relationship in [accResult fields] ) {
                    if( [relationship isEqualToString:@"Id"] )
                        continue;
                    
                    if( ![AccountUtil isEmpty:[accResult fieldValue:relationship]] ) {
                        NSArray *relatedRecords = [[accResult fieldValue:relationship] records];
                                                
                        if( relatedRecords && [relatedRecords count] > 0 ) {
                            if( [relationship isEqualToString:@"ActivityHistories"] || [relationship isEqualToString:@"OpenActivities"] )
                                relatedRecords = [AccountUtil filterRecords:relatedRecords 
                                                                  dateField:@"CreatedDate" 
                                                                   withDate:[NSDate dateWithTimeIntervalSinceNow:-(60 * 60 * 24 * 365 )] 
                                                               createdAfter:YES];
                            
                            [self.listRecordCounts setObject:[NSNumber numberWithInt:[relatedRecords count]] forKey:relationship];
                        }
                    } else
                        [self.listRecordCounts setObject:[NSNumber numberWithInt:0] forKey:relationship];
                }
            }
                 
            NSMutableArray *rowsToReload = [NSMutableArray arrayWithCapacity:maxRelationshipsInSingleQuery];
            
            for( int x = totalRelationshipQueriesExecuted - count; x < totalRelationshipQueriesExecuted; x++ )
                [rowsToReload addObject:[NSIndexPath indexPathForRow:x inSection:0]];
                
            [self.tableView reloadRowsAtIndexPaths:rowsToReload withRowAnimation:UITableViewRowAnimationFade];
            
            // More lists to query?
            if( totalRelationshipQueriesExecuted < [self.relatedLists count] )
                [self loadListCounts];
        });
    });
}

- (void)dealloc {
    [tableView release];
    [relatedLists release];
    [listRecordCounts release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - switching back to news

- (void) toggleNews {    
    // Pop everything off after this list, then slide it offscreen
    [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:NO];
    [self slideFlyingWindowToPoint:CGPointMake( 1200, self.view.center.y )];
    
    [self performSelector:@selector(delayedLaunchNews)
               withObject:nil
               afterDelay:0.3];
}

- (void) delayedLaunchNews {
    [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:YES];
    [self.detailViewController addFlyingWindow:FlyingWindowNews withArg:nil];
}

#pragma mark - related list images

+ (UIImage *) imageForRelatedList:(ZKRelatedList *)relatedList {
    NSString *format = @"%@32.png";
    NSString *sObject = [[relatedList sobject] lowercaseString];
        
    if( [relatedList custom] )
        sObject = @"custom";
    else if( [sObject isEqualToString:@"accountcontactrole"] )
        sObject = @"contact";
    else if( [sObject isEqualToString:@"accountteammember"] )
        sObject = @"account";
    else if( [sObject isEqualToString:@"contentversion"] )
        sObject = @"noteandattachment";
    
    return [UIImage imageNamed:[NSString stringWithFormat:format, sObject]];
}

#pragma mark - table view delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.relatedLists count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return rowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PRPSmartTableViewCell *cell = [PRPSmartTableViewCell cellForTableView:tv];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
    
    ZKRelatedList *list = [self.relatedLists objectAtIndex:indexPath.row];
    NSString *recordCount = nil;

    if( indexPath.row >= totalRelationshipQueriesExecuted || [self.listRecordCounts count] == 0 )
        recordCount = NSLocalizedString(@"Loading...", nil);
    else if( [self.listRecordCounts objectForKey:[list name]] ) {        
        int num = [[self.listRecordCounts objectForKey:[list name]] intValue];
        
        BOOL mightHaveMore = [[list name] isEqualToString:@"OpenActivities"] || [[list name] isEqualToString:@"ActivityHistories"] ?
                                num >= 500 : num >= 200;
        
        if( num > 0 ) {
            recordCount = [NSString stringWithFormat:@"%i%@%@", 
                           num,
                           ( mightHaveMore ? @"+ " : @" " ),
                           ( num > 1 ? NSLocalizedString(@"Records", nil) : NSLocalizedString(@"Record", nil) )];
            cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:14];
        } else
            recordCount = NSLocalizedString(@"No Records", nil);
    } else
        recordCount = NSLocalizedString(@"No Records", nil);
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.text = [list label]; 
    cell.textLabel.textColor = AppLinkColor;
    cell.detailTextLabel.text = recordCount;
    cell.selectedBackgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"leftgradient.png"]] autorelease];
    cell.imageView.image = [[self class] imageForRelatedList:list];
    
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {    
    ZKRelatedList *list = [self.relatedLists objectAtIndex:indexPath.row];
        
    [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:NO];
    [self.detailViewController addFlyingWindow:FlyingWindowRelatedListGrid withArg:[list sobject]];
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    [self flyingWindowDidTap:nil];
}

#pragma mark - View lifecycle

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
	return YES;
}

@end
