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
#import "SynthesizeSingleton.h"
#import "zkSforce.h"
#import "zkParser.h"
#import "PRPAlertView.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#import "PRPConnection.h"
#import "SimpleKeychain.h"
#import "FieldPopoverButton.h"
#import "RootViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "FieldWebview.h"

@implementation AccountUtil

SYNTHESIZE_SINGLETON_FOR_CLASS(AccountUtil);

#define LOADVIEWBOXSIZE 100
#define LOADINGVIEWTAG -11

// Keys for things being stored in the Keychain
static NSString *NextAccountID = @"NextAccountId";

// Keys for things we're saving in NSUserDefaults or keychain
static NSString *DBName = @"accountDB";
static NSString *FollowedAccounts = @"FollowedAccounts";

BOOL chatterEnabled = NO;

@synthesize client;

+ (NSString *) appFullName {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
}

+ (NSString *) appVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
}

#pragma mark - caching functions

- (void) emptyCaches:(BOOL)emptyAll {
    [SimpleKeychain delete:FollowedAccounts];
    activityCount = 0;
    [geoLocationCache removeAllObjects];
    [userPhotoCache removeAllObjects];
    
    if( emptyAll ) {
        [globalDescribeObjects removeAllObjects];
        [layoutCache removeAllObjects];
        [describeCache removeAllObjects];
    }
}

- (void) addCoordinatesToCache:(CLLocationCoordinate2D)coordinates accountId:(NSString *)accountId {
    if( !geoLocationCache )
        geoLocationCache = [[NSMutableDictionary dictionary] retain];
        
    [geoLocationCache setObject:[NSArray arrayWithObjects:[NSNumber numberWithDouble:coordinates.latitude], [NSNumber numberWithDouble:coordinates.longitude], nil]
                         forKey:accountId];        
}

- (NSArray *)coordinatesFromCache:(NSString *)accountId {
    if( !geoLocationCache )
        geoLocationCache = [[NSMutableDictionary dictionary] retain];
    
    // nil or an array
    return [geoLocationCache objectForKey:accountId];
}

- (void) addUserPhotoToCache:(UIImage *)photo forURL:(NSString *)photoURL {
    if( !userPhotoCache )
        userPhotoCache = [[NSMutableDictionary dictionary] retain];
    
    if( !photo )
        return;
        
    [userPhotoCache setObject:photo forKey:photoURL];
}

- (UIImage *) userPhotoFromCache:(NSString *)photoURL {
    if( !userPhotoCache )
        userPhotoCache = [[NSMutableDictionary dictionary] retain];
    
    return [userPhotoCache objectForKey:photoURL];
}

#pragma mark - rendering an account layout

+ (UIView *)createViewForSection:(NSString *)section {
    UIView *sectionView = [[UIView alloc] init];
    
    UILabel *sectionLabel = [[UILabel alloc] init];
    sectionLabel.backgroundColor = [UIColor clearColor];
    sectionLabel.textColor = [UIColor darkTextColor];
    sectionLabel.text = section;
    sectionLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:20];
    sectionLabel.numberOfLines = 1;
    CGSize s = [sectionLabel.text sizeWithFont:sectionLabel.font];
    [sectionLabel setFrame:CGRectMake( 25, 0, s.width, s.height )];
    
    [sectionView addSubview:sectionLabel];
    [sectionLabel release];    
    
    UIImage *u = [UIImage imageNamed:@"sectionLine.png"];
    
    // Underline to the left of the text
    UIImageView *underlineLeft = [[UIImageView alloc] initWithImage:u];
    [underlineLeft setFrame:CGRectMake(0, s.height + 5, 25, 3)];
    [sectionView addSubview:underlineLeft];
    [underlineLeft release];
    
    // Blue text underline, sized to the section
    UIView *blueBG = [[UIView alloc] initWithFrame:CGRectMake( 25, s.height + 5, s.width, 3 )];
    blueBG.backgroundColor = AppSecondaryColor;
    [sectionView addSubview:blueBG];
    [blueBG release];
    
    // Underline to the right of the text
    UIImageView *underlineRight = [[UIImageView alloc] initWithImage:u];
    [underlineRight setFrame:CGRectMake( 25 + s.width, s.height + 5, 600, 3)];
    [sectionView addSubview:underlineRight];
    [underlineRight release];
    
    [sectionView setFrame:CGRectMake(0, 0, 700, s.height + u.size.height + 5 )];
    
    return [sectionView autorelease];
}

