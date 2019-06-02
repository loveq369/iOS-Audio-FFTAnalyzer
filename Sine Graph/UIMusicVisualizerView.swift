//
//  VisualizerView.swift
//  Sine Graph
//
//  Created by Shahar Ben-Dor on 1/30/19.
//  Copyright © 2019 Specter. All rights reserved.
//

import Foundation
import AVFoundation
import Accelerate
import AudioToolbox
import UIKit

@IBDesignable
class UIMusicVisualizerView: UIPlotView, FFTAnalyzerListener {
    let audioEngine = AVAudioEngine()
    let audioNode = AVAudioPlayerNode()
    
    var fftAnalyzer: FFTAnalyzer?
    
    @IBInspectable var minFrequency: Int = 20
    @IBInspectable var maxFrequency: Int = 20000
    @IBInspectable var delay: Double = 0
    
    var waveColor: UIColor = .white {
        didSet {
            (layer as? CAShapeLayer)?.fillColor = waveColor.cgColor
        }
    }
    
    enum VisualizerType {
        case bottomOnly, topOnly, topBottom
    }
    
    init(frame: CGRect) {
        super.init(frame: frame, plot: Plot(yVals: 0, 0), path: nil, graphWindow: GraphWindow(minX: 0, maxX: 1, minY: 0, maxY: 1))
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.plot = Plot(yVals: 0, 0)
        self.path = nil
        self.graphWindow = GraphWindow(minX: 0, maxX: 1, minY: 0, maxY: 1)
    }
    
    var type: VisualizerType = .topOnly {
        didSet {
            switch type {
            case .topOnly:
                graphWindow.minY = 0
                graphWindow.maxY = abs(graphWindow.maxY)
                break
            case .bottomOnly:
                graphWindow.minY = -1 * abs(graphWindow.maxY)
                graphWindow.maxY = 0
                break
            case .topBottom:
                graphWindow.minY = -1 * abs(graphWindow.maxY)
                graphWindow.maxY = abs(graphWindow.maxY)
                break
            }
        }
    }
        
    func attach(to fft: FFTAnalyzer) {
        fft.addListener(self)
    }
    
    func didPerformFFT(plot: FFTPlot) {
        var vals = plot.mapToRange(minFrequency: minFrequency, maxFrequency: maxFrequency)
        
        for _ in 0 ..< (self.normalizeFactor > 0 ? self.normalizeFactor : self.normalizeFactor + 1) {
            vals.insert(0, at: 0)
            vals.append(0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak this = self] in
            this?.plot?.yVals = vals
            this?.animateCurve(with: 0.1)
        }
    }

    override public class var layerClass: AnyClass {
        get {
            return CAShapeLayer.self
        }
    }
    
    private func animateCurve(with duration: CFTimeInterval) {
        if let plot = plot {
            let newPath = UIBezierPath()
            
            let points = plot.plotPoints(on: graphWindow, with: bounds, normalizeFactor: normalizeFactor)
            
            let cubicCurveAlgorithm = CubicCurveAlgorithm()
            let controlPoints = cubicCurveAlgorithm.controlPointsFromPoints(dataPoints: points)
            
            for (i, var point) in points.enumerated() {
                if type == .bottomOnly {
                    point.y = -1 * point.y
                }
                
                if i == 0 {
                    newPath.move(to: point)
                } else if isSmooth {
                    let segment = controlPoints[i - 1]
                    
                    var cp1 = segment.controlPoint1
                    var cp2 = segment.controlPoint2
                    
                    if type == .bottomOnly {
                        cp1.y = -1 * cp1.y
                        cp2.y = -1 * cp2.y
                    }
                    
                    newPath.addCurve(to: point, controlPoint1: cp1, controlPoint2: cp2)
                } else {
                    newPath.addLine(to: point)
                }
            }
            
            if type == .topBottom {
                let newYVals = plot.yVals.compactMap { (-1 * $0) }
                
                let bottomPlot = Plot(yVals: newYVals)
                let bottomPoints = bottomPlot.plotPoints(on: graphWindow, with: bounds, normalizeFactor: normalizeFactor)
                
                let bottomCubicCurveAlgorithm = CubicCurveAlgorithm()
                let bottomControlPoints = bottomCubicCurveAlgorithm.controlPointsFromPoints(dataPoints: bottomPoints.reversed())
                
                for (i, point) in bottomPoints.reversed().enumerated() {
                    let pointConverted = point
                    
                    if i == 0 {
                        newPath.addLine(to: pointConverted)
                    } else if isSmooth {
                        let segment = bottomControlPoints[i - 1]
                        
                        let cp1 = segment.controlPoint1
                        let cp2 = segment.controlPoint2
                        
                        newPath.addCurve(to: pointConverted, controlPoint1: cp1, controlPoint2: cp2)
                    } else {
                        newPath.addLine(to: pointConverted)
                    }
                }
            }
            
            if duration > 0 {
                let pathAnimation = CABasicAnimation(keyPath: "path")
                pathAnimation.fromValue = path?.cgPath
                pathAnimation.toValue = newPath.cgPath
                pathAnimation.duration = duration
                pathAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                
                layer.add(pathAnimation, forKey: "pathAnimation")
            } else {
                (layer as! CAShapeLayer).path = newPath.cgPath
            }
            
            path = newPath
        }
    }
}

extension Collection where Iterator.Element == String {
    var doubleArray: [Double] {
        return compactMap{ Double($0) }
    }
    
    var floatArray: [Float] {
        return compactMap{ Float($0) }
    }
}
