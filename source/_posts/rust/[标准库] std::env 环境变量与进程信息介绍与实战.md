---
title: "[标准库] std::env 环境变量与进程信息介绍与实战"
published: true
layout: post
date: 2026-05-28 10:00:00
permalink: /rust/std-env.html
tags:
  - 环境变量
  - 命令行参数
  - 跨平台
  - 进程信息
  - 配置加载
categories:
  - Rust
---

Rust 进程启动时，操作系统会将当前工作目录、命令行参数和环境变量一并传递给它。`std::env` 是读写这三类上下文的统一接口：读取 `DATABASE_URL` 做配置注入、解析命令行标志、查询可执行文件路径，都通过它完成。与 C 的全局 `environ` 指针相比，`std::env` 增加了错误处理和 `UTF-8` 校验，同时保留了返回 `OsString` 的 `_os` 系列函数，用于处理平台上可能存在非 `UTF-8` 字节的路径和变量值。

## 一、模块概览

`std::env` 自 `Rust 1.0.0` 起稳定，核心组件如下：

| 组件 | 类型 | 说明 |
|------|------|------|
| `var` / `var_os` | `fn` | 读取单个环境变量 |
| `vars` / `vars_os` | `fn` | 遍历所有环境变量 |
| `set_var` / `remove_var` | `fn` | 修改环境变量（`unsafe`，多线程下须注意） |
| `args` / `args_os` | `fn` | 读取命令行参数 |
| `current_dir` / `set_current_dir` | `fn` | 读写当前工作目录 |
| `current_exe` | `fn` | 获取当前可执行文件完整路径 |
| `home_dir` | `fn` | 获取当前用户 home 目录 |
| `temp_dir` | `fn` | 获取系统临时目录 |
| `split_paths` / `join_paths` | `fn` | 按平台规则拆分 / 拼接 `PATH` 格式字符串 |
| `Args` / `ArgsOs` | `struct` | 命令行参数迭代器 |
| `Vars` / `VarsOs` | `struct` | 环境变量键值对迭代器 |
| `VarError` | `enum` | `var()` 失败时的错误类型 |
| `JoinPathsError` | `struct` | `join_paths()` 失败时的错误类型 |
| `consts` | `mod` | 当前目标平台的编译期常量 |

## 二、环境变量读取

### 2.1 var 与 var_os

**语法：**

```rust
fn var<K: AsRef<OsStr>>(key: K) -> Result<String, VarError>
fn var_os<K: AsRef<OsStr>>(key: K) -> Option<OsString>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `key` | - | 环境变量名；区分大小写（`Windows` 上不区分） |

`VarError` 的两个变体：

| 取值 | 说明 |
|------|------|
| `NotPresent` | 变量不存在 |
| `NotUnicode(OsString)` | 变量存在但值不是合法 `UTF-8`；原始字节保存在 `OsString` 中 |

两个函数的核心区别是编码处理策略：`var` 强制将变量值转为 `UTF-8 String`，遇到非法字节时返回 `NotUnicode`；`var_os` 绕过编码校验直接返回 `Option<OsString>`，适合读取可能含非 `UTF-8` 字节的路径型变量（例如旧版 `Linux` 上 `locale` 配置不当的场景）。

```rust
use std::env;

fn main() {
    unsafe {
        env::set_var("APP_MODE", "production");
        env::set_var("APP_PORT", "8080");
    }

    match env::var("APP_MODE") {
        Ok(val) => println!("APP_MODE = {val}"),
        Err(e)  => println!("失败: {e}"),
    }

    // var_os 不做 UTF-8 校验，直接返回 OsString
    if let Some(port) = env::var_os("APP_PORT") {
        println!("APP_PORT = {:?}", port);
    }

    match env::var("NONEXISTENT_KEY") {
        Err(env::VarError::NotPresent) => println!("NONEXISTENT_KEY 不存在"),
        _ => {}
    }
}
```

运行结果：

```
APP_MODE = production
APP_PORT = "8080"
NONEXISTENT_KEY 不存在
```

### 2.2 vars 与 vars_os

**语法：**

```rust
fn vars() -> Vars
fn vars_os() -> VarsOs
```

`Vars` 实现 `Iterator<Item = (String, String)>`，`VarsOs` 实现 `Iterator<Item = (OsString, OsString)>`，两者均可直接接 `filter`、`map`、`collect` 等链式调用。遍历顺序由操作系统决定，不保证稳定。

```rust
use std::env;

