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
#import "zkSforce.h"
#import "FollowButton.h"
#import <QuartzCore/QuartzCore.h>
#import "SubNavViewController.h"

@implementation FollowButton

@synthesize userId, parentId, followButtonState, followId, delegate, sheet;

+ (id) followButtonWithUserId:(NSString *)uId parentId:(NSString *)pId {    
    FollowButton *button = [FollowButton alloc];
    [button initWithTitle:NSLocalizedString(@"Loading...", nil)
                    style:UIBarButtonItemStyleBordered
                   target:button
                   action:@selector(buttonTapped:)];
    
    button.userId = uId;
    button.parentId = pId;
    button.followId = nil;
        
    return [button autorelease];
}

+ (UIBarButtonItem *) loadingBarButtonItem {
    UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake( 0, 0, 25, 25 )];
    [activity sizeToFit];
    [activity setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin)];
    [activity startAnimating];
    
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:activity];
    [activity release];
    
    TransparentToolBar *toolbar = [[TransparentToolBar alloc] initWithFrame:CGRectMake(0, 0, 50, 44)];
    [toolbar setItems:[NSArray arrayWithObjects:item, nil]];
    [item release];
    
    UIBarButtonItem *bar = [[UIBarButtonItem alloc] initWithCustomView:toolbar];
    [toolbar release];
    
    return [bar autorelease];
}

- (void) loadTitle {
    NSString *title = nil;
        
    switch( followButtonState ) {
        case FollowLoading:            
            title = @"";
            break;
        case FollowError:
            title = NSLocalizedString(@"Error", @"Error loading following state");
            break;
        case FollowFollowing:
            title = NSLocalizedString(@"Following", @"Following");
            break;
        case FollowNotFollowing:
            title = NSLocalizedString(@"Follow", @"Follow");
            break;
    }

    [self setTitle:title];
}

- (void) loadFollowState {
    if( !userId || !parentId )
        return;
    
    [self changeStateToState:FollowLoading isUserAction:NO];
    
    NSString *query = [NSString stringWithFormat:@"select id from EntitySubscription where subscriberid='%@' and parentid='%@' limit 1",
                       userId, parentId];
    
    NSLog(@"SOQL %@", query);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
        ZKQueryResult *qr = nil;
        
        @try {
            qr = [[[AccountUtil sharedAccountUtil] client] query:query];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] receivedException:e];
            self.followButtonState = FollowError;
            [self loadTitle];         
            
            if( [self.delegate respondsToSelector:@selector(followButtonDidReceiveException:exception:)] )
                [self.delegate followButtonDidReceiveException:self exception:e];
            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if( [[qr records] count] > 0 ) {
                self.followId = [[[qr records] objectAtIndex:0] fieldValue:@"Id"];
                [self changeStateToState:FollowFollowing isUserAction:NO];
            } else
                [self changeStateToState:FollowNotFollowing isUserAction:NO];
        });
    });
}

- (void) changeStateToState:(enum FollowButtonState)state isUserAction:(BOOL)isUserAction {
    if( [self.delegate respondsToSelector:@selector(followButtonWillChangeState:toState:isUserAction:)] )
        [self.delegate followButtonWillChangeState:self toState:state isUserAction:isUserAction];
    
    self.followButtonState = state;
    [self loadTitle];
    
    if( [self.delegate respondsToSelector:@selector(followButtonDidChangeState:toState:isUserAction:)] )
        [self.delegate followButtonDidChangeState:self toState:self.followButtonState isUserAction:isUserAction];
}

- (void) toggleFollow {
    if( self.followButtonState == FollowFollowing ) {
        if( !followId )
            return;
        
        [self changeStateToState:FollowLoading isUserAction:YES];
                
        // DELETE
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
            NSArray *dr = nil;
            
            NSLog(@"DELETING %@", self.followId);
            
            @try {
                dr = [[[AccountUtil sharedAccountUtil] client] delete:[NSArray arrayWithObjects:self.followId, nil]];
            } @catch( NSException *e ) {
                [[AccountUtil sharedAccountUtil] receivedException:e];
                self.followButtonState = FollowFollowing;
                [self loadTitle];      
                
                if( [self.delegate respondsToSelector:@selector(followButtonDidReceiveException:exception:)] )
                    [self.delegate followButtonDidReceiveException:self exception:e];
                
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {                
                if( [dr count] == 1 && [[dr objectAtIndex:0] success] ) {
                    [self changeStateToState:FollowNotFollowing isUserAction:YES];
                    followId = nil;
                    NSLog(@"DELETE success");
                }
            });
        });
    } else if( self.followButtonState == FollowNotFollowing ) {
        // INSERT
        
        [self changeStateToState:FollowLoading isUserAction:YES];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
            ZKSObject *followObject = [[ZKSObject alloc] initWithType:@"EntitySubscription"];
            [followObject setFieldValue:parentId field:@"parentId"];
            [followObject setFieldValue:userId field:@"subscriberId"];            
            
            NSLog(@"INSERTING %@", followObject);
            
            NSArray *results = nil;
            
            @try {
                results = [[[AccountUtil sharedAccountUtil] client] create:[NSArray arrayWithObjects:followObject, nil]];
            } @catch( NSException *e ) {
                [[AccountUtil sharedAccountUtil] receivedException:e];
                self.followButtonState = FollowNotFollowing;
                [self loadTitle];            
                
                if( [self.delegate respondsToSelector:@selector(followButtonDidReceiveException:exception:)] )
                    [self.delegate followButtonDidReceiveException:self exception:e];
                
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if( [results count] == 1 && [[results objectAtIndex:0] success] ) {
                    self.followId = [[results objectAtIndex:0] id];
                    
                    NSLog(@"INSERT success");
                    
                    [self changeStateToState:FollowFollowing isUserAction:YES];
                }
            });
        });
    } else {
        // reload state
        [self loadFollowState];
    }
}

// Capture tapping a field
- (void) buttonTapped:(FollowButton *)sender {    
    if( self.sheet ) {
        [self.sheet dismissWithClickedButtonIndex:-1 animated:YES];
        self.sheet = nil;
        return;
    }
    
    switch( followButtonState ) {
        case FollowFollowing:
            self.sheet = [[[UIActionSheet alloc] initWithTitle:nil
                                                  delegate:self
                                         cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                    destructiveButtonTitle:NSLocalizedString(@"Unfollow", @"Unfollow")
                                         otherButtonTitles:nil] autorelease];
            
            [sheet showFromBarButtonItem:self animated:YES];
            break;
        case FollowNotFollowing:
            [self toggleFollow];
            break;
        case FollowError:
            [self loadFollowState];
            break;
        default: break;
    }
}

// We've clicked a button in this contextual menu
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {        
    if( buttonIndex == 0 ) {
        [self toggleFollow];
    }
    
    self.sheet = nil;
}

- (void)dealloc {
    [userId release];
    [parentId release];
    [followId release];
    [sheet release];
    [super dealloc];
}

@end
