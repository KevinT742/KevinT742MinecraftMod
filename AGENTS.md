# KevinT742MinecraftMod —— 项目约定

本文件记录**只在本仓库成立的约定**。凡是改动本项目的代码、构建脚本或仓库结构，
动手前先读这里。

---

## 一、Git 约定：每个子模组是独立仓库

**本项目不是单仓库。** 每个家族成员（`base/` 以及将来的其它成员目录）各自是一个
**独立的 git 仓库**，拥有自己的历史、自己的 remote、自己的 tag、自己的发布节奏。

母文件夹 `KevinT742MinecraftMod/` 同时也是**装配层**，负责家族共享的东西。

```
KevinT742MinecraftMod/           ← 装配层仓库（.git 在此）
├── settings.gradle               ← 成员清单：include 'base' 'sandbox' 'arcana'
├── build.gradle                  ← 共享插件版本 + 家族约定（Java 工具链 / 编码）
├── gradle.properties             ← 共享版本：minecraft_version / neo_version
├── gradlew / gradlew.bat / gradle/
├── verification/                 ← 离线验证工具（对全家族通用）
├── .github/workflows/            ← CI：装配成员 → 编译 → 自检
├── members.lock                  ← 成员版本锁定（记录各成员仓库该用哪个 ref）
│
├── base/                         ← ★ 独立仓库（base/.git）：Genesis
│   ├── build.gradle
│   ├── gradle.properties
│   └── src/
│
├── sandbox/                      ← ★ 独立仓库（sandbox/.git）：探针
│   ├── build.gradle              ←   依赖 base 的最小成员
│   ├── gradle.properties
│   └── src/
│
└── arcana/                       ← ★ 独立仓库（arcana/.git）：奥术
    ├── build.gradle              ←   依赖 base 的成员
    ├── gradle.properties
    └── src/
```

> **`members.lock` 的顺序就是依赖顺序**：靠前的成员先编译，靠后的成员编译时，
> 类路径里已经有靠前成员的类。离线验证脚本与 CI 都按这个顺序装配全族。
> 新增成员时把它放在它依赖的成员**后面**。

### 由此推出的硬性规则

1. **不要在母文件夹根上把成员目录一起提交。**
   根仓库的 `.gitignore` 必须忽略成员目录（`/base/` 等），否则成员源码会被根仓库吞进去，
   成员的独立历史就废了。

2. **成员仓库只放自己的东西**：`build.gradle`、`gradle.properties`、`src/`、`README.md`。
   **不放** `settings.gradle`、不放根 `gradle.properties`、不放 `verification/`。

3. **根仓库是强制的构建入口。** 成员的 `build.gradle` 依赖根 `gradle.properties` 的
   `minecraft_version` / `neo_version`，也依赖根 `build.gradle` 声明的插件版本和
   `subprojects` 块（Java 工具链、UTF-8 编码）。**单独 clone 一个成员仓库构建不了**，
   必须在装配好的母文件夹里构建。

4. **CI 必须跨仓库取得成员源码。** `actions/checkout@v4` 只 checkout 根仓库，
   拿不到成员源码。需要在 checkout 根仓库之后，按 `members.lock` 记录的 ref
   额外 checkout 每个成员仓库到对应目录。

5. **成员的版本组合由根仓库锁定。** 因为成员之间会通过 `implementation project(':base')`
   互相依赖，"一套能跑通的家族"是**根仓库的某个 commit + members.lock 里的一组 ref**
   共同决定的。只锁根仓库的 commit 是不够的。

6. **新增成员时**：在 `settings.gradle` 加 `include '成员名'`，在根 `.gitignore` 加
   `/成员名/`，在 `members.lock` 加一条该成员的 ref。

> **副作用提醒**：根 `.gitignore` 里的 `/base/` 会让遵守 gitignore 的检索工具
> （ripgrep 等）默认**跳过整个 base 目录**。搜 base 里的东西时要显式给目录路径，
> 不要以为"搜不到就是不存在"。

---

## 二、构建与验证约定

### 推送：git 传输层在这台机器上不稳

`github.com` 的 git 端点（git-upload-pack）**直连不通**，经 SOCKS5 代理
`127.0.0.1:10808` 能通但**很慢**（一次 `ls-remote` 可能要几十秒到 120 秒）；
而 `api.github.com` **直连稳定**。

因此本机 git 需要配代理：

```
git config --global http.proxy  socks5h://127.0.0.1:10808
git config --global https.proxy socks5h://127.0.0.1:10808
git config --global http.sslBackend openssl
```

