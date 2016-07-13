// Copyright (c) 2016 Lightricks. All rights reserved.
// Created by Michael Kupchick.

#import "MBEBilateralFilter.h"

#import "SharedStructs.h"

NS_ASSUME_NONNULL_BEGIN

@interface MBEBilateralFilter()

@property (strong, nonatomic) id<MTLTexture> tempTexture;
@property (strong, nonatomic) id<MTLBuffer> uniformBufferTemp;
@property (strong, nonatomic) id<MTLSamplerState> sampler;

@end

@implementation MBEBilateralFilter

static const NSUInteger kGroupSize = 16;

- (instancetype)initWithKernelSize:(NSUInteger)size rangeSigma:(float)sigma
                           context:(MBEContext *)context {
  if (self = [super initWithFunctionName:@"bilateral_filter" context:context]) {
    _kernelSize = size;
    _rangeSigma = sigma;
    self.iterationsNumber = 2;
    self.uniformBuffer = [self.context.device newBufferWithLength:sizeof(struct BilateralUniforms)
                                                          options:MTLResourceOptionCPUCacheModeDefault];
    self.uniformBufferTemp = [self.context.device newBufferWithLength:sizeof(struct BilateralUniforms)
                                                              options:MTLResourceOptionCPUCacheModeDefault];
//    MTLSamplerDescriptor
//    _sampler = self.context.device newSamplerStateWithDescriptor:
  }

  return self;
}

+ (instancetype)filterWithKernelSize:(NSUInteger)kernelSize rangeSigma:(float)rangeSigma
                             context:(MBEContext *)context {
  return [[MBEBilateralFilter alloc] initWithKernelSize:kernelSize rangeSigma:rangeSigma
                                                context:context];
}

- (void)setKernelSize:(NSUInteger)kernelSize
{
  self.dirty = YES;
  _kernelSize = kernelSize;
}

- (void)configureArgumentTableWithCommandEncoder:(id<MTLComputeCommandEncoder>)commandEncoder
                                 iterationNumber:(NSUInteger)iteration
{
  struct BilateralUniforms uniforms;
  uniforms.kernelHalfSize = (unsigned int)self.kernelSize / 2;
  uniforms.rangeSigma = self.rangeSigma;
  uniforms.width = self.provider.texture.width;//kGroupSize;
  uniforms.height = self.provider.texture.height;//kGroupSize;
  uniforms.offsetStep.x = iteration % 2 == 0;// = vector2(1, 0);// / uniforms.width, 1.0f / uniforms.height);
  uniforms.offsetStep.y = iteration % 2 == 1;

  id<MTLBuffer> uniformBuffer;
  if (iteration % 2) {
    uniformBuffer = self.uniformBuffer;
  } else {
    uniformBuffer = self.uniformBufferTemp;
  }

  memcpy([uniformBuffer contents], &uniforms, sizeof(uniforms));

  if (self.tempTexture == nil || self.tempTexture.width != self.provider.texture.width ||
      self.tempTexture.height != self.provider.texture.height) {
    MTLTextureDescriptor *textureDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:[self.provider.texture pixelFormat]
                                                           width:[self.provider.texture width]
                                                          height:[self.provider.texture height]
                                                       mipmapped:NO];
    self.tempTexture = [self.context.device newTextureWithDescriptor:textureDescriptor];
  }

  if (iteration % 2 == 1) {
    [commandEncoder setTexture:self.tempTexture atIndex:0];
  } else {
    [commandEncoder setTexture:self.tempTexture atIndex:1];
  }

  [commandEncoder setTexture:self.provider.texture atIndex:2];
  [commandEncoder setBuffer:uniformBuffer offset:0 atIndex:0];
  //[commandEncoder setSamplerState:self.sampler atIndex:0];
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