- (UIView *)createViewForField:(NSString *)field withLabel:(NSString *)label withDictionary:(NSDictionary *)dict withTarget:(id)target {    
    UIView *fieldView = [[UIView alloc] init];
        
    // Get the field describe for this field.
    NSString *sObjectName = [self sObjectFromRecordId:[dict objectForKey:@"Id"]];
    ZKDescribeField *desc = [self describeForField:field sObject:sObjectName];
    
    // Label for this field
    UILabel *fieldLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    fieldLabel.textColor = [UIColor lightGrayColor];
    fieldLabel.backgroundColor = [UIColor clearColor];
    fieldLabel.textAlignment = UITextAlignmentRight;
    fieldLabel.text = label;
    fieldLabel.numberOfLines = 0;
    fieldLabel.adjustsFontSizeToFitWidth = NO;
    fieldLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:16];
    
    CGSize s = [fieldLabel.text sizeWithFont:fieldLabel.font
                           constrainedToSize:CGSizeMake( FIELDLABELWIDTH, FIELDVALUEHEIGHT )
                               lineBreakMode:UILineBreakModeWordWrap];
    
    if( s.width < FIELDLABELWIDTH )
        s.width = FIELDLABELWIDTH;
    
    [fieldLabel setFrame:CGRectMake(0, 0, s.width, s.height)];
    
    // Value for this field
    // Get the properly formatted text contents of this field
    NSString *value = [self textValueForField:field withDictionary:dict];
    
    // If this is modified or created by, also add the datetime
    if( [field isEqualToString:@"LastModifiedById"] && ![AccountUtil isEmpty:[dict objectForKey:@"LastModifiedDate"]] )
        value = [value stringByAppendingFormat:@"\n%@", [self textValueForField:@"LastModifiedDate"
                                                                                            withDictionary:dict]];
    
    if( [field isEqualToString:@"CreatedById"] && ![AccountUtil isEmpty:[dict objectForKey:@"CreatedDate"]] )
        value = [value stringByAppendingFormat:@"\n%@", [self textValueForField:@"CreatedDate"
                                                                                            withDictionary:dict]];
        
    enum FieldType f;
    
    if( [[desc type] isEqualToString:@"email"] || [field isEqualToString:@"Email"] )
        f = EmailField;
    else if( [[desc type] isEqualToString:@"url"] || [field isEqualToString:@"Website"] )
        f = URLField;
    else if( [[desc type] isEqualToString:@"reference"] && ![AccountUtil isEmpty:[dict objectForKey:field]] ) {
        ZKDescribeGlobalSObject *ref = [self describeGlobalsObject:[self sObjectFromRecordId:[dict objectForKey:field]]];
        
        if( !ref )
            f = TextField;
        else if( [[ref name] isEqualToString:@"User"] )
            f = UserField;
        else if( [ref queryable] && [ref layoutable] )
            f = RelatedRecordField;
        else
            f = TextField;
    } else if( [field rangeOfString:@"Street"].location != NSNotFound || [field rangeOfString:@"Address"].location != NSNotFound )
        f = AddressField;
    else if( [[desc type] isEqualToString:@"phone"] || [field isEqualToString:@"Phone"] || [field isEqualToString:@"Fax"] )
        f = PhoneField;
    else if( [[desc type] isEqualToString:@"textarea"] && [desc htmlFormatted] ) {
        f = WebviewField;
    } else
        f = TextField;
    
    FieldPopoverButton *fieldValue = [FieldPopoverButton buttonWithText:value fieldType:f detailText:value];
    fieldValue.detailViewController = target;
    [fieldValue setFrame:CGRectMake(10 + fieldLabel.frame.size.width, 0, FIELDVALUEWIDTH, 35)];
    
    UIImage *fieldImage = nil;
    
    // Special handling for certain fields based on their field type.
    if( [[desc type] isEqualToString:@"boolean"] ) {
        if( [value isEqualToString:@"Yes"] )
            fieldImage = [UIImage imageNamed:@"check_yes.png"];
        else
            fieldImage = [UIImage imageNamed:@"check_no.png"];
        
        value = @"";
    } else if( f == UserField && 
              ![AccountUtil  isEmpty:[dict objectForKey:[desc relationshipName]]] &&
              [[dict objectForKey:[desc relationshipName]] isKindOfClass:[ZKSObject class]] ) {
        ZKSObject *user = [dict objectForKey:[desc relationshipName]];        
        [user setFieldValue:[dict objectForKey:field] field:@"Id"];
        [fieldValue setFieldRecord:user];
        
        if( [[AccountUtil sharedAccountUtil] isChatterEnabled] ) {
            NSString *smallDestURL = [[dict objectForKey:[desc relationshipName]] fieldValue:@"SmallPhotoUrl"],
            *fullDestURL = [[dict objectForKey:[desc relationshipName]] fieldValue:@"FullPhotoUrl"];
            
            // Try our userphoto cache first
            if( ![AccountUtil isEmpty:smallDestURL] ) {
                fieldImage = [[AccountUtil sharedAccountUtil] userPhotoFromCache:smallDestURL];
                
                if( !fieldImage ) {
                    NSLog(@"cache miss for smalluserphoto, pulling from %@", smallDestURL);
                    NSString *imageURL = [NSString stringWithFormat:@"%@?oauth_token=%@",
                                          smallDestURL,
                                          [[[AccountUtil sharedAccountUtil] client] sessionId]];
                    
                    if( [imageURL hasPrefix:@"/"] )
                        imageURL = [NSString stringWithFormat:@"%@%@",
                                    [SimpleKeychain load:instanceURLKey],
                                    imageURL];                    
                    
                    NSData* imageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:imageURL]];
                    
                    if( !imageData )
                        fieldImage = [UIImage imageNamed:@"user24.png"];
                    else {
                        fieldImage = [UIImage imageWithData:imageData];
                        
                        [[AccountUtil sharedAccountUtil] addUserPhotoToCache:fieldImage forURL:smallDestURL];
                    }
                    
                    [imageData release];
                }
                
                fieldImage = [AccountUtil resizeImage:fieldImage toSize:CGSizeMake(24, 24)];
                fieldImage = [AccountUtil roundCornersOfImage:fieldImage roundRadius:5];
            }
            
            if( ![AccountUtil isEmpty:fullDestURL] ) {
                UIImage *fullImage = [[AccountUtil sharedAccountUtil] userPhotoFromCache:fullDestURL];
                
                if( !fullImage ) {
                    NSLog(@"cache miss for fulluserphoto, pulling from %@", fullDestURL);
                    NSString *imageURL = [NSString stringWithFormat:@"%@?oauth_token=%@",
                                          fullDestURL,
                                          [[[AccountUtil sharedAccountUtil] client] sessionId]];
                    
                    if( [imageURL hasPrefix:@"/"] )
                        imageURL = [NSString stringWithFormat:@"%@%@",
                                    [SimpleKeychain load:instanceURLKey],
                                    imageURL];
                    
                    NSData* imageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:imageURL]];
                    
                    if( imageData )
                        [[AccountUtil sharedAccountUtil] addUserPhotoToCache:[UIImage imageWithData:imageData] forURL:fullDestURL];
                    
                    [imageData release];
                }
            }
        }
    } else if( f == RelatedRecordField &&
              ![AccountUtil isEmpty:[dict objectForKey:[desc relationshipName]]] ) {
        ZKSObject *record = [dict objectForKey:[desc relationshipName]];        
        [record setFieldValue:[dict objectForKey:field] field:@"Id"];
        [fieldValue setFieldRecord:record];
    }
    
    // If there is an image associated with this field, display it
    if( fieldImage ) {
        // Add the imageview to our view
        UIImageView *photoView = [[UIImageView alloc] initWithImage:fieldImage];
        [photoView setFrame:CGRectMake(fieldValue.frame.origin.x, fieldValue.frame.origin.y + ( fieldImage.size.height > 22 ? -2 : 2 ), fieldImage.size.width, fieldImage.size.height)];
        
        [fieldView addSubview:photoView];
        
        // Shift the text field over
        CGRect rect = fieldValue.frame;
        rect.origin.x += photoView.frame.size.width + 5;
        rect.size.width -= photoView.frame.size.width + 5;
        [fieldValue setFrame:rect];
        [photoView release];
    }
    
    if( fieldValue.imageView.image ) {
        CGRect r = fieldValue.frame;
        r.size = fieldValue.imageView.image.size;
        [fieldValue setFrame:r];
    } else {
        // Resize the value to fit its text
        CGRect frame = [fieldValue frame];
        CGSize size;
        
        if( ![value isEqualToString:@""] )
            size = [fieldValue.titleLabel.text sizeWithFont:fieldValue.titleLabel.font
                                          constrainedToSize:CGSizeMake(FIELDVALUEWIDTH, FIELDVALUEHEIGHT)
                                              lineBreakMode:UILineBreakModeWordWrap];
        else {
            size = CGSizeMake( 10, fieldLabel.frame.size.height );
            fieldValue.hidden = YES;
        }
        
        frame.size = size;
        [fieldValue setFrame:frame];
    }
    
    [fieldView addSubview:fieldLabel];
    [fieldLabel release];
    
    [fieldView addSubview:fieldValue];
    
    CGRect frame = fieldView.frame;
    
    frame.size = CGSizeMake( fieldLabel.frame.size.width + fieldValue.frame.size.width, MAX( fieldLabel.frame.size.height, fieldValue.frame.size.height ) );
    
    [fieldView setFrame:frame];
    
    return [fieldView autorelease];
}

- (UIView *) layoutViewForLocalRecord:(NSDictionary *)record withTarget:(id)target {
    int curY = 5, fieldCount = 0;
    BOOL showEmptyFields = [[NSUserDefaults standardUserDefaults] boolForKey:emptyFieldsKey];
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    
    view.autoresizingMask = UIViewAutoresizingNone;
    view.backgroundColor = [UIColor clearColor];
    
    UIView *sectionHeader = [[self class] createViewForSection:NSLocalizedString(@"Account Information", @"Account information section header")];
    [sectionHeader setFrame:CGRectMake(0, curY, sectionHeader.frame.size.width, sectionHeader.frame.size.height)];
    curY += sectionHeader.frame.size.height + SECTIONSPACING;
    [view addSubview:sectionHeader];  
    
    // Iterate each field in this dictionary and display
    for( NSString *field in [[self class] sortArray:[record allKeys]] ) {
        // If there is no value in this field, we may not show it
        if( !showEmptyFields && [AccountUtil isEmpty:[record objectForKey:field]] )
            continue;
        
        if( [[record objectForKey:field] rangeOfString:@"<img src"].location != NSNotFound || [[record objectForKey:field] rangeOfString:@"<a href"].location != NSNotFound )
            continue;
        
        if( [record objectForKey:@"Street"] && [[NSArray arrayWithObjects:@"City", @"State", @"PostalCode", @"Country", nil] containsObject:field] )
            continue;
        
        if( [record objectForKey:@"BillingStreet"] && [[NSArray arrayWithObjects:@"BillingCity", @"BillingState", @"BillingPostalCode", @"BillingCountry", nil] containsObject:field] )
            continue;
        
        if( [record objectForKey:@"ShippingStreet"] && [[NSArray arrayWithObjects:@"ShippingCity", @"ShippingState", @"ShippingPostalCode", @"ShippingCountry", nil] containsObject:field] )
            continue;
        
        if( [field isEqualToString:@"Id"] || [field hasSuffix:@"Id"] )
            continue;
        
        NSString *label = nil;
        
        if( [field isEqualToString:@"Billing Street"] )
            label = @"Billing Address";
        else if( [field isEqualToString:@"Shipping Street"] )
            label = @"Shipping Address";
        else if( [field isEqualToString:@"Street"] )
            label = @"Address";
        else
            label = field;
        
        UIView *fieldView = [self createViewForField:field 
                                           withLabel:label
                                      withDictionary:record 
                                          withTarget:target];
        
        fieldView.tag = fieldCount;
        
        [fieldView setFrame:CGRectMake( 0, curY, fieldView.frame.size.width, fieldView.frame.size.height)];
        
        curY += fieldView.frame.size.height + FIELDSPACING;
        
        [view addSubview:fieldView];                
        
        fieldCount++;
    }
    
    if( fieldCount == 0 ) {        
        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                            message:NSLocalizedString(@"Failed to load this account.", @"Account query failed")
                        cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                        cancelBlock:nil
                         otherTitle:NSLocalizedString(@"Retry", @"Retry")
                         otherBlock:^(void) {
                             if( [target respondsToSelector:@selector(loadAccount)] )
                                 [target performSelector:@selector(loadAccount)];
                         }];
        [view release];
        return nil;
    }
    
    [view setFrame:CGRectMake(0, 0, 0, curY)];
    
    return [view autorelease];
}

