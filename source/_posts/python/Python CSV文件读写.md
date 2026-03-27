---
title: Python CSV文件读写
date: 2026-03-23 19:45:00
tags:
  - Python
  - CSV
  - 数据处理
categories:
  - Python
---

CSV（Comma Separated Values）格式是电子表格和数据库中最常见的输入输出文件格式。Python的`csv`模块提供了读取和写入CSV格式表格数据的功能，让程序员可以专注于数据处理而无需关心CSV格式的细节。

## 一、reader和writer对象

`csv`模块的`reader`和`writer`对象用于读取和写入序列形式的数据。

### 1. csv.reader()函数

`csv.reader()`返回一个reader对象，用于读取CSV文件中的行。

**语法格式**

```
csv.reader(csvfile, dialect='excel', **fmtparams)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `csvfile` | CSV文件（必须是可迭代对象） | `csv.reader(f)` |
| `dialect` | CSV变种格式 | `dialect='excel'` |
| `delimiter` | 分隔符 | `delimiter=','` |
| `quotechar` | 引号字符 | `quotechar='"'` |
| `quoting` | 引号模式 | `quoting=csv.QUOTE_MINIMAL` |

**示例**

```python
import csv
import io

# 从字符串读取CSV
csv_data = "name,age,city\nAlice,30,Beijing\nBob,25,Shanghai"
reader = csv.reader(io.StringIO(csv_data))
for row in reader:
    print(row)

print("\n--- 使用自定义分隔符 ---")
# 使用分号作为分隔符
csv_semicolon = "name;age;city\nAlice;30;Beijing\nBob;25;Shanghai"
reader = csv.reader(io.StringIO(csv_semicolon), delimiter=';')
for row in reader:
    print(row)
```

输出：
```
['name', 'age', 'city']
['Alice', '30', 'Beijing']
['Bob', '25', 'Shanghai']

--- 使用自定义分隔符 ---
['name', 'age', 'city']
['Alice', '30', 'Beijing']
['Bob', '25', 'Shanghai']
```

### 2. csv.writer()函数

`csv.writer()`返回一个writer对象，用于将数据写入CSV文件。

**语法格式**

```
csv.writer(csvfile, dialect='excel', **fmtparams)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `csvfile` | CSV文件（必须有write方法） | `csv.writer(f)` |
| `dialect` | CSV变种格式 | `dialect='excel'` |
| `delimiter` | 分隔符 | `delimiter=','` |
| `quotechar` | 引号字符 | `quotechar='"'` |
| `quoting` | 引号模式 | `quoting=csv.QUOTE_ALL` |

**示例**

```python
import csv
import io

# 写入CSV字符串
output = io.StringIO()
writer = csv.writer(output)

# 写入单行
writer.writerow(['Name', 'Age', 'City'])
writer.writerow(['Alice', 30, 'Beijing'])
writer.writerow(['Bob', 25, 'Shanghai'])

# 获取写入的内容
print(output.getvalue())

# 写入多行
print("\n--- 批量写入 ---")
output2 = io.StringIO()
writer2 = csv.writer(output2)
data = [
    ['Product', 'Price', 'Stock'],
    ['Apple', 3.5, 100],
    ['Banana', 2.0, 200]
]
writer2.writerows(data)
print(output2.getvalue())
```

输出：
```
Name,Age,City
Alice,30,Beijing
Bob,25,Shanghai

--- 批量写入 ---
Product,Price,Stock
Apple,3.5,100
Banana,2.0,200
```

### 3. Reader对象属性

**语法格式**

```
reader.dialect        # 变种描述（只读）
reader.line_num      # 已读取的行数
```

**属性说明**

| 属性 | 说明 | 示例 |
|------|------|------|
| `dialect` | 变种描述（只读） | `reader.dialect` |
| `line_num` | 已读取的行数 | `reader.line_num` |

**示例**

```python
import csv
import io

csv_data = "line1\nline2\nline3\nline4"
reader = csv.reader(io.StringIO(csv_data))

print(f"初始行号: {reader.line_num}")
for row in reader:
    print(f"行 {reader.line_num}: {row}")

print(f"\n变种信息: {reader.dialect}")
```

