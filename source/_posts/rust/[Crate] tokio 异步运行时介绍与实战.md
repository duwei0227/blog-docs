---
title: "[Crate] tokio 异步运行时介绍与实战"
published: true
layout: post
date: 2026-06-09 09:00:00
permalink: /rust/tokio.html
tags:
  - 异步编程
  - 异步运行时
  - async/await
  - 并发
  - 任务调度
  - 网络编程
categories: Rust
---

标准库里的 `std::thread`、`std::fs`、`std::io` 都是**同步阻塞**模型：一次 `read` 没有数据就让整条线程停在那里等待。要并发处理一万个网络连接，就得开一万条线程，光是线程栈和上下文切换就足以拖垮系统。`tokio` 用另一种思路解决这个问题——它提供一个异步运行时（runtime），让成千上万个任务（task）跑在少数几条工作线程上，任何一次 IO 没就绪时任务主动"让出"线程而不是阻塞它，从而用极少的线程撑起极高的并发。本文从依赖引入开始，系统讲解 tokio 的运行时、任务与线程模型、`fs`、`io`、`time`、`sync`、`net` 等模块的理论、语法、主要 API 与可运行示例。

## 一、为什么需要 tokio

Rust 的 `async fn` 返回的是一个 `Future`，它描述"一段将来会完成的计算"，但**本身是惰性的**——不被轮询（poll）就什么都不做。`.await` 表示"在此等待这个 `Future` 完成，期间把线程让给别的任务"。真正驱动这些 `Future` 前进、在 IO 就绪时唤醒对应任务的，正是运行时。

tokio 运行时由三部分组成：

- **调度器（scheduler）**：把就绪的任务分配到工作线程上执行；
- **IO 驱动（reactor）**：底层基于 `epoll`（`Linux`）、`kqueue`（`macOS`）、`IOCP`（`Windows`）的 `mio`，负责监听文件描述符就绪事件并唤醒任务；
- **定时器（timer）**：驱动 `sleep`、`timeout`、`interval` 等时间相关能力。

理解 tokio 最快的方式是把它与标准库的同步 API 对照，几乎每个同步原语都有一个异步对应物：

| 能力 | std（同步阻塞） | tokio（异步） | 关键差异 |
|------|----------------|---------------|----------|
| 任务/线程 | `std::thread::spawn` | `tokio::spawn` / `spawn_blocking` | 前者创建 OS 线程；后者创建轻量任务，多任务复用少量线程 |
| 文件 | `std::fs::File` | `tokio::fs::File` | 方法需 `.await`，IO 期间不阻塞工作线程 |
| 字节读写 | `std::io::Read` / `Write` | `tokio::io::AsyncReadExt` / `AsyncWriteExt` | trait 方法返回 `Future`，未就绪时让出 |
| 缓冲读 | `std::io::BufReader` | `tokio::io::BufReader` | 接口几乎一致，方法改为 `.await` |
| 定时/休眠 | `std::thread::sleep` | `tokio::time::sleep` / `interval` / `timeout` | 前者阻塞整条线程；后者只挂起当前任务 |
| 通道 | `std::sync::mpsc` | `tokio::sync::mpsc` / `oneshot` / `broadcast` / `watch` | 异步通道的 `send`/`recv` 可 `.await`，不阻塞线程 |
| 锁 | `std::sync::Mutex` | `tokio::sync::Mutex` | 异步锁可跨 `.await` 持有 |
| 网络 | `std::net::TcpListener` | `tokio::net::TcpListener` | `accept`/`read`/`write` 全异步 |

> 一个核心直觉：同步 API 让出的是"什么都不让"——线程被卡住；异步 API 在 `.await` 处让出**线程的使用权**，运行时立刻调度别的任务上来跑。这就是 tokio 能用 4 条线程处理上万并发连接的根本原因。

## 二、安装与依赖

在 `Cargo.toml` 中添加 tokio。tokio 的功能被切成很多 feature，按需开启可以显著减小编译体积和时间：

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
```

`full` 会启用几乎所有 feature，适合入门和应用层。生产库里通常按需精简，常用 feature 如下：

| feature | 启用的能力 |
|---------|-----------|
| `full` | 启用除少数不稳定项外的所有 feature，省心但编译体积大 |
| `rt` | 当前线程（single-thread）运行时与 `tokio::task` |
| `rt-multi-thread` | 多线程工作窃取运行时（隐含 `rt`） |
| `macros` | `#[tokio::main]`、`#[tokio::test]`、`select!` 等宏 |
| `fs` | `tokio::fs` 异步文件系统 |
| `io-util` | `AsyncReadExt`/`AsyncWriteExt` 等扩展 trait、`BufReader`/`BufWriter`、`copy` |
| `io-std` | 异步 `stdin`/`stdout`/`stderr` |
| `net` | `tokio::net`（TCP/UDP/Unix socket） |
| `time` | `tokio::time`（`sleep`/`timeout`/`interval`） |
| `sync` | `tokio::sync`（各类通道与锁） |
| `process` | `tokio::process` 异步子进程 |
| `signal` | `tokio::signal` 信号处理 |

> 一个常见误区：只写 `tokio = "1"` 而不开任何 feature，结果连 `#[tokio::main]` 都用不了。最小可用组合通常是 `["rt-multi-thread", "macros"]`，再按用到的模块追加 `fs`/`net`/`time`/`sync` 等。

## 三、运行时与程序入口

异步代码必须跑在运行时里。`.await` 只能出现在 `async` 函数或代码块中，而最外层需要有一个运行时来 `block_on` 整个异步入口。

### 3.1 #[tokio::main] — 启动运行时的宏

**语法：**

```rust
#[tokio::main(flavor = "multi_thread", worker_threads = 4)]
async fn main() { /* ... */ }
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `flavor` | `"multi_thread"` | 运行时类型；取值：`"multi_thread"` = 多线程工作窃取；`"current_thread"` = 单线程 |
| `worker_threads` | CPU 逻辑核数 | 工作线程数，仅 `multi_thread` 有效 |

`#[tokio::main]` 是个语法糖，它把 `async fn main` 改写成一个普通 `fn main`，在其中构建运行时并 `block_on` 你的异步逻辑。

```rust
#[tokio::main]
async fn main() {
    println!("在异步上下文中运行");
    let x = compute().await;
    println!("compute 返回 {x}");
}

async fn compute() -> i32 {
    21 * 2
}
```

