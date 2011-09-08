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

@implementation AccountUtil

SYNTHESIZE_SINGLETON_FOR_CLASS(AccountUtil);

#define LOADVIEWBOXSIZE 100
#define LOADINGVIEWTAG -11

// Vertical space between a section header and the fields in that section
#define SECTIONSPACING 10

// Vertical space between field rows within a section
#define FIELDSPACING 5

// Standard width of a field label
#define FIELDLABELWIDTH 140

// Standard width of a field value
#define FIELDVALUEWIDTH 190

// Maximum height for a field value
#define FIELDVALUEHEIGHT 999

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

- (void) emptyCaches {
    [geoLocationCache removeAllObjects];
    [userPhotoCache removeAllObjects];
}

- (void) addCoordinatesToCache:(CLLocationCoordinate2D)coordinates accountId:(NSString *)accountId {
    if( !geoLocationCache )
        geoLocationCache = [[NSMutableDictionary alloc] init];
        
    [geoLocationCache setObject:[NSArray arrayWithObjects:[NSNumber numberWithDouble:coordinates.latitude], [NSNumber numberWithDouble:coordinates.longitude], nil]
                         forKey:accountId];        
}

- (NSArray *)coordinatesFromCache:(NSString *)accountId {
    if( !geoLocationCache )
        geoLocationCache = [[NSMutableDictionary alloc] init];
    
    // nil or an array
    return [geoLocationCache objectForKey:accountId];
}

- (void) addUserPhotoToCache:(UIImage *)photo forURL:(NSString *)photoURL {
    if( !userPhotoCache )
        userPhotoCache = [[NSMutableDictionary alloc] init];
    
    if( !photo )
        return;
        
    [userPhotoCache setObject:photo forKey:photoURL];
}

- (UIImage *) userPhotoFromCache:(NSString *)photoURL {
    if( !userPhotoCache )
        userPhotoCache = [[NSMutableDictionary alloc] init];
    
    return [userPhotoCache objectForKey:photoURL];
}

#pragma mark - rendering an account layout

+ (UIView *)createViewForSection:(NSString *)section {
    UIView *sectionView = [[UIView alloc] init];
    
    UILabel *sectionLabel = [[UILabel alloc] init];
    sectionLabel.backgroundColor = [UIColor clearColor];
    sectionLabel.textColor = [UIColor darkTextColor];
    sectionLabel.text = section;
    sectionLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:18];
    sectionLabel.numberOfLines = 1;
    CGSize s = [sectionLabel.text sizeWithFont:sectionLabel.font];
    [sectionLabel setFrame:CGRectMake( 25, 0, s.width, s.height )];
    
    [sectionView addSubview:sectionLabel];
    [sectionLabel release];    
    
    UIImage *u = [UIImage imageNamed:@"sectionHeaderUnderline.png"];
    UIImageView *underline = [[[UIImageView alloc] initWithImage:u] autorelease];
    [underline setFrame:CGRectMake(0, s.height + 5, u.size.width, u.size.height)];
    
    [sectionView addSubview:underline];
    
    [sectionView setFrame:CGRectMake(0, 0, u.size.width, s.height + u.size.height + 5 )];
    
    return [sectionView autorelease];
}

