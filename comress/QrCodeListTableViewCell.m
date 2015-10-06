//
//  QrCodeListTableViewCell.m
//  comress
//
//  Created by Diffy Romano on 22/9/15.
//  Copyright © 2015 Combuilder. All rights reserved.
//

#import "QrCodeListTableViewCell.h"

@implementation QrCodeListTableViewCell


- (void)awakeFromNib {
    // Initialization code
    
    myDatabase = [Database sharedMyDbManager];
    
    _dateFormatter = [[NSDateFormatter alloc] init];
    _dateFormatter.dateFormat = @"hh:mm a dd/mm/yyyy";
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)initCellWithResultSet:(NSDictionary *)dict
{
    NSString *Area = [NSString stringWithFormat:@"Area: %@",[dict valueForKey:@"Area"]];
    NSString *LastScannedTime = [dict valueForKey:@"LastScannedTime"];
    NSString *ReportTime = [dict valueForKey:@"ReportTime"];
    NSString *PrintedTime = [dict valueForKey:@"PrintedTime"];
    NSIndexPath *indexPath = [dict objectForKey:@"indexPath"];
    NSArray *selectedQrCodeIndexPathsArray = [dict objectForKey:@"selectedQrCodeIndexPathsArray"];
    
    NSDate *LastScannedTimeDate = [myDatabase createNSDateWithWcfDateString:LastScannedTime];
    double LastScannedTimeDouble = [LastScannedTimeDate timeIntervalSince1970];
    
    NSDate *PrintedTimeDate = [myDatabase createNSDateWithWcfDateString:PrintedTime];
    double PrintedTimeDateDouble = [PrintedTimeDate timeIntervalSince1970];
    
    LastScannedTime = @"Scanned time: -";
    if(LastScannedTimeDouble > 0)
        LastScannedTime = [NSString stringWithFormat:@"Scanned time: %@",[_dateFormatter stringFromDate:LastScannedTimeDate]];
    
    NSDate *ReportTimeDate = [myDatabase createNSDateWithWcfDateString:ReportTime];
    double ReportTimeDateDouble = [ReportTimeDate timeIntervalSince1970];
    
    ReportTime = @"Report time: -";
    if(ReportTimeDateDouble > 0)
        ReportTime = [NSString stringWithFormat:@"Report time: %@",[_dateFormatter stringFromDate:ReportTimeDate]];
    
    //hide/show print time
    if(PrintedTimeDateDouble > ReportTimeDateDouble)
        ReportTime = @"-";
    
    //hide/show check box
    if(ReportTimeDateDouble > 0)
        _checkBtn.hidden = YES;
    else
        _checkBtn.hidden = NO;
    
    //check/uncheck checkbox
    if([selectedQrCodeIndexPathsArray containsObject:[NSNumber numberWithInteger:indexPath.row]])
        _checkBtn.selected = YES;
    else
        _checkBtn.selected = NO;
    
    _areaLabel.text = Area;
    _scanTimeLabel.text = LastScannedTime;
    _reportTimeLabel.text = ReportTime;
    _checkBtn.tag = indexPath.row;
}

@end
