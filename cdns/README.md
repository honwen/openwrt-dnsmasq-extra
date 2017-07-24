CDNS for OpenWrt/LEDE
===
forked from [openwrt-gmod][gmod-cdns]

简介
---

本软件包是 [CDNS][cdns] 在OpenWrt/LEDE上的移植，用于快速获得无污染DNS，可与[luci-app-cdns][gmod-luci]配合使用

特性
---

1、UDP协议请求DNS，可使用53端口，使用国外DNS服务器可有效避免污染  
2、速度快于非53端口的TCP DNS  
3、CDNS自身不带缓存，推荐作为dnsmasq的上游DNS使用  


编译
---

 - 从 OpenWrt 的 [SDK][SDK] 编译

   ```bash
   # 以 ar71xx 平台为例
   tar xjf OpenWrt-SDK-ar71xx-for-linux-x86_64-gcc-4.8-linaro_uClibc-0.9.33.2.tar.bz2
   cd OpenWrt-SDK-ar71xx-*
   # 获取 cdns Makefile
   git clone https://github.com/chenhw2/openwrt-dnsmasq-extra.git package/openwrt-dnsmasq-extra
   # 选择要编译的包 Network -> cdns
   make menuconfig
   # 开始编译
   make package/cdns/compile V=99
   ```

[gmod-cdns]: https://github.com/ghostry/openwrt-gmod/tree/master/package/cdns
[gmod-luci]: https://github.com/ghostry/openwrt-gmod/tree/master/luci/luci-app-cdns
[cdns]: https://github.com/semigodking/cdns
[SDK]: https://wiki.openwrt.org/doc/howto/obtain.firmware.sdk
