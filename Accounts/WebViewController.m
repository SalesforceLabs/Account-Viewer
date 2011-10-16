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

#import "AccountUtil.h"
#import "WebViewController.h"
#import "DetailViewController.h"
#import "RootViewController.h"
#import "SubNavViewController.h"
#import "PRPAlertView.h"
#import "ChatterPostController.h"
#import "SlideInView.h"
#import "DSActivityView.h"

@implementation WebViewController

@synthesize webView, navBar, myActionSheet, chatterPop, actionButton, destURL;

int webviewLoads;

- (id) initWithFrame:(CGRect)frame {
    if((self = [super initWithFrame:frame])) {        
        myActionSheet = nil;
        
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        
        self.webView = [[[UIWebView alloc] initWithFrame:CGRectMake(0, self.navBar.frame.size.height, frame.size.width, frame.size.height - self.navBar.frame.size.height)] autorelease];
        self.webView.delegate = self;
        self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
        self.webView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]];
        self.webView.scalesPageToFit = YES;
                
        [self.view addSubview:self.webView];
        
        webviewLoads = 0;
                
        UINavigationItem *item = [[[UINavigationItem alloc] initWithTitle:@"Loading"] autorelease];
        item.hidesBackButton = YES;
        item.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:[self toolBarForSide:YES]] autorelease];
        item.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:[self toolBarForSide:NO]] autorelease];
        
        [self.navBar pushNavigationItem:item animated:YES];
        
        isFullScreen = NO;
    }
        
    return self;
}

- (BOOL) isFullScreen {
    return isFullScreen;
}

- (UIToolbar *) toolBarForSide:(BOOL)isLeftSide {
    UIToolbar* toolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
    NSArray *buttons = nil;
    
    toolbar.tintColor = AppSecondaryColor;
    toolbar.opaque = YES;
    
    CGRect toolbarFrame = CGRectMake( 0, 0, 130, navBar.frame.size.height );
    
    UIBarButtonItem *spacer = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil
                                                                             action:nil] autorelease];
    
    // Set up our right side nav bar
    if( !isLeftSide ) { 
        toolbarFrame.size.width = 110;
        
        self.actionButton = [[[UIBarButtonItem alloc]
                                         initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                         target:self
                                         action:@selector(showActionPopover:)] autorelease];
        
        self.actionButton.enabled = ![[[[self.webView request] URL] absoluteString] isEqualToString:@"about:blank"];
        
        UIBarButtonItem *expandButton = nil;
        
        if( !isFullScreen )
            expandButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"zoomin.png"] 
                                                                         style:UIBarButtonItemStylePlain
                                                                        target:self
                                                                        action:@selector(toggleFullScreen)] autorelease];
        else
            expandButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"zoomout.png"] 
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(toggleFullScreen)] autorelease];
            
        
        buttons = [NSArray arrayWithObjects:actionButton, spacer, expandButton, nil];
    } else {
        // left side toolbar
        UIBarButtonItem *back = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back.png"] 
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:self
                                                                              action:@selector(backAction)] autorelease];
        back.enabled = [self.webView canGoBack];
        
        UIBarButtonItem *reload = nil;
        
        if( [webView isLoading] )
            reload = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                                target:self 
                                                                                action:@selector(stopLoading)] autorelease];
        else
            reload = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                   target:self
                                                                   action:@selector(refreshMe)] autorelease];
        
        reload.style = UIBarButtonItemStylePlain;
        
        UIBarButtonItem *forward = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"forward.png"]
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:self
                                                                              action:@selector(forwardAction)] autorelease];
        forward.enabled = [self.webView canGoForward];
        
        buttons = [NSArray arrayWithObjects:back, spacer, reload, spacer, forward, nil];
    }
        
    if( buttons )
        [toolbar setItems:buttons animated:NO];
    
    [toolbar setFrame:toolbarFrame];
    
    return [toolbar autorelease];
}

- (IBAction) toggleFullScreen {
    if( !isFullScreen ) {  
        isFullScreen = YES;
        [self resetNavToolbar];
        [self.rootViewController.splitViewController presentModalViewController:self animated:YES];
    } else {
        [self.rootViewController.splitViewController dismissModalViewControllerAnimated:YES];
        isFullScreen = NO;
        [self.detailViewController addFlyingWindow:FlyingWindowWebView withArg:self.destURL];
    }
}

- (void)dealloc {
    [myActionSheet release];    
	[webView release];
    [navBar release];
    [destURL release];
    [chatterPop release];
    [actionButton release];
    [super dealloc];
}

