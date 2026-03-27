---
title: MySQL 8.4 内置函数与运算符
published: true
layout: post
date: 2026-03-26 09:00:00
permalink: /mysql/mysql-84-functions-operators.html
categories: [MySQL]
tags: [内置函数, 运算符]
---

## 一、运算符

MySQL 8.4 支持多种运算符，用于构建表达式。按功能分为算术、比较、逻辑、位运算四类。

### 1.1 算术运算符

算术运算符用于数值计算。

| 运算符 | 说明 | 示例 |
|--------|------|------|
| `` + `` | 加法 | `` 3 + 5 `` → 8 |
| `` - `` | 减法 | `` 10 - 4 `` → 6 |
| `` * `` | 乘法 | `` 3 * 5 `` → 15 |
| `` / `` | 除法（返回浮点数） | `` 10 / 3 `` → 3.3333 |
| `` DIV `` | 整数除法 | `` 10 DIV 3 `` → 3 |
| `` % `` 或 `` MOD `` | 取模（余数） | `` 10 % 3 `` → 1 |

**除法与整数除法示例：**

```sql
SELECT 10 / 3 AS float_div, 10 DIV 3 AS int_div, 10 % 3 AS remainder, 10 MOD 3 AS mod_result;
```

```
+------------+----------+------------+--------------+
| float_div  | int_div  | remainder  | mod_result   |
+------------+----------+------------+--------------+
|    3.3333  |        3 |          1 |            1 |
+------------+----------+------------+--------------+
```

> **注意**：`/` 返回精确小数（与 `DECIMAL` 上下文），`DIV` 返回整数。`%` 和 `MOD` 功能相同，推荐 `MOD()` 函数写法以避免与注释符号混淆。

**除法精度规则**：MySQL 使用 `div_precision_increment` 系统变量控制除法结果的小数位数，默认值为 4。分母或分子的位数增加时，精度也会相应提升，显示结果自动四舍五入到对应位数。实际存储精度高于显示精度，可用 `` CAST(x AS DECIMAL(p, s)) `` 或 `` FORMAT(x, d) `` 指定精确位数：

```sql
SELECT @@div_precision_increment;           -- 默认 4
SELECT 10 / 3;                             -- 3.3333
SELECT 100 / 3;                             -- 33.3333
SELECT CAST(10 / 3 AS DECIMAL(20, 10));    -- 3.3333333333
SELECT FORMAT(10 / 3, 6);                   -- 3.333333
```

**算术运算示例：**

```sql
SELECT (10 + 5) * 2 - 8 / 4 AS result;
```

```
+--------+
| result |
+--------+
|  28.00 |
+--------+
```

---

### 1.2 比较运算符

比较运算符用于比较表达式，返回 1（真）、0（假）或 NULL。

| 运算符 | 说明 | 示例 |
|--------|------|------|
| `` = `` | 等于 | `` 5 = 5 `` → 1 |
| `` <> `` 或 `` != `` | 不等于 | `` 5 <> 3 `` → 1 |
| `` < `` | 小于 | `` 3 < 5 `` → 1 |
| `` > `` | 大于 | `` 5 > 3 `` → 1 |
| `` <= `` | 小于等于 | `` 5 <= 5 `` → 1 |
| `` >= `` | 大于等于 | `` 5 >= 6 `` → 0 |
| `` <=> `` | NULL 安全的等于（两者 NULL 也返回 1） | `` NULL <=> NULL `` → 1 |
| `` IS boolean `` | 测试布尔值（TRUE / FALSE / UNKNOWN） | `` 1 IS TRUE `` → 1 |
| `` IS NOT boolean `` | 测试非布尔值 | `` NULL IS NOT UNKNOWN `` → 1 |
| `` IS NULL `` | 是否为 NULL | |
| `` IS NOT NULL `` | 是否不为 NULL | |
| `` BETWEEN min AND max `` | 是否在范围内（含边界） | `` 5 BETWEEN 1 AND 10 `` → 1 |
| `` NOT BETWEEN ... `` | 是否不在范围内 | |
| `` IN (val, ...) `` | 是否在列表中 | `` 5 IN (1, 3, 5) `` → 1 |
| `` NOT IN (val, ...) `` | 是否不在列表中 | |
| `` LIKE pattern `` | 模式匹配（% 任意字符，_ 单个字符） | `` 'hello' LIKE 'h%' `` → 1 |
| `` NOT LIKE `` | 模式不匹配 | |
| `` REGEXP pattern `` 或 `` RLIKE `` | 正则表达式匹配 | `` 'abc' REGEXP '^a' `` → 1 |
| `` NOT REGEXP `` | 正则表达式不匹配 | |
| `` MEMBER OF(json_array) `` | 是否为 JSON 数组的元素 | `` 17 MEMBER OF('[23, 17, 10]') `` → 1 |
| `` EXISTS(subquery) `` | 子查询是否返回行 | |
| `` NOT EXISTS(subquery) `` | 子查询是否无返回行 | |
| `` INTERVAL(N, N1, N2, ...) `` | 返回 N < Ni 时最小的 i-1，否则 -1 | `` INTERVAL(10, 1, 10, 100) `` → 2 |
| `` ISNULL(expr) `` | expr 为 NULL 返回 1，否则返回 0 | `` ISNULL(1/0) `` → 1 |
| `` STRCMP(expr1, expr2) `` | 字符串比较（0 相等，-1 小于，1 大于） | `` STRCMP('abc', 'abd') `` → -1 |
| `` BINARY str `` | 将字符串转为二进制 | `` BINARY 'abc' = 'ABC' `` → 0（区分大小写） |

**常用比较示例：**

```sql
SELECT 5 = 5 AS eq, 5 <> 3 AS neq, 5 < 3 AS lt, NULL <=> NULL AS null_safe_eq;
SELECT 5 BETWEEN 1 AND 10 AS in_range, 5 IN (1, 2, 5) AS in_list;
SELECT 'hello' LIKE 'h%' AS like_match, 'world' REGEXP '^w' AS regex_match;
SELECT ISNULL(1/0) AS is_null_division, ISNULL(1+1) AS is_null_expr;
SELECT COALESCE(NULL, 'first', 'second') AS first_not_null;
SELECT GREATEST(3, 1, 9, 5) AS max_val, LEAST(3, 1, 9, 5) AS min_val;
```

