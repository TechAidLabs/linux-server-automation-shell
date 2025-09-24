#!/bin/bash

echo ">>> BINDパッケージのインストール"
sudo dnf install -y bind bind-chroot

echo ">>> named.confのバックアップを取得"
sudo cp -p /etc/named.conf /etc/named.conf.bak

echo ">>> サーバー自身のIPアドレスを取得"
SERVER_IP=$(ip a | grep inet | grep 192.168 | awk '{print $2}' | cut -d'/' -f1 | head -n1)

echo ">>> named.conf を再構築（安全な上書き）"
sudo tee /etc/named.conf > /dev/null <<EOF
options {
    listen-on port 53 { 127.0.0.1; ${SERVER_IP}; };
    directory "/var/named";
    dump-file "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    allow-query { any; };
    recursion yes;
    forwarders {
        192.168.56.100;
    };
    dnssec-validation no;
};

logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};

zone "." IN {
    type hint;
    file "named.ca";
};

include "/etc/named.rfc1912.zones";
/* include "/etc/named.root.key"; */

zone "example1.jp" IN {
    type master;
    file "example1.jp.zone";
    allow-update { none; };
};
EOF

echo ">>> ゾーンファイルの作成"
sudo cp -p /var/named/named.empty /var/named/example1.jp.zone

echo ">>> ゾーンファイルの編集"
SERIAL_DATE=$(date +%Y%m%d)01
sudo tee /var/named/example1.jp.zone > /dev/null <<EOF
\$TTL 3H
\$ORIGIN example1.jp.
@   IN  SOA host1.example1.jp. root.example1.jp. (
        $SERIAL_DATE ; serial
        1D           ; refresh
        1H           ; retry
        1W           ; expire
        3H )         ; minimum
    IN  NS   host1.example1.jp.
    IN  MX 10 mail.example1.jp.
host1   IN  A    ${SERVER_IP}
www     IN  A    ${SERVER_IP}
mail    IN  A    ${SERVER_IP}
EOF

echo ">>> SELinux コンテキスト修正（chroot対応）"
sudo restorecon -v /var/named/example1.jp.zone

echo ">>> 設定ファイルの文法チェック"
sudo named-checkconf
sudo named-checkzone example1.jp /var/named/example1.jp.zone

echo ">>> named-chroot サービス起動と有効化"
sudo systemctl restart named-chroot
sudo systemctl enable named-chroot
sudo systemctl status named-chroot

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

echo ">>> /etc/resolv.conf の内容確認"
cat /etc/resolv.conf
# --- ここから /etc/hosts追記処理 ---

echo ">>> /etc/hosts に自IPとホスト名の追記"

# サーバー自身のIPアドレスを取得（192.168.で始まる最初のIPv4アドレス）
SERVER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)192\.168\.\d+\.\d+')

# 追記するホスト名（スクリプトに合わせて変更）
HOSTNAME1="host1.example1.jp"
HOSTNAME2="mail.example1.jp"

# /etc/hostsに既にIP+ホスト名の行がなければ追記する
if ! grep -qE "^${SERVER_IP}[[:space:]]+${HOSTNAME1}[[:space:]]+${HOSTNAME2}" /etc/hosts; then
    echo "${SERVER_IP}  ${HOSTNAME1} ${HOSTNAME2}" | sudo tee -a /etc/hosts
    echo "  追記しました: ${SERVER_IP}  ${HOSTNAME1} ${HOSTNAME2}"
else
    echo "  既に /etc/hosts に記載があります"
fi

# --- ここまで /etc/hosts追記処理 ---

echo ">>> 完了しました"

