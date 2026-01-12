---
title: Python函数
published: true
layout: post
date: 2026-01-07 19:00:00
permalink: /python/function.html
categories: [Python]
---



函数（function）是 **可复用的代码块**，接收输入（参数），执行逻辑，并可返回结果。简单来说，就是在编码过程中，有一段代码重复多次出现，那么就可以将这一段逻辑放在一个独立的函数中，通过传入参数获取计算结果。例如（一个不恰当的）：老师需要计算班级里边的每个学生成绩平均分，需要先计算学生总成绩，在除以学科数量获取平均值，求和在平均这个步骤，每个学生都需要计算，就可以把这一部分抽离到一个独立的函数中，通过传入学生的所有成绩获取平均值。



## 语法定义

函数通过`def`关键字来定义一个函数，默认情况不需要显示指定参数类型

```python
def function_name(pos_args1: arg_type, pos_args2, default_args, *args, **kwargs) -> return_type:
    """函数文档字符串"""
    
    # 逻辑业务
    paas
    return value
```



**示例：**

```python
def f(a, b = 2, *args, **kwargs) -> int:
    print("a = ", a)
    print("b = ", b)

    for arg in args:
        print(arg)
    for key, value in kwargs.items():
        print(f"{key}: {value}")
    return 0

args_list = [4, 5]
d = {'x': 10, 'y': 20}
r = f(1, 3, *args_list, **d)
print("Return value:", r)
```

输出结果：

```python
a =  1
b =  3
4
5
x: 10
y: 20
```



## 函数详解

### 位置参数（必需参数）

顾名思义，位置参数就是按照函数定义时参数的顺序传入参数，并对参数进行对应的赋值

```python
def greet(name, age):
    print(f"Hello, my name is {name} and I am {age} years old.")

# 调用函数时传递位置参数
greet("Alice", 30) # 输出: Hello, my name is Alice and I am 30 years old.
greet(25, "Bob")   # 输出: Hello, my name is 25 and I am Bob years old.
```

调用相同的`greet`函数时，参数传入顺序不同，`name`和`age`的值也表现的不同



### 默认值参数（可选参数）

在声明参数时，给参数一个默认值，调用函数时如果不传入具体的值，将默认值作为参数的实际值。

默认产生的定义需要在位置参数后边。



**示例：**

```python
def f(a = 2):
    return a * 2

print(f())  # 返回 4，采用参数 a 的默认值 2 计算
print(f(5)) # 返回 10
```



**重要事项：**默认值只计算一次。默认值为列表、字典或类实例等可变对象时，如果不想在后续调用之间共享默认值时，应该在编写函数时，设置参数的值为 `None`，并在函数内部判断参数是否为`None`并进行初始化，即每次调用函数时，如果期望参数都是一个新的列表或字典时，应该设置参数默认值为 `None`

**不设置None示例**

```python
def f(a, L=[]):
    L.append(a)
    return L

print(f(1)) # [1]
print(f(2)) # [1, 2]
print(f(3)) # [1, 2, 3]
```



**设置None示例**

```python
def f(a, L=None):
    if L is None:
        L = []
    L.append(a)
    return L

print(f(1)) # [1]
print(f(2)) # [2]
print(f(3)) # [3]
```



### 关键字参数

所谓的关键字参数，本质上在函数定义的时候是不存在的，而是发生在函数调用阶段。

函数调用的时候，传入参数的时候指定参数的名称，形成 `kwarg=value` 的形式，从而称之为关键字参数。

使用关键字参数时，可以不用遵循位置参数的顺序，当然如果调用时，位置参数和关键字参数混用的情况，还是需要遵循先位置后关键字的顺序。

**示例：**

```python
def greet(name, age, city = 'Changsha'):
    print(f"Hello, my name is {name}. I am {age} years old and I live in {city}.")

# 关键字参数调用
greet(age=25, name='Alice') # 返回 Hello, my name is Alice. I am 25 years old and I live in Changsha.
greet(name='Bob', age=30, city='New York') # 返回 Hello, my name is Bob. I am 30 years old and I live in New York.
greet('Charlie', 22)  # 使用默认参数city # 返回 Hello, my name is Charlie. I am 22 years old and I live in Changsha.
```

从示例不难看出，使用关键字参数的时候，`age`和`name`的顺序是没有要求的。

假如函数调用的时候，先设置关键字参数在设置位置参数（如`greet(age=28, 'Diana') `）会发生什么事情？

* 编译运行的时候会报错：`SyntaxError: positional argument follows keyword argument`





### 任意数量参数

#### 任意数量的元组tuple或列表list

**语法：**

使用`*args`声明函数接收任意数量的列表或元组，方式调用的时候可以使用 `*`操作符把实参从列表或元组解包出来

```python
def f(*args):
    paas
```

**示例：**

```python
# 函数 *args 示例
def f(*args):
    for index, value in enumerate(args):
        print(f"Argument {index}: {value}")

# 直接传递多个参数
f(10, 20, 30, "hello", [1, 2, 3])

# 使用列表作为参数传递
l = [1, 2, 3, 4, 5]
f(*l)

# 使用元组作为参数传递
t = (100, 200, 300)
f(*t)
```



#### 任意数量的dict

**语法：**

使用`**kwargs`声明函数接收任意数量的列表或元组，方式调用的时候可以使用 `**`操作符把实参从`dict`中解包出来

```python
def f(**kwargs):
    paas
```

**示例：**

```python
# 函数 **kwargs 示例
def f(**kwargs):
    for key, value in kwargs.items():
        print(f"Argument {key}: {value}")

# 调用函数，传递关键字参数
f(name='Alice', age=25, city='Changsha')
f(name='Bob', age=30, city='New York')
f(name='Charlie', age=22)  

# 使用字典传递关键字参数
d = {'name': 'David', 'age': 28, 'city': 'Los Angeles'}
f(**d)  # 使用字典解包传递关键字参数

```



### 函数返回

使用`return`返回值，可以返回单值也可以返回多值，如果函数结尾没有显示编写`return`时，函数默认返回为`None`

**示例：**

```python
# 函数return返回示例
def add(a, b):
    return a + b  # 返回两个数的和

result = add(3, 5)
print("3 + 5 =", result)  # 输出结果

def none_return():
    print("This function does not return anything.")

none_result = none_return()
print("Return value of none_return():", none_result)  # 输出None

# 返回多值
def get_coordinates():
    x = 10
    y = 20
    return x, y  # 返回多个值作为元组
coords = get_coordinates()
print("Coordinates:", coords)  # 输出坐标元组
```





### 函数文档字符串

内容和格式约定如下：

* 第一行应为对象用途的简短摘要。为保持简洁，不要在这里显式说明对象名或类型。
* 文档字符串为多行时，第二行应为空白行
* 第三行以后开始可包含若干段落，描述对象的调用约定、副作用等



**示例：**

```python
"""
    Docstring for f
    
    :param a: Description
    :param b: Description
    :param args: Description
    :param kwargs: Description
    :return: Description
    :rtype: int
    """
```

* `:param`:  入参说明
* `:return`:返回参数说明
* `:rtyp`: 返回参数类型



### Lambda表达式

`lambda` 关键字用于创建小巧的匿名函数。

**语法：**

```python
lambda 参数列表: 表达式
```



**示例：**

```python
# lambda示例
add = lambda x, y: x + y
result = add(3, 5)
print("3 + 5 =", result)
```

