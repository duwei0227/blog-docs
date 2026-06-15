---
title: "[Crate] axum 构建 RESTful API 实战"
published: true
layout: post
date: 2026-06-10 09:00:00
permalink: /rust/axum.html
tags:
  - RESTful
categories: Rust
---

`axum` 是 tokio 团队出品的 Web 框架，构建在 `tokio`（异步运行时）、`tower`（中间件抽象）、`hyper`（HTTP 实现）之上。它最大的特点是**没有宏魔法**——路由就是普通函数调用，处理函数就是普通 `async fn`。理解 `axum` 只需要抓住三个抽象：**提取器（extractor）** 负责从请求里取数据（路径、查询串、body、头），**处理函数（handler）** 是你写业务的 `async fn`，返回值只要实现 **`IntoResponse`** 就能变成 HTTP 响应。请求进来被提取器拆解成函数参数，业务返回值被 `IntoResponse` 组装成响应，整条链路是类型安全的，编译期就能挡住大量错误。

本文从依赖引入开始，覆盖 `GET/POST/PUT/DELETE` 四种方法，路径参数、查询参数、JSON、表单、附件上传、自定义状态码、Header 参数，再到共享状态、路由分组、统一响应结构、优雅关机与开发期热加载。**每一节都是一个可以独立 `cargo run` 的完整程序**，文末再给出把全部能力串起来的整合版。全文示例均基于 `axum 0.8.9` 实测通过。

## 一、安装与依赖

在 `Cargo.toml` 中加入 `axum` 与配套 crate：

```toml
[dependencies]
axum = { version = "0.8", features = ["multipart"] }
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tower-http = { version = "0.6", features = ["limit"] }
listenfd = "1"
```

各依赖的职责：

| crate | 作用 |
|-------|------|
| `axum` | Web 框架本体，提供 `Router`、提取器、`IntoResponse` |
| `tokio` | 异步运行时，`axum::serve` 跑在它上面（需要 `net`、`signal`，`full` 已包含） |
| `serde` / `serde_json` | 请求体/响应体与 Rust 结构体之间的序列化反序列化 |
| `tower-http` | tower 生态的 HTTP 中间件，本文用它的 `RequestBodyLimitLayer` 放宽 body 上限 |
| `listenfd` | 热加载时复用监听 `socket`，配合 `systemfd` 使用 |

`axum` 的常用 feature：

| feature | 启用的能力 |
|---------|-----------|
| `multipart` | `Multipart` 提取器，处理文件上传 |
| `macros` | `#[debug_handler]` 等调试宏（让 handler 类型错误更可读） |
| `ws` | WebSocket 支持 |
| `tracing` | 内置一些 `tracing` 日志埋点 |

> `axum 0.8` 相比 `0.7` 有一个会直接影响代码的破坏性变更：路径参数语法从 `:id` 改成了 `{id}`，通配从 `*rest` 改成 `{*rest}`。本文全部使用 `0.8` 新语法。

## 二、最小可运行服务

先跑通一个返回字符串的 `GET /`：

```rust
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;

async fn root() -> &'static str {
    "Hello, axum!"
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(root));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

`Router::new().route(path, method_router)` 注册路由；`axum::serve(listener, app)` 接管一个 tokio 的 `TcpListener` 开始服务。

```bash
curl localhost:3000/
```

运行结果：

```
Hello, axum!
```

这里 handler 返回 `&'static str` 就能直接作为响应，是因为 `axum` 为大量常见类型实现了 `IntoResponse`：`&str`/`String` 变成 `text/plain`，`Json<T>` 变成 `application/json`，`StatusCode` 变成空响应加状态码，元组 `(StatusCode, T)` 则是「状态码 + 响应体」。你几乎不用手动构造 `Response`，返回业务类型即可。

## 三、路由与 HTTP 方法

`axum::routing` 为每种 HTTP 方法提供了同名函数：`get`、`post`、`put`、`delete`、`patch`、`head`、`options`。它们都返回一个 `MethodRouter`，可以链式叠加，让**同一路径**响应多种方法。

**语法：**

```rust
Router::new().route("/users", get(list).post(create))
Router::new().route("/users/{id}", get(detail).put(update).delete(remove))
```

**参数：**

| 函数 | 说明 |
|------|------|
| `get(handler)` | 匹配 `GET`；`axum` 会自动让 `HEAD` 复用 `GET` 的 handler |
| `post(handler)` | 匹配 `POST`，通常用于创建资源 |
| `put(handler)` | 匹配 `PUT`，通常用于整体更新 |
| `delete(handler)` | 匹配 `DELETE`，删除资源 |
| `MethodRouter::merge` | 合并多个方法路由到同一路径 |

链式调用 `get(...).post(...)` 的本质是把多个 `MethodRouter` 合并：每个方法绑定到各自的 handler，命中不了的方法会自动返回 `405 Method Not Allowed`，这一步不需要你写任何分支判断。下面是完整示例，`/users` 响应 `GET`/`POST`，`/users/{id}` 响应 `GET`/`PUT`/`DELETE`：

```rust
use axum::extract::Path;
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;

async fn list_users() -> &'static str {
    "list users"
}

async fn create_user() -> &'static str {
    "create user"
}

async fn get_user(Path(id): Path<u32>) -> String {
    format!("get user {id}")
}

async fn update_user(Path(id): Path<u32>) -> String {
    format!("update user {id}")
}

async fn delete_user(Path(id): Path<u32>) -> String {
    format!("delete user {id}")
}

// {*rest} 捕获该前缀下剩余的所有路径段（含 `/`）
async fn serve_file(Path(rest): Path<String>) -> String {
    format!("serving file: {rest}")
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/users", get(list_users).post(create_user))
        .route("/users/{id}", get(get_user).put(update_user).delete(delete_user))
        .route("/files/{*rest}", get(serve_file));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl localhost:3000/users
curl -X POST localhost:3000/users
curl localhost:3000/users/7
curl -X PUT localhost:3000/users/7
curl -X DELETE localhost:3000/users/7
curl -i -X DELETE localhost:3000/users           # /users 上没有 DELETE
curl localhost:3000/files/img/avatar.png         # {*rest} 捕获多段
curl localhost:3000/files/a/b/c.txt              # 含 `/` 也整段捕获
```

