/***
 * Excerpted from "iOS Recipes",
 * published by The Pragmatic Bookshelf.
 * Copyrights apply to this code. It may not be used to create training material, 
 * courses, books, articles, and the like. Contact us if you are in doubt.
 * We make no guarantees that this code is fit for any purpose. 
 * Visit http://www.pragmaticprogrammer.com/titles/cdirec for more book information.
***/
//
//  PRPSplashScreenViewController.h
//  BasicSplashScreen
//
//  Created by Matt Drance on 10/1/10.
//  Copyright 2010 Bookhouse Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PRPSplashScreenDelegate.h"

@interface PRPSplashScreen : UIViewController {}

@property (nonatomic, retain) UIImage *splashImage;
@property (nonatomic, assign) BOOL showsStatusBarOnDismissal;
@property (nonatomic, assign) IBOutlet id<PRPSplashScreenDelegate> delegate;

- (void)hide;

@end
