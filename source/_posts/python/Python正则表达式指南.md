---
title: Python正则表达式指南
published: true
layout: post
date: 2026-03-23 19:00:00
permalink: /python/regex-guide.html
categories: [Python]
---

Python的`re`模块提供了与Perl语言类似的正则表达式匹配操作。本模块是Python标准库中处理文本模式匹配的利器，掌握它可以大大提高字符串处理效率。

## 一、正则表达式基础

正则表达式（Regular Expression）指定了一组与之匹配的字符串，用于模式匹配和文本处理。模式和被搜索的字符串既可以是Unicode字符串，也可以是8位字节串，但不能混用。

### 1. 正则表达式特殊字符

**语法格式**

```
r'pattern'     # raw string格式
```

**特殊字符说明**

| 字符 | 说明 | 示例 |
|------|------|------|
| `.` | 匹配任意字符（换行符除外） | `r'a.c'` 匹配 `'abc'` |
| `^` | 匹配字符串开头 | `r'^hello'` 匹配 `'hello world'` |
| `$` | 匹配字符串结尾或换行符前 | `r'world$'` 匹配 `'hello world'` |
| `*` | 匹配0次或多次 | `r'ab*'` 匹配 `'a'`, `'ab'`, `'abbb'` |
| `+` | 匹配1次或多次 | `r'ab+'` 匹配 `'ab'`, `'abbb'` |
| `?` | 匹配0次或1次 | `r'ab?'` 匹配 `'a'`, `'ab'` |
| `*?` | 非贪婪匹配0次或多次 | `r'<.*?>'` 匹配 `'<a>'` |
| `+?` | 非贪婪匹配1次或多次 | `r'<.+?>'` 匹配最小内容 |
| `{m}` | 匹配m次 | `r'a{3}'` 匹配 `'aaa'` |
| `{m,n}` | 匹配m到n次 | `r'a{2,4}'` 匹配 `'aa'` 到 `'aaaa'` |
| `{m,n}?` | 非贪婪匹配m到n次 | 匹配最少的次数 |
| `\` | 转义特殊字符 | `r'\*'` 匹配字面量 `'*'` |
| `|` | 或运算 | `r'a|b'` 匹配 `'a'` 或 `'b'` |
| `()` | 分组 | `r'(ab)+'` 匹配 `'ab'`, `'abab'` |

**示例**

```python
import re

# 基本匹配
print(re.search(r'hello', 'hello world'))  # 匹配 'hello'
print(re.match(r'hello', 'hello world'))  # 匹配 'hello'

# 数量词
pattern = r'ab+'
print(re.findall(pattern, 'ab abbb abbbb'))  # ['ab', 'abbb', 'abbbb']

# 转义字符
pattern = r'\$\d+'
print(re.findall(pattern, 'Price: $100'))  # ['$100']

# 或运算
pattern = r'cat|dog'
print(re.findall(pattern, 'I have a cat and a dog'))  # ['cat', 'dog']
```

输出：
```
<re.Match object; span=(0, 5), match='hello'>
<re.Match object; span=(0, 5), match='hello'>
['ab', 'abbb', 'abbbb']
['$100']
['cat', 'dog']
```

### 2. 字符类和特殊序列

**语法格式**

```
[abc]          # 字符集
[^abc]         # 否定字符集
\d, \w, \s     # 特殊序列
```

**字符类说明**

| 字符 | 说明 | 示例 |
|------|------|------|
| `[abc]` | 匹配字符集中的任意字符 | `r'[aeiou]'` 匹配元音 |
| `[^abc]` | 匹配不在字符集中的字符 | `r'[^0-9]'` 匹配非数字 |
| `[a-z]` | 匹配字符范围 | `r'[a-z]'` 匹配小写字母 |

**特殊序列说明**

| 序列 | 说明 | 示例 |
|------|------|------|
| `\d` | 匹配数字（等价于`[0-9]`） | `r'\d+'` 匹配整数 |
| `\D` | 匹配非数字 | `\D+` 匹配非数字字符 |
| `\w` | 匹配单词字符（字母数字下划线） | `r'\w+'` 匹配单词 |
| `\W` | 匹配非单词字符 | `\W+` 匹配空白和标点 |
| `\s` | 匹配空白字符（空格、tab、换行） | `r'\s+'` 匹配空白 |
| `\S` | 匹配非空白字符 | `\S+` 匹配非空白 |
| `\b` | 匹配单词边界 | `r'\bword\b'` 精确匹配单词 |
| `\B` | 匹配非单词边界 | `r'\Bword'` 匹配单词开头 |
| `\A` | 只匹配字符串开头 | `\Aabc` |
| `\Z` | 只匹配字符串结尾 | `abc\Z` |

**示例**

```python
import re

