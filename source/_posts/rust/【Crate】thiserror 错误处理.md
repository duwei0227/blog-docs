---
title: thiserror 错误处理
date: 2026-04-07 08:39:00
tags:
  - thiserror
  - 错误处理
  - derive 宏
categories: Rust
---

## 一、安装与依赖

在 `Cargo.toml` 中添加依赖：

```toml
[dependencies]
thiserror = "2"
```

`thiserror` 为 `Rust` 标准库 `std::error::Error` trait 提供 `derive` 宏支持。通过 `#[derive(Error)]` 可以自动生成 `Error`、`Display`、`Debug` trait 的实现，开发者只需关注错误类型的设计和错误消息的定义。

## 二、基础用法

### 2.1 错误枚举

`thiserror` 最常见的用法是定义错误 `enum`。以下示例展示一个数据存储的错误类型，所有错误消息均为静态字符串：

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DataStoreError {
    #[error("data store disconnected")]
    Disconnect,

    #[error("entry has been redacted")]
    Redacted,

    #[error("invalid header")]
    InvalidHeader,

    #[error("unknown data store error")]
    Unknown,
}

fn main() {
    let err = DataStoreError::Disconnect;
    println!("{}", err);
}
```

运行结果：

```
data store disconnected
```

其余变体的输出以此类推：

| 构造方式 | 运行结果 |
|---------|---------|
| `DataStoreError::Redacted` | `entry has been redacted` |
| `DataStoreError::InvalidHeader` | `invalid header` |
| `DataStoreError::Unknown` | `unknown data store error` |

### 2.2 字段插值语法

`#[error("...")]` 消息模板支持从错误字段中读取值并嵌入消息。具名字段和元组字段各有简写形式：

| 语法 | 含义 | 等价展开 |
|------|------|---------|
| `#[error("{var}")]` | 具名字段，`Display` 格式化 | `write!("{}", self.var)` |
| `#[error("{0}")]` | 元组字段（索引 0），`Display` 格式化 | `write!("{}", self.0)` |
| `#[error("{var:?}")]` | 具名字段，`Debug` 格式化 | `write!("{:?}", self.var)` |
| `#[error("{0:?}")]` | 元组字段（索引 0），`Debug` 格式化 | `write!("{:?}", self.0)` |

其中 `var` 为具名字段的字段名，`0` 为元组字段的位置索引（从 0 起），`:?` 为 `Debug` 格式化标记，缺省时默认使用 `Display` 格式化。

以下示例同时展示四种语法：

```rust
#[derive(Error, Debug)]
pub enum Error {
    #[error("rebidden: {reason}")]
    Invalid { reason: String },

    #[error("data for key `{0}` not found")]
    Missing(String),

    #[error("invalid value: {0:?}")]
    BadValue(Vec<u8>),

    #[error("position {pos} out of range")]
    OutOfRange { pos: usize },
}	

fn main() {
    let e1 = Error::Invalid { reason: "foo".to_string() };
    let e2 = Error::Missing("mykey".to_string());
    let e3 = Error::BadValue(vec![1, 2, 3]);
    let e4 = Error::OutOfRange { pos: 42 };

    println!("{}", e1);
    println!("{}", e2);
    println!("{}", e3);
    println!("{}", e4);
}
```

运行结果：

```
rebidden: foo
data for key `mykey` not found
invalid value: [1, 2, 3]
position 42 out of range
```

### 2.3 额外格式化参数

除字段插值外，`#[error]` 还支持在模板后添加额外的格式化参数，参数值可以是任意表达式。具名字段用 `.field` 引用，元组字段用 `.0` 引用：

```rust
#[derive(Error, Debug)]
pub enum Error {
    #[error("first letter must be lowercase but was {:?}", first_char(.0))]
    WrongCase(String),

    #[error("invalid index {idx}, expected at least {} and at most {}", .limits.0, .limits.1)]
    OutOfBounds { idx: usize, limits: (usize, usize) },

    #[error("invalid lookahead {0} (max = {max})", max = i32::MAX)]
    BadLookahead(u32),
}

fn first_char(s: &str) -> char {
    s.chars().next().unwrap_or('\0')
}

fn main() {
    let e1 = Error::WrongCase("Hello".to_string());
    let e2 = Error::OutOfBounds { idx: 100, limits: (0, 50) };
    let e3 = Error::BadLookahead(42);

    println!("{}", e1);
    println!("{}", e2);
    println!("{}", e3);
}
```

