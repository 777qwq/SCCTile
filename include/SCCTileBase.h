#ifndef SCCTILE_BASE_H
#define SCCTILE_BASE_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <ControlCenterUIKit/CCUIToggleModule.h>

#import "CCSModuleProvider.h"

/* CCUILayoutSize 与 CGSize 布局一致（CCSupport DynamicSizeModule 使用） */
typedef CGSize CCUILayoutSize;

/* CCSupport 提供的动态尺寸协议（见 CCSupport.h） */
@protocol DynamicSizeModule
@optional
- (CCUILayoutSize)moduleSizeForOrientation:(int)orientation;
@end

#endif
