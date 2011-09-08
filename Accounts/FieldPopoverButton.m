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
#import "FieldPopoverButton.h"
#import "DetailViewController.h"
#import "SimpleKeychain.h"
#import "RootViewController.h"
#import "FollowButton.h"

@implementation FieldPopoverButton

@synthesize popoverController, fieldType, buttonDetailText, detailViewController;

static NSString *facetimeFormat = @"facetime://%@";
static NSString *skypeFormat = @"skype://%@?call";
static NSString *openInMapsFormat = @"https://maps.google.com/maps?q=%@";

+ (id) buttonWithText:(NSString *)text fieldType:(enum FieldType)fT detailText:(NSString *)detailText {
    FieldPopoverButton *button = [self buttonWithType:UIButtonTypeCustom];
    
    button.buttonDetailText = detailText;
    button.fieldType = fT;
    
    button.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:14];
    
    if( fT != TextField )
        [button setTitleColor:UIColorFromRGB(0x1679c9) forState:UIControlStateNormal];
    else
        [button setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        
    [button setTitleColor:[UIColor darkTextColor] forState:UIControlStateHighlighted];
    button.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = UITextAlignmentLeft;
    button.titleLabel.adjustsFontSizeToFitWidth = NO;
    
    if( fT != UserPhotoField )
        [button setTitle:text forState:UIControlStateNormal];
    
    [button addTarget:button action:@selector(fieldTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    return button;
}

- (void) setFieldUser:(ZKSObject *)user {    
    myUser = [user retain];
}

// Capture tapping a field
- (void) fieldTapped:(FieldPopoverButton *)button {    
    UIActionSheet *action = nil;
    UIViewController *popoverContent = nil;
    
    NSString *url = nil;
    
    switch( self.fieldType ) {
        case EmailField:
            action = [[[UIActionSheet alloc] init] autorelease];
            action.delegate = self;
            action.title = button.buttonDetailText;
            [action addButtonWithTitle:NSLocalizedString(@"Copy", @"Copy")];
            [action addButtonWithTitle:NSLocalizedString(@"Send Email", @"Send email")];

            url = [NSString stringWithFormat:facetimeFormat, 
                                    [button.buttonDetailText stringByReplacingOccurrencesOfString:@" " withString:@""]];
            
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]])
                [action addButtonWithTitle:NSLocalizedString(@"Call with FaceTime", @"Call with FaceTime")];
            
            [action showFromRect:button.frame inView:self.superview animated:YES];
            break;
        case URLField:            
            [self.detailViewController openWebView:self.buttonDetailText];
            
            break;
        case TextField:
            action = [[[UIActionSheet alloc] initWithTitle:button.buttonDetailText
                                                 delegate:self
                                        cancelButtonTitle:nil
                                   destructiveButtonTitle:nil
                                        otherButtonTitles:NSLocalizedString(@"Copy", @"Copy"), nil] autorelease];
            
            [action showFromRect:button.frame inView:self.superview animated:YES];
            break;
        case PhoneField:
            action = [[[UIActionSheet alloc] init] autorelease];
            action.delegate = self;
            action.title = button.buttonDetailText;
            [action addButtonWithTitle:NSLocalizedString(@"Copy", @"Copy")];
            
            NSString *phone = [button.buttonDetailText stringByReplacingOccurrencesOfString:@" " withString:@""];
            
            url = [NSString stringWithFormat:skypeFormat, phone];
            
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]])
                [action addButtonWithTitle:NSLocalizedString(@"Call with Skype", @"Call with Skype")];
            
            url = [NSString stringWithFormat:facetimeFormat, phone];
            
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]])
                [action addButtonWithTitle:NSLocalizedString(@"Call with FaceTime", @"Call with FaceTime")];
            
            [action showFromRect:button.frame inView:self.superview animated:YES];
            break;
        case AddressField:
            action = [[[UIActionSheet alloc] initWithTitle:button.buttonDetailText
                                                 delegate:self
                                        cancelButtonTitle:nil
                                   destructiveButtonTitle:nil
                                        otherButtonTitles:NSLocalizedString(@"Copy", @"Copy"),
                                                        NSLocalizedString(@"Open in Maps", @"Open in Maps"),
                                                        nil] autorelease];
            
            [action showFromRect:button.frame inView:self.superview animated:YES];            
            break;
        case UserField: 
        case UserPhotoField:            
            popoverContent = [[UIViewController alloc] init];
            popoverContent.view = [self userPopoverView];
            popoverContent.contentSizeForViewInPopover = CGSizeMake( popoverContent.view.frame.size.width, popoverContent.view.frame.size.height );
            popoverContent.title = [myUser fieldValue:@"Name"];
            popoverContent.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Email", @"Email action")
                                                                                                style:UIBarButtonItemStyleBordered
                                                                                               target:self
                                                                                               action:@selector(openEmailComposer:)] autorelease];
            
            if( [[AccountUtil sharedAccountUtil] isChatterEnabled] ) {
                NSString *uId = [[[[AccountUtil sharedAccountUtil] client] currentUserInfo] userId];
                NSString *pId = [myUser fieldValue:@"Id"];
                
                if( uId && pId && ![uId isEqualToString:pId] ) {
                    FollowButton *followButton = [FollowButton followButtonWithUserId:uId
                                                                             parentId:pId
                                                                               target:nil 
                                                                               action:nil];
                    [followButton setFrame:CGRectMake( 0, 0, 95, 30 )];
                    popoverContent.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:followButton] autorelease];
                }
            }
            
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:popoverContent];
            [popoverContent release];
            
            self.popoverController = [[[UIPopoverController alloc]
                                      initWithContentViewController:nav] autorelease];
            [nav release];

            [self.popoverController presentPopoverFromRect:button.frame
                                                    inView:self.superview
                                  permittedArrowDirections:UIPopoverArrowDirectionAny
                                                  animated:YES];
            break;
    }
}

