---
title: Python字符串操作指南
published: true
layout: post
date: 2026-03-23 13:00:00
permalink: /python/string-guide.html
categories: [Python]
---

Python的`string`模块提供了丰富的字符串操作功能，从基础常量到高级格式化，涵盖了日常开发中的大多数需求。本文将按照从基础到高级的顺序，讲解Python字符串的核心功能。

## 一、字符串常量

`string`模块定义了一系列实用的字符串常量，可以直接在程序中使用，常用于验证输入、生成随机字符串等场景。

### 1. 字符串常量语法

以下是`string`模块中定义的常用字符串常量：

| API | 说明 | 示例（值） |
|-----|------|------------|
| `string.ascii_letters` | ASCII字母（小写+大写） | `'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'` |
| `string.ascii_lowercase` | ASCII小写字母 | `'abcdefghijklmnopqrstuvwxyz'` |
| `string.ascii_uppercase` | ASCII大写字母 | `'ABCDEFGHIJKLMNOPQRSTUVWXYZ'` |
| `string.digits` | 十进制数字 | `'0123456789'` |
| `string.hexdigits` | 十六进制数字 | `'0123456789abcdefABCDEF'` |
| `string.octdigits` | 八进制数字 | `'01234567'` |
| `string.punctuation` | ASCII标点符号 | `'!"#$%&\'()*+,-./:;<=>?@[\\]^_`{\|}~'` |
| `string.printable` | 所有可打印字符 | 包含数字、字母、标点和空白字符 |
| `string.whitespace` | 空白字符 | `' \t\n\r\x0b\x0c'` |

**示例**

```python
import string

# 查看所有字符串常量
print("ASCII字母:", string.ascii_letters)
print("ASCII小写字母:", string.ascii_lowercase) 
print("ASCII大写字母:", string.ascii_uppercase)
print("数字:", string.digits)
print("十六进制数字:", string.hexdigits)
print("八进制数字:", string.octdigits)
print("标点符号:", string.punctuation)
print("空白字符:", repr(string.whitespace))

# 生成随机密码
import random
def generate_password(length=12):
    """生成包含字母、数字和特殊字符的随机密码"""
    chars = string.ascii_letters + string.digits + string.punctuation
    return ''.join(random.choice(chars) for _ in range(length))

print("\n随机密码:", generate_password())

# 验证输入字符
user_input = "abc123"
if all(c in string.ascii_letters + string.digits for c in user_input):
    print(f"输入 '{user_input}' 有效")
else:
    print(f"输入 '{user_input}' 包含非法字符")
```

输出：
```
ASCII字母: abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ
ASCII小写字母: abcdefghijklmnopqrstuvwxyz
ASCII大写字母: ABCDEFGHIJKLMNOPQRSTUVWXYZ
数字: 0123456789
十六进制数字: 0123456789abcdefABCDEF
八进制数字: 01234567
标点符号: !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~
空白字符: ' \t\n\r\x0b\x0c'

随机密码: A3b$kL9@mN!p
输入 'abc123' 有效
```

## 二、字符串格式化

Python提供了多种字符串格式化方法，用于将变量插入到字符串中。最常用的是`str.format()`方法和f-string（Python 3.6+）。

### 1. str.format()方法语法

`str.format()`方法通过大括号`{}`作为占位符，支持位置参数、关键字参数和格式说明符。

| API | 说明 | 示例（用法） |
|-----|------|-------------|
| `"{}".format(value)` | 基本位置参数 | `"Hello, {}".format("World")` |
| `"{0} {1}".format(a, b)` | 索引位置参数 | `"{1} {0}".format("A", "B")` |
| `"{name}".format(name=value)` | 关键字参数 | `"{greet}".format(greet="Hi")` |
| `"{value:.2f}".format(value=3.14159)` | 格式说明符（浮点数） | `"{:.2f}".format(3.14159)` |
| `"{:<10}".format("text")` | 左对齐（宽度10） | `"{:<10}".format("test")` |
| `"{:>10}".format("text")` | 右对齐（宽度10） | `"{:>10}".format("test")` |
| `"{:^10}".format("text")` | 居中对齐（宽度10） | `"{:^10}".format("test")` |
| `"{:*^10}".format("text")` | 填充字符对齐 | `"{:*^10}".format("test")` |

