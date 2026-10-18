TARGET := iphone:clang:9.3:6.0
ARCHS := armv7

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YaMus1c

YaMus1c_FILES = main.m YMCore.m YMControllers.m
YaMus1c_FRAMEWORKS = UIKit Foundation AVFoundation MediaPlayer CoreGraphics QuartzCore CoreMedia
YaMus1c_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
YaMus1c_LDFLAGS = -Wl,-w -Wl,-no_fixup_chains -Wl,-no_function_starts -Wl,-flat_namespace -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/application.mk