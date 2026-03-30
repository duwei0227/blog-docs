---
title: MySQL 字符集与排序规则
date: 2026-03-30 08:30:00
tags:
  - 字符集
  - 排序规则
  - Unicode
  - utf8mb4
categories: MySQL
---

## 一、字符集与排序规则概述

字符集（`Character Set`）定义了 MySQL 可以存储的字符集合，排序规则（`Collation`）则定义了字符之间的比较和排序规则。每个字符集对应一个或多个排序规则。

MySQL 8.4 默认字符集为 `utf8mb4`，默认排序规则为 `utf8mb4_0900_ai_ci`。查看所有可用字符集：

```sql
SHOW CHARACTER SET;
```

```
+----------+---------------------------------+---------------------+--------+
| Charset  | Description                     | Default collation   | Maxlen |
+----------+---------------------------------+---------------------+--------+
| utf8mb4  | UTF-8 Unicode                  | utf8mb4_0900_ai_ci |      4 |
| utf8mb3  | UTF-8 Unicode (deprecated)     | utf8mb3_general_ci |      3 |
| latin1   | cp1252 West European           | latin1_swedish_ci  |      1 |
| ...      | ...                            | ...                 | ...    |
+----------+---------------------------------+---------------------+--------+
```

**验证：**

```sql
SELECT @@character_set_server, @@collation_server;
```

```
+---------------------------+----------------------------+
| @@character_set_server    | @@collation_server         |
+---------------------------+----------------------------+
| utf8mb4                   | utf8mb4_0900_ai_ci        |
+---------------------------+----------------------------+
```

### 核心概念：字符集与排序规则的关系

每个排序规则只属于一个字符集。尝试混用会导致错误：

```sql
SELECT _latin1 'x' COLLATE latin2_bin;
```

```
ERROR 1253 (42000): COLLATION 'latin2_bin' is not valid
for CHARACTER SET 'latin1'
```

**验证：** 执行上述语句返回 `ERROR 1253`，确认字符集与排序规则必须匹配。

## 二、MySQL 中的 `Unicode` 支持

`Unicode` 字符集支持 `BMP`（`Basic Multilingual Plane`，即 `U+0000` 至 `U+FFFF`）字符和补充字符（`U+10000` 及以上）。MySQL 8.4 支持的 `Unicode` 字符集如下：

| 字符集 | 支持范围 | 每字符存储空间 | 状态 |
|--------|---------|--------------|------|
| `utf8mb4` | BMP + 补充字符 | 1-4 字节 | 推荐使用 |
| `utf8mb3` | 仅 BMP | 1-3 字节 | 已弃用 |
| `utf8` | 仅 BMP | 1-3 字节 | `utf8mb3` 的别名，已弃用 |
| `ucs2` | 仅 BMP | 2 字节固定 | 已弃用 |
| `utf16` | BMP + 补充字符 | 2 或 4 字节 | 已弃用 |
| `utf16le` | BMP + 补充字符 | 2 或 4 字节 | 已弃用 |
| `utf32` | BMP + 补充字符 | 4 字节固定 | 已弃用 |

> ⚠️ `utf8mb3`（以及别名 `utf8`）已弃用，未来版本中 `utf8` 将变为 `utf8mb4` 的别名。新应用应直接使用 `utf8mb4`。

**验证 —— emoji 字符存储：**

```sql
SELECT LENGTH('😀') AS byte_length,
       CHAR_LENGTH('😀') AS char_count,
       HEX('😀') AS hex_value;
```

```
+-------------+------------+----------+
| byte_length | char_count | hex_value |
+-------------+------------+----------+
|           4 |          1 | F09F9880 |
+-------------+------------+----------+
```

> `😀`（`U+1F600`）为补充字符，在 `utf8mb4` 中占用 4 字节。`utf8mb3` 无法存储此类字符。

元数据默认使用 `utf8mb3` 存储：

```sql
SHOW VARIABLES LIKE 'character_set_system';
```

```
+----------------------+---------+
| Variable_name        | Value   |
+----------------------+---------+
| character_set_system | utf8mb3 |
+----------------------+---------+
```

## 三、字符集与排序规则的四个级别

