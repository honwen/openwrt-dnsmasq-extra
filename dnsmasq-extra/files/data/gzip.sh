#!/bin/bash

curl -sSL https://ispip.clang.cn/all_cn_cidr.txt -o chnroute.txt
md5sum chnroute.txt | tee chnroute.txt.md5sum

# https://github.com/honwen/shadowsocks-helper
shadowsocks-helper gfwlist >gfwlist

curl -sSL https://anti-ad.net/domains.txt -o adblock
shadowsocks-helper tide -i adblock -o adblock

# whitelist
sed '/ip-api.com/d; /pv.sohu.com/d' -i adblock
sed '/click.union.vip.com/d; /ms.vipstatic.com/d' -i adblock

srcs="tldn gfwlist direct adblock"

for it in $srcs; do
    sed '/^[ \t]*$/d' -i $it
    gzip -n9fk $it
    md5sum $it | tee $it.md5sum
    md5sum $it.gz | tee $it.gz.md5sum
done
