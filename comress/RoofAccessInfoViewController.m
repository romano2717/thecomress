//
//  RoofAccessInfoViewController.m
//  comress
//
//  Created by Diffy Romano on 30/9/15.
//  Copyright © 2015 Combuilder. All rights reserved.
//

#import "RoofAccessInfoViewController.h"

@interface RoofAccessInfoViewController ()<UINavigationControllerDelegate,UIImagePickerControllerDelegate>

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UILabel *blockLabel;
@property (nonatomic, weak) IBOutlet UILabel *dateLabel;
@property (nonatomic, strong) CLLocation *location;

@property (nonatomic, strong) UIImagePickerController *imagePicker;

@end

@implementation RoofAccessInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    myDatabase = [Database sharedMyDbManager];
    
    self.title = @"Roof Access Information";
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"dd/MMM/YYYY hh:ss a";
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    
    _blockLabel.text = [_scheduleDict valueForKey:@"blockDesc"];
    _dateLabel.text = [NSString stringWithFormat:@"On: %@",dateString];
    
    //init location manager
    
    CLLocation *loc = [[CLLocation alloc] initWithLatitude:0 longitude:0];
    _location = loc;
    
    locationManager = [[CLLocationManager alloc] init];
    locationManager.distanceFilter = 100;
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    locationManager.delegate = self;
    
    //ask permission to use location service
    [locationManager requestAlwaysAuthorization];
    [locationManager requestWhenInUseAuthorization];
    
    [locationManager startUpdatingLocation];
    
    
    //retrieve local roof scan information
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {

        FMResultSet *rs = [db executeQuery:@"select * from rt_roof_check_image where block_id = ? order by dateChecked desc limit 1",[NSNumber numberWithInt:[[_scheduleDict valueForKey:@"blk_id"] intValue]]];

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsPath = [paths objectAtIndex:0];
        
        while ([rs next]) {
            NSString *onDateString = [formatter stringFromDate:[rs dateForColumn:@"dateChecked"]];
            _dateLabel.text = [NSString stringWithFormat:@"On: %@",onDateString];
            
            NSString *imagePath = [rs stringForColumn:@"image_name"];
            NSString *filePath = [documentsPath stringByAppendingPathComponent:imagePath];
            UIImage *theImage = [UIImage imageWithContentsOfFile:filePath];
            
            _imageView.image = theImage;
        }
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)takePhoto:(id)sender
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.delegate = self;
    
    self.imagePicker = picker;
    
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    UIImage *img = [info objectForKey:UIImagePickerControllerEditedImage];
    
    if(img == nil)
        img = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    if(imgOpts == nil)
        imgOpts = [ImageOptions new];
    
    UIImage *thumbImage = [imgOpts resizeImageAsThumbnailForImage:img];
    
    _imageView.image = thumbImage;
    _capturedImage = thumbImage;
    
    [self saveRoofAccessWithImage:thumbImage];

}

#pragma mark - core location

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *loc = [locations lastObject];
    
    NSTimeInterval locationAge = -[loc.timestamp timeIntervalSinceNow];
    
    BOOL locationIsGood = YES;
    
    if (locationAge > 15.0)
    {
        locationIsGood = NO;
    }
    
    if (loc.horizontalAccuracy < 0)
    {
        locationIsGood = NO;
    }
    
    if(locationIsGood)
    {
        self.location = loc;
        
        [locationManager stopUpdatingLocation];
    }
}


- (void)saveRoofAccessWithImage:(UIImage *)image
{
    NSData *jpegImageData = UIImageJPEGRepresentation(image, 1);
    
    //save the image to app documents dir
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [paths objectAtIndex:0];
    NSString *imageFileName = [NSString stringWithFormat:@"%@.jpg",[[NSUUID UUID] UUIDString]];
    
    NSString *filePath = [documentsPath stringByAppendingPathComponent:imageFileName]; //Add the file name
    [jpegImageData writeToFile:filePath atomically:YES];
    
    NSFileManager *fManager = [[NSFileManager alloc] init];
    if([fManager fileExistsAtPath:filePath] == NO)
        return;
    
    //resize the saved image
    [imgOpts resizeImageAtPath:filePath];
    
    //save the image info to local db
    
    //save full image to comress album
    [myDatabase saveImageToComressAlbum:image];
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {

        BOOL ins = [db executeUpdate:@"insert into rt_roof_check_image(roof_check_sno, image_name, latitude, longitude, block_id, dateChecked) values (?,?,?,?,?,?)", _roofSNo, imageFileName, [NSNumber numberWithDouble:self.location.coordinate.latitude],[NSNumber numberWithDouble:self.location.coordinate.longitude],[NSNumber numberWithInt:[[_scheduleDict valueForKey:@"block_id"] intValue]],[NSDate date]];
        
        if(!ins)
        {
            *rollback = YES;
            return;
        }

    }];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"dd/MMM/YYYY hh:ss a";
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    _dateLabel.text = [NSString stringWithFormat:@"On: %@",dateString];
    
}

@end
