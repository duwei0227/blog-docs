---
title: "[Crate] tracing 与 tracing-appender 日志实战"
published: true
layout: post
date: 2026-06-05 09:01:08
permalink: /rust/tracing.html
tags:
  - 日志
  - 链路跟踪
  - 文件滚动
  - 结构化日志
categories: Rust
---

`tracing` 是 Rust 生态中常用的结构化日志和链路跟踪框架。它不只记录一行日志，还可以把请求 ID、业务字段、函数参数、错误信息和调用链路一起记录下来。`tracing-appender` 则提供文件写入、非阻塞写入和按时间滚动的能力，适合服务端程序、命令行工具和后台任务使用。

本文讲解如何使用 `tracing` 与 `tracing-appender` 实现控制台与文件同时输出、自定义日志格式、span 链路跟踪、函数出入参记录和日志文件滚动。

## 一、为什么选择 tracing

传统日志通常以文本行为中心，例如“某个时间发生了某条消息”。`tracing` 的核心思想是把日志事件和上下文一起记录下来，尤其适合有请求链路、异步任务、跨函数调用和结构化字段的程序。

`tracing` 中最常见的概念如下：

| 概念 | 说明 |
|------|------|
| `event` | 一次日志事件，例如 `info!`、`warn!`、`error!` 产生的记录 |
| `span` | 一段执行上下文，例如一次 HTTP 请求、一次数据库查询、一个后台任务 |
| `field` | 结构化字段，例如 `request_id = 1001`、`user_id = 7` |
| `subscriber` | 日志收集和分发入口，负责接收 event 与 span |
| `layer` | 日志处理层，可以分别输出到控制台、文件、JSON 或自定义格式 |
| `appender` | 写入目标，`tracing-appender` 提供文件写入和滚动文件写入 |

常见选择可以按下面的方式理解：

| 场景 | 推荐方式 |
|------|----------|
| 只需要简单控制台日志 | `tracing_subscriber::fmt()` |
| 需要同时输出到控制台和文件 | `registry()` 组合多个 `fmt::Layer` |
| 需要记录请求链路 | 使用 `span` 或 `#[instrument]` |
| 需要日志文件滚动 | 使用 `tracing_appender::rolling` |
| 不希望业务线程被文件 IO 阻塞 | 使用 `tracing_appender::non_blocking` |

## 二、安装与依赖

在 `Cargo.toml` 中添加依赖：

```toml
[dependencies]
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "fmt", "json"] }
tracing-appender = "0.2"
tokio = { version = "1", features = ["macros", "rt-multi-thread", "time"] }
```

依赖说明：

| 依赖 | 作用 |
|------|------|
| `tracing` | 提供 `info!`、`warn!`、`error!`、`span`、`#[instrument]` 等核心 API |
| `tracing-subscriber` | 提供 subscriber、formatter、layer、过滤器等组件 |
| `tracing-appender` | 提供文件 appender、非阻塞 writer、滚动文件 writer |
| `tokio` | 只用于本文异步 span 示例；同步项目可以不引入 |

## 三、快速开始

最小示例只需要初始化一个默认 subscriber，然后使用 `info!`、`warn!` 等宏输出日志。

**示例：**

```rust
use tracing::{info, warn};

fn main() {
    let subscriber = tracing_subscriber::fmt()
        .without_time()
        .with_target(false)
        .finish();

    tracing::subscriber::with_default(subscriber, || {
        info!("service started");
        warn!(port = 8080, "port is already in use, fallback to random port");
    });
}
```

运行结果：

```text
 INFO service started
 WARN port is already in use, fallback to random port port=8080
```

这个示例中有两个细节：

| 配置 | 说明 |
|------|------|
| `without_time()` | 关闭时间输出，便于观察固定格式；生产环境通常保留时间 |
| `with_target(false)` | 不输出模块路径，使日志更短 |

`warn!(port = 8080, "...")` 中的 `port` 不是拼接到字符串里，而是一个结构化字段。后续输出 JSON 或接入日志平台时，这类字段更容易检索和聚合。

## 四、同时输出到控制台和文件

