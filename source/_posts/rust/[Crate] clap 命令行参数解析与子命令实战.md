---
title: clap 命令行参数解析与子命令实战
published: true
layout: post
date: 2026-06-16 09:00:00
permalink: /rust/clap.html
tags:
  - clap
  - 命令行
  - 参数解析
categories: Rust
---

编写命令行工具时，绕不开「解析参数」这件事。如果只用 `std::env::args()` 手动处理，要自己判断哪些是位置参数、哪些是选项、还要校验类型、生成帮助信息、处理 `--help` 和 `--version`，代码很快就会被这些样板逻辑淹没。`clap`（Command Line Argument Parser）是 Rust 生态事实标准的参数解析库，它把这些工作全部交给声明式的 `derive` 宏：你只需用一个 `struct` 描述「想要什么参数」，`clap` 自动完成解析、类型转换、校验、帮助生成。本文基于 `clap 4.x` 的 `derive` API，覆盖命令行开发的主要功能。

## 一、安装与依赖

在 `Cargo.toml` 中添加依赖，并按需开启 feature：

```toml
[dependencies]
clap = { version = "4", features = ["derive", "env"] }
```

`clap` 的功能按 feature 拆分，常用的有：

| feature | 默认开启 | 作用 |
|---------|---------|------|
| `std` | ✅ | 标准库支持，几乎总是需要 |
| `derive` | ❌ | 启用 `#[derive(Parser)]` 等派生宏，声明式 API 的核心 |
| `env` | ❌ | 允许参数从环境变量读取默认值（`#[arg(env = "...")]`） |
| `cargo` | ❌ | 启用 `command!()` 宏，从 `Cargo.toml` 自动读取包名、版本、作者 |
| `unicode` | ❌ | 正确处理非 ASCII 字符的对齐宽度 |
| `wrap_help` | ❌ | 根据终端宽度自动折行帮助文本 |

> `derive` 不是默认 feature，必须显式开启，否则 `#[derive(Parser)]` 无法使用。这是新手最常踩的坑。

## 二、derive API 快速上手

`clap` 的 `derive` API 围绕三个核心派生宏：`Parser`（顶层命令）、`Subcommand`（子命令枚举）、`Args`（可复用参数组）。最简单的程序只需一个 `#[derive(Parser)]` 的 `struct`，再调用 `Cli::parse()`：

```rust
use clap::Parser;

/// 一个简单的问候工具
#[derive(Parser)]
#[command(name = "greet", version = "1.0", about = "一个简单的问候工具")]
struct Cli {
    /// 要问候的名字
    name: String,

    /// 重复次数
    #[arg(short, long, default_value_t = 1)]
    count: u8,
}

fn main() {
    let cli = Cli::parse();
    for _ in 0..cli.count {
        println!("Hello, {}!", cli.name);
    }
}
```

字段上的 `///` 文档注释会自动成为该参数的帮助说明，`#[command(...)]` 描述命令本身的元信息。运行：

```bash
$ greet Alice --count 3
```

运行结果：

```
Hello, Alice!
Hello, Alice!
Hello, Alice!
```

`clap` 自动为程序生成了 `--help` 和 `--version`，无需手写：

```bash
$ greet --help
```

运行结果：

```
一个简单的问候工具

Usage: greet [OPTIONS] <NAME>

Arguments:
  <NAME>  要问候的名字

Options:
  -c, --count <COUNT>  重复次数 [default: 1]
  -h, --help           Print help
  -V, --version        Print version
```

```bash
$ greet --version
```

运行结果：

```
greet 1.0
```

> `--version` 显示的程序名来自 `#[command(name = "...")]`，而 `Usage:` 行显示的程序名取自实际的可执行文件名。本文示例均把二者取成一致，以便对照。

## 三、参数类型

`clap` 的核心能力是把不同形态的命令行输入映射到 `struct` 字段。`derive` 会根据字段类型自动推断「动作」（`ArgAction`）：`bool` 映射为标志，`Option<T>` 映射为可选值，`Vec<T>` 映射为可重复多值，普通 `T` 映射为必填单值。下面逐一展开。

### 3.1 位置参数

不加任何 `#[arg(...)]` 属性的字段就是位置参数，按声明顺序依次匹配命令行中的非选项词：

```rust
use clap::Parser;

#[derive(Parser)]
struct Cli {
    /// 源文件路径
    source: String,
    /// 目标文件路径
    dest: String,
}

fn main() {
    let cli = Cli::parse();
    println!("source = {}", cli.source);
    println!("dest   = {}", cli.dest);
}
```

```bash
$ cp-tool a.txt b.txt
```

运行结果：

```
source = a.txt
dest   = b.txt
```

### 3.2 选项参数

**语法：**

```rust
#[arg(short, long)]
field: String
```

**参数：**

