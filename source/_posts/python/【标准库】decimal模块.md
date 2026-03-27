---
title: 【标准库】decimal模块
published: true
layout: post
date: 2026-03-23 19:30:00
permalink: /python/decimal.html
categories: [Python]
---

`decimal` 模块提供了对快速且正确舍入的十进制浮点运算的支持。与 `float` 数据类型相比，它具有精度高、无误差累积的优势，非常适合金融计算等需要精确表示的场景。

## 一、`Decimal` 基础

### 1. Decimal 简介和优势

**语法格式**

```
Decimal(value)
```

**优势说明**

| 优势 | 说明 | 示例 |
|------|------|------|
| 精确表示 | 十进制数可完全精确表示 | `Decimal('1.1')` |
| 无误差累积 | 算术运算精确 | `0.1 + 0.1 + 0.1 - 0.3` |
| 保留有效位 | 1.30 + 1.20 = 2.50 | `Decimal('1.30')` |
| 可控精度 | 默认28位 | `getcontext().prec = 10` |

**示例**

```python
from decimal import Decimal

# 与float对比：精度问题
a = 1.1
b = 2.2
print(f"float运算: {a + b}")  # 3.3000000000000003

# 使用Decimal
d1 = Decimal('1.1')
d2 = Decimal('2.2')
print(f"Decimal运算: {d1 + d2}")  # 3.3

# 误差累积问题
print(f"float: 0.1 + 0.1 + 0.1 - 0.3 = {0.1 + 0.1 + 0.1 - 0.3}")
print(f"Decimal: {Decimal('0.1') + Decimal('0.1') + Decimal('0.1') - Decimal('0.3')}")

# 有效位保留
print(f"Decimal('1.30') + Decimal('1.20') = {Decimal('1.30') + Decimal('1.20')}")
```

输出：
```
float运算: 3.3000000000000003
Decimal运算: 3.3
float: 0.1 + 0.1 + 0.1 - 0.3 = 5.551115123125783e-17
Decimal: 0.00
Decimal('1.30') + Decimal('1.20') = 2.50
```

### 2. 创建 Decimal 对象

**语法格式**

```
Decimal(value)
Decimal.from_float(f)
Decimal.from_number(n)
```

**构造函数说明**

| 构造函数 | 说明 | 示例 |
|----------|------|------|
| `Decimal(value)` | 从整数、字符串、浮点数或元组创建 | `Decimal('3.14')` |
| `Decimal.from_float(f)` | 从浮点数创建 | `Decimal.from_float(3.14)` |
| `Decimal.from_number(n)` | 从数字创建 | `Decimal.from_number(3.14)` |

**示例**

```python
from decimal import Decimal

# 从字符串创建（推荐）
d1 = Decimal('3.14')
print(f"字符串: {d1}")

# 从整数创建
d2 = Decimal(10)
print(f"整数: {d2}")

# 从浮点数创建（会损失精度）
d3 = Decimal(3.14)
print(f"浮点数: {d3}")

# 使用from_float
d4 = Decimal.from_float(3.14)
print(f"from_float: {d4}")

# 使用from_number
d5 = Decimal.from_number(3.14)
print(f"from_number: {d5}")

# 从元组创建 (符号, 数字元组, 指数)
d6 = Decimal((0, (3, 1, 4), -2))  # 符号0正1负
print(f"元组: {d6}")

# 特殊值
print(f"正无穷: {Decimal('Infinity')}")
print(f"负无穷: {Decimal('-Infinity')}")
print(f"NaN: {Decimal('NaN')}")
print(f"负零: {Decimal('-0')}")
```

输出：
```
字符串: 3.14
整数: 10
浮点数: 3.140000000000000124344978758017532527446746826171875
from_float: 3.140000000000000124344978758017532527446746826171875
from_number: 3.14
元组: 3.14
正无穷: Infinity
负无穷: -Infinity
NaN: NaN
负零: -0
```

## 二、Decimal 算术运算

### 1. 基本算术运算

**语法格式**

```
d1 + d2      # 加法
d1 - d2      # 减法
d1 * d2      # 乘法
d1 / d2      # 除法
d1 // d2     # 整除
d1 % d2      # 取余
d1 ** d2     # 幂运算
```

**运算说明**

