#!/bin/bash

if ! command -v ffmpeg &> /dev/null; then
  echo "未检测到 ffmpeg，先安装 ffmpeg"
  apt install ffmpeg
fi
echo "ffmoeg已安装，继续执行"

# 提示用户选择操作类型
echo "请选择操作类型:"
echo "1. 删除输入的片段"
echo "2. 裁切输入的片段并合并"
read -p "请输入选项 (1 或 2): " operation

# 检查用户输入是否合法
if [[ "$operation" != "1" && "$operation" != "2" ]]; then
    echo "无效的选项，请选择 1 或 2。"
    exit 1
fi

# 提示用户输入视频文件的路径，并将其存储在变量 input_video 中
read -p "请输入视频文件的路径: " input_video

# 检查输入的视频文件是否存在，如果不存在则输出错误信息并退出脚本
if [[ ! -f "$input_video" ]]; then
    echo "视频文件不存在，请检查路径。"
    exit 1
fi

# 提示用户输入需要处理的片段，格式为 "开始时间-结束时间" 的多个片段，用分号分隔
read -p "请输入需要处理的片段（格式为 00:09:36-00:09:58；01:16:16-01:17:54 或者 09:36-09:50）: " segments

# 创建一个临时文件用于保存要合并的片段列表，并确保它保存在当前目录
concat_list="./concat_list.txt"  # 指定合并列表的路径
> "$concat_list"  # 清空文件内容

# 将用户输入的片段字符串分割成数组，使用分号作为分隔符
IFS='；' read -ra seg_array <<< "$segments"

# 定义一个函数来验证时间格式是否正确，支持 HH:MM:SS 和 MM:SS 格式
validate_time_format() {
    if [[ ! $1 =~ ^([0-9]{2}):([0-9]{2}):([0-9]{2})$ ]] && [[ ! $1 =~ ^([0-9]{2}):([0-9]{2})$ ]]; then
        echo "时间格式错误: $1"
        exit 1
    fi
}

# 将时间格式转换为 HH:MM:SS
convert_to_hhmmss() {
    if [[ $1 =~ ^([0-9]{2}):([0-9]{2})$ ]]; then
        echo "00:$1"  # 如果是 MM:SS 格式，前面加上 00:
    else
        echo "$1"  # 如果是 HH:MM:SS 格式，直接返回
    fi
}

# 初始化变量 prev_end 用于记录上一个片段的结束时间
prev_end="00:00:00"
index=0  # 初始化片段索引

# 遍历用户输入的每个片段
for seg in "${seg_array[@]}"; do
    # 提取片段的开始时间和结束时间
    start_time=${seg%-*}
    end_time=${seg#*-}

    # 验证开始时间和结束时间的格式是否正确
    validate_time_format "$start_time"
    validate_time_format "$end_time"

    # 将时间格式转换为 HH:MM:SS
    start_time=$(convert_to_hhmmss "$start_time")
    end_time=$(convert_to_hhmmss "$end_time")

    if [[ "$operation" == "1" ]]; then
        # 删除模式：处理保留的片段
        if [[ "$prev_end" != "$start_time" ]]; then
            part_file="./part_${index}.mp4"
            echo "生成的临时文件: $part_file"
            echo "file '$part_file'" >> "$concat_list"
            ffmpeg -ss "$prev_end" -to "$start_time" -i "$input_video" -c copy -y -avoid_negative_ts 1 "$part_file" || { echo "ffmpeg 处理失败"; exit 1; }
            ((index++))
        fi
        prev_end="$end_time"
    else
        # 裁切模式：直接处理所选片段
        part_file="./part_${index}.mp4"
        echo "生成的临时文件: $part_file"
        echo "file '$part_file'" >> "$concat_list"
        ffmpeg -ss "$start_time" -to "$end_time" -i "$input_video" -c copy -y -avoid_negative_ts 1 "$part_file" || { echo "ffmpeg 处理失败"; exit 1; }
        ((index++))
    fi
done

if [[ "$operation" == "1" ]]; then
    # 删除模式：处理最后一个片段，从最后一个片段的结束时间到视频结束
    part_file="./part_${index}.mp4"
    echo "生成的临时文件: $part_file"
    echo "file '$part_file'" >> "$concat_list"
    ffmpeg -ss "$prev_end" -i "$input_video" -c copy -y -avoid_negative_ts 1 "$part_file" || { echo "ffmpeg 处理失败"; exit 1; }
fi

# 设置输出文件名，在原文件名后加上 "-edited"
output_video="${input_video%.mp4}-edited.mp4"

# 使用 ffmpeg 合并所有保留的片段
ffmpeg -f concat -safe 0 -i "$concat_list" -c copy -y "$output_video" || { echo "视频合并失败"; exit 1; }

# 删除所有生成的临时片段文件和合并列表文件
rm -f ./part_*.mp4 "$concat_list"

# 检查输出文件是否成功生成，并给出相应提示
if [[ -f "$output_video" ]]; then
    echo "处理完成，输出文件为: $output_video"
else
    echo "输出文件生成失败"
fi
