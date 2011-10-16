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
#import "zkSforce.h"
#import <MapKit/MapKit.h>

@interface AccountUtil : NSObject {
    NSMutableDictionary *describeCache;
    NSMutableDictionary *layoutCache;
    NSMutableDictionary *geoLocationCache;
    NSMutableDictionary *userPhotoCache;
    NSUInteger *activityCount;
    NSMutableDictionary *globalDescribeObjects;
}

+ (AccountUtil *)sharedAccountUtil;

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]
#define RGB(r, g, b) [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1]
#define RGBA(r, g, b, a) [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a]

#define AppPrimaryColor UIColorFromRGB(0x222222)
#define AppSecondaryColor UIColorFromRGB(0x1797C0)
#define AppLinkColor UIColorFromRGB(0x1679c9)
#define AppTextCellColor RGB( 57.0f, 85.0f, 135.0f )

// Vertical space between a section header and the fields in that section
#define SECTIONSPACING 10

// Vertical space between field rows within a section
#define FIELDSPACING 5

// Standard width of a field label
#define FIELDLABELWIDTH 140

// Standard width of a field value
#define FIELDVALUEWIDTH 200

// Maximum height for a field value
#define FIELDVALUEHEIGHT 9999

// Maximum character length of a soql query
#define SOQLMAXLENGTH 10000

@property (nonatomic, assign) ZKSforceClient *client;

+ (NSString *) appFullName;
+ (NSString *) appVersion;

+ (BOOL) isConnected;

- (void) emptyCaches:(BOOL)emptyAll;
- (NSArray *) coordinatesFromCache:(NSString *)accountId;
- (void) addCoordinatesToCache:(CLLocationCoordinate2D)coordinates accountId:(NSString *)accountId;
- (UIImage *) userPhotoFromCache:(NSString *)photoURL;
- (void) addUserPhotoToCache:(UIImage *)photo forURL:(NSString *)photoURL;

+ (NSString *) addressForsObject:(NSDictionary *)sObject useBillingAddress:(BOOL)useBillingAddress;
+ (NSString *) cityStateForsObject:(NSDictionary *)sObject;

// Database access
+ (void) upsertAccount:(NSDictionary *)fieldSet;
+ (BOOL) deleteAccount:(NSString *)accountId;
+ (void) deleteAllAccounts;
+ (NSDictionary *) getAccount:(NSString *)accountId;
+ (NSDictionary *) getAllAccounts;
+ (NSNumber *) getNextAccountId;

// Followed accounts
- (void) refreshFollowedAccounts;
- (NSArray *) getFollowedAccounts;


// determine if this org is chatter enabled by the presence (or absence) of at one feed-enabled object
- (BOOL) isChatterEnabled;
- (BOOL) isObjectChatterEnabled:(NSString *)object;
- (BOOL) isObjectRecordTypeEnabled:(NSString *)object;

// Creating a page layout for an Account
- (NSString *)textValueForField:(NSString *)fieldName withDictionary:(NSDictionary *)sObject;
- (NSString *)textValueForField:(NSString *)fieldName withSObject:(ZKSObject *)sObject fDescribe:(ZKDescribeField *)fDescribe;
+ (UIView *) createViewForSection:(NSString *)section;
- (UIView *) createViewForField:(NSString *)field withLabel:(NSString *)label withDictionary:(NSDictionary *)dict withTarget:(id)target;
- (UIView *) layoutViewForLocalRecord:(NSDictionary *)record withTarget:(id)target;
- (UIView *) layoutViewForsObject:(ZKSObject *)sObject withTarget:(id)target singleColumn:(BOOL)singleColumn;

// Describe sObjects
- (void) describeGlobal:(void (^)(void))completeBlock;
- (ZKDescribeGlobalSObject *) describeGlobalsObject:(NSString *)sObject;
- (void) describesObject:(NSString *)sObject completeBlock:(void (^)(ZKDescribeSObject * sObjectDescribe))completeBlock;
- (ZKDescribeField *) describeForField:(NSString *)field sObject:(NSString *)sObject;
- (NSString *) sObjectFromLayoutId:(NSString *)layoutId;
- (NSString *) sObjectFromRecordTypeId:(NSString *)recordTypeId;
- (NSString *) sObjectFromRecordId:(NSString *)recordId;
- (NSString *) nameFieldForsObject:(NSString *)sObject;
- (NSArray *) relatedsObjectsOnsObject:(NSString *)sObject;
- (ZKDescribeSObject *) describeSObjectFromCache:(NSString *)sObject;

// Describe sObject layouts  
- (void) describeLayoutForsObject:(NSString *)sObject completeBlock:(void (^)(ZKDescribeLayoutResult * layoutDescribe))completeBlock;
- (ZKDescribeLayout *) layoutForRecord:(NSDictionary *)record;
- (ZKDescribeLayout *) layoutWithLayoutId:(NSString *)layoutId;
- (NSArray *) fieldListForLayoutId:(NSString *)layoutId;

// Running user info
- (void) loadUserInfo;
- (void) userInfoResult:(ZKQueryResult *)results error:(NSError *)error context:(id)context;

// Misc utility functions
+ (NSString *) truncateURL:(NSString *)url;
+ (NSString *) trimWhiteSpaceFromString:(NSString *)source;
+ (BOOL) isEmpty:(id) thing;
+ (NSArray *) randomSubsetFromArray:(NSArray *)original ofSize:(int) size;
+ (NSDictionary *) dictionaryFromAccountArray:(NSArray *)results;
+ (NSDictionary *) accountFromIndexPath:(NSIndexPath *)ip accountDictionary:(NSDictionary *)allAccounts;
+ (NSIndexPath *) indexPathForAccountDictionary:(NSDictionary *)account allAccountDictionary:(NSDictionary *)allAccounts;
+ (NSDictionary *) dictionaryByAddingAccounts:(NSArray *)accounts toDictionary:(NSDictionary *)allAccounts;
+ (NSString *) SOQLDatetimeFromDate:(NSDate *)date;
+ (NSDate *) dateFromSOQLDatetime:(NSString *)datetime;
+ (NSArray *) filterRecords:(NSArray *)records dateField:(NSString *)dateField withDate:(NSDate *)date createdAfter:(BOOL)createdAfter;

+ (NSString *) getIPAddress;
+ (NSString *) stripHTMLTags:(NSString *)str;
+ (NSString *) stringByDecodingEntities:(NSString *)str;

// given an arbitrary HTML string from a rich text field, we scan for any SFDC-stored images
// contained therein and append a session ID to their URLs so they can be loaded
// in a webview
+ (NSString *) stringByAppendingSessionIdToImagesInHTMLString:(NSString *)htmlstring sessionId:(NSString *)sessionId;

void addRoundedRectToPath(CGContextRef context, CGRect rect, float ovalWidth, float ovalHeight);
+ (UIImage *) roundCornersOfImage:(UIImage *)source roundRadius:(int)roundRadius;
+ (UIImage *) resizeImage:(UIImage *)image toSize:(CGSize) newSize;

- (void) startNetworkAction;
- (void) endNetworkAction;
- (void) receivedException:(NSException *)e;
- (void) receivedAPIError:(NSError *)error;
- (void) internalError:(NSError *)error;
+ (NSString *) relativeTime:(NSDate *)sinceDate;
+ (NSArray *) sortArray:(NSArray *) toSort;

@end
