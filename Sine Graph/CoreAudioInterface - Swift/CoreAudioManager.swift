//  Converted to Swift 4 by Swiftify v4.2.28153 - https://objectivec2swift.com/
//
//  CoreAudioManager.swift
//  CoreAudioMixer
//
//  Created by William Welbes on 2/24/16.
//  Copyright © 2016 William Welbes. All rights reserved.
//

import AudioToolbox
import AudioUnit
import AVFoundation
import Foundation

let kSampleRate = Float64(44100.0)
let frequencyDataLength: UInt32 = 256
//Create a struct to store the sound buffer data from sound files loaded
typealias SoundBuffer = (asbd: AudioStreamBasicDescription, data: Float32, numberOfFrames: UInt32, sampleNumber: UInt32, frequencyData: Float32)
typealias SoundBufferPtr = (asbd: AudioStreamBasicDescription, data: Float32, numberOfFrames: UInt32, sampleNumber: UInt32, frequencyData: Float32)

//A static audio render method callback that will be used by the AURenderCallback from the AUGraph
private func renderAudioInput(inRefCon: UnsafeMutableRawPointer?, actionFlags: AudioUnitRenderActionFlags?, inTimeStamp: AudioTimeStamp?, inBusNumber: UInt32, inNumberOfFrames: UInt32, ioData: AudioBufferList?) -> OSStatus {
    let soundBuffer = inRefCon as? SoundBufferPtr

    //NSLog(@"numberOfFrames: %d", inNumberOfFrames);

    //Get the frame to start at and total number of samples
    var sample = soundBuffer?[inBusNumber]?.sampleNumber
    let startSample: UInt32? = sample
    let bufferTotalSamples = soundBuffer?[inBusNumber]?.numberOfFrames

    //Get a reference to the input data buffer
    let inputData = soundBuffer?[inBusNumber]?.data // audio data buffer

    //Get references to the channel buffers
    let outLeft = Float32(ioData?.mBuffers[0].mData ?? 0) // output audio buffer for Left channel
    let outRight = Float32(ioData?.mBuffers[1].mData ?? 0) // output audio buffer for Right channel

    //Loop thru the number of frames and set the output data from the input data.
    //Use the left channel for bus 0 (guitar) and right channel for bus 1 (drums) to distiguish for example
    for i in 0..<inNumberOfFrames {

        if inBusNumber == 0 {
            outLeft[i] = inputData?[sample ?? 0] ?? 0
            sample = (sample ?? 0) + 1
            outRight[i] = 0
        } else {
            //inBusNumber == 1
            outLeft[i] = 0
            outRight[i] = inputData?[sample ?? 0] ?? 0
            sample = (sample ?? 0) + 1
        }

        //If the sample is beyond the total number of samples in the loop, start over at the beginning
        if (sample ?? 0) > (bufferTotalSamples ?? 0) {
            // start over from the beginning of the data, our audio simply loops
            sample = 0
            print("Starting over at frame 0 for bus \(Int(inBusNumber))")
        }
    }

    //Set the sample number in the sound buffer struct so we know which frame playback is on
    soundBuffer?[inBusNumber]?.sampleNumber = sample

    performFFT(&inputData?[startSample ?? 0], inNumberOfFrames, soundBuffer, inBusNumber)

    return []
}

private func performFFT(data: UnsafeMutablePointer<Float>?, numberOfFrames: UInt32, soundBuffer: SoundBufferPtr, inBusNumber: UInt32) {

    let bufferLog2 = Int(round(log2(numberOfFrames)))
    var fftNormFactor: Float = 1.0 / Double((2 * numberOfFrames))

    let fftSetup: FFTSetup = vDSP_create_fftsetup(bufferLog2, [])

    let numberOfFramesOver2 = Int(numberOfFrames / 2)
    let outReal = [Float](repeating: 0.0, count: numberOfFramesOver2)
    let outImaginary = [Float](repeating: 0.0, count: numberOfFramesOver2)

    var output = COMPLEX_SPLIT()
        output.realp = outReal
        output.imagp = outImaginary

    //Put all of the even numbered elements into outReal and odd numbered into outImaginary
    vDSP_ctoz(data as? COMPLEX, 2, &output, 1, numberOfFramesOver2)

    //Perform the FFT via Accelerate
    //Use FFT forward for standard PCM audio
    vDSP_fft_zrip(fftSetup, &output, 1, bufferLog2, [])

    //Scale the FFT data
    vDSP_vsmul(output.realp, 1, &fftNormFactor, output.realp, 1, numberOfFramesOver2)
    vDSP_vsmul(output.imagp, 1, &fftNormFactor, output.imagp, 1, numberOfFramesOver2)

    //vDSP_zvmags(&output, 1, soundBuffer[inBusNumber].frequencyData, 1, numberOfFramesOver2);

    //Take the absolute value of the output to get in range of 0 to 1
    //vDSP_zvabs(&output, 1, frequencyData, 1, numberOfFramesOver2);
    vDSP_zvabs(&output, 1, soundBuffer[inBusNumber].frequencyData, 1, numberOfFramesOver2)

    vDSP_destroy_fftsetup(fftSetup)
}

