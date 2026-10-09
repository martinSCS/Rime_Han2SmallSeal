# Rime 小篆派生方案模板

这套配置用于从现有 Rime 方案派生一个小篆输入方案。原方案继续保留普通输出；派生方案复用原方案的编码、分词、候选和词库，只在候选过滤阶段把普通汉字转换为 Unicode 小篆字符：

```text
任意 Rime 方案候选
-> Lua seal_filter：按 OpenCC SealVariants.txt 转成 SealSources 代表字
-> Lua seal_filter：SealSources 代表字 -> Unicode 小篆
```

`seal_map.tsv` 会保留一个现代汉字对应的多个小篆变体。单字候选会展开为多个小篆候选；词语候选默认使用每个字的第一个小篆形，避免多字变体组合爆炸。

`custom_liding.tsv` 用来补充常用字到 SealSources 代表字的映射。当 Unicode `SealSources.txt` 选用的隶定字不是日常输入时常用的字形时，可以在这里手动指定。例如：

```text
友	㕛
```

这样输入法候选原本给出 `友` 时，除了 `友` 在 SealSources 中直接对应的小篆，也会额外尝试 `㕛` 对应的小篆；候选注释会显示为 `友（㕛）`。

默认生成独立的 `<schema_id>_seal.schema.yaml`。原输入方案保持不变，需要普通输入时切回原方案，需要小篆输出时切到小篆方案。

## 安装

### Windows 小狼毫

1. 获取并生成数据文件。

   ```powershell
   New-Item -ItemType Directory -Force rime\opencc

   curl.exe -L `
     -o rime\opencc\SealVariants.txt `
     https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/SealVariants.txt

   curl.exe -L `
     -o SealSources.txt `
     https://www.unicode.org/Public/UCD/latest/ucd/SealSources.txt

   python scripts\build_rime_seal_map.py `
     -i SealSources.txt `
     -o rime\seal_map.tsv
   ```

2. 复制通用文件到小狼毫用户目录。

   小狼毫用户目录通常是 `%APPDATA%\Rime`，也可以从开始菜单打开“小狼毫输入法 -> 用户文件夹”。

   ```powershell
   New-Item -ItemType Directory -Force "$env:APPDATA\Rime\lua"
   New-Item -ItemType Directory -Force "$env:APPDATA\Rime\opencc"

   Copy-Item rime\seal_map.tsv "$env:APPDATA\Rime\seal_map.tsv"
   Copy-Item rime\custom_liding.tsv "$env:APPDATA\Rime\custom_liding.tsv"
   Copy-Item rime\lua\seal_filter.lua "$env:APPDATA\Rime\lua\seal_filter.lua"
   Copy-Item rime\opencc\SealVariants.txt "$env:APPDATA\Rime\opencc\SealVariants.txt"
   ```

3. 生成小篆派生 schema。

   例如给朙月拼音加小篆输出：

   ```powershell
   python scripts\make_seal_schema.py `
     -i "$env:APPDATA\Rime\luna_pinyin.schema.yaml" `
     -o "$env:APPDATA\Rime\luna_pinyin_seal.schema.yaml"
   ```

   也可以给任意其他方案加小篆输出。把输入文件和输出文件替换为对应方案即可：

   ```powershell
   python scripts\make_seal_schema.py `
     -i "$env:APPDATA\Rime\<source_schema>.schema.yaml" `
     -o "$env:APPDATA\Rime\<source_schema>_seal.schema.yaml"
   ```

   如果原方案的 `.schema.yaml` 不在用户目录，需要先把该方案文件复制到用户目录，或把 `-i` 指向实际文件路径。

4. 把小篆方案加入方案列表。

   在 `%APPDATA%\Rime\default.custom.yaml` 中加入：

   ```yaml
   patch:
     schema_list/+:
       - schema: luna_pinyin_seal
   ```

   其他方案则把 `schema` 改为生成后的 schema id：

   ```yaml
   patch:
     schema_list/+:
       - schema: <source_schema>_seal
   ```

5. 重新部署小狼毫。

   从开始菜单或托盘菜单选择“重新部署”。

### macOS 鼠须管

1. 获取并生成数据文件。

   ```sh
   mkdir -p rime/opencc

   curl -L \
     -o rime/opencc/SealVariants.txt \
     https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/SealVariants.txt

   curl -L \
     -o SealSources.txt \
     https://www.unicode.org/Public/UCD/latest/ucd/SealSources.txt

   python3 scripts/build_rime_seal_map.py \
     -i SealSources.txt \
     -o rime/seal_map.tsv
   ```

