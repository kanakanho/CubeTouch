//
//  SIMD+.swift
//  CubeTouch
//
//  Created by blueken on 2026/04/15.
//

import simd

extension SIMD4 where Scalar: SIMDScalar {
    var position: SIMD3<Scalar> {
        get {
            return SIMD3<Scalar>(x, y, z)
        }
        set {
            self.x = newValue.x
            self.y = newValue.y
            self.z = newValue.z
        }
    }
}

extension simd_float4x4 {
    var position: simd_float3 {
        get {
            return columns.3.position
        }
        set {
            columns.3.position = newValue
        }
    }
}