- (void) resetNavToolbar {
    UIToolbar *leftBar = [self toolBarForSide:YES];
    navBar.topItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:leftBar] autorelease];
    
    UIToolbar *rightBar = [self toolBarForSide:NO];
    navBar.topItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:rightBar] autorelease];
}

- (void) closeWebView {
    if( self.myActionSheet ) {
        [self.myActionSheet dismissWithClickedButtonIndex:-1 animated:NO];
        self.myActionSheet = nil;
    }
    
    // DIRTY HACK ALERT
    // gotta make sure the spinner isn't going forever once the webview closes
    for( int x = 0; x < 20; x++ )
        [[AccountUtil sharedAccountUtil] endNetworkAction];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (void) webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [[AccountUtil sharedAccountUtil] endNetworkAction];
    navBar.topItem.title = @"";    
    webviewLoads--;
    
    if( webviewLoads == 0 )
        [self resetNavToolbar];
    
    [[AccountUtil sharedAccountUtil] receivedAPIError:error];
    
    if( [error code] == -1003 || [error code] == -1009 )
        [PRPAlertView showWithTitle:[[error userInfo] objectForKey:@"NSErrorFailingURLStringKey"]
                            message:[error localizedDescription]
                        cancelTitle:nil
                        cancelBlock:nil
                         otherTitle:NSLocalizedString(@"OK", @"OK") 
                         otherBlock:^(void) {
                             [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:YES];
                         }];
    else if( [error code] != -999 )
        [PRPAlertView showWithTitle:[[error userInfo] objectForKey:@"NSErrorFailingURLStringKey"]
                        message:[error localizedDescription]
                    buttonTitle:NSLocalizedString(@"OK", @"OK")];
}

- (void)webViewDidStartLoad:(UIWebView *)wv {
    [self resignFirstResponder];
    
    if( webviewLoads == 0 )
        [self resetNavToolbar];
    
    webviewLoads++;
    [[AccountUtil sharedAccountUtil] startNetworkAction];
    navBar.topItem.title = NSLocalizedString(@"Loading...", @"Loading...");
}

- (void)webViewDidFinishLoad:(UIWebView *)wv {    
    [[AccountUtil sharedAccountUtil] endNetworkAction];
    webviewLoads--;
    
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"WebKitCacheModelPreferenceKey"];
    
    if( webviewLoads > 0 )
        return;
    
    navBar.topItem.title = [wv stringByEvaluatingJavaScriptFromString:@"document.title"];
    self.destURL = [[[wv request] URL] absoluteString];
    
    [self resetNavToolbar];
    
    if( self.chatterPop && [self.chatterPop isPopoverVisible] ) {
        ChatterPostController *cpc = (ChatterPostController *)[(UINavigationController *)[self.chatterPop contentViewController] visibleViewController];
        
        [cpc updatePostDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                   self.destURL, @"link",
                                   nil]];
    }
}

- (void) stopLoading {
    [webView stopLoading];
    [[AccountUtil sharedAccountUtil] endNetworkAction];
    navBar.topItem.title = nil;
    
    [self resetNavToolbar];
}

- (void) refreshMe {
    if( ![webView request] || [[[[webView request] URL] absoluteString] isEqualToString:@""] ) 
        [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:destURL]]];
    else
        [webView loadRequest:[webView request]];
}

- (void) backAction {
    if( [webView canGoBack] ) {
        [webView goBack];
        
        [self resetNavToolbar];
    }
}

- (void) forwardAction {
    if( [webView canGoForward] ) {
        [webView goForward];
        
        [self resetNavToolbar];
    }
}

- (void) showActionPopover:(id)sender {    
    if( self.myActionSheet && [self.myActionSheet isVisible] ) {
        [self.myActionSheet dismissWithClickedButtonIndex:-1 animated:YES];
        self.myActionSheet = nil;
        return;
    } else {
        [self.myActionSheet dismissWithClickedButtonIndex:-1 animated:YES];
        self.myActionSheet = nil;
    }
    
    if( self.chatterPop ) {
        [self.chatterPop dismissPopoverAnimated:YES];
        self.chatterPop = nil;
    }
    
    UIActionSheet *action = [[UIActionSheet alloc] init];
    
    [action setTitle:self.destURL];
    [action setDelegate:self];
    
    if( [[AccountUtil sharedAccountUtil] isChatterEnabled] )
        [action addButtonWithTitle:NSLocalizedString(@"Share on Chatter", @"Share on Chatter")];
    
    [action addButtonWithTitle:NSLocalizedString(@"Copy Link", @"Copy link")];
    [action addButtonWithTitle:NSLocalizedString(@"Open in Safari", @"Open in safari")];
    
    if ([MFMailComposeViewController canSendMail])
        [action addButtonWithTitle:NSLocalizedString(@"Mail Link", @"Mail Link")];
    
    [action showFromBarButtonItem:sender animated:YES];
    self.myActionSheet = action;
    [action release];
}

