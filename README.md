# Rime 小篆输出层模板

这套配置是一个可叠加到现有 Rime 方案上的“小篆输出层”。原输入方案继续负责编码、分词、候选和词库；小篆输出层只接管候选过滤：

```text
任意 Rime 方案候选
-> OpenCC seal_liding：常用字/异体字 -> SealSources 代表字
-> Lua seal_filter：SealSources 代表字 -> Unicode 小篆
```

`seal_map.tsv` 会保留一个现代汉字对应的多个小篆变体。单字候选会展开为多个小篆候选；词语候选默认使用每个字的第一个小篆形，避免多字变体组合爆炸。

## 安装

### Windows 小狼毫

1. 安装生成工具。

   ```powershell
   winget install BYVoid.OpenCC
   ```

   Windows 也可以从 OpenCC release 下载命令行工具，使用前请确保 `opencc_dict` 在 `PATH` 中。

2. 获取并生成数据文件。

   ```powershell
   New-Item -ItemType Directory -Force rime\opencc

   curl.exe -L `
     -o rime\opencc\SealVariants.txt `
     https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/SealVariants.txt

   opencc_dict `
     -i rime\opencc\SealVariants.txt `
     -o rime\opencc\SealVariants.ocd2 `
     -f text `
     -t ocd2

   curl.exe -L `
     -o SealSources.txt `
     https://www.unicode.org/Public/UCD/latest/ucd/SealSources.txt

   python scripts\build_rime_seal_map.py `
     -i SealSources.txt `
     -o rime\seal_map.tsv
   ```

3. 复制通用文件到小狼毫用户目录。

   小狼毫用户目录通常是 `%APPDATA%\Rime`，也可以从开始菜单打开“小狼毫输入法 -> 用户文件夹”。

   ```powershell
   New-Item -ItemType Directory -Force "$env:APPDATA\Rime\lua"
   New-Item -ItemType Directory -Force "$env:APPDATA\Rime\opencc"

   Copy-Item rime\seal_map.tsv "$env:APPDATA\Rime\seal_map.tsv"
   Copy-Item rime\lua\seal_filter.lua "$env:APPDATA\Rime\lua\seal_filter.lua"
   Copy-Item rime\opencc\seal_liding.json "$env:APPDATA\Rime\opencc\seal_liding.json"
   Copy-Item rime\opencc\SealVariants.txt "$env:APPDATA\Rime\opencc\SealVariants.txt"
   Copy-Item rime\opencc\SealVariants.ocd2 "$env:APPDATA\Rime\opencc\SealVariants.ocd2"
   ```

4. 给目标输入方案生成 custom 补丁。

   例如给朙月拼音加小篆输出：

   ```powershell
   python scripts\make_seal_patch.py luna_pinyin -o "$env:APPDATA\Rime\luna_pinyin.custom.yaml"
   ```

   例如给仓颉五代加小篆输出：

   ```powershell
   python scripts\make_seal_patch.py cangjie5 -o "$env:APPDATA\Rime\cangjie5.custom.yaml"
   ```

5. 重新部署小狼毫。

   从开始菜单或托盘菜单选择“重新部署”。

### macOS 鼠须管

1. 安装生成工具。

   ```sh
   brew install opencc
   ```

2. 获取并生成数据文件。

   ```sh
   mkdir -p rime/opencc

   curl -L \
     -o rime/opencc/SealVariants.txt \
     https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/SealVariants.txt

   opencc_dict \
     -i rime/opencc/SealVariants.txt \
     -o rime/opencc/SealVariants.ocd2 \
     -f text \
     -t ocd2

   curl -L \
     -o SealSources.txt \
     https://www.unicode.org/Public/UCD/latest/ucd/SealSources.txt

   python3 scripts/build_rime_seal_map.py \
     -i SealSources.txt \
     -o rime/seal_map.tsv
   ```

