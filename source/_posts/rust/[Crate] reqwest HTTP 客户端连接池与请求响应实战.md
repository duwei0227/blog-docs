---
title: reqwest HTTP 客户端连接池与请求响应实战
published: true
layout: post
date: 2026-06-16 09:00:00
permalink: /rust/reqwest.html
tags:
  - reqwest
  - HTTP
  - 异步
categories: Rust
---

写一个 HTTP 客户端，理论上你可以直接用 `hyper` 甚至裸 `TcpStream` 拼报文，但那意味着自己处理连接复用、TLS 握手、重定向、`gzip` 解压、chunked 编码、字符集探测——这些和业务无关却又不能出错的脏活。`reqwest` 把这些全部封装好，对外只暴露一套链式调用：`client.get(url).query(...).header(...).send().await?`。它基于 `hyper` 与 `tokio`，默认异步，同时提供 `blocking` 同步客户端。

理解 `reqwest` 的核心只需抓住一条主线：**`Client` 是一个内部带连接池的、可克隆的句柄，应该全程复用，而不是每次请求都新建。** 围绕这个 `Client`，再叠加请求构建（header、query、body）和响应消费（状态、报文、JSON）两套 API，就是 `reqwest` 的全部。本文用 `https://httpbin.org` 这个公开回显服务跑通每一个示例，所有 `运行结果` 都是实际执行抓取的输出。

## 一、安装与第一个请求

在 `Cargo.toml` 中添加依赖。`reqwest` 把很多能力做成了 feature，默认**不开启** `json`、`stream`、`multipart`，需要手动声明：

```toml
[dependencies]
reqwest = { version = "0.12", features = ["json", "stream", "multipart"] }
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
futures-util = "0.3"   # 流式下载 bytes_stream() 需要 StreamExt::next
```

常用 feature 一览：

| feature | 默认开启 | 作用 |
|---------|---------|------|
| `default` | 是 | 含 `default-tls`（基于 `native-tls` 的 HTTPS 支持） |
| `json` | 否 | 启用 `.json()` 请求体与 `response.json::<T>()` 响应解析 |
| `stream` | 否 | 启用 `response.bytes_stream()` 流式响应 |
| `multipart` | 否 | 启用 `multipart::Form` 文件上传 |
| `gzip` / `brotli` / `deflate` / `zstd` | 否 | 按对应算法自动解压响应体 |
| `cookies` | 否 | 启用 `cookie_store` 自动管理 Cookie |
| `blocking` | 否 | 启用 `reqwest::blocking` 同步客户端 |
| `rustls-tls` | 否 | 用纯 Rust 的 `rustls` 替代系统 `native-tls` |

第一个请求：

```rust
use reqwest::Client;

#[tokio::main]
async fn main() -> Result<(), reqwest::Error> {
    let client = Client::new();
    let resp = client.get("https://httpbin.org/get").send().await?;

    println!("status = {}", resp.status());
    println!("content-type = {:?}", resp.headers().get("content-type"));

    let body = resp.text().await?;
    println!("body length = {}", body.len() > 0);
    Ok(())
}
```

运行结果：

```
status = 200 OK
content-type = Some("application/json")
body length = true
```

注意整条链路上有两个 `.await`：`send()` 等待响应头到达，`text()` 等待响应体读完。`send()` 返回后你已经拿到了状态码和响应头，但 body 还没下载——这个分离设计是流式下载的基础（见第八节）。

## 二、Client 与连接池

`Client::new()` 适合快速上手，但生产代码几乎都用 `Client::builder()` 来定制超时、连接池等参数。这里有一个**最重要也最容易踩的坑**：

> `Client` 内部持有连接池，并用 `Arc` 包裹，`clone()` 是廉价的引用计数操作。**你应该在程序启动时构建一个 `Client` 并全局复用**，绝不要在每次请求时 `Client::new()`——那样每次都要重建连接池、重新做 TLS 握手，连接无法复用，性能会断崖式下降。

### 2.1 连接池与超时配置

**语法：**

```rust
Client::builder()
    .pool_idle_timeout(val: impl Into<Option<Duration>>)
    .pool_max_idle_per_host(max: usize)
    .connect_timeout(val: Duration)
    .timeout(val: Duration)
    .build() -> Result<Client, Error>
```

**参数：**

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `pool_idle_timeout` | `90s` | 空闲连接在池中保留多久后被关闭；传 `None` 表示永不超时 |
| `pool_max_idle_per_host` | `usize::MAX` | 每个 host 最多保留多少条空闲连接 |
| `connect_timeout` | 无（不限） | 建立 TCP + TLS 连接的最长耗时，仅作用于握手阶段 |
| `timeout` | 无（不限） | 单次请求从发出到响应体读完的总超时 |

```rust
use reqwest::Client;
use std::time::Duration;

#[tokio::main]
async fn main() -> Result<(), reqwest::Error> {
    let client = Client::builder()
        .pool_idle_timeout(Duration::from_secs(30))
        .pool_max_idle_per_host(8)
        .connect_timeout(Duration::from_secs(5))
        .timeout(Duration::from_secs(10))
        .build()?;

    // 复用同一个 client 连续发 3 次请求，底层复用同一条 TCP 连接
    for i in 1..=3 {
        let status = client.get("https://httpbin.org/get").send().await?.status();
        println!("request {i} -> {status}");
    }
    Ok(())
}
```

运行结果：

```
request 1 -> 200 OK
request 2 -> 200 OK
request 3 -> 200 OK
```

`connect_timeout` 和 `timeout` 的区别值得说清楚：前者只管握手，握手完成后即使响应迟迟不来也不受它约束；后者覆盖整个请求生命周期。一个常见的健壮配置是两者都设——用较短的 `connect_timeout`（如 5s）快速失败掉不可达的主机，用较长的 `timeout`（如 30s）兜住慢响应。

## 三、自定义请求 Header

设置 header 有两个层次：**全局默认头**（每个请求自动携带，适合 `User-Agent`、`Authorization` 这类固定值）和**单次请求头**（只作用于当次调用）。

**语法：**

```rust
// 全局：在 builder 上设置
ClientBuilder::default_headers(headers: HeaderMap) -> ClientBuilder
// 单次：在请求上追加
RequestBuilder::header(key: impl IntoHeaderName, value: impl TryInto<HeaderValue>) -> RequestBuilder
RequestBuilder::headers(headers: HeaderMap) -> RequestBuilder
```

**参数：**

| 方法 | 作用域 | 说明 |
|------|--------|------|
| `default_headers` | 全局 | 接收一个 `HeaderMap`，之后每个请求都会带上；单次 `header()` 同名时会覆盖 |
| `header` | 单次 | 追加或覆盖单个头；`key` 可用 `reqwest::header` 里的常量或字符串字面量 |
| `headers` | 单次 | 一次性合并一整个 `HeaderMap` 到当前请求 |

```rust
use reqwest::Client;
use reqwest::header::{HeaderMap, HeaderValue, USER_AGENT, ACCEPT};
use serde_json::Value;

#[tokio::main]
async fn main() -> Result<(), reqwest::Error> {
    // 方式一：在 client 上设置全局默认头，每个请求自动携带
    let mut default_headers = HeaderMap::new();
    default_headers.insert(USER_AGENT, HeaderValue::from_static("my-app/1.0"));
    default_headers.insert(ACCEPT, HeaderValue::from_static("application/json"));

    let client = Client::builder()
        .default_headers(default_headers)
        .build()?;

    // 方式二：在单次请求上追加/覆盖头
    let resp = client
        .get("https://httpbin.org/headers")
        .header("X-Custom-Header", "my-value")
        .send()
        .await?;

    let json: Value = resp.json().await?;
    let headers = &json["headers"];
    println!("User-Agent      = {}", headers["User-Agent"]);
    println!("Accept          = {}", headers["Accept"]);
    println!("X-Custom-Header = {}", headers["X-Custom-Header"]);
    Ok(())
}
```

运行结果：

```
User-Agent      = "my-app/1.0"
Accept          = "application/json"
X-Custom-Header = "my-value"
```

