//
//  PasswordViewController.m
//  MyKeePass
//
//  Created by Qiang Yu on 3/8/10.
//  Copyright 2010 Qiang Yu. All rights reserved.
//

#import "PasswordViewController.h"
#import "TextFieldCell.h"
#import "MyKeePassAppDelegate.h"
#import "ActivityView.h"
#import "FileManagerOperation.h"
#import "FileManager.h"

@interface PasswordViewController(PrivateMethods)
-(void)showError:(NSString *)message;
@end


@implementation PasswordViewController
@synthesize _filename;
@synthesize _isRemote;
@synthesize _isReopen;
@synthesize _ok;
@synthesize _cancel;
@synthesize _switch;
@synthesize _switchCheckUpdate;
@synthesize _av;
@synthesize _password;
@synthesize _useCache;
@synthesize _checkUpdate;
@synthesize _rusername;
@synthesize _rpassword;
@synthesize _rdomain;
@synthesize _op;

- (id)initWithFileName:(NSString *)fileName remote:(BOOL)isRemote {
	if(self = [super initWithStyle:UITableViewStyleGrouped]){
		self._filename = fileName;
		self._isRemote = isRemote;
		self._isReopen = NO;
		_isLoading = NO;
		_av = [[ActivityView alloc] initWithFrame:CGRectMake(0,0,320,480)];		
	}
    return self;
}

- (void)dealloc {
	self._password._field.delegate = nil;	
	[_filename release];
	[_av release];
	[_password release];
	[_switch release];	
    [_switchCheckUpdate release];
	[_useCache release];
	[_rusername release];
	[_rpassword release];
	[_rdomain release];	
	[_op release];
    [super dealloc];
}

- (void)viewDidAppear:(BOOL)animated { 
	[super viewDidAppear:animated];	
	[_password._field becomeFirstResponder];	
}

-(void)viewDidLoad{
	[super viewDidLoad];	
	_password = [[TextFieldCell alloc] initWithIdentifier:nil]; 
	_password.selectionStyle = UITableViewCellSelectionStyleNone;
	_password._field.secureTextEntry = YES;
	_password._field.placeholder = NSLocalizedString(@"Master Password", @"Master Password");
	_password._field.returnKeyType = UIReturnKeyDone;
	_password._field.delegate = self;
	
	_rusername = [[TextFieldCell alloc] initWithIdentifier:nil];
	_rusername.selectionStyle = UITableViewCellSelectionStyleNone;
	_rusername._field.placeholder = NSLocalizedString(@"Name", @"Name");
	_rusername._field.autocorrectionType = UITextAutocorrectionTypeNo;
	_rusername._field.autocapitalizationType = UITextAutocapitalizationTypeNone;
	
	_rpassword = [[TextFieldCell alloc] initWithIdentifier:nil];
	_rpassword.selectionStyle = UITableViewCellSelectionStyleNone;
	_rpassword._field.secureTextEntry = YES;
	_rpassword._field.placeholder = NSLocalizedString(@"Password", @"Password");
	
	_rdomain = [[TextFieldCell alloc] initWithIdentifier:nil];	
	_rdomain.selectionStyle = UITableViewCellSelectionStyleNone;	
	_rdomain._field.placeholder = NSLocalizedString(@"Domain", @"Domain");
	
	_useCache = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
	_useCache.textLabel.text = NSLocalizedString(@"Use cached file", @"Use cached file");
	_useCache.textLabel.font = [UIFont systemFontOfSize:17];
	_useCache.textLabel.textColor = [UIColor darkGrayColor];
	_useCache.selectionStyle = UITableViewCellSelectionStyleNone;
	
	_checkUpdate = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
	_checkUpdate.textLabel.text = NSLocalizedString(@"Check for update", @"Check for update");
	_checkUpdate.textLabel.font = [UIFont systemFontOfSize:17];
	_checkUpdate.textLabel.textColor = [UIColor darkGrayColor];
	_checkUpdate.selectionStyle = UITableViewCellSelectionStyleNone;

	_switch = [[UISwitch alloc]initWithFrame:CGRectMake(195, 6, 94, 27)];
    [_switch addTarget:self action:@selector(useCacheChanged:) forControlEvents:UIControlEventValueChanged];

    _switch.on = YES;

	_switchCheckUpdate = [[UISwitch alloc]initWithFrame:CGRectMake(195, 6, 94, 27)];
    _switchCheckUpdate.on = NO;

    if (![[MyKeePassAppDelegate delegate]._fileManager bCacheFileExists:_filename]) {
        _switch.on = NO;
        _switch.enabled = NO;
        _switchCheckUpdate.enabled = NO;
    }

	[_useCache.contentView addSubview:_switch];
	[_checkUpdate.contentView addSubview:_switchCheckUpdate];
	
	//set the footer;
	UIView * container = [[UIView alloc]initWithFrame:CGRectMake(0,0,320,44)]; 
	_ok = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	_ok.frame = CGRectMake(11,16,143,50); 
	[_ok setTitle:NSLocalizedString(@"OK", @"OK") forState:UIControlStateNormal];
	
	_cancel = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	_cancel.frame = CGRectMake(165, 16, 143, 50);
	[_cancel setTitle:NSLocalizedString(@"Cancel", @"Cancel") forState:UIControlStateNormal];
	
	[container addSubview:_ok];
	[container addSubview:_cancel];
	
	[_cancel addTarget:self action:@selector(cancelClicked:) forControlEvents:UIControlEventTouchUpInside];
	[_ok addTarget:self action:@selector(okClicked:) forControlEvents:UIControlEventTouchUpInside];	
	
	self.tableView.tableFooterView = container;
	[container release];
}

