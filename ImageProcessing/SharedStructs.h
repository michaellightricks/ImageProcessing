//
//  SharedStructs.h
//  ImageProcessing
//
//  Created by Michael Kupchick on 6/15/16.
//  Copyright © 2016 Metal By Example. All rights reserved.
//

#ifndef SharedStructs_h
#define SharedStructs_h

#include <simd/simd.h>

struct KernelUniforms {
  unsigned int kernelHalfSize;
  unsigned int groupWitdh;
  unsigned int groupHeight;
};

struct BilateralUniforms {
  unsigned short kernelHalfSize;
  vector_float2 offsetStep;
  unsigned int count;
  float rangeSigma;
  unsigned int width;
  unsigned int height;
};

typedef struct StatisticsType {
  vector_float4 mean;
  vector_float4 meanOfSquares;
  vector_float4 stdDevSQ;
} Statistics;

#endif /* SharedStructs_h */