输出：
```
初始行号: 0
行 1: ['line1']
行 2: ['line2']
行 3: ['line3']
行 4: ['line4']

变种信息: excel
```

### 4. Writer对象方法

**语法格式**

```
writer.writerow(row)      # 写入单行
writer.writerows(rows)    # 写入多行
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `writerow(row)` | 写入单行（列表或元组） | `writer.writerow(['A', 'B'])` |
| `writerows(rows)` | 批量写入多行 | `writer.writerows([['A'], ['B']])` |

**示例**

```python
import csv
import io

output = io.StringIO()
writer = csv.writer(output)

# writerow写入单行
writer.writerow(['ID', 'Name', 'Score'])
print("writerow写入:")
print(output.getvalue())

# writerows批量写入
output2 = io.StringIO()
writer2 = csv.writer(output2)
writer2.writerows([
    [1, 'Alice', 95],
    [2, 'Bob', 87],
    [3, 'Charlie', 92]
])
print("writerows批量写入:")
print(output2.getvalue())
```

输出：
```
writerow写入:
ID,Name,Score

writerows批量写入:
1,Alice,95
2,Bob,87
3,Charlie,92
```

## 二、字典形式读写

`DictReader`和`DictWriter`类允许以字典形式读写CSV数据，使用字段名作为键。

### 1. csv.DictReader类

`DictReader`将每行数据映射为一个字典，键由`fieldnames`参数指定。

**语法格式**

```
csv.DictReader(f, fieldnames=None, restkey=None, restval=None, **kwargs)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `f` | CSV文件 | `csv.DictReader(f)` |
| `fieldnames` | 字段名列表 | `fieldnames=['name', 'age']` |
| `restkey` | 多余字段的键名 | `restkey='extra'` |
| `restval` | 缺失字段的值 | `restval='N/A'` |

**示例**

```python
import csv
import io

# 字典形式读取
csv_data = """name,age,city
Alice,30,Beijing
Bob,25,Shanghai
Charlie,35,Guangzhou"""

reader = csv.DictReader(io.StringIO(csv_data))
print("DictReader读取结果:")
for row in reader:
    print(f"  {row}")

# 读取后访问字典
print("\n--- 访问字典值 ---")
reader2 = csv.DictReader(io.StringIO(csv_data))
for row in reader2:
    print(f"  姓名: {row['name']}, 城市: {row['city']}")

# 指定fieldnames
print("\n--- 指定fieldnames ---")
csv_no_header = "Alice,30,Beijing\nBob,25,Shanghai"
reader3 = csv.DictReader(io.StringIO(csv_no_header), fieldnames=['Name', 'Age', 'City'])
for row in reader3:
    print(f"  {row}")
```

输出：
```
DictReader读取结果:
  {'name': 'Alice', 'age': '30', 'city': 'Beijing'}
  {'name': 'Bob', 'age': '25', 'city': 'Shanghai'}
  {'name': 'Charlie', 'age': '35', 'city': 'Guangzhou'}

--- 访问字典值 ---
  姓名: Alice, 城市: Beijing
  姓名: Bob, 城市: Shanghai
  姓名: Charlie, 城市: Guangzhou

--- 指定fieldnames ---
  {'Name': 'Alice', 'Age': '30', 'City': 'Beijing'}
  {'Name': 'Bob', 'Age': '25', 'City': 'Shanghai'}
```

### 2. csv.DictWriter类

`DictWriter`将字典映射到CSV行输出。

**语法格式**

```
csv.DictWriter(f, fieldnames, restval=None, extrasaction='raise', **kwargs)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `f` | CSV文件 | `csv.DictWriter(f, fields)` |
| `fieldnames` | 字段名列表 | `fieldnames=['name', 'age']` |
| `restval` | 缺失字段的值 | `restval='N/A'` |
| `extrasaction` | 额外键操作 | `extrasaction='ignore'` |

**示例**

```python
import csv
import io

# 字典形式写入
output = io.StringIO()
fieldnames = ['name', 'age', 'city']
writer = csv.DictWriter(output, fieldnames=fieldnames)

# 写入表头
writer.writeheader()
print("写入表头:")
print(output.getvalue())

