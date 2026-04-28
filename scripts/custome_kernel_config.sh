#!/bin/bash

CONFIGS=(
  "CONFIG_NET_ACT_CT=m"
  "CONFIG_NET_ACT_CTINFO=m"
)

source .current_config.mk
KCFG=kernel/arch/arm64/configs/$(awk '{print $1}' <<< "$TARGET_KERNEL_CONFIG")

for CFG in "${CONFIGS[@]}"; do
  KEY=${CFG%%=*}
  if grep -q "^#\?${KEY}=" "${KCFG}"; then
    sed -i "s@^#\?${KEY}=.*@${CFG}@g" "${KCFG}"
  else
    echo "$CFG" >> "${KCFG}"
  fi
done

# Patch mac80211: remove AP power constraint enforcement entirely.
# bss_conf.txpower_type is never NL80211_TX_POWER_FIXED in OpenWrt (PHY-level
# txpower is used), so the RFC condition-based approach doesn't work.
# Regulatory channel max still applies; only the AP-advertised constraint is skipped.
python3 - <<'PYEOF'
import sys
filename = 'kernel/net/mac80211/iface.c'
with open(filename, 'r') as f:
    content = f.read()
OLD = '	if (sdata->deflink.ap_power_level != IEEE80211_UNSET_POWER_LEVEL)
		power = min(power, sdata->deflink.ap_power_level);
'
if OLD not in content:
    print('ERROR: mac80211 patch target not found in ' + filename, file=sys.stderr)
    sys.exit(1)
with open(filename, 'w') as f:
    f.write(content.replace(OLD, '', 1))
print('mac80211 ap_power_level constraint removed successfully')
PYEOF
