
include $(TOPDIR)/rules.mk

PKG_NAME:=dnscrypt
PKG_VERSION:=2019-04-01
PKG_RELEASE:=2.0.22
PKG_MAINTAINER:=chenhw2 <https://github.com/chenhw2>

PKG_ARCH:=$(subst mipsel,mipsle,$(ARCH))
PKG_SOURCE:=dnscrypt-proxy-linux_$(PKG_ARCH)-$(PKG_RELEASE).tar.gz
PKG_SOURCE_URL:=https://github.com/jedisct1/dnscrypt-proxy/releases/download/$(PKG_RELEASE)/
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_RELEASE)
PKG_HASH:=skip

include $(INCLUDE_DIR)/package.mk

define Package/dnscrypt
	SECTION:=net
	CATEGORY:=Network
	TITLE:=A flexible DNS proxy
	URL:=https://github.com/jedisct1/dnscrypt-proxy
	DEPENDS:=+ca-bundle
endef

define Package/dnscrypt/description
	A flexible DNS proxy, with support for modern encrypted DNS protocols such as DNSCrypt v2 and DNS-over-HTTPS.
endef

define Build/Prepare
	gzip -dc "$(DL_DIR)/$(PKG_SOURCE)" | tar -C $(PKG_BUILD_DIR)/ -xf -
endef

define Build/Compile
	echo "$(PKG_NAME)Compile Skiped!"
endef

define Package/dnscrypt/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/dnscrypt.conf $(1)/etc/config/dnscrypt
	$(INSTALL_DIR) $(1)/etc/dnscrypt.d
	$(INSTALL_BIN) ./files/dnscrypt.d/* $(1)/etc/dnscrypt.d/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/dnscrypt.init $(1)/etc/init.d/dnscrypt
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/linux-$(PKG_ARCH)/dnscrypt-proxy $(1)/usr/bin/dnscrypt
endef

$(eval $(call BuildPackage,dnscrypt))
