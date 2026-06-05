---
title: build.rs 构建脚本介绍与实战
published: true
layout: post
date: 2026-05-25 10:00:00
permalink: /rust/build-rs.html
tags:
  - 构建脚本
  - 代码生成
  - FFI
categories:
  - Rust
---

想象工厂流水线上有一道"预处理工序"：原材料进入主生产线之前，先经过打磨、涂层、校准。`build.rs` 就是 Rust 项目里的这道工序——它在主 `crate` 编译之前独立运行，负责生成代码、探测系统库、注入版本信息，把"编译环境"准备好。对于刚接触 Rust 的开发者来说，`build.rs` 往往是第一个让人困惑的概念：它不是普通的源码，却藏在项目根目录；它输出的不是程序，却能改变整个编译结果。本文从原理到实战，帮你彻底搞清楚它。

## 一、build.rs 是什么

### 1.1 构建脚本的职责

`build.rs` 是放在项目根目录（与 `Cargo.toml` 同级）的一个特殊 Rust 源文件。`Cargo` 在编译主 `crate` 之前，会先把它编译成一个独立的可执行程序并运行。它的输出是一系列以 `cargo:` 开头的 `println!` 指令，`Cargo` 读取这些指令并据此影响后续的编译过程。

常见用途：

| 场景 | 说明 |
|------|------|
| 代码生成 | 根据配置或外部文件生成 `.rs` 源码，供主 `crate` 用 `include!` 引入 |
| 链接原生库 | 探测系统中的 `C`/`C++` 库，告诉链接器去哪里找 |
| 编译 C 源码 | 用 `cc` 等 `crate` 将项目自带的 C 文件编译为静态库 |
| 条件编译标志 | 根据运行时探测结果动态添加 `cfg` 标志，比内置 `feature` 更灵活 |
| 注入环境变量 | 将构建时信息（版本号、时间戳、目标平台）注入为编译期常量 |

### 1.2 执行时机

`Cargo` 的完整构建顺序如下：

```
cargo build
    │
    ├─ 1. 解析 Cargo.toml，下载/编译所有依赖
    │
    ├─ 2. 编译 build.rs（使用 [build-dependencies]）
    │
    ├─ 3. 运行 build.rs，读取其输出的 cargo: 指令
    │
    └─ 4. 编译主 crate（src/main.rs 或 src/lib.rs）
```

`build.rs` 在一个**隔离的沙箱**中运行：它拥有独立的依赖列表（`[build-dependencies]`，不会污染主 `crate` 的依赖图），也有独立的环境变量集合。主 `crate` 的代码无法直接调用 `build.rs` 的函数——两者之间唯一的通信渠道就是那些 `cargo:` 指令。

> 若项目根目录存在 `build.rs` 文件，`Cargo` 默认自动启用它，无需在 `Cargo.toml` 中声明。也可以显式指定路径：`build = "scripts/build.rs"`。若要**禁用**自动发现，设置 `build = false`。

## 二、第一个构建脚本

### 2.1 创建与声明

最简单的 `build.rs` 只有一个空 `main`：

```rust
fn main() {}
```

更实用的第一个示例——在构建时输出一条警告，验证脚本确实被执行了：

```rust
fn main() {
    println!("cargo:warning=这是来自 build.rs 的构建警告");
    println!("cargo:rerun-if-changed=build.rs");
}
```

运行 `cargo build` 时，终端会显示：

```
   Compiling base-rust v0.1.0 (/path/to/base-rust)
warning: base-rust@0.1.0: 这是来自 build.rs 的构建警告
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.10s
```

`cargo:warning` 是 `build.rs` 向用户传递信息的标准方式——普通的 `println!`（不带 `cargo:` 前缀）默认不显示。

### 2.2 Cargo 指令协议

`build.rs` 通过向标准输出写入 `cargo:KEY=VALUE` 格式的行来与 `Cargo` 通信。完整指令一览：

