#!/bin/bash
set -x
# 设置工作目录和备份文件件路径
source_backup="/rec"
# 设置视频源文件夹路径，会处理设置目录中的的文件夹里的视频，不会处理设置目录中的视频
source_folders=(
  "/rec/录播姬/video"
  "/rec/biliup/video"
  # 可以继续添加其它目录
)
# 设置onedrive网盘
rclone_onedrive_config="onedrivevideo5"
# 需要上传视频文件的录制平台。录播姬或者biliup
update_sever="录播姬"
# 服务器名称
sever_name="甲骨文云-1-debian12-1"

# 定义需要检查的库及其apt包名
declare -A libraries
libraries=(
  ["numpy"]="python3-numpy"
  ["matplotlib"]="python3-matplotlib"
  ["scipy"]="python3-scipy"
)

# 生成压制弹幕版上传描述的函数
generate_upload_desc() {
  local stream_title="$1"
  local formatted_start_time_2="$2"

  echo "直播间标题：$stream_title
开播时间：$formatted_start_time_2
录制平台：$recording_platform

原视频文件和往期视频文件：
https://yourls.xct258.top/zbhf-khx
或者
https://openlist.xct258.top
ps：这两是一样的，第二个链接可能会失效，第一个链接会一直使用

括弧笑频道主页：
bilibili
顶级尼鸡塔结晶
https://space.bilibili.com/296620370
高机动持盾军官
https://space.bilibili.com/32223456
acfun
蘑菇的括弧笑
https://www.acfun.cn/u/12909228
鬼屋神狙会
https://www.acfun.cn/u/73177808
youtube
蘑菇的刮弧笑
https://youtube.com/@user-bb8vd2yv7p?si=a9ihQFywCNcQxLaD

括弧笑直播间地址：
bilibili
https://live.bilibili.com/1962720

使用录播姬和biliup录制上传，有问题请站内私信联系xct258
https://space.bilibili.com/33235987

项目地址：
https://github.com/xct258/docker-bililive

非常感谢录播姬和biliup项目
录播姬
https://github.com/BililiveRecorder/BililiveRecorder
biliup
https://github.com/biliup/biliup"
}

# 生成高能切片版上传描述的函数
generate_upload_desc_2() {
  local formatted_start_time_3="$1"

  echo "来源于${formatted_start_time_3}的直播回放
根据弹幕密集自动切片，完整版会在稍后放出

测试中，有任何问题或者建议欢迎留言"
}

# 处理上传成功的状态的函数
handle_upload_status() {
  local upload_success="$1"
  local streamer_name="$2"
  local start_time="$3"

  if $upload_success; then
    echo "${sever_name}

${streamer_name}
${start_time}场

视频上传成功"
  else
    echo "${sever_name}

${streamer_name}
${start_time}场

脚本执行失败！，请检查⚠"
  fi
}

# 安装ffmpeg
if ! command -v ffmpeg &> /dev/null; then
  echo "未检测到 ffmpeg，先安装 ffmpeg"
  if ! apt install -y ffmpeg; then
    echo "ffmpeg 安装失败，退出脚本"
    exit 1
  fi
fi

# 安装wget
if ! command -v wget &> /dev/null; then
  echo "未检测到 wget，先安装 wget"
  if ! apt install -y wget; then
    echo "wget 安装失败，退出脚本"
    exit 1
  fi
fi

# 检查 source_folders 中的文件夹是否存在，不存在则创建,防止脚本报错
for source_folder in "${source_folders[@]}"; do
  if [ ! -d "$source_folder" ]; then
    mkdir -p "$source_folder"
  fi
done
# 创建一个空数组来保存非空目录
directories=()
# 创建一个空数组来保存所有的备份目录
backup_dirs=()

# 查找非空目录
for source_folder in "${source_folders[@]}"; do
  # 找到所有非空的目录
  while IFS= read -r dir; do
    if [ -z "$(find "$dir" -mindepth 1 -type d)" ]; then
      # 将符合条件的目录添加到数组中
      directories+=("$dir")
    fi
  done < <(find "$source_folder" -type d -not -empty | sort)
done

