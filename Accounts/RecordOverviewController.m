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

#import "RecordOverviewController.h"
#import "DetailViewController.h"
#import "RootViewController.h"
#import "SubNavViewController.h"
#import "AccountUtil.h"
#import "zkSforce.h"
#import "AddressAnnotation.h"
#import <QuartzCore/QuartzCore.h>
#import "PRPConnection.h"
#import "zkParser.h"
#import "DSActivityView.h"
#import "AccountGridCell.h"
#import "FieldPopoverButton.h"
#import "PRPAlertView.h"
#import "FollowButton.h"
#import "FlyingWindowController.h"
#import "CommButton.h"
#import "JSON-Framework/JSON.h"

static float cornerRadius = 4.0f;

@implementation RecordOverviewController

@synthesize accountMap, mapView, gridView, addressButton, recenterButton, geocodeButton, detailButton, recordLayoutView, scrollView, commButtons, commButtonBackground;

- (id) initWithFrame:(CGRect)frame {
    if((self = [super initWithFrame:frame])) {      
        int curY = self.navBar.frame.size.height;
        
        self.view.backgroundColor = [UIColor whiteColor];
        
        // gridview
        UIImage *gridBG = [UIImage imageNamed:@"gridGradient.png"];
        AQGridView *gv = [[AQGridView alloc] initWithFrame:CGRectMake( 0, curY, frame.size.width, gridBG.size.height )];
        
        gv.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
        gv.scrollEnabled = NO;
        gv.requiresSelection = NO;
        gv.delegate = self;
        gv.dataSource = self;
        gv.separatorStyle = AQGridViewCellSeparatorStyleSingleLine;
        gv.separatorColor = UIColorFromRGB(0xdddddd);
        gv.backgroundColor = [UIColor colorWithPatternImage:gridBG];
        
        self.gridView = gv;
        [gv release];
        
        [self.view addSubview:self.gridView];
        
        curY += self.gridView.frame.size.height + 10;
        
        // Comm buttons
        if( !self.commButtonBackground ) {
            self.commButtonBackground = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 70 )] autorelease];
            self.commButtonBackground.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"gridGradient.png"]];
            
            CAGradientLayer *shadowLayer = [CAGradientLayer layer];
            shadowLayer.backgroundColor = [UIColor clearColor].CGColor;
            shadowLayer.frame = CGRectMake(0, 70, self.view.frame.size.width + 10, 5);
            shadowLayer.shouldRasterize = YES;
            
            shadowLayer.colors = [NSArray arrayWithObjects:(id)[UIColor colorWithWhite:0.0 alpha:0.01].CGColor,
                                  (id)[UIColor colorWithWhite:0.0 alpha:0.2].CGColor,
                                  (id)[UIColor colorWithWhite:0.0 alpha:0.4].CGColor,
                                  (id)[UIColor colorWithWhite:0.0 alpha:0.8].CGColor, nil];		
            
            shadowLayer.startPoint = CGPointMake(0.0, 1.0);
            shadowLayer.endPoint = CGPointMake(0.0, 0.0);
            
            shadowLayer.shadowPath = [UIBezierPath bezierPathWithRect:shadowLayer.bounds].CGPath;
            
            [self.commButtonBackground.layer addSublayer:shadowLayer];
            
            [self.view addSubview:self.commButtonBackground];
        }
        
        // Scrollview
        if( !self.scrollView ) {
            self.scrollView = [[[UIScrollView alloc] initWithFrame:CGRectMake( 0, curY, self.view.frame.size.width,
                                                                             self.view.frame.size.height - curY )] autorelease];
            self.scrollView.showsVerticalScrollIndicator = YES;
            self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

            [self.scrollView setContentOffset:CGPointZero animated:NO];
            [self.scrollView setContentSize:CGSizeMake( frame.size.width, self.mapView.frame.size.height )];
            
            [self.view insertSubview:self.scrollView belowSubview:self.commButtonBackground];
        }

        // Container for the map
        UIView *mv = [[UIView alloc] initWithFrame:CGRectZero];
        mv.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        mv.autoresizesSubviews = YES;
        mv.backgroundColor = [UIColor clearColor];
        
        self.mapView = mv;
        [mv release];
        
        [self.scrollView addSubview:self.mapView];
        
        // Retry geocode button   
        if( !self.geocodeButton ) {
            self.geocodeButton = [UIButton buttonWithType:UIButtonTypeCustom];
            geocodeButton.titleLabel.numberOfLines = 0;
            geocodeButton.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
            [geocodeButton setTitleColor:UIColorFromRGB(0x444444) forState:UIControlStateNormal];
            geocodeButton.titleLabel.textAlignment = UITextAlignmentCenter;
            [geocodeButton.titleLabel setFont:[UIFont fontWithName:@"Verdana" size:18]];
            [geocodeButton setTitle:NSLocalizedString(@"Geocode Failed — Tap to retry", @"Geocode failure") forState:UIControlStateNormal];
            geocodeButton.backgroundColor = [UIColor clearColor];
            [geocodeButton addTarget:self action:@selector(configureMap) forControlEvents:UIControlEventTouchUpInside];
            
            geocodeButton.layer.cornerRadius = cornerRadius;
            geocodeButton.layer.borderColor = [UIColor darkGrayColor].CGColor;
            geocodeButton.layer.borderWidth = 1.5f;            
            
            geocodeButton.hidden = YES;
            
            [self.mapView addSubview:self.geocodeButton];
        }
        
        // Address label
        UIView *addressLabel = [AccountUtil createViewForSection:NSLocalizedString(@"Address", @"Address label")];
        [addressLabel setFrame:CGRectMake( 0, 0, self.view.frame.size.width, addressLabel.frame.size.height )];        
        [self.mapView addSubview:addressLabel];
        
        // Recenter Button
        if( !self.recenterButton ) {
            self.recenterButton = [UIButton buttonWithType:UIButtonTypeCustom];
            self.recenterButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
            self.recenterButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
            [self.recenterButton setTitle:NSLocalizedString(@"Recenter", @"Recenter label") forState:UIControlStateNormal];
            [self.recenterButton setTitleColor:UIColorFromRGB(0x1679c9) forState:UIControlStateNormal];
            [self.recenterButton addTarget:self action:@selector(recenterMap:) forControlEvents:UIControlEventTouchUpInside];
            self.recenterButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
            self.recenterButton.titleLabel.shadowColor = [UIColor whiteColor];
            self.recenterButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
            self.recenterButton.layer.borderWidth = 2.0f;
            self.recenterButton.layer.borderColor = gv.separatorColor.CGColor;
            self.recenterButton.layer.cornerRadius = cornerRadius;
            self.recenterButton.layer.masksToBounds = YES;
            
            [self.mapView addSubview:self.recenterButton];
        }
        
        // account map
        MKMapView *map = [[MKMapView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        [map.layer setMasksToBounds:YES];
        map.layer.cornerRadius = cornerRadius;
        map.autoresizingMask = mv.autoresizingMask;
        
        self.accountMap = map;
        [map release];
        
        [self.mapView addSubview:self.accountMap];
    }
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self 
     selector:@selector(layoutView)
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
    
    return self;
}

