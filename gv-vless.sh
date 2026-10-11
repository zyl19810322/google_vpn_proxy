#!/bin/bash
xrinstall(){
pkg install -y screen jq
if [ ! -e xray ]; then
echo "下载 Xray-core arm64 中……"
curl -L -o xray-android-arm64-v8a.zip -# --retry 2 --insecure https://raw.githubusercontent.com/zyl19810322/main/xray-android-arm64-v8a.zip
unzip xray-android-arm64-v8a.zip
mv xray-android-arm64-v8a xray 2>/dev/null
chmod +x xray
fi
if [ ! -e xray ]; then
echo "Xray下载失败，请检查网络" && exit
fi
rm -f xray-android-arm64-v8a.zip README* LICENSE*

echo "生成X25519公私钥对……"
KEY_OUT=$(./xray x25519)
privateKey=$(echo "$KEY_OUT" | sed -n 's/^PrivateKey: //p')
publicKey=$(echo "$KEY_OUT" | sed -n 's/^PublicKey: //p')

vless_uuid=$(./xray uuid)
shortId=$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')

read -p "设置 VLESS+Reality 端口(默认34345): " vless_port
if [ -z "$vless_port" ]; then
vless_port=34345
fi

echo
echo "==== 生成密钥参数 ===="
echo "端口         : $vless_port"
echo "UUID         : $vless_uuid"
echo "服务端私钥   : $privateKey"
echo "客户端pbk公钥: $publicKey"
echo "shortId(sid) : $shortId"
echo "SNI          : www.apple.com"
echo

# ========== config.json 更换为apple，无DNS ==========
cat > config.json <<EOF
{
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": $vless_port,
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
          "show": false,
          "dest": "www.apple.com:443",
          "xver": 0,
          "serverNames": ["www.apple.com"],
          "privateKey": "$privateKey",
          "shortIds": ["$shortId"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

# 生成gv.sh，sni替换为apple，带flow
cat > gv.sh <<GVSCRIPT
#!/data/data/com.termux/files/usr/bin/bash
set -e
pbk_val="$publicKey"
sid_val="$shortId"
uuid_val="$vless_uuid"
port_val="$vless_port"

echo "==== VLESS Reality 参数 ===="
echo "端口: \$port_val"
echo "UUID: \$uuid_val"
echo "pbk公钥: \$pbk_val"
echo "sid shortId: \$sid_val"
echo
echo "✅完整节点链接（把【IP】替换为Pixel内网IP）："
echo "vless://\$uuid_val@【IP】:\$port_val?encryption=none&security=reality&type=tcp&pbk=\$pbk_val&sid=\$sid_val&sni=www.apple.com&fp=chrome&flow=xtls-rprx-vision#GoogleVPN-VLESS"
GVSCRIPT
chmod +x gv.sh

# termux开机自启
mkdir -p /data/data/com.termux/files/home/.config/termux/boot
cat > /data/data/com.termux/files/home/.config/termux/boot/start-xray.sh <<BOOT
#!/data/data/com.termux/files/usr/bin/bash
cd \$HOME
screen -S xrscreen -dm ./xray run -c config.json
BOOT
chmod +x /data/data/com.termux/files/home/.config/termux/boot/start-xray.sh

echo "===== 安装完成 ====="
echo "1. 校验配置： ./xray test -c config.json"
echo "2. 前台启动： ./xray run -c config.json"
echo "3. 后台screen启动：screen -S xrscreen ./xray run -c config.json"
echo "4. 查看节点链接： bash gv.sh"
echo "⚠️仅内网局域网使用！"
sleep 3
exit
}

uninstall(){
screen -ls | grep xrscreen | awk '{print $1}' | xargs -I{} screen -S {} -X quit
rm -f xray config.json gv.sh
rm -f /data/data/com.termux/files/home/.config/termux/boot/start-xray.sh
echo "卸载完成，文件全部清理"
}

show_menu(){
clear
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "      内网 VLESS+Reality 一键部署脚本"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo " 1. 一键安装/重置配置"
echo " 2. 卸载全部文件"
echo " 0. 退出脚本"
echo "------------------------------------------------"
read -p "请输入选项:" opt
case $opt in
1) xrinstall;;
2) uninstall;;
0) exit;;
*) echo "输入错误";sleep 1;show_menu;;
esac
}
show_menu
