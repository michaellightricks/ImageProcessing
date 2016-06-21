//
//  MBEImageFilter.m
//  ImageProcessing
//
//  Created by Warren Moore on 10/8/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//

#import "MBEImageFilter.h"
#import "MBEContext.h"
#import "MBETimer.h"
#import <Metal/Metal.h>

@interface MBEImageFilter ()
@property (nonatomic, strong) id<MTLFunction> kernelFunction;
@property (nonatomic, strong) id<MTLTexture> texture;

@property (nonatomic, strong) MBETimer *timer;
@end

@implementation MBEImageFilter

@synthesize dirty=_dirty;
@synthesize provider=_provider;

- (instancetype)initWithFunctionName:(NSString *)functionName context:(MBEContext *)context;
{
    if ((self = [super init]))
    {
        NSError *error = nil;
        _context = context;
        _timer = [[MBETimer alloc] init];
        _kernelFunction = [_context.library newFunctionWithName:functionName];
        _pipeline = [_context.device newComputePipelineStateWithFunction:_kernelFunction error:&error];
        if (!_pipeline)
        {
            NSLog(@"Error occurred when building compute pipeline for function %@", functionName);
            return nil;
        }
        _dirty = YES;
    }
    
    return self;
}

- (void)configureArgumentTableWithCommandEncoder:(id<MTLComputeCommandEncoder>)commandEncoder
{
}

- (void)applyFilter
{
    id<MTLTexture> inputTexture = self.provider.texture;
    
    if (!self.internalTexture ||
        [self.internalTexture width] != [inputTexture width] ||
        [self.internalTexture height] != [inputTexture height])
    {
        MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:[inputTexture pixelFormat]
                                                                                                     width:[inputTexture width]
                                                                                                    height:[inputTexture height]
                                                                                                 mipmapped:NO];
        self.internalTexture = [self.context.device newTextureWithDescriptor:textureDescriptor];
    }
    
    MTLSize threadgroupSize = [self threadGroupSize];
    MTLSize threadgroups = [self threadGroupsCount:threadgroupSize];
    
    id<MTLCommandBuffer> commandBuffer = [self.context.commandQueue commandBuffer];
    
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];

    [commandEncoder setComputePipelineState:self.pipeline];
    [commandEncoder setTexture:inputTexture atIndex:0];
    [commandEncoder setTexture:self.internalTexture atIndex:1];
    [self configureArgumentTableWithCommandEncoder:commandEncoder];
    [commandEncoder dispatchThreadgroups:threadgroups threadsPerThreadgroup:threadgroupSize];
    [commandEncoder endEncoding];

    [self.timer start];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    CGFloat ms = [self.timer elapse];
    NSLog(@"processed in %f", ms);

    if (commandBuffer.error) {
      NSLog(@"%@", commandBuffer.error);
      NSAssert(commandBuffer.error == nil, @"error");
    }
}

- (MTLSize)threadGroupSize {
  return MTLSizeMake(8, 8, 1);
}

- (MTLSize)threadGroupsCount:(MTLSize)threadGroupSize {
 return MTLSizeMake([self.provider.texture width] / threadGroupSize.width,
             [self.provider.texture height] / threadGroupSize.height,
             1);
}

- (id<MTLTexture>)texture
{
    if (self.isDirty)
    {
        [self applyFilter];
    }
    
    return self.internalTexture;
}

@end
