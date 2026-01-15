---
title: Python常用内置数据类型API示例
published: true
layout: post
date: 2026-01-15 19:00:00
permalink: /python/inner_data_type_api.html
categories: [Python]
---



## 一、文本字符串

在 Python 中处理文本数据是使用 [`str`](https://docs.python.org/zh-cn/3.14/library/stdtypes.html#str) 对象，也称为 *字符串*。

字符串字面值有多种不同的写法：

- 单引号: `'允许包含有 "双" 引号'`
- 双引号: `"允许嵌入 '单' 引号"`
- 三重引号: `'''三重单引号'''`, `"""三重双引号"""`，使用三重引号的字符串可以跨越多行 —— 其中所有的空白字符都将包含在该字符串字面值中。

在`Python`中没有强制要求使用哪种，建议整体风格上统一，或者字符串本身包含单引号或者双引号时，选择一个合适的。

| 场景                       | 推荐使用                                                     |
| -------------------------- | ------------------------------------------------------------ |
| 字符串内部包含单引号 (`'`) | 用双引号包裹 (`"…"`)                                         |
| 字符串内部包含双引号 (`"`) | 用单引号包裹 (`'…'`)                                         |
| 字符串两侧都不包含引号     | 个人/项目习惯，建议整体上风格统一                            |
| 多行文本 / 文档字符串      | 用 **三引号** (`"""…"""` 或 `'''…'''`)（常用三重双引号用于 docstrings） |



```python
a = 'a'
b = "b"
c = '''
    This 
    is 
    a multi-line 
    string
    '''
```



### 1、字符串前缀

字符串字面量可以有一个可选的 *前缀*，该前缀会影响字面量内容的解析方式，例如:

```
b"data"
f'{result=}'
```

允许的前缀有:

- `b`: 字节串字面量
- `r`: 原始字符串
- `f`: 格式字符串字面量("f-string")

前缀不区分大小写（例如，'`B`' 与 '`b`' 效果相同）。



#### 1.1 字节串字面量

*字节串字面值* 总是带有 '`b`' 或 '`B`' 前缀；它们会产生 [`bytes`](https://docs.python.org/zh-cn/3.14/library/stdtypes.html#bytes) 类型而不是 [`str`](https://docs.python.org/zh-cn/3.14/library/stdtypes.html#str) 类型的实例。 它们只能包含 ASCII 字符；数值为 128 或以上的字节必须使用转义序列来表示 (通常为 [十六进制字符](https://docs.python.org/zh-cn/3.14/reference/lexical_analysis.html#string-escape-hex) 或 [八进制字符](https://docs.python.org/zh-cn/3.14/reference/lexical_analysis.html#string-escape-oct))



```python
s = b'\x89PNG\r\n\x1a\n'

print(s)          # b'\x89PNG\r\n\x1a\n'
print(type(s))   # <class 'bytes'>
```



#### 1.2 原始字符串

字符串可以选择带有字符 '`r`' 或 '`R`' 作为前缀,这样的构造称为 *原始字符串字面值* ，它会将反斜杠视为字面字符。 简而言之就是使用`r`或`R`作为前缀的字符串，可以不用考虑转义的情况，直接按照表意编写。

常见的转义字符列表

| 转义序列 | 描述                       |
| -------- | -------------------------- |
| `\\`     | 字面反斜杠 `\`             |
| `\'`     | 单引号                     |
| `\"`     | 双引号                     |
| `\n`     | 换行（Line Feed）          |
| `\r`     | 回车（Carriage Return）    |
| `\t`     | 水平制表符（Tab）          |
| `\v`     | 垂直制表符（Vertical Tab） |
| `\b`     | 退格（Backspace）          |
| `\f`     | 换页（Form Feed）          |
| `\a`     | 响铃（Bell/Alert）         |



**普通字符串与`r`前缀原始字符串对比示例：**

```python
# 包含转义字符的普通字符串
normal_string = "Hello,\nWorld!\tThis is a test string with a backslash: \\"

# 原始字符串，不处理转义字符
raw_string = r"Hello,\nWorld!\tThis is a test string with a backslash: \\"
print("Normal String:")
print(normal_string)
print("\nRaw String:")
print(raw_string)
```

输出：

```python
Normal String:
Hello,
World!  This is a test string with a backslash: \

Raw String:
Hello,\nWorld!\tThis is a test string with a backslash: \\
```



#### 1.3 格式字符串字面量

当字符串以 `f` 或 `F` 开头的时候，可以在字符串内通过 `{变量名}` 直接引用外部定义的变量，在引用变量的同时可以进行一定的运算，例如算术运算。

`f`前缀类似于

**语法格式：**

```python
s = f"{vars}"
```

**示例：**

```python
i = 23

s = F"How old is {i}?"
print(s)
a = f"After 5 years, I will be {i + 5}."
print(a)

# 
How old is 23?
After 5 years, I will be 28.
```



### 2、字符串常量

字符串常量需要引入 `string` 模块

| 常量名                   | 描述                          | 包含的字符                                                   |
| ------------------------ | ----------------------------- | ------------------------------------------------------------ |
| `string.ascii_letters`   | 所有 ASCII 字母（大小写混合） | `abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ`       |
| `string.ascii_lowercase` | 所有小写 ASCII 字母           | `abcdefghijklmnopqrstuvwxyz`                                 |
| `string.ascii_uppercase` | 所有大写 ASCII 字母           | `ABCDEFGHIJKLMNOPQRSTUVWXYZ`                                 |
| `string.digits`          | 十进制数字                    | `0123456789`                                                 |
| `string.hexdigits`       | 十六进制数字                  | `0123456789abcdefABCDEF`                                     |
| `string.octdigits`       | 八进制数字                    | `01234567`                                                   |
| `string.punctuation`     | 所有标点符号                  | ``!"#$%&'()*+,-./:;<=>?@[]^_{`                               |
| `string.whitespace`      | 所有空白字符                  | 空格、制表符(`\t`)、换行符(`\n`)、回车(`\r`)、垂直制表符(`\v`)、换页(`\f`) |
| `string.printable`       | 所有可打印字符                | 包含 `digits, ascii_letters, punctuation 和 whitespace`      |



### 3、常用字符串API

| **分类**          | **方法**                        | **说明**                                     |
| ----------------- | ------------------------------- | -------------------------------------------- |
| **大小写转换**    | `capitalize()`                  | 返回首字符大写，其余小写的字符串副本。       |
|                   | `lower()`                       | 所有字符转小写。                             |
|                   | `upper()`                       | 所有字符转大写。                             |
|                   | `swapcase()`                    | 大小写互换。                                 |
|                   | `title()`                       | 每个单词首字母大写，其余小写，空格分割单词。 |
| **查找/定位**     | `find(sub[, start[, end]])`     | 返回子字符串最低索引，未找到返回 -1。        |
|                   | `rfind(sub[, start[, end]])`    | 从右侧返回子字符串最高索引，未找到返回 -1。  |
|                   | `index(sub[, start[, end]])`    | 同 `find()` 但未找到时抛出 `ValueError`。    |
|                   | `rindex(sub[, start[, end]])`   | 同 `rfind()` 但未找到时抛出 `ValueError`。   |
|                   | `count(sub[, start[, end]])`    | 返回子字符串出现次数。                       |
|                   | `startswith()`                  | 判断字符串是否以指定前缀开头                 |
|                   | `endswith()`                    | 判断字符串是否以指定后缀结尾                 |
| **字符串分类**    | `isalnum()`                     | 是否只包含字母或数字（至少一个字符）。       |
|                   | `isalpha()`                     | 是否只包含字母字符。                         |
|                   | `isdecimal()`                   | 是否只包含十进制字符（数字字符）。           |
|                   | `isdigit()`                     | 是否只包含数字字符。                         |
|                   | `isidentifier()`                | 是否是合法 Python 标识符。                   |
|                   | `islower()`                     | 是否所有字母字符均为小写。                   |
|                   | `isnumeric()`                   | 是否只包含数字字符。                         |
|                   | `isprintable()`                 | 是否所有字符均为可打印字符。                 |
|                   | `isspace()`                     | 是否所有字符均为空白字符。                   |
|                   | `istitle()`                     | 是否为标题格式（每字首字母大写）。           |
|                   | `isupper()`                     | 是否所有字母字符均为大写。                   |
| **拆分/连接**     | `split(sep=None, maxsplit=-1)`  | 按分隔符分割为列表。                         |
|                   | `rsplit(sep=None, maxsplit=-1)` | 同 `split()`，从右侧开始分割。               |
|                   | `splitlines([keepends])`        | 按换行拆分为行列表。                         |
|                   | `join(iterable)`                | 用当前字符串作为连接符，连接序列元素。       |
| **替换**          | `replace(old, new[, count])`    | 替换子字符串。                               |
| **去除空白/修剪** | `strip([chars])`                | 去除两侧指定字符（默认空白）。               |
|                   | `lstrip([chars])`               | 去除左侧指定字符。                           |
|                   | `rstrip([chars])`               | 去除右侧指定字符。                           |
|                   | `removeprefix(prefix)`          | 移除指定前缀（若存在）。                     |
|                   | `removesuffix(suffix)`          | 移除指定后缀（若存在）。                     |
| **对齐/填充**     | `center(width[, fillchar])`     | 居中对齐并填充。                             |
|                   | `ljust(width[, fillchar])`      | 左对齐并填充。                               |
|                   | `rjust(width[, fillchar])`      | 右对齐并填充。                               |
| **格式化**        | `format(*args, **kwargs)`       | 字符串格式化方法。                           |



**示例：**

```python
# 字符串api示例
s = "hello, world!"
print(s.upper())          # 转为大写 HELLO, WORLD!
print(s.capitalize())     # 首字母大写 Hello, world!
print(s.replace("world", "Python"))  # 替换字符串 hello, Python!
print(s.split(", "))      # 分割字符串 ['hello', 'world!']
print(s.find("world"))    # 查找子字符串位置 7
print(s.startswith("hello"))  # 检查开头 True
print(s.endswith("!"))    # 检查结尾 True
print(s.strip("!"))      # 去除指定字符 hello, world
print(s.count("o"))      # 计数字符出现次数 2
print(s.isalpha())       # 检查是否全为字母 False
print(s.isdigit())       # 检查是否全为数字 False
print(s.join(["Say", "to", "you"]))  # 连接字符串 Sayhello
print(s.index("world"))  # 查找子字符串位置 7
print(s.title())         # 标题化 Hello, World!
print(s.swapcase())      # 大小写互换 HELLO, WORLD!
print(s.rfind("o"))      # 反向查找子字符串位置 8
print(s.rsplit(", "))    # 反向分割字符串 ['hello', 'world!']
print(s.lstrip("h"))     # 左侧去除指定字符 ello, world
print(s.rstrip("!"))     # 右侧去除指定字符 hello, world
```



## 二、列表 list

在`Python`中，列表`list`可以理解为一个可变的数组，列表中元素类型可以不同，列表支持添加、删除和修改。

**常用API：**

| **分类**             | **方法 / 操作**                 | **说明**                                                     |
| -------------------- | ------------------------------- | ------------------------------------------------------------ |
| **创建/构造**        | `list(iterable)`                | 使用可迭代对象创建新列表，例如 `list("abc")` → `['a','b','c']`。 |
| **添加元素**         | `append(x)`                     | 在列表末尾添加元素 **x**。                                   |
|                      | `extend(iterable)`              | 用可迭代对象中的所有元素扩展列表。                           |
|                      | `insert(i, x)`                  | 在指定索引位置插入元素 **x**。                               |
| **删除元素**         | `remove(x)`                     | 移除列表中第一个匹配项 **x**。                               |
|                      | `pop([i])`                      | 删除并返回指定索引的元素；不指定则弹出最后一个元素。         |
|                      | `clear()`                       | 删除所有元素，等价于 `del a[:]`。                            |
| **查找/统计**        | `index(x[, start[, end]])`      | 返回第一个值为 **x** 的元素的索引；找不到抛出 `ValueError`。 |
|                      | `count(x)`                      | 返回元素 **x** 在列表中出现的次数。                          |
| **重排序与反转**     | `sort(key=None, reverse=False)` | 对列表进行原地排序（可以指定 `key` 和 `reverse` 参数）。     |
|                      | `reverse()`                     | 就地反转列表顺序。                                           |
| **复制**             | `copy()`                        | 返回列表的浅拷贝，等价于切片 `a[:]`。                        |
| **序列操作（通用）** | 索引 `a[i]`                     | 获取或设置第 **i** 个元素（可赋值）。                        |
|                      | 切片 `a[start:end:step]`        | 获取或修改子列表。                                           |
|                      | `len(a)`（内置）                | 返回列表长度（元素数量）。                                   |
|                      | `in` / `not in`                 | 测试成员关系：`x in a` 或 `x not in a`。                     |
|                      | `+`                             | 连接两个列表，返回新列表。                                   |
|                      | `*`                             | 重复列表，返回新列表。                                       |
| **迭代与循环**       | `for item in a:`                | 迭代列表元素。                                               |
| **内置函数支持**     | `min(a)` / `max(a)`             | 返回列表中最小 / 最大元素。                                  |
|                      | `sum(a)`                        | 求列表数值元素之和。                                         |
|                      | `sorted(a)`                     | 返回列表排序后的新列表，不修改原列表。                       |



**切片：是对序列list进行区间截取的操作**

基本切片语法：

```python
sequence[start:stop:step]
```

参数说明：

- **start**：起始索引（包含），可省略，省略表示从头开始。
- **stop**：结束索引（不包含），可省略，省略表示到结尾。
- **step**：步长（步进值），可省略，默认是 `1`（每隔一个取一个）。

简而言之，切片会返回 **从 start 到 stop-1 之间间隔 step 的新序列**。索引可以是负数，表示从末尾索引（如 `-1` 表示最后一个元素）。



**示例：**

```python
# ------------------ 初始化列表 ------------------
print("\n-- 初始化列表 --")
fruits = ["apple", "banana", "cherry"]
print("original:", fruits)

# ------------------ 添加元素 ------------------
print("\n-- 添加元素 append, extend, insert --")
fruits.append("orange")      # append(x)
print("append orange:", fruits)

fruits.extend(["kiwi", "mango"])  # extend(iterable)
print("extend with ['kiwi','mango']:", fruits)

fruits.insert(1, "lemon")    # insert(index, x)
print("insert lemon at index 1:", fruits)

# ------------------ 删除元素 ------------------
print("\n-- 删除元素 remove, pop, clear --")
fruits.remove("banana")      # remove(x)
print("remove 'banana':", fruits)

popped = fruits.pop()        # pop()
print("pop last element:", popped, "; now:", fruits)

popped_idx = fruits.pop(0)   # pop(i)
print("pop index 0:", popped_idx, "; now:", fruits)

tmp = ["a","b","c"]
tmp.clear()                  # clear()
print("clear tmp:", tmp)

# ------------------ 查找和计数 ------------------
print("\n-- 查找和计数 index, count --")
nums = [1, 9, 2, 9, 3]
print("nums:", nums)
print("first index of 9:", nums.index(9))
print("count of 9:", nums.count(9))

# ------------------ 排序与反转 ------------------
print("\n-- 排序与反转 sort, reverse --")
vals = [5, 2, 9, 1, 5]
vals.sort()                 # sort() 就地升序
print("sorted ascending:", vals)
vals.sort(reverse=True)     # sort(reverse=True)
print("sorted descending:", vals)

vals.reverse()              # reverse()
print("reversed:", vals)

# ------------------ 复制与组合 ------------------
print("\n-- 复制与组合 copy, +, * --")
orig = [1, 2, 3]
cpy = orig.copy()           # copy()
cpy.append(4)
print("orig:", orig, "copy with 4:", cpy)

combined = orig + cpy       # 拼接
print("combined orig + cpy:", combined)

mult = ["X"] * 3            # 重复
print("three times ['X']:", mult)

# ------------------ 通用序列操作 ------------------
print("\n-- 通用序列操作 索引/切片/成员/长度 --")
seq = [10, 20, 30, 40, 50]
print("seq[1]:", seq[1])
print("slice seq[1:4]:", seq[1:4])
print("30 in seq?", 30 in seq)
print("100 in seq?", 100 in seq)
print("len(seq):", len(seq))

# ------------------ 与内置函数结合 ------------------
print("\n-- 内置函数 min/max/sum/sorted --")
vals2 = [3, 7, 1, 4, 9]
print("min:", min(vals2))
print("max:", max(vals2))
print("sum:", sum(vals2))
print("sorted new(list):", sorted(vals2))

# ------------------ 当做栈/队列 ------------------
print("\n-- 栈与队列操作示例 --")
stack = []
stack.append("first")
stack.append("next")
print("stack before pop:", stack)
print("pop from stack:", stack.pop())

queue = ["q1","q2","q3"]
print("dequeue:", queue.pop(0))


```



## 三、字典 dict

字典 是一种用于存储 键 —— 值对（key-value pairs） 的容器类型，键必须是 可哈希（immutable，如字符串、数字、元组等） 的对象，字典也是 可变（mutable） 的，可以随时添加、删除或更新元素。



**API:**

| 方法                            | 作用                                                         |
| ------------------------------- | ------------------------------------------------------------ |
| `clear()`                       | 删除字典中所有元素。                                         |
| `copy()`                        | 返回字典的浅拷贝。                                           |
| `fromkeys(iterable, value)`     | 创建一个新字典，用 iterable 的元素作为键，所有键对应同一个 value。 |
| `get(key, default=None)`        | 获取键的值；若键不存在返回默认（不抛出异常）。               |
| `items()`                       | 返回可遍历的 `(key, value)` 视图对象。                       |
| `keys()`                        | 返回所有键的视图对象。                                       |
| `values()`                      | 返回所有值的视图对象。                                       |
| `pop(key[, default])`           | 删除指定 key，并返回对应的值；key 不存在则返回 default 或抛出异常。 |
| `popitem()`                     | 删除并返回**最后插入的一对**（key, value）。                 |
| `setdefault(key, default=None)` | 若 key 不存在则插入，并返回 value；存在则返回已有值。        |
| `update(other)`                 | 用另一个字典或者可迭代的 key:value 对更新当前字典。          |



**示例：**

```python
# -------- 1. 创建字典 --------
print("\n--- 创建字典 ---")
d1 = {}                           # 空字典
d2 = {"name": "Alice", "age": 30}
d3 = dict(city="Tokyo", country="Japan")
d4 = dict([("x", 100), ("y", 200)])
print("d1:", d1)
print("d2:", d2)
print("d3:", d3)
print("d4:", d4)

# -------- 2. 访问获取 --------
print("\n--- 访问获取 ---")
print("d2['name']:", d2["name"])
print("d2.get('age'):", d2.get("age"))
print("d2.get('job', 'None'):", d2.get("job", "None"))

# -------- 3. 添加/更新 --------
print("\n--- 添加/更新 ---")
d2["job"] = "Engineer"    # 添加新键值对
print("添加 job:", d2)
d2.update({"age": 31, "city": "Tokyo"})
print("update:", d2)

# -------- 4. 删除 --------
print("\n--- 删除操作 ---")
removed = d2.pop("job")
print("pop job:", removed, "; now:", d2)
pair = d2.popitem()
print("popitem() returned:", pair, "; now:", d2)
d2["tmp"] = 42
del d2["tmp"]
print("after del tmp:", d2)

# -------- 5. 清空 --------
print("\n--- 清空 clear() ---")
d_clear = {"a": 1, "b": 2}
d_clear.clear()
print("d_clear:", d_clear)

# -------- 6. 查询统计 --------
print("\n--- keys, values, items ---")
d_stat = {"x": 10, "y": 20, "z": 30}
print("keys():", d_stat.keys())
print("values():", d_stat.values())
print("items():", d_stat.items())
print("len:", len(d_stat))
print("y in d_stat?:", "y" in d_stat)

# -------- 7. 复制 --------
print("\n--- 复制 copy() ---")
orig = {"a": 1, "b": 2}
shallow = orig.copy()
print("orig:", orig, "shallow copy:", shallow)

# -------- 8. fromkeys & setdefault --------
print("\n--- fromkeys & setdefault ---")
keys = ["k1", "k2"]
df = dict.fromkeys(keys, 0)
print("fromkeys:", df)
dv = {"a": 100}
print("setdefault existing:", dv.setdefault("a", -1))
print("setdefault new:", dv.setdefault("b", 50), "; dv now:", dv)

# -------- 9. 遍历 --------
print("\n--- 遍历字典 ---")
loop = {"name": "Bob", "age": 24}
for k in loop:
    print("key", k, "->", loop[k])
for k,v in loop.items():
    print("item:", k, "=", v)

```