# 遍历每个非空目录
for dir in "${directories[@]}"; do
  upload_success=true
  # 读取所有文件路径
  IFS=$'\n' read -d '' -r -a input_files < <(find "$dir" -type f \( -name "*.ts" -o -name "*.flv" -o -name "*.mp4" -o -name "*.xml" \) | sort)

  # 获取第一个文件的信息，用于提取直播开始时间和主播名称
  first_file="${input_files[0]}"
  # 示例：video/高机动持盾军官/录播姬_2024年12月01日22点13分_暗区最穷_高机动持盾军官.flv
  # 去除文件路径
  base_filename=$(basename "$first_file")
  # 示例：录播姬_2024年12月01日22点13分_暗区最穷_高机动持盾军官.flv

  # 获取开播时间
  start_time=$(echo "$base_filename" | cut -d '_' -f 2 | cut -d '.' -f 1)
  # 示例：2024年12月01日22点13分

  # 获取主播名称
  streamer_name=$(echo "$base_filename" | sed -E 's/.*_(.*)\..*/\1/')
  if [[ "$streamer_name" == "高机动持盾军官" ]]; then
    streamer_name="括弧笑bilibili"
  fi

  # 获取录制平台
  recording_platform=$(echo "$base_filename" | cut -d'_' -f 1)
  # 示例：录播姬

  backup_dir="${source_backup}/backup_${recording_platform}_${streamer_name}_${start_time}"
  mkdir -p $backup_dir
  # 将备份目录添加到数组
  backup_dirs+=("$backup_dir")
  # 将文件移动到临时目录
  for file in "${input_files[@]}"; do
    ext="${file##*.}"  # 获取扩展名（不带点）
    filename="$(basename "$file" ."$ext")"

    if [[ "$ext" == "mp4" ]]; then
      # 是mp4文件，直接移动
      mv "$file" "$backup_dir" || upload_success=false
    elif [[ "$ext" == "flv" || "$ext" == "ts" ]]; then
      # 非mp4视频文件，转换为mp4
      output_file="$backup_dir/${filename}.mp4"
      ffmpeg -i "$file" -c:v copy -c:a copy -v quiet -y "$output_file" && rm "$file" || upload_success=false
    elif [[ "$ext" == "xml" ]]; then
      # XML 文件，直接移动
      mv "$file" "$backup_dir" || upload_success=false
    fi
  done

  # 移动成功后删除目录
  if $upload_success; then
    rm -rf "$dir"
  fi
done

# 按时间排序备份目录
sorted_backup_dirs=($(printf '%s\n' "${backup_dirs[@]}" | sort))