运行结果：

```
在异步上下文中运行
compute 返回 42
```

### 3.2 Runtime 与 Builder — 手动构建运行时

宏适合大多数场景，但当你需要在同步程序中嵌入异步、或精细控制线程参数时，应使用 `Builder` 手动构建 `Runtime`，再用 `block_on` 运行异步代码。

**语法：**

```rust
let rt = tokio::runtime::Builder::new_multi_thread()
    .worker_threads(4)
    .enable_all()
    .build()?;
rt.block_on(async { /* ... */ });
```

**参数（Builder 常用方法）：**

| 方法 | 默认值 | 说明 |
|------|--------|------|
| `new_multi_thread()` | - | 创建多线程运行时构建器 |
| `new_current_thread()` | - | 创建单线程运行时构建器 |
| `worker_threads(n)` | CPU 逻辑核数 | 工作线程数（仅多线程） |
| `max_blocking_threads(n)` | `512` | `spawn_blocking` 阻塞线程池上限 |
| `thread_name(name)` | `"tokio-runtime-worker"` | 工作线程名 |
| `thread_stack_size(bytes)` | `2 MiB` | 工作线程栈大小 |
| `enable_all()` | 关闭 | 同时启用 IO 与时间驱动 |
| `enable_io()` / `enable_time()` | 关闭 | 分别只启用 IO / 时间驱动 |

> 易踩的坑：如果忘了 `enable_all()`（或 `enable_time()`），运行时里调用 `sleep` 会直接 panic，提示 "there is no reactor running"。手动构建时几乎总应该调用 `enable_all()`。

```rust
use tokio::runtime::Builder;

fn main() {
    let rt = Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();

    let result = rt.block_on(async {
        println!("在手动构建的运行时中执行");
        let h = tokio::spawn(async { 1 + 2 });
        h.await.unwrap()
    });

    println!("block_on 返回 {result}");
}
```

运行结果：

```
在手动构建的运行时中执行
block_on 返回 3
```

### 3.3 Handle — 从外部与运行时交互

`Handle` 是运行时的轻量句柄（可 `Clone`），用于在**运行时之外**（例如一条普通的 `std::thread`）把任务投递回运行时。`Handle::current()` 在运行时上下文中获取当前句柄。

**语法：**

```rust
let handle = tokio::runtime::Handle::current();
handle.spawn(async { /* ... */ });
```

```rust
use tokio::runtime::Handle;

#[tokio::main]
async fn main() {
    let handle = Handle::current();

    // 在一个普通阻塞线程里，借助 Handle 把任务投递回运行时
    let join = std::thread::spawn(move || {
        handle.spawn(async {
            println!("任务由外部线程通过 Handle 投递");
            100
        })
    })
    .join()
    .unwrap();

    let value = join.await.unwrap();
    println!("外部线程投递的任务返回 {value}");
}
```

运行结果：

```
任务由外部线程通过 Handle 投递
外部线程投递的任务返回 100
```

### 3.4 current_thread vs multi_thread

| 维度 | `current_thread` | `multi_thread` |
|------|------------------|----------------|
| 工作线程数 | 1 | 默认 = CPU 核数 |
| 任务 `Send` 约束 | 无需 `Send`（任务不跨线程） | 任务必须 `Send`（可能被迁移到别的线程） |
| 并行能力 | 无（仅并发） | 有（真正多核并行） |
| 适用场景 | 测试、嵌入式、单连接代理、需要 `!Send` 数据 | 服务端、高并发、CPU 多核利用 |

## 四、任务与线程模型

tokio 没有独立的 "thread" 模块——它的并发单元是**任务（task）**，由 `tokio::spawn` 创建。任务是绿色线程（green thread）：极其轻量（一个任务初始仅几十字节），由运行时调度到工作线程上执行。涉及真正阻塞的同步代码时，再借助 `spawn_blocking` 隔离到专门的阻塞线程池。

### 4.1 spawn 与 JoinHandle

**语法：**

```rust
pub fn spawn<F>(future: F) -> JoinHandle<F::Output>
where
    F: Future + Send + 'static,
    F::Output: Send + 'static,
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `future` | - | 要并发执行的异步任务；必须满足 `Send + 'static` |

`spawn` 调用后任务**立即开始在后台运行**，即使你不 `.await` 返回的 `JoinHandle` 也是如此。`JoinHandle<T>` 是等待任务结束、取回返回值的凭证，`.await` 它得到 `Result<T, JoinError>`。

```rust
#[tokio::main]
async fn main() {
    let mut handles = Vec::new();
    for id in 0..3 {
        handles.push(tokio::spawn(async move {
            format!("任务 {id} 完成")
        }));
    }

    for h in handles {
        let msg = h.await.unwrap();
        println!("{msg}");
    }
}
```

运行结果：

```
任务 0 完成
任务 1 完成
任务 2 完成
```

> `Send + 'static` 约束的本质：多线程运行时可能把任务从一条线程迁移到另一条，所以任务捕获的数据必须能跨线程传递（`Send`）且不借用栈上的临时数据（`'static`）。一个高频编译错误是把 `Rc`、`MutexGuard` 等 `!Send` 类型**跨 `.await` 持有**——解决办法见 4.5 节的 `spawn_local`，或缩小它们的作用域使其不跨越 `.await`。

### 4.2 JoinSet — 批量管理任务

当你 `spawn` 一批任务并希望按完成顺序收集结果时，手动维护 `Vec<JoinHandle>` 很笨拙。`JoinSet` 专门解决这个问题：`join_next` 按**完成先后**而非提交顺序返回结果。

**语法：**

```rust
let mut set = tokio::task::JoinSet::new();
set.spawn(async { /* ... */ });
while let Some(res) = set.join_next().await { /* res: Result<T, JoinError> */ }
```

下面给每个任务安排一段不同的睡眠时长（耗时各异，模拟真实中处理快慢不一的任务），任务返回自己的耗时。可以看到 `join_next` 收回结果的顺序是按**完成先后**，而不是任务的提交顺序。

