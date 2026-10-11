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
rm -f xray.zip README* LICENSE*

# 生成密钥
KEY_OUT=$(./xray x25519)
privateKey=$(echo "$KEY_OUT" | sed -n 's/^PrivateKey: //p')
publicKey=$(echo "$KEY_OUT" | sed -n 's/^Password (PublicKey): //p')
shortId=$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')

read -p "设置 VLESS 监听端口（回车随机10000-65535）：" vless_port
if [ -z "$vless_port" ]; then
vless_port=$(shuf -i 10000-65535 -n 1)
fi
read -p "设置 VLESS UUID（回车自动生成UUID）：" vless_uuid
if [ -z "$vless_uuid" ]; then
vless_uuid=$(cat /proc/sys/kernel/random/uuid)
fi

echo "VLESS端口：$vless_port"
echo "VLESS UUID：$vless_uuid"
echo "Reality私钥：$privateKey"
echo "Reality公钥(pbk)：$publicKey"
echo "shortId：$shortId"
sleep 2

# config.json
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

# ========= 生成gv.sh，菜单移除复制剪贴板选项 =========
cat > gv.sh <<GVSCRIPT
#!/data/data/com.termux/files/usr/bin/bash
# 硬编码保存参数，安装一次性写入
port="$vless_port"
uuid="$vless_uuid"
pbk="$publicKey"
sid="$shortId"
link="vless://\$uuid@你的手机内网IP:\$port?encryption=none&security=reality&type=tcp&pbk=\$pbk&sid=\$sid&sni=www.apple.com&fp=chrome&flow=xtls-rprx-vision#LAN-Reality"

# 重置安装函数
reset_install(){
  echo "⚠️ 重置安装，会重新生成密钥，旧配置失效！"
  read -p "确认继续？(y/N) " ans
  if [[ "\$ans" != "y" && "\$ans" != "Y" ]];then
    echo "已取消"
    sleep 1
    menu
    return
  fi
  # 调用主脚本重新执行安装
  bash "\$0"
}

# 卸载全部函数
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
echo "===== GV 节点管理菜单 ====="
echo "端口: \$port"
echo "UUID: \$uuid"
echo "PBK: \$pbk"
echo "shortId: \$sid"
echo "---------------------------"
echo "1 重置安装（重新生成密钥与配置）"
echo "2 卸载全部"
echo "3 查看完整节点链接"
echo "0 退出"
echo "---------------------------"
read -p "请选择：" opt
case \$opt in
1) reset_install;;
2) uninstall_all;;
3)
echo ""
echo "\$link"
echo ""
read -p "回车返回菜单"
menu
;;
0) exit;;
*) echo "输入错误";sleep 1;menu;;
esac
}
menu
GVSCRIPT
chmod +x gv.sh

# profile.d自启
cd /data/data/com.termux/files/usr/etc/profile.d
echo '#!/data/data/com.termux/files/usr/bin/bash' > xr.sh
echo 'PID=$(screen -ls | grep Detached | cut -d. -f1 | awk "{print \$1}")' >> xr.sh
echo '[ -n "$PID" ] && echo "$PID" | xargs kill' >> xr.sh
echo "screen -dmS xrscreen bash -c './xray run -c config.json'" >> xr.sh
chmod +x xr.sh

echo "===== 安装完成 ====="
echo "日常管理直接运行：bash gv.sh"
sleep 3
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
echo "===== 主安装管理菜单 ====="
echo "1 重置安装（重新生成密钥与配置）"
echo "2 卸载全部"
echo "0 退出"
echo "---------------------------"
read -p "请选择：" Input
case "$Input" in
1 ) xrinstall;;
2 ) uninstall;show_menu;;
0 ) exit;;
* ) echo "输入错误";sleep 1;show_menu;;
esac
}
show_menu
