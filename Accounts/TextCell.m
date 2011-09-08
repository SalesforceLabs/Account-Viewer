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

#import "TextCell.h"
#import "AccountAddEditController.h"
#import "AccountUtil.h"

@implementation TextCell

@synthesize textField, accountAddEditController, fieldLabel, validationType, fieldName;

static int maxCharacters = 255;

- (void)dealloc {
    [textField release], textField = nil;
    [fieldLabel release], fieldLabel = nil;
    [fieldName release], fieldName = nil;
    [super dealloc];
}

- (id)initWithCellIdentifier:(NSString *)cellID {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.textLabel.textColor = [UIColor darkGrayColor];
        self.textLabel.adjustsFontSizeToFitWidth = YES;
        self.textLabel.textAlignment = UITextAlignmentRight;
        
        self.textField = [[[UITextField alloc] initWithFrame:CGRectMake(50, self.textLabel.frame.origin.y, 310, 22)] autorelease];
        textField.delegate = self;
        textField.textAlignment = UITextAlignmentLeft;
        textField.returnKeyType = UIReturnKeyDone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.clearsOnBeginEditing = NO;
        textField.textColor = RGB( 57.0f, 85.0f, 135.0f );
        
        [textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        
        [textField addTarget:self
                      action:@selector(textFieldFinished:)
            forControlEvents:UIControlEventEditingDidEndOnExit];
        
        self.accessoryView = self.textField;
    }
    
    return self;
}

- (void) setKeyboardType:(UIKeyboardType)type {
    [textField setKeyboardType:type];
}

- (void) textFieldDidChange:(id)sender {
    [self.accountAddEditController textFieldValueChanged:self field:sender];
}

- (void) textFieldDidEndEditing:(UITextField *)tf {
    [tf resignFirstResponder];
    [self.accountAddEditController textFieldValueChanged:self field:tf];
}

- (BOOL) textFieldShouldReturn:(UITextField *)tf {
    [tf resignFirstResponder];
    
    [self.accountAddEditController textFieldValueChanged:self field:tf];
    
    return YES;
}

- (void) textFieldFinished:(id)sender {
    [sender resignFirstResponder];
}

- (BOOL)textField:(UITextField *)tf shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {    
    if( range.location >= maxCharacters )
        return NO;
    
    if( !validationType || validationType == ValidateNone )
        return YES;
    
    NSMutableCharacterSet *validChars = nil;
    
    switch( validationType ) {
        case ValidateAlphaNumeric:
            validChars = [NSMutableCharacterSet alphanumericCharacterSet];
            [validChars formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
            [validChars formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
            break;
        case ValidateInteger:
        case ValidatePhone:
            validChars = [NSMutableCharacterSet characterSetWithCharactersInString:@"0123456789"];
            break;
        case ValidateZipCode:
            validChars = [NSMutableCharacterSet characterSetWithCharactersInString:@"0123456789-"];
            break;
        case ValidateDecimal:
            validChars = [NSMutableCharacterSet characterSetWithCharactersInString:@"0123456789.,"];
            break;
        case ValidateURL:
            validChars = [NSMutableCharacterSet alphanumericCharacterSet];
            [validChars formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
            break;
             
        default: break;
    }
    
    // Formats to (XXX) XXX-XXXX
    if( validationType == ValidatePhone ) {
        int length = [self getLength:tf.text];
        
        if(length == 10) {
            if(range.length == 0)
                return NO;
        } else if(length == 3) {
            NSString *num = [self formatNumber:tf.text];
            tf.text = [NSString stringWithFormat:@"(%@) ",num];
            if(range.length > 0)
                textField.text = [NSString stringWithFormat:@"%@",[num substringToIndex:3]];
        } else if(length == 6) {
            NSString *num = [self formatNumber:tf.text];
            tf.text = [NSString stringWithFormat:@"(%@) %@-",[num  substringToIndex:3],[num substringFromIndex:3]];
            if(range.length > 0)
                tf.text = [NSString stringWithFormat:@"(%@) %@",[num substringToIndex:3],[num substringFromIndex:3]];
        }
    }
    
    if( !validChars )
        return YES;
    
    NSCharacterSet *unacceptedInput = [validChars invertedSet];
    
    string = [[string lowercaseString] decomposedStringWithCanonicalMapping];
    
    return [[string componentsSeparatedByCharactersInSet:unacceptedInput] count] == 1;
}

// http://stackoverflow.com/questions/6052966/phone-number-validation-formatting-on-iphone-ios
- (NSString*)formatNumber:(NSString*)mobileNumber {
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@"(" withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@")" withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@" " withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@"-" withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@"+" withString:@""];
        
    int length = [mobileNumber length];
    if(length > 10)
    {
        mobileNumber = [mobileNumber substringFromIndex: length-10];
    }

    return mobileNumber;
}


- (int) getLength:(NSString*)mobileNumber {
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@"(" withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@")" withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@" " withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@"-" withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@"+" withString:@""];
    
    int length = [mobileNumber length];
    
    return length;
}

@end