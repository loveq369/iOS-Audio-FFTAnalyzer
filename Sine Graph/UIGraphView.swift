//
//  GraphView.swift
//  Sine Graph
//
//  Created by Shahar Ben-Dor on 1/28/19.
//  Copyright © 2019 Specter. All rights reserved.
//

import UIKit

class UIGraphView: UIView {
    var graph: Graph?
    var path: UIBezierPath?
    var percision: Double = 0.001
    
    var graphWindow: GraphWindow!
    
    var strokeColor: UIColor? = UIColor.white
    
    init(frame: CGRect = .zero, graph: Graph?, path: UIBezierPath? = nil, graphWindow: GraphWindow = GraphWindow()) {
        self.graph = graph
        self.path = UIGraphView.getDefaultPath(for: path)
        
        self.graphWindow = graphWindow
        
        super.init(frame: frame)
        
        self.backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func redraw(percision: Double = 0.001) {
        self.percision = percision
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        path?.removeAllPoints()
        if let graph = graph {
            for i in stride(from: 0.0, to: 1 + percision, by: percision) {
                let point = graph.pointForProgress(i, graphWindow: graphWindow, bounds: bounds)
                
                i == 0.0 ? path?.move(to: point) : path?.addLine(to: point)
            }
        }
        
        strokeColor?.setStroke()
        path?.stroke()
    }
    
    public static func getDefaultPath(for path: UIBezierPath? = nil) -> UIBezierPath {
        if path == nil {
            let path = UIBezierPath()
            path.lineWidth = 4
            return path
        }
        
        return path!
    }
}

class Graph {
    var function: ((Double) -> (Double))!
    
    init (function: ((Double) -> (Double))!) {
        self.function = function
    }
    
    func pointForProgress(_ progress: Double, graphWindow: GraphWindow, bounds: CGRect) -> CGPoint {
        let convertToWindowX = MathUtils.map(fromMin: 0, fromMax: 1, toMin: graphWindow.minX, toMax: graphWindow.maxX, value: progress)
        let y = function(convertToWindowX)
        return CGPoint(x: progress * Double(bounds.width), y: MathUtils.map(fromMin: graphWindow.maxY, fromMax: graphWindow.minY, toMin: 0, toMax: Double(bounds.height), value: y))
    }
    
    func pointForX(_ xValue: Double, graphWindow: GraphWindow, bounds: CGRect) -> CGPoint {
        let y = function(xValue)
        return CGPoint(x: MathUtils.map(fromMin: graphWindow.minX, fromMax: graphWindow.maxY, toMin: 0, toMax: Double(bounds.width), value: xValue), y: MathUtils.map(fromMin: graphWindow.maxY, fromMax: graphWindow.minY, toMin: 0, toMax: Double(bounds.height), value: y))
    }
}

class GraphWindow {
    var minX: Double!
    var maxX: Double!
    var minY: Double!
    var maxY: Double!
    
    init (minX: Double = 0, maxX: Double = 0, minY: Double = 0, maxY: Double = 0) {
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
    }
}
