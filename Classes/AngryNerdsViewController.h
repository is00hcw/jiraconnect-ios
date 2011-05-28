
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

#import "JCOCustomDataSource.h"

@interface AngryNerdsViewController : UIViewController <JCOCustomDataSource, CLLocationManagerDelegate> {

    CLLocationManager *_locationManager;
    IBOutlet UIButton* _nerd;
    IBOutlet UIImageView* _nerdsView;
}

@property (nonatomic, retain) IBOutlet UIButton *nerd;
@property (nonatomic, retain) IBOutlet UIImageView *nerdsView;

- (IBAction) triggerCrash;
- (IBAction) triggerFeedback;
- (IBAction) triggerDisplayNotifications;
- (NSString *)project;

-(IBAction)bounceNerd;

@end

