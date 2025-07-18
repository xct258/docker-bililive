# 使用 Debian 作为基础镜像
FROM debian

# 设置中文环境
RUN apt-get update && apt-get install -y locales tzdata && rm -rf /var/lib/apt/lists/* \
    # 生成中文 locale
    && localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
# 设置环境变量为中文
ENV LANG=zh_CN.UTF-8
# 设置时区为上海
ENV TZ=Asia/Shanghai

# 安装构建所需的相关依赖
RUN apt-get update \
    && apt-get install -y wget git curl nano jq bc tar xz-utils ffmpeg pciutils fontconfig procps python3-pip rclone \
    && mkdir -p /root/.fonts/ /rec/biliup /rec/录播姬 /root/tmp \
    && wget -O /root/.fonts/seguiemj.ttf https://raw.githubusercontent.com/xct258/docker-bililive/refs/heads/main/字体/seguiemj.ttf \
    && wget -O /root/.fonts/微软雅黑.ttf https://raw.githubusercontent.com/xct258/docker-bililive/refs/heads/main/字体/微软雅黑.ttf \
    && fc-cache -f -v \
    && pip3 install biliup --break-system-packages \
    && cat << 'EOF' > /root/tmp/tmp.sh
#!/bin/bash
latest_release_7z=$(curl -s https://api.github.com/repos/ip7z/7zip/releases/latest)
latest_7z_x64_url=$(echo "$latest_release_7z" | jq -r '.assets[] | select(.name | test("linux-x64.tar.xz")) | .browser_download_url')
latest_7z_arm64_url=$(echo "$latest_release_7z" | jq -r '.assets[] | select(.name | test("linux-arm64.tar.xz")) | .browser_download_url')
arch=$(uname -m)
if [[ "$arch" == "x86_64" ]]; then
    wget -O /root/tmp/7zz.tar.xz "$latest_7z_x64_url"
    wget -O /root/tmp/BililiveRecorder-CLI.zip https://github.com/BililiveRecorder/BililiveRecorder/releases/latest/download/BililiveRecorder-CLI-linux-x64.zip
    wget -O /DanmakuFactory https://raw.githubusercontent.com/xct258/docker-bililive/refs/heads/main/DanmakuFactory/DanmakuFactory-amd64
elif [[ "$arch" == "aarch64" ]]; then
    wget -O /root/tmp/7zz.tar.xz "$latest_7z_arm64_url"
    wget -O /root/tmp/BililiveRecorder-CLI.zip https://github.com/BililiveRecorder/BililiveRecorder/releases/latest/download/BililiveRecorder-CLI-linux-arm64.zip
    wget -O /DanmakuFactory https://raw.githubusercontent.com/xct258/docker-bililive/refs/heads/main/DanmakuFactory/DanmakuFactory-arm64
else
    echo "未知架构: $arch"
fi
EOF \
    && chmod +x /root/tmp/tmp.sh \
    && /root/tmp/tmp.sh \
    && tar -xf /root/tmp/7zz.tar.xz -C /root/tmp \
    && chmod +x /root/tmp/7zz \
    && mv /root/tmp/7zz /bin/7zz \
    && 7zz x /root/tmp/BililiveRecorder-CLI.zip -o/root/BililiveRecorder \
    && chmod +x /root/BililiveRecorder/BililiveRecorder.Cli \
    && rm -rf /root/tmp \
    && cat << 'EOF' > /usr/local/bin/start.sh
#!/bin/bash
mkdir -p /rec/biliup /rec/录播姬
if [ -n "$XCT258_GITHUB_TOKEN" ]; then
  echo "检测到 XCT258_GITHUB_TOKEN，准备检查并下载私有配置文件..."
  mkdir -p /root/.config/rclone
  if [ ! -f "/root/.config/rclone/rclone.conf" ]; then
    echo "未检测到 rclone.conf，开始下载..."
    wget --header="Authorization: token $XCT258_GITHUB_TOKEN" -O "/root/.config/rclone/rclone.conf" "https://raw.githubusercontent.com/xct258/Documentation/refs/heads/main/rclone/rclone.conf"
  else
    echo "已存在 rclone.conf，跳过下载"
  fi
  if [ ! -f "/rec/cookies-烦心事远离.json" ]; then
    echo "未检测到 cookies-烦心事远离.json，开始下载..."
    wget --header="Authorization: token $XCT258_GITHUB_TOKEN" -O "/rec/cookies-烦心事远离.json" "https://raw.githubusercontent.com/xct258/Documentation/refs/heads/main/b站cookies/cookies-b站-烦心事远离.json"
  else
    echo "已存在 cookies-烦心事远离.json，跳过下载"
  fi
  if [ ! -f "/rec/biliup/cookies-xct258-2.json" ]; then
    echo "未检测到 cookies-xct258-2.json，开始下载..."
    wget --header="Authorization: token $XCT258_GITHUB_TOKEN" -O "/rec/biliup/cookies-xct258-2.json" "https://raw.githubusercontent.com/xct258/Documentation/refs/heads/main/b站cookies/cookies-b站-xct258-2.json"
  else
    echo "已存在 cookies-xct258-2.json，跳过下载"
  fi
fi
if [ -f /root/.credentials ]; then
    source /root/.credentials
else
    if [ -z "$Bililive_USER" ]; then
        Bililive_USER="xct258"
        echo Bililive_USER="$Bililive_USER" > /root/.credentials
    else
        echo Bililive_USER="$Bililive_USER" > /root/.credentials
    fi
    if [ -z "$Bililive_PASS" ]; then
        Bililive_PASS=$(openssl rand -base64 12)
        echo Bililive_PASS="$Bililive_PASS" >> /root/.credentials
    else
        echo Bililive_PASS=$Bililive_PASS >> /root/.credentials
    fi
    if [ -z "$Biliup_PASS" ]; then
        Biliup_PASS=$(openssl rand -base64 12)
        echo Biliup_PASS="$Biliup_PASS" >> /root/.credentials
    else
        echo Biliup_PASS=$Biliup_PASS >> /root/.credentials
    fi
fi
/root/BililiveRecorder/BililiveRecorder.Cli run --bind "http://*:2356" --http-basic-user "$Bililive_USER" --http-basic-pass "$Bililive_PASS" "/rec/录播姬" > /dev/null 2>&1 &
sleep 2
if ! pgrep -f "BililiveRecorder.Cli" > /dev/null; then
  echo "------------------------------------"
  echo "$(date)"
  echo "录播姬启动失败"
  echo "------------------------------------"
else
  echo "------------------------------------"
  echo "$(date)"
  echo "录播姬运行中"
  echo "------------------------------------"
fi
cd /rec/biliup
if [ -f ./watch_process.pid ]; then
  rm -rf ./watch_process.pid
fi
biliup --password "$Biliup_PASS" start > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "$(date)"
  echo "biliup启动失败"
else
  echo "------------------------------------"
  echo "$(date)"
  echo "biliup运行中"
  echo "------------------------------------"
fi
if [ -f "/rec/$FILE_BACKUP_SH" ]; then
    chmod +x "/rec/$FILE_BACKUP_SH"
    echo "备份脚本执行中"
    SCHEDULER_SCRIPT="/usr/local/bin/执行视频备份脚本.sh"
    cat << 'EOB' > "$SCHEDULER_SCRIPT"
#!/bin/bash
schedule_sleep_time="02:00"
while true; do
  echo "$(date)" > /rec/backup.log 2>&1
  echo "----------------------------" >> /rec/backup.log 2>&1
  echo "$FILE_BACKUP_SH脚本开始执行" >> /rec/backup.log 2>&1
  /rec/$FILE_BACKUP_SH
  echo "----------------------------" >> /rec/backup.log 2>&1
  echo "$(date)" >> /rec/backup.log 2>&1
  current_date=$(date +%Y-%m-%d)
  target_time="${current_date} $schedule_sleep_time"
  time_difference=$(( $(date -d "$target_time" +%s) - $(date +%s) ))
  if [[ $time_difference -lt 0 ]]; then
    time_difference=$(( $time_difference + 86400 ))
  fi
  sleep $time_difference
done
EOB
    chmod +x "$SCHEDULER_SCRIPT"
    $SCHEDULER_SCRIPT
else
    echo "------------------------------------"
    echo "备份脚本不存在，可以在启动时指定FILE_BACKUP_SH变量来执行一个sh脚本备份录制的视频"
    echo "------------------------------------"
fi
echo "------------------------------------"
echo "当前录播姬用户名:"
echo "$Bililive_USER"
echo "当前录播姬密码:"
echo "$Bililive_PASS"
echo "------------------------------------"
echo "------------------------------------"
echo "biliup默认用户名为："
echo "biliup"
echo "当前biliup密码:"
echo "$Biliup_PASS"
echo "------------------------------------"
tail -f /dev/null
EOF \
    && chmod +x /usr/local/bin/start.sh
# 设置容器启动时执行的命令
ENTRYPOINT ["/usr/local/bin/start.sh"]