```rust
use tokio::task::JoinSet;
use tokio::time::{sleep, Duration};

#[tokio::main]
async fn main() {
    // 为每个任务安排不同（乱序）的处理时长，模拟真实中各异的耗时
    let durations = [40u64, 10, 50, 20, 30];

    let mut set = JoinSet::new();
    for (id, ms) in durations.into_iter().enumerate() {
        set.spawn(async move {
            sleep(Duration::from_millis(ms)).await;
            (id, ms) // 返回任务编号与自己的耗时
        });
    }

    // join_next 按“完成先后”返回结果，而非任务的提交顺序
    while let Some(res) = set.join_next().await {
        let (id, ms) = res.unwrap();
        println!("任务 {id} 完成（耗时 {ms}ms）");
    }
}
```

运行结果：

```
任务 1 完成（耗时 10ms）
任务 3 完成（耗时 20ms）
任务 4 完成（耗时 30ms）
任务 0 完成（耗时 40ms）
任务 2 完成（耗时 50ms）
```

> 任务以编号 0~4 的顺序提交，但输出严格按耗时从小到大排列——这正说明 `join_next` 谁先完成就先返回谁，让你能"尽早处理已完成的结果"而无需等最慢的任务。示例用一组乱序但固定的耗时来保证输出可复现；换成真正的随机时长，完成顺序同样会按实际耗时排列。另外，`JoinSet` 被 `drop` 时会自动 `abort` 其中所有未完成的任务，非常适合"一组任务要么全做完、要么随作用域一起取消"的场景。

### 4.3 spawn_blocking — 隔离阻塞代码

异步任务里**绝不能**直接调用会长时间阻塞的同步代码（如 `std::thread::sleep`、同步文件读写、CPU 密集计算），否则会卡住整条工作线程，拖垮所有共享该线程的任务。`spawn_blocking` 把这类代码放到独立的阻塞线程池执行。

**语法：**

```rust
pub fn spawn_blocking<F, R>(f: F) -> JoinHandle<R>
where
    F: FnOnce() -> R + Send + 'static,
    R: Send + 'static,
```

| 维度 | `spawn` | `spawn_blocking` |
|------|---------|------------------|
| 接收 | `Future`（异步代码） | 闭包（同步代码） |
| 运行位置 | 工作线程池（默认 = 核数） | 专用阻塞线程池（默认上限 512） |
| 适用 | 异步 IO、`.await` 密集逻辑 | CPU 密集、同步阻塞 IO、调用阻塞的 C 库 |

```rust
#[tokio::main]
async fn main() {
    let handle = tokio::task::spawn_blocking(|| {
        // 模拟一段 CPU 密集 / 阻塞的同步计算
        let mut sum: u64 = 0;
        for i in 1..=1_000_000 {
            sum += i;
        }
        sum
    });

    let total = handle.await.unwrap();
    println!("1..=1_000_000 求和 = {total}");
}
```

运行结果：

```
1..=1_000_000 求和 = 500000500000
```

### 4.4 任务取消与 JoinError

`JoinHandle::abort()` 立即请求取消任务；被取消或 panic 的任务，`.await` 其句柄会得到 `Err(JoinError)`，可用 `is_cancelled()` / `is_panic()` 区分原因。

**语法：**

```rust
handle.abort();
match handle.await {
    Ok(v) => { /* 正常完成 */ }
    Err(e) if e.is_cancelled() => { /* 被取消 */ }
    Err(e) if e.is_panic() => { /* 任务 panic */ }
    Err(_) => {}
}
```

```rust
use tokio::time::{sleep, Duration};

#[tokio::main]
async fn main() {
    let handle = tokio::spawn(async {
        sleep(Duration::from_secs(10)).await;
        "永远不会返回"
    });

    // 立刻取消这个长任务
    handle.abort();

    match handle.await {
        Ok(v) => println!("正常完成: {v}"),
        Err(e) if e.is_cancelled() => println!("任务已被取消 (is_cancelled = true)"),
        Err(e) if e.is_panic() => println!("任务 panic"),
        Err(_) => println!("其他错误"),
    }
}
```

运行结果：

```
任务已被取消 (is_cancelled = true)
```

> 取消只发生在任务的 `.await` 点：tokio 是协作式调度，`abort` 标记任务待取消，任务下一次到达 `.await` 时才真正停止。一段没有任何 `.await` 的纯计算循环是无法被 `abort` 中途打断的。`AbortHandle`（由 `JoinSet::spawn` 返回或 `handle.abort_handle()` 获取）则允许在不持有 `JoinHandle` 的情况下取消任务。

## 五、tokio::fs 异步文件系统

`tokio::fs` 是 `std::fs` 的异步镜像，API 几乎一一对应，只是方法都要 `.await`。

> 关键原理：操作系统对**普通文件**并没有真正的异步 IO 接口，因此 `tokio::fs` 的实现其实是用 `spawn_blocking` 把 `std::fs` 的阻塞调用丢到阻塞线程池里。这意味着它的价值在于"不阻塞工作线程"，而非"文件读写更快"——如果是大量小文件操作，开销甚至可能高于直接同步读写。

### 5.1 File 的打开、写入与读取

`File::create` 创建（或截断）文件用于写入，`File::open` 打开已有文件用于读取。文件本身只是字节容器，具体读写方法来自 `tokio::io` 的扩展 trait（见第六章）。

**语法：**

```rust
pub async fn create(path: impl AsRef<Path>) -> io::Result<File>
pub async fn open(path: impl AsRef<Path>) -> io::Result<File>
```

```rust
use tokio::fs::File;
use tokio::io::{AsyncReadExt, AsyncWriteExt};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    // 创建并写入（File::create 会截断已存在文件）
    let mut file = File::create("/tmp/tk_demo.txt").await?;
    file.write_all(b"hello tokio fs\n").await?;
    file.flush().await?;

    // 重新打开并读取
    let mut file = File::open("/tmp/tk_demo.txt").await?;
    let mut contents = String::new();
    file.read_to_string(&mut contents).await?;
    print!("文件内容: {contents}");
    println!("字节数: {}", contents.len());

    tokio::fs::remove_file("/tmp/tk_demo.txt").await?;
    Ok(())
}
```

运行结果：

```
文件内容: hello tokio fs
字节数: 15
```

> 若需要"既能读又能写"或追加写入，用 `tokio::fs::OpenOptions`（`.read(true).write(true).append(true).create(true)`）替代 `File::create`/`File::open`。`File::create` 打开的句柄是只写的，对它调用读操作会得到 "Bad file descriptor" 错误。

