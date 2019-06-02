//  Converted to Swift 4 by Swiftify v4.2.28153 - https://objectivec2swift.com/
//
//  AudioSessionManager.swift
//  CoreAudioMixer
//
//  Created by William Welbes on 2/26/16.
//  Copyright © 2016 William Welbes. All rights reserved.
//

import AVFoundation
import Foundation

class AudioSessionManager: NSObject {
    static let sharedInstance_sharedManager: AudioSessionManager? = nil

    class func sharedInstance() -> AudioSessionManager? {
        // `dispatch_once()` call was converted to a static variable initializer
        return sharedInstance_sharedManager
    }

    //Call setup audio session before loading files or initializing the graph
    func setupAudioSession() {

        let sessionInstance = AVAudioSession.sharedInstance()

        do {
            try sessionInstance.setCategory(AVAudioSession.Category.playback, mode: .default, options: [])
        } catch {
            print("Error setting audio category: \(error.localizedDescription)")
        }

        let bufferDuration: TimeInterval = 0.005
        
        do {
            try sessionInstance.setPreferredIOBufferDuration(bufferDuration)
        } catch {
            print("Error settting Preferred Buffer Duration: \(error.localizedDescription)")
        }

        do {
            try sessionInstance.setPreferredSampleRate(44100.0)
        } catch {
            print("Error setting preferred sample rate: \(error.localizedDescription)")
        }

        //Add self as the interruption handler
        NotificationCenter.default.addObserver(self, selector: #selector(AudioSessionManager.handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: sessionInstance)

        //Add seld as the route change handler
        NotificationCenter.default.addObserver(self, selector: #selector(AudioSessionManager.handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: sessionInstance)


        //Set the session to active
        do {
            try sessionInstance.setActive(true)
            print("AVAudioSession set to active.")
        } catch {
            print("Error setting audio session to active: \(error.localizedDescription)")
        }
    }

    @objc func handleInterruption(_ notification: Notification?) {

        //Get the type of interruption
        let interruptionType = UInt8((notification?.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.intValue ?? 0)

        print("AVAudioSession interrupted: \(interruptionType == UInt8(AVAudioSession.InterruptionType.began.rawValue) ? "Begin Interruption" : "End Interruption")")

        if interruptionType == UInt8(AVAudioSession.InterruptionType.began.rawValue) {
            //stop for the interruption
            //Tell audio managers to stop playing!
            NotificationCenter.default.post(name: NSNotification.Name("StopAudioNotification"), object: nil)
        } else if interruptionType == UInt8(AVAudioSession.InterruptionType.ended.rawValue) {
            //Activate the session
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("AVAudioSession setActive failed: \(error.localizedDescription)")
            }
        }
    }

    @objc func handleRouteChange(_ notification: Notification?) {

        //Get the type of route change
        let reasonValue = UInt8((notification?.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.intValue ?? 0)

        print("handleRouteChange: reasonValue: \(reasonValue)")

        let routeDescription = notification?.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription

        if let routeDescription = routeDescription {
            print("handleRouteChange: new route: \(routeDescription)")
        }
    }
}