```
+----+-----+-----+--------------+
| eq | neq | lt  | null_safe_eq |
+----+-----+-----+--------------+
|  1 |   1 |   0 |            1 |
+----+-----+-----+--------------+

+----------+----------+
| in_range | in_list  |
+----------+----------+
|        1 |        1 |
+----------+----------+

+------------+-------------+
| like_match | regex_match |
+------------+-------------+
|          1 |           1 |
+------------+-------------+

+---------------------+------------+
| isnull_division     | isnull_expr |
+---------------------+------------+
|                   1 |          0 |
+---------------------+------------+

+------------------+
| first_not_null    |
+------------------+
| first             |
+------------------+

+---------+---------+
| max_val  | min_val  |
+---------+---------+
|       9  |       1 |
+---------+---------+
```

> **NULL 比较注意事项**：普通比较运算符遇到 NULL 时返回 NULL。使用 `` <=> `` 或 `` IS NULL `` 处理 NULL 值。

**NULL 安全的比较：**

```sql
SELECT NULL = NULL AS normal_eq, NULL <=> NULL AS safe_eq, 5 IS NULL AS not_null;
```

```
+------------+----------+-----------+
| normal_eq  | safe_eq  | not_null  |
+------------+----------+-----------+
|       NULL |        1 |         0 |
+------------+----------+-----------+
```

**IS 布尔值测试：**

```sql
SELECT 1 IS TRUE AS is_true, 0 IS FALSE AS is_false, NULL IS UNKNOWN AS is_unknown;
SELECT 1 IS NOT UNKNOWN AS not_unknown, NULL IS NOT UNKNOWN AS null_not_unknown;
```

```
+----------+------------+---------------+
| is_true  | is_false   | is_unknown    |
+----------+------------+---------------+
|        1 |          1 |             1 |
+----------+------------+---------------+

+---------------+---------------------+
| not_unknown   | null_not_unknown     |
+---------------+---------------------+
|             1 |                   0 |
+---------------+---------------------+
```

**INTERVAL 函数示例：**

```sql
-- INTERVAL(N, N1, N2, N3, ...) 返回第一个 <= N 的区间索引
SELECT INTERVAL(23, 1, 15, 17, 30, 44, 200) AS idx;
SELECT INTERVAL(10, 1, 10, 100, 1000) AS idx;
SELECT INTERVAL(22, 23, 30, 44, 200) AS idx;
```

```
+-----+
| idx |
+-----+
|   3 |
+-----+

+-----+
| idx |
+-----+
|   2 |
+-----+

+-----+
| idx |
+-----+
|   0 |
+-----+

> INTERVAL 返回 0 表示 N <= N1，返回 1 表示 N1 < N <= N2，以此类推。参数必须升序排列，内部使用二分查找，性能高效。
```

**MEMBER OF 示例：**

```sql
SELECT 17 MEMBER OF('[23, "abc", 17, "ab", 10]') AS result;
SELECT 'ab' MEMBER OF('[23, "abc", 17, "ab", 10]') AS result;
SELECT 7 MEMBER OF('[23, "abc", 17, "ab", 10]') AS result;
```

```
+--------+
| result |
+--------+
|      1 |
+--------+

+--------+
| result |
+--------+
|      1 |
+--------+

+--------+
| result |
+--------+
|      0 |
+--------+

> 部分匹配不成立：'ab' 是 'abc' 的一部分但不是独立元素，所以 'abc' 匹配而 'ab' 不匹配。字符串精确匹配，不进行类型转换。
```

**BINARY 运算符示例：**

```sql
SELECT 'abc' = 'ABC' AS no_binary, BINARY 'abc' = 'ABC' AS with_binary;
SELECT BINARY 'hello' = 'HELLO' AS binary_case_sensitive;
```

```
+--------------+---------------+
| no_binary    | with_binary   |
+--------------+---------------+
|            1 |             0 |
+--------------+---------------+

+-----------------------+
| binary_case_sensitive  |
+-----------------------+
|                     0 |
+-----------------------+

> 不带 BINARY 时，字符串比较不区分大小写（默认 utf8mb4）。BINARY 将字符串转为二进制字节序列，按字节比较，强制区分大小写。
```

---

### 1.3 逻辑运算符

逻辑运算符返回真（1）或假（0）。

| 运算符 | 说明 | 示例 |
|--------|------|------|
| `` AND `` 或 `` && `` | 逻辑与（全真为真） | `` 1 AND 1 `` → 1 |
| `` OR `` 或 `` \|\| `` | 逻辑或（任一为真即为真） | `` 1 OR 0 `` → 1 |
| `` NOT `` 或 `` ! `` | 逻辑非 | `` NOT 1 `` → 0 |
| `` XOR `` | 逻辑异或（一真一假为真） | `` 1 XOR 0 `` → 1 |

**逻辑运算真值表：**

```sql
SELECT 1 AND 1 AS t_and_t, 1 AND 0 AS t_and_f, 0 AND 0 AS f_and_f;
SELECT 1 OR 0 AS t_or_f, 0 OR 0 AS f_or_f;
SELECT NOT 1 AS not_t, NOT 0 AS not_f;
SELECT 1 XOR 1 AS t_xor_t, 1 XOR 0 AS t_xor_f, 0 XOR 0 AS f_xor_f;
```

```
+--------+--------+--------+
| t_and_t | t_and_f | f_and_f |
+--------+--------+--------+
|       1 |       0 |       0 |
+--------+--------+--------+

+-------+--------+
| t_or_f | f_or_f |
+-------+--------+
|      1 |      0 |
+-------+--------+

+-------+-------+
| not_t | not_f |
+-------+-------+
|     0 |     1 |
+-------+-------+

+--------+--------+--------+
| t_xor_t | t_xor_f | f_xor_f |
+--------+--------+--------+
|       0 |       1 |       0 |
+--------+--------+--------+
```

