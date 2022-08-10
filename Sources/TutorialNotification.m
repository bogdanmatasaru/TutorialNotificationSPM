//
//  TutorialNotification.m
//  TutorialNotification
//
//  Created by Gaurav Wadhwani on 28/06/14.
//  Copyright (c) 2014 Mappgic. All rights reserved.
//
//    The MIT License (MIT)
//
//    Copyright (c) 2014 Gaurav Wadhwani
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.
//

#import "TutorialNotification.h"

////////////////////////////////////////////////////////////////////////////////

static const CGFloat kMaximumNotificationWidth = 512;

static const CGFloat kNotificationHeight = 64;
static const CGFloat kIconImageSize = 48.0;
static const NSTimeInterval kLinearAnimationTime = 0.25;

static const CGFloat kColorAdjustmentDark = -0.15;
static const CGFloat kColorAdjustmentLight = 0.35;

////////////////////////////////////////////////////////////////////////////////

@interface TutorialNotification ()

// required for system interaction
@property (nonatomic) UIWindowLevel windowLevel; // ensures the system status bar does not overlap the notification

// always built
@property (nonatomic, strong) UILabel *titleLabel;

// optionally built
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, readwrite) UIView *backgroundView;
@property (nonatomic, readwrite) UIView *contentView;
@property (nonatomic, readwrite) UIButton *firstButton;
@property (nonatomic, readwrite) UIView *firstButtonBackgroundView;
@property (nonatomic, strong) UIView *swipeHintView;

// state
@property (nonatomic) BOOL notificationRevealed;
@property (nonatomic) BOOL notificationDragged;
@property (nonatomic) BOOL notificationDestroyed;

// other
@property (nonatomic) BOOL showActionButton;
@property (nonatomic, strong) UIDynamicAnimator *animator;
@property (nonatomic) TutorialNotificationButtonConfigration buttonConfiguration;
@property (nonatomic) int notificationsStack;

@end

////////////////////////////////////////////////////////////////////////////////

@implementation TutorialNotification

