//
//  DropboxFileViewController.m
//  MyKeePass
//
//  Created by Jose Ramon Roca on 07/05/11.
//  Copyright 2011 -. All rights reserved.
//

#import "DropboxFileViewController.h"
#import "DropboxSDK.h"
#import "FileViewController.h"
#import "MyKeePassAppDelegate.h"

@interface DropboxFileViewController(PrivateMethods)
-(IBAction)cancelClicked:(id)sender;
-(void)updateTable;
- (void)setWorking:(BOOL)isWorking;
-(void)configureCell:(UITableViewCell*) cell indexPath:(NSIndexPath *)indexPath;
@end


@implementation DropboxFileViewController

#define TYPE_DIR "D"
#define TYPE_FILE "F"

#define DROPBOX_ARRAY_TYPE 0
#define DROPBOX_ARRAY_PATH 1

@synthesize tableView;
@synthesize restClient;
@synthesize dropBoxContents;
@synthesize activityIndicator;
@synthesize currentPath;
@synthesize dropboxFileSubViewController;

- (void)dealloc
{
    [restClient release];
    [dropBoxContents release];
    [activityIndicator release];
    [currentPath release];
    [dropboxFileSubViewController release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    //DBLoginController* controller = [[DBLoginController new] autorelease];
    //[controller presentFromController:self];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
	self.navigationItem.title = NSLocalizedString(@"New Dropbox File", @"New Dropbox File");
	
	UIBarButtonItem * cancel = [[UIBarButtonItem alloc]initWithTitle:NSLocalizedString(@"Cancel", @"Cancel") 
															   style:UIBarButtonItemStylePlain target:self action:@selector(cancelClicked:)];
	self.navigationItem.rightBarButtonItem = cancel;
	[cancel release];
	
    /*
	UIBarButtonItem * done = [[UIBarButtonItem alloc]initWithTitle:NSLocalizedString(@"Done", @"Done") 
															 style:UIBarButtonItemStyleDone target:self action:@selector(doneClicked:)];
	self.navigationItem.rightBarButtonItem = done;
	[done release];
    */
    dropBoxContents = [NSMutableArray new];
    if (currentPath == nil) {
        currentPath = @"/";
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (![[DBSession sharedSession] isLinked]) {
        DBLoginController* controller = [[DBLoginController new] autorelease];
        controller.delegate = self;
        [controller presentFromController:self];
    }
    else
    {
        [self updateTable];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [dropBoxContents count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell...
    [self configureCell:cell indexPath:indexPath];
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    NSMutableArray *aAux = [dropBoxContents objectAtIndex:indexPath.row];
    if ([[aAux objectAtIndex:DROPBOX_ARRAY_TYPE] isEqualToString:@"D"]) {
        if (dropboxFileSubViewController == nil) {
        DropboxFileViewController *dropBoxViewController = [[DropboxFileViewController alloc] initWithNibName:@"DropboxFileView" bundle:nil];
            self.dropboxFileSubViewController = dropBoxViewController;
            [dropBoxViewController release];
        } 
        dropboxFileSubViewController.currentPath = [aAux objectAtIndex:DROPBOX_ARRAY_PATH];
        [[self navigationController] pushViewController:self.dropboxFileSubViewController animated:YES];
    }
    else {
        NSString *path = [aAux objectAtIndex:DROPBOX_ARRAY_PATH];
        NSString *url = [NSString stringWithFormat:@"dropbox://%@", [path substringWithRange:NSMakeRange(1, [path length]-1)]];
        NSString *name = [[aAux objectAtIndex:DROPBOX_ARRAY_PATH] lastPathComponent];
        if([[MyKeePassAppDelegate delegate]._fileManager getURLForRemoteFile:name]) {
            UIAlertView * alert = [[UIAlertView alloc]initWithTitle:nil 
                                                            message:NSLocalizedString(@"A same name already exists", @"Name already exisits") delegate:nil 
                                                  cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                                                  otherButtonTitles:nil];	
            [alert show];
            [alert release];       
        }
        else {
            [[MyKeePassAppDelegate delegate]._fileManager addRemoteFile:name Url:url];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DismissModalViewOK" object:self];
        }
    }
}

#pragma mark DBLoginControllerDelegate methods

- (void)loginControllerDidLogin:(DBLoginController*)controller {
    [self updateTable];
}

- (void)loginControllerDidCancel:(DBLoginController*)controller {
    [self cancelClicked:nil];
}

#pragma mark DBRestClient

- (DBRestClient*)restClient {
    if (!restClient) {
        restClient = 
        [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        restClient.delegate = self;
    }
    return restClient;
}


#pragma mark DBRestClientDelegate methods

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata {
    
    NSArray *validExtensions = [NSArray arrayWithObjects:@"kdb", @"kdbx", nil];
    NSMutableArray *aAux;
    [dropBoxContents release];
    dropBoxContents = [NSMutableArray new];
    
    for (DBMetadata *child in metadata.contents) {
        if (child.isDirectory) {
            aAux = [[NSMutableArray alloc] init];
            [aAux autorelease];
            [aAux insertObject:@"D" atIndex:DROPBOX_ARRAY_TYPE];
            [aAux insertObject:child.path atIndex:DROPBOX_ARRAY_PATH];
            [dropBoxContents addObject:aAux];
        }
        else {
            NSString* extension = [[child.path pathExtension] lowercaseString];
            if ([validExtensions indexOfObject:extension] != NSNotFound) {
                aAux = [[NSMutableArray alloc] init];
                [aAux autorelease];
                [aAux insertObject:@"F" atIndex:DROPBOX_ARRAY_TYPE];
                [aAux insertObject:child.path atIndex:DROPBOX_ARRAY_PATH];
                [dropBoxContents addObject:aAux];
            }
        }
    }
    [self setWorking:NO];
    [[self tableView] reloadData];
}

- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path {
    
    NSLog(@"Metadata unchanged!");
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error {
#warning Need to handle errors.
    NSLog(@"Error loading metadata: %@", error);
}

#pragma mark - Private Methods

-(IBAction)cancelClicked:(id)sender{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DismissModalViewCancel" object:self];
}

-(void)updateTable {
    [self setWorking:YES];
    [[self restClient] loadMetadata:currentPath];    
}

-(void)setWorking:(BOOL)isWorking {
    if (working == isWorking) return;
    working = isWorking;
    
    if (working) {
        [activityIndicator startAnimating];
    } else { 
        [activityIndicator stopAnimating];
    }
}

-(void)configureCell:(UITableViewCell*) cell indexPath:(NSIndexPath *)indexPath {
    NSMutableArray *aAux = [dropBoxContents objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [[aAux objectAtIndex:DROPBOX_ARRAY_PATH] lastPathComponent];
    if ([[aAux objectAtIndex:DROPBOX_ARRAY_TYPE] isEqualToString:@"D"]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    else {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
}

@end
