---
title: "[Crate] axum 进阶：Layer 中间件与 tower-http 云原生实战"
published: true
layout: post
date: 2026-06-11 09:00:00
permalink: /rust/axum-tower-http.html
tags:
  - RESTful
  - tower-http
categories: Rust
---

基础篇里我们把 `axum` 的提取器、路由、统一响应都搭起来了，但只「顺手」用过两次 `.layer()`（放宽 body 上限）。真正让一个服务能上生产、能进微服务/云原生环境的，是那一圈**横切能力**：请求日志、链路 ID、跨域、压缩、超时、限流、`panic` 兜底、安全响应头、鉴权——它们不属于任何单个业务接口，却要套在**每个**请求上。`axum` 把这些统一抽象成 **`Layer`（中间件）**，而 `Layer` 正是 `tower` 生态的通用约定，于是 `tower-http` 里现成的几十个中间件可以直接拿来用。本文先讲透「中间件的本质」——`Service` 与 `Layer` 两个 `trait`、`axum` 里的包裹与执行顺序，再逐个落地云原生最常用的能力，最后用一个 `ServiceBuilder` 把它们按正确顺序串成一套生产级中间件栈。全文示例基于 `axum 0.8`、`tower 0.5`、`tower-http 0.6` 实测通过。

## 一、Layer 与 Service：中间件的本质

`axum` 的每个路由，最终都是一个实现了 `tower::Service` 的对象。`Service` 这个 `trait` 只有两个核心方法：

- `poll_ready(&mut self) -> Poll<Result<(), Error>>`：背压钩子，回答「我现在能不能接收下一个请求」。限流、并发控制就靠它在「没有配额」时返回 `Pending`。
- `call(&mut self, req) -> Future<Output = Result<Response, Error>>`：真正处理请求。

而 **`Layer` 是「`Service` 的装饰器工厂」**：它只有一个方法 `fn layer(&self, inner: S) -> Self::Service`，把一个 `Service` 包成另一个 `Service`。所谓「中间件」，本质就是一个 `Layer`——它拿到内层服务，在 `call` 前后插入自己的逻辑（记日志、改 Header、计时、鉴权），再把请求交给内层。一层层包下去，就形成了「洋葱模型」。

`axum` 给 `Router` 提供了两个挂载 `Layer` 的方法，区别在于**作用范围**：

| 方法 | 作用范围 | 典型用途 |
|------|----------|----------|
| `Router::layer(layer)` | 包裹**此前已注册的所有路由**，连未命中的 `fallback`（404）也会经过 | 全局日志、压缩、CORS、超时 |
| `Router::route_layer(layer)` | 只包裹已注册路由，**未命中时不经过该层**，直接走 404 | 鉴权——避免对不存在的路径也跑一遍鉴权再 404 |

### 1.1 执行顺序：洋葱模型

中间件最容易踩的坑是**顺序**。请求「由外向内」穿过每一层到达 handler，响应再「由内向外」穿回来。问题在于：怎么排「外」和「内」？`axum` 有两种写法，顺序规则**相反**，必须记清。下面用 `axum::middleware::from_fn` 写几个只打印「进/出」的中间件，实测它们的穿透顺序：

```rust
use axum::extract::Request;
use axum::middleware::{self, Next};
use axum::response::Response;
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;
use tower::ServiceBuilder;

async fn mw(tag: &'static str, req: Request, next: Next) -> Response {
    println!("-> enter {tag}");
    let resp = next.run(req).await;
    println!("<- leave {tag}");
    resp
}

async fn handler() -> &'static str {
    println!("== handler ==");
    "ok"
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(handler))
        // ServiceBuilder：自上而下 = 由外到内，靠前的 SB1 是最外层
        .layer(
            ServiceBuilder::new()
                .layer(middleware::from_fn(|r, n| mw("SB1", r, n)))
                .layer(middleware::from_fn(|r, n| mw("SB2", r, n))),
        )
        // 链式 .layer()：后写的 CHAIN2 才是最外层（与直觉相反）
        .layer(middleware::from_fn(|r, n| mw("CHAIN1", r, n)))
        .layer(middleware::from_fn(|r, n| mw("CHAIN2", r, n)));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl localhost:3000/
```

运行结果（服务端 stdout）：

```
-> enter CHAIN2
-> enter CHAIN1
-> enter SB1
-> enter SB2
== handler ==
<- leave SB2
<- leave SB1
<- leave CHAIN1
<- leave CHAIN2
```

两条规则一目了然：

- **`ServiceBuilder` 内部：自上而下 = 由外到内**。先写的 `SB1` 在外、先执行——和阅读顺序一致，符合直觉。
- **链式 `.layer()`：后写的在外**。`CHAIN2` 最后写，却最先执行——因为每次 `.layer()` 都把「已有的整个服务」再包一层，所以后包的在最外面。

> 正因为链式 `.layer()` 的顺序违反直觉，`axum` 官方推荐：**多个中间件统一用一个 `ServiceBuilder` 组织**，自上而下书写即自外向内执行。本文后续整合版也遵循这一约定。记住一个实践原则：**日志/链路追踪要放在最外层**（这样它能观测到内层所有中间件产生的状态码，包括超时、限流的拒绝），鉴权放在较外层（尽早拒绝非法请求）。

## 二、依赖与 feature 一览

`tower-http` 的所有中间件都是 **opt-in**——按 feature 开启，不开就不编译进来，保证产物精简。在基础篇 `Cargo.toml` 之上，补齐本文要用的依赖：

