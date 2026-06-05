---
title: "[标准库] std::sync 并发同步原语介绍与实战"
published: true
layout: post
date: 2026-05-29 16:00:00
permalink: /rust/std-sync.html
tags:
  - Mutex
  - RwLock
  - Arc
  - Condvar
  - 原子操作
  - 消息通道
categories:
  - Rust
---

多线程程序共享内存时，数据竞争是最隐蔽的 bug 来源——两个线程同时读写同一块内存，结果取决于调度时序，既无法重现也无法推理。`std::sync` 是 Rust 标准库提供的并发同步工具箱：从最低级的原子操作到高层的锁、条件变量、屏障和消息通道，每一种原语都在类型系统层面表达出"谁在什么时候可以访问数据"，让编译器而非运行时来兜底。

## 一、模块概览

`std::sync` 的核心组件可按用途分为四类：

| 组件                    | 类型       | 说明                                         |
| --------------------- | -------- | ------------------------------------------ |
| `Arc<T>`              | `struct` | 原子引用计数，跨线程共享所有权                            |
| `Weak<T>`             | `struct` | `Arc<T>` 的弱引用，不阻止释放                        |
| `Mutex<T>`            | `struct` | 互斥锁，独占访问被保护数据                              |
| `RwLock<T>`           | `struct` | 读写锁，多读单写                                   |
| `Condvar`             | `struct` | 条件变量，配合 `Mutex` 等待事件                       |
| `Barrier`             | `struct` | 屏障，协调 N 个线程同时到达某一点                         |
| `Once`                | `struct` | 确保全局初始化代码只执行一次                             |
| `OnceLock<T>`         | `struct` | 可写一次的线程安全单元格                               |
| `LazyLock<T>`         | `struct` | 懒初始化静态变量，首次访问时执行闭包                         |
| `atomic`              | 子模块      | 无锁原子类型：`AtomicBool`、`AtomicU64` 等          |
| `mpsc`                | 子模块      | 多生产者单消费者消息通道                               |
| `MutexGuard<T>`       | `struct` | `Mutex` 的 `RAII` 守卫，离开作用域自动解锁              |
| `RwLockReadGuard<T>`  | `struct` | 持有读锁的守卫                                    |
| `RwLockWriteGuard<T>` | `struct` | 持有写锁的守卫                                    |
| `PoisonError<T>`      | `struct` | 锁被毒化时返回的错误                                 |
| `TryLockError<T>`     | `enum`   | `try_lock` 的错误类型：`WouldBlock` 或 `Poisoned` |

## 二、Arc — 跨线程共享所有权

普通的 `Rc<T>` 使用非原子的引用计数，克隆和释放都不是线程安全的操作。`Arc<T>`（`Atomically Reference Counted`）把引用计数的增减替换为原子操作，从而满足 `Send + Sync` 约束，可以跨线程传递。

### 2.1 Arc 基本用法

**语法：**

```rust
pub fn new(data: T) -> Arc<T>
pub fn clone(this: &Arc<T>) -> Arc<T>    // 通常写作 Arc::clone(&arc)
pub fn strong_count(this: &Arc<T>) -> usize
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `data` | - | 被共享的值；`Arc::new` 将其移入堆上 |

`Arc::clone` 只是递增引用计数，代价极低（一次原子加操作），不复制内部数据。所有引用都释放后，内部数据才被析构。`Arc<T>` 本身是不可变的共享引用——若要共享可变数据，必须与 `Mutex<T>` 或 `RwLock<T>` 组合，这也是整个 `std::sync` 最常见的模式。

```rust
use std::sync::{Arc, Mutex};
use std::thread;