运行结果：

```
list users
create user
get user 7
update user 7
delete user 7
HTTP/1.1 405 Method Not Allowed
serving file: img/avatar.png
serving file: a/b/c.txt
```

普通占位符 `{id}` 只匹配**单个**路径段（不含 `/`），而 `{*rest}` 是 catch-all：它贪婪地捕获该前缀之后的**全部剩余路径**（包含 `/`），所以 `/files/a/b/c.txt` 会把 `a/b/c.txt` 整段塞进 `rest`。这类通配最适合静态文件服务、代理转发这种「前缀固定、后面路径不定」的场景。

> 静态段优先级高于动态段，所以 `/users/me` 和 `/users/{id}` 可以共存，`me` 会优先命中静态路由；同理 `{*rest}` 的优先级最低，只兜底其它路由都没命中的请求。`{*rest}` 必须位于路径末尾，不能写成 `/files/{*rest}/meta` 这种中间形式。

## 四、路径参数 Path

`Path<T>` 从 URL 路径里抽取占位符并用 `serde` 反序列化。单个参数用 `Path<u32>`，多个参数用元组 `Path<(String, u32)>`，也可以用结构体按字段名映射。

**语法：**

```rust
async fn get_user(Path(id): Path<u32>) -> String
```

**参数：**

| 形式 | 路径模板 | 提取目标 |
|------|----------|----------|
| `Path<u32>` | `/users/{id}` | 单个参数，按位置取 |
| `Path<(String, u32)>` | `/{group}/{id}` | 多个参数，按顺序映射到元组 |
| `Path<结构体>` | `/{group}/{id}` | 多个参数，按字段名映射 |

```rust
use axum::extract::Path;
use axum::routing::get;
use axum::Router;
use serde::Deserialize;
use tokio::net::TcpListener;

// 单个参数
async fn one(Path(id): Path<u32>) -> String {
    format!("id = {id}")
}

// 多个参数：元组按顺序映射
async fn two(Path((group, id)): Path<(String, u32)>) -> String {
    format!("group = {group}, id = {id}")
}

// 多个参数：结构体按字段名映射
#[derive(Deserialize)]
struct PathParams {
    group: String,
    id: u32,
}

async fn three(Path(p): Path<PathParams>) -> String {
    format!("group = {}, id = {}", p.group, p.id)
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/users/{id}", get(one))
        .route("/tuple/{group}/{id}", get(two))
        .route("/struct/{group}/{id}", get(three));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl localhost:3000/users/42
curl localhost:3000/tuple/team/42
curl localhost:3000/struct/team/42
curl localhost:3000/users/abc       # 类型不匹配
```

运行结果：

```
id = 42
group = team, id = 42
group = team, id = 42
Invalid URL: Cannot parse `abc` to a `u32`
```

> 最后一行 `abc` 无法转成 `u32`，`Path` 直接返回 `400 Bad Request`（响应体就是上面那句），这个失败由 `PathRejection` 描述。第十四节会演示如何把这类提取失败也纳入统一错误结构。

## 五、查询参数 Query

`Query<T>` 解析 URL 问号后面的查询串（`?page=2&size=10`），同样走 `serde`。用结构体接收时，字段类型决定是否必填：`Option<T>` 是可选，配合 `#[serde(default = "...")]` 可以给默认值。

**语法：**

```rust
async fn list(Query(params): Query<Pagination>) -> String
```

**参数：**

| 形式 | 说明 |
|------|------|
| `Query<HashMap<String, String>>` | 把所有查询参数收进 map，适合参数不固定的场景 |
| `Query<结构体>` | 按字段名映射，类型安全；缺失必填字段会 `400` |
| `Option<T>` 字段 | 该参数可缺省，缺省时为 `None` |
| `#[serde(default = "fn")]` | 参数缺省时调用 `fn` 取默认值 |

```rust
use std::collections::HashMap;

use axum::extract::Query;
use axum::routing::get;
use axum::Router;
use serde::Deserialize;
use tokio::net::TcpListener;

fn default_page() -> u32 {
    1
}
fn default_size() -> u32 {
    10
}

#[derive(Deserialize)]
struct Pagination {
    #[serde(default = "default_page")]
    page: u32,
    #[serde(default = "default_size")]
    size: u32,
}

// 结构体接收，带默认值
async fn list(Query(pg): Query<Pagination>) -> String {
    format!("page={}, size={}", pg.page, pg.size)
}

// HashMap 接收任意查询参数
async fn raw(Query(params): Query<HashMap<String, String>>) -> String {
    let mut keys: Vec<_> = params.into_iter().collect();
    keys.sort();
    format!("{keys:?}")
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/list", get(list))
        .route("/raw", get(raw));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl 'localhost:3000/list?page=2&size=20'
curl localhost:3000/list            # 不带参数，走默认值
curl 'localhost:3000/raw?a=1&b=2'
```

运行结果：

```
page=2, size=20
page=1, size=10
[("a", "1"), ("b", "2")]
```

> 数组型查询参数（`?id=1&id=2`）默认的 `Query` 不直接支持，需要 `Vec<u32>` 字段配合 `serde` 的 multi-value 处理，或改用 `axum_extra::extract::Query`。常规分页、过滤场景用结构体即可。

## 六、JSON 请求与响应

`Json<T>` 身兼两职：作为**提取器**时它读取请求体并用 `serde` 反序列化成 `T`（要求 `T: Deserialize`）；作为**返回值**时它把 `T` 序列化成 JSON 响应（要求 `T: Serialize`），并自动带上 `Content-Type: application/json`。

**语法：**

```rust
async fn create(Json(payload): Json<CreateUser>) -> (StatusCode, Json<User>)
```

