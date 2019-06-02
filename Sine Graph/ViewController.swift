//
//  ViewController.swift
//  Sine Graph
//
//  Created by Shahar Ben-Dor on 1/28/19.
//  Copyright © 2019 Specter. All rights reserved.
//

import UIKit
import Darwin
import AVFoundation

class ViewController: UIViewController, FFTAnalyzerListener {
    lazy var displayLink = CADisplayLink(target: self, selector: #selector(updateWave))

    lazy var path1 = SineView(frame: self.view.frame, path: nil, graphWindow: GraphWindow(minX: Double.pi * -1, maxX: Double.pi, minY: -2, maxY: 2))
    lazy var path2 = SineView(frame: self.view.frame, path: nil, graphWindow: GraphWindow(minX: Double.pi * -1, maxX: Double.pi, minY: -3, maxY: 3))
    lazy var path3 = SineView(frame: self.view.frame, path: nil, graphWindow: GraphWindow(minX: Double.pi * -1, maxX: Double.pi, minY: -4, maxY: 4))

    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet var visualizers: [UIMusicVisualizerView]!
    @IBOutlet weak var bgView: UIView!
    
    lazy var particleEmitter = CAEmitterLayer()
    
    let audioEngine = AVAudioEngine()
    let audioNode = AVAudioPlayerNode()
    var fft: FFTAnalyzer!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        let url = Bundle.main.url(forResource: "NOX & Calli Boom - Focused", withExtension: "mp3")!
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return
        }
        
        audioEngine.attach(audioNode)
        audioEngine.connect(audioNode, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
        audioNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
        
        fft = FFTAnalyzer(audioNode: audioNode)
        fft.addListener(self)
        
        setupEmitter()
        
        for (i, visualizer) in visualizers.enumerated() {
            visualizer.isSmooth = true
            
            visualizer.type = .topBottom
            
            if i == visualizers.count - 1 {
                visualizer.layer.shadowRadius = 8
                visualizer.layer.shadowOpacity = 0.4
                visualizer.layer.shadowOffset = CGSize(width: 0, height: 1)
                visualizer.layer.shadowColor = #colorLiteral(red: 0.9985123277, green: 0.9053804874, blue: 0.6972615123, alpha: 1).cgColor
            }
            
            switch i {
            case 0:
                visualizer.isHidden = true
                break
            case 1:
                visualizer.waveColor = #colorLiteral(red: 0.9999071956, green: 1, blue: 0.999881804, alpha: 1)
                break
            case 2:
                visualizer.waveColor = #colorLiteral(red: 0.9974595904, green: 0.768878758, blue: 0.01064642612, alpha: 1)
                visualizer.delay = 0.004
                break
            case 3:
                visualizer.waveColor = #colorLiteral(red: 1, green: 0.03532447293, blue: 0.1751394868, alpha: 1)
                visualizer.delay = 0.008
                break
            case 4:
                visualizer.waveColor = #colorLiteral(red: 1, green: 0, blue: 0.9434228539, alpha: 1)
                visualizer.delay = 0.012
                break
            case 5:
                visualizer.waveColor = #colorLiteral(red: 0.08007759601, green: 0.006968453526, blue: 1, alpha: 1)
                visualizer.delay = 0.016
                break
            case 6:
                visualizer.waveColor = #colorLiteral(red: 0.01183368172, green: 0.4077807069, blue: 1, alpha: 1)
                visualizer.delay = 0.02
                break
            case 7:
                visualizer.waveColor = #colorLiteral(red: 0, green: 0.9987511039, blue: 0.9996721148, alpha: 1)
                visualizer.delay = 0.024
                break
            case 8:
                visualizer.waveColor = #colorLiteral(red: 0.1473516524, green: 1, blue: 0.01612938382, alpha: 1)
                visualizer.delay = 0.028
            default:
                break
            }
            
            
            visualizer.attach(to: fft)
        }

        try? audioEngine.start()
        audioNode.play()
        
//        path1.backgroundColor = #colorLiteral(red: 0.1019607857, green: 0.2784313858, blue: 0.400000006, alpha: 1)
//        view.addSubview(path1)
//        view.addSubview(path2)
//        view.addSubview(path3)
//
//        displayLink.add(to: .main, forMode: .common)
//        displayLink.preferredFramesPerSecond = 60
    }
    
    func didPerformFFT(plot: FFTPlot) {
        let offset = min(0.3, max(0, MathUtils.map(fromMin: 0, fromMax: 1, toMin: 0, toMax: 0.3, value: plot.getNormalizedValues()[2])))
        particleEmitter.timeOffset = offset + particleEmitter.timeOffset
    }
    
    func setupEmitter() {
        particleEmitter.emitterPosition = CGPoint(x: view.center.x, y: view.center.y)
        particleEmitter.emitterShape = .line
        particleEmitter.emitterSize = CGSize(width: backgroundImage.bounds.width, height: 1)
        particleEmitter.renderMode = .additive

        let whiteUp = makeEmitterCell(color: UIColor.white, longitude: 0)
        let whiteDown = makeEmitterCell(color: UIColor.white, longitude: .pi)
        particleEmitter.emitterCells = [whiteUp, whiteDown]

        backgroundImage.layer.addSublayer(particleEmitter)
    }
    
    func makeEmitterCell(color: UIColor, longitude: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.birthRate = 40
        cell.lifetime = 10
        cell.color = color.cgColor
        cell.velocity = 15
        cell.velocityRange = 10
        cell.emissionLongitude = longitude
        cell.emissionRange = CGFloat.pi / 4
        cell.scaleRange = 0.025
        cell.scaleSpeed = -0.015
        cell.scale = 0.05
        cell.alphaSpeed = -0.15

        cell.contents = UIImage(named: "Circular Partical")?.cgImage
        return cell
    }
    
    @objc func updateWave() {
        path1.phase += 0.1
        path2.phase += 0.1
        path3.phase += 0.1
        
        if path1.amplitude > 1 || path1.amplitude < -1 {
            path1.change *= -1
            path2.change *= -1
            path3.change *= -1
        }
    }
}

class SineView: UIGraphView {
    var phase: Double = 0 {
        didSet {
            redraw()
        }
    }
    
    var change: Double = -0.025
    
    var amplitude: Double = 1 {
        didSet {
            redraw()
        }
    }
    
    init(frame: CGRect, path: UIBezierPath?, graphWindow: GraphWindow = GraphWindow()) {
        super.init(frame: frame, graph: nil, path: path, graphWindow: graphWindow)
        
        self.graph = Graph(function: { (x) -> (Double) in
            return cos(x / 2) * self.amplitude * sin(self.phase + x)
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
