THEOS_DEVICE_IP = 192.168.178.116
FINALPACKAGE = 1
# PREFIX = $(THEOS)/toolchain/Xcode.xctoolchain/usr/bin/
THEOS_PACKAGE_SCHEME=rootless
export ADDITIONAL_CFLAGS = -DTHEOS_LEAN_AND_MEAN -fobjc-arc -O3
export TARGET = iphone:16.1

ARCHS = arm64e

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libmitsuhaforever
$(LIBRARY_NAME)_OBJC_FILES = $(wildcard *.m)
$(LIBRARY_NAME)_FILES = $(wildcard *.swift)
$(LIBRARY_NAME)_SWIFTFLAGS += -enable-library-evolution
$(LIBRARY_NAME)_SWIFT_BRIDGING_HEADER = libmitsuhaforever-Bridging-Header.h

include $(THEOS_MAKE_PATH)/library.mk

after-install::
	install.exec "killall -9 SpringBoard"

stage::
	mkdir -p $(THEOS_STAGING_DIR)/usr/include/MitsuhaForever
	$(ECHO_NOTHING)rsync -a ./public/* $(THEOS_STAGING_DIR)/usr/include/MitsuhaForever $(FW_RSYNC_EXCLUDES)$(ECHO_END)
	mkdir -p $(THEOS)/include/MitsuhaForever
	cp -r ./public/* $(THEOS)/include/MitsuhaForever
	cp $(THEOS_STAGING_DIR)/usr/lib/libmitsuhaforever.dylib $(THEOS)/lib/libmitsuhaforever.dylib