2. 复制通用文件到鼠须管用户目录。

   鼠须管用户目录通常是 `~/Library/Rime`，也可以从输入法菜单打开“用户设定”。

   ```sh
   mkdir -p ~/Library/Rime/lua
   mkdir -p ~/Library/Rime/opencc

   cp rime/seal_map.tsv ~/Library/Rime/seal_map.tsv
   cp rime/custom_liding.tsv ~/Library/Rime/custom_liding.tsv
   cp rime/lua/seal_filter.lua ~/Library/Rime/lua/seal_filter.lua
   cp rime/opencc/SealVariants.txt ~/Library/Rime/opencc/SealVariants.txt
   ```

3. 生成小篆派生 schema。

   例如给朙月拼音加小篆输出：

   ```sh
   python3 scripts/make_seal_schema.py \
     -i ~/Library/Rime/luna_pinyin.schema.yaml \
     -o ~/Library/Rime/luna_pinyin_seal.schema.yaml
   ```

   也可以给任意其他方案加小篆输出。把输入文件和输出文件替换为对应方案即可：

   ```sh
   python3 scripts/make_seal_schema.py \
     -i ~/Library/Rime/<source_schema>.schema.yaml \
     -o ~/Library/Rime/<source_schema>_seal.schema.yaml
   ```

   如果原方案的 `.schema.yaml` 不在用户目录，需要先把该方案文件复制到用户目录，或把 `-i` 指向实际文件路径。

4. 把小篆方案加入方案列表。

   在 `~/Library/Rime/default.custom.yaml` 中加入：

   ```yaml
   patch:
     schema_list/+:
       - schema: luna_pinyin_seal
   ```

   其他方案则把 `schema` 改为生成后的 schema id：

   ```yaml
   patch:
     schema_list/+:
       - schema: <source_schema>_seal
   ```

5. 重新部署鼠须管。

   从输入法菜单选择“重新部署”，或运行：

   ```sh
   /Library/Input\ Methods/Squirrel.app/Contents/MacOS/Squirrel --reload
   ```

## 字体

小篆字符位于 Unicode 小篆区，例如 `U+3D000`。候选栏和目标应用要能显示这些字符，需要安装覆盖 Unicode 小篆区的字体。

## 第三方数据

运行时需要以下第三方数据或由第三方数据生成的文件：

- `opencc/SealVariants.txt` 来自 OpenCC，许可证为 Apache-2.0。上游文件：<https://github.com/BYVoid/OpenCC/blob/master/data/dictionary/SealVariants.txt>
- `seal_map.tsv` 是由 Unicode `SealSources.txt` 生成的小篆映射表。Unicode 数据文件受 Unicode License v3 约束。许可说明：<https://www.unicode.org/copyright.html>

`custom_liding.tsv` 是本项目提供的人工补充表，不是第三方数据。它的格式是一行一条映射，第一列为输入方案产出的常用字，第二列为要额外尝试的 SealSources 代表字，中间用 Tab 分隔：

```text
# source	target
友	㕛
```

可以按需要继续添加映射。添加后重新部署 Rime 即可生效。

## 重新生成数据文件

### Windows

```powershell
New-Item -ItemType Directory -Force rime\opencc

curl.exe -L `
  -o rime\opencc\SealVariants.txt `
  https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/SealVariants.txt

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

curl -L \
  -o SealSources.txt \
  https://www.unicode.org/Public/UCD/latest/ucd/SealSources.txt

python3 scripts/build_rime_seal_map.py \
  -i SealSources.txt \
  -o rime/seal_map.tsv
```

## 模板内容

派生 schema 的核心变化是在候选过滤链最后插入 Lua filter。原方案自己的简繁转换、去重等 filter 会先运行，小篆转换最后处理候选：

```yaml
engine:
  filters:
    - simplifier
    - uniquifier
    - lua_filter@*seal_filter

seal_filter:
  map_file: seal_map.tsv
  liding_map_file: opencc/SealVariants.txt
  extra_liding_map_file: custom_liding.tsv
  single_char_variants: true
  max_variants: 9
```

候选文本会被替换为小篆，候选注释会显示原候选文本；如果 OpenCC `SealVariants.txt` 或 `custom_liding.tsv` 使用的 SealSources 代表字不同，注释会显示为 `原候选（SealSources代表字）`。映射表没有覆盖到的字符会保持原样。派生 schema 始终输出小篆；普通输入切回原方案。

可以在派生 schema 里调整：

```yaml
seal_filter:
  single_char_variants: true
  max_variants: 9
```
