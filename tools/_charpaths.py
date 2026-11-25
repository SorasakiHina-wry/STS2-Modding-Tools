"""多角色工作区的路径与参数约定（所有 Python 工具共用）。

工作区结构：

    D:\\STS2\\                         工作区根
    ├─ tools\\                         本目录：各角色共享的工具
    ├─ saria\\                         角色 A（一个角色 = 一个 git 仓库）
    │  ├─ mods-src\\saria\\             该角色的工程（src / design / assets / lib / csproj）
    │  ├─ resources\\                   该角色的美术与 Spine 素材
    │  └─ docs\\                        该角色的专属文档
    ├─ talulah\\                       角色 B（同构）
    └─ dist\\                           所有角色的构建产物（dist\\<角色名>\\、dist\\workshop\\<角色名>\\）

用法：

    from _charpaths import add_character_arg, paths
    parser = add_character_arg()
    args = parser.parse_args()
    p = paths(args.character)
    p.project / "src" ...

命令行默认值来自环境变量 ``STS2_CHARACTER``，没有则用 ``saria``。
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from types import SimpleNamespace

WORKSPACE = Path(__file__).resolve().parent.parent
DEFAULT_CHARACTER = os.environ.get("STS2_CHARACTER", "saria")


def add_character_arg(parser: argparse.ArgumentParser | None = None) -> argparse.ArgumentParser:
    """给 argparse 加上 -c/--character（角色目录名，例如 saria / talulah）。"""
    parser = parser or argparse.ArgumentParser()
    parser.add_argument(
        "-c",
        "--character",
        default=DEFAULT_CHARACTER,
        help="角色目录名，例如 saria / talulah（默认取环境变量 STS2_CHARACTER，否则 saria）",
    )
    return parser


def paths(character: str) -> SimpleNamespace:
    """返回该角色相关的全部常用目录（均已是绝对路径）。"""
    mod_root = WORKSPACE / character
    project = mod_root / "mods-src" / character
    resources = mod_root / "resources"
    return SimpleNamespace(
        character=character,
        workspace=WORKSPACE,
        mod_root=mod_root,
        project=project,
        resources=resources,
        png=resources / "png",
        design=project / "design",
        src=project / "src",
        assets=project / "assets",
        dist=WORKSPACE / "dist",
        dist_stage=WORKSPACE / "dist" / character,
        dist_workshop=WORKSPACE / "dist" / "workshop" / character,
    )


def character_from_argv(argv: list[str] | None = None) -> str:
    """从命令行（-c/--character）或环境变量取角色名，默认 saria。"""
    args = list(sys.argv[1:] if argv is None else argv)
    for index, token in enumerate(args):
        if token in ("-c", "--character") and index + 1 < len(args):
            return args[index + 1]
        if token.startswith("--character="):
            return token.split("=", 1)[1]
    return DEFAULT_CHARACTER


def project_from_argv() -> Path:
    """便捷入口：返回当前角色的工程目录（供顶层常量使用）。"""
    return paths(character_from_argv()).project


def require(path: Path, what: str = "") -> Path:
    """目录/文件不存在时给出清晰错误。"""
    if not path.exists():
        raise SystemExit(f"路径不存在：{path}" + (f"（{what}）" if what else ""))
    return path
