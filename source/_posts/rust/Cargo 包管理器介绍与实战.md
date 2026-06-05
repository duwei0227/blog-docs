---
title: Cargo 包管理器介绍与实战
published: true
layout: post
date: 2026-05-20 10:00:00
permalink: /rust/cargo.html
tags:
  - Cargo
  - 包管理
  - 构建工具
categories:
  - Rust
---

每个 Rust 项目背后都有一个隐形的管家——`Cargo`。它不只是编译器的包装脚本，而是集依赖解析、构建系统、测试运行器、文档生成器、发布工具于一身的完整工作流平台。本文从项目创建到发布 `crates.io`，系统介绍 `Cargo` 的核心功能与常用命令。

## 一、Cargo 简介

`Cargo` 是 Rust 官方的包管理器与构建工具，随 `rustup` 安装时一并提供。它解决了三个核心问题：**依赖版本锁定**、**跨平台构建一致性**、**生态共享**（通过 `crates.io`）。

### 1.1 安装与版本验证

通过 `rustup` 安装 Rust 工具链后，`Cargo` 已自动就绪：

```bash
# 查看 Cargo 版本
cargo --version
```

输出结果：

```
cargo 1.87.0 (99624be96 2025-05-06)
```

### 1.2 核心概念

| 概念 | 说明 |
|------|------|
| `crate` | Rust 的编译单元，分为 `lib`（库）和 `bin`（可执行文件）两种类型 |
| `package` | 包含一个 `Cargo.toml` 的目录，可含多个 `crate` |
| `workspace` | 多个 `package` 共享同一个 `Cargo.lock` 和 `target` 目录的集合 |
| `Cargo.toml` | 项目清单文件，声明元数据、依赖与构建配置 |
| `Cargo.lock` | 依赖版本快照，由 `Cargo` 自动生成和维护 |
| `registry` | crate 发布的远程索引，默认为 `crates.io` |


## 二、项目创建

### 2.1 cargo new

**语法：**

```bash
cargo new [OPTIONS] <path>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `<path>` | - | 项目目录路径，同时作为包名 |
| `--bin` | 是 | 创建可执行二进制项目（默认） |
| `--lib` | - | 创建库项目，生成 `src/lib.rs` |
| `--name <name>` | - | 单独指定包名，与目录名解耦 |
| `--edition <year>` | `2024` | 指定 Rust Edition，可选 `2015`、`2018`、`2021`、`2024` |
| `--vcs <vcs>` | `git` | 版本控制系统；可选 `git`、`hg`、`none` |

```bash
# 创建二进制项目
cargo new hello_world

# 创建库项目
cargo new my_lib --lib

# 指定名称（目录名与包名不同）
cargo new ./projects/v2 --name my-app
```

`cargo new` 会自动生成 `.gitignore`（忽略 `target/`）并初始化 `git` 仓库。

### 2.2 cargo init

`cargo init` 与 `cargo new` 功能相同，区别在于它在**当前已存在的目录**中初始化项目，而不创建新目录：

```bash
mkdir my_project && cd my_project
cargo init --bin
```

### 2.3 项目结构

标准二进制项目的目录结构：

```
hello_world/
├── Cargo.toml       # 项目清单
├── Cargo.lock       # 依赖锁文件（自动生成）
├── src/
│   └── main.rs      # 二进制入口
├── tests/           # 集成测试目录（可选）
├── benches/         # 基准测试目录（可选）
├── examples/        # 示例程序目录（可选）
└── target/          # 构建输出目录（自动生成，.gitignore 忽略）
```

> 一个 `package` 可以同时包含 `src/main.rs`（`bin` crate）和 `src/lib.rs`（`lib` crate）。多个可执行文件放在 `src/bin/` 下，每个 `.rs` 文件对应一个独立的二进制目标。


## 三、Cargo.toml 结构详解

`Cargo.toml` 使用 `TOML` 格式，是 `Cargo` 一切行为的配置中心。

### 3.1 [package] 段

```toml
[package]
name = "hello_world"        # 包名，发布时作为 crate 名
version = "0.1.0"           # 语义化版本（SemVer）
edition = "2024"            # Rust Edition
authors = ["Alice <alice@example.com>"]
description = "A brief description"
license = "MIT OR Apache-2.0"
repository = "https://github.com/user/hello_world"
readme = "README.md"
keywords = ["cli", "tool"]  # 最多 5 个，用于 crates.io 搜索
categories = ["command-line-utilities"]
```

| 字段 | 是否必填 | 说明 |
|------|---------|------|
| `name` | 是 | 只能含字母、数字、`-`、`_` |
| `version` | 是 | 遵循 `SemVer`，格式为 `MAJOR.MINOR.PATCH` |
| `edition` | 否 | 不填默认为 `2015`，强烈建议显式声明 |
| `license` | 发布必填 | `SPDX` 表达式，如 `MIT`、`Apache-2.0` |

> **为什么 `edition` 默认是 `2015`？**
> Edition 系统在 Rust 2018 时才正式引入，此前的项目均无该字段。为保证老 `Cargo.toml` 在升级工具链后不发生破坏性编译失败（2018 引入了 `async`/`await` 关键字、模块路径解析等不兼容变更），Cargo 将缺省值设为 `2015` 作为向后兼容的兜底。`cargo new` 新建项目时默认写入当前最新 edition（目前为 `2024`），因此**新项目应始终显式声明 `edition = "2024"`**，避免无意间退回旧语义。

### 3.2 依赖段

```toml
[dependencies]          # 运行时依赖
serde = "1.0"