> 用 `HeaderValue::from_static` 处理编译期已知的常量字符串，零分配且不会失败；运行期才确定的值用 `HeaderValue::from_str(s)?`，它返回 `Result`，因为 header 值不允许包含换行等控制字符。这种"非法值在类型层面拦截"的设计避免了 HTTP 头注入。

## 四、Query 参数

`.query()` 把键值对序列化成 URL 查询串拼到 `?` 后面，并自动做百分号编码，省去手工拼接 `?a=1&b=2` 的麻烦。它接受任何能被 `serde` 序列化的类型。

**语法：**

```rust
RequestBuilder::query(query: &T) -> RequestBuilder
where T: Serialize + ?Sized
```

**参数：**

| 传入类型 | 适用场景 |
|----------|---------|
| `&[(K, V)]` 元组切片 | 临时拼几个参数，最直接 |
| `&struct`（派生 `Serialize`） | 参数较多或固定，字段名即参数名，类型安全 |
| `&HashMap<K, V>` | 参数在运行期动态收集 |

```rust
use reqwest::Client;
use serde::Serialize;
use serde_json::Value;

#[derive(Serialize)]
struct Pagination {
    page: u32,
    size: u32,
    keyword: String,
}

#[tokio::main]
async fn main() -> Result<(), reqwest::Error> {
    let client = Client::new();

    // 方式一：元组切片，适合临时拼几个参数
    let resp = client
        .get("https://httpbin.org/get")
        .query(&[("page", "1"), ("size", "20")])
        .send()
        .await?;
    let json: Value = resp.json().await?;
    println!("tuple args = {}", json["args"]);

    // 方式二：serde 结构体，字段即参数名，类型安全
    let p = Pagination { page: 2, size: 50, keyword: "rust http".into() };
    let resp = client
        .get("https://httpbin.org/get")
        .query(&p)
        .send()
        .await?;
    let json: Value = resp.json().await?;
    println!("struct args = {}", json["args"]);
    Ok(())
}
```

运行结果：

```
tuple args = {"page":"1","size":"20"}
struct args = {"keyword":"rust http","page":"2","size":"50"}
```

注意 `keyword` 里的空格被自动编码成了 `%20`（httpbin 解码后回显为 `rust http`），无需你手动处理。多次调用 `.query()` 会**追加**而非覆盖，所以可以分步拼装；如果某个字段是 `Option::None`，序列化时会被自动跳过。

## 五、请求体：Form / JSON / Multipart

POST/PUT 请求的 body 有三种最常见形态，`reqwest` 各给一个专用方法，它们的区别只在于**序列化方式和自动设置的 `Content-Type`**。

### 5.1 表单请求

`.form()` 把数据序列化为 `application/x-www-form-urlencoded`（即 `a=1&b=2` 的形式），并自动设置对应的 `Content-Type`。这是传统 HTML 表单和很多老接口的格式。

**语法：**

```rust
RequestBuilder::form(form: &T) -> RequestBuilder
where T: Serialize + ?Sized
```

```rust
use reqwest::Client;
use serde_json::Value;

#[tokio::main]
async fn main() -> Result<(), reqwest::Error> {
    let client = Client::new();

    let resp = client
        .post("https://httpbin.org/post")
        .form(&[("username", "alice"), ("password", "s3cret")])
        .send()
        .await?;

    let json: Value = resp.json().await?;
    // httpbin 把 form 字段回显在 "form"，并标注 Content-Type
    println!("form = {}", json["form"]);
    println!("content-type = {}", json["headers"]["Content-Type"]);
    Ok(())
}
```

运行结果：

```
form = {"password":"s3cret","username":"alice"}
content-type = "application/x-www-form-urlencoded"
```

### 5.2 JSON 请求

`.json()` 把数据序列化为 JSON 并设置 `Content-Type: application/json`。这是现代 API 的主流格式，需要 `json` feature。

**语法：**

```rust
RequestBuilder::json(json: &T) -> RequestBuilder
where T: Serialize + ?Sized
```