// designated initializer
- (instancetype)init
{
    // If the App has a keyWindow, get it, else get the 'top'-most window in the App's hierarchy.
    UIWindow *window = [self _topAppWindow];

    // Now get the 'top'-most object in that window and use its width for the Notification
    UIView *topSubview = [[window subviews] lastObject];
    CGFloat safeArea = self.superview.safeAreaInsets.top;
    CGRect notificationFrame = CGRectMake(0, 0, CGRectGetWidth(topSubview.bounds), kNotificationHeight + safeArea);
    
    self = [super initWithFrame:notificationFrame];
    if (self) {
        
        self.scrollEnabled = NO; // default swipe/scrolling to off (in case swipeToDismiss is not enabled by default)
        self.contentSize = CGSizeMake(CGRectGetWidth(self.bounds), 2 * CGRectGetHeight(self.bounds));
        self.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        self.pagingEnabled = YES;
        self.showsVerticalScrollIndicator = NO;
        self.bounces = NO;
        
        self.delegate = self;
        
        [super setBackgroundColor:[UIColor clearColor]]; // set background color of scrollView to clear
        
        // make background button (always needed, even if no target)
        self.backgroundView = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.backgroundView];
        
        CGRect contentViewFrame = self.bounds;
        contentViewFrame.origin.y = safeArea;
        contentViewFrame.size.height = kNotificationHeight;
        self.contentView = [[UIView alloc]initWithFrame:contentViewFrame];
        [self.backgroundView addSubview:self.contentView];
        
        self.backgroundView.frame = self.bounds;
        self.backgroundView.tag = TutorialNotificationButtonConfigrationZeroButtons;
        
        // set other default values
        self.titleColor = [UIColor whiteColor];
        
        self.backgroundTapsEnabled = YES;
        self.swipeToDismissEnabled = YES;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    NSAssert(NO, @"Wrong initializer. Use the base init method, or initialize with the convenience class method provided.");
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

//- (void)dealloc {
//    NSLog(@"DEBUG: NOTIFICATION DEALLOC");
//}

#pragma mark - Class Overrides

- (void)layoutSubviews
{

    [super layoutSubviews];
    
    static const CGFloat kPaddingX = 15;
    CGFloat notificationWidth = CGRectGetWidth(self.bounds);
    
    CGFloat maxWidth = 0.5 * (notificationWidth - kMaximumNotificationWidth);
    CGFloat contentPaddingX = (self.fullWidthMessages) ? 0 : MAX(0,maxWidth);
    
    // ICON IMAGE
    static const CGFloat kIconPaddingY = 8;
    self.iconImageView.frame = CGRectMake(contentPaddingX + kPaddingX,
                                          kIconPaddingY,
                                          kIconImageSize,
                                          kIconImageSize);
    
    
    // BUTTONS
    
    CGFloat firstButtonOriginY = 64;
    CGFloat buttonHeight = 30;
  
    self.firstButton.frame = CGRectMake(0, firstButtonOriginY, self.frame.size.width, buttonHeight);
    self.firstButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    self.firstButton.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 30);
    
    //FIRST BUTTON BACKGROUND VIEW
    self.firstButtonBackgroundView.frame = CGRectMake(0, 64, self.frame.size.width, 30);
    
    // TITLE LABEL
    CGFloat kTitleLabelHeight = 0;
    
    if(self.buttonConfiguration == TutorialNotificationButtonConfigrationZeroButtons)
    {
        kTitleLabelHeight = 50;
    }
    else
    {
        kTitleLabelHeight = 64;
    }
    
    CGFloat textPaddingX =  CGRectGetMaxX(self.iconImageView.frame);
    CGFloat textTrailingX = contentPaddingX + 25;
    CGFloat textWidth = notificationWidth - (textPaddingX + textTrailingX);

    self.titleLabel.frame = CGRectMake(textPaddingX + 14,
                                       0,
                                       textWidth,
                                       kTitleLabelHeight);
    
    
    // SWIPE HINT VIEW, ONLY SHOW IF ENABLED
    if(self.swipeToDismissEnabled)
    {
        static const CGFloat kSwipeHintWidth = 37;
        static const CGFloat kSwipeHintHeight = 5;
        static const CGFloat kSwipeHintTrailingY = 5;
        
        self.swipeHintView.frame = CGRectMake(0.5 * (CGRectGetWidth(self.contentView.bounds) - kSwipeHintWidth),
                                              CGRectGetHeight(self.contentView.bounds) - kSwipeHintTrailingY - kSwipeHintHeight,
                                              kSwipeHintWidth,
                                              kSwipeHintHeight);
        
        self.swipeHintView.layer.cornerRadius = CGRectGetHeight(self.swipeHintView.bounds) * 0.5;
    }
    
    // COLORS!!
    self.swipeHintView.backgroundColor = [self _lighterColorForColor:self.showActionButton ? self.firstButtonBackgroundView.backgroundColor : self.backgroundView.backgroundColor];
    self.titleLabel.textColor = self.titleColor;
    
}

#pragma mark - UIScrollView Delegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    
    if (self.notificationDragged == NO) {
        self.notificationDragged = YES;
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate &&
        [self _notificationOffScreen] &&
        self.notificationRevealed) {
        
        [self _destroyNotification];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if ([self _notificationOffScreen] &&
        self.notificationRevealed) {
        [self _destroyNotification];
    }
}

#pragma mark - UIDynamicAnimator Delegate

- (void)dynamicAnimatorDidPause:(UIDynamicAnimator *)animator{
    [self _destroyNotification];
}

#pragma mark - Class Methods

+ (TutorialNotification *)notificationWithHostViewController:(UIViewController *)hostViewController title:(NSString *)title subtitle:(NSString *)subtitle backgroundColor:(UIColor *)color iconImage:(UIImage *)image
{
    TutorialNotification *newNotification = [TutorialNotification notificationWithTitle:title subtitle:subtitle backgroundColor:color iconImage:image];
    
    newNotification.hostViewController = hostViewController;
    
    return newNotification;
    
}

+ (TutorialNotification *)notificationWithTitle:(NSString *)title subtitle:(NSString *)subtitle backgroundColor:(UIColor *)color iconImage:(UIImage *)image
{
    TutorialNotification *newNotification = [TutorialNotification new];
    newNotification.title = title;
    newNotification.backgroundColor = color;
    newNotification.iconImage = image;
    
    return newNotification;
}

#pragma mark - Getters & Setters

- (UIColor *)backgroundColor
{
    return self.backgroundView.backgroundColor;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    // do not actually set the background color of the base view (scrollView)
    self.backgroundView.backgroundColor = backgroundColor;
    
}

