// Copyright (c) 2016 Lightricks. All rights reserved.
// Created by Michael Kupchick.

#import "MBEImageFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface MBEKuwaharaFilter : MBEImageFilter

+ (instancetype)filterWithKernelSize:(NSUInteger)saturation context:(MBEContext *)context;

@property (nonatomic) NSUInteger kernelSize;

@end

NS_ASSUME_NONNULL_END