| 指令 | 说明 |
|------|------|
| `cargo:rustc-link-lib=[KIND=]NAME` | 链接原生库，`KIND` 可为 `static`、`dylib`、`framework` |
| `cargo:rustc-link-search=[KIND=]PATH` | 添加链接器库搜索路径 |
| `cargo:rustc-cfg=KEY[="VALUE"]` | 为主 `crate` 添加自定义 `cfg` 标志 |
| `cargo::rustc-check-cfg=cfg(KEY)` | 声明某个自定义 `cfg` 是合法的（`Rust 1.80+` 必须） |
| `cargo:rustc-env=KEY=VALUE` | 向主 `crate` 注入编译期环境变量，可通过 `env!("KEY")` 读取 |
| `cargo:rustc-flags=FLAGS` | 向 `rustc` 传递额外编译器标志 |
| `cargo:rerun-if-changed=PATH` | 指定文件或目录变化时重新运行 `build.rs` |
| `cargo:rerun-if-env-changed=VAR` | 指定环境变量变化时重新运行 `build.rs` |
| `cargo:warning=MESSAGE` | 输出构建警告（只有此前缀的输出才对用户可见） |
| `cargo:metadata=KEY=VALUE` | 向依赖此 `crate` 的上层 `build.rs` 暴露元数据 |

> 注意 `cargo::rustc-check-cfg` 使用双冒号（`cargo::`），是 `Cargo 1.80` 引入的新格式，用于声明自定义 `cfg` 的合法性。与此同时，旧格式 `cargo:rustc-cfg` 仍使用单冒号，两种格式并存。

## 三、内置环境变量

`build.rs` 运行时，`Cargo` 会预先设置一批环境变量，供脚本读取构建上下文信息。

| 变量 | 说明 |
|------|------|
| `OUT_DIR` | 构建输出目录，生成文件**必须**写入此目录 |
| `CARGO_MANIFEST_DIR` | `Cargo.toml` 所在的目录（项目根目录） |
| `CARGO_PKG_NAME` | 当前包名 |
| `CARGO_PKG_VERSION` | 当前包版本号（如 `0.1.0`） |
| `CARGO_PKG_VERSION_MAJOR` | 主版本号 |
| `CARGO_PKG_VERSION_MINOR` | 次版本号 |
| `CARGO_PKG_VERSION_PATCH` | 补丁版本号 |
| `TARGET` | 编译目标三元组，如 `x86_64-unknown-linux-gnu` |
| `HOST` | 构建宿主机三元组（跨编译时与 `TARGET` 不同） |
| `PROFILE` | 构建 `profile`：`debug` 或 `release` |
| `NUM_JOBS` | 并行编译任务数 |
| `OPT_LEVEL` | 优化级别：`0`/`1`/`2`/`3`/`s`/`z` |
| `DEBUG` | 是否包含调试信息：`true` 或 `false` |
| `CARGO_CFG_TARGET_OS` | 目标操作系统：`linux`/`macos`/`windows` 等 |
| `CARGO_CFG_TARGET_ARCH` | 目标架构：`x86_64`/`aarch64`/`riscv64gc` 等 |
| `CARGO_CFG_TARGET_ENV` | 目标环境：`gnu`/`musl`/`msvc` 等 |
| `CARGO_CFG_TARGET_POINTER_WIDTH` | 指针宽度：`32` 或 `64` |
| `CARGO_FEATURE_<NAME>` | 若 feature `NAME` 已启用则此变量存在（值为 `1`） |

读取这些变量的惯用写法：

```rust
use std::env;

fn main() {
    let out_dir = env::var("OUT_DIR").unwrap();
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap();
    let profile = env::var("PROFILE").unwrap();

    println!("cargo:warning=out_dir={out_dir}");
    println!("cargo:warning=target_os={target_os}");
    println!("cargo:warning=profile={profile}");

    println!("cargo:rerun-if-changed=build.rs");
}
```

