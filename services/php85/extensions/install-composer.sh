#!/bin/sh

# Install composer.
# 依次尝试：COMPOSER_URL 指定的镜像 -> mirrors.aliyun.com -> 官方 getcomposer.org
# （国内网络下部分镜像会偶发 SSL 断流，逐个回退比直接失败更稳）
set -e

MIRRORS="${COMPOSER_URL} mirrors.aliyun.com getcomposer.org"

for mirror in ${MIRRORS}; do
    echo "Install composer from     : ${mirror}"
    if [ "${mirror}" = "getcomposer.org" ]; then
        if curl -sSL --retry 3 -o /usr/local/bin/composer https://getcomposer.org/composer-stable.phar; then
            chmod +x /usr/local/bin/composer
            exit 0
        fi
    else
        if curl -sSL --retry 3 -o /usr/local/bin/composer "https://${mirror}/composer/composer.phar"; then
            chmod +x /usr/local/bin/composer
            exit 0
        fi
    fi
    echo "!!! ${mirror} failed, trying next..."
done

echo "!!! composer installation failed"
exit 1
