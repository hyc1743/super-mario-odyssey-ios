# 外置游戏资源布局

IPA 是薄壳，只包含 iOS 运行时、宿主、Metal/NVN 层和必要的 RuntimeShaders。游戏主体资源留在 App 的 Documents 目录中，覆盖安装时不需要重新复制。

## 推荐布局

```text
Documents/
└── SMO Resource/
    ├── ExeFS/
    │   ├── main
    │   ├── sdk
    │   ├── subsdk0
    │   ├── rtld
    │   └── main.npdm
    └── RomFS/
        ├── ObjectData/
        ├── StageData/
        ├── ShaderData/
        └── SoundData/
```

也支持首次复制时使用分卷格式：

```text
Documents/SMO Resource/RomFS/
├── RomFS.smoa.0
├── RomFS.smoa.1
└── ...
```

应用首次启动会检查分卷并展开到 `RomFS/`。分卷编号必须从 `0` 连续递增。

## 检查命令

```bash
python3 smo/tools/build_ipa.py \
  --resources "<SMO Resource 或其父目录>" \
  --output out/ipa
```

命令只读检查资源，生成 `out/ipa/build_report.json`，不会修改或复制游戏资源。

## IPA 内容约束

IPA 中不应出现以下内容：

- `.nsp`、`.nca`、`.tik`；
- `ExeFS/`、`RomFS/`；
- `.szs`、`.sharc`、`.sharcb`、`.bfsha` 等游戏原始资源。

必要的运行时着色器归档位于应用内 `RuntimeShaders/`，它只包含经过验证的运行时 shader 资源。
