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

#import "AccountFirstRunController.h"
#import "AccountUtil.h"
#import "RootViewController.h"
#import "SimpleKeychain.h"
#import <QuartzCore/QuartzCore.h>

@implementation AccountFirstRunController

@synthesize rootViewController, pageControl, scrollView;

- (id) initWithRootViewController:(RootViewController *)rvc {
    if((self = [super init])) {
        self.title = [NSString stringWithFormat:@"%@ %@!", 
                      NSLocalizedString(@"Welcome to", @"Welcome to"),
                      [AccountUtil appFullName]];
        self.view.backgroundColor = UIColorFromRGB(0xdddddd);
        self.rootViewController = rvc;
        
        pageControlBeingUsed = NO;
        
        float curY = 10;
        
        CGSize s = CGSizeMake( 535, 580 );
        
        CGRect r;
        CGSize textSize;
        
        UILabel *swipeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        swipeLabel.backgroundColor = [UIColor clearColor];
        swipeLabel.font = [UIFont boldSystemFontOfSize:16];
        swipeLabel.textColor = [UIColor darkGrayColor];
        swipeLabel.numberOfLines = 0;
        swipeLabel.text = NSLocalizedString(@"Swipe right and left to see what Account Viewer can do.", @"firstrun - Swipe left and right intro string");
        swipeLabel.textAlignment = UITextAlignmentCenter;
        
        textSize = [swipeLabel.text sizeWithFont:swipeLabel.font constrainedToSize:CGSizeMake( s.width - 20, 60 )];
        
        r = swipeLabel.frame;
        r.size = textSize;
        r.origin = CGPointMake( lroundf(( s.width - r.size.width ) / 2.0f), curY );
        
        [swipeLabel setFrame:r];
        
        [self.view addSubview:swipeLabel];
        [swipeLabel release];
        
        curY += swipeLabel.frame.size.height + 20;
        
        self.scrollView = [[[UIScrollView alloc] initWithFrame:CGRectMake( 10, curY, s.width - 20, 380 )] autorelease];
        self.scrollView.pagingEnabled = YES;
        self.scrollView.delegate = self;
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.showsVerticalScrollIndicator = NO;
        
        [self.view addSubview:self.scrollView];
        
        curY += self.scrollView.frame.size.height + 10;
        
        NSArray *images = [NSArray arrayWithObjects:
                           [UIImage imageNamed:@"firstrun1.png"], 
                           [UIImage imageNamed:@"firstrun2.png"],
                           [UIImage imageNamed:@"firstrun3.png"], 
                           [UIImage imageNamed:@"firstrun4.png"], nil];
        NSArray *imageCaptions = [NSArray arrayWithObjects:
                                  NSLocalizedString(@"Save your most important Accounts to secure offline access.", @"first-run 1"),
                                  NSLocalizedString(@"Read the latest news headlines for your Accounts.", @"first-run 2"),
                                  NSLocalizedString(@"Browse record overviews with interactive maps for each Account.", @"first-run 3"),
                                  NSLocalizedString(@"View full record detail for any Account.", @"first-run 4"), nil];
        
        for (int i = 0; i < images.count; i++) {
            CGRect frame;
            frame.origin.x = ( self.scrollView.frame.size.width * i ) + 
                lroundf( ( self.scrollView.frame.size.width - ((UIImage *)[images objectAtIndex:i]).size.width ) / 2.0f ); 
            frame.origin.y = 0;
            frame.size = ((UIImage *)[images objectAtIndex:i]).size;
            
            UIImageView *imageView = [[UIImageView alloc] initWithImage:[images objectAtIndex:i]];
            [imageView setFrame:frame];
            imageView.layer.cornerRadius = 8.0f;
            imageView.layer.borderColor = [UIColor darkGrayColor].CGColor;
            imageView.layer.borderWidth = 1.0f;
            imageView.layer.masksToBounds = YES;
            
            [self.scrollView addSubview:imageView];
            
            UILabel *caption = [[UILabel alloc] initWithFrame:CGRectZero];
            caption.backgroundColor = [UIColor clearColor];
            caption.text = [imageCaptions objectAtIndex:i];
            caption.numberOfLines = 0;
            caption.textAlignment = UITextAlignmentCenter;
            caption.textColor = AppSecondaryColor;
            caption.font = [UIFont systemFontOfSize:15];    
            
            textSize = [caption.text sizeWithFont:caption.font constrainedToSize:CGSizeMake( self.scrollView.frame.size.width - 20, 60 )];
            r = caption.frame;
            r.size = textSize;
            r.origin = CGPointMake( ( self.scrollView.frame.size.width * i ) + lroundf(( s.width - r.size.width ) / 2.0f ), 
                                   imageView.image.size.height + 5);
            
            [caption setFrame:r];
            
            [self.scrollView addSubview:caption];
            [imageView release];
            [caption release];
        }
        
        self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * images.count, self.scrollView.frame.size.height);
        
        self.pageControl = [[[UIPageControl alloc] initWithFrame:CGRectMake( 360, curY, 40, 20 )] autorelease];
        self.pageControl.currentPage = 0;
        self.pageControl.numberOfPages = [images count];
        [self.pageControl addTarget:self action:@selector(changePage) forControlEvents:UIControlEventValueChanged];
        
        [self.view addSubview:self.pageControl];
        
        curY += self.pageControl.frame.size.height;
        
        UILabel *goLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        goLabel.backgroundColor = [UIColor clearColor];
        goLabel.font = [UIFont boldSystemFontOfSize:16];
        goLabel.numberOfLines = 0;
        goLabel.textColor = [UIColor darkGrayColor];
        goLabel.text = NSLocalizedString(@"Start with local accounts or log in now to Salesforce.", @"firstrun - local accounts or login");
        goLabel.textAlignment = UITextAlignmentCenter;
        
        textSize = [goLabel.text sizeWithFont:goLabel.font constrainedToSize:CGSizeMake( s.width - 20, 50 )];
        r = goLabel.frame;
        r.size = textSize;
        r.origin = CGPointMake( lroundf(( s.width - r.size.width ) / 2.0f ), curY);
        
        [goLabel setFrame:r];
        
        [self.view addSubview:goLabel];
        [goLabel release];
        
        curY += goLabel.frame.size.height + 10;
        
        UIButton *laterButton = [UIButton buttonWithType:UIButtonTypeCustom];
        laterButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        laterButton.titleLabel.numberOfLines = 1;
        laterButton.layer.borderColor = [UIColor darkGrayColor].CGColor;
        laterButton.layer.borderWidth = 1.5f;
        laterButton.layer.cornerRadius = 6.0f;

        [laterButton setBackgroundImage:[UIImage imageNamed:@"buttonBG.png"] forState:UIControlStateNormal];
        [laterButton setTitle:NSLocalizedString(@"Local Accounts", @"Local accounts name") forState:UIControlStateNormal];
        [laterButton setTitleColor:AppSecondaryColor forState:UIControlStateNormal];
        
        CGSize buttonSize = [[laterButton titleForState:UIControlStateNormal] sizeWithFont:laterButton.titleLabel.font
                                                                         constrainedToSize:CGSizeMake(325, 35)];
        
        if( buttonSize.height < 35 )
            buttonSize.height = 35;
        
        if( buttonSize.width < 250 )
            buttonSize.width = 250;
        
        [laterButton setFrame:CGRectMake( lroundf( s.width / 2 ) - 5 - buttonSize.width, curY, buttonSize.width, buttonSize.height )];
        [laterButton addTarget:self.rootViewController action:@selector(hideFirstRunModal) forControlEvents:UIControlEventTouchUpInside];
        
        [self.view addSubview:laterButton];
        
        UIButton *loginButton = [UIButton buttonWithType:UIButtonTypeCustom];
        loginButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        loginButton.titleLabel.numberOfLines = 1;
        loginButton.layer.borderColor = [UIColor darkGrayColor].CGColor;
        loginButton.layer.borderWidth = 1.5f;
        loginButton.layer.cornerRadius = 6.0f;
        
        [loginButton setBackgroundImage:[UIImage imageNamed:@"buttonBG.png"] forState:UIControlStateNormal];
        [loginButton setTitleColor:AppSecondaryColor forState:UIControlStateNormal];
        [loginButton setTitle:NSLocalizedString(@"Salesforce Login", @"Salesforce Login") forState:UIControlStateNormal];
        
        buttonSize = [[loginButton titleForState:UIControlStateNormal] sizeWithFont:loginButton.titleLabel.font
                                                                         constrainedToSize:CGSizeMake(325, 35)];
        
        if( buttonSize.height < 35 )
            buttonSize.height = 35;
        
        if( buttonSize.width < 250 )
            buttonSize.width = 250;
        
        [loginButton setFrame:CGRectMake( lroundf( s.width / 2 ) + 5, curY, buttonSize.width, buttonSize.height )];
        [loginButton addTarget:self.rootViewController action:@selector(showLogin) forControlEvents:UIControlEventTouchUpInside];
        
        [self.view addSubview:loginButton];
    }
    
    [self addDefaultLocalAccounts];
    
    return self;
}

