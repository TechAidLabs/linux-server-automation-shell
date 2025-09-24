#!/bin/bash
set -e

echo ">>> Screen blank (画面自動消灯) を無効化します"
gsettings set org.gnome.desktop.session idle-delay 0

echo ">>> Apache (httpd) をインストールします"
sudo dnf install -y httpd

echo ">>> httpd サービスを有効化・起動します"
sudo systemctl enable --now httpd

echo ">>> httpd サービスのステータスを表示します"
sudo systemctl status httpd

echo ">>> ファイアウォールで HTTP 通信を許可します"
if sudo firewall-cmd --permanent --zone=public --add-service=http; then
    echo "  → HTTP サービス追加成功"
fi
if sudo firewall-cmd --reload; then
    echo "  → ファイアウォール設定リロード成功"
fi

echo ">>> ファイアウォールのステータスを表示します"
sudo firewall-cmd --list-all

echo ">>> 簡易HTMLページを作成します"
echo "<h1>Hello from Apache!</h1>" | sudo tee /var/www/html/index.html > /dev/null

echo ">>> localhost にアクセスして httpd 応答を確認します"
curl -I http://localhost

echo ">>> 完了しました"

