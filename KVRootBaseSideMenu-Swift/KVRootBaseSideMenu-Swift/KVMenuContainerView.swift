//
//  KVMenuContainerView.swift
//  KVRootBaseSideMenu-Swift
//
//  Created by Keshav on 7/3/16.
//  Copyright © 2016 Keshav. All rights reserved.
//

import UIKit
import KVConstraintExtensionsMaster

public struct KVSideMenu
{
    public struct Notifications {
        static public let toggleLeft   = "ToggleLeftSideMenuNotification"
        static public let toggleRight  = "ToggleRightSideMenuNotification"
        static public let close        = "CloseSideMenuNotification"
    }
    
    enum SideMenuState {
        case None, Left, Right
        init() {
            self = None
        }
    }
    
    public enum AnimationType
    {
        case Default, Window, Folding
        public init() {
            self = Default
        }
    }
    
}

public class KVMenuContainerView: UIView
{
    // MARK: - Properties
    
    private let thresholdFactor: CGFloat = 0.25
    private let KVSideMenuOffsetValueInRatio : CGFloat = 0.75
    private let KVSideMenuHideShowDuration   : CGFloat = 0.4
    
    private let transformScale:CGAffineTransform = CGAffineTransformMakeScale(1.0, 0.8)
    
    private(set) var leftContainerView   :UIView! = UIView.prepareNewViewForAutoLayout()
    private(set) var centerContainerView :UIView! = UIView.prepareNewViewForAutoLayout()
    private(set) var rightContainerView  :UIView! = UIView.prepareNewViewForAutoLayout()
    
    private(set) var currentSideMenuState:KVSideMenu.SideMenuState = KVSideMenu.SideMenuState()
    
    private var appliedConstraint : NSLayoutConstraint? // may be center, leading, trailling
    private var panRecognizer     : UIPanGestureRecognizer? {
        didSet {
            panRecognizer?.delegate = self
            panRecognizer?.maximumNumberOfTouches = 1
            addGestureRecognizer(panRecognizer!)
        }
    }
    
    public var animationType   = KVSideMenu.AnimationType()
    public var allowPanGesture :    Bool = true
    
    /// A Boolean value indicating whether the left swipe is enabled.
    public var allowLeftPaning  : Bool = false {
        didSet{
            rightContainerView.subviews.first?.removeFromSuperview()
        }
    }
    
    /// A Boolean value indicating whether the right swipe is enabled.
    public var allowRightPaning : Bool = false {
        didSet{
            leftContainerView.subviews.first?.removeFromSuperview()
        }
    }
    
    // MARK: - Initialization
    
    required public init(superView:UIView!)
    {
        self.init()
        
        prepareViewForAutoLayout()
        backgroundColor = UIColor.clearColor()
        superView.addSubview(self)
        
        applyConstraintForCenterInSuperview()
        applyEqualHeightPinConstrainToSuperview()
        applyEqualWidthPinConstrainToSuperview()
        
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private override init(frame: CGRect) {
        super.init(frame: frame)
        initialise()
    }
    
    private func initialise()
    {
        let selector: Selector = Selector("didReceivedNotification:")
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name:KVSideMenu.Notifications.toggleLeft, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name:KVSideMenu.Notifications.toggleRight, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name:KVSideMenu.Notifications.close, object: nil)
        
        setupGestureRecognizer()
        
        clipsToBounds = false
        
        leftContainerView.backgroundColor   = backgroundColor
        centerContainerView.backgroundColor = backgroundColor
        rightContainerView.backgroundColor  = backgroundColor
        
        // addSubview order maitter for side shadow
        addSubview(leftContainerView)
        addSubview(rightContainerView)
        addSubview(centerContainerView)
        
        leftContainerView.applyTopAndBottomPinConstraintToSuperviewWithPadding(defualtConstant)
        centerContainerView.applyTopAndBottomPinConstraintToSuperviewWithPadding(defualtConstant)
        rightContainerView.applyTopAndBottomPinConstraintToSuperviewWithPadding(defualtConstant)
        
        centerContainerView.applyConstraintForHorizontallyCenterInSuperview()
        centerContainerView.applyEqualWidthPinConstrainToSuperview()
        
        leftContainerView.applyEqualWidthRatioPinConstrainToSuperview(KVSideMenuOffsetValueInRatio)
        rightContainerView.applyEqualWidthRatioPinConstrainToSuperview(KVSideMenuOffsetValueInRatio)
        
        leftContainerView.applyConstraintFromSiblingViewAttribute(.Trailing, toAttribute: .Leading, ofView: centerContainerView, spacing: defualtConstant)
        centerContainerView.applyConstraintFromSiblingViewAttribute(.Trailing, toAttribute: .Leading, ofView: rightContainerView, spacing: defualtConstant)
        
    }
    
