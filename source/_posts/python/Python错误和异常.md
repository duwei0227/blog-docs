---
title: Python错误和异常
published: true
layout: post
date: 2026-01-14 19:00:00
permalink: /python/exception.html
categories: [Python]
---

在`Python`中错误一般分为两种：编码阶段产生的语法错误 和 运行期间由于数据不满足逻辑产生的错误。



## 一、语法错误

语法错误又称解析错误，是在编码阶段产生的错误，在初期学习`Python`时最常见的错误：

**关键字错误示例：**

```python
while True:
    prin("Hello, World!") # 正确的应该为 print 
```

运行python文件时，解释器会告诉我们错误发生的函数和错误位置，如果是关键字类错误，解释器也会给出可能的建议。

```python
Traceback (most recent call last):
  File "/home/probie/workspace/python/base-python/test.py", line 2, in <module>
    prin("Hello, World!") # 
    ^^^^
NameError: name 'prin' is not defined. Did you mean: 'print'?
```

*关键字错误会报 NameError，并给出可能的建议*



**语法错误示例：**

```python
while True:
    print("hlsshs"  # 缺少右边的括号
```

```python
File "/home/probie/workspace/python/base-python/test.py", line 2
    print("hlsshs"
         ^
SyntaxError: '(' was never closed
```

*语法错误会报 SyntaxError，并会告知错误的行数和位置*



**针对语法错误，我们需要合理借助解释器给出的错误位置，错误函数，并针对性修复，是在编码阶段可发现的错误**



## 二、异常

整个程序不存在语法错误时，就可以进入运行阶段，在运行阶段由于数据不符合程序预期（有些数据异常可以增加防御性拦截减少）发生的错误，或者程序需要访问网络和磁盘时，可能会发生的网络问题（例如超时）或者访问磁盘文件时文件不存在的情况，产生的错误称呼为 **异常**。



**示例：**

```python
def divide(a, b):
    # if b == 0:
        # raise ValueError("Denominator cannot be zero.")
    return a / b

print(divide(10, 2))  # Expected output: 5.0
print(divide(10, 0))  # This should raise a ValueError
```

```python
5.0
Traceback (most recent call last):
  File "/home/probie/workspace/python/base-python/test.py", line 7, in <module>
    print(divide(10, 0))  # This should raise a ValueError
          ^^^^^^^^^^^^^
  File "/home/probie/workspace/python/base-python/test.py", line 4, in divide
    return a / b
           ~~^~~
ZeroDivisionError: division by zero
```

同样，异常发生的时候，如果程序没有进行逻辑上的捕获处理，解释器会直接中断后续执行，并抛出错误信息，错误信息包含错误发生的位置，异常的原因。

像上述示例中的 `ZeroDivisionError` 我们就可以通过防御性的错误，先判断除数是否为0,从而避免程序的直接中断。



### 1、异常的处理

在`Python`中异常的处理不是必须的，如果代码逻辑上没有主动进行异常的捕获和处理，在发生异常的时候，解释器会中断执行，可能不是我们预期需要的结果。

为什么需要主动对异常进行捕获和处理呢？我们现在想要往文件里边写入数据，这个时候如果文件不存在或者没有写的权限，如果直接失败，用户体验就可能很差；对于文件不存在，业务上是否可以接收当发生文件不存在异常时，程序主动创建文件，继续后续逻辑的执行；对于没有写的权限，可能就需要对异常进行处理，转为用户可读的信息，返回调整后的描述信息。



**异常处理语法：**

```py
try:
    # 可能发生异常的代码
except 异常类型:  # 可以有多个 except
# 或 
except 异常类型 as 别名  
else:    # 可选
    paas 
finally:   # 一定会执行的逻辑，可选
    paas
```

**关键字解释：**

* `try`：可能发生异常的代码逻辑
* `except`：用于捕获并匹配异常类型，可以有多个`except`匹配不同的类型，异常类型的匹配应该遵循从小到达的原则（即先具体异常逐步转为适配度更高的异常类型），同一个`except`下也可以同时匹配多个异常类型，使用元组配置多个异常类型；`except`的匹配过程按照从上到下的顺序。
* `as`：在`except`中，对于异常类型定义一个别名，在子句中通过别名对类型进行操作
* `else`：可选关键字，表示未发生异常的情况下，需要执行的代码逻辑
* `finall`：可选关键字，无论是否发生异常都会执行的代码逻辑，通常用于资源的释放，例如：文件和网络IO资源