实际项目中通常希望日志既能在控制台看到，也能写入文件。`tracing_subscriber::registry()` 可以组合多个 `Layer`，每个 `Layer` 指向不同 writer。

下面示例把同一批日志同时写到标准输出和 `logs/app.log`。文件写入使用 `tracing_appender::non_blocking`，避免业务线程直接阻塞在文件 IO 上。

**示例：**

```rust
use std::error::Error;
use std::fs;
use tracing::{error, info};
use tracing_appender::rolling;
use tracing_subscriber::prelude::*;

fn main() -> Result<(), Box<dyn Error>> {
    fs::remove_dir_all("logs").ok();
    fs::create_dir_all("logs")?;

    let file_appender = rolling::never("logs", "app.log");
    let (file_writer, guard) = tracing_appender::non_blocking(file_appender);

    let console_layer = tracing_subscriber::fmt::layer()
        .without_time()
        .with_target(false)
        .with_writer(std::io::stdout);

    let file_layer = tracing_subscriber::fmt::layer()
        .without_time()
        .with_ansi(false)
        .with_target(false)
        .with_writer(file_writer);

    let subscriber = tracing_subscriber::registry()
        .with(console_layer)
        .with(file_layer);

    tracing::subscriber::with_default(subscriber, || {
        info!(request_id = 1001, "request accepted");
        error!(request_id = 1001, reason = "db timeout", "request failed");
    });

    drop(guard);

    println!("--- logs/app.log ---");
    print!("{}", fs::read_to_string("logs/app.log")?);

    Ok(())
}
```

运行结果：

```text
 INFO request accepted request_id=1001
ERROR request failed request_id=1001 reason="db timeout"
--- logs/app.log ---
 INFO request accepted request_id=1001
ERROR request failed request_id=1001 reason="db timeout"
```

关键点：

| 代码 | 说明 |
|------|------|
| `rolling::never("logs", "app.log")` | 写入固定文件，不滚动 |
| `non_blocking(file_appender)` | 将文件写入改为非阻塞写入 |
| `guard` | 保证后台写入线程在程序退出前刷新日志 |
| `with_ansi(false)` | 文件中不要写入控制台颜色转义字符 |
| 两个 `fmt::Layer` | 同一条日志分别写入控制台和文件 |

> 注意：`guard` 不能被提前丢弃。生产代码中通常把它保存在 `main` 函数生命周期内，例如命名为 `_guard`。

## 五、自定义输出格式

`tracing_subscriber::fmt::layer()` 已经提供了紧凑格式、完整格式、JSON 格式等内置格式。如果项目需要统一公司内部日志格式，可以实现 `FormatEvent` 自定义 event 的输出。

下面示例实现一个简单格式：

```text
[LEVEL] target span=span_name field=value message=...
```

**示例：**

```rust
use std::fmt;
use tracing::field::{Field, Visit};
use tracing::{info, info_span, Event, Subscriber};
use tracing_subscriber::fmt::format::{FormatEvent, FormatFields, Writer};
use tracing_subscriber::fmt::FmtContext;
use tracing_subscriber::prelude::*;
use tracing_subscriber::registry::LookupSpan;

struct SimpleFormat;

impl<S, N> FormatEvent<S, N> for SimpleFormat
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'writer> FormatFields<'writer> + 'static,
{
    fn format_event(
        &self,
        ctx: &FmtContext<'_, S, N>,
        mut writer: Writer<'_>,
        event: &Event<'_>,
    ) -> fmt::Result {
        let metadata = event.metadata();
        write!(writer, "[{}] {}", metadata.level(), metadata.target())?;

        if let Some(scope) = ctx.event_scope() {
            let names = scope
                .from_root()
                .map(|span| span.name())
                .collect::<Vec<_>>()
                .join("::");
            write!(writer, " span={names}")?;
        }

        let mut visitor = FieldVisitor::default();
        event.record(&mut visitor);
        if !visitor.fields.is_empty() {
            write!(writer, " {}", visitor.fields.join(" "))?;
        }

        writeln!(writer)
    }
}

#[derive(Default)]
struct FieldVisitor {
    fields: Vec<String>,
}

impl Visit for FieldVisitor {
    fn record_debug(&mut self, field: &Field, value: &dyn fmt::Debug) {
        self.fields.push(format!("{}={value:?}", field.name()));
    }
}

fn main() {
    let layer = tracing_subscriber::fmt::layer().event_format(SimpleFormat);
    let subscriber = tracing_subscriber::registry().with(layer);

    tracing::subscriber::with_default(subscriber, || {
        let span = info_span!("checkout", order_id = 42);
        let _enter = span.enter();
        info!(amount = 199, "order paid");
    });
}
```

