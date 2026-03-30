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

`字符集`（`Character Set`）定义了 MySQL 可以存储的字符集合，`排序规则`（`Collation`）则定义了字符之间的比较和排序规则。每个字符集对应一个或多个排序规则。

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

MySQL 在四个层级上设置字符集和排序规则：服务器（server）、数据库（database）、表（table）、列（column）。

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
| `_ai` | 重音不敏感 |
| `_as` | 重音敏感 |
| `_ci` | 大小写不敏感 |
| `_cs` | 大小写敏感 |
| `_ks` | 假名敏感 |
| `_bin` | 二进制（按码点值比较） |

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

排序规则名称中的数字表示 `Unicode Collation Algorithm`（`UCA`）版本：

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

查看排序规则的 `PAD` 属性：

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

> 所有 `0900` 系列排序规则均为 `NO PAD`，早期排序规则为 `PAD SPACE`。

## 七、`Unicode` 排序规则详解

### 7.1 `_general_ci` 与 `_unicode_ci` 的区别

`utf8mb4_general_ci` 性能更好但精度较低，不支持扩展（expansion）和收缩（contraction）；`utf8mb4_unicode_ci` 支持这些特性。

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

**验证 —— UCA 4.0.0 扩展权重：**

```sql
SELECT HEX(WEIGHT_STRING('a' COLLATE utf8mb4_unicode_ci)) AS a_weight;
SELECT HEX(WEIGHT_STRING('ß' COLLATE utf8mb4_unicode_ci)) AS ss_weight;
```

```
+-----------+
| a_weight  |
+-----------+
| 0E33      |
+-----------+
| ss_weight |
+-----------+
| 0FEA0FEA  |
+-----------+
```

> `ß` 的权重为 `0FEA0FEA`（两个权重元素），表示它被展开为 `ss` 进行排序——这就是扩展（expansion）。

### 7.2 German 排序规则差异

| 排序规则 | Ä = A | Ö = O | Ü = U | ß = s | ß = ss |
|----------|-------|-------|-------|-------|--------|
| `latin1_german1_ci` (`DIN-1`) | ✅ | ✅ | ✅ | ✅ | ❌ |
| `latin1_german2_ci` (`DIN-2`) | ✅ | ✅ | ✅ | ❌ | ✅ |

**验证 —— `DIN-1` vs `DIN-2`：**

```sql
CREATE TABLE german1 (c CHAR(10))
    CHARACTER SET latin1 COLLATE latin1_german1_ci;
INSERT INTO german1 VALUES ('Bar'), ('Bär');
SELECT 'german1_ci' AS col, c FROM german1 WHERE c = 'Bär';
```

```
+----------------+------+
| col            | c    |
+----------------+------+
| german1_ci     | Bar  |
| german1_ci     | Bär  |
+----------------+------+
```

> `latin1_german1_ci`（`DIN-1`）中 `Ä = A`，所以 `'Bar'` 也满足 `WHERE c = 'Bär'`。

```sql
CREATE TABLE german2 (c CHAR(10))
    CHARACTER SET latin1 COLLATE latin1_german2_ci;
INSERT INTO german2 VALUES ('Bar'), ('Bär');
SELECT 'german2_ci' AS col, c FROM german2 WHERE c = 'Bär';
```

```
+----------------+------+
| col            | c    |
+----------------+------+
| german2_ci     | Bär  |
+----------------+------+
```

> `latin1_german2_ci`（`DIN-2`）中 `Ä = AE`（不等于 `A`），所以只有 `'Bär'` 匹配。

### 7.3 日语假名敏感排序

日语排序规则支持假名敏感性（`Kana Sensitivity`，`_ks` 后缀）：

- `utf8mb4_ja_0900_as_cs`：平假名和片假名在排序时视为相等
- `utf8mb4_ja_0900_as_cs_ks`：区分平假名和片假名

### 7.4 二进制排序规则

`utf8mb4` 有两个二进制排序规则：

- `utf8mb4_bin`：基于码点值比较，`PAD SPACE`
- `utf8mb4_0900_bin`：基于 UTF-8 编码字节比较，`NO PAD`，性能更好

## 八、排序规则强制转换（`Coercibility`）

当比较中两个操作数具有不同排序规则时，MySQL 根据强制转换值（`Coercibility`）决定使用哪个排序规则。值越低优先级越高：

| 强制值 | 来源 | 示例 |
|--------|------|------|
| 0 | 显式 `COLLATE` 子句 | `'abc' COLLATE utf8mb4_bin` |
| 1 | 不同排序规则字符串拼接 | `CONCAT(col1, 'abc')` |
| 2 | 列或存储过程参数 | `column_name` |
| 3 | 系统常量 | `USER()`, `VERSION()` |
| 4 | 字面量字符串 | `'abc'` |
| 5 | 数值或时间值 | `1000`, `'2020-01-01'` |
| 6 | `NULL` | `NULL` |

