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
├── settings.gradle               ← 成员清单：include 'base'
├── build.gradle                  ← 共享插件版本 + 家族约定（Java 工具链 / 编码）
├── gradle.properties             ← 共享版本：minecraft_version / neo_version
├── gradlew / gradlew.bat / gradle/
├── verification/                 ← 离线验证工具（对全家族通用）
├── .github/workflows/            ← CI：装配成员 → 编译 → 自检
├── members.lock                  ← 成员版本锁定（记录各成员仓库该用哪个 ref）
│
├── base/                         ← ★ 独立仓库（base/.git）
│   ├── build.gradle
│   ├── gradle.properties
│   └── src/
└── <新成员>/                      ← ★ 独立仓库（<新成员>/.git）
```

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

---

## 二、构建与验证约定

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

* 魔力浓度只有 F3 调试字符串这一个绑定点（`GenesisChunkGenerator.addDebugScreenInfo`）
* 魔力器官与引导方式是**描述性数据**（类型 + 数值），未接实体与合成表
* 星球的重力 / 天空 / 云 / 天气是参数化预留，未驱动客户端渲染
* 生成器 `fillFromNoise` 用高度图式填充，洞穴由独立 3D 噪声雕刻
* 结构是程序化简化建筑，未接原版结构模板系统

> `MagicField` 目前是**内存态**：实例挂在 `GenesisChunkGenerator.Models` 内部的
> `CopyOnWriteArrayList` 上，没有 dimension 作用域，不写 NBT，
> `influence()` 的结果**服务器重启即丢**。要做仪式 / 献祭类玩法，先把它改成
> dimension 级 + 可持久化。