运行结果：

```
first letter must be lowercase but was 'H'
invalid index 100, expected at least 0 and at most 50
invalid lookahead 42 (max = 2147483647)
```

## 三、自动 `From` 转换

`#[from]` 属性为包含错误源字段的变体自动生成 `From` trait 实现，使错误可以在 `?` 运算符中自动转换：

```rust
use std::io;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum MyError {
    #[error("IO error occurred")]
    Io(#[from] io::Error),

    #[error("parse error: {0}")]
    Parse(#[from] std::num::ParseIntError),
}

fn parse_int(s: &str) -> Result<i32, MyError> {
    let n: i32 = s.parse()?; // 自动 From<ParseIntError> → MyError
    Ok(n)
}

fn read_file() -> Result<Vec<u8>, MyError> {
    let _ = std::fs::read("nonexistent.txt")?; // 自动 From<io::Error> → MyError
    Ok(vec![])
}

fn main() {
    if let Err(e) = parse_int("not a number") {
        println!("{}", e);
    }
    if let Err(e) = read_file() {
        println!("{}", e);
    }
}
```

运行结果：

```
parse error: invalid digit found in string
IO error occurred
```

`#[from]` 隐含 `#[source]` 语义，无需同时标记两个属性。使用 `#[from]` 的变体，其字段只能是错误源（可能有 `Backtrace`），不能包含其他字段。

## 四、手动指定错误源

### 使用场景

`#[source]` 的核心作用是实现 `Error::source()`，让调用方可以通过错误链追溯底层原因。以下是 `#[source]` 的典型适用场景：

**场景一：结构体错误包装单一底层错误**

用结构体包装一个带附加上下文的错误，同时暴露底层错误源。例如数据库连接错误，可能需要在连接失败时保留底层 `io::Error`：

```rust
use thiserror::Error;

#[derive(Error, Debug)]
#[error("database error: {operation} failed")]
pub struct DatabaseError {
    operation: String,
    #[source]
    cause: std::io::Error,
}
```

这里 `cause` 不是 `source` 命名，必须显式标记 `#[source]` 才能让 `Error::source()` 返回底层的 `io::Error`。

**场景二：结构体字段名不是 `source`**

如果底层错误字段命名为其他名称（如 `cause`、`underlying`、`inner`），`thiserror` 不会自动将其识别为错误源，此时必须显式标注 `#[source]`：

```rust
#[derive(Error, Debug)]
#[error("request failed")]
pub struct RequestError {
    #[source]
    cause: reqwest::Error, // 显式标记，字段名不是 source
}
```

**场景三：与 `#[from]` 不同的行为**

`#[from]` 在 `enum` 中隐含 `#[source]`，且自动生成 `From` impl。如果只希望暴露错误链而不生成 `From` 转换，则必须用 `#[source]`。例如在结构体中手动构造错误而非通过 `?` 自动转换：

```rust
use thiserror::Error;

#[derive(Error, Debug)]
#[error("config error: {msg}")]
pub struct ConfigError {
    msg: String,
    #[source]
    source: std::io::Error,
}
```

### 使用方式

当底层错误字段名为 `source` 时，`#[source]` 可以省略（`thiserror` 会自动识别）。当字段名为其他名称时，必须显式添加 `#[source]` 属性：

```rust
use thiserror::Error;

#[derive(Error, Debug)]
#[error("config error: {msg}")]
pub struct ConfigError {
    msg: String,
    #[source] // 字段名非 source，必须显式标记
    cause: std::io::Error,
}

fn main() {
    let io_err = std::io::Error::new(std::io::ErrorKind::NotFound, "file not found");
    let err = ConfigError { msg: "config file missing".to_string(), cause: io_err };

    println!("{}", err);
    println!("source: {:?}", std::error::Error::source(&err));
}
```

运行结果：

```
config error: config file missing
source: Some(Custom { kind: NotFound, error: "file not found" })
```

### `#[source]` vs `#[from]` 对比