```rust
use reqwest::Client;
use serde::{Serialize, Deserialize};

#[derive(Serialize)]
struct CreateUser {
    name: String,
    age: u32,
}

// httpbin /post 把请求体放在 "json" 字段里回显
#[derive(Deserialize, Debug)]
struct Echo {
    json: CreatedBack,
}

#[derive(Deserialize, Debug)]
struct CreatedBack {
    name: String,
    age: u32,
}

#[tokio::main]
async fn main() -> Result<(), reqwest::Error> {
    let client = Client::new();

    let body = CreateUser { name: "bob".into(), age: 30 };
    let resp = client
        .post("https://httpbin.org/post")
        .json(&body)
        .send()
        .await?;

    // 直接把响应 JSON 反序列化成强类型结构体
    let echo: Echo = resp.json().await?;
    println!("name = {}, age = {}", echo.json.name, echo.json.age);
    Ok(())
}
```

运行结果：

```
name = bob, age = 30
```

这个例子同时演示了**JSON 请求 + JSON 响应**的完整闭环：请求体由 `CreateUser` 序列化而来，响应体又被 `resp.json::<Echo>()` 反序列化进结构体，全程类型安全，不用碰任何手写的 JSON 字符串。`json::<T>()` 要求 `T: DeserializeOwned`，且响应体必须是合法 JSON——若只想取其中几个字段，定义一个只含这些字段的结构体即可，`serde` 默认忽略多余字段。

> `.json()` 内部用 `serde_json` 序列化，若类型含无法表示为 JSON 的内容（如非字符串键的 `HashMap`），错误会在 `send()` 时返回，而不是 panic。

### 5.3 Multipart 文件上传

上传文件要用 `multipart/form-data`，对应 `reqwest::multipart::Form`，需要 `multipart` feature。一个 `Form` 由多个字段组成：`text()` 添加普通文本字段，`file()` 直接从磁盘读取一个真实文件作为部件。

**语法：**

```rust
multipart::Form::new()
    .text(name, value)                       // 普通文本字段
    .file(name, path) -> Result<Form>        // 异步读取磁盘文件作为部件
    .part(name, part: multipart::Part)       // 自定义部件（内存字节等）
RequestBuilder::multipart(form: Form) -> RequestBuilder
```

下面以读取项目根目录的 `Cargo.toml` 为例上传一个真实文件：

```rust
use reqwest::Client;
use reqwest::multipart::Form;
use serde_json::Value;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::new();

    // 从磁盘读取真实文件：Form::file 会异步读盘、按扩展名推断 MIME、流式发送
    let form = Form::new()
        .text("author", "alice")
        .file("file", "Cargo.toml")
        .await?;

    let resp = client
        .post("https://httpbin.org/post")
        .multipart(form)
        .send()
        .await?;

    let json: Value = resp.json().await?;
    println!("form      = {}", json["form"]);
    // files 里是上传文件的内容，取第一行确认是 Cargo.toml
    let content = json["files"]["file"].as_str().unwrap_or("");
    println!("uploaded? = {}", !content.is_empty());
    println!("first line= {}", content.lines().next().unwrap_or(""));
    Ok(())
}
```

运行结果：

```
form      = {"author":"alice"}
uploaded? = true
first line= [package]
```

httpbin 把普通文本字段归到 `form`、把带文件名的部件归到 `files`，正好印证了 `multipart` 对两类字段的区分。`Form::file("field", path)` 是异步方法（要 `.await`），它会自动根据扩展名推断 MIME 类型并**流式发送**，不会把整个文件读进内存——所以上传几个 GB 的大文件也不会爆内存。注意返回值用了 `Box<dyn std::error::Error>`，因为 `file()` 读盘可能产生 `std::io::Error`，与 `reqwest::Error` 用一个 `?` 统一处理。如果文件内容来自内存而非磁盘，则用 `Part::bytes(...).file_name(...).mime_str(...)?` 构造部件再 `.part("field", part)`。

## 六、响应处理

`send()` 返回的 `Response` 提供三类能力：查状态、读 header、取 body。**关键约束是 `text()` / `json()` / `bytes()` 会按值消费 `self`**，所以要在消费 body 之前先把状态和 header 取出来。