# 写入数据行
writer.writerow({'name': 'Alice', 'age': 30, 'city': 'Beijing'})
writer.writerow({'name': 'Bob', 'age': 25, 'city': 'Shanghai'})
print("写入数据:")
print(output.getvalue())

# 处理缺失字段
print("\n--- 处理缺失字段 ---")
output2 = io.StringIO()
writer2 = csv.DictWriter(output2, fieldnames=['name', 'age', 'city', 'gender'])
writer2.writeheader()
writer2.writerow({'name': 'Alice', 'age': 30})  # 缺少city和gender
print(output2.getvalue())
```

输出：
```
写入表头:
name,age,city

写入数据:
name,age,city
Alice,30,Beijing
Bob,25,Shanghai

--- 处理缺失字段 ---
name,age,city,gender
Alice,30,,
```

### 3. DictWriter.writeheader()方法

**语法格式**

```
writer.writeheader()
```

**示例**

```python
import csv
import io

output = io.StringIO()
fieldnames = ['ID', 'Name', 'Score']
writer = csv.DictWriter(output, fieldnames=fieldnames)

writer.writeheader()
writer.writerow({'ID': 1, 'Name': 'Alice', 'Score': 95})
print(output.getvalue())
```

输出：
```
ID,Name,Score
1,Alice,95
```

## 三、变种与格式参数

`Dialect`类定义了CSV文件的格式属性，包括分隔符、引号处理等。

### 1. 预定义变种

**语法格式**

```
csv.excel          # Excel CSV格式
csv.excel_tab      # Excel制表符分隔
csv.unix_dialect   # UNIX CSV格式
```

**变种说明**

| 变种 | 说明 | 示例 |
|------|------|------|
| `excel` | Excel CSV格式 | `dialect='excel'` |
| `excel_tab` | Excel制表符分隔 | `dialect='excel-tab'` |
| `unix` | UNIX CSV格式 | `dialect='unix'` |

**示例**

```python
import csv

# 查看所有注册的变种
print("注册的变种:", csv.list_dialects())

# 使用excel变种（默认）
print("\n--- excel变种 ---")
print(f"delimiter: {csv.excel.delimiter}")
print(f"quotechar: {csv.excel.quotechar}")

# 使用unix变种
print("\n--- unix变种 ---")
print(f"delimiter: {csv.unix_dialect.delimiter}")
print(f"lineterminator: {csv.unix_dialect.lineterminator}")
```

输出：
```
注册的变种: ['excel', 'excel-tab', 'unix']

--- excel变种 ---
delimiter: ,
quotechar: "

--- unix变种 ---
delimiter: ,
lineterminator: 
```

### 2. 格式参数

**语法格式**

```
csv.reader(csvfile, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL, ...)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `delimiter` | 分隔符（单字符） | `delimiter=','` |
| `doublequote` | 引号内双写引号 | `doublequote=True` |
| `escapechar` | 转义字符 | `escapechar='\\'` |
| `lineterminator` | 行结束符 | `lineterminator='\r\n'` |
| `quotechar` | 引号字符 | `quotechar='"'` |
| `quoting` | 引号模式 | `quoting=csv.QUOTE_ALL` |
| `skipinitialspace` | 忽略分隔符后的空格 | `skipinitialspace=False` |
| `strict` | 输入错误时抛出异常 | `strict=False` |

**示例**

```python
import csv
import io

# 自定义分隔符
print("--- 自定义分隔符 ---")
output = io.StringIO()
writer = csv.writer(output, delimiter=';')
writer.writerow(['A', 'B', 'C'])
print(f"分隔符为';': {output.getvalue()}")

# 使用单引号
print("\n--- 自定义引号 ---")
output3 = io.StringIO()
writer3 = csv.writer(output3, quotechar="'", quoting=csv.QUOTE_ALL)
writer3.writerow(['Hello', 'World'])
print(f"使用单引号: {output3.getvalue()}")

# 自定义转义字符
print("\n--- 自定义转义字符 ---")
output4 = io.StringIO()
writer4 = csv.writer(output4, escapechar='\\', quoting=csv.QUOTE_NONE)
writer4.writerow(['field with, comma', 'another field'])
print(f"使用转义字符: {output4.getvalue()}")
```