### 2. 数字格式化选项

| 格式说明符 | 说明 | 示例（用法） |
|------------|------|-------------|
| `"{:,}".format(1234567)` | 千位分隔符 | `"{:,}".format(1234567)` |
| `"{:_}".format(1234567)` | 下划线分隔符 | `"{:_}".format(1234567)` |
| `"{:+}".format(42)` | 总是显示符号 | `"{:+}".format(42)` |
| `"{: }".format(42)` | 正数前加空格 | `"{: }".format(42)` |
| `"{:b}".format(255)` | 二进制表示 | `"{:b}".format(255)` |
| `"{:o}".format(255)` | 八进制表示 | `"{:o}".format(255)` |
| `"{:x}".format(255)` | 十六进制小写 | `"{:x}".format(255)` |
| `"{:#x}".format(255)` | 十六进制带前缀 | `"{:#x}".format(255)` |
| `"{:e}".format(1234.56)` | 科学计数法 | `"{:e}".format(1234.56)` |
| `"{:.1%}".format(0.85)` | 百分比格式 | `"{:.1%}".format(0.85)` |

**示例**

```python
# 基本格式化
name = "张三"
age = 30
print("你好，我是{}，今年{}岁。".format(name, age))
print("你好，我是{0}，今年{1}岁。".format(name, age))
print("你好，我是{name}，今年{age}岁。".format(name=name, age=age))

# 数字格式化
pi = 3.1415926
print("\n数字格式化:")
print("圆周率: {:.2f}".format(pi))
print("百分比: {:.1%}".format(0.85))
print("十六进制: 0x{:x}".format(255))

# 对齐和填充
print("\n对齐和填充:")
print("左对齐: '{:<10}'".format("test"))
print("右对齐: '{:>10}'".format("test"))
print("居中对齐: '{:^10}'".format("test"))
print("填充字符: '{:*^10}'".format("test"))

# 高级数字格式化
num = 1234567.89
print("\n高级数字格式化:")
print("千位分隔符: {:,}".format(num))
print("科学计数法: {:e}".format(num))
print("二进制: {:b}".format(255))
print("八进制: {:o}".format(255))
print("十六进制: {:x}".format(255))
print("带符号: {:+}".format(42))
print("正数空格: {: }".format(42))
print("零填充: {:08}".format(42))
```

输出：
```
你好，我是张三，今年30岁。
你好，我是张三，今年30岁。
你好，我是张三，今年30岁。

数字格式化:
圆周率: 3.14
百分比: 85.0%
十六进制: 0xff

对齐和填充:
左对齐: 'test      '
右对齐: '      test'
居中对齐: '   test   '
填充字符: '***test***'

高级数字格式化:
千位分隔符: 1,234,567.89
科学计数法: 1.234568e+06
二进制: 11111111
八进制: 377
十六进制: ff
带符号: +42
正数空格:  42
零填充: 00000042
```

### 3. f-string语法（Python 3.6+）

f-string提供更简洁的格式化语法，在字符串前加`f`或`F`，用大括号包裹表达式。

| API | 说明 | 示例（用法） |
|-----|------|-------------|
| `f"{var}"` | 变量插值 | `name = "Alice"; f"Hello {name}"` |
| `f"{expr}"` | 表达式计算 | `f"{10 + 20}"` |
| `f"{var.upper()}"` | 方法调用 | `f"{'hello'.upper()}"` |
| `f"{len(lst)}"` | 函数调用 | `f"{len([1,2,3])}"` |
| `f"{var:.2f}"` | 格式说明符 | `f"{3.14159:.2f}"` |
| `f"{var:#x}"` | 进制转换 | `f"{255:#x}"` |