| 属性 | 默认值 | 说明 |
|------|--------|------|
| `short` | 无 | 生成短选项，取字段名首字母（如 `output` → `-o`）；也可写 `short = 'x'` 指定字符 |
| `long` | 无 | 生成长选项，取字段名的 kebab-case（如 `max_size` → `--max-size`）；也可写 `long = "name"` 指定名称 |

选项参数通过 `-o value` 或 `--output value` 显式指定，与位置无关：

```rust
use clap::Parser;

#[derive(Parser)]
struct Cli {
    /// 输出文件
    #[arg(short, long)]
    output: String,
}

fn main() {
    let cli = Cli::parse();
    println!("output = {}", cli.output);
}
```

`--output result.txt` 与 `-o result.txt` 等价：

```bash
$ tool --output result.txt
$ tool -o result.txt
```

运行结果：

```
output = result.txt
```

### 3.3 布尔标志

字段类型为 `bool` 时，`derive` 自动采用 `SetTrue` 动作：参数出现即为 `true`，不出现为 `false`，无需也不能跟值：

```rust
use clap::Parser;

#[derive(Parser)]
struct Cli {
    /// 启用详细模式
    #[arg(short, long)]
    verbose: bool,
}

fn main() {
    let cli = Cli::parse();
    println!("verbose = {}", cli.verbose);
}
```

```bash
$ tool --verbose
verbose = true

$ tool
verbose = false
```

### 3.4 计数标志

把动作显式设为 `ArgAction::Count`，字段用整数类型，`clap` 会统计该标志出现的次数。这是实现 `-v`、`-vv`、`-vvv` 这类「越多越详细」语义的标准做法：

```rust
use clap::Parser;

#[derive(Parser)]
struct Cli {
    /// 详细级别，可重复指定 -v
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,
}

fn main() {
    let cli = Cli::parse();
    println!("verbose level = {}", cli.verbose);
}
```

```bash
$ tool -vvv
```

运行结果：

```
verbose level = 3
```

`ArgAction` 决定参数被匹配时如何更新存储值，常用取值如下：

| `ArgAction` 取值 | 适用字段类型 | 说明 |
|------------------|------------|------|
| `Set` | `T` / `Option<T>` | 存储单个值，重复出现时后者覆盖前者（普通值的默认动作） |
| `Append` | `Vec<T>` | 追加值，支持多次出现（`Vec` 的默认动作） |
| `SetTrue` | `bool` | 出现即置为 `true`（`bool` 的默认动作） |
| `SetFalse` | `bool` | 出现即置为 `false` |
| `Count` | 整数 | 统计出现次数 |
| `Help` | - | 打印帮助并退出 |
| `Version` | - | 打印版本并退出 |

### 3.5 多值参数

字段类型为 `Vec<T>` 时，`derive` 自动采用 `Append` 动作：每次出现都把值追加进 `Vec`，从而支持同一选项重复指定。这与 `Set` 的「后者覆盖前者」相反——选 `Append` 是因为多值场景（如多个包含目录）需要保留全部输入而非只留最后一个：

```rust
use clap::Parser;

#[derive(Parser)]
struct Cli {
    /// 可指定多个包含路径
    #[arg(short = 'I', long = "include")]
    includes: Vec<String>,
}

fn main() {
    let cli = Cli::parse();
    println!("includes = {:?}", cli.includes);
}
```

```bash
$ cc -I src -I lib --include vendor
```

运行结果：

```
includes = ["src", "lib", "vendor"]
```

### 3.6 可选与必填

普通字段 `T` 是**必填**的，缺失时 `clap` 会报错退出；包成 `Option<T>` 则变为**可选**，缺失时为 `None`。这一区别完全由类型表达，不需要额外属性：

```rust
use clap::Parser;

#[derive(Parser)]
struct Cli {
    /// 必填：用户名
    #[arg(short, long)]
    user: String,
    /// 可选：邮箱
    #[arg(short, long)]
    email: Option<String>,
}

fn main() {
    let cli = Cli::parse();
    println!("user  = {}", cli.user);
    match cli.email {
        Some(e) => println!("email = {}", e),
        None => println!("email = (未提供)"),
    }
}
```

```bash
$ tool --user bob
user  = bob
email = (未提供)

$ tool --user bob --email bob@example.com
user  = bob
email = bob@example.com
```

## 四、默认值与环境变量

`default_value_t` 为参数提供默认值（类型与字段一致），`env` 允许从环境变量读取。三者存在明确的优先级：**命令行显式值 > 环境变量 > 默认值**。这样设计是为了让用户既能用环境变量做全局配置，又能在单次调用时用命令行临时覆盖：

**语法：**

```rust
#[arg(short, long, env = "APP_PORT", default_value_t = 8080)]
port: u16
```

**参数：**

| 属性 | 默认值 | 说明 |
|------|--------|------|
| `default_value_t` | 无 | 类型化默认值，值的类型必须与字段一致（如 `u16` 写 `8080`） |
| `default_value` | 无 | 字符串形式的默认值（如 `default_value = "8080"`），会经 `value_parser` 解析 |
| `env` | 无 | 关联环境变量名，需开启 `env` feature；命令行未提供时回退到该环境变量 |

