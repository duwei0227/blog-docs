---
title: thiserror 实用指南
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

`thiserror` 为 Rust 标准库 `std::error::Error` trait 提供 derive 宏支持。通过 `#[derive(Error)]` 可以自动生成 `Error`、`Display`、`Debug` trait 的实现，开发者只需关注错误类型的设计和错误消息的定义。

## 二、基础用法

### 2.1 错误枚举

`thiserror` 最常见的用法是定义错误枚举。以下示例展示一个数据存储的错误类型：

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DataStoreError {
    #[error("data store disconnected")]
    Disconnect,

    #[error("the data for key `{0}` is not available")]
    Redaction(String),

    #[error("invalid header (expected {expected:?}, found {found:?})")]
    InvalidHeader { expected: String, found: String },

    #[error("unknown data store error")]
    Unknown,
}
```

运行结果：

```
data store disconnected
the data for key `foo` is not available
invalid header (expected "UTF-8", found "ASCII")
unknown data store error
```

### 2.2 字段插值语法

`#[error("...")]` 消息模板支持字段插值的简写形式：

| 语法 | 等价展开 |
|------|---------|
| `#[error("{var}")]` | `write!("{}", self.var)` |
| `#[error("{0}")]` | `write!("{}", self.0)` |
| `#[error("{var:?}")]` | `write!("{:?}", self.var)` |
| `#[error("{0:?}")]` | `write!("{:?}", self.0)` |

### 2.3 额外格式化参数

除字段插值外，`#[error]` 还支持额外的格式化参数，参数可以是任意表达式。格式为 `#[error("模板", 参数名 = 表达式)]`：

```rust
#[derive(Error, Debug)]
pub enum Error {
    // 额外参数 max 为固定常量
    #[error("invalid rdo_lookahead_frames {0} (expected < {max})", max = i32::MAX)]
    InvalidLookahead(u32),

    // extra_args 中引用字段需加前缀：具名字段加 `.`，元组字段用 `.0`
    #[error("first letter must be lowercase but was {:?}", first_char(.0))]
    WrongCase(String),

    #[error("invalid index {idx}, expected at least {} and at most {}", .limits.0, .limits.1)]
    OutOfBounds { idx: usize, limits: (usize, usize) },
}
```

运行结果：

```
invalid rdo_lookahead_frames 42 (expected < 2147483647)
first letter must be lowercase but was 'H'
invalid index 100, expected at least 0 and at most 50
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

fn read_and_parse(s: &str) -> Result<i32, MyError> {
    let num: i32 = s.parse()?; // 自动 From<ParseIntError> → MyError
    Ok(num)
}
```

运行结果：

```
parse error: parse error: invalid digit found in string
```

`#[from]` 隐含 `#[source]` 语义，无需同时标记两个属性。使用 `#[from]` 的变体，其字段只能是错误源（可能有 `Backtrace`），不能包含其他字段。

## 四、手动指定错误源

`#[source]` 用于显式标记哪个字段是底层错误源。如果字段名为 `source`，则可以省略该属性：

```rust
use thiserror::Error;

#[derive(Error, Debug)]
#[error("config error: {msg}")]
pub struct ConfigError {
    msg: String,
    #[source] // 显式标记 source 字段
    source: std::io::Error,
}
```

运行结果：

```
config error: config file missing
source: Some(Custom { kind: NotFound, error: "file not found" })
```

`#[source]` 和 `#[from]` 的区别在于：`#[from]` 会自动生成 `From` 实现并隐含 `#[source]`，而 `#[source]` 仅用于指定错误源链，不生成 `From` 实现。

## 五、结构体风格的错误类型

错误类型可以是枚举、具名字段结构体、元组结构体或单元结构体：

```rust
use thiserror::Error;

// 具名字段结构体
#[derive(Error, Debug)]
#[error("validation failed: {field} is invalid ({reason})")]
pub struct ValidationError {
    pub field: String,
    pub reason: String,
}

// 元组结构体
#[derive(Error, Debug)]
#[error("parse error at position {0}: {1}")]
pub struct ParseError(usize, String);

// 单元结构体
#[derive(Error, Debug)]
#[error("service unavailable")]
pub struct ServiceUnavailableError;

// 枚举中混合使用
#[derive(Error, Debug)]
pub enum ComplexError {
    #[error("named field variant: x={x}, y={y}")]
    Point { x: f64, y: f64 },

    #[error("tuple variant: ({0}, {1})")]
    Pair(String, i32),

    #[error("unit variant: done")]
    Done,
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
```

运行结果：

```
underlying error details
```