> `&&`、`||`、`!` 是非标准写法，兼容性不如 `AND`、`OR`、`NOT`。建议使用后者。

---

### 1.4 位运算符

位运算符对整数值的二进制位进行操作。

| 运算符 | 说明 | 示例 |
|--------|------|------|
| `` & `` | 按位与 | `` 5 & 3 `` → 1 |
| `` \| `` | 按位或 | `` 5 \| 3 `` → 7 |
| `` ^ `` | 按位异或 | `` 5 ^ 3 `` → 6 |
| `` ~ `` | 按位取反 | `` ~0 `` → 全 1（补码） |
| `` -> `` | JSON 列路径取值（等价于 `` JSON_EXTRACT() ``） | `` col->>'$.name' `` |
| `` ->> `` | JSON 列路径取值并取消引号（等价于 `` JSON_UNQUOTE(JSON_EXTRACT()) ``，MySQL 8.0.13 起已弃用） | `` col->>'$.name' `` |
| `` << `` | 左移 | `` 5 << 1 `` → 10 |
| `` >> `` | 右移 | `` 5 >> 1 `` → 2 |

**位运算示例：**

```sql
SELECT 5 & 3 AS bit_and, 5 | 3 AS bit_or, 5 ^ 3 AS bit_xor;
SELECT ~0 AS all_bits_on, 5 << 1 AS left_shift, 5 >> 1 AS right_shift;
```

```
+---------+---------+---------+
| bit_and | bit_or  | bit_xor |
+---------+---------+---------+
|       1 |       7 |       6 |
+---------+---------+---------+

+-------------+------------+-------------+
| all_bits_on | left_shift | right_shift |
+-------------+------------+-------------+
|           -1 |         10 |           2 |
+-------------+------------+-------------+
```

**权限位掩码示例（READ=1, WRITE=2, DELETE=4, ADMIN=8）：**

```sql
SELECT 3 & 1 AS has_read, 3 & 2 AS has_write, 3 & 4 AS has_delete;
```

```
+-----------+------------+-------------+
| has_read  | has_write  | has_delete  |
+-----------+------------+-------------+
|         1 |          2 |           0 |
+-----------+------------+-------------+
```

> `3 & 4 = 0` 表示权限 3 不包含 DELETE。可用 `` IF(flags & 4, 'YES', 'NO') `` 判断权限。

**JSON 列路径运算符示例：**

```sql
SELECT meta->>'$.name' AS name, meta->>'$.age' AS age FROM json_demo;
-- 等价于
SELECT JSON_UNQUOTE(JSON_EXTRACT(meta, '$.name')) AS name FROM json_demo;
```

> `` -> `` 等价于 `` JSON_EXTRACT() ``，`` ->> `` 等价于 `` JSON_UNQUOTE(JSON_EXTRACT()) ``。官方文档中 `` ->> `` 已标记为弃用，推荐使用 `` JSON_UNQUOTE(JSON_EXTRACT()) `` 或 `` JSON_VALUE() `` 替代。

---

### 1.5 赋值运算符

| 运算符 | 说明 | 示例 |
|--------|------|------|
| `` := `` | 赋值（可在任何表达式中使用，永不解释为比较运算符） | `` @var := 1 `` |
| `` = `` | 赋值（仅在 SET 语句或 UPDATE SET 子句中为赋值，其他上下文为比较运算符） | |

**赋值运算符示例：**

```sql
SELECT @var1 := 1 AS assigned, @var2 := @var1 + 10 AS derived;
UPDATE users SET score = score + 10 WHERE id = 1;
```

```
+---------+
| assigned |
+---------+
|        1 |
+---------+

> `` := `` 可在任何 SQL 语句中使用赋值，`` = `` 在 SET/UPDATE 中为赋值，在 SELECT 中为比较。
```

---

### 1.6 运算符优先级

运算符按以下优先级从高到低执行，优先级相同时从左到右结合。括号 `` () `` 可显式改变优先级。

```
INTERVAL             -- 最高
BINARY, COLLATE
!                    -- 逻辑非（按位取反）
- (unary), ~         -- 负号、按位取反
^
*, /, DIV, %, MOD
+ (binary), - (binary)  -- 加减
<<, >>
&
|
=, <=>, >=, >, <=, <, <>, !=, IS, LIKE, REGEXP, IN, MEMBER OF
BETWEEN, CASE, WHEN, THEN, ELSE
NOT
AND, &&
XOR
OR, ||
= (assignment), :=   -- 最低
```

**优先级示例：**

```sql
SELECT 2 + 3 * 4 AS default_priority, (2 + 3) * 4 AS explicit_priority;
```

```
+------------------+-------------------+
| default_priority | explicit_priority |
+------------------+-------------------+
|                14 |                20 |
+------------------+-------------------+
```

---

## 二、字符串函数

### 2.1 大小写与空白处理

| 函数 | 说明 | 示例 |
|------|------|------|
| `` UPPER(str) `` | 转为大写 | `` UPPER('hello') `` → `'HELLO'` |
| `` LOWER(str) `` | 转为小写 | `` LOWER('HELLO') `` → `'hello'` |
| `` LENGTH(str) `` | 字节长度 | `` LENGTH('你好') `` → 6 |
| `` CHAR_LENGTH(str) `` | 字符数 | `` CHAR_LENGTH('你好') `` → 2 |
| `` CONCAT(str, ...) `` | 连接字符串 | `` CONCAT('a', 'b') `` → `'ab'` |
| `` CONCAT_WS(sep, str, ...) `` | 用分隔符连接 | `` CONCAT_WS('-', 'a', 'b') `` → `'a-b'` |
| `` LEFT(str, n) `` | 取左侧 n 个字符 | `` LEFT('hello', 2) `` → `'he'` |
| `` RIGHT(str, n) `` | 取右侧 n 个字符 | `` RIGHT('hello', 2) `` → `'lo'` |
| `` SUBSTRING(str, pos, len) `` / `` SUBSTR(str, pos, len) `` | 截取子串，pos 从 1 开始，支持负数（从末尾倒计数） | `` SUBSTRING('hello', 2, 3) `` → `'ell'` |
| `` TRIM([rem FROM] str) `` | 去除首尾空白 | `` TRIM('  hi  ') `` → `'hi'` |
| `` LTRIM(str) `` | 去除左侧空白 | |
| `` RTRIM(str) `` | 去除右侧空白 | |
| `` LPAD(str, len, pad) `` | 左侧填充到指定长度 | `` LPAD('hi', 5, '0') `` → `'000hi'` |
| `` RPAD(str, len, pad) `` | 右侧填充到指定长度 | `` RPAD('hi', 5, '0') `` → `'hi000'` |
| `` REPLACE(str, from, to) `` | 替换子串 | `` REPLACE('hello', 'l', 'x') `` → `'hexxo'` |
| `` REVERSE(str) `` | 反转字符串 | `` REVERSE('hello') `` → `'olleh'` |