- (void) loadURL:(NSString *)url {
    if( ![[url lowercaseString] hasPrefix:@"http://"] && ![[url lowercaseString] hasPrefix:@"https://"] )
        url = [NSString stringWithFormat:@"http://%@", url];
    
    self.destURL = url;
    
    [self stopLoading];
    
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [self.webView loadRequest:req];
}

- (BOOL) disablesAutomaticKeyboardDismissal {
    return NO;
}

//This is one of the delegate methods that handles success or failure
//and dismisses the mail
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {    
    [self dismissModalViewControllerAnimated:YES];
    
    if (result == MFMailComposeResultFailed && error )
        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                            message:[error localizedDescription] 
                        buttonTitle:NSLocalizedString(@"OK", @"OK")];
}

// We've clicked a button in this contextual menu
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if( buttonIndex == -1 )
        return;
    
    if( ![[AccountUtil sharedAccountUtil] isChatterEnabled] )
        buttonIndex++;
    
    if( self.chatterPop ) {
        [self.chatterPop dismissPopoverAnimated:NO];
        self.chatterPop = nil;
    }
    
    if (buttonIndex == 0) {
        NSDictionary *account = nil;
        
        if( self.detailViewController.recordOverviewController && 
           [[[self.detailViewController.recordOverviewController account] objectForKey:@"Id"] length] >= 15 &&
           [[AccountUtil sharedAccountUtil] isObjectChatterEnabled:@"Account"] )
            account = [self.detailViewController.recordOverviewController account];        
        
        ChatterPostController *cpc = [[ChatterPostController alloc] initWithPostDictionary:
                                      [NSDictionary dictionaryWithObjectsAndKeys:
                                       self.destURL, @"link",
                                       [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"], @"title",
                                       ( account ? [account objectForKey:@"Name"] : [[[[AccountUtil sharedAccountUtil] client] currentUserInfo] fullName] ), @"parentName",
                                       ( account ? [account objectForKey:@"Id"] : [[[[AccountUtil sharedAccountUtil] client] currentUserInfo] userId] ), @"parentId",
                                       ( account ? @"Account" : @"User" ), @"parentType",
                                       nil]];
        cpc.delegate = self;
                
        UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:cpc];
        [cpc release];
        
        self.chatterPop = [[[UIPopoverController alloc] initWithContentViewController:aNavController] autorelease];
        self.chatterPop.delegate = self;
        [aNavController release];
        
        [self.chatterPop presentPopoverFromBarButtonItem:self.actionButton
                                permittedArrowDirections:UIPopoverArrowDirectionAny
                                                animated:YES];
    } else if( buttonIndex == 1 ) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = self.destURL;      
    } else if (buttonIndex == 2) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.destURL]];
    } else if( buttonIndex == 3 ) {
        MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
        mailViewController.mailComposeDelegate = self;
        [mailViewController setSubject:@""];
        [mailViewController setMessageBody:[NSString stringWithFormat:@"%@\n%@",
                                        [webView stringByEvaluatingJavaScriptFromString:@"document.title"],
                                        self.destURL]
                                    isHTML:NO];
        
        [self presentModalViewController:mailViewController animated:YES];
        [mailViewController release];
    }
    
    myActionSheet = nil;
}

#pragma mark - popover delegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController {
    return NO;
}

#pragma mark - chatter post delegate

- (void) chatterPostDidPost:(ChatterPostController *)chatterPostController {
    SlideInView *checkView = [SlideInView viewWithImage:[UIImage imageNamed:@"postSuccess.png"]];
    
    [checkView showWithTimer:1.5f 
                      inView:((UINavigationController *)self.chatterPop.contentViewController).topViewController.view
                        from:SlideInViewTop
                      bounce:NO];
    
    [self performSelector:@selector(dismissPopover)
               withObject:nil
               afterDelay:1.6f];
}

- (void) dismissPopover {    
    [self.chatterPop dismissPopoverAnimated:YES];
    self.chatterPop = nil;
}

- (void) chatterPostDidDismiss:(ChatterPostController *)chatterPostController {
    [self dismissPopover];
}

- (void) chatterPostDidFailWithException:(ChatterPostController *)chatterPostController exception:(NSException *)e {
    [[AccountUtil sharedAccountUtil] receivedException:e];
    [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert") 
                        message:[e reason]
                    buttonTitle:@"OK"];
}

@end
