---
title: Python命令行参数解析
date: 2026-03-23 19:50:00
tags:
  - Python
  - 命令行
  - argparse
categories:
  - Python
---

Python的`argparse`模块是标准库中用于解析命令行参数的核心工具。它能够自动生成帮助信息、处理无效参数，并支持位置参数、可选参数、默认值等功能。

## 一、ArgumentParser对象

`ArgumentParser`是argparse模块的核心类，用于创建命令行解析器。

### 1. ArgumentParser构造器

**语法格式**

```
argparse.ArgumentParser(prog=None, description=None, epilog=None, add_help=True, ...)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `prog` | 程序名称 | `prog='myapp'` |
| `description` | 程序描述 | `description='我的程序'` |
| `epilog` | 程序结尾文本 | `epilog='更多信息'` |
| `add_help` | 是否添加`-h/--help` | `add_help=True` |

**示例**

```python
import argparse

# 基本创建
parser = argparse.ArgumentParser(description='一个示例程序')
print("基本解析器已创建")

# 自定义程序名
parser = argparse.ArgumentParser(
    prog='myapp',
    description='我的应用程序',
    epilog='了解更多请访问 example.com'
)
parser.print_help()
```

输出：
```
usage: myapp [-h]

我的应用程序

options:
 -h, --help show this help message and exit

了解更多请访问 example.com
```

### 2. ArgumentParser常用方法

**语法格式**

```
parser.add_argument(...)
parser.parse_args(args=None, namespace=None)
parser.print_help()
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `add_argument(...)` | 添加命令行参数 | `parser.add_argument('--name')` |
| `parse_args(args)` | 解析命令行参数 | `parser.parse_args()` |
| `print_help()` | 打印帮助信息 | `parser.print_help()` |

## 二、定义参数

`add_argument()`方法用于向解析器添加命令行参数。

### 1. add_argument()基本参数

**语法格式**

```
parser.add_argument(name或flags, type=None, default=None, help=None, ...)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `name` | 位置参数名 | `add_argument('filename')` |
| `flags` | 可选参数标识 | `add_argument('-v', '--verbose')` |
| `type` | 参数类型 | `type=int` |
| `default` | 默认值 | `default='value'` |
| `help` | 参数说明 | `help='帮助信息'` |

**示例**

```python
import argparse

parser = argparse.ArgumentParser(description='参数示例')

# 位置参数
parser.add_argument('input_file')

# 可选参数
parser.add_argument('-o', '--output')
parser.add_argument('-v', '--verbose', action='store_true')

# 解析测试
args = parser.parse_args(['data.txt', '--output', 'result.txt', '-v'])
print(f"输入文件: {args.input_file}")
print(f"输出文件: {args.output}")
print(f"详细模式: {args.verbose}")
```

输出：
```
输入文件: data.txt
输出文件: result.txt
详细模式: True
```

### 2. action参数

`action`参数控制参数如何处理。

**语法格式**

```
parser.add_argument(..., action='store')
```

**action值说明**

| action值 | 说明 | 示例 |
|----------|------|------|
| `store` | 存储值（默认） | `action='store'` |
| `store_true` | 出现时存储`True` | `action='store_true'` |
| `store_false` | 出现时存储`False` | `action='store_false'` |
| `append` | 追加到列表 | `action='append'` |
| `count` | 计数 | `action='count'` |

**示例**

```python
import argparse

parser = argparse.ArgumentParser()

# 布尔开关
parser.add_argument('-v', '--verbose', action='store_true')
parser.add_argument('-q', '--quiet', action='store_true')

# 追加多个值
parser.add_argument('--name', action='append')

# 计数
parser.add_argument('-d', '--debug', action='count', default=0)

# 测试
args = parser.parse_args(['-vv', '--name=Alice', '--name=Bob', '-ddd'])
print(f"verbose: {args.verbose}")
print(f"quiet: {args.quiet}")
print(f"name: {args.name}")
print(f"debug级别: {args.debug}")
```

输出：
```
verbose: True
quiet: False
name: ['Alice', 'Bob']
debug级别: 3
```

### 3. nargs参数

`nargs`参数指定参数消耗的参数数量。

**语法格式**

```
parser.add_argument(..., nargs=N)
```

**nargs值说明**

| nargs值 | 说明 | 示例 |
|----------|------|------|
| `N`（整数） | 精确N个参数 | `nargs=2` |
| `?` | 0或1个 | `nargs='?'` |
| `*` | 0或多个 | `nargs='*'` |
| `+` | 1或多个 | `nargs='+'` |

**示例**

```python
import argparse

parser = argparse.ArgumentParser()

# 固定数量
parser.add_argument('--coords', nargs=2, type=int)
parser.add_argument('files', nargs=3)

