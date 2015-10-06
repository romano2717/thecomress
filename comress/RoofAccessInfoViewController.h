//
//  RoofAccessInfoViewController.h
//  comress
//
//  Created by Diffy Romano on 30/9/15.
//  Copyright © 2015 Combuilder. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppWideImports.h"
#import "ImageOptions.h"
#import <CoreLocation/CoreLocation.h>
#import "Database.h"

@interface RoofAccessInfoViewController : UIViewController<CLLocationManagerDelegate>

{
    ImageOptions *imgOpts;
    CLLocationManager *locationManager;
    Database *myDatabase;
}

@property (nonatomic, strong) UIImage *capturedImage;
@property (nonatomic, strong) NSDictionary *scheduleDict;
@property (nonatomic, strong) NSNumber *roofSNo;

@end
