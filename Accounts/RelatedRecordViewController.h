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

#import <UIKit/UIKit.h>
#import "FlyingWindowController.h"
#import "zkSforce.h"
#import "FollowButton.h"

@interface RelatedRecordViewController : FlyingWindowController <UIScrollViewDelegate, FollowButtonDelegate, UIActionSheetDelegate> {
    int metadataCount;
}

// The stages of loading a related record.
// 1. Describe the sObject we are loading
// 2. Describe all sObjects related to this object, so we can properly display lookup fields and assemble the query
// 3. Load the layout for this sObject
enum RecordLoadingStages {
    LoadParentDescribe = 0,
    LoadRelatedDescribes,
};

@property (nonatomic, retain) UIScrollView *fieldScrollView;
@property (nonatomic, retain) ZKSObject *record;
@property (nonatomic, retain) NSString *sObjectType;
@property (nonatomic, retain) FollowButton *followButton;
@property (nonatomic, retain) UIActionSheet *actionSheet;

@property enum RecordLoadingStages loadingStage;

- (void) setRelatedRecord:(ZKSObject *)r;
- (void) loadRecord;
- (void) metadataOperationComplete;
- (void) tappedActionButton:(id)sender;

@end
