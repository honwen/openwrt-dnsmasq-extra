include $(TOPDIR)/rules.mk

PKG_NAME:=adguard-home
PKG_VERSION:=2020-11-20
PKG_RELEASE:=0.104.3
PKG_MAINTAINER:=honwen <https://github.com/honwen>

# OpenWrt ARCH: arm, aarch64, i386, x86_64, mips, mipsel
# Golang ARCH: arm[5-7], arm64, 386, amd64, mips, mipsle
PKG_ARCH:=$(ARCH)
ifeq ($(ARCH),mipsel)
	PKG_ARCH:=mipsle
endif
ifeq ($(ARCH),i386)
	PKG_ARCH:=386
endif
ifeq ($(ARCH),x86_64)
	PKG_ARCH:=amd64
endif
ifeq ($(ARCH),aarch64)
	PKG_ARCH:=arm64
endif

PKG_SOURCE:=AdGuardHome_linux_$(PKG_ARCH).tar.gz
PKG_SOURCE_URL:=https://github.com/AdguardTeam/AdGuardHome/releases/download/v$(PKG_RELEASE)/
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_RELEASE)
PKG_HASH:=skip

include $(INCLUDE_DIR)/package.mk

define Package/adguard-home
	SECTION:=net
	CATEGORY:=Network
	TITLE:=Powerful ads and trackers blocking DNS server.
	URL:=https://github.com/AdguardTeam/AdGuardHome
	DEPENDS:=+ca-bundle
endef

define Package/adguard-home/description
	Privacy protection center for you and your devices
	Free and open source, powerful network-wide ads & trackers blocking DNS server.
endef

define Build/Prepare
	gzip -dc "$(DL_DIR)/$(PKG_SOURCE)" | tar -C $(PKG_BUILD_DIR)/ -xf -
	mv "$(DL_DIR)/$(PKG_SOURCE)" "$(DL_DIR)/$(PKG_RELEASE)_$(PKG_SOURCE)"
endef

define Build/Compile
	echo "$(PKG_NAME) Compile Skiped!"
endef

define Package/adguard-home/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/adguard-home.conf $(1)/etc/config/adguard-home
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/adguard-home.init $(1)/etc/init.d/adguard-home
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/AdGuardHome/AdGuardHome $(1)/usr/bin/adguard-home
endef

$(eval $(call BuildPackage,adguard-home))
