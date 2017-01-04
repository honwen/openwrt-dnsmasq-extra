#
# Copyright (C) 2016 chenhw2
#

include $(TOPDIR)/rules.mk

PKG_NAME:=dnsmasq-extra
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/dnsmasq-extra
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=Web Servers/Proxies
	TITLE:=Dnsmasq-Extra
	PKGARCH:=all
endef

define Package/dnsmasq-extra/description
	Dnsmasq-Extra include pdnsd / adblock
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/dnsmasq-extra/postinst
endef

define Package/dnsmasq-extra/conffiles
endef

define Package/dnsmasq-extra/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/dnsmasq-extra.init $(1)/etc/init.d/dnsmasq-extra
	$(INSTALL_DIR) $(1)/etc/ipset
	$(INSTALL_DATA) ./files/{pdnsd,adblock} $(1)/etc/ipset/
endef

$(eval $(call BuildPackage,dnsmasq-extra))
