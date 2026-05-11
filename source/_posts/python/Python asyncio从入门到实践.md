---
title: Python asyncio 从入门到实践
published: true
layout: post
date: 2026-05-08 11:00:00
permalink: /python/asyncio.html
categories:
  - Python
---


`asyncio` 是 Python 标准库中用于编写**单线程并发代码**的框架，基于 `async/await` 语法，适用于 I/O 密集型场景（网络请求、文件读写、数据库查询等）。它的核心思想是：当一个任务在等待 I/O 时，不阻塞整个程序，而是切换到其他任务继续执行——就像一个服务员同时服务多桌客人，给某桌上菜后不是站在旁边等客人吃完，而是立即去服务下一桌。



## 一、同步 vs 异步：为什么需要 asyncio

理解 asyncio 的价值，最直接的方式是对比同步和异步代码在 I/O 密集型场景下的性能差异。

### 1.1 同步代码的瓶颈

模拟同时获取三份远程数据（用 `time.sleep` 模拟网络延迟）：

```python
import time

def fetch_data_sync(name, delay):
    print(f"开始获取 {name}...")
    time.sleep(delay)
    print(f"{name} 获取完成")
    return f"{name} 的数据"

def main_sync():
    start = time.perf_counter()
    results = []
    results.append(fetch_data_sync("用户信息", 1))
    results.append(fetch_data_sync("订单列表", 1))
    results.append(fetch_data_sync("商品详情", 1))
    elapsed = time.perf_counter() - start
    print(f"\n同步总耗时：{elapsed:.2f} 秒")

main_sync()
```

运行结果：

```
开始获取 用户信息...
用户信息 获取完成
开始获取 订单列表...
订单列表 获取完成
开始获取 商品详情...
商品详情 获取完成

同步总耗时：3.00 秒
```

三个任务串行执行，总耗时 = 各任务耗时之和。

### 1.2 asyncio 并发版本

```python
import asyncio
import time

async def fetch_data_async(name, delay):
    print(f"开始获取 {name}...")
    await asyncio.sleep(delay)
    print(f"{name} 获取完成")
    return f"{name} 的数据"

async def main_async():
    start = time.perf_counter()
    results = await asyncio.gather(
        fetch_data_async("用户信息", 1),
        fetch_data_async("订单列表", 1),
        fetch_data_async("商品详情", 1),
    )
    elapsed = time.perf_counter() - start
    print(f"\nasyncio 总耗时：{elapsed:.2f} 秒")

asyncio.run(main_async())
```

运行结果：

```
开始获取 用户信息...
开始获取 订单列表...
开始获取 商品详情...
用户信息 获取完成
订单列表 获取完成
商品详情 获取完成

asyncio 总耗时：1.00 秒
```

三个任务并发执行，总耗时 ≈ 最慢那个任务的耗时。

### 1.3 适用场景对比

| 并发模型 | 适用场景 | GIL 影响 | 内存开销 | 编程复杂度 |
|---------|---------|---------|---------|----------|
| `asyncio` | 大量 I/O 等待（网络、数据库） | 无影响（单线程） | 极低 | 中（需 async/await） |
| `threading` | I/O 密集，调用同步库 | 受限 | 中（每线程约 8MB） | 低 |
| `multiprocessing` | CPU 密集型计算 | 绕过 GIL | 高（独立内存空间） | 高 |

> `asyncio` 不适合 CPU 密集型任务（图像处理、数值计算等），因为它是单线程的，CPU 密集任务会阻塞整个事件循环。CPU 密集型场景请使用 `multiprocessing` 或 `concurrent.futures.ProcessPoolExecutor`。



## 二、什么是 asyncio

### 2.1 事件循环（Event Loop）

事件循环是 asyncio 的核心，是一个持续运行的循环，负责：

1. 管理所有协程和任务的调度
2. 监听 I/O 事件（网络、文件）
3. 当某个任务遇到 `await` 时，暂停该任务并切换到其他就绪任务
4. 当 I/O 完成后，将对应任务标记为就绪并恢复执行