输出：
```
--- 自定义分隔符 ---
分隔符为';': A;B;C

--- 自定义引号 ---
使用单引号: 'Hello','World'

--- 自定义转义字符 ---
使用转义字符: field with\, comma,another field
```

### 3. 引号模式常量

**语法格式**

```
csv.QUOTE_ALL       # 所有字段加引号
csv.QUOTE_MINIMAL   # 仅对特殊字符加引号
csv.QUOTE_NONNUMERIC
csv.QUOTE_NONE
csv.QUOTE_NOTNULL
csv.QUOTE_STRINGS
```

**常量说明**

| 常量 | 说明 | 示例 |
|------|------|------|
| `QUOTE_ALL` | 所有字段加引号 | `quoting=csv.QUOTE_ALL` |
| `QUOTE_MINIMAL` | 仅对特殊字符加引号 | `quoting=csv.QUOTE_MINIMAL` |
| `QUOTE_NONNUMERIC` | 非数字字段加引号 | `quoting=csv.QUOTE_NONNUMERIC` |
| `QUOTE_NONE` | 不加引号 | `quoting=csv.QUOTE_NONE` |
| `QUOTE_NOTNULL` | 非None字段加引号 | `quoting=csv.QUOTE_NOTNULL` |
| `QUOTE_STRINGS` | 字符串字段加引号 | `quoting=csv.QUOTE_STRINGS` |

**示例**

```python
import csv
import io

data = ['Normal text', 'Text with, comma', '123', None, '']

print("--- 不同引号模式对比 ---")
modes = [
    ('QUOTE_ALL', csv.QUOTE_ALL),
    ('QUOTE_MINIMAL', csv.QUOTE_MINIMAL),
    ('QUOTE_NONNUMERIC', csv.QUOTE_NONNUMERIC),
    ('QUOTE_NONE', csv.QUOTE_NONE),
]

for name, mode in modes:
    output = io.StringIO()
    writer = csv.writer(output, quoting=mode)
    writer.writerow(data)
    print(f"{name}: {output.getvalue().strip()}")
```

输出：
```
--- 不同引号模式对比 ---
QUOTE_ALL: "Normal text","Text with, comma","123","",""
QUOTE_MINIMAL: Normal text,"Text with, comma",123,,
QUOTE_NONNUMERIC: "Normal text","Text with, comma",123,,
QUOTE_NONE: Normal text,Text with\, comma,123,,
```

## 四、Sniffer类

`Sniffer`类用于推断CSV文件的格式，适用于不知道CSV格式的情况。

### 1. sniff()方法

**语法格式**

```
csv.Sniffer().sniff(sample, delimiters=None)
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `sniff(sample, delimiters)` | 推断CSV格式，返回Dialect对象 | `Sniffer().sniff(data)` |

**示例**

```python
import csv
import io

# 推断分隔符
print("--- 推断格式 ---")
sample1 = "name;age;city\nAlice;30;Beijing\nBob;25;Shanghai"
dialect = csv.Sniffer().sniff(sample1, delimiters=';,')
print(f"推断的分隔符: '{dialect.delimiter}'")

# 实际使用
print("\n--- 实际使用推断的格式 ---")
reader = csv.reader(io.StringIO(sample1), dialect=dialect)
for row in reader:
    print(f"  {row}")
```

输出：
```
--- 推断格式 ---
推断的分隔符: ';'

--- 实际使用推断的格式 ---
  ['name', 'age', 'city']
  ['Alice', '30', 'Beijing']
  ['Bob', '25', 'Shanghai']
```

### 2. has_header()方法

**语法格式**

```
csv.Sniffer().has_header(sample)
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `has_header(sample)` | 检测CSV是否包含表头行 | `Sniffer().has_header(data)` |

**示例**

```python
import csv
import io

print("--- 检测表头 ---")
# 有表头的数据
sample_with_header = "name,age,city\nAlice,30,Beijing"
print(f"有表头: {csv.Sniffer().has_header(sample_with_header)}")

# 无表头的数据
sample_no_header = "Alice,30,Beijing\nBob,25,Shanghai"
print(f"无表头: {csv.Sniffer().has_header(sample_no_header)}")
```

