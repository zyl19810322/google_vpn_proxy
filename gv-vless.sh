#!/bin/bash
xrinstall(){
pkg install -y screen
if [ ! -e xray ]; then
echo "下载 xray 中……"
curl -L -o xray.zip -# --retry 2 --insecure https://raw.githubusercontent.com/zyl19810322/google_vpn_proxy/main/xray.zip
unzip xray.zip
chmod +x xray
fi
if [ ! -e xray ]; then
echo "xray下载失败，请在代理环境下运行脚本" && exit
fi
rm -f xray.zip
# 生成Reality密钥
KEY_OUT=$(./xray x25519)
privateKey=$(echo "$KEY_OUT" | sed -n 's/^PrivateKey: //p')
publicKey=$(echo "$KEY_OUT" | sed -n 's/^Password (PublicKey): //p')
shortId=$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')

# 端口设定：VLESS默认59322，SOCKS5默认1080，HTTP默认8080
read -p "设置 VLESS 监听端口（回车默认59322）：" vless_port
if [ -z "$vless_port" ]; then
vless_port=59322
fi
read -p "设置 VLESS UUID（回车自动生成UUID）：" vless_uuid
if [ -z "$vless_uuid" ]; then
vless_uuid=$(cat /proc/sys/kernel/random/uuid)
fi
read -p "设置 SOCKS5 监听端口（回车默认1080）：" socks_port
if [ -z "$socks_port" ]; then
socks_port=1080
fi
read -p "设置 HTTP 代理监听端口（回车默认8080）：" http_port
if [ -z "$http_port" ]; then
http_port=8080
fi

echo "================参数预览================"
echo "VLESS(Reality)端口：$vless_port"
echo "SOCKS5端口：$socks_port"
echo "HTTP代理端口：$http_port"
echo "VLESS UUID：$vless_uuid"
echo "Reality私钥：$privateKey"
echo "Reality公钥(pbk)：$publicKey"
echo "shortId：$shortId"
sleep 2

# 三合一 config.json
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
"show": false,
"dest": "www.apple.com:443",
"xver": 0,
"serverNames": ["www.apple.com"],
"privateKey": "$privateKey",
"shortIds": ["$shortId"]
}
}
},
{
"port": $socks_port,
"listen": "0.0.0.0",
"protocol": "socks",
"settings": {
"auth": "noauth",
"udp": true
}
},
{
"port": $http_port,
"listen": "0.0.0.0",
"protocol": "http",
"settings": {}
}
],
"outbounds": [
{
"tag": "direct",
"protocol": "freedom"
}
]
}
EOF

# 生成gv.sh管理脚本，菜单展示全部3个端口与链接
cat > gv.sh <<GVSCRIPT
#!/data/data/com.termux/files/usr/bin/bash
port="$vless_port"
socksport="$socks_port"
httpport="$http_port"
uuid="$vless_uuid"
pbk="$publicKey"
sid="$shortId"

vless_link="vless://\$uuid@内网IP:\$port?encryption=none&security=reality&type=tcp&pbk=\$pbk&sid=\$sid&sni=www.apple.com&fp=chrome&flow=xtls-rprx-vision#Google VPN"
socks_link="socks5://内网IP:\$socksport"
http_link="http://内网IP:\$httpport"

reset_install(){
  echo "⚠️ 重置安装，会重新生成密钥，旧配置失效！"
  read -p "确认继续？(y/N) " ans
  if [[ "\$ans" != "y" && "\$ans" != "Y" ]];then
    echo "已取消"
    sleep 1
    menu
    return
  fi
  bash "\$0"
}

uninstall_all(){
  echo "⚠️ 卸载将停止服务，删除所有配置文件！"
  read -p "确认卸载？(y/N) " ans
  if [[ "\$ans" != "y" && "\$ans" != "Y" ]];then
    echo "已取消"
    sleep 1
    menu
    return
  fi
  screen -S xrscreen -X quit >/dev/null 2>&1
  PID=\$(screen -ls | grep Detached | cut -d. -f1 | awk '{print \$1}')
  [ -n "\$PID" ] && echo "\$PID" | xargs kill
  rm -f xray config.json gv.sh
  rm -f /data/data/com.termux/files/usr/etc/profile.d/xr.sh
  echo "✅ 卸载完成，所有文件已清理"
  exit
}

menu(){
clear
echo "===== Xray代理管理菜单 ====="
echo "SOCKS5 端口: \$socksport"
echo "HTTP   端口: \$httpport"
echo "VLESS  端口: \$port"
echo "VLESS  UUID: \$uuid"
echo "VLESS  PBK: \$pbk"
echo "VLESS  shortId: \$sid"
echo "----------------------------------"
echo "1 重置安装（重新生成密钥与配置）"
echo "2 卸载全部"
echo "3 查看全部节点链接"
echo "0 退出"
echo "----------------------------------"
read -p "请选择：" opt
case \$opt in
1) reset_install;;
2) uninstall_all;;
3)
echo ""
echo "VLESS Reality 链接："
echo "\$vless_link"
echo ""
echo "SOCKS5 链接："
echo "\$socks_link"
echo ""
echo "HTTP代理链接："
echo "\$http_link"
echo ""
read -p "回车返回菜单"
menu
;;
*) exit;;
esac
}
menu
GVSCRIPT
chmod +x gv.sh

# termux profile自启配置
cd /data/data/com.termux/files/usr/etc/profile.d
echo '#!/data/data/com.termux/files/usr/bin/bash' > xr.sh
echo 'PID=$(screen -ls | grep Detached | cut -d. -f1 | awk "{print \$1}")' >> xr.sh
echo '[ -n "$PID" ] && echo "$PID" | xargs kill' >> xr.sh
echo "screen -dmS xrscreen bash -c './xray run -c config.json'" >> xr.sh
chmod +x xr.sh

echo "✅ 安装完成，日常管理: bash gv.sh"
sleep 1
exit
}

uninstall(){
screen -S xrscreen -X quit >/dev/null 2>&1
PID=$(screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}')
[ -n "$PID" ] && echo "$PID" | xargs kill
rm -f xray config.json gv.sh
rm -f /data/data/com.termux/files/usr/etc/profile.d/xr.sh
echo "✅ 卸载完毕，全部文件清理完成"
sleep 1
}

show_menu(){
clear
echo "===== Xray三合一（VLESS+HTTP+SOCKS5）安装 ====="
echo "1 安装"
echo "0 退出"
echo "-----------------------------"
read -p "请选择：" Input
case "$Input" in
1 ) xrinstall;;
* ) exit;;
esac
}
show_menu
