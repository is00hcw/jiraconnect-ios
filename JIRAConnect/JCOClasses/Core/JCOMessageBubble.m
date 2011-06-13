/**
       Licensed to the Apache Software Foundation (ASF) under one
       or more contributor license agreements.  See the NOTICE file
       distributed with this work for additional information
       regarding copyright ownership.  The ASF licenses this file
       to you under the Apache License, Version 2.0 (the
       "License"); you may not use this file except in compliance
       with the License.  You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

       Unless required by applicable law or agreed to in writing,
       software distributed under the License is distributed on an
       "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
       KIND, either express or implied.  See the License for the
       specific language governing permissions and limitations
       under the License.
*/


#import "JCOMessageBubble.h"

@interface JCOMessageBubble()
@property (nonatomic, retain) UIImageView *bubble;

@end

@implementation JCOMessageBubble

@synthesize bubble, detailLabel, label;

- (id)initWithReuseIdentifier:(NSString *)cellIdentifierComment detailHeight:(float)detailHeight {

    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifierComment])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        // this is a work-around for self.backgroundColor = [UIColor clearColor]; appearing black on iOS < 4.3 .
        UIView *transparentBackground = [[UIView alloc] initWithFrame:CGRectZero];
        transparentBackground.backgroundColor = [UIColor clearColor];
        self.backgroundView = transparentBackground;
        [transparentBackground release];

        bubble = [[UIImageView alloc] initWithFrame:CGRectZero];

        detailLabelHeight = detailHeight;

        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.tag = 2;
        label.numberOfLines = 0;
        label.lineBreakMode = UILineBreakModeWordWrap;
        label.backgroundColor = [UIColor clearColor];

        detailLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, detailLabelHeight)];
        detailLabel.tag = 3;
        detailLabel.numberOfLines = 1;
        detailLabel.lineBreakMode = UILineBreakModeClip;
        detailLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:11];
        detailLabel.textColor = [UIColor darkGrayColor];

        detailLabel.backgroundColor = [UIColor clearColor];
        detailLabel.textAlignment = UITextAlignmentCenter;

        UIView *message = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        [message addSubview:detailLabel];
        [message addSubview:bubble];
        [message addSubview:label];

        [self.contentView addSubview:message];

        [message release];
    }
    return self;
}


- (void)setText:(NSString *)string leftAligned:(BOOL)leftAligned withFont:(UIFont *)font {
    // TODO: un hardcode these sizes..
   CGSize  size = [string sizeWithFont:font constrainedToSize:CGSizeMake(240.0f, 480.0f) lineBreakMode:UILineBreakModeWordWrap];

    UIImage * balloon;
    float balloonY = 2.0f + detailLabelHeight;
    float labelY = 8.0f + detailLabelHeight;
    if (leftAligned) {
        CGRect frame = CGRectMake(320.0f - (size.width + 48.0f), balloonY, size.width + 28.0f, size.height + 12.0f);
        self.bubble.frame = frame;
        self.bubble.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        balloon = [[UIImage imageNamed:@"Balloon_1"] stretchableImageWithLeftCapWidth:20.0f topCapHeight:15.0f];
        self.label.frame = CGRectMake(frame.origin.x + 12.0f, labelY - 2.0f, size.width + 5.0f, size.height);

    } else {
        self.bubble.frame = CGRectMake(0.0f, balloonY, size.width + 28.0f, size.height + 12.0f);
        self.bubble.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        balloon = [[UIImage imageNamed:@"Balloon_2"] stretchableImageWithLeftCapWidth:25.0f topCapHeight:15.0f];
        self.label.frame = CGRectMake(20.0f, labelY - 2.0f, size.width + 5, size.height);
    }

    self.bubble.image = balloon;
    self.label.text = string;
}

- (void)dealloc {
    [bubble release];
    [detailLabel release];
    [label release];
    [super dealloc];
}

@end
