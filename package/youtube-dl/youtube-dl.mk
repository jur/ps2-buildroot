################################################################################
#
# youtube-dl
#
################################################################################

YOUTUBE_DL_VERSION = 2014.08.10
YOUTUBE_DL_SOURCE = youtube-dl
YOUTUBE_DL_SITE = http://yt-dl.org/downloads/$(YOUTUBE_DL_VERSION)
YOUTUBE_DL_LICENSE = BSD-3c
YOUTUBE_DL_LICENSE_FILES = LICENSE

define YOUTUBE_DL_EXTRACT_CMDS
	mkdir -p $(@D)
	cp $(DL_DIR)/$(YOUTUBE_DL_SOURCE) $(@D)/youtube-dl
endef

YOUTUBE_DL_INSTALL_STAGING_CMDS = 

define YOUTUBE_DL_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/youtube-dl $(TARGET_DIR)/usr/bin/youtube-dl
endef

$(eval $(generic-package))
