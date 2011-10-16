/* 
 * Copyright (c) 2011, salesforce.com, inc.
 * Author: Jonathan Hersh jhersh.com
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

#import "FieldWebview.h"
#import "AccountUtil.h"

@implementation FieldWebview

@synthesize dvc;

+ (id) fieldWebviewWithHTML:(NSString *)html withDetailViewController:(DetailViewController *)dvcTarget {
    FieldWebview *fwv = [[[self class] alloc] initWithFrame:CGRectMake(0, 0, FIELDVALUEWIDTH, 100)];
    
    fwv.delegate = fwv;
    fwv.dvc = dvcTarget;
    fwv.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    fwv.scalesPageToFit = NO;
    fwv.allowsInlineMediaPlayback = NO;
    fwv.backgroundColor = [UIColor whiteColor];
    
    html = [NSString stringWithFormat:@"<body style=\"margin: 0; padding: 0; max-width: %i px;\">%@</body>", FIELDVALUEWIDTH, html];
    
    NSLog(@"loading html %@", html);
    
    [fwv loadHTMLString:html baseURL:nil];
    
    return [fwv autorelease];
}

- (void)dealloc {
    [super dealloc];
}

#pragma mark - webview delegate

- (void) webViewDidStartLoad:(UIWebView *)webView {
    NSLog(@"started load");
}

- (void) webViewDidFinishLoad:(UIWebView *)webView {
    NSLog(@"finished load");
    
    NSString *bodyHeight = [webView stringByEvaluatingJavaScriptFromString:@"document.body.offsetHeight"];
    NSString *bodyWidth = [webView stringByEvaluatingJavaScriptFromString:@"document.body.offsetWidth"];
    
    CGSize fittedSize = [webView sizeThatFits:CGSizeZero];
    
    NSLog(@"offset w/h: %@ %@ fitted: %@", bodyWidth, bodyHeight, NSStringFromCGSize(fittedSize));
    
    [webView setFrame:CGRectMake( webView.frame.origin.x, 0, 
                                 MIN( FIELDVALUEWIDTH, [bodyWidth floatValue] ), 
                                 MIN( 100, [bodyHeight floatValue] ) )];
}

- (void) webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"failed load");
}

- (BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    // Only load the initial rich text contents
    if( [[[request URL] absoluteString] isEqualToString:@"about:blank"] )
        return YES;
    
    // Otherwise, load the url in a separate webview
    [self.dvc addFlyingWindow:FlyingWindowWebView withArg:[[request URL] absoluteString]];
    
    return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return YES;
}

@end
