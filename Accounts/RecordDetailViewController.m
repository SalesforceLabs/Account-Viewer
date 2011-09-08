//
//  RecordDetailViewController.m
//  Accounts
//
//  Created by Jonathan Hersh on 3/22/11.
//  Copyright 2011 SFDC. All rights reserved.
//
/*
#import "RecordDetailViewController.h"
#import "WebViewController.h"
#import "RootViewController.h"
#import "AccountUtil.h"
#import "zkSforce.h"
#import "PRPConnection.h"
#import "FieldPopoverButton.h"
#import <QuartzCore/QuartzCore.h>
#import "DSActivityView.h"
#import "PRPAlertView.h"
#import "zkParser.h"
#import "FlyingWindowController.h"
#import "SimpleKeychain.h"
#import "DetailViewController.h"

@implementation RecordDetailViewController

@synthesize fieldScrollView, sheet;

#pragma mark - init, basic setup

- (id) initWithFrame:(CGRect)frame {  
    if((self = [super initWithFrame:frame])) {        
        UIScrollView *fsv = [[UIScrollView alloc] initWithFrame:CGRectMake( 5, self.navBar.frame.size.height, frame.size.width - 5, frame.size.height - self.navBar.frame.size.height )];
        self.fieldScrollView = fsv;
        [fsv release];
        
        [self.view addSubview:self.fieldScrollView];
        
        [fieldScrollView.layer setMasksToBounds:YES];
        fieldScrollView.layer.cornerRadius = 8.0f;
        fieldScrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        
        fieldScrollView.showsVerticalScrollIndicator = YES;
    }
    
    return self;
}

// Sets the local account object and updates the view.
- (void)selectAccount:(NSDictionary *)acc {   
    [super selectAccount:acc];
    
    [self loadAccount];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)dealloc {
    [fieldScrollView release];
    [sheet release];
    [super dealloc];
}

#pragma mark - loading accounts

- (void)loadAccount {  
    fieldScrollView.hidden = YES;
    
    for( UIView *view in [fieldScrollView subviews] )
        [view removeFromSuperview];
        
    NSDictionary *localAcct = [[AccountUtil sharedAccountUtil] getAccount:[self.account objectForKey:@"Id"]];
    
    if( self.detailViewController.subNavViewController.subNavTableType == SubNavLocalAccounts && localAcct ) {
        self.account = localAcct;
        [self loadLocalAccount];
        return;
    }
    
    if( ![[[AccountUtil sharedAccountUtil] client] loggedIn] || !self.account )
        return;
    
    // Not a local account. Remove the edit button from the navigation bar
    UINavigationItem *defaultHeader = [[UINavigationItem alloc] initWithTitle:[self.account objectForKey:@"Name"]];
    [self.navBar popNavigationItemAnimated:NO];
    defaultHeader.hidesBackButton = YES;
    [self.navBar pushNavigationItem:defaultHeader animated:YES];
    [defaultHeader release];
    
    NSString *fieldsToQuery = @"";
    
    // Only query the fields that will be displayed in the page layout for this account, given its record type and page layout.
    NSString *layoutId = [[[AccountUtil sharedAccountUtil] layoutForRecordTypeId:[self.account objectForKey:@"RecordTypeId"]] Id];
    
    for( NSString *field in [[AccountUtil sharedAccountUtil] fieldListForLayoutId:layoutId] )
        if( field && ![field isEqualToString:@""] ) {
            if( [fieldsToQuery isEqualToString:@""] )
                fieldsToQuery = field;
            else
                fieldsToQuery = [fieldsToQuery stringByAppendingFormat:@", %@", field];
        }
    
    // Build and execute the query
    [[AccountUtil sharedAccountUtil] startNetworkAction];
    [DSBezelActivityView newActivityViewForView:self.view];
    
    NSString *queryString = [NSString stringWithFormat:@"select %@ from Account where id='%@'",
                             fieldsToQuery, [self.account objectForKey:@"Id"]];
    
    NSLog(@"SOQL %@", queryString);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
        ZKQueryResult *qr = nil;
        
        @try {
            qr = [[[AccountUtil sharedAccountUtil] client] query:queryString];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] receivedException:e];
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            [DSBezelActivityView removeViewAnimated:YES];
            
            [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                                message:NSLocalizedString(@"Failed to load this Account.", @"Failed to load account")
                            cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                            cancelBlock:nil
                             otherTitle:NSLocalizedString(@"Retry", @"Retry")
                             otherBlock: ^(void) {
                                 [self loadAccount];
                             }];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self loadAccountResult:qr error:nil context:nil];
        });
    });
}

- (void) loadLocalAccount {    
    if( self.fieldScrollView )
        [fieldScrollView removeFromSuperview]; 
    
    **self.fieldScrollView = [AccountUtil scrollViewForAccount:self.account withTarget:self isLocalAccount:YES];
    
    [fieldScrollView setContentSize:CGSizeMake( self.view.frame.size.width - 5, fieldScrollView.frame.size.height )];
    [fieldScrollView setFrame:CGRectMake( 5, self.navBar.frame.size.height, self.view.frame.size.width - 5, self.view.frame.size.height - self.navBar.frame.size.height )];
    [fieldScrollView setContentOffset:CGPointZero animated:NO]; 
    
    [self.view addSubview:fieldScrollView];**
    
    // Add an edit button for this account (if it's not a remote account being saved locally)
    UINavigationItem *editItem = [[UINavigationItem alloc] initWithTitle:[self.account objectForKey:@"Name"]];
    
    if( [[self.account objectForKey:@"Id"] length] < 10 ) {
        UIBarButtonItem *editButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                    target:self 
                                                                                    action:@selector(editLocalAccount:)] autorelease];
        editItem.rightBarButtonItem = editButton;
    }
    
    editItem.hidesBackButton = YES;
    [self.navBar popNavigationItemAnimated:NO];
    [self.navBar pushNavigationItem:editItem animated:YES];
    [editItem release];
}

- (void)loadAccountResult:(ZKQueryResult *)results error:(NSError *)error context:(id)context {
    [[AccountUtil sharedAccountUtil] endNetworkAction];
    [DSBezelActivityView removeViewAnimated:YES];
    
    if( error ) {
        [[AccountUtil sharedAccountUtil] receivedAPIError:error];
        return;
    } else if( !results || [[results records] count] == 0 ) {
        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                            message:NSLocalizedString(@"Failed to load this account.", @"Account query failed")
                        cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                        cancelBlock:nil
                         otherTitle:NSLocalizedString(@"Retry", @"Retry")
                         otherBlock:^(void) {
                             [self loadAccount];
                         }];
        return;
    }
    
    if( self.account )
        [self.account release], self.account = nil;
    
    self.account = [[[[results records] objectAtIndex:0] fields] retain];
    
    // If this account is already saved locally, update it
    if( [[AccountUtil sharedAccountUtil] getAccount:[self.account objectForKey:@"Id"]] )
        [[AccountUtil sharedAccountUtil] upsertAccount:self.account];
    
    if( self.fieldScrollView )
        [fieldScrollView removeFromSuperview]; 
    
    **self.fieldScrollView = [AccountUtil scrollViewForAccount:self.account withTarget:self isLocalAccount:NO];
    
    [fieldScrollView setContentSize:CGSizeMake( self.view.frame.size.width - 5, fieldScrollView.frame.size.height )];
    [fieldScrollView setFrame:CGRectMake( 5, self.navBar.frame.size.height, self.view.frame.size.width - 5, self.view.frame.size.height - self.navBar.frame.size.height )];
    [fieldScrollView setContentOffset:CGPointZero animated:NO]; 
    
    [self.view addSubview:fieldScrollView];**
    
    [self createFavoriteButton];
    
    fieldScrollView.hidden = NO;
    
    self.navBar.topItem.title = [self.account objectForKey:@"Name"];
}

#pragma mark - favorites

- (void) createFavoriteButton {
    if( !self.account || ![self.account objectForKey:@"Id"] )
        return;
    
    NSDictionary *account = [[AccountUtil sharedAccountUtil] getAccount:[self.account objectForKey:@"Id"]];
    
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:( account ? [UIImage imageNamed:@"favorite_on.png"] : [UIImage imageNamed:@"favorite_off.png"] )
                                                               style:UIBarButtonItemStyleBordered
                                                              target:self
                                                              action:@selector(toggleFavorite:)];
    
    self.navBar.topItem.rightBarButtonItem = [button autorelease];
}
                               
- (void) toggleFavorite:(id)sender {    
    NSString *accountID = [self.account objectForKey:@"Id"];
    
    if( [[AccountUtil sharedAccountUtil] getAccount:accountID] ) {
        [[AccountUtil sharedAccountUtil] deleteAccount:accountID];
        
        [self createFavoriteButton];
        
        for( SubNavViewController *snvc in self.rootViewController.subNavControllers )
            if( [snvc subNavTableType] == SubNavLocalAccounts )
                [snvc refresh];
    } else {        
        if( self.sheet ) {
            [sheet dismissWithClickedButtonIndex:-1 animated:YES];
            sheet = nil;
            return;
        }
        
        UIActionSheet *buttonSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:NSLocalizedString(@"Save to Local Accounts", @"Save to local accounts"), nil];
        
        [buttonSheet showFromBarButtonItem:self.navBar.topItem.rightBarButtonItem animated:YES];
        
        self.sheet = buttonSheet;
    }
}

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if( buttonIndex == 0 ) {
        [[AccountUtil sharedAccountUtil] upsertAccount:self.account];
        
        [self createFavoriteButton];
        
        for( SubNavViewController *snvc in self.rootViewController.subNavControllers )
            if( [snvc subNavTableType] == SubNavLocalAccounts )
                [snvc refresh];
    }
    
    self.sheet = nil;
}

#pragma mark - editing local accounts

- (IBAction) editLocalAccount:(id)sender {
    AccountAddEditController *accountAddEditController = [[AccountAddEditController alloc] initWithAccount:self.account];
    accountAddEditController.delegate = self;
    
    UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:accountAddEditController];
    
    aNavController.navigationBar.tintColor = [AccountUtil appSecondaryColor];
    aNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    aNavController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    [self presentModalViewController:aNavController animated:YES];
    [aNavController release];
    [accountAddEditController release];
}

- (void) accountDidCancel:(AccountAddEditController *)accountAddEditcontroller {
    [self dismissModalViewControllerAnimated:YES];
}

- (void) accountDidUpsert:(AccountAddEditController *)accountAddEditController {
    [self dismissModalViewControllerAnimated:YES];
    [self.subNavViewController refresh];
    [self loadAccount];
    
    if( self.detailViewController.recordOverviewController )
        [self.detailViewController.recordOverviewController loadAccount];
}

@end

*/