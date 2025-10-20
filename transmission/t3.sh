# 测试 9091 端口是否真的对外开放
SERVER_PUBLIC_IP=$(curl -s ifconfig.me)
echo "测试从公网访问 $SERVER_PUBLIC_IP:9091"
curl -v http://$SERVER_PUBLIC_IP:9091/ 2>&1