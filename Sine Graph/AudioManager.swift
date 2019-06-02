//  Converted to Swift 4 by Swiftify v4.2.28153 - https://objectivec2swift.com/
//
//  AudioManager.swift
//  CoreAudioMixer
//
//  Created by William Welbes on 2/25/16.
//  Copyright © 2016 William Welbes. All rights reserved.
//

import Foundation

protocol AudioManager: NSObjectProtocol {
    func load()
    func startPlaying()
    func stopPlaying()
    func isPlaying() -> Bool
    func setGuitarInputVolume(_ value: Float32)
    func setDrumInputVolume(_ value: Float32)
    func guitarFrequencyDataOfLength(_ size: UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<Float32>?
    func drumsFrequencyDataOfLength(_ size: UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<Float32>?
}