**字符串处理示例：**

```sql
SELECT UPPER('hello') AS upper_case, LOWER('WORLD') AS lower_case;
SELECT LENGTH('你好') AS byte_len, CHAR_LENGTH('你好') AS char_len;
SELECT CONCAT('Hello', ' ', 'World') AS greeting, CONCAT_WS('-', 'a', 'b', 'c') AS separated;
```

```
+------------+------------+
| upper_case | lower_case |
+------------+------------+
| HELLO      | world       |
+------------+------------+

+----------+----------+
| byte_len | char_len |
+----------+----------+
|        6 |        2 |
+----------+----------+

+---------------------+------------+
| greeting            | separated  |
+---------------------+------------+
| Hello World         | a-b-c      |
+---------------------+------------+
```

**子串截取与替换：**

```sql
SELECT LEFT('hello', 2) AS left_part, RIGHT('hello', 3) AS right_part;
SELECT SUBSTRING('hello', 2, 3) AS substring_1, SUBSTR('2026-03-26', 1, 4) AS year_part;
SELECT SUBSTRING('hello', -2, 2) AS neg_start;  -- 从倒数第2位取2个字符
SELECT TRIM('  hello  ') AS trimmed, LPAD('42', 5, '0') AS zero_padded;
SELECT REPLACE('hello-world', '-', '_') AS replaced, REVERSE('hello') AS reversed;
```

```
+-----------+-------------+
| left_part | right_part  |
+-----------+-------------+
| he        | llo         |
+-----------+-------------+

+------------+------------+
| substring_1 | year_part  |
+------------+------------+
| ell        | 2026        |
+------------+------------+

+------------+
| neg_start  |
+------------+
| lo         |
+------------+

+---------+--------------+
| trimmed | zero_padded  |
+---------+--------------+
| hello   | 00042        |
+---------+--------------+

+-----------+-----------+
| replaced | reversed  |
+-----------+-----------+
| hello_world | olleh    |
+-----------+-----------+
```

> `LENGTH()` 按字节计，`CHAR_LENGTH()` 按字符数计。UTF-8 下，中文字符占 3 字节，因此 `LENGTH('你好') = 6`。

---

### 2.2 字符串查找与操作

| 函数 | 说明 | 示例 |
|------|------|------|
| `` FIND_IN_SET(str, strlist) `` | 在逗号分隔列表中查找位置 | `` FIND_IN_SET('b', 'a,b,c') `` → 2 |
| `` SUBSTRING_INDEX(str, delim, count) `` | 按分隔符截取，\|count\| 表示取到第几个分隔符位置，count > 0 从左取，count < 0 从右取 | `` SUBSTRING_INDEX('a-b-c-d', '-', 2) `` → `'a-b'` |
| `` REGEXP_LIKE(str, pattern) `` | 正则匹配（MySQL 8.0+） | `` REGEXP_LIKE('abc', '^a') `` → 1 |
| `` ELT(n, str1, str2, ...) `` | 根据 n 返回参数列表中第 n 个字符串（下标从 1 开始），n 超出范围或为 0/负数返回 NULL | `` ELT(2, 'a', 'b', 'c') `` → `'b'` |
| `` FIELD(str, str1, str2, ...) `` | 查找字符串在列表中的位置 | `` FIELD('b', 'a', 'b', 'c') `` → 2 |
| `` INSTR(str, substr) `` | 查找子串位置（从 1 开始） | `` INSTR('hello', 'll') `` → 3 |
| `` STRCMP(expr1, expr2) `` | 字符串比较（0 相等，-1 小于，1 大于） | `` STRCMP('abc', 'abd') `` → -1 |

**字符串查找示例：**

```sql
SELECT FIND_IN_SET('b', 'a,b,c,d') AS position_result;
SELECT SUBSTRING_INDEX('user@domain.com', '@', 1) AS local_part;
SELECT SUBSTRING_INDEX('user@domain.com', '@', -1) AS domain_part;
SELECT SUBSTRING_INDEX('a-b-c-d', '-', 2) AS from_left_2;
SELECT SUBSTRING_INDEX('a-b-c-d', '-', -2) AS from_right_2;
SELECT REGEXP_LIKE('hello123', '^[a-z]+[0-9]+$') AS regex_match;
SELECT ELT(3, 'apple', 'banana', 'cherry') AS third_elt;
SELECT FIELD('banana', 'apple', 'banana', 'cherry') AS field_position;
```

```
+-----------------+
| position_result |
+-----------------+
|               2 |
+-----------------+

+------------+
| local_part |
+------------+
| user       |
+------------+

+-------------+
| domain_part  |
+-------------+
| domain.com   |
+-------------+

+------------+
| from_left_2 |
+------------+
| a-b         |
+------------+

+---------------+
| from_right_2   |
+---------------+
| c-d             |
+---------------+

+--------------+
| regex_match  |
+--------------+
|            1 |
+--------------+

+------------+
| third_elt  |
+------------+
| cherry     |
+------------+

+---------------+
| field_position |
+---------------+
|              2 |
+---------------+
```

