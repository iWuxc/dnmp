#!/bin/sh
#
# PHP 8.5 extension installer.
#
# 输入与 php74/extensions/install.sh 完全一致（PHP_EXTENSIONS，逗号分隔），
# 例如：PHP_EXTENSIONS=pdo_mysql,mysqli,gd,curl,opcache,zip,bcmath,redis,swoole
#
# 区别：PHP 8.5 下 PECL 扩展（redis/swoole/mongodb/xdebug 等）统一交给
# install-php-extensions 处理，它会按当前 PHP 版本挑选能编译的扩展版本，
# 避免 php74 里写死的旧 tgz 包（如 redis-5.3.7、swoole-4.8.11）在 8.5 上失败。
#
set -e

export MC="-j$(nproc)"

echo
echo "============================================"
echo "Install extensions from   : install.sh"
echo "PHP version               : $(php -r 'echo PHP_VERSION;')"
echo "Extra Extensions          : ${PHP_EXTENSIONS}"
echo "Multicore Compilation     : ${MC}"
echo "Container package url     : ${CONTAINER_PACKAGE_URL}"
echo "Work directory            : ${PWD}"
echo "============================================"
echo

if [ "${PHP_EXTENSIONS}" = "" ]; then
    echo "No extensions to install."
    exit 0
fi

EXT_DIR="$(cd "$(dirname "$0")" && pwd)"
IPE="${EXT_DIR}/install-php-extensions"
chmod +x "${IPE}"

# 1) 编译 PHP 自带扩展所需的依赖（与 php74 的做法一致，装完统一删除）
apk --no-cache add --virtual .build-deps $PHPIZE_DEPS

# 2) 逐个安装 PHP_EXTENSIONS 里的扩展（逗号分隔 -> 空格分隔）
#    install-php-extensions 会自动识别“自带扩展”和“PECL 扩展”，
#    并安装/清理对应的 apk 依赖与 configure 选项（如 gd 的 freetype/jpeg/webp）。
#    pecl.php.net 偶发超时，这里做 3 次重试，避免整个构建失败。
installWithRetry() {
    attempt=1
    while [ "${attempt}" -le 3 ]; do
        if "${IPE}" "$1"; then
            return 0
        fi
        echo "!!! $1 install failed (attempt ${attempt}/3), retrying..."
        sleep 5
        attempt=$((attempt + 1))
    done
    return 1
}

for ext in $(echo "${PHP_EXTENSIONS}" | tr ',' ' '); do
    echo "---------- Install ${ext} ----------"
    installWithRetry "${ext}"
done

# 3) 清理编译依赖
apk del .build-deps 2>/dev/null || true
docker-php-source delete 2>/dev/null || true

echo
echo "Installed extensions:"
php -m | tr '\n' ' '
echo
