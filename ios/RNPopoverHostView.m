//
//  RNPopoverHostView.m
//  RNPopoverIOS
//
//  Created by Bell Zhong on 2017/8/10.
//  Copyright © 2017年 shimo. All rights reserved.
//

#import "RNPopoverHostView.h"

#import <React/RCTAssert.h>
#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/RCTUtils.h>
#import <React/UIView+React.h>
#import <React/RCTShadowView.h>
#import <React/RCTTouchHandler.h>

#if __has_include(<React/RCTUIManagerUtils.h>)
#import <React/RCTUIManagerUtils.h>
#endif

#import "RNPopoverHostViewController.h"
#import "RNPopoverTargetManager.h"

@interface RNPopoverHostView () <RNPopoverHostViewControllerDelegate>

@property (nonatomic, strong) RNPopoverHostViewController *popoverHostViewController;

@property (nonatomic, copy) RCTPromiseResolveBlock dismissResolve;
@property (nonatomic, copy) RCTPromiseRejectBlock dismissReject;
@property (nonatomic, assign) BOOL initialized;
@property (nonatomic, assign) BOOL presented;

@property (nonatomic, assign) CGRect realSourceRect;
@property (nonatomic, assign) CGSize realPreferredContentSize;

@end

@implementation RNPopoverHostView {
    __weak RCTBridge *_bridge;
    RCTTouchHandler *_touchHandler;
}

RCT_NOT_IMPLEMENTED(-(instancetype)initWithFrame
                    : (CGRect)frame)
RCT_NOT_IMPLEMENTED(-(instancetype)initWithCoder
                    : coder)

#pragma mark - React

- (instancetype _Nonnull)initWithBridge:(RCTBridge *_Nullable)bridge {
    if ((self = [super initWithFrame:CGRectZero])) {
        _bridge = bridge;
        _initialized = NO;
        _presented = NO;
        _animated = YES;
        _cancelable = YES;
        _popoverBackgroundColor = [UIColor whiteColor];
        _sourceViewTag = -1;
        _sourceViewGetterTag = -1;
        _sourceViewReactTag = -1;
        _realSourceRect = CGRectNull;
        _permittedArrowDirections = @[@(0), @(1), @(2), @(3)];
        _realPreferredContentSize = CGSizeZero;
        _popoverHostViewController = [[RNPopoverHostViewController alloc] init];
        _popoverHostViewController.popoverHostDelegate = self;
        _touchHandler = [[RCTTouchHandler alloc] initWithBridge:bridge];
        
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter]
         addObserver:self selector:@selector(orientationChanged:)
         name:UIApplicationDidChangeStatusBarOrientationNotification
         object:[UIDevice currentDevice]];
    }
    return self;
}

- (void)insertReactSubview:(UIView *)subview atIndex:(NSInteger)atIndex {
    RCTAssert(_contentView == nil, @"Popover can only have one subview");
    
    [super insertReactSubview:subview atIndex:atIndex];
    subview.frame = _popoverHostViewController.view.bounds;
    [_touchHandler attachToView:subview];
    [_popoverHostViewController.view insertSubview:subview atIndex:0];
    _contentView = subview;
}

- (void)removeReactSubview:(UIView *)subview {
    RCTAssert(subview == _contentView, @"Cannot remove view other than modal view");
    [super removeReactSubview:subview];
    
    [_touchHandler detachFromView:subview];
    _contentView = nil;
}

- (void)didUpdateReactSubviews {
    // Do nothing, as subview (singular) is managed by `insertReactSubview:atIndex:`
}

#pragma mark - UIView

- (void)didMoveToWindow {
    [super didMoveToWindow];
    
    if (!_initialized && self.window) {
        _initialized = YES;
        _popoverHostViewController.view.backgroundColor = _popoverBackgroundColor;
        [self presentViewController];
    }
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    
    if (_presented && !self.superview) {
        [self dismissViewController];
    }
}

#pragma mark - RNPopoverHostViewControllerDelegate

- (void)didContentFrameUpdated:(RNPopoverHostViewController *)viewController {
    CGRect frame = viewController.contentFrame;
    _contentView.frame = frame;
    RCTExecuteOnUIManagerQueue(^{
        RCTShadowView *shadowView = [_bridge.uiManager shadowViewForReactTag:_contentView.reactTag];
        shadowView.top = (YGValue){frame.origin.y, YGUnitPoint};
        shadowView.left = (YGValue){frame.origin.x, YGUnitPoint};
        shadowView.width = (YGValue){CGRectGetWidth(frame), YGUnitPoint};
        shadowView.height = (YGValue){CGRectGetHeight(frame), YGUnitPoint};
        [shadowView didSetProps:@[@"top", @"left", @"width", @"height"]];
        [_bridge.uiManager setNeedsLayout];
    });
}

#pragma mark - RCTInvalidating

- (void)invalidate {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissViewController];
        self.delegate = nil;
        _popoverHostViewController.popoverPresentationController.delegate = nil;
    });
}

#pragma mark - Orientation Notification

- (void) orientationChanged:(NSNotification *)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_popoverHostViewController dismissViewControllerAnimated:NO completion:^{
            _popoverHostViewController.popoverPresentationController.delegate = self;
            [self presentViewController];
        }];
        _presented = NO;
        
    });
}

#pragma mark - Public

