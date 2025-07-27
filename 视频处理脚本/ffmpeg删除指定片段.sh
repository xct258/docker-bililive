#!/bin/bash

INPUT="$1"
DELETE_SEGMENTS="$2"
OUTPUT="$3"

if [[ -z "$INPUT" || -z "$DELETE_SEGMENTS" ]]; then
  echo "用法: $0 输入视频.mp4 \"开始时间-结束时间,开始时间-结束时间,...\" [输出文件.mp4]"
  exit 1
fi

if [[ -z "$OUTPUT" ]]; then
  EXT="${INPUT##*.}"
  BASENAME="${INPUT%.*}"
  OUTPUT="${BASENAME}_edited.${EXT}"
fi

time_to_seconds() {
  IFS=: read -r h m s <<< "$1"
  echo $((10#$h*3600 + 10#$m*60 + 10#$s))
}

get_duration() {
  ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1" | cut -d. -f1
}

parse_segments() {
  local segments_str="$1"
  # 去掉所有空格
  segments_str="${segments_str// /}"
  # 按逗号拆分
  IFS=',' read -ra segments <<< "$segments_str"
  local arr=()
  for seg in "${segments[@]}"; do
    # 用 - 分割开始和结束时间
    start="${seg%-*}"
    end="${seg#*-}"
    start_sec=$(time_to_seconds "$start")
    end_sec=$(time_to_seconds "$end")
    if (( end_sec <= start_sec )); then
      echo "错误：时间段无效 $seg"
      exit 1
    fi
    arr+=("$start_sec-$end_sec")
  done
  IFS=$'\n' sorted=($(sort -n <<<"${arr[*]}"))
  unset IFS
  echo "${sorted[@]}"
}

DURATION=$(get_duration "$INPUT")
if [[ -z "$DURATION" ]]; then
  echo "错误：获取视频时长失败"
  exit 1
fi

DELETE_SEGS=($(parse_segments "$DELETE_SEGMENTS"))

KEEP_SEGS=()
prev_end=0
for seg in "${DELETE_SEGS[@]}"; do
  start=${seg%-*}
  end=${seg#*-}
  if (( start > prev_end )); then
    KEEP_SEGS+=("$prev_end-$start")
  fi
  prev_end=$end
done
if (( prev_end < DURATION )); then
  KEEP_SEGS+=("$prev_end-$DURATION")
fi

echo "保留时间段（秒）: ${KEEP_SEGS[*]}"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

PARTS=()
INDEX=0

for seg in "${KEEP_SEGS[@]}"; do
  start=${seg%-*}
  end=${seg#*-}
  duration=$((end - start))
  PART_FILE="$TMPDIR/part_$INDEX.mp4"
  ffmpeg -y -i "$INPUT" -ss "$start" -t "$duration" -c copy "$PART_FILE" < /dev/null
  if [[ $? -ne 0 ]]; then
    echo "错误：提取片段 $seg 失败"
    exit 1
  fi
  PARTS+=("$PART_FILE")
  INDEX=$((INDEX+1))
done

CONCAT_FILE="$TMPDIR/concat.txt"
for part in "${PARTS[@]}"; do
  echo "file '$part'" >> "$CONCAT_FILE"
done

ffmpeg -y -f concat -safe 0 -i "$CONCAT_FILE" -c copy "$OUTPUT"

if [[ $? -eq 0 ]]; then
  echo "合并完成，输出文件: $OUTPUT"
else
  echo "错误：合并视频失败"
  exit 1
fi
