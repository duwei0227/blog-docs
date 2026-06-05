---
title: "[标准库] std::thread 线程管理介绍与实战"
published: true
layout: post
date: 2026-05-29 14:00:00
permalink: /rust/std-thread.html
tags:
  - 线程安全
  - JoinHandle
  - 线程局部存储
  - scoped线程
  - park
categories:
  - Rust
---

操作系统的调度单元是线程，而不是进程——一个进程可以同时运行多条执行流，彼此共享内存地址空间，但各自有独立的栈。`std::thread` 是 Rust 标准库中原生线程管理的统一接口：创建线程、等待线程结束、通过 `park`/`unpark` 轻量传递信号、通过 `thread_local!` 为每条线程维护独立状态。Rust 的所有权系统在编译期就排除了数据竞争，使并发编程的正确性得到静态保证，而无需运行时 GC 的介入。

## 一、模块概览

`std::thread` 自 `Rust 1.0.0` 起稳定，核心组件如下：

| 组件 | 类型 | 说明 |
|------|------|------|
| `spawn` | `fn` | 创建独立线程，返回 `JoinHandle<T>` |
| `scope` | `fn` | 创建有界作用域，允许线程借用局部变量 |
| `sleep` | `fn` | 阻塞当前线程至少指定时长 |
| `yield_now` | `fn` | 协作式让出 CPU 时间片 |
| `park` | `fn` | 阻塞当前线程直到收到 `unpark` 令牌 |
| `park_timeout` | `fn` | 同 `park`，但有超时上限 |
| `current` | `fn` | 获取当前线程的 `Thread` 句柄 |
| `available_parallelism` | `fn` | 查询程序默认可用的并行度（逻辑 CPU 数） |
| `panicking` | `fn` | 判断当前线程是否正在 `panic` 展开 |
| `Builder` | `struct` | 线程工厂，配置名称与栈大小 |
| `Thread` | `struct` | 线程句柄，可查询 `id`/`name`，调用 `unpark` |
| `JoinHandle<T>` | `struct` | 等待线程结束并获取返回值的所有权凭证 |
| `ThreadId` | `struct` | 线程唯一标识符，不可复用 |
| `Scope` | `struct` | `scope` 函数的作用域对象，用于在其内部 `spawn` 有界线程 |
| `ScopedJoinHandle<'scope, T>` | `struct` | 有界线程的等待凭证 |
| `LocalKey<T>` | `struct` | `thread_local!` 宏生成的线程局部变量访问键 |

## 二、线程创建

### 2.1 spawn — 创建独立线程

**语法：**

```rust
pub fn spawn<F, T>(f: F) -> JoinHandle<T>
where
    F: FnOnce() -> T + Send + 'static,
    T: Send + 'static,
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `f` | - | 闭包，在新线程中执行；必须满足 `Send + 'static` |

`spawn` 立即在操作系统层面创建一条新线程并开始执行 `f`。返回的 `JoinHandle<T>` 是等待该线程结束、取回返回值的唯一凭证。若 `JoinHandle` 被丢弃而未调用 `join`，线程将继续独立运行（`detach`）直到自然结束——它不会被强制杀死，也不受父线程生命周期约束（主线程除外）。

`'static` 约束意味着闭包不能持有对栈上数据的引用，否则编译器拒绝通过；若需要借用局部变量，使用 `scope`（见 2.3 节）。

```rust
use std::thread;

fn main() {
    let handle = thread::spawn(move || {
        println!("子线程运行中，线程名: {:?}", thread::current().name());
        42
    });

    let result = handle.join().expect("线程 panic 了");
    println!("子线程返回值: {result}");
}
```

运行结果：

```
子线程运行中，线程名: None
子线程返回值: 42
```

`JoinHandle::join` 返回 `thread::Result<T>`，即 `Result<T, Box<dyn Any + Send + 'static>>`。`Ok(T)` 是线程正常返回的值；`Err(payload)` 表示线程发生了 `panic`，`payload` 是 `panic!` 的参数（见 4.3 节）。

### 2.2 Builder — 定制线程属性

**语法：**

