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
  # 选择要编译的包 Network -> [adguard-home, smartdns, dnsproxy, dnsmasq-extra]
  make menuconfig
  # 开始编译
  make package/feeds/openwrt-dnsmasq-extra/adguard-home/compile V=99
  make package/feeds/openwrt-dnsmasq-extra/dnsproxy/compile V=99
  make package/feeds/openwrt-dnsmasq-extra/smartdns/compile V=99
  make package/feeds/openwrt-dnsmasq-extra/dnsmasq-extra/compile V=99
  ```

# Recommend

- dnsmasq-extra + smartdns

- dnsmasq-extra + dnsproxy

- dnsmasq-extra + adguard-home

- dnsmasq-extra + ss(r)-tunnel (+dnsFtcp)

# Clean DNS Upstream

- smartdns@7700 with multidns/DoT/DoH

- dnsproxy@7200 with multidns/DoT/DoH

- adguard-home@7600 with multidns/DoT/DoH and **_adguard_**

- dnsmasq-extra
  - dnsmasq for adblock
  - dnsmasq/ipset for adguard-home/smartdns/dnsproxy/ss(r)-tunnel

[s]: https://wiki.openwrt.org/doc/howto/obtain.firmware.sdk
