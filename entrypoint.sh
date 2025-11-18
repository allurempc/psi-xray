#!/bin/bash
set -e

PORT="${PORT:-21000}"
UUID="${UUID:-$(cat /proc/sys/kernel/random/uuid)}"
PUBLIC_HOST="${PUBLIC_HOST:-CHANGE_ME}"

echo "=== Psiphon + Xray inside container ==="
echo "VLESS port: ${PORT}"
echo "UUID: ${UUID}"
echo "PUBLIC_HOST (for URL): ${PUBLIC_HOST}"

mkdir -p /opt/psiphon /usr/local/etc/xray

cat > /opt/psiphon/psiphon.config << 'CFG'
{
  "LocalHttpProxyPort": 8081,
  "LocalSocksProxyPort": 1081,
  "PropagationChannelId": "FFFFFFFFFFFFFFFF",
  "SponsorId":            "FFFFFFFFFFFFFFFF",
  "RemoteServerListUrl": "https://s3.amazonaws.com/psiphon/web/mjr4-p23r-puwl/server_list_compressed",
  "RemoteServerListDownloadFilename": "server_list_compressed",
  "RemoteServerListSignaturePublicKey": "MIICIDANBgkqhkiG9w0BAQEFAAOCAg0AMIICCAKCAgEAt7Ls+/39r+T6zNW7GiVpJfzq/xvL9SBH5rIFnk0RXYEYavax3WS6HOD35eTAqn8AniOwiH+DOkvgSKF2caqk/y1dfq47Pdymtwzp9ikpB1C5OfAysXzBiwVJlCdajBKvBZDerV1cMvRzCKvKwRmvDmHgphQQ7WfXIGbRbmmk6opMBh3roE42KcotLFtqp0RRwLtcBRNtCdsrVsjiI1Lqz/lH+T61sGjSjQ3CHMuZYSQJZo/KrvzgQXpkaCTdbObxHqb6/+i1qaVOfEsvjoiyzTxJADvSytVtcTjijhPEV6XskJVHE1Zgl+7rATr/pDQkw6DPCNBS1+Y6fy7GstZALQXwEDN/qhQI9kWkHijT8ns+i1vGg00Mk/6J75arLhqcodWsdeG/M/moWgqQAnlZAGVtJI1OgeF5fsPpXu4kctOfuZlGjVZXQNW34aOzm8r8S0eVZitPlbhcPiR4gT/aSMz/wd8lZlzZYsje/Jr8u/YtlwjjreZrGRmG8KMOzukV3lLmMppXFMvl4bxv6YFEmIuTsOhbLTwFgh7KYNjodLj/LsqRVfwz31PgWQFTEPICV7GCvgVlPRxnofqKSjgTWI4mxDhBpVcATvaoBl1L/6WLbFvBsoAUBItWwctO2xalKxF5szhGm8lccoc5MZr8kfE0uxMgsxz4er68iCID+rsCAQM="
}
CFG

cat > /usr/local/etc/xray/psiphon.json << CFG
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "tag": "vless-in",
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "${UUID}", "level": 0 }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"],
        "routeOnly": true
      }
    }
  ],
  "outbounds": [
    {
      "tag": "out-psiphon",
      "protocol": "socks",
      "settings": {
        "servers": [
          { "address": "127.0.0.1", "port": 1081 }
        ]
      }
    }
  ]
}
CFG

echo "== starting Psiphon =="
/opt/psiphon/psiphon-tunnel-core-x86_64 -config /opt/psiphon/psiphon.config &
PSI_PID=$!

sleep 10

echo "== running tests via Psiphon (inside container) =="

set +e
PSI_IP=$(curl --proxy socks5h://127.0.0.1:1081 -4 -s --max-time 15 https://api.ipify.org || echo "ERR")
PSI_YT_CODE=$(curl --proxy socks5h://127.0.0.1:1081 -4 -s -o /dev/null -w "%{http_code}" --max-time 15 https://www.youtube.com/generate_204 || echo "ERR")
set -e

echo "Psiphon IP: ${PSI_IP}"
echo "YouTube code via Psiphon: ${PSI_YT_CODE}"

OK=1
[ "$PSI_IP" = "ERR" ] && OK=0
[ "$PSI_YT_CODE" != "204" ] && OK=0

if [ "$OK" -eq 1 ]; then
  echo "✅ Psiphon OK (IP and YouTube 204)"
else
  echo "❌ Psiphon test failed (IP or YouTube)."
fi

echo
echo "==== VLESS URL (use PUBLIC_HOST from env/panel) ===="
echo "vless://${UUID}@${PUBLIC_HOST}:${PORT}?encryption=none&security=none&type=tcp#psi-yt-fast"
echo "===================================================="
echo

echo "== starting Xray (foreground) =="
exec /usr/local/bin/xray -config /usr/local/etc/xray/psiphon.json
EOF