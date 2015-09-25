//
//  ScanQrCodeTableViewCell.h
//  comress
//
//  Created by Diffy Romano on 23/9/15.
//  Copyright © 2015 Combuilder. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Database.h"

@interface ScanQrCodeTableViewCell : UITableViewCell
{
    Database *myDatabase;
}

@property (nonatomic, weak) IBOutlet UILabel *areaLabel;
@property (nonatomic, weak) IBOutlet UILabel *scanTimeLabel;
@property (nonatomic, weak) IBOutlet UILabel *reportTimeLabel;

@property (nonatomic, strong)NSDateFormatter *dateFormatter;

- (void)initCellWithResultSet:(NSDictionary *)dict;

@end
