---
title: "[Crate] sqlx 数据库交互与连接池实战"
published: true
layout: post
date: 2026-06-11 09:00:00
permalink: /rust/sqlx.html
tags:
  - 数据库
  - MySQL
  - 连接池
  - CRUD
categories: Rust
---

`sqlx` 是一个**异步、纯 Rust** 的 SQL 工具包，支持 MySQL、PostgreSQL、SQLite。它和 `Diesel` 这类 ORM 走的是两条路：ORM 让你用 Rust 的方法链拼出 SQL，而 `sqlx` 让你**直接写 SQL 字符串**，再把结果映射回 Rust 类型——你写的 SQL 就是真正执行的 SQL，没有中间的 DSL 翻译层。它最有特色的地方在于 `query!` 宏：能在**编译期**连上数据库，校验你的 SQL 语法、表名列名是否存在、参数与返回类型是否对得上，把一类只能在运行时才暴露的错误提前到 `cargo build` 阶段。本文以 **MySQL** 为后端，从依赖引入讲起，依次覆盖连接池、CRUD、类型映射、事务，以及进阶的编译期检查宏，所有代码都在 `MySQL 8.4` 上实际跑通。

## 一、为什么选择 sqlx

在 Rust 生态里访问数据库，主要有两个方向：以 `Diesel` 为代表的 ORM，以及以 `sqlx` 为代表的「SQL 工具包」。理解 `sqlx` 解决了什么问题，得先看它的几个核心设计取舍：

- **异步优先**：`sqlx` 的每个查询都是 `async`，天然适配 `tokio` / `async-std` 运行时。在 Web 服务里，一次数据库往返期间线程不会被阻塞，可以去处理别的请求——这正是高并发服务需要的。
- **不发明 DSL**：你写 `"SELECT id, name FROM users WHERE age > ?"`，执行的就是这一句。ORM 的链式 API 在复杂查询（多表 JOIN、窗口函数、CTE）面前往往力不从心，而 `sqlx` 没有这个上限——SQL 能写的它都能跑。
- **编译期 SQL 校验**：通过 `query!` 宏，`sqlx` 在编译时连上数据库，把你的 SQL 拿到真实 schema 上验证一遍。写错列名、参数个数对不上、返回类型不匹配，统统编译报错。这是 ORM 也很难做到的安全性。
- **轻量、可控**：`sqlx` 不替你管理对象的「身份」与「脏检查」，它只负责「把 SQL 发出去，把结果拿回来」。心智负担小，行为可预测。

> 一句话区分：如果你想要「面向对象的数据模型 + 自动生成 SQL」，选 `Diesel`；如果你想要「自己掌控 SQL + 异步 + 编译期安全」，选 `sqlx`。

## 二、安装与依赖

`sqlx` 的功能由 Cargo feature 拼装而成，必须**至少选一个运行时、一个数据库驱动**，否则编译期就会报错提醒你。下面是本文用到的 `Cargo.toml`：

```toml
[dependencies]
sqlx = { version = "0.8", features = [
    "runtime-tokio",   # 异步运行时：tokio
    "tls-rustls",      # TLS 后端：纯 Rust 的 rustls
    "mysql",           # 数据库驱动：MySQL
    "chrono",          # 让 DATETIME/DATE 等映射到 chrono 类型
    "json",            # 让 JSON 列映射到 serde_json / Json<T>
] }
tokio = { version = "1", features = ["macros", "rt-multi-thread"] }
chrono = { version = "0.4", features = ["serde"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

常用 feature 一览（按用途分组）：

| Feature | 作用 | 是否必选 |
|---------|------|----------|
| `runtime-tokio` | 使用 `tokio` 作为异步运行时 | 运行时二选一，必选其一 |
| `runtime-async-std` | 使用 `async-std` 作为异步运行时 | 运行时二选一 |
| `tls-rustls` | 纯 Rust 的 `rustls` TLS 后端（默认用 `ring`） | 需要 TLS 时选 |
| `tls-native-tls` | 使用系统原生 TLS（`OpenSSL`/`SChannel`/`SecureTransport`） | 需要 TLS 时选；同时启用则它优先 |
| `mysql` / `postgres` / `sqlite` | 对应数据库驱动 | 至少选一个 |
| `macros` | 启用 `query!` / `query_as!` 编译期宏（默认开启） | 默认 |
| `migrate` | 启用迁移工具与 `migrate!` 宏（默认开启） | 默认 |
| `chrono` | `DATETIME`/`DATE`/`TIME` ↔ `chrono` 类型 | 用到时间类型时选 |
| `time` | 同上，但映射到 `time` crate（与 `chrono` 同时开启时宏优先用 `time`） | 二选一 |
| `json` | `JSON` 列 ↔ `serde_json::Value` / `Json<T>` | 用到 JSON 时选 |
| `uuid` | `uuid::Uuid` 支持 | 用到 UUID 时选 |
| `rust_decimal` / `bigdecimal` | `DECIMAL`/`NUMERIC` ↔ 高精度小数类型 | 用到定点小数时选 |

> 为什么运行时和驱动必须显式选？因为 `sqlx` 不想替你做这种全局性决定——一个项目里 `tokio` 还是 `async-std`、用不用 TLS，都是架构层面的选择，强行内置默认值反而会带来冲突和体积浪费。

## 三、连接数据库

最直接的方式是建立一条单独的连接 `MySqlConnection`。连接串遵循标准 URL 格式 `mysql://用户名:密码@主机:端口/数据库名`：