运行结果：

```text
[INFO] custom_format span=checkout message=order paid amount=199
```

这个示例中，`metadata.level()` 输出日志级别，`metadata.target()` 输出模块目标，`ctx.event_scope()` 可以拿到当前 event 所处的 span 链路，`event.record(&mut visitor)` 用于读取 event 字段。

> 注意：自定义格式会接管 event 的渲染逻辑。生产项目中要明确字段顺序、时间格式、错误格式和换行规则，否则后续日志采集会比较困难。

## 六、span 链路跟踪

`span` 表示一段执行上下文。一个请求进入系统后，可以创建请求级 span；执行数据库查询时，可以在请求 span 内再创建数据库 span。日志事件发生时，subscriber 可以知道它位于哪条链路中。

下面示例使用 JSON 格式输出当前 span 和完整 span 列表。

**示例：**

```rust
use tracing::{info, info_span};
use tracing_subscriber::prelude::*;

fn main() {
    let layer = tracing_subscriber::fmt::layer()
        .json()
        .without_time()
        .with_current_span(true)
        .with_span_list(true);
    let subscriber = tracing_subscriber::registry().with(layer);

    tracing::subscriber::with_default(subscriber, || {
        let request_span = info_span!("http.request", request_id = 7, path = "/orders");
        let _request_guard = request_span.enter();

        let db_span = info_span!("db.query", table = "orders");
        let _db_guard = db_span.enter();

        info!(rows = 1, "query finished");
    });
}
```

运行结果：

```json
{"level":"INFO","fields":{"message":"query finished","rows":1},"target":"span_chain","span":{"table":"orders","name":"db.query"},"spans":[{"path":"/orders","request_id":7,"name":"http.request"},{"table":"orders","name":"db.query"}]}
```

字段说明：

| 字段 | 说明 |
|------|------|
| `fields` | 当前日志事件自己的字段 |
| `span` | 当前所在的最内层 span |
| `spans` | 从外到内的 span 链路 |
| `request_id` | 请求级上下文字段 |
| `table` | 数据库查询上下文字段 |

在异步代码中，不建议长期依赖手动 `.enter()` 跨越 `.await`。更常见的方式是使用 `.instrument(span)` 把 span 绑定到 future 上。

**异步示例：**

```rust
use std::error::Error;
use tracing::{info, info_span, Instrument};
use tracing_subscriber::prelude::*;

fn main() -> Result<(), Box<dyn Error>> {
    let layer = tracing_subscriber::fmt::layer()
        .without_time()
        .with_target(false);
    let subscriber = tracing_subscriber::registry().with(layer);
    let runtime = tokio::runtime::Runtime::new()?;

    tracing::subscriber::with_default(subscriber, || {
        runtime.block_on(async {
            let span = info_span!("worker", job_id = 11);
            async {
                info!(step = "load", "async job finished");
            }
            .instrument(span)
            .await;
        });
    });

    Ok(())
}
```

运行结果：

```text
 INFO worker{job_id=11}: async job finished step="load"
```

## 七、函数出入参记录

`#[instrument]` 可以自动为函数创建 span，并把函数参数记录为 span 字段。它适合服务入口、任务处理函数、数据库访问函数、关键业务函数等位置。

在看示例之前，先了解 `#[instrument]` 支持的完整参数结构。所有参数都是可选的，可按需组合：

