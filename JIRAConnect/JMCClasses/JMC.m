/**
 Copyright 2011 Atlassian Software
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 **/
#import "JMC.h"
#import "Core/JMCPing.h"
#import "Core/JMCNotifier.h"
#import "Core/JMCCrashSender.h"
#import "JMCCreateIssueDelegate.h"
#import "JMCRequestQueue.h"

@implementation JMCOptions
@synthesize url=_url, projectKey=_projectKey, apiKey=_apiKey,
            photosEnabled=_photosEnabled, voiceEnabled=_voiceEnabled, locationEnabled=_locationEnabled,
            customFields=_customFields;

-(id)init
{
    if ((self = [super init])) {
        _photosEnabled = YES;
        _voiceEnabled = YES;
        _locationEnabled = YES;
    }
    return self;
}

+(id)optionsWithContentsOfFile:(NSString *)filePath
{
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:filePath];
    JMCOptions* options = [[[JMCOptions alloc] init]autorelease];
    options.url = [dict objectForKey:kJMCOptionUrl];
    options.projectKey = [dict objectForKey:kJMCOptionProjectKey];
    options.apiKey = [dict objectForKey:kJMCOptionApiKey];
    options.photosEnabled = [[dict objectForKey:kJMCOptionPhotosEnabled] boolValue];
    options.voiceEnabled = [[dict objectForKey:kJMCOptionVoiceEnabled] boolValue];
    options.locationEnabled = [[dict objectForKey:kJMCOptionLocationEnabled] boolValue];
    options.customFields = [dict objectForKey:kJMCOptionCustomFields];
    return options;
}

+(id)optionsWithUrl:(NSString *)jiraUrl
            project:(NSString*)projectKey
             apiKey:(NSString*)apiKey
             photos:(BOOL)photos
              voice:(BOOL)voice
           location:(BOOL)location
       customFields:(NSDictionary*)customFields
{
    JMCOptions* options = [[[JMCOptions alloc] init]autorelease];
    options.url = jiraUrl;
    options.projectKey = projectKey;
    options.apiKey = apiKey;
    options.photosEnabled = photos;
    options.voiceEnabled = voice;
    options.locationEnabled = location;
    options.customFields = customFields;
    return options;
}


-(void) dealloc
{
    self.url = nil;
    self.projectKey = nil;
    self.apiKey = nil;
    self.customFields = nil;
    [super dealloc];
}

@end


@interface JMC ()

@property (nonatomic, retain) JMCPing * _pinger;
@property (nonatomic, retain) JMCNotifier * _notifier;
@property (nonatomic, retain) JMCViewController * _jcController;
@property (nonatomic, retain) UINavigationController* _navController;
@property (nonatomic, retain) JMCCrashSender *_crashSender;
@property (nonatomic, assign) id <JMCCustomDataSource> _customDataSource;
@property (nonatomic, retain) JMCOptions* _options;

@end


@implementation JMC

@synthesize url = _url;
@synthesize _pinger;
@synthesize _notifier;
@synthesize _jcController;
@synthesize _navController;
@synthesize _crashSender;
@synthesize _customDataSource;
@synthesize _options;

+ (JMC *)instance
{
    static JMC *singleton = nil;
    
    if (singleton == nil) {
        singleton = [[JMC alloc] init];
    }
    return singleton;
}

- (id)init
{
    if ((self = [super init])) {
        self._pinger = [[[JMCPing alloc] init] autorelease ];
        self._crashSender = [[[JMCCrashSender alloc] init] autorelease ];
        self._jcController = [[[JMCViewController alloc] initWithNibName:@"JMCViewController" bundle:nil] autorelease ];
        self._navController = [[[UINavigationController alloc] initWithRootViewController:_jcController] autorelease ];
        _navController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
    }
    return self;
}

- (void)dealloc
{
    self.url = nil;
    [_pinger release];
    [_notifier release];
    [_jcController release];
    [_navController release];
    [_crashSender release];
    [_options release];

    [super dealloc];
}

// TODO: call this when network becomes active after app becomes active
-(void)flushRequestQueue
{
    [[JMCRequestQueue sharedInstance] flushQueue];
}


- (void)generateAndStoreUUID
{
    // generate and store a UUID if none exists already
    if ([self getUUID] == nil) {
        
        NSString *uuid = nil;
        CFUUIDRef theUUID = CFUUIDCreate(kCFAllocatorDefault);
        if (theUUID) {
            uuid = NSMakeCollectable(CFUUIDCreateString(kCFAllocatorDefault, theUUID));
            CFRelease(theUUID);
            [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:kJIRAConnectUUID];
            CFRelease(uuid);
        }
    }
}

- (void) configureJiraConnect:(NSString*) withUrl projectKey:(NSString*)project apiKey:(NSString *)apiKey
{
    JMCOptions *options = [[JMCOptions alloc]init];
    options.url = withUrl;
    options.projectKey = project;
    options.apiKey = apiKey;
    [self configureWithOptions:options];
    [options release];
}

- (void) configureJiraConnect:(NSString*) withUrl
                   projectKey:(NSString*)project
                       apiKey:(NSString *)apiKey
                   dataSource:(id<JMCCustomDataSource>)customDataSource
{
    JMCOptions *options = [[JMCOptions alloc]init];
    options.url = withUrl;
    options.projectKey = project;
    options.apiKey = apiKey;
    [self configureWithOptions:options dataSource:customDataSource];
    [options release];
}

