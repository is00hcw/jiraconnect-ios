//
//  JCOIssueViewController.h
//  JiraConnect
//
//  Created by Nicholas Pellow on 17/03/11.
//

#import <UIKit/UIKit.h>
#import "JCOIssue.h"
#import "JCOTransport.h"

@protocol JCOTransportDelegate;

@interface JCOIssueViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, JCOTransportDelegate> {
    IBOutlet UITableView* _tableView;
    IBOutlet UIButton*_replyButton;
    JCOIssue * _issue;

}

- (IBAction) didTouchReply:(UITextField*)sender;

@property (nonatomic, retain) IBOutlet UITableView* tableView;
@property (nonatomic, retain) IBOutlet UIButton* replyButton;
@property (nonatomic, retain) JCOIssue * issue;



@end