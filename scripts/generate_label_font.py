import os
from PIL import Image, ImageDraw, ImageFont

def draw_steps_icon(size=20):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 绘制两个交替的小脚印
    # 左脚印 (稍低)
    d.ellipse([3, 8, 7, 14], fill=(255, 255, 255, 255))
    d.ellipse([3, 5, 5, 7], fill=(255, 255, 255, 255))
    d.ellipse([6, 5, 7, 7], fill=(255, 255, 255, 255))
    # 右脚印 (稍高)
    d.ellipse([11, 4, 15, 10], fill=(255, 255, 255, 255))
    d.ellipse([11, 1, 13, 3], fill=(255, 255, 255, 255))
    d.ellipse([14, 1, 15, 3], fill=(255, 255, 255, 255))
    return img

def draw_heart_icon(size=20):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 经典爱心
    # 两个圆和一个向下的多边形
    d.ellipse([2, 3, 10, 11], fill=(255, 255, 255, 255))
    d.ellipse([10, 3, 18, 11], fill=(255, 255, 255, 255))
    d.polygon([(2, 7), (18, 7), (10, 17)], fill=(255, 255, 255, 255))
    return img

def draw_lightning_icon(size=20):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 闪电折线多边形
    pts = [(11, 1), (5, 10), (10, 10), (8, 19), (16, 8), (11, 8)]
    d.polygon(pts, fill=(255, 255, 255, 255))
    return img

def draw_battery_icon(size=20):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 电池外框 (2 到 15, 5 到 15)
    d.rectangle([2, 5, 15, 14], outline=(255, 255, 255, 255), width=2)
    # 电池正极触点
    d.rectangle([16, 7, 18, 12], fill=(255, 255, 255, 255))
    # 电池内部电量
    d.rectangle([5, 8, 12, 11], fill=(255, 255, 255, 255))
    return img

def draw_flame_icon(size=20):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 卡路里火苗
    pts = [
        (10, 1), (13, 6), (16, 9), (16, 14),
        (13, 18), (7, 18), (4, 14), (4, 10),
        (7, 8), (8, 11), (10, 7)
    ]
    d.polygon(pts, fill=(255, 255, 255, 255))
    # 火焰内部小芯 (镂空/透明)
    inner_pts = [(10, 11), (12, 14), (10, 17), (8, 14)]
    d.polygon(inner_pts, fill=(0, 0, 0, 0))
    return img

def draw_pin_icon(size=20):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 定位图标 (头部圆 + 底部三角 + 中心小孔)
    d.ellipse([4, 2, 16, 14], fill=(255, 255, 255, 255))
    d.polygon([(4, 8), (16, 8), (10, 19)], fill=(255, 255, 255, 255))
    d.ellipse([8, 6, 12, 10], fill=(0, 0, 0, 0))
    return img

def draw_sensor_icon(kind, size=20):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    white = (255, 255, 255, 255)
    if kind == 'stress':
        d.line([(1, 11), (5, 11), (8, 3), (12, 17), (15, 9), (19, 9)], fill=white, width=2)
    elif kind == 'oxygen':
        d.polygon([(10, 1), (3, 11), (3, 15), (7, 19), (13, 19), (17, 15), (17, 11)], outline=white, width=2)
    elif kind == 'elevation':
        d.line([(1, 18), (8, 3), (12, 11), (15, 7), (19, 18), (1, 18)], fill=white, width=2)
    elif kind == 'pressure':
        d.arc((1, 2, 18, 19), 140, 400, fill=white, width=2)
        d.line([(10, 12), (15, 6)], fill=white, width=2)
        d.ellipse((8, 10, 12, 14), fill=white)
    else:
        d.rounded_rectangle((7, 1, 12, 14), radius=2, outline=white, width=2)
        d.ellipse((5, 11, 14, 19), fill=white)
    return img