class CoreAudioManager: NSObject, AudioManager {
    private var mSoundBuffer = [SoundBuffer](repeating: , count: 2) //TODO - make dynamically sized based on files added
    private var mAudioFormat: AVAudioFormat?
    private var mGraph: AUGraph?
    private var mMixer: AudioUnit?
    private var mOutput: AudioUnit?
    private var mIsPlaying = false

    func loadAudioFiles() {
        print("loadAudioFiles")

        let guitarSourcePath = Bundle.main.path(forResource: "Hopex & Calli Boom - Saying Yes", ofType: "mp3")

        let sourcePaths = [guitarSourcePath]

        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: kSampleRate, channels: AVAudioChannelCount(1), interleaved: true)

        //Loop through each of the source path objects and load the file
        for i in 0..<sourcePaths.count {

            let sourcePath = sourcePaths[i]

            let fileUrlRef = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, sourcePath as CFString?, CFURLPathStyle.cfurlposixPathStyle, false)

            //Open the audio file
            var extAFref = 0 as? ExtAudioFileRef
            var result: OSStatus = ExtAudioFileOpenURL(fileUrlRef, &extAFref)
            if Int(result) != 0 || extAFref == nil {
                print(String(format: "Error opening audio file.  ExtAudioFileOpenURL result: %ld ", Int(result)))
                break //Break out of the loop since we hit an error opening (TODO: more handling)
            }

            //Get the file data format
            var audioFileFormat: AudioStreamBasicDescription
            var propertySize = UInt32(MemoryLayout<audioFileFormat>.size)

            result = ExtAudioFileGetProperty(extAFref, kExtAudioFileProperty_FileDataFormat, &propertySize, &audioFileFormat)
            if Int(result) != 0 {
                print(String(format: "Error getting file format property. ExtAudioFileGetProperty result: %ld", Int(result)))
                break //Break out of the loop since we hit an error getting the file format (TODO: more handling)
            }

            //Set the format that will be sent to the input of the mixer

            let sampleRateRatio: Double = kSampleRate / audioFileFormat.mSampleRate

            propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size) //Get the basic description property

            result = ExtAudioFileSetProperty(extAFref, kExtAudioFileProperty_ClientDataFormat, propertySize, audioFormat?.streamDescription)
            if Int(result) != 0 {
                print(String(format: "Error setting audio format property. ExtAudioFileSetProperty result: %ld ", Int(result)))
                break //Break out of the loop since we hit an error setting the format (TODO: more handling)
            }

            //Get the files length in frames

            var numberOfFrames: UInt64 = 0
            propertySize = UInt32(MemoryLayout<numberOfFrames>.size)

            result = ExtAudioFileGetProperty(extAFref, kExtAudioFileProperty_FileLengthFrames, &propertySize, &numberOfFrames)
            if Int(result) != 0 {
                print(String(format: "Error getting number of frames. ExtAudioFileGetProperty result: %ld", Int(result)))
                break //Break out of the loop since we hit an error getting the number of frames (TODO: more handling)
            }

            //Print the number of frames and a converted number of frames based on the sample ratio
            print("\(UInt(numberOfFrames)) frames in \(sourcePath?.lastPathComponent ?? "")")

            numberOfFrames = UInt64(Double(numberOfFrames) * sampleRateRatio)
            print("\(UInt(numberOfFrames)) frames after sample ratio multiplied in \(sourcePath?.lastPathComponent ?? "")")

            //Set up the sound buffer

            mSoundBuffer[i].numberOfFrames = UInt32(numberOfFrames)
            mSoundBuffer[i].asbd = audioFormat?.streamDescription

            //Determine the number of samples by multiplying the number of frames by the number of channels per frame
            let samples = UInt32(numberOfFrames) * mSoundBuffer[i].asbd.mChannelsPerFrame

            //Allocate memory for a buffer size based on the number of samples
            mSoundBuffer[i].data = Float32(calloc(samples, MemoryLayout<Float32>.size))
            mSoundBuffer[i].sampleNumber = 0

            mSoundBuffer[i].frequencyData = Float32(calloc(frequencyDataLength, MemoryLayout<Float32>.size)) //TODO: Dynamic size

            //Create an AudioBufferList to read into
            var bufferList: AudioBufferList
            bufferList.mNumberBuffers = 1
            bufferList.mBuffers[0].mNumberChannels = 1
            bufferList.mBuffers[0].mData = mSoundBuffer[i].data
            bufferList.mBuffers[0].mDataByteSize = Int(samples) * MemoryLayout<Float32>.size

            //Read audio data from file into allocated data buffer

            //Number of packets is the same as the number of frames we've extracted and calculcated based on sample ratio
            var numberOfPackets = UInt32(numberOfFrames)

            result = ExtAudioFileRead(extAFref, &numberOfPackets, &bufferList)
            if Int(result) != 0 {
                print(String(format: "Error reading audio file. ExtAudioFileRead result: %ld", Int(result)))
                free(mSoundBuffer[i].data)
                mSoundBuffer[i].data = 0
            }

            //Dispose the audio file reference now that is has been read.
            ExtAudioFileDispose(extAFref)

            //Release the reference to the file url
        }
    }

    func initializeAUGraph() {
        print("initializeAUGraph")

        //Create the AUNodes to be used
        var outputNode: AUNode
        var mixerNode: AUNode

        //Setup the audio format for the graph
        mAudioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: kSampleRate, channels: AVAudioChannelCount(2), interleaved: false)

        var result = 0 as? OSStatus

        //Create a new AUGraph
        result = NewAUGraph(&mGraph)
        if IntegerLiteralConvertible(result ?? 0) != 0 {
            print(String(format: "Error creating via NewAUGraph: %ld", Int(result ?? 0)))
            return //Short circuit out - TODO: better error handling
        }

        // create two AudioComponentDescriptions for the AUs we want in the graph

        //Output audio unit
        var outputDescription: AudioComponentDescription
        outputDescription.componentType = kAudioUnitType_Output
        outputDescription.componentSubType = kAudioUnitSubType_RemoteIO
        outputDescription.componentManufacturer = kAudioUnitManufacturer_Apple
        outputDescription.componentFlags = 0
        outputDescription.componentFlagsMask = 0

        // Multichannel mixer audio unit
        var mixerDescription: AudioComponentDescription
        mixerDescription.componentType = kAudioUnitType_Mixer
        mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer
        mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple
        mixerDescription.componentFlags = 0
        mixerDescription.componentFlagsMask = 0

        //Create an audio node in the graph that is an AudioUnit
        result = AUGraphAddNode(mGraph, &outputDescription, &outputNode)
        if IntegerLiteralConvertible(result ?? 0) != 0 {
            print(String(format: "Error adding output node: AUGraphAddNode result: %ld", Int(result ?? 0)))
            return //Short circuit out - TODO: better error handling
        }

        result = AUGraphAddNode(mGraph, &mixerDescription, &mixerNode)
        if IntegerLiteralConvertible(result ?? 0) != 0 {
            print(String(format: "Error adding mixer node: AUGraphAddNode result: %ld", Int(result ?? 0)))
            return //Short circuit out - TODO: better error handling
        }

        //Connect the node input and output
        result = AUGraphConnectNodeInput(mGraph, mixerNode, 0, outputNode, 0)
        if IntegerLiteralConvertible(result ?? 0) != 0 {
            print(String(format: "Error connecting node input: AUGraphConnectNodeInput result: %ld", Int(result ?? 0)))
            return //Short circuit out - TODO: better error handling
        }

        //Open the AudioUnits via the graph
        result = AUGraphOpen(mGraph)
        if IntegerLiteralConvertible(result ?? 0) != 0 {
            print(String(format: "Error opening graph: AUGraphOpen result: %ld", Int(result ?? 0)))
            return //Short circuit out - TODO: better error handling
        }

        result = AUGraphNodeInfo(mGraph, mixerNode, nil, &mMixer)
        if IntegerLiteralConvertible(result ?? 0) != 0 {
            print(String(format: "Error loading mixer node info: AUGraphNodeInfo result: %ld", Int(result ?? 0)))
            return //Short circuit out - TODO: better error handling
        }

        result = AUGraphNodeInfo(mGraph, outputNode, nil, &mOutput)
        if IntegerLiteralConvertible(result ?? 0) != 0 {
            print(String(format: "Error loading output node info: AUGraphNodeInfo result: %ld", Int(result ?? 0)))
            return //Short circuit out - TODO: better error handling
        }

        //Setup 2 buses
        var numbuses: UInt32 = 2

        result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, MemoryLayout<numbuses>.size)
        if IntegerLiteralConvertible(result ?? 0) != 0 {
            print(String(format: "Error setting audio unit property on mixer: %ld", Int(result ?? 0)))
        }

        for i in 0..<numbuses {
            // setup render callback struct
            var renderCallbackStruct: AURenderCallbackStruct
            renderCallbackStruct.inputProc = renderAudioInput
            renderCallbackStruct.inputProcRefCon = mSoundBuffer

            // Set a callback for the specified node's specified input
            result = AUGraphSetNodeInputCallback(mGraph, mixerNode, i, &renderCallbackStruct)
            if IntegerLiteralConvertible(result ?? 0) != 0 {
                print(String(format: "AUGraphSetNodeInputCallback failed with result: %ld", Int(result ?? 0)))
                return //Short circuit out - TODO: better error handling
            }

            //Set the input stream format property
            result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, mAudioFormat?.streamDescription, MemoryLayout<AudioStreamBasicDescription>.size)
            if IntegerLiteralConvertible(result ?? 0) != 0 {
                print(String(format: "AudioUnitSetProperty failed with result: %ld", Int(result ?? 0)))
                return //Short circuit out - TODO: better error handling
            }
        }

        //Set the output stream format property
        result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, mAudioFormat?.streamDescription, MemoryLayout<AudioStreamBasicDescription>.size)
        if IntegerLiteralConvertible(result ?? 0) != 0 {
            print(String(format: "AudioUnitSetProperty mixer stream format failed with result: %ld", Int(result ?? 0)))
            return //Short circuit out - TODO: better error handling
        }

        result = AudioUnitSetProperty(mOutput, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, mAudioFormat?.streamDescription, MemoryLayout<AudioStreamBasicDescription>.size)
        if IntegerLiteralConvertible(result ?? 0) != 0 {
            print(String(format: "AudioUnitSetProperty output stream format failed with result: %ld", Int(result ?? 0)))
            return //Short circuit out - TODO: better error handling
        }

        //Initialize the graph
        result = AUGraphInitialize(mGraph)
        if IntegerLiteralConvertible(result ?? 0) != 0 {
            print(String(format: "AUGraphInitialize failed with result: %ld", Int(result ?? 0)))
            return //Short circuit out - TODO: better error handling
        }
    }

    func startPlaying() {
        print("startPlaying")

        let result: OSStatus = AUGraphStart(mGraph)
        if Int(result) != 0 {
            print(String(format: "AUGraphStart failed: %ld", Int(result)))
            return
        }

        mIsPlaying = true
    }

    func stopPlaying() {
        print("stopPlaying")

        var isRunning = false

        var result: OSStatus = AUGraphIsRunning(mGraph, &isRunning)
        if Int(result) != 0 {
            print(String(format: "AUGraphIsRunning failed: %ld", Int(result)))
            return
        }

        if isRunning {
            result = AUGraphStop(mGraph)
            if Int(result) != 0 {
                print(String(format: "AUGraphStop failed: %ld", Int(result)))
                return
            }
            mIsPlaying = false
        } else {
            print("AUGraphIsRunning reported not running.")
        }
    }

    func setGuitarInputVolume(_ value: Float32) {
        setVolumeForInput(0, value: value as? AudioUnitParameterValue ?? 0)
    }

    func setDrumInputVolume(_ value: Float32) {
        setVolumeForInput(1, value: value as? AudioUnitParameterValue ?? 0)
    }

    func guitarFrequencyDataOfLength(_ size: UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<Float32>? {
        size = frequencyDataLength
        return mSoundBuffer[0].frequencyData
    }

    func drumsFrequencyDataOfLength(_ size: UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<Float32>? {
        size = frequencyDataLength
        return mSoundBuffer[1].frequencyData
    }

    func isPlaying() -> Bool {
        return mIsPlaying
    }

    override init() {

        super.init()
        mIsPlaying = false
    }

    deinit {

        //Remove observers
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())

        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance())

        //Dispose of the allocated graph
        DisposeAUGraph(mGraph)

        //Release allocated memory for sound buffer member
        free(mSoundBuffer[0].data)
        free(mSoundBuffer[1].data)
        free(mSoundBuffer[0].frequencyData)
        free(mSoundBuffer[1].frequencyData)

        // clear the mSoundBuffer struct
        memset(&mSoundBuffer, 0, MemoryLayout<mSoundBuffer>.size)
    }

    override class func load() {

        loadAudioFiles()
        initializeAUGraph()
    }

    func setVolumeForInput(_ inputIndex: UInt32, value: AudioUnitParameterValue) {

        let result: OSStatus = AudioUnitSetParameter(mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, inputIndex, value, 0)
        if Int(result) != 0 {
            print(String(format: "AudioUnitSetParameter failed when setting input volume: %ld", Int(result)))
        }
    }
}