```rust
pub fn new() -> Builder
pub fn name(self, name: String) -> Builder
pub fn stack_size(self, size: usize) -> Builder
pub fn spawn<F, T>(self, f: F) -> io::Result<JoinHandle<T>>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `name` | `None`（匿名） | 线程名称；`panic` 信息和调试工具会展示该名称 |
| `stack_size` | 平台默认 `2 MiB` | 线程栈大小（字节）；覆盖 `RUST_MIN_STACK` 环境变量 |

`Builder::spawn` 与 `thread::spawn` 的唯一区别在于返回 `io::Result`——当操作系统资源不足（如线程数上限）时会返回 `Err`，而不是直接 `panic`。

线程名称通过 `pthread_setname_np`（`Linux`/`macOS`）传递给操作系统，可在 `/proc/<pid>/task/<tid>/comm` 和 `ps -T` 中看到，也会出现在 `panic` 消息的 `thread 'name' panicked at ...` 中，有助于快速定位问题。

```rust
use std::thread;

fn main() {
    let handle = thread::Builder::new()
        .name("worker-1".to_string())
        .stack_size(2 * 1024 * 1024)
        .spawn(move || {
            let t = thread::current();
            println!("线程名: {}", t.name().unwrap_or("(unnamed)"));
            println!("线程 ID: {:?}", t.id());
            100u32
        })
        .expect("创建线程失败");

    let result = handle.join().expect("线程 panic 了");
    println!("返回值: {result}");
}
```

运行结果：

```
线程名: worker-1
线程 ID: ThreadId(2)
返回值: 100
```

> 主线程的栈大小由操作系统或链接器控制，`Builder::stack_size` 和 `RUST_MIN_STACK` 均对主线程无效。若程序在主线程递归导致栈溢出，需通过 `ulimit -s`（`Unix`）或链接器标志调整。

### 2.3 scope — 有界作用域线程

**语法：**

```rust
pub fn scope<'env, F, T>(f: F) -> T
where
    F: for<'scope> FnOnce(&'scope Scope<'scope, 'env>) -> T,
```

`scope` 解决了 `spawn` 的 `'static` 限制：在 `scope` 闭包内通过 `Scope::spawn` 创建的线程，其生命周期不得超过 `scope` 本身——`scope` 函数返回前会自动 `join` 所有内部线程，因此这些线程可以安全地借用外层栈上的数据。

```rust
use std::sync::Mutex;
use std::thread;

fn main() {
    let data = vec![10, 20, 30, 40, 50];
    let results: Mutex<Vec<String>> = Mutex::new(Vec::new());

    thread::scope(|s| {
        s.spawn(|| {
            let sum: i32 = data.iter().sum();
            results.lock().unwrap().push(format!("sum = {sum}"));
        });
        s.spawn(|| {
            let max = data.iter().max().unwrap();
            results.lock().unwrap().push(format!("max = {max}"));
        });
    });

    // scope 结束后所有线程已 join
    let mut output = results.into_inner().unwrap();
    output.sort(); // 排序保证输出确定
    for line in &output {
        println!("{line}");
    }
    println!("所有线程已完成，可安全访问 data: {:?}", &data[..2]);
}
```

运行结果：

```
max = 50
sum = 150
所有线程已完成，可安全访问 data: [10, 20]
```

与 `spawn` 的对比：

| 特性 | `spawn` | `scope` 内的 `spawn` |
|------|---------|----------------------|
| 闭包约束 | `'static` | 可借用 `'env` 生命周期内的数据 |
| 自动 `join` | 否（需手动） | 是（`scope` 返回前） |
| 返回凭证 | `JoinHandle<T>` | `ScopedJoinHandle<'scope, T>` |
| 创建方式 | `thread::spawn(f)` | `s.spawn(f)`（`s` 是 `&Scope`） |

## 三、线程控制

### 3.1 sleep

**语法：**

```rust
pub fn sleep(dur: Duration)
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `dur` | - | 最短休眠时长；实际休眠时间 ≥ `dur`，操作系统调度精度决定上限 |

`sleep` 将当前线程挂起，在此期间不占用 CPU。操作系统保证至少等待 `dur`，但可能因调度延迟或虚假唤醒（`spurious wakeup`）而稍长。若需要精确定时（如实时系统），需要平台特定的 API，标准库不提供。

```rust
use std::thread;
use std::time::Duration;