**语句执行顺序：**

* 首先执行`try`自己中的正常代码逻辑
* 如果没有触发异常，则跳过`except`子句，会执行可选的 `else` 和 `finally` 子句
* 如果发生异常，会跳过`try`子句中异常位置的后续语句的执行，会按照`except`的顺序进行异常类型匹配。如果异常的类型与 `except`关键字后指定的异常相匹配，则会执行 *except 子句*，
* 如果发生的异常与 *except 子句* 中指定的异常不匹配，则它会被传递到外层的 `try`语句中；如果没有找到处理器，则它是一个 *未处理异常* 且执行将停止并输出一条错误消息。

![image-20260114170229669](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20260114170229669.png)



#### 1.1 无异常示例

```python
def divide(a, b):
    try:
        r = a / b
    except ZeroDivisionError:
        print("哦豁，除以零了！")
    else:
        print("除法成功，结果是：", r)
    finally:
        print("无论如何，这段代码都会执行。")
    
    print("函数执行完毕。")


divide(10, 2)

```

输出：

```python
除法成功，结果是： 5.0
无论如何，这段代码都会执行。
函数执行完毕。
```



从执行结果来说：执行完`try`子句以后，先执行`else`在执行`finally`语句。



#### 1.2 抛出异常，匹配 except

```python
def divide(a, b):
    try:
        r = a / b
        print("正在执行除法操作...")
    except ZeroDivisionError:
        print("哦豁，除以零了！")
    else:
        print("除法成功，结果是：", r)
    finally:
        print("无论如何，这段代码都会执行。")
    
    print("函数执行完毕。")


divide(10, 0)
```

输出：

```python
哦豁，除以零了！
无论如何，这段代码都会执行。
函数执行完毕。
```

从执行结果来说：执行`try`子句`a/b`发生异常以后，后续的`print`语句不再执行，然后再进行`except`匹配，当前异常类型与`ZeroDivisionError`匹配，执行`except`子句，然后在执行`finally`语句，**其中`else`未执行**。



#### 1.3 抛出异常，无任何except匹配

```python
def divide(a, b):
    try:
        r = a / b
        print("正在执行除法操作...")
    except NameError:
        print("哦豁，除以零了！")
    else:
        print("除法成功，结果是：", r)
    finally:
        print("无论如何，这段代码都会执行。")
    
    print("函数执行完毕。")


divide(10, 0)
```

输出:

```python
无论如何，这段代码都会执行。
Traceback (most recent call last):
  File "/home/probie/workspace/python/base-python/test.py", line 15, in <module>
    divide(10, 0)
  File "/home/probie/workspace/python/base-python/test.py", line 3, in divide
    r = a / b
        ~~^~~
ZeroDivisionError: division by zero
```

`try`子句发生异常的时候，如果没有任何`except`匹配，会先执行`finally`子句，然后中断程序后续执行。



#### 1.4 抛出异常，except按照从大到小匹配（错误顺序）

```python
def divide(a, b):
    try:
        r = a / b
        print("正在执行除法操作...")
    except Exception:
        print("我是 Exception 捕获的异常！")
    except ZeroDivisionError:
        print("我是 ZeroDivisionError 捕获的异常！")
    else:
        print("除法成功，结果是：", r)
    finally:
        print("无论如何，这段代码都会执行。")
    
    print("函数执行完毕。")


divide(10, 0)
```

由于 `ZeroDivisionError` 是 `Exception` 的子类，所有`except`按照从上到下匹配的时候，`Exception`满足，执行`Exception`子句，不再进行后续异常类型匹配。

**此种顺序会导致抛出的错误信息非预期的精确描述**



#### 1.5 同一个 except 匹配多个异常类型

```python
def divide(a, b):
    try:
        r = a / b
        print("正在执行除法操作...")
    except (ZeroDivisionError , NameError):
        print("除法失败，除数不能为零或变量未定义。")
    else:
        print("除法成功，结果是：", r)
    finally:
        print("无论如何，这段代码都会执行。")
    
    print("函数执行完毕。")


divide(10, 0)
```

输出：

```python
除法失败，除数不能为零或变量未定义。
无论如何，这段代码都会执行。
函数执行完毕。
```



### 2、主动触发异常

使用关键字 `raise` 可以强制触发异常。

