THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

BUNDLE_NAME = SCCTile1 SCCTile2 SCCTile3 SCCTile4 SCCTile5 SCCTile6

SCCTile1_FILES = SCCTileModuleShared.m
SCCTile2_FILES = SCCTileModuleShared.m
SCCTile3_FILES = SCCTileModuleShared.m
SCCTile4_FILES = SCCTileModuleShared.m
SCCTile5_FILES = SCCTileModuleShared.m
SCCTile6_FILES = SCCTileModuleShared.m

SCCTile1_CFLAGS = -fobjc-arc -DSLOT=1
SCCTile2_CFLAGS = -fobjc-arc -DSLOT=2
SCCTile3_CFLAGS = -fobjc-arc -DSLOT=3
SCCTile4_CFLAGS = -fobjc-arc -DSLOT=4
SCCTile5_CFLAGS = -fobjc-arc -DSLOT=5
SCCTile6_CFLAGS = -fobjc-arc -DSLOT=6

SCCTile1_FRAMEWORKS = UIKit Foundation
SCCTile2_FRAMEWORKS = UIKit Foundation
SCCTile3_FRAMEWORKS = UIKit Foundation
SCCTile4_FRAMEWORKS = UIKit Foundation
SCCTile5_FRAMEWORKS = UIKit Foundation
SCCTile6_FRAMEWORKS = UIKit Foundation

SCCTile1_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit
SCCTile1_LIBRARIES = sqlite3
SCCTile2_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit
SCCTile2_LIBRARIES = sqlite3
SCCTile3_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit
SCCTile3_LIBRARIES = sqlite3
SCCTile4_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit
SCCTile4_LIBRARIES = sqlite3
SCCTile5_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit
SCCTile5_LIBRARIES = sqlite3
SCCTile6_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit
SCCTile6_LIBRARIES = sqlite3

SCCTile1_RESOURCE_FILES = Res1/Info.plist
SCCTile2_RESOURCE_FILES = Res2/Info.plist
SCCTile3_RESOURCE_FILES = Res3/Info.plist
SCCTile4_RESOURCE_FILES = Res4/Info.plist
SCCTile5_RESOURCE_FILES = Res5/Info.plist
SCCTile6_RESOURCE_FILES = Res6/Info.plist

SCCTile1_INSTALL_PATH = /Library/ControlCenter/Bundles
SCCTile2_INSTALL_PATH = /Library/ControlCenter/Bundles
SCCTile3_INSTALL_PATH = /Library/ControlCenter/Bundles
SCCTile4_INSTALL_PATH = /Library/ControlCenter/Bundles
SCCTile5_INSTALL_PATH = /Library/ControlCenter/Bundles
SCCTile6_INSTALL_PATH = /Library/ControlCenter/Bundles

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk
