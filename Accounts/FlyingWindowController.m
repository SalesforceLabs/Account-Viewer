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

#import "FlyingWindowController.h"
#import "RecordNewsViewController.h"
#import "RootViewController.h"
#import "AccountUtil.h"
#import "zkSforce.h"
#import <QuartzCore/QuartzCore.h>

@implementation FlyingWindowController

@synthesize subNavViewController, detailViewController, navBar, rootViewController, account, delegate, flyingWindowType, rightFWC, leftFWC, dimmer;

- (id) initWithFrame:(CGRect)frame {
    if((self = [super init])) {               
        [self.view setFrame:frame];
        self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"panelBG2.png"]];
        self.view.clipsToBounds = NO;
        
        self.account = [[[NSDictionary alloc] init] autorelease];
        
        frame.origin.x = 0;
        frame.size.height = 44;        
        self.navBar = [[[UINavigationBar alloc] initWithFrame:frame] autorelease];
        self.navBar.tintColor = AppSecondaryColor;
        self.navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        [self.view addSubview:self.navBar];
        
        CAGradientLayer *shadowLayer = [CAGradientLayer layer];
        shadowLayer.backgroundColor = [UIColor clearColor].CGColor;
        shadowLayer.frame = CGRectMake(-5, 0, 5, 1024);
        shadowLayer.shouldRasterize = YES;
        
		shadowLayer.colors = [NSArray arrayWithObjects:(id)[UIColor colorWithWhite:0.0 alpha:0.01].CGColor,
                                                        (id)[UIColor colorWithWhite:0.0 alpha:0.2].CGColor,
                                                        (id)[UIColor colorWithWhite:0.0 alpha:0.4].CGColor,
                                                        (id)[UIColor colorWithWhite:0.0 alpha:0.8].CGColor, nil];		
        
		shadowLayer.startPoint = CGPointMake(0.0, 0.0);
		shadowLayer.endPoint = CGPointMake(1.0, 0.0);
        
        shadowLayer.shadowPath = [UIBezierPath bezierPathWithRect:shadowLayer.bounds].CGPath;
        
        [self.view.layer addSublayer:shadowLayer];
        
        UIPanGestureRecognizer *panRecognizer = [[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(flyingWindowDidDrag:)] autorelease];
        [panRecognizer setMinimumNumberOfTouches:1];
        [panRecognizer setMaximumNumberOfTouches:1];
        panRecognizer.delaysTouchesBegan = YES;
        panRecognizer.delaysTouchesEnded = NO;
        panRecognizer.cancelsTouchesInView = NO;
        [panRecognizer setDelegate:self];
        [self.view addGestureRecognizer:panRecognizer];
        
        UITapGestureRecognizer *tapRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(flyingWindowDidTap:)] autorelease];
        [tapRecognizer setNumberOfTapsRequired:1];
        [tapRecognizer setNumberOfTouchesRequired:1];
        tapRecognizer.delaysTouchesBegan = NO;
        tapRecognizer.cancelsTouchesInView = NO;
        [tapRecognizer setDelegate:self];
        [self.view addGestureRecognizer:tapRecognizer];
    }
    
    return self;
}

- (void) setFrame:(CGRect)frame {
    [self.view setFrame:frame];
}

- (BOOL) isLargeWindow {
    return  self.flyingWindowType == FlyingWindowWebView ||
            self.flyingWindowType == FlyingWindowRelatedListGrid ||
            self.flyingWindowType == FlyingWindowRelatedRecordView;
}

- (void) setDimmerAlpha:(float)alpha {
    if( !self.dimmer ) {
        self.dimmer = [[[UIView alloc] initWithFrame:self.view.frame] autorelease];
        self.dimmer.backgroundColor = [UIColor blackColor];
        self.dimmer.alpha = 0.0f;
        self.dimmer.userInteractionEnabled = NO;
        
        [self.view addSubview:self.dimmer];
    }
    
    if( alpha < 0.0f )
        alpha = 0.0f;
    else if( alpha > 1.0f )
        alpha = 1.0f;
    
    [self.dimmer setFrame:self.view.frame];
    [self.view bringSubviewToFront:self.dimmer];
    [self.dimmer setAlpha:alpha];
}

