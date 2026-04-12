#!/bin/bash
# =========================================
# 隐蔽版 Reality 节点脚本 (带断电记忆功能)
# =========================================
set -uo pipefail

# ===== 基础配置 =====
# 接收传入的第一个参数作为端口，如果没有传入，则默认使用 21828
PORT=${1:-21828}
CORE_BIN="./tuz_core"
CORE_CONFIG="tuz_conf.json"

# ========== 1. 检查并下载核心 ==========
if [[ ! -x "$CORE_BIN" ]]; then
  echo "正在初始化运行环境..."
  curl -L -s -o temp_core.zip "https://github.com/XTLS/Xray-core/releases/download/v1.8.23/Xray-linux-64.zip"
  unzip -j temp_core.zip xray -d . >/dev/null 2>&1
  mv xray "$CORE_BIN"
  rm -f temp_core.zip
  chmod +x "$CORE_BIN"
fi

# ========== 2. 如果没有配置文件，则生成新节点 ==========
if [[ ! -f "$CORE_CONFIG" ]]; then
  echo "首次运行，正在生成专属加密节点..."
  CORE_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16)
  MASQ_DOMAIN="www.bing.com"
  shortId=$(openssl rand -hex 8)
  keys=$("$CORE_BIN" x25519 2>/dev/null)
  priv=$(echo "$keys" | grep Private | awk '{print $3}')
  pub=$(echo "$keys" | grep Public | awk '{print $3}')

  cat > "$CORE_CONFIG" <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": {
      "clients": [{"id": "$CORE_UUID", "flow": "xtls-rprx-vision"}],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "$MASQ_DOMAIN:443",
        "xver": 0,
        "serverNames": ["$MASQ_DOMAIN", "www.microsoft.com"],
        "privateKey": "$priv",
        "publicKey": "$pub",
        "shortIds": ["$shortId"],
        "fingerprint": "chrome",
        "spiderX": "/"
      }
    },
    "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

  # 获取IP并生成链接
  ip=$(curl -s https://api64.ipify.org || echo "127.0.0.1")
  link="vless://$CORE_UUID@$ip:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$MASQ_DOMAIN&fp=chrome&pbk=$pub&sid=$shortId&type=tcp&spx=/#Tuz-Node"
  
  # 把链接存到本地文件里，方便随时查看
  echo -e "$link" > tuz_link.txt
  echo "✅ 节点配置完毕！"
else
  echo "🔄 检测到已有节点配置，正在读取旧配置直接启动..."
fi

# ========== 3. 启动服务 ==========
echo "🚀 服务运行中..."
"$CORE_BIN" run -c "$CORE_CONFIG"