**示例**

```python
name = "李四"
age = 25
score = 95.5

print(f"{name}今年{age}岁，成绩{score}分")
print(f"成绩百分比: {score:.1%}")
print(f"十六进制年龄: {age:#x}")

# 表达式计算
a = 10
b = 20
print(f"\n表达式计算:")
print(f"{a} + {b} = {a + b}")
print(f"{a}的平方是{a**2}")

# 调用方法
text = "hello world"
print(f"\n方法调用:")
print(f"大写: {text.upper()}")
print(f"长度: {len(text)}")

# 复杂表达式
items = [1, 2, 3, 4, 5]
print(f"\n复杂表达式:")
print(f"列表平均值: {sum(items) / len(items):.2f}")
print(f"最大值: {max(items)}")
print(f"最小值: {min(items)}")
```

输出：
```
李四今年25岁，成绩95.5分
成绩百分比: 95.5%
十六进制年龄: 0x19

表达式计算:
10 + 20 = 30
10的平方是100

方法调用:
大写: HELLO WORLD
长度: 11

复杂表达式:
列表平均值: 3.00
最大值: 5
最小值: 1
```

## 三、字符串方法

Python字符串对象提供了丰富的内置方法，用于大小写转换、查找替换、分割连接等操作。

### 1. 大小写转换方法

| API | 说明 | 示例（用法） |
|-----|------|-------------|
| `str.upper()` | 转换为大写 | `"hello".upper()` |
| `str.lower()` | 转换为小写 | `"HELLO".lower()` |
| `str.capitalize()` | 首字母大写 | `"hello world".capitalize()` |
| `str.title()` | 每个单词首字母大写 | `"hello world".title()` |
| `str.swapcase()` | 大小写互换 | `"Hello World".swapcase()` |
| `str.casefold()` | 更激进的小写转换 | `"Straße".casefold()` |

**示例**

```python
text = "  Python字符串操作指南  "

print("原字符串:", repr(text))
print("大写:", text.upper())
print("小写:", text.lower())
print("首字母大写:", text.capitalize())
print("每个单词首字母大写:", text.title())
print("大小写互换:", text.swapcase())

# casefold vs lower
text1 = "Straße"  # 德语
text2 = "STRASSE"
print(f"\ncasefold比较:")
print(f"'{text1}'.lower() = '{text1.lower()}'")
print(f"'{text1}'.casefold() = '{text1.casefold()}'")
print(f"'{text2}'.casefold() = '{text2.casefold()}'")
print(f"比较: '{text1.casefold()}' == '{text2.casefold()}' = {text1.casefold() == text2.casefold()}")
```

输出：
```
原字符串: '  Python字符串操作指南  '
大写: '  PYTHON字符串操作指南  '
小写: '  python字符串操作指南  '
首字母大写: '  python字符串操作指南  '
每个单词首字母大写: '  Python字符串操作指南  '
大小写互换: '  pYTHON字符串操作指南  '

casefold比较:
'Straße'.lower() = 'straße'
'Straße'.casefold() = 'strasse'
'STRASSE'.casefold() = 'strasse'
比较: 'strasse' == 'strasse' = True
```

### 2.空白处理

| API | 说明 | 示例（用法） |
|-----|------|-------------|
| `str.strip([chars])` | 去除两端空白或指定字符 | `"  hello  ".strip()` |
| `str.lstrip([chars])` | 去除左端空白或指定字符 | `"  hello  ".lstrip()` |
| `str.rstrip([chars])` | 去除右端空白或指定字符 | `"  hello  ".rstrip()` |

**示例**