**参数：**

| 位置            | 约束               | 行为                                                |
| ------------- | ---------------- | ------------------------------------------------- |
| 提取器 `Json<T>` | `T: Deserialize` | 读 body 反序列化；`Content-Type` 必须是 `application/json` |
| 返回 `Json<T>`  | `T: Serialize`   | 序列化为 JSON body，自动设 `Content-Type`                 |

```rust
use axum::http::StatusCode;
use axum::routing::post;
use axum::{Json, Router};
use serde::{Deserialize, Serialize};
use tokio::net::TcpListener;

#[derive(Deserialize)]
struct CreateUser {
    name: String,
    email: String,
}

#[derive(Serialize, Clone)]
struct User {
    id: u32,
    name: String,
    email: String,
}

async fn create_user(Json(input): Json<CreateUser>) -> (StatusCode, Json<User>) {
    let user = User { id: 3, name: input.name, email: input.email };
    // 元组 (StatusCode, Json) 把响应状态码改成 201 Created
    (StatusCode::CREATED, Json(user))
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/users", post(create_user));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -i -X POST -H 'Content-Type: application/json' \
  -d '{"name":"Carol","email":"carol@example.com"}' localhost:3000/users
```

运行结果：

```
HTTP/1.1 201 Created
content-type: application/json

{"id":3,"name":"Carol","email":"carol@example.com"}
```

### 6.1 POST 接收数组参数

请求体顶层就是一个 JSON 数组（如 `[1, 2, 3]`）时，直接用 `Json<Vec<T>>` 即可——`serde` 会把数组反序列化成 `Vec`。这和「顶层是对象」没有本质区别，区别只在目标类型：对象对应 `struct`，数组对应 `Vec`。

```rust
use axum::routing::post;
use axum::{Json, Router};
use tokio::net::TcpListener;

// 请求体顶层就是 JSON 数组：[1, 2, 3, 4]
async fn sum(Json(nums): Json<Vec<i64>>) -> Json<i64> {
    Json(nums.iter().sum())
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/sum", post(sum));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -X POST -H 'Content-Type: application/json' -d '[1,2,3,4]' localhost:3000/sum
```

运行结果：

```
10
```

> 想批量接收对象数组就用 `Json<Vec<CreateUser>>`。注意整个 body 会一次性读进内存反序列化，超大数组要配合第九节的 body 大小限制。

## 七、表单 Form

`Form<T>` 处理 `application/x-www-form-urlencoded`（HTML 表单默认编码，形如 `username=alice&password=secret`）。用法和 `Json` 几乎一样，差别只在 `Content-Type` 和编码方式：`Form` 走 url 编码，`Json` 走 JSON。

**语法：**

```rust
async fn login(Form(form): Form<LoginForm>) -> String
```

```rust
use axum::routing::post;
use axum::{Form, Router};
use serde::Deserialize;
use tokio::net::TcpListener;

#[derive(Deserialize)]
struct LoginForm {
    username: String,
    password: String,
}

async fn handle_form(Form(form): Form<LoginForm>) -> String {
    format!("welcome {}, pwd len = {}", form.username, form.password.len())
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/form", post(handle_form));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -X POST -d 'username=alice&password=secret' localhost:3000/form
```

运行结果：

```
welcome alice, pwd len = 6
```

> `Form` 和 `Json` 都会**消费请求体**，因此一个 handler 里只能有其中一个，且必须放在参数列表最后——原因见下一节。

## 八、提取器执行顺序规则

`axum` 的提取器分两类，对应两个 trait：

- **`FromRequestParts`**：只读请求的「头部信息」（方法、路径、查询串、Header），不碰 body。`Path`、`Query`、`HeaderMap`、`State`、`Method` 都属于这类，可以有任意多个，顺序随意。
- **`FromRequest`**：要消费请求体。`Json`、`Form`、`Multipart`、`String`、`Bytes` 属于这类。

请求体是一个**只能读一次的流**，所以消费 body 的提取器：**最多一个，且必须是参数列表的最后一个**。把它放在中间，后面的参数就没有 body 可读了——`axum` 用 trait 约束在编译期强制了这个规则。下面是正确顺序的完整示例：非 body 提取器在前，`Json` 收尾。

```rust
use axum::extract::Path;
use axum::http::{HeaderMap, Method};
use axum::routing::post;
use axum::{Json, Router};
use serde_json::Value;
use tokio::net::TcpListener;

// 正确顺序：不碰 body 的提取器在前，消费 body 的 Json 放最后
async fn demo(
    method: Method,            // FromRequestParts，不碰 body
    headers: HeaderMap,        // FromRequestParts
    Path(id): Path<u32>,       // FromRequestParts
    Json(body): Json<Value>,   // FromRequest，消费 body，必须最后
) -> String {
    let has_auth = headers.contains_key("authorization");
    format!("{method} id={id} auth={has_auth} body={body}")
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/items/{id}", post(demo));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -X POST -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer t' -d '{"k":"v"}' localhost:3000/items/9
```

运行结果：

```
POST id=9 auth=true body={"k":"v"}
```

如果把 `Json` 挪到 `Path` 前面（`async fn bad(Json(body): Json<Value>, Path(id): Path<u32>)`），编译会直接失败，因为这样的函数不再满足 `Handler` trait：

```
error[E0277]: the trait bound `fn(Json<Value>, Path<u32>) -> ... {bad}: Handler<_, _>` is not satisfied
   = note: Consider using `#[axum::debug_handler]` to improve the error message
```

> 按提示在 handler 上加 `#[axum::debug_handler]`（需 `macros` feature），错误信息会精确指出是哪个参数不满足 `FromRequestParts`。记忆口诀：**「读 body 的站最后，且只能站一个」**，`State`/`Path`/`Query`/`HeaderMap` 这些「只读头部」的提取器随便排。

## 九、附件上传 Multipart

