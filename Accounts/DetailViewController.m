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
#import "DetailViewController.h"
#import "RecordOverviewController.h"
#import "RecordNewsViewController.h"
#import "SubNavViewController.h"
#import "RootViewController.h"
#import "AccountUtil.h"
#import "zkSforce.h"
#import "FieldPopoverButton.h"
#import "FlyingWindowController.h"
#import <QuartzCore/QuartzCore.h>
#import "WebViewController.h"
#import "PRPAlertView.h"

@implementation DetailViewController

@synthesize subNavViewController, rootViewController, flyingWindows, browseButton, recordOverviewController;

static int maxAccountNames = 10;
static float windowOverlap = 30.0f;

// allow multiple flying windows of the same type?
BOOL allowMultipleWindows = NO;

- (void) awakeFromNib {
    [super awakeFromNib];
    
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"tableBG.png"]];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)viewDidUnload {    
    if( self.recordOverviewController ) {
        [self.recordOverviewController.view removeFromSuperview];
        self.recordOverviewController = nil;
    }
    
    [self clearFlyingWindows];
    
    [super viewDidUnload];
}

- (void)dealloc {
    [browseButton release];
    [flyingWindows release];
    [account release];
    [super dealloc];
}

- (void) handleInterfaceRotation:(BOOL)isPortrait {    
    if( self.subNavViewController )
        [self.subNavViewController handleInterfaceRotation:isPortrait];
    
    float framewidth;
    
    if( !isPortrait )
        framewidth = 1024 - masterWidth - 1;
    else
        framewidth = 768;
    
    CGRect r;
    
    if( self.recordOverviewController ) {
        r = self.recordOverviewController.view.frame;
        
        r.size.width = lroundf( framewidth / 2.0f );
        r.origin.x = 0;
        
        [self.recordOverviewController.view setFrame:r];
    }
    
    if( self.flyingWindows )
        for( FlyingWindowController *fwc in self.flyingWindows ) {
            r = fwc.view.frame;
                        
            if( fwc.flyingWindowType == FlyingWindowWebView ) {
                r.size.width = framewidth - windowOverlap + ( isPortrait ? 1 : -60 );
                
                CGRect webViewFrame = ((WebViewController *)fwc).webView.frame;
                webViewFrame.size.width = r.size.width;
                
                [((WebViewController *)fwc).webView setFrame:webViewFrame];
            } else
                r.size.width = lroundf( framewidth / 2.0f );
            
            if( ![fwc isEqual:[self.flyingWindows lastObject]] )
                r.origin.x = 0;
            else if( [fwc isEqual:[self.flyingWindows objectAtIndex:0]] && [self.flyingWindows count] == 1 && !self.recordOverviewController )
                r.origin.x = lroundf( ( framewidth - r.size.width ) / 2.0f );
            else if( fwc.flyingWindowType == FlyingWindowWebView )
                r.origin.x = lroundf( framewidth - r.size.width + ( isPortrait ? 30 : -30 ) ); //windowOverlap + 20;
            else
                r.origin.x = lroundf( framewidth / 2.0f ) + ( isPortrait ? 30 : -30 );
                                 
            [fwc.view setFrame:r];
        }
}

- (void) addAccountNewsTable {        
    if( !self.subNavViewController )
        return;
    
    if( self.recordOverviewController ) {
        [self.recordOverviewController.view removeFromSuperview];
        self.recordOverviewController = nil;
    }
    
    [self clearFlyingWindows];
    
    // Build a list of account names as our search term
    NSString *searchTerm = @"";
    NSArray *accounts = [self.subNavViewController.myRecords allValues];

    if( accounts && [accounts count] > 0 ) {
        accounts = [AccountUtil randomSubsetFromArray:accounts ofSize:maxAccountNames];
        NSArray *names = [NSArray array];
        
        for( id acc in accounts ) {
            if( [acc isKindOfClass:[NSArray class]] )
                names = [names arrayByAddingObject:[[acc objectAtIndex:0] objectForKey:@"Name"]];
            else
                names = [names arrayByAddingObject:[acc objectForKey:@"Name"]];
        }
            
        for( NSString *name in names ) {
            name = [NSString stringWithFormat:@"\"%@\"", name];
            
            if( [searchTerm isEqualToString:@""] )
                searchTerm = name;
            else
                searchTerm = [searchTerm stringByAppendingFormat:@" OR %@", name];
        }
        
        [self addFlyingWindow:FlyingWindowNews withArg:searchTerm];
    } else
        [self addFlyingWindow:FlyingWindowNews withArg:nil];
    
    RecordNewsViewController *fwc = [self.flyingWindows objectAtIndex:0];
    
    if( [RootViewController isPortrait] )
        [fwc.navBar.topItem setLeftBarButtonItem:self.browseButton animated:YES];
}
    

