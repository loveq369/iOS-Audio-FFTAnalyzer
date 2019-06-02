//  Converted to Swift 4 by Swiftify v4.2.28153 - https://objectivec2swift.com/
//
//  AudioEngineManager.swift
//  CoreAudioMixer
//
//  Created by William Welbes on 2/25/16.
//  Copyright © 2016 William Welbes. All rights reserved.
//
//  Implement CoreAudio functionality using the AVAudioEngine introduced in iOS8


//
//  AudioEngineManager.swift
//  CoreAudioMixer
//
//  Created by William Welbes on 2/25/16.
//  Copyright © 2016 William Welbes. All rights reserved.
//

import AVFoundation
import Foundation

class AudioEngineManager: NSObject, AudioManager {
    
    private var audioEngine: AVAudioEngine?
    private var inputGuitarPlayerNode: AVAudioPlayerNode?
    private var inputDrumsPlayerNode: AVAudioPlayerNode?
    private var mIsPlaying = false

    func loadEngine() {

        //Allocate the audio engine
        audioEngine = AVAudioEngine()

        //Create a player node for the guitar
        inputGuitarPlayerNode = AVAudioPlayerNode()
        if let inputGuitarPlayerNode = inputGuitarPlayerNode {
            audioEngine?.attach(inputGuitarPlayerNode)
        }

        //Load the audio file
        let guitarFileUrl: URL? = Bundle.main.url(forResource: "GuitarMonoSTP", withExtension: "aif")
        var error: Error? = nil

        var guitarFile: AVAudioFile? = nil
        if let guitarFileUrl = guitarFileUrl {
            guitarFile = try? AVAudioFile(forReading: guitarFileUrl)
        }
        if error != nil {
            print("Error loading file: \(error?.localizedDescription ?? "")")
            return //Short circuit - TODO: more error handling
        }

        var guitarBuffer: AVAudioPCMBuffer? = nil
        if let processingFormat = guitarFile?.processingFormat {
            guitarBuffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: AVAudioFrameCount(UInt32(guitarFile?.length ?? 0)))
        }
        if let guitarBuffer = guitarBuffer {
            try? guitarFile?.read(into: guitarBuffer)
        }
        if error != nil {
            print("Error loading guitar file into buffer: \(error?.localizedDescription ?? "")")
            return //Short circuit - TODO: more error handling
        }

        //Create a player node for the drums
        inputDrumsPlayerNode = AVAudioPlayerNode()
        if let inputDrumsPlayerNode = inputDrumsPlayerNode {
            audioEngine?.attach(inputDrumsPlayerNode)
        }

        //Load the audio file
        let drumsFileUrl: URL? = Bundle.main.url(forResource: "DrumsMonoSTP", withExtension: "aif")

        var drumsFile: AVAudioFile? = nil
        if let drumsFileUrl = drumsFileUrl {
            drumsFile = try? AVAudioFile(forReading: drumsFileUrl)
        }
        if error != nil {
            print("Error loading file: \(error?.localizedDescription ?? "")")
            return //Short circuit - TODO: more error handling
        }

        var drumsBuffer: AVAudioPCMBuffer? = nil
        if let processingFormat = drumsFile?.processingFormat {
            drumsBuffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: AVAudioFrameCount(UInt32(drumsFile?.length ?? 0)))
        }
        if let drumsBuffer = drumsBuffer {
            try? drumsFile?.read(into: drumsBuffer)
        }
        if error != nil {
            print("Error loading drums file into buffer: \(error?.localizedDescription ?? "")")
            return //Short circuit - TODO: more error handling
        }


        let mainMixerNode: AVAudioMixerNode? = audioEngine?.mainMixerNode
        if let inputGuitarPlayerNode = inputGuitarPlayerNode, let mainMixerNode = mainMixerNode {
            audioEngine?.connect(inputGuitarPlayerNode, to: mainMixerNode, format: guitarBuffer?.format)
        }
        if let inputDrumsPlayerNode = inputDrumsPlayerNode, let mainMixerNode = mainMixerNode {
            audioEngine?.connect(inputDrumsPlayerNode, to: mainMixerNode, format: drumsBuffer?.format)
        }

        if let guitarBuffer = guitarBuffer {
            inputGuitarPlayerNode?.scheduleBuffer(guitarBuffer, at: nil, options: .loops, completionHandler: nil)
        }
        if let drumsBuffer = drumsBuffer {
            inputDrumsPlayerNode?.scheduleBuffer(drumsBuffer, at: nil, options: .loops, completionHandler: nil)
        }

        inputGuitarPlayerNode?.pan = -1.0 //Set guitar to the left
        inputDrumsPlayerNode?.pan = 1.0 //Set drums to the right
    }

    func startPlaying() {
        var error: Error? = nil
        try? audioEngine?.start()

        inputGuitarPlayerNode?.play()
        inputDrumsPlayerNode?.play()

        mIsPlaying = true
    }

    func setGuitarInputVolume(_ value: Float32) {
        inputGuitarPlayerNode?.volume = value
    }

    func setDrumInputVolume(_ value: Float32) {
        inputDrumsPlayerNode?.volume = value
    }

    func isPlaying() -> Bool {
        return mIsPlaying
    }

    override init() {

        super.init()
        mIsPlaying = false
    }

    func load() {
        loadEngine()
    }

    func stopPlaying() {
        //Stop the audio player
        audioEngine?.pause()

        mIsPlaying = false
    }

    func guitarFrequencyDataOfLength(_ size: UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<Float32>? {
        var size = size
        size = nil
        return nil
    }

    func drumsFrequencyDataOfLength(_ size: UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<Float32>? {
        var size = size
        size = nil
        return nil
    }
}