文件上传用 `multipart/form-data` 编码，对应 `Multipart` 提取器（需开启 `multipart` feature）。它不是一次性读完，而是**流式**地一个 `field` 一个 `field` 往下取，适合大文件。

**Field 方法：**

| 方法 | 返回 | 说明 |
|------|------|------|
| `name()` | `Option<&str>` | 表单字段名（`<input name>`） |
| `file_name()` | `Option<&str>` | 文件原始名；非文件字段为 `None` |
| `content_type()` | `Option<&str>` | 该 field 的 MIME 类型 |
| `bytes().await` | `Result<Bytes, _>` | 读取该 field 全部内容（会消费 field） |
| `text().await` | `Result<String, _>` | 按 UTF-8 读取该 field |

注意 `bytes()` 会消费 `field`，所以要先取完 `name()`/`file_name()`/`content_type()` 再读 `bytes()`：

```rust
use axum::extract::Multipart;
use axum::routing::post;
use axum::{Json, Router};
use serde::Serialize;
use tokio::net::TcpListener;

#[derive(Serialize)]
struct UploadInfo {
    field: String,
    file_name: Option<String>,
    content_type: Option<String>,
    size: usize,
}

async fn upload(mut multipart: Multipart) -> Json<Vec<UploadInfo>> {
    let mut infos = Vec::new();
    while let Some(field) = multipart.next_field().await.unwrap() {
        // 先取元信息，再读 bytes（bytes 会消费 field）
        let name = field.name().unwrap_or("").to_string();
        let file_name = field.file_name().map(|s| s.to_string());
        let content_type = field.content_type().map(|s| s.to_string());
        let data = field.bytes().await.unwrap();
        infos.push(UploadInfo { field: name, file_name, content_type, size: data.len() });
    }
    Json(infos)
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/upload", post(upload));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

准备一个测试文件再上传（`-F` 让 curl 用 `multipart/form-data`）：

```bash
echo 'hello upload content for axum demo' > axum_up.txt
curl -X POST -F 'desc=hello' -F 'file=@axum_up.txt' localhost:3000/upload
```

运行结果：

```
[{"field":"desc","file_name":null,"content_type":null,"size":5},{"field":"file","file_name":"axum_up.txt","content_type":"text/plain","size":34}]
```

普通字段（`desc`）的 `file_name` 为 `null`、`size` 是值的字节数；文件字段（`file`）带上了原始文件名和 MIME 类型。

### 9.1 请求体大小限制

`axum` 给所有请求体设了**默认上限 2 MB**（`2_097_152` 字节），超过会直接返回 `413 Payload Too Large`。上传大文件时必须放宽这个限制。

**用法：**

| 写法 | 效果 |
|------|------|
| `DefaultBodyLimit::max(n)` | 把上限改为 `n` 字节（`axum` 自带，无需额外依赖） |
| `DefaultBodyLimit::disable()` | 关闭 `axum` 内置限制 |
| `disable()` + `tower_http::limit::RequestBodyLimitLayer::new(n)` | 关闭内置限制后由 `tower-http` 设更大值 |

下面把上限故意调成 16 字节来观察 `413`：

```rust
use axum::extract::DefaultBodyLimit;
use axum::routing::post;
use axum::Router;
use tokio::net::TcpListener;

