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

#import "ObjectLookupController.h"
#import "PRPSmartTableViewCell.h"
#import "PRPConnection.h"
#import "SimpleKeychain.h"
#import "RootViewController.h"

@implementation ObjectLookupController

@synthesize searchBar, resultTable, searchResults, resultLabel, delegate, searchIcon, imageLoaders;

static float searchDelay = 0.4f;

enum ResultTableSections {
    SectionUsers = 0,
    SectionGroups = 1,
    SectionAccounts = 2,
    SectionNumSections
};

- (id) init {
    if(( self = [super init] )) {
        self.contentSizeForViewInPopover = CGSizeMake( 250, 44 * 6 );
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"tableBG.png"]];
        
        searching = NO;
        
        self.searchResults = [NSMutableDictionary dictionary];
        self.imageLoaders = [NSMutableDictionary dictionary];
        
        // search bar
        self.searchBar = [[[UISearchBar alloc] initWithFrame:CGRectMake( 0, 0, self.contentSizeForViewInPopover.width, 44 )] autorelease];
        
        // Removes background
        [[self.searchBar.subviews objectAtIndex:0] removeFromSuperview];
        
        if( [[AccountUtil sharedAccountUtil] isObjectChatterEnabled:@"Account"] )
            self.searchBar.placeholder = NSLocalizedString(@"Account, Group, or User", @"Searching for an account, group, or user");
        else        
            self.searchBar.placeholder = NSLocalizedString(@"User or Group", @"Searching for a user or group");
        
        self.searchBar.delegate = self;
        [self.view addSubview:self.searchBar];
        
        // result label
        self.resultLabel = [[[UILabel alloc] initWithFrame:CGRectMake( 0, 
                                                                      self.searchBar.frame.size.height + lroundf( ( self.contentSizeForViewInPopover.height - self.searchBar.frame.size.height - 30 ) / 2.0f ), 
                                                                      self.contentSizeForViewInPopover.width, 30 )] autorelease];
        [self.resultLabel setFont:[UIFont boldSystemFontOfSize:20]];
        self.resultLabel.textColor = [UIColor lightGrayColor];
        self.resultLabel.backgroundColor = [UIColor clearColor];
        self.resultLabel.textAlignment = UITextAlignmentCenter;
        [self.view addSubview:self.resultLabel];
        
        // search icon
        UIImage *icon = [UIImage imageNamed:@"searchicon.png"];
        self.searchIcon = [[[UIImageView alloc] initWithImage:icon] autorelease];
        [self.searchIcon setFrame:CGRectMake( lroundf( ( self.contentSizeForViewInPopover.width - icon.size.width ) / 2.0f ), 
                                             self.searchBar.frame.size.height + lroundf( ( self.contentSizeForViewInPopover.height - icon.size.height - self.searchBar.frame.size.height ) / 2.0f ), 
                                             icon.size.width, icon.size.height )];
        [self.view addSubview:self.searchIcon];
        
        // result table
        self.resultTable = [[[UITableView alloc] initWithFrame:CGRectMake( 0, self.searchBar.frame.size.height, 
                                                                          self.contentSizeForViewInPopover.width, 
                                                                          self.contentSizeForViewInPopover.height - self.searchBar.frame.size.height )
                                                         style:UITableViewStylePlain] autorelease];
        self.resultTable.backgroundColor = [UIColor clearColor];
        self.resultTable.separatorColor = [UIColor darkGrayColor];
        self.resultTable.delegate = self;
        self.resultTable.dataSource = self;
        self.resultTable.hidden = YES;
        [self.view addSubview:self.resultTable];
    }
    
    return self;
}

- (void)dealloc {
    [searchBar release];
    [searchResults release];
    [resultTable release];
    [searchIcon release];
    [resultLabel release];
    [imageLoaders release];
    [super dealloc];
}

#pragma mark - table view

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [UIImage imageNamed:@"sectionheader.png"].size.height;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIImageView *sectionView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sectionheader.png"]];
    
    UILabel *customLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, -1, sectionView.frame.size.width, sectionView.frame.size.height )];
    customLabel.textColor = AppSecondaryColor;
    customLabel.text = [self tableView:tableView titleForHeaderInSection:section];
    customLabel.font = [UIFont boldSystemFontOfSize:16];
    customLabel.backgroundColor = [UIColor clearColor];
    [sectionView addSubview:customLabel];
    [customLabel release];
    
    return [sectionView autorelease];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {    
    NSString *key = [[self.searchResults allKeys] objectAtIndex:section];
    return [[self.searchResults objectForKey:key] count];
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.searchResults count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *key = [[self.searchResults allKeys] objectAtIndex:section];
    NSString *type = [[[self.searchResults objectForKey:key] objectAtIndex:0] type];    
    
    type = [type isEqualToString:@"CollaborationGroup"] ? 
        NSLocalizedString(@"Chatter Groups", @"Chatter Groups") : 
        [NSString stringWithFormat:@"%@s", NSLocalizedString(type, @"sObject Type")];
    
    return [type stringByAppendingFormat:@" (%i)", [self tableView:tableView numberOfRowsInSection:section]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PRPSmartTableViewCell *cell = [PRPSmartTableViewCell cellForTableView:tableView];
    NSString *key = [[self.searchResults allKeys] objectAtIndex:indexPath.section];
    NSArray *sectionRecords = [self.searchResults objectForKey:key];
    
    if( !sectionRecords || [sectionRecords count] == 0 )
        return cell;
    
    ZKSObject *result = [sectionRecords objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [result fieldValue:@"Name"];
    cell.textLabel.textColor = [UIColor lightGrayColor];
    cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    
    if( [[result type] isEqualToString:@"CollaborationGroup"] )
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@, %@ Member%@",
                                     [result fieldValue:@"CollaborationType"],
                                     [result fieldValue:@"MemberCount"],
                                     ( [[result fieldValue:@"MemberCount"] intValue] != 1 ? @"s" : @"" )];
    else
        cell.detailTextLabel.text = @"";
    
    NSString *imgURL = [result fieldValue:@"SmallPhotoUrl"];
    
    if( [imgURL hasPrefix:@"/"] )
        imgURL = [NSString stringWithFormat:@"%@%@",
                    [SimpleKeychain load:instanceURLKey],
                    imgURL]; 
    
    if( imgURL && [[AccountUtil sharedAccountUtil] userPhotoFromCache:imgURL] )
        cell.imageView.image = [[AccountUtil sharedAccountUtil] userPhotoFromCache:imgURL];
    else if( imgURL ) {        
        cell.imageView.image = nil;
        
        if( ![self.imageLoaders objectForKey:imgURL] ) {                 
            PRPConnection *imgDownload = [PRPConnection connectionWithURL:[NSURL URLWithString:[imgURL stringByAppendingFormat:@"?oauth_token=%@",
                                                                                                [[[AccountUtil sharedAccountUtil] client] sessionId]]]
                                                            progressBlock:nil
                                                          completionBlock:^(PRPConnection *connection, NSError *error) {                                                              
                                                              NSString *downloadURL = [[connection url] absoluteString];
                                                              
                                                              NSString *actualURL = [downloadURL substringToIndex:
                                                                                     [downloadURL rangeOfString:@"?oauth_token"].location];
                                                              
                                                              NSArray *downloadInfo = [self.imageLoaders objectForKey:actualURL];
                                                              
                                                              // Get image
                                                              UIImage *img = [UIImage imageWithData:[connection downloadData]];
                                                              
                                                              if( img ) {
                                                                  [[AccountUtil sharedAccountUtil] addUserPhotoToCache:img forURL:actualURL];
                                                                  
                                                                  // Update this path in the table
                                                                  if( downloadInfo )
                                                                      [self.resultTable reloadRowsAtIndexPaths:[NSArray arrayWithObject:[downloadInfo objectAtIndex:0]]
                                                                                          withRowAnimation:UITableViewRowAnimationFade];
                                                                  else
                                                                      [self.resultTable reloadData];
                                                              }
                                                              
                                                              // Remove this loader
                                                              [self.imageLoaders removeObjectForKey:actualURL];
                                                      }];
            
            [self.imageLoaders setObject:[NSArray arrayWithObjects:indexPath, imgDownload, nil] forKey:imgURL];
        
            [imgDownload start];
        }        
    } else 
        cell.imageView.image = nil;
        
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    ZKSObject *ob = [[self.searchResults objectForKey:[[self.searchResults allKeys] objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
    
    if( [self.delegate respondsToSelector:@selector(objectLookupDidSelectRecord:record:)] )
        [self.delegate objectLookupDidSelectRecord:self record:ob];
}

#pragma mark - image download management

- (void) cancelDownloads {
    for( NSArray *arr in self.imageLoaders ) {
        PRPConnection *dl = [arr objectAtIndex:1];
        
        [dl stop];
    }
    
    [self.imageLoaders removeAllObjects];
}

#pragma mark - search bar delegate

- (void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if( !searchText || [searchText length] == 0 ) {
        searching = NO;
        [self.searchResults removeAllObjects];
        [self.resultTable reloadData];
        self.resultTable.hidden = YES;
        self.resultLabel.hidden = YES;
        self.searchIcon.hidden = NO;
        return;
    }
    
    NSString *text = [searchText stringByReplacingOccurrencesOfString:@"*" withString:@""];
    
    if( [text length] < 2 ) {
        searching = NO;
        [self.searchResults removeAllObjects];
        [self.resultTable reloadData];
        self.resultTable.hidden = YES;
        self.resultLabel.hidden = YES;
        self.searchIcon.hidden = NO;
        return;
    }
    
    self.resultLabel.hidden = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(search)
                                               object:nil];
    [self performSelector:@selector(search)
               withObject:nil
               afterDelay:searchDelay];
}

- (BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if( range.location >= 100 )
        return NO;
    
    NSMutableCharacterSet *validChars = [NSMutableCharacterSet characterSetWithCharactersInString:@" ;,.-@#"];
    [validChars formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
    
    NSCharacterSet *unacceptedInput = [validChars invertedSet];
    
    text = [[text lowercaseString] decomposedStringWithCanonicalMapping];
    
    return [[text componentsSeparatedByCharactersInSet:unacceptedInput] count] == 1;
}

- (void) searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self search];
}

#pragma mark - searching SFDC

- (void) search {    
    NSString *text = [NSString stringWithString:self.searchBar.text];
    
    if( [text length] < 2 )
        return;
    
    if( searching )
        return;
        
    NSString *sosl = [NSString stringWithFormat:@"FIND {%@*} IN NAME FIELDS RETURNING User (id, name, smallphotourl WHERE isactive=true and ( usertype='Standard' or usertype = 'CSNOnly' ) ORDER BY lastname asc ), CollaborationGroup (id, name, collaborationtype, membercount, smallphotourl ORDER BY name asc)", 
                      text];
    
    if( [[AccountUtil sharedAccountUtil] isObjectChatterEnabled:@"Account"] )
        sosl = [sosl stringByAppendingString:@", Account (id, name ORDER BY name asc)"];
    
    NSLog(@"SOSL: %@", sosl);
    
    [self cancelDownloads];
    [[AccountUtil sharedAccountUtil] startNetworkAction];
    self.resultLabel.text = NSLocalizedString(@"Searching...", @"Searching...");
    searching = YES;
    self.resultLabel.hidden = NO;
    self.searchIcon.hidden = YES;
    self.resultTable.hidden = YES;
    
    // Notify delegate
    if( [self.delegate respondsToSelector:@selector(objectLookupDidSearch:search:)] )
        [self.delegate objectLookupDidSearch:self search:text];
    
    // Execute search
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
        NSArray *results = nil;
        
        @try {
            results = [[[AccountUtil sharedAccountUtil] client] search:sosl];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            [[AccountUtil sharedAccountUtil] receivedException:e];
            searching = NO;
            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            [self.searchResults removeAllObjects];
            
            // The user may have wiped or changed the search field during this search
            if( [self.searchBar.text length] == 0 ) {
                searching = NO;
                self.searchIcon.hidden = NO;
                self.resultTable.hidden = YES;
                self.resultLabel.hidden = YES;
                
                [self.resultTable reloadData];
                return;
            }
            
            // The user changed the text of the search while it was ongoing. re-search
            if( [self.searchBar.text length] >= 2 && ![self.searchBar.text isEqualToString:text] ) {
                searching = NO;
                [self search];
                return;
            }
        
            if( !results || [results count] == 0 ) {
                self.resultLabel.text = NSLocalizedString(@"No Results", @"No Results");
                self.resultLabel.hidden = NO;
                self.resultTable.hidden = YES;
                searching = NO;
                
                [self.resultTable reloadData];
            } else {
                NSMutableDictionary *groupsToCheck = [NSMutableDictionary dictionary];
                
                for( ZKSObject *ob in results ) {
                    NSString *type = [NSString stringWithFormat:@"%@s", 
                                      ( [[ob type] isEqualToString:@"CollaborationGroup"] ? @"Group" : [ob type] )];
                    
                    if( [[ob type] isEqualToString:@"CollaborationGroup"] )
                        [groupsToCheck setObject:ob forKey:[ob id]];
                    else if( ![self.searchResults objectForKey:type] )
                        [self.searchResults setObject:[NSMutableArray arrayWithObject:ob] forKey:type];
                    else
                        [[self.searchResults objectForKey:type] addObject:ob];
                }
                                
                // We can only post to groups of which we are a member, even as a sysadmin.
                if( [groupsToCheck count] > 0 ) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
                        ZKQueryResult *groupMemberships = nil;
                        NSString *memberquery = [NSString stringWithFormat:@"select id, collaborationgroupid from CollaborationGroupMember where memberid='%@'",
                                                 [[[[AccountUtil sharedAccountUtil] client] currentUserInfo] userId]];
                        
                        NSLog(@"SOQL: %@", memberquery);
                        
                        @try {
                            groupMemberships = [[[AccountUtil sharedAccountUtil] client] query:memberquery];
                        } @catch( NSException *e ) {
                            [[AccountUtil sharedAccountUtil] receivedException:e];
                        }
                        
                        dispatch_async(dispatch_get_main_queue(), ^(void) {
                            if( [groupMemberships records] && [[groupMemberships records] count] > 0 )
                                for( ZKSObject *membership in [groupMemberships records] ) {
                                    NSString *groupId = [membership fieldValue:@"CollaborationGroupId"];

                                    if( [groupsToCheck objectForKey:groupId] ) {
                                        if( ![self.searchResults objectForKey:@"Groups"] )
                                            [self.searchResults setObject:[NSMutableArray arrayWithObject:[groupsToCheck objectForKey:groupId]] forKey:@"Groups"];
                                        else
                                            [[self.searchResults objectForKey:@"Groups"] addObject:[groupsToCheck objectForKey:groupId]];
                                    }
                                }
                                                        
                            if( [self.searchResults count] == 0 ) {
                                self.resultLabel.text = NSLocalizedString(@"No Results", @"No Results");
                                self.resultLabel.hidden = NO;
                                self.resultTable.hidden = YES;
                            } else {
                                self.resultLabel.hidden = YES;
                                self.resultTable.hidden = NO;
                            }
                            
                            searching = NO;
                            [self.resultTable reloadData];
                            [self.resultTable setContentOffset:CGPointZero animated:NO];
                        });
                    });
                } else {
                    self.resultLabel.hidden = YES;
                    self.resultTable.hidden = NO;
                    searching = NO;
                                    
                    [self.resultTable reloadData];
                    [self.resultTable setContentOffset:CGPointZero animated:NO];
                }
            }
        });
    });
}

#pragma mark - View lifecycle

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
	return YES;
}

@end
