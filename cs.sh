#!/bin/bash

# 定义变量
DOWNLOAD_URL="https://s3-public-test1.s3.ap-northeast-1.amazonaws.com/crowdstrike/FalconSensorMacOS.MaverickGyr.pkg"
CCID="E3E08A20CAE84445821F3AC16D1C2B53-B5"
INSTALLER_PATH="/tmp/FalconSensorMacOS.MaverickGyr.pkg"

# 检查是否具有管理员权限
if [ "$(id -u)" -ne 0 ]; then
  echo "此脚本需要管理员权限，请使用 sudo 运行。"
  exit 1
fi

# 创建临时目录并设置权限
mkdir -p /tmp/crowdstrike
chmod 700 /tmp/crowdstrike

# 下载安装包
echo "正在下载 Crowdstrike Falcon Sensor 安装包..."
curl -L -o "$INSTALLER_PATH" "$DOWNLOAD_URL"

# 检查下载是否成功
if [ ! -f "$INSTALLER_PATH" ]; then
  echo "下载失败，请检查 URL 是否正确。"
  exit 1
fi

echo "下载完成。"

# 安装 Crowdstrike Falcon Sensor
echo "正在安装 Crowdstrike Falcon Sensor..."
installer -pkg "$INSTALLER_PATH" -target /

# 检查安装是否成功
if [ $? -ne 0 ]; then
  echo "安装失败，请检查安装包是否损坏。"
  exit 1
fi

echo "安装完成。"

# 配置 CCID
echo "正在配置 CCID..."
/Library/CS/falconctl config --cid="$CCID"

# 检查配置是否成功
if [ $? -ne 0 ]; then
  echo "配置 CCID 失败，请检查权限。"
  exit 1
fi

echo "CCID 配置完成。"

# 配置自动更新
echo "正在配置自动更新..."
/Library/CS/falconctl config --auto-updates=true

# 检查配置是否成功
if [ $? -ne 0 ]; then
  echo "配置自动更新失败，请检查权限。"
  exit 1
fi

echo "自动更新配置完成。"

# 配置日志级别
echo "正在配置日志级别..."
/Library/CS/falconctl config --log-level=info

# 检查配置是否成功
if [ $? -ne 0 ]; then
  echo "配置日志级别失败，请检查权限。"
  exit 1
fi

echo "日志级别配置完成。"

# 清理下载的安装包
echo "清理下载的安装包..."
rm -f "$INSTALLER_PATH"

echo "Crowdstrike Falcon Sensor 安装和配置完成。"
