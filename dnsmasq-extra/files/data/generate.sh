#!/bin/bash

# set -ex
# Tools:
# https://github.com/honwen/shadowsocks-helper
# https://github.com/zhanhb/cidr-merger

# ------------------ chnroute ------------------
time cidr-merger <<-EOF >chnroute.txt
	$(curl -sSL https://ispip.clang.cn/all_cn_cidr.txt)
	$(curl -sSL https://cdn.staticaly.com/gh/pexcn/daily/gh-pages/chnroute/chnroute.txt)
	$(curl -sSL https://raw.githubusercontents.com/pexcn/daily/gh-pages/chnroute/chnroute.txt)
	$(curl -sSL https://cdn.staticaly.com/gh/17mon/china_ip_list/master/china_ip_list.txt)
	$(curl -sSL https://raw.githubusercontents.com/17mon/china_ip_list/master/china_ip_list.txt)
	$(shadowsocks-helper asn)
EOF
sed '/^[ \t\s]*$/d' -i chnroute.txt
# ------------------ chnroute ------------------

# ------------------ gfwlist ------------------
time shadowsocks-helper gfwlist >gfwlist
sed '/google.*analytics.com/d' -i gfwlist
# ------------------ gfwlist ------------------

# ------------------ adblock ------------------
curl -sSL https://anti-ad.net/domains.txt -o adblock
time shadowsocks-helper tide -i adblock -o adblock

# whitelist
sed '/ip-api.com/d; /pv.sohu.com/d' -i adblock
sed '/click.union.vip.com/d; /ms.vipstatic.com/d' -i adblock
# ------------------ adblock ------------------

# ------------------ direct ------------------
curl -sSL https://raw.githubusercontents.com/pexcn/daily/gh-pages/chinalist/chinalist.txt -o direct.pexcn
# curl -sSL https://s3.amazonaws.com/alexa-static/top-1m.csv.zip | gunzip |
# 	sed '800000,9999999d' | awk -F ',' '{print $2}' >direct.alexa
# $(grep -Fx -f direct.pexcn direct.alexa)

start=$(($(sed -n -e '/^whatismyip.akamai.com$/=' direct) + 1))
cat <<-EOF | sort -u >direct.new
	$(sed -n "$start,99999p" direct)
	$(sed '/^www.apple.com$/,+99999d' direct.pexcn)
EOF

# blacklist
sed '/google/d; /gstatic/d; /youtube/d; /^android/d;' -i direct.new
sed '/ocsp/d; /akamai/d; /aws/d' -i direct.new
sed '/sci-hub/d; /scihub/d; /gitbook/d' -i direct.new
sed '/ebay/d; /lazada/d; /yandex/d' -i direct.new
cat adblock gfwlist >direct.blacklist
sed "$start,99999d" direct >>direct.blacklist
grep -Fxv -f direct.blacklist direct.new >direct.sum

time shadowsocks-helper tide -i direct.sum -o direct.sum
sed "$start,99999d" -i direct
cat direct.sum >>direct
rm -f direct.*
# ------------------ direct ------------------

# ------------------ gzip ------------------
md5sum chnroute.txt | tee chnroute.txt.md5sum

srcs="tldn gfwlist direct adblock"

for it in $srcs; do
	echo >>$it
	sed '/^[ \t\s]*$/d' -i $it
	gzip -n9fk $it
	md5sum $it | tee $it.md5sum
	md5sum $it.gz | tee $it.gz.md5sum
done
# ------------------ gzip ------------------