[dev-dependencies]      # 仅测试/示例时使用
pretty_assertions = "1"

[build-dependencies]    # 仅 build.rs 构建脚本使用
cc = "1.0"
```

### 3.3 版本规范语法

`Cargo` 使用语义化版本约束，常见写法如下：

| 写法 | 含义 | 等价范围 |
|------|------|---------|
| `"1.2.3"` | 精确兼容（`^1.2.3`） | `>=1.2.3, <2.0.0` |
| `"^1.2"` | 主版本兼容 | `>=1.2.0, <2.0.0` |
| `"~1.2.3"` | 补丁级兼容 | `>=1.2.3, <1.3.0` |
| `">=1.0, <2.0"` | 显式范围 | `>=1.0.0, <2.0.0` |
| `"*"` | 任意版本 | 最新稳定版 |

> `Cargo` 默认使用 `^` 语义——即只要不破坏主版本号的兼容性，就允许升级。对于 `0.x.y` 版本，`^0.3` 意为 `>=0.3.0, <0.4.0`（次版本号视为破坏性变更）。

### 3.4 特殊依赖来源

除 `crates.io` 外，`Cargo` 还支持 `Git` 仓库和本地路径依赖：

```toml
[dependencies]
# Git 仓库（指定分支）
my_lib = { git = "https://github.com/user/my_lib", branch = "main" }

# Git 仓库（指定 tag 或 commit）
my_lib = { git = "https://github.com/user/my_lib", tag = "v1.0.0" }

# 本地路径依赖（单体仓库或调试场景常用）
utils = { path = "../utils" }

# 启用可选 features
serde = { version = "1.0", features = ["derive"] }

# 可选依赖（需配合 features 使用）
serde_json = { version = "1.0", optional = true }
```


## 四、构建与运行

### 4.1 cargo build

**语法：**

```bash
cargo build [OPTIONS]
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--release` | - | 使用 `release` profile 编译，开启优化，去除调试信息 |
| `--target <triple>` | 宿主机 | 交叉编译目标，如 `x86_64-unknown-linux-musl` |
| `--bin <name>` | - | 只编译指定的二进制目标 |
| `--lib` | - | 只编译库目标 |
| `-p <pkg>` | - | 在 `workspace` 中只编译指定 `package` |

```bash
cargo build              # debug 构建，产物在 target/debug/
cargo build --release    # release 构建，产物在 target/release/
```

运行结果：

```
   Compiling base-rust v0.1.0 (/home/duwei/workspace/rust/base-rust)
    Finished `release` profile [optimized] target(s) in 0.06s