- (UIView *) layoutViewForsObject:(ZKSObject *)sObject withTarget:(id)target singleColumn:(BOOL)singleColumn {
    int curY = 5, fieldCount = 0, sectionCount = 0;
    BOOL showEmptyFields = [[NSUserDefaults standardUserDefaults] boolForKey:emptyFieldsKey];
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    
    view.autoresizingMask = UIViewAutoresizingNone;
    view.backgroundColor = [UIColor clearColor];
    
    // Get the  layout for this object.
    ZKDescribeLayout *layout = [self layoutForRecord:[sObject fields]];
    
    if( !layout )
        return [view autorelease];
    
    NSString *sObjectName = [self sObjectFromRecordId:[sObject id]];
    
    // 1. Loop through all sections in this page layout
    for( ZKDescribeLayoutSection *section in [layout detailLayoutSections] ) {
        if( [section useHeading] ) {
            UIView *sectionHeader = [AccountUtil createViewForSection:[section heading]];
            sectionHeader.tag = sectionCount;
            
            [sectionHeader setFrame:CGRectMake(0, curY, sectionHeader.frame.size.width, sectionHeader.frame.size.height)];
            
            curY += sectionHeader.frame.size.height + SECTIONSPACING;
            
            [view addSubview:sectionHeader];   
        }
        
        int sectionFields = 0;
        
        // 2. Loop through all rows within this section
        for( ZKDescribeLayoutRow *dlr in [section layoutRows]) {
            float rowHeight = 0, curX = 0;
            
            // 3. Each individual item on this row
            for ( ZKDescribeLayoutItem *item in [dlr layoutItems] ) {                
                if( [item placeholder] || [[item layoutComponents] count] == 0 )
                    continue;
                
                ZKDescribeLayoutComponent *f = [[item layoutComponents] objectAtIndex:0];
                
                if( ![[f typeName] isEqualToString:@"Field"] )
                    continue;
                
                NSString *field = [[f value] isEqualToString:@"Salutation"] ? @"Name" : [f value];
                
                // Position this field within our scrollview, alternating left and right sides
                ZKDescribeField *desc = [[AccountUtil sharedAccountUtil] describeForField:field sObject:sObjectName];
                                    
                if( !showEmptyFields && [AccountUtil isEmpty:[sObject fieldValue:field]] )
                    continue;
                
                // If this is a formula field with a hyperlink or an image, skip for now.
                if( [desc calculated] && ![AccountUtil isEmpty:[sObject fieldValue:field]] &&
                   ( [[sObject fieldValue:[f value]] rangeOfString:@"<img src"].location != NSNotFound || 
                    [[sObject fieldValue:[f value]] rangeOfString:@"<a href"].location != NSNotFound ) )
                    continue;
                
                UIView *fieldView = [self createViewForField:field
                                                   withLabel:[item label] 
                                              withDictionary:[sObject fields]
                                                  withTarget:target];
                
                rowHeight = MAX( rowHeight, fieldView.frame.size.height );
                sectionFields++;
                fieldView.tag = fieldCount;
                
                [fieldView setFrame:CGRectMake( curX, curY, fieldView.frame.size.width, fieldView.frame.size.height)];
                
                if( !singleColumn )
                    curX = 345;
                else
                    curY += fieldView.frame.size.height + FIELDSPACING;
                
                [view addSubview:fieldView];                
                
                fieldCount++;
            }
            
            if( !singleColumn )
                curY += rowHeight + FIELDSPACING;
        }
        
        // This is a little janky; we remove the section header view retroactively if there were no fields in it
        if( [section useHeading] && sectionFields == 0 ) {
            UIView *sectionView = [[view subviews] lastObject];
            curY -= sectionView.frame.size.height + SECTIONSPACING;
            [sectionView removeFromSuperview];
            
            continue;
        }
        
        sectionCount++;
        
        curY += SECTIONSPACING;
    }
    
    if( fieldCount == 0 ) {        
        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                            message:NSLocalizedString(@"Failed to load this account.", @"Account query failed")
                        cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                        cancelBlock:nil
                         otherTitle:NSLocalizedString(@"Retry", @"Retry")
                         otherBlock:^(void) {
                             if( [target respondsToSelector:@selector(loadAccount)] )
                                 [target performSelector:@selector(loadAccount)];
                         }];
        [view release];
        return nil;
    }
    
    [view setFrame:CGRectMake(0, 0, 0, curY)];
    
    return [view autorelease];
}

#pragma mark - Account and sObject functions

- (void) refreshFollowedAccounts {
    NSString *qstring = [NSString stringWithFormat:@"select parentid from EntitySubscription where subscriberid='%@' and parent.type='Account' limit 1000",
                         [[[self client] currentUserInfo] userId]];
    ZKQueryResult *qr = nil;
    
    NSLog(@"SOQL %@", qstring);
    
    @try {
        qr = [client query:qstring];    
    } @catch( NSException *e ) {
        [self receivedException:e];
        return;
    }
    
    NSArray *arr = [NSArray array];
    
    if( [qr records] && [[qr records] count] > 0 )
        for( ZKSObject *sub in [qr records] )
            arr = [arr arrayByAddingObject:[sub fieldValue:@"ParentId"]];
        
    [SimpleKeychain save:FollowedAccounts data:arr];
}

- (NSArray *) getFollowedAccounts {
    return [SimpleKeychain load:FollowedAccounts];
}

- (void) describeGlobal:(void (^)(void))completeBlock {
    if( !globalDescribeObjects )
        globalDescribeObjects = [[NSMutableDictionary dictionary] retain];
    else
        [globalDescribeObjects removeAllObjects];
    
    NSLog(@"DESCRIBE GLOBAL SOBJECTS");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {   
        NSArray *describeResults = nil;
        
        @try {
            describeResults = [[[AccountUtil sharedAccountUtil] client] describeGlobal];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] receivedException:e];
            
            completeBlock();
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {         
            if( describeResults && [describeResults count] > 0 )            
                for( ZKDescribeGlobalSObject *ob in describeResults )
                    [globalDescribeObjects setObject:ob forKey:[ob name]];
                
            completeBlock();
        });
    });
}

- (BOOL) isChatterEnabled {
    if( !globalDescribeObjects )
        return NO;
    
    for( ZKDescribeGlobalSObject *ob in [globalDescribeObjects allValues] )
        if( [ob feedEnabled] )
            return YES;
    
    return NO;
}

- (BOOL) isObjectChatterEnabled:(NSString *)object {    
    if( !globalDescribeObjects )
        return NO;
    
    ZKDescribeGlobalSObject *ob = [globalDescribeObjects objectForKey:object];
    
    if( ob && [ob feedEnabled] )
        return YES;
    
    return NO;
}

- (BOOL) isObjectRecordTypeEnabled:(NSString *)object {
    if( !describeCache )
        return NO;
    
    ZKDescribeSObject *desc = [describeCache objectForKey:object];
    
    if( desc && [desc fieldWithName:@"RecordTypeId"] )
        return YES;
    
    return NO;
}

+ (NSString *) cityStateForsObject:(NSDictionary *)sObject {
    NSString *ret = @"";
    
    if( ![self isEmpty:[sObject objectForKey:@"City"]] ) {
        ret = [sObject objectForKey:@"City"];
        
        if( ![self isEmpty:[sObject objectForKey:@"State"]] )
            ret = [ret stringByAppendingFormat:@", %@", [sObject objectForKey:@"State"]];
    } else if( ![self isEmpty:[sObject objectForKey:@"BillingCity"]] ) {
        ret = [sObject objectForKey:@"BillingCity"];
        
        if( ![self isEmpty:[sObject objectForKey:@"BillingState"]] )
            ret = [ret stringByAppendingFormat:@", %@", [sObject objectForKey:@"BillingState"]];
    } else if( ![self isEmpty:[sObject objectForKey:@"ShippingCity"]] ) {
        ret = [sObject objectForKey:@"ShippingCity"];
        
        if( ![self isEmpty:[sObject objectForKey:@"ShippingState"]] )
            ret = [ret stringByAppendingFormat:@", %@", [sObject objectForKey:@"ShippingState"]];
    }
        
    return ret;
}

