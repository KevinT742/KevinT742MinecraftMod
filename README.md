# KevinT742MinecraftMod

**Minecraft 26.2 · NeoForge 26.2.0.93 · Java 25**

这是 Kevin742 自设计模组家族的**母文件夹**，同时也是整个家族的 Gradle 根工程。

每个模组都是它的一个独立子工程：放在自己的文件夹里，拥有自己的 `build.gradle`、
自己的 `gradle.properties`、自己的资源命名空间，可以单独构建、单独发布，也可以被兄弟模组依赖。

---

## 一、目录结构

```
KevinT742MinecraftMod/          ← 母文件夹 = 家族根工程 = ★ 装配层仓库
├── settings.gradle             ← 家族成员清单（include 'xxx'）
├── build.gradle                ← 统一插件版本 + 家族约定（Java 工具链、编码）
├── gradle.properties           ← 共享属性（Minecraft / NeoForge 版本）
├── members.lock                ← 成员版本清单：目录 | 仓库地址 | ref
├── gradlew / gradlew.bat       ← 构建入口（在根目录执行）
├── gradle/wrapper/
├── tools/fetch-members.sh      ← 按 members.lock 把各成员仓库拉到本地
├── verification/               ← 离线验证工具（对全家族通用）
├── .github/workflows/          ← CI：装配成员 → 构建 → 自检
├── AGENTS.md                   ← 项目约定（改动前先读）
├── TEMPLATE_LICENSE.txt
│
├── base/                       ← ★ 家族成员①：Genesis（地基）
│   │                           ←   ★ 独立 git 仓库（base/.git）
│   ├── build.gradle            ←   该成员的构建脚本
│   ├── gradle.properties       ←   该成员自己的属性
│   ├── README.md               ←   该成员的详细文档
│   └── src/main/
│       ├── java/genesis/
│       ├── resources/
│       └── templates/
│
└── sandbox/                    ← ★ 家族成员②：Sandbox（探针）
    │                           ←   ★ 独立 git 仓库（sandbox/.git）
    ├── build.gradle            ←   依赖 base 的最小成员
    ├── gradle.properties       ←   该成员自己的属性
    ├── README.md               ←   该成员的详细文档
    └── src/main/
        ├── java/sandbox/
        ├── resources/
        └── templates/
│
└── arcana/                     ← ★ 家族成员③：Arcana（奥术）
    │                           ←   ★ 独立 git 仓库（arcana/.git）
    ├── build.gradle            ←   依赖 base 的成员
    ├── gradle.properties       ←   该成员自己的属性
    ├── README.md               ←   该成员的详细文档
    └── src/main/
        ├── java/arcana/
        ├── resources/
        └── templates/
```

### 仓库结构：装配层 + 独立成员

**每个家族成员是一个独立的 git 仓库**，拥有自己的历史、tag 和发布节奏；
母文件夹则是**装配层**，只保存家族共享的脚手架。

```
本仓库（装配层）                 base / sandbox（各自的独立仓库）
├─ settings.gradle              ├─ build.gradle
├─ build.gradle                 ├─ gradle.properties
├─ gradle.properties            └─ src/
├─ members.lock  ← 记录每个成员该用哪个 ref
└─ .github/workflows/ ← CI 按 members.lock 装配成员
```

因此有两个必须记住的约束：

* **成员源码不在本仓库里**，CI 与新环境都要先跑 `tools/fetch-members.sh` 把成员拉下来。
* **成员之间靠 `members.lock` 锁版本**：成员之间会通过 `implementation project(':base')`
  互相依赖，一套能跑通的家族 = 本仓库的某个 commit + `members.lock` 里的一组 ref。

**`members.lock` 的顺序就是依赖顺序**：靠前的成员先编译，靠后的成员编译时，
类路径里已经有靠前成员的类。离线验证脚本也按这个顺序装配全族。

---

## 二、家族成员

