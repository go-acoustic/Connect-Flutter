//
//  PointerEvent.m
//  
//
//  Created by Stephen Schmitt on 9/4/22.

#import <Foundation/Foundation.h>
#import "PointerEvent.h"

@implementation PointerEvent {
    NSDictionary *_actionMap;
}

- (id) initWith:(NSString *) action andX:(CGFloat) x andY:(CGFloat) y andTs:(NSString *) ts andDown:(long) downTime andPressure:(float) pressure andKind:(int) kind {
    self = [super init];

    if (self) {
        
        self.action = [NSString stringWithFormat:@"%@%@", @"ACTION_", action];
        self.x = x;
        self.y = y;
        self.timestamp = ts;
        self.downTime = downTime;
        self.pressure = pressure;
        self.kind = kind;
    }
    return self;
}
@end
