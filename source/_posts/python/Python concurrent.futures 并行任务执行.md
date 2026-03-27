---
title: Python concurrent.futures 并行任务执行
date: 2026-03-24 08:23:00
tags:
  - Python
  - 并发
  - concurrent.futures
categories:
  - Python
---

`concurrent.futures` 是 Python 标准库中用于异步执行任务的高层级接口，提供了线程池和进程池两种并行执行方式。适用于 I/O 密集型任务（线程池）和 CPU 密集型任务（进程池）。

## 一、Executor 执行器

Executor 是抽象基类，提供了 submit()、map()、shutdown() 三个核心方法。

### 1.1 submit() 提交单个任务

**语法格式**

```
Executor.submit(fn, *args, **kwargs)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `fn` | 要执行的函数 | `pow` |
| `*args` | 位置参数 | `323, 1235` |
| `**kwargs` | 关键字参数 | `key=value` |

**返回值**：返回一个 Future 对象，代表异步执行的结果。

**示例**

```python
import concurrent.futures

def task(x, y):
    return x ** y

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
    future = executor.submit(task, 2, 10)
    print(f"结果: {future.result()}")

# 输出
# 结果: 1024
```

### 1.2 map() 并行映射

**语法格式**

```
Executor.map(fn, *iterables, timeout=None, chunksize=1)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `fn` | 要执行的函数 | `math.sqrt` |
| `*iterables` | 可迭代对象 | `[1, 4, 9]` |
| `timeout` | 超时秒数 | `30` |
| `chunksize` | 分块大小（仅进程池有效） | `10` |

**说明**：map() 会将 iterables 中的每个元素并行传给 fn 执行，返回迭代器。chunksize 参数仅对 ProcessPoolExecutor 有效，用于分块提交任务以提升性能。

**示例**

```python
import concurrent.futures
import math

numbers = [1, 4, 9, 16, 25]

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
    results = executor.map(math.sqrt, numbers)
    for num, result in zip(numbers, results):
        print(f"sqrt({num}) = {result}")

# 输出
# sqrt(1) = 1.0
# sqrt(4) = 2.0
# sqrt(9) = 3.0
# sqrt(16) = 4.0
# sqrt(25) = 5.0
```

### 1.3 shutdown() 关闭执行器

**语法格式**

```
Executor.shutdown(wait=True, *, cancel_futures=False)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `wait` | 是否等待任务完成 | `True` |
| `cancel_futures` | 是否取消未执行的任务 | `False` |

**说明**：释放执行器资源。使用 with 语句时会自动调用 shutdown()。

**示例**

```python
import concurrent.futures

def task(n):
    return n * 2

executor = concurrent.futures.ThreadPoolExecutor(max_workers=2)
future = executor.submit(task, 5)
print(future.result())

# 显式关闭
executor.shutdown(wait=True)
print("执行器已关闭")

# 输出
# 10
# 执行器已关闭
```

## 二、ThreadPoolExecutor 线程池

ThreadPoolExecutor 使用线程池异步执行任务，适用于 I/O 密集型操作（如网络请求、文件读写）。

### 2.1 构造函数

**语法格式**

```
ThreadPoolExecutor(max_workers=None, thread_name_prefix='', initializer=None, initargs=())
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `max_workers` | 最大线程数，默认为 min(32, cpu_count+4) | `4` |
| `thread_name_prefix` | 线程名称前缀 | `'worker'` |
| `initializer` | 初始化函数 | `init_func` |
| `initargs` | 初始化函数参数 | `(arg1,)` |

**说明**：max_workers 为 None 时，默认值为 min(32, (os.process_cpu_count() or 1) + 4)。

**示例**

```python
import concurrent.futures
import urllib.request

urls = [
    'https://httpbin.org/delay/1',
    'https://httpbin.org/delay/2',
    'https://httpbin.org/get'
]

def fetch_url(url):
    with urllib.request.urlopen(url, timeout=10) as response:
        return f"{url}: {response.status}"

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
    results = executor.map(fetch_url, urls)
    for result in results:
        print(result)

# 输出示例
# https://httpbin.org/delay/1: 200
# https://httpbin.org/delay/2: 200
# https://httpbin.org/get: 200
```

### 2.2 处理异常和结果

**语法格式**

```
as_completed(futures)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `futures` | Future 对象列表 | `[f1, f2, f3]` |

**说明**：as_completed() 返回迭代器，每当有 Future 完成时就产生该 Future，无论提交顺序如何。

**示例**

```python
import concurrent.futures
import urllib.request

urls = [
    'https://httpbin.org/delay/1',
    'https://httpbin.org/status/500',  # 会失败
    'https://httpbin.org/get'
]

def fetch_url(url):
    with urllib.request.urlopen(url, timeout=10) as response:
        return f"{url}: 成功"

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
    future_to_url = {executor.submit(fetch_url, url): url for url in urls}
    
    for future in concurrent.futures.as_completed(future_to_url):
        url = future_to_url[future]
        try:
            result = future.result()
            print(f"✅ {result}")
        except Exception as exc:
            print(f"❌ {url} 生成异常: {exc}")