- (void) setPopoverButton:(UIBarButtonItem *)button {    
    if( button )
        self.browseButton = button;
    
    if( self.recordOverviewController )
        [self.recordOverviewController.navBar.topItem setLeftBarButtonItem:button animated:YES];
    else if( self.flyingWindows && [self.flyingWindows count] > 0 )
        [((FlyingWindowController *)[self.flyingWindows objectAtIndex:0]).navBar.topItem setLeftBarButtonItem:button animated:YES];
}

- (void) didSelectAccount:(NSDictionary *) acc {   
    if( !acc )
        return;
    
    account = [acc retain];
    
    [self clearFlyingWindows];
    
    // Make sure the network meter is reset
    for( int x = 0; x < 20; x++ )
        [[AccountUtil sharedAccountUtil] endNetworkAction];
    
    if( !self.recordOverviewController ) {
        CGRect r = self.view.bounds;
        
        r.origin.x = r.size.width;
        r.size.width = lroundf( r.size.width / 2.0f );

        RecordOverviewController *fwc = [[RecordOverviewController alloc] initWithFrame:r];
        fwc.detailViewController = self;
        fwc.rootViewController = self.rootViewController;
        fwc.subNavViewController = self.subNavViewController;
        fwc.delegate = self;
        fwc.flyingWindowType = FlyingWindowRecordOverview;
        
        self.recordOverviewController = fwc;
        [fwc release];
        
        [self.view addSubview:self.recordOverviewController.view];
        CGPoint center = CGPointMake( lroundf( self.view.bounds.size.width / 4.0f ), lroundf( self.view.bounds.size.height / 2.0f ) );
        [self.recordOverviewController slideFlyingWindowToPoint:center];
    }
    
    [self.recordOverviewController selectAccount:account];
    
    if( [RootViewController isPortrait] )
        [self.recordOverviewController.navBar.topItem setLeftBarButtonItem:self.browseButton animated:YES];
    
    [self addFlyingWindow:FlyingWindowNews withArg:nil];
}

- (NSString *) visibleAccountId {
    if( account )
        return [account objectForKey:@"Id"];
    
    return nil;
}

#pragma mark - Flying Window delegate/management

- (BOOL) flyingWindowShouldDrag:(FlyingWindowController *)flyingWindowController {
    if( [flyingWindowController isKindOfClass:[WebViewController class]] )
        return ![(WebViewController *)flyingWindowController isFullScreen];
    
    return YES;
}

