#!/bin/bash

echo ">>> Dovecot 設定開始"

# バックアップの作成
echo ">>> 既存設定ファイルのバックアップを作成中..."
for file in 10-mail.conf 10-auth.conf 10-ssl.conf; do
    if [ -f /etc/dovecot/conf.d/$file ]; then
        cp /etc/dovecot/conf.d/$file /etc/dovecot/conf.d/${file}.bak
        echo "バックアップ作成: ${file}.bak"
    else
        echo "警告: /etc/dovecot/conf.d/$file が存在しません"
    fi
done

# fixedファイルによる上書き
echo ">>> 設定ファイルの差し替え中..."
for file in 10-mail.conf 10-auth.conf 10-ssl.conf; do
    src="/root/fixed_conf/conf.d/${file}.fixed"
    dest="/etc/dovecot/conf.d/${file}"
    if [ -f "$src" ]; then
        cp "$src" "$dest"
        echo "差し替え完了: $file"
    else
        echo "エラー: fixed ファイルが見つかりません -> $src"
        exit 1
    fi
done

# Dovecot の起動と有効化
echo ">>> Dovecot の起動と自動起動設定..."
sudo systemctl start dovecot
sudo systemctl enable dovecot

# ステータス確認
echo ">>> Dovecot のステータス:"
sudo systemctl status dovecot

# Firewall 設定
echo ">>> ファイアウォールに IMAP サービスを追加..."
sudo firewall-cmd --add-service=imap --zone=public --permanent
sudo firewall-cmd --reload

echo ">>> Dovecot の設定が完了しました。"
