# Usage
 - 从 OpenWrt 的 [SDK][S] 编译

   ```bash
   # 以 ar71xx 平台为例
   tar xjf OpenWrt-SDK-ar71xx-for-linux-x86_64-gcc-4.8-linaro_uClibc-0.9.33.2.tar.bz2
   cd OpenWrt-SDK-ar71xx-*
   # 添加 feeds
   git clone https://github.com/shadowsocks/openwrt-feeds.git package/feeds
   # 获取 Makefile
   git clone https://github.com/chenhw2/openwrt-dnsmasq-extra.git package/feeds/openwrt-dnsmasq-extra
   # 选择要编译的包 Network -> [dnscrypt, chinadns, dnsmasq-extra]
   make menuconfig
   # 开始编译
   make package/feeds/openwrt-dnsmasq-extra/cdns/compile V=99
   make package/feeds/openwrt-dnsmasq-extra/dns-forwarder/compile V=99
   make package/feeds/openwrt-dnsmasq-extra/chinadns/compile V=99
   make package/feeds/openwrt-dnsmasq-extra/dnscrypt/compile V=99
   make package/feeds/openwrt-dnsmasq-extra/dnsmasq-extra/compile V=99
   ```

# Recommend

- dnsmasq-extra + dnscrypt

- dnsmasq-extra + chinadns (+cdns +dns-forwarder)

# Provider

### dnscrypt@7400 with multidns/tls

### chinadns@7300 with multidns/udp

Upstream DNS for ChinaDNS:
- ```cdns@730X with multidns/udp```
- ```dns-forwarder@730X with multidns/tcp```


### dnsmasq-extra

 - dnsmasq for adblock
 - dnsmasq/ipset for koolproxy
 - dnsmasq/ipset for dnscrypt/chinadns/ss(r)-tunnel

  [S]: https://wiki.openwrt.org/doc/howto/obtain.firmware.sdk
