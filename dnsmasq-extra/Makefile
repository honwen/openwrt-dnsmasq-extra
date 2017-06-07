#
# Copyright (C) 2016 chenhw2
#

include $(TOPDIR)/rules.mk

PKG_NAME:=dnsmasq-extra
PKG_VERSION:=0.2.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/dnsmasq-extra
	SECTION:=net
	CATEGORY:=Network
	TITLE:=Dnsmasq-Extra
	DEPENDS:=+dnsmasq-full
	PKGARCH:=all
endef

define Package/dnsmasq-extra/description
	Dnsmasq-Extra include gfwlist, adblock & tldn
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/dnsmasq-extra/postrm
#!/bin/sh
sed -i '/dnsmasq-extra/d' /etc/crontabs/root
exit 0
endef

define Package/dnsmasq-extra/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" -a -f /etc/uci-defaults/cron-dnsmasq-extra ]; then
	( . /etc/uci-defaults/cron-dnsmasq-extra ) && \
	rm -f /etc/uci-defaults/cron-dnsmasq-extra
fi
exit 0
endef

define Package/dnsmasq-extra/conffiles
endef

define Package/dnsmasq-extra/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/dnsmasq-extra.init $(1)/etc/init.d/dnsmasq-extra
	$(INSTALL_DIR) $(1)/etc/dnsmasq-extra.d
	$(INSTALL_DATA) ./files/{gfwlist,tldn,adblock,custom.conf} $(1)/etc/dnsmasq-extra.d/
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/dnsmasq-extra.cron $(1)/etc/uci-defaults/cron-dnsmasq-extra
endef

$(eval $(call BuildPackage,dnsmasq-extra))
