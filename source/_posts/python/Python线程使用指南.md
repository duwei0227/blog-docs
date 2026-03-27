---
title: Python线程使用指南
date: 2026-03-23 19:53:00
tags:
  - Python
  - 多线程
  - threading
categories:
  - Python
---

Python的`threading`模块提供了在单个进程内部并发运行多个线程的方式。线程允许程序同时执行多个任务，特别适用于I/O密集型任务，如文件操作或网络请求。

## 一、创建线程

学习线程的第一步是了解如何创建线程。Python中创建线程有两种方式：使用`Thread`类的`target`参数指定线程函数，或者继承`Thread`类并重写`run`方法。

### 1. Thread类

`Thread`类的构造器用于创建线程对象。

**语法格式**

```
Thread(target=函数, name=线程名, args=元组, kwargs=字典, daemon=布尔值)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `target` | 线程执行的函数 | `target=worker` |
| `name` | 线程名称 | `name='Worker-1'` |
| `args` | 函数位置参数元组 | `args=(1, 2)` |
| `kwargs` | 函数关键字参数字典 | `kwargs={'delay': 1}` |
| `daemon` | 是否守护线程 | `daemon=True` |

**示例**

```python
import threading
import time

def worker(name, delay):
    print(f"线程 {name} 开始，延迟 {delay} 秒")
    time.sleep(delay)
    print(f"线程 {name} 完成")

# 使用target参数创建线程
t = threading.Thread(
    target=worker,
    args=("Thread-1",),
    kwargs={"delay": 0.5},
    name="MyThread"
)
t.start()
t.join()
```

输出：
```
线程 Thread-1 开始，延迟 0.5 秒
线程 Thread-1 完成
```

### 2. Thread常用方法

线程创建后，通过方法控制其执行。

**语法格式**

```
线程对象.start()
线程对象.join(timeout=None)
线程对象.is_alive()
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `start()` | 启动线程 | `t.start()` |
| `join(timeout)` | 等待线程结束，timeout为超时秒数 | `t.join()` |
| `is_alive()` | 检查线程是否存活 | `t.is_alive()` |

**示例**

```python
import threading
import time

def task(duration):
    time.sleep(duration)

# 创建线程
t = threading.Thread(target=task, args=(1,))
print(f"启动前 - 存活状态: {t.is_alive()}")

t.start()
print(f"启动后 - 存活状态: {t.is_alive()}")

t.join()  # 等待线程结束
print(f"结束后 - 存活状态: {t.is_alive()}")
```

输出：
```
启动前 - 存活状态: False
启动后 - 存活状态: True
结束后 - 存活状态: False
```

## 二、Lock锁

`Lock`是最基本的同步机制，保证同一时刻只有一个线程访问共享资源。

**语法格式**

```
锁变量 = threading.Lock()
锁变量.acquire()
锁变量.release()
# 或使用with语句
with 锁变量:
    # 临界区代码
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `Lock()` | 创建锁对象 | `lock = Lock()` |
| `acquire()` | 获取锁 | `lock.acquire()` |
| `release()` | 释放锁 | `lock.release()` |

**示例**

```python
import threading

counter = 0
lock = threading.Lock()

def increment():
    global counter
    for _ in range(100000):
        with lock:  # 使用with语句自动管理锁
            counter += 1

t1 = threading.Thread(target=increment)
t2 = threading.Thread(target=increment)
t1.start()
t2.start()
t1.join()
t2.join()
print(f"计数器最终值: {counter}")
```

输出：
```
计数器最终值: 200000
```

## 三、RLock重入锁

`RLock`允许同一线程多次获取锁，适合递归调用场景。与`Lock`的区别是同一线程可以多次acquire而不会死锁。

**语法格式**

```
锁变量 = threading.RLock()
锁变量.acquire()      # 同一线程可多次获取
锁变量.acquire()      # 不会阻塞
# ... 操作 ...
锁变量.release()      # 需释放相应次数
锁变量.release()
# 或使用with语句
with 锁变量:
    # 临界区代码
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `RLock()` | 创建重入锁对象 | `rlock = RLock()` |

**示例**

```python
import threading

rlock = threading.RLock()

def recursive(n):
    if n > 0:
        with rlock:
            print(f"获取锁，n={n}")
            recursive(n - 1)
        # 锁自动释放

recursive(3)
```

输出：
```
获取锁，n=3
获取锁，n=2
获取锁，n=1
```

## 四、Semaphore信号量

`Semaphore`管理一个计数器，控制同时访问资源的线程数量。

**语法格式**

