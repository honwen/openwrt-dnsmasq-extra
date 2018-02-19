include $(TOPDIR)/rules.mk

PKG_NAME:=http-dns
PKG_VERSION:=2018-02-14
PKG_RELEASE:=36ea2e3097113e4984a41d6c219d6b172c7fb2b8

PKG_SOURCE_PROTO:=git
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE).tar.bz2
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=https://github.com/chenhw2/dnspod-http-dns-libev.git
PKG_SOURCE_VERSION:=$(PKG_RELEASE)

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)/$(BUILD_VARIANT)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/http-dns
  SECTION:=net
  CATEGORY:=Network
  TITLE:=DNS over HTTP of DNSPOD
  DEPENDS:=+libcares +libcurl +libev
endef

define Package/http-dns/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/etc/init.d $(1)/etc/config
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/http-dns $(1)/usr/bin/
	$(INSTALL_BIN) ./files/httpdns.init $(1)/etc/init.d/httpdns
	$(INSTALL_CONF) ./files/httpdns.config $(1)/etc/config/httpdns
endef

$(eval $(call BuildPackage,http-dns))