（schannel 后端会出现 `server closed abruptly (missing close_notify)`。）

**推不动时的兜底**：`tools/push-via-api.ps1` 走 GitHub 的 Git Data API
（blob / tree / commit / ref），只依赖直连可达的 `api.github.com`：

```powershell
pwsh -File tools\push-via-api.ps1              # 推所有成员 + 装配层
pwsh -File tools\push-via-api.ps1 -Repos base   # 只推 base
```

它的已知限制与要点：

* 推的是**提交里的 blob**（用 `git cat-file` 按字节取），不是工作区文件 ——
  否则工作区的 CRLF 会被传上去，与 `.gitattributes` 的规则冲突。
* 改动清单是把两边的树列出来**逐路径比 blob**得出的 —— 不能用
  `git diff 远端..本地`：远端那个提交是 API 造的，本地根本没有它，
  diff 会失败，而失败会被当成"没有差异"，于是**静默漏推**。
* 重建的提交 **SHA 与本地不同**（作者/时间不同），推完要用
  `tools/align-with-remote.ps1` 对齐：

```powershell
pwsh -File tools\align-with-remote.ps1          # 对齐所有成员
```

  它不去 `git fetch`（那条路同样不稳），而是走 API 把远端提交的元数据读回来，
  在本地用 `commit-tree` 把那条提交链原样重建出来 —— 同样的树、同样的父提交、
  同样的作者与时间、同样的说明，于是 SHA 也一样。

  重建时有三个坑，脚本里都标了出来：
  `git mktree` 从**标准输入**读条目（不是文件参数）；
  API 报的 `message` **少了结尾的换行**（要补回去）；
  `ConvertFrom-Json` 会把日期串转成 DateTime 对象而**丢掉时区**
  （要用 `-DateKind String`）。

### 验证的两条路，各管各的

| 路 | 跑什么 | 能证明什么 | 不能证明什么 |
|---|---|---|---|
| **Gradle**（`./gradlew build` / `:base:selfTest`） | 真实 NeoForge | 代码**对真实 NeoForge 编译得过**、自检跑得起来 | 碰不到游戏注册表 |
| **离线工具链**（`verification/`） | 真实 Minecraft + NeoForge 桩件 | 算法、材质、存档格式**逐条断言** | 证明不了桩件以外的行为 |

**为什么要两条**：游戏注册表在游戏启动之前是不可用的。真实 NeoForge 在类路径上时，
连 `SharedConstants` 的静态初始化都要向模组加载器要东西（`FMLLoader.getCurrent()`），
所以独立进程走不到注册表 —— **材质自检（遍历全部方块与物品）只能在离线工具链里跑**，
没有对应的 Gradle 任务。CI 两条路都跑。

离线工具链是**跨平台**的（JDK 从 `JAVA_HOME` / `MC_JAVA_HOME` 里挑一个够新的，
类路径分隔符按平台取），所以本地和 CI 跑的是同一套脚本。

### 桩件铁律：必须与真实 NeoForge 源码逐个签名对齐

`verification/stubs/` 是**手写的最小桩件**，用来在够不到 `maven.neoforged.net` 的机器上
编译 Minecraft 适配层。**桩件不是装饰，它必须和真实 NeoForge 的签名一模一样**——
否则离线验证会给出**假绿**，等真编译时才炸。

**踩过的坑（2026-10-22，真实事故）**：桩件最早是照着调用方的期望手写的，于是：

| 桩件里写的 | 真实 NeoForge 26.2.x | 后果 |
|---|---|---|
| `registerSimpleBlock(String, Function<Properties,Properties>)` | `registerSimpleBlock(String, UnaryOperator<Properties>)` | 传不进去（`UnaryOperator` 是 `Function` 的**子接口**，反过来不成立） |
| `registerSimpleItem(String, Consumer<Item.Properties>)` | `registerSimpleItem(String, UnaryOperator<Item.Properties>)` | 同上 |
| `net.neoforged.neoforge.event.entity.PlayerEvent` | `net.neoforged.neoforge.event.entity.**player**.PlayerEvent` | 包路径错 |
| `PlayerEvent.PlayerTick`（捏造的） | 不存在；真实的是 `net.neoforged.neoforge.event.tick.PlayerTickEvent`（抽象类，含 `Pre`/`Post`） | 类不存在 |
| `PlayerEvent.getEntity()` 返回 `ServerPlayer` | 返回 `Player` | 需要自己 `instanceof` 一次 |

结果是：**离线验证 99 项全绿，但对真实 NeoForge 的 CI 编译炸了 13 个错误**。
`core` 层的算法是真的被验证过的；`mc` 适配层此前**从未对真实 NeoForge 编译过**。