async fn echo(body: String) -> String {
    format!("got {} bytes", body.len())
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/echo", post(echo))
        // 演示用：把 body 上限改成 16 字节，超过返回 413
        .layer(DefaultBodyLimit::max(16));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -X POST -d 'hello' localhost:3000/echo                       # 5 字节，通过
curl -i -X POST -d 'xxxxxxxxxxxxxxxxxxxx' localhost:3000/echo     # 20 字节，超限
```

运行结果：

```
got 5 bytes
HTTP/1.1 413 Payload Too Large
...
Failed to buffer the request body: length limit exceeded
```

放宽到很大的值时用 `tower-http`（生产里上传大文件的常见写法）：

```rust
use axum::extract::DefaultBodyLimit;
use tower_http::limit::RequestBodyLimitLayer;

let app = Router::new()
    .route("/upload", post(upload))
    .layer(DefaultBodyLimit::disable())
    .layer(RequestBodyLimitLayer::new(250 * 1024 * 1024)); // 250 MB
```

> body 限制是通过请求扩展（request extensions）传递的，**最后生效的那个 layer 决定最终上限**。`DefaultBodyLimit::max` 和 `RequestBodyLimitLayer` 不会叠加，混用时以执行顺序靠后的为准。

## 十、自定义响应状态码

`axum` 默认成功响应是 `200 OK`。要改状态码，最直接的方式是返回元组：`(StatusCode, impl IntoResponse)`，第一个元素就是状态码，会覆盖响应体本来的状态。

**语法：**

| 返回类型 | 含义 |
|----------|------|
| `StatusCode` | 空响应体，只有状态码 |
| `(StatusCode, T)` | 状态码 + 响应体 `T` |
| `(StatusCode, HeaderMap, T)` | 状态码 + 自定义头 + 响应体 |

```rust
use axum::http::StatusCode;
use axum::routing::get;
use axum::{Json, Router};
use tokio::net::TcpListener;

async fn teapot() -> (StatusCode, Json<&'static str>) {
    (StatusCode::IM_A_TEAPOT, Json("I'm a teapot"))
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/teapot", get(teapot));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -i localhost:3000/teapot
```

运行结果：

```
HTTP/1.1 418 I'm a teapot
content-type: application/json

"I'm a teapot"
```

> 元组里状态码必须放第一位，响应体放最后。`(StatusCode, HeaderMap, T)` 这种三元组能一次性设好状态码、响应头和 body，非常适合需要返回 `Location` 头的 `201 Created` 场景。

## 十一、Header 参数

读请求头用 `HeaderMap` 提取器，它是 `FromRequestParts` 类型（不碰 body），可以放在参数列表任意位置。

**常用方法：**

| 方法 | 说明 |
|------|------|
| `headers.get(name)` | 取单个头，返回 `Option<&HeaderValue>` |
| `value.to_str()` | 把 `HeaderValue` 转成 `&str`（非 ASCII 会失败，返回 `Result`） |
| 返回 `HeaderMap` | 给响应设置一组头 |
| 返回 `[(HeaderName, &str); N]` | 用数组形式给响应设头，更轻量 |

```rust
use axum::http::StatusCode;
use axum::http::HeaderMap;
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;

async fn whoami(headers: HeaderMap) -> Result<String, (StatusCode, String)> {
    match headers.get("authorization").and_then(|v| v.to_str().ok()) {
        Some(token) => Ok(format!("your token is: {token}")),
        None => Err((StatusCode::BAD_REQUEST, "missing Authorization header".to_string())),
    }
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/whoami", get(whoami));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -H 'Authorization: Bearer abc123' localhost:3000/whoami
curl localhost:3000/whoami      # 不带头
```

运行结果：

```
your token is: Bearer abc123
missing Authorization header
```

> 这里用核心的 `HeaderMap` 手动取值，胜在零额外依赖。如果想要强类型的头（比如直接拿到解析好的 `Authorization: Bearer <token>`），可以引入 `axum-extra` 的 `TypedHeader`，或自己实现 `FromRequestParts` 把头解析成业务类型。本文为减少依赖只用 `HeaderMap`。

## 十二、共享状态 State

真实应用里 handler 需要访问数据库连接池、配置、缓存等共享资源。`axum` 用 `State<T>` 注入这些应用级状态：定义一个 `Clone` 的状态类型，在路由上 `.with_state(state)` 绑定，handler 里用 `State<T>` 取出。这里用内存版的 `Arc<Mutex<HashMap>>` 模拟一个 user 存储：

```rust
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;

#[derive(Clone)]
struct User {
    id: u32,
    name: String,
}

struct Inner {
    users: HashMap<u32, User>,
}

#[derive(Clone)]
struct AppState {
    inner: Arc<Mutex<Inner>>,
}

async fn get_user(
    State(state): State<AppState>,
    Path(id): Path<u32>,
) -> Result<String, StatusCode> {
    let inner = state.inner.lock().unwrap();
    match inner.users.get(&id) {
        Some(u) => Ok(format!("found user {}: {}", u.id, u.name)),
        None => Err(StatusCode::NOT_FOUND),
    }
}

#[tokio::main]
async fn main() {
    let mut users = HashMap::new();
    users.insert(1, User { id: 1, name: "Alice".to_string() });
    let state = AppState { inner: Arc::new(Mutex::new(Inner { users })) };

    let app = Router::new()
        .route("/users/{id}", get(get_user))
        .with_state(state);

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl localhost:3000/users/1
curl -i localhost:3000/users/99     # 不存在
```

运行结果：

```
found user 1: Alice
HTTP/1.1 404 Not Found
```

**为什么 `AppState` 用 `Arc<Mutex<...>>`：** `State<T>` 要求 `T: Clone`，因为每个请求都会克隆一份状态。`Arc` 让克隆只是引用计数加一（共享同一份数据），`Mutex` 保证并发写安全。

| 机制 | 取值方式 | 安全性 |
|------|----------|--------|
| `State<T>` | `.with_state(...)` 绑定，编译期检查类型 | 类型不匹配直接编译失败 |
| `Extension<T>` | `.layer(Extension(...))` 注入，运行期按类型查找 | 忘记注入会在**运行时** panic |

> 优先用 `State`：它在编译期就能保证状态被正确提供，而 `Extension` 的错误要到请求进来才暴露。`Extension` 多用于中间件之间传递动态数据。

## 十三、路由分组

应用变大后，把所有路由堆在一个 `Router` 里会很乱。`axum` 提供两种组合方式：

- **`nest(prefix, router)`**：把子路由挂到某个前缀下，常用于按资源/版本拆分（`/api`、`/v1`）。
- **`merge(router)`**：把另一个同层 `Router` 的路由合并进来，不加前缀。

```rust
use axum::extract::Path;
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;

async fn root() -> &'static str {
    "root"
}

async fn list_users() -> &'static str {
    "list users"
}

async fn get_user(Path(id): Path<u32>) -> String {
    format!("get user {id}")
}

// users 子路由
fn user_routes() -> Router {
    Router::new()
        .route("/users", get(list_users))
        .route("/users/{id}", get(get_user))
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(root))
        .nest("/api", user_routes()); // /users -> /api/users

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl localhost:3000/
curl localhost:3000/api/users
curl localhost:3000/api/users/5
```

运行结果：

```
root
list users
get user 5
```

挂载后 `/users` 变成 `/api/users`、`/users/{id}` 变成 `/api/users/{id}`。几个关键约束：

- **状态类型要一致**：被 `nest` 的子路由 `Router<AppState>` 必须和外层的状态类型相同。子路由也可以先 `.with_state(...)` 把状态固化掉，变成 `Router<()>` 再挂载。
- **`fallback` 的继承**：外层 `Router` 的 `fallback`（404 处理）会被嵌套子路由继承；如果子路由自己设了 `fallback`，则子路由内部优先用自己的。

> `nest` 适合「带前缀的整组路由」，`merge` 适合「把拆分到不同文件的同层路由拼起来」。两者都不复制 handler，只是组合路由表。

## 十四、统一响应结构

前端最头疼的是每个接口返回格式都不一样。统一响应结构的目标是：**无论成功还是失败，外层结构完全相同**，前端用一套逻辑就能解析。这里约定：

```json
{ "code": 0, "message": "success", "data": { ... } }
```

成功时 `code` 为 `0`、`data` 是业务数据；失败时 `code` 是错误码、`message` 是错误信息、`data` 为 `null`。

实现的关键是**为自定义类型实现 `IntoResponse`**：成功响应 `ApiResponse<T>` 序列化成上面的结构，错误类型 `AppError` 的 `into_response` 也输出同一套结构（`data` 为 `null`）。下面是一个完整可运行的程序，同时演示 14.1 的提取失败容错：

```rust
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use axum::extract::rejection::JsonRejection;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::get;
use axum::{Json, Router};
use serde::{Deserialize, Serialize};
use tokio::net::TcpListener;

// ---------- 统一响应结构 ----------

#[derive(Serialize)]
struct ApiResponse<T> {
    code: i32,
    message: String,
    data: Option<T>,
}

impl<T> ApiResponse<T> {
    fn ok(data: T) -> Self {
        Self { code: 0, message: "success".to_string(), data: Some(data) }
    }
}

impl<T: Serialize> IntoResponse for ApiResponse<T> {
    fn into_response(self) -> Response {
        Json(self).into_response()
    }
}

enum AppError {
    NotFound(String),
    BadRequest(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, code, message) = match self {
            AppError::NotFound(m) => (StatusCode::NOT_FOUND, 404, m),
            AppError::BadRequest(m) => (StatusCode::BAD_REQUEST, 400, m),
        };
        let body = ApiResponse::<()> { code, message, data: None };
        (status, Json(body)).into_response()
    }
}

// 把提取器的 Rejection 也收敛进统一错误结构
impl From<JsonRejection> for AppError {
    fn from(rejection: JsonRejection) -> Self {
        AppError::BadRequest(rejection.body_text())
    }
}

// ---------- 数据与状态 ----------

#[derive(Clone, Serialize)]
struct User {
    id: u32,
    name: String,
}

#[derive(Deserialize)]
struct CreateUser {
    name: String,
}

struct Inner {
    users: HashMap<u32, User>,
    next_id: u32,
}

#[derive(Clone)]
struct AppState {
    inner: Arc<Mutex<Inner>>,
}

async fn get_user(
    State(state): State<AppState>,
    Path(id): Path<u32>,
) -> Result<ApiResponse<User>, AppError> {
    let inner = state.inner.lock().unwrap();
    inner
        .users
        .get(&id)
        .cloned()
        .map(ApiResponse::ok)
        .ok_or_else(|| AppError::NotFound(format!("user {id} not found")))
}

async fn create_user(
    State(state): State<AppState>,
    payload: Result<Json<CreateUser>, JsonRejection>,
) -> Result<(StatusCode, ApiResponse<User>), AppError> {
    let Json(input) = payload?; // 提取失败经 From<JsonRejection> 转成 AppError
    let mut inner = state.inner.lock().unwrap();
    let id = inner.next_id;
    inner.next_id += 1;
    let user = User { id, name: input.name };
    inner.users.insert(id, user.clone());
    Ok((StatusCode::CREATED, ApiResponse::ok(user)))
}

#[tokio::main]
async fn main() {
    let mut users = HashMap::new();
    users.insert(1, User { id: 1, name: "Alice".to_string() });
    let state = AppState { inner: Arc::new(Mutex::new(Inner { users, next_id: 2 })) };

    let app = Router::new()
        .route("/users", axum::routing::post(create_user))
        .route("/users/{id}", get(get_user))
        .with_state(state);

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl localhost:3000/users/1                                                # 成功
curl localhost:3000/users/99                                               # 业务错误
curl -X POST -H 'Content-Type: application/json' -d '{"name":"Carol"}' localhost:3000/users
curl -X POST -H 'Content-Type: application/json' -d '{bad' localhost:3000/users   # 非法 JSON
```

运行结果：

```
{"code":0,"message":"success","data":{"id":1,"name":"Alice"}}
{"code":404,"message":"user 99 not found","data":null}
{"code":0,"message":"success","data":{"id":2,"name":"Carol"}}
{"code":400,"message":"Failed to parse the request body as JSON: key must be a string at line 1 column 2","data":null}
```

### 14.1 Result + Rejection 容错

注意上面第四个请求：客户端发了一段非法 JSON。如果直接写 `Json(input): Json<CreateUser>`，`axum` 会返回它默认的纯文本 `400`，绕开我们的统一结构。

解决办法就是上面代码里的写法——把提取器包进 `Result`：用 `Result<Json<T>, JsonRejection>` 接收，提取失败时拿到 `JsonRejection` 而不是直接短路；再给 `AppError` 实现 `From<JsonRejection>`，`payload?` 就能把它转成统一错误。于是连「参数解析失败」都长成了 `{code, message, data}` 的样子（见运行结果最后一行）。

```rust
// 把提取器的 Rejection 也收敛进统一错误结构
impl From<JsonRejection> for AppError {
  fn from(rejection: JsonRejection) -> Self {
	AppError::BadRequest(rejection.body_text())
  }
}
```

> 同理可以处理 `PathRejection`、`QueryRejection` 等。把所有 `Rejection` 收敛到 `AppError`，你的 API 就**没有任何裂缝**——连框架级的参数错误都长成统一的样子。

## 十五、优雅关机

生产环境重启/扩缩容时，进程收到 `SIGTERM` 不应该粗暴退出，而要：**停止接收新连接，等在途请求处理完再退出**。`axum::serve` 提供 `with_graceful_shutdown`，传入一个「关机信号 Future」，该 Future 完成时就触发优雅关机。

```rust
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;

async fn root() -> &'static str {
    "Hello, axum!"
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
    println!("signal received, shutting down gracefully");
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(root));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}
```

启动后按 `Ctrl+C` 或发送 `SIGTERM`（`kill -TERM <pid>`），进程打印关机日志后干净退出：

```
listening on 0.0.0.0:3000
signal received, shutting down gracefully
```

`tokio::select!` 同时监听 `Ctrl+C`（本地调试）和 `SIGTERM`（容器编排发的停止信号），任一触发即开始关机。`SIGTERM` 监听用 `#[cfg(unix)]` 隔离，非 Unix 平台用一个永不完成的 `pending` 占位，保证跨平台能编译。