+ (NSString *) addressForsObject:(NSDictionary *)sObject useBillingAddress:(BOOL)useBillingAddress {
    NSString *addressStr = @"";
    NSString *fieldPrefix = @"";
    
    if( [[sObject allKeys] containsObject:@"Street"] )
        fieldPrefix = @"";
    else if( useBillingAddress )
        fieldPrefix = @"Billing";
    else if( [sObject objectForKey:@"ShippingStreet"] )
        fieldPrefix = @"Shipping";
    else
        fieldPrefix = @"Mailing";
    
    for( NSString *field in [NSArray arrayWithObjects:@"Street", @"City", @"State", @"PostalCode", @"Country", nil] ) {        
        if( ![addressStr isEqualToString:@""] && ( [field isEqualToString:@"City"] || [field isEqualToString:@"Country"] ) )
            addressStr = [addressStr stringByAppendingString:@"\n"];
        else if( ![addressStr isEqualToString:@""] && [field isEqualToString:@"State"] )
            addressStr = [addressStr stringByAppendingString:@", "];
        else if( ![addressStr isEqualToString:@""] && [field isEqualToString:@"PostalCode"] )
            addressStr = [addressStr stringByAppendingString:@" "];
        
        NSString *fname = [fieldPrefix stringByAppendingString:field];
        
        if( ![[self class] isEmpty:[sObject objectForKey:fname]] )
            addressStr = [addressStr stringByAppendingString:[sObject objectForKey:fname]];
    }
         
    return addressStr;
}

- (NSString *)textValueForField:(NSString *)fieldName withDictionary:(NSDictionary *)sObject {
    // Is this a related object? If so, pass the record over directly
    ZKSObject *ob = nil;
    NSString *sObjectName = nil;
    
    if( ![AccountUtil isEmpty:[sObject objectForKey:@"sObjectType"]] )
        sObjectName = [sObject objectForKey:@"sObjectType"];
    else
        sObjectName = [self sObjectFromRecordId:[sObject objectForKey:@"Id"]];
    
    // if this is a field on a related object, parse it out
    if( [fieldName rangeOfString:@"."].location != NSNotFound ) {
        NSArray *bits = [fieldName componentsSeparatedByString:@"."];
        
        ZKSObject *related = [sObject objectForKey:[bits objectAtIndex:0]];
        
        if( !related || [related isMemberOfClass:[NSNull class]] )
            return @"";
        
        return [self textValueForField:[bits objectAtIndex:1] 
                           withSObject:related 
                             fDescribe:[self describeForField:[bits objectAtIndex:1] sObject:[related type]]];
    }
    
    if( !sObjectName )
        sObjectName = @"Account";
    
    ZKDescribeField *fDescribe = [self describeForField:fieldName sObject:sObjectName];
        
    // if it's a reference, pass the related object directly
    if( [[fDescribe type] isEqualToString:@"reference"] ) {   
        id related = [sObject objectForKey:[fDescribe relationshipName]];
                
        // If this lookup field has just a string, it's coming from local database. Otherwise, pass the related object
        if( [related isKindOfClass:[ZKSObject class]] )
            ob = related;
        else if( [related isKindOfClass:[NSNull class]] )
            return @"";
        else
            return [sObject objectForKey:[fDescribe relationshipName]];
    } else {
        ob = [[[ZKSObject alloc] initWithType:sObjectName] autorelease];
        
        for( id key in [sObject allKeys] )
            [ob setFieldValue:[sObject objectForKey:key] field:key];
    }
    
    if( !ob || [ob isMemberOfClass:[NSNull class]] )
        return @"";
    
    return [self textValueForField:fieldName withSObject:ob fDescribe:fDescribe];
}

- (NSString *)textValueForField:(NSString *)fieldName withSObject:(ZKSObject *)sObject fDescribe:(ZKDescribeField *)fDescribe {
    NSString *value = nil;
    NSNumberFormatter *nformatter = [[NSNumberFormatter alloc] init];  
    NSDateFormatter *dformatter = [[NSDateFormatter alloc] init];
    NSNumber *num;
            
    [dformatter setLocale:[NSLocale currentLocale]];
    [nformatter setLocale:[NSLocale currentLocale]];
        
    if( ![[fDescribe type] isEqualToString:@"reference"] && ![sObject fieldValue:fieldName] )
        value = @"";
    else if( [[fDescribe type] isEqualToString:@"currency"] ) {
        [nformatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        
        num = [NSNumber numberWithDouble:[sObject doubleValue:fieldName]];
        value = [nformatter stringFromNumber:num];
    } else if( [[fDescribe type] isEqualToString:@"boolean"] ) {
        if( [sObject boolValue:fieldName] )
            value = @"Yes";
        else
            value = @"No";
    } else if( [[fDescribe type] isEqualToString:@"date"] ) {
        [dformatter setDateStyle:NSDateFormatterShortStyle];
        
        value = [dformatter stringFromDate:[sObject dateValue:fieldName]];
    } else if( [[fDescribe type] isEqualToString:@"datetime"] ) {
        [dformatter setDateStyle:NSDateFormatterShortStyle];
        [dformatter setTimeStyle:NSDateFormatterShortStyle];
                
        value = [dformatter stringFromDate:[sObject dateTimeValue:fieldName]];
    } else if( [[fDescribe type] isEqualToString:@"percent"] ) {
        [nformatter setNumberStyle:NSNumberFormatterPercentStyle];
        
        num = [NSNumber numberWithDouble:( [sObject doubleValue:fieldName] / 100 )];
        value = [nformatter stringFromNumber:num];
    } else if( [[fDescribe type] isEqualToString:@"double"] ) {
        // 'Precision' is the total number of decimal digits (left and right of the decimal)
        // 'Scale' is the number of digits to the right of the decimal
        // No direct means of getting the number of digits to the left of the decimal, so we just subtract them
        [nformatter setNumberStyle:NSNumberFormatterDecimalStyle];
        
        [nformatter setMinimumFractionDigits:[fDescribe scale]];
        [nformatter setMaximumFractionDigits:[fDescribe scale]];
        [nformatter setMaximumIntegerDigits:( [fDescribe precision] - [fDescribe scale] )];
        
        num = [NSNumber numberWithDouble:[sObject doubleValue:fieldName]];
        value = [nformatter stringFromNumber:num];
    } else if( [[fDescribe type] isEqualToString:@"reference"] ) {         
        // Get the name of the related record
        value = [sObject fieldValue:[self nameFieldForsObject:[sObject type]]];
    } else if( [[fDescribe type] isEqualToString:@"url"] ) {
        // make sure this URL has a protocol prefix
        NSString *urlLC = [[sObject fieldValue:fieldName] lowercaseString];
        
        if( ![urlLC hasPrefix:@"http://"] && ![urlLC hasPrefix:@"https://"] )
            value = [NSString stringWithFormat:@"http://%@", [sObject fieldValue:fieldName]];
        else
            value = [sObject fieldValue:fieldName];
    } else
        value = [sObject fieldValue:fieldName];
    
    if( [fieldName isEqualToString:@"Address"] || [fieldName isEqualToString:@"BillingStreet"] || [fieldName isEqualToString:@"ShippingStreet"] || [fieldName isEqualToString:@"Street"] || [fieldName isEqualToString:@"MailingStreet"] )
        value = [[self class] addressForsObject:[sObject fields] useBillingAddress:[fieldName isEqualToString:@"BillingStreet"]];
    
    [nformatter release];
    [dformatter release];
    
    return value;
}

- (ZKDescribeGlobalSObject *) describeGlobalsObject:(NSString *)sObject {
    if( !globalDescribeObjects )
        return nil;
    
    if( [globalDescribeObjects objectForKey:sObject] )
        return [globalDescribeObjects objectForKey:sObject];
    
    return nil;
}

- (void) describeLayoutForsObject:(NSString *)sObject completeBlock:(void (^)(ZKDescribeLayoutResult * layoutDescribe))completeBlock {
    if( !layoutCache )
        layoutCache = [[NSMutableDictionary dictionary] retain];
    
    if( !sObject )
        return;
    
    if( [layoutCache objectForKey:sObject] ) {
        completeBlock([layoutCache objectForKey:sObject]);
        return;
    }
    
    [self startNetworkAction];
    
    NSLog(@"DESCRIBE LAYOUT: %@", sObject);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {   
        ZKDescribeLayoutResult *result = nil;
        
        @try {
            result = [[[AccountUtil sharedAccountUtil] client] describeLayout:sObject recordTypeIds:nil];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] receivedException:e];
            [self endNetworkAction];
            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {         
            [self endNetworkAction];
            
            if( !result )
                return;
            
            [layoutCache setObject:result forKey:sObject];
            
            completeBlock(result);
        });
    });
    
    return;
}

- (NSString *) sObjectFromRecordId:(NSString *)recordId {
    if( !recordId || [recordId length] < 15 )
        return nil; // local record
    
    NSString *prefix = [recordId substringToIndex:3];
    
    for( NSString *sObject in [globalDescribeObjects allKeys] ) {
        ZKDescribeGlobalSObject *ob = [globalDescribeObjects objectForKey:sObject];
        
        if( ob && [ob queryable] && [ob retrieveable] && ![ob deprecatedAndHidden] && [[ob keyPrefix] isEqualToString:prefix] )
            return sObject;
    }
    
    return nil;
}