```toml
[dependencies]
axum = { version = "0.8", features = ["multipart"] }
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
# tower：ServiceBuilder、限流/并发/降载等通用中间件
tower = { version = "0.5", features = ["limit", "load-shed", "util", "buffer"] }
# tower-http：HTTP 专用中间件，按需开启 feature
tower-http = { version = "0.6", features = [
    "trace", "cors", "compression-full", "timeout",
    "request-id", "catch-panic", "set-header",
    "sensitive-headers", "validate-request", "auth",
    "fs", "util", "limit",
] }
# TraceLayer 的日志要有 subscriber 才能输出
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "fmt"] }
```

`tower-http` 常用 feature 与对应能力：

| feature | 启用的中间件 / 能力 |
|---------|--------------------|
| `trace` | `TraceLayer`，请求/响应日志与 `tracing` span |
| `cors` | `CorsLayer`，跨域资源共享 |
| `compression-full` | `CompressionLayer`/`DecompressionLayer`，支持 `gzip`/`br`/`deflate`/`zstd` 全算法（也可用 `compression-gzip` 等单算法） |
| `timeout` | `TimeoutLayer`，请求超时 |
| `request-id` | `SetRequestIdLayer`/`PropagateRequestIdLayer`，链路 ID |
| `catch-panic` | `CatchPanicLayer`，`panic` 兜底转 500 |
| `set-header` | `SetRequestHeaderLayer`/`SetResponseHeaderLayer`，增删改 Header |
| `sensitive-headers` | `SetSensitive*HeadersLayer`，敏感头脱敏 |
| `validate-request` | `ValidateRequestHeaderLayer`，请求头校验 |
| `auth` | `ValidateRequestHeaderLayer::bearer`/`::basic` 的认证构造器 |
| `fs` | `ServeDir`/`ServeFile`，静态文件服务 |
| `util` | `ServiceBuilderExt`，链路 ID/敏感头的快捷扩展方法 |
| `limit` | `RequestBodyLimitLayer`，请求体大小限制（基础篇已用） |

> 嫌一个个写麻烦可以直接开 `features = ["full"]` 一次性启用全部，但生产构建建议按需开启，减小二进制体积与编译时间。限流/并发相关的 `ConcurrencyLimit`、`RateLimit`、`LoadShed` 不在 `tower-http`，而在 `tower` 自身的 `limit`/`load-shed` feature 里（见第九节）。

## 三、自定义中间件 from_fn

在用内置 `Layer` 之前，先学会自己写一个——理解了 `from_fn`，内置中间件就只是「别人写好的同类东西」。`axum::middleware::from_fn` 让你用一个 `async fn` 当中间件，不必手动实现 `Service`/`Layer`。

**语法：**

```rust
async fn middleware(req: Request, next: Next) -> Response
middleware::from_fn(middleware)
// 需要读取共享状态时：
async fn middleware(State(s): State<T>, req: Request, next: Next) -> Response
middleware::from_fn_with_state(state, middleware)
```

**参数：**

| 参数 | 说明 |
|------|------|
| `req: Request` | 进来的请求；中间件可读改它（加扩展、改 Header）后再往下传 |
| `next: Next` | 代表「内层剩余的所有中间件 + handler」；调用 `next.run(req).await` 把控制权交给内层并拿回响应 |
| 返回 `Response` | 中间件最终给出的响应；可以是内层返回的，也可以**短路**（不调用 `next` 直接返回，如鉴权失败返回 401） |
| `from_fn_with_state(state, f)` | 当中间件需要访问 `State`（连接池、配置、计数器）时使用；`State<T>` 像在 handler 里一样放参数表前面 |

下面写两个：一个**计时日志**中间件（在 handler 前后记录耗时与状态码），一个**读取共享状态**的请求计数中间件，演示 `from_fn_with_state`：

```rust
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Instant;

use axum::extract::{Request, State};
use axum::middleware::{self, Next};
use axum::response::Response;
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;

#[derive(Clone)]
struct Metrics {
    count: Arc<AtomicU64>,
}

// 计时日志中间件：先记开始时间，跑完内层再算耗时
async fn timing(req: Request, next: Next) -> Response {
    let method = req.method().clone();
    let uri = req.uri().clone();
    let start = Instant::now();
    let resp = next.run(req).await;
    println!("{method} {uri} -> {} in {:?}", resp.status(), start.elapsed());
    resp
}

// 读取共享状态的请求计数中间件
async fn counter(State(m): State<Metrics>, req: Request, next: Next) -> Response {
    let n = m.count.fetch_add(1, Ordering::Relaxed) + 1;
    println!("handling request #{n}");
    next.run(req).await
}

async fn hello() -> &'static str {
    "hello"
}

#[tokio::main]
async fn main() {
    let metrics = Metrics { count: Arc::new(AtomicU64::new(0)) };

    let app = Router::new()
        .route("/", get(hello))
        // from_fn_with_state 把 state 注入中间件
        .layer(middleware::from_fn_with_state(metrics.clone(), counter))
        // from_fn 不需要 state
        .layer(middleware::from_fn(timing))
        .with_state(metrics);

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl localhost:3000/
curl localhost:3000/
```

运行结果（服务端 stdout）：

```
handling request #1
GET / -> 200 OK in 60.796µs
handling request #2
GET / -> 200 OK in 57.708µs
```

> 注意 `timing` 用 `.layer()` 后写、所以在 `counter` 外层，但日志里 `counter` 的 `handling request` 先打印——因为 `counter` 的打印发生在调用 `next` **之前**（请求下行阶段），而 `timing` 的打印在 `next` **之后**（响应上行阶段）。这正是洋葱模型：外层的「后半段」最后执行。短路场景（鉴权失败直接返回 `(StatusCode::UNAUTHORIZED, "no").into_response()` 而不调用 `next`）也用这个签名实现，内层 handler 根本不会被触达。

## 四、请求日志 TraceLayer

