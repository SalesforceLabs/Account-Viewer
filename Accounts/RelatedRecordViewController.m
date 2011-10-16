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

#import "RelatedRecordViewController.h"
#import "DetailViewController.h"
#import "AccountUtil.h"
#import "DSActivityView.h"
#import "FollowButton.h"
#import <QuartzCore/QuartzCore.h>
#import "PRPAlertView.h"
#import "SimpleKeychain.h"
#import "RootViewController.h"

@implementation RelatedRecordViewController

@synthesize fieldScrollView, record, loadingStage, sObjectType, followButton, actionSheet;

- (id) initWithFrame:(CGRect)frame {
    if(( self = [super initWithFrame:frame] )) {
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"panelBG.png"]];
        
        metadataCount = 0;
        
        self.fieldScrollView = [[[UIScrollView alloc] initWithFrame:CGRectMake( 5,
                                                                self.navBar.frame.size.height,
                                                                frame.size.width - 5,
                                                                               frame.size.height - self.navBar.frame.size.height )] autorelease];
        self.fieldScrollView.delegate = self;
        self.fieldScrollView.showsVerticalScrollIndicator = YES;
        self.fieldScrollView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        
        [self.fieldScrollView setContentOffset:CGPointZero animated:NO];
        [self.fieldScrollView setContentSize:CGSizeMake( frame.size.width, self.fieldScrollView.frame.size.height )];
        
        [self.view addSubview:self.fieldScrollView];
    }
    
    return self;
}

- (void) setRelatedRecord:(ZKSObject *)r {
    self.record = r;
        
    UINavigationItem *loading = [[UINavigationItem alloc] initWithTitle:NSLocalizedString(@"Loading...", @"Loading...")];
    loading.hidesBackButton = YES;    
    [self.navBar pushNavigationItem:loading animated:NO];
    [loading release];
        
    [DSBezelActivityView newActivityViewForView:self.view];
    self.loadingStage = LoadParentDescribe;
    self.sObjectType = [[AccountUtil sharedAccountUtil] sObjectFromRecordId:[self.record fieldValue:@"Id"]];
    
    [[AccountUtil sharedAccountUtil] describesObject:self.sObjectType
                                       completeBlock:^(ZKDescribeSObject * sObject) {
                                           [self metadataOperationComplete];
                                       }];
}

- (void) setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    CGSize s = self.fieldScrollView.contentSize;
    s.width = self.fieldScrollView.frame.size.width - 1;
    s.height = MAX( frame.size.height + 1, ((UIView *)[[self.fieldScrollView subviews] objectAtIndex:0]).frame.size.height );
    [self.fieldScrollView setContentSize:s];
}

- (void) metadataOperationComplete {
    NSArray *relatedsObjects = nil;
        
    switch( self.loadingStage ) {
        case LoadParentDescribe:            
            relatedsObjects = [[AccountUtil sharedAccountUtil] relatedsObjectsOnsObject:self.sObjectType];
            
            if( relatedsObjects && [relatedsObjects count] > 0 ) {
                self.loadingStage = LoadRelatedDescribes;
                
                for( NSString *relatedsObject in relatedsObjects )
                    [[AccountUtil sharedAccountUtil] describesObject:relatedsObject
                                                       completeBlock:^(ZKDescribeSObject * sObject) {
                                                           [self metadataOperationComplete];
                                                       }];
            } else                
                [[AccountUtil sharedAccountUtil] describeLayoutForsObject:self.sObjectType
                                                                   completeBlock:^(ZKDescribeLayoutResult * layoutDescribe) {
                                                                       [self loadRecord];
                                                                   }];
            break;
        case LoadRelatedDescribes:
            metadataCount++;
            
            if( metadataCount == [[[AccountUtil sharedAccountUtil] relatedsObjectsOnsObject:self.sObjectType] count] ) {
                metadataCount = 0;                
                [[AccountUtil sharedAccountUtil] describeLayoutForsObject:self.sObjectType
                                                                   completeBlock:^(ZKDescribeLayoutResult * layoutDescribe) {
                                                                       [self loadRecord];
                                                                   }];
            }
            break;
        default: break;
    }
}