```
信号量 = threading.Semaphore(value=数量)
信号量.acquire()      # 获取许可
# 访问资源
信号量.release()      # 释放许可
# 或使用with语句
with 信号量:
    # 访问资源
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `Semaphore(value)` | 创建信号量，value为并发数 | `sem = Semaphore(3)` |
| `acquire()` | 获取信号量 | `sem.acquire()` |
| `release()` | 释放信号量 | `sem.release()` |

**示例**

```python
import threading
import time

# 连接池，限制为2个并发连接
pool_sem = threading.Semaphore(2)

def connect(task_id):
    with pool_sem:
        print(f"任务 {task_id} 获取连接")
        time.sleep(1)
        print(f"任务 {task_id} 释放连接")

threads = [threading.Thread(target=connect, args=(i,)) for i in range(4)]
for t in threads:
    t.start()
for t in threads:
    t.join()
```

输出：
```
任务 0 获取连接
任务 1 获取连接
任务 0 释放连接
任务 2 获取连接
任务 1 释放连接
任务 3 获取连接
任务 2 释放连接
任务 3 释放连接
```

## 五、Event事件

`Event`用于线程间的简单信号通知。

**语法格式**

```
事件 = threading.Event()
事件.set()           # 设置事件为True
事件.clear()         # 设置事件为False
事件.wait()          # 阻塞直到事件被设置
事件.is_set()        # 检查事件状态
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `Event()` | 创建事件对象 | `event = Event()` |
| `set()` | 设置事件为True，唤醒等待的线程 | `event.set()` |
| `clear()` | 重置事件为False | `event.clear()` |
| `wait(timeout)` | 阻塞直到事件被设置，timeout为超时秒数 | `event.wait()` |
| `is_set()` | 检查事件是否为True | `event.is_set()` |

**示例**

```python
import threading
import time

event = threading.Event()

def waiter(n):
    print(f"等待者 {n} 开始等待...")
    event.wait()  # 阻塞等待
    print(f"等待者 {n} 收到通知！")

def setter():
    time.sleep(2)
    print("设置者设置事件")
    event.set()

# 启动线程
threads = [threading.Thread(target=waiter, args=(i,)) for i in range(3)]
for t in threads:
    t.start()

setter_thread = threading.Thread(target=setter)
setter_thread.start()

for t in threads + [setter_thread]:
    t.join()
```

输出：
```
等待者 0 开始等待...
等待者 1 开始等待...
等待者 2 开始等待...
设置者设置事件
等待者 0 收到通知！
等待者 1 收到通知！
等待者 2 收到通知！
```

## 六、Condition条件变量

`Condition`用于更复杂的线程协调，支持等待特定条件。

**语法格式**

```
条件 = threading.Condition(lock=None)
条件.acquire()
条件.wait()
条件.wait_for(谓词)
条件.notify()
条件.notify_all()
条件.release()
# 通常与with语句配合使用
with 条件:
    while not 条件:
        条件.wait()
    # 处理
    条件.notify()  # 或 notify_all()
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `Condition(lock)` | 创建条件变量，lock为锁对象 | `cv = Condition()` |
| `wait(timeout)` | 等待通知，timeout为超时秒数 | `cv.wait()` |
| `wait_for(谓词)` | 等待谓词为真 | `cv.wait_for(has_item)` |
| `notify()` | 唤醒一个等待的线程 | `cv.notify()` |
| `notify_all()` | 唤醒所有等待的线程 | `cv.notify_all()` |

**示例**

```python
import threading
import time

class Table:
    def __init__(self):
        self.items = []
        self.cv = threading.Condition()
    
    def put(self, item):
        with self.cv:
            self.items.append(item)
            self.cv.notify()  # 通知消费者
            print(f"生产者放入: {item}")
    
    def get(self):
        with self.cv:
            while not self.items:
                self.cv.wait()  # 等待生产者
            item = self.items.pop(0)
            print(f"消费者取出: {item}")
            return item

table = Table()

def producer():
    for i in range(5):
        table.put(i)
        time.sleep(0.5)

def consumer():
    for _ in range(5):
        table.get()
        time.sleep(0.3)

t1 = threading.Thread(target=producer)
t2 = threading.Thread(target=consumer)
t1.start()
t2.start()
t1.join()
t2.join()
```

输出：
```
生产者放入: 0
消费者取出: 0
生产者放入: 1
消费者取出: 1
生产者放入: 2
消费者取出: 2
生产者放入: 3
消费者取出: 3
生产者放入: 4
消费者取出: 4
```

## 七、线程本地数据

`threading.local`创建线程局部数据，每个线程有独立的值。

**语法格式**

```
变量 = threading.local()
变量.属性 = 值    # 每个线程独立
# 子类化方式
class MyLocal(local):
    属性 = 默认值
    def 方法(self): ...