```
事件循环工作流：

 ┌──────────────────────────────────┐
 │           事件循环                │
 │  ┌────────┐   ┌────────┐        │
 │  │ 任务 A │   │ 任务 B │  ...   │
 │  └────┬───┘   └────┬───┘        │
 │       │ await       │ await      │
 │       ▼             ▼            │
 │   等待 I/O      等待 I/O         │
 │       │  完成后恢复  │            │
 └───────┴─────────────┴────────────┘
```

### 2.2 协程（Coroutine）

**语法：**

```python
async def 函数名(参数, ...):
    result = await 可等待对象
    return result
```

- `async def`：声明协程函数，调用后返回协程对象，不立即执行
- `await`：挂起当前协程，将控制权交给事件循环；右侧只能是可等待对象（协程、Task、Future）

```python
import asyncio

async def greet(name):
    print(f"Hello, {name}!")
    await asyncio.sleep(0)   # 让出控制权，允许其他协程运行
    print(f"Goodbye, {name}!")
    return f"greeted {name}"

result = asyncio.run(greet("asyncio"))
print(f"返回值：{result}")
```

运行结果：

```
Hello, asyncio!
Goodbye, asyncio!
返回值：greeted asyncio
```

> 直接调用 `greet("asyncio")` 只会得到一个协程对象，**不会执行任何代码**。必须用 `asyncio.run()` 或 `await` 才能驱动它执行。

### 2.3 三种可等待对象（Awaitable）

`await` 右侧只能是以下三种对象：

| 类型 | 说明 | 示例 |
|------|------|------|
| **协程（Coroutine）** | `async def` 函数的返回值 | `await fetch_data()` |
| **任务（Task）** | 被事件循环调度的协程包装 | `await asyncio.create_task(coro())` |
| **Future** | 低级别的异步结果占位符 | 通常由框架内部使用 |



## 三、运行协程

### 3.1 asyncio.run()

**语法：**

```python
asyncio.run(coro, *, debug=False)
```

**参数：**

- `coro`：入口协程对象；不能是已运行或已完成的协程
- `debug`：是否启用调试模式，默认 `False`；启用后事件循环会记录慢回调（>100ms）、未关闭的协程等

`asyncio.run()` 是运行异步程序的标准入口（Python 3.7+），它会：

1. 创建一个新的事件循环
2. 运行传入的协程直到完成
3. 关闭事件循环并清理资源

```python
import asyncio

async def main():
    print("程序开始")
    await asyncio.sleep(1)
    print("程序结束")

asyncio.run(main())
```

> 每个程序只应调用一次 `asyncio.run()`，且只在顶层使用。不要在协程内部嵌套调用 `asyncio.run()`。

### 3.2 asyncio.sleep()

**语法：**

```python
await asyncio.sleep(delay, result=None)
```

**参数：**

- `delay`：挂起的秒数，可为浮点数；传 `0` 仅让出控制权而不实际等待
- `result`：协程完成后的返回值，默认 `None`

`asyncio.sleep(seconds)` 是非阻塞版的 `time.sleep()`，它让当前协程暂停指定时间，同时**将控制权交还给事件循环**，让其他任务得以运行。

```python
import asyncio

async def task(name, delay):
    print(f"{name} 开始")
    await asyncio.sleep(delay)   # 非阻塞等待
    print(f"{name} 结束")

async def main():
    # 两个任务交替执行
    await asyncio.gather(task("A", 1), task("B", 2))

asyncio.run(main())
```

运行结果：

```
A 开始
B 开始
A 结束
B 结束
```

> `await asyncio.sleep(0)` 是一个常用技巧，等待时间为 0 但仍然让出控制权，用于主动将 CPU 交还给事件循环。



## 四、并发任务

### 4.1 asyncio.create_task()

**语法：**

```python
task = asyncio.create_task(coro, *, name=None, context=None)
```

**参数：**

- `coro`：要调度的协程对象
- `name`：任务名称，用于调试（可通过 `task.get_name()` 读取），默认自动生成 `Task-N`
- `context`：`contextvars.Context` 实例，指定任务运行的上下文变量环境；默认复制当前上下文