**因此**：

1. 桩件的**生成器是 `verification/gen-stubs.ps1`**，不是 `stubs/` 目录下的文件——
   它会先清空整个 `stubs/` 再重新生成。改桩件必须改**生成器**，否则下次运行就被冲掉。
2. 动桩件之前先去核对真实源码：
   <https://github.com/neoforged/NeoForge> → `src/main/java/net/neoforged/neoforge/`
   本工程当前对齐的分支是 **`26.2.x`**（对应 NeoForge 26.2.0.93）。
   本机够不到 `maven.neoforged.net`，但 GitHub 可以，用 API 读文件即可。
3. **Minecraft 侧的签名不用猜**：本地 `verification/work/mc-classes` 是真实的 MC 26.2 类，
   用 `javap -cp verification/work/mc-classes <全限定类名>` 直接查。
4. 桩件只能证明**签名**对不对，证明不了**行为**对不对。桩件绿 ≠ 模组能跑，
   真正的闸门仍然是 CI 上对真实 NeoForge 的编译 + 自检。

### 不要拿 `./gradlew build` 当验证手段

`maven.neoforged.net` 在国内不可达，`./gradlew build` 会失败在
`Could not resolve net.neoforged:neoform-runtime:<版本>`（连接超时）。
Gradle 发行包官方地址（`services.gradle.org` 会 307 到 GitHub）同样会超时，
本项目已把 wrapper 指向南京大学镜像（SHA-256 与官方一致，由 `distributionSha256Sum` 校验）。

**正确的验证链路**（只从 Mojang 官方源下载游戏本体，对全家族通用）：

```powershell
cd verification
pwsh -File fetch26.ps1         # 首次：下载 MC 26.2 客户端 / 服务端 / 依赖库
pwsh -File prep.ps1            # 解包并生成编译类路径
pwsh -File build-and-test.ps1  # 编译全部源码 + 运行自检
```

校验非 `base` 的成员：

```powershell
$env:MC_MOD_MEMBER='成员名'; pwsh -File build-and-test.ps1
```

Gradle 侧只跑**不解析 NeoForge 制品**的任务做结构校验：`projects`、`generateModMetadata`。

### 本机环境

- 本机 JDK 25 在 `E:\DevEnv\JDKs\ms-25.0.4`；**PATH 上的 java 是 8**，
  运行 Gradle 前先设 `JAVA_HOME`。
- 真正的 NeoForge 打包编译只能在 CI（`windows-latest` / `ubuntu-latest` + `setup-msbuild`）
  上完成，本地做不了。

---

## 三、代码分层约定（base 及全体成员）

```
api/    稳定扩展面 —— 家族成员可以依赖的契约
core/   纯算法层 —— 零 Minecraft 依赖，可脱离游戏独立测试
mc/     Minecraft / NeoForge 适配层 —— 只做粘合
dev/    自检程序 —— 不启动游戏即可验证算法
```

**分层原则**：`api` 定义契约 → `core` 实现算法 → `mc` 只做粘合。
新代码进哪一层，先问"它依赖 Minecraft 吗"：

* 不依赖 → `core`
* 定义给兄弟模组用的契约 → `api`
* 需要碰 Minecraft 类 → `mc`

`core` 层不得 import 任何 `net.minecraft.*` / `net.neoforged.*`。

### 自检的两个目录，别搞混

* `<成员根包>/dev/`（如 `genesis/dev/`、`sandbox/dev/`）—— 自检用**窄类路径**编译：
  类路径里只有各成员的类，**没有游戏**。这机械地证明了 `api` / `core` 层不依赖 Minecraft。
  想给某个 api 加一个 `com.mojang.serialization` 的依赖？窄类路径会立刻拦住你。
* 更深的 `dev/` 包（如 `genesis/mc/dev/`）—— 自检需要游戏的 NBT 之类的机制，
  用**完整类路径**编译。

**注意**：`api` 层连 `com.mojang.serialization` 都要避开。序列化格式属于 mc 层
（`mc/magic/MagicInfluenceCodec.java`），因为写文件的是 mc 层。

### 兄弟模组怎么进基地

**一律走 `genesis.mc.GenesisApi`**，不要伸进 base 的内部结构。facade 给出的东西：

