# Usage
```bash
git clone https://github.com/chenhw2/openwrt-dnsmasq-extra.git package/feeds/openwrt-dnsmasq-extra
```
----
# Recommend
 - dnsmasq-extra + dnscrypt
 - dnsmasq-extra + chinadns (+cdns +dns-forwarder)
----
## dnscrypt@7400 with multidns/tls
----
## chinadns@7300 with multidns/udp
 - Upstream DNS for ChinaDNS
   - ```cdns@730X with multidns/udp```
   - ```dns-forwarder@730X with multidns/tcp```
----
## dnsmasq-extra
 - dnsmasq for adblock
 - dnsmasq/ipset for koolproxy
 - dnsmasq/ipset for dnscrypt/chinadns/ss(r)-tunnel