```

> `debug` 构建保留完整调试符号，编译速度快但运行慢；`release` 构建开启 `opt-level = 3`，运行快但编译慢。开发时始终用 `debug`，部署时切换到 `release`。

### 4.2 cargo run

```bash
cargo run [OPTIONS] [-- <args>...]
```

等同于先 `cargo build` 再运行产物，并将 `--` 之后的参数透传给程序：

```rust
fn main() {
    println!("Hello, Cargo!");
    println!("version: {}", env!("CARGO_PKG_VERSION"));
    println!("name: {}", env!("CARGO_PKG_NAME"));
}
```

```bash
cargo run
```

运行结果：

```
   Compiling base-rust v0.1.0 (/home/duwei/workspace/rust/base-rust)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.05s
     Running `target/debug/base-rust`
Hello, Cargo!
version: 0.1.0
name: base-rust
```

`src/bin/` 下有多个二进制目标时，使用 `--bin` 指定：

```bash
cargo run --bin server
cargo run --bin client -- --port 8080
```

### 4.3 cargo check

`cargo check` 只做类型检查和借用检查，**不生成可执行文件**，速度通常比完整编译快 3–10 倍，适合开发时的快速反馈循环：

```bash
cargo check
```

运行结果：

```
    Checking base-rust v0.1.0 (/home/duwei/workspace/rust/base-rust)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.02s
```

### 4.4 构建配置文件（Profiles）

`Profiles` 控制编译器优化级别、调试信息、`panic` 策略等行为。在 `Cargo.toml` 中自定义：

```toml
[profile.dev]
opt-level = 0          # 不优化，编译快
debug = true           # 保留调试信息
overflow-checks = true # 开启整数溢出检查

[profile.release]
opt-level = 3          # 最高优化
debug = false
lto = true             # 开启链接时优化（Link-Time Optimization）
codegen-units = 1      # 单码生成单元，进一步提升优化质量
panic = "abort"        # 出现 panic 直接 abort，减小二进制体积
strip = "symbols"      # 剥离符号表，进一步缩小产物

[profile.dev.package."*"]
opt-level = 2          # 对所有依赖开启优化，只有自身代码保持 debug 状态
```

内置 `profile` 一览：

| Profile | 触发命令 | `opt-level` 默认 | `debug` 默认 |
|---------|---------|----------------|-------------|
| `dev` | `cargo build` / `cargo run` | `0` | `true` |
| `release` | `cargo build --release` | `3` | `false` |
| `test` | `cargo test` | `0` | `true` |
| `bench` | `cargo bench` | `3` | `false` |

所有内置和自定义 `profile` 均支持以下配置项：

| 配置项 | 可选值 | `dev` 默认 | `release` 默认 | 说明与用途 |
|--------|--------|-----------|----------------|-----------|
| `opt-level` | `0` / `1` / `2` / `3` / `"s"` / `"z"` | `0` | `3` | 编译器优化等级。`0` = 不优化（编译最快）；`1` = 基础优化；`2` = 中等优化；`3` = 最高优化（运行最快）；`"s"` = 优化二进制体积；`"z"` = 进一步缩小体积（同时禁用循环向量化） |
| `debug` | `0`/`false` / `"line-tables-only"` / `"limited"` / `1` / `2`/`true`/`"full"` | `true`（等同 `2`） | `false`（等同 `0`） | 调试信息详细程度。`false` = 不含调试信息；`"line-tables-only"` = 仅行号表（最小调试信息，可用于 `panic` 回溯）；`"limited"` = 部分信息（含行号，无类型与变量）；`true`/`"full"` = 完整调试信息 |
| `split-debuginfo` | `"off"` / `"packed"` / `"unpacked"` | 平台相关 | 平台相关 | 控制调试信息是否从可执行文件中分离。`"off"` = 内嵌到产物；`"packed"` = 拆出到单独文件（如 `.dSYM`、`.pdb`）；`"unpacked"` = 拆出为多个对象文件（仅 macOS） |
| `strip` | `"none"` / `"debuginfo"` / `"symbols"` | `"none"` | `"none"` | 从产物中剥离信息。`"none"` = 不剥离；`"debuginfo"` = 仅剥离调试信息（保留符号表）；`"symbols"` = 剥离全部符号与调试信息（产物最小） |
| `debug-assertions` | `true` / `false` | `true` | `false` | 是否启用 `debug_assert!` 宏及标准库内部断言的运行时检查。关闭后相关断言被完全消除，不产生运行时开销 |
| `overflow-checks` | `true` / `false` | `true` | `false` | 是否开启整数算术溢出的运行时 `panic` 检测。关闭后溢出行为遵循二进制补码回绕（与 C 相同），性能略优但存在隐患 |
| `lto` | `false` / `"thin"` / `true`/`"fat"` / `"off"` | `false` | `false` | 链接时优化（LTO）策略。`false` = 仅在同一 crate 内做 ThinLTO；`"thin"` = 跨 crate ThinLTO（速度与质量均衡）；`true`/`"fat"` = 全量 LTO（优化质量最佳，编译最慢）；`"off"` = 完全禁用所有 LTO |
| `panic` | `"unwind"` / `"abort"` | `"unwind"` | `"unwind"` | `panic` 发生时的处理策略。`"unwind"` = 展开调用栈（支持 `catch_unwind` 恢复）；`"abort"` = 立即终止进程（减小二进制体积，不可恢复，适合嵌入式或体积敏感场景） |
| `incremental` | `true` / `false` | `true` | `false` | 是否开启增量编译。开启后仅重新编译变更部分，显著提升开发时迭代速度；关闭后全量编译，通常优化质量更高且产物更稳定 |
| `codegen-units` | 正整数 | `256` | `16` | 将 crate 拆分为多少个并行代码生成单元。值越大编译越快，但跨单元的内联优化机会越少；设为 `1` 时串行编译，优化质量最高，适合 `release` 最终构建 |
| `rpath` | `true` / `false` | `false` | `false` | 是否在产物中写入 `rpath`（运行时动态库搜索路径）。仅对链接动态库的 Unix 平台有意义，通常不建议开启以避免可移植性问题 |

> **自定义 profile 继承**：自定义 `profile` 须通过 `inherits` 字段指定继承基础，例如 `inherits = "release"`，否则 Cargo 会报错。未显式覆盖的选项均沿用父 `profile` 的值。
>
> ```toml
> [profile.release-lto]
> inherits = "release"
> lto = "fat"
> codegen-units = 1
> ```


## 五、依赖管理

### 5.1 cargo add / cargo remove

从 `Cargo 1.62` 起，`cargo add` 成为内置命令，无需手动编辑 `Cargo.toml`：

```bash
# 添加最新版本
cargo add serde