```rust
use sqlx::mysql::MySqlConnection;
use sqlx::Connection;

#[tokio::main]
async fn main() -> Result<(), sqlx::Error> {
    let mut conn =
        MySqlConnection::connect("mysql://root:password@127.0.0.1:3306/sqlx_demo").await?;

    let row: (i64,) = sqlx::query_as("SELECT 1").fetch_one(&mut conn).await?;
    println!("{}", row.0);

    conn.close().await?;
    Ok(())
}
```

> 密码里如果含有 `@`、`/`、`:` 等 URL 保留字符，必须做百分号编码——例如密码 `root@123` 要写成 `root%40123`，否则 URL 会被解析错乱。

单连接适合脚本或一次性任务。但在服务端，每个请求都新建一条连接（TCP 握手 + 认证）开销巨大，且数据库的并发连接数有上限。**生产环境一律使用连接池**，这正是下一节的主题。

## 四、连接池 MySqlPool 与 MySqlPoolOptions

连接池预先维护一组可复用的连接：请求来了从池里借一条，用完自动归还，避免反复握手。`sqlx` 的连接池 `MySqlPool` 内部是 `Arc` 包裹的，`clone()` 只是增加引用计数、共享同一个底层池，因此可以放心地把它 `clone` 给各个 handler。

`MySqlPool::connect(url)` 用默认参数快速建池；要精细控制则用 `MySqlPoolOptions`。

**语法：**

```rust
MySqlPoolOptions::new()
    .max_connections(u32)
    .min_connections(u32)
    .acquire_timeout(Duration)
    .idle_timeout(Option<Duration>)
    .max_lifetime(Option<Duration>)
    .connect(url).await
```

**参数：**

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `max_connections` | `u32` | `10` | 池中最多保持的连接数，达到上限后新请求需排队等待 |
| `min_connections` | `u32` | `0` | 即使空闲也保持的最小连接数，用于「保温」避免冷启动 |
| `acquire_timeout` | `Duration` | `30s` | 借连接的最长等待时间，超时返回 `PoolTimedOut` 错误 |
| `idle_timeout` | `Option<Duration>` | `None`（10 分钟，由内部默认设置） | 空闲连接超过该时长会被关闭回收 |
| `max_lifetime` | `Option<Duration>` | `None`（30 分钟） | 单条连接从创建起的最长寿命，到期后无论忙闲都重建 |
| `test_before_acquire` | `bool` | `true` | 借出前先 ping 一次确认连接可用，牺牲一点性能换可靠性 |

下面这个例子展示了建池、`clone` 共享、两种取连接方式，以及查看池状态：

```rust
use std::time::Duration;
use sqlx::mysql::MySqlPoolOptions;
use sqlx::Row;

#[tokio::main]
async fn main() -> Result<(), sqlx::Error> {
    let url = "mysql://root:root%40123@127.0.0.1:3306";

    let pool = MySqlPoolOptions::new()
        .max_connections(10)               // 池中最大连接数
        .min_connections(2)                // 空闲时保留的最小连接数
        .acquire_timeout(Duration::from_secs(5)) // 取连接的超时时间
        .idle_timeout(Duration::from_secs(600))  // 空闲连接的存活时间
        .max_lifetime(Duration::from_secs(1800)) // 单个连接的最长寿命
        .connect(&url)
        .await?;

    // 连接池实现了 Clone，clone 出来的句柄共享同一个底层池（内部 Arc）
    let pool2 = pool.clone();

    // 直接把 &pool 作为 Executor 传给查询，用完自动归还
    let one: i64 = sqlx::query("SELECT 1 + 1 AS s")
        .fetch_one(&pool)
        .await?
        .get("s");
    println!("1 + 1 = {one}");

    // 也可以显式 acquire 一个连接，作用域结束后归还
    let mut conn = pool2.acquire().await?;
    let now: String = sqlx::query("SELECT DATE_FORMAT(NOW(), '%Y') AS y")
        .fetch_one(&mut *conn)
        .await?
        .get("y");
    println!("当前年份 = {now}");

    println!("池大小 size = {}，空闲 idle = {}", pool.size(), pool.num_idle());

    pool.close().await;
    Ok(())
}
```