| 子工程 | 模组 | mod id | 定位 |
|---|---|---|---|
| `base/` | [Genesis](base/README.md) | `genesis` | **地基**：统一材质模板（物理/化学/魔法）、物品注册信息、魔法模型（游离魔力·浓度场·器官·材料·引导方式）、真实世界生成、结构体系、多星球架构 |
| `sandbox/` | [Sandbox](sandbox/README.md) | `sandbox` | **探针**：最小的兄弟模组，只靠 `implementation project(':base')` 就能用上 Genesis 的契约。它证明"再开一个模组真的只是照抄一个目录的事" |
| `arcana/` | [Arcana](arcana/README.md) | `arcana` | **奥术**：把 Genesis 的游离魔力变成可以用得上的东西——奥术祭坛（抽取/灌注地面的魔力）、奥术透镜、魔药瓶。因为魔力是存下来的，祭坛对一片地做过的事一直算数 |

`base` 对外提供 `api/`（稳定扩展面）与 `core/`（纯算法层）两套契约，家族成员可以直接依赖。
进入基地能力的统一入口是 `genesis.mc.GenesisApi`：

```java
dependencies {
    implementation project(':base')
}
```

```java
Optional<MagicField> field = GenesisApi.magicField(serverLevel);
field.ifPresent(f -> f.influence(x, z, 128.0, -0.6));   // 魔力场是持久化的
```

---

## 三、共享什么、各自拥有什么

| 内容 | 位置 | 说明 |
|---|---|---|
| Minecraft / NeoForge 版本 | 根 `gradle.properties` | 全家族统一升级，只改这一处 |
| Gradle 插件版本 | 根 `build.gradle` | 子工程引用插件时不再写版本号 |
| Java 工具链、源码编码 | 根 `build.gradle`（`subprojects` 块） | 全家族统一 Java 25 / UTF-8 |
| 成员清单 | 根 `settings.gradle` | `include '成员名'` |
| 成员版本锁定 | 根 `members.lock` | `目录 \| 仓库地址 \| ref` |
| mod id / 名称 / 版本 / 许可 | 各成员的 `gradle.properties` | 每个模组独立 |
| 源码与资源 | 各成员的 `src/` | 每个模组独立，命名空间用自己的 mod id |

---

## 四、如何新增一个家族成员

> 成员是**独立仓库**，所以这条流程分成两半：
> **装配层**（本仓库）登记它，**成员仓库**里放它自己的代码。

### 4.1 装配层（本仓库）

1. 在根 `settings.gradle` 的成员清单里登记：

   ```groovy
   include '新成员名'
   ```

2. 在根 `.gitignore` 里忽略成员目录，让本仓库不吞掉它的源码：

   ```gitignore
   /新成员名/
   ```

3. 在根 `members.lock` 里登记成员该用哪个 ref：

   ```
   新成员名 | https://github.com/KevinT742/YourMod.git | main
   ```

4. 把成员仓库拉到本地：

   ```bash
   ./tools/fetch-members.sh
   ```

### 4.2 成员仓库

5. 新建 `新成员名/` 目录并**单独 `git init`**，把它变成独立仓库。
   成员仓库只放自己的东西：`build.gradle`、`gradle.properties`、`src/`、`README.md`、
   以及一份自己的 `.gitignore` 和 `.gitattributes`（根仓库的规则管不到独立仓库）。

   > **直接照抄 `sandbox/`。** 它是家族里最小的一个成员，已经把
   > `implementation project(':base')`、moddev 的模组依赖写法、
   > 用 Genesis 的模板注册方块与物品、以及一个自检全都演示了一遍。

6. 复制 `base/build.gradle` 作为模板，删掉与 Genesis 无关的部分（`genesis/dev/**` 排除规则、`selfTest` 任务等）。

7. 新建 `新成员名/gradle.properties`，写上自己的身份信息：

   ```properties
   mod_id=your_mod
   mod_name=Your Mod
   mod_license=MIT
   mod_version=1.0.0
   mod_group_id=your_mod
   ```

