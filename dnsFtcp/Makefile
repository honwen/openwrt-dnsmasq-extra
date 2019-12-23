include $(TOPDIR)/rules.mk

PKG_NAME:=dnsFtcp
PKG_VERSION:=2017-07-21
PKG_RELEASE:=289e8c9c7167200668dff83b1e0cbce258665387

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/aa65535/hev-dns-forwarder.git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE)
PKG_SOURCE_VERSION:=$(PKG_RELEASE)
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)/$(PKG_SOURCE_SUBDIR)
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/dnsFtcp
	SECTION:=net
	CATEGORY:=Network
	TITLE:=Forwarding DNS queries on TCP transport
	URL:=https://github.com/aa65535/hev-dns-forwarder
endef

define Package/dnsFtcp/description
Forwarding DNS queries on TCP transport.
endef

define Package/dnsFtcp/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/hev-dns-forwarder $(1)/usr/bin/dnsFtcp
endef

$(eval $(call BuildPackage,dnsFtcp))
