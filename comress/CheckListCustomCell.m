//
//  CheckListCustomCell.m
//  comress
//
//  Created by Diffy Romano on 16/9/15.
//  Copyright (c) 2015 Combuilder. All rights reserved.
//

#import "CheckListCustomCell.h"

@implementation CheckListCustomCell

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)initCellWithResultSet:(NSDictionary *)dict
{
    NSDictionary *checkList = [dict objectForKey:@"checkListArray"];
    NSNumber *checkListId = [NSNumber numberWithInt:[[checkList valueForKey:@"CheckListId"] intValue]];
    
    NSArray *checkedCheckList = [dict objectForKey:@"checked"];

    NSString *checkListName = [checkList valueForKey:@"CheckListName"];
    
    BOOL isChecked = [[checkList valueForKey:@"IsCheck"] boolValue];
    BOOL wasModified = [[dict valueForKey:@"wasModified"] boolValue];
    
    
    //defaults
    [_checkBoxBtn setSelected:NO];
    
    
    //config ui
#if DEBUG
    _checkListLabel.text = [NSString stringWithFormat:@"%@:%@:%@",checkListName,checkListId,[checkList valueForKey:@"IsCheck"]];
#else
    _checkListLabel.text = checkListName;
#endif
    [_checkBoxBtn setSelected:isChecked];

    if([checkedCheckList containsObject:checkListId])
        [_checkBoxBtn setSelected:YES];
    else if([checkedCheckList containsObject:checkListId] == NO && wasModified == YES) //list was modified
    {
        if([checkedCheckList containsObject:checkListId] == NO)
            [_checkBoxBtn setSelected:NO];
        else
            [_checkBoxBtn setSelected:YES];
    }
}
@end
