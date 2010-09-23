//
//  JCSetup.m
//  JiraConnect
//
//  Created by Nicholas Pellow on 21/09/10.
//  Copyright 2010 Nick Pellow. All rights reserved.
//

#import "JCSetup.h"
#import "JCPing.h"
#import "JCCreateViewController.h"
#import "JCLocation.h"
#import "JCNotifier.h"
#import "JCNotifications.h"
#import "JSON.h"


@implementation JCSetup

@synthesize url=_url;

JCPing* _pinger;
JCNotifier* _notifier;
JCNotifications* _notifications;
JCCreateViewController* _jcController;
JCLocation* _location;

-(void) dealloc {
	[_url release]; _url = nil;
	[_pinger release]; _pinger = nil;
	[_notifier release]; _notifier = nil;
	[_notifications release]; _notifications = nil;
	[_jcController release]; _jcController = nil;
	[_location release]; _location = nil;
	[super dealloc];
}

+(JCSetup*) instance {
	static JCSetup *singleton = nil;
	
	if (singleton == nil) {
		singleton = [[JCSetup alloc] init];
	}
	return singleton;
}

- (id)init {
	if (self = [super init]) {
		_notifications = [[[JCNotifications alloc] init] retain];
		_location = [[[JCLocation alloc] init] retain];
		_pinger = [[[JCPing alloc] initWithLocator:_location] retain];
		UIView* window = [[UIApplication sharedApplication] keyWindow];
		_notifier = [[[JCNotifier alloc] initWithView:window notifications:_notifications] retain];
		_jcController = [[[JCCreateViewController alloc] initWithNibName:@"JCCreateViewController" bundle:nil] retain];
		
	}
	return self;
}

- (void) configureJiraConnect:(NSURL*) withUrl {

    [[CrashReportSender sharedCrashReportSender] sendCrashReportToURL:withUrl
                                                             delegate:self 
                                                     activateFeedback:YES];
	self.url = withUrl;
	[_pinger startPinging:withUrl];
	
	NSLog(@"JiraConnect is Configured with url: %@", withUrl);
	
}

-(JCCreateViewController*) viewController {
	return _jcController;
}

-(NSDictionary*) getMetaData {
	UIDevice* device = [UIDevice currentDevice];
	NSDictionary* appMetaData = [[NSBundle mainBundle] infoDictionary];
	NSMutableDictionary* info = [[[NSMutableDictionary alloc] initWithCapacity:20] autorelease];
	
	// add device data
	[info setObject:[device uniqueIdentifier] forKey:@"udid"];
	[info setObject:[device name] forKey:@"devName"];
	[info setObject:[device systemName] forKey:@"systemName"];
	[info setObject:[device systemVersion] forKey:@"systemVersion"];
	[info setObject:[device model] forKey:@"model"];
	
	// app application data (we could make these two separate dicts but cbf atm)
	[info setObject:[appMetaData objectForKey:@"CFBundleVersion"] forKey:@"appVersion"];
	[info setObject:[appMetaData objectForKey:@"CFBundleName"] forKey:@"appName"];
	[info setObject:[appMetaData objectForKey:@"CFBundleIdentifier"] forKey:@"appId"];
	
	// location data
	[info setObject:[NSString stringWithFormat:@"%f", [_location lat]] forKey:@"latitude"];
	[info setObject:[NSString stringWithFormat:@"%f", [_location lon]] forKey:@"longitude"];
	return info;
	
}


-(NSString*) crashReportUserID {
	return [[UIDevice currentDevice] uniqueIdentifier];
	
}

-(NSString*) crashReportContact {
	return @"Contact - TODO";
}

-(NSString*) crashReportDescription {
	return [[self getMetaData] JSONRepresentation];
}


@end