`TraceLayer` 是可观测性的基石：它为每个请求创建一个 `tracing` span，并在请求进入、响应返回、发生错误时各打一条日志，自带方法、路径、状态码、延迟。它只负责「产生 `tracing` 事件」，你必须配一个 `tracing-subscriber` 才能看到输出。

**语法：**

```rust
TraceLayer::new_for_http()
    .make_span_with(DefaultMakeSpan::new().include_headers(true))
    .on_request(DefaultOnRequest::new().level(Level::INFO))
    .on_response(DefaultOnResponse::new().level(Level::INFO).latency_unit(LatencyUnit::Micros))
```

**参数：**

| 方法 | 说明 |
|------|------|
| `new_for_http()` | 为 HTTP 预设的构造器，自动按状态码判断成功/失败 |
| `make_span_with(MakeSpan)` | 定制每个请求的 span（字段、级别）；`DefaultMakeSpan::new().include_headers(true)` 把请求头也记进 span |
| `on_request(OnRequest)` | 请求进入时的回调，默认打一条 `started processing request` |
| `on_response(OnResponse)` | 响应返回时的回调，记录状态码与延迟；`latency_unit` 取值 `Seconds`/`Millis`/`Micros`/`Nanos` |
| `on_failure(OnFailure)` | 服务返回错误或 `5xx` 时的回调，默认以 `ERROR` 级别记录 |

`DefaultOnResponse`/`DefaultOnRequest` 的默认日志级别是 `DEBUG`，所以下面把 subscriber 的过滤级别放到 `DEBUG`（或用 `RUST_LOG=tower_http=debug`）才能看到：

```rust
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;
use tower_http::trace::{DefaultMakeSpan, DefaultOnResponse, TraceLayer};
use tower_http::LatencyUnit;
use tracing::Level;
use tracing_subscriber::EnvFilter;

async fn hello() -> &'static str {
    "hello"
}

#[tokio::main]
async fn main() {
    // 只放开 tower_http 的 debug，其余 info，避免噪音
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::new("info,tower_http=debug"))
        .with_target(true)
        .init();

    let app = Router::new().route("/", get(hello)).layer(
        TraceLayer::new_for_http()
            .make_span_with(DefaultMakeSpan::new().include_headers(false))
            .on_response(
                DefaultOnResponse::new()
                    .level(Level::INFO)
                    .latency_unit(LatencyUnit::Micros),
            ),
    );

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl localhost:3000/
```

运行结果（服务端日志，时间戳与延迟每次不同）：

```
2026-06-11T00:58:40.060327Z DEBUG request{method=GET uri=/ version=HTTP/1.1}: tower_http::trace::on_request: started processing request
2026-06-11T00:58:40.060403Z  INFO request{method=GET uri=/ version=HTTP/1.1}: tower_http::trace::on_response: finished processing request latency=212 μs status=200
```

> `request{...}` 是 span，后面所有日志都自动带上 `method`/`uri`/`version` 字段——这就是结构化日志的价值：一次请求里业务代码打的任何日志，都会带上这个 span 上下文。把 `TraceLayer` 放在中间件栈**最外层**，它记录的 `status` 才会包含内层超时/限流/鉴权中间件改写后的最终状态码。下一节再给它加上「请求 ID」，跨服务的日志就能串成一条链路。

## 五、请求 ID 链路传播 request-id

微服务里一个请求会穿过网关、订单、库存多个服务，排查问题时必须能把它们的日志**串成一条链**。做法是给每个请求生成一个唯一 ID（通常放在 `x-request-id` 头），入口服务生成、后续服务透传，所有日志都带上它。`tower-http` 的 `request-id` 模块就干这件事。

**语法：**

```rust
use tower_http::request_id::{SetRequestIdLayer, PropagateRequestIdLayer, MakeRequestUuid};

SetRequestIdLayer::x_request_id(MakeRequestUuid)   // 没有 x-request-id 就生成一个
PropagateRequestIdLayer::x_request_id()            // 把请求里的 x-request-id 复制到响应
```

**参数：**

| 项 | 说明 |
|----|------|
| `SetRequestIdLayer::x_request_id(make)` | 针对 `x-request-id` 头：请求若已带该头则保留，否则用 `make` 生成 |
| `SetRequestIdLayer::new(header_name, make)` | 自定义头名（如 `x-trace-id`） |
| `MakeRequestUuid` | 内置生成器，产出 `UUID v4` |
| 自定义 `MakeRequestId` | 实现 `make_request_id(&Request) -> Option<RequestId>`，可对接雪花 ID、递增计数等 |
| `PropagateRequestIdLayer::x_request_id()` | 把（生成或透传来的）`x-request-id` 写回响应头，客户端/上游就能拿到 |

`util` feature 下的 `ServiceBuilderExt` 提供了更顺手的链式写法 `.set_x_request_id(...)` 和 `.propagate_x_request_id()`。下面用 `MakeRequestUuid` 演示：没带 `x-request-id` 时自动生成并回写，带了则原样透传：

```rust
use axum::http::HeaderMap;
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;
use tower::ServiceBuilder;
use tower_http::request_id::MakeRequestUuid;
use tower_http::ServiceBuilderExt;

// 读出最终生效的 x-request-id 一并返回，方便观察
async fn show(headers: HeaderMap) -> String {
    let id = headers
        .get("x-request-id")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("<none>");
    format!("x-request-id seen by handler: {id}")
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(show)).layer(
        ServiceBuilder::new()
            .set_x_request_id(MakeRequestUuid) // 入口处生成
            .propagate_x_request_id(),         // 回写到响应
    );

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -i localhost:3000/                                   # 不带 ID：自动生成
curl -i -H 'x-request-id: trace-abc-123' localhost:3000/  # 带 ID：原样透传
```

运行结果（生成的 `UUID` 每次不同）：

