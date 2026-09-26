THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:16.5:15.0
ARCHS = arm64e

TWEAK_NAME = SCCTile
SCCTile_FILES = Tweak.x SCCTileProvider.m SCCTileShortcutModule.m
SCCTile_FRAMEWORKS = UIKit Foundation
SCCTile_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit
SCCTile_CFLAGS = -fobjc-arc -Iinclude
SCCTile_LIBRARIES = substrate

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