fn main() {
    let counter = Arc::new(Mutex::new(0u32));
    let mut handles = vec![];

    for i in 0..4 {
        let counter = Arc::clone(&counter);
        let handle = thread::spawn(move || {
            let mut val = counter.lock().unwrap();
            *val += 10;
            println!("thread-{i}: counter = {}", *val);
        });
        handles.push(handle);
    }

    for h in handles {
        h.join().unwrap();
    }

    println!("最终 counter = {}", *counter.lock().unwrap());
}
```

运行结果：

```
thread-0: counter = 10
thread-1: counter = 20
thread-2: counter = 30
thread-3: counter = 40
最终 counter = 40
```

> 线程间打印顺序由调度决定，实际运行时可能与上方不同；但最终 `counter` 必然等于 40——这正是 `Mutex` 提供的保证。

### 2.2 Weak — 打破循环引用

`Weak<T>` 是 `Arc<T>` 的弱引用：它不增加强引用计数，因此不阻止数据释放。调用 `upgrade()` 可尝试升级为 `Arc<T>`，若数据已释放则返回 `None`。

典型用途是父子节点互相引用的树形结构：子节点持有父节点的 `Weak`，父节点持有子节点的 `Arc`，从而避免循环引用导致内存永不释放。

```rust
pub fn downgrade(this: &Arc<T>) -> Weak<T>
pub fn upgrade(&self) -> Option<Arc<T>>
pub fn strong_count(&self) -> usize
```

## 三、Mutex — 互斥锁

`Mutex<T>`（`Mutual Exclusion`）确保同一时刻至多有一个线程能访问被保护的数据。与 C/C++ 的锁不同，Rust 的 `Mutex<T>` 把数据直接包裹在锁里——只有成功持有锁，才能拿到数据的引用，让"持锁访问"在类型层面成为必要条件。

### 3.1 lock 与 try_lock

**语法：**

```rust
pub fn lock(&self) -> LockResult<MutexGuard<'_, T>>
pub fn try_lock(&self) -> TryLockResult<MutexGuard<'_, T>>
```

**参数：**

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `lock` | `LockResult<MutexGuard<T>>` | 阻塞直到获得锁；若锁已毒化返回 `Err(PoisonError)` |
| `try_lock` | `TryLockResult<MutexGuard<T>>` | 非阻塞；锁被占用时返回 `Err(TryLockError::WouldBlock)` |

`MutexGuard<T>` 实现了 `Deref` 和 `DerefMut`，可直接通过 `*guard` 访问数据。守卫离开作用域时自动解锁，无需手动调用 unlock。

### 3.2 锁毒化（Lock Poisoning）

若一个线程在持有 `Mutex` 锁期间发生 `panic`，Rust 认为被保护的数据可能处于不一致状态，会将该锁标记为"毒化"（`poisoned`）。后续任何 `lock()` 调用都会返回 `Err(PoisonError<MutexGuard<T>>)`，而非 `Ok`。

这是一种防御性设计：与其让下一个线程悄悄读到损坏数据，不如显式报告异常。若确定数据仍然有效，可以通过 `into_inner()` 从 `PoisonError` 中取出守卫继续使用：

```rust
use std::sync::{Arc, Mutex};
use std::thread;