运行结果：

```
1 + 1 = 2
当前年份 = 2026
池大小 size = 2，空闲 idle = 1
```

`size = 2` 是因为 `min_connections(2)` 让池启动时就建好两条连接；`idle = 1` 是因为此刻有一条连接被 `pool2.acquire()` 借走、尚未归还。

> 连接池大小不是越大越好。`max_connections` 应当 ≤ 数据库的 `max_connections` 配置，并为其他客户端留出余量。一个常见误区是「池开 100 条」，结果几十个应用实例一起把数据库连接数打爆。

## 五、执行查询的核心 API

`sqlx` 的运行时查询围绕两个构造函数和一组「终结方法」展开：

- `sqlx::query(sql)`：返回未类型化的查询，结果是 `MySqlRow`，需要手动 `row.get("列名")` 取值。
- `sqlx::query_as::<_, T>(sql)`：把每行映射成实现了 `FromRow` 的类型 `T`（结构体或元组）。
- `sqlx::query_scalar(sql)`：只取每行第一列，适合 `COUNT(*)`、`MAX(x)` 这类标量查询。

参数通过 `.bind(value)` 按顺序绑定。**MySQL 的占位符是 `?`**（PostgreSQL 用 `$1`），`.bind()` 的调用顺序对应 SQL 里 `?` 出现的顺序。

终结方法决定「期望几行」以及返回类型：

| 期望行数 | 终结方法 | 返回类型 | 说明 |
|----------|----------|----------|------|
| 无（写操作） | `.execute()` | `MySqlQueryResult` | 用于 `INSERT`/`UPDATE`/`DELETE`，可取 `rows_affected()` |
| 0 或 1 行 | `.fetch_optional()` | `Option<T>` | 没有行返回 `None`，不报错 |
| 恰好 1 行 | `.fetch_one()` | `T` | 没有行返回 `RowNotFound` 错误；聚合查询用它 |
| 多行 | `.fetch_all()` | `Vec<T>` | 一次性收集所有行到内存 |
| 流式 | `.fetch()` | `impl Stream<Item = Result<T>>` | 边读边处理，适合大结果集 |

> 始终用 `.bind()` 传参，**绝不要用字符串拼接 SQL**。`.bind()` 走的是预处理语句（prepared statement），参数和 SQL 文本分离，从根本上杜绝 SQL 注入。所有终结方法都接受 `&Pool`、`&mut Connection` 或 `&mut Transaction` 作为执行器（Executor）。

## 六、CRUD 实战

本节用一张 `users` 表把增删改查串起来。以下代码是一个完整可运行的程序，从环境变量读取连接串。

### 6.1 建表

建表也是一次普通的 `execute`。这里每次运行先 `DROP` 再 `CREATE`，保证可复现：

```rust
sqlx::query("DROP TABLE IF EXISTS users")
    .execute(&pool)
    .await?;
sqlx::query(
    r#"
    CREATE TABLE users (
        id    BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name  VARCHAR(64)  NOT NULL,
        email VARCHAR(128) NOT NULL UNIQUE,
        age   INT          NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    "#,
)
.execute(&pool)
.await?;
```

### 6.2 Create — 插入与自增主键

`INSERT` 用 `execute()` 执行。MySQL 的自增主键通过返回结果的 `last_insert_id()` 拿到，影响行数用 `rows_affected()`：

```rust
let result = sqlx::query("INSERT INTO users (name, email, age) VALUES (?, ?, ?)")
    .bind("alice")
    .bind("alice@example.com")
    .bind(30)
    .execute(&pool)
    .await?;
let new_id = result.last_insert_id();
println!("插入成功，影响行数 = {}，新主键 = {}", result.rows_affected(), new_id);

// 一条 INSERT 插多行，bind 顺序对应所有 ? 的顺序
sqlx::query("INSERT INTO users (name, email, age) VALUES (?, ?, ?), (?, ?, ?)")
    .bind("bob").bind("bob@example.com").bind(25)
    .bind("carol").bind("carol@example.com").bind(35)
    .execute(&pool)
    .await?;
```

