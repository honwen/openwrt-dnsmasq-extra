#
# Copyright (C) 2018-2025 honwen <https://github.com/honwen>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=dnsmasq-extra
PKG_VERSION:=2025-07-28
PKG_RELEASE:=2.0.0

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

PKG_CONFIG_DEPENDS:= CONFIG_DNSMASQ_EXTRA_FORCE_SMARTDNS

include $(INCLUDE_DIR)/package.mk

define Package/dnsmasq-extra
	SECTION:=net
	CATEGORY:=Network
	TITLE:=Dnsmasq-Extra
	DEPENDS:=+curl +dnsFtcp
	PKGARCH:=all
endef

define Package/dnsmasq-extra/config
menu "DNSMASQ-Extra Configuration"
	depends on PACKAGE_dnsmasq-extra && ( PACKAGE_smartdns || PACKAGE_dnsproxy || PACKAGE_dcompass || PACKAGE_aiodns)
	config DNSMASQ_EXTRA_LITE
		bool "lite data: gfwlist/adblock."
		default y
	config DNSMASQ_EXTRA_FORCE_AIODNS
		depends on PACKAGE_aiodns
		bool "force all to aiodns."
		default n
	config DNSMASQ_EXTRA_FORCE_SMARTDNS
		depends on PACKAGE_smartdns
		bool "force all to smartdns."
		default n
	config DNSMASQ_EXTRA_FORCE_DNSPROXY
		depends on PACKAGE_dnsproxy
		bool "force all to dnsproxy."
		default n
	config DNSMASQ_EXTRA_FORCE_DCOMPASS
		depends on PACKAGE_dcompass
		bool "force all to dcompass."
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
uci -q delete firewall.extra
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
	$(INSTALL_DATA) ./files/dnsmasq-extra.conf $(1)/etc/config/dnsmasq-extra
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/dnsmasq-extra.init $(1)/etc/init.d/dnsmasq-extra
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/uci-defaults $(1)/etc/uci-defaults/dnsmasq-extra
	$(INSTALL_DIR) $(1)/etc/dnsmasq-extra.d
	$(INSTALL_DATA) ./files/data/*.gz $(1)/etc/dnsmasq-extra.d/
	$(INSTALL_DATA) ./files/data/*.txt $(1)/etc/dnsmasq-extra.d/
	$(INSTALL_DATA) ./files/data/*.conf $(1)/etc/dnsmasq-extra.d/

ifeq ($(CONFIG_DNSMASQ_EXTRA_LITE),y)
	ln -sf gfwlist.lite.gz $(1)/etc/dnsmasq-extra.d/gfwlist.gz
	ln -sf adblock.lite.gz $(1)/etc/dnsmasq-extra.d/adblock.gz
else
	rm -f $(1)/etc/dnsmasq-extra.d/*.lite.gz
endif

ifeq ($(CONFIG_DNSMASQ_EXTRA_FORCE_AIODNS),y)
	sed 's+\(overwrite_resolve.*\)[0-9]+\1enabled+g' -i $(1)/etc/config/dnsmasq-extra
	sed 's+\(overwrite_aiodns.*\)[0-9]+\1enabled+g' -i $(1)/etc/config/dnsmasq-extra
endif
ifeq ($(CONFIG_DNSMASQ_EXTRA_FORCE_SMARTDNS),y)
	sed 's+\(overwrite_resolve.*\)[0-9]+\1enabled+g' -i $(1)/etc/config/dnsmasq-extra
	sed 's+\(overwrite_smartdns.*\)[0-9]+\1enabled+g' -i $(1)/etc/config/dnsmasq-extra
endif
ifeq ($(CONFIG_DNSMASQ_EXTRA_FORCE_DNSPROXY),y)
	sed 's+\(overwrite_resolve.*\)[0-9]+\1enabled+g' -i $(1)/etc/config/dnsmasq-extra
	sed 's+\(overwrite_dnsproxy.*\)[0-9]+\1enabled+g' -i $(1)/etc/config/dnsmasq-extra
endif
ifeq ($(CONFIG_DNSMASQ_EXTRA_FORCE_DCOMPASS),y)
	sed 's+\(overwrite_resolve.*\)[0-9]+\1enabled+g' -i $(1)/etc/config/dnsmasq-extra
	sed 's+\(overwrite_dcompass.*\)[0-9]+\1enabled+g' -i $(1)/etc/config/dnsmasq-extra
endif
endef

$(eval $(call BuildPackage,dnsmasq-extra))