> `SUBSTRING_INDEX(str, delim, count)`：\|count\| 表示取到第几个分隔符为止，count > 0 从左数，count < 0 从右数。可用于解析邮箱、文件路径等。

---

## 三、数值函数

### 3.1 算术与数学函数

| 函数 | 说明 | 示例 |
|------|------|------|
| `` ABS(x) `` | 绝对值 | `` ABS(-5) `` → 5 |
| `` CEIL(x) `` 或 `` CEILING(x) `` | 向上取整 | `` CEIL(3.2) `` → 4 |
| `` FLOOR(x) `` | 向下取整 | `` FLOOR(3.8) `` → 3 |
| `` ROUND(x, d) `` | 四舍五入到 d 位小数 | `` ROUND(3.14159, 2) `` → 3.14 |
| `` TRUNCATE(x, d) `` | 截断到 d 位小数 | `` TRUNCATE(3.14159, 2) `` → 3.14 |
| `` MOD(a, b) `` | 取模 | `` MOD(10, 3) `` → 1 |
| `` POW(x, y) `` 或 `` POWER(x, y) `` | 幂运算 | `` POW(2, 3) `` → 8 |
| `` SQRT(x) `` | 平方根 | `` SQRT(16) `` → 4 |
| `` RAND() `` | 0~1 之间的随机浮点数 | |
| `` RAND(n) `` | 确定性随机（n 为种子） | |
| `` SIGN(x) `` | 符号（-1/0/1） | `` SIGN(-5) `` → -1 |
| `` GREATEST(val, ...) `` | 返回最大值 | `` GREATEST(1, 5, 3) `` → 5 |
| `` LEAST(val, ...) `` | 返回最小值 | `` LEAST(1, 5, 3) `` → 1 |

**数学函数示例：**

```sql
SELECT ABS(-10) AS abs_val, CEIL(3.2) AS ceil_val, FLOOR(3.8) AS floor_val;
SELECT ROUND(3.14159, 3) AS rounded, TRUNCATE(3.14159, 3) AS truncated;
SELECT POW(2, 10) AS power_val, SQRT(64) AS sqrt_val, MOD(17, 5) AS mod_val;
SELECT GREATEST(3, 1, 9, 5) AS max_val, LEAST(3, 1, 9, 5) AS min_val;
```

```
+---------+-----------+-----------+
| abs_val | ceil_val  | floor_val |
+---------+-----------+-----------+
|      10 |         4 |         3 |
+---------+-----------+-----------+

+----------+-------------+
| rounded  | truncated   |
+----------+-------------+
|  3.142  |      3.141  |
+----------+-------------+

+----------+---------+---------+
| power_val | sqrt_val | mod_val |
+----------+---------+---------+
|      1024 |       8 |       2 |
+----------+---------+---------+

+---------+---------+
| max_val  | min_val  |
+---------+---------+
|       9  |       1  |
+---------+---------+
```

**随机数据生成：**

```sql
-- 生成 1~100 之间的随机整数
SELECT FLOOR(1 + RAND() * 100) AS random_int;
```

---

### 3.2 三角函数

| 函数 | 说明 |
|------|------|
| `` SIN(x) `` | 正弦（弧度） |
| `` COS(x) `` | 余弦（弧度） |
| `` TAN(x) `` | 正切（弧度） |
| `` ASIN(x) `` | 反正弦 |
| `` ACOS(x) `` | 反余弦 |
| `` ATAN(x) `` | 反正切 |
| `` ATAN2(y, x) `` | 四象限反正切 |
| `` DEGREES(x) `` | 弧度转角度 |
| `` RADIANS(x) `` | 角度转弧度 |
| `` PI() `` | π 常量 |

**三角函数示例：**

```sql
SELECT SIN(PI() / 2) AS sin_90deg, COS(0) AS cos_0, TAN(PI() / 4) AS tan_45deg;
SELECT DEGREES(PI()) AS pi_to_deg, RADIANS(180) AS deg_to_rad;
```

```
+-----------+--------+-------------+
| sin_90deg | cos_0  | tan_45deg   |
+-----------+--------+-------------+
|         1 |      1 |  1.00000000 |
+-----------+--------+-------------+

+------------+-------------+
| pi_to_deg  | deg_to_rad  |
+------------+-------------+
|        180 |   3.14159265 |
+------------+-------------+
```

---

## 四、日期和时间函数

### 4.1 获取当前值

| 函数 | 说明 |
|------|------|
| `` CURDATE() `` / `` CURRENT_DATE() `` | 当前日期 |
| `` CURTIME() `` / `` CURRENT_TIME() `` | 当前时间 |
| `` NOW() `` | 当前日期时间（语句开始时固定） |
| `` SYSDATE() `` | 当前日期时间（每次调用实时） |
| `` UTC_DATE() `` | UTC 日期 |
| `` UTC_TIME() `` | UTC 时间 |
| `` UTC_TIMESTAMP() `` | UTC 日期时间 |
| `` YEAR(date) `` | 提取年份 |
| `` MONTH(date) `` | 提取月份（1~12） |
| `` MONTHNAME(date) `` | 月份名称 |
| `` DAY(date) `` / `` DAYOFMONTH(date) `` | 提取日（1~31） |
| `` DAYNAME(date) `` | 星期名称 |
| `` DAYOFWEEK(date) `` | 星期索引（1=周日，7=周六） |
| `` WEEKDAY(date) `` | 星期索引（0=周一，6=周日） |
| `` DAYOFYEAR(date) `` | 一年中的第几天 |
| `` QUARTER(date) `` | 季度（1~4） |
| `` HOUR(time) `` | 小时（0~23） |
| `` MINUTE(time) `` | 分钟（0~59） |
| `` SECOND(time) `` | 秒（0~59） |

**日期时间提取示例：**

```sql
SELECT CURDATE() AS today, CURTIME() AS now_time, NOW() AS current_datetime;
SELECT YEAR(NOW()) AS year_val, MONTH(NOW()) AS month_val, DAY(NOW()) AS day_val;
SELECT DAYNAME(NOW()) AS weekday_name, QUARTER(NOW()) AS quarter_val;
SELECT HOUR(NOW()) AS hour_val, MINUTE(NOW()) AS minute_val, SECOND(NOW()) AS second_val;
```

