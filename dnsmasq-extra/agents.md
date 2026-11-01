# dnsmasq-extra —— 给 AI 助手/维护者的说明

本文记录 `generate.sh` 数据生成链路里**不写下来就会被重新踩一遍**的约束。
改动前请先读完「铁律」一节。

## 数据流

`generate.sh` 按顺序生成六份数据，最终由 `files/dnsmasq-extra.init` 消费：

| 文件 | 用途 | 消费方 |
|---|---|---|
| `chnroute.txt` | 国内 IP 段（ipset / 路由） | `.shadowrocket/cncidr.txt`、防火墙 |
| `gfwlist` / `gfwlist.lite` | 需走代理的域名 → `server=/d/127.0.0.1#port` | `plugin_*.conf` |
| `adblock` / `adblock.lite` | 屏蔽域名 → `address=/d/SOA` | `misc_adblock.conf` |
| `tldn` | 非中国 TLD 列表（Clash `tld-not-cn`） | `plugin_*.conf`、下游闸门 |
| `direct` | **直连**域名 → `server=/d/#` | `misc_direct.conf` |

`direct` 是唯一一道需要小心对待的：它**不是**"所有中国域名"，而是
"要用本地/直连解析器解析的域名"。见下。

### `direct` 的四段流水（`generate.sh:201-279`）

```
18 个上游 URL ──► $_direct_tmp/[0-9][0-9].*   每份独立落文件，统一补行尾换行
              ──► direct.new                  cat 合并（17k+ 行）
              ──► direct.sum                  grep -Fvx -f direct.blacklist（丢约 2k）
              ──► direct.appended             grep -E -f direct.suffix（丢约 14k）★
              ──► 追加到 direct
```

★ 这一步是**闸门**，也是最大的丢弃点。

## 铁律

### 1. `direct.suffix` 闸门是 TLD 白名单，不要"修"成放行更多域名

`generate.sh:268-273` 的闸门只放行两类域名：

- TLD 在 `tldn` 里的（Clash `tld-not-cn`，1627 个**非中国** TLD）
- 在 `gfwlist` 里有精确条目的

`.com` / `.net` / `.cn` / `.top` 等**都被整类否决** —— `tldn` 里没有它们，这是有意的，
否则等于放行大半个互联网。

实测规模：`direct.new` 17,771 → 黑名单后 15,427 → **闸门后仅 1,467**。
`.org` / `.xyz` 放行率 100%，`.com` 放行率 0.5%。

**副作用值得知道**：`direct.new` 里那一大堆中国域名源（pexcn chinalist、tencent、
alibaba、bytedance、ChinaDomain…）绝大多数是 `.com` / `.net`，因此基本在空转。
它们是历史遗留，不代表这些域名的实际去向。若哪天要重新审视这批源的价值，这里是切入点。

### 2. 要直连的域名 → 插到 `files/data/direct` 的**前缀**

所谓前缀 = `whatismyip.akamai.com` 这一行**之前**的所有行。

`generate.sh:211` 用这行定位：

```bash
start=$(($(sed -n -e '/^whatismyip.akamai.com$/=' direct) + 1))
```

之后 `sed "$start,99999d" -i direct`（`:262`）把该行**及其之后**的内容整段截掉，
前缀原样保留。所以：

- ✅ 插在 `whatismyip.akamai.com` **之前** → 永久保留
- ❌ 插在它**之后** → 下一轮生成就会消失

例：`halomt.com` 来自上游 `no_proxy_needed.list`（该文件注释即"ptool 手动添加"，
语义是明确要求直连），因 `.com` 被闸门否决，故登记在前缀。

历史上曾引入过 `direct.ext` 之类的旁路机制，已被否决 —— 多余，插前缀即可。

### 3. 前缀的顺序不能重排

`start` 由 `whatismyip.akamai.com` 的**行号**决定。对前缀做 `sort`
会移动这一行，导致下一轮截断位置错乱。

因此追加区（`:271-277`）的写法是：

```bash
grep -E -f direct.suffix direct.sum | sort -u >direct.appended   # 自身去重
grep -Fvx -f direct direct.appended >direct.appended.uniq        # 再对前缀去重
cat direct.appended.uniq >>direct                                # 前缀一个字不动
```

不要图省事写成 `sort -u -o direct direct`。

### 4. sed 替换部分的反斜杠要写两个

```bash
sed 's+^\.+(^|\\.)+; s+$+$+g' tldn     # 正确 → (^|\.)xyz$
sed 's+^\.+(^|\.)+;  s+$+$+g' tldn     # 错误 → (^|.)xyz$
```

