#!/bin/bash
# CrowdStrike 部署前主机名设置 + Webhook 通知脚本
# 适用于 macOS 环境
# 支持双击运行

# 检查是否在终端中运行，如果不是则打开终端
if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    # 不在终端中运行，打开终端并执行
    osascript -e 'tell application "Terminal" to do script "'"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"'"'
    exit 0
fi

WEBHOOK_URL="https://twqnhk7kyg.sg.larksuite.com/base/automation/webhook/event/Ieh5acpYhwFEM9hn58Qlcfmwgof"   # ← 请替换为你的 Webhook 地址
ADMIN_NAME="SecurityOps"

clear
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              内部终端设备主机名称统一规范设置工具              ║"
echo "║                    CrowdStrike EDR 部署前准备                ║"
echo "║                        适用于 macOS 环境                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 请选择你的部门："
echo ""
echo "   1️⃣  产研团队"
echo "   2️⃣  风控团队"
echo "   3️⃣  市场运营团队"
echo "   4️⃣  HR团队"
echo "   5️⃣  Web3团队"
echo "   6️⃣  安全团队"
echo "   7️⃣  运维团队"
echo "   8️⃣  客服团队"
echo "   9️⃣  财务团队"
echo ""
read -p "👉 请输入部门编号 (1-9): " dept_num

# 根据输入编号映射部门前缀
case $dept_num in
  1) dept_prefix="Dev";;
  2) dept_prefix="Ris";;
  3) dept_prefix="Mkt";;
  4) dept_prefix="Hr";;
  5) dept_prefix="Web3";;
  6) dept_prefix="Sec";;
  7) dept_prefix="Ops";;
  8) dept_prefix="CS";;
  9) dept_prefix="Fin";;
  *) echo ""
     echo "❌ 输入错误！请输入 1-9 之间的数字"
     echo ""
     echo "按任意键退出..."
     read -n 1 -s
     osascript -e 'tell application "Terminal" to close front window' 2>/dev/null
     exit 1;;
esac

# 获取当前用户名与旧主机名
user_name=$(whoami)
old_hostname=$(scutil --get ComputerName 2>/dev/null)

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                        当前系统信息                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "🖥️  当前主机名：${old_hostname}"
echo "👤 当前用户名：${user_name}"
echo "🏢 选择部门：${dept_prefix}"
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                        主机名设置选项                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "   1️⃣  使用当前用户名：${user_name}"
echo "   2️⃣  输入其他用户名（需与 Lark 名称保持一致）"
echo ""
read -p "👉 请选择 (1/2): " use_username

# 获取设备型号（原始格式）
device_model=$(system_profiler SPHardwareDataType | grep "Model Name" | awk -F': ' '{print $2}' 2>/dev/null)

if [[ "$use_username" == "1" || "$use_username" == "一" ]]; then
  new_hostname="${dept_prefix}-${user_name}-${device_model}"
  echo ""
  echo "✅ 已选择使用当前用户名"
  echo "📝 新主机名：${new_hostname}"
else
  echo ""
  echo "⚠️  重要提醒：主机名需要与 Lark 中的名称保持一致"
  echo ""
  read -p "👉 请输入用户名（将自动添加部门前缀）: " custom_username
  new_hostname="${dept_prefix}-${custom_username}-${device_model}"
  echo ""
  echo "✅ 已设置自定义用户名"
  echo "📝 新主机名：${new_hostname}"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                        确认修改                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 修改摘要："
echo "   🏢 部门：${dept_prefix}"
echo "   🖥️  原主机名：${old_hostname}"
echo "   ✨ 新主机名：${new_hostname}"
echo ""
read -p "👉 确认执行修改？(y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo ""
  echo "❌ 已取消修改"
  echo ""
  echo "按任意键退出..."
  read -n 1 -s
  osascript -e 'tell application "Terminal" to close front window' 2>/dev/null
  exit 0
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                        权限验证                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "🔐 修改主机名需要管理员权限"
echo "💡 请在下方输入您的电脑系统密码（输入时不会显示字符，输入完成后按回车）"
echo ""

# 执行修改（需要sudo权限）
sudo scutil --set ComputerName "$new_hostname"
sudo scutil --set HostName "$new_hostname"
sudo scutil --set LocalHostName "$new_hostname"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                        修改完成                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ 主机名修改成功！"
echo "🖥️  新主机名：$(scutil --get ComputerName)"

# 检查 CrowdStrike 是否安装
if [ -d "/Applications/Falcon.app" ] || [ -f "/Library/CS/falconctl" ]; then
  cs_status="✅ CrowdStrike 已安装"
else
  cs_status="⚠️ CrowdStrike 未安装"
fi

# 获取当前时间与IP
timestamp=$(date "+%Y-%m-%d %H:%M:%S")
local_ip=$(ipconfig getifaddr en0 2>/dev/null)
# 使用之前获取的设备型号，去除空格替换为连字符
computer_model=$(echo "$device_model" | sed 's/-/ /g')

# 构造 Webhook 消息
payload=$(cat <<EOF
{
  "attachments": [
    {
      "color": "#36a64f",
      "title": "💻 CrowdStrike 主机名更新通知"
    },
    {
      "color": "#36a64f",
      "title": "执行用户",
      "text": "${user_name}"
    },
    {
      "color": "#36a64f",
      "title": "部门",
      "text": "${dept_prefix}"
    },
    {
      "color": "#36a64f",
      "title": "原主机名",
      "text": "${old_hostname}"
    },
    {
      "color": "#36a64f",
      "title": "新主机名",
      "text": "${new_hostname}"
    },
    {
      "color": "#36a64f",
      "title": "命名方式",
      "text": "$(if [[ "$use_username" == "1" ]]; then echo "使用当前用户名"; else echo "自定义输入"; fi)"
    },
    {
      "color": "#36a64f",
      "title": "CrowdStrike 状态",
      "text": "${cs_status}"
    },
    {
      "color": "#36a64f",
      "title": "IP地址",
      "text": "${local_ip}"
    },
    {
      "color": "#36a64f",
      "title": "设备型号",
      "text": "${computer_model}"
    },
    {
      "color": "#36a64f",
      "title": "执行时间",
      "text": "${timestamp}"
    }
  ]
}
EOF
)

# 发送通知
curl -X POST -H "Content-Type: application/json" -d "${payload}" "$WEBHOOK_URL" >/dev/null 2>&1

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                        操作完成                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📨 已发送修改结果至管理员 ${ADMIN_NAME}"
echo "🔄 建议重新启动电脑或继续安装 CrowdStrike Agent"
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                        感谢使用                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "按任意键退出..."
read -n 1 -s

# 自动关闭终端窗口
osascript -e 'tell application "Terminal" to close front window' 2>/dev/null
exit 0
