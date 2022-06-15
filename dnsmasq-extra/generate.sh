#!/bin/bash

set -e
# Tools:
# https://github.com/honwen/shadowsocks-helper
# https://github.com/zhanhb/cidr-merger

_date=$(date '+%Y-%m-%d')
_path=$(dirname $(readlink -f $0))

curl_githubusercontent() {
	url="$1"
	curl -skL --speed-limit 100000 --speed-time 10 "https://ghproxy.com/${url}" ||
		curl -skL --speed-limit 100000 --speed-time 10 "https://ghproxy.com/${url}" ||
		curl -skL --speed-limit 100000 --speed-time 10 "$(echo ${url} | sed 's+raw.githubusercontent.com+cdn.staticaly.com/gh+g')" ||
		curl -skL --speed-limit 100000 --speed-time 10 "${url}"
}

sed "s+PKG_VERSION:=.*+PKG_VERSION:=${_date}+g" -i $_path/Makefile
echo "# Generated At ${_date}"

cd $_path/files/data
# -------------------- tldn --------------------
echo >&2 "# tldn"
curl_githubusercontent https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/tld-not-cn.txt |
	sed "s|.*+||g; s+'$++g" | grep -e '^\.' >>tldn
sort -u tldn -o tldn
# -------------------- tldn --------------------

