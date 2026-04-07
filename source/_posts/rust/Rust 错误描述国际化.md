---
title: Rust 错误描述国际化
date: 2026-04-07 16:51:00
tags:
  - 错误处理
  - 国际化
  - i18n
categories: Rust
---

## 一、问题背景

`std::error::Error` trait 的 `Display` trait 方法签名如下：

```rust
fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result;
```

该签名中不存在 locale 或语言上下文参数，`std::fmt::Formatter` 本身也不携带语言环境信息。因此 `std::error::Error` 的设计从根源上就不支持国际化。

`thiserror` 的 `#[error("...")]` 属性接受编译期字符串字面量，derive 宏在编译阶段生成 `Display` trait 实现，运行时不存在任何翻译查找逻辑。以下代码展示了这一限制：

```rust
#[derive(Error, Debug)]
pub enum DataStoreError {
    #[error("data store disconnected")] // 硬编码，编译时固定
    Disconnect,
}
```

编译器将 `"data store disconnected"` 直接嵌入生成的代码，运行时无法切换为 `"数据存储连接断开"`。

因此，如果项目需要多语言错误消息，不能依赖 `thiserror` 的 `#[error]` 属性，需要另行设计。

## 二、主流方案

Rust 生态中，处理错误描述国际化的主流方案有以下三种：

| 方案 | 核心思路 | 优点 | 缺点 |
|------|---------|------|------|
| 错误码 + 翻译表 | 错误只携带代码和结构化数据，翻译由调用方或翻译层负责 | 简单、灵活、兼容性好 | 调用方需额外处理翻译 |
| fluent-rs | Mozilla 主导的本地化系统，通过 FTL 文件定义消息 | 支持复数、性别、占位符等复杂特性 | API 较底层，较复杂 |
| rust-i18n | 从 YAML/JSON 文件加载翻译宏，编译时生成 | 用法简单，YAML 文件易于维护 | `t!` 宏需要编译期字符串字面量，不支持运行时 key 查找 |

## 三、方案一：错误码 + 翻译表

### 3.1 核心设计

错误类型只携带错误码（字符串标识符）和结构化参数，`Display` trait 的实现调用翻译函数查找消息：

```rust
use std::error::Error as StdError;
use std::fmt;

// 错误码定义
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ErrorCode {
    DbConnectionFailed,
    DbQueryTimeout,
    ConfigMissingKey,
    ConfigInvalidValue,
}

// 翻译表（实际项目替换为 rust-i18n 或数据库）
fn translations(lang: &str) -> std::collections::HashMap<&'static str, &'static str> {
    match lang {
        "zh-CN" => {
            let mut m = std::collections::HashMap::new();
            m.insert("db.connection_failed", "数据库连接失败: {reason}");
            m.insert("db.query_timeout", "数据库查询超时 ({seconds}秒)");
            m.insert("config.missing_key", "缺少配置项: {key}");
            m.insert("config.invalid_value", "配置项 '{key}' 的值无效: {value}");
            m
        }
        _ => {
            let mut m = std::collections::HashMap::new();
            m.insert("db.connection_failed", "Database connection failed: {reason}");
            m.insert("db.query_timeout", "Database query timeout ({seconds}s)");
            m.insert("config.missing_key", "Missing configuration key: {key}");
            m.insert("config.invalid_value", "Invalid value for key '{key}': {value}");
            m
        }
    }
}

fn translate(key: &str, lang: &str) -> String {
    translations(lang)
        .get(key)
        .cloned()
        .unwrap_or(key)
        .to_string()
}
```

### 3.2 统一错误类型