> 需要 tokio 的 `signal` feature（`full` 已包含）。优雅关机配合健康检查使用效果最好：先让健康检查失败把流量摘掉，再发 `SIGTERM`，在途请求就能干净收尾。

## 十六、开发阶段热加载

Rust 改一行代码要重新编译，手动 `cargo run` 很烦。开发期可以用 `cargo-watch` 监听文件变化自动重编重启；再加 `systemfd` + `listenfd` 让重启时**复用同一个监听 socket**，避免「重启瞬间端口被占用 / 连接被拒」。

安装工具：

```bash
cargo install cargo-watch systemfd
```

依赖里加上 `listenfd`，改造启动代码，让它**优先使用 `systemfd` 传进来的 socket**，没有再自己 `bind`：

```rust
let mut listenfd = ListenFd::from_env();
let listener = match listenfd.take_tcp_listener(0).unwrap() {
	// systemfd 传入了 socket：复用它
	Some(listener) => {
		listener.set_nonblocking(true).unwrap();
		TcpListener::from_std(listener).unwrap()
	}
	// 没有就自己 bind（直接 cargo run 时）
	None => TcpListener::bind("0.0.0.0:3000").await.unwrap(),
};
```

完整示例：
```rust
use axum::routing::get;
use axum::Router;
use listenfd::ListenFd;
use tokio::net::TcpListener;

async fn root() -> &'static str {
    "Hello, axum!"
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(root));

    let mut listenfd = ListenFd::from_env();
    let listener = match listenfd.take_tcp_listener(0).unwrap() {
        // systemfd 传入了 socket：复用它
        Some(listener) => {
            listener.set_nonblocking(true).unwrap();
            TcpListener::from_std(listener).unwrap()
        }
        // 没有就自己 bind（直接 cargo run 时）
        None => TcpListener::bind("0.0.0.0:3000").await.unwrap(),
    };

    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

直接 `cargo run` 走 `None` 分支自己 `bind`，访问照常：

```bash
curl localhost:3000/
```

运行结果：

```
Hello, axum!
```

开发时则用 `systemfd` 启动，它持有监听 `socket` 并通过环境变量传给子进程，`cargo watch -x run` 在文件变化时重新编译并重启子进程，新进程通过 `ListenFd::from_env()` 接管同一个 `socket`，连接平滑过渡：

```bash
systemfd --no-pid -s http::3000 -- cargo watch -x run
```

> 只装 `cargo-watch`、直接 `cargo watch -x run` 也能自动重编，只是重启瞬间会短暂断开、偶尔报 `address already in use`。加 `systemfd` 是为了让这个过渡无缝——对需要保持长连接调试的场景很有用。

## 十七、完整示例

把以上所有能力（统一响应、State、路由分组、四种方法、各类提取器、容错、自定义状态码、body 限制、优雅关机、热加载）串成一个完整可运行的 `users` API。直接 `cargo run`，或用第十六节的命令热加载启动。

```rust
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use axum::extract::rejection::JsonRejection;
use axum::extract::{DefaultBodyLimit, Form, Json, Multipart, Path, Query, State};
use axum::http::{HeaderMap, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::Router;
use listenfd::ListenFd;
use serde::{Deserialize, Serialize};
use tokio::net::TcpListener;

// ---------- 统一响应结构 ----------

#[derive(Serialize)]
struct ApiResponse<T> {
    code: i32,
    message: String,
    data: Option<T>,
}

impl<T> ApiResponse<T> {
    fn ok(data: T) -> Self {
        Self { code: 0, message: "success".to_string(), data: Some(data) }
    }
}

impl<T: Serialize> IntoResponse for ApiResponse<T> {
    fn into_response(self) -> Response {
        Json(self).into_response()
    }
}

enum AppError {
    NotFound(String),
    BadRequest(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, code, message) = match self {
            AppError::NotFound(m) => (StatusCode::NOT_FOUND, 404, m),
            AppError::BadRequest(m) => (StatusCode::BAD_REQUEST, 400, m),
        };
        let body = ApiResponse::<()> { code, message, data: None };
        (status, Json(body)).into_response()
    }
}