```
+------------+------------+---------------------+
| today      | now_time   | current_datetime    |
+------------+------------+---------------------+
| 2026-03-26 | 10:30:45   | 2026-03-26 10:30:45 |
+------------+------------+---------------------+

+---------+-----------+---------+
| year_val | month_val | day_val |
+---------+-----------+---------+
|    2026 |         3 |      26 |
+---------+-----------+---------+

+---------------+-------------+
| weekday_name  | quarter_val |
+---------------+-------------+
| Thursday      |           1 |
+---------------+-------------+

+----------+-------------+-------------+
| hour_val | minute_val  | second_val  |
+----------+-------------+-------------+
|       10 |          30 |          45 |
+----------+-------------+-------------+
```

> `NOW()` 和 `SYSDATE()` 的区别：`NOW()` 在语句开始时固定，`SYSDATE()` 每次调用实时获取。`SYSDATE()` 不受 `SET TIMESTAMP` 影响。

---

### 4.2 日期计算

| 函数 | 说明 | 示例 |
|------|------|------|
| `` DATE_ADD(date, INTERVAL expr unit) `` | 日期加法 | `` DATE_ADD(NOW(), INTERVAL 1 DAY) `` |
| `` DATE_SUB(date, INTERVAL expr unit) `` | 日期减法 | `` DATE_SUB(NOW(), INTERVAL 7 DAY) `` |
| `` DATEDIFF(expr1, expr2) `` | 日期差（忽略时间部分） | `` DATEDIFF('2026-03-26', '2026-01-01') `` → 84 |
| `` TIMESTAMPDIFF(unit, expr1, expr2) `` | 时间差（指定单位） | |
| `` TIMEDIFF(expr1, expr2) `` | 时间差（保留时间部分） | |
| `` DATE_FORMAT(date, format) `` | 格式化日期 | `` DATE_FORMAT(NOW(), '%Y-%m-%d') `` |
| `` STR_TO_DATE(str, format) `` | 按格式解析字符串为日期 | `` STR_TO_DATE('2026-03-26', '%Y-%m-%d') `` |
| `` DATE(expr) `` | 提取日期部分 | |
| `` TIME(expr) `` | 提取时间部分 | |
| `` UNIX_TIMESTAMP([date]) `` | 转 Unix 时间戳 | |
| `` FROM_UNIXTIME(ts) `` | Unix 时间戳转日期时间 | |
| `` MAKEDATE(year, dayofyear) `` | 根据年份和年内天数构造日期 | `` MAKEDATE(2026, 100) `` |
| `` MAKETIME(hour, minute, second) `` | 构造时间 | `` MAKETIME(14, 30, 0) `` |

**INTERVAL 常用单位：**

| 单位 | 说明 | 示例值 |
|------|------|-------|
| `` SECOND `` | 秒 | `` INTERVAL 30 SECOND `` |
| `` MINUTE `` | 分钟 | `` INTERVAL 15 MINUTE `` |
| `` HOUR `` | 小时 | `` INTERVAL 2 HOUR `` |
| `` DAY `` | 天 | `` INTERVAL 5 DAY `` |
| `` WEEK `` | 周 | `` INTERVAL 1 WEEK `` |
| `` MONTH `` | 月 | `` INTERVAL 3 MONTH `` |
| `` QUARTER `` | 季度 | `` INTERVAL 2 QUARTER `` |
| `` YEAR `` | 年 | `` INTERVAL 1 YEAR `` |

**日期计算示例：**

```sql
SELECT DATE_ADD(NOW(), INTERVAL 1 MONTH) AS next_month;
SELECT DATE_SUB(NOW(), INTERVAL 7 DAY) AS last_week;
SELECT DATEDIFF('2026-03-26', '2026-01-01') AS days_diff;
SELECT TIMESTAMPDIFF(HOUR, '2026-03-26 08:00:00', NOW()) AS hours_elapsed;
SELECT DATE(NOW()) AS date_part, TIME(NOW()) AS time_part;
```

```
+---------------------+
| next_month          |
+---------------------+
| 2026-04-26 10:30:45 |
+---------------------+

+---------------------+
| last_week           |
+---------------------+
| 2026-03-19 10:30:45 |
+---------------------+

+------------+
| days_diff  |
+------------+
|         84 |
+------------+

+---------------+
| hours_elapsed |
+---------------+
|             2 |
+---------------+

+------------+------------+
| date_part  | time_part  |
+------------+------------+
| 2026-03-26 | 10:30:45   |
+------------+------------+
```

**DATE_FORMAT 常用格式化符号：**

| 符号 | 说明 | 示例 |
|------|------|------|
| `` %Y `` | 4 位年份 | `` 2026 `` |
| `` %m `` | 2 位月份（01~12） | `` 03 `` |
| `` %d `` | 2 位日期（01~31） | `` 26 `` |
| `` %H `` | 24 小时制（00~23） | `` 10 `` |
| `` %i `` | 分钟（00~59） | `` 30 `` |
| `` %S `` / `` %s `` | 秒（00~59） | `` 45 `` |
| `` %T `` | 24 小时制时间 | `` 10:30:45 `` |
| `` %W `` | 完整星期名 | `` Thursday `` |
| `` %a `` | 缩写的星期名 | `` Thu `` |

**日期格式化示例：**

```sql
SELECT DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i:%s') AS formatted;
SELECT DATE_FORMAT(NOW(), '%W, %M %d, %Y') AS human_readable;
SELECT STR_TO_DATE('26/03/2026', '%d/%m/%Y') AS parsed_date;
SELECT UNIX_TIMESTAMP(NOW()) AS unix_ts, FROM_UNIXTIME(UNIX_TIMESTAMP(NOW())) AS back_to_date;
```