- (void)setTitle:(NSString *)title
{
    _title = title;
    
    if (!self.titleLabel) {
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:self.titleLabel];
        
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.titleLabel.font = [UIFont fontWithName:@"OpenSans-Semibold" size:14];
        self.titleLabel.numberOfLines = 4;
        self.titleLabel.adjustsFontSizeToFitWidth = YES;
    }
    
    self.titleLabel.text = title;
    [self setNeedsLayout];
}

- (void)setIconImage:(UIImage *)iconImage {
    
    _iconImage = iconImage;
    
    if (!self.iconImageView) {
        self.iconImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:self.iconImageView];
    }
    
    self.iconImageView.image = iconImage;
    [self setNeedsLayout];
}

- (void)setBackgroundTapsEnabled:(BOOL)allowBackgroundTaps {
    
    NSParameterAssert(self.backgroundView);
    
    _backgroundTapsEnabled = allowBackgroundTaps;
    
    // remove existing tapRecognizers
    for (UIGestureRecognizer *recognizer in self.backgroundView.gestureRecognizers.copy) {
        [self.backgroundView removeGestureRecognizer:recognizer];
    }
    
    if (allowBackgroundTaps) {
        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_backgroundTapped:)];
        [self.backgroundView addGestureRecognizer:tapRecognizer];
    }
    
}

- (void)setSwipeToDismissEnabled:(BOOL)swipeToDismissEnabled
{
    _swipeToDismissEnabled = swipeToDismissEnabled;
    
    self.scrollEnabled = swipeToDismissEnabled;
    
    if (swipeToDismissEnabled)
    {
        if (!self.swipeHintView)
        {
            self.swipeHintView = [[UIView alloc] initWithFrame:CGRectZero];
            [self.contentView addSubview:self.swipeHintView];
        }
    }
}

- (void)setHostViewController:(UIViewController *)hostViewController {
    
    if (self.notificationRevealed && hostViewController == nil) {
        NSAssert(NO, @"Cannot set hostViewController to nil after the Notification has been revealed.");
    } else {
        _hostViewController = hostViewController;
    }
    
}

#pragma mark - Public Methods

- (void)setButtonConfiguration:(TutorialNotificationButtonConfigration)configuration withButtonTitles:(NSArray *)buttonTitles
{
    self.buttonConfiguration = configuration;
    NSInteger buttonTag = configuration;
    
    switch (configuration)
    {
        case TutorialNotificationButtonConfigrationZeroButtons:
        {
            NSParameterAssert(buttonTitles == nil || buttonTitles.count == 0);
            self.firstButton = nil;
            self.firstButtonBackgroundView = nil;
            self.showActionButton = NO;
            
            break;
        }
            
        // deliberately grabbing one and two button states
        case TutorialNotificationButtonConfigrationOneButton:
        case TutorialNotificationButtonConfigrationTwoButton:
        {
            // note: configuration typedef value is matches # of buttons
            NSParameterAssert(buttonTitles.count == configuration);
            
            _showActionButton = YES;

            NSString *firstButtonTitle = buttonTitles[0];
            if (!self.firstButton)
            {
                self.firstButtonBackgroundView = [UIView new];
                self.firstButtonBackgroundView.backgroundColor = [UIColor colorWithRed:82/255.0
                                                                                 green:110/255.0
                                                                                  blue:196/255.0
                                                                                 alpha:1];
               
                [self.contentView addSubview:self.firstButtonBackgroundView];
                
                self.firstButton = [self _newButtonWithTitle:firstButtonTitle withTag:buttonTag];
                [self.contentView addSubview:self.firstButton];
               
                [self.contentView bringSubviewToFront:self.swipeHintView];
            }
            else
            {
                [self.firstButton setTitle:firstButtonTitle forState:UIControlStateNormal];
                [self.contentView addSubview:self.firstButtonBackgroundView];
                [self.contentView bringSubviewToFront:self.swipeHintView];
            }
            
            break;
        }

    }
    
    [self setNeedsLayout];
    
}

- (void)show {
    
    [self _showNotification];
    
}

- (void)showWithButtonHandler:(TutorialNotificationButtonHandler)buttonHandler {
    
    self.buttonHandler = buttonHandler;
    
    [self _showNotification];
    
}

- (void)dismissWithAnimation:(BOOL)animated {
    
    [self _dismissAnimated:animated];
    
}

#pragma mark - Private Methods - Show/Dismiss