- (NSString *) sObjectFromLayoutId:(NSString *)layoutId {
    for( NSString *sObject in [layoutCache allKeys] )
        for( ZKDescribeLayout *layout in [[layoutCache objectForKey:sObject] layouts] )
            if( [[layout Id] isEqualToString:layoutId] )
                return sObject;

    return nil;
}

- (NSString *) sObjectFromRecordTypeId:(NSString *)recordTypeId {
    for( NSString *sObject in [layoutCache allKeys] )
        for( ZKRecordTypeMapping *mapping in [[layoutCache objectForKey:sObject] recordTypeMappings] )
            if( [[mapping recordTypeId] isEqualToString:recordTypeId] )
                return sObject;
    
    return nil;
}

- (ZKDescribeLayout *) layoutForRecord:(NSDictionary *)record {
    if( !layoutCache || !record || ![record objectForKey:@"Id"] )
        return nil;
    
    ZKDescribeLayoutResult *result = [layoutCache objectForKey:[self sObjectFromRecordId:[record objectForKey:@"Id"]]];
    NSString *layoutId = nil;
    
    if( result ) {
        // First attempt to pick the proper layout for this record type, if there is a record type
        if( [record objectForKey:@"RecordTypeId"] ) {
            for( ZKRecordTypeMapping *rt in [result recordTypeMappings] )
                if( [rt available] && [[rt recordTypeId] isEqualToString:[record objectForKey:@"RecordTypeId"]] )
                    layoutId = [rt layoutId];
        }
        
        // Next attempt to pick the default layout for this object
        if( !layoutId )
            for( ZKRecordTypeMapping *rt in [result recordTypeMappings] )
                if( [rt defaultRecordTypeMapping] && [rt available] ) {
                    layoutId = [rt layoutId];
                    break;
                }
        
        // If all else fails, just choose the first available layout
        if( !layoutId )
            layoutId = [[[result layouts] objectAtIndex:0] Id];
    }
    
    return [self layoutWithLayoutId:layoutId];
}

- (ZKDescribeLayout *) layoutWithLayoutId:(NSString *)layoutId {
    if( !layoutCache || [layoutCache count] == 0 || !layoutId )
        return nil;
    
    for( ZKDescribeLayoutResult *result in [layoutCache allValues] )
        for( ZKDescribeLayout *layout in [result layouts] )
            if( [[layout Id] isEqualToString:layoutId] )
                return layout;
    
    return nil;
}

- (NSString *)nameFieldForsObject:(NSString *)sObject {
    if( !describeCache || !sObject || ![describeCache objectForKey:sObject] )
        return @"Name";
    
    for( ZKDescribeField *field in [[describeCache objectForKey:sObject] fields] )
        if( [field nameField] || [[[field name] lowercaseString] isEqualToString:@"name"] )
            return [field name];
    
    return @"Name";
}

- (NSArray *) relatedsObjectsOnsObject:(NSString *)sObject {
    NSMutableArray *ret = [NSMutableArray array];
    
    if( !describeCache || !sObject || ![describeCache objectForKey:sObject] )
        return ret;
    
    for( ZKDescribeField *field in [[describeCache objectForKey:sObject] fields] ) {
        // Tasks can be related to basically anything and we don't really need to describe every
        // sObject just to display them
        if( [sObject isEqualToString:@"Task"] &&
            [[NSArray arrayWithObjects:@"WhoId", @"WhatId", nil] containsObject:[field name]] )
            continue;
        
        if( [[field type] isEqualToString:@"reference"] )
            for( NSString *relatedTo in [field referenceTo] )
                [ret addObject:relatedTo];
    }
    
    return [[NSSet setWithArray:ret] allObjects];
}

// Returns a list of field names that appear in a given record layout, for use in constructing a query
- (NSArray *)fieldListForLayoutId:(NSString *)layoutId {
    NSMutableArray *ret = [NSMutableArray arrayWithObject:@"id"];
    
    ZKDescribeLayout *layout = [self layoutWithLayoutId:layoutId];
    NSString *sObject = [self sObjectFromLayoutId:layoutId];
    
    if( !layout ) 
        return ret;
        
    // 1. Loop through all sections in this page layout
    for( ZKDescribeLayoutSection *section in [layout detailLayoutSections] ) {
        
        // 2. Loop through all rows within this section
        for( ZKDescribeLayoutRow *dlr in [section layoutRows]) {
            
            // 3. Each individual item on this row
            for ( ZKDescribeLayoutItem *item in [dlr layoutItems] ) {
                
                // If this item is blank or a placeholder, we ignore it
                if( [item placeholder] )
                    continue;
                
                for( ZKDescribeLayoutComponent *dlc in [item layoutComponents] ) {                    
                    if( ![[dlc typeName] isEqualToString:@"Field"] )
                        continue;
                    
                    NSString *fname = [dlc value];
                    
                    // If this field is a lookup relationship, we will attempt to get the name of the related object in addition to its ID
                    ZKDescribeField *f = [self describeForField:fname sObject:[self sObjectFromLayoutId:layoutId]];
                    
                    if( [f relationshipName] && [[f type] isEqualToString:@"reference"] ) {
                        // Special handling for the 'What' and 'Who' fields on Task, which can refer to just about anything                        
                        if( [[f name] isEqualToString:@"WhatId"] )
                            [ret addObject:@"What.Name"];
                        else if( [[f name] isEqualToString:@"WhoId"] )
                            [ret addObject:@"Who.Name"];
                        else if( [[f referenceTo] count] == 1 && [[f referenceTo] containsObject:@"User"] ) {
                            // Special handling for Task, as it uses the Name field for owner (sigh)
                            if( [sObject isEqualToString:@"Task"] && [[f name] isEqualToString:@"OwnerId"] )
                                [ret addObject:[NSString stringWithFormat:@"%@.%@", [f relationshipName], @"Name"]];
                            else {
                                NSArray *newFields = [NSArray arrayWithObjects:@"name", @"email", @"title", @"phone", @"mobilephone", @"city", @"state", @"department", nil];
                                
                                if( [[AccountUtil sharedAccountUtil] isChatterEnabled] )
                                    newFields = [newFields arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"smallphotourl", @"fullphotourl", @"currentstatus", @"aboutme", nil]];
                                
                                for( NSString *s in newFields ) 
                                    [ret addObject:[NSString stringWithFormat:@"%@.%@", [f relationshipName], s]];
                            }
                        } else
                            for( NSString *refTo in [f referenceTo] ) {
                                [ret addObject:[NSString stringWithFormat:@"%@.%@",
                                                                [f relationshipName],
                                                                [self nameFieldForsObject:refTo]]];
                                
                                if( [self isObjectRecordTypeEnabled:refTo] )
                                    [ret addObject:[NSString stringWithFormat:@"%@.%@",
                                                    [f relationshipName],
                                                    @"RecordTypeId"]];
                            }
                    }
                    
                    [ret addObject:fname];
                }     
            }
        }
    }
    
    // Ensure that header fields are included in the query for accounts
    if( [sObject isEqualToString:@"Account"] ) 
        for( NSString *headerField in [NSArray arrayWithObjects:@"Name", @"Phone", @"Industry", @"Website", nil] ) {
            ZKDescribeField *desc = [[AccountUtil sharedAccountUtil] describeForField:headerField sObject:@"Account"];
            
            // access check for this field. even though it's a standard field, some users may not have access
            if( desc && ![ret containsObject:headerField] )
                [ret addObject:headerField];
        }
    
    // This is a little silly, but page layouts don't seem to include created/modified dates if they also include
    // the created/modified user
    if( [ret containsObject:@"LastModifiedById"] && ![ret containsObject:@"LastModifiedDate"] )
        [ret addObject:@"LastModifiedDate"];
    
    if( [ret containsObject:@"CreatedById"] && ![ret containsObject:@"CreatedDate"] )
        [ret addObject:@"CreatedDate"];
    
    // Also, some page layouts don't include the record name so we must be sure to include it
    if( ![ret containsObject:[self nameFieldForsObject:sObject]] )
        [ret addObject:[self nameFieldForsObject:sObject]];
    
    NSArray *allFields = [[NSSet setWithArray:ret] allObjects];
    [ret removeAllObjects];
    int counter = 0;
    
    for( int x = 0; x < [allFields count]; x++ ) {
        if( counter >= SOQLMAXLENGTH - 50 )
            break;
        
        [ret addObject:[allFields objectAtIndex:x]];
        
        counter += [[allFields objectAtIndex:x] length] + ( counter > 0 ? 1 : 0 );
    }
    
    return ret;
}

