"""prepare_icons.py —— 从「角色图」派生头像 / 选人图 / 地图标记。

源文件（`<角色>/resources/png/sundry/`）与目标尺寸：

| 源文件 | 目标尺寸 | 用途 |
|---|---|---|
| `character_icon_<角色>.png` | 170×170 | 顶栏 / 先古 / 多人头像 |
| `char_select_<角色>.png` | 264×390 | 选人栏头像 |
| `char_select_bg_<角色>.png` | 1600×750 | 选人背景 |
| `map_marker_<角色>.png` | 98×128 | 地图标记 |

输出统一写到 `<角色>/resources/png/derived/`（打包脚本读这里）。
源图已经是目标尺寸时只做居中裁切（无损失）。

用法：
    python tools/prepare_icons.py -c saria
    python tools/prepare_icons.py --character talulah
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _charpaths import add_character_arg, paths  # noqa: E402

TARGETS = [
    ("character_icon_{char}.png", "character_icon_{char}.png", (170, 170)),
    ("char_select_{char}.png", "char_select_{char}.png", (264, 390)),
    ("char_select_bg_{char}.png", "char_select_bg_{char}.png", (1600, 750)),
    ("map_marker_{char}.png", "map_marker_{char}.png", (98, 128)),
]


def center_crop(image: Image.Image, target_ratio: float) -> Image.Image:
    width, height = image.size
    current_ratio = width / height
    if abs(current_ratio - target_ratio) < 1e-3:
        return image
    if current_ratio > target_ratio:
        new_width = round(height * target_ratio)
        left = (width - new_width) // 2
        return image.crop((left, 0, left + new_width, height))
    new_height = round(width / target_ratio)
    top = (height - new_height) // 2
    return image.crop((0, top, width, top + new_height))


def main() -> int:
    parser = add_character_arg()
    args = parser.parse_args()

    p = paths(args.character)
    src = p.png / "sundry"
    out = p.png / "derived"
    if not src.is_dir():
        print(f"缺少源目录：{src}（角色 {args.character} 的 resources/png/sundry）")
        return 1
    out.mkdir(parents=True, exist_ok=True)

    for source_template, output_template, size in TARGETS:
        source = src / source_template.format(char=args.character)
        output = out / output_template.format(char=args.character)
        if not source.exists():
            print(f"缺少源图：{source}")
            return 1

        image = Image.open(source).convert("RGBA")
        before = image.size
        image = center_crop(image, size[0] / size[1])
        if image.size != size:
            image = image.resize(size, Image.LANCZOS)
        image.save(output, optimize=True)
        print(f"{source.name} {before[0]}x{before[1]} -> derived/{output.name} {size[0]}x{size[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
