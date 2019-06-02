//
//  GraphView.swift
//  Sine Graph
//
//  Created by Shahar Ben-Dor on 1/28/19.
//  Copyright © 2019 Specter. All rights reserved.
//

import UIKit

class UIPlotView: UIView {
    var plot: Plot?
    var path: UIBezierPath?
    
    var normalizeFactor: Int = 0
    var isSmooth: Bool = false
    
    var graphWindow: GraphWindow!
    
    var strokeColor: UIColor? = UIColor.white
    
    init(frame: CGRect = .zero, plot: Plot?, path: UIBezierPath? = nil, graphWindow: GraphWindow = GraphWindow()) {
        self.plot = plot
        self.path = UIGraphView.getDefaultPath(for: path)
        
        self.graphWindow = graphWindow
        
        super.init(frame: frame)
        
        self.backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func redraw() {
        DispatchQueue.main.async {
            self.setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        path?.removeAllPoints()
        if let plot = plot {
            let points = plot.plotPoints(on: graphWindow, with: bounds, normalizeFactor: normalizeFactor)
            
            let cubicCurveAlgorithm = CubicCurveAlgorithm()
            let controlPoints = cubicCurveAlgorithm.controlPointsFromPoints(dataPoints: points)
            
            for (i, point) in points.enumerated() {
                if i == 0 {
                    path?.move(to: point)
                } else if isSmooth {
                    let segment = controlPoints[i-1]
                    path?.addCurve(to: point, controlPoint1: segment.controlPoint1, controlPoint2: segment.controlPoint2)
                } else {
                    path?.addLine(to: point)
                }
            }
        }
        
        strokeColor?.setStroke()
        if let layer = layer as? CAShapeLayer {
            layer.path = path?.cgPath
        } else {
            path?.stroke()
        }
    }
    
    private static func getDefaultPath(for path: UIBezierPath? = nil) -> UIBezierPath {
        if path == nil {
            let path = UIBezierPath()
            path.lineWidth = 4
            return path
        }
        
        return path!
    }
}

class Plot {
    var yVals: [Double]
    
    init (yVals: [Double]) {
        self.yVals = yVals
    }
    
    init (yVals: Double...) {
        self.yVals = yVals
    }
    
    func plotPoints(on graphWindow: GraphWindow, with bounds: CGRect, normalizeFactor: Int = 0) -> [CGPoint] {
        var points = [CGPoint]()
        
        for (index, yVal) in yVals.enumerated() {
            var realVal = yVal
            var valuesNum = 1
            for i in 0 ..< normalizeFactor {
                if index + i <= (yVals.count - 1) {
                    realVal += yVals[index + i]
                    valuesNum += 1
                }
                
                if index > 0 && index - i >= 0 {
                    realVal += yVals[index - i]
                    valuesNum += 1
                }
            }
            
            realVal /= Double(valuesNum)
            
            let progress = Double(index) / Double(yVals.count > 1 ? yVals.count - 1 : yVals.count)
            points.append(CGPoint(x: progress * Double(bounds.width), y: MathUtils.map(fromMin: graphWindow.maxY, fromMax: graphWindow.minY, toMin: 0, toMax: Double(bounds.height), value: realVal)))
        }
        
        return points
    }
}








struct CubicCurveSegment {
    let controlPoint1: CGPoint
    let controlPoint2: CGPoint
}

class CubicCurveAlgorithm {
    private var firstControlPoints: [CGPoint?] = []
    private var secondControlPoints: [CGPoint?] = []
    
    func controlPointsFromPoints(dataPoints: [CGPoint]) -> [CubicCurveSegment] {
        
        //Number of Segments
        let count = dataPoints.count - 1
        
        //P0, P1, P2, P3 are the points for each segment, where P0 & P3 are the knots and P1, P2 are the control points.
        if count == 1 {
            let P0 = dataPoints[0]
            let P3 = dataPoints[1]
            
            //Calculate First Control Point
            //3P1 = 2P0 + P3
            
            let P1x = (2*P0.x + P3.x)/3
            let P1y = (2*P0.y + P3.y)/3
            
            firstControlPoints.append(CGPoint(x: P1x, y: P1y))
            
            //Calculate second Control Point
            //P2 = 2P1 - P0
            let P2x = (2*P1x - P0.x)
            let P2y = (2*P1y - P0.y)
            
            secondControlPoints.append(CGPoint(x: P2x, y: P2y))
        } else {
            firstControlPoints = Array(repeating: nil, count: count)
            
            var rhsArray = [CGPoint]()
            
            //Array of Coefficients
            var a = [Double]()
            var b = [Double]()
            var c = [Double]()
            
            for i in 0..<count {
                var rhsValueX: CGFloat = 0
                var rhsValueY: CGFloat = 0
                
                let P0 = dataPoints[i];
                let P3 = dataPoints[i+1];
                
                if i==0 {
                    a.append(0)
                    b.append(2)
                    c.append(1)
                    
                    //rhs for first segment
                    rhsValueX = P0.x + 2*P3.x;
                    rhsValueY = P0.y + 2*P3.y;
                    
                } else if i == count-1 {
                    a.append(2)
                    b.append(7)
                    c.append(0)
                    
                    //rhs for last segment
                    rhsValueX = 8*P0.x + P3.x;
                    rhsValueY = 8*P0.y + P3.y;
                } else {
                    a.append(1)
                    b.append(4)
                    c.append(1)
                    
                    rhsValueX = 4*P0.x + 2*P3.x;
                    rhsValueY = 4*P0.y + 2*P3.y;
                }
                
                rhsArray.append(CGPoint(x: rhsValueX, y: rhsValueY))
            }
            
            //Solve Ax=B. Use Tridiagonal matrix algorithm a.k.a Thomas Algorithm
            for i in 1..<count {
                let rhsValueX = rhsArray[i].x
                let rhsValueY = rhsArray[i].y
                
                let prevRhsValueX = rhsArray[i-1].x
                let prevRhsValueY = rhsArray[i-1].y
                
                let m = a[i]/b[i-1]
                
                let b1 = b[i] - m * c[i-1];
                b[i] = b1
                
                let r2x = rhsValueX.d - m * prevRhsValueX.d
                let r2y = rhsValueY.d - m * prevRhsValueY.d
                
                rhsArray[i] = CGPoint(x: r2x, y: r2y)
            }
            //Get First Control Points
            
            //Last control Point
            let lastControlPointX = rhsArray[count-1].x.d/b[count-1]
            let lastControlPointY = rhsArray[count-1].y.d/b[count-1]
            
            firstControlPoints[count-1] = CGPoint(x: lastControlPointX, y: lastControlPointY)
            
            for i in (0 ..< count - 1).reversed() {
                if let nextControlPoint = firstControlPoints[i+1] {
                    let controlPointX = (rhsArray[i].x.d - c[i] * nextControlPoint.x.d)/b[i]
                    let controlPointY = (rhsArray[i].y.d - c[i] * nextControlPoint.y.d)/b[i]
                    
                    firstControlPoints[i] = CGPoint(x: controlPointX, y: controlPointY)
                    
                }
            }
            
            
            //Compute second Control Points from first
            
            for i in 0..<count {
                
                if i == count-1 {
                    let P3 = dataPoints[i+1]
                    
                    guard let P1 = firstControlPoints[i] else{
                        continue
                    }
                    
                    let controlPointX = (P3.x + P1.x)/2
                    let controlPointY = (P3.y + P1.y)/2
                    
                    secondControlPoints.append(CGPoint(x: controlPointX, y: controlPointY))
                    
                } else {
                    let P3 = dataPoints[i+1]
                    
                    guard let nextP1 = firstControlPoints[i+1] else {
                        continue
                    }
                    
                    let controlPointX = 2*P3.x - nextP1.x
                    let controlPointY = 2*P3.y - nextP1.y
                    
                    secondControlPoints.append(CGPoint(x: controlPointX, y: controlPointY))
                }
                
            }
            
        }
        
        var controlPoints = [CubicCurveSegment]()
        
        for i in 0..<count {
            if let firstControlPoint = firstControlPoints[i],
                let secondControlPoint = secondControlPoints[i] {
                let segment = CubicCurveSegment(controlPoint1: firstControlPoint, controlPoint2: secondControlPoint)
                controlPoints.append(segment)
            }
        }
        
        return controlPoints
    }
}

extension CGFloat {
    var d: Double {
        return Double(self)
    }
}