fn main() {
    println!("开始");
    thread::sleep(Duration::from_millis(200));
    println!("休眠 200ms 结束");
}
```

运行结果：

```
开始
休眠 200ms 结束
```

### 3.2 yield_now

**语法：**

```rust
pub fn yield_now()
```

协作式让出当前线程剩余的 CPU 时间片，通知调度器可以运行其他线程。与 `sleep` 不同，`yield_now` 不阻塞——如果没有其他可运行线程，当前线程可能立刻继续执行。

典型用途是在自旋等待某个条件时降低 CPU 占用：

```rust
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;

fn main() {
    let ready = Arc::new(AtomicBool::new(false));
    let ready_w = Arc::clone(&ready);

    let worker = thread::spawn(move || {
        thread::sleep(std::time::Duration::from_millis(5));
        ready_w.store(true, Ordering::Release);
    });

    while !ready.load(Ordering::Acquire) {
        thread::yield_now(); // 让出 CPU，而非空转
    }
    println!("ready!");
    worker.join().unwrap();
}
```

运行结果：

```
ready!
```

> 自旋 + `yield_now` 仍然消耗 CPU，适合等待时间极短（微秒级）的场景。等待时间不可预测时，优先使用 `park`/`unpark` 或条件变量（`Condvar`）。

### 3.3 park 与 unpark

**语法：**

```rust
pub fn park()
pub fn park_timeout(dur: Duration)
```

`park` 阻塞当前线程，直到有其他线程调用 `Thread::unpark` 向该线程发放一个令牌（`token`）。令牌模型的关键特性：

- 令牌只有 0 和 1 两种状态（不会累积）
- 若 `unpark` 先于 `park` 发生，`park` 将立即返回并消耗该令牌
- 即便没有 `unpark`，`park` 也可能虚假唤醒——使用者必须在唤醒后重新检查条件

```rust
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

fn main() {
    let ready = Arc::new(Mutex::new(false));
    let ready_clone = Arc::clone(&ready);

    let worker = thread::spawn(move || {
        println!("worker: 等待信号...");
        thread::park();
        println!("worker: 收到信号，开始处理");
        "done"
    });

    // 主线程准备好数据后 unpark
    thread::sleep(Duration::from_millis(50));
    *ready_clone.lock().unwrap() = true;
    println!("main: 数据就绪，发送信号");
    worker.thread().unpark();

    let result = worker.join().unwrap();
    println!("main: worker 返回 \"{result}\"");
}
```

运行结果：

```
worker: 等待信号...
main: 数据就绪，发送信号
worker: 收到信号，开始处理
main: worker 返回 "done"
```

`park_timeout` 是带超时的版本，超时后自动返回，适合需要定期检查状态的场景：

```rust
use std::time::Duration;
use std::thread;

thread::park_timeout(Duration::from_secs(1));
// 1 秒内若被 unpark 则提前返回，否则超时返回
```

> `park`/`unpark` 的正确使用模式是"先设置条件，再 `unpark`"；唤醒后"先检查条件，再继续"。因为令牌不会累积，多次 `unpark` 只会留下一个令牌，中途丢失的信号需要通过共享状态补偿。

## 四、线程信息查询

### 4.1 current 与 ThreadId

**语法：**

```rust
pub fn current() -> Thread
```

返回当前正在执行的线程的 `Thread` 句柄。`Thread` 提供两个主要方法：

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `name()` | `Option<&str>` | 线程名称；未命名线程返回 `None` |
| `id()` | `ThreadId` | 唯一标识符；进程生命周期内不复用 |
| `unpark()` | `()` | 向该线程发放一个 `park` 令牌 |

`ThreadId` 实现了 `Eq`、`Hash`、`Debug`，可用作 `HashMap` 的键。不同进程的 `ThreadId` 没有可比性。

```rust
use std::thread;

fn main() {
    let t = thread::current();
    println!("当前线程名: {}", t.name().unwrap_or("(unnamed)"));
    println!("当前线程 ID: {:?}", t.id());
    println!("当前是否在 panic 中: {}", thread::panicking());
}
```

运行结果：

```
当前线程名: main
当前线程 ID: ThreadId(1)
当前是否在 panic 中: false
```

### 4.2 available_parallelism

**语法：**

```rust
pub fn available_parallelism() -> io::Result<NonZeroUsize>
```

返回程序当前可利用的默认并行度——通常是逻辑 CPU 核数，但在受 `cgroup` 或 `taskset` 约束的容器环境下会反映实际配额，而非主机总核数。线程池的初始大小通常以此为依据。

```rust
use std::thread;