```rust
#[instrument(
    // —— 基础 ——
    name = "custom_name",      // 覆盖 span 名，默认使用函数名
    level = "info",            // span 与自动事件的级别，可写 "trace"/"debug"/"info"/"warn"/"error"，
                               // 也可写 Level::INFO 或数字 1..=5
    target = "my_app::svc",    // 覆盖事件 target，默认是当前模块路径

    // —— 参数记录控制 ——
    skip(secret, conn),        // 不记录指定参数（敏感信息、大对象、连接等）
    skip_all,                  // 不记录任何函数参数
    fields(user_id = user_id, // 显式新增或覆盖字段；右侧可用表达式
           req_id = tracing::field::Empty),  // 用 Empty 占位，后续可通过 span.record() 补值

    // —— span 关系 ——
    parent = some_span,        // 显式指定父 span，默认取当前上下文中的 span
    follows_from = cause_id,   // 添加 follows-from（因果而非父子）关系

    // —— 返回值与错误 ——
    ret,                       // 函数返回时记录返回值，默认 Debug；可写 ret(level = "debug", Display)
    err,                       // 函数返回 Err 时记录错误，默认 Display；可写 err(Debug)
)]
fn some_function(/* ... */) { /* ... */ }
```

> 说明：`skip` 与 `skip_all` 用于排除参数，`fields` 用于补充字段，两者可同时出现；`ret` / `err` 仅对返回 `Result` 的函数有实际意义。括号内全部参数都可省略，最简写法就是裸 `#[instrument]`。

下面示例展示参数记录、跳过敏感参数、记录返回值和记录错误。

**示例：**

```rust
use tracing::{info, instrument};
use tracing_subscriber::prelude::*;

#[instrument(level = "info", skip(secret), fields(user_id = user_id), ret, err)]
fn create_order(user_id: u64, amount: u64, secret: &str) -> Result<String, String> {
    if amount == 0 {
        return Err("amount must be greater than zero".to_string());
    }

    info!(secret_len = secret.len(), "creating order");
    Ok(format!("order-{user_id}-{amount}"))
}

fn main() {
    let layer = tracing_subscriber::fmt::layer()
        .without_time()
        .with_target(false);
    let subscriber = tracing_subscriber::registry().with(layer);

    tracing::subscriber::with_default(subscriber, || {
        let _ = create_order(7, 128, "private-token");
        let _ = create_order(8, 0, "private-token");
    });
}
```

运行结果：

```text
 INFO create_order{amount=128 user_id=7}: creating order secret_len=13
 INFO create_order{amount=128 user_id=7}: return="order-7-128"
ERROR create_order{amount=0 user_id=8}: error=amount must be greater than zero
```

属性说明：

| 写法 | 说明 |
|------|------|
| `#[instrument]` | 自动创建与函数同名的 span |
| `level = "info"` | 指定 span 和自动事件的级别 |
| `skip(secret)` | 不记录 `secret` 参数，避免敏感信息进入日志 |
| `fields(user_id = user_id)` | 显式添加或覆盖 span 字段 |
| `ret` | 函数成功返回时记录返回值 |
| `err` | 函数返回错误时记录错误 |

> 注意：`#[instrument]` 默认会用 `Debug` 格式记录参数。大对象、二进制内容、密码、token、连接对象等不适合直接记录，应使用 `skip(...)` 或只记录摘要字段。

## 八、日志文件滚动

`tracing-appender` 的 `rolling` 模块提供按时间滚动的文件 writer。常用函数如下：

| 函数 | 说明 |
|------|------|
| `rolling::daily(dir, prefix)` | 按天滚动 |
| `rolling::hourly(dir, prefix)` | 按小时滚动 |
| `rolling::minutely(dir, prefix)` | 按分钟滚动 |
| `rolling::never(dir, file_name)` | 不滚动，写入固定文件 |

下面示例使用 `rolling::never` 生成固定文件，便于验证输出；同时构造 `daily`、`hourly`、`minutely`，验证这些滚动 writer 的 API 可以正常使用。

**示例：**