# 添加并启用 features
cargo add serde --features derive

# 添加指定版本
cargo add tokio@1.28 --features full

# 添加为开发依赖
cargo add --dev pretty_assertions

# 移除依赖
cargo remove serde
```

### 5.2 cargo update 与 Cargo.lock

`Cargo.lock` 将所有直接和间接依赖锁定到精确版本，确保团队成员和 `CI` 环境构建结果一致。

```bash
# 将所有依赖升级到符合版本约束的最新版
cargo update

# 只升级指定 crate
cargo update serde

# 升级到特定版本（会修改 Cargo.toml）
cargo add serde@1.0.197
```

> **库（`lib` crate）不应提交 `Cargo.lock`**，因为下游使用者会用自己的锁文件。**二进制项目（`bin` crate）应提交 `Cargo.lock`**，以保证可重复构建。

### 5.3 cargo tree

可视化展示依赖树，快速排查重复依赖或版本冲突：

```bash
cargo tree
```

运行结果：

```
base-rust v0.1.0 (/home/duwei/workspace/rust/base-rust)
```

实际有依赖时的典型输出：

```
my_app v0.1.0
├── serde v1.0.197
│   └── serde_derive v1.0.197 (proc-macro)
├── tokio v1.37.0
│   ├── bytes v1.6.0
│   └── mio v0.8.11
└── reqwest v0.12.3
    ├── hyper v1.3.1
    └── ...
```

```bash
# 只显示重复出现的 crate
cargo tree --duplicates

# 查看某个 crate 被哪些依赖引入
cargo tree --invert serde
```


## 六、测试

### 6.1 单元测试

单元测试写在源文件内，用 `#[cfg(test)]` 模块隔离，可访问私有函数：

