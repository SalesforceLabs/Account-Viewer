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

#import "AccountAddEditController.h"
#import "PRPSmartTableViewCell.h"
#import "TextCell.h"
#import "AccountUtil.h"

// YES - new account
// NO - editing existing account
BOOL isNewAccount = YES;

// START:TableSections
enum AccountTableSections {
    AccountTableSectionBasics = 0,
    AccountTableSectionAddress,
    AccountTableSectionDetail,
    AccountTableNumSections,
};
// END:TableSections

// START:TableRows
enum AccountTableBasicsRows {
    Name = 0,
    Industry,
    Phone,
    Website,
    AccountTableBasicsNumRows,
};

enum AccountTableAddressRows {
    MailingStreet = 0,
    MailingCity,
    MailingState,
    MailingPostalCode,
    MailingCountry,
    AccountTableAddressNumRows,
};

enum AccountTableDetailRows {
    AnnualRevenue = 0,
    TickerSymbol,
    Employees,
    Fax,
    Description,
    AccountTableDetailNumRows,
};
// END:TableRows

@implementation AccountAddEditController

@synthesize saveButton, fields, delegate;

- (BOOL) isNewAccount {
    return isNewAccount;
}

- (id) init {
    if(( self = [super initWithStyle:UITableViewStyleGrouped] )) {
        self.title = NSLocalizedString(@"New Account", @"Creating a new account");
        isNewAccount = YES;
        
        if( !self.saveButton ) {
            self.saveButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                      target:self
                                                                                      action:@selector(save)] autorelease];
            saveButton.style = UIBarButtonItemStyleDone;
            saveButton.enabled = NO;
        }
        
        self.navigationItem.rightBarButtonItem = self.saveButton;
        
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                      target:self
                                                                                      action:@selector(cancel)];
        self.navigationItem.leftBarButtonItem = cancelButton;
        [cancelButton release];
        
        fields = [[NSMutableDictionary alloc] init];
        textFields = [[NSMutableDictionary alloc] init];
        
        self.tableView.canCancelContentTouches = YES;
    }
    
    return self;
}

- (id) initWithAccount:(NSDictionary *)account {
    if(( self = [self init] )) {
        fields = [[NSMutableDictionary alloc] initWithDictionary:account];
        isNewAccount = NO;
        saveButton.enabled = YES;
        self.title = [NSString stringWithFormat:@"%@: %@", 
                      NSLocalizedString( @"Edit Account", @"Editing an account" ),
                      [account objectForKey:@"Name"]];
    }
    
    return self;
}

- (void) cancel {
    // Notify our delegate of a cancel
    if ([self.delegate respondsToSelector:@selector(accountDidCancel:)]) {
        [self.delegate accountDidCancel:self];
    }   
}

- (void) save {
    // Ensure a name has been set.
    if( ![fields objectForKey:@"Name"] ) {
        saveButton.enabled = NO;
        return;
    }
    
    int newID = [[AccountUtil getNextAccountId] intValue];
    [AccountUtil upsertAccount:fields];
    [fields setObject:[NSString stringWithFormat:@"%i", newID] forKey:@"Id"];
    
    if ([self.delegate respondsToSelector:@selector(accountDidUpsert:)]) {
        [self.delegate accountDidUpsert:self];
    }
}

- (void) viewDidLoad {
    [super viewDidLoad];
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch( section ) {
        case AccountTableSectionBasics:
            return NSLocalizedString(@"Account Basics", @"Account basics section");
        case AccountTableSectionAddress:
            return NSLocalizedString(@"Account Address", @"Account address section");
        case AccountTableSectionDetail:
            return NSLocalizedString(@"Account Detail", @"Account detail section");
        default:
            NSLog(@"Unexpected section (%d)", section);
            break;
    }
    
    return nil;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // START:NumRows
    switch (section) {
        case AccountTableSectionBasics:
            return AccountTableBasicsNumRows;
        case AccountTableSectionAddress:
            return AccountTableAddressNumRows;
        case AccountTableSectionDetail:
            return AccountTableDetailNumRows;
        default:
            NSLog(@"Unexpected section (%d)", section);
            break;
    }
    // END:NumRows
    return 0;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return AccountTableNumSections;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TextCell *cell = [TextCell cellForTableView:tableView];
    cell.textField.text = @"";
    cell.textField.placeholder = @"";
    
    switch( indexPath.section ) {
        case AccountTableSectionBasics:            
            switch( indexPath.row ) {
                case Name:
                    cell.fieldName = @"Name";
                    cell.textField.placeholder = NSLocalizedString( @"Required", @"Required field" );
                    cell.validationType = ValidateAlphaNumeric;
                    break;
                case Phone:
                    cell.fieldName = @"Phone";
                    [cell setKeyboardType:UIKeyboardTypePhonePad];
                    cell.validationType = ValidatePhone;
                    break;
                case Industry:
                    cell.fieldName = @"Industry";
                    cell.validationType = ValidateAlphaNumeric;
                    break;
                case Website:
                    cell.fieldName = @"Website";
                    [cell setKeyboardType:UIKeyboardTypeURL];
                    cell.validationType = ValidateURL;
                    break;
            }
            
            break;
        case AccountTableSectionAddress:           
            switch( indexPath.row ) {
                case MailingStreet:
                    cell.fieldName = @"Street";
                    cell.validationType = ValidateAlphaNumeric;
                    break;
                case MailingCity:
                    cell.fieldName = @"City";
                    cell.validationType = ValidateAlphaNumeric;
                    break;
                case MailingState:
                    cell.fieldName = @"State";
                    cell.validationType = ValidateAlphaNumeric;
                    break;
                case MailingPostalCode:
                    cell.fieldName = @"Postal Code";
                    [cell setKeyboardType:UIKeyboardTypeNumberPad];
                    cell.validationType = ValidateAlphaNumeric;
                    break;
                case MailingCountry:
                    cell.fieldName = @"Country";
                    cell.validationType = ValidateAlphaNumeric;
                    break;
            }
            
            break;
        case AccountTableSectionDetail:            
            switch( indexPath.row ) {
                case AnnualRevenue:
                    cell.fieldName = @"Annual Revenue";
                    [cell setKeyboardType:UIKeyboardTypeDecimalPad];
                    cell.validationType = ValidateDecimal;
                    break;
                case Employees:
                    cell.fieldName = @"Employees";
                    [cell setKeyboardType:UIKeyboardTypeNumberPad];
                    cell.validationType = ValidateInteger;
                    break;
                case TickerSymbol:
                    cell.fieldName = @"Ticker Symbol";
                    cell.validationType = ValidateAlphaNumeric;
                    break;
                case Fax:
                    cell.fieldName = @"Fax";
                    cell.validationType = ValidatePhone;
                    [cell setKeyboardType:UIKeyboardTypePhonePad];
                    break;
                case Description:
                    cell.fieldName = @"Description";
                    cell.validationType = ValidateAlphaNumeric;
                    break;
                default:
                    cell.fieldName = @"Unknown";
                    break;
            }
            
            break;
        default:
            break;
    }
    
    cell.textLabel.text = NSLocalizedString( cell.fieldName, @"account fields" );
    cell.fieldLabel = cell.textLabel.text;
    cell.accountAddEditController = self;
    
    // Add a blank entry for this field if it's not empty
    NSString *field = [cell.fieldName stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    if( ![fields objectForKey:field] )
        [fields setObject:@"" forKey:field];
    else
        cell.textField.text = [fields objectForKey:field];
    
    // save this textfield into our dictionary
    [textFields setValue:cell.textField forKey:[NSString stringWithFormat:@"%i%i", indexPath.section, indexPath.row]];
    
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {    
    NSString *key = [NSString stringWithFormat:@"%i%i", indexPath.section, indexPath.row];
    
    if( [textFields objectForKey:key] )
        [(UITextField *)[textFields objectForKey:key] becomeFirstResponder];
}

- (void) textFieldValueChanged:(UITableViewCell *)cell field:(UITextField *)textField {    
    // Save the value in this field
    NSString *value = [AccountUtil trimWhiteSpaceFromString:textField.text];
            
    [fields setObject:value forKey:[((TextCell *)cell).fieldName stringByReplacingOccurrencesOfString:@" " withString:@""]];
    
    // Is there a value for our name field?    
    if( ![AccountUtil isEmpty:[fields objectForKey:@"Name"]] ) {
        [saveButton setEnabled:YES];
        self.title = [NSString stringWithFormat:@"%@: %@", 
                      ( isNewAccount ? NSLocalizedString(@"New Account", @"New Account action") : NSLocalizedString(@"Edit Account", @"Edit Account action") ),
                      [fields objectForKey:@"Name"]];
    } else {
        [saveButton setEnabled:NO];
        self.title = [NSString stringWithFormat:@"%@",
                      ( isNewAccount ? NSLocalizedString(@"New Account", @"New Account action") : NSLocalizedString(@"Edit Account", @"Edit Account action") )];
    }
    
    // Notify our delegate
    if ([self.delegate respondsToSelector:@selector(accountFieldDidChange:textField:)]) {
        [self.delegate accountFieldDidChange:self textField:textField];
    }
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (void) dealloc {
    [fields release];
    [textFields release];
    [saveButton release];
    [super dealloc];
}

@end