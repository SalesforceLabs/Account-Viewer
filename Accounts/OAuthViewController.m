/* 
 * Copyright (c) 2011, salesforce.com, inc.
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

#import "OAuthViewController.h"
#import "NSURL+Additions.h"
#import "WebViewController.h"
#import "DSActivityView.h"
#import "PRPAlertView.h"

@interface OAuthViewController (Private)

- (NSURL *)loginURL;
- (void)sendActionToTarget:(NSError *)error;

@end

@implementation OAuthViewController

@synthesize accessToken;
@synthesize refreshToken;
@synthesize display;
@synthesize redirectUri;
@synthesize instanceUrl;
@synthesize webView;

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector clientId:(NSString *)aClientId
{
    if ((self = [super init])) {
        target = [aTarget retain];
        action = aSelector;
        clientId = [aClientId retain];
        self.display = @"touch";
        self.redirectUri = [NSString stringWithFormat:@"%@services/oauth2/success", [self loginHost]];  
        
        [self.view setFrame:CGRectMake(0, 0, 540, 575)];
        
        if( !self.webView ) {
            self.webView = [[[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 540, 575)] autorelease];
            webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight ;
            webView.delegate = self;
            webView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]];
            webView.scalesPageToFit = YES;
            
            [self.view addSubview:self.webView];
        }
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self loginURL]];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [self.webView loadRequest:request];
    
    [DSBezelActivityView newActivityViewForView:self.webView];
    
    return self;
}

- (NSString *)loginHost {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *host = [defaults stringForKey:@"custom_host"];
    
    if( [[defaults stringForKey:@"login_host"] isEqualToString:@"Sandbox"] )
        return @"https://test.salesforce.com/";
    else if( [[defaults stringForKey:@"login_host"] isEqualToString:@"Custom Host"] && host ) {    
        if( [host hasPrefix:@"http://"] )
            host = [host stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
        
        if( ![host hasPrefix:@"https://"] )
            host = [@"https://" stringByAppendingString:host];
        
        if( ![host hasSuffix:@"/"] )
            host = [host stringByAppendingString:@"/"];
        
        return host;
    }
    
    return @"https://login.salesforce.com/";
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}



- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Overriden to allow any orientation.
    return YES;
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)dealloc {
    [target release];
    [clientId release];
    [webView release];
    [display release];
    [accessToken release];
    [instanceUrl release];
    [refreshToken release];
    [super dealloc];
}

#pragma mark -
#pragma mark Properties


#pragma mark -
#pragma mark Private

- (NSURL *)loginURL {
    NSString *urlTemplate = @"%@services/oauth2/authorize?response_type=token&client_id=%@&redirect_uri=%@&display=%@";
    NSString *urlString = [NSString stringWithFormat:urlTemplate, [self loginHost], clientId, redirectUri, display];
    
    urlString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:urlString];
    //NSLog(@"loginURL = %@", url);
    return url;
}

- (void)sendActionToTarget:(NSError *)error {
    [target performSelector:action withObject:self withObject:error];
}

#pragma mark -
#pragma mark UIWebViewDelegate

- (void) webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [DSBezelActivityView removeViewAnimated:NO];
    
    if( [error code] != -999 )
        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert",@"Alert")
                            message:[error localizedDescription]
                        cancelTitle:nil
                        cancelBlock:nil
                         otherTitle:NSLocalizedString(@"OK",@"OK")
                         otherBlock: ^(void) {
                             [self sendActionToTarget:error];
                         }];
}

- (void) webViewDidFinishLoad:(UIWebView *)webView {
    [DSBezelActivityView removeViewAnimated:YES];
}

- (BOOL)webView:(UIWebView *)myWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType 
{
    NSString *urlString = [[request URL] absoluteString];

    NSRange range = [urlString rangeOfString:self.redirectUri];
    
    if (range.length > 0 && range.location == 0) 
    {
        NSString * newInstanceURL = [[request URL] parameterWithName:@"instance_url"];
        if (newInstanceURL)
        {
            [instanceUrl release];
            instanceUrl = [newInstanceURL retain];
        }
        
        NSString *newRefreshToken = [[request URL] parameterWithName:@"refresh_token"];
        if (newRefreshToken)
        {
            [refreshToken release];
            refreshToken = [newRefreshToken retain];
        }
        
        NSString *newAccessToken = [[request URL] parameterWithName:@"access_token"];
        if (newAccessToken)
        {
            [accessToken release];
            accessToken = [newAccessToken retain];
            [self sendActionToTarget:nil];
        }
        return NO;
    }
    
    return YES;
}

@end
