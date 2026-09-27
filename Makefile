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

SCCTile1_FRAMEWORKS = UIKit Foundation CoreText
SCCTile2_FRAMEWORKS = UIKit Foundation CoreText
SCCTile3_FRAMEWORKS = UIKit Foundation CoreText
SCCTile4_FRAMEWORKS = UIKit Foundation CoreText
SCCTile5_FRAMEWORKS = UIKit Foundation CoreText
SCCTile6_FRAMEWORKS = UIKit Foundation CoreText

SCCTile1_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit CoreSpotlight
SCCTile1_LIBRARIES =
SCCTile2_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit CoreSpotlight
SCCTile2_LIBRARIES =
SCCTile3_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit CoreSpotlight
SCCTile3_LIBRARIES =
SCCTile4_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit CoreSpotlight
SCCTile4_LIBRARIES =
SCCTile5_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit CoreSpotlight
SCCTile5_LIBRARIES =
SCCTile6_PRIVATE_FRAMEWORKS = MobileCoreServices ControlCenterUIKit CoreSpotlight
SCCTile6_LIBRARIES =

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

TOOL_NAME = sctiled
sctiled_FILES = sctiled.m
sctiled_CFLAGS = -fobjc-arc
sctiled_FRAMEWORKS = Foundation CoreFoundation Security
sctiled_LIBRARIES = sqlite3
sctiled_CODESIGN_FLAGS = -Ssctiled.entitlements
sctiled_INSTALL_PATH = /usr/libexec

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk
include $(THEOS_MAKE_PATH)/tool.mk

after-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/LaunchDaemons$(ECHO_END)
	$(ECHO_NOTHING)cp layout/Library/LaunchDaemons/com.qwq.scctile.resolver.plist $(THEOS_STAGING_DIR)/Library/LaunchDaemons/$(ECHO_END)
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/DEBIAN$(ECHO_END)
	$(ECHO_NOTHING)for f in postinst prerm postrm; do [ -f DEBIAN/$$f ] && cp DEBIAN/$$f $(THEOS_STAGING_DIR)/DEBIAN/ && chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/$$f; done; true$(ECHO_END)
