/* 
 * Copyright (c) 2011, salesforce.com, inc.
 * Author: Jonathan Hersh
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

#import "AccountsAppDelegate.h"
#import "SubNavViewController.h"
#import "AccountUtil.h"
#import "RecordDetailViewController.h"
#import "RootViewController.h"
#import "DetailViewController.h"
#import "PRPSmartTableViewCell.h"
#import "DSActivityView.h"
#import <QuartzCore/QuartzCore.h>
#import "PullRefreshTableViewController.h"
#import "PRPAlertView.h"
#import "zkSforce.h"

@implementation SubNavViewController

@synthesize myRecords, detailViewController, searchBar, searchResults, rootViewController, navigationBar, titleButton, pullRefreshTableViewController, subNavTableType, listActionSheet, rowCountLabel, bottomBar;

// Maximum length of a search term
static int maxSearchLength = 35;

// Delay, in seconds, between keying a character into the search bar and firing SOSL
static float searchDelay = 0.4f;

// Tag used to locate the helper view
static int helperTag = 11;

static NSString *indexAlphabet = @"#ABCDEFGHIJKLMNOPQRSTUVWXYZ";

- (id) initWithTableType:(enum SubNavTableType)tableType {
    if((self = [super init])) {
        [self.view setFrame:CGRectMake(0, 0, masterWidth, 748)];
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"tableBG.png"]];
        self.view.autoresizingMask = UIViewAutoresizingNone;
        
        myRecords = [[NSMutableDictionary alloc] init];
        searchResults = [[NSMutableArray alloc] init];
        
        helperViewVisible = NO;
        subNavTableType = tableType;
        storedSize = 0;
        letUserSelectRow = YES;
        searching = NO;
        
        int curY = 10;
        
        // Top section
        UIView *tableHeader = [[[UIView alloc] init] autorelease];
        tableHeader.backgroundColor = [UIColor clearColor];
        tableHeader.autoresizingMask = UIViewAutoresizingNone;
        
        // Title, gear, search bar background        
        UIImageView *bgView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"leftbg.png"]] autorelease];
        bgView.userInteractionEnabled = NO;
        [bgView setFrame:CGRectMake(0, curY - 5, masterWidth, 0)];
        
        [tableHeader addSubview:bgView];
        
        // Title
        if( !self.titleButton ) {
            self.titleButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [titleButton setFrame:CGRectMake( 10, curY, 170, 20)];
            [titleButton setTitleColor:UIColorFromRGB(0xbababa) forState:UIControlStateNormal];
            [titleButton.titleLabel setFont:[UIFont boldSystemFontOfSize:16]];
            titleButton.titleLabel.shadowColor = [UIColor blackColor];
            titleButton.titleLabel.shadowOffset = CGSizeMake( 0, 2 );
            titleButton.backgroundColor = [UIColor clearColor];            
            titleButton.titleLabel.textAlignment = UITextAlignmentLeft;
            
            [titleButton addTarget:self action:@selector(showListActions:) forControlEvents:UIControlEventTouchUpInside];
            [titleButton setTitleColor:[UIColor darkTextColor] forState:UIControlStateHighlighted];
            
            [tableHeader addSubview:self.titleButton];
        }
        
        curY += titleButton.frame.size.height + 2;
        
        // search bar
        if( !self.searchBar ) {
            self.searchBar = [[[UISearchBar alloc] initWithFrame:CGRectMake(0, curY, masterWidth, 44)] autorelease];
            searchBar.placeholder = ( subNavTableType == SubNavLocalAccounts ? 
                                     NSLocalizedString(@"Search Local Accounts", @"Searching local accounts") : 
                                     NSLocalizedString(@"Search All Accounts", @"Searching all accounts") );
            searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
            searchBar.keyboardType = UIKeyboardTypeAlphabet;
            searchBar.delegate = self;
            
            // background
            [[searchBar.subviews objectAtIndex:0] removeFromSuperview];
            
            // return button            
            for (UIView *view in searchBar.subviews)
                if ([view isKindOfClass: [UITextField class]]) {
                    UITextField *tf = (UITextField *)view;
                    tf.delegate = self;
                    break;
                }
                        
            [tableHeader addSubview:searchBar];
        }
        
        curY += searchBar.frame.size.height;
        
        if( subNavTableType == SubNavLocalAccounts ) {
            if( !self.navigationBar ) {
                TransparentNavigationBar *navbar = [[TransparentNavigationBar alloc] initWithFrame:CGRectMake( 0, curY, masterWidth, 40)];
                navbar.tintColor = [UIColor blackColor];
                
                self.navigationBar = navbar;
                [navbar release];
                
                [tableHeader addSubview:self.navigationBar];
            }
            
            [self setupNavBar];
            
            curY += self.navigationBar.frame.size.height;
        }
        
        // size the background properly
        CGRect bgFrame = bgView.frame;
        bgFrame.size.height = curY - bgFrame.origin.y;
        [bgView setFrame:bgFrame];
        
        [tableHeader setFrame:CGRectMake(0, 0, masterWidth, curY)];
        [self.view addSubview:tableHeader];
        
        // table view
        if( !self.pullRefreshTableViewController ) {
            UITableViewController *ptvc = nil;
            
            if( subNavTableType == SubNavLocalAccounts )
                ptvc = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
            else
                ptvc = (PullRefreshTableViewController *)[[PullRefreshTableViewController alloc] initWithStyle:UITableViewStylePlain useHeaderImage:NO];
            
            ptvc.tableView.delegate = self;
            ptvc.tableView.dataSource = self;
            
            ptvc.tableView.backgroundColor = [UIColor clearColor];
            ptvc.tableView.separatorColor = UIColorFromRGB(0x252525);
            ptvc.tableView.sectionIndexMinimumDisplayRowCount = 6;
                        
            self.pullRefreshTableViewController = ptvc;
            [ptvc release];
            
            // Table Footer            
            UIImage *i = [UIImage imageNamed:@"tilde.png"];
            UIImageView *iv = [[[UIImageView alloc] initWithImage:i] autorelease];
            iv.alpha = 0.25f;
            [iv setFrame:CGRectMake( lroundf( ( masterWidth - i.size.width ) / 2.0f ), 10, i.size.width, i.size.height )];
            
            UIView *footerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, masterWidth, 70 )] autorelease];
            [footerView addSubview:iv];
            
            self.pullRefreshTableViewController.tableView.tableFooterView = footerView;
            
            CGRect r = self.view.frame;
            r.origin.y = tableHeader.frame.size.height;
            r.size.height = self.view.frame.size.height - r.origin.y - 52;
            [self.pullRefreshTableViewController.tableView setFrame:r];
            
            [self.view addSubview:self.pullRefreshTableViewController.view];
            
            curY += r.size.height;
        }
        
        if( !self.rowCountLabel ) {
            self.rowCountLabel = [[[UILabel alloc] initWithFrame:CGRectMake( 0, 0, 150, 35 )] autorelease];
            rowCountLabel.backgroundColor = [UIColor clearColor];
            rowCountLabel.font = [UIFont boldSystemFontOfSize:15];
            rowCountLabel.shadowColor = [UIColor blackColor];
            rowCountLabel.shadowOffset = CGSizeMake( 0, 2 );
            rowCountLabel.textColor = [UIColor lightGrayColor];
            rowCountLabel.textAlignment = UITextAlignmentCenter;
        }
        
        // bottom bar
        if( !self.bottomBar ) {
            self.bottomBar = [[[TransparentToolBar alloc] initWithFrame:CGRectMake( 0, curY, masterWidth, 52)] autorelease];
            self.bottomBar.tintColor = [UIColor clearColor];
            
            // bar shadow
            CAGradientLayer *shadowLayer = [CAGradientLayer layer];
            shadowLayer.backgroundColor = [UIColor clearColor].CGColor;
            shadowLayer.frame = CGRectMake(0, -5, masterWidth, 5);
            shadowLayer.shouldRasterize = YES;
            
            shadowLayer.colors = [NSArray arrayWithObjects:(id)[UIColor colorWithWhite:0.0 alpha:0.01].CGColor,
                                  (id)[UIColor colorWithWhite:0.0 alpha:0.2].CGColor,
                                  (id)[UIColor colorWithWhite:0.0 alpha:0.4].CGColor,
                                  (id)[UIColor colorWithWhite:0.0 alpha:0.8].CGColor, nil];		
            
            shadowLayer.startPoint = CGPointMake(0.0, 0.0);
            shadowLayer.endPoint = CGPointMake(0.0, 1.0);
            
            shadowLayer.shadowPath = [UIBezierPath bezierPathWithRect:shadowLayer.bounds].CGPath;
            
            [self.bottomBar.layer addSublayer:shadowLayer];
            
            
            UIImage *buttonImage = [UIImage imageNamed:@"gear.png"];
            
            UIButton *gearButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [gearButton setImage:buttonImage forState:UIControlStateNormal];
            [gearButton addTarget:self
                           action:@selector(showSettings:)
                 forControlEvents:UIControlEventTouchUpInside];
            [gearButton setFrame:CGRectMake( 0, 0, buttonImage.size.width, buttonImage.size.height )];
            
            UIBarButtonItem *gear = [[[UIBarButtonItem alloc] initWithCustomView:gearButton] autorelease];
            
            UIBarButtonItem *space = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                    target:nil
                                                                                    action:nil] autorelease];
            
            buttonImage = [UIImage imageNamed:@"home.png"];
            
            UIButton *homeButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [homeButton setImage:buttonImage forState:UIControlStateNormal];
            [homeButton addTarget:self
                           action:@selector(tappedLogo:)
                 forControlEvents:UIControlEventTouchUpInside];
            [homeButton setFrame:CGRectMake( 0, 0, buttonImage.size.width, buttonImage.size.height )];
            
            UIBarButtonItem *home = [[[UIBarButtonItem alloc] initWithCustomView:homeButton] autorelease];
            
            UIBarButtonItem *count = [[[UIBarButtonItem alloc] initWithCustomView:self.rowCountLabel] autorelease];
            
            [self.bottomBar setItems:[NSArray arrayWithObjects:home, space, count, space, gear, nil] animated:YES];
            
            [self.view addSubview:self.bottomBar];
        }
    }
    
    return self;
}

- (void) refresh {
    [self refresh:YES];
}

- (void) refresh:(BOOL) resetRefresh {    
    [titleButton setTitle:[self whichList] forState:UIControlStateNormal];    
    [titleButton sizeToFit];
    
    if( searching ) {
        [self searchTableView];
        return;
    }
    
    if( subNavTableType == SubNavLocalAccounts ) {
        NSArray *accounts = [[AccountUtil getAllAccounts] allValues];
        
        [self refreshResult:accounts];
        return;
    }
    
    if( ![[[AccountUtil sharedAccountUtil] client] loggedIn] || ![[[AccountUtil sharedAccountUtil] client] currentUserInfo] )
        return;
    
    [[AccountUtil sharedAccountUtil] startNetworkAction];
    [DSBezelActivityView newActivityViewForView:self.view];
    
    if( subNavTableType == SubNavFollowedAccounts ) {        
        // Refresh the list of accounts I'm following, then query those IDs
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
            @try {
                [[AccountUtil sharedAccountUtil] refreshFollowedAccounts:[[[AccountUtil sharedAccountUtil] client] currentUserInfo].userId];
            } @catch( NSException *e ) {
                [[AccountUtil sharedAccountUtil] endNetworkAction];
                [DSBezelActivityView removeViewAnimated:YES];
                [[AccountUtil sharedAccountUtil] receivedException:e];
                [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                
                [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                                    message:NSLocalizedString(@"Failed to load Accounts.", @"Account query failed")
                                cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                cancelBlock:nil 
                                 otherTitle:NSLocalizedString(@"Retry", @"Retry")
                                 otherBlock: ^(void) {
                                     [self refresh];
                                 }];
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                // Do we follow any accounts?
                if( [[[AccountUtil sharedAccountUtil] getFollowedAccounts] count] == 0 ) {
                    [[AccountUtil sharedAccountUtil] endNetworkAction];
                    [DSBezelActivityView removeViewAnimated:YES];
                    [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                    rowCountLabel.text = NSLocalizedString(@"No Accounts", @"No Accounts");
                    return;
                }
                
                NSString *accountIDs = @"(";
                
                for( NSString *aID in [[AccountUtil sharedAccountUtil] getFollowedAccounts] ) {
                    if( [accountIDs length] > 9950 ) // soql query character limit is 10k
                        break;
                    
                    if( [accountIDs isEqualToString:@"("] )
                        accountIDs = [accountIDs stringByAppendingFormat:@"'%@'", aID];
                    else
                        accountIDs = [accountIDs stringByAppendingFormat:@", '%@'", aID];
                }
                
                accountIDs = [accountIDs stringByAppendingString:@")"];
                
                NSString *queryString = [NSString stringWithFormat:@"select id, name%@ from Account where id in %@ order by name asc limit 1000",
                                         ( [[AccountUtil sharedAccountUtil] hasRecordTypes] ? @", recordtypeid" : @"" ),
                                         accountIDs];
                
                NSLog(@"SOQL %@",queryString);
                
                // Nested async?
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
                    ZKQueryResult *qr = nil;
                    
                    @try {
                        qr = [[[AccountUtil sharedAccountUtil] client] query:queryString];
                    } @catch( NSException *e ) {
                        [[AccountUtil sharedAccountUtil] endNetworkAction];
                        [DSBezelActivityView removeViewAnimated:YES];
                        [[AccountUtil sharedAccountUtil] receivedException:e];
                        [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                        
                        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                                            message:NSLocalizedString(@"Failed to load Accounts.", @"Account query failed")
                                        cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                        cancelBlock:nil 
                                         otherTitle:NSLocalizedString(@"Retry", @"Retry")
                                         otherBlock: ^(void) {
                                             [self refresh];
                                         }];
                        
                        return;
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        [self refreshResult:[qr records]];
                    });
                });
            });
        });
    } else if( subNavTableType == SubNavOwnedAccounts ) {
        NSString *queryString = [NSString stringWithFormat:@"select id, name%@ from Account where ownerid='%@' order by name asc limit 1000",
                                 ( [[AccountUtil sharedAccountUtil] hasRecordTypes] ? @", recordtypeid" : @"" ),
                                 [[[[AccountUtil sharedAccountUtil] client] currentUserInfo] userId]];
        
        NSLog(@"SOQL %@",queryString);
        
        // run the query in the background thread, when its done, update the ui.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
            ZKQueryResult *qr = nil;
            
            @try {
                qr = [[[AccountUtil sharedAccountUtil] client] query:queryString];
            } @catch( NSException *e ) {
                [[AccountUtil sharedAccountUtil] endNetworkAction];
                [DSBezelActivityView removeViewAnimated:YES];
                [[AccountUtil sharedAccountUtil] receivedException:e];
                [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                
                [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                                    message:NSLocalizedString(@"Failed to load Accounts.", @"Account query failed")
                                cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                cancelBlock:nil 
                                 otherTitle:NSLocalizedString(@"Retry", @"Retry")
                                 otherBlock: ^(void) {
                                     [self refresh];
                                 }];
                
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self refreshResult:[qr records]];
            });
        });
    }
}

- (void) refreshResult:(NSArray *)results {
    [[AccountUtil sharedAccountUtil] endNetworkAction];
    [DSBezelActivityView removeViewAnimated:YES];

    if( [self.pullRefreshTableViewController respondsToSelector:@selector(stopLoading)] )
        [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
    
    NSString *selectedAccountId = nil;
    
    if( [self.pullRefreshTableViewController.tableView indexPathForSelectedRow] )
        selectedAccountId = [[AccountUtil accountFromIndexPath:[self.pullRefreshTableViewController.tableView indexPathForSelectedRow]
                                             accountDictionary:myRecords] objectForKey:@"Id"];
    
    // Clear out existing accounts on this list
    [myRecords removeAllObjects];
    
    if( results && [results count] > 0 ) {        
        myRecords = [[NSMutableDictionary dictionaryWithDictionary:[AccountUtil dictionaryFromAccountArray:results]] retain];
        
        storedSize = [results count];
        
        rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                              storedSize,
                              ( storedSize != 1 ? NSLocalizedString(@"Accounts", @"Account plural") : NSLocalizedString(@"Account", @"Account singular") )];
        
        if( helperViewVisible )
            [self toggleHelperView];
        
        [self.pullRefreshTableViewController.tableView reloadData];
        [self.pullRefreshTableViewController.tableView setContentOffset:CGPointZero animated:NO];
        [self selectAccountWithId:selectedAccountId];
        
        // With a new list of accounts in place, notify our detail view to display news for them
        // but only if it's not already displaying news
        if( self.detailViewController.subNavViewController == self && 
            ( !self.detailViewController.flyingWindows || [self.detailViewController.flyingWindows count] == 0 ) ) {
            [NSObject cancelPreviousPerformRequestsWithTarget:self.detailViewController selector:@selector(addAccountNewsTable) object:nil];
            [self.detailViewController performSelector:@selector(addAccountNewsTable) withObject:nil afterDelay:0.5];
        }
    } else {
        storedSize = 0;
        
        rowCountLabel.text = NSLocalizedString(@"No Accounts", @"No Accounts");
        
        if( !helperViewVisible )
            [self toggleHelperView];
    }
    
    if( subNavTableType == SubNavLocalAccounts )
        [self setupNavBar];
}

- (void)dealloc {
    [searchBar release];
    [searchResults release];
    [myRecords release];
    [rowCountLabel release];
    [pullRefreshTableViewController release];
    [listActionSheet release];
    [bottomBar release];
    
    [super dealloc];
}


#pragma mark - searching table view

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if( [self.pullRefreshTableViewController respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)] )
        [self.pullRefreshTableViewController scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if( [self.pullRefreshTableViewController respondsToSelector:@selector(scrollViewWillBeginDragging:)] )
        [self.pullRefreshTableViewController scrollViewWillBeginDragging:scrollView];
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    [searchBar resignFirstResponder];
    
    if( [self.pullRefreshTableViewController respondsToSelector:@selector(scrollViewDidScroll:)] )
        [self.pullRefreshTableViewController scrollViewDidScroll:scrollView];
}

- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar {
    searching = [theSearchBar.text length] > 0;
    
    //[searchBar setShowsCancelButton:searching animated:YES];
    //letUserSelectRow = NO;
    //self.tableView.scrollEnabled = NO;
}

- (BOOL) searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if( range.location >= maxSearchLength )
        return NO;
    
    NSMutableCharacterSet *validChars = [NSMutableCharacterSet characterSetWithCharactersInString:@" ;,.-"];
    [validChars formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
    
    NSCharacterSet *unacceptedInput = [validChars invertedSet];
    
    text = [[text lowercaseString] decomposedStringWithCanonicalMapping];
    
    return [[text componentsSeparatedByCharactersInSet:unacceptedInput] count] == 1;
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    return searching;
}

- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText {  
    if([searchText length] > 0) {
        searching = YES;
        
        // If this is a local search, fire it right away. Otherwise, wait for a delay
        if( subNavTableType == SubNavLocalAccounts )
            [self searchTableView];
        else {
            [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                     selector:@selector(searchTableView)
                                                       object:nil];
            
            [self performSelector:@selector(searchTableView)
                       withObject:nil
                       afterDelay:searchDelay];
        }
    } else {
        [[AccountUtil sharedAccountUtil] endNetworkAction];
        searching = NO;
        
        if( storedSize == 0 )
            rowCountLabel.text = NSLocalizedString(@"No Accounts", @"No Accounts");
        else
            rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                                  storedSize,
                                  ( storedSize != 1 ? NSLocalizedString(@"Accounts", @"Account plural") : NSLocalizedString(@"Account", @"Account singular") )];
        
        [titleButton setTitle:[self whichList] forState:UIControlStateNormal];
        [titleButton sizeToFit];
        
        [self.pullRefreshTableViewController.tableView reloadData];
    }
}

- (void) searchBarSearchButtonClicked:(UISearchBar *)theSearchBar {
    [searchBar resignFirstResponder];
    [self searchTableView];
}

- (void) cancelSearch {
    if( !searching )
        return;
    
    self.searchBar.text = @"";
    [self.searchBar resignFirstResponder];
    [self searchBar:self.searchBar textDidChange:@""];
}

- (void) searchTableView {    
    NSString *searchText = [NSString stringWithString:searchBar.text];
    
    searchText = [AccountUtil trimWhiteSpaceFromString:searchText];
    searchText = [searchText stringByReplacingOccurrencesOfString:@"*" withString:@""];
    
    if( [searchText length] < 2 )
        return;
    
    // Is this a search of local accounts?
    if( subNavTableType == SubNavLocalAccounts ) {
        NSMutableArray *searchArray = [NSMutableArray array];
        searchResults = [NSDictionary dictionary];
        
        for( NSArray *acclist in [myRecords allValues] )
            [searchArray addObjectsFromArray:acclist];
        
        NSMutableArray *resultArray = [NSMutableArray array];
        
        for( NSDictionary *account in searchArray )
            for( NSString *key in [account allKeys] )
                if( [[account objectForKey:key] rangeOfString:searchText options:NSCaseInsensitiveSearch].length > 0 ) {
                    [resultArray addObject:account];
                    break;
                }
        
        if( [resultArray count] > 0 )
            searchResults = [[AccountUtil dictionaryFromAccountArray:resultArray] retain];
        
        [titleButton setTitle:[NSString stringWithFormat:@"%@ (%i) ▼", 
                               NSLocalizedString(@"Results", @"Results"),
                               [searchResults count]] forState:UIControlStateNormal];
        [titleButton sizeToFit];
        rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                                [searchResults count],
                                ( [searchResults count] != 1 ? NSLocalizedString(@"Results", @"Results plural") : NSLocalizedString(@"Result", @"Result") )];
        
        [self.pullRefreshTableViewController.tableView reloadData];
        [self.pullRefreshTableViewController.tableView setContentOffset:CGPointZero animated:NO];
    } else {                
        [titleButton setTitle:NSLocalizedString(@"Searching...", @"Searching...") forState:UIControlStateNormal];
        [titleButton sizeToFit];
        
        NSLog(@"SOSL search for %@", searchText);
        
        NSString *sosl = [NSString stringWithFormat:@"FIND {%@*} IN ALL FIELDS RETURNING Account (id, name, owner.name)", 
                          searchText];
        
        [[AccountUtil sharedAccountUtil] startNetworkAction];
        
        // Execute search
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
            NSArray *results = [NSDictionary dictionary];
            
            @try {
                results = [[[AccountUtil sharedAccountUtil] client] search:sosl];
            } @catch( NSException *e ) {
                [[AccountUtil sharedAccountUtil] endNetworkAction];
                [[AccountUtil sharedAccountUtil] receivedException:e];
                [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [[AccountUtil sharedAccountUtil] endNetworkAction];
                [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                
                searchResults = nil;
                searchResults = [[NSMutableDictionary dictionaryWithDictionary:[AccountUtil dictionaryFromAccountArray:results]] retain];
                
                rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                                     [results count],
                                     ( [results count] != 1 ? NSLocalizedString(@"Results", @"Results plural") : NSLocalizedString(@"Result", @"Result") )];
                [titleButton setTitle:[NSString stringWithFormat:@"%@ (%i) ▼", 
                                       NSLocalizedString(@"Results", @"Results"),
                                       [results count]] forState:UIControlStateNormal];
                [titleButton sizeToFit];
                
                [self.pullRefreshTableViewController.tableView reloadData];
                [self.pullRefreshTableViewController.tableView setContentOffset:CGPointZero animated:NO];
            });
        });
    }
}

#pragma mark - editing table view

- (void) toggleEditMode {  
    [self cancelSearch];
    
    if( ![self.pullRefreshTableViewController.tableView isEditing] )
        [self.pullRefreshTableViewController.tableView setEditing:YES animated:YES];
    else
        [self.pullRefreshTableViewController.tableView setEditing:NO animated:YES];
    
    [self setupNavBar];
}

- (void) newAccount {
    [self cancelSearch];
    
    if( self.rootViewController.popoverController )
        [self.rootViewController.popoverController dismissPopoverAnimated:YES];
    
    AccountAddEditController *accountAddEditController = [[AccountAddEditController alloc] init];
    accountAddEditController.delegate = self;
    
    UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:accountAddEditController];
    
    aNavController.navigationBar.tintColor = AppSecondaryColor;
    aNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [self.detailViewController presentModalViewController:aNavController animated:YES];
    [aNavController release];
    [accountAddEditController release];
}

- (void) accountDidCancel:(AccountAddEditController *)accountAddEditcontroller {
    [self.detailViewController dismissModalViewControllerAnimated:YES];
}

- (void) accountDidUpsert:(AccountAddEditController *)accountAddEditController {
    [self.detailViewController dismissModalViewControllerAnimated:YES];
    
    NSDictionary *account = [NSDictionary dictionaryWithDictionary:accountAddEditController.fields];
    NSIndexPath *ip = [AccountUtil indexPathForAccountDictionary:account accountDictionary:myRecords];
        
    [self refresh:YES];
    
    [self.pullRefreshTableViewController.tableView selectRowAtIndexPath:ip animated:YES scrollPosition:UITableViewScrollPositionNone];
    [self tableView:self.pullRefreshTableViewController.tableView didSelectRowAtIndexPath:ip];
}

- (void) deleteAllAccounts {
    // R U RLY RLY RLY RLY RLY SHUR?
    [PRPAlertView showWithTitle:NSLocalizedString(@"Delete Local Accounts", @"Delete local accounts")
                        message:NSLocalizedString(@"Delete all local accounts? This cannot be undone.", @"Delete local accounts warning")
                    cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                    cancelBlock:nil
                     otherTitle:NSLocalizedString(@"Delete All", @"Delete all action")
                     otherBlock:^(void) {
                         [PRPAlertView showWithTitle:NSLocalizedString(@"Delete Local Accounts", @"Delete local accounts")
                                             message:NSLocalizedString(@"Are you sure? This cannot be undone.", @"Delete local accounts second warning")
                                         cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                         cancelBlock:nil
                                          otherTitle:NSLocalizedString(@"Delete All", @"Delete all action")
                                          otherBlock:^(void) {
                                              // nuke
                                              [AccountUtil deleteAllAccounts];
                                              [self toggleEditMode];
                                              [self refresh];
                                              [self.detailViewController eventLogInOrOut];
                                          }];
                     }];
}

- (void) toggleHelperView {
    // only displayed for local accounts
    if( subNavTableType != SubNavLocalAccounts )
        return;   
    
    UIView *v = nil;
    
    if( !helperViewVisible ) {        
        CGRect r = CGRectMake( 0, 180, masterWidth, 500);
        
        v = [[UIView alloc] initWithFrame:r];
        v.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        v.backgroundColor = [UIColor clearColor];
        v.tag = helperTag;
        
        // label 1
        UILabel *l1 = [[UILabel alloc] initWithFrame:CGRectMake(0, 100, v.frame.size.width, 25)];
        l1.text = NSLocalizedString(@"No Local Accounts", @"No local accounts");
        l1.font = [UIFont boldSystemFontOfSize:18];
        l1.textColor = [UIColor whiteColor];
        l1.textAlignment = UITextAlignmentCenter;
        l1.backgroundColor = [UIColor clearColor];
        
        [v addSubview:l1];
        [l1 release];
        
        // label 2
        UILabel *l2 = [[UILabel alloc] initWithFrame:CGRectMake(0, 130, v.frame.size.width, 25)];
        l2.text = NSLocalizedString(@"Tap + to add one!", @"Tap to add an account");
        l2.font = [UIFont systemFontOfSize:15];
        l2.textColor = [UIColor lightGrayColor];
        l2.textAlignment = UITextAlignmentCenter;
        l2.backgroundColor = [UIColor clearColor];
        
        [v addSubview:l2];
        [l2 release];
        
        [self.view addSubview:v];   
        [v release];
    } else {        
        for( UIView *v in [self.view subviews] )
            if( v.tag == helperTag ) {
                [v removeFromSuperview];
                break;
            }
    }
    
    helperViewVisible = !helperViewVisible;
    
    if( self.pullRefreshTableViewController )
        self.pullRefreshTableViewController.view.hidden = helperViewVisible;
}

#pragma mark - table view operations

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 40;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [UIImage imageNamed:@"sectionheader.png"].size.height;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIImageView *sectionView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sectionheader.png"]];
    
    UILabel *customLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, -1, sectionView.frame.size.width, sectionView.frame.size.height )];
    customLabel.textColor = AppSecondaryColor;
    customLabel.text = [[AccountUtil sortArray:( searching ? [searchResults allKeys] : [myRecords allKeys] )] objectAtIndex:section];
    customLabel.font = [UIFont boldSystemFontOfSize:16];
    customLabel.backgroundColor = [UIColor clearColor];
    [sectionView addSubview:customLabel];
    [customLabel release];
    
    return [sectionView autorelease];
}

- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {    
    return ( letUserSelectRow ? indexPath : nil );
}

- (void) selectAccountWithId:(NSString *)accountId {
    if( accountId ) {
        for( NSArray *accountArray in [myRecords allValues] )
            for( NSDictionary *account in accountArray )
                if( [[account objectForKey:@"Id"] isEqualToString:accountId] ) {
                    NSIndexPath *path = [AccountUtil indexPathForAccountDictionary:account accountDictionary:myRecords];
                    
                    if( path )
                        [self.pullRefreshTableViewController.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];

                    return;
                }
    }
    
    [self.pullRefreshTableViewController.tableView deselectRowAtIndexPath:[self.pullRefreshTableViewController.tableView indexPathForSelectedRow] animated:YES];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {          
    NSArray *ret = [NSArray array];
    
    for( int x = 0; x < [indexAlphabet length]; x++ )
        ret = [ret arrayByAddingObject:[indexAlphabet substringWithRange:NSMakeRange(x, 1)]];
        
    return ret;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {       
    NSArray *sortedKeys = [AccountUtil sortArray:( searching ? [searchResults allKeys] : [myRecords allKeys] )];
    
    int ret = 0;
    
    for( int x = 0; x < [sortedKeys count]; x++ )        
        if( [[sortedKeys objectAtIndex:x] compare:title options:NSCaseInsensitiveSearch] != NSOrderedDescending )
            ret = x;
            
    return ret;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [[AccountUtil sortArray:( searching ? [searchResults allKeys] : [myRecords allKeys] )] objectAtIndex:section];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return ( searching ? [[searchResults allKeys] count] : [[myRecords allKeys] count] );
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {    
    NSArray *sortedKeys = nil;
    
    if( searching ) {
        sortedKeys = [AccountUtil sortArray:[searchResults allKeys]];
        return [[searchResults objectForKey:[sortedKeys objectAtIndex:section]] count];
    }
    
    sortedKeys = [AccountUtil sortArray:[myRecords allKeys]];
    return [[myRecords objectForKey:[sortedKeys objectAtIndex:section]] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {    
    UITableViewCell *cell = [PRPSmartTableViewCell cellForTableView:tableView];
    
    NSDictionary *account = nil;
    
    if( searching )
        account = [AccountUtil accountFromIndexPath:indexPath accountDictionary:searchResults];
    else       
        account = [AccountUtil accountFromIndexPath:indexPath accountDictionary:myRecords];
    
    cell.textLabel.adjustsFontSizeToFitWidth = NO;
    cell.textLabel.text = [account objectForKey:@"Name"];
    cell.textLabel.textColor = UIColorFromRGB(0xbababa);
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
    
    cell.detailTextLabel.textColor = [UIColor whiteColor];
    
    if( searching && [account objectForKey:@"Owner"] )
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@: %@",
                                     NSLocalizedString(@"Owner", @"Owner"),
                                     [((ZKSObject *)[account objectForKey:@"Owner"]) fieldValue:@"Name"]];
    else
        cell.detailTextLabel.text = @"";
    
    UIImageView *selectedGradient = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"leftgradient.png"]] autorelease];
    
    cell.selectedBackgroundView = selectedGradient;
    
    return cell;
}

// we can only delete accounts that are stored locally
- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return !searching && subNavTableType == SubNavLocalAccounts;
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {    
    NSDictionary *account = nil;
    
    [self.rootViewController.popoverController dismissPopoverAnimated:YES];
    [searchBar resignFirstResponder];
    
    if( searching )
        account = [AccountUtil accountFromIndexPath:indexPath accountDictionary:searchResults];
        //[searchResults objectAtIndex:indexPath.row];
    else
        account = [AccountUtil accountFromIndexPath:indexPath accountDictionary:myRecords];
    
    [self.detailViewController didSelectAccount:account];
    
    [self.rootViewController allSubNavSelectAccountWithId:[account objectForKey:@"Id"]];
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if( editingStyle == UITableViewCellEditingStyleDelete ) {                
        NSDictionary *thisAccount = [AccountUtil accountFromIndexPath:indexPath accountDictionary:myRecords];
        
        // R U RLY SHUR?
        [PRPAlertView showWithTitle:NSLocalizedString(@"Delete Account", @"Delete account action")
                            message:[NSString stringWithFormat:@"%@ \"%@\"?",
                                     NSLocalizedString(@"Are you sure you want to delete", @"Single account delete confirm"),
                                     [thisAccount objectForKey:@"Name"]]
                        cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                        cancelBlock:nil
                         otherTitle:NSLocalizedString(@"Delete", @"Delete")
                         otherBlock:^(void) {                             
                             // Perform actual DB delete                             
                             [AccountUtil deleteAccount:[thisAccount objectForKey:@"Id"]];
                             
                             [titleButton setTitle:[self whichList] forState:UIControlStateNormal];
                             
                             NSString *index = [[AccountUtil sortArray:[myRecords allKeys]] objectAtIndex:[indexPath section]];
                             
                             if( [[myRecords objectForKey:index] count] == 1 ) {
                                 [myRecords removeObjectForKey:index];
                                 [tableView deleteSections:[NSIndexSet indexSetWithIndex:[indexPath section]] withRowAnimation:UITableViewRowAnimationFade];
                             } else {
                                 NSMutableArray *accounts = [NSMutableArray arrayWithArray:[myRecords objectForKey:index]];
                                 int tag = 0;
                                 
                                 if( [thisAccount objectForKey:@"tag"] )
                                     tag = [[thisAccount objectForKey:@"tag"] integerValue];
                                 
                                 [accounts removeObjectAtIndex:tag];
                                 
                                 [myRecords setObject:accounts forKey:index];
                                 [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
                             }
                             
                             // this is working around an apparent bug with UITableView's reloadSectionIndexTitles failing to update the section index
                             // see http://blommegard.tumblr.com/post/1668753586/reloadsectionindextitles-doesnt-work-on-uitableview                                 
                             [tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.4];
                             
                             // Are we showing this record in the detail view? Refresh if so
                             if( [[self.detailViewController visibleAccountId] isEqualToString:[thisAccount objectForKey:@"Id"]] ) {
                                 if( self.rootViewController.popoverController ) {
                                     [self.rootViewController.popoverController dismissPopoverAnimated:YES];
                                     [self toggleEditMode];
                                 }
                                 
                                 [self.detailViewController addAccountNewsTable];
                             }
                             
                             // Are there any accounts remaining after this delete?
                             if( [myRecords count] == 0 ) {
                                 [self toggleEditMode];
                                 [self toggleHelperView];
                                 storedSize = 0;
                                 rowCountLabel.text = NSLocalizedString(@"No Accounts", @"No Accounts");
                             } else {
                                 storedSize--;
                                 rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                                                       storedSize,
                                                       ( storedSize != 1 ? NSLocalizedString(@"Accounts", @"Account plural") : NSLocalizedString(@"Account", @"Account singular") )];
                             }
                         }];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void) handleInterfaceRotation:(BOOL)isPortrait {
    if( isPortrait ) {        
        [self.searchBar resignFirstResponder];
        
        if( self.listActionSheet && [self.listActionSheet isVisible] )
            [self.listActionSheet dismissWithClickedButtonIndex:-1 animated:NO];
    }
}

#pragma mark - app icon, header, navbar actions

- (IBAction) showSettings:(id)sender {
    [self cancelSearch];
    
    [self.rootViewController showSettings:sender];
}

- (IBAction) tappedLogo:(id)sender {
    if( self.rootViewController.popoverController )
        [self.rootViewController.popoverController dismissPopoverAnimated:YES];
    
    [self cancelSearch];
    
    [self.rootViewController allSubNavSelectAccountWithId:nil];
    [self.detailViewController addAccountNewsTable];
}

- (IBAction) showListActions:(id)sender {        
    [self.searchBar resignFirstResponder];
    
    if( [RootViewController isPortrait] ) {
        [self cancelSearch];
        
        if( [self.rootViewController isLoggedIn] )
            [self.rootViewController switchSubNavView:( subNavTableType == SubNavTableNumTypes - 1 ? 0 : subNavTableType + 1 )];
        
        return;
    }
        
    UIActionSheet *action = [[[UIActionSheet alloc] init] autorelease];
    
    [action setTitle:[NSString stringWithFormat:@"%@ (%i)", [self listTitleForTableType:subNavTableType withArrow:NO], storedSize]];
    [action setDelegate:self];
    
    for( int x = 0; x < SubNavTableNumTypes; x++ ) {
        if( x == SubNavFollowedAccounts && [self.rootViewController isLoggedIn] && ![[AccountUtil sharedAccountUtil] isChatterEnabled] )
           continue;
    
        [action addButtonWithTitle:[self listTitleForTableType:x withArrow:NO]];
    }
    
    [action showFromRect:[sender frame] inView:self.view animated:YES];
    listActionSheet = action;
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {    
    if( buttonIndex < 0 ) {
        listActionSheet = nil;
        return;
    }
    
    [self cancelSearch];
    
    if( [self.pullRefreshTableViewController.tableView isEditing] )
        [self toggleEditMode];
    
    for( int x = 0; x < SubNavTableNumTypes; x++ )  
        if( [[listActionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:[self listTitleForTableType:x withArrow:NO]] )
            [self.rootViewController switchSubNavView:x];
    
    listActionSheet = nil;
}

- (NSString *) whichList {
    return [self listTitleForTableType:subNavTableType withArrow:YES];
}

- (NSString *) listTitleForTableType:(enum SubNavTableType)tableType withArrow:(BOOL)withArrow {
    NSString *ret = nil;
    
    switch( tableType ) {
        case SubNavLocalAccounts:
            ret = NSLocalizedString(@"Local Accounts", @"Local Accounts title");
            break;
        case SubNavFollowedAccounts:
            ret = NSLocalizedString(@"Accounts I Follow", @"Followed accounts title");
            break;
        case SubNavOwnedAccounts:
            ret = NSLocalizedString(@"My Accounts", @"My Accounts title");
            break;
        default:
            ret = @"Unknown List";
            break;
    }
    
    if( withArrow )
        ret = [ret stringByAppendingFormat:@" ▼"];
    
    return ret;
}

- (void) setupNavBar {       
    if( !self.navigationBar )
        return;
    
    UINavigationItem *topItem = [[UINavigationItem alloc] initWithTitle:nil];
    topItem.hidesBackButton = YES;
    
    if( [self.pullRefreshTableViewController.tableView isEditing] ) {
        [topItem setLeftBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                     target:self
                                                                                     action:@selector(toggleEditMode)] autorelease] animated:YES];            
        
        UIBarButtonItem *trash = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash 
                                                                                target:self
                                                                                action:@selector(deleteAllAccounts)] autorelease];
        trash.style = UIBarButtonItemStyleBordered;
        
        [topItem setRightBarButtonItem:trash];
    } else {
        if( [myRecords count] > 0 )
            [topItem setLeftBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                         target:self
                                                                                         action:@selector(toggleEditMode)] autorelease] animated:YES];
        else
            [topItem setLeftBarButtonItem:nil animated:YES];
        
        UIBarButtonItem *add = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                              target:self
                                                                              action:@selector(newAccount)] autorelease];
        add.style = UIBarButtonItemStyleBordered;
        
        [topItem setRightBarButtonItem:add];
    }
    
    [self.navigationBar pushNavigationItem:topItem animated:YES];
    [topItem release];
}

@end

#pragma mark - transparent navigation bar

@implementation TransparentNavigationBar

// Override draw rect to avoid
// background coloring
- (void)drawRect:(CGRect)rect {
    // do nothing in here
}


- (void) applyTranslucentBackground {
    self.backgroundColor = [UIColor clearColor];
}

// Override init.
- (id) init {
    self = [super init];
    [self applyTranslucentBackground];
    return self;
}

// Override initWithFrame.
- (id) initWithFrame:(CGRect) frame {
    self = [super initWithFrame:frame];
    [self applyTranslucentBackground];
    return self;
}

@end

#pragma mark - transparent toolbar

@implementation TransparentToolBar

// Override draw rect to avoid
// background coloring
- (void)drawRect:(CGRect)rect {
    // do nothing in here
}


- (void) applyTranslucentBackground {
    self.backgroundColor = [UIColor clearColor];
}

// Override init.
- (id) init {
    self = [super init];
    [self applyTranslucentBackground];
    return self;
}

// Override initWithFrame.
- (id) initWithFrame:(CGRect) frame {
    self = [super initWithFrame:frame];
    [self applyTranslucentBackground];
    return self;
}

@end