### 6.1 响应状态

`status()` 返回 `StatusCode`，它带有一组语义化的判断方法；`error_for_status()` 则能把 4xx/5xx 直接转成 `Err`，方便用 `?` 短路。

**语法：**

```rust
Response::status(&self) -> StatusCode
StatusCode::is_success(&self) -> bool       // 2xx
StatusCode::is_redirection(&self) -> bool   // 3xx
StatusCode::is_client_error(&self) -> bool  // 4xx
StatusCode::is_server_error(&self) -> bool  // 5xx
Response::error_for_status(self) -> Result<Response, Error>
```

```rust
use reqwest::{Client, StatusCode};

#[tokio::main]
async fn main() -> Result<(), reqwest::Error> {
    let client = Client::new();

    // 让 httpbin 返回指定状态码
    let resp = client.get("https://httpbin.org/status/404").send().await?;
    let status = resp.status();

    println!("status code  = {}", status.as_u16());
    println!("is_success   = {}", status.is_success());
    println!("is_client_err= {}", status.is_client_error());
    println!("== NOT_FOUND = {}", status == StatusCode::NOT_FOUND);

    // error_for_status() 把 4xx/5xx 直接转成 Err，方便用 ? 短路
    match resp.error_for_status() {
        Ok(_) => println!("ok"),
        Err(e) => println!("error_for_status -> {}", e.status().unwrap()),
    }
    Ok(())
}
```

运行结果：

```
status code  = 404
is_success   = false
is_client_err= true
== NOT_FOUND = true
error_for_status -> 404 Not Found
```

> 一个高频误解：HTTP 返回 404 或 500 **不是** `reqwest` 的错误——`send()` 依然返回 `Ok(Response)`，因为网络层面请求是成功的。只有连接失败、超时、解码失败才会让 `send()` 返回 `Err`。想把"业务上的失败状态码"也当错误处理，就显式调用 `error_for_status()`。

### 6.2 响应报文解析

读取 body 有多种形态，按需选择：

| 方法 | 返回 | 说明 |
|------|------|------|
| `text()` | `String` | 按 `Content-Type` 探测字符集解码，无法识别时回退 UTF-8 |
| `text_with_charset(enc)` | `String` | 指定默认字符集（需 `charset` feature） |
| `bytes()` | `Bytes` | 整个 body 的原始字节，适合二进制 |
| `json::<T>()` | `T` | 反序列化为类型 `T`（需 `json` feature） |
| `chunk()` | `Option<Bytes>` | 循环调用，逐块读取（流式） |
| `bytes_stream()` | `Stream<Item=Result<Bytes>>` | 作为 `Stream` 处理（需 `stream` feature） |

```rust
use reqwest::Client;

#[tokio::main]
async fn main() -> Result<(), reqwest::Error> {
    let client = Client::new();
    let resp = client.get("https://httpbin.org/json").send().await?;

    // 消费前先把需要的元信息拿出来（text()/bytes() 会消费掉 resp）
    println!("status      = {}", resp.status());
    println!("content-type= {:?}", resp.headers().get("content-type"));
    if let Some(len) = resp.content_length() {
        println!("content-len = {len}");
    }

    let bytes = resp.bytes().await?;
    println!("body bytes  = {}", bytes.len() > 0);
    Ok(())
}
```

运行结果：

```
status      = 200 OK
content-type= Some("application/json")
content-len = 429
body bytes  = true
```

`content_length()` 来自响应的 `Content-Length` 头，返回 `Option<u64>`——服务端用 chunked 传输时没有这个头，会返回 `None`，所以下载进度条逻辑要对 `None` 做兜底。

上面的 `text()` / `bytes()` 都是**一次性**把整个 body 读进内存，body 很大或服务端持续推送（如 SSE、日志流）时并不合适。`reqwest` 给了两种增量读取方式：`chunk()` 在循环里逐块拉取，`bytes_stream()` 把 body 暴露成一个 `Stream`。两者底层一样，区别只在调用风格——`chunk()` 是命令式的 `while let`，`bytes_stream()` 能接入 `futures` 的 `Stream` 组合子生态。

