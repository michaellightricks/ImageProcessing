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
                             texture2d<float, access::read> guideTexture [[texture(2)]],
                             texture2d<float, access::write> outTexture [[texture(1)]],
                             constant BilateralUniforms &uniforms [[buffer(0)]],
                             uint2 gridPos [[ thread_position_in_grid ]]) {
  float4 guideColor = guideTexture.read(gridPos);

  float weightSum = 1;
  float4 colorSum = inTexture.read(gridPos);
  for (int i = 1; i <= uniforms.kernelHalfSize; ++i) {
    uint2 neighborCoordsP = gridPos + i * (uint2)uniforms.offsetStep;
    uint2 neighborCoordsN = gridPos - i * (uint2)uniforms.offsetStep;

    float4 colorDiffN = guideColor - guideTexture.read(neighborCoordsN);
    float4 colorDiffP = guideColor - guideTexture.read(neighborCoordsP);

    float weightN = exp(-sqrt(dot(colorDiffN, colorDiffN)) / (uniforms.rangeSigma));
    float weightP = exp(-sqrt(dot(colorDiffP, colorDiffP)) / (uniforms.rangeSigma));
    weightSum += weightN + weightP ;
    colorSum += weightN * inTexture.read(neighborCoordsN) +
    weightP * inTexture.read(neighborCoordsP);
  }
  outTexture.write(colorSum / weightSum, gridPos);
}