fn main() {
    // thread::spawn 要求闭包为 'static，因此用 Arc 跨线程共享 Mutex
    let m = Arc::new(Mutex::new(vec![1, 2, 3]));

    // 模拟持锁 panic
    let m2 = Arc::clone(&m);
    let _ = thread::spawn(move || {
        let _guard = m2.lock().unwrap();
        panic!("持锁时 panic");
    }).join(); // Err，但我们继续

    // 锁已毒化
    let result = m.lock();
    match result {
        Ok(v) => println!("正常: {:?}", *v),
        Err(poison) => {
            let v = poison.into_inner();
            println!("锁已毒化，数据仍可用: {:?}", *v);
        }
    }
}
```

运行结果：

```
锁已毒化，数据仍可用: [1, 2, 3]
```

> 若不想处理毒化逻辑，可以直接 `.unwrap_or_else(|e| e.into_inner())` 跳过检查；但在高可靠场景下应认真对待毒化错误，它往往意味着某条线程崩溃了。

## 四、RwLock — 读写锁

`RwLock<T>` 允许任意数量的读者或至多一个写者同时持有锁，二者互斥。当读操作远多于写操作时，`RwLock` 比 `Mutex` 有更高的并发吞吐。

### 4.1 read 与 write

**语法：**

```rust
pub fn read(&self) -> LockResult<RwLockReadGuard<'_, T>>
pub fn write(&self) -> LockResult<RwLockWriteGuard<'_, T>>
pub fn try_read(&self) -> TryLockResult<RwLockReadGuard<'_, T>>
pub fn try_write(&self) -> TryLockResult<RwLockWriteGuard<'_, T>>
```

**参数：**

| 方法 | 守卫类型 | 说明 |
|------|----------|------|
| `read` | `RwLockReadGuard<T>` | 阻塞直到获得读锁；允许多个读者同时持有 |
| `write` | `RwLockWriteGuard<T>` | 阻塞直到获得写锁；独占，期间无读者也无写者 |
| `try_read` | 同上 | 非阻塞版 |
| `try_write` | 同上 | 非阻塞版 |

```rust
use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use std::thread;

