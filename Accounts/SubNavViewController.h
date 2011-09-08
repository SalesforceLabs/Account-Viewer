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

#import <UIKit/UIKit.h>
#import "zkSforce.h"
#import "AccountAddEditController.h"

@class DetailViewController;
@class RootViewController;

@interface SubNavViewController : UIViewController <UISearchBarDelegate, UITextFieldDelegate, AccountAddEditControllerDelegate, UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate> {
    BOOL searching;
    BOOL letUserSelectRow;
    BOOL helperViewVisible;
    int storedSize;
}

enum SubNavTableType {
    SubNavOwnedAccounts = 0,
    SubNavFollowedAccounts,
    SubNavLocalAccounts,
    SubNavTableNumTypes
};

@property enum SubNavTableType subNavTableType;

@property (nonatomic, retain) UITableViewController *pullRefreshTableViewController;
@property (nonatomic, retain) UISearchBar *searchBar;
@property (nonatomic, retain) NSDictionary *searchResults;
@property (nonatomic, retain) NSMutableDictionary *myRecords;
@property (nonatomic, retain) UINavigationBar *navigationBar;
@property (nonatomic, retain) UIActionSheet *listActionSheet;
@property (nonatomic, retain) UILabel *rowCountLabel;
@property (nonatomic, retain) UIToolbar *bottomBar;

@property (nonatomic, assign) UIButton *titleButton;
@property (nonatomic, assign) DetailViewController *detailViewController;
@property (nonatomic, assign) RootViewController *rootViewController;

- (id) initWithTableType:(enum SubNavTableType) tableType;

- (void) toggleHelperView;

- (NSString *) whichList;
- (NSString *) listTitleForTableType:(enum SubNavTableType)tableType withArrow:(BOOL)withArrow;

- (void) refresh;
- (void) refresh:(BOOL)resetRefresh;
- (void) refreshResult:(NSArray *)results;
- (void) setupNavBar;

- (void) cancelSearch;
- (void) searchTableView;
- (void) handleInterfaceRotation:(BOOL) isPortrait;

- (void) toggleEditMode;
- (void) deleteAllAccounts;
- (void) newAccount;

- (void) selectAccountWithId:(NSString *)accountId;

- (IBAction) showSettings:(id)sender;
- (IBAction) showListActions:(id)sender;
- (IBAction) tappedLogo:(id)sender;

@end

// http://stackoverflow.com/questions/2315862/iphone-sdk-make-uinavigationbar-transparent
@interface TransparentNavigationBar : UINavigationBar
@end

@interface TransparentToolBar : UIToolbar
@end