for backup_dir in "${sorted_backup_dirs[@]}"; do

  # 声明数组，用于存储上传到B站视频的文件名
  compressed_files=()
  original_files=()

  # 处理从临时目录获取的文件路径
  IFS=$'\n' read -d '' -r -a input_files < <(find "$backup_dir" -type f | sort)

  # 获取临时目录第一个文件的信息，用于提取直播开始时间和主播名称
  first_file="${input_files[0]}"
  # 示例：video/高机动持盾军官/录播姬_2024年12月01日22点13分_暗区最穷_高机动持盾军官.flv
  # 去除文件路径
  base_filename=$(basename "$first_file")
  # 示例：录播姬_2024年12月01日22点13分_暗区最穷_高机动持盾军官.flv

  # 获取开播时间
  start_time=$(echo "$base_filename" | cut -d '_' -f 2 | cut -d '.' -f 1)
  # 示例：2024年12月01日22点13分
  # 处理开播时间格式
  formatted_start_time_1=$(echo "$start_time" | sed 's/^\(.*点\)[0-9]\+分$/\1/')
  # 示例：2024年12月01日22点
  formatted_start_time_2=$(echo "$start_time" | sed 's/日/日 /')
  # 示例：2024年12月01日 22点13分
  formatted_start_time_3=$(echo "$start_time" | sed -E 's/([0-9]{4})年([0-9]{2})月([0-9]{2})日([0-9]{2})点([0-9]{2})分/\1\/\2\/\1-\2-\3/; s/日/日 /')
  # 示例：2024/12/2024-12-01
  formatted_start_time_4=$(echo "$start_time" | sed -E 's/([0-9]+年[0-9]+月[0-9]+日).*/\1/')
  # 示例：2024年12月01日

  # 获取直播间标题
  stream_title=$(echo "$base_filename" | awk -F'_' '{for (i=3; i<NF-1; i++) printf "%s_", $i; printf "%s\n", $(NF-1)}')
  # 示例：暗区最穷

  # 获取录制平台
  recording_platform=$(echo "$base_filename" | cut -d'_' -f 1)
  # 示例：录播姬

  # 获取主播名称
  streamer_name=$(echo "$base_filename" | sed -E 's/.*_(.*)\..*/\1/')
  if [[ "$streamer_name" == "高机动持盾军官" ]]; then
    streamer_name="括弧笑bilibili"
  fi
  # 投稿高能切片
  if [[ "$streamer_name" == "括弧笑bilibili" && "$recording_platform" == "$update_sever" ]]; then
    biliup_high_energy_clip=$(python3 /rec/获取高能片段.py "$backup_dir")
    
    # 获取封面
    biliup_cover_image=$(python3 /rec/封面获取.py "$backup_dir")


    # 安装xz工具
    if ! command -v xz-utils &> /dev/null; then
      echo "未检测到 xz-utils，先安装 xz-utils"
      if ! apt install -y xz-utils; then
        echo "xz-utils 安装失败，退出脚本"
        exit 1
      fi
    fi

    # 上传到B站
    if [[ ! -f "$source_backup/biliup-rs" ]]; then
      latest_release_biliup_rs=$(curl -s https://api.github.com/repos/biliup/biliup-rs/releases/latest)
      latest_biliup_rs_x64_url=$(echo "$latest_release_biliup_rs" | jq -r ".assets[] | select(.name | test(\"x86_64-linux.tar.xz\")) | .browser_download_url")
      latest_biliup_rs_arm64_url=$(echo "$latest_release_biliup_rs" | jq -r ".assets[] | select(.name | test(\"aarch64-linux.tar.xz\")) | .browser_download_url")

      arch=$(uname -m | grep -i -E "x86_64|aarch64")
      if [[ $arch == *"x86_64"* ]]; then
        wget -O $source_backup/biliup-rs.tar.xz $latest_biliup_rs_x64_url
      elif [[ $arch == *"aarch64"* ]]; then
        wget -O $source_backup/biliup-rs.tar.xz $latest_biliup_rs_arm64_url
      fi
      mkdir $source_backup/biliup-rs-tmp
      tar -xf $source_backup/biliup-rs.tar.xz -C $source_backup/biliup-rs-tmp
      rm -rf $source_backup/biliup-rs.tar.xz
      biliup_file=$(find $source_backup/biliup-rs-tmp -type f -name "biliup")
      mv $biliup_file $source_backup/biliup-rs
      rm -rf $source_backup/biliup-rs-tmp
    fi
    chmod +x $source_backup/biliup-rs


    # 构建视频标题
    #upload_title_2="括弧笑${formatted_start_time_4}直播回放抢先版"
    # 构建视频简介
    #upload_desc_2=$(generate_upload_desc_2 "$formatted_start_time_4")
    #biliup_upload_output_2=$($source_backup/biliup-rs -u "$source_backup"/cookies-烦心事远离.json upload --copyright 2 --cover "$biliup_cover_image" --source https://live.bilibili.com/1962720 --tid 17 --title "$upload_title_2" --desc "$upload_desc_2" --tag "搞笑,直播回放,奶茶猪,高机动持盾军官,括弧笑,娱乐主播,切片" "${biliup_high_energy_clip}")
    #if echo "$biliup_upload_output_2" | grep -q "成功"; then
    #  echo "上传成功，删除高能切片文件: $biliup_high_energy_clip"
    #  rm -f "$biliup_high_energy_clip"
    #else
    #  echo "上传失败，保留高能切片文件"
    #fi
  fi

  for video_file in "${input_files[@]}"; do
    if [[ -f "$video_file" ]]; then
      # 获取文件名（不带路径）
      filename=$(basename "$video_file")
      # 示例：录播姬_2024年12月01日22点13分_暗区最穷_高机动持盾军官.flv

      # 获取文件名（不带扩展名）
      filename_no_ext="${filename%.*}"
      # 示例：录播姬_2024年12月01日22点13分_暗区最穷_高机动持盾军官

      if [[ "$streamer_name" == "括弧笑bilibili" && "$recording_platform" == "$update_sever" ]]; then
        if [[ "$filename" == *.mp4 ]]; then
          xml_file="${filename_no_ext}.xml"
          ass_file="${filename_no_ext}.ass"
          output_file="压制版-${filename_no_ext}.mp4"
          if [[ -f "${backup_dir}/${xml_file}" ]]; then
            # 使用 DanmakuFactory 生成 ASS 弹幕文件
            chmod +x /DanmakuFactory
            /DanmakuFactory -i "${backup_dir}/${xml_file}" -o "${backup_dir}/${ass_file}" -S 50 -O 230 --ignore-warnings > /dev/null || upload_success=false

            # 压制弹幕
            if lspci | grep -i "VGA\|Display" | grep -i "Intel Corporation" > /dev/null; then
              # 检查是否已安装 Intel 显卡驱动
              if ! vainfo > /dev/null 2>&1; then
                echo "未安装 Intel 显卡驱动。正在安装驱动..."
                # 安装所需的软件包
                apt update
                apt install -y gpg wget
                # 下载并添加 Intel 显卡软件仓库的 GPG 密钥
                wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
                gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg
                echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
                tee /etc/apt/sources.list.d/intel-gpu-jammy.list
                # 更新软件包列表
                apt update
                # 安装 Intel 显卡驱动相关的软件包
                apt install -y intel-media-va-driver-non-free libmfx1 libmfxgen1 libvpl2 va-driver-all vainfo
              fi
            fi

            # 检查并安装缺失的库
            for lib in "${!libraries[@]}"; do
              if ! python3 -c "import $lib" &> /dev/null; then
                echo "$lib 未安装，正在通过 apt 安装 ${libraries[$lib]} ..."
                apt install -y "${libraries[$lib]}"
              else
                echo "$lib 已安装"
              fi
            done

            # 使用py脚本压制视频
            python3 /rec/压制视频.py "${backup_dir}/${xml_file}"

            # 添加压制弹幕版到数组
            compressed_files+=("${backup_dir}/${output_file}")
            # 删除生成的 ASS 弹幕文件
            rm -f "${backup_dir}/${ass_file}" || upload_success=false
          else
            # 添加视频到数组
            compressed_files+=("${backup_dir}/${filename}")
          fi
          # 同时将原始视频文件添加到原始文件数组
          original_files+=("${backup_dir}/${filename}")
        fi
      fi
    fi
  done

  if [[ "$streamer_name" == "括弧笑bilibili" && "$recording_platform" == "$update_sever" ]]; then
    # 构建视频标题
    upload_title_1="括弧笑${formatted_start_time_4}直播回放"
    # 构建视频简介
    upload_desc_1=$(generate_upload_desc "$stream_title" "$formatted_start_time_2")

    # 延时发布
    # 获取当前时间的时间戳
    #current_time_biliup_rs=$(date +%s)
    # 计算6小时后的时间戳
    #delay_time_biliup_rs=$((current_time_biliup_rs + 6 * 3600))
    #$source_backup/biliup-rs -u $source_backup/cookies.json upload --copyright 2 --source https://live.bilibili.com/1962720 --tid 17 --title "$upload_title_1" --desc "$upload_desc_1" --tag "搞笑,直播回放,奶茶猪,高机动持盾军官,括弧笑,娱乐主播" --dtime ${delay_time_biliup_rs} "${compressed_files[@]}"

    # 正常发布
    biliup_upload_output=$($source_backup/biliup-rs -u "$source_backup"/cookies-烦心事远离.json upload --copyright 2 --cover "$biliup_cover_image" --source https://live.bilibili.com/1962720 --tid 17 --title "$upload_title_1" --desc "$upload_desc_1" --tag "搞笑,直播回放,奶茶猪,高机动持盾军官,括弧笑,娱乐主播" "${compressed_files[@]}")
    # 备份压制弹幕版文件，下次执行时会删除
    danmu_version_backup_dir="${source_backup}/压制版视频文件备份"
    # 查找以"压制弹幕版-"开头的文件
    if ls "${backup_dir}/压制版-"* 1> /dev/null 2>&1; then
      # 检查文件夹是否存在
      if [ -d "$danmu_version_backup_dir" ]; then
        rm -rf "$danmu_version_backup_dir"
        mkdir -p "$danmu_version_backup_dir"
      else
        mkdir -p "$danmu_version_backup_dir"
      fi
      mv "${backup_dir}/压制版-"* "$danmu_version_backup_dir"
    fi
  fi

  # 备份到rclone脚本
  if [[ "$streamer_name" == "括弧笑bilibili" ]]; then
    # rclone 网盘路径
    rclone_backup_path="$rclone_onedrive_config:/直播录制/括弧笑/"
  else
    # rclone 网盘路径
    rclone_backup_path="$rclone_onedrive_config:/直播录制/${streamer_name}/"
  fi
  # 上传rclone命令
  rclone move "$backup_dir" "${rclone_backup_path}${formatted_start_time_3}/bilibili/$recording_platform/"  || upload_success=false

  # 检查备份目录是否为空
  if [ -z "$(ls -A "$backup_dir")" ]; then
    rmdir "$backup_dir"
  fi

  # 推送消息
  message=$(handle_upload_status "$upload_success" "$streamer_name" "$start_time")

  # 推送消息命令
  curl -s -X POST "https://msgpusher.xct258.top/push/root" \
    -d "title=直播录制&description=直播录制&channel=一般通知&content=$message" \
  >/dev/null
done
