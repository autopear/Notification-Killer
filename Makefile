export ARCHS = arm64 armv7s armv7
export TARGET = iphone:8.1:7.0

include theos/makefiles/common.mk

TWEAK_NAME = NotificationKiller
NotificationKiller_FILES = Tweak.xm
NotificationKiller_FRAMEWORKS = UIKit

VERSION.INC_BUILD_NUMBER = 1

include $(THEOS_MAKE_PATH)/tweak.mk

before-package::
	find _ -name "*.plist" -exec plutil -convert binary1 {} \;
	find _ -name "*.strings" -exec chmod 0644 {} \;
	find _ -name "*.plist" -exec chmod 0644 {} \;
	find _ -name "*.png" -exec chmod 0644 {} \;
	find _ -exec touch -r _/Library/MobileSubstrate/DynamicLibraries/NotificationKiller.dylib {} \;

after-package::
	rm -fr .theos/packages/*