- (void)viewDidUnload {	
	self._password = nil;
	self._rusername = nil;
	self._rpassword = nil;
	self._rdomain = nil;
	self._useCache = nil;
	self._switch = nil;
	[super viewDidUnload];	
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
	if(section==1){
		return NSLocalizedString(@"Server side authentication", @"Server side authentication");
	}else{
		return [NSLocalizedString(@"Password of File ", @"Password of File") stringByAppendingString:_filename];
	}
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (!_isRemote) {
        return 1;
    }
    else {
        if ([[MyKeePassAppDelegate delegate]._fileManager bIsDropBoxFileName:_filename]){
            return 1;
        }
        else {
            return 2;
        }
    }
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(section==0){
        if (!_isRemote) {
            return 1;
        }
        else {
            if ([[MyKeePassAppDelegate delegate]._fileManager bIsDropBoxFileName:_filename]){
                return 3;
            }
            else {
                return 2;
            }
        }
	}else{
		return 3;
	}
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {    
	if([indexPath section]==0){
        switch ([indexPath row]) {
            case 0:
                return _password;
                break;
            case 1:
                return _useCache;
                break;
            case 2:
                return _checkUpdate;
            default:
                break;
        }
	}else{
		switch ([indexPath row]) {
			case 0:
				return _rusername;
			case 1:
				return _rpassword;
			case 2:
				return _rdomain;
		}
	}
	return nil;
}

-(IBAction)cancelClicked:(id)sender {
	if(!_isReopen){
		[[NSNotificationCenter defaultCenter] postNotificationName:@"DismissModalViewCancel" object:nil];	
	}
	else{
		[[MyKeePassAppDelegate delegate] showMainView];
	}
}

-(IBAction)okClicked:(id)sender{
	if(!_isReopen){
		_ok.enabled = _cancel.enabled = NO;
		if(_isLoading) return;
		_isLoading = YES;
		[self.view addSubview:_av];	
		if(!_op) _op = [[FileManagerOperation alloc]initWithDelegate:self];		
		_op._filename = _filename;				
		_op._password = _password._field.text;
        
		if(!self._isRemote){
			[_op performSelectorInBackground:@selector(openLocalFile) withObject:nil];
		}else{
			_op._useCache = _switch.on;
            _op._checkUpdate = _switchCheckUpdate.on;
			_op._username = _rusername._field.text;
			_op._userpass = _rpassword._field.text;
			_op._domain = _rdomain._field.text;	
            if (![[MyKeePassAppDelegate delegate]._fileManager bIsDropBoxFileName:_filename]) {
                [_op performSelectorInBackground:@selector(openRemoteFile) withObject:nil];
            }
            else {
                [_op openDropboxRemoteFile]; 
            }
		}				
	}else{ // it is reopen, we verify the password directly
		NSString * password = _password._field.text;
		if([password isEqualToString:[MyKeePassAppDelegate delegate]._fileManager._password]){
			[[MyKeePassAppDelegate delegate] showKdb];
		}else{
			[self showError:NSLocalizedString(@"Master password is not correct", @"Master password is not correct")];
		}
	}
}

-(void)fileOperationSuccess{
    _switch.enabled = YES;
    _switch.on = YES;
	[_av removeFromSuperview];	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DismissModalViewOK" object:self];	
}

-(void)fileOperationFailureWithException:(NSException *)exception{
	[_av removeFromSuperview];
	_ok.enabled = _cancel.enabled = YES;
	_isLoading = NO;
    _switch.enabled = YES;
    _switch.on = YES;
	
	if([[exception name] isEqualToString:@"DecryptError"]){
		[self showError:NSLocalizedString(@"Master password is not correct", @"Master password is not correct")];
	}else if([[exception name] hasPrefix:@"Unsupported"]){
		NSString * msg = [[NSString alloc]initWithFormat:NSLocalizedString(@"File is not supported (error code:%@)", @"Unsupported file"),[exception reason],nil];
		[self showError:msg];
		[msg release];
	}else if([[exception name] isEqualToString:@"DownloadError"]){
		[self showError:NSLocalizedString(@"Cannot download the file", @"Cannot download the file")];
	}else if([[exception name] isEqualToString:@"MetadataErrorWithUserInfo"]){
		[self showError:NSLocalizedString(@"Cannot download the file", @"Cannot download the file")];
	}else if([[exception name] isEqualToString:@"DownloadErrorWithUserInfo"]){
		[self showError:[NSString stringWithFormat:@"%@.%@", NSLocalizedString(@"Cannot download the file", @"Cannot download the file"),[[exception userInfo] valueForKey:@"error"]]];
	}else if ([[exception name] isEqualToString:@"RemoteAuthenticationError"]){
		[self showError:NSLocalizedString(@"Server authentication error", @"Server authentication error")];
	}else{
		NSString * msg = [[NSString alloc]initWithFormat:NSLocalizedString(@"Master password might not be correct (error code:%@)", @"Unknown error"),[exception reason],nil];
		[self showError:msg];
		[msg release];
	}
}

-(void)showError:(NSString *)message{
	UIAlertView * alert = [[UIAlertView alloc]initWithTitle:nil 
													message:message delegate:self
										  cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
										  otherButtonTitles:nil];	
	[alert show];
	[alert release];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
	[self okClicked:_ok];
	return NO;
}

-(void)useCacheChanged:(UISwitch *)sender {
    if (!sender.on) {
        _switchCheckUpdate.on = NO;
        _switchCheckUpdate.enabled = NO;
    }
    else {
        _switchCheckUpdate.enabled = YES;
    }
}

@end

