## pdnsd@1053 with multidns@443/tcp

Add this line to your feeds.conf.default.

`src-git openwrtpdnsd https://github.com/chenhw2/openwrt-pdnsd.git`

And run:


`./scripts/feeds update -a && ./scripts/feeds install -a`