| 运算 | 说明 | 示例 |
|------|------|------|
| `+` | 加法 | `Decimal('1') + Decimal('2')` |
| `-` | 减法 | `Decimal('5') - Decimal('3')` |
| `*` | 乘法 | `Decimal('2') * Decimal('3')` |
| `/` | 除法 | `Decimal('10') / Decimal('3')` |
| `//` | 整除 | `Decimal('10') // Decimal('3')` |
| `%` | 取余 | `Decimal('10') % Decimal('3')` |
| `**` | 幂运算 | `Decimal('2') ** Decimal('3')` |

**示例**

```python
from decimal import Decimal

d1 = Decimal('10')
d2 = Decimal('3')

print(f"加法: {d1} + {d2} = {d1 + d2}")
print(f"减法: {d1} - {d2} = {d1 - d2}")
print(f"乘法: {d1} * {d2} = {d1 * d2}")
print(f"除法: {d1} / {d2} = {d1 / d2}")
print(f"整除: {d1} // {d2} = {d1 // d2}")
print(f"取余: {d1} % {d2} = {d1 % d2}")
print(f"幂运算: {d2} ** 2 = {d2 ** 2}")
```

输出：
```
加法: 10 + 3 = 13
减法: 10 - 3 = 7
乘法: 10 * 3 = 30
除法: 10 / 3 = 3.333333333333333333333333333
整除: 10 // 3 = 3
取余: 10 % 3 = 1
幂运算: 3 ** 2 = 9
```

### 2. 比较运算

**语法格式**

```
d1 == d2     # 相等
d1 != d2     # 不等
d1 < d2      # 小于
d1 <= d2     # 小于等于
d1 > d2      # 大于
d1 >= d2     # 大于等于
```

**比较运算说明**

| 运算 | 说明 | 示例 |
|------|------|------|
| `==` | 相等 | `Decimal('1') == Decimal('1')` |
| `!=` | 不等 | `Decimal('1') != Decimal('2')` |
| `<` | 小于 | `Decimal('1') < Decimal('2')` |
| `<=` | 小于等于 | `Decimal('1') <= Decimal('1')` |
| `>` | 大于 | `Decimal('2') > Decimal('1')` |
| `>=` | 大于等于 | `Decimal('2') >= Decimal('1')` |

**示例**

```python
from decimal import Decimal

a = Decimal('1.0')
b = Decimal('1.00')

print(f"1.0 == 1.00: {a == b}")
print(f"1.0 != 1.00: {a != b}")

# NaN比较
print(f"NaN比较: Decimal('NaN') == Decimal('NaN') = {Decimal('NaN') == Decimal('NaN')}")
print(f"NaN is qNaN: {Decimal('NaN').is_qnan()}")
```

## 三、Decimal 常用方法

### 1. 数值操作方法

**语法格式**

```
d.abs()
d.quantize(exp, rounding=None)
d.floor()
d.ceil()
d.to_integral_value(rounding=None)
d.round(precision=None)
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `abs()` | 绝对值 | `Decimal('-5').abs()` |
| `quantize(exp)` | 量化到指定精度 | `d.quantize(Decimal('0.01'))` |
| `floor()` | 向下取整 | `Decimal('3.7').floor()` |
| `ceil()` | 向上取整 | `Decimal('3.2').ceil()` |
| `to_integral_value()` | 转整数 | `d.to_integral_value()` |
| `round(precision)` | 四舍五入 | `d.round(2)` |

**示例**

```python
from decimal import Decimal, ROUND_FLOOR, ROUND_CEILING

d = Decimal('3.14159')

print(f"绝对值: abs({d}) = {abs(d)}")
print(f"量化: quantize(0.01) = {d.quantize(Decimal('0.01'))}")
print(f"量化: quantize(0.0001) = {d.quantize(Decimal('0.0001'))}")

d2 = Decimal('3.7')
print(f"向下取整: floor({d2}) = {d2.to_integral_value(rounding=ROUND_FLOOR)}")
print(f"向上取整: ceil({d2}) = {d2.to_integral_value(rounding=ROUND_CEILING)}")

d3 = Decimal('123.456')
print(f"四舍五入: round({d3}, 1) = {d3.__round__(1)}")
print(f"四舍五入: round({d3}, 2) = {d3.__round__(2)}")
```

输出：
```
绝对值: abs(3.14159) = 3.14159
量化: quantize(0.01) = 3.14
量化: quantize(0.0001) = 3.1416
向下取整: floor(3.7) = 3
向上取整: ceil(3.7) = 4
四舍五入: round(123.456, 1) = 123.5
四舍五入: round(123.456, 2) = 123.46
```

### 2. 查询方法

**语法格式**

```
d.is_finite()
d.is_infinite()
d.is_nan()
d.is_zero()
d.is_signed()
d.is_normal()
d.is_subnormal()
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `is_finite()` | 是否有限 | `Decimal('1').is_finite()` |
| `is_infinite()` | 是否无穷 | `Decimal('Infinity').is_infinite()` |
| `is_nan()` | 是否NaN | `Decimal('NaN').is_nan()` |
| `is_zero()` | 是否零 | `Decimal('0').is_zero()` |
| `is_signed()` | 是否负数 | `Decimal('-5').is_signed()` |

