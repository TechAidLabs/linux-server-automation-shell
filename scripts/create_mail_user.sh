#!/bin/bash

# IPアドレスの末尾（例：192.168.56.101 → 101）を取得
LAST_OCTET=$(hostname -I | awk '{print $1}' | awk -F. '{print $4}' | sed 's/^0*//')

if [ "$LAST_OCTET" == "101" ]; then
    USERNAME="user1"
    EMAIL_DOMAIN="example1.jp"
elif [ "$LAST_OCTET" == "102" ]; then
    USERNAME="user2"
    EMAIL_DOMAIN="example2.jp"
else
    echo "未対応のIP末尾です: $LAST_OCTET"
    exit 1
fi

echo ">>> ユーザー $USERNAME を作成します"

# ユーザー作成（存在チェック）
if id "$USERNAME" &>/dev/null; then
    echo "ユーザー $USERNAME はすでに存在します"
else
    useradd "$USERNAME"
    echo "userpass" | passwd --stdin "$USERNAME"
    echo ">>> ユーザー $USERNAME を作成し、パスワードを設定しました"
fi

# Maildir作成（存在チェック）
MAILDIR="/home/$USERNAME/Maildir"
if [ ! -d "$MAILDIR" ]; then
    mkdir -p "$MAILDIR"
    chown -R "$USERNAME":"$USERNAME" "$MAILDIR"
    echo ">>> Maildir を作成しました: $MAILDIR"
fi

# SASLパスワード設定
echo ">>> SASL認証パスワードを設定します"
echo "userpass" | saslpasswd2 -p -c -u "$EMAIL_DOMAIN" "$USERNAME"
if [ $? -eq 0 ]; then
    echo "SASL認証パスワード設定完了: $USERNAME@$EMAIL_DOMAIN"
else
    echo "SASL認証パスワード設定に失敗しました"
    exit 1
fi

# SASLデータベースファイルの権限調整（必要に応じて）
SASL_DB_FILE="/etc/sasldb2"
if [ -f "$SASL_DB_FILE" ]; then
    chown root:postfix "$SASL_DB_FILE"
    chmod 640 "$SASL_DB_FILE"
    echo "SASLデータベースの権限を設定しました: $SASL_DB_FILE"
fi

echo ">>> メールユーザー $USERNAME の作成と SASL 設定が完了しました"

