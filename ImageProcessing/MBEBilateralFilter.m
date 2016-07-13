// Copyright (c) 2016 Lightricks. All rights reserved.
// Created by Michael Kupchick.

#import "MBEBilateralFilter.h"

#import "SharedStructs.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MBEBilateralFilter

static const NSUInteger kGroupSize = 16;

- (instancetype)initWithKernelSize:(NSUInteger)size context:(MBEContext *)context {
  if (self = [super initWithFunctionName:@"bilateral_filter" context:context]) {
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
  struct BilateralUniforms uniforms;
  uniforms.kernelHalfSize = (unsigned int)self.kernelSize / 2;
  uniforms.rangeSigma = self.rangeSigma;
  uniforms.groupWitdh = kGroupSize;
  uniforms.groupHeight = kGroupSize;

  if (!self.uniformBuffer)
  {
    self.uniformBuffer = [self.context.device newBufferWithLength:sizeof(uniforms)
                                                          options:MTLResourceOptionCPUCacheModeDefault];
  }

  memcpy([self.uniformBuffer contents], &uniforms, sizeof(uniforms));

  [commandEncoder setBuffer:self.uniformBuffer offset:0 atIndex:0];
}

- (MTLSize)threadGroupSize {
  return MTLSizeMake(kGroupSize, kGroupSize, 1);
  //return MTLSizeMake(kGroupSize, kGroupSize, 1);
}

- (MTLSize)threadGroupsCount:(MTLSize)threadGroupSize {
  return MTLSizeMake(self.provider.texture.width / kGroupSize,
                     self.provider.texture.height / kGroupSize, 1);
}

@end

NS_ASSUME_NONNULL_END