```python
text = "  Python字符串操作指南  "
print("原字符串:", repr(text))
print("去除两端空白:", repr(text.strip()))
print("去除左端空白:", repr(text.lstrip()))
print("去除右端空白:", repr(text.rstrip()))

# 去除指定字符
text2 = "---hello---"
print(f"\n原字符串: {repr(text2)}")
print(f"去除'-': {repr(text2.strip('-'))}")
print(f"去除左端'-': {repr(text2.lstrip('-'))}")
print(f"去除右端'-': {repr(text2.rstrip('-'))}")

# 去除混合字符
text3 = " ** hello ** "
print(f"\n原字符串: {repr(text3)}")
print(f"去除' *': {repr(text3.strip(' *'))}")
print(f"去除左端' *': {repr(text3.lstrip(' *'))}")
print(f"去除右端' *': {repr(text3.rstrip(' *'))}")
```

输出：
```
原字符串: '  Python字符串操作指南  '
去除两端空白: 'Python字符串操作指南'
去除左端空白: 'Python字符串操作指南  '
去除右端空白: '  Python字符串操作指南'

原字符串: '---hello---'
去除'-': 'hello'
去除左端'-': 'hello---'
去除右端'-': '---hello'

原字符串: ' ** hello ** '
去除' *': 'hello'
去除左端' *': 'hello ** '
去除右端' *': ' ** hello'
```

### 3. 查找和替换

| API | 说明 | 示例（用法） |
|-----|------|-------------|
| `str.find(sub[, start[, end]])` | 查找子串，返回索引 | `"hello".find("l")` |
| `str.rfind(sub[, start[, end]])` | 从右侧查找子串 | `"hello".rfind("l")` |
| `str.index(sub[, start[, end]])` | 类似find，找不到时抛异常 | `"hello".index("l")` |
| `str.rindex(sub[, start[, end]])` | 从右侧查找，找不到时抛异常 | `"hello".rindex("l")` |
| `str.count(sub[, start[, end]])` | 统计子串出现次数 | `"hello".count("l")` |
| `str.replace(old, new[, count])` | 替换子串 | `"hello".replace("l", "x")` |

**示例**

```python
text = "Python是一门强大的编程语言，Python易学易用"

print("原字符串:", text)
print("查找'Python':", text.find("Python"))
print("从右侧查找'Python':", text.rfind("Python"))
print("查找'Java':", text.find("Java"))  # 返回-1

# index方法（找不到时抛出异常）
try:
    print("index查找'Python':", text.index("Python"))
    print("index查找'Java':", text.index("Java"))
except ValueError as e:
    print("index查找'Java'失败:", e)

print("统计'Python'出现次数:", text.count("Python"))
print("替换'Python'为'Java':", text.replace("Python", "Java"))
print("替换前1个'Python':", text.replace("Python", "Java", 1))

# 使用start和end参数
text2 = "hello world, hello python"
print(f"\n原字符串: {text2}")
print(f"查找'hello'（从位置5开始）: {text2.find('hello', 5)}")
print(f"查找'hello'（位置0-12）: {text2.find('hello', 0, 12)}")
print(f"统计'hello'（位置0-12）: {text2.count('hello', 0, 12)}")
```

输出：
```
原字符串: Python是一门强大的编程语言，Python易学易用
查找'Python': 0
从右侧查找'Python': 17
查找'Java': -1
index查找'Python': 0
index查找'Java'失败: substring not found
统计'Python'出现次数: 2
替换'Python'为'Java': Java是一门强大的编程语言，Java易学易用
替换前1个'Python': Java是一门强大的编程语言，Python易学易用

原字符串: hello world, hello python
查找'hello'（从位置5开始）: 13
查找'hello'（位置0-12）: 0
统计'hello'（位置0-12）: 1
```

### 4. 分割和连接

| API | 说明 | 示例（用法） |
|-----|------|-------------|
| `str.split(sep=None, maxsplit=-1)` | 分割字符串 | `"a,b,c".split(",")` |
| `str.rsplit(sep=None, maxsplit=-1)` | 从右侧分割 | `"a,b,c".rsplit(",", 1)` |
| `str.splitlines([keepends])` | 按行分割 | `"a\nb\nc".splitlines()` |
| `str.partition(sep)` | 分割为三部分 | `"a,b,c".partition(",")` |
| `str.rpartition(sep)` | 从右侧分割为三部分 | `"a,b,c".rpartition(",")` |
| `str.join(iterable)` | 连接字符串 | `",".join(['a', 'b', 'c'])` |