MySQL 在四个层级上设置字符集和排序规则：`server`（服务器）、`database`（数据库）、`table`（表）、`column`（列）。

### 3.1 服务器级别

服务器启动时通过参数指定，未指定时默认 `utf8mb4` 和 `utf8mb4_0900_ai_ci`：

```bash
mysqld --character-set-server=utf8mb4 \
       --collation-server=utf8mb4_0900_ai_ci
```

运行时可通过系统变量查看和修改：

```sql
SET GLOBAL character_set_server = 'utf8mb4';
SET GLOBAL collation_server = 'utf8mb4_unicode_ci';
```

### 3.2 数据库级别

`CREATE DATABASE` 和 `ALTER DATABASE` 支持 `CHARACTER SET` 和 `COLLATE` 子句：

```sql
CREATE DATABASE db_name
    CHARACTER SET latin1 COLLATE latin1_swedish_ci;
```

若未指定，则继承服务器级别设置。查看当前数据库的字符集和排序规则：

```sql
SELECT @@character_set_database, @@collation_database;
```

### 3.3 表级别

```sql
CREATE TABLE tbl_name ( ... )
    CHARACTER SET latin1 COLLATE latin1_danish_ci;
```

若未指定，则继承数据库级别设置。

### 3.4 列级别

```sql
CREATE TABLE t1 (
    col1 VARCHAR(10) CHARACTER SET latin1 COLLATE latin1_german1_ci
);

ALTER TABLE t1
    MODIFY col1 VARCHAR(10) CHARACTER SET latin1 COLLATE latin1_swedish_ci;
```

### 3.5 级别继承规则

优先级从高到低：列级别 > 表级别 > 数据库级别 > 服务器级别。

**验证 —— 级别继承示例：**

```sql
CREATE TABLE t1 (
    c1 CHAR(10) CHARACTER SET latin1 COLLATE latin1_german1_ci
) DEFAULT CHARACTER SET latin2 COLLATE latin2_bin;
```

> 列 `c1` 的字符集为 `latin1`，排序规则为 `latin1_german1_ci`（显式指定）。

```sql
CREATE TABLE t1 (
    c1 CHAR(10) CHARACTER SET latin1
) DEFAULT CHARACTER SET latin1 COLLATE latin1_danish_ci;
```

> 列 `c1` 的字符集为 `latin1`，排序规则为 `latin1_swedish_ci`（`latin1` 的默认排序规则），而非 `latin1_danish_ci`。

## 四、字符集 `Introducer` 与 `COLLATE` 子句

字符集 introducer（引入器）用于显式指定字面量字符串的字符集，`_charset_name` 语法：

```sql
SELECT _latin1'Müller' COLLATE latin1_german1_ci;
SELECT _binary'abc';
SELECT _utf8mb4'abc' COLLATE utf8mb4_danish_ci;
```

**验证 —— introducer 不改变转义解析：**

```sql
SET NAMES latin1;
SELECT HEX('à\n'), HEX(_sjis'à\n');
```

```
+------------+-----------------+
| HEX('à\n') | HEX(_sjis'à\n') |
+------------+-----------------+
| E00A       | E00A            |
+------------+-----------------+
```

> 无论是否使用 introducer，转义字符 `\n` 均按 `character_set_connection` 解析，不会因 introducer 改变。这是标准 SQL 行为。

`introducer` 不同于 `CONVERT()`，后者会实际转换字符集而不仅仅是指定。

## 五、排序规则命名约定与后缀含义

MySQL 排序规则命名遵循统一规范，后缀表示排序特性：

| 后缀 | 含义 |
|------|------|
| `_ai` | 重音不敏感。重音指语言中的变音符号（如德语 `ä`、`ö`、`ü`、`ß`，法语 `é`、`è`，西班牙语 `ñ`），忽略后 `ä` 与 `a` 等价比较 |
| `_as` | 重音敏感。重音指语言中的变音符号，区分后 `ä` 与 `a` 不等价 |
| `_ci` | 大小写不敏感 |
| `_cs` | 大小写敏感 |
| `_ks` | 假名敏感。假名是日语的音节文字系统，平假名圆润（にほんご）、片假名方正（ニホンゴ），区分后平假名和片假名视为不同字符；无此后缀时视为相等 |
| `_bin` | 二进制（按码点值比较） |