// We've clicked a button in this contextual menu
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {    
    NSString *urlString = nil;
    
    if (buttonIndex == 0) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = self.buttonDetailText;        
    } else if (buttonIndex == 1) {        
        switch( self.fieldType ) {
            case EmailField:
                [self openEmailComposer:self];
                break;
                
            case AddressField:
                urlString = [NSString stringWithFormat:openInMapsFormat,
                                 self.buttonDetailText];
                
                urlString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                                
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
                break;
            case PhoneField:
                urlString = [NSString stringWithFormat:skypeFormat, 
                                                        [self.buttonDetailText stringByReplacingOccurrencesOfString:@" " withString:@""]];
                
                if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlString]])
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
                else {
                    urlString = [NSString stringWithFormat:facetimeFormat, 
                                 [self.buttonDetailText stringByReplacingOccurrencesOfString:@" " withString:@""]];
                    
                    if( [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlString]] )
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
                }
                break;
            default: break;
        }
    } else if( buttonIndex == 2 ) {
        switch( self.fieldType ) {
            case PhoneField: 
            case EmailField:
                urlString = [NSString stringWithFormat:facetimeFormat, 
                                                 [self.buttonDetailText stringByReplacingOccurrencesOfString:@" " withString:@""]];
                
                if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlString]])
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
                break;
            default: break;
        }
    }
}

