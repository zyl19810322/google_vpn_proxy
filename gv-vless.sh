#!/bin/bash
xrinstall(){
pkg install -y screen openssl
if [ ! -e xray ]; then
echo "下载 Xray-core arm64 中……"
curl -L -o xray-android-arm64-v8a.zip -# --retry 2 --insecure https://raw.githubusercontent.com/zyl19810322/google_vpn_proxy/main/Xray-android-arm64-v8a.zip
unzip xray-android-arm64-v8a.zip
chmod +x xray
fi
if [ ! -e xray ]; then
echo "Github直连失败，切换ghproxy中转"
curl -L -o xray-android-arm64-v8a.zip -# --retry 2 --insecure https://gh-proxy.com/https://raw.githubusercontent.com/zyl19810322/google_vpn_proxy/main/Xray-android-arm64-v8a.zip
unzip xray-android-arm64-v8a.zip
chmod +x xray
fi
if [ ! -e xray ]; then
echo "Xray下载失败，请在代理环境下运行脚本" && exit
fi
rm -f xray-android-arm64-v8a.zip README* LICENSE*

# 自动生成 Reality X25519公私钥
echo "生成X25519公私钥……"
KEY_OUT=$(./xray x25519)
privateKey=$(echo "$KEY_OUT" | grep "Private key" | awk '{print $3}')
publicKey=$(echo "$KEY_OUT" | grep "Public key" | awk '{print $3}')

# 生成UUID
vless_uuid=$(./xray uuid)
# 生成shortId，8字节 16位16进制
shortId=$(openssl rand -hex 8)

# 端口交互
read -p "设置 VLESS+Reality 监听端口（回车随机10000-65535）：" vless_port
if [ -z "$vless_port" ]; then
vless_port=$(shuf -i 10000-65535 -n 1)
fi

echo
echo "==== 生成参数 ===="
echo "端口         : $vless_port"
echo "UUID         : $vless_uuid"
echo "服务端私钥   : $privateKey"
echo "客户端公钥pbk: $publicKey"
echo "shortId(sid) : $shortId"
echo "SNI          : www.microsoft.com"
echo
sleep 2

# 写入Reality config.json
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
            "id": "$vless_uuid",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.microsoft.com:443",
          "serverNames": ["www.microsoft.com"],
          "privateKey": "$privateKey",
          "shortIds": ["$shortId"],
          "fingerprint": "chrome"
        }
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

# 开机自启脚本写入profile.d
cd /data/data/com.termux/files/usr/etc/profile.d
echo '#!/data/data/com.termux/files/usr/bin/bash' > xr.sh
echo 'screen -wipe' >> xr.sh
echo "screen -ls | grep Detached | cut -d. -f1 | awk '{print \$1}' | xargs kill" >> xr.sh
echo "screen -dmS xrscreen bash -c './xray run -c config.json'" >> xr.sh
chmod +x xr.sh

echo "===== VLESS+Reality 安装完成 ====="
echo "内网节点链接模板："
echo "vless://$vless_uuid@【本机局域网IP】:$vless_port?encryption=none&security=reality&type=tcp&pbk=$publicKey&sid=$shortId&sni=www.microsoft.com&fp=chrome#Termux-VLESS-Reality-LAN"
echo "👉霓虹络直接粘贴导入，无需任何证书！"
echo "快捷查看配置命令：bash gv.sh"
sleep 3
exit
}

uninstall(){
# 杀掉xray screen会话
screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs kill
rm -f xray config.json gv.sh
rm -f /data/data/com.termux/files/usr/etc/profile.d/xr.sh
echo "卸载完成，已清理所有文件与自启项"
}

show_menu(){
# 生成gv.sh查看配置脚本
cat > gv.sh <<EOF
#!/data/data/com.termux/files/usr/bin/bash
echo "==== 当前VLESS+Reality配置 ===="
port=\$(cat config.json 2>/dev/null | grep port | head -1 | awk '{print \$2}' | tr -d ',')
uuid=\$(cat config.json 2>/dev/null | grep id | head -1 | awk '{print \$2}' | tr -d '"')
privkey=\$(cat config.json 2>/dev/null | grep privateKey | head -1 | awk '{print \$2}' | tr -d '"')
pbk=\$(./xray x25519 | grep "Public key" | awk '{print \$3}')
shortid=\$(cat config.json 2>/dev/null | grep shortIds -A1 | grep -v shortIds | awk '{print \$1}' | tr -d '["],')
sni=www.microsoft.com
fp=chrome
echo "端口: \$port"
echo "UUID: \$uuid"
echo "服务端私钥: \$privkey"
echo "pbk公钥: \$pbk"
echo "sid shortId: \$shortid"
echo "节点链接：vless://\$uuid@你的手机内网IP:\$port?encryption=none&security=reality&type=tcp&pbk=\$pbk&sid=\$shortid&sni=\$sni&fp=\$fp#LAN-VLESS-Reality"
EOF
chmod +x gv.sh

clear
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Google_VPN局域网共享代理【VLESS+Reality版】"
echo "Xray内核 | 无需证书 | 内网局域网专用"
echo "项目地址：github.com/zyl19810322/google_vpn_proxy"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo " 1. 重置安装 VLESS+Reality"
echo " 2. 删除卸载"
echo " 0. 退出脚本"
echo "------------------------------------------------"
if [[ -e config.json ]]; then
vless_port_now=$(cat config.json | grep port | head -1 | awk '{print $2}' | tr -d ',')
vless_uuid_now=$(cat config.json | grep id | head -1 | awk '{print $2}' | tr -d '"')
echo "当前VLESS+Reality端口：$vless_port_now"
echo "当前UUID：$vless_uuid_now"
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
