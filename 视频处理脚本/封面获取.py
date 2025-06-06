import sys
import os
import subprocess
import xml.etree.ElementTree as ET

def parse_danmaku(xml_file):
    tree = ET.parse(xml_file)
    root = tree.getroot()
    times = []
    for d in root.findall('d'):
        p = d.get('p')
        if p:
            try:
                stime = float(p.split(',')[0])
                times.append(int(stime))  # 取整秒
            except:
                continue
    return times

def build_timeline(times):
    if not times:
        return []
    max_sec = max(times)
    timeline = [0] * (max_sec + 1)
    for t in times:
        timeline[t] += 1
    return timeline

def extract_frame_ffmpeg(mp4_path, timestamp, output_path):
    cmd = [
        'ffmpeg',
        '-ss', str(timestamp),
        '-i', mp4_path,
        '-frames:v', '1',
        '-q:v', '2',
        '-y',
        output_path
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def main():
    if len(sys.argv) < 2:
        print("用法: python extract_hot_frame.py 弹幕文件夹路径")
        return

    folder = sys.argv[1]
    if not os.path.isdir(folder):
        print("找不到文件夹:", folder)
        return

    hottest_info = None  # (弹幕数, 视频路径, 时间点)

    for file in os.listdir(folder):
        if file.endswith(".xml"):
            xml_path = os.path.join(folder, file)
            base_name = os.path.splitext(xml_path)[0]
            mp4_path = base_name + ".mp4"
            if not os.path.isfile(mp4_path):
                continue

            times = parse_danmaku(xml_path)
            timeline = build_timeline(times)

            if not timeline:
                print("跳过，弹幕为空:", file)
                continue

            peak_time = timeline.index(max(timeline))
            peak_value = timeline[peak_time]

            if hottest_info is None or peak_value > hottest_info[0]:
                hottest_info = (peak_value, mp4_path, peak_time, base_name)

    if hottest_info:
        peak_value, mp4_path, peak_time, base_name = hottest_info
        output_img = os.path.join(folder, f"{os.path.basename(base_name)}.jpg")
        extract_frame_ffmpeg(mp4_path, peak_time, output_img)
        print(output_img)

if __name__ == '__main__':
    main()