`create_task()` 将协程包装为 `Task` 对象并**立即提交给事件循环调度**，不需要等待当前协程挂起。多个 `create_task()` 调用后，这些任务会并发执行。

```python
import asyncio
import time

async def worker(name, delay):
    print(f"[{name}] 开始，延迟 {delay}s")
    await asyncio.sleep(delay)
    print(f"[{name}] 完成")
    return name

async def main():
    start = time.perf_counter()

    task_a = asyncio.create_task(worker("A", 2))
    task_b = asyncio.create_task(worker("B", 1))
    task_c = asyncio.create_task(worker("C", 3))

    results = await asyncio.gather(task_a, task_b, task_c)
    elapsed = time.perf_counter() - start
    print(f"\n结果：{results}")
    print(f"总耗时：{elapsed:.2f} 秒（非 6 秒）")

asyncio.run(main())
```

运行结果：

```
[A] 开始，延迟 2s
[B] 开始，延迟 1s
[C] 开始，延迟 3s
[B] 完成
[A] 完成
[C] 完成

结果：['A', 'B', 'C']
总耗时：3.00 秒（非 6 秒）
```

### 4.2 asyncio.gather()

**语法：**

```python
results = await asyncio.gather(*aws, return_exceptions=False)
```

**参数：**

- `*aws`：一个或多个协程、Task 或 Future；传入裸协程时自动包装为 Task
- `return_exceptions`：
  - `False`（默认）：任意一个抛出异常时立即向调用方传播，其余任务**不会**被自动取消
  - `True`：将异常作为普通结果收集到返回列表，不中断其他任务

`asyncio.gather(*coros_or_tasks)` 并发运行多个协程或任务，**按照传入顺序返回结果列表**（与完成顺序无关）。

```python
import asyncio

async def fetch(url_id, delay):
    await asyncio.sleep(delay)
    return f"url_{url_id} 的响应"

async def main():
    # 同时发起 3 个"请求"
    results = await asyncio.gather(
        fetch(1, 3),
        fetch(2, 1),
        fetch(3, 2),
    )
    # 结果顺序与参数顺序一致，而非完成顺序
    for r in results:
        print(r)

asyncio.run(main())
```

运行结果：

```
url_1 的响应
url_2 的响应
url_3 的响应
```

### 4.3 asyncio.wait()

**语法：**

```python
done, pending = await asyncio.wait(aws, *, timeout=None, return_when=asyncio.ALL_COMPLETED)
```

**参数：**

- `aws`：Task 或 Future 的集合；**不接受裸协程**，需先用 `create_task()` 包装
- `timeout`：最长等待秒数；超时后直接返回当前 `done` / `pending`，未完成任务**不会**被取消；默认 `None`（无限等待）
- `return_when`：返回时机，枚举值：
  - `asyncio.ALL_COMPLETED`（默认）：全部完成（或抛出异常）后返回
  - `asyncio.FIRST_COMPLETED`：第一个完成或取消后立即返回
  - `asyncio.FIRST_EXCEPTION`：第一个抛出异常后返回；若无异常等同于 `ALL_COMPLETED`

与 `gather()` 的关键区别：返回 `(done, pending)` 两个集合，让你可以分别处理已完成和仍在运行的任务，也不会自动传播异常。

```python
import asyncio

async def task(name, delay):
    await asyncio.sleep(delay)
    return f"{name} done"

async def main():
    tasks = {
        asyncio.create_task(task("fast", 1), name="fast"),
        asyncio.create_task(task("medium", 2), name="medium"),
        asyncio.create_task(task("slow", 3), name="slow"),
    }

    done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)

    print("已完成：")
    for t in done:
        print(f"  {t.get_name()}: {t.result()}")

    print("未完成：")
    for t in pending:
        print(f"  {t.get_name()}")
        t.cancel()

asyncio.run(main())
```

运行结果：

```
已完成：
  fast: fast done
未完成：
  medium
  slow
```

### 4.4 asyncio.TaskGroup（Python 3.11+）