```rust
// 统一错误类型：携带错误码 + 结构化参数
#[derive(Debug)]
pub struct AppError {
    code: ErrorCode,
    params: Vec<(String, String)>,
}

impl AppError {
    pub fn new(code: ErrorCode) -> Self {
        Self { code, params: vec![] }
    }

    pub fn with_param(mut self, k: impl Into<String>, v: impl Into<String>) -> Self {
        self.params.push((k.into(), v.into()));
        self
    }

    pub fn code(&self) -> ErrorCode {
        self.code
    }
}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let key = match self.code {
            ErrorCode::DbConnectionFailed => "db.connection_failed",
            ErrorCode::DbQueryTimeout => "db.query_timeout",
            ErrorCode::ConfigMissingKey => "config.missing_key",
            ErrorCode::ConfigInvalidValue => "config.invalid_value",
        };
        let lang = LOCALE.read().unwrap();
        let mut msg = translate(key, lang);
        // 替换占位符
        for (k, v) in &self.params {
            msg = msg.replace(&format!("{{{}}}", k), v);
        }
        write!(f, "{}", msg)
    }
}

impl StdError for AppError {}

// 辅助构造函数
impl AppError {
    pub fn db_connection_failed(reason: impl Into<String>) -> Self {
        Self::new(ErrorCode::DbConnectionFailed).with_param("reason", reason)
    }

    pub fn config_missing_key(key: impl Into<String>) -> Self {
        Self::new(ErrorCode::ConfigMissingKey).with_param("key", key)
    }

    pub fn config_invalid_value(key: impl Into<String>, value: impl Into<String>) -> Self {
        Self::new(ErrorCode::ConfigInvalidValue)
            .with_param("key", key)
            .with_param("value", value)
    }
}

// 全局语言设置
static LOCALE: std::sync::RwLock<&'static str> = std::sync::RwLock::new("en");

fn set_locale(s: &'static str) {
    *LOCALE.write().unwrap() = s;
}

fn main() {
    println!("=== 英文环境 ===");
    set_locale("en");

    println!("{}", AppError::db_connection_failed("connection refused"));
    println!("{}", AppError::config_missing_key("database.url"));
    println!("{}", AppError::config_invalid_value("port", "not a number"));

    println!("\n=== 中文环境 ===");
    set_locale("zh-CN");

    println!("{}", AppError::db_connection_failed("connection refused"));
    println!("{}", AppError::config_missing_key("database.url"));
    println!("{}", AppError::config_invalid_value("port", "not a number"));
}
```

运行结果：

```
=== 英文环境 ===
Database connection failed: connection refused
Missing configuration key: database.url
Invalid value for key 'port': not a number

=== 中文环境 ===
数据库连接失败: connection refused
缺少配置项: database.url
配置项 'port' 的值无效: not a number
```

### 3.3 与 `thiserror` 结合

上述方案完全独立于 `thiserror`，如果希望在已有 `thiserror` 错误类型中增加 i18n 能力，可以为每个错误变体添加 `code()` 方法返回错误码，上层根据错误码查翻译表：

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DataStoreError {
    #[error("data store disconnected")]
    Disconnect,

    #[error("connection failed: {reason}")]
    ConnectionFailed { reason: String },
}

impl DataStoreError {
    pub fn code(&self) -> &'static str {
        match self {
            DataStoreError::Disconnect => "ERR_DISCONNECT",
            DataStoreError::ConnectionFailed { .. } => "ERR_CONNECTION_FAILED",
        }
    }
}
```

应用层根据 `code()` 查翻译表获取本地化消息，`Display` 仍用于日志和调试输出。

## 四、方案二：rust-i18n

`rust-i18n` 是 Rust 生态中最易用的国际化库，支持 YAML/JSON 格式的翻译文件，翻译在编译时打包进二进制，运行时通过 `t!` 宏读取。

### 4.1 安装与配置

在 `Cargo.toml` 中添加依赖，并在项目根目录创建 `locales/` 目录：

```toml
[dependencies]
rust-i18n = "3"
```

在 `Cargo.toml` 中配置可用语言：

```toml
[package.metadata.i18n]
available-locales = ["en", "zh-CN"]
default-locale = "en"
load-path = "locales"
```

在 `main.rs` 开头初始化：

```rust
rust_i18n::i18n!("locales");
```

### 4.2 翻译文件

在 `locales/app.yml` 中定义翻译：

```yaml
db.connection_failed:
  en: "Database connection failed: {reason}"
  zh-CN: "数据库连接失败: {reason}"

