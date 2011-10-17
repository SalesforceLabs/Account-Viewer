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

#import "TextCell.h"
#import "AccountAddEditController.h"
#import "AccountUtil.h"

@implementation TextCell

@synthesize textField, delegate, fieldLabel, validationType, fieldName, cellType, textView;

#pragma mark - setup

- (void)dealloc {
    [textField release], textField = nil;
    [textView release], textView = nil;
    [fieldLabel release], fieldLabel = nil;
    [fieldName release], fieldName = nil;
    [super dealloc];
}

- (id)initWithCellIdentifier:(NSString *)cellID {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.textLabel.textColor = [UIColor darkGrayColor];
        self.textLabel.adjustsFontSizeToFitWidth = NO;
        self.textLabel.textAlignment = UITextAlignmentRight;
        self.textLabel.text = @"";
        self.textLabel.font = [UIFont boldSystemFontOfSize:16];
        
        maxLength = 100;
        maxLabelWidth = 120;
    }
    
    return self;
}

- (void) setTextCellType:(enum TextCellTypes)textCellType {
    self.cellType = textCellType;
            
    if( self.cellType == TextFieldCell && !self.textField ) {
        self.textField = [[[UITextField alloc] initWithFrame:CGRectMake(0, 0, 310, 22)] autorelease];
        textField.delegate = self;
        textField.textAlignment = UITextAlignmentLeft;
        textField.returnKeyType = UIReturnKeyDone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.clearsOnBeginEditing = NO;
        textField.textColor = AppTextCellColor;
        textField.text = @"";
        textField.placeholder = @"";
        textField.font = [UIFont systemFontOfSize:16];
        
        [textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        
        [textField addTarget:self
                      action:@selector(textFieldFinished:)
            forControlEvents:UIControlEventEditingDidEndOnExit];
        
        self.accessoryView = self.textField;
    } else if( self.cellType == TextViewCell && !self.textView ) {
        self.textView = [[[UITextView alloc] initWithFrame:CGRectMake(0, 0, 330, 22)] autorelease];
        textView.delegate = self;
        textView.textAlignment = UITextAlignmentLeft;
        textView.returnKeyType = UIReturnKeyDone;
        textView.autocorrectionType = UITextAutocorrectionTypeNo;
        textView.textColor = AppTextCellColor;
        textView.text = @"";
        textView.font = [UIFont systemFontOfSize:16]; 
        textView.editable = YES;
                
        self.accessoryView = self.textView;
    }
}

- (BOOL) becomeFirstResponder {
    if( self.cellType == TextFieldCell )
        [self.textField becomeFirstResponder];
    else
        [self.textView becomeFirstResponder];
    
    return YES;
}

- (BOOL) resignFirstResponder {
    if( self.cellType == TextFieldCell )
        return [self.textField resignFirstResponder];
    else
        return [self.textView resignFirstResponder];
}

- (void) setKeyboardType:(UIKeyboardType)type {
    if( self.cellType == TextFieldCell )
        [self.textField setKeyboardType:type];
    else
        [self.textView setKeyboardType:type];
}

- (void) setCellText:(NSString *)text {
    if( self.cellType == TextFieldCell )
        self.textField.text = text;
    else
        self.textView.text = text;
}

- (NSString *) getCellText {
    NSString *text = nil;
    
    if( self.cellType == TextFieldCell )
        text = self.textField.text;
    else
        text = self.textView.text;
    
    if( [text length] > maxLength )
        return [text substringToIndex:maxLength];
    
    return text;
}

- (void) setMaxLength:(int) length {
    maxLength = length;
}

- (int) getMaxLength {
    return maxLength;
}

- (void) setMaxLabelWidth:(float)width {
    maxLabelWidth = width;
}

- (BOOL) shouldChangeCharacters:(NSString *)characters range:(NSRange)range replacementString:(NSString *)string {    
    if( range.location >= maxLength || range.location + [string length] >= maxLength )
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
            validChars = [NSMutableCharacterSet characterSetWithCharactersInString:@"0123456789+-() "];
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
    // Removed this so we can support international numbers too
    /*if( validationType == ValidatePhone ) {
        int length = [self getLength:characters];
        
        if(length == 10) {
            if(range.length == 0)
                return NO;
        } else if(length == 3) {
            NSString *num = [self formatNumber:characters];

            [self setCellText:[NSString stringWithFormat:@"(%@) ",num]];
            
            if(range.length > 0)
                [self setCellText:[NSString stringWithFormat:@"%@",[num substringToIndex:3]]];
        } else if(length == 6) {
            NSString *num = [self formatNumber:characters];
            
            [self setCellText:[NSString stringWithFormat:@"(%@) %@-",[num  substringToIndex:3],[num substringFromIndex:3]]];
            
            if(range.length > 0)
                [self setCellText:[NSString stringWithFormat:@"(%@) %@",[num substringToIndex:3],[num substringFromIndex:3]]];
        }
    }*/
    
    if( !validChars )
        return YES;
    
    NSCharacterSet *unacceptedInput = [validChars invertedSet];
    
    string = [[string lowercaseString] decomposedStringWithCanonicalMapping];
    
    return [[string componentsSeparatedByCharactersInSet:unacceptedInput] count] == 1;
}

#pragma mark - textfield delegate

- (void) textFieldDidChange:(id)sender {
    if( [self.delegate respondsToSelector:@selector(textCellValueChanged:)] )
        [self.delegate textCellValueChanged:self];
}

- (void) textFieldDidEndEditing:(UITextField *)tf {
    [self resignFirstResponder];
    
    if( [self.delegate respondsToSelector:@selector(textCellValueChanged:)] )
        [self.delegate textCellValueChanged:self];
}

- (BOOL) textFieldShouldReturn:(UITextField *)tf {
    [self resignFirstResponder];
    
    if( [self.delegate respondsToSelector:@selector(textCellValueChanged:)] )
        [self.delegate textCellValueChanged:self];
    
    return YES;
}

- (void) textFieldFinished:(id)sender {
    [sender resignFirstResponder];
}

- (BOOL)textField:(UITextField *)tf shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {    
    return [self shouldChangeCharacters:tf.text range:range replacementString:string];
}

#pragma mark - textview delegate

- (BOOL)textView:(UITextView *)tv shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if( [text isEqualToString:@"\n"] ) {
        [self textViewDidEndEditing:tv];
        return NO;
    }
    
    return [self shouldChangeCharacters:tv.text range:range replacementString:text];
}

- (void)textViewDidChange:(UITextView *)tv {
    if( [self.delegate respondsToSelector:@selector(textCellValueChanged:)] )
        [self.delegate textCellValueChanged:self];
}

- (void)textViewDidEndEditing:(UITextView *)tv { 
    [self resignFirstResponder];
    
    if( [self.delegate respondsToSelector:@selector(textCellValueChanged:)] )
        [self.delegate textCellValueChanged:self];
}

- (void)textViewDidChangeSelection:(UITextView *)tv {
    if( [self.delegate respondsToSelector:@selector(textCellValueChanged:)] )
        [self.delegate textCellValueChanged:self];
}

#pragma mark - misc

- (void) layoutSubviews {
    [super layoutSubviews];
    
    self.textLabel.frame = CGRectMake( 0, ( self.cellType == TextFieldCell ? 10 : 6 ), maxLabelWidth, 22 );
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