- (CGPoint) translateFlyingWindowCenterPoint:(FlyingWindowController *)flyingWindowController originalPoint:(CGPoint)originalPoint isDragging:(BOOL)isDragging {
    float framewidth = ( [RootViewController isPortrait] ? 768 : 1024 - masterWidth - 1 ), 
        windowwidth = flyingWindowController.view.frame.size.width,
        leftCenter = ( framewidth / 2.0f ) - ( windowwidth / 2.0f ),
        rightCenter = ( framewidth / 2.0f ) + ( windowwidth / 2.0f ),
        centerCenter = ( framewidth / 2.0f ), leftbound, rightbound, target;
    CGPoint newPoint;
    int flyingWindowCount = ( self.flyingWindows ? [self.flyingWindows count] : 0 ), 
        totalWindowCount = flyingWindowCount + ( self.recordOverviewController ? 1 : 0 );
    BOOL isLeftmost, isRightmost, isAlone;
        
    isLeftmost = [flyingWindowController isEqual:self.recordOverviewController] ||
                ( !self.recordOverviewController && [[self.flyingWindows objectAtIndex:0] isEqual:flyingWindowController] );
    isRightmost = ( flyingWindowCount == 0 && [flyingWindowController isEqual:self.recordOverviewController] ) ||
                [[self.flyingWindows lastObject] isEqual:flyingWindowController];
    isAlone = totalWindowCount == 1; 
    
    leftbound = rightbound = target = leftCenter;
    
    // define a left/right bound for dragging, and a target when released, for each type of window
    // given its position in the window stack
    if( flyingWindowController.flyingWindowType == FlyingWindowWebView ) {
        leftbound = centerCenter;
        rightbound = rightCenter;
        
        if( isRightmost && totalWindowCount >= 3 ) {
            rightbound = 2000;
            
            if( originalPoint.x > rightCenter + 75 )
                target = framewidth + ( windowwidth / 2.0f );
            else
                target = centerCenter + windowOverlap;
        } else if( ( originalPoint.x - centerCenter ) < ( rightCenter - originalPoint.x ) )
            target = centerCenter + windowOverlap;
        else
            target = rightCenter;
    } else if( isAlone ) {
        leftbound = rightbound = target = centerCenter;
    } else if( isLeftmost ) {
        rightbound = target = leftCenter;
    } else if( !isLeftmost && !isRightmost ) {
        leftbound = leftCenter;
        
        if( totalWindowCount <= 2 || !flyingWindowController.leftFWC.leftFWC )
            rightbound = rightCenter;
        else
            rightbound = 2000;
        
        if( flyingWindowController.leftFWC.leftFWC && originalPoint.x > rightCenter + 75 )
            target = framewidth + ( windowwidth / 2.0f );
        else if( ( rightCenter - originalPoint.x ) > ( originalPoint.x - leftCenter ) )
            target = leftCenter;
        else
            target = rightCenter;        
    } else if( isRightmost && !isLeftmost ) {
        leftbound = target = rightCenter;
        
        if( totalWindowCount <= 2 )
            rightbound = rightCenter;
        else {
            rightbound = 2000;
            
            if( originalPoint.x < rightCenter + 75 )
                target = rightCenter;
            else
                target = framewidth + ( windowwidth / 2.0f );
        }
    }
    
    // if we are dragging beyond a bound, we apply some resistance 
    if( isDragging ) {        
        if( originalPoint.x < leftbound )
            newPoint.x = leftbound + ( ( originalPoint.x - leftbound ) / 5 );
        else if( originalPoint.x > rightbound )
            newPoint.x = rightbound + ( ( originalPoint.x - rightbound ) / 5 );
        else
            newPoint.x = originalPoint.x;
        
        CGPoint otherCenter;
        float otherWidth, ourWidth = flyingWindowController.view.frame.size.width;
            
        if( flyingWindowController.leftFWC ) {
            otherCenter = flyingWindowController.leftFWC.view.center;
            otherWidth = flyingWindowController.leftFWC.view.frame.size.width;
            
            otherCenter.x = newPoint.x - ( ourWidth / 2.0f ) - ( otherWidth / 2.0f );
            
            if( otherCenter.x < ( framewidth / 4.0f ) )
                otherCenter.x = framewidth / 4.0f;
            
            otherCenter.x = lroundf( otherCenter.x );
            
            if( CGRectIntersectsRect( flyingWindowController.view.frame, flyingWindowController.leftFWC.view.frame ) &&
               CGRectIntersection( flyingWindowController.view.frame, flyingWindowController.leftFWC.view.frame ).size.width > 40 )
                [flyingWindowController.leftFWC slideFlyingWindowToPoint:otherCenter];
            else
                [flyingWindowController.leftFWC.view setCenter:otherCenter];
        }
        
        if( flyingWindowController.rightFWC ) {
            otherCenter = flyingWindowController.rightFWC.view.center;
            otherWidth = flyingWindowController.rightFWC.view.frame.size.width;
            
            otherCenter.x = lroundf( newPoint.x + ( ourWidth / 2.0f ) + ( otherWidth / 2.0f ) );
            
            [self.view bringSubviewToFront:flyingWindowController.rightFWC.view];
            
            if( CGRectIntersectsRect( flyingWindowController.view.frame, flyingWindowController.rightFWC.view.frame ) &&
               CGRectIntersection( flyingWindowController.view.frame, flyingWindowController.rightFWC.view.frame ).size.width > 40 )
                [flyingWindowController.rightFWC slideFlyingWindowToPoint:otherCenter];
            else
                [flyingWindowController.rightFWC.view setCenter:otherCenter];
            
            if( flyingWindowController.rightFWC.rightFWC ) {
                [self.view bringSubviewToFront:flyingWindowController.rightFWC.rightFWC.view];
                
                CGPoint p = flyingWindowController.rightFWC.rightFWC.view.center;
                
                p.x = otherCenter.x + ( flyingWindowController.rightFWC.view.frame.size.width / 2.0f ) + ( flyingWindowController.rightFWC.rightFWC.view.frame.size.width / 2.0f );
                
                [flyingWindowController.rightFWC.rightFWC.view setCenter:p];
            }
        }            
        
        // dimming
        if( flyingWindowController.leftFWC ) {
            CGRect overlap = CGRectIntersection( flyingWindowController.view.frame, flyingWindowController.leftFWC.view.frame );
            float perc = overlap.size.width / flyingWindowController.leftFWC.view.frame.size.width;

            [flyingWindowController.leftFWC setDimmerAlpha:perc];
        }
        
        [flyingWindowController setDimmerAlpha:0];
        
        if( flyingWindowController.rightFWC ) {
            CGRect overlap = CGRectIntersection( flyingWindowController.view.frame, flyingWindowController.rightFWC.view.frame );
            float perc = overlap.size.width / flyingWindowController.rightFWC.view.frame.size.width;
            
            [flyingWindowController.rightFWC setDimmerAlpha:perc];
        }
    } else { /* released touch. snap to target */
        newPoint.x = lroundf( target );
        
        // Ensure the window to our left slides back to its position too
        if( flyingWindowController.leftFWC ) {
            CGPoint p = flyingWindowController.leftFWC.view.center;
            int leftTarget = target - ( flyingWindowController.view.frame.size.width / 2.0f ) - ( flyingWindowController.leftFWC.view.frame.size.width / 2.0f );
            
            if( leftTarget < centerCenter )
                leftTarget = framewidth / 4.0f;
            else if( target > framewidth * 0.75f )
                leftTarget = framewidth * 0.75f;
            
            p.x = lroundf( leftTarget ) + ( [RootViewController isPortrait] ? 0 : 1 );
            
            [flyingWindowController.leftFWC slideFlyingWindowToPoint:p];
        }
            
        if( flyingWindowController.rightFWC ) {
            CGPoint p = flyingWindowController.rightFWC.view.center;
            int rightTarget;
            
            if( target < centerCenter )
                rightTarget = centerCenter + ( flyingWindowController.rightFWC.view.frame.size.width / 2.0f );
            else
                rightTarget = framewidth + ( flyingWindowController.rightFWC.view.frame.size.width / 2.0f );

            p.x = lroundf( rightTarget );
                
            [flyingWindowController.rightFWC slideFlyingWindowToPoint:p];
            
            if( flyingWindowController.rightFWC.rightFWC ) {
                p = flyingWindowController.rightFWC.rightFWC.view.center;
                p.x = framewidth + ( flyingWindowController.rightFWC.rightFWC.view.frame.size.width / 2.0f );
                
                [flyingWindowController.rightFWC.rightFWC slideFlyingWindowToPoint:p];
            }
        }    
    }

    newPoint.y = lroundf( self.view.bounds.size.height / 2.0f );
        
    return newPoint;
}