- (void) configureWithOptions:(JMCOptions*)options
{
    [self configureWithOptions:options dataSource:nil];
}

- (void) configureWithOptions:(JMCOptions*)options dataSource:(id<JMCCustomDataSource>)customDataSource
{
    self._options = options;
    [self configureJiraConnect:options.url customDataSource:customDataSource];
}

- (void)configureJiraConnect:(NSString *)withUrl customDataSource:(id <JMCCustomDataSource>)customDataSource
{
    [CrashReporter enableCrashReporter];
    if (!self._options) {
        self._options = [[[JMCOptions alloc] init] autorelease];
    }

    unichar lastChar = [withUrl characterAtIndex:[withUrl length] - 1];
    // if the lastChar is not a /, then add a /
    NSString* charToAppend = lastChar != '/' ? @"/" : @"";
    withUrl = [withUrl stringByAppendingString:charToAppend];
    self.url = [NSURL URLWithString:withUrl];
    
    [self generateAndStoreUUID];

    _pinger.baseUrl = self.url;

    _customDataSource = customDataSource;
    [_customDataSource retain];
    _jcController.payloadDataSource = _customDataSource;

    JMCIssuesViewController *issuesController = [[JMCIssuesViewController alloc] initWithStyle:UITableViewStylePlain];
    JMCNotifier* notifier = [[JMCNotifier alloc] initWithIssuesViewController:issuesController];
    self._notifier = notifier;
    [issuesController release];
    [notifier release];

    // TODO: firing this when network becomes active could be better
    [NSTimer scheduledTimerWithTimeInterval:3 target:_crashSender selector:@selector(promptThenMaybeSendCrashReports) userInfo:nil repeats:NO];
    // whenever the Application Becomes Active, ping for notifications from JIRA.
    [[NSNotificationCenter defaultCenter] addObserver:_pinger selector:@selector(start) name:UIApplicationDidBecomeActiveNotification object:nil];
    NSLog(@"JIRA Mobile Connect is configured with url: %@", withUrl);
}

- (UIViewController *)viewController
{
    return _navController;
}

- (UIViewController *)issuesViewController
{
    [_notifier populateIssuesViewController];
    return _notifier.viewController;
}

- (NSDictionary *)getMetaData
{
    UIDevice *device = [UIDevice currentDevice];
    NSDictionary *appMetaData = [[NSBundle mainBundle] infoDictionary];
    NSMutableDictionary *info = [[[NSMutableDictionary alloc] initWithCapacity:10] autorelease];
    
    // add device data
    [info setObject:[device uniqueIdentifier] forKey:@"udid"];
    [info setObject:[self getUUID] forKey:@"uuid"];
    [info setObject:[device name] forKey:@"devName"];
    [info setObject:[device systemName] forKey:@"systemName"];
    [info setObject:[device systemVersion] forKey:@"systemVersion"];
    [info setObject:[device model] forKey:@"model"];
    
    
    // app application data 
    NSString* bundleVersion = [appMetaData objectForKey:@"CFBundleVersion"];
    NSString* bundleName = [appMetaData objectForKey:@"CFBundleName"];
    NSString* bundleId = [appMetaData objectForKey:@"CFBundleIdentifier"];
    if (bundleVersion) [info setObject:bundleVersion forKey:@"appVersion"];
    if (bundleName) [info setObject:bundleName forKey:@"appName"];
    if (bundleId) [info setObject:bundleId forKey:@"appId"];
    
    return info;
}

- (NSString *)getAppName
{
    return [[self getMetaData] objectForKey:@"appName"];
}

- (NSString *)getUUID
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:kJIRAConnectUUID];
}

- (NSString *) getAPIVersion
{
    return @"1.0"; // TODO: pull this from a map. make it a config, etc..
}

- (NSString *)getProject
{
    if ([_customDataSource respondsToSelector:@selector(project)]) {
        return [_customDataSource project]; // for backward compatibility with the beta... deprecated
    }
    if (self._options.projectKey != nil) {
        return self._options.projectKey;
    }
    return [self getAppName];
}


-(NSMutableDictionary *)getCustomFields
{
    NSMutableDictionary *customFields = [[[NSMutableDictionary alloc] init] autorelease];
    if ([_customDataSource respondsToSelector:@selector(customFields)]) {
        [customFields addEntriesFromDictionary:[_customDataSource customFields]];
    }
    if (_options.customFields) {
        [customFields addEntriesFromDictionary:_options.customFields];
    }
    return customFields;
}

-(NSString *)getApiKey
{
    return _options.apiKey ? _options.apiKey : @"";
}

- (BOOL)isPhotosEnabled {
    return _options.photosEnabled;
}

- (BOOL)isLocationEnabled {
    return _options.locationEnabled;
}

- (BOOL)isVoiceEnabled {
    return _options.voiceEnabled && [JMCRecorder audioRecordingIsAvailable]; // only enabled if device supports audio input
}

-(NSString*) issueTypeNameFor:(JMCIssueType)type useDefault:(NSString *)defaultType {
    if (([_customDataSource respondsToSelector:@selector(jiraIssueTypeNameFor:)])) {
        NSString * typeName = [_customDataSource jiraIssueTypeNameFor:type];
        if (typeName != nil) {
            return typeName;
        }
    }
    return defaultType;
}

@end
