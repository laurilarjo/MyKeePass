//
//  FileManager.m
//  MyKeePass
//
//  Created by Qiang Yu on 3/3/10.
//  Copyright 2010 Qiang Yu. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>

//Keepass2 utils
#import <Utils.h>  

#import "FileManager.h"
#import "ASIHTTPRequest.h"
#import "MyKeePassAppDelegate.h"
#import "ActivityView.h"
#import "DropboxSDK.h"

@interface FileManager(PrivateMethods)
-(id<KdbTree>) readFileHelp:(NSString *) fileName withPassword:(NSString *)password;
@end


@implementation FileManager
@synthesize _kdbReader;
@synthesize _editable;
@synthesize _filename;
@synthesize _password;
@synthesize _dirty;
@synthesize _remoteFiles;
@synthesize _cacheFileName;
@synthesize _restClient;

@synthesize _passwordViewController;

#define KDB_PATH "Passwords"
#define DOWNLOAD_PATH "Download"

#define KDB1_SUFFIX ".kdb"
#define KDB2_SUFFIX ".kdbx"

static NSString * DATA_DIR;
static NSString * DOWNLOAD_DIR;
static NSString * DOWNLOAD_CONFIG;

+(void)initialize{
    if ( self == [FileManager class] ) {
#if TARGET_IPHONE_SIMULATOR_2		
		DATA_DIR = @"/Volumes/Users/qiang/Desktop/";		
		DOWNLOAD_DIR = DATA_DIR;
#else
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		DATA_DIR = [[(NSString *)[paths objectAtIndex:0] stringByAppendingPathComponent:@KDB_PATH] retain];
		DOWNLOAD_DIR = [[(NSString *)[paths objectAtIndex:0] stringByAppendingPathComponent:@DOWNLOAD_PATH] retain];
		NSFileManager * fileManager = [NSFileManager defaultManager];
		if(![fileManager fileExistsAtPath:DATA_DIR]){
			[fileManager createDirectoryAtPath:DATA_DIR withIntermediateDirectories:YES attributes:nil error:nil];
		}		
		if(![fileManager fileExistsAtPath:DOWNLOAD_DIR]){
			[fileManager createDirectoryAtPath:DOWNLOAD_DIR withIntermediateDirectories:YES attributes:nil error:nil];
		}				
#endif
		DOWNLOAD_CONFIG = [[DOWNLOAD_DIR stringByAppendingPathComponent:@".download"] retain];
		if(![[NSFileManager defaultManager] fileExistsAtPath:DOWNLOAD_CONFIG]){
			NSDictionary * dic = [[NSDictionary alloc]init];
			[dic writeToFile:DOWNLOAD_CONFIG atomically:YES];
			[dic release];
		}
	}
}

+(NSString *)dataDir{
	return DATA_DIR;
}

-(id)init{
	if(self = [super init]){
		self._remoteFiles = [NSMutableDictionary dictionaryWithContentsOfFile:DOWNLOAD_CONFIG];
	}	
	return self;
}

-(void)dealloc{
	[_remoteFiles release];
	[_password release];
	[_filename release];
	[_kdbReader release];
	[super dealloc];
}


-(id<KdbTree>) readFile:(NSString *) fileName withPassword:(NSString *)password{
	self._filename = fileName;
	return [self readFileHelp:[FileManager getFullFileName:fileName] withPassword:password];
}

-(id<KdbTree>) readFileHelp:(NSString *) fileName withPassword:(NSString *)password{	
	self._password = password;
	self._dirty = NO;

	WrapperNSData * source = [[WrapperNSData alloc]initWithContentsOfMappedFile:fileName];
	self._kdbReader = nil;
	_kdbReader = [KdbReaderFactory newKdbReader:source];
	//
	// only kdb3 file is editable so far
	//
	_editable = [_kdbReader isKindOfClass:[Kdb3Reader class]];
	[_kdbReader load:source withPassword:password];
	[source release];
	return [_kdbReader getKdbTree];
}

+(NSString *)getTempFileNameFromURL:(NSString *)url{
	ByteBuffer * buffer = [Utils createByteBufferForString:url coding:NSUTF8StringEncoding];
	uint8_t hash[20];
	CC_SHA1(buffer._bytes, buffer._size, hash);
	[buffer release];
	NSString * filename = [NSString  stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
						   hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7], hash[8], hash[9],
						   hash[10], hash[11], hash[12], hash[13], hash[14], hash[15], hash[16], hash[17], hash[18], hash[19], nil];
	
	return [DOWNLOAD_DIR stringByAppendingPathComponent:filename];
}

