#!/bin/bash
#===============================================================
# CrowdStrike 部署前主机名统一设置工具  —  macOS 强化版
#===============================================================
if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    osascript -e 'tell application "Terminal" to do script "'"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"'"'
    exit 0
fi

WEBHOOK_URL="https://twqnhk7kyg.sg.larksuite.com/base/automation/webhook/event/Ieh5acpYhwFEM9hn58Qlcfmwgof"   # ← 如失效请替换
ADMIN_NAME="SecurityOps"

clear
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        内部终端设备主机名称统一规范设置工具（强化版）         ║"
echo "║                 适用于 macOS  /  CrowdStrike 部署前          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# -------- 部门选择 --------
dept_list=(Dev Ris Mkt Hr Web3 Sec Ops CS Fin)
PS3="👉 请输入部门编号 (1-${#dept_list[@]}): "
select dept_num in "${dept_list[@]}"; do
  [[ -n $dept_num ]] && break
  echo "❌ 输入错误！请重新选择 1-${#dept_list[@]}"
done
dept_prefix=$dept_num

# -------- 用户名选择 --------
user_name=$(whoami)
old_hostname=$(scutil --get ComputerName 2>/dev/null || echo "Unknown")
echo ""
echo "   1️⃣  使用当前用户名：${user_name}"
echo "   2️⃣  输入其他用户名（与 Lark 保持一致）"
read -p "👉 请选择 (1/2): " use_username
if [[ "$use_username" == "2" ]]; then
    read -p "请输入用户名: " custom_username
    final_user=$custom_username
else
    final_user=$user_name
fi

# -------- 生成新主机名 --------
device_model=$(system_profiler SPHardwareDataType | awk -F': ' '/Model Name/{print $2}' | tr -d ' ')
new_hostname="${dept_prefix}-${final_user}-${device_model}"

# -------- 确认 --------
echo ""
echo "📋 修改摘要："
echo "   🏢 部门：${dept_prefix}"
echo "   🖥️  原主机名：${old_hostname}"
echo "   ✨ 新主机名：${new_hostname}"
read -p "👉 确认执行修改？(y/n): " confirm
[[ ! "$confirm" =~ ^[Yy]$ ]] && { echo "❌ 已取消"; read -n1 -s; exit 0; }

#===============================================================
#  核心：三处 hostname 修改 + 原子性回滚
#===============================================================
echo ""
echo "🔐 请输入系统密码（sudo 授权）:"
if ! sudo -v; then
    echo "❌ 未获得 sudo 权限，脚本终止"
    exit 1
fi

# 备份旧值，用于回滚
old_ComputerName=$(scutil --get ComputerName 2>/dev/null)
old_HostName=$(scutil --get HostName 2>/dev/null)
old_LocalHostName=$(scutil --get LocalHostName 2>/dev/null)

# 统一修改函数
set_name(){
    sudo scutil --set ComputerName "$1"  && \
    sudo scutil --set HostName "$1"      && \
    sudo scutil --set LocalHostName "$1"
}

# 执行修改
if set_name "$new_hostname"; then
    # 二次校验：任意一项不一致即回滚
    curr_ComputerName=$(scutil --get ComputerName)
    curr_HostName=$(scutil --get HostName)
    curr_LocalHostName=$(scutil --get LocalHostName)
    if [[ "$curr_ComputerName" == "$new_hostname" && \
          "$curr_HostName" == "$new_hostname" && \
          "$curr_LocalHostName" == "$new_hostname" ]]; then
        echo "✅ 三处 hostname 已全部生效！"
    else
        echo "⚠️  校验失败，正在回滚..."
        sudo scutil --set ComputerName "$old_ComputerName"
        sudo scutil --set HostName "$old_HostName"
        sudo scutil --set LocalHostName "$old_LocalHostName"
        echo "❌ 已回滚到初始状态，请检查错误后重试"
        exit 1
    fi
else
    echo "❌ 设置过程出错，未做任何更改"
    exit 1
fi

#===============================================================
#  Webhook 通知（同旧逻辑，略）
#===============================================================
[[ -d "/Applications/Falcon.app" || -f "/Library/CS/falconctl" ]] && cs_status="✅ 已安装" || cs_status="⚠️ 未安装"
timestamp=$(date "+%F %T")
local_ip=$(ipconfig getifaddr en0 2>/dev/null || echo "无IP")

payload=$(cat <<EOF
{
  "attachments": [
    {"color": "#36a64f", "title": "💻 CrowdStrike 主机名更新通知"},
    {"color": "#36a64f", "title": "执行用户", "text": "${user_name}"},
    {"color": "#36a64f", "title": "部门", "text": "${dept_prefix}"},
    {"color": "#36a64f", "title": "原主机名", "text": "${old_hostname}"},
    {"color": "#36a64f", "title": "新主机名", "text": "${new_hostname}"},
    {"color": "#36a64f", "title": "CrowdStrike 状态", "text": "${cs_status}"},
    {"color": "#36a64f", "title": "IP地址", "text": "${local_ip}"},
    {"color": "#36a64f", "title": "执行时间", "text": "${timestamp}"}
  ]
}
EOF
)

curl -X POST -H "Content-Type: application/json" -d "${payload}" "$WEBHOOK_URL" &>/dev/null

echo ""
echo "📨 结果已推送至 ${ADMIN_NAME}，建议重启或继续安装 CrowdStrike Agent"
echo "按任意键退出..."
read -n1 -s
osascript -e 'tell application "Terminal" to close front window' 2>/dev/null
exit 0
