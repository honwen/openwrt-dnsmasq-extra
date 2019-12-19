include $(TOPDIR)/rules.mk

PKG_NAME:=smartdns
PKG_VERSION:=2019-12-15
PKG_RELEASE:=Release28

PKG_SOURCE_URL:=https://github.com/pymumu/smartdns/archive/
PKG_SOURCE:=$(PKG_RELEASE).tar.gz
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_RELEASE)

include $(INCLUDE_DIR)/package.mk
MAKE_ARGS := CFLAGS="$(TARGET_CFLAGS)" CC=$(TARGET_CC)

define Package/smartdns
	SECTION:=net
	CATEGORY:=Network
	TITLE:=A local DNS server to obtain the fastest access results
	URL:=http://github.com/pymumu/smartdns/
	MAINTAINER:=honwen <https://github.com/honwen>
	DEPENDS:=+libopenssl
endef

define Package/smartdns/description
SmartDNS accepts DNS query requests from local clients,
obtains DNS query results from multiple upstream DNS servers,
and returns the fastest access results to clients.
endef

define Build/Configure
	mkdir -p $(PKG_INSTALL_DIR)
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/src $(MAKE_ARGS) all
endef

define Package/smartdns/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/smartdns $(1)/usr/bin/smartdns
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/smartdns.init $(1)/etc/init.d/smartdns
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/smartdns.config $(1)/etc/config/smartdns
endef

$(eval $(call BuildPackage,smartdns))