```
+---------------------+
| formatted           |
+---------------------+
| 2026-03-26 10:30:45 |
+---------------------+

+--------------------------+
| human_readable           |
+--------------------------+
| Thursday, March 26, 2026  |
+--------------------------+

+---------------+
| parsed_date    |
+---------------+
| 2026-03-26     |
+---------------+

+---------------+---------------------+
| unix_ts       | back_to_date        |
+---------------+---------------------+
| 1742947245    | 2026-03-26 10:30:45 |
+---------------+---------------------+
```

---

## 五、条件判断函数

### 5.1 IF 与 IFNULL

| 函数 | 说明 | 示例 |
|------|------|------|
| `` IF(condition, val_true, val_false) `` | 条件为真返回 val_true，否则返回 val_false | `` IF(5 > 3, 'yes', 'no') `` → `'yes'` |
| `` IFNULL(expr, fallback) `` | expr 非 NULL 返回本身，否则返回 fallback | `` IFNULL(NULL, 'default') `` → `'default'` |
| `` NULLIF(expr1, expr2) `` | 两值相等返回 NULL，否则返回 expr1 | `` NULLIF(5, 5) `` → NULL |

**条件函数示例：**

```sql
SELECT IF(10 > 5, '大于', '小于或等于') AS comparison;
SELECT IFNULL(NULL, '无数据') AS null_handled, IFNULL('有数据', '无数据') AS not_null;
SELECT NULLIF(5, 5) AS same_is_null, NULLIF(5, 3) AS diff_returns_first;
```

```
+------------+
| comparison |
+------------+
| 大于       |
+------------+

+-------------+----------+
| null_handled | not_null  |
+-------------+----------+
| 无数据        | 有数据     |
+-------------+----------+

+--------------+------------------+
| same_is_null | diff_returns_first |
+--------------+-------------------+
|         NULL |                 5 |
+--------------+-------------------+
```

---

### 5.2 CASE 表达式

`` CASE `` 提供多条件分支功能。

**搜索 CASE 表达式（推荐）：**

```sql
CASE
    WHEN condition1 THEN result1
    WHEN condition2 THEN result2
    ...
    [ELSE result_n]
END
```

**简单 CASE 表达式：**

```sql
CASE expression
    WHEN value1 THEN result1
    WHEN value2 THEN result2
    ...
    [ELSE result_n]
END
```

**CASE 表达式示例：**

```sql
SELECT name, score,
    CASE
        WHEN score >= 90 THEN '优秀'
        WHEN score >= 80 THEN '良好'
        WHEN score >= 60 THEN '及格'
        ELSE '不及格'
    END AS grade
FROM students;
```

```
+-------+-------+--------+
| name  | score | grade  |
+-------+-------+--------+
| Alice |    95 | 优秀   |
| Bob   |    72 | 及格   |
| Carol |    55 | 不及格 |
+-------+-------+--------+
```

**简单 CASE 示例：**

```sql
SELECT order_status,
    CASE order_status
        WHEN 'pending' THEN '等待处理'
        WHEN 'processing' THEN '处理中'
        WHEN 'completed' THEN '已完成'
        WHEN 'cancelled' THEN '已取消'
        ELSE '未知状态'
    END AS status_cn
FROM orders;
```

**在聚合中使用 CASE：**

```sql
SELECT
    COUNT(CASE WHEN status = 'active' THEN 1 END) AS active_count,
    COUNT(CASE WHEN status = 'inactive' THEN 1 END) AS inactive_count
FROM users;
```

---

## 六、聚合函数

聚合函数对一组行进行计算，返回单个值。常与 `` GROUP BY `` 配合使用。

| 函数 | 说明 | 示例 |
|------|------|------|
| `` COUNT(*) `` | 统计所有行（含 NULL） | |
| `` COUNT(expr) `` | 统计非 NULL 的行数 | |
| `` COUNT(DISTINCT expr) `` | 去重计数 | `` COUNT(DISTINCT city) `` |
| `` SUM(expr) `` | 求和 | `` SUM(salary) `` |
| `` AVG(expr) `` | 平均值 | `` AVG(score) `` |
| `` MAX(expr) `` | 最大值 | `` MAX(price) `` |
| `` MIN(expr) `` | 最小值 | `` MIN(price) `` |
| `` GROUP_CONCAT(expr [SEPARATOR sep]) `` | 连接分组内的值 | `` GROUP_CONCAT(name SEPARATOR ', ') `` |

**聚合函数示例：**

```sql
SELECT
    COUNT(*) AS total_count,
    COUNT(DISTINCT department) AS dept_count,
    SUM(salary) AS total_salary,
    AVG(salary) AS avg_salary,
    MAX(salary) AS max_salary,
    MIN(salary) AS min_salary
FROM employees;
```

```
+-------------+-------------+--------------+-------------+-------------+-------------+
| total_count | dept_count | total_salary | avg_salary  | max_salary  | min_salary  |
+-------------+-------------+--------------+-------------+-------------+-------------+
|          10 |           3 |      650000  |  65000.0000 |     120000  |      30000  |
+-------------+-------------+--------------+-------------+-------------+-------------+
```

**GROUP_CONCAT 示例：**

```sql
SELECT department, GROUP_CONCAT(name ORDER BY name SEPARATOR ', ') AS members
FROM employees
GROUP BY department;
```

```
+------------+------------------------+
| department | members                |
+------------+------------------------+
| IT         | Alice, Bob, Charlie    |
| Sales      | David, Eve              |
+------------+------------------------+
```

> `GROUP_CONCAT` 默认最大长度为 1024 字节，可通过 `` SET SESSION group_concat_max_len = 10240; `` 调整。

**HAVING 子句**：对分组后的结果进行过滤（类似于 WHERE，但作用于聚合之后）。

```sql
SELECT department, AVG(salary) AS avg_sal
FROM employees
GROUP BY department
HAVING AVG(salary) > 50000;
```

---

## 七、信息函数

信息函数返回关于当前数据库会话、连接或表达式的元信息。