> `HOST` 与 `TARGET` 在**交叉编译**（`cross-compile`）时会不同。例如在 `x86_64` 的 `Linux` 上为 ARM 嵌入式设备编译时，`HOST=x86_64-unknown-linux-gnu`，`TARGET=thumbv7em-none-eabi`。构建脚本中**绝对不能**用 `HOST` 的值来判断目标平台特性，必须用 `TARGET` 或 `CARGO_CFG_*` 系列变量。

## 四、代码生成与 OUT_DIR

### 4.1 OUT_DIR 机制

`Cargo` 为每次构建分配一个独立的临时目录作为 `OUT_DIR`，路径类似 `target/debug/build/my-crate-xxxx/out/`。`build.rs` 生成的所有文件都必须写入这个目录——写入其他路径会因沙箱限制失败。

生成文件后，主 `crate` 通过 `include!` 宏将其纳入编译：

```rust
// src/main.rs 或 src/lib.rs 中
include!(concat!(env!("OUT_DIR"), "/generated_file.rs"));
```

`env!("OUT_DIR")` 是一个编译期宏，在 `rustc` 读取 `build.rs` 输出之后展开，因此始终指向本次构建的正确目录。

### 4.2 实战：注入版本与平台信息

下面的示例演示如何在构建时生成一个包含包名、版本号、目标平台信息的常量文件，供主程序直接使用。

**`build.rs`：**

```rust
use std::env;
use std::fs;
use std::path::Path;

fn main() {
    let out_dir = env::var("OUT_DIR").unwrap();
    let dest = Path::new(&out_dir).join("platform_info.rs");

    let os      = env::var("CARGO_CFG_TARGET_OS").unwrap_or_else(|_| "unknown".to_string());
    let arch    = env::var("CARGO_CFG_TARGET_ARCH").unwrap_or_else(|_| "unknown".to_string());
    let version = env::var("CARGO_PKG_VERSION").unwrap();
    let name    = env::var("CARGO_PKG_NAME").unwrap();

    let content = format!(
        "pub const PKG_NAME: &str = \"{name}\";\n\
         pub const PKG_VERSION: &str = \"{version}\";\n\
         pub const TARGET_OS: &str = \"{os}\";\n\
         pub const TARGET_ARCH: &str = \"{arch}\";\n"
    );

    fs::write(dest, content).unwrap();

    // 只有 Cargo.toml 改变（版本号更新）时才重新生成
    println!("cargo:rerun-if-changed=Cargo.toml");
}
```

**`src/main.rs`：**

```rust
include!(concat!(env!("OUT_DIR"), "/platform_info.rs"));

fn main() {
    println!("Package : {} v{}", PKG_NAME, PKG_VERSION);
    println!("Platform: {}/{}", TARGET_OS, TARGET_ARCH);
}
```

运行结果：

```
Package : base-rust v0.1.0
Platform: linux/x86_64
```

这种模式的关键优势在于：`PKG_NAME`、`PKG_VERSION` 等常量在编译期就已确定，运行时零开销；而且它们与 `Cargo.toml` 中的声明严格同步，不会出现手动维护版本字符串时的遗漏。

## 五、自定义 cfg 标志

### 5.1 cargo:rustc-cfg 与 rustc-check-cfg

内置的 `#[cfg(feature = "...")]` 只能在 `Cargo.toml` 声明 `feature` 后才能使用，且只能在编译前手动指定。`cargo:rustc-cfg` 的优势在于可以**在 `build.rs` 运行期探测任意条件**——查询系统版本、检测库是否存在、读取外部文件——再动态决定是否开启某个标志。

从 `Rust 1.80` 起，编译器会对未声明的自定义 `cfg` 发出警告。因此每个自定义 `cfg` 都需要配套一条 `cargo::rustc-check-cfg` 指令，告知编译器该 `cfg` 是合法的：

```rust
// 先声明，再使用
println!("cargo::rustc-check-cfg=cfg(my_flag)");
println!("cargo:rustc-cfg=my_flag");
```