```rust
use std::error::Error;
use std::fs;
use std::path::Path;
use tracing::info;
use tracing_appender::rolling;
use tracing_subscriber::prelude::*;

fn main() -> Result<(), Box<dyn Error>> {
    fs::remove_dir_all("logs").ok();
    fs::create_dir_all("logs")?;

    let _daily = rolling::daily("logs", "daily.log");
    let _hourly = rolling::hourly("logs", "hourly.log");
    let _minutely = rolling::minutely("logs", "minutely.log");

    let file_appender = rolling::never("logs", "rolling-demo.log");
    let (file_writer, guard) = tracing_appender::non_blocking(file_appender);

    let layer = tracing_subscriber::fmt::layer()
        .without_time()
        .with_ansi(false)
        .with_target(false)
        .with_writer(file_writer);
    let subscriber = tracing_subscriber::registry().with(layer);

    tracing::subscriber::with_default(subscriber, || {
        info!("rolling file writer is ready");
    });

    drop(guard);

    println!("--- rolling files ---");
    for name in ["rolling-demo.log"] {
        let path = Path::new("logs").join(name);
        println!("{} exists: {}", path.display(), path.exists());
    }
    print!("{}", fs::read_to_string("logs/rolling-demo.log")?);

    Ok(())
}
```

运行结果：

```text
--- rolling files ---
logs/rolling-demo.log exists: true
 INFO rolling file writer is ready
```

> 注意：`tracing-appender` 主要提供按时间滚动能力。它不是 Logback 那种完整的文件归档策略引擎，按大小滚动、按总大小清理历史文件等能力需要额外实现或选择其他日志库。

## 九、完整实战示例

下面是一个整合版示例，包含控制台输出、文件输出、自定义格式、span 链路、异步 span、函数参数记录和滚动文件。为了方便阅读，这里保留核心代码结构；前文各小节已经分别解释每一部分的作用。

**示例：**

```rust
use std::error::Error;
use std::fs;
use tracing::{error, info, info_span, instrument, warn, Instrument};
use tracing_appender::rolling;
use tracing_subscriber::prelude::*;

#[instrument(level = "info", skip(secret), fields(user_id = user_id), ret, err)]
fn create_order(user_id: u64, amount: u64, secret: &str) -> Result<String, String> {
    if amount == 0 {
        return Err("amount must be greater than zero".to_string());
    }

    info!(secret_len = secret.len(), "creating order");
    Ok(format!("order-{user_id}-{amount}"))
}

fn main() -> Result<(), Box<dyn Error>> {
    fs::remove_dir_all("logs").ok();
    fs::create_dir_all("logs")?;

    let file_appender = rolling::never("logs", "app.log");
    let (file_writer, guard) = tracing_appender::non_blocking(file_appender);

    let console_layer = tracing_subscriber::fmt::layer()
        .without_time()
        .with_target(false)
        .with_writer(std::io::stdout);

    let file_layer = tracing_subscriber::fmt::layer()
        .without_time()
        .with_ansi(false)
        .with_target(false)
        .with_writer(file_writer);

    let subscriber = tracing_subscriber::registry()
        .with(console_layer)
        .with(file_layer);

    let runtime = tokio::runtime::Runtime::new()?;

    tracing::subscriber::with_default(subscriber, || {
        info!("service started");
        warn!(port = 8080, "port is already in use, fallback to random port");

        let request_span = info_span!("http.request", request_id = 1001);
        let _request_guard = request_span.enter();

        info!("request accepted");
        let _ = create_order(7, 128, "private-token");
        let _ = create_order(8, 0, "private-token");

        runtime.block_on(async {
            let span = info_span!("worker", job_id = 11);
            async {
                info!(step = "load", "async job finished");
            }
            .instrument(span)
            .await;
        });

        error!(reason = "db timeout", "request failed");
    });

    drop(guard);
    Ok(())
}
```

这个示例的重点不是业务逻辑，而是日志结构：

| 能力 | 对应代码 |
|------|----------|
| 控制台输出 | `console_layer` |
| 文件输出 | `file_layer` |
| 非阻塞写入 | `tracing_appender::non_blocking` |
| 请求链路 | `info_span!("http.request", request_id = 1001)` |
| 函数入参 | `#[instrument]` 自动记录 `amount`、`user_id` |
| 跳过敏感参数 | `skip(secret)` |
| 返回值和错误 | `ret`、`err` |
| 异步 span | `.instrument(span)` |

## 十、常见问题与最佳实践

### 10.1 guard 提前释放导致日志丢失

`tracing_appender::non_blocking` 会返回 writer 和 guard。writer 负责写入，guard 负责在退出时刷新后台缓冲。如果 guard 生命周期太短，程序结束前可能还有日志没有写入文件。

