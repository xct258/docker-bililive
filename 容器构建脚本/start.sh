#!/bin/bash

mkdir -p /rec/biliup/脚本
mkdir -p /rec/录播姬
mkdir -p /rec/脚本
mkdir -p /rec/apps

# 配置文件单独处理
if [ ! -f /rec/上传备份脚本配置文件.conf ]; then
    cp /opt/bililive/config/上传备份脚本配置文件.conf /rec/
fi

# 复制 /opt/bililive/biliup 到 /rec/biliup/脚本
for file in /opt/bililive/biliup/*; do
    filename=$(basename "$file")
    target="/rec/biliup/脚本/$filename"
    if [ -f "$file" ] && [ ! -f "$target" ]; then
        cp "$file" "$target"
    fi
done

# 复制 /opt/bililive/scripts 到 /rec/脚本
for file in /opt/bililive/scripts/*; do
    filename=$(basename "$file")
    target="/rec/脚本/$filename"
    if [ -f "$file" ] && [ ! -f "$target" ]; then
        cp "$file" "$target"
    fi
done

# 复制 /opt/bililive/apps 到 /rec/apps
for file in /opt/bililive/apps/*; do
    filename=$(basename "$file")
    target="/rec/apps/$filename"
    if [ -f "$file" ] && [ ! -f "$target" ]; then
        cp "$file" "$target"
    fi
done

# 下载私有配置文件（需 GitHub Token）
if [ -n "$XCT258_GITHUB_TOKEN" ]; then

  # 检查是否有文件缺失，只有缺失时才下载
  missing_file=false

  [ ! -f "/root/.config/rclone/rclone.conf" ] && missing_file=true
  [ ! -f "/rec/cookies/bilibili/cookies-烦心事远离.json" ] && missing_file=true
  [ ! -f "/rec/cookies/bilibili/cookies-xct258-2.json" ] && missing_file=true

  if $missing_file; then
    echo "检测到 XCT258_GITHUB_TOKEN，正在静默下载私有配置文件..."

    mkdir -p /root/.config/rclone
    mkdir -p /rec/cookies/bilibili

    download_all_success=true

    if [ ! -f "/root/.config/rclone/rclone.conf" ]; then
      wget --quiet --header="Authorization: token $XCT258_GITHUB_TOKEN" \
        -O "/root/.config/rclone/rclone.conf" \
        "https://raw.githubusercontent.com/xct258/Documentation/refs/heads/main/rclone/rclone.conf" || download_all_success=false
    fi

    if [ ! -f "/rec/cookies/bilibili/cookies-烦心事远离.json" ]; then
      wget --quiet --header="Authorization: token $XCT258_GITHUB_TOKEN" \
        -O "/rec/cookies/bilibili/cookies-烦心事远离.json" \
        "https://raw.githubusercontent.com/xct258/Documentation/refs/heads/main/b站cookies/cookies-b站-烦心事远离.json" || download_all_success=false
    fi

    if [ ! -f "/rec/cookies/bilibili/cookies-xct258-2.json" ]; then
      wget --quiet --header="Authorization: token $XCT258_GITHUB_TOKEN" \
        -O "/rec/cookies/bilibili/cookies-xct258-2.json" \
        "https://raw.githubusercontent.com/xct258/Documentation/refs/heads/main/b站cookies/cookies-b站-xct258-2.json" || download_all_success=false
    fi

    if $download_all_success; then
      echo "✅ 私有配置文件全部已下载完成。"
    else
      echo "⚠️ 私有配置文件部分下载失败，请检查 GitHub Token 或网络连接。"
    fi
  fi
fi

# 初始化登录账户密码
if [ -f /root/.credentials ]; then
  source /root/.credentials
else
  touch /root/.credentials

  if [ -z "$Bililive_USER" ]; then
    Bililive_USER="xct258"
  fi
  echo Bililive_USER="$Bililive_USER" >> /root/.credentials

  if [ -z "$Bililive_PASS" ]; then
    Bililive_PASS=$(openssl rand -base64 12)
  fi
  echo Bililive_PASS="$Bililive_PASS" >> /root/.credentials

  if [ -z "$Biliup_PASS" ]; then
    Biliup_PASS=$(openssl rand -base64 12)
  fi
  echo Biliup_PASS="$Biliup_PASS" >> /root/.credentials
fi

# 启动 BililiveRecorder
/root/BililiveRecorder/BililiveRecorder.Cli run --bind "http://*:2356" --http-basic-user "$Bililive_USER" --http-basic-pass "$Bililive_PASS" "/rec/录播姬" > /dev/null 2>&1 &

# 检查 Bililive 是否启动成功
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

# 启动 biliup
cd /rec/biliup

[ -f ./watch_process.pid ] && rm -rf ./watch_process.pid

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

# 创建并启动每日视频上传备份定时任务
SCHEDULER_SCRIPT="/usr/local/bin/执行视频备份脚本.sh"

cat << 'EOF' > "$SCHEDULER_SCRIPT"
#!/bin/bash

CONFIG_FILE="/rec/上传备份脚本配置文件.conf"
DEFAULT_SLEEP_TIME="02:00"

while true; do
  # 读取配置文件
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
  else
    echo "配置文件不存在，使用默认设置" >> /rec/录播上传备份脚本.log 2>&1
    ENABLE_UPLOAD_SCRIPT=false
    SCHEDULE_SLEEP_TIME="$DEFAULT_SLEEP_TIME"
  fi

  # 如果未启用，则跳过执行
  if [[ "$ENABLE_UPLOAD_SCRIPT" != "true" ]]; then
    echo "$(date)" > /rec/录播上传备份脚本.log 2>&1
    echo "----------------------------" >> /rec/录播上传备份脚本.log 2>&1
    echo "已禁用上传脚本执行，跳过本次任务。" >> /rec/录播上传备份脚本.log 2>&1
    echo "----------------------------" >> /rec/录播上传备份脚本.log 2>&1
    echo "$(date)" >> /rec/录播上传备份脚本.log 2>&1
  else
    echo "$(date)" > /rec/录播上传备份脚本.log 2>&1
    echo "----------------------------" >> /rec/录播上传备份脚本.log 2>&1
    /rec/脚本/录播上传备份脚本.sh >> /rec/录播上传备份脚本.log 2>&1
    echo "----------------------------" >> /rec/录播上传备份脚本.log 2>&1
    echo "$(date)" >> /rec/录播上传备份脚本.log 2>&1
  fi

  # 计算下次执行时间
  current_date=$(date +%Y-%m-%d)
  target_time="${current_date} ${SCHEDULE_SLEEP_TIME:-$DEFAULT_SLEEP_TIME}"
  time_difference=$(( $(date -d "$target_time" +%s) - $(date +%s) ))

  if [[ $time_difference -lt 0 ]]; then
    time_difference=$(( time_difference + 86400 ))  # 加一天
  fi

  echo "睡眠 $time_difference 秒，等待下次执行时间 $target_time" >> /rec/录播上传备份脚本.log 2>&1
  sleep $time_difference
done
EOF

chmod +x "$SCHEDULER_SCRIPT"
"$SCHEDULER_SCRIPT" &

# 输出账户信息
echo "------------------------------------"
echo "当前录播姬用户名:"
echo "$Bililive_USER"
echo "当前录播姬密码:"
echo "$Bililive_PASS"
echo "------------------------------------"
echo "biliup默认用户名为："
echo "biliup"
echo "当前biliup密码:"
echo "$Biliup_PASS"
echo "------------------------------------"

# 保持容器运行
tail -f /dev/null
