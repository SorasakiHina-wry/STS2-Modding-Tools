"""从裁切小图生成遗物剪影（纯白 alpha）。

原版用独立的 `relic_outline_atlas`，每件遗物是**纯白剪影**（NRelic 用半透明黑染色
来画图标背后的投影）。这里从 `cropped/` 的 alpha 派生：膨胀 2 像素后填白。

用法：
    python tools/prepare_relic_outlines.py -c saria
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _charpaths import add_character_arg, paths  # noqa: E402

DILATE_PX = 2


def main() -> int:
    parser = add_character_arg()
    args = parser.parse_args()
    p = paths(args.character)

    src = p.png / "relics" / "derived" / "cropped"
    out = p.png / "relics" / "derived" / "outline"
    if not src.exists():
        print(f"没有裁切小图目录：{src}")
        return 1

    out.mkdir(parents=True, exist_ok=True)
    count = 0
    for source in sorted(src.glob("*.png")):
        image = Image.open(source).convert("RGBA")
        alpha = image.getchannel("A")

        size = DILATE_PX * 2 + 1
        dilated = alpha.filter(ImageFilter.MaxFilter(size))

        outline = Image.new("RGBA", image.size, (255, 255, 255, 0))
        outline.putalpha(dilated)
        outline.paste((255, 255, 255), mask=dilated)

        outline.save(out / source.name, optimize=True)
        count += 1
        print(f"{source.name} -> outline/{source.name}")

    print(f"done: {count} outline(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