# 输出示例
# ✅ https://httpbin.org/get: 成功
# ✅ https://httpbin.org/delay/1: 成功
# ❌ https://httpbin.org/status/500 生成异常: HTTPError: HTTP Error 500
```

## 三、ProcessPoolExecutor 进程池

ProcessPoolExecutor 使用进程池异步执行任务，可突破 GIL 限制，适用于 CPU 密集型操作。

### 3.1 构造函数

**语法格式**

```
ProcessPoolExecutor(max_workers=None, mp_context=None, initializer=None, initargs=(), max_tasks_per_child=None)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `max_workers` | 最大进程数，默认为 cpu_count() | `4` |
| `mp_context` | 进程启动上下文 | `multiprocessing.get_context('spawn')` |
| `initializer` | 初始化函数 | `init_func` |
| `initargs` | 初始化函数参数 | `(arg1,)` |
| `max_tasks_per_child` | 每个进程最大任务数 | `10` |

**说明**：max_tasks_per_child 用于限制工作进程的生命周期，避免内存泄漏。

**示例**

```python
import concurrent.futures
import math

def is_prime(n):
    if n < 2:
        return False
    if n == 2:
        return True
    if n % 2 == 0:
        return False
    sqrt_n = int(math.floor(math.sqrt(n)))
    for i in range(3, sqrt_n + 1, 2):
        if n % i == 0:
            return False
    return True

numbers = [104729, 104723, 104729, 99991, 100003]

with concurrent.futures.ProcessPoolExecutor(max_workers=4) as executor:
    results = executor.map(is_prime, numbers)
    for num, prime in zip(numbers, results):
        print(f"{num} 是素数: {prime}")

# 输出
# 104729 是素数: True
# 104723 是素数: True
# 104729 是素数: True
# 99991 是素数: False
# 100003 是素数: True
```

### 3.2 terminate_workers() 和 kill_workers()

**语法格式**

```
ProcessPoolExecutor.terminate_workers()
ProcessPoolExecutor.kill_workers()
```

**说明**：terminate_workers() 尝试优雅终止工作进程，kill_workers() 强制杀死所有工作进程。

**示例**

```python
import concurrent.futures
import time

def long_task(n):
    time.sleep(n)
    return n

with concurrent.futures.ProcessPoolExecutor(max_workers=2) as executor:
    futures = [executor.submit(long_task, i) for i in [10, 5, 3]]
    
    # 强制终止所有工作进程
    executor.kill_workers()
    
    print("工作进程已被终止")

# 输出
# 工作进程已被终止
```

## 四、Future 对象

Future 封装了异步执行的任务，通过 Executor.submit() 创建。

### 4.1 获取结果 result()

**语法格式**

```
Future.result(timeout=None)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `timeout` | 超时秒数，超时抛出 TimeoutError | `30` |

**示例**

```python
import concurrent.futures

def divide(a, b):
    return a / b

with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
    future = executor.submit(divide, 10, 2)
    
    try:
        result = future.result(timeout=5)
        print(f"结果: {result}")
    except concurrent.futures.TimeoutError:
        print("任务超时")

# 输出
# 结果: 5.0
```

### 4.2 检查状态 done()

**语法格式**

```
Future.done()
```

**说明**：返回 True 表示任务已完成（正常结束或被取消）。

**示例**

```python
import concurrent.futures
import time

def task():
    time.sleep(2)
    return "完成"

with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
    future = executor.submit(task)
    
    # 等待期间检查状态
    while not future.done():
        print("任务执行中...")
        time.sleep(0.5)
    
    print(f"任务状态: {future.done()}, 结果: {future.result()}")

# 输出
# 任务执行中...
# 任务执行中...
# 任务执行中...
# 任务执行中...
# 任务状态: True, 结果: 完成
```

### 4.3 取消任务 cancel()

**语法格式**

```
Future.cancel()
Future.cancelled()
```

**说明**：cancel() 尝试取消任务，返回 True 表示成功。cancelled() 返回任务是否被成功取消。

**示例**

```python
import concurrent.futures
import time

def slow_task():
    time.sleep(10)
    return "完成"

with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
    future = executor.submit(slow_task)
    
    # 尝试取消
    cancelled = future.cancel()
    print(f"取消{'成功' if cancelled else '失败'}")
    print(f"任务已被取消: {future.cancelled()}")

# 输出（任务未开始时被取消）
# 取消成功
# 任务已被取消: True
```

### 4.4 回调函数 add_done_callback()

**语法格式**

```
Future.add_done_callback(fn)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `fn` | 回调函数，接收 Future 作为唯一参数 | `my_callback` |

**说明**：当 Future 完成（正常结束、被取消或抛出异常）时调用回调函数。

**示例**