### 5.2 便捷函数：read / write / read_to_string

对于"一次性读写整个文件"的常见需求，无需手动开关文件句柄，`fs::read`/`fs::write`/`fs::read_to_string` 一行搞定。

**语法：**

```rust
pub async fn read(path: impl AsRef<Path>) -> io::Result<Vec<u8>>
pub async fn read_to_string(path: impl AsRef<Path>) -> io::Result<String>
pub async fn write(path: impl AsRef<Path>, contents: impl AsRef<[u8]>) -> io::Result<()>
```

```rust
use tokio::fs;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    // 一行写入整个文件
    fs::write("/tmp/tk_helper.txt", b"line-1\nline-2\n").await?;

    // 一行读为 Vec<u8>
    let bytes = fs::read("/tmp/tk_helper.txt").await?;
    println!("read 字节数: {}", bytes.len());

    // 一行读为 String
    let text = fs::read_to_string("/tmp/tk_helper.txt").await?;
    println!("行数: {}", text.lines().count());

    fs::remove_file("/tmp/tk_helper.txt").await?;
    Ok(())
}
```

运行结果：

```
read 字节数: 14
行数: 2
```

### 5.3 目录与元数据

`create_dir_all` 递归建目录，`read_dir` 返回 `ReadDir` 流，用 `next_entry().await` 逐项遍历 `DirEntry`；`metadata`/`entry.metadata()` 获取大小、类型等信息，`try_exists` 判断路径是否存在，`remove_dir_all` 递归删除。

```rust
use tokio::fs;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let dir = "/tmp/tk_dir_demo";
    fs::create_dir_all(dir).await?;

    // 写入两个文件
    fs::write(format!("{dir}/a.txt"), b"aaa").await?;
    fs::write(format!("{dir}/b.txt"), b"bbbbb").await?;

    // 遍历目录
    let mut names = Vec::new();
    let mut entries = fs::read_dir(dir).await?;
    while let Some(entry) = entries.next_entry().await? {
        let meta = entry.metadata().await?;
        names.push(format!("{} ({} 字节)", entry.file_name().to_string_lossy(), meta.len()));
    }
    names.sort();
    for n in &names {
        println!("{n}");
    }

    println!("a.txt 是否存在: {}", fs::try_exists(format!("{dir}/a.txt")).await?);

    fs::remove_dir_all(dir).await?;
    Ok(())
}
```

运行结果：

```
a.txt (3 字节)
b.txt (5 字节)
a.txt 是否存在: true
```

> `read_dir` 返回的条目顺序由文件系统决定、不保证有序，所以示例里收集后 `sort` 再输出。其余便捷函数还有 `fs::copy`（复制文件）、`fs::rename`（移动/重命名）、`fs::remove_file`（删文件）、`fs::create_dir`（建单层目录），用法与 `std::fs` 同名函数一致。

## 六、tokio::io 异步 IO

`tokio::io` 定义了四个底层 trait：`AsyncRead`、`AsyncWrite`、`AsyncBufRead`、`AsyncSeek`，分别对应 `std::io` 的 `Read`/`Write`/`BufRead`/`Seek`。但你日常调用的 `read`/`write`/`lines` 等方法来自对应的**扩展 trait**：`AsyncReadExt`、`AsyncWriteExt`、`AsyncBufReadExt`、`AsyncSeekExt`。

> 最常见的编译报错就是"方法 `read`/`write_all`/`lines` 找不到"——原因是没有 `use` 对应的 `*Ext` trait。记住：底层 trait 描述能力，`*Ext` trait 提供便捷方法，调用前必须把 `*Ext` 引入作用域。

### 6.1 AsyncReadExt — 读取

| 方法 | 说明 |
|------|------|
| `read(&mut buf)` | 读取若干字节到 buf，返回实际读取数 `n`（`0` 表示 EOF） |
| `read_exact(&mut buf)` | 读满整个 buf，否则报错 |
| `read_to_end(&mut vec)` | 读到 EOF，追加进 `Vec<u8>` |
| `read_to_string(&mut s)` | 读到 EOF，追加进 `String` |

`read_to_string` 的示例已在 5.1 节给出，此处不再重复。

### 6.2 AsyncWriteExt — 写入

| 方法 | 说明 |
|------|------|
| `write(buf)` | 写入若干字节，返回实际写入数 |
| `write_all(buf)` | 写完整个 buf，否则报错 |
| `flush()` | 把缓冲数据刷到底层 |
| `shutdown()` | 关闭写端（对 socket 表示发送 FIN） |

### 6.3 BufReader / BufWriter 与按行读取

裸 `File` 每次 `read` 都是一次系统调用，频繁小读写时开销大。`BufReader`/`BufWriter` 在内存中加一层缓冲，`AsyncBufReadExt` 还提供 `lines()`（按行迭代）和 `read_line()`。

```rust
use tokio::fs::File;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    tokio::fs::write("/tmp/tk_lines.txt", b"first\nsecond\nthird\n").await?;

    let file = File::open("/tmp/tk_lines.txt").await?;
    let reader = BufReader::new(file);
    let mut lines = reader.lines();

    let mut idx = 0;
    while let Some(line) = lines.next_line().await? {
        idx += 1;
        println!("第 {idx} 行: {line}");
    }

    // BufWriter 缓冲多次小写入
    let out = File::create("/tmp/tk_out.txt").await?;
    let mut writer = tokio::io::BufWriter::new(out);
    for i in 0..3 {
        writer.write_all(format!("row-{i}\n").as_bytes()).await?;
    }
    writer.flush().await?; // BufWriter 必须 flush

    let written = tokio::fs::read_to_string("/tmp/tk_out.txt").await?;
    println!("BufWriter 写出行数: {}", written.lines().count());

    tokio::fs::remove_file("/tmp/tk_lines.txt").await?;
    tokio::fs::remove_file("/tmp/tk_out.txt").await?;
    Ok(())
}
```

运行结果：

```
第 1 行: first
第 2 行: second
第 3 行: third
BufWriter 写出行数: 3
```

> `BufWriter` 是缓冲写——数据先攒在内存里，**必须显式 `flush()`**（或等它被 `drop` 时由 tokio 尽力刷写）才能确保落盘。忘记 `flush` 是导致"文件内容不全"的经典 bug。`lines()` 返回的 `Lines` 用 `next_line().await` 拉取下一行，返回 `None` 即结束。

