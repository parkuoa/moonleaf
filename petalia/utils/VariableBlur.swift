import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins
import QuartzCore

public enum VariableBlurDirection {
    case blurredTopClearBottom
    case blurredBottomClearTop
}

public struct VariableBlurView: NSViewRepresentable {
    public var maxBlurRadius: CGFloat = 20
    public var direction: VariableBlurDirection = .blurredTopClearBottom
    public var startOffset: CGFloat = 0
    
    public init(maxBlurRadius: CGFloat = 20, direction: VariableBlurDirection = .blurredTopClearBottom, startOffset: CGFloat = 0) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.startOffset = startOffset
    }
    
    public func makeNSView(context: Context) -> VariableBlurNSView {
        VariableBlurNSView(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset)
    }

    public func updateNSView(_ nsView: VariableBlurNSView, context: Context) {
        nsView.updateFilters(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset)
    }
}

open class VariableBlurNSView: NSView {
    private var maxBlurRadius: CGFloat
    private var direction: VariableBlurDirection
    private var startOffset: CGFloat
    
    public init(maxBlurRadius: CGFloat = 20, direction: VariableBlurDirection = .blurredTopClearBottom, startOffset: CGFloat = 0) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.startOffset = startOffset
        super.init(frame: .zero)
        
        self.wantsLayer = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func makeBackingLayer() -> CALayer {
        let clsName = "CABackdropLayer"
        if let BackdropClass = NSClassFromString(clsName) as? CALayer.Type {
            return BackdropClass.init()
        }
        return super.makeBackingLayer()
    }
    
    open override func updateLayer() {
        super.updateLayer()
        applyVariableBlur()
    }
    
    public func updateFilters(maxBlurRadius: CGFloat, direction: VariableBlurDirection, startOffset: CGFloat) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.startOffset = startOffset
        applyVariableBlur()
    }
    
    private func applyVariableBlur() {
        guard let layer = self.layer else { return }
        
        let clsName = String("retliFAC".reversed()) // CAFilter
        guard let Cls = NSClassFromString(clsName)! as? NSObject.Type else {
            print("[VariableBlur] Error: Can't find filter class")
            return
        }
        let selName = String(":epyThtiWretlif".reversed()) // filterWithType:
        guard let variableBlur = Cls.self.perform(NSSelectorFromString(selName), with: "variableBlur").takeUnretainedValue() as? NSObject else {
            print("[VariableBlur] Error: Can't create variableBlur filter")
            return
        }

        let gradientImage = makeGradientImage(width: 100, height: 100, startOffset: startOffset, direction: direction)

        variableBlur.setValue(maxBlurRadius, forKey: "inputRadius")
        variableBlur.setValue(gradientImage, forKey: "inputMaskImage")
        variableBlur.setValue(true, forKey: "inputNormalizeEdges")

        layer.filters = [variableBlur]
    }
    
    private func makeGradientImage(width: CGFloat = 100, height: CGFloat = 100, startOffset: CGFloat, direction: VariableBlurDirection) -> CGImage {
        let ciGradientFilter = CIFilter.linearGradient()
        ciGradientFilter.color0 = CIColor.black
        ciGradientFilter.color1 = CIColor.clear
        ciGradientFilter.point0 = CGPoint(x: 0, y: height)
        ciGradientFilter.point1 = CGPoint(x: 0, y: startOffset * height)
        if case .blurredBottomClearTop = direction {
            ciGradientFilter.point0.y = 0
            ciGradientFilter.point1.y = height - ciGradientFilter.point1.y
        }
        return CIContext().createCGImage(ciGradientFilter.outputImage!, from: CGRect(x: 0, y: 0, width: width, height: height))!
    }
}
