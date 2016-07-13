// Copyright (c) 2016 Lightricks. All rights reserved.
// Created by Michael Kupchick.

#import <Foundation/Foundation.h>

#import "MBEImageFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface MBEBilateralFilter : MBEImageFilter

- (instancetype)initWithKernelSize:(NSUInteger)saturation rangeSigma:(float) rangeSigma
                           context:(MBEContext *)context;

+ (instancetype)filterWithKernelSize:(NSUInteger)saturation rangeSigma:(float) rangeSigma
                             context:(MBEContext *)context;

@property (nonatomic) NSUInteger kernelSize;

@property (nonatomic) float rangeSigma;

@end

NS_ASSUME_NONNULL_END