输出：
```
--- 检测表头 ---
有表头: True
无表头: False
```

## 五、变种注册

`csv`模块允许注册自定义变种，方便重复使用特定格式。

### 1. 变种管理函数

**语法格式**

```
csv.register_dialect(name, dialect, **fmtparams)
csv.unregister_dialect(name)
csv.get_dialect(name)
csv.list_dialects()
```

**函数说明**

| 函数 | 说明 | 示例 |
|------|------|------|
| `register_dialect(name, dialect)` | 注册新变种 | `register_dialect('custom', delimiter='|')` |
| `unregister_dialect(name)` | 删除变种 | `unregister_dialect('custom')` |
| `get_dialect(name)` | 获取变种 | `get_dialect('excel')` |
| `list_dialects()` | 列出所有变种 | `list_dialects()` |

**示例**

```python
import csv
import io

# 注册自定义变种
print("--- 注册自定义变种 ---")
csv.register_dialect('custom', delimiter='|', quoting=csv.QUOTE_ALL)
print(f"注册后变种: {csv.list_dialects()}")

# 使用自定义变种
output = io.StringIO()
writer = csv.writer(output, dialect='custom')
writer.writerow(['Field1', 'Field2', 'Field3'])
print(f"使用自定义变种: {output.getvalue()}")

# 获取变种信息
print("\n--- 获取变种 ---")
dialect = csv.get_dialect('custom')
print(f"分隔符: '{dialect.delimiter}'")
print(f"引号模式: {dialect.quoting}")

# 删除变种
print("\n--- 删除变种 ---")
csv.unregister_dialect('custom')
print(f"删除后变种: {csv.list_dialects()}")
```

输出：
```
--- 注册自定义变种 ---
注册后变种: ['excel', 'excel-tab', 'unix', 'custom']
使用自定义变种: "Field1"|"Field2"|"Field3"

--- 获取变种 ---
分隔符: '|'
引号模式: 1

--- 删除变种 ---
删除后变种: ['excel', 'excel-tab', 'unix']
```

## 六、字段大小限制

`csv`模块提供了控制字段大小的功能。

### 1. field_size_limit()函数

**语法格式**

```
csv.field_size_limit(limit=None)
```

**函数说明**

| 函数 | 说明 | 示例 |
|------|------|------|
| `field_size_limit(limit)` | 获取或设置最大字段大小 | `field_size_limit(1024*1024)` |

**示例**

```python
import csv

# 获取当前限制
print("--- 字段大小限制 ---")
current_limit = csv.field_size_limit()
print(f"当前限制: {current_limit} bytes")

# 设置新限制
csv.field_size_limit(1024 * 1024)  # 1MB
new_limit = csv.field_size_limit()
print(f"新限制: {new_limit} bytes")
```

输出：
```
--- 字段大小限制 ---
当前限制: 131072 bytes
新限制: 1048576 bytes
```

## 七、常见问题与注意事项

### 1. 文件打开方式

读取CSV文件时，建议使用`newline=''`避免行分隔符问题：

```python
import csv

# 正确方式
# with open('data.csv', 'r', newline='') as f:
#     reader = csv.reader(f)
#     for row in reader:
#         print(row)

# 写入CSV文件
# with open('output.csv', 'w', newline='') as f:
#     writer = csv.writer(f)
#     writer.writerow(['header1', 'header2'])
```

### 2. 编码问题

处理非UTF-8编码的CSV文件时，指定编码：

```python
import csv

# 读取GBK编码的CSV文件
# with open('data_gbk.csv', 'r', newline='', encoding='gbk') as f:
#     reader = csv.reader(f)
#     for row in reader:
#         print(row)
```

### 3. 错误处理

使用`csv.Error`捕获和处理CSV格式错误：

```python
import csv
import io

print("--- 错误处理 ---")
invalid_csv = "a,b,c\n1,2\nx,y,z,w"

try:
    reader = csv.reader(io.StringIO(invalid_csv))
    for row in reader:
        print(row)
except csv.Error as e:
    print(f"CSV错误: {e}")
```

输出：
```
--- 错误处理 ---
['a', 'b', 'c']
['1', '2']
['x', 'y', 'z', 'w']
```