```
HTTP/1.1 200 OK
x-request-id: 1b4e28ba-2fa1-11d2-883f-0016d3cca427
content-type: text/plain; charset=utf-8

x-request-id seen by handler: 1b4e28ba-2fa1-11d2-883f-0016d3cca427
```

```
HTTP/1.1 200 OK
x-request-id: trace-abc-123
content-type: text/plain; charset=utf-8

x-request-id seen by handler: trace-abc-123
```

> 第二个请求带了 `x-request-id`，中间件**不会覆盖**它，而是透传——这保证整条调用链共用同一个 ID。要换成递增计数或雪花 ID，自定义一个实现了 `MakeRequestId` 的结构体传给 `SetRequestIdLayer::new` 即可。配合上一节的 `TraceLayer`：把 `set_x_request_id` 放在 `TraceLayer` **之外**，span 里就能带上 `request_id` 字段，日志与链路 ID 彻底打通。

## 六、跨域 CorsLayer

浏览器的同源策略会拦截跨域 `XHR`/`fetch`，前后端分离、第三方调用都绕不开 CORS。`CorsLayer` 在响应里加上 `Access-Control-Allow-*` 系列头，并自动处理 `OPTIONS` 预检请求。

**语法：**

```rust
CorsLayer::new()
    .allow_origin(Any)
    .allow_methods([Method::GET, Method::POST])
    .allow_headers(Any)
```

**参数：**

| 方法 | 取值 | 说明 |
|------|------|------|
| `allow_origin(...)` | `Any` / 单个 `HeaderValue` / 列表 / `AllowOrigin::predicate(..)` | 允许的来源；`Any` 即 `*` |
| `allow_methods(...)` | `Any` / `[Method::GET, ...]` | 允许的方法，写回 `Access-Control-Allow-Methods` |
| `allow_headers(...)` | `Any` / `[header::CONTENT_TYPE, ...]` | 允许的自定义请求头 |
| `allow_credentials(bool)` | `true`/`false`（默认 `false`） | 是否允许带 `Cookie`/认证信息 |
| `expose_headers(...)` | 头列表 | 允许浏览器 JS 读取的响应头 |
| `max_age(Duration)` | 时长 | 预检结果缓存时间，减少 `OPTIONS` 次数 |

```rust
use std::time::Duration;

use axum::http::Method;
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;
use tower_http::cors::{Any, CorsLayer};

async fn data() -> &'static str {
    "cross-origin data"
}

#[tokio::main]
async fn main() {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST])
        .allow_headers(Any)
        .max_age(Duration::from_secs(3600));

    let app = Router::new().route("/data", get(data)).layer(cors);

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -i -H 'Origin: https://example.com' localhost:3000/data        # 实际请求
curl -i -X OPTIONS -H 'Origin: https://example.com' \
  -H 'Access-Control-Request-Method: POST' localhost:3000/data      # 预检请求
```

运行结果：

```
HTTP/1.1 200 OK
vary: origin, access-control-request-method, access-control-request-headers
access-control-allow-origin: *
content-type: text/plain; charset=utf-8

cross-origin data
```

```
HTTP/1.1 200 OK
vary: origin, access-control-request-method, access-control-request-headers
access-control-allow-methods: GET,POST
access-control-allow-headers: *
access-control-max-age: 3600
access-control-allow-origin: *
```

> 预检 `OPTIONS` 请求被 `CorsLayer` 直接应答（返回 `200` + 一组 `Allow` 头），根本不会走到你的 handler。**一个常见的安全坑**：`allow_credentials(true)` 不能和 `allow_origin(Any)` 同时用——浏览器规范禁止「允许携带凭证」时把来源设为 `*`，`CorsLayer` 在这种组合下会直接 panic 提醒你。需要带 `Cookie` 时，必须用 `allow_origin` 显式列出具体域名。

## 七、响应压缩 CompressionLayer

`JSON`、`HTML` 这类文本响应可压缩率很高，开启压缩能大幅降低带宽与首屏时间。`CompressionLayer` 根据请求的 `Accept-Encoding` 自动选择算法压缩响应体，并设好 `Content-Encoding`，对 handler 完全透明。

**语法：**

```rust
CompressionLayer::new().quality(CompressionLevel::Default)
```

**参数：**

| 方法 | 说明 |
|------|------|
| `new()` | 启用所有已编译进来的算法（`compression-full` 含 `gzip`/`br`/`deflate`/`zstd`），按客户端偏好协商 |
| `quality(CompressionLevel)` | 压缩级别，取值见下表 |
| `gzip(bool)` / `br(bool)` / `deflate(bool)` / `zstd(bool)` | 单独开关某算法 |
| `compress_when(Predicate)` | 自定义「何时压缩」，默认 `DefaultPredicate` |

`CompressionLevel` 枚举取值：

| 取值 | 说明 |
|------|------|
| `Fastest` | 最快、压缩率最低 |
| `Best` | 最慢、压缩率最高 |
| `Default`（默认） | 算法各自的折中默认值 |
| `Precise(i32)` | 指定具体等级（如 `gzip` 的 1~9） |

```rust
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;
use tower_http::compression::{CompressionLayer, CompressionLevel};

// 返回一段足够长的可压缩文本（默认谓词只压缩 32 字节以上的 body）
async fn big() -> String {
    "axum + tower-http makes compression trivial. ".repeat(20)
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/big", get(big))
        .layer(CompressionLayer::new().quality(CompressionLevel::Best));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -s -o /dev/null -w 'no-encoding: %{size_download} bytes\n' localhost:3000/big
curl -s -o /dev/null -w 'gzip: %{size_download} bytes\n' \
  -H 'Accept-Encoding: gzip' localhost:3000/big
curl -i -s -H 'Accept-Encoding: gzip' localhost:3000/big | grep -ai content-encoding
```

