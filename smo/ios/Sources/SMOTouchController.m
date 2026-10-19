#import "SMOTouchController.h"
#import <GameController/GameController.h>
#include "dm_input.h"
#include "logbuf.h"
#include <math.h>
@interface SMOPadButton : UIControl
@property(nonatomic) uint64_t bit;
@property(nonatomic,strong) UILabel *label;
@end
@implementation SMOPadButton
- (instancetype)init {
    if((self=[super init])){
        self.layer.cornerRadius=22;self.layer.borderWidth=1;self.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.4].CGColor;
        _label=[UILabel new];_label.textAlignment=NSTextAlignmentCenter;_label.textColor=UIColor.whiteColor;
        _label.font=[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];[self addSubview:_label];
        self.isAccessibilityElement=YES;self.accessibilityTraits=UIAccessibilityTraitButton;
        [self setHighlighted:NO];
    }return self;
}
- (void)layoutSubviews {[super layoutSubviews];_label.frame=self.bounds;}
- (void)setHighlighted:(BOOL)value {
    [super setHighlighted:value];self.backgroundColor=[UIColor colorWithWhite:value?0.6:0.12 alpha:value?0.7:0.4];
}
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    (void)touch;(void)event;self.highlighted=YES;[self sendActionsForControlEvents:UIControlEventValueChanged];return YES;
}
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    (void)event;self.highlighted=CGRectContainsPoint(self.bounds,[touch locationInView:self]);
    [self sendActionsForControlEvents:UIControlEventValueChanged];return YES;
}
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    (void)touch;(void)event;self.highlighted=NO;[self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (void)cancelTrackingWithEvent:(UIEvent *)event {[super cancelTrackingWithEvent:event];self.highlighted=NO;[self sendActionsForControlEvents:UIControlEventValueChanged];}
@end
@interface SMOPadStick : UIControl
@property(nonatomic) CGPoint axis;
@end
@implementation SMOPadStick
- (instancetype)init {if((self=[super init])){self.backgroundColor=UIColor.clearColor;self.accessibilityLabel=@"摇杆";}return self;}
- (void)drawRect:(CGRect)rect {
    (void)rect;CGFloat diameter=MIN(self.bounds.size.width,self.bounds.size.height);
    [[UIColor colorWithWhite:0.1 alpha:0.4] setFill];[[UIColor colorWithWhite:1 alpha:0.4] setStroke];
    UIBezierPath *base=[UIBezierPath bezierPathWithOvalInRect:CGRectInset(self.bounds,1,1)];[base fill];[base stroke];
    CGPoint c=CGPointMake(CGRectGetMidX(self.bounds)+_axis.x*diameter*0.3,CGRectGetMidY(self.bounds)-_axis.y*diameter*0.3);
    [[UIColor colorWithWhite:0.8 alpha:0.55] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(c.x-diameter*0.2,c.y-diameter*0.2,diameter*0.4,diameter*0.4)] fill];
}
- (void)updateTouch:(UITouch *)touch {
    CGPoint p=[touch locationInView:self];CGFloat radius=MIN(self.bounds.size.width,self.bounds.size.height)*0.36;
    CGFloat x=(p.x-CGRectGetMidX(self.bounds))/radius,y=(CGRectGetMidY(self.bounds)-p.y)/radius;
    CGFloat length=hypot(x,y);if(length>1){x/=length;y/=length;}
    if(length<0.12){x=0;y=0;}else if(length<=1){CGFloat scale=(length-0.12)/(0.88*length);x*=scale;y*=scale;}
    _axis=CGPointMake(x,y);[self setNeedsDisplay];[self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {(void)event;[self updateTouch:touch];return YES;}
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {(void)event;[self updateTouch:touch];return YES;}
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {(void)touch;(void)event;_axis=CGPointZero;[self setNeedsDisplay];[self sendActionsForControlEvents:UIControlEventValueChanged];}
- (void)cancelTrackingWithEvent:(UIEvent *)event {[super cancelTrackingWithEvent:event];[self endTrackingWithTouch:nil withEvent:event];}
@end
@implementation SMOTouchController {
    NSArray<SMOPadButton *> *_buttons;
    SMOPadStick *_left,*_right;
    BOOL _active;
    BOOL _threeDLayout;
    GCController *_controller;
    BOOL _controllerConnected;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){
        self.multipleTouchEnabled=YES;_active=YES;self.backgroundColor=UIColor.clearColor;
        _threeDLayout=[[NSUserDefaults standardUserDefaults] objectForKey:@"SMOTouchLayout3D"] == nil ? YES :
            [[NSUserDefaults standardUserDefaults] boolForKey:@"SMOTouchLayout3D"];
        NSArray *names=@[@"A",@"B",@"X",@"Y",@"L",@"R",@"ZL",@"ZR",@"+",@"−",@"◀",@"▲",@"▶",@"▼",@"L3",@"R3"];
        const uint64_t bits[]={DM_BTN_A,DM_BTN_B,DM_BTN_X,DM_BTN_Y,DM_BTN_L,DM_BTN_R,DM_BTN_ZL,DM_BTN_ZR,DM_BTN_PLUS,DM_BTN_MINUS,DM_BTN_LEFT,DM_BTN_UP,DM_BTN_RIGHT,DM_BTN_DOWN,DM_BTN_LSTICK,DM_BTN_RSTICK};
        NSMutableArray *buttons=[NSMutableArray new];
        for(NSUInteger i=0;i<names.count;i++){
            SMOPadButton *b=[SMOPadButton new];b.bit=bits[i];b.label.text=names[i];b.accessibilityLabel=names[i];
            [b addTarget:self action:@selector(publishInput) forControlEvents:UIControlEventValueChanged];[self addSubview:b];[buttons addObject:b];
        }_buttons=buttons;
        _left=[SMOPadStick new];_right=[SMOPadStick new];
        for(SMOPadStick *stick in @[_left,_right]){[stick addTarget:self action:@selector(publishInput) forControlEvents:UIControlEventValueChanged];[self addSubview:stick];}
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(suspend) name:UIApplicationWillResignActiveNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resume) name:UIApplicationDidBecomeActiveNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(controllerConnected:) name:GCControllerDidConnectNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(controllerDisconnected:) name:GCControllerDidDisconnectNotification object:nil];
        for(GCController *controller in GCController.controllers){[self attachController:controller];break;}
        dm_log_emit("TOUCH_CONTROLLER_READY dual_stick=1 buttons=16");
    }return self;
}
- (void)dealloc {[NSNotificationCenter.defaultCenter removeObserver:self];}
- (void)attachController:(GCController *)controller {
    GCExtendedGamepad *pad=controller.extendedGamepad;
    if(!pad)return;
    _controller=controller;_controllerConnected=YES;self.hidden=YES;[self resetInput];
    __weak SMOTouchController *weakSelf=self;
    pad.valueChangedHandler=^(GCExtendedGamepad *gamepad,GCControllerElement *element){
        (void)gamepad;(void)element;[weakSelf publishControllerInput];
    };
    [self publishControllerInput];
    dm_log_emit("GAME_CONTROLLER_CONNECTED");
}
- (void)controllerConnected:(NSNotification *)note { [self attachController:note.object]; }
- (void)controllerDisconnected:(NSNotification *)note {
    if(note.object!=_controller)return;
    _controller=nil;_controllerConnected=NO;[self resetInput];self.hidden=NO;
    dm_log_emit("GAME_CONTROLLER_DISCONNECTED");
}
- (void)publishControllerInput {
    GCExtendedGamepad *pad=_controller.extendedGamepad;
    if(!_controllerConnected || !pad || !_active){dm_input_set_state(0,0,0,0,0);return;}
    uint64_t bits=0;
    if(pad.buttonA.pressed)bits|=DM_BTN_A;if(pad.buttonB.pressed)bits|=DM_BTN_B;
    if(pad.buttonX.pressed)bits|=DM_BTN_X;if(pad.buttonY.pressed)bits|=DM_BTN_Y;
    if(pad.leftShoulder.pressed)bits|=DM_BTN_L;if(pad.rightShoulder.pressed)bits|=DM_BTN_R;
    if(pad.leftTrigger.pressed)bits|=DM_BTN_ZL;if(pad.rightTrigger.pressed)bits|=DM_BTN_ZR;
    if(pad.buttonMenu.pressed)bits|=DM_BTN_PLUS;
    if(@available(iOS 14.0,*)){if(pad.buttonOptions.pressed)bits|=DM_BTN_MINUS;}
    if(pad.dpad.left.pressed)bits|=DM_BTN_LEFT;if(pad.dpad.up.pressed)bits|=DM_BTN_UP;
    if(pad.dpad.right.pressed)bits|=DM_BTN_RIGHT;if(pad.dpad.down.pressed)bits|=DM_BTN_DOWN;
    if(pad.leftThumbstickButton.pressed)bits|=DM_BTN_LSTICK;if(pad.rightThumbstickButton.pressed)bits|=DM_BTN_RSTICK;
    CGPoint l=CGPointMake(pad.leftThumbstick.xAxis.value,pad.leftThumbstick.yAxis.value);
    CGPoint r=CGPointMake(pad.rightThumbstick.xAxis.value,pad.rightThumbstick.yAxis.value);
    dm_input_set_state(bits,(int32_t)lrint(l.x*32767),(int32_t)lrint(l.y*32767),(int32_t)lrint(r.x*32767),(int32_t)lrint(r.y*32767));
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {UIView *hit=[super hitTest:point withEvent:event];return hit==self?nil:hit;}
- (void)layoutSubviews {
    [super layoutSubviews];CGRect area=UIEdgeInsetsInsetRect(self.bounds,self.safeAreaInsets);
    CGFloat scale=MIN(1,MIN(area.size.width/760,area.size.height/340));
    CGFloat unit=(_threeDLayout?44:38)*scale,left=CGRectGetMinX(area)+12,right=CGRectGetMaxX(area)-12,bottom=CGRectGetMaxY(area)-10;
    CGFloat top=CGRectGetMinY(area)+(_threeDLayout?50:18)*scale;
    CGFloat stickSize=(_threeDLayout?112:96)*scale;
    _left.frame=CGRectMake(left,bottom-stickSize,stickSize,stickSize);
    _right.frame=CGRectMake(right-(_threeDLayout?240:108)*scale,bottom-stickSize,stickSize,stickSize);
    if(!_threeDLayout){
        CGPoint centers[]={
            {right-42*scale,bottom-stickSize-42*scale},{right-88*scale,bottom-stickSize-10*scale},
            {right-88*scale,bottom-stickSize-74*scale},{right-134*scale,bottom-stickSize-42*scale},
            {left+34*scale,top+unit/2},{right-34*scale,top+unit/2},
            {left+86*scale,top+unit/2},{right-86*scale,top+unit/2},
            {CGRectGetMidX(area)+30*scale,top+unit/2},{CGRectGetMidX(area)-30*scale,top+unit/2},
            {left+stickSize/2,bottom-stickSize-92*scale},{left+stickSize/2-32*scale,bottom-stickSize-60*scale},
            {left+stickSize/2,bottom-stickSize-28*scale},{left+stickSize/2+32*scale,bottom-stickSize-60*scale},
            {left+stickSize+18*scale,bottom-stickSize/2},{right-(_threeDLayout?276:18)*scale,bottom-18*scale}};
        for(NSUInteger i=0;i<_buttons.count;i++)_buttons[i].frame=CGRectMake(centers[i].x-unit/2,centers[i].y-unit/2,unit,unit);
        return;
    }
    CGPoint centers[]={
        {right-unit/2,bottom-96*scale},{right-66*scale,bottom-52*scale},
        {right-66*scale,bottom-140*scale},{right-110*scale,bottom-96*scale},
        {left+36*scale,top+unit/2},{right-36*scale,top+unit/2},
        {left+116*scale,top+unit/2},{right-116*scale,top+unit/2},
        {CGRectGetMidX(area)+36*scale,top+unit/2},{CGRectGetMidX(area)-36*scale,top+unit/2},
        {left+144*scale,bottom-80*scale},{left+188*scale,bottom-124*scale},
        {left+232*scale,bottom-80*scale},{left+188*scale,bottom-36*scale},
        {left+66*scale,bottom-148*scale},{right-276*scale,bottom-24*scale}};
    for(NSUInteger i=0;i<_buttons.count;i++)_buttons[i].frame=CGRectMake(centers[i].x-unit/2,centers[i].y-unit/2,unit,unit);
}
- (void)publishInput {
    if(_controllerConnected){[self publishControllerInput];return;}
    uint64_t bits=0;if(_active && !self.hidden)for(SMOPadButton *b in _buttons)if(b.highlighted)bits|=b.bit;
    CGPoint l=_active && !self.hidden?_left.axis:CGPointZero,r=_active && !self.hidden?_right.axis:CGPointZero;
    dm_input_set_state(bits,(int32_t)lrint(l.x*32767),(int32_t)lrint(l.y*32767),(int32_t)lrint(r.x*32767),(int32_t)lrint(r.y*32767));
}
- (void)resetInput {
    for(SMOPadButton *b in _buttons){[b cancelTrackingWithEvent:nil];b.highlighted=NO;}
    [_left cancelTrackingWithEvent:nil];[_right cancelTrackingWithEvent:nil];[self publishInput];
}
- (void)setHidden:(BOOL)hidden {[super setHidden:hidden];if(hidden)[self resetInput];}
- (void)suspend {_active=NO;[self resetInput];}
- (void)resume {[self resetInput];_active=YES;[self publishControllerInput];}
- (BOOL)isThreeDLayout { return _threeDLayout; }
- (BOOL)hasExternalController { return _controllerConnected; }
- (void)toggleLayout {
    if(_controllerConnected)return;
    _threeDLayout=!_threeDLayout;
    [[NSUserDefaults standardUserDefaults] setBool:_threeDLayout forKey:@"SMOTouchLayout3D"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self setNeedsLayout];
    dm_log_emit("TOUCH_LAYOUT mode=%s",_threeDLayout?"3D":"2D");
}
@end