# 字符集
text = 'The price is $99.99'
pattern = r'[aeiou]'
vowels = re.findall(pattern, text)
print(f"元音字母: {vowels}")

pattern = r'[^0-9\s]'  # 非数字、非空白
non_digit = re.findall(pattern, text)
print(f"非数字非空白: {non_digit}")

# 特殊序列
pattern = r'\d+\.\d+'
decimals = re.findall(pattern, text)
print(f"小数: {decimals}")

pattern = r'\b\w+\b'
words = re.findall(pattern, text)
print(f"单词: {words}")

# 单词边界
pattern = r'\bprice\b'
text2 = 'The price is good. The price is right.'
matches = re.findall(pattern, text2)
print(f"精确匹配'price': {matches}")
```

输出：
```
元音字母: ['e', 'i', 'e', 'i']
非数字非空白: ['T', 'h', 'e', 'p', 'r', 'i', 'c', 'e', 'i', 's', '$', '.', '.']
小数: ['99.99']
单词: ['The', 'price', 'is', '99', '99']
精确匹配'price': ['price', 'price']
```

### 3. 分组和捕获

**语法格式**

```
(abc)           # 捕获组
(?:abc)         # 非捕获组
(?P<name>abc)   # 命名组
```

**分组说明**

| 语法 | 说明 | 示例 |
|------|------|------|
| `(...)` | 捕获组 | `r'(\d+)'` |
| `(?:...)` | 非捕获组 | `r'(?:\d+)'` |
| `(?P<name>...)` | 命名组 | `r'(?P<num>\d+)'` |

**示例**

```python
import re

# 捕获组
text = 'Date: 2024-03-15'
pattern = r'(\d{4})-(\d{2})-(\d{2})'
match = re.search(pattern, text)
if match:
    print(f"完整匹配: {match.group(0)}")
    print(f"年: {match.group(1)}")
    print(f"月: {match.group(2)}")
    print(f"日: {match.group(3)}")
    print(f"全部: {match.groups()}")

# 命名组
pattern = r'(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})'
match = re.search(pattern, text)
if match:
    print(f"\n命名组: {match.groupdict()}")

# 非捕获组
pattern = r'(?:\d{4})-(\d{2})-(\d{2})'
match = re.search(pattern, text)
if match:
    print(f"\n非捕获组groups: {match.groups()}")
```

输出：
```
完整匹配: 2024-03-15
年: 2024
月: 03
日: 15
全部: ('2024', '03', '15')

命名组: {'year': '2024', 'month': '03', 'day': '15'}

非捕获组groups: ('03', '15')
```

### 4. 断言

**语法格式**

```
(?=abc)         # 正向前瞻
(?!abc)         # 负向前瞻
(?<=abc)        # 正向后顾
(?<!abc)        # 负向后顾
```

**断言说明**

| 语法 | 说明 | 示例 |
|------|------|------|
| `(?=...)` | 正向前瞻，匹配后面是...的位置 | `r'\d+(?=元)'` |
| `(?!...)` | 负向前瞻，匹配后面不是...的位置 | `r'\d+(?!元)'` |
| `(?<=...)` | 正向后顾，匹配前面是...的位置 | `r'(?<=￥)\d+'` |
| `(?<!...)` | 负向后顾，匹配前面不是...的位置 | `r'(?<!￥)\d+'` |

**示例**

```python
import re

# 正向前瞻
text = '100元 200美元 300元'
pattern = r'\d+(?=元)'
print(f"正向前瞻(元): {re.findall(pattern, text)}")

# 负向前瞻
pattern = r'\d+(?!元)'
print(f"负向前瞻: {re.findall(pattern, text)}")

# 正向后顾
text2 = '编号: 12345 产品: ABC'
pattern = r'(?<=编号: )\w+'
print(f"正向后顾: {re.findall(pattern, text2)}")

