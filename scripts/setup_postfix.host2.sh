#!/bin/bash

set -e  # エラーが出たら即時停止

echo ">>> Postfix と関連パッケージのインストール"
sudo dnf install -y postfix cyrus-sasl s-nail dovecot thunderbird

echo ">>> /etc/postfix/main.cf のバックアップを取得"
sudo cp -p /etc/postfix/main.cf /etc/postfix/main.cf.bak.$(date +%F_%T)

echo ">>> main.cf の差し替え"
sudo cp -p /root/fixed_conf/conf.d/main.cf.host2.fixed /etc/postfix/main.cf

echo ">>> main.cf の書式チェックを実施"
if ! sudo postfix check; then
  echo "!!! postfix check でエラーが発生しました。処理を中断します。"
  exit 1
fi

echo ">>> Postfix サービスを起動・有効化"
sudo systemctl start postfix
sudo systemctl enable postfix
sudo systemctl status postfix --no-pager

echo ">>> ファイアウォール設定: SMTPポートを開放"

if sudo firewall-cmd --add-service=smtp --zone=public --permanent; then
    echo "  → SMTP ポートの開放に成功"
else
    echo "  → SMTP ポートの開放に失敗"
fi

if sudo firewall-cmd --reload; then
    echo "  → ファイアウォール設定のリロードに成功"
else
    echo "  → ファイアウォール設定のリロードに失敗"
fi

echo ">>> postfix.service のバックアップを取得"
sudo cp -p /usr/lib/systemd/system/postfix.service /usr/lib/systemd/system/postfix.service.bak.$(date +%F_%T)

echo ">>> postfix.service の差し替え"
sudo cp -p /root/fixed_conf/conf.d/postfix.service.fixed /usr/lib/systemd/system/postfix.service

echo ">>> saslauthd サービスを起動・有効化"

# 起動
if sudo systemctl start saslauthd; then
    echo "  → saslauthd の起動に成功"
else
    echo "  → saslauthd の起動に失敗"
fi

# 有効化（ブート時に自動起動）
if sudo systemctl enable saslauthd; then
    echo "  → saslauthd の自動起動設定に成功"
else
    echo "  → saslauthd の自動起動設定に失敗"
fi

# 状態表示
echo ">>> saslauthd のステータス:"
sudo systemctl status saslauthd --no-pager

echo ">>> setup_postfix.sh が正常に完了しました。"