```rust
use clap::Parser;

#[derive(Parser)]
struct Cli {
    /// 服务监听端口
    #[arg(short, long, env = "APP_PORT", default_value_t = 8080)]
    port: u16,
}

fn main() {
    let cli = Cli::parse();
    println!("port = {}", cli.port);
}
```

```bash
$ server
port = 8080

$ APP_PORT=9000 server
port = 9000

$ APP_PORT=9000 server --port 3000
port = 3000
```

最后一例同时存在环境变量和命令行参数，命令行值 `3000` 胜出，印证了优先级规则。

## 五、值校验

`clap` 在解析时即可校验输入，把非法值挡在 `main` 逻辑之外。校验失败会输出友好错误并以退出码 `2` 终止，无需你手写任何判断。

### 5.1 数值区间校验

`value_parser!` 宏为内置类型生成解析器，对整数类型还可链式调用 `.range(...)` 限定区间：

**语法：**

```rust
#[arg(value_parser = clap::value_parser!(u16).range(1..=65535))]
port: u16
```

```rust
use clap::Parser;

#[derive(Parser)]
struct Cli {
    /// 端口号，必须在 1..=65535 之间
    #[arg(value_parser = clap::value_parser!(u16).range(1..=65535))]
    port: u16,
}

fn main() {
    let cli = Cli::parse();
    println!("port = {}", cli.port);
}
```

合法值正常解析，越界值被拒绝：

```bash
$ server 8080
port = 8080
```

```bash
$ server 0
```

运行结果：

```
error: invalid value '0' for '<PORT>': 0 is not in 1..=65535

For more information, try '--help'.
```

> `value_parser!` 不仅做区间校验，也负责类型转换。对于实现了 `FromStr` 的类型（`i32`、`PathBuf`、`IpAddr` 等），`clap` 会自动选用合适的解析器，无需显式书写。

### 5.2 枚举取值与匹配规则

**基础用法**

把参数限定为一组固定取值，用 `#[derive(ValueEnum)]`。`clap` 会自动校验输入、在帮助中列出 `possible values`，并对非法值给出提示。枚举变体名默认转为 kebab-case 作为可接受的输入值：

```rust
use clap::{Parser, ValueEnum};

#[derive(Parser)]
struct Cli {
    /// 日志级别
    #[arg(short, long, value_enum, default_value_t = Level::Info)]
    level: Level,
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
enum Level {
    Debug,
    Info,
    Warn,
    Error,
}

fn main() {
    let cli = Cli::parse();
    println!("level = {:?}", cli.level);
}
```

```bash
$ logger --level warn
level = Warn

$ logger
level = Info
```

帮助信息会自动列出全部合法取值：

```bash
$ logger --help
```

运行结果：

```
Usage: logger [OPTIONS]

Options:
  -l, --level <LEVEL>  日志级别 [default: info] [possible values: debug, info, warn, error]
  -h, --help           Print help
```

**多个枚举类型**

当一个命令需要多个枚举型参数时，无需任何特殊处理：每个枚举各自 `#[derive(ValueEnum)]`，再分别作用到不同字段即可。各枚举之间完全独立，`clap` 会为每个参数单独维护其可接受的取值集合，互不干扰。下例同时引入 `Level`（日志级别）和 `Format`（输出格式）两个枚举：

```rust
use clap::{Parser, ValueEnum};

#[derive(Parser)]
#[command(name = "applog")]
struct Cli {
    /// 日志级别
    #[arg(short, long, value_enum, default_value_t = Level::Info)]
    level: Level,

    /// 输出格式
    #[arg(short, long, value_enum, default_value_t = Format::Text)]
    format: Format,
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
enum Level {
    Debug,
    Info,
    Warn,
    Error,
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
enum Format {
    Text,
    Json,
}

fn main() {
    let cli = Cli::parse();
    println!("level = {:?}, format = {:?}", cli.level, cli.format);
}
```

```bash
$ applog --level warn --format json
level = Warn, format = Json

$ applog
level = Info, format = Text
```

帮助信息中，两个参数各自列出独立的 `possible values`：

```bash
$ applog --help
```

运行结果：

```
Usage: applog [OPTIONS]

Options:
  -l, --level <LEVEL>    日志级别 [default: info] [possible values: debug, info, warn, error]
  -f, --format <FORMAT>  输出格式 [default: text] [possible values: text, json]
  -h, --help             Print help
```

校验也是按参数独立进行的——给 `--format` 传一个不属于 `Format` 的值，错误信息只会列出 `Format` 的合法取值，不会与 `Level` 混淆：

```bash
$ applog --format xml
```

运行结果：

```
error: invalid value 'xml' for '--format <FORMAT>'
  [possible values: text, json]

For more information, try '--help'.
```

