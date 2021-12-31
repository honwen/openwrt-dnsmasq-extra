#!/bin/bash

# set -ex
# Tools:
# https://github.com/honwen/shadowsocks-helper
# https://github.com/zhanhb/cidr-merger

_date=$(date '+%Y-%m-%d')
_path=$(dirname $(dirname $(dirname $(readlink -f $0))))

sed "s+PKG_VERSION:=.*+PKG_VERSION:=${_date}+g" -i $_path/Makefile
echo "# Generated At ${_date}"

cd $_path/files/data
# ------------------ chnroute ------------------
time cidr-merger <<-EOF >chnroute.txt.new
	$(curl -skL --speed-limit 100000 --speed-time 10 https://ispip.clang.cn/all_cn_cidr.txt)

	$(curl -skL --speed-limit 100000 --speed-time 10 https://raw.githubusercontent.com/metowolf/iplist/master/data/country/CN.txt)

	$(
		curl -skL --speed-limit 100000 --speed-time 10 https://cdn.staticaly.com/gh/pexcn/daily/gh-pages/chnroute/chnroute.txt ||
			curl -skL --speed-limit 100000 --speed-time 10 https://raw.githubusercontent.com/pexcn/daily/gh-pages/chnroute/chnroute.txt
	)

	$(
		curl -skL --speed-limit 100000 --speed-time 10 https://cdn.staticaly.com/gh/17mon/china_ip_list/master/china_ip_list.txt ||
			curl -skL --speed-limit 100000 --speed-time 10 https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt
	)

	$(
		curl -skL --speed-limit 100000 --speed-time 10 https://cdn.staticaly.com/gh/QiuSimons/Chnroute/master/dist/chnroute/chnroute.txt ||
			curl -skL --speed-limit 100000 --speed-time 10 https://raw.githubusercontent.com//QiuSimons/Chnroute/master/dist/chnroute/chnroute.txt
	)

	$(
		curl -skL --speed-limit 100000 --speed-time 10 https://cdn.staticaly.com/gh/gaoyifan/china-operator-ip/ip-lists/china.txt ||
			curl -skL --speed-limit 100000 --speed-time 10 https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china.txt
	)

	$(shadowsocks-helper asn)
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

# min netmask >= /24
time cidr-merger <<-EOF >chnroute.txt
	$(cat chnroute.txt.new)
	$(sed 's+\.[^\.]*$+.0/24+g' chnroute.txt.new)
EOF

sed '/^[ \t\s]*$/d' -i chnroute.txt
rm -f chnroute.txt.*
# ------------------ chnroute ------------------

# ------------------ gfwlist ------------------
time shadowsocks-helper gfwlist >gfwlist
sed '/^google.*analytics.com$/d' -i gfwlist
# ------------------ gfwlist ------------------

# ------------------ adblock ------------------

curl -sSL https://anti-ad.net/domains.txt -o adblock
curl -sSL https://raw.githubusercontent.com/neodevpro/neodevhost/master/customblocklist >>adblock
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
time shadowsocks-helper tide -i adblock -o adblock

# whitelist
sed '/wns.windows.com/d' -i adblock
sed '/ip-api.com/d; /pv.sohu.com/d' -i adblock
sed '/click.union.vip.com/d; /ms.vipstatic.com/d' -i adblock
# rm -f adblock.*
# ------------------ adblock ------------------

# ------------------ direct ------------------
curl -sSL https://raw.githubusercontent.com/pexcn/daily/gh-pages/chinalist/chinalist.txt -o direct.pexcn

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
sed 's+$+\$+g; s+\.+\\.+g' tldn gfwlist >direct.suffix
echo "\.*apple\." >>direct.suffix
echo "\.*windows\." >>direct.suffix
echo "\.*microsoft\." >>direct.suffix
echo "\.*windowsupdate\." >>direct.suffix
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

rm -f ShadowrocketEx.conf Complete.conf
curl -sSL https://raw.githubusercontent.com/lhie1/Rules/master/Shadowrocket/Complete.conf -o Complete.conf
sed 's+^dns-server.*+dns-server = tls://223.5.5.5, https://doh.pub/dns-query, https://223.6.6.6/dns-query+g' -i Complete.conf
sed 's+^bypass-tun *= *+bypass-tun = 223.5.5.0/24, 223.6.6.0/24, 120.53.80.0/24, 175.24.219.0/24, 162.14.20.0/22, +g' -i Complete.conf

end_of_header=$(sed -n -e '/^DOMAIN-SUFFIX,12306.cn,DIRECT$/=' Complete.conf)
start_of_cidr=$(sed -n -e "$end_of_header,999999{/^IP-CIDR,.*,DIRECT,no-resolve$/=}" Complete.conf | head -n1)

echo "# Generated At ${_date}" >ShadowrocketEx.conf
sed -n "1,$((end_of_header - 1))p" Complete.conf >>ShadowrocketEx.conf

(
	sed -n "$end_of_header,$((start_of_cidr - 1))p" Complete.conf
	sed -n "$start,999999p" direct | sed 's+^+DOMAIN-SUFFIX,+g; s+$+,DIRECT,no-resolve+g'
) | sort -u | sed '/^[ \t\s]*$/d' >>ShadowrocketEx.conf

sed 's+^+IP-CIDR,+g; s+$+,DIRECT,no-resolve+g' chnroute.txt >>ShadowrocketEx.conf
echo -e '\n# > GFWLIST' >>ShadowrocketEx.conf
sed '/[0-9]$/d' gfwlist | sed 's+^+DOMAIN-SUFFIX,+g; s+$+,PROXY+g' >>ShadowrocketEx.conf
echo -e '\n# > CN' >>ShadowrocketEx.conf

start_of_footer=$(sed -n -e '/^DOMAIN-SUFFIX,cn,DIRECT$/=' Complete.conf)

sed -n "$start_of_footer,999999p" Complete.conf >>ShadowrocketEx.conf

rm -f Complete.conf
# ----------- ShadowrocketEx.conf ----------

cd -