**语法：**

```python
async with asyncio.TaskGroup() as tg:
    task = tg.create_task(coro, *, name=None, context=None)
```

**参数：**

- `tg.create_task()` 参数与 `asyncio.create_task()` 相同（`coro`、`name`、`context`）
- 退出 `async with` 块时自动等待组内所有任务完成；任意任务抛出异常则立即取消其余任务，所有异常汇总为 `ExceptionGroup` 向外传播

```python
import asyncio

async def step(name, delay, fail=False):
    await asyncio.sleep(delay)
    if fail:
        raise ValueError(f"{name} 出错了")
    print(f"{name} 完成")
    return name

async def main():
    try:
        async with asyncio.TaskGroup() as tg:
            t1 = tg.create_task(step("任务1", 1))
            t2 = tg.create_task(step("任务2", 0.5, fail=True))
            t3 = tg.create_task(step("任务3", 2))
    except* ValueError as eg:
        print(f"捕获到异常组：{eg.exceptions}")

asyncio.run(main())
```

运行结果：

```
捕获到异常组：(ValueError('任务2 出错了'),)
```

> `except*` 是 Python 3.11 引入的异常组捕获语法，配合 `TaskGroup` 使用。`TaskGroup` 推荐作为 `gather()` 的现代替代品，错误处理更清晰。

### 4.5 四种方式对比与选型

| | `create_task()` | `gather()` | `wait()` | `TaskGroup` |
|--|----------------|------------|----------|-------------|
| **Python 版本** | 3.7+ | 3.7+ | 3.7+ | 3.11+ |
| **返回值** | 单个 `Task` 对象 | 按入参顺序的结果列表 | `(done, pending)` 两个集合 | 通过各 task 对象获取 |
| **结果顺序** | 不保证 | 与入参顺序一致 | 不保证 | 不保证 |
| **异常处理** | 需手动 `await task` | 默认立即传播；`return_exceptions=True` 可收集 | 不自动传播，需手动检查 | 兄弟任务自动取消，`ExceptionGroup` 统一抛出 |
| **部分完成控制** | ❌ | ❌ | ✅（`FIRST_COMPLETED`） | ❌ |
| **自动取消兄弟任务** | ❌ | ❌ | ❌ | ✅ |
| **典型用途** | 后台任务、fire-and-forget | 并发请求、需要有序结果 | 竞速（取最快结果）、超时降级 | 结构化并发、任一失败全部回滚 |

**选型建议：**

- **需要有序结果、任务数固定** → 用 `gather()`，一行代码搞定，结果与入参顺序对齐。
- **只需拿最快那个结果**（竞速），或想在等待过程中做其他事 → 用 `wait(FIRST_COMPLETED)`，取到结果后手动 `cancel()` 剩余任务。
- **Python 3.11+，任一子任务失败应让整批任务回滚** → 用 `TaskGroup`，错误边界清晰，推荐作为 `gather()` 的现代替代。
- **长期后台任务**（不需要立刻等待其完成） → 用 `create_task()` 提交后继续执行，在合适时机再 `await` 或 `cancel()`。

```python
# 竞速示例：取最快完成的结果，其余取消
import asyncio

async def race(*coros):
    tasks = {asyncio.create_task(c) for c in coros}
    done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    for t in pending:
        t.cancel()
    return next(iter(done)).result()

async def main():
    result = await race(
        asyncio.sleep(3, result="慢"),
        asyncio.sleep(1, result="快"),
        asyncio.sleep(2, result="中"),
    )
    print(f"最先完成：{result}")

asyncio.run(main())
```

运行结果：

```
最先完成：快
```



## 五、超时与取消

### 5.1 asyncio.timeout()（Python 3.11+）

**语法：**

```python
# Python 3.11+
async with asyncio.timeout(delay):
    ...

# Python 3.7+（兼容写法）
result = await asyncio.wait_for(aw, timeout)
```

**参数：**