- (ZKDescribeSObject *) describeSObjectFromCache:(NSString *)sObject {
    if( !describeCache || ![describeCache objectForKey:sObject] )
        return nil;
    
    return [describeCache objectForKey:sObject];
}

- (void) describesObject:(NSString *)sObject completeBlock:(void (^)(ZKDescribeSObject *))completeBlock {
    if( !describeCache )
        describeCache = [[NSMutableDictionary dictionary] retain];
    
    if( !sObject )
        return;
    
    if( [describeCache objectForKey:sObject] ) {
        completeBlock([describeCache objectForKey:sObject]);
        
        return;
    }
    
    [self startNetworkAction];
    
    NSLog(@"DESCRIBE SOBJECT: %@", sObject);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {   
        ZKDescribeSObject *describe = nil;
        
        @try {
            describe = [[[AccountUtil sharedAccountUtil] client] describeSObject:sObject];
        } @catch( NSException *e ) {
            [[AccountUtil sharedAccountUtil] receivedException:e];
            [self endNetworkAction];
            
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {         
            [self endNetworkAction];
            
            if( describe ) {         
                [describeCache setObject:describe forKey:sObject];
                completeBlock( describe );
            } else
                completeBlock( nil );    
        });
    });
    
    return;
}

- (ZKDescribeField *) describeForField:(NSString *)field sObject:(NSString *)sObject {
    if( !describeCache )
        return nil;
    
    ZKDescribeSObject *describe = [describeCache objectForKey:sObject];
    
    if( describe )
        return [describe fieldWithName:field];
    
    return nil;
}

- (void) loadUserInfo {
    // load details in about the current user
    NSString *queryString = [NSString stringWithFormat:@"select id, smallphotourl, name, email, phone, username from user where id='%@'", 
                             [[client currentUserInfo] userId]];
    
    [self startNetworkAction];
    
    @try {
        ZKQueryResult *result = [client query:queryString];
        
        [self userInfoResult:result error:nil context:nil];
    } @catch( NSException *e ) {
        [self endNetworkAction];
        [self receivedException:e];
    }
}

// Process userPhoto results and save the result as our profile photo
- (void)userInfoResult:(ZKQueryResult *)results error:(NSError *)error context:(id)context {    
    [self endNetworkAction];
    
    UIImage *myPhoto = nil;
    NSString *photoURL = nil;
    
    if( [results.records count] == 0 || error ) {
        myPhoto = [UIImage imageNamed:@"user24.png"];
    } else if( results ) {
        ZKSObject *user = [results.records objectAtIndex:0];
              
        photoURL = [user fieldValue:@"SmallPhotoUrl"];
        
        NSString* imageURL = [NSString stringWithFormat:@"%@?oauth_token=%@", 
                              [user fieldValue:@"SmallPhotoUrl"], 
                              [client sessionId]];
        
        NSLog(@"Loading my own userphoto with URL %@", imageURL);
        
        NSData* imageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:imageURL]];	
        
        if( !imageData )
            myPhoto = [UIImage imageNamed:@"user24.png"];
        else {
            UIImage *photo = [[UIImage alloc] initWithData:imageData];
            
            myPhoto = [[self class] roundCornersOfImage:photo roundRadius:5];
            
            [photo release];
        }
        
        [imageData release];
    }
    
    // Cache it
    [self addUserPhotoToCache:myPhoto forURL:photoURL];
}

#pragma mark - network activity indicator management

- (void) refreshNetworkIndicator {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = activityCount > 0;
}

- (void) startNetworkAction {
    // Start the network activity spinner
    if( !activityCount )
        activityCount = 0;
    
    activityCount++;

    [self refreshNetworkIndicator];
}

- (void) endNetworkAction {
    if( activityCount > 0 )
        activityCount--;
    else
        activityCount = 0;
    
    [self refreshNetworkIndicator];
}

+ (BOOL) isConnected {
    NSURL *url = [NSURL URLWithString:@"http://www.google.com"];
    NSURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSHTTPURLResponse *response = nil;
    [NSURLConnection sendSynchronousRequest:request
                          returningResponse:&response error:NULL];
    return (response != nil);
}

#pragma mark - Error and alert functions

- (void) receivedException:(NSException *)e {
    NSLog(@"*** Exception *** %@", e );
    
    /*[PRPAlertView showWithTitle:@"Error"
                        message:( description ? description : [NSString stringWithFormat:@"%@", e])
                    buttonTitle:@"OK"];*/
}

// Handle displaying an error as a result of an API call to SFDC
- (void) receivedAPIError:(NSError *)error {
    NSLog(@"*** API ERROR *** %@", error);
    
    //[PRPAlertView showWithTitle:@"API Error" message:[error localizedDescription] buttonTitle:@"OK"];
}

// Handle any other kind of internal error and hard crash if necessary
- (void) internalError:(NSError *)error {
    NSLog(@"*** Unresolved error %@, %@", error, [error userInfo]);
}

#pragma mark - Misc utility functions

+ (NSString *) truncateURL:(NSString *)url {
    NSMutableString *ret = [url mutableCopy];
    
    for( NSString *prefix in [NSArray arrayWithObjects:@"http://", @"https://", @"www.", nil] )
        if( [ret hasPrefix:prefix] )
            [ret deleteCharactersInRange:NSMakeRange( 0, [prefix length] )];
    
    if( [ret hasSuffix:@"/"] )
        [ret deleteCharactersInRange:NSMakeRange( [ret length] - 1, 1 )];
    
    return [ret autorelease];
}

+ (NSString *) trimWhiteSpaceFromString:(NSString *)source {
    NSCharacterSet *whitespaces = [NSCharacterSet whitespaceCharacterSet];
    NSPredicate *noEmptyStrings = [NSPredicate predicateWithFormat:@"SELF != ''"];
    
    NSArray *parts = [source componentsSeparatedByCharactersInSet:whitespaces];
    NSArray *filteredArray = [parts filteredArrayUsingPredicate:noEmptyStrings];
    return [filteredArray componentsJoinedByString:@" "];
}

// Takes an array of dictionaries or sobjects and alphabetizes them into a dictionary
// key is the first letter of the account name, value is an array of accounts starting with that letter
// in alphabetical order ascending - assumes results were passed to us in alphabetical order
+ (NSDictionary *) dictionaryFromAccountArray:(NSArray *)results {
    if( !results )
        return nil;
    
    NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
    
    for( id ob in results ) {
        NSDictionary *accountDict;
        
        // Live query?
        if( [ob isMemberOfClass:[ZKSObject class]] )
            accountDict = [ob fields];
        else
            accountDict = ob;
        
        // first char of this account's name
        NSString *index = [[[accountDict objectForKey:@"Name"] substringToIndex:1] uppercaseString];
        
        if( ![[NSCharacterSet letterCharacterSet] characterIsMember:[index characterAtIndex:0]] )
            index = @"#";
        
        // Add this account to the list of accounts at this position
        if( ![ret objectForKey:index] )
            [ret setObject:[NSArray arrayWithObject:accountDict] forKey:index];
        else {
            NSArray *records = [[ret objectForKey:index] arrayByAddingObject:accountDict];
            
            [ret setObject:records forKey:index];
        }
    }
    
    return [ret autorelease];
}

// Given a dictionary defined as in dictionaryFromAccountArray, add some new accounts to it
// while maintaining alphabetical order by name
+ (NSDictionary *) dictionaryByAddingAccounts:(NSArray *)accounts toDictionary:(NSDictionary *)allAccounts {
    NSMutableDictionary *newDictionary = [NSMutableDictionary dictionaryWithDictionary:allAccounts];
    
    if( !accounts || [accounts count] == 0 )
        return newDictionary;
    
    for( id a in accounts ) {
        NSDictionary *newAccount = nil;
        
        if( [a isMemberOfClass:[ZKSObject class]] )
            newAccount = [a fields];
        else
            newAccount = a;
        
        if( [self isEmpty:[newAccount objectForKey:@"Name"]] )
            continue;
        
        NSString *index = [[[newAccount objectForKey:@"Name"] substringToIndex:1] uppercaseString];
        
        if( ![newDictionary objectForKey:index] )
            [newDictionary setObject:[NSArray array] forKey:index];
        
        NSMutableArray *indexAccounts = [NSMutableArray arrayWithArray:[newDictionary objectForKey:index]];
        
        if( [indexAccounts count] == 0 )
            [indexAccounts addObject:newAccount];
        else {
            BOOL added = NO;
            
            for( int x = 0; x < [indexAccounts count]; x++ ) {
                NSDictionary *indexAccount = [indexAccounts objectAtIndex:x];
                
                if( [[newAccount objectForKey:@"Name"] compare:[indexAccount objectForKey:@"Name"]
                                                    options:NSCaseInsensitiveSearch] != NSOrderedDescending ) {
                    [indexAccounts insertObject:newAccount atIndex:x];
                    added = YES;
                    break;
                }
            }
            
            if( !added )
                [indexAccounts addObject:newAccount];
        }
        
        [newDictionary setObject:indexAccounts forKey:index];
    }
    
    return newDictionary;
}

