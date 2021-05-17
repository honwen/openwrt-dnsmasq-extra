#!/bin/bash

curl -sSL https://ispip.clang.cn/all_cn_cidr.txt -o chnroute.txt
md5sum chnroute.txt | tee chnroute.txt.md5sum

# https://github.com/honwen/shadowsocks-helper
shadowsocks-helper gfwlist > gfwlist

curl -sSL https://anti-ad.net/domains.txt -o adblock
shadowsocks-helper tide -i adblock -o adblock

srcs="tldn gfwlist direct adblock"

for it in $srcs; do
    sed '/^[ \t]*$/d' -i $it
    gzip -n9fk $it
    md5sum $it | tee $it.md5sum
    md5sum $it.gz | tee $it.gz.md5sum
done