```python
import concurrent.futures

def task(x):
    if x < 0:
        raise ValueError("负数不能计算平方根")
    return x ** 0.5

def callback(future):
    try:
        result = future.result()
        print(f"✅ 成功: {result}")
    except Exception as e:
        print(f"❌ 失败: {e}")

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
    # 成功的任务
    f1 = executor.submit(task, 16)
    f1.add_done_callback(callback)
    
    # 失败的任务
    f2 = executor.submit(task, -4)
    f2.add_done_callback(callback)

# 输出
# ✅ 成功: 4.0
# ❌ 失败: 负数不能计算平方根
```

## 五、模块函数

### 5.1 as_completed() 迭代完成的 Future

**语法格式**

```
concurrent.futures.as_completed(fs, timeout=None)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `fs` | Future 可迭代对象 | `[f1, f2, f3]` |
| `timeout` | 超时秒数 | `30` |

**说明**：返回迭代器，按完成顺序产生 Future 对象。

**示例**

```python
import concurrent.futures
import time

def task(n):
    time.sleep(n)
    return f"任务{n}完成"

with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
    futures = [executor.submit(task, i) for i in [3, 1, 2]]
    
    for future in concurrent.futures.as_completed(futures):
        print(future.result())

# 输出（顺序可能不同）
# 任务1完成
# 任务2完成
# 任务3完成
```

### 5.2 wait() 等待 Future 完成

**语法格式**

```
concurrent.futures.wait(fs, timeout=None, return_when=ALL_COMPLETED)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `fs` | Future 可迭代对象 | `[f1, f2, f3]` |
| `timeout` | 超时秒数 | `30` |
| `return_when` | 返回时机 | `FIRST_COMPLETED` |

**return_when 常量说明**

| 常量 | 说明 |
|------|------|
| `FIRST_COMPLETED` | 任意一个 Future 完成时返回 |
| `FIRST_EXCEPTION` | 任意一个 Future 抛出异常时返回 |
| `ALL_COMPLETED` | 所有 Future 完成时返回 |

**示例**

```python
import concurrent.futures
import time

def task(n):
    time.sleep(n)
    return f"任务{n}"

with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
    futures = [executor.submit(task, i) for i in [5, 3, 1]]
    
    # 等待任意一个完成
    done, not_done = concurrent.futures.wait(
        futures, 
        timeout=2,
        return_when=concurrent.futures.FIRST_COMPLETED
    )
    
    print(f"已完成: {len(done)} 个")
    print(f"未完成: {len(not_done)} 个")
    
    for f in done:
        print(f.result())

# 输出
# 已完成: 1 个
# 未完成: 2 个
# 任务1
```

## 六、异常处理

### 6.1 CancelledError 取消异常

当 Future 被取消时获取结果会抛出 CancelledError。

**示例**

```python
import concurrent.futures
import time

def task():
    time.sleep(5)
    return "完成"

with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
    future = executor.submit(task)
    future.cancel()
    
    try:
        result = future.result()
    except concurrent.futures.CancelledError:
        print("任务已被取消")

# 输出
# 任务已被取消
```

### 6.2 BrokenExecutor 执行器异常

当执行器因工作线程/进程失败而中断时会抛出 BrokenExecutor 及其子类。

**示例**

```python
import concurrent.futures

def failing_task():
    raise ValueError("任务执行失败")

with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
    future = executor.submit(failing_task)
    
    try:
        result = future.result()
    except Exception as e:
        print(f"捕获异常: {type(e).__name__}: {e}")

# 输出
# 捕获异常: ValueError: 任务执行失败
```

### 6.3 TimeoutError 超时异常

当 Future.result() 超时时抛出。

**示例**

```python
import concurrent.futures
import time

def slow_task():
    time.sleep(10)
    return "完成"

with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
    future = executor.submit(slow_task)
    
    try:
        result = future.result(timeout=1)
    except concurrent.futures.TimeoutError:
        print("任务执行超时")

# 输出
# 任务执行超时
```

## 七、实战技巧

### 7.1 线程池 vs 进程池选择

| 场景 | 推荐 | 原因 |
|------|------|------|
| 网络请求、文件读写 | ThreadPoolExecutor | I/O 等待时线程可切换 |
| 数学计算、数据处理 | ProcessPoolExecutor | 突破 GIL，多核并行 |
| 混合型任务 | InterpreterPoolExecutor | 3.14+ 新增，真多核并行 |

### 7.2 使用 with 语句管理资源

**示例**

```python
import concurrent.futures

def task(n):
    return n * 2

# 推荐写法：自动管理资源
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    results = list(executor.map(task, range(10)))

print(results)

# 输出
# [0, 2, 4, 6, 8, 10, 12, 14, 16, 18]
```

### 7.3 避免死锁

ThreadPoolExecutor 中如果 Future 等待另一个 Future 的结果会导致死锁。

**错误示例**

```python
import concurrent.futures

def wait_on_future():
    f = executor.submit(lambda: 42)
    # 死锁：单个工作线程在等待自己
    return f.result()

executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)
f = executor.submit(wait_on_future)
# f.result() 会永远阻塞
```

**正确示例**

```python
import concurrent.futures

def compute():
    return 42

# 确保有足够的工作线程
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
    future = executor.submit(compute)
    result = future.result()
    print(f"结果: {result}")

# 输出
# 结果: 42
```