- `delay` / `timeout`：超时秒数，浮点数；`None` 表示不设超时上限
- 超时后：
  - `asyncio.timeout` 抛出内置 `TimeoutError`
  - `asyncio.wait_for` 抛出 `asyncio.TimeoutError`（`TimeoutError` 的子类）；被等待的任务会被自动取消

```python
import asyncio

async def slow_operation():
    print("开始耗时操作...")
    await asyncio.sleep(5)
    return "完成"

async def main():
    # 方式一：asyncio.timeout() 上下文管理器（推荐，3.11+）
    try:
        async with asyncio.timeout(2):
            result = await slow_operation()
    except TimeoutError:
        print("操作超时（asyncio.timeout）")

    # 方式二：asyncio.wait_for()（兼容 3.7+）
    try:
        result = await asyncio.wait_for(slow_operation(), timeout=2)
    except asyncio.TimeoutError:
        print("操作超时（wait_for）")

asyncio.run(main())
```

运行结果：

```
开始耗时操作...
操作超时（asyncio.timeout）
开始耗时操作...
操作超时（wait_for）
```

### 5.2 Task 取消

**语法：**

```python
task.cancel(msg=None)
await task
task.cancelled()
```

**参数：**

- `task.cancel(msg)` — 向任务投递取消请求：
  - `msg`：附加到 `CancelledError` 的消息字符串（Python 3.9+），默认 `None`
  - 返回 `True` 表示请求已成功投递（任务尚未完成）；`False` 表示任务已完成，取消无效
- `await task` — 等待任务真正结束并重新抛出 `CancelledError`；应始终与 `task.cancel()` 成对使用
- `task.cancelled()` — 任务被成功取消后返回 `True`

```python
import asyncio

async def long_task():
    try:
        print("长任务：开始")
        await asyncio.sleep(10)
        print("长任务：完成")
    except asyncio.CancelledError:
        print("长任务：被取消，执行清理...")
        raise  # 必须重新抛出，让取消机制正常工作

async def main():
    task = asyncio.create_task(long_task())
    await asyncio.sleep(1)
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        print("主函数：确认任务已取消")

asyncio.run(main())
```

运行结果：

```
长任务：开始
长任务：被取消，执行清理...
主函数：确认任务已取消
```

> `task.cancel()` 只是向事件循环**投递一个取消请求**，调用后立即返回，任务并未真正停止。紧随其后的 `await task` 有三个作用：
> 1. 将控制权交还事件循环，让它把 `CancelledError` 注入任务；
> 2. 等待任务的清理代码（`except CancelledError` 块）执行完毕；
> 3. 确认取消结果——若任务捕获了 `CancelledError` 但未重新 `raise`，`await task` 会正常返回而非抛出异常，表明取消被拒绝。
>
> 因此 `task.cancel()` 与 `await task` 应始终成对使用：前者发出信号，后者等待确认。

> 捕获 `CancelledError` 后**必须重新 `raise`**，否则取消操作不会传播，任务会被认为正常完成。

**取消对外部 I/O 的局限性**

`task.cancel()` 的本质是在下一个 `await` 处注入 `CancelledError`，同时关闭本地 socket 连接。但它**无法撤回已经发出的请求**：

```
客户端                          服务端
  │──── POST /api/pay ─────────►│
  │                              │（服务端开始处理）
  │  task.cancel()               │
  │  本地 socket 关闭 ◄──────────│
  │                              │（服务端继续处理，
  │                              │  支付可能仍然成功）
```

| 取消后的实际行为 | 说明 |
|---|---|
| `await` 之后的代码 | 不会执行 |
| 本地 socket | 已关闭 / 中止 |
| 已发送到服务端的字节 | 服务端照常处理 |
| 服务端的副作用 | 无法通过取消回滚 |

对于有副作用的操作（支付、写入、发送邮件），取消只保证**本地协程停止等待**，不保证服务端回滚。需要服务端配合幂等设计或补偿事务才能真正"撤销"。



## 六、同步原语

### 6.1 asyncio.Lock

**语法：**