何时使用`raise`主动抛出异常：

* 在捕获到异常以后，对异常添加额外的注释信息或记录相关行为后，抛出转换后的自定义异常--全局异常统一
* 将 `raise` 作为多层嵌套`if`的一个替换，在条件不满足的情况下，抛出一个特定的异常，减少嵌套深度

**示例：**

```python
i = int(input("输入一个整数: "))

if i < 0:
    raise ValueError("负数没有平方根")
else:
    print(i ** 0.5)
```

```python
输入一个整数: -1
Traceback (most recent call last):
  File "/home/probie/workspace/python/base-python/test.py", line 4, in <module>
    raise ValueError("负数没有平方根")
ValueError: 负数没有平方根
```



### 3、使用注释细化异常原因

当一个异常被创建以引发时，它通常被初始化为描述所发生错误的信息。在有些情况下，在异常被捕获后添加信息是很有用的。为了这个目的，异常有一个 `add_note(note)` 方法接受一个字符串，并将其添加到异常的注释列表。在异常堆栈信息之后按照它们被添加的顺序输出所有的注释。

**如果对异常需要增加额外的注释信息时，需要使用 `as` 将异常定义一个别名**

**示例：**

```python
def divide(a, b):
    try:
        r = a / b
    except ZeroDivisionError as e:
        e.add_note("我是 1")
        e.add_note("我是 2")
        raise
    return r

divide(1, 0)
```

输出：

```python
Traceback (most recent call last):
  File "/home/probie/workspace/python/base-python/test.py", line 10, in <module>
    divide(1, 0)
  File "/home/probie/workspace/python/base-python/test.py", line 3, in divide
    r = a / b
        ~~^~~
ZeroDivisionError: division by zero
我是 1
我是 2
```



### 4、自定义异常

通过创建新的类自定义异常，自定义类需要直接或间接的方式继承 `Exception` 类。`Exception` 可以被用作通配符，捕获（几乎）一切。大多数异常命名都以 “Error” 结尾，类似标准异常的命名。

*`BaseException`是所有异常的共同基类。它的一个子类， `Exception`，是所有非致命异常的基类。不是 `Exception`的子类的异常通常不被处理，因为它们被用来指示程序应该终止。*

#### 4.1 基本自定义异常

**语法：**

```python
class 名称Error(Exception):  # 此处Exception可以变更为其他任何继承 Exception 的类
    paas
```



**示例**

```python
class BaseError(Exception):
    """Base class for all custom exceptions in the module."""
    pass

class SubErrorA(BaseError):
    """Exception raised for specific error A."""
    pass

i = int(input("请输入一个整数："))

if i < 0:
    raise SubErrorA("输入的整数不能为负数。")
elif i == 0:
    raise BaseError("输入的整数不能为零。")
else:
    print(f"输入的整数是：{i}")
```

匹配 `SubErrorA`:

```python
请输入一个整数：-1
Traceback (most recent call last):
  File "/home/probie/workspace/python/base-python/test.py", line 12, in <module>
    raise SubErrorA("输入的整数不能为负数。")
SubErrorA: 输入的整数不能为负数。
```

匹配`BaseError`:

```python
请输入一个整数：0
Traceback (most recent call last):
  File "/home/probie/workspace/python/base-python/test.py", line 14, in <module>
    raise BaseError("输入的整数不能为零。")
BaseError: 输入的整数不能为零。
```

正常输出：

```python
请输入一个整数：2
输入的整数是：2
```





#### 4.2 增加自定义操作异常定义

**自定义异常描述格式**

需要重写 `__str__`方法：

```python
class 名称Error(Exception):
    def __str__(self):
        # 自定义逻辑
        return xx
```

**示例：**

```python
class CommonError(Exception):
    def __init__(self, code):
        self._code = code
        super().__init__(code)

    def __str__(self):
        if self._code == "ERR101":
            return "输入的整数不能为负数"
        elif self._code == "ERR102":
            return "输入的值不是整数"
        else:
            return "未知错误"

i = int(input("请输入一个整数: "))
if i < 0:
    raise CommonError("ERR101")
else:
    print("输入的整数是:", i)
```

输出：

```python
请输入一个整数: -2
Traceback (most recent call last):
  File "/home/probie/workspace/python/base-python/test.py", line 16, in <module>
    raise CommonError("ERR101")
CommonError: 输入的整数不能为负数



```

