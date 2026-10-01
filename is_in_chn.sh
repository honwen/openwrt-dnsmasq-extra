#!/bin/bash
# is_in_chn.sh - Check if an IP or CIDR range is contained in chnroute.txt
#
# Usage: is_in_chn.sh <ip/cidr>
#
# Example:
#   ./is_in_chn.sh 43.165.128.0/18
#   ./is_in_chn.sh 8.8.8.8
#   ./is_in_chn.sh 114.114.114.114

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHNROUTE="${SCRIPT_DIR}/dnsmasq-extra/files/data/chnroute.txt"

usage() {
    cat <<EOF
Usage: $(basename "$0") <IP[/prefix]>

Check whether the given IP address or CIDR range is covered by chnroute.txt.

Examples:
  $(basename "$0") 43.165.128.0/18
  $(basename "$0") 8.8.8.8
  $(basename "$0") 114.114.114.114
EOF
    exit 1
}

[ $# -eq 1 ] || usage

QUERY="$1"

# If no prefix length provided, treat as /32 (single IP)
[[ "$QUERY" == */* ]] || QUERY="${QUERY}/32"

[ -f "$CHNROUTE" ] || { echo "ERROR: chnroute.txt not found at $CHNROUTE"; exit 2; }

python3 -c "
import ipaddress
import sys

query = ipaddress.ip_network('${QUERY}', strict=False)

found = []
with open('${CHNROUTE}') as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        try:
            net = ipaddress.ip_network(line, strict=False)
        except ValueError:
            continue

        # query is contained in 'net' if it's a subnet-of or equal to 'net'
        # subnet_of is Python 3.7+; fallback to manual check
        if hasattr(query, 'subnet_of'):
            if query.subnet_of(net):
                found.append(str(net))
        else:
            # manual: query's first & last addresses must both be in net
            if query[0] in net and query[-1] in net:
                found.append(str(net))

if found:
    print(f'YES: {query} is covered by chnroute')
    for m in found:
        print(f'  matched: {m}')
    sys.exit(0)
else:
    print(f'NO:  {query} is NOT covered by chnroute')
    sys.exit(1)
"