// Given an index path, get an account from a dictionary defined as in dictionaryFromAccountArray
+ (NSDictionary *) accountFromIndexPath:(NSIndexPath *)ip accountDictionary:(NSDictionary *)allAccounts {
    if( !ip || !allAccounts )
        return nil;
    
    NSArray *sortedKeys = [[self class] sortArray:[allAccounts allKeys]];
    NSString *index = [sortedKeys objectAtIndex:[ip section]];
    NSArray *indexedAccounts = [allAccounts objectForKey:index];
    
    return [indexedAccounts objectAtIndex:ip.row];
}

// Given an account, get an index path for it from a dictionary defined as in dictionaryFromAccountArray
+ (NSIndexPath *) indexPathForAccountDictionary:(NSDictionary *)account allAccountDictionary:(NSDictionary *)allAccounts {
    int section = 0, row = 0;
    
    if( !account || !allAccounts )
        return nil;
    
    NSString *index = nil; 
    
    if( ![account objectForKey:@"Name"] )
        index = nil;
    else if( ![[NSCharacterSet letterCharacterSet] characterIsMember:[[account objectForKey:@"Name"] characterAtIndex:0]] )
        index = @"#";
    else
        index = [[[account objectForKey:@"Name"] substringToIndex:1] uppercaseString];
        
    NSArray *keys = [self sortArray:[allAccounts allKeys]];
        
    if( !index ) {
        for( NSString *key in keys ) {
            for( NSDictionary *a in [allAccounts objectForKey:key] ) {                
                if( [[a objectForKey:@"Id"] isEqualToString:[account objectForKey:@"Id"]] )
                    return [NSIndexPath indexPathForRow:row inSection:section];
                else
                    row++;
            }
            
            section++;
            row = 0;
        }
    } else {
        NSArray *accounts = [allAccounts objectForKey:index];
        
        for( NSString *key in keys )
            if( [key isEqualToString:index] )
                break;
            else
                section++;
        
        for( NSDictionary *a in accounts ) {
            if( [[a objectForKey:@"Id"] isEqualToString:[account objectForKey:@"Id"]] )
                return [NSIndexPath indexPathForRow:row inSection:section];
            
            row++;
        }
    }
    
    return nil;    
}

+ (BOOL) isEmpty:(id) thing {
    return thing == nil
    || [thing isKindOfClass:[NSNull class]]
    || [[NSString stringWithFormat:@"%@", thing] isEqualToString:@"<null>"]
    || ([thing respondsToSelector:@selector(length)]
        && [(NSData *)thing length] == 0)
    || ([thing respondsToSelector:@selector(count)]
        && [(NSArray *)thing count] == 0);
}

+ (NSArray *) randomSubsetFromArray:(NSArray *)original ofSize:(int)size {
    NSArray *names = [NSArray array];
    
    if( !original || [original count] == 0 )
        return names;
    
    if( size <= 0 || size >= [original count] )
        return original;
    
    for( int x = 0; x < size; x++ ) {
        int i = arc4random() % [original count];
        
        while( [names containsObject:[original objectAtIndex:i]] )
            i = arc4random() % [original count];
            
        names = [names arrayByAddingObject:[original objectAtIndex:i]];                
    }
    
    return names;
}

