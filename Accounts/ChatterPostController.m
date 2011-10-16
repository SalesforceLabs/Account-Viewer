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

#import "ChatterPostController.h"
#import "AccountUtil.h"
#import "DSActivityView.h"
#import "PRPAlertView.h"

@implementation ChatterPostController

@synthesize postButton, postTable, postDictionary, searchPopover, delegate;

enum PostTableRows {
    PostParent = 0,
    PostLink,
    PostTitle,
    PostBody,
    PostTableNumRows
};

#pragma mark - setup

- (id) initWithPostDictionary:(NSDictionary *)dict {
    if(( self = [super init] )) {
        self.title = NSLocalizedString(@"Share on Chatter", @"Share on Chatter");
        self.contentSizeForViewInPopover = CGSizeMake( 420, 44 * ( PostTableNumRows + 2 ) );
        self.view.backgroundColor = [UIColor whiteColor];
        
        self.postDictionary = [[[NSMutableDictionary alloc] initWithDictionary:dict] autorelease];
        
        self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                               target:self
                                                                                               action:@selector(cancel)] autorelease];
        
        self.postButton = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Post", @"Posting to chatter")
                                                                style:UIBarButtonItemStyleDone
                                                               target:self 
                                                               action:@selector(submitPost)] autorelease];
        
        self.navigationItem.rightBarButtonItem = self.postButton;
        
        self.postButton.enabled = [self canSubmitPost];
        
        self.postTable = [[[UITableView alloc] initWithFrame:CGRectMake( 0, 0, self.contentSizeForViewInPopover.width, self.contentSizeForViewInPopover.height )
                                                       style:UITableViewStylePlain] autorelease];
        self.postTable.dataSource = self;
        self.postTable.delegate = self;
        
        [self.view addSubview:self.postTable];
    }
    
    return self;
}

- (void) updatePostDictionary:(NSDictionary *)dict {
    NSMutableArray *indexesToUpdate = [NSMutableArray array];
    
    for( NSString *key in [dict allKeys] ) {
        if( [key isEqualToString:@"link"] )
            [indexesToUpdate addObject:[NSIndexPath indexPathForRow:PostLink inSection:0]];
        else if( [key isEqualToString:@"title"] )
            [indexesToUpdate addObject:[NSIndexPath indexPathForRow:PostTitle inSection:0]];
        
        [self.postDictionary setObject:[dict objectForKey:key] forKey:key];
    }
    
    if( [indexesToUpdate count] > 0 )
        [self.postTable reloadRowsAtIndexPaths:indexesToUpdate withRowAnimation:UITableViewRowAnimationFade];
    
    self.postButton.enabled = [self canSubmitPost];
}

- (BOOL) canSubmitPost {
    for( NSString *reqField in [NSArray arrayWithObjects:@"link", @"parentId", nil] )
        if( [AccountUtil isEmpty:[self.postDictionary objectForKey:reqField]] )
            return NO;
    
    return YES;
}

- (void)dealloc {
    [postDictionary release];
    [postButton release];
    [postTable release];
    [searchPopover release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    [DSBezelActivityView removeViewAnimated:NO];
    
    if( self.searchPopover ) {
        [self.searchPopover dismissPopoverAnimated:NO];
        self.searchPopover = nil;
    }
}

#pragma mark - text cell response

- (void) textCellValueChanged:(TextCell *)cell {
    NSString *text = [cell getCellText];
    
    switch( cell.tag ) {
        case PostTitle:
            [self.postDictionary setObject:text forKey:@"title"];
            break;
        case PostBody:
            [self.postDictionary setObject:text forKey:@"body"];
            break;
        default: break;
    }
    
    self.postButton.enabled = [self canSubmitPost];
}

#pragma mark - table view setup

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return PostTableNumRows;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TextCell *cell = [TextCell cellForTableView:tableView];
    cell.delegate = self;
    cell.tag = indexPath.row;
    [cell setMaxLabelWidth:90.0f];
    cell.textLabel.textColor = AppSecondaryColor;
    
    switch( indexPath.row ) {
        case PostParent:
            [cell setTextCellType:TextFieldCell];
            cell.textLabel.text = NSLocalizedString(@"Post to", @"Chatter post destination");
            cell.textField.placeholder = NSLocalizedString(@"User, Group, or Account name", @"User, Group, or Account name");
            [cell setCellText:[NSString stringWithFormat:@"%@ (%@)",
                                   [postDictionary objectForKey:@"parentName"],
                                   [postDictionary objectForKey:@"parentType"]]];
            cell.textField.enabled = NO;
            cell.textField.textColor = AppTextCellColor;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            break;
        case PostLink:
            [cell setTextCellType:TextFieldCell];
            cell.textLabel.text = NSLocalizedString(@"Link", @"Link URL");
            [cell setCellText:[postDictionary objectForKey:@"link"]];
            cell.textField.textColor = [UIColor lightGrayColor];
            cell.textField.enabled = NO;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            break;
        case PostTitle:
            [cell setTextCellType:TextFieldCell];
            cell.textField.enabled = YES;
            cell.textField.textColor = AppTextCellColor;
            cell.textLabel.text = NSLocalizedString(@"Title", @"Link Title");
            [cell setCellText:[postDictionary objectForKey:@"title"]];
            cell.validationType = ValidateAlphaNumeric;
            [cell setMaxLength:255];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        case PostBody:
            [cell setTextCellType:TextViewCell];
            cell.textView.textColor = AppTextCellColor;
            cell.validationType = ValidateAlphaNumeric;
            cell.textLabel.text = NSLocalizedString(@"Body", @"Post Body");
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            CGRect r = cell.textView.frame;
            r.size.height = [self tableView:tableView heightForRowAtIndexPath:indexPath];
            [cell.textView setFrame:r];
            [cell.contentView setFrame:cell.textLabel.frame];
            [cell setMaxLength:1000];
            break;
        default: break;
    }
        
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {    
    if( indexPath.row == PostParent ) {
        if( self.searchPopover ) {
            [self.searchPopover dismissPopoverAnimated:YES];
            self.searchPopover = nil;
        }
            
        ObjectLookupController *olc = [[ObjectLookupController alloc] init];        
        olc.delegate = self;
        self.searchPopover = [[[UIPopoverController alloc] initWithContentViewController:olc] autorelease];
        self.searchPopover.delegate = self;
        [olc release];
        
        [self.searchPopover presentPopoverFromRect:[self.postTable rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]]
                                            inView:self.view.superview
                          permittedArrowDirections:UIPopoverArrowDirectionRight
                                          animated:YES];
        [olc.searchBar becomeFirstResponder];
    } else if( indexPath.row == PostLink ) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [((TextCell *)[tableView cellForRowAtIndexPath:indexPath]) becomeFirstResponder];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if( indexPath.row == PostBody )
        return 44 * 3;
    
    return 44;
}