| 特性 | `#[source]` | `#[from]` |
|------|-------------|-----------|
| 指定 `Error::source()` | ✅ | ✅（隐含） |
| 生成 `From` impl | ❌ | ✅ |
| 支持 enum 变体 | ✅（但通常用 `#[from]`） | ✅ |
| 支持 struct 字段 | ✅ | ❌ |
| 字段名非 `source` 时可用 | ✅ | ❌ |

## 五、结构体风格的错误类型

错误类型可以是 `enum`、具名字段 `struct`、元组 `struct` 或单元 `struct`：

```rust
use thiserror::Error;

// 具名字段 struct
#[derive(Error, Debug)]
#[error("validation failed: {field} is invalid ({reason})")]
pub struct ValidationError {
    pub field: String,
    pub reason: String,
}

// 元组 struct
#[derive(Error, Debug)]
#[error("parse error at position {0}: {1}")]
pub struct ParseError(usize, String);

// 单元 struct
#[derive(Error, Debug)]
#[error("service unavailable")]
pub struct ServiceUnavailableError;

// enum 中混合使用
#[derive(Error, Debug)]
pub enum ComplexError {
    #[error("named field variant: x={x}, y={y}")]
    Point { x: f64, y: f64 },

    #[error("tuple variant: ({0}, {1})")]
    Pair(String, i32),

    #[error("unit variant: done")]
    Done,
}

fn main() {
    let e1 = ValidationError { field: "email".to_string(), reason: "格式不正确".to_string() };
    let e2 = ParseError(10, "unexpected token".to_string());
    let e3 = ServiceUnavailableError;
    let e4 = ComplexError::Point { x: 1.5, y: 2.5 };
    let e5 = ComplexError::Pair("hello".to_string(), 42);
    let e6 = ComplexError::Done;

    println!("{}", e1);
    println!("{}", e2);
    println!("{}", e3);
    println!("{}", e4);
    println!("{}", e5);
    println!("{}", e6);
}
```

运行结果：

```
validation failed: email is invalid (格式不正确)
parse error at position 10: unexpected token
service unavailable
named field variant: x=1.5, y=2.5
tuple variant: (hello, 42)
unit variant: done
```

## 六、透明错误

`#[error(transparent)]` 将 `Display` 和 `source` 方法直接转发到底层错误类型，不添加额外消息。适用于封装"其他未知错误"的场景：

```rust
use thiserror::Error;

#[derive(Debug)]
pub struct OpaqueError(String);

impl std::fmt::Display for OpaqueError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl std::error::Error for OpaqueError {}

#[derive(Error, Debug)]
pub enum MyError {
    #[error("specific error: {0}")]
    Specific(String),

    #[error(transparent)]
    Other(OpaqueError),
}

fn main() {
    let e1 = MyError::Specific("just this".to_string());
    let e2 = MyError::Other(OpaqueError("underlying error details".to_string()));

    println!("{}", e1);
    println!("{}", e2);
}
```

运行结果：

```
specific error: just this
underlying error details
```

`transparent` 的典型用途包括：包装 `anyhow::Error` 作为 `enum` 的兜底变体；将内部错误表示的具体实现隐藏在 opaque public type 之后，使内部表示可以在不破坏公开 API 的前提下自由演进。

## 七、Backtrace 支持

`thiserror` 支持通过 `Backtrace` 字段自动捕获栈回溯。使用 `Backtrace` 需要 `Rust` 1.73+ 并启用 nightly：

```rust
use std::backtrace::Backtrace;
use thiserror::Error;

#[derive(Error, Debug)]
pub struct MyError {
    msg: String,
    backtrace: Backtrace, // 自动检测并提供 Backtrace
}
```

当字段同时标记 `#[backtrace]` 和 `#[source]`（或 `#[from]`）时，`Error::provide()` 方法会转发到底层错误的 `provide`，使两层错误共享同一个 `Backtrace`：

```rust
#[derive(Error, Debug)]
pub enum MyError {
    Io {
        #[backtrace]
        source: io::Error,
    },
}
```

如果变体同时包含 `#[from]` 和 `Backtrace` 字段，`Backtrace` 会在 `From` impl 中自动捕获。

## 八、thiserror 与 anyhow 的选择

`thiserror` 和 `anyhow` 均来自 `dtolnay` 之手，适用于不同场景：