- (void) refreshSubNav {
    if( !self.detailViewController )
        return;
    
    [self.detailViewController.subNavViewController refresh];
}

- (void) layoutView {   
    float curY = self.navBar.frame.size.height;
    CGSize s;
    
    // Gridview
    [self.gridView setFrame:CGRectMake( 0, curY, self.view.frame.size.width, gridView.frame.size.height )];
    [self.gridView reloadData];
    
    curY += self.gridView.frame.size.height;
    
    // Comm button background
    if( self.commButtons && [self.commButtons count] > 0 ) {
        [self.commButtonBackground setFrame:CGRectMake(0, curY, self.view.frame.size.width, self.commButtonBackground.frame.size.height )];
        curY += self.commButtonBackground.frame.size.height;
        
        // Layout comm buttons
        float buttonWidth = self.commButtonBackground.frame.size.width / [self.commButtons count];
        float curX = 0;
        
        for( UIButton *button in self.commButtons ) {
            s = [button imageForState:UIControlStateNormal].size;
            
            [button setFrame:CGRectMake( lroundf( curX + ( ( buttonWidth - s.width ) / 2.0f ) ), 
                                        lroundf( ( self.commButtonBackground.frame.size.height - s.height ) / 2.0f ), 
                                        s.width, s.height )];
            curX += buttonWidth;
        }
    }
    
    // Scrollview frame
    CGRect r = CGRectMake( 0, curY, self.view.frame.size.width - 10, self.view.frame.size.height - curY);
    
    if( !CGRectEqualToRect( r, self.scrollView.frame ) )
        [self.scrollView setFrame:r];
    
    // Reset curY for the scrollView inner content
    curY = 10;
    
    // Mapview container
    [self.mapView setFrame:CGRectMake( 0, curY, self.view.frame.size.width, ( self.geocodeButton.hidden ? 350 : 100 ) )];
    
    if( !self.mapView.hidden )
        curY += self.mapView.frame.size.height + 5;
    
    // Account address button
    s = [self.addressButton.titleLabel.text sizeWithFont:self.addressButton.titleLabel.font
                                              constrainedToSize:CGSizeMake( self.view.frame.size.width - 20, 999 )];
    [self.addressButton setFrame:CGRectMake( 10, 40, s.width, s.height)];
    
    // Account map
    r = CGRectMake( 10, self.addressButton.frame.origin.y + self.addressButton.frame.size.height + 5, 
                          self.view.frame.size.width - 30, self.mapView.frame.size.height - self.addressButton.frame.size.height - 10 );
    
    if( r.size.height > 250 )
        r.size.height = 250;
    
    [self.accountMap setFrame:r];
    
    // Geocode failed button
    [geocodeButton setFrame:CGRectMake( 10, 40, self.mapView.frame.size.width - 30, 40)];
    
    // Recenter button
    CGSize buttonSize = CGSizeMake( lroundf(self.view.frame.size.width / 2.6f), 35 );
    [self.recenterButton setFrame:CGRectMake( self.accountMap.frame.origin.x + self.accountMap.frame.size.width - buttonSize.width, 
                                             self.accountMap.frame.origin.y, buttonSize.width, buttonSize.height )];
    [self.recenterButton.superview bringSubviewToFront:self.recenterButton];
    
    // Account detail view
    r = CGRectMake( 0, curY, 
                   self.view.frame.size.width, self.recordLayoutView.frame.size.height );
    
    if( !CGRectEqualToRect( r, self.recordLayoutView.frame ) )
        [self.recordLayoutView setFrame:r];
    
    curY += self.recordLayoutView.frame.size.height;
    
    // Scrollview content size
    s.width = self.scrollView.frame.size.width;    
    s.height = MAX( curY, self.scrollView.frame.size.height + 1 );
    
    if( !CGSizeEqualToSize( s, self.scrollView.contentSize ) )
        [self.scrollView setContentSize:s];
}