#pragma mark - popover delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    [self.postTable deselectRowAtIndexPath:[self.postTable indexPathForSelectedRow] animated:YES];
}

#pragma mark - lookup delegate

- (void) objectLookupDidSelectRecord:(ObjectLookupController *)objectLookupController record:(ZKSObject *)record {    
    [self.searchPopover dismissPopoverAnimated:YES];
    self.searchPopover = nil;
    
    [postDictionary setObject:[record id] forKey:@"parentId"];
    [postDictionary setObject:[record fieldValue:@"Name"] forKey:@"parentName"];
    
    if( [[record type] isEqualToString:@"CollaborationGroup"] )
        [postDictionary setObject:@"Group" forKey:@"parentType"];
    else
        [postDictionary setObject:[record type] forKey:@"parentType"];
    
    [self.postTable reloadRowsAtIndexPaths:[NSArray arrayWithObjects:[NSIndexPath indexPathForRow:0 inSection:0], nil]
                          withRowAnimation:UITableViewRowAnimationRight];
}

#pragma mark - post and cancel

- (void) cancel {
    if( [self.delegate respondsToSelector:@selector(chatterPostDidDismiss:)] )
        [self.delegate chatterPostDidDismiss:self];
}

- (void) submitPost {     
    // Apply some defaults if our fields are empty
    if( [AccountUtil isEmpty:[postDictionary objectForKey:@"parentId"]] )
        [postDictionary setObject:[[[[AccountUtil sharedAccountUtil] client] currentUserInfo] userId] forKey:@"parentId"];
    
    if( [AccountUtil isEmpty:[postDictionary objectForKey:@"body"]] )
        [postDictionary setObject:NSLocalizedString(@"shared a link.", @"user shared a link.") forKey:@"body"];
    
    ZKSObject *post = [[ZKSObject alloc] initWithType:@"FeedItem"];
    [post setFieldValue:[postDictionary objectForKey:@"parentId"] field:@"parentId"];
    [post setFieldValue:[postDictionary objectForKey:@"body"] field:@"body"];
    [post setFieldValue:[postDictionary objectForKey:@"link"] field:@"linkurl"];
    [post setFieldValue:[postDictionary objectForKey:@"title"] field:@"title"];
    
    [DSBezelActivityView newActivityViewForView:self.view withLabel:NSLocalizedString(@"Posting...",@"Posting...")];
    [[AccountUtil sharedAccountUtil] startNetworkAction];
    self.postButton.enabled = NO;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {   
        NSArray *postResults = nil;
        
        @try {
            postResults = [[[AccountUtil sharedAccountUtil] client] create:[NSArray arrayWithObjects:post, nil]];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            [DSBezelActivityView removeViewAnimated:YES];
            [[AccountUtil sharedAccountUtil] receivedException:e];
            [post release];
            
            if( [self.delegate respondsToSelector:@selector(chatterPostDidFailWithException:exception:)] )
                [self.delegate chatterPostDidFailWithException:self exception:e];
            
            self.postButton.enabled = YES;
            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [DSBezelActivityView removeViewAnimated:YES];
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            
            if( [[postResults objectAtIndex:0] success] ) {
                if( [self.delegate respondsToSelector:@selector(chatterPostDidPost:)] )
                    [self.delegate chatterPostDidPost:self];
            } else {
                if( [self.delegate respondsToSelector:@selector(chatterPostDidFailWithException:exception:)] ) {
                    NSException *e = [NSException exceptionWithName:NSLocalizedString(@"Post Failed", @"Post Failed")
                                                             reason:[[postResults objectAtIndex:0] message]
                                                           userInfo:nil];
                    
                    [self.delegate chatterPostDidFailWithException:self exception:e];
                    
                    self.postButton.enabled = YES;
                }
            }

        });
    });
}

@end