sed 会折叠一个 `\`，退化成未转义的 `.`，即"匹配任意单字符"。
这个坑曾把闸门放宽成 `(^|.)om$`，误放行 1909 条 `.com` 域名
（`halomt.com` 之所以"看起来被放行"，也是这个原因，**纯属巧合**）。

### 5. `grep -F` 是子串匹配，不是整词

`grep -F -f <pattern-file>` 里，任一 pattern 是行的**子串**即命中 —— 不是整词，也不是后缀。

真实受害者（实测，均因短条目而中招）：

| 域名 | 被哪个 pattern 子串命中 |
|---|---|
| `halomt.com` | `t.co`（`halo`**`mt.co`**`m`） |
| `199it.com` | `t.co` |
| `0daydown.com` | `wn.com`（`0daydo`**`wn.com`**） |

需要整行语义时必须带 `-x`：`grep -Fvx -f …`。

**注意区分**：`114la.com`、`2345.com` 这类是 `adblock` 里的**真实条目**，
带 `-x` 也应当被删 —— 别把它们当作误伤案例。

> 这个 `-x` 是 2022-08-21 `4df75ec` 被误删的，此后四年一直带着缺陷运行，
> 直到 2026-10 才恢复。改动这一行时请留意。

### 6. 黑名单比对前必须先归一化（前导点 / 尾部回车）

`generate.sh:258` 附近的 `sed 's+\r++g; s+^\.++' -i direct.new` **不能删**。

`grep -Fvx` 是整行比较，上游源里的两种写法会让条目"看起来不一样"从而绕过黑名单：

| 写法 | 实测行数 | 为什么会绕过 |
|---|---|---|
| 前导点 `.browserleaks.com` | 3830 | blacklist 存的是裸域名 `browserleaks.com` |
| 尾部回车 `bilibili.tv\r`（CRLF 源） | 1220 | `bilibili.tv\r != bilibili.tv` |

绕过后 `tide` 会把它们修整成裸域名（它本来就去点、去 CR），于是这些
**gfwlist 域名最终落进 `direct`，被写成直连** —— 与「gfwlist 走代理」的设计正好相反。

实测影响：100 个 gfwlist/adblock 域名因此被误写成直连，包括
`browserleaks.com`、`bilibili.tv`、`office.com`、`sony.com`、`xbox.com`、
`m-team.cc`、`rarbg.to`、`airbnb.com`、`adf.ly` 等。

判断手法：拿不准某个域名为何在 `direct` 里时，先看它在 `direct.new` 里的**原始字节**：

```bash
grep -n '某域名' direct.new | cat -A     # ^M$ 结尾即带 CR，前导点一眼可见
```

### 7. 上游文件末行常常没有换行

`>>` 直接追加会让该行与**下一个来源的首行**粘连成一个假域名。
例：`no_proxy_needed.list` 末行是 `DOMAIN-SUFFIX,halomt.com`，无换行 →
与 eliozy WeChat 列表首行拼成 `halomt.comszaxshort.weixin.qq.com`。

因此各来源必须先落到独立文件，用 `sed -i -e '$a\'` 补足行尾换行，最后 `cat`。
`$_direct_tmp` 目录 + `trap … EXIT` 负责清理。

## 生成与验证

### 触发

`generate.sh` 生成时只改 `PKG_VERSION` 的日期。`update.sh` 判定逻辑是
**日期 != 今天**才重新生成（`update.sh` 中 `process_generate`），因此：

- 同一天内改了 `generate.sh`，`./update.sh` **不会**重新生成，需要手动跑
- `./update.sh` 默认 dry-run，实际更新要加 `--update`（加 `--commit` 才会提交）

### 完整跑一次

```bash
cd dnsmasq-extra && bash generate.sh
```

耗时大头是网络抓取 + `shadowsocks-helper tide`（DNS 解析去重）；相形之下
`grep -E -f direct.suffix`（32k 条模式）在修正后约 27s，不再是瓶颈。

### 验收清单

```bash
cd dnsmasq-extra/files/data
wc -l direct                                    # 当前基线 1429
printf "dups: %s\n" "$(( $(wc -l <direct) - $(sort -u direct | wc -l) ))"   # 必须 0
printf "CR:   %s\n" "$(grep -c $'\r' direct)"   # 必须 0
sed -n '/^whatismyip.akamai.com$/=' direct      # 必须 40
md5sum -c direct.md5sum && md5sum -c direct.gz.md5sum
zcat direct.gz | cmp - direct                   # 必须一致
```

另外抽查：`direct` 里不应出现任何 gfwlist 域名（除前缀手工登记的外）。

```bash
comm -12 <(sort -u direct) <(sort -u gfwlist)   # 应只剩前缀里那几个
```

**跑第二遍，结果必须完全一致**（幂等性是这套脚本最容易坏的性质，见铁律 3）。

## 已知的坑（非目标，别顺手"修"）

- `direct.suffix` 里的模式形如 `(^|\.)com$` 时匹配的是**字符串**而非 DNS 语义，
  但现有形式只用于 TLD 与 gfwlist 后缀，行为符合预期。
- 四行手写的 `echo "\.*apple\." >>direct.suffix` 已在 2026-10 删除 ——
  `gfwlist` 生成的等价模式已覆盖，且能匹配裸域名。
- `direct` 前 39 行是人工维护的精选（`.lan`、`ip.sb`、`wechat.com`… ），
  不属于生成产物，勿批量替换。

## 编码约定

- `generate.sh` 内注释用中文，与既有风格一致
- 各段以 `# ------------------ <name> ------------------` 分隔
- 上游抓取统一走 `curl_githubusercontent()`（自带多个 ghproxy 回退）
