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
#import "FieldPopoverButton.h"
#import "DetailViewController.h"
#import "SimpleKeychain.h"
#import "RootViewController.h"
#import "FollowButton.h"

@implementation FieldPopoverButton

@synthesize popoverController, fieldType, buttonDetailText, detailViewController, myRecord, flyingWindowController, followButton;

static NSString *facetimeFormat = @"facetime://%@";
static NSString *skypeFormat = @"skype:%@?call";
static NSString *openInMapsFormat = @"http://maps.google.com/maps?q=%@";

+ (id) buttonWithText:(NSString *)text fieldType:(enum FieldType)fT detailText:(NSString *)detailText {
    FieldPopoverButton *button = [self buttonWithType:UIButtonTypeCustom];
    
    button.buttonDetailText = detailText;
    button.fieldType = fT;
    button.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:16];
    
    switch( button.fieldType ) {
        case TextField:
            [button setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
            [button setTitle:text forState:UIControlStateNormal];
            break;
        case UserPhotoField:
            break;
        case WebviewField:
            if( detailText && [detailText length] > 0 )
                [button setImage:[UIImage imageNamed:@"openPopover.png"] forState:UIControlStateNormal];
            
            break;
        default:
            [button setTitleColor:AppLinkColor forState:UIControlStateNormal];
            [button setTitle:text forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:16];
            break;
    }
              
    [button setTitleColor:[UIColor darkTextColor] forState:UIControlStateHighlighted];
    button.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = UITextAlignmentLeft;
    button.titleLabel.adjustsFontSizeToFitWidth = NO;
    
    [button addTarget:button action:@selector(fieldTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    return button;
}

- (BOOL) isButtonInPopover {
    UIView *v = self;        
    
    while( v ) {
        if (!strcmp(object_getClassName(v), "UIPopoverView"))
            return YES;
        
        v = v.superview;
    }
        
    return NO;
}

- (void) setFieldRecord:(ZKSObject *)record {    
    self.myRecord = record;
    
    NSArray *requiredFields = nil;
    
    if( self.fieldType == UserField || self.fieldType == UserPhotoField )
        requiredFields = [NSArray arrayWithObjects:@"Name", @"Email", @"FullPhotoUrl", nil];
    else if( self.fieldType == RelatedRecordField )
        requiredFields = [NSArray arrayWithObjects:@"Name", nil];
        
    if( record && requiredFields )
        for( NSString *field in requiredFields )
            if( [AccountUtil isEmpty:[record fieldValue:field]] ) {
                [self removeTarget:self action:@selector(fieldTapped:) forControlEvents:UIControlEventTouchUpInside];
                [self setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
                [self setTitleColor:[UIColor darkGrayColor] forState:UIControlStateHighlighted];
                self.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:16];
                
                break;
            }
}

- (NSString *) trimmedDetailText {
    if( [self.buttonDetailText length] > 250 )
        return [[self.buttonDetailText substringToIndex:250] stringByAppendingFormat:@"...\n[%i more characters]",
                [self.buttonDetailText length] - 250];
    
    return self.buttonDetailText;
}

// Capture tapping a field
- (void) fieldTapped:(FieldPopoverButton *)button {    
    UIActionSheet *action = nil;
    UIViewController *popoverContent = nil;
    
    NSString *url = nil;
        
    switch( self.fieldType ) {
        case RelatedRecordField:
            [self walkFlyingWindows];
            
            if( self.flyingWindowController )
                [self.detailViewController tearOffFlyingWindowsStartingWith:self.flyingWindowController inclusive:NO];
            
            [self.detailViewController addFlyingWindow:FlyingWindowRelatedRecordView withArg:self.myRecord];
            
            break;
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
            action = [[[UIActionSheet alloc] initWithTitle:[self trimmedDetailText]
                                                 delegate:self
                                         cancelButtonTitle:( [self isButtonInPopover] ? NSLocalizedString(@"Cancel", nil) : nil )
                                   destructiveButtonTitle:nil
                                        otherButtonTitles:NSLocalizedString(@"Copy", @"Copy"), nil] autorelease];
            
            [action showFromRect:button.frame inView:self.superview animated:YES];
            break;
        case PhoneField:
            action = [[[UIActionSheet alloc] init] autorelease];
            action.delegate = self;
            action.title = self.buttonDetailText;
            
            [action addButtonWithTitle:NSLocalizedString(@"Copy", @"Copy")];
            
            NSString *phone = [button.buttonDetailText stringByReplacingOccurrencesOfString:@" " withString:@""];
            
            url = [NSString stringWithFormat:skypeFormat, phone];
            
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]])
                [action addButtonWithTitle:NSLocalizedString(@"Call with Skype", @"Call with Skype")];
            
            url = [NSString stringWithFormat:facetimeFormat, phone];
            
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]])
                [action addButtonWithTitle:NSLocalizedString(@"Call with FaceTime", @"Call with FaceTime")];
            
            if( [self isButtonInPopover] )
                action.cancelButtonIndex = [action addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
            
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
        case WebviewField:
            popoverContent = [[UIViewController alloc] init];
            UIWebView *wv = [[UIWebView alloc] initWithFrame:CGRectZero];
            wv.delegate = self;
            wv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            wv.scalesPageToFit = NO;
            wv.allowsInlineMediaPlayback = NO;
            wv.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"panelBG.png"]];
            
            NSString *html =  [AccountUtil stringByAppendingSessionIdToImagesInHTMLString:
                                    [AccountUtil stringByDecodingEntities:[NSString stringWithFormat:@"<body style=\"margin: 0; padding: 5; max-width: 600px;\">%@</body>", self.buttonDetailText]]
                                                                                sessionId:[[[AccountUtil sharedAccountUtil] client] sessionId]];
        
            [wv loadHTMLString:html baseURL:nil];
            popoverContent.view = wv;
            [wv release];
            
            self.popoverController = [[[UIPopoverController alloc] initWithContentViewController:popoverContent] autorelease];
            [popoverContent release];
            
            [self.popoverController presentPopoverFromRect:button.frame
                                                    inView:self.superview
                                  permittedArrowDirections:UIPopoverArrowDirectionAny
                                                  animated:YES];            
            
            break;
        case UserField: 
        case UserPhotoField:                   
            popoverContent = [[UIViewController alloc] init];
            popoverContent.view = [self userPopoverView];
            popoverContent.contentSizeForViewInPopover = CGSizeMake( popoverContent.view.frame.size.width, popoverContent.view.frame.size.height );
            popoverContent.title = [myRecord fieldValue:@"Name"];
            
            if ([MFMailComposeViewController canSendMail])
                popoverContent.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] 
                                                                    initWithTitle:NSLocalizedString(@"Email", @"Email action")
                                                                            style:UIBarButtonItemStyleBordered
                                                                            target:self
                                                                            action:@selector(openEmailComposer:)] autorelease];
            
            if( [[AccountUtil sharedAccountUtil] isChatterEnabled] ) {
                NSString *uId = [[[[AccountUtil sharedAccountUtil] client] currentUserInfo] userId];
                NSString *pId = [myRecord fieldValue:@"Id"];
                
                if( uId && pId && ![uId isEqualToString:pId] ) {
                    self.followButton = [FollowButton followButtonWithUserId:uId parentId:pId];
                    self.followButton.delegate = self;
                    
                    popoverContent.navigationItem.rightBarButtonItem = [FollowButton loadingBarButtonItem];
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
            
            [self.followButton performSelector:@selector(loadFollowState) withObject:nil afterDelay:0.5];
            break;
        default: break;
    }
}