```rust
fn add(a: i32, b: i32) -> i32 {
    a + b
}

fn is_even(n: i32) -> bool {
    n % 2 == 0
}

fn main() {
    println!("add(3, 4) = {}", add(3, 4));
    println!("is_even(6) = {}", is_even(6));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        assert_eq!(add(2, 3), 5);
        assert_eq!(add(-1, 1), 0);
    }

    #[test]
    fn test_is_even() {
        assert!(is_even(4));
        assert!(!is_even(7));
    }
}
```

```bash
cargo test
```

运行结果：

```
   Compiling base-rust v0.1.0 (/home/duwei/workspace/rust/base-rust)
    Finished `test` profile [unoptimized + debuginfo] target(s) in 0.06s
     Running unittests src/main.rs (target/debug/deps/base_rust-b65e63a635fc6ae0)

running 2 tests
test tests::test_add ... ok
test tests::test_is_even ... ok

test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

### 6.2 cargo test 常用参数

| 参数 | 说明 |
|------|------|
| `cargo test <name>` | 只运行名称包含 `<name>` 的测试 |
| `cargo test -- --nocapture` | 显示测试中的 `println!` 输出 |
| `cargo test -- --test-threads=1` | 单线程运行测试，避免并发干扰 |
| `cargo test --lib` | 只运行 `lib` crate 的单元测试 |
| `cargo test --test <filename>` | 只运行 `tests/` 目录下指定的集成测试文件 |
| `cargo test --doc` | 只运行文档测试 |

### 6.3 集成测试

集成测试放在 `tests/` 目录，每个文件是独立的 `crate`，只能访问库的公开 `API`：

```rust
// tests/integration_test.rs
use my_lib::add;

