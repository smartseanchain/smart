#!/bin/bash
# install_all.sh —— macOS 全量自动安装（含 Falcon 自动配置）
set -u
cd /tmp
CID="E3E08A20CAE84445821F3AC16D1C2B53-B5"   # <—— 换成你的 CID

echo "===== $(date) 开始全量安装 ====="

# 1. CrowdStrike Falcon Sensor（下载+安装+配CID）
echo -n "CrowdStrike ... "
curl -fsSL -o cs.pkg http://192.168.3.99/download/FalconSensorMacOS.MaverickGyr.pkg && \
sudo /usr/sbin/installer -pkg cs.pkg -target / >/dev/null 2>&1 && \
sudo /Applications/Falcon.app/Contents/Resources/falconctl license "$CID" >/dev/null 2>&1 && \
rm cs.pkg && echo "OK" || echo "ERROR"

# 2. 飞连
echo -n "Feilian ... "
curl -fsSL -o http://192.168.3.99/download/FeiLian_Mac_arm64_v3.1.17_r9688_aabb65.pkg && \
sudo /usr/sbin/installer -pkg feilian.pkg -target / >/dev/null 2>&1 && \
rm feilian.pkg && echo "OK" || echo "ERROR"

# 3. Lark
echo -n "Lark ... "
curl -fsSL -o lark.dmg http://192.168.3.99/download/Lark-darwin_arm64-7.52.8-signed-2.dmg && \
hdiutil attach -quiet -nobrowse lark.dmg && \
cp -R /Volumes/Lark*/Lark.app /Applications/ && \
hdiutil detach -quiet /Volumes/Lark* && \
rm lark.dmg && echo "OK" || echo "ERROR"

# 4. Google Chrome
echo -n "Chrome ... "
curl -fsSL -o chrome.dmg https://smart-1386797427.cos.ap-guangzhou.myqcloud.com/googlechrome.dmg && \
hdiutil attach -quiet -nobrowse chrome.dmg && \
cp -R "/Volumes/Chrome*/Google Chrome.app" /Applications/ && \
hdiutil detach -quiet /Volumes/Chrome* && \
rm chrome.dmg && echo "OK" || echo "ERROR"

echo "===== 完成 ====="