```python
lock = asyncio.Lock()

async with lock:         # 推荐：自动 acquire / release
    ...

await lock.acquire()     # 手动获取；锁被持有时阻塞
lock.release()           # 手动释放；未持有时抛出 RuntimeError
lock.locked()            # 返回锁当前是否被持有（bool）
```

**参数：** 构造函数无参数。

`Lock` 保证同一时刻只有一个协程持有锁，用于保护共享资源。

```python
import asyncio

counter = 0
lock = asyncio.Lock()

async def increment(name, n):
    global counter
    for _ in range(n):
        async with lock:
            current = counter
            await asyncio.sleep(0)   # 模拟读写间隙
            counter = current + 1
    print(f"{name} 完成，当前 counter = {counter}")

async def main():
    await asyncio.gather(
        increment("协程A", 5),
        increment("协程B", 5),
        increment("协程C", 5),
    )
    print(f"最终 counter = {counter}（期望 15）")

asyncio.run(main())
```

运行结果：

```
协程A 完成，当前 counter = 13
协程B 完成，当前 counter = 14
协程C 完成，当前 counter = 15
最终 counter = 15（期望 15）
```

> 去掉 `lock` 后由于 `await asyncio.sleep(0)` 让出控制权，三个协程会出现竞态条件，最终 `counter` 可能小于 15。

### 6.2 asyncio.Semaphore

**语法：**

```python
sem = asyncio.Semaphore(value=1)

async with sem:
    ...
```

**参数：**

- `value`：内部计数器初始值，即最大并发数，默认 `1`（等同于 `Lock`）；每次 `acquire` 计数 -1，`release` 计数 +1，计数为 0 时 `acquire` 阻塞

`Semaphore` 限制**同时运行的协程数量**，常用于限制并发连接数、API 调用频率等场景。

```python
import asyncio
import time

sem = asyncio.Semaphore(3)  # 最多同时 3 个并发

async def limited_task(name):
    async with sem:
        print(f"[{time.strftime('%H:%M:%S')}] {name} 开始执行")
        await asyncio.sleep(1)
        print(f"[{time.strftime('%H:%M:%S')}] {name} 执行完毕")

async def main():
    tasks = [limited_task(f"任务{i}") for i in range(7)]
    await asyncio.gather(*tasks)

asyncio.run(main())
```

运行结果（7 个任务，每批最多 3 个并发）：

```
[HH:MM:SS] 任务0 开始执行
[HH:MM:SS] 任务1 开始执行
[HH:MM:SS] 任务2 开始执行
[HH:MM:SS] 任务0 执行完毕
[HH:MM:SS] 任务1 执行完毕
[HH:MM:SS] 任务2 执行完毕
[HH:MM:SS] 任务3 开始执行
[HH:MM:SS] 任务4 开始执行
[HH:MM:SS] 任务5 开始执行
[HH:MM:SS] 任务3 执行完毕
[HH:MM:SS] 任务4 执行完毕
[HH:MM:SS] 任务5 执行完毕
[HH:MM:SS] 任务6 开始执行
[HH:MM:SS] 任务6 执行完毕
```

### 6.3 asyncio.Event

**语法：**

```python
event = asyncio.Event()

event.set()            # 将内部标志置为 True，唤醒所有在 wait() 中阻塞的协程
event.clear()          # 将内部标志重置为 False
await event.wait()     # 标志为 True 时立即返回；否则阻塞直到被 set()
event.is_set()         # 返回内部标志当前值（bool）
```

**参数：** 构造函数无参数；内部标志初始为 `False`。

`Event` 用于协程间的**事件通知**：一个协程等待事件发生，另一个协程在条件满足时触发事件。

```python
import asyncio

event = asyncio.Event()

async def producer():
    print("生产者：准备数据中...")
    await asyncio.sleep(2)
    print("生产者：数据准备完毕，发出信号")
    event.set()

async def consumer(name):
    print(f"{name}：等待数据...")
    await event.wait()
    print(f"{name}：收到信号，开始处理")

async def main():
    await asyncio.gather(
        producer(),
        consumer("消费者A"),
        consumer("消费者B"),
    )

asyncio.run(main())
```

