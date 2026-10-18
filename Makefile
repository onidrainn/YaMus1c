TARGET := iphone:clang:9.3:6.0
ARCHS := armv7

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = yourproject

yourproject_FILES = main.m YMCore.m YMControllers.m
yourproject_FRAMEWORKS = UIKit Foundation AVFoundation MediaPlayer CoreGraphics QuartzCore CoreMedia
yourproject_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
yourproject_LDFLAGS = -Wl,-w -Wl,-no_fixup_chains -Wl,-no_function_starts -Wl,-flat_namespace -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/application.mk