- (UIScrollView *) userPopoverView {
    int curY = 10, curX = 5;
    UIScrollView *view = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 350, 0)];
    
    view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]]; 
    
    // User Photo
    UIImage *userPhoto = nil;
    
    if( [[AccountUtil sharedAccountUtil] isChatterEnabled] ) {
        NSString *url = [myUser fieldValue:@"FullPhotoUrl"];
        
        userPhoto = [[AccountUtil sharedAccountUtil] userPhotoFromCache:url];
    }
        
    if( userPhoto ) {     
        userPhoto = [AccountUtil roundCornersOfImage:userPhoto roundRadius:5];
        
        UIImageView *userPhotoView = [[UIImageView alloc] initWithImage:userPhoto];
        [userPhotoView setFrame:CGRectMake( curX, curY, userPhoto.size.width, userPhoto.size.height)];
        
        [view addSubview:userPhotoView];
        [userPhotoView release];
        
        curX += userPhoto.size.width + 10;
        
        [view setFrame:CGRectMake(0, 0, userPhoto.size.width + 300, 0)];
    }
    
    // User title
    if( [myUser fieldValue:@"Title"] ) {
        UILabel *userTitle = [[UILabel alloc] initWithFrame:CGRectMake( curX, curY, view.frame.size.width - curX - 5, 20)];
        userTitle.text = [myUser fieldValue:@"Title"];
        userTitle.textColor = [UIColor whiteColor];
        userTitle.backgroundColor = [UIColor clearColor];
        userTitle.font = [UIFont fontWithName:@"Helvetica" size:18];
        userTitle.numberOfLines = 0;
        userTitle.adjustsFontSizeToFitWidth = NO;
        userTitle.shadowColor = [UIColor darkTextColor];
        userTitle.shadowOffset = CGSizeMake(0, 2);
        
        [userTitle sizeToFit];

        curY += userTitle.frame.size.height;
        [view addSubview:userTitle];
        
        [userTitle release];
    }
    
    NSArray *orderedKeys = [NSArray arrayWithObjects:@"Department", @"Phone", @"MobilePhone", @"CurrentStatus", @"AboutMe", nil];
    NSDictionary *fieldNames = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"Phone", @"Phone",
                                @"Department", @"Department",
                                @"Mobile", @"MobilePhone",
                                @"Current Status", @"CurrentStatus",
                                @"About Me", @"AboutMe",
                                nil];
    
    for( NSString *field in orderedKeys ) {
        if( ![myUser fieldValue:field] || ![fieldNames objectForKey:field] )
            continue;
        
        UILabel *label = [self labelForField:[fieldNames objectForKey:field]];
        [label sizeToFit];
        [label setFrame:CGRectMake( curX, curY, label.frame.size.width, label.frame.size.height )];
        
        curY += label.frame.size.height;
        [view addSubview:label];
        
        UILabel *value = [self valueForField:[myUser fieldValue:field]];
        CGSize s = [value.text sizeWithFont:value.font
                                constrainedToSize:CGSizeMake( view.frame.size.width - curX - 5, 9999 )
                                    lineBreakMode:UILineBreakModeWordWrap];
        
        [value setFrame:CGRectMake( curX, curY, s.width, s.height )];
        curY += value.frame.size.height;
        
        [view addSubview:value];
    }
    
    if( userPhoto && curY < userPhoto.size.height + 15 )
        curY = userPhoto.size.height + 15;
    
    if( [[AccountUtil sharedAccountUtil] isChatterEnabled] && curY < 150 )
        curY = 150;
    
    [view setFrame:CGRectMake(0, 0, view.frame.size.width, MIN( curY, 450 ) )];
    [view setContentSize:CGSizeMake( view.frame.size.width, curY + 1 )];
    [view setContentOffset:CGPointZero];
    
    return [view autorelease];
}

- (IBAction) openEmailComposer:(id)sender {
    [self.detailViewController openEmailComposer:[myUser fieldValue:@"Email"]];
}

- (UILabel *) labelForField:(NSString *)field {
    UILabel *label = [[UILabel alloc] init];
    label.text = field;
    label.font = [UIFont boldSystemFontOfSize:15];
    label.textColor = AppSecondaryColor;
    label.backgroundColor = [UIColor clearColor];
    label.shadowColor = [UIColor darkTextColor];
    label.shadowOffset = CGSizeMake(0, 1);
    
    [label sizeToFit];
    
    return [label autorelease];
}

- (UILabel *) valueForField:(NSString *)value {
    UILabel *label = [[UILabel alloc] init];
    label.text = value;
    label.textColor = [UIColor lightTextColor];
    label.font = [UIFont systemFontOfSize:14];
    label.backgroundColor = [UIColor clearColor];
    label.numberOfLines = 0;
    
    [label sizeToFit];
    
    return [label autorelease];
}

- (void)dealloc {
    [myUser release];
    [popoverController release];
    [super dealloc];
}

@end