**验证 —— 强制值测试：**

```sql
SELECT COERCIBILITY(_utf8mb4'A' COLLATE utf8mb4_bin) AS coercibility_0;
SELECT COERCIBILITY(VERSION()) AS coercibility_3;
SELECT COERCIBILITY('A') AS coercibility_4;
SELECT COERCIBILITY(1000) AS coercibility_5;
SELECT COERCIBILITY(NULL) AS coercibility_6;
```

```
+---------------+
| coercibility_0|
+---------------+
|             0 |
+---------------+
| coercibility_3|
+---------------+
|             3 |
+---------------+
| coercibility_4|
+---------------+
|             4 |
+---------------+
| coercibility_5|
+---------------+
|             5 |
+---------------+
| coercibility_6|
+---------------+
|             6 |
+---------------+
```

强制转换规则补充：若两边强制值相同且均为 `Unicode` 或均为非 `Unicode`，则报错；若一边为 `Unicode` 而另一边不是，`Unicode` 端获胜并自动转换非 `Unicode` 端。

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

## 十、`NCHAR` 与 `National Character`

标准 SQL 的 `NCHAR` 表示使用预定义字符集，MySQL 将其实现为 `utf8mb3`（已弃用）。使用 `NCHAR`/`NATIONAL` 会产生警告：

```sql
CREATE TABLE t_warn2 (c1 NCHAR(10));
SHOW WARNINGS;
```

```
+--------+------+--------------------------------------------------------------+
| Level  | Code | Message                                                     |
+--------+------+--------------------------------------------------------------+
| Warning|  3720| NATIONAL/NCHAR/NVARCHAR implies the character set UTF8MB3,  |
|        |      | which will be replaced by UTF8MB4 in a future release.      |
|        |      | Please consider using CHAR(x) CHARACTER SET UTF8MB4.        |
+--------+------+--------------------------------------------------------------+
```

**验证：** `N'test'` 的字符集为 `utf8mb3`，而非 `utf8mb4`：

```sql
SELECT CHARSET(N'test');
```

```
+----------------+
| CHARSET(N'test')|
+----------------+
| utf8mb3        |
+----------------+
```

## 十一、二进制字符集与 `_bin` 排序规则的区别

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

## 十二、`WEIGHT_STRING()` 与字符排序权重

`WEIGHT_STRING()` 函数返回字符的排序权重，可通过 `HEX()` 查看。

**验证 —— 二进制排序规则权重：**

```sql
SELECT HEX(WEIGHT_STRING(BINARY 'aA')) AS binary_weight;
SELECT HEX(WEIGHT_STRING('aA' COLLATE utf8mb4_bin)) AS utf8mb4_bin_weight;
```

```
+----------------+
| binary_weight  |
+----------------+
| 6141           |
+----------------+
| utf8mb4_bin_weight |
+--------------------+
| 000061000041     |
+--------------------+
```

> `BINARY 'aA'` 的权重为 `0x6141`（两个字节的码点值拼接）；`utf8mb4_bin` 的权重为 `000061000041`（每个字符 4 字节权重）。

## 十三、`lc_time_names` 与本地化

`lc_time_names` 控制日期函数返回的月份和星期名称语言：

```sql
SELECT @@lc_time_names;
SELECT DAYNAME('2020-01-01'), MONTHNAME('2020-01-01');
SET lc_time_names = 'zh_CN';
SELECT DAYNAME('2020-01-01'), MONTHNAME('2020-01-01');
```

```
+-----------------+
| @@lc_time_names |
+-----------------+
| en_US           |
+-----------------+
| DAYNAME('2020-01-01') | MONTHNAME('2020-01-01') |
+-----------------------+-------------------------+
| Wednesday             | January                 |
+-----------------------+-------------------------+
| DAYNAME('2020-01-01') | MONTHNAME('2020-01-01') |
+-----------------------+-------------------------+
| 星期三                | 一月                     |
+-----------------------+-------------------------+
```

## 十四、字符集使用建议

1. **新项目使用 `utf8mb4`**：`utf8mb3` 已弃用，`utf8mb4` 支持完整的 `Unicode` 字符（包括 emoji）
2. **默认排序规则 `utf8mb4_0900_ai_ci`**：基于 `UCA` 9.0.0，准确性高，性能好
3. **需要大小写敏感时**：使用 `utf8mb4_0900_as_cs`
4. **多语言应用**：使用语言特定排序规则（如 `utf8mb4_zh_0900_as_cs`）
5. **避免使用 `NCHAR`**：改用 `CHAR(x) CHARACTER SET utf8mb4`
6. **连接字符集**：客户端应显式设置 `SET NAMES utf8mb4`，确保通信编码一致
