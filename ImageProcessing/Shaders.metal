//
//  Shaders.metal
//  ImageProcessing
//
//  Created by Warren Moore on 10/4/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//

#include <metal_stdlib>

#include "SharedStructs.h"

using namespace metal;

constant int KERNEL_HALF_SIZE = 7;

Statistics calcStatistics(texture2d<float, access::read> inTexture, int xStart, int yStart);

struct AdjustSaturationUniforms
{
    float saturationFactor;
};

kernel void adjust_saturation(texture2d<float, access::read> inTexture [[texture(0)]],
                              texture2d<float, access::write> outTexture [[texture(1)]],
                              constant AdjustSaturationUniforms &uniforms [[buffer(0)]],
                              uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = inTexture.read(gid);
    float value = dot(inColor.rgb, float3(0.299, 0.587, 0.114));
    float4 grayColor(value, value, value, 1.0);
    float4 outColor = mix(grayColor, inColor, uniforms.saturationFactor);
    outTexture.write(outColor, gid);
}

kernel void gaussian_blur_2d(texture2d<float, access::read> inTexture [[texture(0)]],
                             texture2d<float, access::write> outTexture [[texture(1)]],
                             texture2d<float, access::read> weights [[texture(2)]],
                             uint2 gid [[thread_position_in_grid]])
{
    int size = weights.get_width();
    int radius = size / 2;
    
    float4 accumColor(0, 0, 0, 0);
    for (int j = 0; j < size; ++j)
    {
        for (int i = 0; i < size; ++i)
        {
            uint2 kernelIndex(i, j);
            uint2 textureIndex(gid.x + (i - radius), gid.y + (j - radius));
            float4 color = inTexture.read(textureIndex).rgba;
            float4 weight = weights.read(kernelIndex).rrrr;
            accumColor += weight * color;
        }
    }

    outTexture.write(float4(accumColor.rgb, 1), gid);
}

Statistics calcStatistics(texture2d<float, access::read> inTexture, int xStart, int yStart) {
  Statistics stats;
  stats.mean = 0;
  stats.meanOfSquares = 0;

  int count = 0;
  for (int x = xStart; x <= xStart + KERNEL_HALF_SIZE; ++x) {
    for (int y = yStart; y <= yStart + KERNEL_HALF_SIZE; ++y) {
      float4 c = inTexture.read(uint2(x, y));
      stats.mean += c;
      stats.meanOfSquares += c * c;
      ++count;
    }
  }

  stats.mean /= count;
  stats.meanOfSquares /= count;
  stats.stdDevSQ = stats.meanOfSquares - stats.mean * stats.mean;

  return stats;
}

kernel void kuwahara_filter_naive(texture2d<float, access::read> inTexture [[texture(0)]],
                                  texture2d<float, access::write> outTexture [[texture(1)]],
                                  //constant KernelUniforms &uniforms [[buffer(0)]],
                                  uint2 gid [[thread_position_in_grid]])
{
  Statistics stats[4];
  // upper left
  stats[0] = calcStatistics(inTexture, gid.x - KERNEL_HALF_SIZE, gid.y - KERNEL_HALF_SIZE);
  // upper rigth
  stats[1] = calcStatistics(inTexture, gid.x, gid.y - KERNEL_HALF_SIZE);
  // bottom left
  stats[2] = calcStatistics(inTexture, gid.x - KERNEL_HALF_SIZE, gid.y);
  // bottom right
  stats[3] = calcStatistics(inTexture, gid.x, gid.y);

  Statistics minStats = stats[0];
  for (int i = 1; i < 4; ++i) {
    if (minStats.stdDevSQ.r > stats[i].stdDevSQ.r) {
      minStats.stdDevSQ.r = stats[i].stdDevSQ.r;
      minStats.mean.r = stats[i].mean.r;
    }
    if (minStats.stdDevSQ.g > stats[i].stdDevSQ.g) {
      minStats.stdDevSQ.g = stats[i].stdDevSQ.g;
      minStats.mean.g = stats[i].mean.g;
    }
    if (minStats.stdDevSQ.b > stats[i].stdDevSQ.b) {
      minStats.stdDevSQ.b = stats[i].stdDevSQ.b;
      minStats.mean.b = stats[i].mean.b;
    }
  }

  float4 outColor = minStats.mean;

  outTexture.write(float4(outColor.rgb, 1), gid);
}