- (void)presentViewController {
    if (_presented) {
        return;
    }
    
    [self autoGetSourceView:^(UIView *sourceView, RNPopoverHostView *popoverHostView) {
        if (!sourceView) {
            NSLog(@"sourceView is invalid");
            if (_onHide) {
                _onHide(nil);
            }
            return;
        }
        _presented = YES;
        [self updateContentSize];
        _popoverHostViewController.popoverPresentationController.sourceView = sourceView;
        _popoverHostViewController.popoverPresentationController.sourceRect = CGRectEqualToRect(_realSourceRect, CGRectNull) ? sourceView.bounds : _realSourceRect;
        _popoverHostViewController.popoverPresentationController.backgroundColor = _popoverBackgroundColor;
        _popoverHostViewController.popoverPresentationController.permittedArrowDirections = [self getPermittedArrowDirections];
        _popoverHostViewController.popoverPresentationController.delegate = self;
        if (!CGSizeEqualToSize(CGSizeZero, _realPreferredContentSize)) {
            _popoverHostViewController.preferredContentSize = _realPreferredContentSize;
        }
        
        UIViewController *parent;
        if (popoverHostView == self) {
            parent = [popoverHostView reactViewController];
        } else {
            parent = popoverHostView.popoverHostViewController;
        }
        
        if (parent.presentedViewController) {
            if (_onHide) {
                _onHide(nil);
            }
            return;
        }
        
        [_delegate presentPopoverHostView:popoverHostView
                       withViewController:_popoverHostViewController
                     parentViewController:parent
                                 animated:_animated];
    }];
}

- (void)dismissViewController {
    if (_presented) {
        [_delegate dismissPopoverHostView:self withViewController:_popoverHostViewController animated:_animated];
        _presented = NO;
    }
}

#pragma mark - UIPopoverPresentationControllerDelegate

// Called on the delegate when the user has taken action to dismiss the popover. This is not called when the popover is dimissed programatically.
- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    _presented = NO;
    if (_onHide) {
        _onHide(nil);
    }
}

- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController{
    return _cancelable;
}

#pragma mark - Private

- (UIPopoverArrowDirection)getPermittedArrowDirections {
    UIPopoverArrowDirection permittedArrowDirections = 0;
    for (NSNumber *direction in _permittedArrowDirections) {
        if ([direction integerValue] == 0) {
            permittedArrowDirections |= UIPopoverArrowDirectionUp;
        } else if ([direction integerValue] == 1) {
            permittedArrowDirections |= UIPopoverArrowDirectionDown;
        } else if ([direction integerValue] == 2) {
            permittedArrowDirections |= UIPopoverArrowDirectionLeft;
        } else if ([direction integerValue] == 3) {
            permittedArrowDirections |= UIPopoverArrowDirectionRight;
        }
    }
    return permittedArrowDirections;
}

- (void)updateContentSize {
    if (!CGSizeEqualToSize(_realPreferredContentSize, CGSizeZero) &&
        !CGSizeEqualToSize(_popoverHostViewController.preferredContentSize, _realPreferredContentSize)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _popoverHostViewController.preferredContentSize = _realPreferredContentSize;
        });
    }
    
    dispatch_sync(RCTGetUIManagerQueue(), ^{
        RCTShadowView *shadowView = [_bridge.uiManager shadowViewForReactTag:_contentView.reactTag];
        if (shadowView
            && !CGSizeEqualToSize(_realPreferredContentSize, CGSizeZero)
            && !CGSizeEqualToSize(shadowView.size, _realPreferredContentSize)) {
            shadowView.size = _realPreferredContentSize;
            [_bridge.uiManager setNeedsLayout];
        }
    });
}

- (void)autoGetSourceView:(void (^)(UIView *view, RNPopoverHostView *popoverHostView))completion {
    if (_sourceViewNativeID) {
        __block NSString *nativeID = _sourceViewNativeID;
        [_bridge.uiManager rootViewForReactTag:self.reactTag withCompletion:^(UIView *view) {
            UIView *target = [_bridge.uiManager viewForNativeID:nativeID withRootTag:view.reactTag];
            if (!target) {
                [self.delegate lookupViewForNativeID:nativeID :completion];
            } else {
                completion(target, self);
            }
        }];
    } else {
        UIView *sourceView = nil;
        if (_sourceViewReactTag >= 0) {
            sourceView = [_bridge.uiManager viewForReactTag:@(_sourceViewReactTag)];
        } else if (_sourceViewTag >= 0) {
            sourceView = [[RNPopoverTargetManager getInstance] viewForTag:_sourceViewTag];
        } else if (_sourceViewGetterTag >= 0) {
            sourceView = [[RNPopoverTargetManager getInstance] viewForGetterTag:_sourceViewGetterTag];
        }
        completion(sourceView, self);
    }
    
}

#pragma mark - Setter

- (void)setPreferredContentSize:(NSArray *)preferredContentSize {
    if (preferredContentSize.count != 2 || [_preferredContentSize isEqualToArray:preferredContentSize]) {
        return;
    }
    _preferredContentSize = preferredContentSize;
    _realPreferredContentSize = CGSizeMake([_preferredContentSize[0] floatValue], [_preferredContentSize[1] floatValue]);
    [self updateContentSize];
}

- (void)setSourceRect:(NSArray *)sourceRect {
    if (sourceRect.count != 4 || [_sourceRect isEqualToArray:sourceRect]) {
        return;
    }
    _sourceRect = sourceRect;
    _realSourceRect = CGRectMake([_sourceRect[0] floatValue], [_sourceRect[1] floatValue], [_sourceRect[2] floatValue], [_sourceRect[3] floatValue]);
}

@end
