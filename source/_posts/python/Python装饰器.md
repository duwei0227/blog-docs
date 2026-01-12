---
title: Python装饰器
published: true
layout: post
date: 2026-01-12 19:00:00
permalink: /python/decorator.html
categories: [Python]
---



## 一、定义

**装饰器**是对函数的一个装饰，通过装饰器可以做到在不改变目标函数逻辑的情况下增强目标函数的能力；当调用被装饰函数时，实际上是运行装饰器返回的那个包装函数，装饰器中需要处理对目标函数的调用。



**常见使用场景：**

* 日志记录：自动记录函数什么时候被调用、参数是什么，返回值是什么
* 权限控制：可以检查用户是否用于访问接口的权限



## 二、装饰器的使用

### 1、无参数装饰器

**语法：**

```python
def 装饰器的名称(func):
    def wrapper(*args, **kwargs):
        result = func(*args, **kwargs)
        return result
    return wrapper


def decorator(func):
    def wrapper(*args, **kwargs):
        # 在这里可以添加 “额外逻辑”
        result = func(*args, **kwargs)  # 调用原函数
        # 在这里可以添加 “额外逻辑”
        return result
    return wrapper

@decorator
def func(...):
    ...

```

* 接收一个函数作为外层参数
* 内部返回一个函数，内部函数处理任意参数，调用目标函数
* 使用`*args` `**kwargs`，让装饰器适配任意参数签名，不必逐个定义



**示例：**

```python
def log_decorator(func):
    def wrapper(*args, **kwargs):
        print("Before calling", func.__name__)
        result = func(*args, **kwargs)
        print("After calling", func.__name__)
        return result
    return wrapper

@log_decorator
def greet(name):
    print("Hello", name)

greet("Alice")

# 输出
Before calling greet
Hello Alice
After calling greet
```





### 2、有参数装饰器

如果想要装饰器也支持参数，那么就需要在嵌套一层函数，最外层函数接收装饰器的参数。

**语法：**

```python
def 最外层函数名(装饰器参数名):
    # 无参数装饰器

def repeat(times):
    def decorator(func):
        def wrapper(*args, **kwargs):
            for _ in range(times):
                func(*args, **kwargs)
        return wrapper
    return decorator

```



**示例：**

```python
def logger(level):
    def decorator(func):
        def wrapper(*args, **kwargs):
            print(f"[{level}] Calling {func.__name__}")
            return func(*args, **kwargs)
        return wrapper
    return decorator

@logger("DEBUG")
def multiply(a, b):
    return a * b

print(multiply(5, 6))

# 输出 
[DEBUG] Calling multiply
30
```



### 3、保留被装饰函数的原始信息

默认情况下，目标函数被装饰器装饰后，由于函数的执行被内部函数`wrapper`包括，在获取原函数的元数据（例如函数名、文档注释）信息时，获取到的是 `wrapper`函数的名称和文档注释。

例如以下示例代码，我们期望获取到的函数名是 `multiply`,然而实际获取到的却是 `wrapper`:

```python
def logger(level):
    def decorator(func):
        def wrapper(*args, **kwargs):
            """I am a wrapper function"""
            print(f"[{level}] Calling {func.__name__}")
            return func(*args, **kwargs)
        return wrapper
    return decorator

@logger("DEBUG")
def multiply(a, b):
    """
    Docstring for multiply
    
    :param a: Description
    :param b: Description
    """
    return a * b

print(multiply.__name__)
print(multiply.__doc__)
print(multiply.__module__)
print(multiply.__annotations__)

# 输出
wrapper
I am a wrapper function
__main__
{}
```



那么如果我们想要获取被装饰函数的原始信息时，应该要如何实现呢？答案是使用 `functools.wraps` 来将原函数的元数据信息复制到包装函数上，包括但不限于：

* 函数名（`__name__`）
* 文档字符串（`__doc__`）
* 模块名（`__module__`）



**语法：**

```python
# 1、引入 from functools import wraps
# 2、内部 wrapper 函数增加 @wraps(func)
```



**示例：**

```python
from functools import wraps

def logger(level):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            """I am a wrapper function"""
            print(f"[{level}] Calling {func.__name__}")
            return func(*args, **kwargs)
        return wrapper
    return decorator

@logger("DEBUG")
def multiply(a, b):
    """
    Docstring for multiply
    
    :param a: Description
    :param b: Description
    """
    return a * b

print(multiply.__name__)
print(multiply.__doc__)
print(multiply.__module__)
print(multiply.__annotations__)

# 输出
multiply

    Docstring for multiply
    
    :param a: Description
    :param b: Description
    
__main__
{}
```

*模块名是由于测试的时候都在 main中测试*



```python
from functools import wraps

def log(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        # 打印入参
        print(f"Calling {func.__name__} with args: {args}, kwargs: {kwargs}")
        result = func(*args, **kwargs)
        # 打印返回值
        print(f"{func.__name__} returned: {result}")
        return result
    return wrapper

@log
def add(a, b):
    return a + b

print(add(2, 3))  # Output: 5


# 输出
Calling add with args: (2, 3), kwargs: {}
add returned: 5
5
```

