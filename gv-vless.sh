#!/bin/bash
xrinstall(){
pkg install -y screen
if [ ! -e xray ]; then
echo "下载 Xray-core arm64 中……"
# 从你的github仓库下载
curl -L -o xray-android-arm64-v8a.zip -# --retry 2 --insecure https://raw.githubusercontent.com/zyl19810322/google_vpn_proxy/main/xray-android-arm64-v8a.zip
unzip xray-android-arm64-v8a.zip
cp -r xray-android-arm64-v8a/* ./
rm -rf xray-android-arm64-v8a
chmod +x xray
fi
if [ ! -e xray ]; then
echo "Github直连失败，切换ghproxy中转"
curl -L -o xray-android-arm64-v8a.zip -# --retry 2 --insecure https://gh-proxy.com/https://raw.githubusercontent.com/zyl19810322/google_vpn_proxy/main/xray-android-arm64-v8a.zip
unzip xray-android-arm64-v8a.zip
cp -r xray-android-arm64-v8a/* ./
rm -rf xray-android-arm64-v8a
chmod +x xray
fi
if [ ! -e xray ]; then
echo "Xray下载失败，请在代理环境下运行脚本" && exit
fi
rm -f xray-android-arm64-v8a.zip README* LICENSE*

# ========== 新增：自动生成Reality密钥对 ==========
KEY_OUT=$(./xray x25519)
privateKey=$(echo "$KEY_OUT" | sed -n 's/^PrivateKey: //p')
publicKey=$(echo "$KEY_OUT" | sed -n 's/^PublicKey: //p')
# 随机生成shortId 16位十六进制
shortId=$(openssl rand -hex 8)

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
echo "Reality私钥：$privateKey"
echo "Reality公钥(pbk)：$publicKey"
echo "shortId：$shortId"
sleep 2

# ========== 写入Reality版本 config.json ==========
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

# 自启脚本，放到profile.d
cd /data/data/com.termux/files/usr/etc/profile.d
echo '#!/data/data/com.termux/files/usr/bin/bash' > xr.sh
echo 'screen -wipe' >> xr.sh
echo "screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs kill" >> xr.sh
echo "screen -dmS xrscreen bash -c './xray run -c config.json'" >> xr.sh
chmod +x xr.sh

echo "===== 安装完成 ====="
echo "内网Reality节点链接模板："
echo "vless://$vless_uuid@【本机局域网IP】:$vless_port?encryption=none&security=reality&type=tcp&pbk=$publicKey&sid=$shortId&sni=www.apple.com&fp=chrome&flow=xtls-rprx-vision#Termux-Reality-LAN"
echo "快捷查看信息：bash gv.sh"
sleep 3
exit
}
uninstall(){
screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs kill
rm -f xray config.json gv.sh
rm -f /data/data/com.termux/files/usr/etc/profile.d/xr.sh
echo "卸载完毕"
}
show_menu(){
# ========== 更新gv.sh，读取Reality全部参数 ==========
cat > gv.sh <<GVSCRIPT
#!/data/data/com.termux/files/usr/bin/bash
echo "==== 当前VLESS-Reality配置 ===="
port=\$(cat config.json | grep port | head -1 | awk '{print \$2}' | tr -d ',')
uuid=\$(cat config.json | grep id | head -1 | awk '{print \$2}' | tr -d '"')
privKey=\$(cat config.json | grep privateKey | head -1 | awk '{print \$2}' | tr -d '",')
sid=\$(cat config.json | grep shortIds | grep -Eo '"[0-9a-f]+"' | tr -d '"')
# 用xray计算公钥
pbk=\$(./xray x25519 -i "\$privKey" | sed -n 's/^PublicKey: //p')
echo "端口: \$port"
echo "UUID: \$uuid"
echo "Reality PBK公钥: \$pbk"
echo "shortId: \$sid"
echo
echo "节点链接：vless://\$uuid@你的手机内网IP:\$port?encryption=none&security=reality&type=tcp&pbk=\$pbk&sid=\$sid&sni=www.apple.com&fp=chrome&flow=xtls-rprx-vision#LAN-Reality"
GVSCRIPT
chmod +x gv.sh
clear
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Termux Xray VLESS-Reality 局域网代理一键脚本"
echo "Xray包来自 zyl19810322/google_vpn_proxy"
echo "仅内网TCP Reality，本机流量走系统已有VPN"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo " 1. 重置安装"
echo " 2. 删除卸载"
echo " 0. 退出"
echo "------------------------------------------------"
if [[ -e config.json ]]; then
vless_port_now=$(cat config.json | grep port | head -1 | awk '{print $2}' | tr -d ',')
vless_uuid_now=$(cat config.json | grep id | head -1 | awk '{print $2}' | tr -d '"')
privKey_now=$(cat config.json | grep privateKey | head -1 | awk '{print $2}' | tr -d '",')
# 读取公钥
pbk_now=$(./xray x25519 -i "$privKey_now" | sed -n 's/^PublicKey: //p')
sid_now=$(cat config.json | grep shortIds | grep -Eo '"[0-9a-f]+"' | tr -d '"')
echo "当前VLESS端口：$vless_port_now"
echo "当前VLESS UUID：$vless_uuid_now"
echo "Reality PBK公钥：$pbk_now"
echo "shortId：$sid_now"
else
echo "未安装，请选择 1 进行安装"
fi
echo "------------------------------------------------"
read -p "请输入数字:" Input
case "$Input" in
1 ) xrinstall;;
2 ) uninstall;;
0 ) exit;;
* ) echo "输入错误";sleep 1;show_menu;;
esac
}
show_menu