3. 复制通用文件到鼠须管用户目录。

   鼠须管用户目录通常是 `~/Library/Rime`，也可以从输入法菜单打开“用户设定”。

   ```sh
   mkdir -p ~/Library/Rime/lua
   mkdir -p ~/Library/Rime/opencc

   cp rime/seal_map.tsv ~/Library/Rime/seal_map.tsv
   cp rime/lua/seal_filter.lua ~/Library/Rime/lua/seal_filter.lua
   cp rime/opencc/seal_liding.json ~/Library/Rime/opencc/seal_liding.json
   cp rime/opencc/SealVariants.txt ~/Library/Rime/opencc/SealVariants.txt
   cp rime/opencc/SealVariants.ocd2 ~/Library/Rime/opencc/SealVariants.ocd2
   ```

4. 给目标输入方案生成 custom 补丁。

   例如给朙月拼音加小篆输出：

   ```sh
   python3 scripts/make_seal_patch.py luna_pinyin -o ~/Library/Rime/luna_pinyin.custom.yaml
   ```

   例如给仓颉五代加小篆输出：

   ```sh
   python3 scripts/make_seal_patch.py cangjie5 -o ~/Library/Rime/cangjie5.custom.yaml
   ```

5. 重新部署鼠须管。

   从输入法菜单选择“重新部署”，或运行：

   ```sh
   /Library/Input\ Methods/Squirrel.app/Contents/MacOS/Squirrel --reload
   ```

`examples/` 里有已经命名好的示例：

- `examples/cangjie5_seal.custom.yaml`
- `examples/luna_pinyin_seal.custom.yaml`

## 字体

小篆字符位于 Unicode 小篆区，例如 `U+3D000`。候选栏和目标应用要能显示这些字符，需要安装覆盖 Unicode 小篆区的字体。

## 第三方数据

运行时需要以下第三方数据或由第三方数据生成的文件：

- `opencc/SealVariants.txt` 来自 OpenCC，许可证为 Apache-2.0。上游文件：<https://github.com/BYVoid/OpenCC/blob/master/data/dictionary/SealVariants.txt>
- `opencc/SealVariants.ocd2` 是由 `opencc/SealVariants.txt` 编译得到的 OpenCC 二进制字典。
- `seal_map.tsv` 是由 Unicode `SealSources.txt` 生成的小篆映射表。Unicode 数据文件受 Unicode License v3 约束。许可说明：<https://www.unicode.org/copyright.html>
```

## 重新生成数据文件

### Windows

```powershell
New-Item -ItemType Directory -Force rime\opencc

curl.exe -L `
  -o rime\opencc\SealVariants.txt `
  https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/SealVariants.txt

opencc_dict `
  -i rime\opencc\SealVariants.txt `
  -o rime\opencc\SealVariants.ocd2 `
  -f text `
  -t ocd2

curl.exe -L `
  -o SealSources.txt `
  https://www.unicode.org/Public/UCD/latest/ucd/SealSources.txt

python scripts\build_rime_seal_map.py `
  -i SealSources.txt `
  -o rime\seal_map.tsv
```

### macOS

```sh
mkdir -p rime/opencc

curl -L \
  -o rime/opencc/SealVariants.txt \
  https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/SealVariants.txt

opencc_dict \
  -i rime/opencc/SealVariants.txt \
  -o rime/opencc/SealVariants.ocd2 \
  -f text \
  -t ocd2

curl -L \
  -o SealSources.txt \
  https://www.unicode.org/Public/UCD/latest/ucd/SealSources.txt

python3 scripts/build_rime_seal_map.py \
  -i SealSources.txt \
  -o rime/seal_map.tsv
```

## 模板内容

`seal_output.custom.yaml.template` 的核心是：

```yaml
patch:
  switches/+:
    - name: seal_liding
      reset: 1
      states: [ 原字, 隸定 ]

  engine/filters/@before 0: simplifier@seal_liding
  engine/filters/@before 1: lua_filter@*seal_filter

  seal_liding/opencc_config: seal_liding.json
  seal_liding/option_name: seal_liding
  seal_liding/tips: all

  seal_filter/map_file: seal_map.tsv
  seal_filter/single_char_variants: true
  seal_filter/max_variants: 9
```

候选文本会被替换为小篆，候选注释会保留中间候选文本。映射表没有覆盖到的字符会保持原样。

可以在 custom patch 或独立 schema 里调整：

```yaml
switches:
  - name: seal_liding
    reset: 1
    states: [ 原字, 隸定 ]

seal_filter:
  single_char_variants: true
  max_variants: 9
```