### 6.3 Read — 四种取数方式

读取前先定义一个映射目标结构体，派生 `sqlx::FromRow`，字段名要和查询列名一致：

```rust
use sqlx::FromRow;

#[derive(Debug, FromRow)]
struct User {
    id: i64,
    name: String,
    email: String,
    age: i32,
}
```

然后根据「期望几行」选不同终结方法：

```rust
// 按主键取唯一一行：无行会报 RowNotFound 错误
let alice: User = sqlx::query_as("SELECT id, name, email, age FROM users WHERE id = ?")
    .bind(new_id)
    .fetch_one(&pool)
    .await?;
println!("fetch_one  -> {alice:?}");

// 可能不存在：返回 Option，没有行就是 None
let missing: Option<User> = sqlx::query_as("SELECT id, name, email, age FROM users WHERE id = ?")
    .bind(9999)
    .fetch_optional(&pool)
    .await?;
println!("fetch_optional(9999) -> {missing:?}");

// 列表：返回 Vec
let users: Vec<User> = sqlx::query_as("SELECT id, name, email, age FROM users ORDER BY id")
    .fetch_all(&pool)
    .await?;
println!("fetch_all  -> 共 {} 条", users.len());
for u in &users {
    println!("  {} {} <{}> age={}", u.id, u.name, u.email, u.age);
}

// 标量聚合：COUNT(*) 用 query_scalar + fetch_one
let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE age >= ?")
    .bind(30)
    .fetch_one(&pool)
    .await?;
println!("query_scalar COUNT(age>=30) -> {count}");
```

前面几种终结方法（`fetch_all` / `fetch_one` / `fetch_optional`）都会**一次性把结果读进内存**。当结果集很大（几十万行的导出、报表）时，这样会瞬间吃满内存。这时改用 `fetch()`：它返回一个 `Stream`，**一行一行地从数据库读取**，边读边处理、不在内存里堆积。

`fetch()` 的返回值实现了 `futures` 的 `Stream`，最常用的消费方式是 `TryStreamExt::try_next()`——它逐行产出 `Result<Option<T>>`，配合 `while let` 循环取到 `None` 为止。所以要先在 `Cargo.toml` 里加一个依赖：

```toml
futures = "0.3"
```

```rust
use futures::TryStreamExt; // 为 Stream 引入 try_next()

// fetch：返回 Stream，逐行流式读取，适合大结果集
let mut stream = sqlx::query_as::<_, User>("SELECT id, name, email, age FROM users ORDER BY id")
    .fetch(&pool);

let mut n = 0;
while let Some(u) = stream.try_next().await? {
    n += 1;
    println!("fetch stream -> {} {} <{}> age={}", u.id, u.name, u.email, u.age);
}
println!("fetch 共流式读取 {n} 条");
```

> `fetch()` 流式读取期间会**借用住一条连接**，直到 stream 被读完或丢弃才归还，所以别让一个长时间存活的 stream 跨越大量其他逻辑。它的价值在于「大结果集 + 逐行处理」（如导出、ETL），普通的小查询用 `fetch_all` 更简单直接。

> `fetch_one` 在「查不到」时返回 `Err(RowNotFound)`，所以它只适合「逻辑上必然有一行」的场景，比如按主键查一条肯定存在的记录、或聚合查询（`COUNT` 一定返回一行）。如果记录**可能不存在**，请用 `fetch_optional` 拿 `Option`，否则会把正常的「没查到」当成错误抛出去。

### 6.4 Update — 更新

`UPDATE` 同样是 `execute`，用 `rows_affected()` 确认改了几行：

```rust
let updated = sqlx::query("UPDATE users SET age = ? WHERE name = ?")
    .bind(31)
    .bind("alice")
    .execute(&pool)
    .await?;
println!("更新 alice，影响行数 = {}", updated.rows_affected());
```

### 6.5 Delete — 删除

```rust
let deleted = sqlx::query("DELETE FROM users WHERE name = ?")
    .bind("bob")
    .execute(&pool)
    .await?;
println!("删除 bob，影响行数 = {}", deleted.rows_affected());
```