| 要什么 | 拿它 |
|---|---|
| 某维度的魔力场（**持久化**，重启不丢） | `GenesisApi.magicField(level)` |
| 某位置的浓度 / 强度 | `GenesisApi.concentration(level, x, z)` / `tierAt(...)` |
| 某维度所在的星球 | `GenesisApi.planetOf(level)` |
| 某方块的材质档案 | `GenesisApi.materialOf(block)` |
| 把**自己的**方块/物品模板翻译成 Minecraft 属性 | `GenesisApi.blockProperties(template)` / `itemProperties(template)` |

最后一条是 `sandbox` 这个探针逼出来的：模板在 `api` 层，但"模板 → Minecraft 属性"
的翻译原先锁在 base 的 `mc` 层内部，兄弟模组拿不到。**新成员会暴露新的这种缺口，
看到就补进 facade，别让兄弟模组去碰内部结构。**

### 原版材质：靠规则，不靠手写

原版有 **1196 个方块**和 **1537 个物品**，逐个手写档案既不现实也容易错。
所以原版材质是**按标识符的规则**推出来的（`mc/material/VanillaMaterials`）：

* 原版的标识符本身成系统——`iron_ingot` / `iron_ore` / `iron_sword` 都带着同一个词，
  那个词就说明了它是什么做的；
* **同一个标识符永远给出同一种材质**，所以方块与"放置它的物品"是同一种东西；
* **用量由东西的种类决定**：方块一立方米，锭是其中一小块，工具比锭多一点，食物是一份；
* 方块物品**继承它放置的方块**的材质——二者的标识符不一定相同
  （一团线是 `minecraft:string`，一格线块是 `minecraft:string_block`）；
* 认不出来的物品拿 `MaterialFamily.generic` 的档案。**没有例外**：覆盖率必须是 100%，
  材质自检会逐个查。

> 踩过的坑：**查材质时不要硬编码命名空间**。曾经写成 `"genesis:" + path`，
> 于是原版方块永远查不到、家族自己的方块反而用错了名字。正确写法是
> `BuiltInRegistries.BLOCK.getKey(block).toString()`。

### 魔法模型是设计中心

一切魔法来自**对外界游离魔力的使用**：世界里每个地区有自己的**魔力浓度**，
浓度在世界生成时随种子初始化，之后可被外界操作（仪式、献祭、汲取）改变。
浓度分档 `NONE / TRACE / FAINT / MODERATE / STRONG / EXTREME`。

`MagicProperties` 用三个量把模型落到每种材质上：

| 量 | 含义 | 决定 |
|---|---|---|
| 适应度 adaptability | 材料多容易吃进魔力 | 是否算**魔力材料**（阈值 0.55） |
| 引导效率 channelEfficiency | 魔力能不能被**控制地**导过去 | 能不能当引导介质 |
| 留存 retention | 放进来的魔力能留多久 | 魔药能不能装瓶 |

固化形态：`MagicInput.ESSENCE`（固化的魔力）、`MagicInput.CHANNEL`（固化的引导方式）、
`MagicChannelKind.SPELL`（魔咒，说完即逝，需活着的施术者）。

### 温度一律用开尔文

`Temperature` 值类型承载绝对温度，构造时拒绝低于绝对零度，降温钳位在 0 K。
比值只在绝对标度下有意义；温差在两套标度下数值相同。
`Temperature.format()` 输出 `"1811.15K（1538℃）"`。

---

## 四、已知缺口（改代码时注意别重复造）

base 目前**尚未**接入玩法的地方（README 第七节"已知限制"同样列了）：

* 魔力浓度对玩家的绑定点仍然只有 F3 调试字符串（`GenesisChunkGenerator.addDebugScreenInfo`，
  它显示的是由种子推出的**分布**，不含被施加过的影响）
* 魔力器官与引导方式是**描述性数据**（类型 + 数值），未接实体与合成表
* 星球的重力 / 天空 / 云 / 天气是参数化预留，未驱动客户端渲染
* 生成器 `fillFromNoise` 用高度图式填充，洞穴由独立 3D 噪声雕刻
* 结构是程序化简化建筑，未接原版结构模板系统

> **魔力场已经是持久化的**（2026-10-22）：`MagicField` 的影响列表由
> `mc/magic/GenesisMagicData`（一个 `SavedData`）持有，**每个维度一份**，写 NBT。
> 入口是 `mc/GenesisApi`——兄弟模组一律走它，不要伸进 base 的内部结构。
>
> 注意 `SavedDataType` 的第四个参数（data fix type）传的是 `null`：这是我们自己的数据，
> 没有原版 datafixer 认识它，NeoForge 支持 null 表示跳过修复。**不要**随便改成某个
> `DataFixTypes.SAVED_DATA_*`，那会让原版的修复器跑在我们的数据上。
