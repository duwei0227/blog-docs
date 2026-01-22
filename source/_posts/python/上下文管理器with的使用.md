---
title: 上下文管理器with的使用
published: true
layout: post
date: 2026-01-22 19:00:00
permalink: /python/with.html
categories: [Python]
---

在介绍《文件操作》的时候，我们有使用`with`进行文件IO的管理，在这里我们专门介绍`with`是什么，如何定义自己的上下文。

在 Python 开发中，`with` 语句被称为**上下文管理器（Context Manager）**。它的核心作用是简化资源管理（如文件、数据库连接、锁等），确保无论代码执行过程中是否发生异常，资源都能被正确释放，从而避免内存泄漏或文件句柄未关闭等常见问题。



## 1. 为什么需要 `with`？

在不使用`with`的情况，为了确保资源的正确释放，我们通常使用 `try...finally` 来确保安全。

```python
f = open("data.txt", "w")
try:
    f.write("Hello")
finally:
    f.close()  # 无论是否报错，必须执行关闭操作
```

在使用`with`语法后，只需要简单的2行就可以实现相同的功能：

```python
with open("data.txt", "w") as f:
    f.write("Hello")
# 离开缩进块后，f.close() 会被自动调用
```



所以为什么需要呢？

* 简化代码语法，一次定义到处使用，不需要每个地方都增加`try...finally`进行资源的释放
* 避免`finally`子句的遗忘，导致资源未正确释放



## 2. 常用内置场景

### 2.1 文件操作

这是最常见的用法，自动处理文件关闭。

```
with open("data.txt", "r") as f:
    content = f.read()
    print(content) 
```

### 2.2 线程锁（Threading Lock）

自动处理锁的获取（acquire）和释放（release）。

```
import threading

lock = threading.Lock()
with lock:
    # 临界区代码
    pass 
```

### 2.3 数据库连接

许多数据库库（如 `sqlite3`）支持 `with` 自动提交事务或回滚。

```
import sqlite3

with sqlite3.connect("db.sqlite") as conn:
    conn.execute("INSERT INTO users VALUES ('Alice')")
    # 如果块内报错，事务会自动回滚；否则自动提交
```



## 3. `with` 的底层原理

`with` 语句依赖于**上下文管理器协议**，即对象必须实现以下两个特殊方法：

1. **`__enter__(self)`**:
   - 在进入 `with` 块前执行，完成资源的初始化准备。
   - 其返回值将赋值给 `as` 后面的变量。
2. **`__exit__(self, exc_type, exc_val, exc_tb)`**:
   - 在离开 `with` 块（或块内抛出异常）时执行，确保资源能够正确释放。
   - 参数包含异常类型、异常值和追踪信息。如果返回 `True`，异常会被“压制”（不再向上传播）。



## 4. 自定义上下文管理器

### 4.1 基于类的实现

```python
class MyTimer:
    def __enter__(self):
        print("计时开始...")
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        print("计时结束，清理资源。")
        if exc_type:
            print(f"异常类型：{exc_type} 异常值: {exc_val} 异常追踪: {exc_tb}")
        return False # 不压制异常

with MyTimer():
    print("执行业务逻辑，未抛出异常...")

print('\n--------------------------\n')

with MyTimer():
    print("执行业务逻辑，抛出异常...")
    raise ValueError("模拟异常")

```

输出：

```python
计时开始...
执行业务逻辑，未抛出异常...
计时结束，清理资源。

--------------------------

计时开始...
执行业务逻辑，抛出异常...
计时结束，清理资源。
异常类型：<class 'ValueError'> 异常值: 模拟异常 异常追踪: <traceback object at 0x7f886ebab140>
Traceback (most recent call last):
  File "/home/duwei/workspace/python/base-python/test.py", line 19, in <module>
    raise ValueError("模拟异常")
ValueError: 模拟异常
```



**with抑制异常的抛出：**

```python
class MyTimer:
    def __enter__(self):
        print("计时开始...")
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        print("计时结束，清理资源。")
        if exc_type:
            print(f"异常类型：{exc_type} 异常值: {exc_val} 异常追踪: {exc_tb}")
        return True # 压制异常


with MyTimer():
    print("异常信息不会抛出...")
    raise ValueError("这是一个测试异常")
```

当 `__exit__`返回`True`时，即使执行`with`发生异常也不会抛出异常中断程序执行。

```python
计时开始...
异常信息不会抛出...
计时结束，清理资源。
异常类型：<class 'ValueError'> 异常值: 这是一个测试异常 异常追踪: <traceback object at 0x7f6a6bca7180>
```



### 4.2 基于装饰器的实现

利用 `contextlib` 模块，可以使用生成器更简单地定义上下文管理器：

**使用`contextlib`模块时，一定要结合`try...finally`，确保资源即使在发生异常的情况下也能够正确释放**



**基本语法示例：**

*如果有使用 `except Exception`捕获所有基类异常，`with`中发生的异常会被抑制并不会向上层抛出*

```python
from contextlib import contextmanager

@contextmanager
def simple_with():
    try:
        print('类似于进入 __enter__')
        yield
        print('类似于进入 __exit__')
    except Exception as e:
        print(f"异常类型：{type(e)} 异常值: {e}")
    finally:
        print("清理资源。")

with simple_with():
    print("简单with语法")
    
# 输出
类似于进入 __enter__
简单with语法
类似于进入 __exit__
清理资源。
```



**无`try...finally`语句示例：**

如果在`with`语句内发生异常，资源的释放没有放在`finally`子句中，`yield`后边的代码不会执行，资源无法得到正确释放

```python
from contextlib import contextmanager

@contextmanager
def simple_with():
    print('类似于进入 __enter__')
    yield
    print('类似于进入 __exit__')

with simple_with():
    print("简单with语法")
    raise ValueError("这是一个异常")
```

输出，从输出结果不难看出，`yield`后边的语句并没有执行：

```python
类似于进入 __enter__
简单with语法
Traceback (most recent call last):
  File "/home/duwei/workspace/python/base-python/test.py", line 11, in <module>
    raise ValueError("这是一个异常")
ValueError: 这是一个异常
```



**异常被捕获示例：**

```python
from contextlib import contextmanager

@contextmanager
def simple_with():
    try:
        print('类似于进入 __enter__')
        yield
        print('类似于进入 __exit__')
    except Exception as e:
        print(f"异常类型：{type(e)} 异常值: {e}")
    finally:
        print("清理资源。")

with simple_with():
    print("简单with语法")
    raise ValueError("这是一个测试异常")
```

输出：

```python
类似于进入 __enter__
简单with语法
异常类型：<class 'ValueError'> 异常值: 这是一个测试异常
清理资源。
```