fn main() {
    let cache: Arc<RwLock<HashMap<&str, u32>>> = Arc::new(RwLock::new(HashMap::new()));

    // 写入初始数据
    {
        let mut w = cache.write().unwrap();
        w.insert("price_a", 100);
        w.insert("price_b", 200);
        println!("写入完成: {:?}", *w);
    }

    // 多个读线程并发读取
    let mut handles = vec![];
    for i in 0..3 {
        let cache = Arc::clone(&cache);
        let key = if i % 2 == 0 { "price_a" } else { "price_b" };
        let h = thread::spawn(move || {
            let r = cache.read().unwrap();
            println!("reader-{i}: {key} = {:?}", r.get(key));
        });
        handles.push(h);
    }
    for h in handles {
        h.join().unwrap();
    }

    // 写入更新
    {
        let mut w = cache.write().unwrap();
        w.insert("price_a", 150);
        println!("更新 price_a -> 150");
    }

    let r = cache.read().unwrap();
    println!("最终 price_a = {:?}", r.get("price_a"));
}
```

运行结果：

```
写入完成: {"price_b": 200, "price_a": 100}
reader-0: price_a = Some(100)
reader-1: price_b = Some(200)
reader-2: price_a = Some(100)
更新 price_a -> 150
最终 price_a = Some(150)
```

### 4.2 Mutex vs RwLock 选择

| 场景 | 推荐 | 原因 |
|------|------|------|
| 读写比例相近 | `Mutex` | `RwLock` 的读写调度开销并无优势 |
| 读多写少（如缓存、配置） | `RwLock` | 多读者并发，吞吐明显更高 |
| 写操作需要读取旧值再写入 | `Mutex` | `RwLock` 无法将读锁升级为写锁，升级必须释放读锁再重新竞争写锁，容易引发 `TOCTOU` 问题 |
| 保护的数据类型实现了 `Copy` | 考虑 `atomic` | 若只是整数计数，原子操作更轻量 |

> `RwLock` 在 `Linux` 上由 `pthreads` `rwlock` 实现；写者饥饿（`writer starvation`）是已知问题——若读者持续涌入，写者可能长期无法获得锁。写操作频率较高的场景应优先考虑 `Mutex`。

## 五、Condvar — 条件变量

`Condvar` 解决"等待某个条件成立"的问题。线程持有 `Mutex` 后，发现条件不满足，调用 `wait` 将锁释放并阻塞；当其他线程修改了数据、条件可能成立时，调用 `notify_one` 或 `notify_all` 唤醒等待的线程。

### 5.1 wait 与 notify

**语法：**

```rust
pub fn wait<'a, T>(&self, guard: MutexGuard<'a, T>) -> LockResult<MutexGuard<'a, T>>
pub fn wait_timeout<'a, T>(&self, guard: MutexGuard<'a, T>, dur: Duration)
    -> LockResult<(MutexGuard<'a, T>, WaitTimeoutResult)>
pub fn notify_one(&self)
pub fn notify_all(&self)
```

**参数：**

| 方法 | 说明 |
|------|------|
| `wait(guard)` | 释放 `guard` 持有的锁并阻塞；唤醒后重新持锁，返回新守卫 |
| `wait_timeout(guard, dur)` | 同上，但最多等待 `dur`；返回值中 `WaitTimeoutResult::timed_out()` 表示是否超时 |
| `notify_one` | 唤醒至多一个等待中的线程 |
| `notify_all` | 唤醒所有等待中的线程 |

`Condvar` 必须始终与同一个 `Mutex` 配合使用；传给 `wait` 的守卫来自哪个 `Mutex`，唤醒后也必须重新持有同一把锁。

```rust
use std::sync::{Arc, Condvar, Mutex};
use std::thread;
use std::time::Duration;

fn main() {
    // (队列, 条件变量)
    let pair = Arc::new((Mutex::new(Vec::<i32>::new()), Condvar::new()));
    let pair_producer = Arc::clone(&pair);

    // 生产者线程
    let producer = thread::spawn(move || {
        let (lock, cvar) = &*pair_producer;
        for i in 1..=3 {
            thread::sleep(Duration::from_millis(20));
            let mut q = lock.lock().unwrap();
            q.push(i * 10);
            println!("生产者: 放入 {}", i * 10);
            cvar.notify_one();
        }
    });

    // 消费者在主线程，消费 3 条消息
    let (lock, cvar) = &*pair;
    let mut consumed = 0;
    while consumed < 3 {
        let mut q = lock.lock().unwrap();
        while q.is_empty() {
            q = cvar.wait(q).unwrap();
        }
        let item = q.remove(0);
        println!("消费者: 取出 {item}");
        consumed += 1;
    }

    producer.join().unwrap();
    println!("生产/消费完成");
}
```

运行结果：

```
生产者: 放入 10
消费者: 取出 10
生产者: 放入 20
消费者: 取出 20
生产者: 放入 30
消费者: 取出 30
生产/消费完成
```

> `wait` 存在虚假唤醒（`spurious wakeup`）：即使没有 `notify`，线程也可能返回。因此唤醒后必须用 `while` 循环重新检查条件，而不是 `if`。本例中 `while q.is_empty()` 就是这个目的。

## 六、Barrier — 线程屏障

`Barrier` 让 N 个线程在某个同步点相互等待，所有线程到达后再同时继续执行。典型用途是并行算法中的阶段切换：确保每个线程都完成了上一阶段的工作，再一起进入下一阶段。

### 6.1 wait 与 is_leader

**语法：**

```rust
pub fn new(n: usize) -> Barrier
pub fn wait(&self) -> BarrierWaitResult
```

**参数：**

| 参数/方法 | 说明 |
|---------|------|
| `n`（`new`） | 需要同步的线程数；第 `n` 个调用 `wait` 的线程会解除所有阻塞 |
| `wait` | 阻塞直到 `n` 个线程均调用了 `wait`；返回 `BarrierWaitResult` |
| `is_leader()` | 在同一轮等待中恰好有一个线程返回 `true`，可用于执行只需一次的汇总操作 |

```rust
use std::sync::{Arc, Barrier};
use std::thread;

fn main() {
    let n = 4;
    let barrier = Arc::new(Barrier::new(n));
    let mut handles = vec![];

    for i in 0..n {
        let b = Arc::clone(&barrier);
        let h = thread::spawn(move || {
            println!("worker-{i}: 准备就绪");
            let result = b.wait();
            if result.is_leader() {
                println!("worker-{i}: 我是 leader，所有线程已到达屏障");
            }
            println!("worker-{i}: 开始执行主任务");
        });
        handles.push(h);
    }

    for h in handles {
        h.join().unwrap();
    }
    println!("所有 worker 完成");
}
```

运行结果（线程打印顺序由调度决定）：

```
worker-0: 准备就绪
worker-1: 准备就绪
worker-3: 准备就绪
worker-2: 准备就绪
worker-2: 我是 leader，所有线程已到达屏障
worker-1: 开始执行主任务
worker-0: 开始执行主任务
worker-3: 开始执行主任务
worker-2: 开始执行主任务
所有 worker 完成
```

> `Barrier` 是可重用的：N 个线程全部到达一次后，屏障自动重置，可直接用于下一轮同步，无需重新创建。

## 七、一次性初始化

### 7.1 OnceLock — 可写一次的单元格

`OnceLock<T>` 自 `Rust 1.70.0` 稳定，是线程安全版本的 `OnceCell<T>`。它允许任何代码路径尝试写入，但只有第一次 `set` 成功，后续均被拒绝。

**语法：**

```rust
pub fn new() -> OnceLock<T>
pub fn get(&self) -> Option<&T>
pub fn set(&self, value: T) -> Result<(), T>
pub fn get_or_init<F: FnOnce() -> T>(&self, f: F) -> &T
pub fn get_or_try_init<F, E>(&self, f: F) -> Result<&T, E>
```

**参数：**

| 方法 | 说明 |
|------|------|
| `get` | 返回值的引用；未初始化时返回 `None` |
| `set(value)` | 首次调用写入 `value` 并返回 `Ok(())`；已初始化则返回 `Err(value)` |
| `get_or_init(f)` | 若未初始化则调用 `f` 并写入；已初始化直接返回现有值的引用 |

### 7.2 LazyLock — 懒初始化静态变量

`LazyLock<T>` 自 `Rust 1.80.0` 稳定，专为静态变量设计：在声明时提供一个初始化闭包，首次通过 `Deref` 访问时执行，线程安全地保证只执行一次。与 `OnceLock` 的区别在于初始化逻辑固定在声明处，无法从外部注入不同的初始值。

```rust
use std::sync::{LazyLock, OnceLock};

// OnceLock：运行时一次性初始化，常用于全局静态变量
static APP_NAME: OnceLock<String> = OnceLock::new();

// LazyLock：懒初始化，首次访问时执行闭包
static PRIMES: LazyLock<Vec<u32>> = LazyLock::new(|| {
    println!("  [LazyLock] 初始化质数表...");
    let mut primes = vec![];
    'outer: for n in 2u32..=30 {
        for p in &primes {
            if n % p == 0 {
                continue 'outer;
            }
        }
        primes.push(n);
    }
    primes
});