# ------------------ chnroute ------------------
echo >&2 "# chnroute.txt"
time cidr-merger <<-EOF >chnroute.txt.new
	$(curl -skL --speed-limit 100000 --speed-time 10 https://ispip.clang.cn/all_cn_cidr.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com/metowolf/iplist/master/data/country/CN.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com/pexcn/daily/gh-pages/chnroute/chnroute.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com//QiuSimons/Chnroute/master/dist/chnroute/chnroute.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com/PaPerseller/chn-iplist/master/chnroute-ipv4.txt)

	$(
		curl_githubusercontent https://raw.githubusercontent.com/DivineEngine/Profiles/master/Surge/Ruleset/Extra/WeChat.list |
			sed -n 's+IP-CIDR,\(.*\),no-resolve+\1+p'
	)

	$(for it in 132203 45090 45102 136907 3462 9381 9269 135377 64050 136038 31898 48266; do
		echo >&2 "ASN$it"
		curl -skL --speed-limit 100000 --speed-time 30 https://api.bgpview.io/asn/$it/prefixes | jq -r '.data.ipv4_prefixes[]|.prefix'
	done)
EOF

# add checkip.synology.com
time cidr-merger <<-EOF >>chnroute.txt.new
	104.248.79.120
	159.89.129.146
	165.227.63.200
	138.68.28.244
	159.89.142.52
	206.189.214.49
	142.93.81.166
	159.65.77.153
EOF

# add wechat
time cidr-merger <<-EOF >>chnroute.txt.new
	109.244.0.0/16
	101.32.118.0/23
	101.32.104.0/21
EOF

echo >&2 "# chnroute.txt"

# min netmask >= /24
time cidr-merger <<-EOF >chnroute.txt
	$(cat chnroute.txt.new)
	$(sed 's+\.[^\.]*$+.0/24+g' chnroute.txt.new)
EOF

sed '/^[ \t\s]*$/d' -i chnroute.txt
rm -f chnroute.txt.*
# git checkout -- chnroute.txt
# ------------------ chnroute ------------------

# ------------------ gfwlist ------------------
echo >&2 "# gfwlist"
time shadowsocks-helper gfwlist >gfwlist
sed '/^google.*analytics.com$/d' -i gfwlist
# ------------------ gfwlist ------------------

# ------------------ adblock ------------------

curl -sSL https://anti-ad.net/domains.txt -o adblock
curl_githubusercontent https://raw.githubusercontent.com/neodevpro/neodevhost/master/customblocklist >>adblock
# curl -sSL https://neodev.team/lite_host -o adblock.neodevhost
# $(sed -n 's+^0.0.0.0 *++p' adblock.neodevhost)
cat <<-EOF >>adblock
	c.msn.com
	ntp.msn.com
	ntp.msn.cn
	assets.msn.cn
	api.msn.com
	browser.events.data.msn.com
EOF
# sort -u adblock -o adblock
echo >&2 "# adblock"
time shadowsocks-helper tide -i adblock -o adblock

# whitelist
sed '/wns.windows.com/d' -i adblock
sed '/ip-api.com/d; /pv.sohu.com/d' -i adblock
sed '/click.simba.taobao.com/d' -i adblock
sed '/click.union.vip.com/d; /ms.vipstatic.com/d' -i adblock
# rm -f adblock.*
# ------------------ adblock ------------------

# ------------------ direct ------------------
curl_githubusercontent https://raw.githubusercontent.com/pexcn/daily/gh-pages/chinalist/chinalist.txt >direct.pexcn

start=$(($(sed -n -e '/^whatismyip.akamai.com$/=' direct) + 1))
# $(sed -n "$start,99999p" direct)
cat <<-EOF | sort -u >direct.new
	$(sed '/^www.apple.com$/,+99999d' direct.pexcn)
EOF

curl_githubusercontent https://raw.githubusercontent.com/Loyalsoldier/surge-rules/release/apple.txt >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/v2fly/domain-list-community/master/data/tencent >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/v2fly/domain-list-community/master/data/alibaba >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/v2fly/domain-list-community/master/data/bytedance >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/pluwen/china-domain-allowlist/main/allow-list.sorl |
	sed -n 's+^*\.++p' | sed '/apple/d; /akadns/d; /doubleclick/d' >>direct.new

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
sed 's+$+\$+g; s+\.+\\.+g' tldn gfwlist >direct.suffix
echo "\.*apple\." >>direct.suffix
echo "\.*windows\." >>direct.suffix
echo "\.*microsoft\." >>direct.suffix
echo "\.*windowsupdate\." >>direct.suffix
echo >&2 "# direct"
time grep -eF -f direct.suffix direct.sum >>direct
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

# ----------- ShadowrocketEx.conf ----------

curl_githubusercontent https://raw.githubusercontent.com/xiangsanliu/Rules/main/merge-lhie1.conf >ADBLOCK.conf
curl_githubusercontent https://raw.githubusercontent.com/xiangsanliu/Rules/main/gen/gfw.conf >Complete.conf
sed 's+^dns-server.*+dns-server = system, tls://223.5.5.5, tls://120.53.53.53, https://1.12.12.12/dns-query+g' -i Complete.conf
sed 's+^bypass-tun *= *+bypass-tun = 119.29.0.0/16, 223.5.5.0/24, 223.6.6.0/24, 120.53.52.0/23, 1.12.0.0/20, 129.226.0.0/16, 101.32.0.0/16, 109.244.0.0/16, +g' -i Complete.conf
sed '/bypass-tun/adns-direct-fallback-proxy = true' -i Complete.conf
sed 's+bypass-tun+tun-excluded-routes+g' -i Complete.conf
sed '/^skip-proxy/{s+$+, captive.apple.com, netcts.cdn-apple.com, *.qq.com, *.gtimg.com, *.qpic.cn, *.qlogo.cn, *.wechat.com, *.weixin.com, *.iot-tencent.com, *.tencent-cloud.net, *.wechatos.net, *.servicewechat.com+g}' -i Complete.conf

insert_line=$(sed -n -e '/^# Proxy$/=' Complete.conf)

echo >&2 "# ShadowrocketEx"
echo "# Generated At ${_date}" >ShadowrocketEx.conf
sed -n "1,$((insert_line - 1))p" Complete.conf >>ShadowrocketEx.conf
echo -e '\n# > GFWLIST' >>ShadowrocketEx.conf
(
	sed -n '/DOMAIN-SUFFIX,.*,PROXY/p' Complete.conf
	sed '/[0-9]$/d' gfwlist | sed 's+^+DOMAIN-SUFFIX,+g; s+$+,PROXY+g'
) | sort -u >>ShadowrocketEx.conf

echo -e '\n# > DIRECT' >>ShadowrocketEx.conf
(
	sed -n "$start,999999p" direct | sed 's+^+DOMAIN-SUFFIX,+g; s+$+,DIRECT,no-resolve+g'
) | sort -u | sed '/^[ \t\s]*$/d' >>ShadowrocketEx.conf

echo -e '\n# > ADBLOCK' >>ShadowrocketEx.conf
(
	sed -n '/^DOMAIN-SUFFIX,.*,REJECT$/p' ADBLOCK.conf
) | sort -u | sed '/^[ \t\s]*$/d' >>ShadowrocketEx.conf

# echo -e '\n# > CHNROUTE' >>ShadowrocketEx.conf
# sed 's+^+IP-CIDR,+g; s+$+,DIRECT,no-resolve+g' chnroute.txt >>ShadowrocketEx.conf

# # > FINAL
# FINAL,PROXY

cat <<-EOF >>ShadowrocketEx.conf
	# > CN
	GEOIP,CN,DIRECT
	DOMAIN-SUFFIX,cn,DIRECT

	IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
	IP-CIDR,100.64.0.0/10,DIRECT,no-resolve
	IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
	IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
	IP-CIDR,192.168.0.0/16,DIRECT,no-resolve

	# > WeChat
	DOMAIN,dl.wechat.com,DIRECT
	DOMAIN,sglong.wechat.com,DIRECT
	DOMAIN,sgminorshort.wechat.com,DIRECT
	DOMAIN,sgshort.wechat.com,DIRECT
	DOMAIN,tencentmap.wechat.com,DIRECT
	IP-CIDR,101.32.104.4/32,DIRECT,no-resolve
	IP-CIDR,101.32.104.41/32,DIRECT,no-resolve
	IP-CIDR,101.32.104.56/32,DIRECT,no-resolve
	IP-CIDR,101.32.118.25/32,DIRECT,no-resolve
	IP-CIDR,101.32.133.16/32,DIRECT,no-resolve
	IP-CIDR,101.32.133.53/32,DIRECT,no-resolve
	IP-CIDR,101.32.133.209/32,DIRECT,no-resolve
	IP-CIDR,129.226.3.47/32,DIRECT,no-resolve
	IP-CIDR,129.226.107.244/32,DIRECT,no-resolve


	# > Apple API
	DOMAIN-SUFFIX,aaplimg.com,PROXY
	DOMAIN-SUFFIX,Proxy.co,PROXY
	DOMAIN-SUFFIX,Proxy.com,PROXY
	DOMAIN-SUFFIX,Proxy-cloudkit.com,PROXY
	DOMAIN-SUFFIX,appsto.re,PROXY
	DOMAIN-SUFFIX,cdn-apple.com,PROXY
	DOMAIN-SUFFIX,icloud.com,PROXY
	DOMAIN-SUFFIX,icloud-content.com,PROXY
	DOMAIN-SUFFIX,itunes.com,PROXY
	DOMAIN-SUFFIX,me.com,PROXY
	IP-CIDR,17.0.0.0/8,PROXY,no-resolve
	IP-CIDR,63.92.224.0/19,PROXY,no-resolve
	IP-CIDR,65.199.22.0/23,PROXY,no-resolve
	IP-CIDR,139.178.128.0/18,PROXY,no-resolve
	IP-CIDR,144.178.0.0/19,PROXY,no-resolve
	IP-CIDR,144.178.36.0/22,PROXY,no-resolve
	IP-CIDR,144.178.48.0/20,PROXY,no-resolve
	IP-CIDR,192.35.50.0/24,PROXY,no-resolve
	IP-CIDR,198.183.17.0/24,PROXY,no-resolve
	IP-CIDR,205.180.175.0/24,PROXY,no-resolve

	# > Apple News
	DOMAIN-SUFFIX,Proxy.news,PROXY

	# > Apple CDN
	DOMAIN,aod.itunes.apple.com,DIRECT
	DOMAIN,api.smoot.apple.cn,DIRECT
	DOMAIN,appldnld.apple.com,DIRECT
	DOMAIN,apptrailers.itunes.apple.com,DIRECT
	DOMAIN,gs-loc-cn.apple.com,DIRECT
	DOMAIN,iosapps.itunes.apple.com,DIRECT
	DOMAIN,music.apple.com,DIRECT
	DOMAIN,mvod.itunes.apple.com,DIRECT
	DOMAIN,osxapps.itunes.apple.com,DIRECT
	DOMAIN,supportdownload.apple.com,DIRECT
	DOMAIN,swcdn.apple.com,DIRECT
	DOMAIN,updates-http.cdn-apple.com,DIRECT
	DOMAIN-SUFFIX,ls.apple.com,DIRECT
	DOMAIN-SUFFIX,mzstatic.com,DIRECT

	[URL Rewrite]
	^http://(www.)?google.cn https://www.google.com 302
EOF

mv ShadowrocketEx.conf $_path/.shadowrocket/ex.conf
rm -f Complete.conf ADBLOCK.conf
# ----------- ShadowrocketEx.conf ----------

cd -