fn main() {
    unsafe {
        env::set_var("MY_APP_DEBUG", "true");
        env::set_var("MY_APP_LOG", "info");
    }

    let mut app_vars: Vec<(String, String)> = env::vars()
        .filter(|(key, _)| key.starts_with("MY_APP_"))
        .collect();
    app_vars.sort_by_key(|(k, _)| k.clone());

    for (k, v) in &app_vars {
        println!("{k} = {v}");
    }
    println!("共找到 {} 个 MY_APP_ 前缀变量", app_vars.len());
}
```

运行结果：

```
MY_APP_DEBUG = true
MY_APP_LOG = info
共找到 2 个 MY_APP_ 前缀变量
```

## 三、环境变量修改

### 3.1 set_var

**语法：**

```rust
pub unsafe fn set_var<K: AsRef<OsStr>, V: AsRef<OsStr>>(key: K, value: V)
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `key` | - | 变量名；不能为空、不能含 `=` 或 `\0` |
| `value` | - | 变量值；不能含 `\0` |

`set_var` 在 `Rust 1.81.0` 中被标注为 `unsafe`，因为 `Unix` 的 `setenv` 不是线程安全的：若其他线程正在调用 `getenv`（包括标准库内部的 DNS 解析等操作），并发修改 `environ` 会触发数据竞争，属于未定义行为。`Windows` 上 `SetEnvironmentVariable` 是线程安全的，因此不受此限。

> 最佳实践：在任何额外线程启动前完成所有 `set_var` 调用；若只需为子进程注入变量，优先使用 `Command::env` 而非修改当前进程的全局环境。

### 3.2 remove_var

**语法：**

```rust
pub unsafe fn remove_var<K: AsRef<OsStr>>(key: K)
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `key` | - | 要删除的变量名；不能含 `=` 或 `\0` |

变量不存在时调用无效果，不会 `panic`。与 `set_var` 有相同的线程安全问题。

```rust
use std::env;

fn main() {
    unsafe {
        env::set_var("TEMP_TOKEN", "secret-123");
    }
    println!("设置后: {:?}", env::var("TEMP_TOKEN"));

    unsafe {
        env::remove_var("TEMP_TOKEN");
    }
    println!("删除后: {:?}", env::var("TEMP_TOKEN"));

    unsafe {
        env::remove_var("ALREADY_GONE");
    }
    println!("删除不存在的变量: OK");
}
```

运行结果：

```
设置后: Ok("secret-123")
删除后: Err(NotPresent)
删除不存在的变量: OK
```

## 四、命令行参数

### 4.1 args 与 args_os

**语法：**

```rust
fn args() -> Args
fn args_os() -> ArgsOs
```

`Args` 实现 `Iterator<Item = String>`，`ArgsOs` 实现 `Iterator<Item = OsString>`。两者的第 0 个元素均为程序名（对应 C 的 `argv[0]`），后续元素为用户传入的参数。

`args()` 对每个参数做 `UTF-8` 校验，含非法字节时 `panic`；`args_os()` 不校验，适合需要接受任意字节参数的工具（如处理旧文件名的 CLI 程序）。

```rust
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    let exe_name = std::path::Path::new(&args[0])
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown");
    println!("程序名: {exe_name}");
    println!("参数数量: {}", args.len() - 1);
    if args.len() == 1 {
        println!("（未传入参数）");
    }
}
```

运行结果（`cargo run`，无额外参数）：

```
程序名: base-rust
参数数量: 0
（未传入参数）
```

> `args[0]`（程序名）的格式因平台和调用方式而异：直接执行二进制文件时通常是完整路径，通过 `exec` 族函数启动时可以是任意字符串，不应用于安全判断。

## 五、文件系统路径查询

### 5.1 current_dir 与 set_current_dir

**语法：**

```rust
fn current_dir() -> io::Result<PathBuf>
fn set_current_dir<P: AsRef<Path>>(path: P) -> io::Result<()>
```

`current_dir` 读取进程的当前工作目录（`CWD`），`set_current_dir` 修改它。`CWD` 是整个进程的全局状态，修改后所有使用相对路径的系统调用行为随即改变。

> 在多线程程序中，`set_current_dir` 本身是合法的，但变更 `CWD` 会立即影响其他线程的相对路径解析，是难以追踪的竞态根源。建议程序启动后固定 `CWD`，或始终使用绝对路径。

```rust
use std::env;