把上面各步组装进 `main`（建池 → 建表 → 增 → 查 → 改 → 删），完整运行的输出如下：

运行结果：

```
插入成功，影响行数 = 1，新主键 = 1
fetch_one  -> User { id: 1, name: "alice", email: "alice@example.com", age: 30 }
fetch_optional(9999) -> None
fetch_all  -> 共 3 条
  1 alice <alice@example.com> age=30
  2 bob <bob@example.com> age=25
  3 carol <carol@example.com> age=35
query_scalar COUNT(age>=30) -> 2
更新 alice，影响行数 = 1
删除 bob，影响行数 = 1
```

## 七、MySQL 数据类型与 Rust 类型映射

`sqlx` 在 `sqlx::mysql::types` 模块里定义了 MySQL 类型与 Rust 类型的双向转换。下表是常用类型对照：

| MySQL 类型 | Rust 类型 | 所需 feature |
|------------|-----------|--------------|
| `VARCHAR` / `CHAR` / `TEXT` | `String` / `&str` | 内置 |
| `TINYINT` | `i8`（`UNSIGNED` → `u8`） | 内置 |
| `SMALLINT` | `i16` / `u16` | 内置 |
| `INT` | `i32` / `u32` | 内置 |
| `BIGINT` | `i64` / `u64` | 内置 |
| `FLOAT` | `f32` | 内置 |
| `DOUBLE` | `f64` | 内置 |
| `DECIMAL` / `NUMERIC` | `rust_decimal::Decimal` 或 `bigdecimal::BigDecimal` | `rust_decimal` / `bigdecimal` |
| `DATETIME` | `chrono::NaiveDateTime` | `chrono`（或 `time`） |
| `DATE` | `chrono::NaiveDate` | `chrono` |
| `TIME` | `chrono::NaiveTime` | `chrono` |
| `TIMESTAMP` | `chrono::DateTime<Utc>` / `DateTime<Local>` | `chrono` |
| `JSON` | `sqlx::types::Json<T>` / `serde_json::Value` | `json` |
| `BLOB` / `BINARY` | `Vec<u8>` / `&[u8]` | 内置 |
| `TINYINT(1)` / `BOOLEAN` | `bool` | 内置 |

几个关键点解释「为什么」：

- **可空列必须用 `Option<T>`**。数据库的 `NULL` 在 Rust 里没有对应的「空值」，`sqlx` 用 `Option<T>` 表达：列值为 `NULL` 解码成 `None`，否则是 `Some(v)`。如果列可能为 `NULL` 却用了非 `Option` 类型，运行时会报解码错误。
- **`DATETIME` 与 `TIMESTAMP` 的映射类型不同**。`DATETIME` 不带时区，对应不带时区的 `NaiveDateTime`；`TIMESTAMP` 在 MySQL 里按 UTC 存储、按会话时区呈现，对应带时区的 `DateTime<Utc>`。选错类型会导致时区偏移。
- **`bool` 实质是 `TINYINT(1)`**。MySQL 没有真正的布尔类型，`BOOLEAN` 只是 `TINYINT(1)` 的别名。`sqlx` 运行时 API 能把它解码成 `bool`，但 `query!` 宏因 MySQL 协议限制会把它推断成 `i8`——这一点在第十节会再提。
- **`JSON` 列推荐用 `Json<T>`**。`Json<T>` 是一个包装类型，写入时把 `T` 序列化成 JSON 文本、读取时反序列化回 `T`，类型安全；若你想要弱类型的任意 JSON，用 `serde_json::Value`。

下面这个综合 demo 建一张涵盖 `int` / `varchar` / `char` / `double` / `bool` / `datetime` / `date` / 可空列 / `json` 的表，写入再读回，验证各类型往返正确：

