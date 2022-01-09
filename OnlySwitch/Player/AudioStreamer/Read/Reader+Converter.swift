//
//  Reader+Converter.swift
//  AudioStreamer
//
//  Created by Syed Haris Ali on 1/7/18.
//  Copyright © 2018 Ausome Apps LLC. All rights reserved.
//

import Foundation
import AVFoundation
import AudioToolbox
import os.log

// MARK: - Errors


// MARK: -
var packetDescs:[UnsafeMutablePointer<AudioStreamPacketDescription>?] = []
var packetDatas:[UnsafeMutableRawPointer?] = []

func ReaderConverterCallback(_ converter: AudioConverterRef,
                             _ packetCount: UnsafeMutablePointer<UInt32>,
                             _ ioData: UnsafeMutablePointer<AudioBufferList>,
                             _ outPacketDescriptions: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
                             _ context: UnsafeMutableRawPointer?) -> OSStatus {
    let reader = Unmanaged<Reader>.fromOpaque(context!).takeUnretainedValue()
    
    //
    // Make sure we have a valid source format so we know the data format of the parser's audio packets
    //
    guard let sourceFormat = reader.parser.dataFormat else {
        return ReaderMissingSourceFormatError
    }
    
    //
    // Check if we've reached the end of the packets. We have two scenarios:
    //     1. We've reached the end of the packet data and the file has been completely parsed
    //     2. We've reached the end of the data we currently have downloaded, but not the file
    //
    let packetIndex = Int(reader.currentPacket)
    let packets = reader.parser.packets
    let isEndOfData = packetIndex >= packets.count - 1
    if isEndOfData {
        if reader.parser.isParsingComplete {
            packetCount.pointee = 0
            return ReaderReachedEndOfDataError
        } else {
            return ReaderNotEnoughDataError
        }
    }
    
    //
    // Copy data over (note we've only processing a single packet of data at a time)
    //
    let packet = packets[packetIndex]
    var data = packet.0
    let dataCount = data.count
    ioData.pointee.mNumberBuffers = 1
    ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer.allocate(byteCount: dataCount, alignment: 0)
    data.withUnsafeMutableBytes { rawMutableBufferPointer in
        let bufferPointer = rawMutableBufferPointer.bindMemory(to: UInt8.self)
        if let address = bufferPointer.baseAddress {
            memcpy((ioData.pointee.mBuffers.mData?.assumingMemoryBound(to: UInt8.self))!, address, dataCount)
        }
        
    }
    ioData.pointee.mBuffers.mDataByteSize = UInt32(dataCount)
    packetDatas.append(ioData.pointee.mBuffers.mData)
    
    //
    // Handle packet descriptions for compressed formats (MP3, AAC, etc)
    //
    let sourceFormatDescription = sourceFormat.streamDescription.pointee
    if sourceFormatDescription.mFormatID != kAudioFormatLinearPCM {
        if outPacketDescriptions?.pointee == nil {
            outPacketDescriptions?.pointee = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: 1)
        }
        outPacketDescriptions?.pointee?.pointee.mDataByteSize = UInt32(dataCount)
        outPacketDescriptions?.pointee?.pointee.mStartOffset = 0
        outPacketDescriptions?.pointee?.pointee.mVariableFramesInPacket = 0
        packetDescs.append(outPacketDescriptions?.pointee)
    }
    packetCount.pointee = 1
    reader.currentPacket = reader.currentPacket + 1
    
    parserQueue.sync {
        if packetIndex >= 256 {
            reader.parser.packets.removeSubrange(0...255)
            reader.currentPacket = 1
        }
    }
    
//    print("packets count:\(reader.parser.packets.count)")
//    print("current packet:\(reader.currentPacket)")
    return noErr;
}

func cleanupConverterGarbage() {
    packetDescs.forEach { (desc) in desc?.deinitialize(count: 1); desc?.deallocate() }
//    print("deallocated \(packetDescs.count) packet descriptions")
    packetDescs.removeAll()
    packetDatas.forEach { (data) in data?.deallocate() }
//    print("deallocated \(packetDatas.count) packets of data")
    packetDatas.removeAll()
}