fn main() {
    let parallelism = thread::available_parallelism().unwrap();
    println!("逻辑 CPU 数: {parallelism}");
}
```

运行结果：

```
逻辑 CPU 数: 8
```

### 4.3 panicking 与 panic 捕获

**语法：**

```rust
pub fn panicking() -> bool
```

判断当前线程是否处于 `panic` 展开（`unwinding`）阶段。典型用途是在 `Drop` 实现中区分"正常析构"与"panic 时析构"，避免在后者中再次触发 `panic`（`double-panic` 会导致 `abort`）。

非 `panic` 路径下 `panicking()` 恒为 `false`；它只在 `panic` 展开调用栈期间才返回 `true`。

---

`JoinHandle::join` 能捕获子线程的 `panic`：

```rust
use std::thread;

fn main() {
    // 捕获另一线程的 panic
    let handle = thread::spawn(|| {
        panic!("演示 panic 捕获");
    });

    match handle.join() {
        Ok(_) => println!("线程正常退出"),
        Err(payload) => {
            if let Some(msg) = payload.downcast_ref::<&str>() {
                println!("捕获到 panic: \"{msg}\"");
            }
        }
    }
}
```

运行结果：

```
捕获到 panic: "演示 panic 捕获"
```

> `panic` 捕获对 `panic = "abort"` 编译配置无效——该配置下 `panic` 直接终止进程，`JoinHandle::join` 永远得不到 `Err`。生产环境若需要捕获 `panic`，须在 `Cargo.toml` 中确认 `panic = "unwind"`（默认值）。

## 五、线程局部存储（TLS）

### 5.1 thread_local! 宏

**语法：**

```rust
thread_local! {
    static NAME: TYPE = INIT_EXPR;
    static NAME: TYPE = const { CONST_EXPR }; // 常量初始化（更高效）
}
```

`thread_local!` 宏声明线程局部变量：每条线程首次访问时独立初始化，线程退出时销毁。不同线程的同名变量完全独立，既无需同步原语，也不会相互影响。

初始化表达式有两种形式：
- 普通表达式：首次访问时懒求值（`lazy initialization`）
- `const { ... }`：在编译期求值，避免运行时初始化开销（自 `Rust 1.84.0` 稳定）

```rust
use std::cell::RefCell;
use std::thread;

thread_local! {
    static REQUEST_ID: RefCell<u64> = const { RefCell::new(0) };
}

fn set_request_id(id: u64) {
    REQUEST_ID.with(|r| *r.borrow_mut() = id);
}

fn current_request_id() -> u64 {
    REQUEST_ID.with(|r| *r.borrow())
}

fn main() {
    set_request_id(1001);
    println!("[main] request_id = {}", current_request_id());

    // 每个线程独立维护自己的 REQUEST_ID
    let t1 = thread::spawn(|| {
        set_request_id(2001);
        current_request_id()
    });

    let t2 = thread::spawn(|| {
        set_request_id(3001);
        current_request_id()
    });

    println!("[thread-1] request_id = {}", t1.join().unwrap());
    println!("[thread-2] request_id = {}", t2.join().unwrap());

    // 主线程的 REQUEST_ID 未受子线程影响
    println!("[main] request_id 仍为 {}", current_request_id());
}
```

运行结果：

```
[main] request_id = 1001
[thread-1] request_id = 2001
[thread-2] request_id = 3001
[main] request_id 仍为 1001
```

### 5.2 LocalKey 访问方式

`thread_local!` 生成的变量类型为 `LocalKey<T>`，提供以下访问方法：

| 方法 | 说明 |
|------|------|
| `with(f)` | 将共享引用传给闭包 `f`；线程退出后调用会 `panic` |
| `try_with(f)` | 同 `with`，但线程退出后返回 `Err(AccessError)` 而非 `panic` |
| `set(value)` | 直接替换当前线程的值（自 `Rust 1.84.0` 稳定） |
| `get()` | 返回当前线程的值副本（需 `T: Copy`，自 `Rust 1.84.0` 稳定） |
| `replace(value)` | 替换并返回旧值（需 `T: Clone`，自 `Rust 1.84.0` 稳定） |

`with` 传入的是 `&T`，若要修改内部数据，`T` 需包含内部可变性——`Cell<T>`（适合 `Copy` 类型）或 `RefCell<T>`（适合任意类型）。`LocalKey<T>` 本身不是 `Sync`，因此无法在线程间共享，也不需要锁。

> `thread_local!` 变量的析构顺序在同一线程内是声明的逆序，但跨线程不保证顺序。若析构函数访问另一个已被销毁的 `TLS` 变量，`try_with` 会返回 `Err`；`with` 会 `panic`。涉及 `TLS` 相互依赖时，优先使用 `try_with`。

## 六、综合实战

以下示例综合运用了本文介绍的主要 API：用 `available_parallelism` 感知环境并行度、通过 `scope` 让 `worker` 借用外层数据、用 `thread_local!` 为每条 `worker` 线程维护独立计数、最后用 `park`/`unpark` 触发汇报线程。

```rust
use std::cell::RefCell;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