```rust
use chrono::{NaiveDate, NaiveDateTime};
use serde::{Deserialize, Serialize};
use sqlx::mysql::MySqlPoolOptions;
use sqlx::types::Json;
use sqlx::FromRow;

// JSON 列里存放的结构体
#[derive(Debug, Serialize, Deserialize)]
struct Profile {
    city: String,
    tags: Vec<String>,
}

#[derive(Debug, FromRow)]
struct Record {
    id: i32,                   // INT      -> i32
    title: String,             // VARCHAR  -> String
    code: String,              // CHAR     -> String
    score: f64,                // DOUBLE   -> f64
    active: bool,              // TINYINT(1) -> bool
    created_at: NaiveDateTime, // DATETIME -> NaiveDateTime
    birthday: NaiveDate,       // DATE     -> NaiveDate
    nickname: Option<String>,  // 可空列   -> Option<T>
    profile: Json<Profile>,    // JSON     -> Json<T>
}

#[tokio::main]
async fn main() -> Result<(), sqlx::Error> {
	let url = "mysql://root:root%40123@127.0.0.1:3306/sqlx_demo";
    let pool = MySqlPoolOptions::new().connect(&url).await?;

    sqlx::query("DROP TABLE IF EXISTS type_demo").execute(&pool).await?;
    sqlx::query(
        r#"
        CREATE TABLE type_demo (
            id         INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
            title      VARCHAR(100) NOT NULL,
            code       CHAR(8)      NOT NULL,
            score      DOUBLE       NOT NULL,
            active     TINYINT(1)   NOT NULL,
            created_at DATETIME     NOT NULL,
            birthday   DATE         NOT NULL,
            nickname   VARCHAR(50)  NULL,
            profile    JSON         NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        "#,
    )
    .execute(&pool)
    .await?;

    let created = NaiveDateTime::parse_from_str("2026-06-11 09:00:00", "%Y-%m-%d %H:%M:%S").unwrap();
    let birthday = NaiveDate::from_ymd_opt(1995, 3, 18).unwrap();
    let profile = Json(Profile {
        city: "Shanghai".to_string(),
        tags: vec!["rust".to_string(), "sqlx".to_string()],
    });

    sqlx::query(
        "INSERT INTO type_demo (title, code, score, active, created_at, birthday, nickname, profile)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind("第一条记录")
    .bind("AB123456")
    .bind(98.5_f64)
    .bind(true)
    .bind(created)
    .bind(birthday)
    .bind(None::<String>) // 写入 NULL
    .bind(&profile)
    .execute(&pool)
    .await?;

    let rec: Record = sqlx::query_as(
        "SELECT id, title, code, score, active, created_at, birthday, nickname, profile
         FROM type_demo WHERE id = ?",
    )
    .bind(1)
    .fetch_one(&pool)
    .await?;

    println!("id        = {}", rec.id);
    println!("title     = {}", rec.title);
    println!("code      = {:?}", rec.code);
    println!("score     = {}", rec.score);
    println!("active    = {}", rec.active);
    println!("created_at= {}", rec.created_at);
    println!("birthday  = {}", rec.birthday);
    println!("nickname  = {:?}", rec.nickname);
    println!("profile   = {:?}", rec.profile.0);

    pool.close().await;
    Ok(())
}
```

运行结果：

```
id        = 1
title     = 第一条记录
code      = "AB123456"
score     = 98.5
active    = true
created_at= 2026-06-11 09:00:00
birthday  = 1995-03-18
nickname  = None
profile   = Profile { city: "Shanghai", tags: ["rust", "sqlx"] }
```

可以看到 `CHAR(8)` 读回的是完整的 8 个字符 `"AB123456"`，`active` 写入 `true` 读回 `bool`，`nickname` 的 `NULL` 解码成 `None`，`profile` 的 JSON 文本反序列化回了 `Profile` 结构体——各类型往返无损。

## 八、结果映射 FromRow

`#[derive(sqlx::FromRow)]` 自动为结构体生成「从一行数据构造自己」的逻辑。默认按**字段名 == 列名**匹配，匹配不上就报错。两个常用控制：

```rust
#[derive(Debug, sqlx::FromRow)]
struct User {
    id: i64,
    // 结构体字段叫 full_name，但数据库列叫 name
    #[sqlx(rename = "name")]
    full_name: String,
    // 数据库里没有这一列，用默认值填充
    #[sqlx(default)]
    nickname: Option<String>,
}
```

- `#[sqlx(rename = "列名")]`：字段名与列名不一致时显式指定映射关系。
- `#[sqlx(default)]`：结果集里缺这一列时，用 `Default::default()` 填充，而不是报错。

除了结构体，`FromRow` 也为**最多 16 元素的元组**实现了，按位置取前 N 列：

```rust
// 取前两列，第三列被忽略
let row: (i64, String) = sqlx::query_as("SELECT id, name, age FROM users WHERE id = ?")
    .bind(1)
    .fetch_one(&pool)
    .await?;
```

> 用元组或 `FromRow` 时**不要写 `SELECT *`**。`*` 返回的列顺序由表结构决定，一旦表加了列或调整了顺序，元组的位置映射就会错位、甚至类型对不上。永远显式列出列名，既稳定又自文档化。

