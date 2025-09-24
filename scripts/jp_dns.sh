#!/bin/bash

echo ">>> BIND パッケージのインストール"
sudo dnf install -y bind bind-chroot

echo ">>> named.conf のバックアップ"
sudo cp -p /etc/named.conf /etc/named.conf.bak

echo ">>> サーバーのIPアドレスを取得"
SERVER_IP=$(ip a | grep inet | grep 192.168 | awk '{print $2}' | cut -d'/' -f1 | head -n1)

echo ">>> named.conf の編集"
# recursion は yes のままにする
sudo sed -i \
  -e "s|listen-on port 53 { 127.0.0.1;.*|listen-on port 53 { 127.0.0.1; ${SERVER_IP}; };|" \
  -e "s|allow-query\s*{.*|allow-query { any; };|" \
  /etc/named.conf

echo ">>> jp ゾーンの定義を追記"
sudo tee -a /etc/named.conf > /dev/null <<EOF

zone "jp" IN {
    type master;
    file "jp.zone";
    allow-update { none; };
};
EOF

echo ">>> jp.zone の作成"
sudo cp -p /var/named/named.empty /var/named/jp.zone

echo ">>> jp.zone の編集"
SERIAL_DATE=$(date +%Y%m%d)01
sudo tee /var/named/jp.zone > /dev/null <<EOF
\$TTL 3H
\$ORIGIN jp.
@   IN  SOA host0.jp. root.jp. (
        $SERIAL_DATE ; serial
        1D           ; refresh
        1H           ; retry
        1W           ; expire
        3H )         ; minimum

    IN  NS   host0.jp.
example1.jp. IN NS host1.example1.jp.
example2.jp. IN NS host2.example2.jp.

host0           IN A 192.168.56.100
host1.example1.jp. IN A 192.168.56.101
host2.example2.jp. IN A 192.168.56.102
EOF

echo ">>> named 設定の文法チェック"
sudo named-checkconf
sudo named-checkzone jp /var/named/jp.zone

echo ">>> named-chroot サービスの起動と有効化"
sudo systemctl start named-chroot
sudo systemctl enable named-chroot

echo ">>> Firewall に DNS サービスを許可"
if sudo firewall-cmd --add-service=dns --zone=public --permanent; then
    echo "  → DNS サービスの追加に成功"
else
    echo "  → DNS サービスの追加に失敗"
fi

if sudo firewall-cmd --reload; then
    echo "  → ファイアウォール設定のリロードに成功"
else
    echo "  → ファイアウォール設定のリロードに失敗"
fi

echo ">>> /etc/resolv.conf の確認"
cat /etc/resolv.conf

echo ">>> 完了しました。上位 jp ゾーンの DNS が設定されました。"