| 维度 | thiserror | anyhow |
|------|-----------|--------|
| 定位 | 定义专用错误类型 | 使用通用错误类型 |
| 适用场景 | 库代码（需要公开错误 API） | 应用代码（不关心具体错误类型） |
| API 影响 | 不进入公开 API，可与手写实现互换 | 进入公开 API，返回 `Result<T, anyhow::Error>` |
| 灵活性 | 高，由 `you` 定义每个错误变体的结构 | 中，所有错误统一为一种类型 |

简言之：编写库代码时使用 `thiserror` 定义清晰的错误类型；编写应用代码时使用 `anyhow` 简化错误传播。

## 九、错误描述国际化

### 9.1 thiserror 不支持国际化

`thiserror` 的 `#[error("...")]` 属性接受的是编译期字符串字面量，`Display` trait 的实现由 `derive` 宏在编译时生成。这意味着错误消息的内容在编译阶段就固定了，无法在运行时根据语言环境动态切换。

以下代码展示了这一限制的根源：

```rust
#[derive(Error, Debug)]
pub enum Error {
    #[error("数据文件断开连接")] // 硬编码的中文字符串
    Disconnect,
}

fn main() {
    let err = Error::Disconnect;
    println!("{}", err);
}
```

运行结果：

```
数据文件断开连接
```

编译器将 `"数据文件断开连接"` 直接嵌入生成的 `Display` 实现中，运行时不存在任何查表的逻辑。

### 9.2 原因分析

`thiserror` 的设计哲学是提供与手写 `Error` trait 实现完全等价的能力——生成的代码与手工编写无异。而 `std::error::Error` 的 `Display` trait 本身设计为接收一个 `&self` 和 `&mut Formatter`，参数中不包含 locale 或语言上下文。`Rust` 标准库的错误处理体系中根本没有国际化的基础设施。

因此，即使 `thiserror` 想支持国际化，也面临两个根本障碍：`Display` trait 签名中不存在 locale 参数；`thiserror` 生成的代码是静态的，没有运行时查找机制。

### 9.3 替代方案

如果项目确实需要错误消息国际化，有以下几种思路：

**方案一：错误码而非错误文本**

将错误定义为携带错误码（通常是数值或字符串标识符），由调用方根据错误码查表获取本地化消息：

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("ERR_DISCONNECT: code={0}")]
    Disconnect(u32),
}

impl Error {
    pub fn error_code(&self) -> &'static str {
        match self {
            Error::Disconnect(_) => "ERR_DISCONNECT",
        }
    }
}

fn main() {
    let err = Error::Disconnect(42);
    println!("Display: {}", err);
    println!("code:   {}", err.error_code());
}
```

运行结果：

```
Display: ERR_DISCONNECT: code=42
code:   ERR_DISCONNECT
```

调用方根据 `error_code()` 查表返回对应语言的消息。

**方案二：使用 fluent-rs 替代字符串字面量**

fluent-rs 是 `Mozilla` 维护的国际化系统，通过 FTL 文件定义翻译资源。可以将错误码作为 message ID，通过 fluent-rs 查找翻译。以下示例演示其查表逻辑：

```rust
use std::collections::HashMap;

fn get_i18n_message(error_id: &str, lang: &str) -> String {
    // 模拟 fluent-rs 查表行为
    let mut zh: HashMap<&str, &str> = HashMap::new();
    zh.insert("err_disconnect", "数据文件断开连接");

    let mut en: HashMap<&str, &str> = HashMap::new();
    en.insert("err_disconnect", "data store disconnected");

    match lang {
        "zh" => zh.get(error_id).map(|s| s.to_string()).unwrap_or_else(|| error_id.to_string()),
        _ => en.get(error_id).map(|s| s.to_string()).unwrap_or_else(|| error_id.to_string()),
    }
}

fn main() {
    let msg_zh = get_i18n_message("err_disconnect", "zh");
    let msg_en = get_i18n_message("err_disconnect", "en");
    println!("[zh] {}", msg_zh);
    println!("[en] {}", msg_en);
}
```

运行结果：

```
[zh] 数据文件断开连接
[en] data store disconnected
```

但需要注意，`thiserror` 的 `#[error("...")]` 仍然只能接受字面量，因此这种方案实际上放弃了使用 `thiserror` 的消息模板功能，改由调用方在 `Display` 之外单独处理国际化。

**方案三：手动实现 Display**