#[test]
fn test_add_from_outside() {
    assert_eq!(add(10, 20), 30);
}
```

### 6.4 文档测试

文档注释中的代码块会被 `cargo test --doc` 自动执行，确保文档示例始终有效：

```rust
/// 将两个整数相加。
///
/// # Examples
///
/// ```
/// let result = my_lib::add(2, 3);
/// assert_eq!(result, 5);
/// ```
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
```


## 七、工作空间（Workspace）

当项目拆分为多个相互依赖的 `crate` 时，`Workspace` 让它们共享同一个 `Cargo.lock` 和 `target/` 目录，避免重复编译依赖。

### 7.1 创建工作空间

根目录的 `Cargo.toml` 只声明 `[workspace]`，不含 `[package]`：

```toml
# workspace/Cargo.toml（根清单）
[workspace]
resolver = "2"
members = [
    "crates/core",
    "crates/cli",
    "crates/server",
]
```

成员 `crate` 的结构：

```
workspace/
├── Cargo.toml          # 根清单（只有 [workspace]）
├── Cargo.lock          # 整个 workspace 共享
├── target/             # 整个 workspace 共享
├── crates/
│   ├── core/
│   │   ├── Cargo.toml
│   │   └── src/lib.rs
│   ├── cli/
│   │   ├── Cargo.toml
│   │   └── src/main.rs
│   └── server/
│       ├── Cargo.toml
│       └── src/main.rs
```

### 7.2 成员间依赖与共享依赖

成员 `crate` 互相依赖时使用路径依赖：

```toml
# crates/cli/Cargo.toml
[dependencies]
core = { path = "../core" }
```

从 `Cargo 1.64` 起，可在根清单中用 `[workspace.dependencies]` 统一管理版本，避免各成员各自声明版本不一致：

```toml
# workspace/Cargo.toml
[workspace.dependencies]
serde = { version = "1.0", features = ["derive"] }
tokio = { version = "1", features = ["full"] }
```

成员中只需继承，无需重复填写版本：

```toml
# crates/server/Cargo.toml
[dependencies]
serde = { workspace = true }
tokio = { workspace = true }
```

在 `workspace` 根目录运行命令时，默认作用于所有成员；用 `-p` 指定单个：

```bash
cargo build              # 构建所有成员
cargo test -p core       # 只测试 core crate
cargo run -p cli         # 只运行 cli
```

### 7.3 根清单完整配置说明

workspace 根 `Cargo.toml` 支持以下顶层表，各自职责独立：

#### `[workspace]` — 核心声明

| 字段 | 类型 | 是否必填 | 说明 |
|------|------|---------|------|
| `members` | 字符串数组 | 是 | 成员包路径列表，支持 glob（如 `"crates/*"`）。Cargo 按此列表发现并管理所有成员 |
| `exclude` | 字符串数组 | 否 | 从 `members` glob 匹配结果中排除的路径，精确匹配，不支持 glob |
| `default-members` | 字符串数组 | 否 | 未指定 `-p` 时默认操作的成员子集；不填则默认作用于所有成员 |
| `resolver` | `"1"` / `"2"` | 否 | 依赖解析器版本。`"2"` 支持更精细的 feature 独立解析，edition 2021+ 项目默认为 `"2"`，强烈建议显式声明 |

```toml
[workspace]
resolver = "2"
members = ["crates/*", "tools/cli"]
exclude = ["crates/experimental"]
default-members = ["crates/core", "tools/cli"]
```

#### `[workspace.package]` — 共享包元数据（Cargo 1.64+）

在根清单统一声明后，成员通过 `key.workspace = true` 继承，避免重复维护。

| 可继承字段 | 说明 |
|-----------|------|
| `version` | 语义化版本号 |
| `authors` | 作者列表 |
| `edition` | Rust Edition |
| `rust-version` | 最低支持的 Rust 版本（MSRV） |
| `description` | 包描述 |
| `documentation` | 文档 URL |
| `readme` | README 文件路径 |
| `homepage` | 主页 URL |
| `repository` | 仓库 URL |
| `license` | SPDX 许可证表达式 |
| `license-file` | 许可证文件路径 |
| `keywords` | 关键词列表（最多 5 个） |
| `categories` | crates.io 分类列表 |
| `publish` | 是否允许发布到 crates.io |
| `exclude` / `include` | 打包时的文件过滤规则 |

```toml
# workspace/Cargo.toml
[workspace.package]
version = "1.0.0"
edition = "2024"
authors = ["Alice <alice@example.com>"]
license = "MIT OR Apache-2.0"
repository = "https://github.com/user/my-workspace"
rust-version = "1.85"
```

```toml
# crates/core/Cargo.toml
[package]
name = "core"
version.workspace = true
edition.workspace = true
authors.workspace = true
license.workspace = true
```

#### `[workspace.dependencies]` — 共享依赖版本（Cargo 1.64+）

在根清单统一锁定版本，成员通过 `dep = { workspace = true }` 继承，可在继承时追加额外 `features`，但不能覆盖 `version`。

```toml
# workspace/Cargo.toml
[workspace.dependencies]
serde       = { version = "1.0", features = ["derive"] }
tokio       = { version = "1", features = ["rt-multi-thread"] }
tracing     = "0.1"
anyhow      = "1"
```

```toml
# crates/server/Cargo.toml
[dependencies]
serde   = { workspace = true }
tokio   = { workspace = true, features = ["net"] }   # 追加 features
tracing = { workspace = true }

[dev-dependencies]
anyhow = { workspace = true }
```

#### `[workspace.lints]` — 共享 lint 配置（Cargo 1.73+）

在根清单统一设置 lint 级别，成员通过 `[lints] workspace = true` 继承。

| 子表 | 说明 |
|------|------|
| `[workspace.lints.rust]` | 标准 `rustc` lint |
| `[workspace.lints.clippy]` | Clippy lint |
| `[workspace.lints.rustdoc]` | rustdoc lint |

```toml
# workspace/Cargo.toml
[workspace.lints.rust]
unsafe_code     = "forbid"
missing_docs    = "warn"

[workspace.lints.clippy]
unwrap_used     = "warn"
pedantic        = "warn"
```

```toml
# crates/core/Cargo.toml
[lints]
workspace = true
```

#### `[workspace.metadata]` — 工具自定义元数据

Cargo 完全忽略此表，可供外部工具（CI 脚本、构建系统、IDE 插件等）存储 workspace 级别的配置，结构自由定义。

```toml
[workspace.metadata.release]
pre-release-commit-message = "chore: release {{version}}"
tag-message = "Release {{version}}"

