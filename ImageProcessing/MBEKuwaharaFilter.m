// Copyright (c) 2016 Lightricks. All rights reserved.
// Created by Michael Kupchick.

#import "MBEKuwaharaFilter.h"
#import <Metal/Metal.h>
#import "SharedStructs.h"

NS_ASSUME_NONNULL_BEGIN


@implementation MBEKuwaharaFilter

static const NSUInteger kGroupSize = 16;

const int KERNEL_HALF_SIZE = 7;

+ (instancetype)filterWithKernelSize:(NSUInteger)size context:(MBEContext *)context {
  return [[MBEKuwaharaFilter alloc] initWithKernelSize:size context:context];
}

- (instancetype)initWithKernelSize:(NSUInteger)size context:(MBEContext *)context {
  if (self = [super initWithFunctionName:@"kuwahara_filter" context:context]) {
    _kernelSize = size;
  }

  return self;
}

- (void)setKernelSize:(NSUInteger)kernelSize
{
  self.dirty = YES;
  _kernelSize = kernelSize;
}

- (void)configureArgumentTableWithCommandEncoder:(id<MTLComputeCommandEncoder>)commandEncoder
{
  struct KuwaharaUniforms uniforms;
  uniforms.kernelHalfSize = (unsigned int)self.kernelSize / 2;
  uniforms.groupWitdh = kGroupSize;
  uniforms.groupHeight = kGroupSize;

  if (!self.uniformBuffer)
  {
    self.uniformBuffer = [self.context.device newBufferWithLength:sizeof(uniforms)
                                                          options:MTLResourceOptionCPUCacheModeDefault];
  }

  memcpy([self.uniformBuffer contents], &uniforms, sizeof(uniforms));

  [commandEncoder setBuffer:self.uniformBuffer offset:0 atIndex:0];
  NSUInteger groupLength = kGroupSize * kGroupSize;
  NSUInteger pixelsPerBlockDimension = (2 * KERNEL_HALF_SIZE + kGroupSize / 2);
  NSUInteger pixelsPerBlock = pixelsPerBlockDimension * pixelsPerBlockDimension;
  [commandEncoder setThreadgroupMemoryLength:sizeof(Statistics) * groupLength atIndex:0];
  [commandEncoder setThreadgroupMemoryLength:pixelsPerBlock * sizeof(vector_float4) / 4 atIndex:1];
}

- (MTLSize)threadGroupSize {
  return MTLSizeMake(kGroupSize * kGroupSize, 1, 1);
  //return MTLSizeMake(kGroupSize, kGroupSize, 1);
}

- (MTLSize)threadGroupsCount:(MTLSize)threadGroupSize {
  return MTLSizeMake(self.provider.texture.width / kGroupSize * 2,
                     self.provider.texture.height / kGroupSize * 2, 1);
}

@end

NS_ASSUME_NONNULL_END
