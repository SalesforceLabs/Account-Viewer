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
#import "RootViewController.h"
#import "AccountUtil.h"
#import "DetailViewController.h"
#import "SubNavViewController.h"
#import "PRPSmartTableViewCell.h"
#import "PRPAlertView.h"
#import "OAuthViewController.h"
#import "AccountsAppDelegate.h"
#import "MGSplitViewController.h"
#import "zkSforce.h"
#import "DSActivityView.h"
#import "IASKSettingsReader.h"
#import "IASKSpecifier.h"
#import "AccountFirstRunController.h"
#import "SimpleKeychain.h"
#import "PRPConnection.h"

@implementation RootViewController

@synthesize detailViewController, client, popoverController, subNavControllers, splitViewController;

static NSString *clientUserName = @"username@org.com";
static NSString *clientPassword = @"password";

// This variable determines the login method. If you have an OAuth client ID,
// input it in the header file and set this var to NO. Otherwise, set it to yes and add your
// dev credentials above.
// YES - login with client username/pw, specified above
// NO - OAuth
BOOL useClientLogin = NO;

#pragma mark - init and dealloc

- (void)dealloc {
    [detailViewController release];
    [client release];
    [popoverController release];
    [subNavControllers release];
    [super dealloc];
}

- (void) awakeFromNib {
    [super awakeFromNib];
    
    self.contentSizeForViewInPopover = CGSizeMake( masterWidth, 748 );
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"tableBG.png"]];
    
    self.client = [[[ZKSforceClient alloc] init] autorelease];
    [client setClientId:SOAPClientID];
}

- (void) appFinishedLaunching {   
    NSLog(@"app finished launching");
    
    if( ![[NSUserDefaults standardUserDefaults] boolForKey:firstRunKey] )
        [self showFirstRunModal];
    else if( !useClientLogin && [[self class] hasStoredOAuthRefreshToken] )
        [self logInOrOut:nil];
    else {
        [self addSubNavControllers];
        [self.detailViewController eventLogInOrOut];
    }
}

#pragma mark - subnavigation management

- (void) addSubNavControllers {
    if( !self.subNavControllers ) {
        self.subNavControllers = [[[NSMutableArray alloc] initWithCapacity:SubNavTableNumTypes] autorelease];
        
        for( int x = 0; x < SubNavTableNumTypes; x++ ) {
            SubNavViewController *snvc = [[SubNavViewController alloc] initWithTableType:x];
            snvc.rootViewController = self;
            snvc.detailViewController = self.detailViewController;
            [snvc refresh];
            
            [self.view addSubview:snvc.view];
            [self.subNavControllers addObject:snvc];
            [snvc release];
        }
    } else
        for( SubNavViewController *snvc in self.subNavControllers )
            [snvc refresh];
    
    SubNavViewController *snvc = (SubNavViewController *)[self.subNavControllers lastObject];
    
    self.detailViewController.subNavViewController = snvc;
    [self.view bringSubviewToFront:snvc.view];
}

- (void) removeSubNavControllers {
    if( self.subNavControllers ) {
        for( SubNavViewController *controller in self.subNavControllers ) {
            [controller.view removeFromSuperview];
            controller = nil;
        }
        
        [self.subNavControllers removeAllObjects];
        self.subNavControllers = nil;
        
        self.detailViewController.subNavViewController = nil;        
    }
}

- (void) switchSubNavView:(int)selectedIndex {  
    if( selectedIndex >= [self.subNavControllers count] )
        selectedIndex = [self.subNavControllers count] - 1;
    
    SubNavViewController *snvc = (SubNavViewController *)[self.subNavControllers objectAtIndex:selectedIndex];
    
    if( snvc.subNavTableType != SubNavLocalAccounts && ![self isLoggedIn] )
        [self showLogin];
    else if( snvc.subNavTableType == SubNavFollowedAccounts && ![[AccountUtil sharedAccountUtil] isChatterEnabled] )
        return;
    else {
        [self.view bringSubviewToFront:snvc.view];
        self.detailViewController.subNavViewController = snvc;
        
        if( !self.detailViewController.recordOverviewController )
            [self.detailViewController addAccountNewsTable];
    }
}

- (void) allSubNavSelectAccountWithId:(NSString *)accountId {
    if( !self.subNavControllers )
        return;
    
    for( SubNavViewController *snvc in self.subNavControllers )
        [snvc selectAccountWithId:accountId];
}

#pragma mark - Split view controller

+ (BOOL)isPortrait {
    return UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]);
}

- (void)splitViewController:(MGSplitViewController *)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController: (UIPopoverController *)pc {
        
    barButtonItem.title = NSLocalizedString(@"Accounts",@"Accounts button");   
    
    self.popoverController = pc;
    
    [self.detailViewController setPopoverButton:barButtonItem];    
}

