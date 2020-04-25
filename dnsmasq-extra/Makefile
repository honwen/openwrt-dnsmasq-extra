#
# Copyright (C) 2018-2020 honwen <https://github.com/honwen>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=dnsmasq-extra
PKG_VERSION:=2020-04-26
PKG_RELEASE:=1.6.0

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

PKG_CONFIG_DEPENDS:= CONFIG_DNSMASQ_EXTRA_FORCE_SMARTDNS

include $(INCLUDE_DIR)/package.mk

define Package/dnsmasq-extra
	SECTION:=net
	CATEGORY:=Network
	TITLE:=Dnsmasq-Extra
	DEPENDS:=+dnsmasq-full +ipset +curl +dnsFtcp
	PKGARCH:=all
endef

define Package/dnsmasq-extra/config
menu "DNSMASQ-Extra Configuration"
	depends on PACKAGE_dnsmasq-extra && PACKAGE_smartdns
	config DNSMASQ_EXTRA_FORCE_SMARTDNS
		bool "force all to smartdns."
		default n
endmenu
endef

define Package/dnsmasq-extra/description
	Dnsmasq-Extra include gfwlist, adblock & tldn
endef

define Build/Compile
endef

define Package/dnsmasq-extra/postrm
#!/bin/sh
sed -i '/dnsmasq-extra/d' /etc/crontabs/root
uci -q delete firewall.dnsmasqextra
uci commit firewall
exit 0
endef

define Package/dnsmasq-extra/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" -a -f /etc/uci-defaults/dnsmasq-extra ]; then
	( . /etc/uci-defaults/dnsmasq-extra) && \
	rm -f /etc/uci-defaults/dnsmasq-extra
fi
exit 0
endef

define Package/dnsmasq-extra/conffiles
	/etc/dnsmasq-extra.d/custom.conf
	/etc/dnsmasq-extra.d/chnroute.txt
endef

define Package/dnsmasq-extra/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/config $(1)/etc/config/dnsmasq-extra
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/sh/init $(1)/etc/init.d/dnsmasq-extra
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/sh/uci-defaults $(1)/etc/uci-defaults/dnsmasq-extra
	$(INSTALL_DIR) $(1)/etc/dnsmasq-extra.d
	$(INSTALL_DATA) ./files/data/{gfwlist,tldn,direct,adblock,custom.conf,bogus.conf,chnroute.txt} $(1)/etc/dnsmasq-extra.d/
ifeq ($(CONFIG_DNSMASQ_EXTRA_FORCE_SMARTDNS),y)
	sed 's+\(overwrite_resolve.*\)[0-9]+\11+g' -i $(1)/etc/config/dnsmasq-extra
endif
endef

$(eval $(call BuildPackage,dnsmasq-extra))
