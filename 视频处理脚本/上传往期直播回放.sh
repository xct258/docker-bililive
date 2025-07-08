#!/bin/bash

set -e

# 设置路径
WORK_DIR="/root/apps/脚本/上传往期视频回放"
RCLONE_REMOTE="onedrive-video-7:直播录制/括弧笑/2022/12"  # rclone 中的远程名和路径（请根据实际替换）
DST_DIR="$WORK_DIR/video"
CACHE_DIR="$WORK_DIR/cache"
COVER_DIR="$WORK_DIR/covers"
USED_COVER_FILE="$CACHE_DIR/used_biliup_covers.txt"
PROCESSED_DIRS_FILE="$CACHE_DIR/processed_dirs.txt"

# 创建本地缓存目录
mkdir -p "$DST_DIR"
mkdir -p "$CACHE_DIR"
[[ -f "$USED_COVER_FILE" ]] || touch "$USED_COVER_FILE"

# 封面选择函数：选择未使用过的封面
select_unused_cover() {
    mapfile -t unused_covers < <(comm -23 <(find "$COVER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort) <(sort "$USED_COVER_FILE"))
    
    if [[ ${#unused_covers[@]} -eq 0 ]]; then
        echo "❌ 封面图片已全部使用，停止脚本。" >&2
        return 1
    fi

    local rand_index=$(od -An -N2 -i /dev/urandom | tr -d ' ' | awk -v max="${#unused_covers[@]}" '{print $1 % max}')
    local cover="${unused_covers[$rand_index]}"


    echo "$cover"  # 不记录，延迟到投稿成功后写入
    return 0
}

# 读取已处理的目录列表
[[ -f "$PROCESSED_DIRS_FILE" ]] || touch "$PROCESSED_DIRS_FILE"

# 获取所有子目录，并过滤掉已处理过的
mapfile -t subdirs < <(
  rclone lsd "$RCLONE_REMOTE" --max-depth 1 | awk '{print $NF}' |
  sort | grep -vFf "$PROCESSED_DIRS_FILE"
)

for dirname in "${subdirs[@]}"; do
    echo "▶️ 处理远程子目录：$dirname"

    # 检查封面是否可用
    if ! biliup_cover_image=$(select_unused_cover); then
        echo "❌ 封面用尽，停止处理后续子目录。"
        exit 1
    fi

    echo "🖼 使用封面：$biliup_cover_image"

    local_dst_dir="${DST_DIR}/${dirname}"

    # 将远程子目录复制到本地
    rclone copy "$RCLONE_REMOTE/$dirname" "$local_dst_dir" -P

    # 查找视频文件
    mapfile -t video_files < <(find "$local_dst_dir" -type f \( -iname "*.mp4" -o -iname "*.flv" \))

    if [[ ${#video_files[@]} -gt 0 ]]; then
        echo "📼 目录 $dirname 中找到 ${#video_files[@]} 个视频文件："
        upload_output=$(
        "$WORK_DIR/biliup-rs" -u cookies-烦心事远离.json upload \
            --copyright 2 \
            --cover "$biliup_cover_image" \
            --source https://live.bilibili.com/1962720 \
            --tid 17 \
            --title "$dirname" \
            --desc "硬盘空间回收，不定期投稿没有上传过的直播回放" \
            --tag "搞笑,直播回放,奶茶猪,高机动持盾军官,括弧笑,娱乐主播" \
            "${video_files[@]}" 2>&1
        )
        echo "$upload_output"
        if echo "$upload_output" | grep -q "投稿成功"; then
            echo "✅ 投稿成功，删除本地缓存：$local_dst_dir"
            rm -rf "$local_dst_dir"

            if ! grep -Fxq "$biliup_cover_image" "$USED_COVER_FILE"; then
                echo "$biliup_cover_image" >> "$USED_COVER_FILE"
            fi

            # 仅当未记录过时再写入
            if ! grep -Fxq "$dirname" "$PROCESSED_DIRS_FILE"; then
                echo "$dirname" >> "$PROCESSED_DIRS_FILE"
            fi

        else
            echo "⚠️ 未检测到投稿成功，保留本地文件以便排查"
        fi
    else
        echo "⛔️ 目录 $dirname 中未找到视频文件，跳过"
    fi
done
