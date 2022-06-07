
include $(TOPDIR)/rules.mk

PKG_NAME:=dcompass
PKG_VERSION:=20220316
PKG_RELEASE:=1022
PKG_MAINTAINER:=honwen <https://github.com/honwen>

# OpenWrt ARCH: arm, aarch64, i386, x86_64, mips, mipsel
# Rust ARCH: armv7, aarch64, i686, x86_64, mips, mipsle
PKG_ARCH:=$(ARCH)-unknown-linux-musl
ifeq ($(ARCH),mipsel)
	PKG_ARCH:=mipsle-unknown-linux-musl
endif
ifeq ($(ARCH),i386)
	PKG_ARCH:=i686-unknown-linux-musl
endif
ifeq ($(ARCH),arm)
	PKG_ARCH:=armv7-unknown-linux-musleabihf
endif
ifeq ($(ARCH),aarch64)
	PKG_ARCH:=aarch64-unknown-linux-musleabihf
endif

PKG_SOURCE:=dcompass-$(PKG_ARCH)
PKG_SOURCE_URL:=https://github.com/compassd/dcompass/releases/download/build-$(PKG_VERSION)_$(PKG_RELEASE)/
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_ARCH)-$(PKG_VERSION)_$(PKG_RELEASE)
PKG_HASH:=skip

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=net
	CATEGORY:=Network
	TITLE:=A high-performance, routing-scheme-support DNS server
	URL:=https://github.com/compassd/dcompass
	DEPENDS:=+ca-bundle
endef

define Package/$(PKG_NAME)/description
	A high-performance DNS server with freestyle routing scheme support, DoT/DoH functionalities built-in..
endef

define Build/Prepare
	rm -rf $(PKG_BUILD_DIR)/dcompass
	mv -f "$(DL_DIR)/$(PKG_SOURCE)" $(PKG_BUILD_DIR)/dcompass
	chmod a+x $(PKG_BUILD_DIR)/dcompass
endef

define Build/Compile
	echo "$(PKG_NAME) Compile Skiped!"
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/dcompass.conf $(1)/etc/config/dcompass
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/dcompass.init $(1)/etc/init.d/dcompass
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/dcompass $(1)/usr/bin/dcompass
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