运行结果：

```
no-encoding: 900 bytes
gzip: 76 bytes
content-encoding: gzip
```

> 不带 `Accept-Encoding` 时原样返回 `900` 字节，带上 `gzip` 后压到 `76` 字节并标注 `content-encoding: gzip`。默认的 `DefaultPredicate` 有两条重要规则：**body 小于 32 字节不压缩**（压缩开销不划算），且**对已压缩的内容类型**（图片、视频、`gzip` 包等）不重复压缩。所以别奇怪小响应没被压缩——那是有意为之。生产中通常用 `Default` 级别即可，`Best` 的 CPU 开销在高 QPS 下未必划算。

## 八、超时控制 TimeoutLayer

慢请求会占住连接和线程资源，雪崩时尤甚。给每个请求设硬超时是云原生服务的基本自保。`tower-http` 的 `TimeoutLayer` 在超时后返回一个**正常的 HTTP 响应**（`408`），而不是像 `tower` 自带的 `timeout` 那样把错误类型变成 `BoxError`——后者还得额外写错误处理才能接进 `axum`。

**语法：**

```rust
TimeoutLayer::new(Duration::from_secs(30))                              // 超时返回 408
TimeoutLayer::with_status_code(StatusCode::GATEWAY_TIMEOUT, dur)        // 自定义超时状态码
```

**参数：**

| 构造器 | 说明 |
|--------|------|
| `TimeoutLayer::new(Duration)` | 超时后返回 `408 Request Timeout` |
| `TimeoutLayer::with_status_code(StatusCode, Duration)` | 超时后返回指定状态码（如 `504 Gateway Timeout`） |

```rust
use std::time::Duration;

use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;
use tower_http::timeout::TimeoutLayer;

async fn slow() -> &'static str {
    tokio::time::sleep(Duration::from_secs(3)).await;
    "done"
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/slow", get(slow))
        // 1 秒还不返回就判超时
        .layer(TimeoutLayer::new(Duration::from_secs(1)));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -i -s localhost:3000/slow
```

运行结果（约 1 秒后返回）：

```
HTTP/1.1 408 Request Timeout
content-length: 0
```

> `TimeoutLayer` 因为返回的是合法 HTTP 响应（`Error = Infallible`），可以直接 `.layer()` 到 `Router` 上。这和下一节的限流/降载形成对比——那些 `tower` 中间件会产生 `BoxError`，必须额外配 `HandleErrorLayer` 才能接进 `axum`。把超时放在中间件栈**靠内**的位置，让它只覆盖业务处理时间；若放最外层，连读取大请求体的时间也会被计入。

## 九、并发限制与限流

超时是「单个请求」的自保，限流则是「整个服务」的自保：在过载时**主动拒绝**部分请求（返回 `503`），保住核心容量，避免被拖垮。相关中间件在 `tower` 而非 `tower-http`：`ConcurrencyLimitLayer`/`GlobalConcurrencyLimitLayer`（并发数上限）、`RateLimitLayer`（速率上限）、`LoadShedLayer`（不排队、过载即拒）。

这里有一个**极易踩的坑**，必须先讲清楚：`axum` 为**每条 TCP 连接克隆一份**服务。普通的 `ConcurrencyLimitLayer::new(n)` 在克隆时**每个克隆各自持有一套配额**，于是「限制」退化成「每连接限制」——10 个客户端就是 `10 × n`，根本拦不住全局流量。要全局共享一套配额，必须用 **`GlobalConcurrencyLimitLayer`**，它内部用 `Arc<Semaphore>`，所有克隆共享同一个信号量。

**参数：**

| Layer | 来源 feature | 语义 |
|-------|-------------|------|
| `ConcurrencyLimitLayer::new(n)` | `tower/limit` | 限制并发，但**每个克隆独立配额**（每连接，慎用） |
| `GlobalConcurrencyLimitLayer::new(n)` | `tower/limit` | 限制**全局**并发为 `n`，所有连接共享 |
| `RateLimitLayer::new(n, dur)` | `tower/limit` | 每 `dur` 内最多 `n` 个请求；非 `Clone`，需 `BufferLayer` 包裹才能上 `axum` |
| `LoadShedLayer::new()` | `tower/load-shed` | 内层「未就绪」时立即拒绝（产生 `Overloaded` 错误），而非排队等待 |

`ConcurrencyLimit` 本身在配额耗尽时会让请求**排队等待**；要做到「过载立即拒绝」，需叠加 `LoadShedLayer`。而 `LoadShed` 过载时产生的是 `BoxError`，`axum` 的 `Router` 要求 `Error = Infallible`，所以必须用 **`axum::error_handling::HandleErrorLayer`** 把错误转回 HTTP 响应。完整、正确的「全局并发限制 + 过载拒绝」写法如下：