+ (UIView *)createViewForField:(NSString *)field withLabel:(NSString *)label withDictionary:(NSDictionary *)dict withTarget:(id)target {    
    UIView *fieldView = [[UIView alloc] init];
    
    // Get the field describe for this field.
    ZKDescribeField *desc = [[[AccountUtil sharedAccountUtil] getAccountDescribe] fieldWithName:field];
    
    // Label for this field
    UILabel *fieldLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    fieldLabel.textColor = [UIColor lightGrayColor];
    fieldLabel.backgroundColor = [UIColor clearColor];
    fieldLabel.textAlignment = UITextAlignmentRight;
    fieldLabel.text = NSLocalizedString( label, @"localized field label" );
    fieldLabel.numberOfLines = 0;
    fieldLabel.adjustsFontSizeToFitWidth = NO;
    fieldLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:14];
    
    CGSize s = [fieldLabel.text sizeWithFont:fieldLabel.font
                           constrainedToSize:CGSizeMake( FIELDLABELWIDTH, 999 )
                               lineBreakMode:UILineBreakModeWordWrap];
    
    if( s.width < FIELDLABELWIDTH )
        s.width = FIELDLABELWIDTH;
    
    [fieldLabel setFrame:CGRectMake(0, 0, s.width, s.height)];
    
    // Value for this field
    // Get the properly formatted text contents of this field
    NSString *value = [[AccountUtil sharedAccountUtil] textValueForField:field withDictionary:dict];
    
    // If this is modified or created by, also add the datetime
    if( [field isEqualToString:@"LastModifiedById"] && ![AccountUtil isEmpty:[dict objectForKey:@"LastModifiedDate"]] )
        value = [value stringByAppendingFormat:@"\n%@", [[AccountUtil sharedAccountUtil] textValueForField:@"LastModifiedDate"
                                                                                            withDictionary:dict]];
    
    if( [field isEqualToString:@"CreatedById"] && ![AccountUtil isEmpty:[dict objectForKey:@"CreatedDate"]] )
        value = [value stringByAppendingFormat:@"\n%@", [[AccountUtil sharedAccountUtil] textValueForField:@"CreatedDate"
                                                                                            withDictionary:dict]];
    
    enum FieldType f;
    
    if( [[desc type] isEqualToString:@"email"] || [field isEqualToString:@"Email"] )
        f = EmailField;
    else if( [[desc type] isEqualToString:@"url"] || [field isEqualToString:@"Website"] )
        f = URLField;
    else if( [[desc type] isEqualToString:@"reference"] && [[desc referenceTo] containsObject:@"User"] )
        f = UserField;
    else if( [field rangeOfString:@"Street"].location != NSNotFound || [field rangeOfString:@"Address"].location != NSNotFound )
        f = AddressField;
    else if( [[desc type] isEqualToString:@"phone"] || [field isEqualToString:@"Phone"] || [field isEqualToString:@"Fax"] )
        f = PhoneField;
    else
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
        
        value = nil;
    } else if( [[desc type] isEqualToString:@"reference"] && [[desc referenceTo] containsObject:@"User"] && 
              ![AccountUtil  isEmpty:[dict objectForKey:[desc relationshipName]]] &&
              [[dict objectForKey:[desc relationshipName]] isKindOfClass:[ZKSObject class]] ) {
        ZKSObject *user = [dict objectForKey:[desc relationshipName]];        
        [user setFieldValue:[dict objectForKey:field] field:@"Id"];
        [fieldValue setFieldUser:user];
        
        if( [[AccountUtil sharedAccountUtil] isChatterEnabled] ) {
            NSString *smallDestURL = [[dict objectForKey:[desc relationshipName]] fieldValue:@"SmallPhotoUrl"],
            *fullDestURL = [[dict objectForKey:[desc relationshipName]] fieldValue:@"FullPhotoUrl"];
            
            // Try our userphoto cache first
            fieldImage = [[AccountUtil sharedAccountUtil] userPhotoFromCache:smallDestURL];
            UIImage *fullImage = [[AccountUtil sharedAccountUtil] userPhotoFromCache:fullDestURL];
            
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
    
    // Add the label
    [fieldView addSubview:fieldLabel];
    
    // Add the value
    [fieldValue setTitle:value forState:UIControlStateNormal];
    
    // Resize the value to fit its text
    CGRect frame = [fieldValue frame];
    CGSize size;
    
    if( ![value isEqualToString:@""] )
        size = [fieldValue.titleLabel.text sizeWithFont:fieldValue.titleLabel.font
                                      constrainedToSize:CGSizeMake(FIELDVALUEWIDTH, FIELDVALUEHEIGHT)
                                          lineBreakMode:UILineBreakModeWordWrap];
    else
        size = CGSizeMake( 10, fieldLabel.frame.size.height );
    
    frame.size.height = size.height;
    frame.size.width = size.width;
    [fieldValue setFrame:frame];
    
    [fieldView addSubview:fieldValue];
    
    frame = fieldView.frame;
    
    frame.size = CGSizeMake( fieldLabel.frame.size.width + fieldValue.frame.size.width, MAX( fieldLabel.frame.size.height, fieldValue.frame.size.height ) );
    
    [fieldView setFrame:frame];
    
    [fieldLabel release];   
    
    return [fieldView autorelease];
}

+ (UIView *) layoutViewForAccount:(NSDictionary *)account withTarget:(id)target isLocalAccount:(BOOL)isLocalAccount {
    int curY = 5, fieldCount = 0, sectionCount = 0;
    BOOL showEmptyFields = [[NSUserDefaults standardUserDefaults] boolForKey:emptyFieldsKey];
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    
    //[view.layer setMasksToBounds:YES];
    //view.layer.cornerRadius = 8.0f;
    view.autoresizingMask = UIViewAutoresizingNone;
    view.backgroundColor = [UIColor clearColor];
    
    if( isLocalAccount ) {
        UIView *sectionHeader = [[self class] createViewForSection:NSLocalizedString(@"Account Information", @"Account information section header")];
        [sectionHeader setFrame:CGRectMake(0, curY, sectionHeader.frame.size.width, sectionHeader.frame.size.height)];
        curY += sectionHeader.frame.size.height + SECTIONSPACING;
        [view addSubview:sectionHeader];  
        
        // Iterate each field in this dictionary and display
        for( NSString *field in [[self class] sortArray:[account allKeys]] ) {
            // If there is no value in this field, we may not show it
            if( !showEmptyFields && [AccountUtil isEmpty:[account objectForKey:field]] )
                continue;
            
            if( [[account objectForKey:field] rangeOfString:@"<img src"].location != NSNotFound || [[account objectForKey:field] rangeOfString:@"<a href"].location != NSNotFound )
                continue;
            
            if( [account objectForKey:@"Street"] && [[NSArray arrayWithObjects:@"City", @"State", @"PostalCode", @"Country", nil] containsObject:field] )
                continue;
            
            if( [account objectForKey:@"BillingStreet"] && [[NSArray arrayWithObjects:@"BillingCity", @"BillingState", @"BillingPostalCode", @"BillingCountry", nil] containsObject:field] )
                continue;
            
            if( [account objectForKey:@"ShippingStreet"] && [[NSArray arrayWithObjects:@"ShippingCity", @"ShippingState", @"ShippingPostalCode", @"ShippingCountry", nil] containsObject:field] )
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
            
            UIView *fieldView = [AccountUtil createViewForField:field 
                                                      withLabel:label
                                                 withDictionary:account 
                                                     withTarget:target];
            
            fieldView.tag = fieldCount;
            
            [fieldView setFrame:CGRectMake( 0, curY, fieldView.frame.size.width, fieldView.frame.size.height)];
            
            curY += fieldView.frame.size.height + FIELDSPACING;
            
            [view addSubview:fieldView];                
            
            fieldCount++;
        }
    } else {
        // Get the Account layout for this account's record type.
        ZKDescribeLayout *accLayout = [[AccountUtil sharedAccountUtil] layoutForRecordTypeId:[account objectForKey:@"RecordTypeId"]];
        
        // Generate labels and values for all fields on this account
        // and then add them to our field scroll view, tagging each one
        
        // 1. Loop through all sections in this page layout
        for( ZKDescribeLayoutSection *section in [accLayout detailLayoutSections] ) {
            // Add the section to our layout
            
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
                //int rowHeight = 0;
                
                // 3. Each individual item on this row
                for ( ZKDescribeLayoutItem *item in [dlr layoutItems] ) {                
                    if( [item placeholder] || [[item layoutComponents] count] == 0 )
                        continue;
                    
                    ZKDescribeLayoutComponent *f = [[item layoutComponents] objectAtIndex:0];
                    
                    if( ![[f typeName] isEqualToString:@"Field"] )
                        continue;
                    
                    // Position this field within our scrollview, alternating left and right sides
                    //ZKDescribeLayoutComponent *f = [[item layoutComponents] objectAtIndex:0];
                    ZKDescribeField *desc = [[[AccountUtil sharedAccountUtil] getAccountDescribe] fieldWithName:[f value]];
                    
                    if( !showEmptyFields && [AccountUtil isEmpty:[account objectForKey:[f value]]] )
                        continue;
                    
                    // If this is a formula field with a hyperlink or an image, skip for now.
                    // This is a janky hack.
                    if( [desc calculated] && ![AccountUtil isEmpty:[account objectForKey:[f value]]] &&
                       ( [[account objectForKey:[f value]] rangeOfString:@"<img src"].location != NSNotFound || [[account objectForKey:[f value]] rangeOfString:@"<a href"].location != NSNotFound ) )
                        continue;
                    
                    UIView *fieldView = [AccountUtil createViewForField:[f value] 
                                                              withLabel:[item label] 
                                                         withDictionary:account
                                                             withTarget:target];
                    
                    sectionFields++;
                    fieldView.tag = fieldCount;
                    
                    [fieldView setFrame:CGRectMake( 0, curY, fieldView.frame.size.width, fieldView.frame.size.height)];
                    
                    curY += fieldView.frame.size.height + FIELDSPACING;  
                    
                    [view addSubview:fieldView];                
                    
                    fieldCount++;
                }
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

- (void) refreshFollowedAccounts:(NSString *)userId {
    NSString *qstring = [NSString stringWithFormat:@"select parentid from EntitySubscription where subscriberid='%@' and parent.type='Account' limit 1000",
                         userId];
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

- (BOOL) isChatterEnabled {
    return chatterEnabled;
}

- (void) setChatterEnabled:(BOOL) enabled {
    chatterEnabled = enabled;
}

// used to determine if we're in an org that has record types. 
// usually means EE+, or a PE org with the addon
- (BOOL) hasRecordTypes {
    return [[self getAccountDescribe] fieldWithName:@"RecordTypeId"] != nil;
}

+ (NSString *) cityStateForAccount:(NSDictionary *)account {
    NSString *ret = @"";
    
    if( ![self isEmpty:[account objectForKey:@"City"]] ) {
        ret = [account objectForKey:@"City"];
        
        if( ![self isEmpty:[account objectForKey:@"State"]] )
            ret = [ret stringByAppendingFormat:@", %@", [account objectForKey:@"State"]];
    } else if( ![self isEmpty:[account objectForKey:@"BillingCity"]] ) {
        ret = [account objectForKey:@"BillingCity"];
        
        if( ![self isEmpty:[account objectForKey:@"BillingState"]] )
            ret = [ret stringByAppendingFormat:@", %@", [account objectForKey:@"BillingState"]];
    } else if( ![self isEmpty:[account objectForKey:@"ShippingCity"]] ) {
        ret = [account objectForKey:@"ShippingCity"];
        
        if( ![self isEmpty:[account objectForKey:@"ShippingState"]] )
            ret = [ret stringByAppendingFormat:@", %@", [account objectForKey:@"ShippingState"]];
    }
        
    return ret;
}

+ (NSString *) addressForAccount:(NSDictionary *)account useBillingAddress:(BOOL)useBillingAddress {
    NSString *addressStr = @"";
    NSString *fieldPrefix = @"";
    
    if( [[account allKeys] containsObject:@"Street"] )
        fieldPrefix = @"";
    else if( useBillingAddress )
        fieldPrefix = @"Billing";
    else
        fieldPrefix = @"Shipping";
    
    for( NSString *field in [NSArray arrayWithObjects:@"Street", @"City", @"State", @"PostalCode", @"Country", nil] ) {        
        if( ![addressStr isEqualToString:@""] && ( [field isEqualToString:@"City"] || [field isEqualToString:@"Country"] ) )
            addressStr = [addressStr stringByAppendingString:@"\n"];
        else if( ![addressStr isEqualToString:@""] && [field isEqualToString:@"State"] )
            addressStr = [addressStr stringByAppendingString:@", "];
        else if( ![addressStr isEqualToString:@""] && [field isEqualToString:@"PostalCode"] )
            addressStr = [addressStr stringByAppendingString:@" "];
        
        NSString *fname = [fieldPrefix stringByAppendingString:field];
        
        if( ![[self class] isEmpty:[account objectForKey:fname]] )
            addressStr = [addressStr stringByAppendingString:[account objectForKey:fname]];
    }
         
    return addressStr;
}

// Given a field name and an sObject containing that field,
// we parse and format the text in that field for display
- (NSString *)textValueForField:(NSString *)fieldName withDictionary:(NSDictionary *)sObject {
    // Is this a related object? If so, pass the record over directly
    ZKSObject *ob;
    ZKDescribeField *fDescribe = [accountDescribe fieldWithName:fieldName];
    
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
        ob = [[[ZKSObject alloc] initWithType:@"Account"] autorelease];
        
        for( id key in [sObject allKeys] )
            [ob setFieldValue:[sObject objectForKey:key] field:key];
    }
    
    if( !ob || [ob isMemberOfClass:[NSNull class]] )
        return @"";
    
    return [self textValueForField:fieldName withSObject:ob];
}

- (NSString *)textValueForField:(NSString *)fieldName withSObject:(ZKSObject *)sObject {
    NSString *value = nil;
    NSNumberFormatter *nformatter = [[NSNumberFormatter alloc] init];  
    NSDateFormatter *dformatter = [[NSDateFormatter alloc] init];
    NSNumber *num;
    
    ZKDescribeField *fDescribe = [accountDescribe fieldWithName:fieldName];
        
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
        [nformatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [nformatter setMaximumFractionDigits:[fDescribe precision]];
        [nformatter setMaximumIntegerDigits:[fDescribe digits]];
        
        num = [NSNumber numberWithDouble:[sObject doubleValue:fieldName]];
        value = [nformatter stringFromNumber:num];
    } else if( [[fDescribe type] isEqualToString:@"reference"] ) {          
        // Get the name of the related record
        if( [[fDescribe referenceTo] containsObject:@"Case"] )
            value = [sObject fieldValue:@"CaseNumber"];
            //value = [[sObject fieldValue:[fDescribe relationshipName]] fieldValue:@"CaseNumber"];
        else
            value = [sObject fieldValue:@"Name"];
            // value = [[sObject fieldValue:[fDescribe relationshipName]] fieldValue:@"Name"];        
    } else if( [[fDescribe type] isEqualToString:@"url"] ) {
        // make sure this URL has a protocol prefix
        NSString *urlLC = [[sObject fieldValue:fieldName] lowercaseString];
        
        if( ![urlLC hasPrefix:@"http://"] && ![urlLC hasPrefix:@"https://"] )
            value = [NSString stringWithFormat:@"http://%@", [sObject fieldValue:fieldName]];
        else
            value = [sObject fieldValue:fieldName];
    } else
        value = [sObject fieldValue:fieldName];
    
    if( [fieldName isEqualToString:@"Address"] || [fieldName isEqualToString:@"BillingStreet"] || [fieldName isEqualToString:@"ShippingStreet"] || [fieldName isEqualToString:@"Street"] )
        value = [[self class] addressForAccount:[sObject fields] useBillingAddress:[fieldName isEqualToString:@"BillingStreet"]];
    
    [nformatter release];
    [dformatter release];
    
    return value;
}

- (ZKDescribeLayoutResult *) getAccountLayout {
    if( !accountLayout ) {
        [self startNetworkAction];
        
        @try {
            ZKDescribeLayoutResult *layout = [client describeLayout:@"Account" recordTypeIds:nil];
            
            [self describeLayoutResult:layout error:nil context:nil];
        } @catch( NSException *e ) {
            [self endNetworkAction];
            [self receivedException:e];
            return nil;
        }
        
        return nil;
    }
    
    return accountLayout;
}

- (void) describeLayoutResult:(ZKDescribeLayoutResult *)result error:(NSError *)error context:(id)context {
    [self endNetworkAction];
    
    if( error )
        [self receivedAPIError:error];
    else
        accountLayout = [result retain];
}

// Given a record type, return the proper page layout for this record
- (ZKDescribeLayout *)layoutForRecordTypeId:(NSString *)recordTypeId {
    if( !accountLayout || [[accountLayout layouts] count] == 0 )
        return nil;
    
    if( !recordTypeId )
        return [[accountLayout layouts] objectAtIndex:0];
    
    NSString *layoutId = nil;
    
    for( ZKRecordTypeMapping *rt in [accountLayout recordTypeMappings] )
        if( [[rt recordTypeId] isEqualToString:recordTypeId] ) {
            layoutId = [rt layoutId];
            break;
        }
    
    for( ZKDescribeLayout *layout in [accountLayout layouts] )
        if( [[layout Id] isEqualToString:layoutId] )
            return layout;
    
    return [[accountLayout layouts] objectAtIndex:0];
}

// Returns a list of field names that appear in a given record layout, for use in constructing a query
- (NSArray *)fieldListForLayoutId:(NSString *)layoutId {
    NSArray *ret = [NSArray arrayWithObject:@"id"];
    
    ZKDescribeLayout *layout = nil;
    
    for( ZKDescribeLayout *l in [accountLayout layouts] )
        if( [[l Id] isEqualToString:layoutId] ) {
            layout = l;
            break;
        }
    
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
                    ZKDescribeField *f = [accountDescribe fieldWithName:fname];
                    
                    if( [[f type] isEqualToString:@"reference"] ) {
                        // Attempt to get the name of the related object
                        if( [[f referenceTo] containsObject:@"Case"] )
                            ret = [ret arrayByAddingObject:[NSString stringWithFormat:@"%@.casenumber", [f relationshipName]]];
                        else
                            ret = [ret arrayByAddingObject:[NSString stringWithFormat:@"%@.name", [f relationshipName]]];
                        
                        // And if this is a lookup to a user, attempt to get that user's small chatter photo
                        // and a few other fields on them for their user popover
                        if( [[f referenceTo] containsObject:@"User"] ) {
                            NSArray *newFields = [NSArray arrayWithObjects:@"email", @"title", @"phone", @"mobilephone", @"city", @"state", @"department", nil];
                            
                            if( [[AccountUtil sharedAccountUtil] isChatterEnabled] )
                                newFields = [newFields arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"smallphotourl", @"fullphotourl", @"currentstatus", @"aboutme", nil]];
                            
                            for( NSString *s in newFields )
                                ret = [ret arrayByAddingObject:[NSString stringWithFormat:@"%@.%@", [f relationshipName], s]];
                        }
                    }
                    
                    if( ![ret containsObject:fname] )
                        ret = [ret arrayByAddingObject:fname];
                }     
            }
        }
    }
    
    // This is a little silly, but page layouts don't seem to include created/modified dates if they also include
    // the created/modified user
    if( [ret containsObject:@"LastModifiedById"] && ![ret containsObject:@"LastModifiedDate"] )
        ret = [ret arrayByAddingObject:@"LastModifiedDate"];
    
    if( [ret containsObject:@"CreatedById"] && ![ret containsObject:@"CreatedDate"] )
        ret = [ret arrayByAddingObject:@"CreatedDate"];
    
    // Also, some page layouts don't include the record name so we must be sure to include it
    if( ![ret containsObject:@"Name"] )
        ret = [ret arrayByAddingObject:@"Name"];
    
    return ret;
}