- (void)_showNotification {
    
    // Called to display the initiliased notification on screen.
   
    self.notificationDestroyed = NO;
    self.notificationRevealed = YES;
    
    [self _setupNotificationViews];
    
    switch (self.animationType) {
        case TutorialNotificationAnimationTypeLinear: {
            
            // move notification off-screen
            self.contentOffset = CGPointMake(0, CGRectGetHeight(self.bounds));
            
            [UIView animateWithDuration:kLinearAnimationTime animations:^{
                self.contentOffset = CGPointZero;
            } completion:^(BOOL finished) {
                [self _startDismissTimerIfSet];
            }];
            
            break;
        }
            
        case TutorialNotificationAnimationTypeDrop: {
            
            self.backgroundView.center = CGPointMake(self.center.x,
                                                     self.center.y - CGRectGetHeight(self.bounds));
            
            self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self];
            
            UIGravityBehavior* gravityBehavior = [[UIGravityBehavior alloc] initWithItems:@[self.backgroundView]];
            [self.animator addBehavior:gravityBehavior];
            
            CGFloat notificationWidth = CGRectGetWidth(self.bounds);
            CGFloat notificationHeight = CGRectGetHeight(self.bounds);
            
            UICollisionBehavior* collisionBehavior = [[UICollisionBehavior alloc] initWithItems:@[self.backgroundView]];
            [collisionBehavior addBoundaryWithIdentifier:@"TutorialNotificationBoundary"
                                               fromPoint:CGPointMake(0, notificationHeight)
                                                 toPoint:CGPointMake(notificationWidth, notificationHeight)];
            
            [self.animator addBehavior:collisionBehavior];
            
            UIDynamicItemBehavior *elasticityBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.backgroundView]];
            elasticityBehavior.elasticity = 0.3f;
            [self.animator addBehavior:elasticityBehavior];
            
            [self _startDismissTimerIfSet];
            
            break;
        }
            
        case TutorialNotificationAnimationTypeSnap: {
            
            self.backgroundView.center = CGPointMake(self.center.x,
                                                     self.center.y - 2 * CGRectGetHeight(self.bounds));
            
            self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self];
            
            CGPoint centerPoint = CGPointMake(CGRectGetWidth(self.bounds) * 0.5,
                                              CGRectGetHeight(self.bounds) * 0.5);
            
            UISnapBehavior *snapBehaviour = [[UISnapBehavior alloc] initWithItem:self.backgroundView snapToPoint:centerPoint];
            snapBehaviour.damping = 0.50f;
            [self.animator addBehavior:snapBehaviour];
            
            [self _startDismissTimerIfSet];
            break;
        }
            
    }
    
}

- (void)_dismissAnimated:(BOOL)animated {
    
    // Call this method to dismiss the notification. The notification will dismiss in the same animation as it appeared on screen. If the 'animated' variable is set NO, the notification will disappear without any animation.
    CGRect viewBounds = [self.superview bounds];
    if (animated) {
        
        switch (self.animationType) {
            
            // deliberately capturing 2 cases
            case TutorialNotificationAnimationTypeLinear:
            case TutorialNotificationAnimationTypeDrop: {
                
                [UIView animateWithDuration:kLinearAnimationTime animations:^{
                    self.contentOffset = CGPointMake(0, CGRectGetHeight(self.bounds));
                } completion:^(BOOL finished){
                    [self _destroyNotification];
                }];
                break;
            }
                
            case TutorialNotificationAnimationTypeSnap: {
                self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self];
                [self.animator setDelegate:self];
                UISnapBehavior *snapBehaviour = [[UISnapBehavior alloc] initWithItem:self.backgroundView snapToPoint:CGPointMake(viewBounds.size.width, -74)];
                snapBehaviour.damping = 0.75f;
                [self.animator addBehavior:snapBehaviour];
                break;
            }
        }
        
    } else {
        
        [self _destroyNotification];
    }
    
}

#pragma mark - Private Methods - Taps & Gestures

- (void)_buttonTapped:(UIButton *)button {
    
    [self _responderTapped:button];
    
}

- (void)_backgroundTapped:(UITapGestureRecognizer *)tapRecognizer {
    
    [self _responderTapped:self.backgroundView];
    
}

#pragma mark - Private Methods

