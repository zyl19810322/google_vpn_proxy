#!/bin/bash
xrinstall(){
pkg install -y screen
if [ ! -e xray ]; then
echo "下载 Xray-core arm64 中……"
curl -L -o xray-android-arm64-v8a.zip -# --retry 2 --insecure https://github.com/XTLS/Xray-core/releases/latest/download/Xray-android-arm64-v8a.zip
unzip xray-android-arm64-v8a.zip
chmod +x xray
fi
if [ ! -e xray ]; then
echo "Github直连失败，切换ghproxy中转"
curl -L -o xray-android-arm64-v8a.zip -# --retry 2 --insecure https://gh-proxy.com/https://github.com/XTLS/Xray-core/releases/latest/download/Xray-android-arm64-v8a.zip
unzip xray-android-arm64-v8a.zip
chmod +x xray
fi
if [ ! -e xray ]; then
echo "Xray下载失败，请在代理环境下运行脚本" && exit
fi
rm -f xray-android-arm64-v8a.zip README* LICENSE*
# 输入配置
read -p "设置 VLESS 监听端口（回车随机10000-65535）：" vless_port
if [ -z "$vless_port" ]; then
vless_port=$(shuf -i 10000-65535 -n 1)
fi
read -p "设置 VLESS UUID（回车自动生成UUID）：" vless_uuid
if [ -z "$vless_uuid" ]; then
# 生成随机UUID
vless_uuid=$(cat /proc/sys/kernel/random/uuid)
fi
echo "VLESS端口：$vless_port"
echo "VLESS UUID：$vless_uuid"
sleep 2
# 写入Xray config.json
cat > config.json <<EOF
{
  "inbounds": [
    {
      "port": $vless_port,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$vless_uuid"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp"
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {}
    }
  ],
  "dns": {
    "servers": [
      "8.8.8.8",
      "8.8.4.4"
    ]
  }
}
EOF
# 自启脚本，放到profile.d
cd /data/data/com.termux/files/usr/etc/profile.d
echo '#!/data/data/com.termux/files/usr/bin/bash' > xr.sh
echo 'screen -wipe' >> xr.sh
echo "screen -ls | grep Detached | cut -d. -f1 | awk '{print \$1}' | xargs kill" >> xr.sh
echo "screen -dmS xrscreen bash -c './xray run -c config.json'" >> xr.sh
chmod +x xr.sh
echo "===== 安装完成 ====="
echo "内网节点链接模板："
echo "vless://$vless_uuid@【本机局域网IP】:$vless_port?encryption=none&type=tcp#Termux-VLESS-LAN"
echo "快捷查看信息：bash gv.sh"
sleep 3
exit
}
uninstall(){
screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs kill
rm -f xray config.json gv.sh
echo "卸载完毕"
}
show_menu(){
# 生成gv.sh查看配置
cat > gv.sh <<EOF
#!/data/data/com.termux/files/usr/bin/bash
echo "==== 当前VLESS配置 ===="
port=\$(cat config.json | grep port | head -1 | awk '{print \$2}' | tr -d ',')
uuid=\$(cat config.json | grep id | head -1 | awk '{print \$2}' | tr -d '"')
echo "端口: \$port"
echo "UUID: \$uuid"
echo "节点链接：vless://\$uuid@你的手机内网IP:\$port?encryption=none&type=tcp#LAN-VLESS"
EOF
chmod +x gv.sh
clear
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Termux Xray VLESS局域网共享代理一键脚本"
echo "仅内网TCP VLESS，本机流量走系统已有VPN"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo " 1. 重置安装"
echo " 2. 删除卸载"
echo " 0. 退出"
echo "------------------------------------------------"
if [[ -e config.json ]]; then
vless_port_now=$(cat config.json | grep port | head -1 | awk '{print $2}' | tr -d ',')
vless_uuid_now=$(cat config.json | grep id | head -1 | awk '{print $2}' | tr -d '"')
echo "当前VLESS端口：$vless_port_now"
echo "当前VLESS UUID：$vless_uuid_now"
else
echo "未安装，请选择 1 进行安装"
fi
echo "------------------------------------------------"
read -p "请输入数字:" Input
case "$Input" in
 1 ) xrinstall;;
 2 ) uninstall;;
 * ) exit
esac
}
show_menu