// Called when the view is shown again in the split view, invalidating the button and popover controller.
- (void)splitViewController:(MGSplitViewController *)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem {  
    
    self.popoverController = nil;
    [self.detailViewController setPopoverButton:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - log in / log out

- (void)logInOrOut:(id)sender {   
    if( self.popoverController )
        [self.popoverController dismissPopoverAnimated:YES];
    
    // log in
    if( ![self isLoggedIn] ) {   
        if ( useClientLogin ) {
            [[AccountUtil sharedAccountUtil] startNetworkAction];

            [DSBezelActivityView newActivityViewForView:self.splitViewController.view withLabel:NSLocalizedString(@"Authenticating",@"Authenticating")];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
                ZKLoginResult *lr = nil;
                
                @try {
                    lr = [client login:clientUserName password:clientPassword];
                } @catch( NSException *e ) {
                    [[AccountUtil sharedAccountUtil] endNetworkAction];
                    [DSBezelActivityView removeViewAnimated:YES];
                    [[AccountUtil sharedAccountUtil] receivedException:e];
                    
                    [PRPAlertView showWithTitle:NSLocalizedString(@"Alert",@"Alert")
                                        message:NSLocalizedString(@"Failed to login with client credentials.",@"Client login failed")
                                    buttonTitle:NSLocalizedString(@"OK",@"OK")];
                    return;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self loginResult:lr error:nil];
                });
            });
        } else { // OAuth
            if( [[self class] hasStoredOAuthRefreshToken] ) {               
                [DSBezelActivityView newActivityViewForView:self.splitViewController.view withLabel:NSLocalizedString(@"Authenticating",@"Authenticating")];
                
                // use our saved OAuth token  
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
                    @try {
                        [client loginWithRefreshToken:[SimpleKeychain load:refreshTokenKey]
                                              authUrl:[NSURL URLWithString:[SimpleKeychain load:instanceURLKey]]
                                     oAuthConsumerKey:OAuthClientID];
                    } @catch( NSException *e ) {
                        [[AccountUtil sharedAccountUtil] receivedException:e];
                        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert",@"Alert")
                                            message:NSLocalizedString(@"Failed to authenticate.",@"Generic OAuth failure")
                                        buttonTitle:NSLocalizedString(@"OK",@"OK")];
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        if( [client loggedIn] ) {
                            NSLog(@"OAuth session successfully resumed");
                            
                            [self appDidLogin];  
                        } else {
                            // OAuth failed for some reason
                            NSLog(@"OAuth session failed to resume");
                            [DSBezelActivityView removeViewAnimated:YES];
                            [self doLogout];
                        }
                    });
                });
            } else
                [self showLogin];
        }        
    } else { 
        // are you sure you want to log out?
        [PRPAlertView showWithTitle:NSLocalizedString(@"Log Out",@"Log Out")
                            message:[NSString stringWithFormat:@"%@ %@?", 
                                     NSLocalizedString(@"Log out",@"Log out"),
                                     [[[[AccountUtil sharedAccountUtil] client] getUserInfo] userName]] 
                        cancelTitle:NSLocalizedString(@"Cancel",@"Cancel")
                        cancelBlock:nil
                         otherTitle:NSLocalizedString(@"Log Out",@"Log Out")
                         otherBlock:^(void) {
                             [self doLogout];
            }];
    }
}

// Logging in with client login (u/p)
- (void)loginResult:(ZKLoginResult *)result error:(NSError *)error {    
    [[AccountUtil sharedAccountUtil] endNetworkAction];
    
    if( [result passwordExpired] ) {
        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert",@"Alert")
                            message:NSLocalizedString(@"Your password is expired. Please reset it at login.salesforce.com.", @"Password needs reset")
                        buttonTitle:NSLocalizedString(@"OK", @"OK")];
        
        [DSBezelActivityView removeViewAnimated:YES];
    } else if( !result || error ) {
        [[AccountUtil sharedAccountUtil] receivedAPIError:error];
        [DSBezelActivityView removeViewAnimated:YES];
    } else {
        NSLog(@"logged in using basic auth"); 
        
        [self appDidLogin];
    }
}