// We've clicked a button in this contextual menu
- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {    
    NSString *urlString = nil;
        
    if( buttonIndex == actionSheet.cancelButtonIndex )
        return;
    
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
        NSString *url = [myRecord fieldValue:@"FullPhotoUrl"];
        
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
    if( [myRecord fieldValue:@"Title"] ) {
        UILabel *userTitle = [[UILabel alloc] initWithFrame:CGRectMake( curX, curY, view.frame.size.width - curX - 5, 20)];
        userTitle.text = [myRecord fieldValue:@"Title"];
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
        if( ![myRecord fieldValue:field] || ![fieldNames objectForKey:field] )
            continue;
        
        UILabel *label = [[self class] labelForField:[fieldNames objectForKey:field]];
        [label sizeToFit];
        [label setFrame:CGRectMake( curX, curY, label.frame.size.width, label.frame.size.height )];
        
        curY += label.frame.size.height;
        [view addSubview:label];
        
        enum FieldType ft = TextField;
        
        if( [[NSArray arrayWithObjects:@"Phone", @"MobilePhone", nil] containsObject:field] )
            ft = PhoneField;
        
        NSString *text = [myRecord fieldValue:field];
        
        FieldPopoverButton *valueButton = [FieldPopoverButton buttonWithText:text
                                                                   fieldType:ft
                                                                  detailText:text];
        
        if( ft == TextField )
            [valueButton setTitleColor:[UIColor lightTextColor] forState:UIControlStateNormal];
        
        CGSize s = [text sizeWithFont:valueButton.titleLabel.font
                          constrainedToSize:CGSizeMake( view.frame.size.width - curX - 5, 9999 )
                              lineBreakMode:UILineBreakModeWordWrap];
        [valueButton setFrame:CGRectMake( curX, curY, s.width, s.height )];
        [view addSubview:valueButton];
        
        curY += s.height;
    }
    
    if( userPhoto && curY < userPhoto.size.height + 15 )
        curY = userPhoto.size.height + 15;
    
    if( [[AccountUtil sharedAccountUtil] isChatterEnabled] && curY < 150 )
        curY = 150;
    
    [view setFrame:CGRectMake(0, 0, view.frame.size.width, MIN( curY, 400 ) )];
    [view setContentSize:CGSizeMake( view.frame.size.width, curY + 1 )];
    [view setContentOffset:CGPointZero];
    
    return [view autorelease];
}