> 如果两个不同的枚举碰巧含有同名变体（如都有 `Auto`），它们也不会冲突——`ValueEnum` 的取值是按参数（字段类型）解析的，`clap` 只会在对应参数的取值集合里匹配。若需要让同一个枚举在多处复用，直接在多个字段上引用该枚举类型即可，无需重复定义。

**匹配规则**

前面只看到「`warn` 能匹配到 `Warn`」，但 `clap` 究竟是按什么规则把命令行字符串对应到枚举变体的？`#[derive(ValueEnum)]` 会为枚举生成两样东西：`value_variants()`（全部候选变体的列表）和每个变体的 `to_possible_value()`（该变体对外暴露的「可选值」，即一个 `PossibleValue`，包含一个主名称和若干别名）。解析时，`clap` 把输入字符串逐一与这些 `PossibleValue` 的名称/别名比对，命中则得到对应变体，未命中则报错并列出全部合法取值。理解这套规则，才能精确控制命令行接受哪些写法。

**规则一：变体名默认转 kebab-case。** 变体的主名称由其 Rust 名按 kebab-case 转换得到，例如 `FastMode` → `fast-mode`、`Info` → `info`。这是为了贴合命令行惯用的短横线风格，而非直接暴露 Rust 的 `PascalCase`。

**规则二：默认大小写敏感。** 输入必须与主名称（或别名）大小写完全一致，`FAST-MODE` 不会匹配 `fast-mode`。若希望忽略大小写，在参数上加 `ignore_case = true`。

**规则三：用 `#[value(...)]` 定制单个变体的匹配名与别名。** `name` 替换该变体的主名称，`alias` 增加一个不在帮助中显示的额外可接受写法，`skip` 则让变体完全不暴露给命令行。

下面这个例子集中演示规则一与规则三：

```rust
use clap::{Parser, ValueEnum};

#[derive(Parser)]
#[command(name = "fmt")]
struct Cli {
    #[arg(short, long, value_enum)]
    mode: Mode,
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
enum Mode {
    // 多词变体：默认转 kebab-case，匹配名为 fast-mode
    FastMode,
    // 自定义匹配名 slow，并额外接受别名 lazy
    #[value(name = "slow", alias = "lazy")]
    SlowMode,
    // 不暴露给命令行
    #[value(skip)]
    Internal,
}

fn main() {
    let cli = Cli::parse();
    println!("mode = {:?}", cli.mode);
}
```

帮助只列出主名称（`fast-mode`、`slow`），别名 `lazy` 与被 `skip` 的 `Internal` 都不出现：

```bash
$ fmt --help
```

运行结果：

```
Usage: fmt --mode <MODE>

Options:
  -m, --mode <MODE>  [possible values: fast-mode, slow]
  -h, --help         Print help
```

主名称、别名都能命中目标变体：

```bash
$ fmt --mode fast-mode
mode = FastMode

$ fmt --mode slow
mode = SlowMode

$ fmt --mode lazy
mode = SlowMode
```

而大小写不符、用了被 `name` 覆盖掉的旧名、或被 `skip` 的变体，都会匹配失败（注意 `clap` 还会给出最接近的拼写提示）：

```bash
$ fmt --mode FAST-MODE
```

运行结果：

```
error: invalid value 'FAST-MODE' for '--mode <MODE>'
  [possible values: fast-mode, slow]

For more information, try '--help'.
```

```bash
$ fmt --mode slow-mode
```

运行结果：

```
error: invalid value 'slow-mode' for '--mode <MODE>'
  [possible values: fast-mode, slow]

  tip: a similar value exists: 'slow'

For more information, try '--help'.
```

**规则二的开启方式**——加上 `ignore_case = true` 后，大小写不再敏感：

```rust
use clap::{Parser, ValueEnum};

#[derive(Parser)]
struct Cli {
    #[arg(short, long, value_enum, ignore_case = true)]
    level: Level,
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
enum Level {
    Info,
    Warn,
}

fn main() {
    let cli = Cli::parse();
    println!("level = {:?}", cli.level);
}
```

```bash
$ app --level WARN
level = Warn

$ app --level Warn
level = Warn

$ app --level warn
level = Warn
```

**批量改变命名风格**——若想一次性改变整个枚举的转换规则（而非逐个写 `name`），在枚举上加 `#[value(rename_all = "...")]`，可选 `kebab-case`（默认）、`snake_case`、`PascalCase`、`camelCase`、`SCREAMING_SNAKE_CASE` 等。例如改用 `snake_case` 后，`FastMode` 的匹配名变为 `fast_mode`：

```rust
#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
#[value(rename_all = "snake_case")]
enum Mode {
    FastMode,
    SlowMode,
}
```

```bash
$ app --mode fast_mode
mode = FastMode
```

> 一句话总结匹配流程：**输入字符串 → 与各变体的「主名称 + 别名」按当前大小写策略比对 → 命中得到变体，否则报错。** 主名称由 `rename_all`（默认 kebab-case）统一决定，可被单个变体的 `#[value(name = "...")]` 覆盖；`alias` 只扩展可接受的输入而不进入帮助；`skip` 则把变体彻底排除在命令行之外。

