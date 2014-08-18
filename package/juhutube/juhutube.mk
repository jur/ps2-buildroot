################################################################################
#
# juhutube
#
################################################################################

JUHUTUBE_VERSION = da038b5aa2c2c76cc62b788470dd7ea477cafef1
JUHUTUBE_SITE = git://github.com/jur/juhutube
JUHUTUBE_LICENSE = BSD-3c
JUHUTUBE_LICENSE_FILES = LICENSE
JUHUTUBE_DEPENDENCIES = youtube-dl libjson sdl sdl_image sdl_ttf wget mplayer libcurl

define JUHUTUBE_BUILD_CMDS
	$(MAKE) CROSS_COMPILE="$(TARGET_CROSS)" -C $(@D) all
endef

define JUHUTUBE_INSTALL_STAGING_CMDS
	$(MAKE) CROSS_COMPILE="$(TARGET_CROSS)" CHROOTDIR="$(STAGING_DIR)" PREFIX="/usr" -C $(@D)/libjt install
endef

define JUHUTUBE_INSTALL_TARGET_CMDS
	$(MAKE) CROSS_COMPILE="$(TARGET_CROSS)" CHROOTDIR="$(TARGET_DIR)" PREFIX="/usr" -C $(@D)/samples/navigator install
endef

$(eval $(generic-package))