config.missing_key:
  en: "Missing configuration key: {key}"
  zh-CN: "缺少配置项: {key}"

messages.saved:
  en: "Data saved successfully"
  zh-CN: "数据保存成功"
```

### 4.3 在代码中使用

```rust
rust_i18n::i18n!("locales");

fn main() {
    // 设置全局语言
    rust_i18n::set_locale("zh-CN");

    // 获取翻译（支持占位符替换）
    let msg = t!("db.connection_failed", reason = "connection refused");
    println!("{}", msg); // 数据库连接失败: connection refused

    // 查询所有可用语言
    println!("{:?}", rust_i18n::available_locales!()); // ["en", "zh-CN"]
}
```

`rust-i18n` 的 `t!` 宏接受编译期字符串字面量作为 key，**不支持运行时 key 变量**。因此与 `thiserror` 结合时，只能在手动实现的 `Display` 中使用 `t!` 宏，而不能用于运行时动态查表。

## 五、方案三：fluent-rs

fluent-rs 是 Mozilla 主导的本地化系统，比 rust-i18n 更强大，支持复数形式、性别语法、条件逻辑等复杂翻译场景。

### 5.1 安装

```toml
[dependencies]
fluent = "0.16"
unic-langid = "0.9"
```

### 5.2 基本用法

FTL（Fluent）文件格式：

```ftl
# locales/app.ftl
err-disconnect = 数据文件断开连接
err-disconnect-en = Data store disconnected
```

在 Rust 中使用：

```rust
use fluent::{FluentBundle, FluentResource};
use fluent::syntax::parser::parse;
use unic_langid::LanguageIdentifier;

fn main() {
    let ftl = "
err-disconnect = 数据文件断开连接
err-disconnect-en = Data store disconnected
";
    let resource = parse(ftl, 0).into_iter().next().unwrap();
    let langid: LanguageIdentifier = "zh-CN".parse().unwrap();
    let mut bundle = FluentBundle::new(vec![langid]);
    bundle.add_resource(resource).expect("failed to add resource");

    let msg = bundle.get_message("err-disconnect")
        .expect("message not found");
    let pattern = msg.value().expect("no pattern");
    let value = bundle.format_pattern(&pattern, None, &mut vec![]);

    println!("{}", value); // 数据文件断开连接
}
```

## 六、方案对比与选择

| 维度 | 错误码 + 翻译表 | rust-i18n | fluent-rs |
|------|----------------|-----------|-----------|
| 翻译格式 | HashMap / JSON / YAML | YAML / JSON / TOML | FTL |
| 运行时 key 查找 | ✅ 支持 | ❌ 只支持编译期字面量 | ✅ 支持 |
| 复数/性别支持 | ❌ | ❌ | ✅ |
| 翻译工具链 | 自建或用现成 i18n 工具 | 有 VS Code I18n Ally 插件 | 有专业工具支持 |
| 与 `thiserror` 结合 | ✅ 通过 `code()` 方法 | ✅ 仅限手动 Display | ✅ |
| 学习成本 | 低 | 中 | 高 |
| 适用场景 | 错误消息为主的场景 | 完整应用国际化 | 复杂多语言场景 |

## 七、推荐做法

实际项目中的最佳实践是**错误码与翻译分离**：

- 错误定义层（库/模块）：使用 `thiserror` 定义错误变体，通过 `code()` 方法暴露错误码，Display 用于日志（默认语言）
- 翻译层（应用）：根据错误码在翻译文件中查找对应语言的消息

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DbError {
    #[error("connection failed")]
    ConnectionFailed,

    #[error("query timeout")]
    QueryTimeout,
}

impl DbError {
    pub fn code(&self) -> &'static str {
        match self {
            DbError::ConnectionFailed => "ERR_DB_CONNECTION_FAILED",
            DbError::QueryTimeout => "ERR_DB_QUERY_TIMEOUT",
        }
    }
}
```

调用方根据 `code()` 查翻译系统得到本地化消息，同时保留原始 `Display` 用于日志和调试输出。这样既利用了 `thiserror` 的便利性，又不牺牲国际化能力。