- (void) loadRecord {
    NSString *fieldsToQuery = @"";
    
    // Only query the fields that will be displayed in the page layout for this account, given its record type and page layout.
    NSString *layoutId = [[[AccountUtil sharedAccountUtil] layoutForRecord:[self.record fields]] Id];
    
    fieldsToQuery = [[[AccountUtil sharedAccountUtil] fieldListForLayoutId:layoutId] componentsJoinedByString:@","];
    
    // Build and execute the query
    [[AccountUtil sharedAccountUtil] startNetworkAction];
    
    NSString *queryString = [NSString stringWithFormat:@"select %@ from %@ where id='%@' limit 1",
                             fieldsToQuery, 
                             self.sObjectType,
                             [self.record fieldValue:@"Id"]];
    
    NSLog(@"SOQL %@", queryString);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
        ZKQueryResult *qr = nil;
        
        @try {
            qr = [[[AccountUtil sharedAccountUtil] client] query:queryString];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] receivedException:e];
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            [DSBezelActivityView removeViewAnimated:NO];
            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) { 
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            [DSBezelActivityView removeViewAnimated:YES];
            
            if( qr && [qr records] && [[qr records] count] > 0 ) {
                ZKSObject *ob = [[qr records] objectAtIndex:0];
                self.record = ob;
                
                [[AccountUtil sharedAccountUtil] describesObject:[self.record type]
                                                   completeBlock:^(ZKDescribeSObject *desc) {
                                                       NSString *nameField = [[AccountUtil sharedAccountUtil] nameFieldForsObject:self.sObjectType];
                                                       
                                                       UINavigationItem *title = [[[UINavigationItem alloc] initWithTitle:[AccountUtil trimWhiteSpaceFromString:
                                                                                                                           [NSString stringWithFormat:@"%@%@",
                                                                                                                            [desc label],
                                                                                                                            ( [self.record fieldValue:nameField] ? 
                                                                                                                             [NSString stringWithFormat:@" - %@",
                                                                                                                              [self.record fieldValue:nameField]] : @"" )]]] autorelease];
                                                       title.hidesBackButton = YES;
                                                       
                                                       if( [[AccountUtil sharedAccountUtil] isObjectChatterEnabled:self.sObjectType] ) {                                                           
                                                           self.followButton = [FollowButton followButtonWithUserId:[[[[AccountUtil sharedAccountUtil] client] currentUserInfo] userId]
                                                                                                           parentId:[self.record id]];
                                                           self.followButton.delegate = self;
                                                           
                                                           [title setLeftBarButtonItem:[FollowButton loadingBarButtonItem]];
                                                       }
                                                       
                                                       title.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                                                                 target:self
                                                                                                                                 action:@selector(tappedActionButton:)] autorelease];
                                                       
                                                       [self.navBar pushNavigationItem:title animated:YES];
                                                       
                                                       [self.followButton performSelector:@selector(loadFollowState) withObject:nil afterDelay:0.5];
                                                       
                                                       UIView *recordView = [[AccountUtil sharedAccountUtil] layoutViewForsObject:ob withTarget:self.detailViewController singleColumn:NO];
                                                       
                                                       CGRect r = recordView.frame;
                                                       r.size.width = self.view.frame.size.width;
                                                       [recordView setFrame:r];
                                                       
                                                       [self.fieldScrollView addSubview:recordView];
                                                       [self.fieldScrollView setContentOffset:CGPointZero animated:NO];
                                                       [self.fieldScrollView setContentSize:CGSizeMake( self.fieldScrollView.frame.size.width, 
                                                                                                       MAX( self.fieldScrollView.frame.size.height + 1, recordView.frame.size.height ))]; 
                                                   }];
            } else {
                // failed to load this record for some reason
                [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", nil)
                                    message:NSLocalizedString(@"Unable to load this record.", )
                                cancelTitle:nil
                                cancelBlock:nil 
                                 otherTitle:NSLocalizedString(@"OK", nil) 
                                 otherBlock:^(void) {
                                     [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:YES];
                                 }];
            }
        });
    });    
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self flyingWindowDidTap:nil];
}

- (void) dealloc {
    [record release];
    [fieldScrollView release];
    [sObjectType release];
    [followButton release];
    [actionSheet release];
    [super dealloc];
}

#pragma mark - action sheet

- (void) tappedActionButton:(id)sender {
    if( self.actionSheet ) {
        [self.actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
        self.actionSheet = nil;
        return;
    }
    
    self.actionSheet = [[[UIActionSheet alloc] initWithTitle:nil
                                                    delegate:self
                                           cancelButtonTitle:nil
                                      destructiveButtonTitle:nil
                                           otherButtonTitles:NSLocalizedString(@"Copy Link", nil), nil] autorelease];
    
    [self.actionSheet showFromBarButtonItem:sender animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if( buttonIndex == 0 ) {
        NSString *link = [NSString stringWithFormat:@"%@/%@",
                          [SimpleKeychain load:instanceURLKey],
                          [self.record id]];
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = link;
    }
    
    self.actionSheet = nil;
}

#pragma mark - follow button delegate 

- (void)followButtonDidChangeState:(FollowButton *)followButton toState:(enum FollowButtonState)state isUserAction:(BOOL)isUserAction {
    if( state == FollowLoading )
        [self.navBar.topItem setLeftBarButtonItem:[FollowButton loadingBarButtonItem] animated:YES];
    else
        [self.navBar.topItem setLeftBarButtonItem:self.followButton animated:YES];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

@end