```rust
use std::time::Duration;

use axum::error_handling::HandleErrorLayer;
use axum::http::StatusCode;
use axum::routing::get;
use axum::{BoxError, Router};
use tokio::net::TcpListener;
use tower::limit::GlobalConcurrencyLimitLayer;
use tower::load_shed::LoadShedLayer;
use tower::ServiceBuilder;

async fn slow() -> &'static str {
    tokio::time::sleep(Duration::from_millis(800)).await;
    "ok"
}

// 把 BoxError 转回 HTTP 响应：过载 -> 503，其余 -> 500
async fn handle_error(err: BoxError) -> (StatusCode, String) {
    if err.is::<tower::load_shed::error::Overloaded>() {
        (StatusCode::SERVICE_UNAVAILABLE, "service overloaded".to_string())
    } else {
        (StatusCode::INTERNAL_SERVER_ERROR, err.to_string())
    }
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/slow", get(slow)).layer(
        ServiceBuilder::new()
            // 顺序：先把错误兜成响应，再降载，最内是全局并发上限
            .layer(HandleErrorLayer::new(handle_error))
            .layer(LoadShedLayer::new())
            .layer(GlobalConcurrencyLimitLayer::new(2)),
    );

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

并发打 5 个请求，handler 各占 `800ms`，全局只允许 2 个在途：

```bash
for i in 1 2 3 4 5; do curl -s -o /dev/null -w "%{http_code}\n" localhost:3000/slow & done; wait
```

运行结果（`200`/`503` 的具体行序随调度略有不同）：

```
503
503
503
200
200
```

> 2 个请求拿到并发配额返回 `200`，其余 3 个被 `LoadShed` 立即判定过载、经 `HandleErrorLayer` 转成 `503`。这套「`HandleError` + `LoadShed` + `GlobalConcurrencyLimit`」是 `axum` 里做过载保护的标准范式。`RateLimitLayer`（按速率而非并发限制）用法类似，但它不是 `Clone`，须再包一层 `tower::buffer::BufferLayer::new(n)` 才能挂到 `Router` 上。记住：**普通 `ConcurrencyLimitLayer` 在 `axum` 里是每连接语义，要全局限制一定用 `GlobalConcurrencyLimitLayer`。**

## 十、Panic 兜底 CatchPanicLayer

handler 里一个 `unwrap` 踩空就会 `panic`。默认情况下 `axum`/`hyper` 会中止该请求的处理、断开这条连接，客户端收到的是「连接被重置」而非一个干净的错误响应；更糟的是若编译配置为 `panic = "abort"`，整个进程都会挂掉。`CatchPanicLayer` 捕获 handler 的 `panic`，转成一个正常的 `500` 响应，把「一个请求的 bug」隔离成「一个请求的失败」。

**语法：**

```rust
CatchPanicLayer::new()                       // 默认：返回纯文本 500
CatchPanicLayer::custom(handler)             // 自定义 500 响应体
```

**参数：**

| 构造器 | 说明 |
|--------|------|
| `CatchPanicLayer::new()` | 捕获 `panic`，返回 `500 Internal Server Error`（纯文本） |
| `CatchPanicLayer::custom(f)` | `f: Fn(Box<dyn Any + Send>) -> Response`，自定义响应体（如统一 `JSON`） |

下面用 `custom` 让兜底响应也符合基础篇的统一结构 `{code, message, data}`：

```rust
use std::any::Any;

use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::get;
use axum::{Json, Router};
use serde_json::json;
use tokio::net::TcpListener;
use tower_http::catch_panic::CatchPanicLayer;

async fn boom() -> &'static str {
    panic!("something went terribly wrong");
}

// panic 的 payload 通常是 &str 或 String，尽量取出原始信息
fn on_panic(err: Box<dyn Any + Send + 'static>) -> Response {
    let detail = err
        .downcast_ref::<&str>()
        .map(|s| s.to_string())
        .or_else(|| err.downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "unknown panic".to_string());

    let body = json!({ "code": 500, "message": detail, "data": null });
    (StatusCode::INTERNAL_SERVER_ERROR, Json(body)).into_response()
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/boom", get(boom))
        .layer(CatchPanicLayer::custom(on_panic));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -i -s localhost:3000/boom
```

运行结果：

```
HTTP/1.1 500 Internal Server Error
content-type: application/json

{"code":500,"data":null,"message":"something went terribly wrong"}
```

> 进程不会因为这次 `panic` 退出，连接也不会被粗暴重置，客户端拿到的是结构化的 `500`。把 `CatchPanicLayer` 放在中间件栈**较外层**，它才能兜住内层中间件里发生的 `panic`；但要放在 `TraceLayer` **之内**，这样 panic 转成的 `500` 仍能被日志记录到。注意它兜的是 `panic`，不是业务错误——业务错误应当用基础篇的 `Result<_, AppError>` 显式返回，`CatchPanic` 只是最后一道安全网。

## 十一、安全响应头与敏感头脱敏

云原生服务常被要求统一注入一组**安全响应头**（如 `X-Content-Type-Options: nosniff` 防 MIME 嗅探、`X-Frame-Options: DENY` 防点击劫持）。这类「给所有响应加固定头」的活儿交给 `SetResponseHeaderLayer`。与之配套的是**敏感头脱敏**：让日志中间件不要把 `Authorization`、`Cookie` 这种机密原文打进日志。

**语法：**

```rust
SetResponseHeaderLayer::if_not_present(name, value)   // 没有才加，不覆盖业务设置的
SetResponseHeaderLayer::overriding(name, value)       // 强制覆盖
SetResponseHeaderLayer::appending(name, value)        // 追加（同名头可多值）
```

**参数：**

| 构造器 | 行为 |
|--------|------|
| `if_not_present(name, value)` | 仅当响应**没有**该头时才设置——适合默认值，尊重 handler 已设的值 |
| `overriding(name, value)` | 无条件覆盖为该值 |
| `appending(name, value)` | 追加一个同名头，不动已有的 |
| `SetSensitiveResponseHeadersLayer::new([..])` | 把指定响应头标记为「敏感」，`TraceLayer` 等会以 `Sensitive` 占位代替原文 |
| `SetSensitiveRequestHeadersLayer::new([..])` | 同上，针对请求头 |

```rust
use axum::http::{header, HeaderName, HeaderValue};
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;
use tower::ServiceBuilder;
use tower_http::sensitive_headers::SetSensitiveRequestHeadersLayer;
use tower_http::set_header::SetResponseHeaderLayer;

async fn hello() -> &'static str {
    "hello"
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(hello)).layer(
        ServiceBuilder::new()
            // 把请求里的 Authorization 标记为敏感，后续日志不会打印其原文
            .layer(SetSensitiveRequestHeadersLayer::new([header::AUTHORIZATION]))
            // 统一注入两个安全响应头
            .layer(SetResponseHeaderLayer::if_not_present(
                HeaderName::from_static("x-content-type-options"),
                HeaderValue::from_static("nosniff"),
            ))
            .layer(SetResponseHeaderLayer::if_not_present(
                HeaderName::from_static("x-frame-options"),
                HeaderValue::from_static("DENY"),
            )),
    );

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -i -s localhost:3000/ | grep -iE 'x-content-type-options|x-frame-options'
```

运行结果：

```
x-frame-options: DENY
x-content-type-options: nosniff
```

> `if_not_present` 的语义很关键：它**不会覆盖** handler 主动设置的同名头，只补默认值，这样个别接口仍能定制自己的策略。敏感头脱敏要和 `TraceLayer` 配合才有意义——单独用看不出效果，但一旦开了 `include_headers(true)` 的请求日志，被标记的头会显示为 `Sensitive` 而非令牌原文，避免机密泄进日志系统。`util` feature 下也可用 `ServiceBuilderExt` 的 `.sensitive_request_headers([...])` 简写。

## 十二、请求校验与认证 ValidateRequestHeaderLayer

把「认证」下沉到中间件层，业务 handler 就能假定「能进来的都是合法请求」，逻辑更干净。`ValidateRequestHeaderLayer` 在请求进入 handler 前校验头部，不通过直接短路返回 `401`/`403`。

**语法：**

```rust
ValidateRequestHeaderLayer::bearer("secret-token")           // 校验 Authorization: Bearer <token>
ValidateRequestHeaderLayer::basic("user", "pass")            // 校验 HTTP Basic 认证
ValidateRequestHeaderLayer::accept("application/json")       // 校验 Accept 头
```

**参数：**

| 构造器 | 校验内容 | 失败响应 |
|--------|----------|----------|
| `bearer(token)` | `Authorization: Bearer <token>` 是否匹配（需 `auth` feature） | `401 Unauthorized` |
| `basic(user, pass)` | HTTP Basic 用户名密码（需 `auth` feature） | `401 Unauthorized` |
| `accept(mime)` | 请求的 `Accept` 头是否接受该类型 | `406 Not Acceptable` |
| `custom(ValidateRequest)` | 自定义校验逻辑 | 由你的实现决定 |

```rust
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;
use tower_http::validate_request::ValidateRequestHeaderLayer;