| 函数 | 说明 | 示例 |
|------|------|------|
| `` DATABASE() `` / `` SCHEMA() `` | 当前数据库名 | |
| `` USER() `` | 当前用户名（包含主机名） | |
| `` CURRENT_USER() `` | 认证时的用户名 | |
| `` VERSION() `` | MySQL 服务器版本 | |
| `` CONNECTION_ID() `` | 当前连接 ID | |
| `` LAST_INSERT_ID() `` | 最近一次自增插入的值 | |
| `` ROW_COUNT() `` | 受影响行数（INSERT/UPDATE/DELETE） | |
| `` FOUND_ROWS() `` | SELECT 瞬时去重后的总行数 | |
| `` CHARSET(str) `` | 字符串的字符集 | `` CHARSET('abc') `` → `'utf8mb4'` |
| `` COLLATION(str) `` | 字符串的排序规则 | |

**信息函数示例：**

```sql
SELECT DATABASE() AS current_db, USER() AS current_usr, VERSION() AS mysql_version;
SELECT CONNECTION_ID() AS conn_id, LAST_INSERT_ID() AS last_id;
SELECT CHARSET('你好') AS charset_val, COLLATION('abc') AS collation_val;
```

```
+-------------+--------------------+------------------+
| current_db  | current_usr        | mysql_version    |
+-------------+--------------------+------------------+
| test_db     | root@localhost     | 8.4.0            |
+-------------+--------------------+------------------+

+---------+----------+
| conn_id | last_id  |
+---------+----------+
|      42 |        0 |
+---------+----------+

+------------+---------------+
| charset_val | collation_val |
+------------+---------------+
| utf8mb4    | utf8mb4_0900_ai_ci |
+------------+---------------+
```

---

## 八、其他常用函数

### 8.1 加密与哈希函数

| 函数 | 说明 |
|------|------|
| `` MD5(str) `` | MD5 哈希（128 位，32 位十六进制） |
| `` SHA1(str) `` | SHA-1 哈希（160 位，40 位十六进制） |
| `` SHA2(str, hash_len) `` | SHA-2 哈希（224/256/384/512 位） | |
| `` HEX(str_or_num) `` | 转为十六进制字符串，或数字转十六进制 | `` HEX('abc') `` → `'616263'` |
| `` PASSWORD(str) `` | 密码哈希（MySQL 8.0 已废弃） |
| `` ENCODE(str, pass_str) `` | 编码（双向，对称加密） |
| `` DECODE(str, pass_str) `` | 解码 |
| `` AES_ENCRYPT(str, key) `` | AES 加密 |
| `` AES_DECRYPT(crypt_str, key) `` | AES 解密 |
| `` RANDOM_BYTES(len) `` | 生成随机字节序列 |
| `` SHA2('password', 256) `` | 推荐：SHA-256 哈希（不可逆） |

**加密函数示例：**

```sql
SELECT MD5('hello') AS md5_hash, SHA1('hello') AS sha1_hash;
SELECT SHA2('hello', 256) AS sha256_hash, SHA2('hello', 512) AS sha512_hash;
SELECT HEX(RANDOM_BYTES(16)) AS random_token;
SELECT AES_ENCRYPT('secret', 'key123') AS encrypted, AES_DECRYPT(AES_ENCRYPT('secret', 'key123'), 'key123') AS decrypted;
```

```
+--------------------------------+------------------------------------------+
| md5_hash                       | sha1_hash                                |
+--------------------------------+------------------------------------------+
| 5d41402abc4b2a76b9719d911017c592 | aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434 |
+--------------------------------+------------------------------------------+

+------------------------------------------------------------------+------------------------------------------------------------------+
| sha256_hash                               | sha512_hash                                                                                                    |
+------------------------------------------------------------------+------------------------------------------------------------------+
| 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824 | 9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c4663475c2e5c3adef46f73bcdec043f+------------------------------------------------------------------+------------------------------------------------------------------+
| 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824 | 9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c4663475c2e5c3adef46f73bcdec043f |
+------------------------------------------------------------------+------------------------------------------------------------------+

+------------------------+
| random_token           |
+------------------------+
| DBEACBB6C33B96CBF5854866A8BD40C3 |
+------------------------+

+--------------------------------+-------------+
| encrypted                       | decrypted    |
+--------------------------------+-------------+
| CD4C7F51AB05D5B409EE18971CB34175 | secret        |
+--------------------------------+-------------+
```

> **密码存储建议**：不要使用 MD5/SHA1 存储密码（可被彩虹表破解）。推荐使用 `` SHA2(..., 256) `` 加盐，或应用层使用 bcrypt/Argon2 等专业密码哈希算法。

---

### 8.2 类型转换函数

| 函数 | 说明 | 示例 |
|------|------|------|
| `` CAST(expr AS type) `` | 将表达式转为指定类型 | `` CAST('123' AS SIGNED) `` |
| `` CONVERT(expr, type) `` | 同 CAST 语法（MySQL 风格） | `` CONVERT('2026-03-26', DATE) `` |
| `` CONVERT(expr USING charset) `` | 字符集转换 | `` CONVERT('你好' USING utf8mb4) `` |

**可用类型**：`` BINARY ``、`` CHAR ``、`` DATE ``、`` DATETIME ``、`` DECIMAL ``、`` DOUBLE ``、`` FLOAT ``、`` INT ``/`` INTEGER ``、`` SIGNED ``、`` TIME ``、`` UNSIGNED ``。

**类型转换示例：**

```sql
SELECT CAST('123' AS SIGNED) + 10 AS cast_result;
SELECT CONVERT('2026-03-26', DATE) AS converted_date;
SELECT CAST('3.14' AS DECIMAL(3,2)) AS decimal_val;
SELECT CONVERT('hello' USING utf8mb4) AS charset_converted;
```

```
+--------------+
| cast_result  |
+--------------+
|          133 |
+--------------+

+------------------+
| converted_date    |
+------------------+
| 2026-03-26        |
+------------------+

+-------------+
| decimal_val  |
+-------------+
|        3.14 |
+-------------+
```

> **隐式转换**：MySQL 在表达式中也会自动进行类型转换，但显式 `` CAST `` 使意图更清晰，也避免隐式转换带来的意外行为。