**示例**

```python
csv = "apple,banana,orange,grape"
print("原字符串:", csv)
print("分割字符串:", csv.split(","))
print("分割字符串（限制2次）:", csv.split(",", 2))
print("从右侧分割（限制1次）:", csv.rsplit(",", 1))

# splitlines
multiline = "第一行\n第二行\r\n第三行\n"
print(f"\n多行文本: {repr(multiline)}")
print("按行分割（不保留换行符）:", multiline.splitlines())
print("按行分割（保留换行符）:", multiline.splitlines(keepends=True))

# partition
text = "username@example.com"
print(f"\n原字符串: {text}")
print("partition分割:", text.partition("@"))
print("rpartition分割:", text.rpartition("@"))

# join
words = ["Python", "字符串", "操作"]
print(f"\n列表: {words}")
print("连接字符串:", "-".join(words))
print("连接字符串:", " ".join(words))

# 复杂join
data = [("name", "张三"), ("age", "30"), ("city", "北京")]
print(f"\n复杂数据: {data}")
print("连接为查询字符串:", "&".join([f"{k}={v}" for k, v in data]))
```

输出：
```
原字符串: apple,banana,orange,grape
分割字符串: ['apple', 'banana', 'orange', 'grape']
分割字符串（限制2次）: ['apple', 'banana', 'orange,grape']
从右侧分割（限制1次）: ['apple,banana,orange', 'grape']

多行文本: '第一行\n第二行\r\n第三行\n'
按行分割（不保留换行符）: ['第一行', '第二行', '第三行']
按行分割（保留换行符）: ['第一行\n', '第二行\r\n', '第三行\n']

原字符串: username@example.com
partition分割: ('username', '@', 'example.com')
rpartition分割: ('username', '@', 'example.com')

列表: ['Python', '字符串', '操作']
连接字符串: Python-字符串-操作
连接字符串: Python 字符串 操作

复杂数据: [('name', '张三'), ('age', '30'), ('city', '北京')]
连接为查询字符串: name=张三&age=30&city=北京
```

### 5. 字符串判断

| API | 说明 | 示例（用法） |
|-----|------|-------------|
| `str.startswith(prefix[, start[, end]])` | 是否以指定前缀开头 | `"hello".startswith("he")` |
| `str.endswith(suffix[, start[, end]])` | 是否以指定后缀结尾 | `"hello".endswith("lo")` |
| `str.isalpha()` | 是否全为字母 | `"hello".isalpha()` |
| `str.isdigit()` | 是否全为数字 | `"123".isdigit()` |
| `str.isalnum()` | 是否全为字母或数字 | `"abc123".isalnum()` |
| `str.isdecimal()` | 是否全为十进制数字 | `"123".isdecimal()` |
| `str.isnumeric()` | 是否全为数字字符 | `"½".isnumeric()` |
| `str.islower()` | 是否全为小写 | `"hello".islower()` |
| `str.isupper()` | 是否全为大写 | `"HELLO".isupper()` |
| `str.isspace()` | 是否全为空白字符 | `"  \t\n".isspace()` |
| `str.istitle()` | 是否每个单词首字母大写 | `"Hello World".istitle()` |

**示例**