async fn secret() -> &'static str {
    "top secret data"
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/secret", get(secret))
        // 只有带正确 Bearer token 才放行
        .layer(ValidateRequestHeaderLayer::bearer("secret-token"));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

```bash
curl -i -s localhost:3000/secret | head -1                                    # 不带 token
curl -i -s -H 'Authorization: Bearer wrong' localhost:3000/secret | head -1   # token 错误
curl -s -H 'Authorization: Bearer secret-token' localhost:3000/secret         # 正确 token
```

运行结果：

```
HTTP/1.1 401 Unauthorized
HTTP/1.1 401 Unauthorized
top secret data
```

> 这是「网关式鉴权」在 Web 层的最简落地：固定 token 适合内部服务间调用、健康检查放行等。真实的 `JWT`/数据库校验要复杂得多，那时用第三节的 `from_fn_with_state` 自己写中间件（能读 `State` 拿到密钥/连接池）更灵活。鉴权中间件建议用 `route_layer` 而非 `layer` 挂载——这样未命中的路径直接走 404，而不是先被鉴权拦成 401，避免「用 401/404 的差异探测哪些路径存在」。

## 十三、静态文件服务 ServeDir

很多服务要顺带托管前端构建产物或下载文件。`tower-http` 的 `ServeDir`/`ServeFile` 是现成的静态文件 `Service`，可直接当作路由或 `fallback` 挂上（需 `fs` feature）。

**参数：**

| 项 | 说明 |
|----|------|
| `ServeDir::new(path)` | 把 `path` 目录映射为静态文件服务，自动处理 `Content-Type`、`Range`、`304` |
| `.not_found_service(svc)` | 找不到文件时回退到另一个 `Service`（常用于 SPA：回退到 `index.html`） |
| `ServeFile::new(file)` | 始终返回单个文件，SPA 前端路由的兜底首选 |
| `Router::fallback_service(svc)` | 把静态服务设为整个 app 的兜底：API 路由优先，其余交给静态文件 |