推荐写法：

```rust
let (file_writer, _guard) = tracing_appender::non_blocking(file_appender);
```

把 `_guard` 保存在 `main` 函数作用域中，不要在初始化函数内部直接丢弃。

### 10.2 subscriber 只能全局初始化一次

如果使用 `.init()` 或 `set_global_default()`，全局 subscriber 通常只能设置一次。测试代码或多段示例中，可以使用：

```rust
tracing::subscriber::with_default(subscriber, || {
    tracing::info!("only active in this closure");
});
```

这样可以避免多个示例重复初始化全局 subscriber。

### 10.3 文件日志关闭 ANSI 颜色

控制台日志可以保留颜色，但文件日志通常应该关闭 ANSI 转义字符：

```rust
let file_layer = tracing_subscriber::fmt::layer()
    .with_ansi(false);
```

否则日志文件中可能出现不可读的颜色控制字符。

### 10.4 敏感信息不要进入 span 字段

`#[instrument]` 很方便，但默认记录参数。下面这些信息不要直接记录：

| 信息 | 推荐做法 |
|------|----------|
| 密码、token、密钥 | `skip(...)` |
| 请求体、二进制数据 | 记录长度或哈希 |
| 用户隐私信息 | 脱敏后记录 |
| 大型对象 | 记录 ID 或摘要字段 |

### 10.5 滚动策略选择

| 场景 | 建议 |
|------|------|
| 本地开发 | `rolling::never` 或控制台输出 |
| 普通后台服务 | `rolling::daily` |
| 日志量较大 | `rolling::hourly` |
| 高频测试或短周期任务 | `rolling::minutely` |
| 需要按大小滚动 | 额外实现或选择其他日志库 |

## 十一、速查表

### 11.1 常用宏

| 宏 | 说明 |
|----|------|
| `trace!` | 最细粒度调试信息 |
| `debug!` | 调试信息 |
| `info!` | 普通业务信息 |
| `warn!` | 警告信息 |
| `error!` | 错误信息 |
| `span!` | 创建 span |
| `info_span!` | 创建 info 级别 span |

### 11.2 常用配置

| 配置 | 说明 |
|------|------|
| `without_time()` | 不输出时间 |
| `with_target(false)` | 不输出 target |
| `with_ansi(false)` | 关闭颜色 |
| `json()` | 输出 JSON 格式 |
| `with_current_span(true)` | JSON 中输出当前 span |
| `with_span_list(true)` | JSON 中输出完整 span 链路 |
| `with_writer(...)` | 指定输出目标 |

### 11.3 常用 instrument 参数

| 参数 | 说明 |
|------|------|
| `level = "info"` | 设置 span 级别 |
| `name = "..."` | 自定义 span 名称 |
| `skip(arg)` | 跳过参数 |
| `fields(...)` | 添加自定义字段 |
| `ret` | 记录返回值 |
| `err` | 记录错误 |

### 11.4 rolling API

| API | 说明 |
|-----|------|
| `rolling::daily` | 按天滚动 |
| `rolling::hourly` | 按小时滚动 |
| `rolling::minutely` | 按分钟滚动 |
| `rolling::never` | 不滚动 |
| `tracing_appender::non_blocking` | 非阻塞写入 |

## 十二、总结

`tracing` 的优势在于结构化日志和上下文传播。相比只输出字符串的日志框架，它可以把请求、函数、异步任务和业务字段组织成可查询的链路。`tracing-appender` 补充了文件写入和按时间滚动能力，让它更适合落地到实际服务中。

实际项目中可以按下面的顺序落地：

1. 先用 `tracing_subscriber::fmt()` 接入控制台日志。
2. 再通过 `registry()` 增加文件 `Layer`。
3. 文件 writer 使用 `tracing_appender::non_blocking`。
4. 请求入口、任务入口使用 `span` 或 `#[instrument]`。
5. 生产环境中明确过滤级别、字段规范和敏感信息策略。

如果只需要简单日志，`tracing` 的默认格式已经足够；如果需要排查跨函数、跨异步任务、跨请求的复杂问题，span 和结构化字段才是它真正有价值的部分。