// Logging in with OAuth and NOT refreshing an existing OAuth key
- (void)loginOAuth:(OAuthViewController *)controller error:(NSError *)error {
    [[AccountUtil sharedAccountUtil] endNetworkAction];
    
    if ([controller accessToken] && !error) {   
        @try {
            [client loginWithRefreshToken:[controller refreshToken] 
                              authUrl:[NSURL URLWithString:[controller instanceUrl]] 
                     oAuthConsumerKey:OAuthClientID];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] receivedException:e];
            [PRPAlertView showWithTitle:NSLocalizedString(@"Alert",@"Alert")
                                message:NSLocalizedString(@"Failed to authenticate.", @"Generic OAuth failure")
                            buttonTitle:NSLocalizedString(@"OK", @"OK")];
        }
        
        if( [client loggedIn] ) {
            NSLog(@"logged in with oauth");    
            
            [SimpleKeychain save:refreshTokenKey data:[controller refreshToken]];
            [SimpleKeychain save:instanceURLKey data:[controller instanceUrl]];
            
            [DSBezelActivityView newActivityViewForView:self.splitViewController.view withLabel:NSLocalizedString(@"Authenticating", @"Authenticating")];
            [self hideLogin];
            [self appDidLogin];
        } else {
            NSLog(@"error logging in with oauth");
            [self hideLogin];
        }
        
    } else if (error) {
        [[AccountUtil sharedAccountUtil] receivedAPIError:error];
        [self hideLogin];
    }
}

- (void)removeApplicationLibraryDirectoryWithDirectory:(NSString *)dirName {
	NSString *dir = [[[[NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSUserDomainMask, YES) lastObject] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:dirName];
	if ([[NSFileManager defaultManager] fileExistsAtPath:dir]) {
		[[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
	}
}

- (void)hideLogin {
    [self.splitViewController dismissModalViewControllerAnimated:YES];
        
	[[NSURLCache sharedURLCache] removeAllCachedResponses];
	[self removeApplicationLibraryDirectoryWithDirectory:@"Caches"];
	[self removeApplicationLibraryDirectoryWithDirectory:@"WebKit"];
    
    NSArray *cookiesToSave = [NSArray arrayWithObjects:@"rememberUn", @"login", @"autocomplete", nil];
    
	for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies])        
        if( ![cookiesToSave containsObject:[cookie name]] )
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];

	[self removeApplicationLibraryDirectoryWithDirectory:@"Cookies"];
}

- (BOOL) isLoggedIn {
    return [client loggedIn];
}

- (NSString *) loginAction {
    if( [self isLoggedIn] )
        return NSLocalizedString(@"Log Out", @"Log Out action");
    
    return NSLocalizedString(@"Log In", @"Log In action");
}

- (void) appDidLogin {    
    NSLog(@"app did login");  
        
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
        BOOL metadataFail = NO;
        
        // describe to determine if chatter is enabled    
        @try {
            [[AccountUtil sharedAccountUtil] setChatterEnabled:YES];
            [client describeSObject:@"CollaborationGroup"];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] setChatterEnabled:NO];
        }
                
        // Grab my user info
        ZKUserInfo *userinfo = nil;
        
        @try {
            userinfo = [client getUserInfo];
            [client setUserInfo:userinfo]; 
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] receivedException:e];
            metadataFail = YES;
        }        
        
        // Get the metadata description of the account object in this org 
        ZKDescribeSObject *describe = nil;
        
        @try {
            describe = [client describeSObject:@"Account"];
            [[AccountUtil sharedAccountUtil] describeAccountResult:describe error:nil context:nil];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] receivedException:e];
            metadataFail = YES;
        }
                
        // Get the metadata description of the account layouts in this org  
        ZKDescribeLayoutResult *layout = nil;
        
        @try {
            layout = [client describeLayout:@"Account" recordTypeIds:nil];
            [[AccountUtil sharedAccountUtil] describeLayoutResult:layout error:nil context:nil];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] receivedException:e];
            metadataFail = YES;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {  
            [DSBezelActivityView removeViewAnimated:YES];
            
            if( metadataFail ) {
                [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                                    message:NSLocalizedString(@"There was an error logging in.", @"Generic login error")
                                buttonTitle:NSLocalizedString(@"OK", @"OK")];
                [self doLogout];
                return;
            }
            
            [[AccountUtil sharedAccountUtil] setClient:client];
            [self addSubNavControllers];
            
            [self switchSubNavView:SubNavOwnedAccounts];
            [self.detailViewController eventLogInOrOut];            
        });
    });
}

- (void) doLogout {
    NSLog(@"app did logout");
    
    // Perform actual logout
    [client setAuthenticationInfo:nil];
    [client setUserInfo:nil];
    [client flushCachedDescribes];
    
    // Wipe our stored access and refresh tokens
    [SimpleKeychain delete:refreshTokenKey];
    [SimpleKeychain delete:instanceURLKey];
    
    // wipe our caches for geolocations and photos
    [[AccountUtil sharedAccountUtil] emptyCaches];
    
    //[self removeSubNavControllers];
    //[self addLocalAccountTable];
    [self addSubNavControllers];
    [self switchSubNavView:SubNavLocalAccounts];
    
    // on the detail view, return to the default detailview screen
    [self.detailViewController eventLogInOrOut];
    
    if( self.splitViewController.modalViewController )       
        [self.splitViewController dismissModalViewControllerAnimated:YES];
}