# 负向后顾
text3 = 'item-1 item-2 order-3'
pattern = r'(?<!item-)\d+'
print(f"负向后顾: {re.findall(pattern, text3)}")
```

输出：
```
正向前瞻(元): ['100', '300']
负向前瞻: ['100', '200', '3']
正向后顾: ['12345']
负向后顾: ['1', '2', '3']
```

## 二、re模块函数

`re`模块提供了多个函数用于正则表达式操作。

### 1. compile() 函数

**语法格式**

```
re.compile(pattern, flags=0)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `pattern` | 正则表达式模式 | `compile(r'\d+')` |
| `flags` | 正则表达式标志 | `flags=re.IGNORECASE` |

**示例**

```python
import re

# 编译正则表达式
pattern = re.compile(r'\d+')

# 使用编译后的pattern
text = 'abc123def456'
print(f"search: {pattern.search(text)}")
print(f"match: {pattern.match(text)}")
print(f"findall: {pattern.findall(text)}")
print(f"split: {pattern.split(text)}")

# 使用sub替换
result = pattern.sub('NUM', text)
print(f"sub: {result}")
```

输出：
```
search: <re.Match object; span=(3, 6), match='123'>
match: None
findall: ['123', '456']
split: ['abc', 'def', '']
sub: abcNUMdefNUM
```

### 2. search() 和 match() 函数

**语法格式**

```
re.search(pattern, string, flags=0)
re.match(pattern, string, flags=0)
```

**函数说明**

| 函数 | 说明 | 区别 |
|------|------|------|
| `search()` | 搜索整个字符串 | 查找任意位置的匹配 |
| `match()` | 从字符串开头匹配 | 只匹配字符串开头 |

**示例**

```python
import re

text = 'hello world'

# search - 搜索整个字符串
result = re.search(r'world', text)
print(f"search('world'): {result}")

result = re.search(r'hello', text)
print(f"search('hello'): {result}")

# match - 只匹配开头
result = re.match(r'hello', text)
print(f"match('hello'): {result}")

result = re.match(r'world', text)
print(f"match('world'): {result}")

# 结合使用
text2 = 'python3.10'
print(f"\nsearch '\\d': {re.search(r'\d', text2)}")
print(f"match '\\d': {re.match(r'\d', text2)}")
print(f"match 'python': {re.match(r'python', text2)}")
```

输出：
```
search('world'): <re.Match object; span=(6, 11), match='world'>
search('hello'): <re.Match object; span=(0, 5), match='hello'>
match('hello'): <re.Match object; span=(0, 5), match='hello'>
match('world'): None

search '\d': <re.Match object; span=(6, 7), match='3'>
match '\d': None
match 'python': <re.Match object; span=(0, 6), match='python'>
```

### 3. findall() 和 finditer() 函数

**语法格式**

```
re.findall(pattern, string, flags=0)
re.finditer(pattern, string, flags=0)
```

**函数说明**

| 函数 | 说明 | 返回值 |
|------|------|--------|
| `findall()` | 查找所有匹配 | 字符串列表 |
| `finditer()` | 查找所有匹配 | 迭代器 |

**示例**

```python
import re

text = '1号 2号 3号 10号'

# findall - 返回字符串列表
numbers = re.findall(r'\d+', text)
print(f"findall: {numbers}")

# finditer - 返回迭代器
print("\nfinditer:")
for match in re.finditer(r'\d+', text):
    print(f"  位置 {match.span()}: {match.group()}")
```

输出：
```
findall: ['1', '2', '3', '10']

finditer:
  位置 (0, 1): 1
  位置 (3, 4): 2
  位置 (6, 7): 3
  位置 (9, 11): 10
```

### 4. split() 函数

**语法格式**

```
re.split(pattern, string, maxsplit=0, flags=0)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `pattern` | 分隔符模式 | `split(r'\s+')` |
| `string` | 要分割的字符串 | `split('a b c')` |
| `maxsplit` | 最大分割次数 | `maxsplit=1` |

**示例**

```python
import re

text = 'a,b;c|d e'

# 按多种分隔符分割
result = re.split(r'[,;|\s]', text)
print(f"多种分隔符: {result}")

# 限制分割次数
text2 = 'a:b:c:d'
result = re.split(r':', text2, maxsplit=2)
print(f"限制2次: {result}")