fn main() {
    // OnceLock：第一次 set 成功，后续均失败
    println!("第一次 set: {:?}", APP_NAME.set("my-service".to_string()));
    println!("第二次 set: {:?}", APP_NAME.set("other".to_string()));
    println!("APP_NAME = {:?}", APP_NAME.get().unwrap());

    // get_or_init：若未初始化则执行闭包，线程安全
    let val = APP_NAME.get_or_init(|| "fallback".to_string());
    println!("get_or_init（已初始化）= {:?}", val);

    // LazyLock：首次 deref 触发初始化
    println!("\n第一次访问 PRIMES:");
    println!("  30 以内的质数: {:?}", *PRIMES);
    println!("第二次访问 PRIMES（不再初始化）:");
    println!("  质数个数: {}", PRIMES.len());
}
```

运行结果：

```
第一次 set: Ok(())
第二次 set: Err("other")
APP_NAME = "my-service"
get_or_init（已初始化）= "my-service"

第一次访问 PRIMES:
  [LazyLock] 初始化质数表...
  30 以内的质数: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
第二次访问 PRIMES（不再初始化）:
  质数个数: 10
```

### 7.3 OnceLock vs LazyLock vs Once 选择

| 类型 | 稳定版本 | 初始化逻辑 | 适用场景 |
|------|----------|-----------|----------|
| `Once` | `1.0.0` | 任意代码路径调用 `call_once` | 无返回值的全局初始化，如注册日志 |
| `OnceLock<T>` | `1.70.0` | 任意代码路径 `set` / `get_or_init` | 运行时决定初始值的全局变量 |
| `LazyLock<T>` | `1.80.0` | 声明时固定的闭包，首次 `deref` 触发 | 编译期知道初始化逻辑的静态变量 |

## 八、原子操作（atomic）

`std::sync::atomic` 提供无锁并发原语，适用于简单数值类型的读写、计数器、标志位等场景。原子操作在单条 CPU 指令层面保证不可分割，不需要操作系统层面的锁，开销远低于 `Mutex`。

### 8.1 原子类型一览

| 类型 | 稳定版本 | 对应的基础类型 |
|------|----------|--------------|
| `AtomicBool` | `1.0.0` | `bool` |
| `AtomicI8` / `AtomicU8` | `1.34.0` | `i8` / `u8` |
| `AtomicI16` / `AtomicU16` | `1.34.0` | `i16` / `u16` |
| `AtomicI32` / `AtomicU32` | `1.34.0` | `i32` / `u32` |
| `AtomicI64` / `AtomicU64` | `1.34.0` | `i64` / `u64` |
| `AtomicIsize` / `AtomicUsize` | `1.0.0` | `isize` / `usize` |
| `AtomicPtr<T>` | `1.0.0` | `*mut T` |

### 8.2 内存顺序（Ordering）

原子操作的每一次调用都需要指定内存顺序，控制编译器和 CPU 在该操作前后的内存可见性约束。

| `Ordering` 值 | 说明 | 适用场景 |
|--------------|------|---------|
| `Relaxed` | 只保证原子性，不提供跨线程的顺序约束 | 纯计数器、无需同步其他内存的场景 |
| `Acquire` | 此操作之后的读写不会被重排到此操作之前 | 读取端：接收"数据已就绪"的信号 |
| `Release` | 此操作之前的读写不会被重排到此操作之后 | 写入端：发出"数据已就绪"的信号 |
| `AcqRel` | `Acquire` + `Release` 的组合 | 读-改-写操作（如 `fetch_add`）的同步点 |
| `SeqCst` | 全局顺序一致，最强约束，最高开销 | 需要在所有线程视角下看到相同操作顺序 |

> `Acquire`/`Release` 配对是最常见的"生产/消费"模式：写入端用 `Release` 发布数据，读取端用 `Acquire` 消费信号，保证消费端能看到写入端在 `store` 之前完成的所有写入。

### 8.3 常用操作

**语法：**

```rust
pub fn load(&self, order: Ordering) -> T
pub fn store(&self, val: T, order: Ordering)
pub fn fetch_add(&self, val: T, order: Ordering) -> T
pub fn fetch_sub(&self, val: T, order: Ordering) -> T
pub fn compare_exchange(
    &self, current: T, new: T,
    success: Ordering, failure: Ordering
) -> Result<T, T>
```

**参数：**

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `load` | `T` | 读取当前值 |
| `store` | `()` | 写入新值 |
| `fetch_add` | 旧值 `T` | 加法并返回操作前的值 |
| `fetch_sub` | 旧值 `T` | 减法并返回操作前的值 |
| `compare_exchange(cur, new, succ, fail)` | `Ok(旧值)` 或 `Err(当前值)` | 若当前值 == `cur` 则原子替换为 `new`；成功用 `succ` 顺序，失败用 `fail` 顺序 |

```rust
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::thread;