### 5.3 自定义验证规则

内置的区间校验和枚举只能覆盖固定模式的约束。当规则更复杂时（如「必须为偶数」「形如 `KEY=VALUE`」），可以把 `value_parser` 指向一个**自定义函数**。`clap` 会对每个原始输入调用该函数，函数既负责把字符串转成目标类型，也负责校验——两者合二为一。

**语法：**

```rust
#[arg(value_parser = my_parser)]
field: T

// 解析函数签名
fn my_parser(s: &str) -> Result<T, E>
```

**参数：**

| 要求 | 说明 |
|------|------|
| 入参 | 固定为 `&str`，即命令行传入的单个原始值 |
| 返回 `Ok(T)` | `T` 必须与字段类型一致，且满足 `Clone + Send + Sync + 'static` |
| 返回 `Err(E)` | `E` 需可转为 `Box<dyn Error + Send + Sync>`；最简单是直接返回 `String`，错误文案会原样嵌入 `clap` 的报错 |

下例定义两个解析函数：`parse_even` 校验「必须为偶数」，`parse_key_val` 把 `KEY=VALUE` 拆成元组（配合 `Vec` 可重复收集，呼应 3.5 节的多值语义）：

```rust
use clap::Parser;

#[derive(Parser)]
struct Cli {
    /// 必须是偶数
    #[arg(long, value_parser = parse_even)]
    threads: u64,

    /// 形如 KEY=VALUE 的键值对，可重复
    #[arg(long = "define", short = 'D', value_parser = parse_key_val)]
    defines: Vec<(String, String)>,
}

/// 自定义校验：解析为偶数，否则返回错误信息
fn parse_even(s: &str) -> Result<u64, String> {
    let n: u64 = s
        .parse()
        .map_err(|_| format!("`{s}` 不是合法的非负整数"))?;
    if n % 2 != 0 {
        return Err(format!("线程数必须为偶数，但得到 {n}"));
    }
    Ok(n)
}

/// 自定义解析：把 KEY=VALUE 拆成元组
fn parse_key_val(s: &str) -> Result<(String, String), String> {
    let pos = s
        .find('=')
        .ok_or_else(|| format!("缺少 `=` 分隔符: `{s}`"))?;
    Ok((s[..pos].to_string(), s[pos + 1..].to_string()))
}

fn main() {
    let cli = Cli::parse();
    println!("threads = {}", cli.threads);
    println!("defines = {:?}", cli.defines);
}
```

合法输入正常解析，`Vec<(String, String)>` 把多个 `-D` 收集成元组列表：

```bash
$ runner --threads 4 -D host=localhost -D port=8080
```

运行结果：

```
threads = 4
defines = [("host", "localhost"), ("port", "8080")]
```

校验失败时，函数返回的 `Err` 文案会被 `clap` 嵌入标准错误格式中——它自动补上是哪个参数、哪个非法值，你只需提供「为什么不合法」：

```bash
$ runner --threads 3
```

运行结果：

```
error: invalid value '3' for '--threads <THREADS>': 线程数必须为偶数，但得到 3

For more information, try '--help'.
```

```bash
$ runner --threads 4 -D bad_pair
```

运行结果：

```
error: invalid value 'bad_pair' for '--define <DEFINES>': 缺少 `=` 分隔符: `bad_pair`

For more information, try '--help'.
```

> 自定义函数返回的目标类型可以是任意满足约束的类型，包括元组、`PathBuf`、自定义 `struct` 等——这让「校验」和「把原始字符串转换成业务类型」一步到位，避免在 `main` 里二次解析。若校验逻辑需要在多个参数间复用，把它写成独立函数（而非闭包）即可直接被多个字段的 `value_parser` 引用。

## 六、子命令

复杂工具往往按动作拆分为多个子命令（如 `git add`、`git commit`）。用一个 `#[derive(Subcommand)]` 枚举描述所有子命令，每个变体就是一个子命令，变体内的字段就是该子命令的参数；再在顶层 `struct` 用 `#[command(subcommand)]` 标记字段引入它：

```rust
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "todo")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// 添加一个任务
    Add {
        /// 任务内容
        text: String,
        /// 优先级
        #[arg(short, long, default_value_t = 1)]
        priority: u8,
    },
    /// 按编号删除任务
    Remove {
        /// 任务编号
        id: u32,
    },
    /// 列出所有任务
    List,
}

fn main() {
    let cli = Cli::parse();
    match cli.command {
        Commands::Add { text, priority } => {
            println!("添加任务: {} (优先级 {})", text, priority);
        }
        Commands::Remove { id } => {
            println!("删除任务 #{}", id);
        }
        Commands::List => {
            println!("列出所有任务");
        }
    }
}
```

