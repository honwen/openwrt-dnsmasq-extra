include $(TOPDIR)/rules.mk

PKG_NAME:=smartdns
PKG_VERSION:=2023-09-04
PKG_RELEASE:=Release43.1

PKG_SOURCE_PROTO:=git
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE).tar.gz
PKG_SOURCE_URL:=https://github.com/pymumu/smartdns.git
PKG_SOURCE_VERSION:=8befd9d5d2a84785cbf6296b02aae89a65311a91
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)/$(BUILD_VARIANT)/$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE)
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk
MAKE_VARS += VER=$(PKG_RELEASE)\@$(PKG_VERSION)
MAKE_PATH:=src

define Package/smartdns
	SECTION:=net
	CATEGORY:=Network
	TITLE:=A local DNS server to obtain the fastest access results
	URL:=http://github.com/pymumu/smartdns/
	MAINTAINER:=honwen <https://github.com/honwen>
	DEPENDS:=+ca-bundle +libpthread +libopenssl
endef

define Package/smartdns/description
SmartDNS accepts DNS query requests from local clients,
obtains DNS query results from multiple upstream DNS servers,
and returns the fastest access results to clients.
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