fn main() {
    let counter = Arc::new(AtomicU64::new(0));
    let mut handles = vec![];

    for _ in 0..4 {
        let c = Arc::clone(&counter);
        let h = thread::spawn(move || {
            for _ in 0..1000 {
                c.fetch_add(1, Ordering::Relaxed);
            }
        });
        handles.push(h);
    }
    for h in handles {
        h.join().unwrap();
    }
    println!("计数结果: {}", counter.load(Ordering::SeqCst));

    // compare_exchange：无锁 CAS 操作
    let flag = AtomicU64::new(0);
    match flag.compare_exchange(0, 1, Ordering::Acquire, Ordering::Relaxed) {
        Ok(prev) => println!("CAS 成功：旧值 = {prev}，新值 = 1"),
        Err(cur) => println!("CAS 失败：当前值 = {cur}"),
    }
    match flag.compare_exchange(0, 2, Ordering::Acquire, Ordering::Relaxed) {
        Ok(prev) => println!("CAS 成功：旧值 = {prev}，新值 = 2"),
        Err(cur) => println!("CAS 失败：当前值 = {cur}"),
    }
}
```

运行结果：

```
计数结果: 4000
CAS 成功：旧值 = 0，新值 = 1
CAS 失败：当前值 = 1
```

> `compare_exchange_weak` 是 `compare_exchange` 的弱版本：在某些平台（如 `ARM`）上可能虚假失败（值匹配但仍返回 `Err`），但性能更好。通常在循环重试的 `CAS` 中使用弱版本，单次检查用强版本。

## 九、消息通道（mpsc）

`std::sync::mpsc`（`Multi-Producer, Single-Consumer`）提供基于消息传递的线程间通信。与共享内存加锁相比，通道让数据在线程间转移所有权，接收端不需要担心发送端是否仍在修改数据。

### 9.1 channel 与 sync_channel

**语法：**

```rust
pub fn channel<T>() -> (Sender<T>, Receiver<T>)
pub fn sync_channel<T>(bound: usize) -> (SyncSender<T>, Receiver<T>)
```

**参数：**

| 函数 | 类型 | 说明 |
|------|------|------|
| `channel` | 无界通道 | `Sender::send` 永不阻塞；若接收端已关闭，发送返回 `Err` |
| `sync_channel(bound)` | 有界通道 | 缓冲区满时 `SyncSender::send` 阻塞；`bound = 0` 表示需要双方同时就位的同步通道 |

```rust
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