- (void) tearOffFlyingWindowsStartingWith:(FlyingWindowController *)flyingWindowController {
    if( !self.flyingWindows || [self.flyingWindows count] == 0 )
        return;
    
    int tearPoint = -1;
    
    for( int x = 0; x < [self.flyingWindows count]; x++ ) {
        FlyingWindowController *fwc = [self.flyingWindows objectAtIndex:x];
        
        if( [fwc isEqual:flyingWindowController] )
            tearPoint = x;
    }
    
    if( tearPoint != -1 )
        for( int x = [self.flyingWindows count] - 1; x >= tearPoint; x-- ) {
            FlyingWindowController *fwc = [self.flyingWindows objectAtIndex:x];
            fwc.leftFWC.rightFWC = nil;
            
            [fwc.view removeFromSuperview];
            fwc = nil;
            [self.flyingWindows removeObjectAtIndex:x];
        }
    
    if( tearPoint > 0 )
        [[self.flyingWindows objectAtIndex:tearPoint-1] slideFlyingWindowToPoint:CGPointMake( lroundf( self.view.frame.size.width * 0.75f ), lroundf( self.view.frame.size.height / 2.0f ))];
}

- (void) addFlyingWindow:(enum FlyingWindowTypes)windowType withArg:(NSString *)arg {
    FlyingWindowController *fwc = nil;
    float framewidth = self.view.bounds.size.width;
    
    if( !self.flyingWindows )
        self.flyingWindows = [NSMutableArray array];
    
    for( int x = 0; x < [self.flyingWindows count]; x++ ) {
        FlyingWindowController *fwc = [self.flyingWindows objectAtIndex:x];
        
        CGRect fr = fwc.view.frame;
        
        [self.view bringSubviewToFront:fwc.view];  
        
        // always zap webviews
        if( fwc.flyingWindowType == FlyingWindowWebView ) {
            [fwc.view removeFromSuperview];
            [self.flyingWindows removeObject:fwc];
            fwc = nil;
            continue;
        }
        
        CGPoint center = CGPointMake( lroundf( framewidth / 4.0f ), lroundf( fr.size.height / 2.0f ) );
        
        // move windows over
        if( !allowMultipleWindows && fwc.flyingWindowType == windowType ) {
            if( x > 0 )
                [(FlyingWindowController *)[self.flyingWindows objectAtIndex:(x-1)] slideFlyingWindowToPoint:center];
            
            center.x = lroundf( framewidth * 0.75 );
            [fwc slideFlyingWindowToPoint:center];
            
            return;
        }
        
        [fwc slideFlyingWindowToPoint:center];
    }
    
    CGRect r = CGRectMake( 1100, 0, lroundf( framewidth / 2.0f ), self.view.bounds.size.height );
    
    float centerCenter = framewidth / 2.0f,
        rightCenter = 1.5f * centerCenter;
        
    switch( windowType ) {
        case FlyingWindowRecordOverview:
            fwc = [[RecordOverviewController alloc] initWithFrame:r];
            break;
        case FlyingWindowNews:
            fwc = [[RecordNewsViewController alloc] initWithFrame:r];
            
            if( arg ) {
                [(RecordNewsViewController *)fwc setCompoundNewsView:YES];
                [(RecordNewsViewController *)fwc setNewsSearchTerm:arg];
            } else {
                [(RecordNewsViewController *)fwc setCompoundNewsView:NO];
                [(RecordNewsViewController *)fwc setNewsSearchTerm:( account ? [account objectForKey:@"Name"] : @"Salesforce.com" )];
            }
            break;
        case FlyingWindowWebView:
            r.size.width = framewidth - windowOverlap - 30;
            fwc = [[WebViewController alloc] initWithFrame:r];
            [(WebViewController *)fwc loadURL:arg];
            
            rightCenter = framewidth;
            break;
        default:
            break;
    }
    
    fwc.detailViewController = self;
    fwc.rootViewController = self.rootViewController;
    fwc.subNavViewController = self.subNavViewController;
    fwc.delegate = self;
    fwc.flyingWindowType = windowType;
    [fwc selectAccount:account];
    
    if( self.recordOverviewController && [self.flyingWindows count] == 0 ) {
        fwc.leftFWC = self.recordOverviewController;
        self.recordOverviewController.rightFWC = fwc;
    } else if( [self.flyingWindows count] > 0 ) {
        fwc.leftFWC = [self.flyingWindows lastObject];
        ((FlyingWindowController *)[self.flyingWindows lastObject]).rightFWC = fwc;
    }
    
    CGPoint center = CGPointMake( lroundf( rightCenter ), lroundf( r.size.height / 2.0f ) );
    
    if( windowType == FlyingWindowWebView )
        center.x = centerCenter + windowOverlap;
    else if( !self.recordOverviewController && [self.flyingWindows count] == 0 )
        center.x = lroundf( centerCenter );
    
    [self.flyingWindows addObject:fwc];
    [self.view addSubview:fwc.view];
    [fwc slideFlyingWindowToPoint:center];
    [fwc release];
}