### 6.4 AsyncSeekExt — 随机定位

`seek` 移动读写位置，`rewind` 回到开头，`stream_position` 查询当前偏移。注意需要同时读写时要用 `OpenOptions` 打开。

```rust
use std::io::SeekFrom;
use tokio::fs::OpenOptions;
use tokio::io::{AsyncReadExt, AsyncSeekExt, AsyncWriteExt};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    // 需要同时读写，用 OpenOptions 而非 File::create（后者只读不了）
    let mut file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(true)
        .open("/tmp/tk_seek.txt")
        .await?;
    file.write_all(b"0123456789").await?;
    file.flush().await?;

    // 定位到第 4 个字节再读
    file.seek(SeekFrom::Start(4)).await?;
    let mut buf = [0u8; 3];
    file.read_exact(&mut buf).await?;
    println!("从偏移 4 读取 3 字节: {:?}", std::str::from_utf8(&buf).unwrap());

    // rewind 回到开头
    file.rewind().await?;
    let pos = file.stream_position().await?;
    println!("rewind 后位置: {pos}");

    tokio::fs::remove_file("/tmp/tk_seek.txt").await?;
    Ok(())
}
```

运行结果：

```
从偏移 4 读取 3 字节: "456"
rewind 后位置: 0
```

### 6.5 io::copy 与标准流

`io::copy` 把一个 `AsyncRead` 的全部内容拷贝到一个 `AsyncWrite`，常用于流转发。`tokio::io::stdin/stdout/stderr` 提供异步标准流，`io::split` 可把一个读写双工对象（如 `TcpStream`）拆成独立的读半、写半，分别交给不同任务。

```rust
use tokio::io;

#[tokio::main]
async fn main() -> io::Result<()> {
    // reader 是内存中的字节，writer 是一个 Vec
    let mut reader: &[u8] = b"copy these bytes through tokio::io::copy";
    let mut writer: Vec<u8> = Vec::new();

    let n = io::copy(&mut reader, &mut writer).await?;
    println!("拷贝字节数: {n}");
    println!("目标内容: {}", String::from_utf8_lossy(&writer));
    Ok(())
}
```

运行结果：

```
拷贝字节数: 40
目标内容: copy these bytes through tokio::io::copy
```

## 七、tokio::time 定时器

`tokio::time` 提供异步的休眠、超时和周期触发。它们都只挂起**当前任务**，绝不阻塞工作线程，这是与 `std::thread::sleep` 的本质区别。

### 7.1 sleep — 异步休眠

**语法：**

```rust
pub fn sleep(duration: Duration) -> Sleep
```

```rust
use tokio::time::{sleep, Duration, Instant};

#[tokio::main]
async fn main() {
    let start = Instant::now();
    println!("开始");
    sleep(Duration::from_millis(100)).await;
    println!("100ms 后继续，已过去约 {} ms", start.elapsed().as_millis() / 100 * 100);
}
```

运行结果：

```
开始
100ms 后继续，已过去约 100 ms
```

> 示例里对 `elapsed` 做了取整（`/ 100 * 100`），只是为了让输出在文章里稳定可复现；真实代码里 `elapsed()` 会返回略大于 100ms 的精确值。

### 7.2 timeout — 给 Future 设时限

`timeout` 包裹任意 `Future`，超过时限则返回 `Err(Elapsed)` 并取消内部 `Future`。

**语法：**

```rust
pub fn timeout<F: Future>(duration: Duration, future: F) -> Timeout<F>
```

```rust
use tokio::time::{sleep, timeout, Duration};

async fn work(ms: u64) -> u64 {
    sleep(Duration::from_millis(ms)).await;
    ms
}

#[tokio::main]
async fn main() {
    // 在时限内完成
    match timeout(Duration::from_millis(200), work(50)).await {
        Ok(v) => println!("任务在时限内完成，结果 = {v}"),
        Err(_) => println!("任务超时"),
    }

    // 超过时限
    match timeout(Duration::from_millis(50), work(200)).await {
        Ok(v) => println!("任务在时限内完成，结果 = {v}"),
        Err(_) => println!("任务超时，已被取消"),
    }
}
```

运行结果：

```
任务在时限内完成，结果 = 50
任务超时，已被取消
```

### 7.3 interval — 周期触发

`interval` 创建一个周期性触发器，`tick().await` 在每个周期返回一次。第一次 `tick()` 立即返回，之后每隔一个周期返回。

**语法：**

```rust
pub fn interval(period: Duration) -> Interval
```

```rust
use tokio::time::{interval, Duration};

#[tokio::main]
async fn main() {
    let mut ticker = interval(Duration::from_millis(50));

    for i in 1..=3 {
        ticker.tick().await; // 第一次 tick 立即返回
        println!("第 {i} 次 tick");
    }
}
```

运行结果：

```
第 1 次 tick
第 2 次 tick
第 3 次 tick
```

> `interval` 与"循环里 `sleep`"的关键差异：`interval` 按**上一次 tick 的时间点**计算下一次触发，即使任务体本身耗时，也会尽量维持稳定的触发频率；而循环 `sleep` 是"任务耗时 + 休眠时长"累加，频率会漂移。当任务耗时偶尔超过周期时，可通过 `set_missed_tick_behavior(MissedTickBehavior::Skip)` 等策略控制补偿行为。

## 八、tokio::sync 同步原语

`tokio::sync` 提供异步版的通道与锁。它们的 `send`/`recv`/`lock` 等操作可以 `.await`，在未就绪时让出线程而非阻塞。

### 8.1 mpsc — 多生产者单消费者通道

**语法：**

```rust
pub fn channel<T>(buffer: usize) -> (Sender<T>, Receiver<T>)        // 有界
pub fn unbounded_channel<T>() -> (UnboundedSender<T>, UnboundedReceiver<T>) // 无界
```

有界通道在缓冲满时 `send().await` 会挂起，形成天然的**背压（backpressure）**，防止生产者压垮消费者。所有 `Sender` 被丢弃后，`recv()` 取空数据返回 `None`。

