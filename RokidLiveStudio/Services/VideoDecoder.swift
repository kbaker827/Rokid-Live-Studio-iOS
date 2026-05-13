import Foundation
import VideoToolbox
import AVFoundation
import CoreMedia

/// Decodes H264 Annex-B frames using VideoToolbox and feeds CMSampleBuffers
/// to an AVSampleBufferDisplayLayer for live preview.
class VideoDecoder {

    var displayLayer: AVSampleBufferDisplayLayer?
    var onDecodedSampleBuffer: ((CMSampleBuffer) -> Void)?

    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?
    private var sps: Data?
    private var pps: Data?

    // Called when VIDEO_CONFIG arrives
    func configure(sps: Data, pps: Data) {
        self.sps = sps
        self.pps = pps
        createFormatDescription(sps: sps, pps: pps)
        createDecompressionSession()
    }

    // Called for each VIDEO_FRAME
    func decodeFrame(_ packet: MediaPacket) {
        guard let session = decompressionSession,
              let fmtDesc = formatDescription else { return }

        // Convert Annex-B to AVCC (length-prefixed)
        let avcc = annexBToAVCC(packet.payload)
        guard !avcc.isEmpty else { return }

        let timestampSecs = Double(packet.timestampUs) / 1_000_000.0
        let pts = CMTime(seconds: timestampSecs, preferredTimescale: 90000)
        let dts = pts

        var blockBuffer: CMBlockBuffer?
        let avccBytes = [UInt8](avcc)
        let len = avccBytes.count
        let status = avccBytes.withUnsafeBufferPointer { ptr -> OSStatus in
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: UnsafeMutableRawPointer(mutating: ptr.baseAddress!),
                blockLength: len,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: len,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
        }
        guard status == noErr, let bb = blockBuffer else { return }

        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(duration: CMTime.invalid, presentationTimeStamp: pts, decodeTimeStamp: dts)
        var size = len
        let sbStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: bb,
            formatDescription: fmtDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &size,
            sampleBufferOut: &sampleBuffer
        )
        guard sbStatus == noErr, let sb = sampleBuffer else { return }

        if packet.isKeyFrame {
            let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: true) as? [[CFString: Any]]
            if let att = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: true) {
                let dict = unsafeBitCast(CFArrayGetValueAtIndex(att, 0), to: CFMutableDictionary.self)
                CFDictionarySetValue(dict,
                    Unmanaged.passRetained(kCMSampleAttachmentKey_DisplayImmediately as AnyObject).autorelease().toOpaque(),
                    Unmanaged.passRetained(kCFBooleanTrue).autorelease().toOpaque())
                _ = attachments  // suppress warning
            }
        }

        var flags = VTDecodeFrameFlags(rawValue: 0)
        if !packet.isKeyFrame { flags = [] }
        var flagsOut = VTDecodeInfoFlags(rawValue: 0)

        let decodeStatus = VTDecompressionSessionDecodeFrame(
            session, sampleBuffer: sb, flags: flags,
            frameRefcon: nil, infoFlagsOut: &flagsOut
        )
        if decodeStatus != noErr && decodeStatus != kVTInvalidSessionErr {
            // Non-fatal; skip frame
        }
    }

    func invalidate() {
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
        }
        decompressionSession = nil
        formatDescription = nil
    }

    // MARK: - Private

    private func createFormatDescription(sps: Data, pps: Data) {
        var fmtDesc: CMFormatDescription?
        let paramSets: [Data] = [sps, pps]
        let paramPtrs = paramSets.map { $0.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt8.self) } }
        let paramSizes = paramSets.map { $0.count }

        let status = paramPtrs.withUnsafeBufferPointer { ptrsPtr in
            paramSizes.withUnsafeBufferPointer { sizesPtr in
                CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: 2,
                    parameterSetPointers: ptrsPtr.baseAddress!,
                    parameterSetSizes: sizesPtr.baseAddress!,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &fmtDesc
                )
            }
        }
        if status == noErr { formatDescription = fmtDesc }
    }

    private func createDecompressionSession() {
        if let old = decompressionSession {
            VTDecompressionSessionInvalidate(old)
            decompressionSession = nil
        }
        guard let fmtDesc = formatDescription else { return }

        let videoCallback: VTDecompressionOutputCallback = { refcon, _, status, _, imageBuffer, pts, duration in
            guard status == noErr, let pixelBuffer = imageBuffer else { return }
            let decoder = Unmanaged<VideoDecoder>.fromOpaque(refcon!).takeUnretainedValue()
            decoder.onFrameDecoded(pixelBuffer: pixelBuffer, pts: pts, duration: duration)
        }

        var callbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: videoCallback,
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        let decoderSpec: [CFString: Any] = [
            kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder: true
        ]
        let imageBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        ]

        var session: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: fmtDesc,
            decoderSpecification: decoderSpec as CFDictionary,
            imageBufferAttributes: imageBufferAttributes as CFDictionary,
            outputCallback: &callbackRecord,
            decompressionSessionOut: &session
        )
        if status == noErr { decompressionSession = session }
    }

    private func onFrameDecoded(pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) {
        guard let fmtDesc = formatDescription else { return }
        var sb: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(duration: duration, presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: fmtDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sb
        )
        guard let sampleBuffer = sb else { return }
        DispatchQueue.main.async { [weak self] in
            self?.displayLayer?.enqueue(sampleBuffer)
            self?.onDecodedSampleBuffer?(sampleBuffer)
        }
    }

    /// Convert Annex-B (start-code prefixed) to AVCC (4-byte big-endian length prefix).
    private func annexBToAVCC(_ data: Data) -> Data {
        let nalUnits = MediaIngressServer.splitAnnexB(data)
        var result = Data()
        for nal in nalUnits where !nal.isEmpty {
            var length = UInt32(nal.count).bigEndian
            result.append(contentsOf: withUnsafeBytes(of: &length) { Array($0) })
            result.append(nal)
        }
        return result
    }
}