- (void) clearFlyingWindows {
    if( !self.flyingWindows || [self.flyingWindows count] == 0 )
        return;
    
    for( FlyingWindowController *fwc in self.flyingWindows ) {
        [fwc.view removeFromSuperview];
        fwc = nil;
    }
    
    [self.flyingWindows removeAllObjects];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
} 

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {    
    [self handleInterfaceRotation:UIInterfaceOrientationIsPortrait(toInterfaceOrientation)];
}

#pragma mark - email and webview

- (void) openWebView:(NSString *)url {    
    [self addFlyingWindow:FlyingWindowWebView withArg:url];
}

- (void) openEmailComposer:(NSString *)toAddress {
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
        mailViewController.mailComposeDelegate = self;
        [mailViewController setSubject:@""];
        [mailViewController setToRecipients:[NSArray arrayWithObjects:toAddress, nil]];
        
        
        [self.rootViewController.splitViewController presentModalViewController:mailViewController animated:YES];
        [mailViewController release];
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {    
    [self.rootViewController.splitViewController dismissModalViewControllerAnimated:YES];
    
    if (result == MFMailComposeResultFailed && error )
        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert") 
                            message:[error localizedDescription] 
                        buttonTitle:NSLocalizedString(@"OK",@"OK")];
}

- (void) eventLogInOrOut {                
    if( self.recordOverviewController ) {
        [self.recordOverviewController.view removeFromSuperview];
        self.recordOverviewController = nil;
    }
    
    [self clearFlyingWindows];
    
    [self.rootViewController allSubNavSelectAccountWithId:nil];
    
    if( ![self.rootViewController isLoggedIn] ) {                
        // we've just logged out
        [self addAccountNewsTable];
    } else {
        // we've just logged in
    }
}

@end