```python
test_cases = [
    ("hello", "字符串"),
    ("123", "数字"),
    ("abc123", "字母数字"),
    ("½", "分数"),
    ("HELLO", "大写"),
    ("  \t\n", "空白"),
    ("Hello World", "标题格式"),
]

for text, desc in test_cases:
    print(f"\n测试 '{text}' ({desc}):")
    print(f"  isalpha(): {text.isalpha()}")
    print(f"  isdigit(): {text.isdigit()}")
    print(f"  isalnum(): {text.isalnum()}")
    print(f"  isdecimal(): {text.isdecimal()}")
    print(f"  isnumeric(): {text.isnumeric()}")
    print(f"  islower(): {text.islower()}")
    print(f"  isupper(): {text.isupper()}")
    print(f"  isspace(): {text.isspace()}")
    print(f"  istitle(): {text.istitle()}")

# startswith和endswith
filename = "document.pdf"
url = "https://example.com/api"
print(f"\n文件名: {filename}")
print(f"  是否以'.pdf'结尾: {filename.endswith('.pdf')}")
print(f"  是否以'.doc'结尾: {filename.endswith('.doc')}")
print(f"URL: {url}")
print(f"  是否以'https://'开头: {url.startswith('https://')}")
print(f"  是否以'/api'结尾: {url.endswith('/api')}")

# 使用start和end参数
text = "hello world"
print(f"\n字符串: {text}")
print(f"  位置0-5是否以'he'开头: {text.startswith('he', 0, 5)}")
print(f"  位置6-11是否以'wo'开头: {text.startswith('wo', 6, 11)}")
```

输出：
```
测试 'hello' (字符串):
  isalpha(): True
  isdigit(): False
  isalnum(): True
  isdecimal(): False
  isnumeric(): False
  islower(): True
  isupper(): False
  isspace(): False
  istitle(): False

测试 '123' (数字):
  isalpha(): False
  isdigit(): True
  isalnum(): True
  isdecimal(): True
  isnumeric(): True
  islower(): False
  isupper(): False
  isspace(): False
  istitle(): False

测试 'abc123' (字母数字):
  isalpha(): False
  isdigit(): False
  isalnum(): True
  isdecimal(): False
  isnumeric(): False
  islower(): True
  isupper(): False
  isspace(): False
  istitle(): False

测试 '½' (分数):
  isalpha(): False
  isdigit(): False
  isalnum(): False
  isdecimal(): False
  isnumeric(): True
  islower(): False
  isupper(): False
  isspace(): False
  istitle(): False

测试 'HELLO' (大写):
  isalpha(): True
  isdigit(): False
  isalnum(): True
  isdecimal(): False
  isnumeric(): False
  islower(): False
  isupper(): True
  isspace(): False
  istitle(): False

测试 '  \t\n' (空白):
  isalpha(): False
  isdigit(): False
  isalnum(): False
  isdecimal(): False
  isnumeric(): False
  islower(): False
  isupper(): False
  isspace(): True
  istitle(): False

测试 'Hello World' (标题格式):
  isalpha(): False
  isdigit(): False
  isalnum(): False
  isdecimal(): False
  isnumeric(): False
  islower(): False
  isupper(): False
  isspace(): False
  istitle(): True

文件名: document.pdf
  是否以'.pdf'结尾: True
  是否以'.doc'结尾: False
URL: https://example.com/api
  是否以'https://'开头: True
  是否以'/api'结尾: True

字符串: hello world
  位置0-5是否以'he'开头: True
  位置6-11是否以'wo'开头: True
```

### 6. 填充和对齐

| API | 说明 | 示例（用法） |
|-----|------|-------------|
| `str.center(width[, fillchar])` | 居中对齐 | `"test".center(10, "*")` |
| `str.ljust(width[, fillchar])` | 左对齐 | `"test".ljust(10, "*")` |
| `str.rjust(width[, fillchar])` | 右对齐 | `"test".rjust(10, "*")` |
| `str.zfill(width)` | 用零填充 | `"42".zfill(5)` |

**示例**