impl From<JsonRejection> for AppError {
    fn from(rejection: JsonRejection) -> Self {
        AppError::BadRequest(rejection.body_text())
    }
}

// ---------- 数据模型与共享状态 ----------

#[derive(Clone, Serialize)]
struct User {
    id: u32,
    name: String,
    email: String,
}

#[derive(Deserialize)]
struct CreateUser {
    name: String,
    email: String,
}

#[derive(Deserialize)]
struct UpdateUser {
    name: Option<String>,
    email: Option<String>,
}

struct Inner {
    users: HashMap<u32, User>,
    next_id: u32,
}

#[derive(Clone)]
struct AppState {
    inner: Arc<Mutex<Inner>>,
}

impl AppState {
    fn new() -> Self {
        let mut users = HashMap::new();
        users.insert(1, User { id: 1, name: "Alice".to_string(), email: "alice@example.com".to_string() });
        users.insert(2, User { id: 2, name: "Bob".to_string(), email: "bob@example.com".to_string() });
        Self { inner: Arc::new(Mutex::new(Inner { users, next_id: 3 })) }
    }
}

// ---------- 各功能 handler ----------

async fn root() -> &'static str {
    "Hello, axum!"
}

// POST 接收 JSON 数组：[1, 2, 3]
async fn sum(Json(nums): Json<Vec<i64>>) -> ApiResponse<i64> {
    ApiResponse::ok(nums.iter().sum())
}

#[derive(Deserialize)]
struct LoginForm {
    username: String,
    password: String,
}

// 表单 application/x-www-form-urlencoded
async fn handle_form(Form(form): Form<LoginForm>) -> ApiResponse<String> {
    ApiResponse::ok(format!("welcome {}, pwd len = {}", form.username, form.password.len()))
}

#[derive(Serialize)]
struct UploadInfo {
    field: String,
    file_name: Option<String>,
    content_type: Option<String>,
    size: usize,
}

