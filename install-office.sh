#!/bin/bash
#  auto-install-office.sh
#  依赖：macOS 10.15+、curl、osascript、installer
#  用法：chmod +x auto-install-office.sh && ./auto-install-office.sh

set -e
LANG=en_US.UTF-8
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TMP_DL="$SCRIPT_DIR/.download"
mkdir -p "$TMP_DL"

# 进度条函数（AppleScript）
function progress(){
  osascript -e "display notification \"$1\" with title \"办公套件自动安装\""
}

# 带管理员权限跑命令（一次性要密码）
function sudo_once(){
  sudo -K          # 清缓存
  osascript -e "do shell script \"$*\" with administrator privileges"
}

################### 1. Lark ###################
progress "正在下载 Lark…"
curl -L -o "$TMP_DL/Lark.dmg" \
     "https://sf3-cn.feishucdn.com/obj/ee-appcenter/Lark-latest.dmg"
hdiutil attach -quiet -noverify "$TMP_DL/Lark.dmg"
sudo_once "cp -R '/Volumes/Lark/Lark.app' /Applications/"
hdiutil detach -quiet "/Volumes/Lark"
# 写租户（按需改）
sudo_once "defaults write /Library/Preferences/com.bytedance.lark.helper TenantDomain -string 'yourcompany.feishu.cn'"

################### 2. 飞连 ###################
progress "正在下载 飞连…"
curl -L -o "$TMP_DL/Feilian.dmg" \
     "https://github.com/yourorg/feilian/releases/latest/download/Feilian.dmg"
hdiutil attach -quiet -noverify "$TMP_DL/Feilian.dmg"
sudo_once "installer -pkg '/Volumes/Feilian/Feilian.pkg' -target /"
hdiutil detach -quiet "/Volumes/Feilian"
# 预置 ovpn（仓库里放 client.ovpn）
sudo_once "cp '$SCRIPT_DIR/client.ovpn' /opt/feilian/config/ && chmod 600 /opt/feilian/config/client.ovpn"

################### 3. Google Chrome ###################
progress "正在下载 Chrome…"
curl -L -o "$TMP_DL/Chrome.dmg" \
     "https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg"
hdiutil attach -quiet -noverify "$TMP_DL/Chrome.dmg"
sudo_once "cp -R '/Volumes/Google Chrome/Google Chrome.app' /Applications/"
hdiutil detach -quiet "/Volumes/Google Chrome"
# 关自动更新
sudo_once "launchctl unload -w /Library/LaunchAgents/com.google.keystone.agent.plist 2>/dev/null || true"

################### 4. SecureLink ###################
progress "正在下载 SecureLink…"
curl -L -o "$TMP_DL/SecureLink.pkg" \
     "https://github.com/yourorg/securelink/releases/latest/download/SecureLink.pkg"
sudo_once "installer -pkg '$TMP_DL/SecureLink.pkg' -target /"
# 写服务器地址
sudo_once "defaults write /Library/Preferences/com.securelink ServerURL -string 'https://sl.example.com'"

################### 5. CrowdStrike Agent ###################
progress "正在下载 CrowdStrike…"
curl -L -o "$TMP_DL/falcon-sensor.pkg" \
     "https://your-bucket.s3.amazonaws.com/falcon-sensor-latest.pkg"
sudo_once "installer -pkg '$TMP_DL/falcon-sensor.pkg' -target /"
sleep 25
sudo_once "/Applications/Falcon.app/Contents/Resources/falconctl license 12345678-1234-1234-1234-123456789ABC"

################### 收尾 ###################
progress "安装完成，清理缓存…"
rm -rf "$TMP_DL"
dscacheutil -flushcache
progress "全部搞定！"
