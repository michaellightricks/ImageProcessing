// Copyright (c) 2016 Lightricks. All rights reserved.
// Created by Michael Kupchick.

#import "MBETimer.h"
#include <mach/mach.h>
#include <mach/mach_time.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBETimer()

@property (nonatomic) uint64_t startMach;

@property (nonatomic) mach_timebase_info_data_t info;

@end

@implementation MBETimer

- (instancetype)init {
  if (self = [super init]) {
    if (mach_timebase_info (&_info) != KERN_SUCCESS) {
      printf ("mach_timebase_info failed\n");

      return nil;
    }
  }

  return self;
}

- (void)start {

  self.startMach = mach_absolute_time();
}

- (CGFloat)elapse {
  uint64_t end = mach_absolute_time();
  uint64_t elapsed = end - self.startMach;

  uint64_t nanosecs = elapsed * self.info.numer / self.info.denom;
  uint64_t millisecs = nanosecs / 1000000;

  return millisecs;
}

@end

NS_ASSUME_NONNULL_END