每个子命令拥有独立的参数与帮助：

```bash
$ todo add 买牛奶 --priority 2
添加任务: 买牛奶 (优先级 2)

$ todo remove 3
删除任务 #3

$ todo list
列出所有任务
```

顶层 `--help` 自动汇总所有子命令：

```bash
$ todo --help
```

运行结果：

```
Usage: todo <COMMAND>

Commands:
  add     添加一个任务
  remove  按编号删除任务
  list    列出所有任务
  help    Print this message or the help of the given subcommand(s)

Options:
  -h, --help  Print help
```

> 若把字段类型写成 `Option<Commands>`，子命令就变为可选——允许「不带子命令直接运行」的场景。本例用非 `Option` 类型，因此不带子命令会报错。

## 七、参数关系约束

参数之间常有依赖或互斥关系，`clap` 提供属性声明这些约束，并在违反时自动报错。

### 7.1 互斥（conflicts_with）

`conflicts_with` 声明两个参数不能同时出现。约束是**单向声明即可双向生效**——因为冲突关系本身是对称的，`clap` 在内部对双方都登记，避免你重复书写：

```rust
use clap::Parser;

#[derive(Parser)]
struct Cli {
    /// 静默模式
    #[arg(short, long, conflicts_with = "verbose")]
    quiet: bool,
    /// 详细模式
    #[arg(short, long)]
    verbose: bool,
}

fn main() {
    let cli = Cli::parse();
    println!("quiet = {}, verbose = {}", cli.quiet, cli.verbose);
}
```

```bash
$ app --quiet
quiet = true, verbose = false
```

```bash
$ app --quiet --verbose
```

运行结果：

```
error: the argument '--quiet' cannot be used with '--verbose'

Usage: app --quiet

For more information, try '--help'.
```

### 7.2 依赖（requires）

`requires` 声明「使用 A 时必须同时提供 B」。下例中 `--config` 依赖 `--input`：

```rust
use clap::Parser;

#[derive(Parser)]
struct Cli {
    /// 配置文件，使用时必须同时指定 --input
    #[arg(long, requires = "input")]
    config: Option<String>,
    /// 输入文件
    #[arg(long)]
    input: Option<String>,
}

fn main() {
    let cli = Cli::parse();
    println!("config = {:?}, input = {:?}", cli.config, cli.input);
}
```

```bash
$ deploy --config a.toml --input in.txt
config = Some("a.toml"), input = Some("in.txt")
```

```bash
$ deploy --config a.toml
```

运行结果：

```
error: the following required arguments were not provided:
  --input <INPUT>

Usage: deploy --input <INPUT> --config <CONFIG>

For more information, try '--help'.
```

下表对比三种常用约束的语义：

| 属性 | 含义 | 违反时的错误类型 |
|------|------|----------------|
| `required = true` | 该参数必须提供 | 缺少必填参数 |
| `conflicts_with = "B"` | 不能与 B 同时出现 | 参数冲突 |
| `requires = "B"` | 使用本参数时必须同时提供 B | 缺少依赖参数 |

## 八、参数组与复用（flatten）

当多个子命令共享同一批参数（如全局的 `--verbose`、`--config`）时，可把它们抽到一个 `#[derive(Args)]` 结构体，再用 `#[command(flatten)]` 在多处复用，避免重复定义。被 flatten 的字段会像直接写在父结构体里一样平铺到命令行：

```rust
use clap::{Args, Parser, Subcommand};

#[derive(Parser)]
#[command(name = "tool")]
struct Cli {
    #[command(flatten)]
    global: GlobalOpts,

    #[command(subcommand)]
    command: Commands,
}

/// 多个子命令共享的全局选项
#[derive(Args)]
struct GlobalOpts {
    /// 详细级别，可重复指定 -v
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,
    /// 配置文件
    #[arg(short, long, default_value = "config.toml")]
    config: String,
}

#[derive(Subcommand)]
enum Commands {
    /// 构建项目
    Build,
    /// 运行项目
    Run,
}

fn main() {
    let cli = Cli::parse();
    println!("verbose = {}, config = {}", cli.global.verbose, cli.global.config);
    match cli.command {
        Commands::Build => println!("command = build"),
        Commands::Run => println!("command = run"),
    }
}
```

```bash
$ tool -vv --config app.toml build
verbose = 2, config = app.toml
command = build

$ tool run
verbose = 0, config = config.toml
command = run
```

`#[derive(Args)]` 结构体上还能用 `#[group(...)]` 定义一组参数的整体约束。下例声明「必须且只能选择一种输入来源」（`required = true` 表示至少选一个，`multiple = false` 表示至多选一个，合起来即「恰好一个」）：