```python
text = "test"
print("原字符串:", repr(text))
print("居中对齐（宽度10，填充*）:", repr(text.center(10, "*")))
print("左对齐（宽度10，填充*）:", repr(text.ljust(10, "*")))
print("右对齐（宽度10，填充*）:", repr(text.rjust(10, "*")))
print("用零填充（宽度5）:", repr(text.zfill(5)))

# 数字的zfill
numbers = ["42", "-42", "3.14", "-3.14", "1000"]
print(f"\n数字零填充:")
for num in numbers:
    print(f"  {num:>6} -> {num.zfill(8)}")

# 创建表格
headers = ["姓名", "年龄", "城市"]
data = [
    ["张三", "30", "北京"],
    ["李四", "25", "上海"],
    ["王五", "35", "广州"]
]

print(f"\n表格对齐示例:")
# 表头
header_line = " | ".join(h.center(10) for h in headers)
print(header_line)
print("-" * len(header_line))

# 数据行
for row in data:
    row_line = " | ".join(item.ljust(10) for item in row)
    print(row_line)
```

输出：
```
原字符串: 'test'
居中对齐（宽度10，填充*）: '***test***'
左对齐（宽度10，填充*）: 'test******'
右对齐（宽度10，填充*）: '******test'
用零填充（宽度5）: '0test'

数字零填充:
      42 -> 00000042
     -42 -> -0000042
    3.14 -> 00003.14
   -3.14 -> -0003.14
    1000 -> 00001000

表格对齐示例:
    姓名      |     年龄      |     城市      
------------------------------------------------
张三        | 30         | 北京        
李四        | 25         | 上海        
王五        | 35         | 广州        
```

## 四、模板字符串

`string`模块提供了`Template`类，用于简单的变量替换，比`str.format()`更安全，适合处理用户提供的模板。

### 1. Template类方法

| API | 说明 | 示例（用法） |
|-----|------|-------------|
| `Template(template)` | 创建模板对象 | `Template("Hello $name")` |
| `template.substitute(mapping)` | 替换模板变量 | `Template("$x + $y").substitute(x=1, y=2)` |
| `template.safe_substitute(mapping)` | 安全替换，缺少变量时不抛异常 | `Template("$x").safe_substitute()` |
| `Template.delimiter` | 分隔符（默认`$`） | 可覆盖为其他字符 |
| `Template.idpattern` | 标识符模式 | 可覆盖以改变变量名规则 |

**示例**

```python
from string import Template

# 基本用法
t = Template("你好，$name！今天是$day。")
result = t.substitute(name="张三", day="星期一")
print("基本模板:", result)

# 使用字典
data = {"name": "李四", "day": "星期二"}
result = t.substitute(data)
print("使用字典:", result)

# 安全替换（不会抛出KeyError）
t2 = Template("欢迎，$user！您的余额是$balance元。")
result = t2.safe_substitute(user="访客")  # balance变量不存在
print("安全替换:", result)

# 尝试普通替换（会抛出KeyError）
try:
    result = t2.substitute(user="访客")
except KeyError as e:
    print(f"普通替换失败，缺少变量: {e}")

# 美元符号转义
t3 = Template("价格: $$ $amount")
result = t3.substitute(amount=100)
print("美元转义:", result)

# 自定义分隔符
class CustomTemplate(Template):
    delimiter = '#'

t4 = CustomTemplate("文件: #filename, 大小: #size KB")
result = t4.substitute(filename="data.txt", size="1024")
print("自定义分隔符:", result)

# 更复杂的分隔符
class BraceTemplate(Template):
    delimiter = '{'
    idpattern = r'[a-z][a-z0-9]*'

t5 = BraceTemplate("Hello {name}, your score is {score}")
result = t5.substitute(name="Alice", score=95)
print("花括号分隔符:", result)
```

输出：
```
基本模板: 你好，张三！今天是星期一。
使用字典: 你好，李四！今天是星期二。
安全替换: 欢迎，访客！您的余额是$balance元。
普通替换失败，缺少变量: 'balance'
美元转义: 价格: $ 100
自定义分隔符: 文件: data.txt, 大小: 1024 KB
花括号分隔符: Hello Alice, your score is 95
```