下面用 httpbin 的 `/stream/5` 端点演示：它返回 5 行、每行一个独立 JSON 对象（即 JSONL 格式），非常适合边收边处理。两种方式各做一件真实的事——`chunk()` 跨块拼出完整行并解析出每行的 `id`，`bytes_stream()` 边收边统计字节数与行数：

```rust
use reqwest::Client;
use futures_util::StreamExt;
use serde_json::Value;

#[tokio::main]
async fn main() -> Result<(), reqwest::Error> {
    let client = Client::new();

    // 方式一：chunk() 逐块取，跨块拼出完整行后解析，提取每行的 id 字段
    let mut resp = client.get("https://httpbin.org/stream/5").send().await?;
    let mut buf = String::new();
    let mut ids = Vec::new();
    while let Some(chunk) = resp.chunk().await? {
        buf.push_str(&String::from_utf8_lossy(&chunk));
        // 只处理已收齐的整行，残缺的一行留在 buf 里等下一块
        while let Some(pos) = buf.find('\n') {
            let line: String = buf.drain(..=pos).collect();
            if let Ok(v) = serde_json::from_str::<Value>(line.trim()) {
                ids.push(v["id"].as_i64().unwrap());
            }
        }
    }
    println!("[chunk]  ids = {:?}", ids);

    // 方式二：bytes_stream() 当作 Stream 迭代，边收边累加字节并统计行数
    let resp = client.get("https://httpbin.org/stream/5").send().await?;
    let mut stream = resp.bytes_stream();
    let (mut total, mut lines) = (0usize, 0usize);
    while let Some(item) = stream.next().await {
        let bytes = item?;
        total += bytes.len();
        lines += bytes.iter().filter(|&&b| b == b'\n').count();
    }
    println!("[stream] total>0 = {}, lines = {}", total > 0, lines);
    Ok(())
}
```

运行结果：

```
[chunk]  ids = [0, 1, 2, 3, 4]
[stream] total>0 = true, lines = 5
```

这里有个流式处理的通用要点：**网络分块的边界和业务记录的边界（这里是行）并不对齐**——一个 chunk 可能切在某行中间。所以 `chunk()` 那段用一个 `buf` 暂存，只处理已经出现 `\n` 的完整行，残缺的半行留到下一块再拼，避免把一行 JSON 解析到一半。其余两点：`chunk()` 会推进响应内部读取位置，接收它的 `resp` 必须声明为 `mut`；`bytes_stream()` 按值消费 `resp` 返回 `Stream`，其 `.next()` 来自 `futures_util::StreamExt`，每个元素是 `Result<Bytes, Error>`，网络中断会在迭代途中以 `Err` 暴露，所以每个 chunk 都要用 `?`。把流式数据落盘的完整示例见第八节文件下载。

## 七、重定向控制

`reqwest` 默认会自动跟随重定向，但有上限以防死循环。重定向策略通过 `ClientBuilder::redirect()` 配置。

**语法：**

```rust
ClientBuilder::redirect(policy: redirect::Policy) -> ClientBuilder
```

**参数（`redirect::Policy` 的几种构造）：**

| 构造方法 | 行为 |
|----------|------|
| `Policy::limited(n)` | 最多自动跟随 `n` 次；默认策略等价于 `limited(10)` |
| `Policy::none()` | 完全不跟随，直接返回 3xx 原始响应 |
| `Policy::custom(f)` | 自定义闭包，按目标 URL 决定 `follow` / `stop` |

```rust
use reqwest::{Client, redirect::Policy};

#[tokio::main]
async fn main() -> Result<(), reqwest::Error> {
    // 默认策略：最多自动跟随 10 次重定向
    let default_client = Client::new();
    let resp = default_client
        .get("https://httpbin.org/redirect/3")
        .send()
        .await?;
    println!("[follow]  final status = {}", resp.status());
    println!("[follow]  final url    = {}", resp.url().path());

    // 关闭自动重定向：拿到 3xx 原始响应自己处理
    let no_redirect = Client::builder().redirect(Policy::none()).build()?;
    let resp = no_redirect
        .get("https://httpbin.org/redirect/3")
        .send()
        .await?;
    println!("[none]    status = {}", resp.status());
    println!("[none]    location = {:?}", resp.headers().get("location"));
    Ok(())
}
```

