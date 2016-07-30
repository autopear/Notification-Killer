export ARCHS = arm64 armv7
export TARGET=iphone:9.2:7.0

include theos/makefiles/common.mk

BUNDLE_NAME = NKPrefs
NKPrefs_FILES = NKPrefs.mm
NKPrefs_INSTALL_PATH = /Library/PreferenceBundles
NKPrefs_FRAMEWORKS = UIKit
NKPrefs_PRIVATE_FRAMEWORKS = Preferences
NKPrefs_LDFLAGS += -Wl,-segalign,4000

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/NKPrefs.plist$(ECHO_END)