    // MARK: - Deinitialization
    
    deinit
    {
        NSNotificationCenter.defaultCenter().removeObserver(self, name:KVSideMenu.Notifications.close, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name:KVSideMenu.Notifications.toggleLeft, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name:KVSideMenu.Notifications.toggleRight, object: nil)
    }
    
    // Must be public or internal but not private other wise app will crashed.
    func didReceivedNotification(notify:NSNotification)
    {
        if (notify.name == KVSideMenu.Notifications.toggleLeft) {
            toggleLeftSideMenu()
        } else if (notify.name == KVSideMenu.Notifications.toggleRight) {
            toggleRightSideMenu()
        } else if (notify.name == KVSideMenu.Notifications.close) {
            closeSideMenu()
        }
        else{
            
        }
    }
    
    /// Close the side menu if the menu is showed.
    public func closeSideMenu()
    {
        switch (currentSideMenuState)
        {
        case .Left:  closeOpenedSideMenu(leftContainerView, attribute: .Trailing)
            // OR
            // self.toggleLeftSideMenu()
            
        case .Right: closeOpenedSideMenu(rightContainerView, attribute: .Trailing)
            // OR
            // self.toggleRightSideMenu()
            
        default: appliedConstraint?.constant = 0
                 applyAnimations({
                    self.centerContainerView.transform = CGAffineTransformIdentity
                 })
        }
        
    }
    
    /// Toggles the state (open or close) of the left side menu.
    public func toggleLeftSideMenu()
    {
        if allowRightPaning
        {
            endEditing(true)
            backgroundColor  = leftContainerView.subviews.first?.backgroundColor
            
            if (currentSideMenuState == .Right) {
                closeOpenedSideMenu(rightContainerView, attribute: .Trailing)
            }
            
            centerContainerView.accessAppliedConstraintByAttribute(.CenterX) { (appliedConstraint) -> Void in
                if appliedConstraint != nil {
                    self.currentSideMenuState = .Left
                    
                    self.centerContainerView.superview?.removeConstraint(appliedConstraint)
                    self.leftContainerView.applyLeadingPinConstraintToSuperviewWithPadding(defualtConstant)
                    
                    self.handelTransformAnimations()
                }
                else {
                    self.closeOpenedSideMenu(self.leftContainerView, attribute: .Leading, completion: { _ in
                        self.applyAnimations({
                            self.centerContainerView.transform = CGAffineTransformIdentity
                        })
                    })
                }
            }
        }
        else {
            debugPrint("Left SideMenu has beed disable, because leftSideMenuViewController is nil.")
        }
        
    }
    
    /// Toggles the state (open or close) of the right side menu.
    public func toggleRightSideMenu()
    {
        if allowLeftPaning
        {
            endEditing(true)
            backgroundColor  = rightContainerView.subviews.first?.backgroundColor
            
            if (currentSideMenuState == .Left) {
                closeOpenedSideMenu(leftContainerView, attribute: .Leading)
            }
            
            centerContainerView.accessAppliedConstraintByAttribute(.CenterX) { (appliedConstraint) -> Void in
                if appliedConstraint != nil {
                    self.currentSideMenuState = .Right
                    
                    self.centerContainerView.superview?.removeConstraint(appliedConstraint)
                    self.rightContainerView.applyTrailingPinConstraintToSuperviewWithPadding(defualtConstant)
                    
                    self.handelTransformAnimations()
                }
                else {
                    self.closeOpenedSideMenu(self.rightContainerView, attribute: .Trailing, completion: { _ in
                        self.applyAnimations({
                            self.centerContainerView.transform = CGAffineTransformIdentity
                        })
                    })
                }
            }
        }
        else{
            debugPrint("Right SideMenu has beed disable, because rightSideMenuViewController is nil.")
        }
    }
    