### 5.2 实战：按构建模式开关日志

**`build.rs`：**

```rust
use std::env;

fn main() {
    // 声明 debug_mode 是合法的自定义 cfg（Rust 1.80+ 要求）
    println!("cargo::rustc-check-cfg=cfg(debug_mode)");

    let profile = env::var("PROFILE").unwrap();
    if profile == "debug" {
        println!("cargo:rustc-cfg=debug_mode");
    }
    println!("cargo:rerun-if-changed=build.rs");
}
```

**`src/main.rs`：**

```rust
fn main() {
    #[cfg(debug_mode)]
    println!("[DEBUG] 当前为 debug 构建，已启用详细日志");

    println!("程序正常运行");
}
```

`cargo run`（debug 模式）运行结果：

```
[DEBUG] 当前为 debug 构建，已启用详细日志
程序正常运行
```

`cargo run --release`（release 模式）运行结果：

```
程序正常运行
```

`#[cfg(debug_mode)]` 块在 `release` 构建中被编译器完全消除，不产生任何运行时开销，也不会影响二进制体积。

> 与 `cfg!(debug_assertions)` 相比，自定义 `cfg` 的优势是名称语义明确，且可以根据任意探测逻辑设置，不局限于 Cargo 内置的 `profile` 规则。

## 六、链接原生 C 库

### 6.1 手动指定链接参数

当项目需要调用系统中已有的 C 库时，`build.rs` 通过两条指令告知链接器：

```rust
fn main() {
    // 链接动态库 libm（数学库）
    println!("cargo:rustc-link-lib=dylib=m");

    // 如果库不在默认搜索路径，需要额外指定
    println!("cargo:rustc-link-search=native=/usr/local/lib");

    println!("cargo:rerun-if-changed=build.rs");
}
```

`rustc-link-lib` 的 `KIND` 可选值：

| `KIND` | 说明 |
|--------|------|
| `dylib`（默认） | 动态链接库（`.so` / `.dll` / `.dylib`） |
| `static` | 静态链接库（`.a` / `.lib`），链接器将其直接嵌入产物 |
| `framework` | `macOS` 专用的 `.framework` 包 |

### 6.2 使用 cc crate 编译 C 源码

更常见的场景是项目自带 C 源文件，需要在构建时编译成静态库并链接到 Rust 产物中。`cc` 是 Rust 生态中专门处理这类任务的 `crate`。

**`Cargo.toml`（仅需添加构建依赖）：**

```toml
[build-dependencies]
cc = "1"
```

`[build-dependencies]` 中声明的依赖**只在 `build.rs` 的编译和运行阶段可用**，不会出现在主 `crate` 的依赖图中，对最终产物的体积没有影响。

**`c_src/add.c`：**

```c
int c_add(int a, int b) {
    return a + b;
}
```

**`build.rs`：**

```rust
fn main() {
    cc::Build::new()
        .file("c_src/add.c")
        .compile("add");            // 生成 libadd.a 并告知 Cargo 链接它
    println!("cargo:rerun-if-changed=c_src/add.c");
}
```

**`src/main.rs`（Rust 2024 edition）：**

```rust
// Rust 2024 edition 要求 extern 块声明为 unsafe
unsafe extern "C" {
    fn c_add(a: i32, b: i32) -> i32;
}

fn main() {
    let result = unsafe { c_add(10, 32) };
    println!("c_add(10, 32) = {}", result);
}
```

运行结果：

```
c_add(10, 32) = 42
```

> **Rust 2024 edition 注意事项**：Rust 2024 要求所有 `extern` 块必须显式写成 `unsafe extern`，以明确标出"调用这些函数的风险由程序员负责"。如果使用的是 `edition = "2021"` 或更早版本，保持原来的 `extern "C" {}` 即可。

`cc::Build` 的常用方法：

