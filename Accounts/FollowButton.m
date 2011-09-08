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

#import "AccountUtil.h"
#import "zkSforce.h"
#import "FollowButton.h"
#import <QuartzCore/QuartzCore.h>

@implementation FollowButton

@synthesize userId, parentId, followButtonState, followId, target, action, activityIndicator;

+ (id) followButtonWithUserId:(NSString *)uId parentId:(NSString *)pId target:(id)target action:(SEL)action {    
    FollowButton *button = [self buttonWithType:UIButtonTypeCustom];
    
    button.userId = uId;
    button.parentId = pId;
    button.followId = nil;
    button.target = target;
    button.action = action;
    
    button.titleLabel.font = [UIFont boldSystemFontOfSize:13];        
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor darkTextColor] forState:UIControlStateHighlighted];
    
    button.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"barButtonBackground.png"]];
        
    button.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
    button.titleLabel.numberOfLines = 1;
    button.titleLabel.textAlignment = UITextAlignmentCenter;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    
    button.layer.masksToBounds = YES;
    button.layer.cornerRadius = 8.0f;
    
    [button addTarget:button action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    button.followButtonState = FollowLoading;
    
    [button loadTitle];    
    [button loadFollowState];
    
    return button;
}

- (void) loadTitle {
    NSString *title = nil;
    UIImage *image = nil;
    
    switch( followButtonState ) {
        case FollowLoading:
            if( !self.activityIndicator ) {
                self.activityIndicator = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite] autorelease];
                [self.activityIndicator setFrame:CGRectMake( 35, 5, 20, 20 )];
                [self.activityIndicator startAnimating];
                
                [self addSubview:self.activityIndicator];
            }
            break;
        case FollowError:
            title = NSLocalizedString(@"Error", @"Error loading following state");
            break;
        case FollowFollowing:
            title = NSLocalizedString(@"Following", @"Following");
            image = [UIImage imageNamed:@"following.png"];
            break;
        case FollowNotFollowing:
            title = NSLocalizedString(@"Follow", @"Follow");
            image = [UIImage imageNamed:@"follow.png"];
            break;
    }
    
    if( followButtonState != FollowLoading && self.activityIndicator ) {
        [self.activityIndicator stopAnimating];
        [self.activityIndicator removeFromSuperview];
        self.activityIndicator = nil;
    }

    [self setTitle:title forState:UIControlStateNormal];
    [self setImage:image forState:UIControlStateNormal];
    
    /*CGRect r = self.frame;
    CGSize s = [[self titleForState:UIControlStateNormal] sizeWithFont:self.titleLabel.font constrainedToSize:CGSizeMake( 150, 30 )];
    
    if( s.width < 95 )
        s.width = 95;
    
    if( s.height < 30 )
        s.height = 30;
    
    r.size = s;
    
    [self setFrame:r];*/
    
    if( image ) 
        self.imageEdgeInsets = UIEdgeInsetsMake( 0, 5, 0, 5 );
    else
        self.imageEdgeInsets = UIEdgeInsetsZero;
}

- (void) loadFollowState {
    if( !userId || !parentId )
        return;
    
    NSString *query = [NSString stringWithFormat:@"select id from EntitySubscription where subscriberid='%@' and parentid='%@' limit 1",
                       userId, parentId];
    
    NSLog(@"SOQL %@", query);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
        ZKQueryResult *qr = nil;
        
        @try {
            qr = [[[AccountUtil sharedAccountUtil] client] query:query];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] receivedException:e];
            followButtonState = FollowError;
            [self loadTitle];            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if( [[qr records] count] > 0 ) {
                followButtonState = FollowFollowing;
                self.followId = [[[qr records] objectAtIndex:0] fieldValue:@"Id"];
            } else
                followButtonState = FollowNotFollowing;
            
            [self loadTitle];
        });
    });
}

- (void) toggleFollow {
    if( followButtonState == FollowFollowing ) {
        if( !followId )
            return;
                
        // DELETE
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
            NSArray *dr = nil;
            followButtonState = FollowLoading;
            [self loadTitle];
            
            NSLog(@"DELETING %@", self.followId);
            
            @try {
                dr = [[[AccountUtil sharedAccountUtil] client] delete:[NSArray arrayWithObjects:self.followId, nil]];
            } @catch( NSException *e ) {
                [[AccountUtil sharedAccountUtil] receivedException:e];
                followButtonState = FollowFollowing;
                [self loadTitle];            
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {                
                if( [dr count] == 1 && [[dr objectAtIndex:0] success] ) {
                    followButtonState = FollowNotFollowing;
                    followId = nil;
                    NSLog(@"DELETE success");
                    
                    if( target && action && [target respondsToSelector:action] )
                        [target performSelector:action];
                }
                
                [self loadTitle];
            });
        });
    } else if( followButtonState == FollowNotFollowing ) {
        // INSERT
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
            ZKSObject *followObject = [[ZKSObject alloc] initWithType:@"EntitySubscription"];
            [followObject setFieldValue:parentId field:@"parentId"];
            [followObject setFieldValue:userId field:@"subscriberId"];            
            
            followButtonState = FollowLoading;
            [self loadTitle];
            
            NSLog(@"INSERTING %@", followObject);
            
            NSArray *results = nil;
            
            @try {
                results = [[[AccountUtil sharedAccountUtil] client] create:[NSArray arrayWithObjects:followObject, nil]];
            } @catch( NSException *e ) {
                [[AccountUtil sharedAccountUtil] receivedException:e];
                followButtonState = FollowNotFollowing;
                [self loadTitle];            
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if( [results count] == 1 && [[results objectAtIndex:0] success] ) {
                    followButtonState = FollowFollowing;
                    self.followId = [[results objectAtIndex:0] id];
                    
                    NSLog(@"INSERT success");
                    
                    if( target && action && [target respondsToSelector:action] )
                        [target performSelector:action];
                }
                
                [self loadTitle];
            });
        });
    } else {
        // reload state
        [self loadFollowState];
    }
}

// Capture tapping a field
- (void) buttonTapped:(FollowButton *)sender {    
    UIActionSheet *sheet = nil;
    
    switch( followButtonState ) {
        case FollowFollowing:
            sheet = [[[UIActionSheet alloc] initWithTitle:nil
                                                  delegate:self
                                         cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                    destructiveButtonTitle:NSLocalizedString(@"Unfollow", @"Unfollow")
                                         otherButtonTitles:nil] autorelease];
            
            [sheet showFromRect:sender.frame inView:self.superview animated:YES];
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
}

- (void)dealloc {
    [userId release];
    [activityIndicator release];
    [parentId release];
    [followId release];
    [super dealloc];
}

@end
