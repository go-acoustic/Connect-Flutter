//
//  PointerEvent.h
//  
//
//  Created by Stephen Schmitt on 9/4/22.
//

#ifndef PointerEvent_h
#define PointerEvent_h

@interface PointerEvent : NSObject

@property (nonatomic) NSString *action;
@property (nonatomic) CGFloat x,y;
@property (nonatomic) NSString *timestamp;
@property (nonatomic) long downTime;
@property (nonatomic) float pressure;
@property (nonatomic) int   kind;


- (id) initWith:(NSString *) action andX:(CGFloat) x andY:(CGFloat) y andTs:(NSString *) ts andDown:(long) downTime andPressure:(float) pressure andKind:(int) kind;

@end
#endif /* PointerEvent_h */