fn main() {
    let original = env::current_dir().unwrap();
    println!("当前目录: {}", original.display());

    let tmp = env::temp_dir();
    env::set_current_dir(&tmp).unwrap();
    println!("切换后: {}", env::current_dir().unwrap().display());

    env::set_current_dir(&original).unwrap();
    println!("恢复后: {}", env::current_dir().unwrap().display());
}
```

运行结果：

```
当前目录: /home/duwei/workspace/rust/base-rust
切换后: /tmp
恢复后: /home/duwei/workspace/rust/base-rust
```

### 5.2 current_exe

**语法：**

```rust
fn current_exe() -> io::Result<PathBuf>
```

返回当前进程可执行文件的完整绝对路径，符号链接已解析为真实路径。常见用途是定位与可执行文件同目录的资源文件（配置、模板、插件）。底层实现因平台而异：`Linux` 读取 `/proc/self/exe`，`macOS` 调用 `_NSGetExecutablePath`，`Windows` 调用 `GetModuleFileName`。

```rust
use std::env;

fn main() {
    match env::current_exe() {
        Ok(exe) => {
            println!("可执行文件: {}", exe.display());
            println!("文件名: {}", exe.file_name().unwrap().to_string_lossy());
            println!("所在目录: {}", exe.parent().unwrap().display());
        }
        Err(e) => println!("获取失败: {e}"),
    }
}
```

运行结果：

```
可执行文件: /home/duwei/workspace/rust/base-rust/target/debug/base-rust
文件名: base-rust
所在目录: /home/duwei/workspace/rust/base-rust/target/debug
```

### 5.3 home_dir 与 temp_dir

**语法：**

```rust
fn home_dir() -> Option<PathBuf>
fn temp_dir() -> PathBuf
```

| 函数 | `Linux` 实现 | `macOS` 实现 | `Windows` 实现 |
|------|------------|------------|--------------|
| `home_dir` | 优先读 `HOME` 环境变量，回退 `passwd` 条目 | 同 `Linux` | `USERPROFILE` 或 `HOMEPATH` |
| `temp_dir` | 优先读 `TMPDIR`，默认 `/tmp` | 优先读 `TMPDIR`，默认 `/tmp` | `GetTempPath` API |

`home_dir` 返回 `Option` 而非 `Result`，因为在容器或最小化环境中 home 目录可能确实不存在。`temp_dir` 始终返回路径，但不保证该路径存在或可写，必要时应在写入前自行检查。

```rust
use std::env;

fn main() {
    match env::home_dir() {
        Some(home) => println!("Home 目录: {}", home.display()),
        None       => println!("Home 目录未定义"),
    }

    let tmp = env::temp_dir();
    println!("临时目录: {}", tmp.display());
    println!("临时目录存在: {}", tmp.exists());
}
```

运行结果：

```
Home 目录: /home/duwei
临时目录: /tmp
临时目录存在: true
```

## 六、PATH 字符串操作

### 6.1 split_paths

**语法：**

```rust
fn split_paths<T: AsRef<OsStr>>(input: T) -> SplitPaths<'_>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `input` | - | `PATH` 格式字符串；`Unix` 以 `:` 分隔，`Windows` 以 `;` 分隔 |

`split_paths` 比直接调用 `str::split(':')` 更健壮：`Windows` 路径中可能含 `;`，此时需要引号包裹，`split_paths` 会正确解析引号转义规则，而 `str::split` 会错误地截断路径。返回的 `SplitPaths` 是惰性迭代器，每个元素为 `PathBuf`。

```rust
use std::env;

fn main() {
    let path_str = "/usr/local/bin:/usr/bin:/bin";
    let paths: Vec<_> = env::split_paths(path_str).collect();

    println!("PATH 共 {} 条目:", paths.len());
    for (i, p) in paths.iter().enumerate() {
        println!("  [{}] {}", i, p.display());
    }
}
```

运行结果：

```
PATH 共 3 条目:
  [0] /usr/local/bin
  [1] /usr/bin
  [2] /bin
```

### 6.2 join_paths

**语法：**

```rust
fn join_paths<I, T>(paths: I) -> Result<OsString, JoinPathsError>
where
    I: IntoIterator<Item = T>,
    T: AsRef<OsStr>,
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `paths` | - | 路径列表；各元素按平台规则拼接为 `PATH` 格式字符串 |

`join_paths` 是 `split_paths` 的逆操作。若某个路径含有平台分隔符（`Unix` 的 `:`，`Windows` 的 `;`）且无法转义，则返回 `JoinPathsError`。常见用法是读取当前 `PATH`、头部插入新路径、再写回：

```rust
use std::env;