// 线程局部存储：每个 worker 持有自己的处理计数
thread_local! {
    static PROCESSED: RefCell<usize> = const { RefCell::new(0) };
}

fn process_chunk(chunk: &[i32]) -> i64 {
    PROCESSED.with(|p| *p.borrow_mut() += chunk.len());
    chunk.iter().map(|&x| x as i64 * x as i64).sum()
}

fn main() {
    let parallelism = thread::available_parallelism().unwrap().get();
    println!("逻辑 CPU 数: {parallelism}，使用 4 个 worker");

    let data: Vec<i32> = (1..=20).collect();
    let chunk_size = (data.len() + 3) / 4;

    // worker_results[i] 存放 worker-i 的 (索引, 本线程累计, 平方和)
    let worker_results: Mutex<Vec<(usize, usize, i64)>> = Mutex::new(Vec::new());

    // 用 scope 确保 worker 能借用 data
    thread::scope(|s| {
        for (i, chunk) in data.chunks(chunk_size).enumerate() {
            let results = &worker_results;
            s.spawn(move || {
                let result = process_chunk(chunk);
                let local_count = PROCESSED.with(|p| *p.borrow());
                results.lock().unwrap().push((i, local_count, result));
            });
        }
    });

    // scope 结束后所有 worker 已 join，按 worker 索引排序打印
    let mut records = worker_results.into_inner().unwrap();
    records.sort_by_key(|r| r.0);

    let chunk_sizes: Vec<usize> = data.chunks(chunk_size).map(|c| c.len()).collect();
    let mut total = 0i64;
    for (i, local_count, result) in &records {
        println!(
            "  worker-{i} 处理 {} 个元素，平方和 = {result}，本线程累计 {local_count}",
            chunk_sizes[*i]
        );
        total += result;
    }
    println!("1²+2²+...+20² = {total}");

    // 演示 park/unpark 作为简单信号机制
    let flag = Arc::new(Mutex::new(false));
    let flag_clone = Arc::clone(&flag);

    let reporter = thread::Builder::new()
        .name("reporter".to_string())
        .spawn(move || {
            println!("\nreporter: 等待汇报信号...");
            thread::park();
            println!("reporter: 任务完成，总平方和已就绪");
        })
        .unwrap();

    thread::sleep(Duration::from_millis(10));
    *flag_clone.lock().unwrap() = true;
    println!("main: 发送汇报信号");
    reporter.thread().unpark();
    reporter.join().unwrap();
}
```

运行结果：

```
逻辑 CPU 数: 8，使用 4 个 worker
  worker-0 处理 5 个元素，平方和 = 55，本线程累计 5
  worker-1 处理 5 个元素，平方和 = 330，本线程累计 5
  worker-2 处理 5 个元素，平方和 = 855，本线程累计 5
  worker-3 处理 5 个元素，平方和 = 1630，本线程累计 5
1²+2²+...+20² = 2870

reporter: 等待汇报信号...
main: 发送汇报信号
reporter: 任务完成，总平方和已就绪
```
