#!/bin/bash
set -e

echo "=== V2Ray / Xray on GCP Cloud Run ==="
echo "Protocol : VLESS + gRPC"
echo "Domain   : AUTO (*.run.app)"
echo

# check gcloud
if ! command -v gcloud >/dev/null 2>&1; then
  echo "❌ gcloud not found. Use Cloud Shell or install Google Cloud SDK."
  exit 1
fi

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
SERVICE="v2ray-grpc"
UUID=$(cat /proc/sys/kernel/random/uuid)
GRPC_SERVICE="9R6keFLN"

echo "[+] Project : $PROJECT_ID"
echo "[+] UUID    : $UUID"
echo "[+] gRPC    : $GRPC_SERVICE"
echo

mkdir -p v2ray-cloudrun
cd v2ray-cloudrun

# -------- config.json --------
cat > config.json <<EOF
{
  "inbounds": [
    {
      "port": 8080,
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "$UUID", "encryption": "none" }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "$GRPC_SERVICE"
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" }
  ]
}
EOF

# -------- Dockerfile --------
cat > Dockerfile <<EOF
FROM alpine:latest
RUN apk add --no-cache curl unzip
RUN curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip \\
 && unzip xray.zip \\
 && chmod +x xray \\
 && mv xray /usr/bin/xray \\
 && rm -f xray.zip
COPY config.json /config.json
ENV PORT=8080
CMD ["xray","run","-config","/config.json"]
EOF

echo "[+] Build image..."
gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE

echo "[+] Deploy to Cloud Run..."
gcloud run deploy $SERVICE \
  --image gcr.io/$PROJECT_ID/$SERVICE \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated

URL=$(gcloud run services describe $SERVICE --region $REGION --format 'value(status.url)')

echo
echo "======================================"
echo " ✅ DONE"
echo "======================================"
echo "Cloud Run URL : $URL"
echo
echo "📱 CLIENT CONFIG (v2rayNG / v2rayN)"
echo "Protocol   : VLESS"
echo "Address    : ${URL#https://}"
echo "Port       : 443"
echo "UUID       : $UUID"
echo "Network    : gRPC"
echo "serviceName: $GRPC_SERVICE"
echo "TLS        : ON"
echo "SNI        : ${URL#https://}"
echo "======================================"