//Color methods to create a darker and lighter tone of the notification background color. These colors are used for providing backgrounds to button and make sure that buttons are suited to all color environments.
- (UIColor *)_darkerColorForColor:(UIColor *)color
{
    CGFloat r,g,b,a;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        static const CGFloat minValue = 0.0;
        return [UIColor colorWithRed:MAX(r + kColorAdjustmentDark, minValue)
                               green:MAX(g + kColorAdjustmentDark, minValue)
                                blue:MAX(b + kColorAdjustmentDark, minValue)
                               alpha:a];
    } else {
        return nil;
    }
}

- (UIColor *)_lighterColorForColor:(UIColor *)color
{
    CGFloat r, g, b, a;
    if ([color getRed:&r green:&g blue:&b alpha:&a]){
        static const CGFloat maxValue = 1.0;
        return [UIColor colorWithRed:MIN(r + kColorAdjustmentLight, maxValue)
                               green:MIN(g + kColorAdjustmentLight, maxValue)
                                blue:MIN(b + kColorAdjustmentLight, maxValue)
                               alpha:a];
    } else {
        return nil;
    }
    
}

- (UIWindow *)_topAppWindow {
    return ([UIApplication sharedApplication].keyWindow) ?: [[UIApplication sharedApplication].windows lastObject];
}

- (void)_startDismissTimerIfSet {
    
    if (self.duration > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.notificationDragged == NO && self.notificationDestroyed == NO)
            {
                [self _dismissAnimated:YES];
            }
        });
    }
    
}

- (UIButton *)_newButtonWithTitle:(NSString *)title withTag:(NSInteger)tag {
    
    UIButton *newButton = [[UIButton alloc] initWithFrame:CGRectZero];
    newButton.tag = tag;
    
    if(title)
    {
       [newButton setTitle:title forState:UIControlStateNormal];
        newButton.titleLabel.font = [UIFont fontWithName:@"OpenSans-Regular" size:13];;
    }
    else
    {
       [newButton setImage:[UIImage imageNamed:@"fav_tutorial_close"] forState:UIControlStateNormal];
    }
    
    [newButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [newButton setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
    
    [newButton addTarget:self action:@selector(_buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
//    newButton.backgroundColor = [UIColor redColor];
    
    return newButton;
    
}

- (void)_destroyNotification {
    
    if (!self.notificationDestroyed) {
        self.notificationDestroyed = YES;
        
        if (self.hostViewController == nil) {
            [[[[UIApplication sharedApplication] delegate] window] setWindowLevel:self.windowLevel];
        }
        
        [self _dismissBlockHandler];
        
        self.animator.delegate = nil;
        self.animator = nil;
        
        [self removeFromSuperview];
    }
    
}

- (BOOL)_notificationOffScreen {
    
    return (self.contentOffset.y >= CGRectGetHeight(self.bounds));
    
}

- (void)_responderTapped:(UIView *)responder {
    
    [self _dismissAnimated:YES];
    
    if (self.buttonHandler) {
        self.buttonHandler(self, responder.tag);
    }
    
}

- (void)_dismissBlockHandler
{
    if (self.dismissHandler) {
        self.dismissHandler(self);
        self.dismissHandler = nil;
    }
}

- (void)_setupNotificationViews {
    
    if (self.hostViewController) {
        
        [self.hostViewController.view addSubview:self];
        
    } else {
        
        UIWindow *window = [self _topAppWindow];
        
        self.windowLevel = [[[[UIApplication sharedApplication] delegate] window] windowLevel];
        
        // Update windowLevel to make sure status bar does not interfere with the notification
        [[[[UIApplication sharedApplication] delegate] window] setWindowLevel:UIWindowLevelStatusBar+1];
        
        // add the notification to the screen
//        [window.subviews.lastObject addSubview:self];
        [window addSubview:self];
        
    }
    
    UIView *superview = self.superview;
    CGFloat topInsets = self.superview.safeAreaInsets.top;
    CGFloat height = _showActionButton ? kNotificationHeight + 30 : kNotificationHeight;
    self.frame = CGRectMake(0, 0, CGRectGetWidth(superview.bounds), height + topInsets);
    self.contentSize = CGSizeMake(CGRectGetWidth(self.bounds), 2 * CGRectGetHeight(self.bounds));
    self.backgroundView.frame = self.bounds;
    self.contentView.frame = CGRectMake(0, topInsets, CGRectGetWidth(self.bounds), height);
}

@end
