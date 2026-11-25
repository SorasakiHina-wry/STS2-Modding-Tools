"""把「获得能量」特效贴图规范化后写入 `<角色>/resources/png/derived/vfx/`。

接受几种拼写变体（游戏里叫 `fire_burst_*`，手写文件可能写成 `fire_bust_*`），
统一输出成原版规范名，运行时只需认一种拼写。

用法：
    python tools/prepare_vfx.py -c saria
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _charpaths import add_character_arg, paths  # noqa: E402

# 规范名 -> 候选源文件名（按顺序取第一个存在的）
TARGETS = {
    "fire_burst_flipbook_1.png": ["fire_burst_flipbook_1.png", "fire_bust_flipbook_1.png"],
    "fire_burst_flipbook_2.png": ["fire_burst_flipbook_2.png", "fire_bust_flipbook_2.png"],
    "fire_burst_flipbook_3.png": ["fire_burst_flipbook_3.png", "fire_bust_flipbook_3.png"],
    "fire_burst_ember_straight.png": ["fire_burst_ember_straight.png", "fire_bust_ember_straight.png"],
    "common_glow.png": ["common_glow.png"],
    "common_ring_polar_a.png": ["common_ring_polar_a.png"],
}


def main() -> int:
    parser = add_character_arg()
    args = parser.parse_args()
    p = paths(args.character)

    src = p.png / "vfx"
    out = p.png / "derived" / "vfx"
    if not src.exists():
        print(f"没有特效源目录：{src}")
        return 0

    out.mkdir(parents=True, exist_ok=True)
    found = 0
    for canonical, candidates in TARGETS.items():
        for name in candidates:
            candidate = src / name
            if candidate.exists():
                shutil.copyfile(candidate, out / canonical)
                print(f"{name} -> derived/vfx/{canonical}")
                found += 1
                break
        else:
            print(f"(missing) {canonical}")

    print(f"done: {found} file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