+ (BOOL) hasStoredOAuthRefreshToken {
    return ![AccountUtil isEmpty:[SimpleKeychain load:refreshTokenKey]] &&
             ![AccountUtil isEmpty:[SimpleKeychain load:instanceURLKey]];
}

#pragma mark - toolbar actions

- (IBAction) showSettings:(id)sender {    
    IASKAppSettingsViewController *settingsViewController = [[IASKAppSettingsViewController alloc] initWithNibName:@"IASKAppSettingsView" bundle:nil];
    settingsViewController.delegate = self;
    settingsViewController.showDoneButton = YES;
    settingsViewController.showCreditsFooter = YES;
    settingsViewController.extraFooterText = [NSString stringWithFormat:@"%@%@",
                                              ( [self isLoggedIn] ? [NSString stringWithFormat:@"%@ %@.\n", 
                                                                     NSLocalizedString(@"Logged in as", @"Logged in as"),
                                                                     [[client currentUserInfo] userName]] : @"" ),
                                              [NSString stringWithFormat:@"%@ (%@)", 
                                               [AccountUtil appFullName],
                                               [AccountUtil appVersion]]];
    settingsViewController.title = [NSString stringWithFormat:@"%@ %@", 
                                    [AccountUtil appFullName],
                                    NSLocalizedString(@"Settings", @"Settings")];
    
    settingsViewController.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:[self loginAction]
                                                                                                 style:UIBarButtonItemStyleBordered
                                                                                                target:self
                                                                                                action:@selector(logInOrOut:)] autorelease];
    
    if( self.popoverController )
        [self.popoverController dismissPopoverAnimated:YES];
    
    UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    [settingsViewController release];
    
    aNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    aNavController.navigationBar.tintColor = AppSecondaryColor;
    
    [self.splitViewController presentModalViewController:aNavController animated:YES];
    [aNavController release];
}

#pragma mark - settings delegate

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    [self.splitViewController dismissModalViewControllerAnimated:YES];
}

#pragma mark - first-run experience

- (void) showFirstRunModal {
    AccountFirstRunController *afrc = [[AccountFirstRunController alloc] initWithRootViewController:self];
    
    UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:afrc];
    [afrc release];
    
    aNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    aNavController.navigationBar.tintColor = AppSecondaryColor;
    
    [self.splitViewController presentModalViewController:aNavController animated:YES];
    [aNavController release];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:[NSNumber numberWithBool:YES] forKey:firstRunKey];
    [defaults setObject:[NSNumber numberWithBool:YES] forKey:emptyFieldsKey];
    [defaults synchronize];   
}

- (void) hideFirstRunModal {    
    [self.splitViewController dismissModalViewControllerAnimated:YES];
    [self addSubNavControllers];
    [self.detailViewController eventLogInOrOut];
}

- (OAuthViewController *) loginController {
    OAuthViewController *oAuthViewController = [[OAuthViewController alloc] 
                                                initWithTarget:self 
                                                selector:@selector(loginOAuth:error:) 
                                                clientId:OAuthClientID];
    
    NSString *host = [[NSUserDefaults standardUserDefaults] stringForKey:@"login_host"],
    *customHost = [[NSUserDefaults standardUserDefaults] stringForKey:@"custom_host"];
    
    
    if( !host || ( [host isEqualToString:@"Custom Host"] && [AccountUtil isEmpty:customHost] ) )
        host = @"Production";
    
    oAuthViewController.navigationItem.title = [NSString stringWithFormat:@"%@ (%@)", 
                                                NSLocalizedString(@"Secure Log In", @"log in window title"),
                                                host];
    
    return [oAuthViewController autorelease];
}

- (void) showLogin {
    if( self.splitViewController.modalViewController )
        [(UINavigationController *)self.splitViewController.modalViewController pushViewController:[self loginController] animated:YES];
    else {
        UIViewController *vc = [self loginController];
        
        vc.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                             target:self
                                                                                             action:@selector(hideLogin)] autorelease];
        
        UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:vc];
        
        aNavController.modalPresentationStyle = UIModalPresentationFormSheet;
        aNavController.navigationBar.tintColor = AppSecondaryColor;
        
        [self.splitViewController presentModalViewController:aNavController animated:YES];
        [aNavController release];
    }
}

@end
