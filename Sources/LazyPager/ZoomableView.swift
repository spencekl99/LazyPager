//
//  ZoomableView.swift
//  ImageScrollView
//
//  Created by Brian Floersch on 7/4/23.
//

import Foundation
import UIKit
import SwiftUI

class ZoomableView: UIScrollView, UIScrollViewDelegate {
    
    var trailingConstraint: NSLayoutConstraint?
    var leadingConstraint: NSLayoutConstraint?
    
    var contentTopToContent: NSLayoutConstraint!
    var contentTopToFrame: NSLayoutConstraint!
    var contentBottomToFrame: NSLayoutConstraint!
    var contentBottomToView: NSLayoutConstraint!
    
    var config: Config
    var bottomView: UIView
    var allowScroll: Bool = true {
        didSet {
            if allowScroll {
                contentTopToFrame.isActive = false
                contentBottomToFrame.isActive = false
                bottomView.isHidden = false
                
                contentTopToContent.isActive = true
                contentBottomToView.isActive = true
            } else {
                contentTopToContent.isActive = false
                contentBottomToView.isActive = false
                
                contentTopToFrame.isActive = true
                contentBottomToFrame.isActive = true
                bottomView.isHidden = true
            }
        }
    }
    
    var wasTracking = false
    var isAnimating = false
    var isZoomHappening = false
    var lastInset: CGFloat = 0
    var view: UIView
    
    var index: Int
    init(view: UIView, index: Int, config: Config) {
        self.index = index
        self.view = view
        self.config = config
        let v = UIView()
        bottomView = v
        
        super.init(frame: .zero)
        
        translatesAutoresizingMaskIntoConstraints = false
        delegate = self
        maximumZoomScale = config.maxZoom
        minimumZoomScale = config.minZoom
        bouncesZoom = true
        backgroundColor = .clear
        alwaysBounceVertical = false
        contentInsetAdjustmentBehavior = .always
        if config.dismissCallback != nil {
            alwaysBounceVertical = true
        }
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        addSubview(view)
        
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),
            view.heightAnchor.constraint(equalTo: frameLayoutGuide.heightAnchor),
        ])
        
        contentTopToFrame = view.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor)
        contentTopToContent = view.topAnchor.constraint(equalTo: topAnchor)
        contentBottomToFrame = view.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor)
        contentBottomToView = view.bottomAnchor.constraint(equalTo: v.topAnchor)
        
        v.translatesAutoresizingMaskIntoConstraints = false
        addSubview(v)
        
        // This is for future support of a drawer view
        let constant: CGFloat = config.dismissCallback == nil ? 0 : 1
        
        NSLayoutConstraint.activate([
            v.bottomAnchor.constraint(equalTo: bottomAnchor),
            v.leadingAnchor.constraint(equalTo: frameLayoutGuide.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: frameLayoutGuide.trailingAnchor),
            v.heightAnchor.constraint(equalToConstant: constant)
        ])
        
        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(singleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.numberOfTouchesRequired = 1
        addGestureRecognizer(singleTapGesture)
        
        switch config.doubleTapSetting {
        case .scale:
            let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
            doubleTapRecognizer.numberOfTapsRequired = 2
            doubleTapRecognizer.numberOfTouchesRequired = 1
            addGestureRecognizer(doubleTapRecognizer)
            
            singleTapGesture.require(toFail: doubleTapRecognizer)
        default: break
        }
        
        DispatchQueue.main.async {
            self.updateState()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    @objc func singleTap(_ recognizer: UITapGestureRecognizer) {
        config.tapCallback?()
    }
    
    @objc func doubleTap(_ recognizer:UITapGestureRecognizer) {
        if case let .scale(scale) = config.doubleTapSetting {
            let pointInView = recognizer.location(in: view)
            zoomInOrOut(at: pointInView, scale: scale)
        }
    }
    
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        isZoomHappening = true
        updateState()
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        isZoomHappening = false
        updateState()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateState()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView.subviews[0]
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        
        let w: CGFloat = view.intrinsicContentSize.width * UIScreen.main.scale
        let h: CGFloat = view.intrinsicContentSize.height * UIScreen.main.scale


        let ratioW = view.frame.width / w
        let ratioH = view.frame.height / h

        let ratio = ratioW < ratioH ? ratioW : ratioH

        let newWidth = w*ratio
        let newHeight = h*ratio

        let left = 0.5 * (newWidth * scrollView.zoomScale > view.frame.width
                          ? (newWidth - view.frame.width)
                          : (scrollView.frame.width - view.frame.width))
        let top = 0.5 * (newHeight * scrollView.zoomScale > view.frame.height
                         ? (newHeight - view.frame.height)
                         : (scrollView.frame.height - view.frame.height))

        if zoomScale <= maximumZoomScale {
            contentInset = UIEdgeInsets(top: top - safeAreaInsets.top, left: left, bottom: top - safeAreaInsets.bottom, right: left)
        }
        
    }
    
    func updateState() {
        
        allowScroll = zoomScale == 1

        if contentOffset.y > 10 && zoomScale == 1 {
            allowScroll = true
            pinchGestureRecognizer?.isEnabled = false
        } else {
            pinchGestureRecognizer?.isEnabled = true
        }
        
        if allowScroll {
            // Counteract content inset adjustments. Makes .ignoresSafeArea() work
            contentInset = UIEdgeInsets(top: -safeAreaInsets.top, left: 0, bottom: -safeAreaInsets.bottom, right: 0)
            
            
            if !isAnimating, config.dismissCallback != nil {
                let offset = contentOffset.y
                if offset < 0 {
                    let nrom = normalize(from: 0, at: abs(offset), to: frame.size.height)
                    let norm2 = normalize(from: 0, at: nrom, to: config.fullFadeOnDragAt)
                    config.backgroundOpacity?.wrappedValue = 1 - norm2
                } else {
                    config.backgroundOpacity?.wrappedValue = 1
                }
            }
            
            wasTracking = isTracking
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        
        let offset = contentOffset.y
        let percentage = offset / (contentSize.height - bounds.size.height)
        
        if wasTracking, percentage < -config.dismissTriggerOffset,
           !isZoomHappening,
            velocity.y < -config.dismissVelocity,
           config.dismissCallback != nil {
            isAnimating = true
            let ogFram = frame.origin
            DispatchQueue.main.async {
                withAnimation(.linear(duration: self.config.dismissAnimationLength)) {
                    self.config.backgroundOpacity?.wrappedValue = 0
                }
                UIView.animate(withDuration: self.config.dismissAnimationLength, animations: {
                    self.frame.origin = CGPoint(x: ogFram.x, y: self.frame.size.height)
                }) { _ in
                    if self.config.shouldCacnelSwiftUIAnimationsOnDismiss {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            self.config.dismissCallback?()
                        }
                    } else {
                        self.config.dismissCallback?()
                    }
                }
            }
        }
    }
    
    func zoomInOrOut(at point: CGPoint, scale: CGFloat) {
        let mid = lerp(from: minimumZoomScale, to: maximumZoomScale, by: scale)
        let newZoomScale = zoomScale == minimumZoomScale ? mid : minimumZoomScale
        let size = bounds.size
        let w = size.width / newZoomScale
        let h = size.height / newZoomScale
        let x = point.x - (w * 0.5)
        let y = point.y - (h * 0.5)
        let rect = CGRect(x: x, y: y, width: w, height: h)
        zoom(to: rect, animated: true)
    }
}