+ (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)newSize {
    // resize image
    UIGraphicsBeginImageContext( newSize );
    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

+ (NSString *) SOQLDatetimeFromDate:(NSDate *)date {
    if( !date )
        date = [NSDate dateWithTimeIntervalSinceNow:0];
    
    // 2011-01-24T17:34:14.000Z
    
    NSDateFormatter *dformatter = [[NSDateFormatter alloc] init];
    [dformatter setLocale:[NSLocale currentLocale]];
    [dformatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.000Z'"];
    
    NSString *format = [dformatter stringFromDate:date];
    [dformatter release];
        
    return format;
}

+ (NSDate *) dateFromSOQLDatetime:(NSString *)datetime {
    // 2011-01-24T17:34:14.000Z
    NSDate *date;
    
    if( !datetime )
        return [NSDate dateWithTimeIntervalSinceNow:0];
    
    datetime = [datetime stringByReplacingOccurrencesOfString:@".000Z" withString:@""];
    datetime = [datetime stringByReplacingOccurrencesOfString:@"T" withString:@" "];
    
    NSDateFormatter *dformatter = [[NSDateFormatter alloc] init];
    [dformatter setLocale:[NSLocale currentLocale]];
    [dformatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    date = [dformatter dateFromString:datetime];
    [dformatter release];
    
    return date;
}

+ (NSArray *) filterRecords:(NSArray *)records dateField:(NSString *)dateField withDate:(NSDate *)date createdAfter:(BOOL)createdAfter {
    if( !records || !dateField )
        return nil;
    
    if( !date || [records count] == 0 )
        return records;
    
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[records count]];
    
    for( ZKSObject *record in records ) {
        NSComparisonResult result = [date compare:[AccountUtil dateFromSOQLDatetime:[record fieldValue:dateField]]];
        
        if( createdAfter && result == NSOrderedAscending )
            [ret addObject:record];
        else if( !createdAfter && result == NSOrderedDescending )
            [ret addObject:record];
    }
    
    return ret;
}

// Sort an array alphabetically
+ (NSArray *)sortArray:(NSArray *)toSort {
    return [toSort sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

// Returns a relative amount of time since a date
+ (NSString *)relativeTime:(NSDate *)sinceDate {
    NSDate *now = [NSDate date];
    double d = -1 * [sinceDate timeIntervalSinceDate:now];
    
    if( d < -1 )
        return NSLocalizedString(@"never", @"never relative time");
    else if( d < 2 )
        return NSLocalizedString(@"just now", @"just now relative time");
    else if (d < 60) {
        int diff = round(d);
        return [NSString stringWithFormat:@"%d %@", 
                diff,
                NSLocalizedString(@"seconds ago", @"seconds ago relative time")];
    } else if (d < 3600) {
        int diff = round(d / 60);
        return [NSString stringWithFormat:@"%d %@", 
                diff,
                NSLocalizedString(@"minutes ago", @"minutes ago relative time")];
    } else if (d < 86400) {
        int diff = round(d / 60 / 60);
        return [NSString stringWithFormat:@"%d %@", 
                diff,
                NSLocalizedString(@"hours ago", @"hours ago relative time")];
    } else if (d < 2629743) {
        int diff = round(d / 60 / 60 / 24);
        return [NSString stringWithFormat:@"%d %@", 
                diff,
                NSLocalizedString(@"days ago", @"days ago relative time")];
    } else
        return NSLocalizedString(@"never", @"never relative time");
}

void addRoundedRectToPath(CGContextRef context, CGRect rect, float ovalWidth, float ovalHeight) {
    float fw, fh;
	if (ovalWidth == 0 || ovalHeight == 0) {
		CGContextAddRect(context, rect);
		return;
	}
	CGContextSaveGState(context);
	CGContextTranslateCTM (context, CGRectGetMinX(rect), CGRectGetMinY(rect));
	CGContextScaleCTM (context, ovalWidth, ovalHeight);
	fw = CGRectGetWidth (rect) / ovalWidth;
	fh = CGRectGetHeight (rect) / ovalHeight;
	CGContextMoveToPoint(context, fw, fh/2);
	CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
	CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
	CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
	CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
	CGContextClosePath(context);
	CGContextRestoreGState(context);
}

+ (UIImage *)roundCornersOfImage:(UIImage *)source roundRadius:(int)roundRadius {
	int w = source.size.width;
	int h = source.size.height;
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGImageAlphaPremultipliedFirst);
	
	CGContextBeginPath(context);
	CGRect rect = CGRectMake(0, 0, w, h);
	addRoundedRectToPath(context, rect, roundRadius, roundRadius);
	CGContextClosePath(context);
	CGContextClip(context);
	
	CGContextDrawImage(context, CGRectMake(0, 0, w, h), source.CGImage);
	
	CGImageRef imageMasked = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	CGColorSpaceRelease(colorSpace);
	
	UIImage *img = [UIImage imageWithCGImage:imageMasked];   
    CGImageRelease(imageMasked);
    
    return img;
}

+ (NSString *) stripHTMLTags:(NSString *)str {
    NSMutableString *html = [NSMutableString stringWithCapacity:[str length]];
    
    NSScanner *scanner = [NSScanner scannerWithString:str];
    NSString *tempText = nil;
    
    while (![scanner isAtEnd]) {
        [scanner scanUpToString:@"<" intoString:&tempText];
        
        if (tempText != nil)
            [html appendString:[NSString stringWithFormat:@" %@", tempText]];
        
        [scanner scanUpToString:@">" intoString:NULL];
        
        if (![scanner isAtEnd])
            [scanner setScanLocation:[scanner scanLocation] + 1];
        
        tempText = nil;
    }
        
    return [self trimWhiteSpaceFromString:html];
}

+ (NSString *)stringByDecodingEntities:(NSString *)str {
    NSUInteger myLength = [str length];
    NSUInteger ampIndex = [str rangeOfString:@"&" options:NSLiteralSearch].location;
    
    // Short-circuit if there are no ampersands.
    if (ampIndex == NSNotFound) {
        return str;
    }
    // Make result string with some extra capacity.
    NSMutableString *result = [NSMutableString stringWithCapacity:(myLength * 1.25)];
    
    // First iteration doesn't need to scan to & since we did that already, but for code simplicity's sake we'll do it again with the scanner.
    NSScanner *scanner = [NSScanner scannerWithString:str];
    
    [scanner setCharactersToBeSkipped:nil];
    
    NSCharacterSet *boundaryCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r;"];
    
    do {
        // Scan up to the next entity or the end of the string.
        NSString *nonEntityString;
        if ([scanner scanUpToString:@"&" intoString:&nonEntityString]) {
            [result appendString:nonEntityString];
        }
        if ([scanner isAtEnd]) {
            goto finish;
        }
        // Scan either a HTML or numeric character entity reference.
        if ([scanner scanString:@"&amp;" intoString:NULL])
            [result appendString:@"&"];
        else if ([scanner scanString:@"&apos;" intoString:NULL])
            [result appendString:@"'"];
        else if ([scanner scanString:@"&quot;" intoString:NULL])
            [result appendString:@"\""];
        else if ([scanner scanString:@"&lt;" intoString:NULL])
            [result appendString:@"<"];
        else if ([scanner scanString:@"&gt;" intoString:NULL])
            [result appendString:@">"];
        else if ([scanner scanString:@"&#" intoString:NULL]) {
            BOOL gotNumber;
            unsigned charCode;
            NSString *xForHex = @"";
            
            // Is it hex or decimal?
            if ([scanner scanString:@"x" intoString:&xForHex]) {
                gotNumber = [scanner scanHexInt:&charCode];
            }
            else {
                gotNumber = [scanner scanInt:(int*)&charCode];
            }
            
            if (gotNumber) {
                [result appendFormat:@"%C", charCode];
                
                [scanner scanString:@";" intoString:NULL];
            }
            else {
                NSString *unknownEntity = @"";
                
                [scanner scanUpToCharactersFromSet:boundaryCharacterSet intoString:&unknownEntity];
                
                
                [result appendFormat:@"&#%@%@", xForHex, unknownEntity];
                
                //[scanner scanUpToString:@";" intoString:&unknownEntity];
                //[result appendFormat:@"&#%@%@;", xForHex, unknownEntity];
                NSLog(@"Expected numeric character entity but got &#%@%@;", xForHex, unknownEntity);
                
            }
            
        }
        else {
            NSString *amp;
            
            [scanner scanString:@"&" intoString:&amp];      //an isolated & symbol
            [result appendString:amp];
            
            /*
             NSString *unknownEntity = @"";
             [scanner scanUpToString:@";" intoString:&unknownEntity];
             NSString *semicolon = @"";
             [scanner scanString:@";" intoString:&semicolon];
             [result appendFormat:@"%@%@", unknownEntity, semicolon];
             NSLog(@"Unsupported XML character entity %@%@", unknownEntity, semicolon);
             */
        }
        
    }
    while (![scanner isAtEnd]);
    
finish:
    return result;
}

+ (NSString *) stringByAppendingSessionIdToImagesInHTMLString:(NSString *)htmlstring sessionId:(NSString *)sessionId {
    // Quick exit if there are no images    
    if( [htmlstring rangeOfString:@"<img" options:NSCaseInsensitiveSearch].location == NSNotFound ||
        [htmlstring rangeOfString:@"src=" options:NSCaseInsensitiveSearch].location == NSNotFound )
        return htmlstring;
        
    NSMutableString *result = [NSMutableString string];
    NSScanner *scanner = [NSScanner scannerWithString:htmlstring];
    [scanner setCharactersToBeSkipped:nil];
        
    do {
        NSString *nonEntityString;
        if ([scanner scanUpToString:@"<img" intoString:&nonEntityString]) {
            [result appendString:nonEntityString];
                        
            // Scan to the URL marker
            if([scanner scanUpToString:@"src=\"" intoString:&nonEntityString]) {
                [result appendString:nonEntityString];
                            
                if([scanner scanUpToString:@"\"" intoString:&nonEntityString])
                    [result appendString:nonEntityString];
                                
                NSString *urlstring;
                                
                // insert session ID
                if([scanner scanUpToString:@"\">" intoString:&urlstring] &&
                   [urlstring rangeOfString:@"content.force.com" options:NSCaseInsensitiveSearch].location != NSNotFound )
                    [result appendFormat:@"%@&oauth_token=%@",
                        urlstring, sessionId];
                else if( urlstring )
                    [result appendString:urlstring];   
            }
        }
    } while( ![scanner isAtEnd] );
    
    return result;
}

+ (NSString *)getIPAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL)
        {
            if(temp_addr->ifa_addr->sa_family == AF_INET)
            {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"])
                {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}

#pragma mark - Database access

+ (void) upsertAccount:(NSDictionary *)fieldSet {  
    NSDictionary *d = [SimpleKeychain load:DBName];
    NSMutableDictionary *dict;
    NSString *accountId = [fieldSet objectForKey:@"Id"];
    
    if( !d )
        dict = [[NSMutableDictionary alloc] init];
    else
        dict = [[NSMutableDictionary alloc] initWithDictionary:d];
    
    NSMutableDictionary *newFields = [[NSMutableDictionary alloc] init];
    
    // sanitize. we can only store primitives
    for( NSString *key in [fieldSet allKeys] ) {
        if( [[self class] isEmpty:[fieldSet objectForKey:key]] )
            continue;
        
        id value = [fieldSet objectForKey:key];
        
        if( [value isKindOfClass:[ZKSObject class]] ) 
            [newFields setObject:[value fieldValue:@"Name"] forKey:key];
        else
            [newFields setObject:[NSString stringWithFormat:@"%@",[fieldSet objectForKey:key]] forKey:key];
    }
    
    if( [[self class] isEmpty:accountId] ) {
        int accid = [[[self class] getNextAccountId] intValue];
        
        accountId = [NSString stringWithFormat:@"%i", accid];
        
        [newFields setObject:accountId forKey:@"Id"];
        [SimpleKeychain save:NextAccountID data:[NSNumber numberWithInt:( accid + 1 )]];
    }
    
    NSLog(@"UPSERTING '%@' with ID %@", [newFields objectForKey:@"Name"], [newFields objectForKey:@"Id"]);
            
    [dict setObject:newFields forKey:accountId];
    [newFields release];
    
    [SimpleKeychain save:DBName data:dict];
    [dict release];
}

+ (NSDictionary *) getAccount:(NSString *)accountId {
    NSMutableDictionary *dict = [SimpleKeychain load:DBName];
    
    if( !dict )
        return nil;
    
    return [dict objectForKey:accountId];
}

+ (NSDictionary *) getAllAccounts {
    return [SimpleKeychain load:DBName];
}

+ (void) deleteAllAccounts {
    [SimpleKeychain delete:DBName];
}

+ (BOOL) deleteAccount:(NSString *)accountId {
    NSDictionary *d = [SimpleKeychain load:DBName];
    NSMutableDictionary *dict = nil;
    
    if( !d )
        dict = [[NSMutableDictionary alloc] init];
    else
        dict = [[NSMutableDictionary alloc] initWithDictionary:d];
    
    if( ![dict objectForKey:accountId] ) {
        [dict release];
        return NO;
    }
    
    [dict removeObjectForKey:accountId];
    [SimpleKeychain save:DBName data:dict];
    [dict release];
        
    return YES;
}

+ (NSNumber *) getNextAccountId {
    NSNumber *i = [SimpleKeychain load:NextAccountID];
    
    if( !i )
        i = [NSNumber numberWithInt:0];
    
    return i;        
}

/*
 * unnecessary in a singleton?
- (void) dealloc {
    [accountDescribe release];
    [accountLayout release];
    [geoLocationCache release];
    [userPhotoCache release];
    [super dealloc];
}
 */


@end