## 九、事务 Transaction

事务保证一组操作「要么全成功，要么全失败」。`pool.begin()` 借一条连接并开启事务，返回 `Transaction`；在它上面执行若干语句后，`commit()` 提交、`rollback()` 回滚。

最关键的设计是：**`Transaction` 在 `Drop` 时若未提交，会自动回滚**。这意味着即使中途 `?` 提前返回错误、函数提前退出，未完成的事务也不会留下脏数据——你不需要手写 `try/catch` 式的回滚逻辑，RAII 帮你兜底。

下面用经典的转账场景演示原子性：从 `alice` 扣钱、给 `bob` 加钱，两步必须同时生效。

```rust
use sqlx::mysql::MySqlPoolOptions;
use sqlx::FromRow;

#[derive(Debug, FromRow)]
struct Account {
    name: String,
    balance: i64,
}

// 转账：从 from 扣钱、给 to 加钱，要么都成功要么都回滚
async fn transfer(
    pool: &sqlx::MySqlPool,
    from: &str,
    to: &str,
    amount: i64,
) -> Result<(), sqlx::Error> {
    let mut tx = pool.begin().await?;

    sqlx::query("UPDATE accounts SET balance = balance - ? WHERE name = ?")
        .bind(amount)
        .bind(from)
        .execute(&mut *tx)
        .await?;

    sqlx::query("UPDATE accounts SET balance = balance + ? WHERE name = ?")
        .bind(amount)
        .bind(to)
        .execute(&mut *tx)
        .await?;

    tx.commit().await?; // 不调用 commit，则 tx 被 drop 时自动回滚
    Ok(())
}

#[tokio::main]
async fn main() -> Result<(), sqlx::Error> {
	let url = "mysql://root:root%40123@127.0.0.1:3306/sqlx_demo";
    let pool = MySqlPoolOptions::new().connect(&url).await?;

    sqlx::query("DROP TABLE IF EXISTS accounts").execute(&pool).await?;
    sqlx::query(
        r#"
        CREATE TABLE accounts (
            name    VARCHAR(32) NOT NULL PRIMARY KEY,
            balance BIGINT      NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        "#,
    )
    .execute(&pool)
    .await?;
    sqlx::query("INSERT INTO accounts (name, balance) VALUES ('alice', 100), ('bob', 50)")
        .execute(&pool)
        .await?;

    transfer(&pool, "alice", "bob", 30).await?;

    let rows: Vec<Account> = sqlx::query_as("SELECT name, balance FROM accounts ORDER BY name")
        .fetch_all(&pool)
        .await?;
    println!("转账后余额：");
    for a in &rows {
        println!("  {} = {}", a.name, a.balance);
    }

    pool.close().await;
    Ok(())
}
```

运行结果：

```
转账后余额：
  alice = 70
  bob = 80
```

> 注意执行语句时传的是 `&mut *tx`，把 `Transaction` 解引用再可变借用，作为执行器传给查询——事务里的语句必须走同一条连接才能保证隔离性。另外，事务期间会**独占一条池连接**，所以事务要尽量短小，别在事务里夹杂网络请求、复杂计算这类耗时操作，否则连接被长时间占用，池很快被掏空。

## 十、编译期检查宏（进阶）

前面所有查询都是**运行时 API**：SQL 只是普通字符串，写错列名要到运行时才暴露。`sqlx` 的杀手锏是 `query!` / `query_as!` 宏，它们在**编译期**连上数据库，把 SQL 拿到真实 schema 上校验，并自动推断每一列的 Rust 类型。

`query!` 用 `println!` 风格的语法，返回一个字段名、类型都由数据库推断出来的**匿名结构体**；`query_as!` 则把结果映射到你指定的具名结构体。占位符仍然是 MySQL 的 `?`，但宏会**检查参数个数与类型**是否匹配。

要使用这两个宏，编译时必须能连上数据库，方式是设置环境变量 `DATABASE_URL`（通常放在项目根目录的 `.env` 文件里）：

```bash
# .env
DATABASE_URL=mysql://root:password@127.0.0.1:3306/sqlx_demo
```

