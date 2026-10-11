#!/bin/bash
xrinstall(){
pkg install -y screen jq
if [ ! -e xray ]; then
echo "下载 Xray-core arm64 中……"
curl -L -o xray-android-arm64-v8a.zip -# --retry 2 --insecure https://raw.githubusercontent.com/zyl19810322/google_vpn_proxy/main/Xray-android-arm64-v8a.zip
unzip xray-android-arm64-v8a.zip
mv xray-android-arm64-v8a xray 2>/dev/null
chmod +x xray
fi
if [ ! -e xray ]; then
echo "Github直连失败，切换ghproxy中转"
curl -L -o xray-android-arm64-v8a.zip -# --retry 2 --insecure https://gh-proxy.com/https://raw.githubusercontent.com/zyl19810322/google_vpn_proxy/main/Xray-android-arm64-v8a.zip
unzip xray-android-arm64-v8a.zip
mv xray-android-arm64-v8a xray 2>/dev/null
chmod +x xray
fi
if [ ! -e xray ]; then
echo "Xray下载失败，请在代理环境下运行脚本" && exit
fi
rm -f xray-android-arm64-v8a.zip README* LICENSE*

echo "生成X25519公私钥……"
KEY_OUT=$(./xray x25519)
privateKey=$(echo "$KEY_OUT" | sed -n 's/^PrivateKey: //p')
publicKey=$(echo "$KEY_OUT" | sed -n 's/^Password (PublicKey): //p')

vless_uuid=$(./xray uuid)
shortId=$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')

read -p "设置 VLESS+Reality 监听端口（回车随机10000‑65535）：" vless_port
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

# gv.sh 使用jq解析JSON，彻底解决多行json错乱问题
cat > gv.sh <<'GVSCRIPT'
#!/data/data/com.termux/files/usr/bin/bash
set -e
if [ ! -f config.json ];then
    echo "错误：找不到 config.json，请先完成安装"
    exit 1
fi
port=$(jq '.inbounds[0].port' config.json)
uuid=$(jq -r '.inbounds[0].settings.clients[0].id' config.json)
privkey=$(jq -r '.inbounds[0].streamSettings.realitySettings.privateKey' config.json)
shortid=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[0]' config.json)
pbk=$(./xray x25519 -private "$privkey" 2>/dev/null | sed -n 's/^Password (PublicKey): //p')
sni="www.microsoft.com"
fp="chrome"
echo "==== 当前VLESS+Reality配置 ===="
echo "端口: $port"
echo "UUID: $uuid"
echo "服务端私钥: $privkey"
echo "pbk公钥: $pbk"
echo "sid shortId: $shortid"
echo
echo "节点链接："
echo "vless://$uuid@你的手机内网IP:$port?encryption=none&security=reality&type=tcp&pbk=$pbk&sid=$shortid&sni=$sni&fp=$fp#LAN‑VLESS‑Reality"
echo
echo "⚠️ 提示：把【你的手机内网IP】替换成Termux手机局域网IP"
GVSCRIPT
chmod +x gv.sh

cd /data/data/com.termux/files/usr/etc/profile.d
echo '#!/data/data/com.termux/files/usr/bin/bash' > xr.sh
echo 'screen -wipe' >> xr.sh
echo "screen -ls | grep Detached | cut -d. -f1 | awk '{print \$1}' | xargs kill" >> xr.sh
echo "screen -dmS xrscreen bash -c './xray run -c config.json'" >> xr.sh
chmod +x xr.sh

echo "===== VLESS+Reality 安装完成 ====="
echo "运行命令 bash gv.sh 查看完整节点链接"
echo "👉霓虹络直接粘贴导入，无需任何证书！"
sleep 3
exit
}

uninstall(){
screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs kill
rm -f xray config.json gv.sh
rm -f /data/data/com.termux/files/usr/etc/profile.d/xr.sh
echo "卸载完成，已清理所有文件与自启项"
}

show_menu(){
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
port_now=$(jq '.inbounds[0].port' config.json)
uuid_now=$(jq -r '.inbounds[0].settings.clients[0].id' config.json)
echo "当前VLESS+Reality端口：$port_now"
echo "当前UUID：$uuid_now"
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