-(id<KdbTree>) readRemoteFile:(NSString *)filename withPassword:(NSString *)password useCached:(BOOL)useCached username:(NSString *)username userpass:(NSString *)userpass domain:(NSString *)domain{
    id<KdbTree> tree = nil;
	self._filename = filename;
	
    _editable = NO;
	NSString * url = [self getURLForRemoteFile:filename];
		
	if(!url) @throw [NSException exceptionWithName:@"DownloadError" reason:@"DownloadError" userInfo:nil];
	
	NSString * cacheFileName = [FileManager getTempFileNameFromURL:url];
	NSString * tmp = [cacheFileName stringByAppendingString:@".tmp"];
    
    self._cacheFileName = cacheFileName;
	
	NSFileManager * fileManager = [NSFileManager defaultManager];
	
	if([fileManager fileExistsAtPath:cacheFileName]&&useCached){
		id<KdbTree> tree = [self readFileHelp:cacheFileName withPassword:password];
		_editable = NO;
        if ([self bIsDropBoxURL:url]) {
            [self._passwordViewController performSelector:@selector(fileOperationSuccess) withObject:nil];
        }
		return tree;
	}
    
    if (![self bIsDropBoxURL:url]) {
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:url]];
        [request setDownloadDestinationPath:tmp];
        
        if([username length])
            [request setUsername:username];
        if([userpass length])
            [request setPassword:userpass];
        if([domain length])
            [request setDomain:domain];
        
        [request startSynchronous];
        
        int statusCode = [request responseStatusCode];	
        
        if(statusCode!=200){		
            if(statusCode==401){
                @throw [NSException exceptionWithName:@"RemoteAuthenticationError" reason:@"RemoteAuthenticationError" userInfo:nil];
            }else{			
                @throw [NSException exceptionWithName:@"DownloadError" reason:@"DownloadError" userInfo:nil];
            }
        }
        
        [[NSFileManager defaultManager] removeItemAtPath:cacheFileName error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:tmp toPath:cacheFileName error:nil];	
        id<KdbTree> tree = [self readFileHelp:cacheFileName withPassword:password];
        return tree;
    }
    else {
        if (![[DBSession sharedSession] isLinked]) {
            @throw [NSException exceptionWithName:@"RemoteAuthenticationError" reason:@"RemoteAuthenticationError" userInfo:nil];
        }        
        self._password = password;
        NSString *path = [url substringFromIndex:9];
        [[self _restClient] loadFile:path intoPath:tmp];
    }
    return tree;
}

-(void)getKDBFiles:(NSMutableArray *)list{
	[list removeAllObjects];

	//kdb/kdbx files
	NSFileManager * fileManager = [NSFileManager defaultManager];
	NSArray * contents = [fileManager contentsOfDirectoryAtPath:DATA_DIR error:nil];
	for(NSString * fileName in contents){
		if(![fileName hasPrefix:@"."]){
			[list addObject:fileName];
		}
	}
	[list sortUsingSelector:@selector(caseInsensitiveCompare:)];
}

-(void)getRemoteFiles:(NSMutableArray *)list{
	[list removeAllObjects];
	[list addObjectsFromArray:[_remoteFiles keysSortedByValueUsingSelector:@selector(caseInsensitiveCompare:)]];
	[list sortUsingSelector:@selector(compare:)];
}

-(void)addRemoteFile:(NSString *)name Url:(NSString *)url{
	[_remoteFiles setObject:url forKey:name];
	[_remoteFiles writeToFile:DOWNLOAD_CONFIG atomically:YES];	
}

-(NSString *)getURLForRemoteFile:(NSString *)name{
	return [_remoteFiles objectForKey:name];
}

-(void)deleteLocalFile:(NSString *)filename{
	[[NSFileManager defaultManager] removeItemAtPath:[FileManager getFullFileName:filename] error:nil];
}

-(void)deleteRemoteFile:(NSString *)name{
	[_remoteFiles removeObjectForKey:name];
	[_remoteFiles writeToFile:DOWNLOAD_CONFIG atomically:YES];	
}

-(NSUInteger) getKDBVersion{
	if([_kdbReader isKindOfClass:[Kdb3Reader class]]){
		return KDB_VERSION1;
	}else{
		return KDB_VERSION2;
	}
}

-(void)save{
	if(!_dirty) return;
	if([_kdbReader isKindOfClass:[Kdb3Reader class]]){
		Kdb3Writer * writer = nil;
		@try{
			writer = [[Kdb3Writer alloc]init];
			[writer persist:[_kdbReader getKdbTree] file:[FileManager getFullFileName:_filename] withPassword:_password];
			_dirty = NO;
		}@finally {
			[writer release];
		}
	}
}

+(NSString *)getFullFileName:(NSString *)filename{
	return [DATA_DIR stringByAppendingPathComponent:filename];
}

+(void)newKdb3File:(NSString *)filename withPassword:(NSString *)password{
	Kdb3Writer * writer = nil;
	@try{
		writer = [[Kdb3Writer alloc]init];
		[writer newFile:[FileManager getFullFileName:filename] withPassword:password];
	}@finally {
		[writer release];
	}
}

-(BOOL)bIsDropBoxFileName:(NSString *)filename {
    NSString *url = [self getURLForRemoteFile:filename];
    return [self bIsDropBoxURL:url];
}

-(BOOL)bIsDropBoxURL:(NSString *) url {
    if ([url hasPrefix:@"dropbox://"]){
        return YES;
    }
    return NO;
}

#pragma mark DBRestClient

- (DBRestClient*)_restClient {
    if (!_restClient) {
        _restClient = 
        [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        _restClient.delegate = self;
    }
    return _restClient;
}

#pragma mark DBRestClientDelegate methods

/*
 - (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata {
 NSLog(@"loadedMeta");
 }
 
 - (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path {
 
 NSLog(@"Metadata unchanged!");
 }
 
 - (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error {
 
 NSLog(@"Error loading metadata: %@", error);
 }
 */

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath{
    [[NSFileManager defaultManager] removeItemAtPath:self._cacheFileName error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:destPath toPath:self._cacheFileName error:nil];
    @try{
        id<KdbTree> tree = [self readFileHelp:self._cacheFileName withPassword:self._password];
        tree = nil;
        [self._passwordViewController performSelector:@selector(fileOperationSuccess) withObject:nil];        
    }@catch(NSException * exception){
		[self._passwordViewController performSelector:@selector(fileOperationFailureWithException:) withObject:exception];
    }
}
- (void)restClient:(DBRestClient*)client loadProgress:(CGFloat)progress forFile:(NSString*)destPath {
    //NSLog(@"Progress");
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    NSException *exception =  [NSException exceptionWithName:@"DownloadErrorWithUserInfo" reason:@"DownloadError" userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[error localizedDescription],@"error", nil]];
    [self._passwordViewController performSelector:@selector(fileOperationFailureWithException:) withObject:exception];
}

@end