fn main() {
    // 单生产者单消费者
    let (tx, rx) = mpsc::channel::<String>();

    let producer = thread::spawn(move || {
        for i in 1..=3 {
            let msg = format!("消息-{i}");
            println!("生产者发送: {msg}");
            tx.send(msg).unwrap();
            thread::sleep(Duration::from_millis(10));
        }
    });

    // recv 阻塞直到收到一条消息或 sender 断开
    while let Ok(msg) = rx.recv() {
        println!("消费者收到: {msg}");
    }
    producer.join().unwrap();

    // 多生产者：clone tx 给多个线程
    println!("\n--- 多生产者 ---");
    let (tx2, rx2) = mpsc::channel::<(usize, i32)>();
    let mut handles = vec![];
    for i in 0..3 {
        let tx = tx2.clone();
        let h = thread::spawn(move || {
            let val = (i + 1) as i32 * 100;
            tx.send((i, val)).unwrap();
        });
        handles.push(h);
    }
    drop(tx2); // 必须 drop 最后一个 sender，rx.recv() 才会在消息耗尽后返回 Err

    let mut results: Vec<_> = rx2.iter().collect();
    results.sort_by_key(|r| r.0);
    for (id, val) in results {
        println!("  worker-{id} 发送: {val}");
    }
    for h in handles {
        h.join().unwrap();
    }
}
```

运行结果：

```
生产者发送: 消息-1
消费者收到: 消息-1
生产者发送: 消息-2
消费者收到: 消息-2
生产者发送: 消息-3
消费者收到: 消息-3

--- 多生产者 ---
  worker-0 发送: 100
  worker-1 发送: 200
  worker-2 发送: 300