- (void) selectAccount:(NSDictionary *) acc {
    [super selectAccount:acc];
    
    [self loadAccount];    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
} 

- (void) setupCommButtons {
    // Comm buttons
    if( self.commButtons ) {
        for( UIButton *button in self.commButtons )
            [button removeFromSuperview];
        
        [self.commButtons removeAllObjects];
    } else
        self.commButtons = [NSMutableArray arrayWithCapacity:CommNumButtonTypes];
    
    for( int x = 0; x < CommNumButtonTypes; x++ )
        if( [CommButton supportsButtonOfType:x] ) {
            CommButton *button = [CommButton commButtonWithType:x withRecord:self.account];    
            
            if( !button ) // no actual fields to display for this button
                continue;
            
            button.detailViewController = self.detailViewController;
            
            [self.commButtons addObject:button];
            [self.commButtonBackground addSubview:button];
        }
    
    self.commButtonBackground.hidden = !self.commButtons || [self.commButtons count] == 0;
}

- (void) loadAccount {
    [accountMap removeAnnotations:[accountMap annotations]];
    mapView.hidden = YES;   
    gridView.hidden = YES;
    geocodeButton.hidden = YES;
    addressButton.hidden = YES;
    commButtonBackground.hidden = YES;
    
    int fieldLayoutTag = 11;
    
    // If the user taps several accounts in rapid succession, we can end up adding multiple layout views,
    // so remove all of them
    for( UIView *subview in [self.scrollView subviews] )
        if( subview.tag == fieldLayoutTag ) {
            [subview removeFromSuperview];
            //subview = nil;
        }
    
    [DSBezelActivityView removeViewAnimated:NO];
        
    NSDictionary *localAcct = [AccountUtil getAccount:[self.account objectForKey:@"Id"]];
    
    if( self.detailViewController.subNavViewController.subNavTableType == SubNavLocalAccounts && localAcct ) {
        self.account = localAcct;
        //[self.gridView reloadData];
        self.gridView.hidden = NO;
        
        UINavigationItem *title = [[[UINavigationItem alloc] initWithTitle:[localAcct objectForKey:@"Name"]] autorelease];
        title.hidesBackButton = YES;
        
        if( [RootViewController isPortrait] )
            title.leftBarButtonItem = self.detailViewController.browseButton;
        
        // Add some space to the right of the edit button
        if( [[self.account objectForKey:@"Id"] length] < 10 ) {
            UIToolbar* toolbar = [[UIToolbar alloc]
                                  initWithFrame:CGRectMake(0, 0, 80, self.navBar.frame.size.height)];
            NSMutableArray *buttons = [[NSMutableArray alloc] initWithCapacity:2];
            
            toolbar.tintColor = AppSecondaryColor;
            toolbar.opaque = YES;
            
            [buttons addObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                              target:self
                                                                              action:@selector(editLocalAccount:)] autorelease]];
            [buttons addObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                              target:nil
                                                                              action:nil] autorelease]];
            
            [toolbar setItems:buttons];
            [buttons release];
            
            [title setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithCustomView:toolbar] autorelease]];
            [toolbar release];
        }
        
        [self.navBar pushNavigationItem:title animated:YES];
        
        self.recordLayoutView = [AccountUtil layoutViewForAccount:self.account withTarget:self.detailViewController isLocalAccount:YES];
        self.recordLayoutView.tag = fieldLayoutTag;
        
        [self.scrollView addSubview:self.recordLayoutView];
        [self.scrollView setContentOffset:CGPointZero animated:NO];
        
        [self setupCommButtons];
        
        [self configureMap];
        [self layoutView];
        
        return;
    } 
    
    UINavigationItem *loading = [[UINavigationItem alloc] initWithTitle:NSLocalizedString(@"Loading...", @"Loading...")];
    loading.hidesBackButton = YES;    
    
    if( self.navBar.topItem.leftBarButtonItem )
        loading.leftBarButtonItem = self.navBar.topItem.leftBarButtonItem;
    
    [self.navBar pushNavigationItem:loading animated:NO];
    [loading release];
    
    NSString *fieldsToQuery = @"";
    
    // Only query the fields that will be displayed in the page layout for this account, given its record type and page layout.
    NSString *layoutId = [[[AccountUtil sharedAccountUtil] layoutForRecordTypeId:[self.account objectForKey:@"RecordTypeId"]] Id];
    NSArray *allFields = [[AccountUtil sharedAccountUtil] fieldListForLayoutId:layoutId];
    
    for( NSString *field in allFields ) {
        if( [fieldsToQuery length] > 9950 )
            break;
        
        if( field && ![field isEqualToString:@""] ) {
            if( [fieldsToQuery isEqualToString:@""] )
                fieldsToQuery = field;
            else
                fieldsToQuery = [fieldsToQuery stringByAppendingFormat:@", %@", field];
        }
    }
    
    for( NSString *headerField in [NSArray arrayWithObjects:@"Name", @"Phone", @"Industry", @"Website", nil] )
        if( ![allFields containsObject:headerField] )
            fieldsToQuery = [fieldsToQuery stringByAppendingFormat:@", %@", headerField];
    
    // Build and execute the query
    [[AccountUtil sharedAccountUtil] startNetworkAction];
    [DSBezelActivityView newActivityViewForView:self.view];
    
    NSString *queryString = [NSString stringWithFormat:@"select %@ from Account where id='%@' limit 1",
                             fieldsToQuery, [self.account objectForKey:@"Id"]];
    
    NSLog(@"SOQL %@", queryString);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
        ZKQueryResult *qr = nil;
        
        @try {
            qr = [[[AccountUtil sharedAccountUtil] client] query:queryString];
        } @catch( NSException *e ) {
            // Nuclear option - forces a logout in case loading this account failed
            [[AccountUtil sharedAccountUtil] receivedException:e];
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            [DSBezelActivityView removeViewAnimated:YES];
            
            [self.rootViewController doLogout];
            
            /*[PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                                message:NSLocalizedString(@"Failed to load this Account.", @"Account load failed")
                            cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                            cancelBlock:nil
                             otherTitle:NSLocalizedString(@"Retry", @"Retry")
                             otherBlock: ^ (void) {
                                 [self loadAccount];
                             }];*/
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) { 
            self.account = [[[qr records] objectAtIndex:0] fields];
            self.recordLayoutView = [AccountUtil layoutViewForAccount:self.account withTarget:self.detailViewController isLocalAccount:NO];
            self.recordLayoutView.tag = fieldLayoutTag;
        
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            
            UINavigationItem *title = [[[UINavigationItem alloc] initWithTitle:[self.account objectForKey:@"Name"]] autorelease];
            title.hidesBackButton = YES;
            
            if( [RootViewController isPortrait] )
                title.leftBarButtonItem = self.detailViewController.browseButton;
            
            if( [[AccountUtil sharedAccountUtil] isChatterEnabled] ) {
                FollowButton *followButton = [FollowButton followButtonWithUserId:[[[[AccountUtil sharedAccountUtil] client] currentUserInfo] userId]
                                                                         parentId:[self.account objectForKey:@"Id"]
                                                                           target:self
                                                                           action:@selector(refreshSubNav)];
                followButton.layer.cornerRadius = cornerRadius;
                followButton.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"blueButtonBackground.png"]];
                
                [followButton setFrame:CGRectMake(0, 0, 95, 30)];
                
                UIToolbar* toolbar = [[UIToolbar alloc]
                                      initWithFrame:CGRectMake(0, 0, 100, self.navBar.frame.size.height)];
                NSMutableArray *buttons = [[NSMutableArray alloc] initWithCapacity:2];
                
                toolbar.tintColor = AppSecondaryColor;
                toolbar.opaque = YES;
                
                [buttons addObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                  target:nil
                                                                                  action:nil] autorelease]];
                [buttons addObject:[[[UIBarButtonItem alloc] initWithCustomView:followButton] autorelease]];
                
                [toolbar setItems:buttons];
                [buttons release];
                
                [title setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithCustomView:toolbar] autorelease]];
                [toolbar release];
            }
            
            [DSBezelActivityView removeViewAnimated:YES];
            [self.navBar pushNavigationItem:title animated:YES];
            
            //[self.gridView reloadData];
            self.gridView.hidden = NO;
            [self configureMap];
           
            [self.scrollView addSubview:self.recordLayoutView];
            [self.scrollView setContentOffset:CGPointZero animated:NO];
            
            [self setupCommButtons];
            
            [self layoutView];
        });
    });    
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]
     removeObserver:self 
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
    
    [commButtonBackground release];
    [scrollView release];
    [recordLayoutView release];
    [accountMap release];
    [mapView release];
    [gridView release];
    [commButtons release];
    [super dealloc];
}

