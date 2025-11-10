#!/bin/bash

max_remote=""
max_free_bytes=0

for remote in $(rclone listremotes | sed 's/:$//' | grep -i 'onedrive-video-' | sort); do
    free=$(rclone about "$remote": --json 2>/dev/null | jq -r '.free // 0')

    # 过滤剩余容量 <=50GB
    if (( free <= 50*1024*1024*1024 )); then
        continue
    fi

    # 记录剩余容量最大的网盘
    if (( free > max_free_bytes )); then
        max_free_bytes=$free
        max_remote=$remote
    fi
done

# 输出 JSON
if [[ -n "$max_remote" ]]; then
    max_free_gb=$(awk "BEGIN {printf \"%.2f\", $max_free_bytes/1024/1024/1024}")
    jq -n --arg remote "$max_remote" --arg free_gb "$max_free_gb" \
        '{remote: $remote, free_gb: ($free_gb | tonumber)}'
else
    jq -n '{remote: null, free_gb: 0}'
fi