```

> 多生产者场景中，`Sender` 可以任意 `clone`，每个线程持有一个独立的副本。`Receiver` 不可克隆——消费者必须是唯一的。当所有 `Sender` 都被 `drop` 后，`rx.recv()` 返回 `Err(RecvError)`，`while let Ok` 循环自然结束。忘记 `drop(tx2)` 是多生产者场景最常见的死锁来源。

## 十、综合实战

以下示例实现一个并行日志分析器，综合运用本文介绍的多种同步原语：

- `LazyLock` 持有全局关键词配置
- `Barrier` 确保所有 `worker` 同时开始
- `AtomicU64` 无锁统计处理总行数
- `Arc<RwLock<...>>` 缓存已处理分块信息（多读少写）
- `Arc<Mutex<...>>` 汇总错误日志（独占写入）
- `mpsc` 将各 `worker` 的发现传回主线程

```rust
use std::sync::{Arc, Barrier, LazyLock, Mutex, RwLock};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc;
use std::thread;

static KEYWORD: LazyLock<String> = LazyLock::new(|| "ERROR".to_string());

fn analyze_chunk(chunk: &[&str]) -> Vec<String> {
    chunk
        .iter()
        .filter(|line| line.contains(KEYWORD.as_str()))
        .map(|s| s.to_string())
        .collect()
}

fn main() {
    let logs: Vec<&str> = vec![
        "INFO  app started",
        "ERROR disk full",
        "WARN  high cpu",
        "ERROR network timeout",
        "INFO  request ok",
        "ERROR db connection lost",
        "INFO  shutdown",
        "WARN  cache miss",
    ];

    let chunk_size = 2;
    let chunks: Vec<&[&str]> = logs.chunks(chunk_size).collect();
    let n = chunks.len();

    let barrier = Arc::new(Barrier::new(n));
    let total_lines = Arc::new(AtomicU64::new(0));
    let processed_files: Arc<RwLock<Vec<String>>> = Arc::new(RwLock::new(Vec::new()));
    let errors: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
    let (tx, rx) = mpsc::channel::<(usize, Vec<String>)>();

    let mut handles = vec![];
    for (i, chunk) in chunks.into_iter().enumerate() {
        let barrier = Arc::clone(&barrier);
        let total = Arc::clone(&total_lines);
        let files = Arc::clone(&processed_files);
        let errs = Arc::clone(&errors);
        let tx = tx.clone();
        let chunk: Vec<&str> = chunk.to_vec();

        let h = thread::spawn(move || {
            barrier.wait(); // 所有 worker 同时开始
            total.fetch_add(chunk.len() as u64, Ordering::Relaxed);
            files.write().unwrap().push(format!("chunk-{i}"));
            let found = analyze_chunk(&chunk);
            if !found.is_empty() {
                errs.lock().unwrap().extend(found.clone());
            }
            tx.send((i, found)).unwrap();
        });
        handles.push(h);
    }
    drop(tx);

    let mut results: Vec<(usize, Vec<String>)> = rx.iter().collect();
    results.sort_by_key(|r| r.0);

    for h in handles {
        h.join().unwrap();
    }

    println!("=== 日志分析报告 ===");
    println!("总行数: {}", total_lines.load(Ordering::SeqCst));
    println!("ERROR 汇总（共 {} 条）:", errors.lock().unwrap().len());
    for line in errors.lock().unwrap().iter() {
        println!("  {line}");
    }
    println!("各 chunk 发现的 ERROR:");
    for (i, found) in &results {
        println!("  chunk-{i}: {} 条", found.len());
    }
}
```

运行结果（`ERROR 汇总` 顺序因线程调度而异）：

```
=== 日志分析报告 ===
总行数: 8
ERROR 汇总（共 3 条）:
  ERROR db connection lost
  ERROR network timeout
  ERROR disk full
各 chunk 发现的 ERROR:
  chunk-0: 1 条
  chunk-1: 1 条
  chunk-2: 1 条
  chunk-3: 0 条
```
