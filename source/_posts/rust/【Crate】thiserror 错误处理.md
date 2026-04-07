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
use thiserror::Error;

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
use thiserror::Error;

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

`#[from]` 属性为包含错误源字段的变体自动生成 `From` trait 实现，使错误可以在 `?` 运算符中自动转换。

### 用于 enum 变体

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
    let n: i32 = s.parse()?;
    Ok(n)
}

fn read_file() -> Result<Vec<u8>, MyError> {
    let _ = std::fs::read("nonexistent.txt")?;
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

### 用于 struct 字段

`#[from]` 也可以用在 struct 的具名字段上，但此时 struct **不能包含其他普通字段**（只能有 source 字段和可选的 backtrace 字段）。如果需要额外上下文，建议通过 `From` impl 或构造函数注入：

```rust
use std::io;
use thiserror::Error;

#[derive(Error, Debug)]
#[error("IO error occurred")]
pub struct IoError {
    #[from]
    source: io::Error,
}

fn read_file(path: &str) -> Result<String, IoError> {
    let s = std::fs::read_to_string(path)?; // io::Error 自动转换为 IoError
    Ok(s)
}

fn main() {
    if let Err(e) = read_file("/nonexistent/file") {
        println!("{}", e);
    }
}
```

运行结果：

```
IO error occurred
```

`#[from]` 隐含 `#[source]` 语义，无需同时标记两个属性。使用 `#[from]` 的字段只能是错误源（可能有 `Backtrace`），不能包含其他普通字段。

### 变体同时需要 `#[from]` 和额外上下文

`#[from]` 的约束是：使用 `#[from]` 的变体，其字段**只能是 source 字段**（和可选 backtrace），不能混合存储额外上下文。因此，如果希望变体既能通过 `?` 自动转换、又携带额外结构化信息，必须**放弃 `#[from]`，改用 `#[source]` 配合手动 `From` impl**：

```rust
use std::io;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum MyError {
    #[error("IO error while {operation}: {source}")]
    Io {
        operation: String,      // 额外上下文
        #[source]
        source: io::Error,      // source 字段，但不用 #[from]
    },

    #[error("parse error in {field}: {source}")]
    Parse {
        field: String,
        source: std::num::ParseIntError,
    },
}

impl From<io::Error> for MyError {
    fn from(e: io::Error) -> Self {
        MyError::Io { operation: "reading".to_string(), source: e }
    }
}

impl From<std::num::ParseIntError> for MyError {
    fn from(e: std::num::ParseIntError) -> Self {
        MyError::Parse { field: "user_id".to_string(), source: e }
    }
}

fn main() {
    fn read_config() -> Result<String, MyError> {
        let _ = std::fs::read("/nonexistent/file")?;
        Ok("ok".to_string())
    }

    if let Err(e) = read_config() {
        println!("{}", e);
    }
}
```

运行结果：

```
IO error while reading: No such file or directory (os error 2)
```

变体内使用 `#[source]` 标记错误源字段（而非 `#[from]`），由开发者手动实现 `From` impl，在转换时注入额外上下文。这样既保留了 `?` 的自动转换能力，又能让错误携带结构化的附加信息。

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
| 用于 enum 变体 | ✅ | ✅ |
| 用于 struct 字段 | ✅ | ✅（但所有字段必须均为 source/backtrace） |
| 字段名非 `source` 时可用 | ✅ | ❌（字段名需与底层错误类型一致） |

`#[from]` 用于 struct 字段时，struct 中不能包含其他普通字段（只能是 source/backtrace 字段）。如果需要额外上下文，建议通过 `From` impl 或构造函数方式注入，而非作为 struct 字段。

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

`#[error(transparent)]` 将 `Display` 和 `source` 方法直接转发到底层错误类型，不添加额外消息。以下是两个典型用法。

### 用法一：enum 的兜底变体

当 enum 中存在"其他未知错误"变体时，用 `transparent` 包装 `anyhow::Error` 或其他通用错误类型：

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

### 用法二：opaque public type（内部实现可演进）

将内部错误表示的具体实现隐藏在公开的 opaque 错误类型之后，使内部表示可以在不破坏公开 API 的前提下自由演进。`PublicError` 对外公开但内部结构不可见，`ErrorRepr` 则是私有实现细节：

```rust
use thiserror::Error;

// 对外公开但内部结构不可见，opaque public type
#[derive(Error, Debug)]
#[error(transparent)]
pub struct PublicError(#[from] ErrorRepr);

// 私有实现，可自由演进，不影响公开 API
#[derive(Error, Debug)]
enum ErrorRepr {
    #[error("file not found: {0}")]
    FileNotFound(String),

    #[error("permission denied")]
    PermissionDenied,
}

impl PublicError {
    // 公开访问器，只暴露必要信息
    pub fn is_file_not_found(&self) -> bool {
        matches!(self.0, ErrorRepr::FileNotFound(_))
    }
}

fn main() {
    let err = PublicError::from(ErrorRepr::FileNotFound("/etc/passwd".to_string()));
    println!("{}", err);
    println!("is file not found: {}", err.is_file_not_found());
}
```

运行结果：

```
file not found: /etc/passwd
is file not found: true
```

### `transparent` vs 普通变体对比

| 特性 | 普通变体 `#[error("...")]` | `#[error(transparent)]` |
|------|--------------------------|------------------------|
| 消息内容 | 使用模板字符串自定义 | 直接透传底层错误消息 |
| `Display` 转发 | 不转发 | 转发到底层错误类型 |
| `Error::source()` 转发 | 不转发 | 转发到底层错误类型 |
| 典型用途 | 已知具体错误类型 | 兜底变体或 opaque type |



## 七、thiserror 与 anyhow 的选择

`thiserror` 和 `anyhow` 均来自 `dtolnay` 之手，适用于不同场景：

| 维度 | thiserror | anyhow |
|------|-----------|--------|
| 定位 | 定义专用错误类型 | 使用通用错误类型 |
| 适用场景 | 库代码（需要公开错误 API） | 应用代码（不关心具体错误类型） |
| API 影响 | 不进入公开 API，可与手写实现互换 | 进入公开 API，返回 `Result<T, anyhow::Error>` |
| 灵活性 | 高，由 `you` 定义每个错误变体的结构 | 中，所有错误统一为一种类型 |

简言之：编写库代码时使用 `thiserror` 定义清晰的错误类型；编写应用代码时使用 `anyhow` 简化错误传播。

