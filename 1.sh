{\rtf1\ansi\ansicpg936\cocoartf2822
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww28600\viewh18000\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 #!/bin/bash\
# macOS \uc0\u19968 \u38190 \u23433 \u35013 \u65306 Lark + Google Chrome + \u39134 \u36830  + CrowdStrike Agent\
# usage:  sudo ./install_all.sh\
set -e\
log=/var/log/mac_install.log\
exec &> >(tee -a "$log")\
\
echo "======== \uc0\u24320 \u22987 \u19968 \u38190 \u23433 \u35013  $(date) ========"\
\
# ---- \uc0\u36890 \u29992 \u20989 \u25968  ----\
install_dmg() \{\
  local url=$1 name=$2\
  echo "[*] \uc0\u27491 \u22312 \u23433 \u35013  $name ..."\
  tmp=$(mktemp -d)\
  curl -L -s "$url" -o "$tmp/pkg.dmg"\
  mount=$(hdiutil attach "$tmp/pkg.dmg" -nobrowse -quiet | grep Volumes | awk '\{print $3\}')\
  if ls "$mount"/*.pkg &>/dev/null; then\
    sudo installer -pkg "$mount"/*.pkg -target /\
  elif ls "$mount"/*.app &>/dev/null; then\
    cp -R "$mount"/*.app /Applications/\
  fi\
  hdiutil detach "$mount" -quiet\
  rm -rf "$tmp"\
  echo "[\uc0\u10003 ] $name \u23433 \u35013 \u23436 \u25104 "\
\}\
\
# ---- 0. \uc0\u21028 \u26029 \u26550 \u26500  ----\
ARCH=$(uname -m)\
case $ARCH in\
  x86_64)  ARCH_TAG="x64" ;;\
  arm64)   ARCH_TAG="arm64" ;;\
  *)       echo "\uc0\u26410 \u30693 \u26550 \u26500 "; exit 1 ;;\
esac\
\
# ---- 1. Google Chrome ----\
if [[ -d "/Applications/Google Chrome.app" ]]; then\
  echo "[-] Chrome \uc0\u24050 \u23384 \u22312 \u65292 \u36339 \u36807 "\
else\
  CHROME_URL="https://dl.google.com/chrome/mac/stable/$ARCH_TAG/googlechrome.dmg"\
  install_dmg "$CHROME_URL" "Google Chrome"\
fi\
\
# ---- 2. Lark\uc0\u65288 \u22269 \u20869 \u38236 \u20687 \u65289  ----\
if [[ -d "/Applications/Lark.app" ]]; then\
  echo "[-] Lark \uc0\u24050 \u23384 \u22312 \u65292 \u36339 \u36807 "\
else\
  LARK_URL="https://sf3-cn.feishucdn.com/obj/lark-eco-statics/Lark-darwin_$\{ARCH_TAG\}-latest.dmg"\
  install_dmg "$LARK_URL" "Lark"\
fi\
\
# ---- 3. \uc0\u39134 \u36830 \u65288 Feilian\u65289 ----\
if [[ -d "/Applications/\uc0\u39134 \u36830 .app" || -d "/Applications/Feilian.app" ]]; then\
  echo "[-] \uc0\u39134 \u36830  \u24050 \u23384 \u22312 \u65292 \u36339 \u36807 "\
else\
  FEILIAN_URL="https://lf3-static.bytedance.com/obj/lark-obj-ecology/feilian-mac-$ARCH_TAG.dmg"\
  install_dmg "$FEILIAN_URL" "\uc0\u39134 \u36830 "\
fi\
\
# ---- 4. CrowdStrike Falcon Agent ----\
# \uc0\u27880 \u24847 \u65306 \u20225 \u19994 \u36890 \u24120 \u33258 \u24049 \u25552 \u20379  CCID\u65292 \u36825 \u37324 \u25918 \u23448 \u26041 \u26368 \u26032  pkg \u21253 \u65307 \u22914 \u36149 \u21496 \u26377 \u20869 \u37096 \u28304 \u35831 \u25913  URL\
if launchctl list | grep -q falcon; then\
  echo "[-] CrowdStrike \uc0\u24050 \u22312 \u36816 \u34892 \u65292 \u36339 \u36807 "\
else\
  CS_URL="https://dl.crowdstrike.com/protect/latest/falcon-mac-install.pkg"\
  tmp=$(mktemp)\
  curl -L -s "$CS_URL" -o "$tmp/f.pkg"\
  sudo installer -pkg "$tmp/f.pkg" -target /\
  rm -rf "$tmp"\
  echo "[\uc0\u10003 ] CrowdStrike \u23433 \u35013 \u23436 \u25104 "\
fi\
\
echo "======== \uc0\u20840 \u37096 \u23433 \u35013 \u32467 \u26463  $(date) ========"}