完全不使用 `thiserror` 的 `#[error]` 属性，手动实现 `Display` trait 并在实现中调用翻译函数：

```rust
use std::error::Error as StdError;
use std::fmt;

#[derive(Debug)]
pub enum MyError {
    Disconnect,
}

impl fmt::Display for MyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MyError::Disconnect => {
                write!(f, "{}", translate("err_disconnect"))
            }
        }
    }
}

impl StdError for MyError {}

fn translate(id: &str) -> String {
    // 实际项目中调用翻译系统
    format!("[i18n:{}]", id)
}

fn main() {
    let err = MyError::Disconnect;
    println!("{}", err);
}
```

运行结果：

```
[i18n:err_disconnect]
```

此方案失去了 `derive` 宏的便利性，但获得了完整的国际化能力。

### 9.4 推荐做法

实际项目中，`thiserror` 的典型使用者是库作者，库不应该假设最终用户的语言环境。因此 **错误码 + 错误描述** 的分离设计是最佳实践：

- 错误变体携带机器可读的标识符（错误码）和结构化数据
- 将人类可读的错误消息留给应用层或翻译系统处理

具体而言，给每个错误变体添加一个 `code()` 方法返回静态字符串，供上层做国际化映射：

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DataStoreError {
    #[error("data store disconnected")]
    Disconnect,

    #[error("the data for key `{0}` is not available")]
    Redaction(String),
}

impl DataStoreError {
    pub fn code(&self) -> &'static str {
        match self {
            DataStoreError::Disconnect => "ERR_DISCONNECT",
            DataStoreError::Redaction(_) => "ERR_REDACTION",
        }
    }
}

fn main() {
    let err = DataStoreError::Disconnect;
    println!("Display: {}", err);
    println!("code:   {}", err.code());
}
```

运行结果：

```
Display: data store disconnected
code:   ERR_DISCONNECT
```

应用层根据 `code()` 查 `fluent` 或其他 i18n 系统得到本地化消息，同时保留 `Display` 在日志和控制台输出中提供可读但不依赖特定语言的默认信息。

## 各语言必须包裹的术语索引

> content.md 各章节的等效术语映射，写作对应语言文章时必须覆盖。

### Rust 语言术语

| 类别 | 示例 |
|------|------|
| Rust 关键字 | `trait`、`struct`、`enum`、`fn`、`impl`、`let`、`mut`、`pub`、`mod`、`use`、`crate` |
| derive 相关 | `derive`、`#[derive]`、`#[derive(Error)]` |
| 属性宏 | `#[error]`、`#[error("...")]`、`#[source]`、`#[from]`、`#[backtrace]` |
| 核心 Trait 名 | `Error`、`Display`、`Debug`、`From`、`Result` |
| 标准库类型/模块 | `std::error::Error`、`std::fmt::Display`、`Backtrace`、`Rust` |
| 外部 Crate 名 | `thiserror`、`anyhow`、`fluent-rs` |
| 格式化语法 | `{0}`、`{var}`、`{var:?}`、`transparent`、`i32::MAX` |
| 方法引用（作为术语时） | `Error::source()`、`Error::provide()`、`first_char()`、`parse()` |
| 数据类型名 | `f64`、`f32`、`usize`、`u32`、`i64`、`String`、`&str` |

### Python 语言术语

| 类别 | 示例 |
|------|------|
| 内置函数 | `len()`、`str()`、`int()`、`print()`、`open()` |
| 内置类型 | `str`、`int`、`float`、`list`、`dict`、`tuple`、`set`、`bool` |
| 保留字/关键字 | `if`、`else`、`for`、`while`、`def`、`class`、`import`、`from`、`return`、`yield` |
| 魔术方法 | `__init__`、`__str__`、`__repr__`、`__len__` |
| 标准库模块 | `datetime`、`collections`、`os`、`sys`、`pathlib` |

### Java 语言术语

| 类别 | 示例 |
|------|------|
| 关键字 | `public`、`private`、`protected`、`class`、`interface`、`extends`、`implements`、`static`、`void`、`return` |
| 注解 | `@Override`、`@Deprecated`、`@FunctionalInterface` |
| 核心类/接口 | `String`、`Object`、`Class`、`Exception`、`Runnable` |
| 方法引用（作为术语时） | `toString()`、`hashCode()`、`equals()` |