# 可选数量
parser.add_argument('--optional', nargs='?')
parser.add_argument('--multiple', nargs='*')

# 至少一个
parser.add_argument('--required', nargs='+')

args = parser.parse_args(['a.txt', 'b.txt', 'c.txt', 
                          '--coords', '10', '20',
                          '--multiple', 'x', 'y'])
print(f"files: {args.files}")
print(f"coords: {args.coords}")
print(f"optional: {args.optional}")
print(f"multiple: {args.multiple}")
```

输出：
```
files: ['a.txt', 'b.txt', 'c.txt']
coords: [10, 20]
optional: None
multiple: ['x', 'y']
```

### 4. choices参数

`choices`限制参数的可选值。

**语法格式**

```
parser.add_argument(..., choices=['值1', '值2', ...])
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `choices` | 可选值列表 | `choices=['low', 'high']` |

**示例**

```python
import argparse

parser = argparse.ArgumentParser()

# 限制可选值
parser.add_argument('--level', choices=['low', 'medium', 'high'])
parser.add_argument('-v', '--verbosity', choices=[0, 1, 2], type=int)

# 测试
args = parser.parse_args(['--level', 'high', '-v', '2'])
print(f"level: {args.level}")
print(f"verbosity: {args.verbosity}")
```

输出：
```
level: high
verbosity: 2
```

### 5. required参数

`required`使可选参数变为必需的。

**语法格式**

```
parser.add_argument(..., required=True)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `required` | 是否必需 | `required=True` |

**示例**

```python
import argparse

parser = argparse.ArgumentParser()

# 强制要求的可选参数
parser.add_argument('--config', required=True, help='配置文件路径')
parser.add_argument('--mode', choices=['dev', 'prod'], default='dev')

# 测试缺少必需参数
print("=== 缺少必需参数 ===")
import sys
try:
    args = parser.parse_args([])
except SystemExit:
    print("解析失败：缺少必需参数")

# 提供必需参数
args = parser.parse_args(['--config', 'app.conf'])
print(f"\n提供必需参数:")
print(f"config: {args.config}")
```

输出：
```
=== 缺少必需参数 ===
usage: arg_example.py [-h] --config CONFIG
arg_example.py: error: the following arguments are required: --config

解析失败：缺少必需参数

提供必需参数:
config: app.conf
```

## 三、解析参数

`parse_args()`方法执行参数解析。

### 1. parse_args()方法

**语法格式**

```
args = parser.parse_args(args=None, namespace=None)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `args` | 命令行参数列表 | `parse_args(['--name', 'value'])` |
| `namespace` | 结果存放对象 | `parse_args(namespace=obj)` |

**示例**

```python
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--name', default='World')
parser.add_argument('--count', type=int, default=1)

# 从列表解析
args = parser.parse_args(['--name', 'Alice', '--count', '3'])
print(f"从列表解析: name={args.name}, count={args.count}")
```

输出：
```
从列表解析: name=Alice, count=3
```

### 2. 访问解析结果

**语法格式**

```
args.属性名
vars(args)
```

**示例**

```python
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('filename')
parser.add_argument('-n', '--name', default='unnamed')
parser.add_argument('--age', type=int)

args = parser.parse_args(['data.csv', '--name', 'Test', '--age', '25'])

# 访问方式1：属性访问
print(f"属性访问: filename={args.filename}, name={args.name}")

# 访问方式2：vars()转换为字典
print(f"字典形式: {vars(args)}")
```

输出：
```
属性访问: filename=data.csv, name=Test
字典形式: {'filename': 'data.csv', 'name': 'Test', 'age': 25}
```

### 3. parse_known_args()方法

`parse_known_args()`处理未知参数。

**语法格式**

```
args, extras = parser.parse_known_args(args=None, namespace=None)
```

**示例**

```python
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--known', default='default')

# 使用parse_known_args
print("=== parse_known_args解析 ===")
args, extras = parser.parse_known_args(['--known', 'value', '--unknown', 'x'])
print(f"已知参数: known={args.known}")
print(f"未知参数: {extras}")
```

输出：
```
=== parse_known_args解析 ===
已知参数: known=value
未知参数: ['--unknown', 'x']
```

## 四、参数分组

参数分组可以组织相关的参数。

### 1. add_argument_group()方法

**语法格式**

```
group = parser.add_argument_group(title=None, description=None)
group.add_argument(...)
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `add_argument_group(title)` | 创建参数组 | `add_argument_group('基本选项')` |

**示例**

```python
import argparse

parser = argparse.ArgumentParser(description='程序参数示例')

# 创建参数组
basic_group = parser.add_argument_group('基本选项')
basic_group.add_argument('--name', default='app')
basic_group.add_argument('--version', action='store_true')