    private func handelTransformAnimations()
    {
        if self.animationType == KVSideMenu.AnimationType.Window
        {
            // update Top And Bottom Pin Constraints Of SideMenu
            centerContainerView.applyTopAndBottomPinConstraintToSuperviewWithPadding(22.5)
            // this valus is fixed for orientation so try to avoid it
        }
        
        self.applyAnimations({
            
            if self.animationType == KVSideMenu.AnimationType.Folding
            {
                self.applyTransformAnimations(self.centerContainerView, transform_d: self.transformScale.d )
            }
            else if self.animationType == KVSideMenu.AnimationType.Window
            {
                self.applyTransform3DAnimations(self.centerContainerView, transformRotatingAngle: 22.5)
            }
            else{
                
            }
        })
    }

    
}

// MARK: -  Helpper Methods to Open & Close the SideMenu

extension KVMenuContainerView: UIGestureRecognizerDelegate
{
    // MARK: Gesture recognizer
    
    private func setupGestureRecognizer()
    {
        if allowPanGesture {
            panRecognizer = UIPanGestureRecognizer(target: self, action: "handlePanGesture:")
        }
    }
    
    private dynamic func handlePanGesture(recognizer: UIPanGestureRecognizer)
    {
        let translation = recognizer.translationInView(recognizer.view)
        
        switch(recognizer.state)
        {
        case .Began:
            switch (currentSideMenuState)
            {
            case .Left:
                appliedConstraint = leftContainerView.accessAppliedConstraintByAttribute(.Leading)
            case .Right:
                appliedConstraint = rightContainerView.accessAppliedConstraintByAttribute(.Trailing)
            default:
                appliedConstraint = centerContainerView.accessAppliedConstraintByAttribute(.CenterX)
            }
            
        case .Changed:
            
            if appliedConstraint != nil {
                var xPoint : CGFloat = appliedConstraint!.constant + translation.x
                
                switch (currentSideMenuState)
                {
                case .Left:
                    xPoint = max(-CGRectGetWidth(leftContainerView.bounds), min(CGFloat(xPoint), 0))
                    
                case .Right:
                    xPoint = max(0, min(CGFloat(xPoint), CGRectGetWidth(rightContainerView.bounds)))
                    
                default:
                    
                    if allowLeftPaning && allowRightPaning {
                        xPoint = max(-CGRectGetWidth(rightContainerView.bounds), min(CGFloat(xPoint), CGRectGetWidth(leftContainerView.bounds)))
                    }
                    else if allowLeftPaning {
                        xPoint = max(-CGRectGetWidth(leftContainerView.bounds), min(CGFloat(xPoint), 0))
                    }
                    else if allowRightPaning {
                        xPoint = max(0, min(CGFloat(xPoint), CGRectGetWidth(rightContainerView.bounds)))
                    }
                    else {
                        xPoint = max(0, min(CGFloat(xPoint), 0))
                    }
                    
                }
                
                if animationType == KVSideMenu.AnimationType.Folding
                {
                    let dy = abs(CGFloat(Int(xPoint)))*(1.0 - transformScale.d)/CGRectGetWidth(leftContainerView.bounds)
                    debugPrint(dy)
                    
                    if (currentSideMenuState == .Left || currentSideMenuState == .Right) {
                        applyTransformAnimations(centerContainerView, transform_d: min(1.0, transformScale.d + dy))
                    }
                    else{
                        applyTransformAnimations(centerContainerView, transform_d: min(1.0, abs(1-dy)) )
                    }
                }

                self.appliedConstraint?.constant = CGFloat(Int(xPoint))
                recognizer.setTranslation(CGPointZero, inView: self)
            }
            
        default:
            
            let constaint = appliedConstraint?.constant ?? 0
            
            switch (currentSideMenuState)
            {
            case .Left:     // Negative value
                if abs(constaint) > CGRectGetWidth(leftContainerView.bounds)*thresholdFactor {
                    self.toggleLeftSideMenu();
                }else{
                    self.appliedConstraint?.constant = 0
                    self.applyAnimations({
                        self.applyTransformAnimations(self.centerContainerView, transform_d: self.transformScale.d )
                    })
                }
                
            case .Right:    // Possitive value
                if constaint > CGRectGetWidth(rightContainerView.bounds)*thresholdFactor {
                    self.toggleRightSideMenu();
                }else{
                    self.appliedConstraint?.constant = 0
                    self.applyAnimations({
                        self.applyTransformAnimations(self.centerContainerView, transform_d: self.transformScale.d )
                    })
                }
                
            default:  // None state
                
                if constaint > 0
                {
                    if constaint > CGRectGetWidth(leftContainerView.bounds)*thresholdFactor {
                        self.toggleLeftSideMenu();
                    }else{
                        self.closeSideMenu()
                    }
                }
                else if constaint < 0
                {
                    if abs(constaint) > CGRectGetWidth(rightContainerView.bounds)*thresholdFactor {
                        self.toggleRightSideMenu();
                    }else{
                        self.closeSideMenu()
                    }
                }
            }
            
            appliedConstraint = nil
        }
        
    }
    