```rust
use tokio::sync::mpsc;

#[tokio::main]
async fn main() {
    let (tx, mut rx) = mpsc::channel::<i32>(8);

    // 生产者任务
    tokio::spawn(async move {
        for i in 1..=3 {
            tx.send(i * 10).await.unwrap();
        }
        // tx 在此被 drop，通道关闭
    });

    // 消费者：通道关闭且取空后 recv 返回 None
    let mut sum = 0;
    while let Some(v) = rx.recv().await {
        println!("收到: {v}");
        sum += v;
    }
    println!("合计: {sum}");
}
```

运行结果：

```
收到: 10
收到: 20
收到: 30
合计: 60
```

### 8.2 oneshot — 一次性应答

`oneshot` 用于任务间传递**单个**值，常见于"发起请求并等待一个结果"。`Sender::send` 不需要 `.await`（只能用一次）。

```rust
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx, rx) = oneshot::channel::<String>();

    tokio::spawn(async move {
        // 完成一次性计算后回送结果
        let answer = format!("计算结果 = {}", 6 * 7);
        let _ = tx.send(answer);
    });

    match rx.await {
        Ok(msg) => println!("收到应答: {msg}"),
        Err(_) => println!("发送端已丢弃，无应答"),
    }
}
```

运行结果：

```
收到应答: 计算结果 = 42
```

### 8.3 broadcast — 多生产多消费广播

`broadcast` 通道里**每个**订阅者都能收到此后发送的所有消息。`subscribe()` 新增订阅者，容量满时滞后的接收者会收到 `RecvError::Lagged` 并丢失最早的消息。

```rust
use tokio::sync::broadcast;

#[tokio::main]
async fn main() {
    let (tx, mut rx1) = broadcast::channel::<i32>(16);
    let mut rx2 = tx.subscribe();

    for i in 1..=3 {
        tx.send(i).unwrap();
    }
    drop(tx);

    // 每个订阅者都能收到全部消息
    let mut out1 = Vec::new();
    while let Ok(v) = rx1.recv().await {
        out1.push(v);
    }
    let mut out2 = Vec::new();
    while let Ok(v) = rx2.recv().await {
        out2.push(v);
    }

    println!("rx1 收到: {out1:?}");
    println!("rx2 收到: {out2:?}");
}
```

运行结果：

```
rx1 收到: [1, 2, 3]
rx2 收到: [1, 2, 3]
```

> 坑点：`broadcast` 只送达"订阅之后"发送的消息——`subscribe()` 之前发出的消息新订阅者收不到。另外，慢消费者若跟不上发送速度、积压超过容量，就会丢消息（`Lagged`），它换来的是发送端永不被慢消费者阻塞。

### 8.4 watch — 最新值广播

`watch` 只保留"最新一个值"，适合配置热更新、状态/关停信号广播。`borrow()` 读当前值，`changed().await` 等待值变化。

```rust
use tokio::sync::watch;
use tokio::time::{sleep, Duration};

#[tokio::main]
async fn main() {
    let (tx, mut rx) = watch::channel("初始配置");

    let consumer = tokio::spawn(async move {
        let mut seen = Vec::new();
        // 记录初始值
        seen.push(rx.borrow().to_string());
        // 等待变更
        while rx.changed().await.is_ok() {
            seen.push(rx.borrow().to_string());
        }
        seen
    });

    // 稍等，确保消费者已记录初始值后再更新
    sleep(Duration::from_millis(50)).await;
    tx.send("更新后的配置").unwrap();
    drop(tx); // 关闭通道，consumer 的 changed() 返回 Err 退出

    let seen = consumer.await.unwrap();
    println!("消费者看到的状态序列: {seen:?}");
}
```

运行结果：

```
消费者看到的状态序列: ["初始配置", "更新后的配置"]
```

### 8.5 四种通道选型

| 通道 | 生产者 | 消费者 | 消息语义 | 典型场景 |
|------|--------|--------|----------|----------|
| `oneshot` | 1 | 1 | 单个值，一次性 | 请求-应答、返回单个结果 |
| `mpsc` | 多 | 1 | 每条消息被消费一次 | 工作队列、任务汇总（有界带背压） |
| `broadcast` | 多 | 多 | 每条消息送达所有订阅者 | 事件分发、发布订阅 |
| `watch` | 多 | 多 | 只保留最新值 | 配置热更新、关停/状态信号 |

### 8.6 Mutex / RwLock — 异步锁

`tokio::sync::Mutex` 的 `lock().await` 是异步的，其守卫（guard）可以**跨 `.await` 持有**而不会出问题——这是它相对 `std::sync::Mutex` 的核心能力。`RwLock` 则区分 `read()`（可多个并发）与 `write()`（独占）。

```rust
use std::sync::Arc;
use tokio::sync::Mutex;

#[tokio::main]
async fn main() {
    let counter = Arc::new(Mutex::new(0));
    let mut handles = Vec::new();

    for _ in 0..5 {
        let c = counter.clone();
        handles.push(tokio::spawn(async move {
            let mut guard = c.lock().await; // 异步锁，可跨 .await 持有
            *guard += 1;
        }));
    }

    for h in handles {
        h.await.unwrap();
    }

    println!("最终计数: {}", *counter.lock().await);
}
```

运行结果：

```
最终计数: 5
```

> 取舍原则：**能用 `std::sync::Mutex` 就别用异步锁**。如果临界区里没有 `.await`（只是改个计数、推个 `Vec`），`std::sync::Mutex` 更快更简单——它不会跨 `.await`，不存在"持锁挂起"问题。只有当你确实需要在持锁期间执行 `.await`（如持锁访问数据库）时，才用 `tokio::sync::Mutex`。

### 8.7 Semaphore — 并发限流

`Semaphore` 持有固定数量的"许可（permit）"，`acquire().await` 拿一个许可，许可耗尽时后续请求挂起，用来限制同时进行的操作数量。

```rust
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use tokio::sync::Semaphore;
use tokio::time::{sleep, Duration};

#[tokio::main]
async fn main() {
    let sem = Arc::new(Semaphore::new(2)); // 最多 2 个并发
    let current = Arc::new(AtomicUsize::new(0));
    let max = Arc::new(AtomicUsize::new(0));

    let mut handles = Vec::new();
    for _ in 0..6 {
        let permit = sem.clone();
        let current = current.clone();
        let max = max.clone();
        handles.push(tokio::spawn(async move {
            let _p = permit.acquire().await.unwrap();
            let now = current.fetch_add(1, Ordering::SeqCst) + 1;
            max.fetch_max(now, Ordering::SeqCst);
            sleep(Duration::from_millis(20)).await;
            current.fetch_sub(1, Ordering::SeqCst);
        }));
    }

    for h in handles {
        h.await.unwrap();
    }
    println!("观测到的最大并发数: {}", max.load(Ordering::SeqCst));
}
```