[workspace.metadata.docs]
default-target = "x86_64-unknown-linux-gnu"
```

#### `[profile.*]` — 构建配置（workspace 共享）

定义在根清单的 `[profile.*]` 自动对所有成员生效，成员自身的 `Cargo.toml` **不能**覆盖 profile（会被忽略）。详见 [4.4 构建配置文件](#44-构建配置文件profiles)。


## 八、特性（Features）

`Features` 是一套条件编译机制，允许用户按需启用可选功能，避免将不必要的依赖引入编译结果。

### 8.1 声明特性

`[features]` 表中每一行的格式为 `feature名 = [依赖列表]`，列表元素有三种形式：

| 元素形式 | 含义 |
|---------|------|
| `"other-feature"` | 启用同一 crate 内的另一个 feature |
| `"dep:pkg"` | 启用名为 `pkg` 的可选依赖（不暴露同名 feature） |
| `"pkg/feat"` | 启用依赖 `pkg` 的子 feature，同时也会引入该依赖 |
| `"pkg?/feat"` | 仅当 `pkg` 已被其他途径启用时，才为其追加子 feature（弱依赖语法，Cargo 1.60+） |

#### 纯标志 feature

最简单的形式，不关联任何依赖，仅作为条件编译开关：

```toml
[features]
logging = []
metrics = []
```

#### `default` feature

名为 `default` 的 feature 在未指定 `--no-default-features` 时自动启用。它的值是一个普通的 feature 列表：

```toml
[features]
default = ["logging"]   # 默认启用 logging，不启用 metrics
logging = []
metrics = []
```

> 下游使用者可通过 `default-features = false` 关闭所有默认 feature，再按需手动指定：
> ```toml
> [dependencies]
> my-lib = { version = "1.0", default-features = false, features = ["metrics"] }
> ```

#### 可选依赖与 `dep:` 前缀

将依赖标记为 `optional = true` 后，可在 `[features]` 中通过 `dep:` 前缀显式引入。`dep:` 语法（Cargo 1.60+）可避免自动生成与依赖同名的隐式 feature，从而自由命名：

```toml
[dependencies]
serde_json = { version = "1.0", optional = true }
ravif       = { version = "0.6", optional = true }
rgb         = { version = "0.8", optional = true }

[features]
json-support = ["dep:serde_json"]   # 自定义名称，不暴露 serde_json feature
avif         = ["dep:ravif", "dep:rgb"]  # 一个 feature 聚合多个可选依赖
```

> 若不加 `dep:` 前缀直接写 `"serde_json"`，Cargo 会把该可选依赖当作同名 feature 来启用，等价于旧式写法。推荐始终使用 `dep:` 以保持语义清晰。

#### 启用依赖的子 feature（`pkg/feat` 语法）

激活某个 feature 时，顺带启用其依赖的指定子 feature：

```toml
[dependencies]
serde = { version = "1.0", optional = true }

[features]
serde = ["dep:serde", "serde/derive"]   # 启用 serde 并同时开启其 derive feature
```

#### 弱依赖 feature（`pkg?/feat` 语法，Cargo 1.60+）

`?` 语法表示"如果该可选依赖已被启用，则为其追加子 feature；否则什么都不做"。常用于避免无意间将可选依赖变为强依赖：

```toml
[dependencies]
serde = { version = "1.0", optional = true }
rgb   = { version = "0.8", optional = true }

[features]
serde = ["dep:serde", "rgb?/serde"]
# 启用 serde feature 时：
#   - 引入 serde 依赖
#   - 若 rgb 已被其他 feature 启用，则也为 rgb 开启 serde 支持
#   - 若 rgb 未被启用，rgb?/serde 被忽略，不会强制引入 rgb
```

#### feature 聚合与完整示例

```toml
[dependencies]
serde      = { version = "1.0", optional = true }
serde_json = { version = "1.0", optional = true }
tracing    = { version = "0.1", optional = true }