**验证 —— 重音敏感性：**

```sql
SELECT 'Ä' = 'A' COLLATE utf8mb4_0900_ai_ci AS accent_insensitive;
SELECT 'Ä' = 'A' COLLATE utf8mb4_0900_as_cs AS accent_sensitive;
```

```
+--------------------+---------------------+
| accent_insensitive | accent_sensitive    |
+--------------------+---------------------+
|                  1 |                   0 |
+--------------------+---------------------+
```

> `_ai` 中 `Ä = A`（忽略重音），`_as` 中 `Ä ≠ A`（区分重音）。

**验证 —— 大小写与重音敏感性：**

```sql
SELECT 'a' = 'A' COLLATE utf8mb4_0900_ai_ci AS ai_ci;
SELECT 'a' = 'A' COLLATE utf8mb4_0900_as_cs AS as_cs;
```

```
+-------+-------+
| ai_ci | as_cs |
+-------+-------+
|     1 |     0 |
+-------+-------+
```

> `_ai_ci` 中 `a = A`（大小写不敏感），`_as_cs` 中 `a ≠ A`（大小写敏感）。

若排序规则名称中不含 `_ai` 或 `_as`，则由大小写敏感性隐含决定：`_ci` 隐含 `_ai`，`_cs` 隐含 `_as`。

### 5.1 UCA 版本号

`UCA`（`Unicode Collation Algorithm`）是 Unicode 联盟制定的统一排序算法，用于定义全球所有语言字符的排序规则和比较逻辑。MySQL 的 `Unicode` 排序规则基于 `UCA` 实现，名称中的数字表示所采用的 `UCA` 版本：

- `utf8mb4_0900_ai_ci` 基于 `UCA` 9.0.0
- `utf8mb4_unicode_520_ci` 基于 `UCA` 5.2.0
- `utf8mb4_unicode_ci`（无版本号）基于 `UCA` 4.0.0

### 5.2 语言特定排序规则

MySQL 支持多种语言特定排序规则，通过语言代码后缀标识：

```sql
SELECT COLLATION_NAME
FROM INFORMATION_SCHEMA.COLLATIONS
WHERE CHARACTER_SET_NAME = 'utf8mb4'
  AND COLLATION_NAME LIKE '%\_0900%'
ORDER BY COLLATION_NAME;
```

包括 `utf8mb4_danish_ci`、`utf8mb4_german2_ci`、`utf8mb4_ja_0900_as_cs`（日语）、`utf8mb4_zh_0900_as_cs`（中文）等。

## 六、`PAD` 属性：`PAD SPACE` 与 `NO PAD`

排序规则的 `PAD_ATTRIBUTE` 决定尾部空格在比较中的行为：

| 属性 | 行为 |
|------|------|
| `PAD SPACE` | 尾部空格在比较中忽略（默认） |
| `NO PAD` | 尾部空格在比较中与其他字符等价（`UCA` 9.0.0+ 排序规则） |

**验证 —— 尾部空格比较：**

```sql
SET NAMES utf8mb4 COLLATE utf8mb4_bin;
SELECT 'a ' = 'a' AS result;  -- utf8mb4_bin: PAD SPACE
```

```
+--------+
| result |
+--------+
|      1 |
+--------+
```

```sql
SET NAMES utf8mb4 COLLATE utf8mb4_0900_bin;
SELECT 'a ' = 'a' AS result;  -- utf8mb4_0900_bin: NO PAD
```

```
+--------+
| result |
+--------+
|      0 |
+--------+
```

> `utf8mb4_bin`（`PAD SPACE`）忽略尾部空格，`'a '` 与 `'a'` 相等；`utf8mb4_0900_bin`（`NO PAD`）将尾部空格视为有效字符，`'a '` 与 `'a'` 不相等。

**查看排序规则的 `PAD` 属性有两种方式：**

**方式一：查询指定排序规则**