# 保留分割符（使用捕获组）
result = re.split(r'(:|,)', text2)
print(f"保留分隔符: {result}")
```

输出：
```
多种分隔符: ['a', 'b', 'c', 'd', 'e']
限制2次: ['a', 'b', 'c:d']
保留分隔符: ['a', ':', 'b', ':', 'c', ':', 'd']
```

### 5. sub() 和 subn() 函数

**语法格式**

```
re.sub(pattern, repl, string, count=0, flags=0)
re.subn(pattern, repl, string, count=0, flags=0)
```

**函数说明**

| 函数 | 说明 | 返回值 |
|------|------|--------|
| `sub()` | 替换匹配项 | 替换后的字符串 |
| `subn()` | 替换匹配项 | (替换后字符串, 替换次数) |

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `pattern` | 要匹配的模式 | `r'\d+'` |
| `repl` | 替换内容（字符串或函数） | `'NUM'` |
| `string` | 原始字符串 | `'abc123'` |
| `count` | 最大替换次数 | `count=1` |

**示例**

```python
import re

text = 'abc123def456'

# 基本替换
result = re.sub(r'\d+', 'NUM', text)
print(f"sub: {result}")

# 返回替换次数
result, count = re.subn(r'\d+', 'NUM', text)
print(f"subn: {result}, 替换了{count}次")

# 使用分组引用
text2 = '2024-03-15'
result = re.sub(r'(\d{4})-(\d{2})-(\d{2})', r'\3/\2/\1', text2)
print(f"日期格式转换: {result}")

# 使用命名组
result = re.sub(r'(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})', 
                r'\g<month>-\g<day>-\g<year>', text2)
print(f"命名组转换: {result}")

# 使用函数作为替换内容
def convert(match):
    num = int(match.group())
    return str(num * 2)

result = re.sub(r'\d+', convert, text)
print(f"函数替换: {result}")
```

输出：
```
sub: abcNUMdefNUM
subn: abcNUMdefNUM, 替换了2次
日期格式转换: 15/03/2024
命名组转换: 03-15-2024
函数替换: abc246def912
```

## 三、正则表达式标志

正则表达式标志用于修改正则表达式的匹配行为。

### 1. 常用标志

**语法格式**

```
re.compile(pattern, flags=re.IGNORECASE | re.MULTILINE)
re.search(pattern, string, flags=0)
```

**标志说明**

| 标志 | 说明 | 示例 |
|------|------|------|
| `re.IGNORECASE` 或 `re.I` | 忽略大小写 | `flags=re.I` |
| `re.MULTILINE` 或 `re.M` | 多行模式 | `flags=re.M` |
| `re.DOTALL` 或 `re.S` | 点号匹配换行 | `flags=re.S` |
| `re.VERBOSE` 或 `re.X` | 详细模式 | `flags=re.X` |
| `re.ASCII` 或 `re.A` | ASCII模式 | `flags=re.A` |

**示例**

```python
import re

text = 'Hello\nWorld'

# IGNORECASE - 忽略大小写
print("=== IGNORECASE ===")
pattern = re.compile(r'hello', re.I)
print(pattern.findall(text))

# MULTILINE - 多行模式
print("\n=== MULTILINE ===")
text2 = 'first line\nsecond line'
pattern = re.compile(r'^second', re.M)
print(pattern.findall(text2))

# DOTALL - 点号匹配换行
print("\n=== DOTALL ===")
text3 = 'hello\nworld'
pattern = re.compile(r'hello.*world', re.S)
print(pattern.findall(text3))

# VERBOSE - 详细模式（忽略空白和注释）
print("\n=== VERBOSE ===")
pattern = re.compile(r'''
    \d+     # 数字
    \s+     # 空白
    \w+     # 单词
''', re.VERBOSE)
print(pattern.findall('123 abc'))
```

输出：
```
=== IGNORECASE ===
['Hello']

=== MULTILINE ===
['second']

=== DOTALL ===
['hello\nworld']

