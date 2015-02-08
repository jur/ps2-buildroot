################################################################################
#
# juhutube
#
################################################################################

JUHUTUBE_VERSION = f0a7b8effca7bce6ae4a4bc5f710b9c9f8cb3e68
JUHUTUBE_SITE = git://github.com/jur/juhutube
JUHUTUBE_LICENSE = BSD-3c
JUHUTUBE_LICENSE_FILES = LICENSE
JUHUTUBE_DEPENDENCIES = libjson sdl sdl_image sdl_ttf libcurl

define JUHUTUBE_BUILD_CMDS
	$(MAKE) CROSS_COMPILE="$(TARGET_CROSS)" PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" -C $(@D) all
endef

define JUHUTUBE_INSTALL_STAGING_CMDS
	$(MAKE) CROSS_COMPILE="$(TARGET_CROSS)" PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" CHROOTDIR="$(STAGING_DIR)" PREFIX="/usr" -C $(@D)/libjt install
endef

define JUHUTUBE_INSTALL_TARGET_CMDS
	$(MAKE) CROSS_COMPILE="$(TARGET_CROSS)" PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" CHROOTDIR="$(TARGET_DIR)" PREFIX="/usr" -C $(@D)/samples/navigator install
endef

define JUHUTUBE_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 755 package/juhutube/S95juhutube \
		$(TARGET_DIR)/etc/init.d/S95juhutube
endef

$(eval $(generic-package))