**示例**

```python
from decimal import Decimal

values = [
    Decimal('1'),
    Decimal('0'),
    Decimal('-5'),
    Decimal('Infinity'),
    Decimal('-Infinity'),
    Decimal('NaN'),
    Decimal('sNaN'),
]

for v in values:
    print(f"{str(v):12} 有限:{v.is_finite()} 无穷:{v.is_infinite()} NaN:{v.is_nan()} 零:{v.is_zero()} 负:{v.is_signed()}")
```

### 3. 格式化方法

**语法格式**

```
d.to_eng_string()
format(d, 'f')
str(d)
repr(d)
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `to_eng_string()` | 工程字符串 | `d.to_eng_string()` |
| `format(d, 'f')` | 定点格式 | `format(d, 'f')` |
| `str(d)` | 字符串 | `str(d)` |
| `repr(d)` | 表达式字符串 | `repr(d)` |

**示例**

```python
from decimal import Decimal

d = Decimal('1.23E+5')

print(f"原始: {d}")
print(f"to_eng_string: {d.to_eng_string()}")
print(f"定点格式: {format(d, 'f')}")
print(f"str: {str(d)}")
print(f"repr: {repr(d)}")
```

## 四、上下文和精度控制

### 1. 获取和设置上下文

**语法格式**

```
getcontext()
setcontext(context)
localcontext()
Decimal.localcontext()
```

**函数说明**

| 函数 | 说明 | 示例 |
|------|------|------|
| `getcontext()` | 获取当前上下文 | `getcontext().prec` |
| `setcontext(context)` | 设置上下文 | `setcontext(new_context)` |
| `localcontext()` | 获取本地上下文管理器 | `with localcontext():` |
| `Decimal.localcontext()` | 同上（模块方法） | `with Decimal.localcontext():` |

**示例**

```python
from decimal import Decimal, getcontext, setcontext, Context

# 获取当前上下文
ctx = getcontext()
print(f"当前精度: {ctx.prec}")
print(f"当前舍入模式: {ctx.rounding}")

# 修改精度
ctx.prec = 6
d = Decimal('1') / Decimal('3')
print(f"精度6位: 1/3 = {d}")

# 恢复精度
ctx.prec = 28
d = Decimal('1') / Decimal('3')
print(f"精度28位: 1/3 = {d}")
```

### 2. 舍入模式

**语法格式**

```
ctx.rounding = ROUND_HALF_UP
d.quantize(exp, rounding=ROUND_HALF_UP)
```

**舍入模式说明**

| 模式 | 说明 | 示例 |
|------|------|------|
| `ROUND_CEILING` | 永远向上舍入 | `Decimal('1.1').quantize(1, 'CEILING')` |
| `ROUND_FLOOR` | 永远向下舍入 | `Decimal('1.9').quantize(1, 'FLOOR')` |
| `ROUND_DOWN` | 截断 | `Decimal('1.9').quantize(1, 'DOWN')` |
| `ROUND_UP` | 总是舍入 | `Decimal('1.1').quantize(1, 'UP')` |
| `ROUND_HALF_UP` | 四舍五入 | `Decimal('1.5').quantize(1, 'HALF_UP')` |
| `ROUND_HALF_DOWN` | 五舍六入 | `Decimal('1.5').quantize(1, 'HALF_DOWN')` |
| `ROUND_HALF_EVEN` | 银行家舍入 | `Decimal('1.5').quantize(1, 'HALF_EVEN')` |
| `ROUND_05UP` | 末位为0或5则向上 | 特殊用法 |

**示例**

```python
from decimal import Decimal
from decimal import ROUND_HALF_UP, ROUND_HALF_DOWN, ROUND_HALF_EVEN

# 比较不同舍入模式
value = Decimal('2.5')