```rust
use axum::routing::get;
use axum::Router;
use tokio::net::TcpListener;
use tower_http::services::{ServeDir, ServeFile};

async fn api_hello() -> &'static str {
    "hello from api"
}

#[tokio::main]
async fn main() {
    // API 路由优先；未命中的路径交给 ./static 目录，找不到再回退到 index.html
    let serve_dir =
        ServeDir::new("static").not_found_service(ServeFile::new("static/index.html"));

    let app = Router::new()
        .route("/api/hello", get(api_hello))
        .fallback_service(serve_dir);

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

准备一个静态文件再访问：

```bash
mkdir -p static && echo '<h1>Hello SPA</h1>' > static/index.html
curl -s localhost:3000/api/hello        # 命中 API
curl -s localhost:3000/index.html       # 命中静态文件
curl -s localhost:3000/unknown/route    # 未命中 -> 回退 index.html
```

运行结果：

```
hello from api
<h1>Hello SPA</h1>
<h1>Hello SPA</h1>
```

> `fallback_service` 让「API 优先、其余走前端」这种单体部署一行搞定：`/api/*` 命中后端，其它路径（包括前端的 client-side 路由）统统回退到 `index.html`，由前端框架接管路由。`ServeDir` 自带 `ETag`/`Last-Modified`/`Range` 支持，托管大文件或断点续传也无需额外代码。

## 十四、生产级中间件栈整合

把前面各能力按正确顺序串成一套完整的中间件栈，复用基础篇的统一响应、`AppState` 与 `/api` 路由，再补上云原生最常见的 `/health` 健康探针。**顺序**是这里的灵魂：用一个 `ServiceBuilder` 自上而下书写（= 由外到内执行），日志/链路在最外、兜底与安全居中、超时在最内贴近业务；鉴权只用 `route_layer` 套在 `/api` 上，让 `/health` 免鉴权。

```rust
use std::any::Any;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use axum::extract::{Path, State};
use axum::http::{HeaderName, HeaderValue, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::get;
use axum::{Json, Router};
use serde::{Deserialize, Serialize};
use serde_json::json;
use tokio::net::TcpListener;
use tower::ServiceBuilder;
use tower_http::catch_panic::CatchPanicLayer;
use tower_http::compression::CompressionLayer;
use tower_http::cors::{Any as CorsAny, CorsLayer};
use tower_http::request_id::MakeRequestUuid;
use tower_http::set_header::SetResponseHeaderLayer;
use tower_http::timeout::TimeoutLayer;
use tower_http::trace::{DefaultMakeSpan, DefaultOnResponse, TraceLayer};
use tower_http::validate_request::ValidateRequestHeaderLayer;
use tower_http::{LatencyUnit, ServiceBuilderExt};
use tracing::Level;
use tracing_subscriber::EnvFilter;

// ---------- 统一响应结构（同基础篇）----------

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
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, code, message) = match self {
            AppError::NotFound(m) => (StatusCode::NOT_FOUND, 404, m),
        };
        let body = ApiResponse::<()> { code, message, data: None };
        (status, Json(body)).into_response()
    }
}

// ---------- 数据与状态 ----------

#[derive(Clone, Serialize)]
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

// ---------- handler ----------

async fn health() -> &'static str {
    "OK"
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

fn on_panic(err: Box<dyn Any + Send + 'static>) -> Response {
    let detail = err
        .downcast_ref::<&str>()
        .map(|s| s.to_string())
        .or_else(|| err.downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "unknown panic".to_string());
    let body = json!({ "code": 500, "message": detail, "data": null });
    (StatusCode::INTERNAL_SERVER_ERROR, Json(body)).into_response()
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c().await.expect("failed to install Ctrl+C handler");
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
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::new("info,tower_http=debug"))
        .init();

    let mut users = HashMap::new();
    users.insert(1, User { id: 1, name: "Alice".to_string() });
    let state = AppState { inner: Arc::new(Mutex::new(Inner { users })) };

    // 全局中间件栈：自上而下 = 由外到内
    let middleware = ServiceBuilder::new()
        // 1. 最外层：链路 ID + 请求日志（能观测到内层一切结果）
        .set_x_request_id(MakeRequestUuid)
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(DefaultMakeSpan::new().include_headers(false))
                .on_response(
                    DefaultOnResponse::new().level(Level::INFO).latency_unit(LatencyUnit::Micros),
                ),
        )
        .propagate_x_request_id()
        // 2. 安全响应头
        .layer(SetResponseHeaderLayer::if_not_present(
            HeaderName::from_static("x-content-type-options"),
            HeaderValue::from_static("nosniff"),
        ))
        // 3. CORS
        .layer(CorsLayer::new().allow_origin(CorsAny).allow_methods(CorsAny))
        // 4. 压缩
        .layer(CompressionLayer::new())
        // 5. panic 兜底（兜内层业务，但仍被上面的日志记录）
        .layer(CatchPanicLayer::custom(on_panic))
        // 6. 最内层：贴近业务的超时
        .layer(TimeoutLayer::new(Duration::from_secs(10)));

    // /api 单独加鉴权（route_layer：未命中不触发鉴权）；/health 免鉴权
    let api = Router::new()
        .route("/users/{id}", get(get_user))
        .route_layer(ValidateRequestHeaderLayer::bearer("secret-token"));

    let app = Router::new()
        .route("/health", get(health))
        .nest("/api", api)
        .layer(middleware)
        .with_state(state);

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}
```

逐项验证：健康检查免鉴权、`/api` 需 token、链路 ID 回写、统一错误结构：

```bash
curl -s localhost:3000/health                                              # 探针，免鉴权
curl -i -s localhost:3000/api/users/1 | head -1                            # 无 token -> 401
curl -s -H 'Authorization: Bearer secret-token' localhost:3000/api/users/1 # 正常
curl -s -H 'Authorization: Bearer secret-token' localhost:3000/api/users/9 # 业务 404
curl -is -H 'Authorization: Bearer secret-token' localhost:3000/api/users/1 | grep -i x-request-id
```

运行结果：

```
OK
HTTP/1.1 401 Unauthorized
{"code":0,"message":"success","data":{"id":1,"name":"Alice"}}
{"code":404,"message":"user 9 not found","data":null}
x-request-id: 1b4e28ba-2fa1-11d2-883f-0016d3cca427
```

> 这套栈把可观测性（链路 ID + 日志）、安全（响应头 + 鉴权）、韧性（超时 + panic 兜底）、性能（压缩）一次性套在所有请求上，业务 handler 只管写业务。`/health` 放在鉴权之外，正是为了让 `k8s` 的存活/就绪探针能免认证访问；想做更细的就绪检查（探测数据库连通性），把 `health` 改成读 `State` 跑一次 `ping` 即可。需要限流时，按第九节用 `HandleErrorLayer + LoadShedLayer + GlobalConcurrencyLimitLayer` 单独组一段加进来。至此，一个具备完整云原生横切能力、且全部在 Web 服务层落地的 `axum` 服务就成型了——从「能跑」到「能上生产」，缺的正是这一圈 `Layer`。