| 方法 | 说明 |
|------|------|
| `.file("path.c")` | 添加一个 C 源文件 |
| `.files(iter)` | 批量添加多个 C 源文件 |
| `.include("dir")` | 添加头文件搜索目录（等同 `-I`） |
| `.define("KEY", "VALUE")` | 添加预处理宏定义（等同 `-DKEY=VALUE`） |
| `.flag("-O2")` | 传递额外的编译器标志 |
| `.opt_level(2)` | 设置优化级别 |
| `.compile("name")` | 编译并生成 `libname.a`，同时自动发出链接指令 |

## 七、重运行条件与性能陷阱

### 7.1 默认行为：每次构建都重跑

这是新手最容易踩的坑：**如果 `build.rs` 没有任何 `cargo:rerun-if-changed` 指令，`Cargo` 默认在每次 `cargo build` 时都重新运行它**，不管任何文件是否发生变化。

对于简单的脚本，这只是几毫秒的开销，几乎感知不到。但如果 `build.rs` 执行了代码生成或 C 编译，每次改动任意 Rust 源码都会触发重跑，极大拖慢增量编译速度。

### 7.2 正确声明 rerun-if-changed

**一旦声明了哪怕一条 `cargo:rerun-if-changed`，Cargo 就会切换为"只在这些路径变化时才重跑"的模式**。因此声明必须覆盖所有真正会影响 `build.rs` 输出的文件。

常见场景的声明方式：

```rust
fn main() {
    // 场景 1：只注入版本信息，仅 Cargo.toml 变化时重跑
    println!("cargo:rerun-if-changed=Cargo.toml");

    // 场景 2：依赖 C 源文件，声明所有 .c 和 .h 文件
    println!("cargo:rerun-if-changed=c_src/add.c");
    println!("cargo:rerun-if-changed=c_src/math.h");

    // 场景 3：整个目录下任意文件变化都重跑（声明目录路径）
    println!("cargo:rerun-if-changed=c_src");

    // 场景 4：环境变量变化时重跑（如依赖 OPENSSL_DIR 路径）
    println!("cargo:rerun-if-env-changed=OPENSSL_DIR");

    // 场景 5：build.rs 自身变化时重跑（始终建议加上）
    println!("cargo:rerun-if-changed=build.rs");
}
```

> **一个常见误区**：把 `build.rs` 自身加入 `rerun-if-changed` 是好习惯，但声明目录时要小心——如果声明了 `src/`，任何 `.rs` 文件的修改都会触发重跑，相当于退回到"每次都重跑"的状态。只声明真正被 `build.rs` 读取的文件或目录。

## 八、常见陷阱

| 陷阱 | 说明与解决方案 |
|------|----------------|
| 写入 `OUT_DIR` 以外的路径 | `Cargo` 的沙箱机制会拒绝写入。所有生成文件必须放在 `env::var("OUT_DIR")` 指向的目录 |
| `build.rs` `panic` | 会导致整个 `cargo build` 失败。在处理环境变量和文件操作时做好错误处理，使用 `unwrap_or_else` 或 `?` 传播错误 |
| 普通 `println!` 不可见 | 非 `cargo:` 前缀的输出默认被丢弃，调试信息需用 `cargo:warning=` |
| 跨编译混用 `HOST` 和 `TARGET` | 探测目标平台特性时必须用 `CARGO_CFG_TARGET_OS`/`CARGO_CFG_TARGET_ARCH`，而非 `HOST` |
| 忘记 `rustc-check-cfg` | `Rust 1.80+` 对未声明的自定义 `cfg` 发出警告。每个 `cargo:rustc-cfg=X` 都要配套 `cargo::rustc-check-cfg=cfg(X)` |
| `build-dependencies` 与 `dependencies` 混淆 | `build.rs` 用到的 `crate`（如 `cc`）必须放在 `[build-dependencies]`，放在 `[dependencies]` 会导致类型不匹配的编译错误 |
| 没有声明 `rerun-if-changed` | 每次 `cargo build` 都会重跑，代码生成/C 编译场景下拖慢增量构建速度 |
