import xml.etree.ElementTree as ET
import sys
import os
import shutil

gift_level_map = {
    "总督": "1",
    "提督": "2",
    "舰长": "3"
}

price_time_map = [
    (1000, 600),
    (500, 300),
    (200, 150),
    (100, 120),
    (50, 90),
    (30, 60)
]

def get_sc_time(price_yuan: int) -> int:
    for threshold, duration in price_time_map:
        if price_yuan >= threshold:
            return duration
    return 60

def safe_text(text: str) -> str:
    """将回车符替换为 XML 实体"""
    return text.replace('\r', '&#13;') if text else ''

def main(xml_path):
    if not os.path.isfile(xml_path):
        print(f"[错误] 找不到文件: {xml_path}")
        return

    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
    except Exception as e:
        print(f"[错误] 解析 XML 失败: {e}")
        return

    modified_lines = []
    indent_unit = "  "

    for elem in root:
        if elem.tag != 's':
            line = ET.tostring(elem, encoding='unicode').strip()
            line = line.replace('\r', '&#13;')
            modified_lines.append(f"{indent_unit}{line}")
            continue

        type_attr = elem.get('type')
        giftname = elem.get('giftname')
        price = elem.get('price')
        price_int = int(price) if price else 0
        new_elem = None

        if type_attr == 'guard_buy' and giftname in gift_level_map:
            new_elem = ET.Element('guard', {
                'ts': elem.get('timestamp'),
                'user': elem.get('username'),
                'uid': elem.get('uid'),
                'level': gift_level_map[giftname],
                'count': elem.get('num'),
            })
        elif type_attr == 'super_chat' and giftname == '醒目留言':
            price_in_cents = price_int
            price_yuan = price_in_cents // 1000
            time_seconds = get_sc_time(price_yuan)
            new_elem = ET.Element('sc', {
                'ts': elem.get('timestamp'),
                'user': elem.get('username'),
                'uid': elem.get('uid'),
                'price': str(price_yuan),
                'time': str(time_seconds)
            })
            new_elem.text = safe_text(elem.text)
        elif type_attr == 'gift' and giftname != '辣条':
            new_elem = ET.Element('gift', {
                'ts': elem.get('timestamp'),
                'user': elem.get('username'),
                'uid': elem.get('uid'),
                'giftname': giftname if giftname else '',
                'giftcount': elem.get('num') if elem.get('num') else '1',
            })

        if new_elem is not None:
            new_elem_str = ET.tostring(new_elem, encoding='unicode').strip()
            new_elem_str = new_elem_str.replace('\r', '&#13;')
            modified_lines.append(f"{indent_unit}{new_elem_str}")
        else:
            # 保留非 gift/guard/sc 的 <s> 弹幕
            original_str = ET.tostring(elem, encoding='unicode').strip()
            original_str = original_str.replace('\r', '&#13;')
            modified_lines.append(f"{indent_unit}{original_str}")

    # 备份原文件，格式 input_bak.xml
    base, ext = os.path.splitext(xml_path)
    backup_path = f"{base}_original{ext}"
    shutil.copy2(xml_path, backup_path)

    # 写回覆盖原文件
    with open(xml_path, "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        f.write('<i>\n')
        for line in modified_lines:
            f.write(f"{line}\n")
        f.write('</i>\n')

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("用法: python convert_xml.py input.xml")
    else:
        main(sys.argv[1])