- (IBAction) openEmailComposer:(id)sender {
    [self.detailViewController openEmailComposer:( myRecord ? [myRecord fieldValue:@"Email"] : self.buttonDetailText )];
}

#pragma mark - webview delegate

- (void) webViewDidFinishLoad:(UIWebView *)webView {    
    CGSize s = [webView sizeThatFits:CGSizeZero];
        
    if( s.width < 320 ) 
        s.width = 320;
    else if( s.width > 600 ) 
        s.width = 600;
    
    if( s.height < 100 ) 
        s.height = 100;
    else if( s.height > 500 ) 
        s.height = 500;
    
    self.popoverController.popoverContentSize = s;
    
    [self.popoverController presentPopoverFromRect:self.frame
                                            inView:self.superview
                          permittedArrowDirections:UIPopoverArrowDirectionAny 
                                          animated:YES];
}

- (void) webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"failed load");
}

- (BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    // Only load the initial rich text contents
    if( [[[request URL] absoluteString] isEqualToString:@"about:blank"] )
        return YES;
    
    // Otherwise, load the url in a separate webview
    [self.detailViewController addFlyingWindow:FlyingWindowWebView withArg:[[request URL] absoluteString]];
    [self.popoverController dismissPopoverAnimated:YES];
    self.popoverController = nil;
    
    return NO;
}

// a silly little function to determine in which flying window this button appears
- (void) walkFlyingWindows {
    UIView *parent = nil;
    
    if( self.flyingWindowController )
        return;
    
    for( FlyingWindowController *fwc in [self.detailViewController flyingWindows] ) {
        parent = self.superview;
        
        while( parent ) {
            if( [fwc.view isEqual:parent] ) {
                self.flyingWindowController = fwc;
                return;
            }
            
            parent = [parent superview];
        }
    }
}

#pragma mark - follow button delegate

- (void)followButtonDidChangeState:(FollowButton *)followButton toState:(enum FollowButtonState)state isUserAction:(BOOL)isUserAction {
    if( state == FollowLoading )
        [(((UINavigationController *)self.popoverController.contentViewController).visibleViewController).navigationItem setRightBarButtonItem:[FollowButton loadingBarButtonItem] animated:YES];
    else
        [(((UINavigationController *)self.popoverController.contentViewController).visibleViewController).navigationItem setRightBarButtonItem:self.followButton animated:YES];
}

#pragma mark - util

+ (UILabel *) labelForField:(NSString *)field {
    UILabel *label = [[UILabel alloc] init];
    label.text = field;
    label.font = [UIFont boldSystemFontOfSize:18];
    label.textColor = AppSecondaryColor;
    label.backgroundColor = [UIColor clearColor];
    label.shadowColor = [UIColor darkTextColor];
    label.shadowOffset = CGSizeMake(0, 1);
    
    [label sizeToFit];
    
    return [label autorelease];
}

+ (UILabel *) valueForField:(NSString *)value {
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
    [myRecord release];
    [popoverController release];
    [buttonDetailText release];
    [followButton release];
    [super dealloc];
}

@end