8. 目录约定：`新成员名/src/main/{java,resources,templates}`。资源模板里的
   `${mod_id}`、`${mod_name}` 等占位符由各子工程自己的 `generateModMetadata` 任务展开。

9. 需要复用基地能力时，在依赖里加 `implementation project(':base')`，
   并在自己的 `neoforge.mods.toml` 里声明对 `genesis` 的依赖。

   复用基地能力的入口是 **`genesis.mc.GenesisApi`**：它给出一个维度的**魔力场**
   （持久化，重启不丢）、**星球**、某方块的**材质档案**，以及该位置的**浓度**与**强度**。
   一律走它，不要伸进 Genesis 的内部结构——内部结构会变，facade 不会。

10. 离线验证脚本默认校验 `base`；要校验新成员，用环境变量指定子工程目录名即可：

    ```powershell
    $env:MC_MOD_MEMBER='新成员名'; pwsh -File verification\build-and-test.ps1
    ```

---

## 五、构建与运行

### 首次装配

成员是独立仓库，克隆本仓库后**成员目录是空的**，先把它们拉下来：

```bash
./tools/fetch-members.sh          # 按 members.lock 拉取全部成员
./tools/fetch-members.sh --force  # 已有成员目录时强制重建
```

> 在 Windows 上用 Git Bash 或 WSL 运行这个脚本。

### 日常构建

在**根目录**执行：

```bash
./gradlew build            # 构建全部成员
./gradlew :base:build      # 只构建 base
./gradlew :base:runClient  # 启动 base 的客户端
./gradlew :base:runServer  # 启动 base 的服务端
./gradlew :base:selfTest   # 运行 base 的算法自检（不需要启动游戏）
```

> **在成员目录里单独跑 Gradle 是构建不了的**：成员依赖根 `gradle.properties` 的版本号
> 和根 `build.gradle` 的插件声明，所以**必须在装配好的母文件夹里构建**。

### 网络前提

构建需要访问 **Maven Central**、**Gradle Plugin Portal** 和 **`maven.neoforged.net`**。
若 `maven.neoforged.net` 不可达（国内常见），需要加两处镜像：

1. **Gradle 插件**（`net.neoforged.moddev` 等）——根 `settings.gradle` 的 `pluginManagement`：

   ```groovy
   pluginManagement {
       repositories {
           maven { url = 'https://你的镜像/maven.neoforged.net/releases/' }
           gradlePluginPortal()
           mavenCentral()
       }
   }
   ```

2. **NeoForge 制品本身**（`neoforge` / `neoform-runtime`）——各成员的 `build.gradle` 的 `repositories` 块：

   ```groovy
   repositories {
       maven { url = 'https://你的镜像/maven.neoforged.net/releases/' }
   }
   ```

若连 `maven.neoforged.net` 完全不可达，也可以用 `verification/` 的离线工具（见下）验证代码。

> **Gradle 发行包**：`gradle/wrapper/gradle-wrapper.properties` 的 `distributionUrl` 默认走
> 南京大学镜像（官方地址会被重定向到 GitHub，部分网络下会超时）。镜像文件与官方发行包
> SHA-256 完全一致，并由 `distributionSha256Sum` 自动校验；要切回官方地址，改这一行即可。

### 离线验证（无需 NeoForge 仓库）

当 `maven.neoforged.net` 完全不可达时，仍然可以**用真实的 Minecraft 26.2 jar 校验整个模组**。
`verification/` 目录提供了一套离线工具，它只从 Mojang 官方源下载游戏本体：

```powershell
cd verification
pwsh -File fetch26.ps1         # 下载 Minecraft 26.2 客户端 / 服务端 / 依赖库（仅首次）
pwsh -File prep.ps1            # 解包并生成编译类路径
pwsh -File build-and-test.ps1  # 编译模组并运行自检
```

这套工具对全家族通用：默认校验 `base`，换成员只需指定目录名：

```powershell
$env:MC_MOD_MEMBER='成员名'; pwsh -File build-and-test.ps1
```

---

## 六、许可

MIT