```rust
use clap::{Args, Parser};

#[derive(Parser)]
#[command(name = "reader")]
struct Cli {
    #[command(flatten)]
    source: Source,
}

/// 输入来源：必须且只能选择其中一种
#[derive(Args)]
#[group(required = true, multiple = false)]
struct Source {
    /// 从文件读取
    #[arg(long)]
    file: Option<String>,
    /// 从标准输入读取
    #[arg(long)]
    stdin: bool,
}

fn main() {
    let cli = Cli::parse();
    match (cli.source.file, cli.source.stdin) {
        (Some(f), _) => println!("从文件读取: {}", f),
        (None, true) => println!("从标准输入读取"),
        _ => unreachable!(),
    }
}
```

```bash
$ reader --file data.txt
从文件读取: data.txt

$ reader --stdin
从标准输入读取
```

一个都不提供时报「缺少必填」，两个都提供时报「互斥」：

```bash
$ reader
```

运行结果：

```
error: the following required arguments were not provided:
  <--file <FILE>|--stdin>

Usage: reader <--file <FILE>|--stdin>

For more information, try '--help'.
```

```bash
$ reader --file data.txt --stdin
```

运行结果：

```
error: the argument '--file <FILE>' cannot be used with '--stdin'

Usage: reader <--file <FILE>|--stdin>

For more information, try '--help'.
```

## 九、`#[arg]` 属性全貌

前面各章按场景介绍了 `#[arg(...)]` 的常用属性。本章把它们系统梳理一遍，便于查阅。

理解 `#[arg]` 的关键，是先分清它支持的两类属性：

- **魔法属性（magic attribute）**：由 `derive` 宏特殊处理，会触发推断、默认值或专门行为，语法受限（通常为 `attr = value`）。包括 `id`、`value_parser`、`action`、`help`、`long_help`、`verbatim_doc_comment`、`short`、`long`、`env`、`from_global`、`value_enum`、`skip`，以及各种默认值设置（`default_value`、`default_value_t`、`default_values_t`、`default_value_os_t`）。
- **原始属性（raw attribute）**：直接转发到底层 `Arg` 构建器的同名方法。`#[arg(num_args(..=3))]` 就等价于调用 `arg.num_args(..=3)`。这意味着 **`Arg` 上的任何方法都能作为 `#[arg]` 属性使用**——`num_args`、`required`、`requires`、`conflicts_with`、`value_name`、`hide`、`global`、`last` 等都属于此类。

> 原始属性有两种写法：单参数方法用 `attr = value`，多参数方法用 `attr(arg1, arg2)`（如 `required_if_eq("out", "file")`）。魔法属性优先级低于「从类型/文档注释推断」的结果，除非用 `attr(value)` 形式强制走原始行为。

下面按用途分组列出常用属性。

**命名与别名**

| 属性 | 说明 |
|------|------|
| `short` / `short = 'x'` | 短选项，省略值时取字段名首字母 |
| `long` / `long = "name"` | 长选项，省略值时取字段名的 kebab-case |
| `value_name = "X"` | 帮助中值的占位符名（默认是字段名大写） |
| `alias = "x"` / `aliases = ["a", "b"]` | 隐藏别名，可用但不在帮助中显示 |
| `visible_alias = "x"` / `visible_aliases = [...]` | 可见别名，会在帮助中以 `[aliases: ...]` 标出 |
| `id = "name"` | 参数的内部标识符，供 `requires`/`conflicts_with` 等引用 |

**帮助与可见性**

| 属性                        | 说明                                                         |
| ------------------------- | ---------------------------------------------------------- |
| `help = "..."`            | 覆盖由文档注释生成的短帮助                                              |
| `long_help = "..."`       | `--help` 显示的长帮助（`-h` 仍显示短帮助）                               |
| `verbatim_doc_comment`    | 原样保留文档注释的换行与格式，不做规整                                        |
| `hide = true`             | 不在帮助中显示该参数（但仍可使用）                                          |
| `next_line_help = true`   | 帮助文本另起一行显示，适合说明较长时                                         |
| `c = ValueHint::FilePath` | 为 shell 补全提供值类型提示（`FilePath`、`DirPath`、`Url`、`Hostname` 等） |

**取值与解析**

| 属性 | 说明 |
|------|------|
| `value_parser = ...` | 指定解析器/校验器（内置类型、`value_parser!(T).range(..)` 或自定义函数） |
| `action = ArgAction::...` | 匹配时的动作（`Set`/`Append`/`SetTrue`/`Count` 等，详见 3.4 节的表） |
| `value_enum` | 配合 `#[derive(ValueEnum)]`，限定为枚举取值 |
| `num_args = 1..=3` | 该参数接受的值的个数（精确值或区间） |
| `require_equals = true` | 必须使用 `--opt=value` 形式，不接受 `--opt value` |

**默认值与来源**

| 属性 | 说明 |
|------|------|
| `default_value = "..."` | 字符串形式默认值，经 `value_parser` 解析 |
| `default_value_t [= expr]` | 类型化默认值，省略时用 `Default::default()` |
| `default_values_t = [...]` | `Vec` 字段的多值默认 |
| `default_missing_value = "..."` | 提供了选项但未给值时使用的值（配合 `num_args(0..=1)`） |
| `env = "VAR"` | 命令行未提供时从环境变量读取（需 `env` feature） |
| `global = true` | 全局参数，子命令也能识别 |
| `from_global` | 从父命令的全局参数读取该字段的值 |

