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
    # 安装必要的软件包
    && apt-get install -y wget git curl nano jq bc tar xz-utils ffmpeg pciutils fontconfig procps python3-pip \
    # 创建字体目录
    && mkdir -p /root/.fonts/ \
    # 下载 Segoe Emoji 字体
    && wget -O "/root/.fonts/seguiemj.ttf" https://raw.githubusercontent.com/xct258/docker-bililive/refs/heads/main/字体/seguiemj.ttf \
    # 下载 微软雅黑 字体
    && wget -O "/root/.fonts/微软雅黑.ttf" https://raw.githubusercontent.com/xct258/docker-bililive/refs/heads/main/字体/微软雅黑.ttf \
    # 更新字体缓存
    && fc-cache -f -v \
    # 安装rclone
    && apt install rclone -y \
    # 创建工作目录
    && mkdir -p /rec/biliup \
    && mkdir -p /rec/录播姬 \
    # 创建临时目录
    && mkdir -p /root/tmp \
    # 创建临时脚本
    && echo '#!/bin/bash' > /root/tmp/tmp.sh \
    && echo 'latest_release_7z=$(curl -s https://api.github.com/repos/ip7z/7zip/releases/latest)' >> /root/tmp/tmp.sh \
    && echo 'latest_7z_x64_url=$(echo "$latest_release_7z" | jq -r ".assets[] | select(.name | test(\"linux-x64.tar.xz\")) | .browser_download_url")' >> /root/tmp/tmp.sh \
    && echo 'latest_7z_arm64_url=$(echo "$latest_release_7z" | jq -r ".assets[] | select(.name | test(\"linux-arm64.tar.xz\")) | .browser_download_url")' >> /root/tmp/tmp.sh \
    && echo 'arch=$(uname -m | grep -i -E "x86_64|aarch64")' >> /root/tmp/tmp.sh \
    && echo 'if [[ $arch == *"x86_64"* ]]; then' >> /root/tmp/tmp.sh \
    && echo '    wget -O /root/tmp/7zz.tar.xz "$latest_7z_x64_url"' >> /root/tmp/tmp.sh \
    && echo '    wget -O /root/tmp/BililiveRecorder-CLI.zip https://github.com/BililiveRecorder/BililiveRecorder/releases/latest/download/BililiveRecorder-CLI-linux-x64.zip' >> /root/tmp/tmp.sh \
    && echo '    wget -O /DanmakuFactory https://raw.githubusercontent.com/xct258/docker-bililive/refs/heads/main/DanmakuFactory/DanmakuFactory-amd64' >> /root/tmp/tmp.sh \
    && echo 'elif [[ $arch == *"aarch64"* ]]; then' >> /root/tmp/tmp.sh \
    && echo '    wget -O /root/tmp/7zz.tar.xz "$latest_7z_arm64_url"' >> /root/tmp/tmp.sh \
    && echo '    wget -O /root/tmp/BililiveRecorder-CLI.zip https://github.com/BililiveRecorder/BililiveRecorder/releases/latest/download/BililiveRecorder-CLI-linux-arm64.zip' >> /root/tmp/tmp.sh \
    && echo '    wget -O /DanmakuFactory https://raw.githubusercontent.com/xct258/docker-bililive/refs/heads/main/DanmakuFactory/DanmakuFactory-arm64' >> /root/tmp/tmp.sh \
    && echo 'fi' >> /root/tmp/tmp.sh \
    # 赋予脚本执行权限
    && chmod +x /root/tmp/tmp.sh \
    # 执行下载脚本
    && /root/tmp/tmp.sh \
    # 解压下载的 7zip
    && tar -xf /root/tmp/7zz.tar.xz -C /root/tmp \
    # 赋予解压后的 7zz 执行权限
    && chmod +x /root/tmp/7zz \
    # 移动 7zz 到 /bin 目录
    && mv /root/tmp/7zz /bin/7zz \
    # 使用 7zz 解压 BililiveRecorder CLI
    && 7zz x /root/tmp/BililiveRecorder-CLI.zip -o/root/BililiveRecorder \
    # 赋予 BililiveRecorder CLI 执行权限
    && chmod +x /root/BililiveRecorder/BililiveRecorder.Cli \
    # 安装biliup
    && pip3 install biliup --break-system-packages \
    # 清理临时文件
    && rm -rf /root/tmp \
    
    # 创建启动脚本
    && echo '#!/bin/bash' >> /usr/local/bin/start.sh \
    # 创建工作目录
    && echo 'mkdir -p /rec/biliup' >> /usr/local/bin/start.sh \
    && echo 'mkdir -p /rec/录播姬' >> /usr/local/bin/start.sh \
    && echo 'if [ -n "$XCT258_GITHUB_TOKEN" ]; then' >> /usr/local/bin/start.sh \
    && echo '  echo "检测到 XCT258_GITHUB_TOKEN，准备检查并下载私有配置文件..."' >> /usr/local/bin/start.sh \
    && echo '  mkdir -p /root/.config/rclone' >> /usr/local/bin/start.sh \
    && echo '  if [ ! -f "/root/.config/rclone/rclone.conf" ]; then' >> /usr/local/bin/start.sh \
    && echo '    echo "未检测到 rclone.conf，开始下载..."' >> /usr/local/bin/start.sh \
    && echo '    wget --header="Authorization: token $XCT258_GITHUB_TOKEN" -O "/root/.config/rclone/rclone.conf" "https://raw.githubusercontent.com/xct258/Documentation/refs/heads/main/服务器相关/other/rclone配置文件有效期25-11"' >> /usr/local/bin/start.sh \
    && echo '  else' >> /usr/local/bin/start.sh \
    && echo '    echo "已存在 rclone.conf，跳过下载"' >> /usr/local/bin/start.sh \
    && echo '  fi' >> /usr/local/bin/start.sh \
    && echo '  if [ ! -f "/rec/cookies-烦心事远离.json" ]; then' >> /usr/local/bin/start.sh \
    && echo '    echo "未检测到 cookies-烦心事远离.json，开始下载..."' >> /usr/local/bin/start.sh \
    && echo '    wget --header="Authorization: token $XCT258_GITHUB_TOKEN" -O "/rec/cookies-烦心事远离.json" "https://raw.githubusercontent.com/xct258/Documentation/refs/heads/main/b站cookies/cookies-b站-烦心事远离.json"' >> /usr/local/bin/start.sh \
    && echo '  else' >> /usr/local/bin/start.sh \
    && echo '    echo "已存在 cookies-烦心事远离.json，跳过下载"' >> /usr/local/bin/start.sh \
    && echo '  fi' >> /usr/local/bin/start.sh \
    && echo '  if [ ! -f "/rec/biliup/cookies-xct258-2.json" ]; then' >> /usr/local/bin/start.sh \
    && echo '    echo "未检测到 cookies-xct258-2.json，开始下载..."' >> /usr/local/bin/start.sh \
    && echo '    wget --header="Authorization: token $XCT258_GITHUB_TOKEN" -O "/rec/biliup/cookies-xct258-2.json" "https://raw.githubusercontent.com/xct258/Documentation/refs/heads/main/b站cookies/cookies-b站-xct258-2.json"' >> /usr/local/bin/start.sh \
    && echo '  else' >> /usr/local/bin/start.sh \
    && echo '    echo "已存在 cookies-xct258-2.json，跳过下载"' >> /usr/local/bin/start.sh \
    && echo '  fi' >> /usr/local/bin/start.sh \
    && echo 'fi' >> /usr/local/bin/start.sh \
    && echo 'if [ -f /root/.credentials ]; then' >> /usr/local/bin/start.sh \
    && echo '    source /root/.credentials' >> /usr/local/bin/start.sh \
    && echo 'else' >> /usr/local/bin/start.sh \
    && echo '    if [ -z "$Bililive_USER" ]; then' >> /usr/local/bin/start.sh \
    && echo '        Bililive_USER="xct258"' >> /usr/local/bin/start.sh \
    && echo '        echo Bililive_USER="$Bililive_USER" > /root/.credentials' >> /usr/local/bin/start.sh \
    && echo '    else' >> /usr/local/bin/start.sh \
    && echo '        echo Bililive_USER="$Bililive_USER" > /root/.credentials' >> /usr/local/bin/start.sh \
    && echo '    fi' >> /usr/local/bin/start.sh \
    && echo '    if [ -z "$Bililive_PASS" ]; then' >> /usr/local/bin/start.sh \
    && echo '        Bililive_PASS=$(openssl rand -base64 12)' >> /usr/local/bin/start.sh \
    && echo '        echo Bililive_PASS="$Bililive_PASS" >> /root/.credentials' >> /usr/local/bin/start.sh \
    && echo '    else' >> /usr/local/bin/start.sh \
    && echo '        Bililive_PASS=$Bililive_PASS >> /root/.credentials' >> /usr/local/bin/start.sh \
    && echo '    fi' >> /usr/local/bin/start.sh \
    && echo '    if [ -z "$Biliup_PASS" ]; then' >> /usr/local/bin/start.sh \
    && echo '        Biliup_PASS=$(openssl rand -base64 12)' >> /usr/local/bin/start.sh \
    && echo '        echo Biliup_PASS="$Biliup_PASS" >> /root/.credentials' >> /usr/local/bin/start.sh \
    && echo '    else' >> /usr/local/bin/start.sh \
    && echo '        Biliup_PASS=$Biliup_PASS >> /root/.credentials' >> /usr/local/bin/start.sh \
    && echo '    fi' >> /usr/local/bin/start.sh \
    && echo 'fi' >> /usr/local/bin/start.sh \
    # 启动 BililiveRecorder
    && echo '/root/BililiveRecorder/BililiveRecorder.Cli run --bind "http://*:2356" --http-basic-user "$Bililive_USER" --http-basic-pass "$Bililive_PASS" "/rec/录播姬" > /dev/null 2>&1 &' >> /usr/local/bin/start.sh \
    # 检查录播姬是否启动成功
    && echo 'sleep 2' >> /usr/local/bin/start.sh \
    && echo 'if ! pgrep -f "BililiveRecorder.Cli" > /dev/null; then' >> /usr/local/bin/start.sh \
    && echo '  echo "------------------------------------"' >> /usr/local/bin/start.sh \
    && echo '  echo "$(date)"' >> /usr/local/bin/start.sh \
    && echo '  echo "录播姬启动失败"' >> /usr/local/bin/start.sh \
    && echo '  echo "------------------------------------"' >> /usr/local/bin/start.sh \
    && echo 'else' >> /usr/local/bin/start.sh \
    && echo '  echo "------------------------------------"' >> /usr/local/bin/start.sh \
    && echo '  echo "$(date)"' >> /usr/local/bin/start.sh \
    && echo '  echo "录播姬运行中"' >> /usr/local/bin/start.sh \
    && echo '  echo "------------------------------------"' >> /usr/local/bin/start.sh \
    && echo 'fi' >> /usr/local/bin/start.sh \
    # 切换到biliup工作目录
    && echo 'cd /rec/biliup' >> /usr/local/bin/start.sh \
    # 启动biliup
    && echo 'if [ -f ./watch_process.pid ]; then' >> /usr/local/bin/start.sh \
    && echo '  rm -rf ./watch_process.pid' >> /usr/local/bin/start.sh \
    && echo 'fi' >> /usr/local/bin/start.sh \
    && echo 'biliup --password "$Biliup_PASS" start > /dev/null 2>&1' >> /usr/local/bin/start.sh \
    && echo 'if [ $? -ne 0 ]; then' >> /usr/local/bin/start.sh \
    && echo '  echo "$(date)"' >> /usr/local/bin/start.sh \
    && echo '  echo "biliup启动失败"' >> /usr/local/bin/start.sh \
    && echo 'else' >> /usr/local/bin/start.sh \
    && echo '  echo "------------------------------------"' >> /usr/local/bin/start.sh \
    && echo '  echo "$(date)"' >> /usr/local/bin/start.sh \
    && echo '  echo "biliup运行中"' >> /usr/local/bin/start.sh \
    && echo '  echo "------------------------------------"' >> /usr/local/bin/start.sh \
    && echo 'fi' >> /usr/local/bin/start.sh \
    # 检查备份脚本是否存在
    && echo '# 检查备份脚本是否存在' >> /usr/local/bin/start.sh \
    && echo 'if [ -f "/rec/$FILE_BACKUP_SH" ]; then' >> /usr/local/bin/start.sh \
    # 赋予备份脚本执行权限
    && echo '    chmod +x "/rec/$FILE_BACKUP_SH"' >> /usr/local/bin/start.sh \
    # 提示备份脚本正在执行
    && echo '    echo "备份脚本执行中"' >> /usr/local/bin/start.sh \
    # 创建调度脚本
    && echo '    # 创建调度脚本' >> /usr/local/bin/start.sh \
    && echo '    SCHEDULER_SCRIPT="/usr/local/bin/执行视频备份脚本.sh"' >> /usr/local/bin/start.sh \
    # 写入调度脚本内容
    && echo 'cat << EOF > "$SCHEDULER_SCRIPT"' >> /usr/local/bin/start.sh \
    && echo '#!/bin/bash' >> /usr/local/bin/start.sh \
    && echo 'schedule_sleep_time="02:00"' >> /usr/local/bin/start.sh \
    && echo 'while true; do' >> /usr/local/bin/start.sh \
    && echo '  echo "\$(date)" > /rec/backup.log 2>&1' >> /usr/local/bin/start.sh \
    && echo '  echo "----------------------------" >> /rec/backup.log 2>&1' >> /usr/local/bin/start.sh \
    && echo '  /rec/\$FILE_BACKUP_SH >> /rec/backup.log 2>&1' >> /usr/local/bin/start.sh \
    && echo '  echo "----------------------------" >> /rec/backup.log 2>&1' >> /usr/local/bin/start.sh \
    && echo '  echo "\$(date)" >> /rec/backup.log 2>&1' >> /usr/local/bin/start.sh \
    && echo '  current_date=\$(date +%Y-%m-%d)' >> /usr/local/bin/start.sh \
    && echo '  target_time="\${current_date} \$schedule_sleep_time"' >> /usr/local/bin/start.sh \
    # 计算时间差
    && echo '  time_difference=\$(( \$(date -d "\$target_time" +%s) - \$(date +%s) ))' >> /usr/local/bin/start.sh \
    # 如果时间差小于0，调整为第二天
    && echo '  if [[ \$time_difference -lt 0 ]]; then' >> /usr/local/bin/start.sh \
    && echo '    time_difference=\$(( \$time_difference + 86400 ))' >> /usr/local/bin/start.sh \
    && echo '  fi' >> /usr/local/bin/start.sh \
    # 睡眠直到下一个备份时间
    && echo '  sleep \$time_difference' >> /usr/local/bin/start.sh \
    && echo 'done' >> /usr/local/bin/start.sh \
    && echo 'EOF' >> /usr/local/bin/start.sh \
    # 赋予调度脚本执行权限
    && echo '    chmod +x "$SCHEDULER_SCRIPT"' >> /usr/local/bin/start.sh \
    # 启动调度脚本
    && echo '    $SCHEDULER_SCRIPT' >> /usr/local/bin/start.sh \
    && echo 'else' >> /usr/local/bin/start.sh \
    # 提示用户备份脚本不存在
    && echo '    echo "------------------------------------"' >> /usr/local/bin/start.sh \
    && echo '    echo "备份脚本不存在，可以在启动时指定FILE_BACKUP_SH变量来执行一个sh脚本备份录制的视频"' >> /usr/local/bin/start.sh \
    && echo '    echo "------------------------------------"' >> /usr/local/bin/start.sh \
    && echo 'fi' >> /usr/local/bin/start.sh \
    && echo 'echo "------------------------------------"' >> /usr/local/bin/start.sh \
    && echo 'echo "当前录播姬用户名:"' >> /usr/local/bin/start.sh \
    && echo 'echo "$Bililive_USER"' >> /usr/local/bin/start.sh \
    && echo 'echo "当前录播姬密码:"' >> /usr/local/bin/start.sh \
    && echo 'echo "$Bililive_PASS"' >> /usr/local/bin/start.sh \
    && echo 'echo "------------------------------------"' >> /usr/local/bin/start.sh \
    && echo 'echo "------------------------------------"' >> /usr/local/bin/start.sh \
    && echo 'echo "biliup默认用户名为："' >> /usr/local/bin/start.sh \
    && echo 'echo "biliup"' >> /usr/local/bin/start.sh \
    && echo 'echo "当前biliup密码:"' >> /usr/local/bin/start.sh \
    && echo 'echo "$Biliup_PASS"' >> /usr/local/bin/start.sh \
    && echo 'echo "------------------------------------"' >> /usr/local/bin/start.sh \
    # 保持容器运行
    && echo 'tail -f /dev/null' >> /usr/local/bin/start.sh \
    # 赋予启动脚本执行权限
    && chmod +x /usr/local/bin/start.sh
# 设置容器启动时执行的命令
ENTRYPOINT ["/usr/local/bin/start.sh"]