运行结果：

```
[follow]  final status = 200 OK
[follow]  final url    = /get
[none]    status = 302 Found
[none]    location = Some("/relative-redirect/2")
```

跟随重定向后，`resp.url()` 是**最终落地**的 URL 而非最初请求的，可以用它判断是否发生过跳转。关闭重定向在某些场景下是刚需，比如你要捕获短链服务返回的 `Location` 而不真正访问目标，或要严格防止跨域跳转泄露 `Authorization` 头。

## 八、文件下载

下载大文件时，绝不要用 `bytes()` 把整个响应读进内存——几个 GB 的文件会直接撑爆。正确做法是用 `bytes_stream()` **边收边写盘**，内存占用始终只有单个 chunk 大小。这正是第一节提到的"`send()` 与 body 分离"设计的价值所在。

**语法：**

```rust
Response::bytes_stream(self) -> impl Stream<Item = Result<Bytes, Error>>
```

```rust
use reqwest::Client;
use futures_util::StreamExt;
use tokio::io::AsyncWriteExt;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::new();

    // 下载 64KB 随机字节，边收边写盘，不把整个 body 读进内存
    let resp = client
        .get("https://httpbin.org/bytes/65536")
        .send()
        .await?
        .error_for_status()?;

    let total = resp.content_length();
    let mut file = tokio::fs::File::create("/tmp/reqwest_download.bin").await?;
    let mut stream = resp.bytes_stream();

    let mut downloaded: u64 = 0;
    while let Some(chunk) = stream.next().await {
        let chunk = chunk?;
        downloaded += chunk.len() as u64;
        file.write_all(&chunk).await?;
    }
    file.flush().await?;

    println!("content-length = {total:?}");
    println!("downloaded     = {downloaded} bytes");
    Ok(())
}
```

运行结果：

```
content-length = Some(65536)
downloaded     = 65536 bytes
```

几个要点：`bytes_stream()` 需要 `stream` feature，`.next()` 来自 `futures_util::StreamExt`，缺任意一个都编译不过。这里返回值用 `Box<dyn std::error::Error>` 而非 `reqwest::Error`，因为循环里同时可能产生 `reqwest::Error`（网络）和 `std::io::Error`（写盘），`Box<dyn Error>` 能用一个 `?` 统一向上抛。把累加的 `downloaded` 和 `content_length()` 对比，就能实现下载进度条。

## 九、超时与错误处理

第二节已经配置了 `timeout`，这里看它触发时如何被识别。`reqwest::Error` 不是单一错误，而是携带分类信息，用一组 `is_xxx()` 方法判断成因，从而做出不同的重试/降级决策。

**语法：**

```rust
Error::is_timeout(&self) -> bool   // 连接或读取超时
Error::is_connect(&self) -> bool   // 建立连接阶段失败
Error::is_status(&self) -> bool    // 由 error_for_status() 产生的状态错误
Error::is_decode(&self) -> bool    // 响应体解码/反序列化失败
Error::status(&self) -> Option<StatusCode>  // 关联的状态码（若有）
```

```rust
use reqwest::Client;
use std::time::Duration;

#[tokio::main]
async fn main() {
    let client = Client::builder()
        .timeout(Duration::from_secs(2))
        .build()
        .unwrap();

    // httpbin /delay/5 会拖 5 秒，必然超过 2 秒超时
    match client.get("https://httpbin.org/delay/5").send().await {
        Ok(resp) => println!("status = {}", resp.status()),
        Err(e) => {
            println!("is_timeout = {}", e.is_timeout());
            println!("is_connect = {}", e.is_connect());
            println!("is_status  = {}", e.is_status());
        }
    }
}
```

运行结果：

```
is_timeout = true
is_connect = false
is_status  = false
```

