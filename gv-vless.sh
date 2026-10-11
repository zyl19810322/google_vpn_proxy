#!/bin/bash
xrinstall(){
pkg install -y screen
# 安装剪贴板依赖
pkg install -y termux-api
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
# ========== 生成Reality密钥对 ==========
KEY_OUT=$(./xray x25519)
privateKey=$(echo "$KEY_OUT" | sed -n 's/^PrivateKey: //p')
publicKey=$(echo "$KEY_OUT" | sed -n 's/^Password (PublicKey): //p')
# 随机生成shortId 16位十六进制
shortId=$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')
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
# ========== 纯净标准Xray config.json ==========
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
# ========= gv.sh：仅硬编码保存参数，只存变量，不做菜单 =========
cat > gv.sh <<GVSCRIPT
#!/data/data/com.termux/files/usr/bin/bash
port="$vless_port"
uuid="$vless_uuid"
pbk="$publicKey"
sid="$shortId"
link="vless://\$uuid@你的手机内网IP:\$port?encryption=none&security=reality&type=tcp&pbk=\$pbk&sid=\$sid&sni=www.apple.com&fp=chrome&flow=xtls-rprx-vision#LAN-Reality"
GVSCRIPT
chmod +x gv.sh
# 自启脚本，放到profile.d
cd /data/data/com.termux/files/usr/etc/profile.d
echo '#!/data/data/com.termux/files/usr/bin/bash' > xr.sh
echo 'PID=$(screen -ls | grep Detached | cut -d. -f1 | awk "{print \$1}")' >> xr.sh
echo '[ -n "$PID" ] && echo "$PID" | xargs kill' >> xr.sh
echo "screen -dmS xrscreen bash -c './xray run -c config.json'" >> xr.sh
chmod +x xr.sh
echo "===== 安装完成 ====="
echo "快捷查看信息：bash gv.sh （只输出参数，不是菜单）"
sleep 3
exit
}
uninstall(){
# 1. 关闭所有screen会话
screen -S xrscreen -X quit >/dev/null 2>&1
# 清理残留detached会话
PID=$(screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}')
[ -n "$PID" ] && echo "$PID" | xargs kill
# 2. 删除全部业务文件
rm -f xray config.json gv.sh
# 3. 删除profile.d自启脚本（重点，解决卸载残留）
rm -f /data/data/com.termux/files/usr/etc/profile.d/xr.sh
echo "✅ 卸载完毕，所有文件、自启脚本、screen会话全部清理"
sleep 1
}
show_menu(){
clear
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Termux Xray VLESS-Reality 局域网代理一键脚本"
echo "Xray包来自 zyl19810322/google_vpn_proxy"
echo "仅内网TCP Reality，本机流量走系统已有VPN"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo " 1. 重置安装"
echo " 2. 删除卸载"
echo " 3. 查看当前节点信息"
echo " 4. 复制节点链接到剪贴板"
echo " 0. 退出"
echo "------------------------------------------------"
# 判断是否已安装
if [[ -e gv.sh ]]; then
source ./gv.sh
echo "当前VLESS端口：$port"
echo "当前VLESS UUID：$uuid"
echo "Reality PBK公钥：$pbk"
echo "shortId：$sid"
else
echo "⚠️ 未安装，请选择 1 进行安装"
fi
echo "------------------------------------------------"
read -p "请输入数字:" Input
case "$Input" in
1 ) xrinstall;;
2 ) uninstall;show_menu;;
3 )
source ./gv.sh
echo ""
echo "==== 完整节点链接 ===="
echo "$link"
echo ""
read -p "回车返回菜单"
show_menu
;;
4 )
source ./gv.sh
# 复制到剪贴板
echo "$link" | termux-clipboard-set
echo "✅ 链接已复制到安卓剪贴板！"
echo "$link"
read -p "回车返回菜单"
show_menu
;;
0 ) exit;;
* ) echo "输入错误";sleep 1;show_menu;;
esac
}
show_menu
