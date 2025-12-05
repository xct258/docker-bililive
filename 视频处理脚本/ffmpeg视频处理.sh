#!/bin/bash

### === 环境检查 === ###
if ! command -v ffmpeg &> /dev/null; then
  echo "未检测到 ffmpeg，正在安装..."
  apt install -y ffmpeg
fi
echo "ffmpeg 已安装，继续执行"


### === 选择操作模式 === ###
echo "请选择操作类型:"
echo "1. 删除输入的片段（保留其它部分）"
echo "2. 裁切输入的片段并合并（仅保留选择部分）"
echo "3. 删除片段，但将删除掉的片段另存为一个视频"
read -p "请输入选项 (1/2/3): " operation

if [[ "$operation" != "1" && "$operation" != "2" && "$operation" != "3" ]]; then
    echo "❌ 无效选项，请输入 1、2 或 3"
    exit 1
fi


### === 输入文件 === ###
read -p "请输入视频文件路径: " input_video

if [[ ! -f "$input_video" ]]; then
    echo "❌ 视频文件不存在"
    exit 1
fi


### === 输入片段 === ###
read -p "请输入片段（格式: 00:09:36-00:09:58；1:16:16-1:17:54 或 9:36-9:50）: " segments

segments=$(echo "$segments" | sed 's/;/；/g')
IFS='；' read -ra seg_array <<< "$segments"


### === 工具函数 === ###
normalize_time() {
    local t="$1"

    # SS
    if [[ "$t" =~ ^([0-9]{1,2})$ ]]; then
        printf "00:00:%02d" "${BASH_REMATCH[1]}"; return
    fi

    # MM:SS
    if [[ "$t" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
        printf "00:%02d:%02d" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"; return
    fi

    # HH:MM:SS
    if [[ "$t" =~ ^([0-9]{1,2}):([0-9]{2}):([0-9]{2})$ ]]; then
        printf "%02d:%02d:%02d" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"; return
    fi

    echo "❌ 无效时间格式: $t"
    exit 1
}

to_seconds() {
    IFS=: read -r h m s <<< "$1"
    echo $((10#$h*3600 + 10#$m*60 + 10#$s))
}

sec_to_hms() {
    printf "%02d:%02d:%02d" "$(($1/3600))" "$((($1%3600)/60))" "$(($1%60))"
}


### === 获取视频总时长 === ###
video_duration_sec=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$input_video" | awk '{print int($1)}')

video_duration=$(sec_to_hms "$video_duration_sec")


### === 解析片段并排序 === ###
declare -a ranges

for seg in "${seg_array[@]}"; do
    start=${seg%-*}
    end=${seg#*-}

    start=$(normalize_time "$start")
    end=$(normalize_time "$end")

    start_sec=$(to_seconds "$start")
    end_sec=$(to_seconds "$end")

    if (( start_sec >= end_sec )); then
        echo "❌ 片段起始时间必须小于结束时间: $seg"
        exit 1
    fi

    ranges+=("$start_sec-$end_sec")
done

IFS=$'\n' sorted_ranges=($(sort -n <<< "${ranges[*]}"))
unset IFS


### === 准备临时文件 === ###
concat_keep="./concat_keep.txt"
concat_removed="./concat_removed.txt"

> "$concat_keep"
> "$concat_removed"

index_keep=0
index_removed=0
prev_end_sec=0


### === 主处理逻辑 === ###
for seg in "${sorted_ranges[@]}"; do
    start_sec=${seg%-*}
    end_sec=${seg#*-}

    ### 模式 1 & 3：保留未删除部分 ###
    if [[ "$operation" == "1" || "$operation" == "3" ]]; then
        if (( prev_end_sec < start_sec )); then
            part_file="./keep_${index_keep}.mp4"
            echo "file '$part_file'" >> "$concat_keep"

            ffmpeg -ss "$(sec_to_hms "$prev_end_sec")" \
                   -to "$(sec_to_hms "$start_sec")" \
                   -i "$input_video" \
                   -c copy -y "$part_file"

            ((index_keep++))
        fi
    fi

    ### 模式 2：裁切片段 ###
    if [[ "$operation" == "2" ]]; then
        part_file="./keep_${index_keep}.mp4"
        echo "file '$part_file'" >> "$concat_keep"

        ffmpeg -ss "$(sec_to_hms "$start_sec")" \
               -to "$(sec_to_hms "$end_sec")" \
               -i "$input_video" \
               -c copy -y "$part_file"

        ((index_keep++))
    fi

    ### 模式 3：将删除的片段单独保存 ###
    if [[ "$operation" == "3" ]]; then
        part_file="./removed_${index_removed}.mp4"
        echo "file '$part_file'" >> "$concat_removed"

        ffmpeg -ss "$(sec_to_hms "$start_sec")" \
               -to "$(sec_to_hms "$end_sec")" \
               -i "$input_video" \
               -c copy -y "$part_file"

        ((index_removed++))
    fi

    prev_end_sec=$end_sec
done


### === 最后一段（用于模式 1 & 3） === ###
if [[ "$operation" == "1" || "$operation" == "3" ]]; then
    if (( prev_end_sec < video_duration_sec )); then
        part_file="./keep_${index_keep}.mp4"
        echo "file '$part_file'" >> "$concat_keep"

        ffmpeg -ss "$(sec_to_hms "$prev_end_sec")" \
               -to "$video_duration" \
               -i "$input_video" \
               -c copy -y "$part_file"
    fi
fi


### === 生成最终文件 === ###
base="${input_video%.*}"

output_keep="${base}-edited.mp4"
output_removed="${base}-deleted.mp4"

# 合并保留部分
ffmpeg -f concat -safe 0 -i "$concat_keep" -c copy -y "$output_keep"

# 合并删除部分（用于模式 3）
if [[ "$operation" == "3" ]]; then
    ffmpeg -f concat -safe 0 -i "$concat_removed" -c copy -y "$output_removed"
fi


### === 清理 === ###
rm -f keep_*.mp4 removed_*.mp4 "$concat_keep" "$concat_removed"


### === 完成提示 === ###
echo "🎉 已完成!"
echo "保留部分视频: $output_keep"
if [[ "$operation" == "3" ]]; then
    echo "被删除片段合集: $output_removed"
fi