// 附件上传
async fn upload(mut multipart: Multipart) -> Result<ApiResponse<Vec<UploadInfo>>, AppError> {
    let mut infos = Vec::new();
    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|e| AppError::BadRequest(e.to_string()))?
    {
        let name = field.name().unwrap_or("").to_string();
        let file_name = field.file_name().map(|s| s.to_string());
        let content_type = field.content_type().map(|s| s.to_string());
        let data = field
            .bytes()
            .await
            .map_err(|e| AppError::BadRequest(e.to_string()))?;
        infos.push(UploadInfo { field: name, file_name, content_type, size: data.len() });
    }
    Ok(ApiResponse::ok(infos))
}

// Header 参数
async fn whoami(headers: HeaderMap) -> Result<ApiResponse<String>, AppError> {
    let token = headers
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| AppError::BadRequest("missing Authorization header".to_string()))?;
    Ok(ApiResponse::ok(format!("your token is: {token}")))
}

// 自定义响应状态码
async fn teapot() -> (StatusCode, ApiResponse<String>) {
    (StatusCode::IM_A_TEAPOT, ApiResponse::ok("I'm a teapot".to_string()))
}

// ---------- users 资源（路由分组到 /api 下）----------

fn default_page() -> u32 { 1 }
fn default_size() -> u32 { 10 }

#[derive(Deserialize)]
struct Pagination {
    #[serde(default = "default_page")]
    page: u32,
    #[serde(default = "default_size")]
    size: u32,
}

#[derive(Serialize)]
struct UserPage {
    page: u32,
    size: u32,
    total: usize,
    items: Vec<User>,
}

async fn list_users(
    State(state): State<AppState>,
    Query(pg): Query<Pagination>,
) -> ApiResponse<UserPage> {
    let inner = state.inner.lock().unwrap();
    let mut all: Vec<User> = inner.users.values().cloned().collect();
    all.sort_by_key(|u| u.id);
    let total = all.len();
    let start = ((pg.page.saturating_sub(1)) * pg.size) as usize;
    let items: Vec<User> = all.into_iter().skip(start).take(pg.size as usize).collect();
    ApiResponse::ok(UserPage { page: pg.page, size: pg.size, total, items })
}

async fn get_user(
    State(state): State<AppState>,
    Path(id): Path<u32>,
) -> Result<ApiResponse<User>, AppError> {
    let inner = state.inner.lock().unwrap();
    inner
        .users
        .get(&id)
        .cloned()
        .map(ApiResponse::ok)
        .ok_or_else(|| AppError::NotFound(format!("user {id} not found")))
}

async fn create_user(
    State(state): State<AppState>,
    payload: Result<Json<CreateUser>, JsonRejection>,
) -> Result<(StatusCode, ApiResponse<User>), AppError> {
    let Json(input) = payload?;
    let mut inner = state.inner.lock().unwrap();
    let id = inner.next_id;
    inner.next_id += 1;
    let user = User { id, name: input.name, email: input.email };
    inner.users.insert(id, user.clone());
    Ok((StatusCode::CREATED, ApiResponse::ok(user)))
}

async fn update_user(
    State(state): State<AppState>,
    Path(id): Path<u32>,
    Json(input): Json<UpdateUser>,
) -> Result<ApiResponse<User>, AppError> {
    let mut inner = state.inner.lock().unwrap();
    let user = inner
        .users
        .get_mut(&id)
        .ok_or_else(|| AppError::NotFound(format!("user {id} not found")))?;
    if let Some(name) = input.name {
        user.name = name;
    }
    if let Some(email) = input.email {
        user.email = email;
    }
    Ok(ApiResponse::ok(user.clone()))
}

async fn delete_user(
    State(state): State<AppState>,
    Path(id): Path<u32>,
) -> Result<ApiResponse<()>, AppError> {
    let mut inner = state.inner.lock().unwrap();
    if inner.users.remove(&id).is_some() {
        Ok(ApiResponse::ok(()))
    } else {
        Err(AppError::NotFound(format!("user {id} not found")))
    }
}

fn user_routes() -> Router<AppState> {
    Router::new()
        .route("/users", get(list_users).post(create_user))
        .route("/users/{id}", get(get_user).put(update_user).delete(delete_user))
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
    println!("signal received, shutting down gracefully");
}

#[tokio::main]
async fn main() {
    let state = AppState::new();

    let app = Router::new()
        .route("/", get(root))
        .route("/sum", post(sum))
        .route("/form", post(handle_form))
        .route("/upload", post(upload))
        .route("/whoami", get(whoami))
        .route("/teapot", get(teapot))
        .nest("/api", user_routes())
        .layer(DefaultBodyLimit::max(10 * 1024 * 1024))
        .with_state(state);

    let mut listenfd = ListenFd::from_env();
    let listener = match listenfd.take_tcp_listener(0).unwrap() {
        Some(listener) => {
            listener.set_nonblocking(true).unwrap();
            TcpListener::from_std(listener).unwrap()
        }
        None => TcpListener::bind("0.0.0.0:3000").await.unwrap(),
    };

    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}
```

启动后逐个验证四种方法与统一响应：

```bash
curl localhost:3000/api/users/1
curl -X POST -H 'Content-Type: application/json' \
  -d '{"name":"Carol","email":"carol@example.com"}' localhost:3000/api/users
curl -X PUT -H 'Content-Type: application/json' \
  -d '{"name":"Bobby"}' localhost:3000/api/users/2
curl -X DELETE localhost:3000/api/users/1
```

运行结果：

```
{"code":0,"message":"success","data":{"id":1,"name":"Alice","email":"alice@example.com"}}
{"code":0,"message":"success","data":{"id":3,"name":"Carol","email":"carol@example.com"}}
{"code":0,"message":"success","data":{"id":2,"name":"Bobby","email":"bob@example.com"}}
{"code":0,"message":"success","data":null}
```

成功与失败、有数据与无数据，外层结构始终是 `{code, message, data}` 三件套——这正是统一响应结构的价值：前端拿到任何接口都用同一套逻辑解析。至此，一个覆盖完整 RESTful 能力的 `axum` 服务就搭建完成了。