**关系约束**

| 属性 | 说明 |
|------|------|
| `required = true` | 强制必填（覆盖由 `Option<T>` 推断出的可选） |
| `requires = "B"` | 使用本参数时必须同时提供 B（详见 7.2） |
| `conflicts_with = "B"` / `conflicts_with_all = [...]` | 与指定参数互斥（详见 7.1） |
| `exclusive = true` | 与其他**所有**参数互斥 |
| `required_if_eq("B", "val")` | 当 B 等于某值时本参数才必填 |
| `last = true` | 该位置参数只能出现在 `--` 之后 |

**结构组织**（写在字段上，但属于 `#[command]`/容器语义）

| 属性 | 说明 |
|------|------|
| `#[command(flatten)]` | 把一个 `#[derive(Args)]` 结构体平铺进来（详见第八章） |
| `#[command(subcommand)]` | 引入子命令枚举（详见第六章） |
| `#[arg(skip [= expr])]` | 该字段不作为命令行参数，用默认值或指定表达式填充 |

下面用一个示例集中演示多个属性的协同效果——重命名长短选项、自定义占位符名、关联环境变量与默认值、可见别名、补全提示、限定取值个数、以及隐藏参数：

```rust
use clap::{Parser, ValueHint};

#[derive(Parser)]
#[command(name = "srv")]
struct Cli {
    /// 监听端口
    #[arg(
        short = 'p',
        long = "port",
        value_name = "PORT",
        env = "APP_PORT",
        default_value_t = 8080,
        visible_alias = "bind"
    )]
    port: u16,

    /// 配置文件路径
    #[arg(short, long, value_name = "FILE", value_hint = ValueHint::FilePath)]
    config: Option<String>,

    /// 额外标签，1 到 3 个
    #[arg(long, num_args = 1..=3)]
    tags: Vec<String>,

    /// 内部调试开关（不在帮助中显示）
    #[arg(long, hide = true)]
    debug_internal: bool,
}

fn main() {
    let cli = Cli::parse();
    println!("port = {}", cli.port);
    println!("config = {:?}", cli.config);
    println!("tags = {:?}", cli.tags);
    println!("debug_internal = {}", cli.debug_internal);
}
```

帮助信息综合反映了这些属性：`port` 显示了别名、环境变量与默认值，`config` 用了自定义占位符 `FILE`，`tags` 标出了可重复（`...`），而 `debug_internal` 因 `hide` 完全不出现：

```bash
$ srv --help
```

运行结果：

```
Usage: srv [OPTIONS]

Options:
  -p, --port <PORT>     监听端口 [env: APP_PORT=] [default: 8080] [aliases: --bind]
  -c, --config <FILE>   配置文件路径
      --tags <TAGS>...  额外标签，1 到 3 个
  -h, --help            Print help
```

可见别名 `--bind` 与隐藏参数 `--debug-internal` 虽未必出现在帮助中，但都能正常使用：

```bash
$ srv --bind 9000 --tags a b
port = 9000
config = None
tags = ["a", "b"]
debug_internal = false

$ srv --debug-internal
port = 8080
config = None
tags = []
debug_internal = true
```

> 由于原始属性等价于 `Arg` 的方法调用，本章的表格无法穷尽所有属性——任何 `Arg` 上的方法都是潜在可用的属性。遇到表中没有的需求时，先去 `Arg` 的文档里找对应方法，再以 `#[arg(method = value)]` 或 `#[arg(method(a, b))]` 的形式写上即可。

## 十、derive API 与 builder API 的选择

`clap` 提供两套等价的 API：本文使用的 `derive`（声明式），以及更底层的 `builder`（命令式，通过 `Command::new(...).arg(...)` 链式构建）。二者能力相同，区别在于风格：

| 维度 | derive API | builder API |
|------|-----------|-------------|
| 定义方式 | 用 `struct` / `enum` + 派生宏声明 | 用 `Command` / `Arg` 链式调用构建 |
| 代码量 | 少，参数即类型 | 多，每个参数手写 |
| 类型映射 | 自动（字段类型即解析结果） | 手动 `get_one::<T>(...)` 取值 |
| 动态构建 | 受限（编译期固定） | 灵活（可运行时按条件增减参数） |
| 适用场景 | 绝大多数应用，结构清晰 | 参数在运行时动态生成的特殊场景 |

简言之：**优先使用 `derive` API**，它把参数定义和数据结构统一为一个 `struct`，可读性和维护性最佳；只有在需要运行时动态拼装命令结构时，才考虑 `builder` API。两套 API 还可混用——用 `derive` 定义主体，再通过 `CommandFactory` 拿到底层 `Command` 做局部定制。
