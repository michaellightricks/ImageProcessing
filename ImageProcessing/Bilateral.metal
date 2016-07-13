//
//  Bilateral.metal
//  ImageProcessing
//
//  Created by Michael Kupchick on 7/13/16.
//  Copyright © 2016 Metal By Example. All rights reserved.
//

#include <metal_stdlib>

#include "SharedStructs.h"

using namespace metal;


kernel void bilateral_filter(texture2d<float, access::read> inTexture [[texture(0)]],
                             texture2d<float, access::read> guideTexture [[texture(0)]],
                             texture2d<float, access::write> outTexture [[texture(1)]],
                             constant BilateralUniforms &uniforms [[buffer(0)]],
                             uint2 tid [[thread_position_in_threadgroup]],
                             uint2 groupPos [[ threadgroup_position_in_grid ]],
                             uint2 groupSize [[ threads_per_threadgroup ]],
                             uint2 gridPos [[ thread_position_in_grid ]]) {

  float3 sourceColor = inTexture.read(gridPos);
  float3 guideColor = guideTexture.read(gridPos);

  for (int i = -uniforms.kernelHalfSize; i <= uniforms.kernelHalfSize; ++i) {
    float3 colorDiff = guideColor - guideTexture.read(tid + i * uniforms.offsetStep)
  }

}