- (void) flyingWindowDidTap:(id)sender {        
    if( self.rightFWC &&
       CGRectIntersectsRect( self.view.frame, self.rightFWC.view.frame ) &&
       CGRectIntersection( self.view.frame, self.rightFWC.view.frame ).size.width >= 50 ) {
        CGPoint p = self.rightFWC.view.center;
        
        p.x = lroundf( self.view.center.x + ( self.view.frame.size.width / 2.0f ) + ( self.rightFWC.view.frame.size.width / 2.0f ) );
        
        [self.rightFWC slideFlyingWindowToPoint:p];
    }
}

- (void)flyingWindowDidDrag:(id)sender {    
    if( [self.delegate respondsToSelector:@selector(flyingWindowShouldDrag:)] )
        if( ![self.delegate flyingWindowShouldDrag:self] )
            return;
    
	[[[(UITapGestureRecognizer*)sender view] layer] removeAllAnimations];
	[self.view.superview bringSubviewToFront:[(UIPanGestureRecognizer*)sender view]];
	CGPoint translatedPoint = [(UIPanGestureRecognizer*)sender translationInView:self.view.superview];
    
	if([(UIPanGestureRecognizer*)sender state] == UIGestureRecognizerStateBegan) {
		firstX = [[sender view] center].x;
		firstY = [[sender view] center].y;
	}
        
	translatedPoint = CGPointMake( firstX+translatedPoint.x, firstY+translatedPoint.y);
    
    if( [self.delegate respondsToSelector:@selector(translateFlyingWindowCenterPoint:originalPoint:isDragging:)] )
        translatedPoint = [self.delegate translateFlyingWindowCenterPoint:self originalPoint:translatedPoint isDragging:YES];
    
	[[sender view] setCenter:translatedPoint];
    
	if([(UIPanGestureRecognizer*)sender state] == UIGestureRecognizerStateEnded) {
        
		translatedPoint.x += (.35*[(UIPanGestureRecognizer*)sender velocityInView:self.view.superview].x);
        
        CGPoint center = CGPointMake( lroundf( translatedPoint.x ), translatedPoint.y );
        
        if( [self.delegate respondsToSelector:@selector(translateFlyingWindowCenterPoint:originalPoint:isDragging:)] )
            center = [self.delegate translateFlyingWindowCenterPoint:self originalPoint:center isDragging:NO];
        
		[self slideFlyingWindowToPoint:center];
        
        if( [self.delegate respondsToSelector:@selector(flyingWindowDidMove:)] )
            [self.delegate flyingWindowDidMove:self];
	}
}

- (CGPoint) originPoint {
    return CGPointMake( firstX, firstY );
}

- (void) slideFlyingWindowToPoint:(CGPoint)point {    
    point.x = lroundf( point.x );
    
    if( CGPointEqualToPoint( point, self.view.center ) )
        return;
        
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:.35];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    [[self view] setCenter:point];
    /*[self setDimmerAlpha:0];
    
    if( self.leftFWC ) {
         CGRect overlap = CGRectIntersection( self.view.frame, self.leftFWC.view.frame );
         float perc = overlap.size.width / self.leftFWC.view.frame.size.width;
         [self.leftFWC setDimmerAlpha:perc];
    }*/
    
    [UIView commitAnimations];
}

- (void) selectAccount:(NSDictionary *) acc {   
    if( acc )
        self.account = acc;
    
    // implement me in functions using this interface
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void) viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidUnload {       
    [super viewDidUnload];
}

- (void)dealloc {    
    [navBar release];
    [account release];

    [super dealloc];
}

@end