```sql
SELECT COLLATION_NAME, PAD_ATTRIBUTE
FROM INFORMATION_SCHEMA.COLLATIONS
WHERE COLLATION_NAME IN (
    'utf8mb4_bin','utf8mb4_0900_bin',
    'utf8mb4_general_ci','utf8mb4_0900_ai_ci'
);
```

```
+----------------------+--------------+
| COLLATION_NAME       | PAD_ATTRIBUTE|
+----------------------+--------------+
| utf8mb4_0900_ai_ci  | NO PAD       |
| utf8mb4_0900_bin    | NO PAD       |
| utf8mb4_bin         | PAD SPACE    |
| utf8mb4_general_ci  | PAD SPACE    |
+----------------------+--------------+
```

**方式二：查询当前会话使用的排序规则**

```sql
SELECT @@collation_connection AS current_collation,
       PAD_ATTRIBUTE
FROM INFORMATION_SCHEMA.COLLATIONS
WHERE COLLATION_NAME = @@collation_connection;
```

```
+------------------------+--------------+
| current_collation      | PAD_ATTRIBUTE|
+------------------------+--------------+
| utf8mb4_0900_ai_ci   | NO PAD       |
+------------------------+--------------+
```

> 所有 `0900` 系列排序规则均为 `NO PAD`，早期排序规则为 `PAD SPACE`。

## 七、`Unicode` 排序规则详解

### 7.1 `_general_ci` 与 `_unicode_ci` 的区别

`utf8mb4_general_ci` 性能更好但精度较低，不支持扩展（expansion）和收缩（contraction）；`utf8mb4_unicode_ci` 支持这些特性。

**扩展（expansion）**指一个字符在排序时被展开为多个字符参与比较。最典型的例子是德语 `ß`（eszett）。在 `unicode_ci` 排序规则中，`ß` 被展开为 `ss`（两个字符的权重），因此 `ß` 与 `ss` 在比较时等价：`WHERE c = 'ß'` 能匹配到 `'ss'`。而 `general_ci` 不支持扩展，`ß` 与 `ss` 各有独立权重，互不相等。

**收缩（contraction）**指多个字符在排序时被收缩为一个单元参与比较。典型场景是西班牙语中的 `ch` 和 `ll`。传统西班牙语排序中，`ch` 被视为独立字母，位于 `c` 和 `d` 之间；`ll` 位于 `l` 和 `m` 之间。`unicode_ci` 支持这种多字符收缩，`general_ci` 不支持。

**中文和英文场景是否需要考虑：** 扩展和收缩主要影响带变音符号的欧洲语言。中文和英文均不涉及变音符号或字符组合收缩——中文字符按 Unicode 码点或偏旁笔画排序，英文字母各自独立无组合规则。因此在这两个场景下，`general_ci` 和 `unicode_ci` 的排序结果完全一致，不需要特别关注扩展和收缩问题。选择 `unicode_ci` 主要是为了与多语言环境保持一致，以及获得 `NO PAD` 特性。

**验证 —— 德语 `ß` 的处理：**

```sql
CREATE TABLE g1 (c CHAR(10))
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
INSERT INTO g1 VALUES ('ss');
SELECT * FROM g1 WHERE c = 'ß';
INSERT INTO g1 VALUES ('ß');
SELECT * FROM g1 WHERE c = 'ss';
```

```
+------+
| c    |
+------+
| ss   |
+------+
| ss   |
| ß    |
+------+
```

> `utf8mb4_unicode_ci` 中 `ß` 与 `ss` 在比较时等价。

**验证 —— 扩展与不扩展的权重对比：**

```sql
SELECT HEX(WEIGHT_STRING('ß' COLLATE utf8mb4_unicode_ci)) AS unicode_ci_weight;
SELECT HEX(WEIGHT_STRING('ss' COLLATE utf8mb4_unicode_ci)) AS ss_in_unicode_ci;
SELECT HEX(WEIGHT_STRING('ß' COLLATE utf8mb4_general_ci)) AS general_ci_weight;
SELECT HEX(WEIGHT_STRING('s' COLLATE utf8mb4_general_ci)) AS s_in_general_ci;
```