    override public func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panRecognizer {
            return (allowPanGesture && (allowLeftPaning || allowRightPaning ))
        }
        
        return false
    }
    
}

// MARK: -  Helpper methods to Open & Close the SideMenu

private extension KVMenuContainerView
{
    func closeOpenedSideMenu(view:UIView, attribute: NSLayoutAttribute, completion: (Void -> Void)? = nil )
    {
        view.accessAppliedConstraintByAttribute(attribute, completion: { (appliedConstraint) -> Void in
            if appliedConstraint != nil {
                self.currentSideMenuState = .None
                view.superview?.removeConstraint(appliedConstraint)
                self.centerContainerView.applyConstraintForHorizontallyCenterInSuperview()
                self.centerContainerView.applyTopAndBottomPinConstraintToSuperviewWithPadding(defualtConstant)
                if completion == nil {
                    self.updateModifyConstraints()
                }else{
                    completion?()
                }
            }
        })
    }
    
}

// MARK: -  Helpper methods to apply animation & shadow with SideMenu

private extension KVMenuContainerView
{
    func applyAnimations(completionHandler: (Void -> Void)? = nil)
    {
        // let options : UIViewAnimationOptions = [.AllowUserInteraction, .OverrideInheritedCurve, .LayoutSubviews, .BeginFromCurrentState, .CurveEaseOut]
        
        let options : UIViewAnimationOptions = [.AllowUserInteraction, .LayoutSubviews, .BeginFromCurrentState, .CurveLinear, .CurveEaseOut]
        let duration = NSTimeInterval(self.KVSideMenuHideShowDuration)
        
        UIView.animateWithDuration(duration, delay: 0, usingSpringWithDamping: 0.95, initialSpringVelocity: 10, options: options, animations: { _ in
            self.updateModifyConstraints()
            self.setNeedsUpdateConstraints()
            self.applyShadow(self.centerContainerView)
            completionHandler?()
            }, completion: nil)
    }
    
    func applyTransformAnimations(view:UIView!,transform_d:CGFloat) {
        view.transform.d = transform_d
    }
    
    func applyTransform3DAnimations(view:UIView!,transformRotatingAngle:CGFloat)
    {
        let layerTemp : CALayer = view.layer
        layerTemp.zPosition = 1000
        
        var tRotate : CATransform3D = CATransform3DIdentity
        tRotate.m34 = 1.0/(500)
        
        let aXpos: CGFloat = CGFloat(22.5*((currentSideMenuState == .Right) ? -1.0 : 1.0)*(M_PI/180))
        tRotate = CATransform3DRotate(tRotate,aXpos, 0, 1, 0)
        layerTemp.transform = tRotate
        
    }
    
    func applyShadow(shadowView:UIView)
    {
        let shadowViewLayer : CALayer = shadowView.layer
        shadowViewLayer.shadowColor = shadowView.backgroundColor?.CGColor
        shadowViewLayer.shadowOpacity = 0.4
        shadowViewLayer.shadowRadius = 4.0
        shadowViewLayer.rasterizationScale = (self.window?.screen.scale)!
        
        if (self.currentSideMenuState == .Left) {
            shadowViewLayer.shadowOffset = CGSizeMake(-2, 2)
        } else if (self.currentSideMenuState == .Right){
            shadowViewLayer.shadowOffset = CGSizeMake(0, 2)
        } else {
            shadowViewLayer.shadowRadius = 3
            shadowViewLayer.shadowOpacity = 0
            shadowViewLayer.shadowOffset = CGSizeMake(0, -3)
            shadowViewLayer.shadowColor = nil
        }
    }
    
    
}