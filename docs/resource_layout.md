# nxnative 外置资源布局

在「文件 → 我的 iPhone → SMO Mobile」复制以下内容：

```text
Documents/
├── romfs/
│   ├── ObjectData/
│   ├── StageData/
│   ├── ShaderData/
│   └── SoundData/SeResourceStd2nd.aras
├── msl/
│   └── b-<shader_chain>/
│       ├── <key>_b.metallib
│       └── <key>_b.json
├── resource_manifest.json
├── save/                       # 自动创建，更新资源不覆盖
├── temp/                       # 自动创建
├── env.txt                     # 可选
├── log.txt
└── log.prev.txt
```

`romfs` 是本体和 1.4.1 升级档经 LibHac 合并后的目录，不是升级档单独解出的目录。
用户不需要向手机复制 ExeFS，游戏程序已进入本人私有构建的个人 IPA 并随应用签名。
编译后着色器及反射文件随资源包提供，不包含在个人 IPA 中。
旧版 `SMO Resource/ExeFS`、`RomFS.smoa.N` 不作为新 nxnative 路径的输入；请用新工具重新生成资源包。

清单记录格式版本、Title ID、显示版本、nxnative 提交、各模块 Build ID、着色器链，
以及每个资源的相对路径、字节数和 SHA-256。个人 IPA 内的身份信息绑定资源清单哈希。
启动前核对身份和全部文件；校验缓存存放在应用 Caches，修改文件后重新核对。
复制错误、版本混用和损坏文件显示可修复的路径说明。

资源分发采用不超过 1 GiB 的 ZIP 连续分片，文件名为
`SMO-Resources-1.4.1.zip.part000` 起连续编号。使用同 release 的 `resources-parts.json`
与还原脚本恢复目录后再复制到手机，不能直接将分片作为 RomFS 使用。