```
+-------------------+------------------+-------------------+----------------+
| unicode_ci_weight | ss_in_unicode_ci | general_ci_weight | s_in_general_ci |
+-------------------+------------------+-------------------+----------------+
| 0FEA0FEA         | 0FEA0FEA        | 0053             | 0053           |
+-------------------+------------------+-------------------+----------------+
```

> `utf8mb4_unicode_ci` 中 `ß` 与 `ss` 的权重完全相同（`0FEA0FEA`），说明 `ß` 被展开为 `ss` 两个字符参与排序——这就是扩展。`utf8mb4_general_ci` 中 `ß` 的权重仅为 `0053`（与 `s` 相同），不发生展开。

### 7.2 二进制排序规则

`utf8mb4` 有两个二进制排序规则：

- `utf8mb4_bin`：基于码点值比较，`PAD SPACE`
- `utf8mb4_0900_bin`：基于 UTF-8 编码字节比较，`NO PAD`，性能更好

## 九、连接字符集与排序规则

客户端与服务器通信时，涉及多个字符集相关的系统变量：

| 变量 | 作用 |
|------|------|
| `character_set_client` | 客户端发送 SQL 语句使用的字符集 |
| `character_set_connection` | 服务器解析字面量字符串时的字符集 |
| `character_set_results` | 服务器返回结果给客户端的字符集 |
| `collation_connection` | 字面量字符串比较时使用的排序规则 |

**验证 —— 连接变量：**

```sql
SELECT * FROM performance_schema.session_variables
WHERE VARIABLE_NAME IN (
    'character_set_client','character_set_connection',
    'character_set_results','collation_connection'
);
```

```
+-------------------------+--------------------+
| VARIABLE_NAME           | VARIABLE_VALUE     |
+-------------------------+--------------------+
| character_set_client    | utf8mb4            |
| character_set_connection| utf8mb4            |
| character_set_results   | utf8mb4            |
| collation_connection    | utf8mb4_0900_ai_ci |
+-------------------------+--------------------+
```

### 9.1 `SET NAMES` 与 `SET CHARACTER SET`

```sql
SET NAMES 'latin1';
-- 等价于：
SET character_set_client = latin1;
SET character_set_results = latin1;
SET character_set_connection = latin1;
-- collation_connection 自动设为 latin1 的默认排序规则
```

```sql
SELECT @@character_set_client, @@character_set_connection,
       @@character_set_results, @@collation_connection;
```

```
+------------------------+----------------------------+-------------------------+----------------------------+
| @@character_set_client | @@character_set_connection | @@character_set_results | @@collation_connection     |
+------------------------+----------------------------+-------------------------+----------------------------+
| latin1                 | latin1                     | latin1                  | latin1_swedish_ci          |
+------------------------+----------------------------+-------------------------+----------------------------+
```

`SET CHARACTER SET charset_name` 则使用数据库级别的字符集和排序规则来设置连接。

### 9.2 不能用作客户端字符集

以下字符集不能作为客户端字符集（`SET NAMES`、命令行 `--default-character-set` 等均会报错）：

- `ucs2`、`utf16`、`utf16le`、`utf32`

## 十、二进制字符集与 `_bin` 排序规则的区别

二进制字符串（`BINARY`、`VARBINARY`、`BLOB`）使用 `binary` 字符集，按字节值比较。`_bin` 排序规则用于非二进制字符集，按码点值比较。

**验证 —— `CHAR` vs `BINARY` 填充差异：**

```sql
CREATE TABLE t1 (
    a CHAR(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
    b BINARY(10)
);
INSERT INTO t1 VALUES ('x','x');
INSERT INTO t1 VALUES ('x ','x ');
SELECT a, b, HEX(a), HEX(b) FROM t1;
```

```
+------+------------------------+--------+----------------------+
| a    | b                      | HEX(a) | HEX(b)               |
+------+------------------------+--------+----------------------+
| x    | 0x78000000000000000000 | 78     | 78000000000000000000 |
| x    | 0x78200000000000000000 | 78     | 78200000000000000000 |
+------+------------------------+--------+----------------------+
```

> `CHAR` 列尾部空格被移除，存储为 `'x'`（1 字节）；`BINARY` 列用 `0x00` 填充到 10 字节。