区分这些类别在实战中很有用：`is_timeout()` 和 `is_connect()` 通常是**可重试**的瞬时故障，适合做指数退避重试；而 `is_status()`（如 400 参数错误）是确定性失败，重试毫无意义，应直接上报。

## 十、认证

`reqwest` 为两种最常见的认证方案提供了便捷方法，本质都是帮你设置 `Authorization` 头。

**语法：**

```rust
RequestBuilder::basic_auth(username, password: Option<P>) -> RequestBuilder
RequestBuilder::bearer_auth(token) -> RequestBuilder
```

| 方法 | 生成的头 | 说明 |
|------|---------|------|
| `basic_auth(user, Some(pass))` | `Authorization: Basic base64(user:pass)` | HTTP Basic 认证，密码可传 `None` 表示只有用户名 |
| `bearer_auth(token)` | `Authorization: Bearer <token>` | 适用于 OAuth2 / JWT 等令牌认证 |

```rust
use reqwest::Client;
use serde_json::Value;

#[tokio::main]
async fn main() -> Result<(), reqwest::Error> {
    let client = Client::new();

    // Basic 认证：httpbin /basic-auth/{user}/{passwd} 校验通过返回 authenticated=true
    let resp = client
        .get("https://httpbin.org/basic-auth/alice/secret")
        .basic_auth("alice", Some("secret"))
        .send()
        .await?;
    println!("[basic]  status = {}", resp.status());
    let json: Value = resp.json().await?;
    println!("[basic]  authenticated = {}", json["authenticated"]);

    // Bearer 认证：httpbin /bearer 校验 Authorization: Bearer <token>
    let resp = client
        .get("https://httpbin.org/bearer")
        .bearer_auth("my-token-xyz")
        .send()
        .await?;
    println!("[bearer] status = {}", resp.status());
    let json: Value = resp.json().await?;
    println!("[bearer] token = {}", json["token"]);
    Ok(())
}
```

运行结果：

```
[basic]  status = 200 OK
[basic]  authenticated = true
[bearer] status = 200 OK
[bearer] token = "my-token-xyz"
```

如果认证信息是全局固定的（比如调用某个内部服务的固定令牌），更推荐用第三节的 `default_headers` 把 `Authorization` 设为默认头，避免每个请求重复写。

## 十一、blocking 同步客户端

前面全部用异步 API，但有些场景并不需要 `tokio`——比如一个简单的命令行工具、一段构建脚本、或在已有同步代码里偶尔发个请求。这时引入整个异步运行时是过度设计，`reqwest::blocking` 正是为此准备的同步客户端，需要开启 `blocking` feature：

```toml
reqwest = { version = "0.12", features = ["json", "blocking"] }
```

```rust
fn main() -> Result<(), reqwest::Error> {
    let client = reqwest::blocking::Client::new();
    let resp = client.get("https://httpbin.org/get").send()?;
    println!("status = {}", resp.status());
    let body = resp.text()?;
    println!("len = {}", body.len());
    Ok(())
}
```

它和异步版的 API 几乎一一对应，只是去掉了所有 `.await`、`async fn` 和 `#[tokio::main]`。两者的取舍很清晰：

| 维度  | `reqwest::Client`（异步） | `reqwest::blocking::Client`（同步） |
| --- | --------------------- | ------------------------------- |
| 运行时 | 需要 `tokio` 等异步运行时     | 无需运行时，内部自建线程跑异步                 |
| 并发  | 单线程可并发数千请求            | 每个请求阻塞当前线程                      |
| 适用  | Web 服务、高并发客户端         | CLI 工具、脚本、同步代码集成                |

> 绝对不要在异步上下文（如 `#[tokio::main]` 或任一 `.await` 链路）里调用 `blocking::Client`——它会阻塞整个 `tokio` 工作线程，可能导致死锁。同步和异步两套 API 不要混用。

至此，`reqwest` 从连接池配置、请求构建（header / query / form / json / multipart）到响应消费（状态 / 报文 / JSON / 流式下载），再到重定向、超时、认证的全套常用能力就梳理完了。记住那条主线——**复用一个 `Client`，链式构建请求，按需消费响应**——剩下的都是在这个骨架上按业务叠加细节。
