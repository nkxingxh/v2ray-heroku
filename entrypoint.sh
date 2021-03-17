#! /bin/bash
set -ex
if [[ -z "${VER}" ]]; then
  VER="latest"
fi
echo ${VER}

if [[ -z "${protocol}" ]]; then
  protocol="vmess"
fi
echo ${protocol}

if [[ -z "${UUID}" ]]; then
  UUID="770742b4-b3ee-4edd-b560-480d05da50a1"
fi
echo ${UUID}

if [[ -z "${AlterID}" ]]; then
  AlterID="24"
fi
echo ${AlterID}

if [[ -z "${V2_Path}" ]]; then
  V2_Path="/stream"
fi
echo ${V2_Path}

if [[ -z "${V2_QR_Path}" ]]; then
  V2_QR_Path="ch874gek"
fi
echo ${V2_QR_Path}

rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
date -R


if [ "$VER" = "latest" ]; then
  V2RAY_URL="https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip"
else
  V_VER="v$VER"
  V2RAY_URL="https://github.com/v2fly/v2ray-core/releases/download/$V_VER/v2ray-linux-64.zip"
fi

mkdir /v2raybin
cd /v2raybin
echo ${V2RAY_URL}
wget --no-check-certificate -qO 'v2ray.zip' ${V2RAY_URL}
unzip v2ray.zip
rm -rf v2ray.zip

C_VER="v1.0.3"
mkdir /caddybin
cd /caddybin
CADDY_URL="https://github.com/caddyserver/caddy/releases/download/$C_VER/caddy_${C_VER}_linux_amd64.tar.gz"
echo ${CADDY_URL}
wget --no-check-certificate -qO 'caddy.tar.gz' ${CADDY_URL}
tar xvf caddy.tar.gz
rm -rf caddy.tar.gz
chmod +x caddy

cd /wwwroot
tar xvf wwwroot.tar.gz
rm -rf wwwroot.tar.gz

cat <<-EOF > /v2raybin/config.json
{
    "log":{
        "loglevel":"warning"
    },
    "inbound":{
        "protocol":"${protocol}",
        "listen":"127.0.0.1",
        "port":2333,
        "settings":{
            "clients":[
                {
                    "id":"${UUID}",
                    "level":1,
                    "alterId":${AlterID}
                }
            ],
            "disableInsecureEncryption": ${disableInsecureEncryption}
        },
        "streamSettings":{
            "network":"${network}",
            "${network}Settings":{
                "path":"${V2_Path}"
            }
        }
    },
    "outbound":{
        "protocol":"freedom",
        "settings":{
        }
    }
}
EOF

echo /v2raybin/config.json
cat /v2raybin/config.json

cat <<-EOF > /caddybin/Caddyfile
http://0.0.0.0:${PORT}
{
	root /wwwroot
	index index.html
	timeouts none
	proxy ${V2_Path} localhost:2333 {
		websocket
		header_upstream -Origin
	}
}
EOF

cat <<-EOF > /v2raybin/vmess.json
{
    "v": "2",
    "ps": "${AppName}.herokuapp.com",
    "add": "${AppName}.herokuapp.com",
    "port": "443",
    "id": "${UUID}",
    "aid": "${AlterID}",
    "net": "ws",
    "type": "none",
    "host": "",
    "path": "${V2_Path}",
    "tls": "tls"
}
EOF

if [ "$AppName" = "no" ]; then
  echo "不生成二维码"
else
  mkdir /wwwroot/${V2_QR_Path}
  vmess="vmess://$(cat /v2raybin/vmess.json | base64 -w 0)"
  Linkbase64=$(echo -n "${vmess}" | tr -d '\n' | base64 -w 0)
  echo "${Linkbase64}" | tr -d '\n' > /wwwroot/${V2_QR_Path}/index.html
  echo -n "${vmess}" | qrencode -s 6 -o /wwwroot/${V2_QR_Path}/v2.png
fi

cd /v2raybin
./v2ray -config config.json &
cd /caddybin
./caddy -conf="Caddyfile"