fn main() {
    let original = "/usr/local/bin:/usr/bin:/bin";
    let mut paths: Vec<_> = env::split_paths(original).collect();
    paths.insert(0, "/opt/myapp/bin".into());

    let new_path = env::join_paths(&paths).unwrap();
    println!("{}", new_path.to_string_lossy());
}
```

运行结果：

```
/opt/myapp/bin:/usr/local/bin:/usr/bin:/bin
```

## 七、平台常量：consts 子模块

`std::env::consts` 提供描述当前编译目标的常量，所有值在编译期确定，可用于条件逻辑和平台特定文件名构造。

| 常量 | 类型 | 说明 |
|------|------|------|
| `OS` | `&str` | 操作系统名称，如 `"linux"`、`"macos"`、`"windows"` |
| `ARCH` | `&str` | CPU 架构，如 `"x86_64"`、`"aarch64"`、`"riscv64"` |
| `FAMILY` | `&str` | OS 家族，如 `"unix"`、`"windows"` |
| `DLL_PREFIX` | `&str` | 动态库文件名前缀；`Unix` 为 `"lib"`，`Windows` 为 `""` |
| `DLL_SUFFIX` | `&str` | 动态库文件名后缀（含点），如 `".so"`、`".dylib"`、`".dll"` |
| `DLL_EXTENSION` | `&str` | 动态库扩展名（不含点），如 `"so"`、`"dylib"`、`"dll"` |
| `EXE_SUFFIX` | `&str` | 可执行文件后缀；`Windows` 为 `".exe"`，其他为 `""` |
| `EXE_EXTENSION` | `&str` | 可执行文件扩展名（不含点）；`Windows` 为 `"exe"`，其他为 `""` |

```rust
use std::env::consts;

fn main() {
    println!("OS:       {}", consts::OS);
    println!("Arch:     {}", consts::ARCH);
    println!("Family:   {}", consts::FAMILY);
    println!("DLL 后缀: {}", consts::DLL_SUFFIX);
    println!("DLL 前缀: {}", consts::DLL_PREFIX);
    println!("Exe 后缀: {:?}", consts::EXE_SUFFIX);
}
```

运行结果（`Linux x86_64`）：

```
OS:       linux
Arch:     x86_64
Family:   unix
DLL 后缀: .so
DLL 前缀: lib
Exe 后缀: ""
```

`consts` 的典型应用是构造跨平台兼容的库文件名：

```rust
use std::env::consts;

fn lib_name(base: &str) -> String {
    format!("{}{}{}", consts::DLL_PREFIX, base, consts::DLL_SUFFIX)
}
```

在 `Linux` 上调用 `lib_name("mylib")` 得 `"libmylib.so"`，`Windows` 上得 `"mylib.dll"`。

> `consts` 中的值反映的是**编译目标**，不是运行时主机。交叉编译时两者可能不同，不能用它判断当前运行的操作系统。

## 八、综合实战：环境驱动配置加载

以下示例综合使用 `var`、`set_var`、`current_dir`、`current_exe` 和 `consts`，实现从环境变量加载应用配置的完整流程，未设置的变量自动回退到默认值：

```rust
use std::env;
use std::env::consts;

struct AppConfig {
    host: String,
    port: u16,
    debug: bool,
    log_level: String,
}

impl AppConfig {
    fn from_env() -> Self {
        let host = env::var("APP_HOST").unwrap_or_else(|_| "127.0.0.1".to_string());
        let port = env::var("APP_PORT")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(3000u16);
        let debug = env::var("APP_DEBUG")
            .map(|v| v == "true" || v == "1")
            .unwrap_or(false);
        let log_level = env::var("APP_LOG_LEVEL").unwrap_or_else(|_| "info".to_string());

        Self { host, port, debug, log_level }
    }
}

fn main() {
    unsafe {
        env::set_var("APP_HOST", "0.0.0.0");
        env::set_var("APP_PORT", "8080");
        env::set_var("APP_DEBUG", "true");
        // APP_LOG_LEVEL 未设置，使用默认值 "info"
    }

    let cfg = AppConfig::from_env();

    println!("=== 应用配置 ===");
    println!("Host:      {}", cfg.host);
    println!("Port:      {}", cfg.port);
    println!("Debug:     {}", cfg.debug);
    println!("Log Level: {}", cfg.log_level);

    println!("\n=== 进程信息 ===");
    println!("工作目录: {}", env::current_dir().unwrap().display());
    let exe = env::current_exe().unwrap();
    println!("可执行文件: {}", exe.file_name().unwrap().to_string_lossy());
    println!("参数数量: {}", env::args().count() - 1);

    println!("\n=== 平台信息 ===");
    println!("OS: {} ({})", consts::OS, consts::FAMILY);
    println!("Arch: {}", consts::ARCH);
}
```

运行结果：

```
=== 应用配置 ===
Host:      0.0.0.0
Port:      8080
Debug:     true
Log Level: info

=== 进程信息 ===
工作目录: /home/duwei/workspace/rust/base-rust
可执行文件: base-rust
参数数量: 0

=== 平台信息 ===
OS: linux (unix)
Arch: x86_64
```