modes = [
    ('ROUND_DOWN', 'ROUND_DOWN'),
    ('ROUND_UP', 'ROUND_UP'),
    ('ROUND_HALF_UP', 'ROUND_HALF_UP'),
    ('ROUND_HALF_DOWN', 'ROUND_HALF_DOWN'),
    ('ROUND_HALF_EVEN', 'ROUND_HALF_EVEN'),
    ('ROUND_CEILING', 'ROUND_CEILING'),
    ('ROUND_FLOOR', 'ROUND_FLOOR'),
]

print(f"值: {value}")
for name, mode in modes:
    result = value.quantize(Decimal('1'), rounding=mode)
    print(f"  {name:18}: {result}")
```

### 3. 自定义上下文

**语法格式**

```
Context(prec=None, rounding=None, Emin=None, Emax=None, capitals=None, ...)
```

**上下文参数说明**

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `prec` | 精度 | 28 |
| `rounding` | 舍入模式 | ROUND_HALF_EVEN |
| `Emin` | 最小指数 | -999999 |
| `Emax` | 最大指数 | 999999 |
| `capitals` | 指数大写E | 1 |

**示例**

```python
from decimal import Decimal, Context, localcontext

# 创建高精度上下文
high_precision = Context(prec=50)
low_precision = Context(prec=5)

# 使用 localcontext 设置上下文
with localcontext(low_precision):
    d1 = Decimal('1') / Decimal('3')
    print(f"低精度(5位): 1/3 = {d1}")

with localcontext(high_precision):
    d2 = Decimal('1') / Decimal('3')
    print(f"高精度(50位): 1/3 = {d2}")

# 嵌套使用
with localcontext(low_precision):
    result = Decimal('1') / Decimal('3')
    print(f"\n内部计算结果: {result}")
    with localcontext(high_precision):
        precise = Decimal('1') / Decimal('3')
        print(f"临时高精度: 1/3 = {precise}")
```

## 五、信号和异常处理

### 1. 信号类型

**语法格式**

```
try:
    # 操作
except signals.InvalidOperation:
    # 处理
```

**信号类型说明**

| 信号 | 说明 | 触发条件 |
|------|------|----------|
| `InvalidOperation` | 无效操作 | 0/0, sqrt(-1) |
| `DivisionByZero` | 除零 | 1/0 |
| `Overflow` | 溢出 | 结果太大 |
| `Underflow` | 下溢 | 结果太小 |
| `Subnormal` | 次正规 | 结果次正规 |
| `Inexact` | 不精确 | 舍入导致精度丢失 |
| `Rounded` | 已舍入 | 计算被舍入 |
| `Clamped` | 被限制 | 指数被修改 |

**示例**

```python
from decimal import Decimal, InvalidOperation, DivisionByZero

# InvalidOperation
try:
    result = Decimal('0') / Decimal('0')
except InvalidOperation as e:
    print(f"InvalidOperation: {e}")

# DivisionByZero
try:
    result = Decimal('1') / Decimal('0')
except DivisionByZero as e:
    print(f"DivisionByZero: {e}")

# 处理NaN
print(f"NaN运算: Decimal('NaN') + 1 = {Decimal('NaN') + 1}")
```

### 2. 监控标志

**语法格式**

```
getcontext().flags[signal] = False
getcontext().trap_errors[signal] = True
```

**示例**

```python
from decimal import Decimal, getcontext, DivisionByZero

ctx = getcontext()

# 清除所有标志
for flag in ctx.flags:
    ctx.flags[flag] = False

# 触发除零（trap_errors 未开启时会抛出异常）
try:
    result = Decimal('1') / Decimal('0')
    print(f"结果: {result}")
except DivisionByZero:
    print("捕获到 DivisionByZero 异常")
print(f"DivisionByZero标志: {ctx.flags[DivisionByZero]}")
```

### 3. 金融计算示例

**示例**

```python
from decimal import Decimal, ROUND_HALF_UP

# 货币计算
price = Decimal('19.99')
tax_rate = Decimal('0.08')
quantity = Decimal('3')

# 计算含税总价
subtotal = price * quantity
tax = subtotal * tax_rate
total = subtotal + tax

print(f"单价: ${price}")
print(f"数量: {quantity}")
print(f"小计: ${subtotal}")
print(f"税(8%): ${tax.quantize(Decimal('0.01'), ROUND_HALF_UP)}")
print(f"总计: ${total.quantize(Decimal('0.01'), ROUND_HALF_UP)}")
```

输出：
```
单价: $19.99
数量: 3
小计: $59.97
税(8%): $4.80
总计: $64.77
```