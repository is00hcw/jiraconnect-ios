//
//  Created by nick on 20/09/11.
//
//  To change this template use File | Settings | File Templates.
//


#import "JMCRequestQueue.h"
#import "JMCIssueTransport.h"
#import "JMCReplyTransport.h"
#import "JMCCreateIssueDelegate.h"
#import "JMCReplyDelegate.h"

static NSOperationQueue *sharedOperationQueue = nil;

#define KEY_NUM_ATTEMPTS @"numAttempts"
#define KEY_SENT_STATUS @"sentStatus"

@interface JMCRequestQueue ()
- (NSString *)getQueueIndexPath;

- (NSString *)getQueueDirPath;

- (NSString *)getQueueItemPathFor:(NSString *)uuid;

- (void)saveQueueIndex:(NSMutableDictionary *)queueList;

- (NSMutableDictionary *)getQueueList;

@end

JMCIssueTransport* _issueTransport;
JMCReplyTransport* _replyTransport;
NSRecursiveLock* _flushLock;

@implementation JMCRequestQueue {

}

+ (JMCRequestQueue *)sharedInstance
{
    static JMCRequestQueue *instance = nil;
    if (instance == nil) {
        instance = [[JMCRequestQueue alloc] init];
        sharedOperationQueue = [[NSOperationQueue alloc] init];
        [sharedOperationQueue setMaxConcurrentOperationCount:1];
        _issueTransport = [[JMCIssueTransport alloc] init];
        _replyTransport = [[JMCReplyTransport alloc] init];
        _issueTransport.delegate = [[[JMCCreateIssueDelegate alloc]init] autorelease];
        _replyTransport.delegate = [[[JMCReplyDelegate alloc] init] autorelease];
        _flushLock = [[NSRecursiveLock alloc] init];
        NSLog(@"queue at  %@", [instance getQueueIndexPath]);

    }
    return instance;
}

-(void) flushQueue
{
    @synchronized (_flushLock) { // Ensure a single thread at a time tries to flush the queue.
        JMCRequestQueue *requestQueue = [JMCRequestQueue sharedInstance];
        NSMutableDictionary *items = [requestQueue getQueueList];
        for (NSString *itemId in [items allKeys]) {
            JMCQueueItem *item = [requestQueue getItem:itemId];
            NSOperation *operation = nil;
            if ([item.type isEqualToString:kTypeReply]) {
                operation = [_replyTransport requestFromItem:item];
            } else if ([item.type isEqualToString:kTypeCreate]) {
                operation = [_issueTransport requestFromItem:item];
            }
            if (operation == nil) {
                NSLog(@"Missing or invalid queued item with id: %@. Removing from queue.", itemId);
                [requestQueue deleteItem:itemId];
            } else {
                [sharedOperationQueue addOperation:operation];
                NSLog(@"Added request to operation queue %@", item.uuid);
            }
        }
    }
}

-(JMCSentStatus) requestStatusFor:(NSString *)uuid
{
    NSMutableDictionary *queueIndex = [self getQueueList];
    NSDictionary *metadata = [queueIndex objectForKey:uuid];
    if (!metadata) {
        // no news, is good news! means the message was sent.
        return JMCSentStatusSuccess;
    }
    NSNumber *status = [metadata objectForKey:KEY_SENT_STATUS];
    return status.intValue;
}

-(void)updateItem:(NSString *)uuid sentStatus:(JMCSentStatus)sentStatus bumpNumAttemptsBy:(int)inc
{
    @synchronized (_flushLock) {
        // get the index, set the sent status, save the index
        NSMutableDictionary *queueIndex = [self getQueueList];
        NSMutableDictionary *metadata = [queueIndex objectForKey:uuid];

        [metadata setObject:[NSNumber numberWithInt:sentStatus] forKey:KEY_SENT_STATUS];

        NSNumber *numAttempts = [metadata objectForKey:KEY_NUM_ATTEMPTS];
        [metadata setObject:[NSNumber numberWithInt:numAttempts.intValue + inc] forKey:KEY_NUM_ATTEMPTS];
        [self saveQueueIndex:queueIndex];
    }

}

- (void)addItem:(JMCQueueItem *)item
{
    @synchronized (_flushLock) {
        // get the index, set the metadata, save the index, write the item
        NSMutableDictionary *queueIndex = [self getQueueList];
        NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithCapacity:2];
        [metadata setObject:[NSNumber numberWithInt:JMCSentStatusNew] forKey:KEY_SENT_STATUS];
        [metadata setObject:[NSNumber numberWithInt:0] forKey:KEY_NUM_ATTEMPTS];
        [queueIndex setObject:metadata forKey:item.uuid];
        [self saveQueueIndex:queueIndex];
        // now save the queue item to disc...
        NSString *itemPath = [self getQueueItemPathFor:item.uuid];
        [item writeToFile:itemPath];
    }
}

-(JMCQueueItem *)getItem:(NSString *)uuid
{
    NSString *itemPath = [self getQueueItemPathFor:uuid];
    return [JMCQueueItem queueItemFromFile:itemPath];
}


- (void)saveQueueIndex:(NSMutableDictionary *)queueList
{
    [queueList writeToFile:[self getQueueIndexPath] atomically:YES];
}

- (void)deleteItem:(NSString *)uuid
{
    @synchronized (_flushLock) {
        // get the index, remove the object, save the index, remove the item
        NSMutableDictionary *queue = [self getQueueList];
        [queue removeObjectForKey:uuid];
        [self saveQueueIndex:queue];
        // now remove the queue item from disk
        [[NSFileManager defaultManager] removeItemAtPath:[self getQueueItemPathFor:uuid] error:nil];
    }

}

// This is the actual list of items that need sending
- (NSMutableDictionary *)getQueueList {
    NSMutableDictionary  *queueIndex = [[[NSMutableDictionary dictionaryWithContentsOfFile:[self getQueueIndexPath]] mutableCopy] autorelease];
    if (queueIndex == nil) {
        queueIndex = [NSMutableDictionary dictionary];
    }
    return queueIndex;
}

// The path of the plist that stores a list of request that need resending
- (NSString *)getQueueIndexPath {
    return [[self getQueueDirPath] stringByAppendingPathComponent:@"JMCQueueIndex.plist"];
}

- (NSString *)getQueueItemPathFor:(NSString *)uuid {
    return [[self getQueueDirPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", uuid]];
}

- (NSString *)getQueueDirPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cache = [paths objectAtIndex:0];
    NSString *cachePath = [cache stringByAppendingPathComponent:@"JMC"];

    if (![fileManager fileExistsAtPath:cachePath]) {
        [fileManager createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    return cachePath;
}

-(void) dealloc
{
    [_issueTransport release];
    [_replyTransport release];
    [sharedOperationQueue release];
    [_flushLock release];
    [super dealloc];
}

@end