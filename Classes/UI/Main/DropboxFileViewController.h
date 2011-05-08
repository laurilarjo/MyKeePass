//
//  DropboxFileViewController.h
//  MyKeePass
//
//  Created by Jose Ramon Roca on 07/05/11.
//  Copyright 2011 -. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DropboxSDK.h"

@class DBRestClient;

@interface DropboxFileViewController : UIViewController <DBRestClientDelegate, DBLoginControllerDelegate, UITableViewDataSource, UITableViewDelegate> {
    UITableView *tableView;
    DBRestClient *restClient;
    NSMutableArray *dropBoxContents;
    UIActivityIndicatorView* activityIndicator;
    BOOL working;
    NSString *currentPath;
    DropboxFileViewController *dropboxFileSubViewController;
}

@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, retain) DBRestClient *restClient;
@property (nonatomic, retain) NSMutableArray *dropBoxContents;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView* activityIndicator;
@property (nonatomic, retain) NSString *currentPath;
@property (nonatomic, retain) DropboxFileViewController *dropboxFileSubViewController;

@end