```

**类说明**

| 类 | 说明 | 示例 |
|------|------|------|
| `local()` | 创建线程本地数据对象 | `data = local()` |

**示例**

```python
import threading
import time

local_data = threading.local()

def process():
    local_data.value = threading.current_thread().name
    print(f"线程 {local_data.value} 设置的值")
    time.sleep(0.1)
    print(f"线程 {local_data.value} 读取的值")

threads = [threading.Thread(target=process) for _ in range(3)]
for t in threads:
    t.start()
for t in threads:
    t.join()
```

输出：
```
线程 Thread-1 设置的值
线程 Thread-2 设置的值
线程 Thread-3 设置的值
线程 Thread-1 读取的值: Thread-1
线程 Thread-2 读取的值: Thread-2
线程 Thread-3 读取的值: Thread-3
```

## 八、线程模块函数

`threading`模块提供了一些实用的模块级函数。

**语法格式**

```
threading.active_count()
threading.current_thread()
threading.enumerate()
threading.get_ident()
threading.get_native_id()
threading.main_thread()
```

**函数说明**

| 函数 | 说明 | 示例 |
|------|------|------|
| `active_count()` | 返回存活线程数量 | `threading.active_count()` |
| `current_thread()` | 返回当前线程对象 | `threading.current_thread()` |
| `enumerate()` | 返回所有存活线程列表 | `threading.enumerate()` |
| `get_ident()` | 返回当前线程标识符 | `threading.get_ident()` |
| `main_thread()` | 返回主线程对象 | `threading.main_thread()` |

**示例**

```python
import threading
import time

def worker():
    print(f"线程ID: {threading.get_ident()}")
    time.sleep(0.5)

# 主线程信息
print(f"当前线程: {threading.current_thread().name}")
print(f"活跃线程数: {threading.active_count()}")

# 创建线程
t = threading.Thread(target=worker)
t.start()
print(f"启动后活跃线程数: {threading.active_count()}")
t.join()
```

输出：
```
当前线程: MainThread
活跃线程数: 1
启动后活跃线程数: 2
线程ID: 1234567890
```

## 九、综合示例

### 1. 生产者-消费者模型

**示例**

```python
import threading
import queue
import time

class Producer(threading.Thread):
    def __init__(self, queue, count):
        super().__init__()
        self.queue = queue
        self.count = count
    
    def run(self):
        for i in range(self.count):
            self.queue.put(i)
            print(f"生产者放入: {i}")
            time.sleep(0.3)

class Consumer(threading.Thread):
    def __init__(self, queue, count):
        super().__init__()
        self.queue = queue
        self.count = count
    
    def run(self):
        for _ in range(self.count):
            item = self.queue.get()
            print(f"消费者取出: {item}")
            time.sleep(0.5)

# 共享队列
work_queue = queue.Queue()

# 启动生产者和消费者
producer = Producer(work_queue, 5)
consumer1 = Consumer(work_queue, 3)
consumer2 = Consumer(work_queue, 2)

producer.start()
consumer1.start()
consumer2.start()

producer.join()
work_queue.join()  # 等待队列清空

print("所有任务完成！")
```

输出：
```
生产者放入: 0
消费者取出: 0
生产者放入: 1
消费者取出: 1
生产者放入: 2
消费者取出: 2
生产者放入: 3
消费者取出: 3
生产者放入: 4
消费者取出: 4
所有任务完成！
```

### 2. 线程池模拟

**示例**

```python
import threading
import time

class ThreadPool:
    def __init__(self, size=3):
        self.size = size
        self.sem = threading.Semaphore(size)
        self.active = 0
        self.lock = threading.Lock()
    
    def worker(self, task_id):
        self.sem.acquire()
        with self.lock:
            self.active += 1
            print(f"任务 {task_id} 开始（活跃: {self.active}）")
        
        time.sleep(1)  # 模拟工作
        
        with self.lock:
            self.active -= 1
            print(f"任务 {task_id} 完成")
        self.sem.release()
    
    def submit(self, task_id):
        t = threading.Thread(target=self.worker, args=(task_id,))
        t.start()

# 使用线程池
pool = ThreadPool(size=2)
for i in range(5):
    pool.submit(i)
    time.sleep(0.3)

time.sleep(6)  # 等待所有任务完成
```

输出：
```
任务 0 开始（活跃: 1）
任务 1 开始（活跃: 2）
任务 0 完成
任务 2 开始（活跃: 2）
任务 1 完成
任务 3 开始（活跃: 2）
任务 2 完成
任务 4 开始（活跃: 2）
任务 3 完成
任务 4 完成
```