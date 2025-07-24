#!/bin/bash

# 定义源目录和文件清单
SRC_DIR=/opt/bililive/scripts
FILES=(
    录播上传备份脚本.sh
    biliup后处理.sh
    压制视频.py
    封面获取.py
    log.sh
)

# 配置文件单独处理
if [ ! -f /rec/上传备份脚本配置文件.conf ]; then
    cp /opt/bililive/config/上传备份脚本配置文件.conf /rec/
fi

# 逐个检查脚本文件是否存在
for file in "${FILES[@]}"; do
    if [ ! -f "/rec/脚本/$file" ]; then
        cp "$SRC_DIR/$file" "/rec/脚本/$file"
    fi
done


# 下载私有配置文件（需 GitHub Token）
if [ -n "$XCT258_GITHUB_TOKEN" ]; then
  echo "检测到 XCT258_GITHUB_TOKEN，准备检查并下载私有配置文件..."

  mkdir -p /root/.config/rclone
  if [ ! -f "/root/.config/rclone/rclone.conf" ]; then
    echo "未检测到 rclone.conf，开始下载..."
    wget --header="Authorization: token $XCT258_GITHUB_TOKEN" \
      -O "/root/.config/rclone/rclone.conf" \
      "https://raw.githubusercontent.com/xct258/Documentation/refs/heads/main/rclone/rclone.conf"
  fi

  if [ ! -f "/rec/cookies/bilibili/cookies-烦心事远离.json" ]; then
    echo "未检测到 cookies-烦心事远离.json，开始下载..."
    wget --header="Authorization: token $XCT258_GITHUB_TOKEN" \
      -O "/rec/cookies/bilibili/cookies-烦心事远离.json" \
      "https://raw.githubusercontent.com/xct258/Documentation/refs/heads/main/b站cookies/cookies-b站-烦心事远离.json"
  fi

  if [ ! -f "/rec/cookies/bilibili/cookies-xct258-2.json" ]; then
    echo "未检测到 cookies-xct258-2.json，开始下载..."
    wget --header="Authorization: token $XCT258_GITHUB_TOKEN" \
      -O "/rec/cookies/bilibili/cookies-xct258-2.json" \
      "https://raw.githubusercontent.com/xct258/Documentation/refs/heads/main/b站cookies/cookies-b站-xct258-2.json"
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
/root/BililiveRecorder/BililiveRecorder.Cli run \
  --bind "http://*:2356" \
  --http-basic-user "$Bililive_USER" \
  --http-basic-pass "$Bililive_PASS" > /dev/null 2>&1 &

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
schedule_sleep_time="02:00"
while true; do
  echo "$(date)" > /rec/录播上传备份脚本.log 2>&1
  echo "----------------------------" >> /rec/录播上传备份脚本.log 2>&1
  /rec/脚本/录播上传备份脚本.sh >> /rec/录播上传备份脚本.log 2>&1
  echo "----------------------------" >> /rec/录播上传备份脚本.log 2>&1
  echo "$(date)" >> /rec/录播上传备份脚本.log 2>&1

  current_date=$(date +%Y-%m-%d)
  target_time="${current_date} ${schedule_sleep_time}"
  time_difference=$(( $(date -d "$target_time" +%s) - $(date +%s) ))

  if [[ $time_difference -lt 0 ]]; then
    time_difference=$(( time_difference + 86400 ))
  fi

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
