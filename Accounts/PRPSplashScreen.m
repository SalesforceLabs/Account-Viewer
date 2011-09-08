/***
 * Excerpted from "iOS Recipes",
 * published by The Pragmatic Bookshelf.
 * Copyrights apply to this code. It may not be used to create training material, 
 * courses, books, articles, and the like. Contact us if you are in doubt.
 * We make no guarantees that this code is fit for any purpose. 
 * Visit http://www.pragmaticprogrammer.com/titles/cdirec for more book information.
***/
    //
//  PRPSplashScreenViewController.m
//  BasicSplashScreen
//
//  Created by Matt Drance on 10/1/10.
//  Copyright 2010 Bookhouse Software, LLC. All rights reserved.
//

#import "PRPSplashScreen.h"

@implementation PRPSplashScreen

@synthesize splashImage;
@synthesize showsStatusBarOnDismissal;
@synthesize delegate;

- (void)dealloc {
    [splashImage release], splashImage = nil;
    [super dealloc];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.splashImage = nil;
}

- (void)loadView {
    UIImageView *iv = [[UIImageView alloc] initWithImage:self.splashImage];
    iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | 
        UIViewAutoresizingFlexibleHeight;
    iv.contentMode = UIViewContentModeCenter;
    self.view = iv;
    [iv release];
}

- (UIImage *)splashImage {
    if (splashImage == nil) {
        self.splashImage = [UIImage imageNamed:@"Default.png"];
    }
    return splashImage;
}

- (void)hide {
    if (self.showsStatusBarOnDismissal) {
        UIApplication *app = [UIApplication sharedApplication];
        [app setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    }
    [self dismissModalViewControllerAnimated:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    SEL didAppearSelector = @selector(splashScreenDidAppear:);
    if ([self.delegate respondsToSelector:didAppearSelector]) {
        [self.delegate splashScreenDidAppear:self];
    }
    [self performSelector:@selector(hide) withObject:nil afterDelay:0];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if ([self.delegate respondsToSelector:@selector(splashScreenWillDisappear:)]) {
        [self.delegate splashScreenWillDisappear:self];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if ([self.delegate respondsToSelector:@selector(splashScreenDidDisappear:)]) {
        [self.delegate splashScreenDidDisappear:self];
    }
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}


@end
