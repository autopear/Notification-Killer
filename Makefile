export ARCHS = arm64 armv7
export TARGET = iphone:9.2:7.0

include theos/makefiles/common.mk

TWEAK_NAME = NotificationKiller
NotificationKiller_FILES = Tweak.xm
NotificationKiller_FRAMEWORKS = UIKit
NotificationKiller_LDFLAGS = -weak_library theos/lib/libactivator.dylib
NotificationKiller_CFLAGS = -Wno-error
NotificationKiller_LDFLAGS += -Wl,-segalign,4000

VERSION.INC_BUILD_NUMBER = 1

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += nkprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
	find $(THEOS_STAGING_DIR) -name "*.plist" -exec plutil -convert binary1 {} \;
	find $(THEOS_STAGING_DIR) -name "*.strings" -exec chmod 0644 {} \;
	find $(THEOS_STAGING_DIR) -name "*.plist" -exec chmod 0644 {} \;
	find $(THEOS_STAGING_DIR) -name "*.png" -exec chmod 0644 {} \;
	find $(THEOS_STAGING_DIR) -exec touch -r $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/NotificationKiller.dylib {} \;
