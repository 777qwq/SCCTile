THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:16.5:15.0
ARCHS = arm64e

BUNDLE_NAME = SCCTile

SCCTile_FILES = SCCTileProvider.m SCCTileShortcutModule.m
SCCTile_FRAMEWORKS = UIKit Foundation
SCCTile_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit
SCCTile_CFLAGS = -fobjc-arc -Iinclude
SCCTile_INSTALL_PATH = /Library/ControlCenter/CCSupport_Providers

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk
