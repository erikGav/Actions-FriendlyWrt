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

# Patch mac80211: ignore AP power constraint when txpower type is fixed
# RFC: https://patchwork.kernel.org/project/linux-wireless/patch/1449324423-99589-1-git-send-email-nbd@openwrt.org/
python3 - <<'PYEOF'
import sys
filename = 'kernel/net/mac80211/iface.c'
with open(filename, 'r') as f:
    content = f.read()
OLD = '\tif (sdata->deflink.ap_power_level != IEEE80211_UNSET_POWER_LEVEL)\n\t\tpower = min(power, sdata->deflink.ap_power_level);'
NEW = ('\tif (sdata->deflink.ap_power_level != IEEE80211_UNSET_POWER_LEVEL &&\n'
       '\t    sdata->vif.bss_conf.txpower_type != NL80211_TX_POWER_FIXED)\n'
       '\t\tpower = min(power, sdata->deflink.ap_power_level);')
if OLD not in content:
    print('ERROR: mac80211 patch target not found in ' + filename, file=sys.stderr)
    sys.exit(1)
with open(filename, 'w') as f:
    f.write(content.replace(OLD, NEW, 1))
print('mac80211 txpower patch applied successfully')
PYEOF