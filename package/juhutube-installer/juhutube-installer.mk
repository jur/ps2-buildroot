################################################################################
#
# juhutube-installer
#
################################################################################

JUHUTUBE_INSTALLER_VERSION = 1.0
JUHUTUBE_INSTALLER_LICENSE = BSD-3c
JUHUTUBE_INSTALLER_SITE_METHOD = local
JUHUTUBE_INSTALLER_SITE = package/juhutube-installer/

define JUHUTUBE_INSTALLER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/juhutube-installer.sh $(TARGET_DIR)/usr/bin/juhutube-installer.sh
	mkdir -p $(TARGET_DIR)/usr/share/kloader
	$(INSTALL) -D -m 0755 $(@D)/icon.sys $(TARGET_DIR)/usr/share/kloader/icon.sys
	$(INSTALL) -D -m 0755 $(@D)/kloader.icn $(TARGET_DIR)/usr/share/kloader/kloader.icn
endef
define JUHUTUBE_INSTALLER_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 755 package/juhutube-installer/S95juhutubeinstaller \
		$(TARGET_DIR)/etc/init.d/S95juhutubeinstaller
endef

$(eval $(generic-package))
