//
//  FFTAnalyzer.swift
//  Sine Graph
//
//  Created by Shahar Ben-Dor on 2/9/19.
//  Copyright © 2019 Specter. All rights reserved.
//

import Foundation
import AVFoundation
import Accelerate

@objc protocol FFTAnalyzerListener {
    @objc optional func didPerformFFT(plot: FFTPlot)
}

@objc class FFTPlot: NSObject {
    let magnitudes: [Double]
    
    init (magnitudes: [Double]) {
        self.magnitudes = magnitudes
    }
    
    // Returns the values on a range from 0-1
    func getScaledValues() -> [Double] {
        return magnitudes.compactMap { $0 / 2600000 }
    }
    
    
    /// - Returns: the normalized scaled values
    func getNormalizedValues() -> [Double] {
        return getScaledValues().compactMap {
            if $0 > 0 {
                return ($0 * 1.5) / pow(($0) * 2, 1.0 / 1.8)
            }
            
            return $0
        }
    }
    
    func mapToRange(minFrequency: Int, maxFrequency: Int) -> [Double] {
        var normalizedPlot = [Double]()
        var normalizedValues = getNormalizedValues()
        
        for i in 0 ..< normalizedValues.count {
            let val = MathUtils.map(fromMin: 0, fromMax: Double(normalizedValues.count), toMin: 20, toMax: 20000, value: Double(i))
            
            if val >= Double(minFrequency) && val <= Double(maxFrequency) {
                normalizedPlot.append(normalizedValues[i])
            }
        }
        
        return normalizedPlot
    }
}

class FFTAnalyzer {
    private var listeners = NSPointerArray.weakObjects()
    
    init (audioNode: AVAudioPlayerNode) {
        let format = audioNode.outputFormat(forBus: 0)
        let tapFormat = AVAudioFormat(commonFormat: format.commonFormat, sampleRate: 20000, channels: format.channelCount, interleaved: format.isInterleaved)!
        
        audioNode.installTap(onBus: 0, bufferSize: 1, format: tapFormat) { buffer, time in
            DispatchQueue.main.async { [weak this = self] in
                this?.performFFT(buffer: buffer)
            }
        }
    }
    
    
    
    
    
    
    @discardableResult func addListener(_ listener: FFTAnalyzerListener) -> Int {
        let pointer = Unmanaged.passUnretained(listener as AnyObject).toOpaque()
        listeners.addPointer(pointer)
        
        return listeners.count - 1
    }
    
    func removeListener(at index: Int) {
        listeners.removePointer(at: index)
    }
    
    func removeListener(listener: FFTAnalyzerListener) {
        let pointerToCompare = Unmanaged.passUnretained(listener as AnyObject).toOpaque()
        for i in 0 ..< listeners.count {
            if let pointer = listeners.pointer(at: i), pointer == pointerToCompare {
                listeners.removePointer(at: i)
                break
            }
        }
    }
    
    private func getListeners() -> [FFTAnalyzerListener] {
        var toReturn = [FFTAnalyzerListener]()
        for i in 0 ..< listeners.count {
            if let pointer = listeners.pointer(at: i) {
                let toAdd = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as! FFTAnalyzerListener
                toReturn.append(toAdd)
            }
        }
        
        return toReturn
    }
    
    
    
    

    
    private func performFFT(buffer: AVAudioPCMBuffer) {
        let frameCount = buffer.frameLength
        let log2n =  UInt(round(log2(Double(frameCount))))
        let bufferSizePOT = Int(1 << log2n)
        let inputCount = bufferSizePOT / 2
        let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix5))
        
        var realp = [Float](repeating: 0, count: inputCount)
        var imagp = [Float](repeating: 0, count: inputCount)
        var output = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        let windowSize = bufferSizePOT
        var transferBuffer = [Float](repeating: 0, count: windowSize)
        var window = [Float](repeating: 0, count: windowSize)
        
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul((buffer.floatChannelData?.pointee)!, 1, window, 1, &transferBuffer, 1, vDSP_Length(windowSize))
        
        let temp = UnsafePointer<Float>(transferBuffer)
        temp.withMemoryRebound(to: DSPComplex.self, capacity: transferBuffer.count) { vDSP_ctoz($0, 2, &output, 1, vDSP_Length(inputCount))
        }
        
        vDSP_fft_zrip(fftSetup!, &output, 1, log2n, FFTDirection(FFT_FORWARD))
        
        var magnitudes = [Float](repeating: 0.0, count: inputCount)
        vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(inputCount))
        
        var normalizedMagnitudes = [Float](repeating: 0.0, count: inputCount)
        vDSP_vsmul(sqrtq(magnitudes), 1, [2.0 / (Float(inputCount) * 16)], &normalizedMagnitudes, 1, vDSP_Length(inputCount))
        
        let fftPlot = FFTPlot(magnitudes: magnitudes.compactMap( { Double($0) } ))

        for listener in getListeners() {
            listener.didPerformFFT?(plot: fftPlot)
        }
        
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    private func sqrtq(_ x: [Float]) -> [Float] {
        var results = [Float](repeating: 0.0, count: x.count)
        vvsqrtf(&results, x, [Int32(x.count)])
        
        return results
    }
}