`transparent` 的典型用途包括：包装 `anyhow::Error` 作为枚举的兜底变体；将内部错误表示的具体实现隐藏在 opaque public type 之后，使内部表示可以在不破坏公开 API 的前提下自由演进。

## 七、Backtrace 支持

`thiserror` 支持通过 `Backtrace` 字段自动捕获栈回溯。使用 `Backtrace` 需要 Rust 1.73+ 并启用 nightly：

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

`thiserror` 和 `anyhow` 均来自 dtolnay之手，适用于不同场景：

| 维度 | thiserror | anyhow |
|------|-----------|--------|
| 定位 | 定义专用错误类型 | 使用通用错误类型 |
| 适用场景 | 库代码（需要公开错误 API） | 应用代码（不关心具体错误类型） |
| API 影响 | 不进入公开 API，可与手写实现互换 | 进入公开 API，返回 `Result<T, anyhow::Error>` |
| 灵活性 | 高，由你定义每个错误变体的结构 | 中，所有错误统一为一种类型 |

简言之：编写库代码时使用 `thiserror` 定义清晰的错误类型；编写应用代码时使用 `anyhow` 简化错误传播。

## 九、错误描述国际化

### 9.1 `thiserror` 不支持国际化

`thiserror` 的 `#[error("...")]` 属性接受的是编译期字符串字面量，`Display` trait 的实现由 derive 宏在编译时生成。这意味着错误消息的内容在编译阶段就固定了，无法在运行时根据语言环境动态切换。

以下代码展示了这一限制的根源：

```rust
#[derive(Error, Debug)]
pub enum Error {
    #[error("数据文件断开连接")] // 硬编码的中文字符串
    Disconnect,
}
```

编译器将 `"数据文件断开连接"` 直接嵌入生成的 `Display` 实现中，运行时不存在任何查表的逻辑。

### 9.2 原因分析

`thiserror` 的设计哲学是提供与手写 `Error` trait 实现完全等价的能力——生成的代码与手工编写无异。而 `std::error::Error` 的 `Display` trait 本身设计为接收一个 `&self` 和 `&mut Formatter`，参数中不包含 locale 或语言上下文。Rust 标准库的错误处理体系中根本没有国际化的基础设施。

因此，即使 `thiserror` 想支持国际化，也面临两个根本障碍：`Display` trait 签名中不存在 locale 参数；`thiserror` 生成的代码是静态的，没有运行时查找机制。

### 9.3 替代方案

如果项目确实需要错误消息国际化，有以下几种思路：

**方案一：错误码而非错误文本**

将错误定义为携带错误码（通常是数值或字符串标识符），由调用方根据错误码查表获取本地化消息：

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("ERR_DISCONNECT: 0x{:08x}")]
    Disconnect(u32),
}

impl Error {
    pub fn error_code(&self) -> &'static str {
        match self {
            Error::Disconnect(_) => "ERR_DISCONNECT",
        }
    }
}
```

调用方根据 `error_code()` 查表返回对应语言的消息。

**方案二：使用 `fluent-rs` 替代字符串字面量**

`fluent-rs` 是 Mozilla 维护的国际化系统，通过 FTL（Fluent）文件定义翻译资源。可以将错误码作为 message ID，通过 `fluent-rs` 查找翻译：

```rust
use fluent::{FluentBundle, FluentResource, FluentArgs};
use fluent::syntax::parser::parse;

fn get_localized_message(bundle: &FluentBundle<FluentResource>, error_code: &str) -> String {
    let msg = bundle.get_message(error_code)
        .expect("error message not found");
    let pattern = msg.value().expect("no pattern");
    // 使用 pattern.format(bundle, &args) 进行格式化
    pattern.to_string()
}
```

但需要注意，`thiserror` 的 `#[error("...")]` 仍然只能接受字面量，因此这种方案实际上放弃了使用 `thiserror` 的消息模板功能，改由调用方在 `Display` 之外单独处理国际化。

**方案三：手动实现 `Display`**

完全不使用 `thiserror` 的 `#[error]` 属性，手动实现 `Display` trait 并在实现中调用翻译函数：

```rust
use std::error::Error;
use std::fmt;

pub enum Error {
    Disconnect,
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Error::Disconnect => {
                write!(f, "{}", translate("err_disconnect"))
            }
        }
    }
}

fn translate(id: &str) -> String {
    // 调用翻译系统
    id.to_string()
}
```

此方案失去了 derive 宏的便利性，但获得了完整的国际化能力。

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
```

应用层根据 `code()` 查 `fluent` 或其他 i18n 系统得到本地化消息，同时保留 `Display` 在日志和控制台输出中提供可读但不依赖特定语言的默认信息。
