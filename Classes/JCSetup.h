//
//  JCSetup.h
//  JiraConnect
//
//  Created by Nicholas Pellow on 21/09/10.
//  Copyright 2010 Nick Pellow. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CrashReportSender.h"
#import "JCCreateViewController.h"


@interface JCSetup : NSObject <CrashReportSenderDelegate> {
	NSURL* _url;	
}

@property (nonatomic, retain) NSURL* url;

+ (JCSetup*) instance;

- (UIWindow*) configureJiraConnect:(NSURL*)url;
- (JCCreateViewController*) viewController;
- (NSDictionary*) getMetaData;

@end