kernel void kuwahara_filter(texture2d<float, access::read> inTexture [[texture(0)]],
                            texture2d<float, access::write> outTexture [[texture(1)]],
                            constant KernelUniforms &uniforms [[buffer(0)]],
                            threadgroup Statistics *stats [[threadgroup(0)]],
                            //threadgroup float4 *pixels [[threadgroup(1)]],
                            uint2 tid [[thread_position_in_threadgroup]],
                            uint2 groupPos [[ threadgroup_position_in_grid ]],
                            uint2 groupSize [[ threads_per_threadgroup ]])
{
  uint fourGroupIndex = tid.x / 4;
  uint inFourGroupIndex = tid.x % 4;
  uint2 pixelsInGroup = uint2(uniforms.groupWitdh / 2, uniforms.groupHeight / 2);

  uint2 pixelInGroup = uint2(fourGroupIndex / pixelsInGroup.x, fourGroupIndex % pixelsInGroup.y);

  uint2 pixelIdx = uint2(groupPos.x * pixelsInGroup.x + pixelInGroup.x,
                         groupPos.y * pixelsInGroup.y + pixelInGroup.y);

  uint2 start(0);
  if (inFourGroupIndex == 0) {
    start = uint2(pixelIdx.x - KERNEL_HALF_SIZE, pixelIdx.y - KERNEL_HALF_SIZE);
  } else if (inFourGroupIndex == 1) {
    start = uint2(pixelIdx.x, pixelIdx.y - KERNEL_HALF_SIZE);
  } else if (inFourGroupIndex == 2) {
    start = uint2(pixelIdx.x - KERNEL_HALF_SIZE, pixelIdx.y);
  } else if (inFourGroupIndex == 3) {
    start = uint2(pixelIdx.x, pixelIdx.y);
  }

  stats[tid.x] = calcStatistics(inTexture, start.x, start.y);

  if (inFourGroupIndex > 0) {
    return;
  }

  Statistics minStats = stats[tid.x];
  for (uint i = tid.x + 1; i < tid.x + 4; ++i) {
    if (minStats.stdDevSQ.r > stats[i].stdDevSQ.r) {
      minStats.stdDevSQ.r = stats[i].stdDevSQ.r;
      minStats.mean.r = stats[i].mean.r;
    }
    if (minStats.stdDevSQ.g > stats[i].stdDevSQ.g) {
      minStats.stdDevSQ.g = stats[i].stdDevSQ.g;
      minStats.mean.g = stats[i].mean.g;
    }
    if (minStats.stdDevSQ.b > stats[i].stdDevSQ.b) {
      minStats.stdDevSQ.b = stats[i].stdDevSQ.b;
      minStats.mean.b = stats[i].mean.b;
    }
  }

  float4 outColor = minStats.mean;

  outTexture.write(float4(outColor.rgb, 1), pixelIdx);
}

//void loadData(texture2d<float, access::read> inTexture [[texture(0)]],
//              threadgroup float4 *pixels [[threadgroup(1)]],
//              uint2 tid,
//              uint2 groupPos,
//              uint2 groupSize,
//              uint2 textureStart) {
//
//
//  float4 color = inTexture.read();
//
//}
//
//kernel void kuwahara_filter_collaborative2(texture2d<float, access::read> inTexture [[texture(0)]],
//                            texture2d<float, access::write> outTexture [[texture(1)]],
                            constant KuwaharaUniforms &uniforms [[buffer(0)]],
//                            threadgroup Statistics *stats [[threadgroup(0)]],
//                            threadgroup float4 *pixels [[threadgroup(1)]],
//                            uint2 tid [[thread_position_in_threadgroup]],
//                            uint2 groupPos [[ threadgroup_position_in_grid ]],
//                            uint2 groupSize [[ threads_per_threadgroup ]])
//{
//  uint fourGroupIndex = tid.x / 4;
//  uint inFourGroupIndex = tid.x % 4;
//  uint2 pixelsInGroup = uint2(uniforms.groupWitdh / 2, uniforms.groupHeight / 2);
//
//  uint2 pixelInGroup = uint2(fourGroupIndex / pixelsInGroup.x, fourGroupIndex % pixelsInGroup.y);
//
//  uint2 pixelIdx = uint2(groupPos.x * pixelsInGroup.x + pixelInGroup.x,
//                         groupPos.y * pixelsInGroup.y + pixelInGroup.y);
//
//  uint2 start(0);
//  if (inFourGroupIndex == 0) {
//    start = uint2(pixelIdx.x - KERNEL_HALF_SIZE, pixelIdx.y - KERNEL_HALF_SIZE);
//  } else if (inFourGroupIndex == 1) {
//    start = uint2(pixelIdx.x, pixelIdx.y - KERNEL_HALF_SIZE);
//  } else if (inFourGroupIndex == 2) {
//    start = uint2(pixelIdx.x - KERNEL_HALF_SIZE, pixelIdx.y);
//  } else if (inFourGroupIndex == 3) {
//    start = uint2(pixelIdx.x, pixelIdx.y);
//  }
//
//  stats[tid.x] = calcStatistics(inTexture, start.x, start.y);
//
//  if (inFourGroupIndex > 0) {
//    return;
//  }
//
//  Statistics minStats = stats[tid.x];
//  for (uint i = tid.x + 1; i < tid.x + 4; ++i) {
//    if (minStats.stdDevSQ.r > stats[i].stdDevSQ.r) {
//      minStats.stdDevSQ.r = stats[i].stdDevSQ.r;
//      minStats.mean.r = stats[i].mean.r;
//    }
//    if (minStats.stdDevSQ.g > stats[i].stdDevSQ.g) {
//      minStats.stdDevSQ.g = stats[i].stdDevSQ.g;
//      minStats.mean.g = stats[i].mean.g;
//    }
//    if (minStats.stdDevSQ.b > stats[i].stdDevSQ.b) {
//      minStats.stdDevSQ.b = stats[i].stdDevSQ.b;
//      minStats.mean.b = stats[i].mean.b;
//    }
//  }
//
//  float4 outColor = minStats.mean;
//
//  outTexture.write(float4(outColor.rgb, 1), pixelIdx);
//}