```rust
use sqlx::mysql::MySqlPoolOptions;

#[derive(Debug)]
struct UserRow {
    id: i64,
    name: String,
    age: i32,
}

#[tokio::main]
async fn main() -> Result<(), sqlx::Error> {
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL 未设置");
    let pool = MySqlPoolOptions::new().connect(&url).await?;

    // query! —— 编译期连接 DATABASE_URL 校验 SQL、推断列类型，返回匿名结构体
    let rows = sqlx::query!("SELECT id, name, age FROM users WHERE age >= ? ORDER BY id", 18)
        .fetch_all(&pool)
        .await?;
    for r in &rows {
        // 字段 r.id / r.name / r.age 的类型由数据库 schema 推断得出
        println!("query!     -> {} {} {}", r.id, r.name, r.age);
    }

    // query_as! —— 同样的编译期校验，但映射到具名 struct
    let users = sqlx::query_as!(
        UserRow,
        "SELECT id, name, age FROM users ORDER BY id"
    )
    .fetch_all(&pool)
    .await?;
    println!("query_as!  -> {users:?}");

    pool.close().await;
    Ok(())
}
```

运行结果（表中预置了 alice/bob 两行）：

```
query!     -> 1 alice 30
query!     -> 2 bob 25
query_as!  -> [UserRow { id: 1, name: "alice", age: 30 }, UserRow { id: 2, name: "bob", age: 25 }]
```

如果你把 SQL 里的 `name` 写成不存在的 `username`，或把 `?` 的参数漏掉，`cargo build` 直接报错——错误被拦在了编译阶段。

**离线模式**：编译期连数据库在 CI 或他人本地不一定方便。`sqlx` 提供离线模式：安装 `sqlx-cli` 后，在本地连着库的情况下运行 `cargo sqlx prepare`，它会把每条宏查询的校验信息缓存到项目下的 `.sqlx/` 目录，提交进 Git。之后编译不再需要 `DATABASE_URL`，宏直接读 `.sqlx/` 缓存校验。CI 里可用 `cargo sqlx prepare --check` 确认缓存与代码一致。

```bash
cargo install sqlx-cli --no-default-features --features mysql
cargo sqlx prepare          # 生成 .sqlx/ 缓存，提交到版本库
cargo sqlx prepare --check  # CI 中校验缓存是否最新
```

运行时 API 与编译期宏的取舍：

| 维度 | 运行时 API（`query` / `query_as`） | 编译期宏（`query!` / `query_as!`） |
|------|-----------------------------------|-----------------------------------|
| SQL 校验时机 | 运行时 | 编译期 |
| 是否需连库编译 | 否 | 是（或用 `.sqlx/` 离线缓存） |
| 类型映射 | 手动指定目标类型 | 由数据库 schema 自动推断 |
| 动态 SQL | 灵活，可运行时拼接条件 | SQL 必须是字符串字面量，不能动态拼 |
| 适用场景 | 动态查询、SQL 在运行时才确定 | 固定 SQL，追求最强的编译期安全 |

> 一个 MySQL 专属陷阱：因协议限制，`query!` 宏会把 `TINYINT(1)`（即 `BOOLEAN`）推断成 `i8` 而不是 `bool`。如果你需要 `bool`，可以在 SQL 里用类型标注 `as "active: bool"`，或干脆改用运行时 `query_as` 配合显式的 `bool` 字段。

## 十一、最佳实践与常见陷阱

把前面散落的经验汇总成一份清单：

- **连接池全局共享，按需 `clone`**。`MySqlPool` 内部是 `Arc`，`clone()` 廉价且共享同一个池。在 Web 框架里把 `pool` 放进应用状态，每个 handler `clone` 一份即可，不要在每个请求里 `connect` 新池。
- **永远 `.bind()`，绝不字符串拼接**。这既是防 SQL 注入的底线，也能让数据库复用预处理语句的执行计划。
- **按「期望几行」选终结方法**。必然有一行用 `fetch_one`，可能没有用 `fetch_optional`，多行用 `fetch_all`，大结果集用 `fetch` 流式处理避免一次性吃满内存。
- **池大小要和数据库 `max_connections` 对齐**。`max_connections` 是「每个应用实例」的上限，要乘以实例数后仍小于数据库总上限，并留余量。盲目调大只会把数据库连接数打爆。
- **事务尽量短**。事务独占一条连接直到 `commit`/`rollback`，长事务会拖垮连接池吞吐。别在事务里做网络 IO 或重计算。
- **可空列一律 `Option<T>`**。否则 `NULL` 会触发解码错误。
- **优先列出列名，别用 `SELECT *`**。配合 `FromRow` / 元组时，`*` 的列顺序变化会导致映射错位。

掌握这些，`sqlx` 就能在「写真实 SQL」的直接与「编译期安全」的稳健之间，给你一个恰到好处的平衡点。