def build_bmfont(output_dir, font_id, font_face, font_size, line_height, base_line, chars_to_add, icons=None):
    os.makedirs(output_dir, exist_ok=True)
    fnt_path = os.path.join(output_dir, f"{font_id}.fnt")
    png_path = os.path.join(output_dir, f"{font_id}_0.png")

    font_files = ['C:/Windows/Fonts/msyhbd.ttc', 'C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simhei.ttf']
    font = None
    for f in font_files:
        if os.path.exists(f):
            try:
                font = ImageFont.truetype(f, font_size)
                break
            except Exception:
                pass

    char_images = {}
    for ch in chars_to_add:
        bbox = font.getbbox(ch)
        w = max(1, bbox[2] - bbox[0])
        h = max(1, bbox[3] - bbox[1])
        glyph_img = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
        d = ImageDraw.Draw(glyph_img)
        d.text((1 - bbox[0], 1 - bbox[1]), ch, font=font, fill=(255, 255, 255, 255))
        bbox_actual = glyph_img.getbbox()
        if bbox_actual:
            glyph_cropped = glyph_img.crop(bbox_actual)
            xoffset = bbox_actual[0] + bbox[0] - 1
            yoffset = bbox_actual[1] + bbox[1] - 1
        else:
            glyph_cropped = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
            xoffset = 0
            yoffset = 0
        adv = int(round(font.getlength(ch)))
        if adv <= 0:
            adv = font_size
        char_images[ord(ch)] = {
            'img': glyph_cropped,
            'xoffset': xoffset,
            'yoffset': yoffset,
            'xadvance': adv,
        }

    if icons:
        for ch_key, icon_img in icons.items():
            bbox_actual = icon_img.getbbox()
            if bbox_actual:
                glyph_cropped = icon_img.crop(bbox_actual)
                xoffset = bbox_actual[0]
                yoffset = bbox_actual[1]
            else:
                glyph_cropped = icon_img
                xoffset = 0
                yoffset = 0
            char_images[ord(ch_key)] = {
                'img': glyph_cropped,
                'xoffset': xoffset,
                'yoffset': yoffset,
                'xadvance': icon_img.width,
            }

    atlas_w = 256
    atlas_h = 128
    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))

    cur_x = 2
    cur_y = 2
    row_h = 0
    char_entries = []

    for code, info in sorted(char_images.items()):
        img = info['img']
        gw, gh = img.size
        if cur_x + gw + 2 >= atlas_w:
            cur_x = 2
            cur_y += row_h + 2
            row_h = 0
        if cur_y + gh >= atlas_h:
            atlas_h *= 2
            new_atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
            new_atlas.paste(atlas, (0, 0))
            atlas = new_atlas

        atlas.paste(img, (cur_x, cur_y))
        char_entries.append({
            'id': code,
            'x': cur_x,
            'y': cur_y,
            'width': gw,
            'height': gh,
            'xoffset': info['xoffset'],
            'yoffset': info['yoffset'],
            'xadvance': info['xadvance']
        })

        cur_x += gw + 2
        if gh > row_h:
            row_h = gh

    atlas.save(png_path)

    with open(fnt_path, "w", encoding="utf-8") as f:
        f.write(f'info face="{font_face}" size={font_size} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1\n')
        f.write(f'common lineHeight={line_height} base={base_line} scaleW={atlas_w} scaleH={atlas_h} pages=1 packed=0\n')
        f.write(f'page id=0 file="{font_id}_0.png"\n')
        f.write(f'chars count={len(char_entries)}\n')
        for c in char_entries:
            f.write(f"char id={c['id']:<5} x={c['x']:<4} y={c['y']:<4} width={c['width']:<3} height={c['height']:<3} "
                    f"xoffset={c['xoffset']:<3} yoffset={c['yoffset']:<3} xadvance={c['xadvance']:<3} page=0 chnl=15\n")

    print(f"BMFont generated successfully: {fnt_path}, {png_path}, chars: {len(char_entries)}")


def generate_font(output_dir):
    # 1. 字段名称字体 custom_label: 16px + 16px 图标
    icon_size = 16
    raw_icons = {
        'A': draw_steps_icon(20),
        'B': draw_heart_icon(20),
        'C': draw_lightning_icon(20),
        'D': draw_battery_icon(20),
        'E': draw_flame_icon(20),
        'F': draw_pin_icon(20),
        'G': draw_sensor_icon('stress'),
        'H': draw_sensor_icon('oxygen'),
        'I': draw_sensor_icon('elevation'),
        'J': draw_sensor_icon('pressure'),
        'K': draw_sensor_icon('temperature'),
    }
    icons = {
        k: img.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
        for k, img in raw_icons.items()
    }
    build_bmfont(
        output_dir=output_dir,
        font_id="custom_label",
        font_face="CustomLabel",
        font_size=16,
        line_height=18,
        base_line=15,
        chars_to_add="压力血氧海拔气温度心率身电量卡路里距离步数 0123456789",
        icons=icons
    )

    # 2. 中文日期字体 custom_date: 22px，与数值字体一样大
    build_bmfont(
        output_dir=output_dir,
        font_id="custom_date",
        font_face="CustomDate",
        font_size=22,
        line_height=24,
        base_line=21,
        chars_to_add="周一二三四五六日星期 0123456789",
        icons=None
    )


if __name__ == "__main__":
    generate_font("resources/fonts")
