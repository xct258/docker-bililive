#!/bin/bash

mkdir -p /opt/bililive/scripts /opt/bililive/config /opt/bililive/apps /root/BililiveRecorder

# 获取 7z 下载链接
latest_release_7z=$(curl -s https://api.github.com/repos/ip7z/7zip/releases/latest)
latest_7z_x64_url=$(echo "$latest_release_7z" | jq -r '.assets[] | select(.name | test("linux-x64.tar.xz")) | .browser_download_url')
latest_7z_arm64_url=$(echo "$latest_release_7z" | jq -r '.assets[] | select(.name | test("linux-arm64.tar.xz")) | .browser_download_url')

# 获取 biliup-rs 下载链接
latest_release_biliup_rs=$(curl -s https://api.github.com/repos/biliup/biliup-rs/releases/latest)
latest_biliup_rs_x64_url=$(echo "$latest_release_biliup_rs" | jq -r '.assets[] | select(.name | test("x86_64-linux.tar.xz")) | .browser_download_url')
latest_biliup_rs_arm64_url=$(echo "$latest_release_biliup_rs" | jq -r '.assets[] | select(.name | test("aarch64-linux.tar.xz")) | .browser_download_url')

arch=$(uname -m)
if [[ $arch == *"x86_64"* ]]; then
    wget -O /root/tmp/7zz.tar.xz "$latest_7z_x64_url"
    wget -O /root/tmp/biliup-rs.tar.xz "$latest_biliup_rs_x64_url"
    wget -O /root/tmp/BililiveRecorder-CLI.zip https://github.com/BililiveRecorder/BililiveRecorder/releases/latest/download/BililiveRecorder-CLI-linux-x64.zip
    wget -O /DanmakuFactory https://raw.githubusercontent.com/xct258/docker-bililive/main/DanmakuFactory/DanmakuFactory-amd64
elif [[ $arch == *"aarch64"* ]]; then
    wget -O /root/tmp/7zz.tar.xz "$latest_7z_arm64_url"
    wget -O /root/tmp/biliup-rs.tar.xz "$latest_biliup_rs_arm64_url"
    wget -O /root/tmp/BililiveRecorder-CLI.zip https://github.com/BililiveRecorder/BililiveRecorder/releases/latest/download/BililiveRecorder-CLI-linux-arm64.zip
    wget -O /root/tmp/DanmakuFactory https://raw.githubusercontent.com/xct258/docker-bililive/main/DanmakuFactory/DanmakuFactory-arm64
fi

# 解压与移动
tar -xf /root/tmp/7zz.tar.xz -C /root/tmp
tar -xf /root/tmp/biliup-rs.tar.xz -C /root/tmp
chmod +x /root/tmp/7zz
mv /root/tmp/7zz /bin/7zz
biliup_file=$(find /root/tmp -type f -name "biliup")
mv "$biliup_file" /opt/bililive/apps/biliup-rs
mv /root/tmp/DanmakuFactory /opt/bililive/apps/DanmakuFactory

7zz x /root/tmp/BililiveRecorder-CLI.zip -o/root/BililiveRecorder

# 下载视频处理相关脚本
wget -O /opt/bililive/config/上传备份脚本配置文件.conf https://raw.githubusercontent.com/xct258/docker-bililive/main/视频处理脚本/上传备份脚本配置文件.conf
wget -O /opt/bililive/scripts/录播上传备份脚本.sh https://raw.githubusercontent.com/xct258/docker-bililive/main/视频处理脚本/录播上传备份脚本.sh
wget -O /opt/bililive/scripts/压制视频.py https://raw.githubusercontent.com/xct258/docker-bililive/main/视频处理脚本/压制视频.py
wget -O /opt/bililive/scripts/封面获取.py https://raw.githubusercontent.com/xct258/docker-bililive/main/视频处理脚本/封面获取.py
wget -O /opt/bililive/scripts/biliup后处理.sh https://raw.githubusercontent.com/xct258/docker-bililive/main/biliup/biliup后处理.sh
wget -O /opt/bililive/scripts/log.sh https://raw.githubusercontent.com/xct258/docker-bililive/main/视频处理脚本/log.sh