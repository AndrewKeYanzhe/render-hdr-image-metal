//
//  HDRmetadata.swift
//
//  Created by Zero on 2024/4/7.
//

// HDR metadata to Apple EDR metadata, which is used to describe brightness of the metalLayer.

// How to use:
// You must have the following data:
// MasteringDisplayMetadata、ContentLightMetadata、AmbientViewingEnvironment
//

// let hdrMetadata = HDRMetaData(...)
// 
// let layer: CAMetalLayer
// layer.wantsExtendedDynamicRangeContent = true
// layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
// layer.pixelFormat = MTLPixelFormat.rgba16Float
// layer.edrMetadata = hdrMetadata.toEDRMetadata

import AVFoundation

public struct HDRMetaData {
    var masteringDisplayMetadata: MasteringDisplayMetadata?
    var contentLightMetadata: ContentLightMetadata?
    var ambientViewingEnvironment: AmbientViewingEnvironment?

    var toEDRMetadata: CAEDRMetadata? {
        if let displayData = masteringDisplayMetadata,
           let contentData = contentLightMetadata
        {
            return CAEDRMetadata.hdr10(displayInfo: displayData.toSEIData(), contentInfo: contentData.toSEIData(), opticalOutputScale: 10000)
        }

        if let sei = ambientViewingEnvironment?.toSEIData() {
            if #available(macOS 14.0, iOS 17.0, *) {
                return CAEDRMetadata.hlg(ambientViewingEnvironment: sei)
            } else {
                return CAEDRMetadata.hlg
            }
        }

        return CAEDRMetadata.hdr10(minLuminance: 0.1, maxLuminance: 1000, opticalOutputScale: 10000)
    }
}

public struct MasteringDisplayMetadata {
    let display_primaries_r_x: Float
    let display_primaries_r_y: Float
    let display_primaries_g_x: Float
    let display_primaries_g_y: Float
    let display_primaries_b_x: Float
    let display_primaries_b_y: Float
    let white_point_x: Float
    let white_point_y: Float
    var min_luminance: Float
    var max_luminance: Float

    /// 转换为 apple EDR SEI 数据
    /// https://github.com/chromium/chromium/blob/main/ui/gfx/hdr_metadata_mac.mm
    func toSEIData() -> Data? {
        struct MasteringDisplayColorVolumeSEI {
            var primaries: (SIMD2<UInt16>, SIMD2<UInt16>, SIMD2<UInt16>) // GBR
            var white_point: SIMD2<UInt16>
            var luminance_max: UInt32
            var luminance_min: UInt32
        }

        // 确保结构体大小为 24 字节
        assert(MemoryLayout<MasteringDisplayColorVolumeSEI>.size == 24, "Must be 24 bytes")

        let kColorCoordinateUpperBound: Float = 50000.0
        let kUnitOfMasteringLuminance: Float = 10000.0

        let luminanceMin = min_luminance * kUnitOfMasteringLuminance
        let luminanceMax = max_luminance * kUnitOfMasteringLuminance

        var sei = MasteringDisplayColorVolumeSEI(
            primaries: (
                SIMD2<UInt16>(CFSwapInt16HostToBig(UInt16(display_primaries_g_x * kColorCoordinateUpperBound + 0.5)),
                              CFSwapInt16HostToBig(UInt16(display_primaries_g_y * kColorCoordinateUpperBound + 0.5))),
                SIMD2<UInt16>(CFSwapInt16HostToBig(UInt16(display_primaries_b_x * kColorCoordinateUpperBound + 0.5)),
                              CFSwapInt16HostToBig(UInt16(display_primaries_b_y * kColorCoordinateUpperBound + 0.5))),
                SIMD2<UInt16>(CFSwapInt16HostToBig(UInt16(display_primaries_r_x * kColorCoordinateUpperBound + 0.5)),
                              CFSwapInt16HostToBig(UInt16(display_primaries_r_y * kColorCoordinateUpperBound + 0.5)))
            ),
            white_point: SIMD2<UInt16>(x: CFSwapInt16HostToBig(UInt16(white_point_x * kColorCoordinateUpperBound + 0.5)),
                                       y: CFSwapInt16HostToBig(UInt16(white_point_y * kColorCoordinateUpperBound + 0.5))),
            luminance_max: CFSwapInt32HostToBig(UInt32(luminanceMax + 0.5)),
            luminance_min: CFSwapInt32HostToBig(UInt32(luminanceMin + 0.5))
        )

        let data = withUnsafeBytes(of: &sei) { Data($0) }
        guard let cfData = CFDataCreate(nil, data.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }, data.count) else {
            return nil
        }
        return Data(referencing: cfData)
    }
}

public struct ContentLightMetadata {
    let MaxCLL: UInt16 // Max content light level
    let MaxFALL: UInt16 // Max average light level per frame

    /// 转换为 apple EDR SEI 数据
    /// https://github.com/chromium/chromium/blob/main/ui/gfx/hdr_metadata_mac.mm
    func toSEIData() -> Data? {
        struct ContentLightLevelInfoSEI {
            var max_content_light_level: UInt16
            var max_frame_average_light_level: UInt16
        }

        // 确保结构体大小为 4 字节
        assert(MemoryLayout<ContentLightLevelInfoSEI>.size == 4, "Must be 24 bytes")

        var sei = ContentLightLevelInfoSEI(
            max_content_light_level: CFSwapInt16HostToBig(UInt16(MaxCLL)),
            max_frame_average_light_level: CFSwapInt16HostToBig(UInt16(MaxFALL))
        )

        let data = withUnsafeBytes(of: &sei) { Data($0) }
        guard let cfData = CFDataCreate(nil, data.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }, data.count) else {
            return nil
        }
        return Data(referencing: cfData)
    }
}

/// https://developer.apple.com/documentation/technotes/tn3145-hdr-video-metadata
public struct AmbientViewingEnvironment {
    let ambient_illuminance: Float
    let ambient_light_x: Float
    let ambient_light_y: Float

    /// 转换为 apple EDR SEI 数据
    func toSEIData() -> Data? {
        struct AmbientViewingEnvironmentSEI {
            var ambient_illuminance: UInt32
            var ambient_light_x: UInt16
            var ambient_light_y: UInt16
        }

        // 确保结构体大小为 8 字节
        assert(MemoryLayout<AmbientViewingEnvironmentSEI>.size == 8, "Must be 8 bytes")

        let sei = AmbientViewingEnvironmentSEI(
            ambient_illuminance: CFSwapInt32HostToBig(UInt32(ambient_illuminance * 10000.0)),
            ambient_light_x: CFSwapInt16HostToBig(UInt16(ambient_light_x * 50000.0)),
            ambient_light_y: CFSwapInt16HostToBig(UInt16(ambient_light_y * 50000.0))
        )

        let data = withUnsafeBytes(of: sei) { Data($0) }
        guard let cfData = CFDataCreate(nil, data.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }, data.count) else {
            return nil
        }
        return Data(referencing: cfData)
    }
}
