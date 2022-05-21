# Usage

- 从 OpenWrt 的 [SDK][s] 编译

  ```bash
  # 以 ar71xx 平台为例
  tar xjf OpenWrt-SDK-ar71xx-for-linux-x86_64-gcc-4.8-linaro_uClibc-0.9.33.2.tar.bz2
  cd OpenWrt-SDK-ar71xx-*
  # 添加 feeds
  git clone https://github.com/shadowsocks/openwrt-feeds.git package/feeds
  # 获取 Makefile
  git clone https://github.com/chenhw2/openwrt-dnsmasq-extra.git package/feeds/openwrt-dnsmasq-extra
  # 选择要编译的包 Network -> [aiodns, smartdns, dnsproxy, dcompass, dnsmasq-extra]
  make menuconfig
  # 开始编译
  make package/feeds/openwrt-dnsmasq-extra/aiodns/compile V=99
  make package/feeds/openwrt-dnsmasq-extra/dnsproxy/compile V=99
  make package/feeds/openwrt-dnsmasq-extra/dcompass/compile V=99
  make package/feeds/openwrt-dnsmasq-extra/smartdns/compile V=99
  make package/feeds/openwrt-dnsmasq-extra/dnsmasq-extra/compile V=99
  ```

# Recommend

- dnsmasq-extra + aiodns **_(recommended)_**

- dnsmasq-extra + smartdns **_(recommended)_**

- dnsmasq-extra + dcompass _(experimental)_

- dnsmasq-extra + dnsproxy

- dnsmasq-extra + ss(r)-tunnel (+dnsFtcp)

# Clean DNS Upstream

- aiodns@7100 with multidns/DoT/DoH/DNSCrypt

- dnsproxy@7200 with multidns/DoT/DoH/DNSCrypt

- dcompass@7500 with multidns/DoT/DoH

- smartdns@7700 with multidns/DoT/DoH

- dnsmasq-extra
  - dnsmasq for adblock/bogus
  - dnsmasq/ipset for aiodns/dnsproxy/smartdns/dcompass/ss(r)-tunnel

[s]: https://wiki.openwrt.org/doc/howto/obtain.firmware.sdk
