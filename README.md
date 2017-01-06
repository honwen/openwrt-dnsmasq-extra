## pdnsd@1053    with multidns@443/tcp
## chinadns@5353 with multidns/udp

## dnsmasq for adblock
## dnsmasq for pdnsd/chinadns/ss-tunnel

Add this line to your feeds.conf.default.

`src-git openwrtpdnsd https://github.com/chenhw2/openwrt-pdnsd.git`

And run:

`./scripts/feeds update -a && ./scripts/feeds install -a`