运行结果：

```
观测到的最大并发数: 2
```

> 持有的 `permit`（这里命名为 `_p`）在任务作用域结束时自动归还。`Semaphore` 是给一批 `spawn` 出去的任务限并发的标准做法，比如"最多同时发起 10 个 HTTP 请求"。

### 8.8 Notify — 任务唤醒

`Notify` 是最轻量的同步原语，只传"事件发生了"这一信号、不带数据。`notified().await` 等待通知，`notify_one()` 唤醒一个等待者，`notify_waiters()` 唤醒当前所有等待者。

```rust
use std::sync::Arc;
use tokio::sync::Notify;
use tokio::time::{sleep, Duration};

#[tokio::main]
async fn main() {
    let notify = Arc::new(Notify::new());

    let waiter = {
        let notify = notify.clone();
        tokio::spawn(async move {
            println!("等待者: 开始等待通知");
            notify.notified().await;
            println!("等待者: 收到通知，继续执行");
        })
    };

    sleep(Duration::from_millis(50)).await;
    println!("主任务: 发出通知");
    notify.notify_one();

    waiter.await.unwrap();
}
```

运行结果：

```
等待者: 开始等待通知
主任务: 发出通知
等待者: 收到通知，继续执行
```

### 8.9 Barrier — 任务屏障

`Barrier::new(n)` 要求 `n` 个任务都调用 `wait().await` 后，才一起放行。常用于"所有任务都准备好后再统一开始"的阶段同步。`wait()` 返回的结果中恰有一个 `is_leader()` 为 `true`，便于指定某个任务做收尾工作。

```rust
use std::sync::Arc;
use tokio::sync::Barrier;

#[tokio::main]
async fn main() {
    let barrier = Arc::new(Barrier::new(3));
    let mut handles = Vec::new();

    for id in 0..3 {
        let b = barrier.clone();
        handles.push(tokio::spawn(async move {
            // 各任务先做各自的准备工作
            let result = b.wait().await; // 在此等待全部 3 个任务到齐
            (id, result.is_leader())
        }));
    }

    let mut leaders = 0;
    for h in handles {
        let (_id, is_leader) = h.await.unwrap();
        if is_leader {
            leaders += 1;
        }
    }
    println!("所有任务已越过屏障，leader 数量: {leaders}");
}
```

运行结果：

```
所有任务已越过屏障，leader 数量: 1
```

### 8.10 OnceCell — 异步惰性初始化

`OnceCell` 提供"只初始化一次"的延迟初始化。多个任务并发调用 `get_or_init`，初始化逻辑只会真正执行一次，其余调用复用结果。

```rust
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use tokio::sync::OnceCell;

static INIT_CALLS: AtomicUsize = AtomicUsize::new(0);

async fn expensive_init() -> u32 {
    INIT_CALLS.fetch_add(1, Ordering::SeqCst);
    42
}

#[tokio::main]
async fn main() {
    let cell: Arc<OnceCell<u32>> = Arc::new(OnceCell::new());
    let mut handles = Vec::new();

    // 多个任务并发请求初始化，但初始化只会真正执行一次
    for _ in 0..5 {
        let cell = cell.clone();
        handles.push(tokio::spawn(async move {
            *cell.get_or_init(expensive_init).await
        }));
    }

    for h in handles {
        assert_eq!(h.await.unwrap(), 42);
    }

    println!("初始化函数被调用次数: {}", INIT_CALLS.load(Ordering::SeqCst));
    println!("缓存值: {:?}", cell.get());
}
```

运行结果：

```
初始化函数被调用次数: 1
缓存值: Some(42)
```

> `OnceCell` 的初始化函数是 `async` 的，这正是它相对 `std::sync::OnceLock` 的价值——可以 `.await`（例如从数据库或网络加载一次性配置）。适合做全局连接池、配置等"懒加载且只加载一次"的资源。

## 九、tokio::net 网络

`tokio::net` 提供异步的 TCP、UDP、Unix socket。`TcpListener::accept()`、`TcpStream` 的读写全是异步的，配合 `tokio::spawn` 即可"每个连接一个任务"地处理海量并发连接。

### 9.1 TcpListener / TcpStream — 并发回显服务

下面是一个完整可运行的例子：服务端绑定随机端口、为每个连接 spawn 一个回显任务；客户端连接后发送数据并读回回显。

```rust
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    // 绑定到随机端口，由内核分配
    let listener = TcpListener::bind("127.0.0.1:0").await?;
    let addr = listener.local_addr()?;
    println!("服务端监听于 {addr}");

    // 服务端：每来一个连接就 spawn 一个任务回显
    tokio::spawn(async move {
        loop {
            let (mut socket, _) = listener.accept().await.unwrap();
            tokio::spawn(async move {
                let mut buf = [0u8; 1024];
                let n = socket.read(&mut buf).await.unwrap();
                socket.write_all(&buf[..n]).await.unwrap();
            });
        }
    });

    // 客户端：连接并发送数据，再读回显
    let mut client = TcpStream::connect(addr).await?;
    client.write_all(b"ping").await?;
    let mut buf = [0u8; 1024];
    let n = client.read(&mut buf).await?;
    println!("客户端收到回显: {}", String::from_utf8_lossy(&buf[..n]));
    Ok(())
}
```

运行结果（端口由内核随机分配，每次不同）：

```
服务端监听于 127.0.0.1:41597
客户端收到回显: ping
```

> 这段代码体现了 tokio 网络编程的标准范式：外层一个任务循环 `accept`，每接受一个连接就 `spawn` 一个独立任务去处理。因为任务极其轻量，这种"一连接一任务"的写法可以轻松支撑数万并发连接，而无需像同步模型那样开等量的 OS 线程。

### 9.2 UdpSocket — 无连接通信

UDP 用 `UdpSocket::bind` 创建，`send_to`/`recv_from` 收发数据报。它无连接、不保证送达与顺序，适合实时音视频、心跳、DNS 等场景。其余网络类型还有 `UnixListener`/`UnixStream`（Unix 域 socket，本机进程间通信），用法与 TCP 对应物高度一致。