advanced_group = parser.add_argument_group('高级选项')
advanced_group.add_argument('--debug', action='store_true')
advanced_group.add_argument('--config', default='config.yaml')

parser.print_help()
```

输出：
```
usage: arg_example.py [-h] [--name NAME] [--version] [--debug] [--config CONFIG]

程序参数示例

optional arguments:
  -h, --help    show this help message and exit

基本选项:
  --name NAME
  --version

高级选项:
  --debug
  --config CONFIG
```

## 五、互斥参数

互斥参数组确保同时只能使用其中一个。

### 1. add_mutually_exclusive_group()方法

**语法格式**

```
group = parser.add_mutually_exclusive_group(require=False)
group.add_argument(...)
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `add_mutually_exclusive_group()` | 创建互斥组 | `add_mutually_exclusive_group()` |

**示例**

```python
import argparse

parser = argparse.ArgumentParser()

# 创建互斥组
group = parser.add_mutually_exclusive_group()
group.add_argument('--short', action='store_true')
group.add_argument('--long', action='store_true')

# 测试
print("=== 只使用一个参数 ===")
args = parser.parse_args(['--short'])
print(f"short={args.short}, long={args.long}")

print("\n=== 同时使用两个参数 ===")
try:
    args = parser.parse_args(['--short', '--long'])
except SystemExit as e:
    print("错误：不能同时使用--short和--long")
```

输出：
```
=== 只使用一个参数 ===
short=True, long=False

=== 同时使用两个参数 ===
usage: arg_example.py [-h] [--short | --long]
arg_example.py: error: argument --long: not allowed with argument --short

错误：不能同时使用--short和--long
```

## 六、参数格式化

帮助信息的格式化控制。

### 1. formatter_class参数
**语法格式**

```
argparse.ArgumentParser(formatter_class=类名)
```

**formatter_class类说明**

| 类 | 说明 | 示例 |
|----|------|------|
| `RawDescriptionHelpFormatter` | 保留描述格式 | `formatter_class=RawDescriptionHelpFormatter` |
| `ArgumentDefaultsHelpFormatter` | 显示默认值 | `formatter_class=ArgumentDefaultsHelpFormatter` |
| `MetavarTypeHelpFormatter` | 显示参数类型 | `formatter_class=MetavarTypeHelpFormatter` |

**示例**

```python
import argparse

# 显示默认值
parser = argparse.ArgumentParser(
    formatter_class=argparse.ArgumentDefaultsHelpFormatter
)
parser.add_argument('--host', default='localhost')
parser.add_argument('--port', type=int, default=8080)
print("=== 显示默认值 ===")
parser.print_help()

# 显示类型
print("\n=== 显示类型 ===")
parser2 = argparse.ArgumentParser(
    formatter_class=argparse.MetavarTypeHelpFormatter
)
parser2.add_argument('--count', type=int)
parser2.add_argument('--name', type=str)
parser2.print_help()
```

输出：
```
=== 显示默认值 ===
usage: arg_example.py [-h] [--host HOST] [--port PORT]

optional arguments:
 -h, --help    show this help message and exit
 --host HOST    (default: localhost)
 --port PORT   (default: 8080)

=== 显示类型 ===
usage: arg_example.py [-h] [--count int] [--name str]

optional arguments:
 -h, --help    show this help message and exit
 --count int
 --name str
```

## 七、综合示例

### 1. 文件处理工具

**示例**

```python
import argparse

# 创建解析器
parser = argparse.ArgumentParser(
    description='文件处理工具',
    formatter_class=argparse.RawDescriptionHelpFormatter,
    epilog='示例用法: python tool.py input.txt -o output.txt -v'
)

# 位置参数
parser.add_argument('input_file', help='输入文件路径')

# 可选参数
parser.add_argument('-o', '--output', help='输出文件路径', default='a.out')
parser.add_argument('-v', '--verbose', action='store_true', help='详细输出')
parser.add_argument('-c', '--count', type=int, default=1, help='处理次数')
parser.add_argument('--mode', choices=['copy', 'move', 'delete'], default='copy')

# 解析参数（显式传入模拟参数列表，避免依赖 sys.argv）
args = parser.parse_args(['data.txt', '-o', 'result.txt', '-v'])

# 使用参数
print(f"输入文件: {args.input_file}")
print(f"输出文件: {args.output}")
print(f"详细模式: {args.verbose}")
print(f"处理次数: {args.count}")
print(f"处理模式: {args.mode}")
```

运行示例：
```bash
python tool.py data.txt -o result.txt -v --mode copy
```

输出：
```
输入文件: data.txt
输出文件: result.txt
详细模式: True
处理次数: 1
处理模式: copy
```