- (void) addDefaultLocalAccounts {
    NSDictionary *localAcct = nil;
    NSDictionary *accounts = [AccountUtil getAllAccounts];
    
    // Zap all accounts
    if( accounts && [accounts count] > 0 )
        [AccountUtil deleteAllAccounts];
    
    // Zap any saved credentials
    [SimpleKeychain delete:instanceURLKey];
    [SimpleKeychain delete:refreshTokenKey];
    
    localAcct = [NSDictionary dictionaryWithObjectsAndKeys:
                 @"Salesforce.com Inc.", @"Name",
                 @"800-NOSOFTWARE", @"Phone",
                 @"Technology", @"Industry",
                 @"http://www.salesforce.com/", @"Website",
                 @"1 Market St", @"Street",
                 @"San Francisco", @"City",
                 @"CA", @"State",
                 @"94105", @"PostalCode",
                 @"USA", @"Country",
                 @"5600", @"Employees",
                 @"CRM", @"TickerSymbol",
                 nil];
    
    [AccountUtil upsertAccount:localAcct];
    
    localAcct = [NSDictionary dictionaryWithObjectsAndKeys:
                 @"Twitter Inc.", @"Name",
                 @"Technology", @"Industry",
                 @"http://www.twitter.com/", @"Website",
                 @"795 Folsom St", @"Street",
                 @"San Francisco", @"City",
                 @"CA", @"State",
                 @"94107", @"PostalCode",
                 @"USA", @"Country",
                 @"500", @"Employees",
                 nil];
    
    [AccountUtil upsertAccount:localAcct];
    
    localAcct = [NSDictionary dictionaryWithObjectsAndKeys:
                 @"Google Inc.", @"Name",
                 @"650-253-0000", @"Phone",
                 @"Technology", @"Industry",
                 @"http://www.google.com/", @"Website",
                 @"1600 Amphitheatre Parkway", @"Street",
                 @"Mountain View", @"City",
                 @"CA", @"State",
                 @"94043", @"PostalCode",
                 @"USA", @"Country",
                 @"GOOG", @"TickerSymbol",
                 @"26000", @"Employees",
                 nil];
    
    [AccountUtil upsertAccount:localAcct];
    
    localAcct = [NSDictionary dictionaryWithObjectsAndKeys:
                 @"Apple Inc.", @"Name",
                 @"800-MY-APPLE", @"Phone",
                 @"Technology", @"Industry",
                 @"AAPL", @"TickerSymbol",
                 @"http://www.apple.com/", @"Website",
                 @"1 Infinite Loop", @"Street",
                 @"Cupertino", @"City",
                 @"CA", @"State",
                 @"95014", @"PostalCode",
                 @"USA", @"Country",
                 @"32000", @"Employees",
                 nil];
    
    [AccountUtil upsertAccount:localAcct];
    
    localAcct = [NSDictionary dictionaryWithObjectsAndKeys:
                 @"Cisco Systems Inc.", @"Name",
                 @"408-526-7209", @"Phone",
                 @"Technology", @"Industry",
                 @"CSCO", @"TickerSymbol",
                 @"http://www.cisco.com", @"Website",
                 @"170 W. Tasman Dr.", @"Street",
                 @"San Jose", @"City",
                 @"CA", @"State",
                 @"95134", @"PostalCode",
                 @"USA", @"Country",
                 @"73408", @"Employees",
                 nil];
    
    [AccountUtil upsertAccount:localAcct];
    
    localAcct = [NSDictionary dictionaryWithObjectsAndKeys:
                 @"Dell Inc.", @"Name",
                 @"800-999-3355", @"Phone",
                 @"Technology", @"Industry",
                 @"DELL", @"TickerSymbol",
                 @"http://www.dell.com", @"Website",
                 @"One Dell Way", @"Street",
                 @"Round Rock", @"City",
                 @"TX", @"State",
                 @"78682", @"PostalCode",
                 @"USA", @"Country",
                 @"65200", @"Employees",
                 nil];
    
    [AccountUtil upsertAccount:localAcct];
}

- (IBAction)changePage {
    // update the scroll view to the appropriate page
    CGRect frame;
    frame.origin.x = self.scrollView.frame.size.width * self.pageControl.currentPage;
    frame.origin.y = 0;
    frame.size = self.scrollView.frame.size;
    [self.scrollView scrollRectToVisible:frame animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)sender {
	if (!pageControlBeingUsed) {
		// Switch the indicator when more than 50% of the previous/next page is visible
		CGFloat pageWidth = self.scrollView.frame.size.width;
		int page = floor((self.scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
		self.pageControl.currentPage = page;
	}
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	pageControlBeingUsed = NO;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	pageControlBeingUsed = NO;
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (void) viewDidUnload {
    self.pageControl = nil;
    self.scrollView = nil;
    
    [super viewDidUnload];
}

- (void) dealloc {
    [pageControl release];
    [scrollView release];
    [super dealloc];
}

@end