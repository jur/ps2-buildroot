################################################################################
#
# juhutube
#
################################################################################

JUHUTUBE_VERSION = 14ec4211a89d063b27ebcb07ef2dd2f26153ce28
JUHUTUBE_SITE = git://github.com/jur/juhutube
JUHUTUBE_LICENSE = BSD-3c
JUHUTUBE_LICENSE_FILES = LICENSE
JUHUTUBE_DEPENDENCIES = libjson sdl sdl_image sdl_ttf libcurl

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
