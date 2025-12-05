#!/bin/bash

# 安装必要软件
apt install -y curl nano jq bc

# 获取 7z 下载链接
latest_release_7z=$(curl -s https://api.github.com/repos/ip7z/7zip/releases/latest)
latest_7z_x64_url=$(echo "$latest_release_7z" | jq -r '.assets[] | select(.name | test("linux-x64.tar.xz")) | .browser_download_url')
latest_7z_arm64_url=$(echo "$latest_release_7z" | jq -r '.assets[] | select(.name | test("linux-arm64.tar.xz")) | .browser_download_url')

# 获取 biliup-rs 下载链接
latest_release_biliup_rs=$(curl -s https://api.github.com/repos/biliup/biliup-rs/releases/latest)
latest_biliup_rs_x64_url=$(echo "$latest_release_biliup_rs" | jq -r '.assets[] | select(.name | test("x86_64-linux.tar.xz")) | .browser_download_url')
latest_biliup_rs_arm64_url=$(echo "$latest_release_biliup_rs" | jq -r '.assets[] | select(.name | test("aarch64-linux.tar.xz")) | .browser_download_url')

# 获取服务器架构
arch=$(uname -m)
if [[ $arch == *"x86_64"* ]]; then
    wget -O /root/tmp/7zz.tar.xz "$latest_7z_x64_url"
    wget -O /root/tmp/biliup-rs.tar.xz "$latest_biliup_rs_x64_url"
    wget -O /root/tmp/BililiveRecorder-CLI.zip https://github.com/BililiveRecorder/BililiveRecorder/releases/latest/download/BililiveRecorder-CLI-linux-x64.zip
    wget -O /root/tmp/DanmakuFactory https://raw.githubusercontent.com/xct258/docker-bililive/main/DanmakuFactory/DanmakuFactory-amd64
elif [[ $arch == *"aarch64"* ]]; then
    wget -O /root/tmp/7zz.tar.xz "$latest_7z_arm64_url"
    wget -O /root/tmp/biliup-rs.tar.xz "$latest_biliup_rs_arm64_url"
    wget -O /root/tmp/BililiveRecorder-CLI.zip https://github.com/BililiveRecorder/BililiveRecorder/releases/latest/download/BililiveRecorder-CLI-linux-arm64.zip
    wget -O /root/tmp/DanmakuFactory https://raw.githubusercontent.com/xct258/docker-bililive/main/DanmakuFactory/DanmakuFactory-arm64
fi

# 安装解压工具
apt install -y tar xz-utils
# 安装7zz
tar -xf /root/tmp/7zz.tar.xz -C /root/tmp
tar -xf /root/tmp/biliup-rs.tar.xz -C /root/tmp
chmod +x /root/tmp/7zz
mv /root/tmp/7zz /bin/7zz

# 安装该镜像所需要的软件
apt install -y ffmpeg pciutils fontconfig procps python3-pip rclone

# 安装该镜像所需要的字体
# 创建字体目录
mkdir -p /root/.fonts/
# 下载 Segoe Emoji 字体
wget -O "/root/.fonts/seguiemj.ttf" https://raw.githubusercontent.com/xct258/docker-bililive/refs/heads/main/字体/seguiemj.ttf
# 下载 微软雅黑 字体
wget -O "/root/.fonts/微软雅黑.ttf" https://raw.githubusercontent.com/xct258/docker-bililive/refs/heads/main/字体/微软雅黑.ttf
# 更新字体缓存
fc-cache -f -v

# 安装biliup-rs
biliup_rs_file=$(find /root/tmp -type f -name "biliup")
mkdir -p /opt/bililive/apps
mv "$biliup_rs_file" /opt/bililive/apps/biliup-rs

# 安装DanmakuFactory
chmod +x /root/tmp/DanmakuFactory 
mv /root/tmp/DanmakuFactory /opt/bililive/apps/DanmakuFactory

# 安装BililiveRecorder
mkdir -p /root/BililiveRecorder
7zz x /root/tmp/BililiveRecorder-CLI.zip -o/root/BililiveRecorder
chmod +x /root/BililiveRecorder/BililiveRecorder.Cli

# 安装biliup
pip3 install biliup --break-system-packages

# 下载容器所需脚本
# 创建相关目录
mkdir -p /opt/bililive/config /opt/bililive/scripts /opt/bililive/biliup
# 下载视频处理相关脚本
wget -O /opt/bililive/config/上传备份脚本配置文件.conf https://raw.githubusercontent.com/xct258/docker-bililive/main/视频处理脚本/上传备份脚本配置文件.conf
wget -O /opt/bililive/scripts/录播上传备份脚本.sh https://raw.githubusercontent.com/xct258/docker-bililive/main/视频处理脚本/录播上传备份脚本.sh
wget -O /opt/bililive/scripts/压制视频.py https://raw.githubusercontent.com/xct258/docker-bililive/main/视频处理脚本/压制视频.py
wget -O /opt/bililive/scripts/封面获取.py https://raw.githubusercontent.com/xct258/docker-bililive/main/视频处理脚本/封面获取.py
wget -O /opt/bililive/scripts/ffmpeg视频处理.sh https://raw.githubusercontent.com/xct258/docker-bililive/main/视频处理脚本/ffmpeg视频处理.sh
wget -O /opt/bililive/biliup/biliup后处理.sh https://raw.githubusercontent.com/xct258/docker-bililive/main/biliup/biliup后处理.sh
wget -O /opt/bililive/scripts/log.sh https://raw.githubusercontent.com/xct258/docker-bililive/main/视频处理脚本/log.sh
wget -O /opt/bililive/scripts/自动选择onedrive网盘.sh https://raw.githubusercontent.com/xct258/docker-bililive/main/视频处理脚本/自动选择onedrive网盘.sh
chmod +x /opt/bililive/scripts/*.sh
chmod +x /opt/bililive/biliup/*.sh