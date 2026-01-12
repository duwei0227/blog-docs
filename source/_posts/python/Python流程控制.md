---
title: Python流程控制
published: true
layout: post
date: 2026-01-06 19:00:00
permalink: /python/flow_control.html
categories: [Python]
---



**流程控制**指的是程序中**指令执行的顺序**，即决定哪条语句什么时候执行。默认情况下代码是从上往下一行一行执行，但加入控制结构后，程序可以：

- 按条件分支执行不同代码

- 循环重复执行某段代码

  

这些改变正常顺序的行为统称为流程控制。



## 条件判断（Conditional Statements）

条件判断用于根据条件的真值（True/False）来控制程序执行哪一段代码。

### if 语句

**基本结构：**

```python
if condition:
    # 条件为 True 时执行
```

**示例：**

```python
x = 10
if x > 5:
    print("x 大于 5")
```

### if — else 语句

**基本结构：**

```python
if condition:
   # 条件为 True 时执行
else:
   # 当条件为 False 时执行另一段代码
```



**示例：**

```python
age = 16
if age >= 18:
    print("成年")
else:
    print("未成年")
```



### if — elif — else（多分支）

**`elif`** 是 “else if” 的缩写，用于添加多个条件判断：

**基本结构：**

```python
if condition:
   # 条件为 True 时执行
elif condition:
    # 前一个条件不满足时,且当前条件满足
else:
   # 当条件为 False 时执行另一段代码
```



**示例：**

```python
score = 75
if score >= 90:
    print("优秀")
elif score >= 60:
    print("及格")
else:
    print("不及格")
```

当第一个条件满足时，后续 `elif` 和 `else` 都不会再判断



## 循环结构

循环可以重复执行一段代码，直到特定条件满足或序列结束。

###  `for` 循环

`for` 用于遍历序列（如列表、字符串、range 等）：

**基本结构:**

```python
for 变量 in 可迭代对象:
    # 每次循环要执行的代码块

else:
    # 循环结束以后执行逻辑
```



**示例:**

```python
# 遍历 range ,range 用于产生列表
for i in range(5):
    print(i)
    
# 遍历列表 -- 只遍历元素
fruits = ["apple", "banana", "cherry"]
for fruit in fruits:
    print(fruit)

    
# 同时获取索引和元素  enumerate(fruits) 会返回一个可迭代的对象，每次迭代返回一个 (index, value) 二元组
for index, fruit in enumerate(fruits):
    print(index, fruit)

    
# 遍历 dict
person = {"name": "Alice", "age": 30, "city": "Beijing"}

# 遍历 dict 键 key   
for key in person:   # 等同于     for key in person.keys():
    print(key)
    
#  遍历值
for value in person.values():
    print(value)


# 遍历键 + 值
for key, value in person.items():
    print(key, value)


# for else
for i in range(5):
    print(i)
else:
    print("Loop completed")
# 输出 0 1 2 3 4 Loop completed
```



### `while` 循环

`while` 会只要条件为真就一直执行：

**基本结构:**

```python
while condition:
    # 需要在循环体中修改condition,使condition可以变为False,终止循环
else:
    # 循环结束以后执行逻辑
    
    
while True:
    # 默认为死循环
```



```python
count = 1
while count <= 3:
    print(count)
    count += 1
else:
    print("count = ", count)
```

输出：

```
1
2
3
count =  4
```

注意要在循环内修改条件，否则可能变成无限循环



## 循环跳转控制语句（Loop Control）

Python 提供一些关键字来改变循环执行的流程：`break` `continue` 和 `pass`。



### `break` — 提前退出循环

`break` 会 **立刻停止当前循环**（包括 `for` 和 `while`）,不再执行后续的循环判断：

```python
for i in range(5):
    if i == 3:
        break
    print(i)
```

输出：

```
0
1
2
```

循环当 `i == 3` 时被打断，后面的值不再输出。



### `continue` — 跳过本次迭代

`continue` 会跳过当前循环剩余的代码，**直接进行下一次循环**, `continue`不会中断循环,而是在循环内部判断条件满足时,跳过后续逻辑的执行：

```python
for i in range(5):
    if i == 2:
        continue
    print(i)
```

输出：

```
0
1
3
4
```

当 `i == 2` 时跳过打印。



### `pass` — 空操作（占位符）

`pass` 什么都不做，只是为了语法上保持结构有效：

```python
for i in range(3):
    if i == 1:
        pass  # 占位
    print(i)
```

输出：

```
0
1
2
```

`pass` 常用于函数体、类体等暂时未实现的地方



## `match`匹配

`match`语句接受一个表达式并把它的值与一个或多个 case 块给出的一系列模式进行比较。只有第一个匹配的模式会被执行，并且它还可以提取值的组成部分（序列的元素或对象的属性）赋给变量。如果没有匹配的case，则不执行任何分支。

**简单结构：**

* 用 `|` 将多个字面值组合到一个模式中
* `_`作为*通配符* ，所有case不匹配时，执行的逻辑
* `return` 的使用，需要将`match`作为函数的返回
* 可以用来匹配 常量值 枚举(`Enum`) 和 类(`Class`)



*函数、枚举和类后续讲解*



```python
match expression:
    case condition | condition:
        return value;  
    case condition:
        # 业务逻辑，无结果返回
    case _:
        # 默认处理，无任何case匹配时
```



**示例：**

```python
import random

rad = random.randint(0, 10)
match rad:
    case 0 | 1| 2:
        print("Low")
    case 3 | 4 :
        print("Medium")
    case _:
        print("High")    
```



**匹配类时，可以将匹配结果绑定到类属性，同时可以通过 `if` 增加守卫子句（需要满足`if`条件）**

```python
match 类实例：
    case 类(属性) if 条件:
        # 逻辑
    case 类(属性):
        # 逻辑
```



自定义类需要在类中设置特殊属性 `__match_args__`，为属性指定其在`match`模式中对应的位置。若设为 `("x", "y")`，则以下模式相互等价（且都把属性 `y` 绑定到变量 `var`）

```python
Point(1, var)
Point(1, y=var)
Point(x=1, y=var)
Point(y=var, x=1)
```

如果不设置`__match_args__`会报如下错误：

```python
TypeError: Point() accepts 0 positional sub-patterns (2 given)
```



**示例：**

```python
class Point:
    __match_args__ = ('x', 'y')
    def __init__(self, x, y):
        self.x = x
        self.y = y

point = Point(0, 5)

match point:
    case Point(x, y) if x == y:
        print(f"Y=X at {x}")
    case Point(x, y):
        print(f"Not on the diagonal")

```



**匹配枚举`Enum`**

```python
from enum import Enum
class Color(Enum):
    RED = 'red'
    GREEN = 'green'
    BLUE = 'blue'

# 可以修改 color 实例的值观察 match 模式匹配的输出
#color = Color.BLUE
color = Color.RED

match color:
    case Color.RED:
        print("I see red!")
    case Color.GREEN:
        print("Grass is green")
    case Color.BLUE:
        print("I'm feeling the blues :(")
```