#pragma mark - displaying MKMapView for an account's address

- (IBAction) recenterMap:(id)sender {
    AddressAnnotation *pin = [[accountMap annotations] objectAtIndex:0];
    CLLocationCoordinate2D loc = pin.coordinate;
    loc.latitude += 0.005;
    
    MKCoordinateSpan span = MKCoordinateSpanMake(0.03, 0.03);
    MKCoordinateRegion region = MKCoordinateRegionMake( loc, span);
    
    [accountMap setRegion:region animated:(sender != nil)];    
    [accountMap selectAnnotation:pin animated:YES];
}

- (void)configureMap {    
    NSArray *cached = [[AccountUtil sharedAccountUtil] coordinatesFromCache:[self.account objectForKey:@"Id"]];
    CLLocationCoordinate2D loc;
    
    mapView.hidden = YES;
    geocodeButton.hidden = YES;
    accountMap.hidden = YES;
    recenterButton.hidden = YES;
    addressButton.hidden = YES;
    
    if( cached ) {        
        loc.latitude = [[cached objectAtIndex:0] doubleValue];
        loc.longitude = [[cached objectAtIndex:1] doubleValue];
    } else {                
        NSString *addressStr = [AccountUtil addressForAccount:self.account useBillingAddress:![AccountUtil isEmpty:[self.account objectForKey:@"BillingStreet"]]];
        
        if( !addressStr || [addressStr isEqualToString:@""] )
            return;
                
        NSString *urlStr = [NSString stringWithFormat:@"%@%@&sensor=true", 
                            GEOCODE_ENDPOINT,
                            [[AccountUtil trimWhiteSpaceFromString:addressStr] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        
        NSLog(@"geocoding %@", urlStr);
        
        PRPConnectionCompletionBlock complete = ^(PRPConnection *connection, NSError *error) {
            [[AccountUtil sharedAccountUtil] endNetworkAction];
            
            if( !error ) {                    
                NSString *responseStr = [[NSString alloc] initWithData:connection.downloadData encoding:NSUTF8StringEncoding];
                
                //NSLog(@"received response %@", responseStr);
                
                SBJsonParser *jp = [[SBJsonParser alloc] init];
                NSDictionary *json = [jp objectWithString:responseStr];
                [responseStr release];
                [jp release];
                
                CLLocationCoordinate2D loc;
                
                NSArray *geoResults = [json valueForKeyPath:@"results.geometry.location"];
                
                if( geoResults && [geoResults count] > 0 ) {
                    NSDictionary *coords = [geoResults objectAtIndex:0];
                    
                    if( coords && [coords count] == 2 ) {
                        loc = CLLocationCoordinate2DMake( [[coords objectForKey:@"lat"] floatValue],
                                                          [[coords objectForKey:@"lng"] floatValue] );
                    
                        [[AccountUtil sharedAccountUtil] addCoordinatesToCache:loc accountId:[self.account objectForKey:@"Id"]];
                        
                        // Fire this function again, which will now read the coordinates from the cache and update the map
                        [self configureMap];
                    }
                }
            } else {
                mapView.hidden = NO;
                geocodeButton.hidden = NO;
                
                [self layoutView];
                
                return;
            }
        };
        
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        [req addValue:[NSString stringWithFormat:@"Salesforce %@ for iPad", [AccountUtil appFullName]] forHTTPHeaderField:@"Referer"];
        
        PRPConnection *conn = [PRPConnection connectionWithRequest:req
                                                     progressBlock:nil
                                                   completionBlock:complete];
        [conn start]; 
        return;
    }
    
    if( [[NSNumber numberWithDouble:loc.latitude] integerValue] != 0 ) {  
        if( self.addressButton )
            [self.addressButton removeFromSuperview];
        
        NSString *address = [AccountUtil addressForAccount:self.account useBillingAddress:![AccountUtil isEmpty:[self.account objectForKey:@"BillingStreet"]]];
        
        self.addressButton = [FieldPopoverButton buttonWithText:address
                                                      fieldType:AddressField
                                                     detailText:address];
        [self.mapView addSubview:self.addressButton];
        
        mapView.hidden = NO;
        accountMap.hidden = NO;
        recenterButton.hidden = NO;
        addressButton.hidden = NO;
        
        AddressAnnotation *addAnnotation = [[AddressAnnotation alloc] initWithCoordinate:loc];
        addAnnotation.title = [self.account objectForKey:@"Name"];
        addAnnotation.subtitle = nil;
                
        [accountMap addAnnotation:addAnnotation];
        [addAnnotation release];
        
        [self recenterMap:nil];
        
        [self layoutView];
    }
}

#pragma mark - editing local accounts

- (IBAction) editLocalAccount:(id)sender {
    AccountAddEditController *accountAddEditController = [[AccountAddEditController alloc] initWithAccount:self.account];
    accountAddEditController.delegate = self;
    
    UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:accountAddEditController];
    
    aNavController.navigationBar.tintColor = AppSecondaryColor;
    aNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    aNavController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    [self presentModalViewController:aNavController animated:YES];
    [aNavController release];
    [accountAddEditController release];
}

- (void) accountDidCancel:(AccountAddEditController *)accountAddEditcontroller {
    [self dismissModalViewControllerAnimated:YES];
}

- (void) accountDidUpsert:(AccountAddEditController *)accountAddEditController {
    [self dismissModalViewControllerAnimated:YES];
    [self.subNavViewController refresh];
    [self loadAccount];
}

#pragma mark - gridview

- (NSUInteger) numberOfItemsInGridView: (AQGridView *) aGridView {
    return AccountGridNumItems;
}

- (CGSize) portraitGridCellSizeForGridView: (AQGridView *) aGridView {
    return CGSizeMake( lroundf( self.view.frame.size.width / 2.0f ), lroundf( self.gridView.frame.size.height / 2.0f ) );
}

- (AQGridViewCell *) gridView: (AQGridView *) aGridView cellForItemAtIndex: (NSUInteger) index {    
    AccountGridCell *cell = [AccountGridCell cellForGridView:aGridView];
    
    NSString *title = nil;
    NSString *value = nil;
    enum FieldType ft = TextField;
    
    switch ( index ) {
        case AccountNameCell:
            title = NSLocalizedString(@"Account Name", @"Account name field");
            value = [self.account objectForKey:@"Name"];
            break;
        case AccountIndustryCell:
            title = NSLocalizedString(@"Industry", @"Industry field");
            value = [self.account objectForKey:@"Industry"];
            break;
            
        case AccountPhoneCell:
            title = NSLocalizedString(@"Phone", @"Phone field");
            value = [self.account objectForKey:@"Phone"];
            ft = PhoneField;
            break;
        case AccountWebsiteCell:
            title = NSLocalizedString(@"Website", @"Website field");
            value = [self.account objectForKey:@"Website"];
            ft = URLField;
            break;            
        default:
            break;
    }
    
    CGSize s = [self portraitGridCellSizeForGridView:aGridView];
    
    [cell setFrame:CGRectMake(0, 0, s.width, s.height)];
    [cell setupCellWithButton:title buttonType:ft buttonText:value detailText:value];
    ((FieldPopoverButton *)cell.gridButton).detailViewController = self.detailViewController;
    [cell layoutCell];
    
    return cell;
}

- (void) gridView:(AQGridView *)gv didSelectItemAtIndex:(NSUInteger)index {
    [gv deselectItemAtIndex:index animated:YES];
}

#pragma mark - favorites

/* - (void) createFavoriteButton {
    if( !self.account || ![self.account objectForKey:@"Id"] )
        return;
    
    NSDictionary *account = [[AccountUtil sharedAccountUtil] getAccount:[self.account objectForKey:@"Id"]];
    
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:( account ? [UIImage imageNamed:@"favorite_on.png"] : [UIImage imageNamed:@"favorite_off.png"] )
                                                               style:UIBarButtonItemStyleBordered
                                                              target:self
                                                              action:@selector(toggleFavorite:)];
    
    self.navBar.topItem.rightBarButtonItem = [button autorelease];
}

- (void) toggleFavorite:(id)sender {    
    NSString *accountID = [self.account objectForKey:@"Id"];
    
    if( [[AccountUtil sharedAccountUtil] getAccount:accountID] ) {
        [[AccountUtil sharedAccountUtil] deleteAccount:accountID];
        
        [self createFavoriteButton];
        
        for( SubNavViewController *snvc in self.rootViewController.subNavControllers )
            if( [snvc subNavTableType] == SubNavLocalAccounts )
                [snvc refresh];
    } else {        
        if( self.sheet ) {
            [sheet dismissWithClickedButtonIndex:-1 animated:YES];
            sheet = nil;
            return;
        }
        
        UIActionSheet *buttonSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                                 delegate:self
                                                        cancelButtonTitle:nil
                                                   destructiveButtonTitle:nil
                                                        otherButtonTitles:NSLocalizedString(@"Save to Local Accounts", @"Save to local accounts"), nil];
        
        [buttonSheet showFromBarButtonItem:self.navBar.topItem.rightBarButtonItem animated:YES];
        
        self.sheet = buttonSheet;
    }
}

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if( buttonIndex == 0 ) {
        [[AccountUtil sharedAccountUtil] upsertAccount:self.account];
        
        [self createFavoriteButton];
        
        for( SubNavViewController *snvc in self.rootViewController.subNavControllers )
            if( [snvc subNavTableType] == SubNavLocalAccounts )
                [snvc refresh];
    }
    
    self.sheet = nil;
} */

@end