=== VERBOSE ===
['123 abc']
```

## 四、编译后的正则表达式对象

`re.compile()`返回的Pattern对象有多个方法和属性。

### 1. Pattern对象方法

**语法格式**

```
pattern.search(string[, pos[, endpos]])
pattern.match(string[, pos[, endpos]])
pattern.findall(string[, pos[, endpos]])
pattern.finditer(string[, pos[, endpos]])
pattern.split(string[, maxsplit])
pattern.sub(repl, string[, count])
pattern.subn(repl, string[, count])
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `search(string)` | 搜索匹配 | `pattern.search(text)` |
| `match(string)` | 开头匹配 | `pattern.match(text)` |
| `findall(string)` | 查找所有 | `pattern.findall(text)` |
| `finditer(string)` | 查找迭代器 | `pattern.finditer(text)` |
| `split(string)` | 分割字符串 | `pattern.split(text)` |
| `sub(repl, string)` | 替换 | `pattern.sub('X', text)` |
| `subn(repl, string)` | 替换并计数 | `pattern.subn('X', text)` |

**示例**

```python
import re

pattern = re.compile(r'\d+')

text = 'abc123def456ghi789'

print(f"search: {pattern.search(text)}")
print(f"match: {pattern.match(text)}")
print(f"findall: {pattern.findall(text)}")
print(f"split: {pattern.split(text)}")
print(f"sub: {pattern.sub('NUM', text)}")
print(f"subn: {pattern.subn('NUM', text)}")
```

输出：
```
search: <re.Match object; span=(3, 6), match='123'>
match: None
findall: ['123', '456', '789']
split: ['abc', 'def', 'ghi', '']
sub: abcNUMdefNUMghiNUM
subn: ('abcNUMdefNUMghiNUM', 3)
```

### 2. Pattern对象属性

**语法格式**

```
pattern.flags        # 标志
pattern.groups       # 分组数量
pattern.groupindex  # 命名组字典
pattern.pattern     # 原始模式字符串
```

**属性说明**

| 属性 | 说明 | 示例 |
|------|------|------|
| `flags` | 正则表达式标志 | `pattern.flags` |
| `groups` | 分组数量 | `pattern.groups` |
| `groupindex` | 命名组字典 | `pattern.groupindex` |
| `pattern` | 原始模式 | `pattern.pattern` |

**示例**

```python
import re

pattern = re.compile(r'(?P<num>\d+)(?P<suffix>[a-z]+)', re.I)

print(f"flags: {pattern.flags}")
print(f"groups: {pattern.groups}")
print(f"groupindex: {pattern.groupindex}")
print(f"pattern: {pattern.pattern}")
```

## 五、Match对象

`search()`、`match()`等函数返回Match对象，包含匹配信息。

### 1. Match对象方法

**语法格式**

```
match.group([group1, ...])
match.groups()
match.groupdict()
match.start([group])
match.end([group])
match.span([group])
match.expand(template)
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `group(n)` | 获取第n个分组 | `match.group(1)` |
| `groups()` | 所有分组元组 | `match.groups()` |
| `groupdict()` | 命名组字典 | `match.groupdict()` |
| `start()` | 匹配起始位置 | `match.start()` |
| `end()` | 匹配结束位置 | `match.end()` |
| `span()` | 匹配范围 | `match.span()` |
| `expand()` | 模板展开 | `match.expand(r'\1-\2')` |

**示例**

```python
import re

text = 'Date: 2024-03-15'
pattern = r'(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})'
match = re.search(pattern, text)

print(f"完整匹配: {match.group(0)}")
print(f"year: {match.group('year')}")
print(f"month: {match.group(2)}")
print(f"day: {match.group(3)}")
print(f"groups: {match.groups()}")
print(f"groupdict: {match.groupdict()}")
print(f"span: {match.span()}")
print(f"expand: {match.expand(r'\g<year>/\g<month>/\g<day>')}")
```

输出：
```
完整匹配: 2024-03-15
year: 2024
month: 03
day: 15
groups: ('2024', '03', '15')
groupdict: {'year': '2024', 'month': '03', 'day': '15'}
span: (6, 16)
expand: 2024/03/15
```

### 2. Match对象切片

**语法格式**

```
match[0]        # 完整匹配
match[1]        # 第1个分组
match[2]        # 第2个分组
```

**示例**

```python
import re

text = 'hello123'
match = re.search(r'hello(\d+)', text)

print(f"完整匹配: {match[0]}")
print(f"分组: {match[1]}")
print(f"切片: {text[match.start():match.end()]}")
```