运行结果：

```
生产者：准备数据中...
消费者A：等待数据...
消费者B：等待数据...
生产者：数据准备完毕，发出信号
消费者A：收到信号，开始处理
消费者B：收到信号，开始处理
```

### 6.4 asyncio.Queue

**语法：**

```python
queue = asyncio.Queue(maxsize=0)

await queue.put(item)      # 队满时阻塞，直到有空位
queue.put_nowait(item)     # 队满时立即抛出 asyncio.QueueFull
item = await queue.get()   # 队空时阻塞，直到有元素
queue.task_done()          # 标记当前元素已处理，需与 join() 配合
await queue.join()         # 阻塞直到队列中所有元素都被 task_done() 确认
queue.qsize()              # 返回当前队列中的元素数量
queue.empty()              # 队列为空返回 True
queue.full()               # 队列已满返回 True（maxsize > 0 时有效）
```

**参数：**

- `maxsize`：队列最大容量，默认 `0`（无限制）；大于 `0` 时队满会使 `put()` 阻塞，可用于实现背压

`Queue` 实现协程间的**生产者-消费者**模式，支持背压（通过 `maxsize` 限制队列长度）。

```python
import asyncio

async def producer(queue, items):
    for item in items:
        await asyncio.sleep(0.3)
        await queue.put(item)
        print(f"生产：{item}")
    await queue.put(None)  # 哨兵值，通知消费者结束

async def consumer(queue, name):
    while True:
        item = await queue.get()
        if item is None:
            queue.task_done()
            break
        print(f"{name} 消费：{item}")
        await asyncio.sleep(0.5)
        queue.task_done()

async def main():
    queue = asyncio.Queue(maxsize=3)
    await asyncio.gather(
        producer(queue, ["苹果", "香蕉", "橙子", "葡萄", "芒果"]),
        consumer(queue, "消费者"),
    )
    print("队列处理完毕")

asyncio.run(main())
```

运行结果：

```
生产：苹果
消费者 消费：苹果
生产：香蕉
消费者 消费：香蕉
生产：橙子
生产：葡萄
消费者 消费：橙子
生产：芒果
消费者 消费：葡萄
消费者 消费：芒果
队列处理完毕
```



## 七、网络 I/O（Streams API）

`asyncio.streams` 提供高级别的异步网络 I/O，基于 `StreamReader` / `StreamWriter` 抽象 TCP 连接。

### 7.1 TCP 服务端

**语法：**

```python
server = await asyncio.start_server(client_connected_cb, host, port, **kwds)
async with server:
    await server.serve_forever()
```

**参数：**

- `client_connected_cb`：每次新连接时调用的回调，签名为 `async def cb(reader: StreamReader, writer: StreamWriter)`
- `host`：监听地址字符串；`None` 表示监听所有接口；可传列表同时监听多个地址
- `port`：监听端口号（整数）
- `server.serve_forever()`：持续接受新连接直到被取消或调用 `server.close()`

```python
# 服务端核心逻辑
async def handle_client(reader, writer):
    data = await reader.read(1024)
    writer.write(f"Echo: {data.decode()}".encode())
    await writer.drain()
    writer.close()
    await writer.wait_closed()

server = await asyncio.start_server(handle_client, '127.0.0.1', 8888)
async with server:
    await server.serve_forever()
```

### 7.2 TCP 客户端

**语法：**

```python
reader, writer = await asyncio.open_connection(host, port, **kwds)
```

**参数：**

- `host`：目标主机名或 IP 地址字符串
- `port`：目标端口号（整数）
- 返回 `(StreamReader, StreamWriter)` 元组：
  - `await reader.read(n)`：读取至多 `n` 字节；`n=-1` 读到 EOF
  - `await reader.readline()`：读取一行（含 `\n`）
  - `writer.write(data)`：将数据写入发送缓冲区（非阻塞）
  - `await writer.drain()`：等待缓冲区刷新至底层 socket，防止内存无限增长
  - `writer.close()` + `await writer.wait_closed()`：关闭连接并等待完全释放

