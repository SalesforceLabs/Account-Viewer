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
#import "DetailViewController.h"
#import "RootViewController.h"
#import "CommButton.h"

@implementation CommButton

@synthesize actionSheet, commType, detailViewController;

static NSString *facetimeFormat = @"facetime://%@";
static NSString *skypeFormat = @"skype://%@?call";

+ (id) commButtonWithType:(enum CommType)type withRecord:(NSDictionary *)record {
    CommButton *button = [self buttonWithType:UIButtonTypeCustom];
    
    button.commType = type;
    [button addTarget:button action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // Button image
    switch( type ) {
        case CommWeb:
            [button setImage:[UIImage imageNamed:@"websiteButton.png"] forState:UIControlStateNormal];
            break;
        case CommEmail:
            [button setImage:[UIImage imageNamed:@"emailButton.png"] forState:UIControlStateNormal];
            break;
        case CommSkype:
            [button setImage:[UIImage imageNamed:@"skypeButton.png"] forState:UIControlStateNormal];
            break;
        case CommFacetime:
            [button setImage:[UIImage imageNamed:@"facetimeButton.png"] forState:UIControlStateNormal];
            break;
        default:
            NSLog(@"unexpected button type in CommButton.");
            return nil;
    }
    
    // Build our action sheet with eligible fields of the right type
    button.actionSheet = [[[UIActionSheet alloc] init] autorelease];
    button.actionSheet.delegate = button;
    button.actionSheet.title = nil;
    
    NSArray *callFields = [NSArray arrayWithObjects:@"Phone", @"Fax", @"MobilePhone", nil];
    NSArray *emailFields = [NSArray arrayWithObjects:@"Email", nil];
    NSArray *webFields = [NSArray arrayWithObjects:@"Website", nil];
    ZKDescribeSObject *desc = [[AccountUtil sharedAccountUtil] getAccountDescribe];
    ZKDescribeField *fDesc = nil;
    NSString *fValue = nil;
    
    for( NSString *field in [record allKeys] ) {
        if( desc )
            fDesc = [desc fieldWithName:field];
        
        fValue = [record objectForKey:field];
        
        if( [AccountUtil isEmpty:fValue] )
            continue;
        
        switch( type ) {
            case CommSkype:
                if( [callFields containsObject:field] ||
                   ( fDesc && [[fDesc type] isEqualToString:@"phone"] ) )
                    [button.actionSheet addButtonWithTitle:[record objectForKey:field]];
                break;
            case CommEmail:
                if( [emailFields containsObject:field] || 
                   ( fDesc && [[fDesc type] isEqualToString:@"email"] ) )
                    [button.actionSheet addButtonWithTitle:[record objectForKey:field]];
                break;
            case CommFacetime:
                if( [callFields containsObject:field] || 
                    [emailFields containsObject:field] ||
                   ( fDesc && [[fDesc type] isEqualToString:@"phone"] || [[fDesc type] isEqualToString:@"email"] ) )
                    [button.actionSheet addButtonWithTitle:[record objectForKey:field]];
                break;                    
            case CommWeb:
                if( [webFields containsObject:field] || 
                    ( fDesc && [[fDesc type] isEqualToString:@"url"] ) )
                    [button.actionSheet addButtonWithTitle:[AccountUtil truncateURL:[record objectForKey:field]]];
            default:
                break;
        }
    }
    
    // Did we actually add any buttons to this action sheet?
    if( [AccountUtil isEmpty:[button.actionSheet buttonTitleAtIndex:0]] ) {
        button = nil;
        return nil;
    }
    
    return button;
}

+ (BOOL) supportsButtonOfType:(enum CommType)type {
    NSString *url = nil;
    
    switch( type ) {
        case CommEmail:
        case CommWeb:
            return YES;
            break;
        case CommSkype:
            url = [NSString stringWithFormat:skypeFormat, @"4155551212"];
            break;
        case CommFacetime:
            url = [NSString stringWithFormat:facetimeFormat, @"4155551212"];
            break;
        default:
            return NO;
    }
    
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]];
}

- (void) buttonTapped:(id)button {
    if( self.actionSheet && [self.actionSheet isVisible] ) {
        [self.actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
        return;
    }
    
    [actionSheet showFromRect:self.frame inView:self.superview animated:YES];
}

- (void) actionSheet:(UIActionSheet *)as clickedButtonAtIndex:(NSInteger)buttonIndex { 
    if( buttonIndex < 0 )
        return;
    
    NSString *value = [as buttonTitleAtIndex:buttonIndex];
    NSString *url = nil;
    
    value = [value stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    switch( self.commType ) {
        case CommSkype:
            url = [NSString stringWithFormat:skypeFormat, value];
            break;
        case CommFacetime:
            url = [NSString stringWithFormat:facetimeFormat, value];
            break;
        case CommWeb:
        case CommEmail:
            url = value;
            break;
        default:
            break;
    }
    
    if( self.commType == CommWeb )
        [self.detailViewController addFlyingWindow:FlyingWindowWebView withArg:url];
    else if( self.commType == CommEmail )
        [self.detailViewController openEmailComposer:url];
    else
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

- (void)dealloc {
    [actionSheet release];
    [super dealloc];
}

@end