[features]
default      = ["logging"]
logging      = ["dep:tracing"]
serde-support = ["dep:serde", "serde/derive"]
json-support  = ["serde-support", "dep:serde_json"]  # 依赖另一个 feature
full          = ["logging", "json-support"]           # 聚合所有可选功能
```

> **可加性原则**：feature 必须是可加的——启用一个 feature 只能增加功能，绝不能破坏已有功能。互斥 feature（如 `backend-a` 与 `backend-b` 不能同时开启）在 Cargo 层面无法强制约束，只能在代码中用 `compile_error!` 主动报错：
> ```rust
> #[cfg(all(feature = "backend-a", feature = "backend-b"))]
> compile_error!("feature \"backend-a\" and \"backend-b\" cannot be enabled at the same time");
> ```

### 8.2 条件编译

在代码中通过 `#[cfg(feature = "...")]` 按 `feature` 开关代码块：

```rust
fn process(data: &str) -> String {
    #[cfg(feature = "logging")]
    println!("[LOG] processing: {}", data);

    format!("result: {}", data.to_uppercase())
}

fn main() {
    let r = process("hello cargo");
    println!("{}", r);
}
```

不启用 `logging` feature 时：

```bash
cargo run
```

运行结果：

```
result: HELLO CARGO
```

启用 `logging` feature 时：

```bash
cargo run --features logging
```

运行结果：

```
[LOG] processing: hello cargo
result: HELLO CARGO
```

### 8.3 Features 使用建议

| 场景 | 建议 |
|------|------|
| 重型可选依赖（如 `tokio`、`serde`） | 封装为可选 `feature`，减小最小构建体积 |
| 跨平台差异实现 | 用 `#[cfg(target_os = "linux")]` 而非 `feature` |
| 默认行为 | 放入 `default = [...]`，用户可通过 `default-features = false` 关闭 |
| 聚合多个 feature | 提供 `full` feature 方便一次性开启所有功能 |


## 九、常用工具命令

### 9.1 代码质量

```bash
# 格式化代码（依赖 rustfmt）
cargo fmt

# 静态分析，给出更严格的建议（依赖 clippy）
cargo clippy

# 修复编译器警告（自动应用建议）
cargo fix
```

### 9.2 文档

```bash
# 生成并在浏览器中打开文档
cargo doc --open

# 同时为依赖生成文档
cargo doc --open --no-deps
```

### 9.3 供应商（Vendor）与离线构建

在网络受限环境中，可将所有依赖源码下载到本地 `vendor/` 目录：

```bash
cargo vendor
```

随后在 `.cargo/config.toml` 中声明使用本地源：

```toml
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
```

之后所有 `cargo` 命令均不再需要网络访问。

### 9.4 常用命令速查

| 命令 | 说明 |
|------|------|
| `cargo new <name>` | 创建新项目 |
| `cargo build` | debug 构建 |
| `cargo build --release` | release 构建 |
| `cargo run` | 构建并运行 |
| `cargo check` | 快速类型检查，不生成产物 |
| `cargo test` | 运行所有测试 |
| `cargo doc --open` | 生成并浏览文档 |
| `cargo add <crate>` | 添加依赖 |
| `cargo remove <crate>` | 移除依赖 |
| `cargo update` | 升级依赖到最新兼容版本 |
| `cargo tree` | 查看依赖树 |
| `cargo fmt` | 格式化代码 |
| `cargo clippy` | 静态分析 |
| `cargo clean` | 清除 `target/` 目录 |
| `cargo publish` | 发布到 `crates.io` |


## 十、发布到 crates.io

### 10.1 发布前准备

发布前 `Cargo.toml` 中以下字段为必填：

```toml
[package]
name = "my_unique_crate"
version = "0.1.0"
edition = "2024"
description = "A short description of what this crate does"
license = "MIT OR Apache-2.0"
repository = "https://github.com/user/my_unique_crate"
```

用 `cargo package` 预检打包内容，确认哪些文件会被上传：

```bash
cargo package --list
```

### 10.2 登录与发布

在 `crates.io` 注册账号后，生成 `API token` 并登录：

```bash
cargo login <your_api_token>
```

正式发布：

```bash
cargo publish
```

发布后版本不可删除，只能用 `cargo yank` 撤销（阻止新项目依赖该版本，不影响已锁定的项目）：

```bash
# 撤销版本（不删除，仅标记）
cargo yank --version 0.1.0

# 取消撤销
cargo yank --version 0.1.0 --undo
```

> 每次发布前记得更新 `version` 字段，`crates.io` 不允许覆盖已发布的版本号。
