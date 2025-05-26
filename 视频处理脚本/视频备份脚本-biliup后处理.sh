#!/bin/bash
set -x
# 定义上传的OneDrive网盘
rclone_onedrive_config="onedrivevideo2"
# 服务器名称
sever_name="甲骨文-1-debian12-1-biliup"

# 读取输入数据并存入数组
input_files=()
while read line; do
    input_files+=("$line")
done

# 获取第一个文件的信息，用于提取直播开始时间和主播名称
first_file="${input_files[0]}"
# 示例：/home/xct258/biliup1/biliup_2024年06月29日20点15分_三脚猫行动_括弧笑bilibili.flv

# 去除文件路径
base_filename=$(basename "$first_file")
# 示例：biliup_2024年06月29日20点15分_三脚猫行动_括弧笑bilibili.flv

# 获取开播时间
broadcast_start_time=$(echo "$base_filename" | cut -d '_' -f 2 | cut -d '.' -f 1)
# 示例：2024年06月29日20点15分

# 处理开播时间格式
formatted_start_time_1=$(echo "$broadcast_start_time" | sed 's/^\(.*点\)[0-9]\+分$/\1/')
# 示例：2024年06月29日20点
formatted_start_time_2=$(echo "$broadcast_start_time" | sed 's/日/日 /')
# 示例：2024年06月29日 20点15分
formatted_start_time_3=$(echo "$broadcast_start_time" | sed -E 's/.*([0-9]{4})年([0-9]{2})月([0-9]{2})日([0-9]{2})点([0-9]{2})分/\1\/\2\/\1-\2-\3/')
# 示例：2024/06/2024-06-29

# 获取直播间标题
stream_title=$(echo "$base_filename" | sed -E 's/^[^_]*_[^_]*_([^_]+)_.*/\1/')
# 示例：三脚猫行动

# 获取录制平台
recording_platform=$(echo "$base_filename" | cut -d'_' -f 1)
# 实例：biliup

# 获取主播名称
streamer_name=$(echo "$base_filename" | sed -E 's/.*_(.*)\..*/\1/')
# 获取主播名称
streamer_name=$(echo "$base_filename" | sed -E 's/.*_(.*)\..*/\1/')

# 创建备份目录
backup_dir="backup_${streamer_name}_${broadcast_start_time}"
mkdir -p "$backup_dir"

# 遍历每个文件并移动到备份目录
for input_file in "${input_files[@]}"; do
    mv "$input_file" "$backup_dir/"
done

# 遍历当前文件夹的所有文件
for video_file in $backup_dir/*; do
    # 确保只处理文件而不是目录
    if [[ -f "$video_file" ]]; then
        # 获取文件名（不带路径）
        filename=$(basename "$video_file")
        # 示例：biliup_2024年06月29日20点15分_三脚猫行动_括弧笑bilibili.flv

        # 获取文件名（不带扩展名）
        filename_no_ext="${filename%.*}"
        # 示例：biliup_2024年06月29日20点15分_三脚猫行动_括弧笑bilibili

        # 如果文件是 ts 或 flv 格式，则转换为 mp4
        if [[ "$filename" == *.ts || "$filename" == *.flv ]]; then
            # 定义转换后的 mp4 文件名
            mp4_file="${filename_no_ext}.mp4"
            # 使用 ffmpeg 转换为 mp4
            ffmpeg -i "$video_file" -c:v copy -c:a copy -v quiet -y "$backup_dir/$mp4_file"
            rm "$video_file"  # 删除原文件
        fi
    fi
done

# 备份到rclone脚本
if [[ "$streamer_name" == "括弧笑bilibili" ]]; then
    # rclone 网盘路径
    rclone_backup_path="$rclone_onedrive_config:/直播录制/括弧笑/"
else
    # rclone 网盘路径
    rclone_backup_path="$rclone_onedrive_config:/直播录制/${streamer_name}/"
fi
# 上传rclone命令
rclone move "$backup_dir" "${rclone_backup_path}${formatted_start_time_3}/bilibili/$recording_platform/"

# 检查备份目录是否为空
if [ -z "$(ls -A "$backup_dir")" ]; then
    rmdir "$backup_dir"
fi

# 推送消息
message="${sever_name}

${streamer_name}
${broadcast_start_time}场

直播结束录制"

# 推送消息命令
curl -s -X POST "https://msgpusher.xct258.top/push/root" \
    -d "title=直播录制&description=直播录制&channel=一般通知&content=$message" \
>/dev/null
