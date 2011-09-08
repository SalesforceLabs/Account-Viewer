/***
 * Excerpted from "iOS Recipes",
 * published by The Pragmatic Bookshelf.
 * Copyrights apply to this code. It may not be used to create training material, 
 * courses, books, articles, and the like. Contact us if you are in doubt.
 * We make no guarantees that this code is fit for any purpose. 
 * Visit http://www.pragmaticprogrammer.com/titles/cdirec for more book information.
***/
//
//  PRPSplashScreenDelegate.h
//  BasicSplashScreen
//
//  Created by Matt Drance on 3/22/11.
//  Copyright 2011 Bookhouse Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PRPSplashScreen;

@protocol PRPSplashScreenDelegate <NSObject>

@optional
- (void)splashScreenDidAppear:(PRPSplashScreen *)splashScreen;
- (void)splashScreenWillDisappear:(PRPSplashScreen *)splashScreen;
- (void)splashScreenDidDisappear:(PRPSplashScreen *)splashScreen;

@end
