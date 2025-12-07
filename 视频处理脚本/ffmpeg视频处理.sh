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
read -p "请输入片段（格式: 00:00:30-00:01:30；00:02:00-00:02:30 或 5:00-6:00）: " segments
segments=$(echo "$segments" | sed 's/;/；/g')
IFS='；' read -ra seg_array <<< "$segments"

### === 工具函数 === ###
normalize_time() {
    local t="$1"
    if [[ "$t" =~ ^([0-9]{1,2})$ ]]; then
        printf "00:00:%02d" "${BASH_REMATCH[1]}"; return
    fi
    if [[ "$t" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
        printf "00:%02d:%02d" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"; return
    fi
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

### === 解析片段并排序 === ###
declare -a ranges
for seg in "${seg_array[@]}"; do
    start=${seg%-*}
    end=${seg#*-}
    start=$(normalize_time "$start")
    end=$(normalize_time "$end")
    start_sec=$(to_seconds "$start")
    end_sec=$(to_seconds "$end")

    # 自动扩展 3 秒
    start_sec=$((start_sec - 5))
    end_sec=$((end_sec + 5))

    # 边界检查
    if (( start_sec < 0 )); then
        start_sec=0
    fi
    if (( end_sec > video_duration_sec )); then
        end_sec=$video_duration_sec
    fi

    if (( start_sec >= end_sec )); then
        echo "❌ 片段起始时间必须小于结束时间: $seg"
        exit 1
    fi

    ranges+=("$start_sec-$end_sec")

done

IFS=$'\n' sorted_ranges=($(sort -n <<< "${ranges[*]}"))
unset IFS

### === 生成保留/删除片段时间列表 === ###
prev_end=0
keep_times=()
remove_times=()

for seg in "${sorted_ranges[@]}"; do
    start_sec=${seg%-*}
    end_sec=${seg#*-}

    if [[ "$operation" == "1" || "$operation" == "3" ]]; then
        if (( prev_end < start_sec )); then
            keep_times+=("$prev_end-$start_sec")
        fi
    fi

    if [[ "$operation" == "2" ]]; then
        keep_times+=("$start_sec-$end_sec")
    fi

    if [[ "$operation" == "3" ]]; then
        remove_times+=("$start_sec-$end_sec")
    fi

    prev_end=$end_sec
done

# 最后一段（模式 1 & 3）
if [[ "$operation" == "1" || "$operation" == "3" ]]; then
    if (( prev_end < video_duration_sec )); then
        keep_times+=("$prev_end-$video_duration_sec")
    fi
fi

### === 零重编码切割函数 === ###
split_and_concat() {
    local times=("$@")
    local prefix=$1
    local output_file=$2
    shift 2

    concat_file="${prefix}_concat.txt"
    > "$concat_file"
    idx=0

    for t in "$@"; do
        s=${t%-*}
        e=${t#*-}
        part_file="./${prefix}_${idx}.ts"
        ffmpeg -ss "$s" -to "$e" -i "$input_video" -c copy -avoid_negative_ts make_zero -y "$part_file"
        echo "file '$part_file'" >> "$concat_file"
        ((idx++))
    done

    ffmpeg -f concat -safe 0 -i "$concat_file" -c copy -y "$output_file"
    rm -f ./${prefix}_*.ts "$concat_file"
}

### === 执行零重编码处理 === ###
base="${input_video%.*}"
output_keep="${base}-edited.mp4"
output_removed="${base}-deleted.mp4"

if [[ ${#keep_times[@]} -gt 0 ]]; then
    split_and_concat keep "$output_keep" "${keep_times[@]}"
fi

if [[ "$operation" == "3" && ${#remove_times[@]} -gt 0 ]]; then
    split_and_concat removed "$output_removed" "${remove_times[@]}"
fi

echo "🎉 已完成!"
echo "保留部分视频: $output_keep"
if [[ "$operation" == "3" ]]; then
    echo "被删除片段合集: $output_removed"
fi