- (ZKDescribeSObject *)getAccountDescribe {
    if( !accountDescribe ) {
        [self startNetworkAction];
        
        @try {
            ZKDescribeSObject *describe = [client describeSObject:@"Account"];
                     
            [self describeAccountResult:describe error:nil context:nil];
        } @catch( NSException *e ) {
            [self endNetworkAction];
            [self receivedException:e];
            
            return nil;
        }
    }
    
    return accountDescribe;
}

- (void)describeAccountResult:(ZKDescribeSObject *)result error:(NSError *)error context:(id)context {
    [self endNetworkAction];
    
    if( error )
        [self receivedAPIError:error];
    else if( result )
        accountDescribe = [result retain];
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

// Given an index path, get an account from a dictionary defined as in dictionaryFromAccountArray
+ (NSDictionary *) accountFromIndexPath:(NSIndexPath *)ip accountDictionary:(NSDictionary *)allAccounts {
    if( !ip || !allAccounts )
        return nil;
    
    NSArray *sortedKeys = [[self class] sortArray:[allAccounts allKeys]];
    NSString *index = [sortedKeys objectAtIndex:[ip section]];
    NSArray *unsortedAccounts = [allAccounts objectForKey:index];
    NSArray *accountNames = [NSArray array];
    NSMutableDictionary *thisAccount = nil;
    
    for( NSDictionary *account in unsortedAccounts )
        if( account && ![AccountUtil isEmpty:[account objectForKey:@"Name"]] )
            accountNames = [accountNames arrayByAddingObject:[account objectForKey:@"Name"]];
    
    if( [accountNames count] == 0 )
        return nil;
    
    accountNames = [self sortArray:accountNames];
    
    int c = 0;
    
    for( NSDictionary *account in unsortedAccounts ) {
        if( [[account objectForKey:@"Name"] isEqualToString:[accountNames objectAtIndex:[ip row]]] ) {
            thisAccount = [NSMutableDictionary dictionaryWithDictionary:account];
            break;
        }
        
        c++;
    }
    
    if( !thisAccount )
        return nil;
    
    [thisAccount setValue:[NSNumber numberWithInt:c] forKey:@"tag"];
    
    return thisAccount;
}

// Given an account, get an index path for it from a dictionary defined as in dictionaryFromAccountArray
+ (NSIndexPath *) indexPathForAccountDictionary:(NSDictionary *)account accountDictionary:(NSDictionary *)allAccounts {
    int section = 0, row = 0;
    
    if( !account || !allAccounts )
        return nil;
    
    NSString *index = nil; 
    
    if( ![[NSCharacterSet letterCharacterSet] characterIsMember:[[account objectForKey:@"Name"] characterAtIndex:0]] )
        index = @"#";
    else
        index = [[[account objectForKey:@"Name"] substringToIndex:1] uppercaseString];
    
    NSArray *accounts = [allAccounts objectForKey:index];
    NSArray *keys = [self sortArray:[allAccounts allKeys]];
    NSArray *accountNames = [NSArray array];
        
    for( int x = 0; x < [keys count]; x++ )
        switch( [index compare:[keys objectAtIndex:x] options:NSCaseInsensitiveSearch] ) {
            case NSOrderedDescending:
                section++;
                break;
            default:
                break;
        }            

    for( NSDictionary *acc in accounts )
        if( acc && ![AccountUtil isEmpty:[acc objectForKey:@"Name"]] )
            accountNames = [accountNames arrayByAddingObject:[acc objectForKey:@"Name"]];
    
    if( [accountNames count] == 0 )
        return [NSIndexPath indexPathForRow:0 inSection:section];
    
    accountNames = [self sortArray:accountNames];
    
    for( int x = 0; x < [accountNames count]; x++ )
        switch( [[account objectForKey:@"Name"] compare:[accountNames objectAtIndex:x] options:NSCaseInsensitiveSearch] ) {
            case NSOrderedDescending: 
                row++;
                break;
            default:
                break;
        }

    return [NSIndexPath indexPathForRow:row inSection:section];
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
            [html appendString:tempText];
        
        [scanner scanUpToString:@">" intoString:NULL];
        
        if (![scanner isAtEnd])
            [scanner setScanLocation:[scanner scanLocation] + 1];
        
        tempText = nil;
    }
    
    return html;
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

- (NSDictionary *) convertFieldNamesToLabels:(NSDictionary *)account {
    if( !accountDescribe )
        return account;
    
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithCapacity:[account count]];
    
    for( NSString *key in [account allKeys] )
        if( ![accountDescribe fieldWithName:key] || [key isEqualToString:@"Name"] || [key isEqualToString:@"Id"] )
            [ret setObject:[account objectForKey:key] forKey:key];
        else
            [ret setObject:[account objectForKey:key] forKey:[[accountDescribe fieldWithName:key] label]];
    
    return [NSDictionary dictionaryWithObjects:[ret allValues] forKeys:[ret allKeys]];
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
