#!/bin/bash

set -e
# Tools:
# https://github.com/honwen/shadowsocks-helper
# https://github.com/zhanhb/cidr-merger

# _date=$(date '+%Y%m%d')
_date=$(date '+%Y-%m-%d')
_path=$(dirname $(readlink -f $0))

curl_githubusercontent() {
	url="$(echo $1 | sed 's+^https*://++g')"
	curl -skSL --speed-limit 100000 --speed-time 10 "https://${url}" ||
		curl -skSL --speed-limit 100000 --speed-time 10 "https://ghproxy.com/https://${url}" ||
		curl -skSL --speed-limit 100000 --speed-time 10 "https://ghproxy.net/https://${url}" ||
		curl -skSL --speed-limit 100000 --speed-time 10 "https://ghproxy.cc/https://${url}" ||
		curl -skSL --speed-limit 100000 --speed-time 10 "https://cf.ghproxy.cc/https://${url}" ||
		curl -skSL --speed-limit 100000 --speed-time 10 "https://ghproxy.cn/https://${url}" ||
		curl -skSL --speed-limit 100000 --speed-time 10 "https://ghgo.xyz/https://${url}" ||
		curl -skSL --speed-limit 100000 --speed-time 10 "$(echo https://${url} | sed 's+raw.githubusercontent.com+cdn.staticaly.com/gh+g')" ||
		curl -skSL --speed-limit 100000 --speed-time 10 "$(echo https://${url} | sed 's+raw.githubusercontent.com+jsd.proxy.aks.moe/gh+g')"
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
	$(curl -skSL --speed-limit 100000 --speed-time 10 https://ispip.clang.cn/all_cn_cidr.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com/metowolf/iplist/master/data/country/CN.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com/pexcn/daily/gh-pages/chnroute/chnroute.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com//QiuSimons/Chnroute/master/dist/chnroute/chnroute.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com/PaPerseller/chn-iplist/master/chnroute-ipv4.txt)

	$(curl_githubusercontent https://raw.githubusercontent.com/soffchen/GeoIP2-CN/release/CN-ip-cidr.txt)

	$(
		curl_githubusercontent https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/ChinaCompanyIp.list |
			sed -n 's+IP-CIDR,\(.*\),no-resolve+\1+p'
	)

	$(
		curl_githubusercontent https://raw.githubusercontent.com/DivineEngine/Profiles/master/Surge/Ruleset/Extra/WeChat.list |
			sed -n 's+IP-CIDR,\(.*\),no-resolve+\1+p'
	)

	$(
		curl_githubusercontent https://raw.githubusercontent.com/marsgogo/Surge/main/Weixin.list |
			sed -n 's+IP-CIDR,\(.*\),no-resolve+\1+p'
	)

	141.98.197.0/24
	154.21.192.0/20

	$(for it in 3462 9269 9381 25820 31898 35916 36352 45090 45102 48266 49683 64050 132203 132591 135377 136038 136907 138915 141159; do
		echo >&2 "ASN$it"

		curl_githubusercontent https://raw.githubusercontent.com/cbuijs/ipasn/refs/heads/master/asn/as$it.list | grep -vE '^#' | grep -v ':'

		# curl -skSL -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64)' --speed-limit 50000 --speed-time 90 https://api.bgpview.io/asn/$it/prefixes | jq . >../../.asn/$it.json
		# sleep 44

		jq -r '.data.ipv4_prefixes[]|.prefix' ../../.asn/$it.json
	done)
EOF

# add checkip.synology.com
time cidr-merger <<-EOF >>chnroute.txt.new
	104.248.79.120
	138.68.28.244
	142.93.81.166
	159.65.77.153
	159.89.129.146
	159.89.142.52
	165.227.63.200
	206.189.214.49
EOF

# add wechat
time cidr-merger <<-EOF >>chnroute.txt.new
	43.156.222.0/24
	101.32.104.0/24
	101.32.118.0/24
	101.32.133.0/24
	129.226.3.0/24
	129.226.107.0/24
	162.62.163.0/24
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
sed '/^apple.com$/d' -i gfwlist
echo 'ess.apple.com' >>gfwlist
echo 'push.apple.com' >>gfwlist
curl_githubusercontent https://raw.githubusercontent.com/dler-io/Rules/main/Surge/Surge%203/Provider/OpenAI.list |
	grep -v 'KEYWORD' | grep '^DOMAIN' | awk -F',' '{print $2}' >>gfwlist
# ------------------ gfwlist ------------------

# ------------------ gfwlist.lite ------------------
echo >&2 "# gfwlist.lite"
sed 's|^\.|.*\\.|g; s+$+$+g' tldn >gfwlist.blacklist
grep -Exv -f gfwlist.blacklist gfwlist >gfwlist.lite
rm -f gfwlist.blacklist
echo
# ------------------ gfwlist ------------------

# ------------------ adblock ------------------

curl_githubusercontent https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/adblockdomain.txt | grep -vE '^!' >adblock
curl_githubusercontent https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/adblockdomainlite.txt | grep -vE '^!' >adblock.lite

curl_githubusercontent https://raw.githubusercontent.com/neodevpro/neodevhost/master/domain | sed -n '/^#/d' >>adblock
curl_githubusercontent https://raw.githubusercontent.com/neodevpro/neodevhost/master/customblocklist | tee -a adblock adblock.lite >/dev/null
curl_githubusercontent https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/refs/heads/master/discretion/pcdn.txt | grep -v '^#' | tee -a adblock adblock.lite >/dev/null
curl_githubusercontent https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/refs/heads/master/discretion/anv.txt | grep -v '^#' | tee -a adblock adblock.lite >/dev/null
cat <<-EOF | tee -a adblock adblock.lite >/dev/null
	c.msn.com
	ntp.msn.com
	ntp.msn.cn
	assets.msn.cn
	api.msn.com
	browser.events.data.msn.com
EOF
grep -v '^#' adblock.ext | sort -u | tee -a adblock adblock.lite >/dev/null

echo >&2 "# adblock"
time shadowsocks-helper tide -i adblock -o adblock
time shadowsocks-helper tide -i adblock.lite -o adblock.lite

# whitelist
curl_githubusercontent https://raw.githubusercontent.com/217heidai/adblockfilters/refs/heads/main/rules/white.txt |
	grep -v '^#' | grep -E '^[a-z\-\.]*$' | while read it; do
	sed "/^${it}$/d" -i adblock adblock.lite
done
sed 's+\.$++g' -i adblock adblock.lite
sed 's+localhost++g' -i adblock adblock.lite
sed '/^bj.bcebos.com/d; /^puui.qpic.cn/d; /^zhanzhang.toutiao.com/d' -i adblock adblock.lite
sed '/tencent-cloud/d' -i adblock adblock.lite
sed '/weixinbridge/d' -i adblock adblock.lite
sed '/bootcdn.net/d' -i adblock adblock.lite
sed '/wns.windows.com/d' -i adblock adblock.lite
sed '/e.189.cn/d' -i adblock adblock.lite
sed '/ip-api.com/d; /pv.sohu.com/d' -i adblock adblock.lite
sed '/click.simba.taobao.com/d' -i adblock adblock.lite
sed '/click.union.vip.com/d; /ms.vipstatic.com/d' -i adblock adblock.lite
sed '/dlswbr.baidu.com/d' -i adblock adblock.lite
# rm adblock.lite_*

# ------------------ adblock ------------------

# ------------------ direct ------------------
curl_githubusercontent https://raw.githubusercontent.com/pexcn/daily/gh-pages/chinalist/chinalist.txt >direct.pexcn

start=$(($(sed -n -e '/^whatismyip.akamai.com$/=' direct) + 1))
cat <<-EOF | sort -u >direct.new
	$(sed '/^www.apple.com$/,+99999d' direct.pexcn)
EOF

curl_githubusercontent https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/apple.china.conf | awk -F'/' '{print $2}' >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/Loyalsoldier/surge-rules/release/apple.txt >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/v2fly/domain-list-community/master/data/tencent >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/v2fly/domain-list-community/master/data/alibaba >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/v2fly/domain-list-community/master/data/bytedance >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/China/China_Domain.txt | sed '/^#/d' | sed '/akadns.net/d; /microsoft/d' >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/pluwen/china-domain-allowlist/main/allow-list.sorl |
	sed -n 's+^*\.++p' | sed '/apple/d; /akadns/d; /doubleclick/d' >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/eliozy/Qumtumult-X/master/Filter/WeChat.list |
	sed -n 's+^DOMAIN-SUFFIX,++p' | sed 's+,.*++g' >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/Ruleset/Wechat.list |
	sed -n 's+^DOMAIN[^,]*,++p' >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/marsgogo/Surge/main/Weixin.list |
	sed -n 's+^DOMAIN[^,]*,++p' >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/ChinaMedia.list |
	sed -n 's+^DOMAIN[^,]*,++p' >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/ChinaDomain.list |
	sed -n 's+^DOMAIN[^,]*,++p' >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/QuantumultX/WeChat/WeChat.list |
	grep -v 'KEYWORD' | grep '^HOST' | awk -F',' '{print $2}' >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Shadowrocket/XianYu/XianYu.list |
	grep -v 'KEYWORD' | grep '^DOMAIN' | awk -F',' '{print $2}' >>direct.new
curl_githubusercontent https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Shadowrocket/DouYin/DouYin.list |
	grep -v 'KEYWORD' | grep '^DOMAIN' | awk -F',' '{print $2}' >>direct.new

# blacklist
sed '/google/d; /gstatic/d; /youtube/d; /^android/d;' -i direct.new
sed '/ocsp/d; /akamai/d; /aws/d' -i direct.new
sed '/sci-hub/d; /scihub/d; /gitbook/d' -i direct.new
sed '/ebay/d; /lazada/d; /yandex/d' -i direct.new
cat adblock gfwlist >direct.blacklist
sed "$start,99999d" direct >>direct.blacklist
sed 's+\.+\\.+g' -i direct.blacklist
grep -Fv -f direct.blacklist direct.new >direct.sum

echo >&2 "# direct.sum"
time shadowsocks-helper tide -i direct.sum -o direct.sum
sed "$start,99999d" -i direct
sed 's+$+\$+g; s+\.+\\.+g' tldn gfwlist >direct.suffix
echo "\.*apple\." >>direct.suffix
echo "\.*windows\." >>direct.suffix
echo "\.*microsoft\." >>direct.suffix
echo "\.*windowsupdate\." >>direct.suffix
echo >&2 "# direct"
time grep -eF -f direct.suffix direct.sum >>direct
sed '/gvt2.com/d; /www.microsoft.com/d' -i direct
rm -f direct.*
# ------------------ direct ------------------

# ------------------ gzip ------------------
md5sum chnroute.txt | tee chnroute.txt.md5sum

srcs="tldn gfwlist direct adblock $(ls *.lite)"

for it in $srcs; do
	echo >>$it
	sed '/^[ \t\s]*$/d' -i $it
	gzip -n9fk $it
	md5sum $it | tee $it.md5sum
	md5sum $it.gz | tee $it.gz.md5sum
done
# ------------------ gzip ------------------

# ----------- ShadowrocketEx.conf ----------
sed 's+^+IP-CIDR,+g; s+$+,no-resolve+g' chnroute.txt >$_path/.shadowrocket/cncidr.txt
curl_githubusercontent https://raw.githubusercontent.com/Johnshall/Shadowrocket-ADBlock-Rules-Forever/release/sr_top500_banlist.conf >$_path/.shadowrocket/banlist.conf
curl_githubusercontent https://raw.githubusercontent.com/Johnshall/Shadowrocket-ADBlock-Rules-Forever/release/sr_top500_whitelist.conf >$_path/.shadowrocket/whitelist.conf
sed '/ios_rule_script/iDOMAIN-SET,https://raw.githubusercontent.com/honwen/openwrt-dnsmasq-extra/master/dnsmasq-extra/files/data/adblock.ext,REJECT' -i $_path/.shadowrocket/*list.conf
sed 's+https://raw.githubusercontent.com+https://ghproxy.net/https://raw.githubusercontent.com+g' -i $_path/.shadowrocket/*list.conf
sed '/^#/d' -i $_path/.shadowrocket/*list.conf
sed -i '/MITM/,+2d' -i $_path/.shadowrocket/*list.conf

sed '/^[ \t]*$/d' -i $_path/.shadowrocket/*list.conf
sed 's+^\[+\n[+g' -i $_path/.shadowrocket/*list.conf
sed '/./,$!d' -i $_path/.shadowrocket/*list.conf

curl_githubusercontent https://raw.githubusercontent.com/GMOogway/shadowrocket-rules/master/docs/03.shadowsocks_tiny.conf >$_path/.shadowrocket/tiny.conf
sed '/always-real-ip/d' -i $_path/.shadowrocket/tiny.conf
sed '/^dns-server/a always-real-ip = *' -i $_path/.shadowrocket/tiny.conf
# ----------- ShadowrocketEx.conf ----------

cd -