## 十、其他常用模块

### 10.1 select! — 并发竞速

`tokio::select!` 同时等待多个分支，**哪个先就绪就执行哪个**，其余分支的 `Future` 被丢弃（取消）。常用于"任务 + 超时"、"任务 + 退出信号"等竞速场景。

```rust
use tokio::time::{sleep, Duration};

async fn fast() -> &'static str {
    sleep(Duration::from_millis(20)).await;
    "fast 分支先完成"
}

async fn slow() -> &'static str {
    sleep(Duration::from_millis(200)).await;
    "slow 分支先完成"
}

#[tokio::main]
async fn main() {
    tokio::select! {
        r = fast() => println!("胜出: {r}"),
        r = slow() => println!("胜出: {r}"),
    }
    // select! 一旦有分支完成，其余分支的 Future 会被丢弃（取消）
    println!("select 结束");
}
```

运行结果：

```
胜出: fast 分支先完成
select 结束
```

> 重要语义：落败分支的 `Future` 会被**取消**——它们停在自己的 `.await` 点不再前进。如果某个分支有副作用且不能被中途取消，要么把它放进 `tokio::spawn` 让它独立完成，要么使用具备"取消安全（cancellation safety）"的操作。这是 `select!` 最容易出错的地方。

### 10.2 process::Command — 异步子进程

`tokio::process::Command` 是 `std::process::Command` 的异步版，`output().await` 等待子进程结束并收集输出，`spawn()` + `wait().await` 则可在等待的同时不阻塞运行时。

```rust
use tokio::process::Command;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let output = Command::new("echo")
        .arg("hello from subprocess")
        .output()
        .await?;

    println!("退出状态成功: {}", output.status.success());
    print!("子进程 stdout: {}", String::from_utf8_lossy(&output.stdout));
    Ok(())
}
```

运行结果：

```
退出状态成功: true
子进程 stdout: hello from subprocess
```

### 10.3 signal::ctrl_c — 优雅停机

`signal::ctrl_c().await` 在收到 `Ctrl-C`（`SIGINT`）时返回，是实现优雅停机的标准入口。下面的例子为了能自动结束，用一个任务在 100ms 后给自己发送 `SIGINT`：

```rust
use tokio::process::Command;
use tokio::signal;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let pid = std::process::id();

    // 为了让示例自动结束，这里 100ms 后给自己发送 SIGINT（等价于按 Ctrl-C）
    tokio::spawn(async move {
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
        let _ = Command::new("kill").arg("-INT").arg(pid.to_string()).status().await;
    });

    println!("服务运行中，等待 Ctrl-C ...");
    signal::ctrl_c().await?;
    println!("收到 Ctrl-C，开始优雅停机");
    Ok(())
}
```

运行结果：

```
服务运行中，等待 Ctrl-C ...
收到 Ctrl-C，开始优雅停机
```

> 真实服务里常把 `signal::ctrl_c()` 放进 `tokio::select!` 的一个分支，另一个分支跑主循环；收到信号后跳出循环、关闭连接、刷写缓冲、再退出，实现优雅停机。

## 十一、综合实战

最后把多个模块串起来：并发读取一批文件（`fs` + `JoinSet`），每次读取用 `timeout` 限时，结果通过 `mpsc` 汇总给一个专门的任务，由它用 `BufWriter` 写出统计文件。这接近真实的"并发采集 + 汇总落盘"流水线。

```rust
use tokio::fs;
use tokio::io::AsyncWriteExt;
use tokio::sync::mpsc;
use tokio::task::JoinSet;
use tokio::time::{timeout, Duration};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let dir = "/tmp/tk_combined";
    fs::create_dir_all(dir).await?;
    for i in 1..=3 {
        fs::write(format!("{dir}/f{i}.txt"), format!("file {i} content\n").repeat(i)).await?;
    }

    // 汇总任务：通过 mpsc 接收每个文件的统计，写入 summary
    let (tx, mut rx) = mpsc::channel::<(String, usize)>(16);
    let summary = tokio::spawn(async move {
        let out = fs::File::create("/tmp/tk_combined/summary.txt").await.unwrap();
        let mut writer = tokio::io::BufWriter::new(out);
        let mut lines = Vec::new();
        while let Some((name, len)) = rx.recv().await {
            lines.push(format!("{name}={len}"));
        }
        lines.sort();
        for line in &lines {
            writer.write_all(format!("{line}\n").as_bytes()).await.unwrap();
        }
        writer.flush().await.unwrap();
        lines.len()
    });

    // 并发读取所有文件，每个读取限时 1s
    let mut set = JoinSet::new();
    for i in 1..=3 {
        let tx = tx.clone();
        let path = format!("{dir}/f{i}.txt");
        set.spawn(async move {
            let name = format!("f{i}.txt");
            if let Ok(Ok(content)) = timeout(Duration::from_secs(1), fs::read_to_string(&path)).await {
                tx.send((name, content.len())).await.unwrap();
            }
        });
    }
    while set.join_next().await.is_some() {}
    drop(tx); // 关闭通道，汇总任务退出

    let count = summary.await.unwrap();
    let summary_text = fs::read_to_string("/tmp/tk_combined/summary.txt").await?;
    println!("汇总了 {count} 个文件:");
    print!("{summary_text}");

    fs::remove_dir_all(dir).await?;
    Ok(())
}
```

运行结果：

```
汇总了 3 个文件:
f1.txt=15
f2.txt=30
f3.txt=45
```

这个例子里有几个值得回味的设计：读取任务们和汇总任务通过 `mpsc` 解耦——读取者只管 `send`，汇总者只管 `recv`；所有读取任务 `spawn` 出去的 `tx` clone 加上主线程持有的 `tx`，必须全部 `drop` 后 `rx.recv()` 才会返回 `None`，所以 `while set.join_next()` 结束后要显式 `drop(tx)`，否则汇总任务会永远等下去。这正是异步编程里"通道生命周期决定收尾时机"的典型范式。

至此，从依赖引入、运行时与任务模型，到 `fs`、`io`、`time`、`sync`、`net` 以及 `select!`/`process`/`signal`，tokio 的核心能力就构成了一张完整的图。掌握这些，你已经可以用 tokio 写出高并发的网络服务、批处理流水线和各类异步应用了。