```python
# 客户端核心逻辑（需要服务端已在运行）
reader, writer = await asyncio.open_connection('127.0.0.1', 8888)
writer.write(b"Hello")
await writer.drain()
data = await reader.read(1024)
writer.close()
await writer.wait_closed()
```

**完整可运行示例**

客户端和服务端都依赖对方，无法单独执行。下面的示例在同一个事件循环内同时启动两者，可直接运行：

```python
import asyncio

async def handle_client(reader, writer):
    addr = writer.get_extra_info('peername')
    print(f"[服务端] 客户端连接：{addr}")
    data = await reader.read(1024)
    message = data.decode()
    print(f"[服务端] 收到：{message!r}")
    writer.write(f"Echo: {message}".encode())
    await writer.drain()
    writer.close()
    await writer.wait_closed()
    print("[服务端] 连接关闭")

async def tcp_client():
    reader, writer = await asyncio.open_connection('127.0.0.1', 8888)
    message = "Hello, asyncio Streams!"
    print(f"[客户端] 发送：{message!r}")
    writer.write(message.encode())
    await writer.drain()
    data = await reader.read(1024)
    print(f"[客户端] 收到回显：{data.decode()!r}")
    writer.close()
    await writer.wait_closed()

async def main():
    # 先启动服务端，再在同一事件循环中执行客户端
    server = await asyncio.start_server(handle_client, '127.0.0.1', 8888)
    async with server:
        await tcp_client()

asyncio.run(main())
```

运行结果：

```
[服务端] 客户端连接：('127.0.0.1', 55034)
[客户端] 发送：'Hello, asyncio Streams!'
[服务端] 收到：'Hello, asyncio Streams!'
[服务端] 连接关闭
[客户端] 收到回显：'Echo: Hello, asyncio Streams!'
```

> `await writer.drain()` 在 `write()` 之后调用，用于等待写缓冲区清空，避免内存无限增长。`writer.close()` 后必须 `await writer.wait_closed()` 才能确保连接完全关闭。



## 八、asyncio vs 多线程 vs 多进程

### 8.1 核心对比

| | asyncio | threading | multiprocessing |
|--|---------|-----------|----------------|
| **并发模型** | 协程（单线程） | 系统线程 | 独立进程 |
| **GIL 影响** | 无（单线程） | 受限（I/O 期间释放） | 无（独立进程） |
| **内存开销** | 极低（协程约几 KB） | 中（每线程约 8 MB） | 高（进程独立内存） |
| **适用场景** | 大量 I/O 并发 | I/O + 遗留同步库 | CPU 密集型计算 |
| **上下文切换** | 主动让出（`await`） | 操作系统调度 | 操作系统调度 |
| **调试难度** | 中 | 高（竞态、死锁） | 中 |

### 8.2 如何选择

**用 asyncio：**
- 需要管理大量并发连接（如 HTTP 服务器、WebSocket、数据库连接池）
- 任务瓶颈在 I/O 等待，而非 CPU 计算
- 使用支持 asyncio 的库（`aiohttp`、`asyncpg`、`aiofiles`）

**用 threading：**
- 调用不支持 asyncio 的同步第三方库
- 已有大量同步代码，迁移成本高
- I/O 并发数量较少（几十个线程以内）

**用 multiprocessing：**
- 图像/视频处理、数值计算、机器学习推理等 CPU 密集场景
- 需要绕过 GIL 充分利用多核 CPU

```python
# asyncio + ProcessPoolExecutor：在 asyncio 中运行 CPU 密集任务
import asyncio
from concurrent.futures import ProcessPoolExecutor

def cpu_bound(n):
    return sum(i * i for i in range(n))

async def main():
    loop = asyncio.get_running_loop()
    with ProcessPoolExecutor() as pool:
        # 在进程池中运行，不阻塞事件循环
        result = await loop.run_in_executor(pool, cpu_bound, 10_000_000)
    print(f"计算结果：{result}")

if __name__ == "__main__":
    asyncio.run(main())
```

运行结果：

```
计算结果：333333283333335000000
```
