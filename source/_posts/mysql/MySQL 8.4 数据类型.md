---
title: MySQL 8.4 数据类型
published: true
layout: post
date: 2026-03-25 08:50:00
permalink: /mysql/mysql-84-data-types.html
categories: [MySQL]
tags: [MySQL, 数据类型, SQL, 8.4]
---

## 一、数值类型

MySQL 8.4 支持完整的 SQL 数值类型，包括整数、定点数、浮点数和位值类型。所有数值类型都可以有可选的 `` UNSIGNED `` 属性来指定无符号范围。

### 1.1 整数类型

整数类型（Integer Types）包括 `` TINYINT ``、`` SMALLINT ``、`` MEDIUMINT ``、`` INT ``、`` BIGINT `` 五种，语法如下：

```sql
col_name { TINYINT | SMALLINT | MEDIUMINT | INT | INTEGER | BIGINT } [UNSIGNED]
```

| 类型 | 有符号范围 | 无符号范围 | 存储字节 |
|------|-----------|-----------|---------|
| `` TINYINT `` | `` -128 ~ 127 `` | `` 0 ~ 255 `` | 1 |
| `` SMALLINT `` | `` -32768 ~ 32767 `` | `` 0 ~ 65535 `` | 2 |
| `` MEDIUMINT `` | `` -8388608 ~ 8388607 `` | `` 0 ~ 16777215 `` | 3 |
| `` INT `` / `` INTEGER `` | `` -2147483648 ~ 2147483647 `` | `` 0 ~ 4294967295 `` | 4 |
| `` BIGINT `` | `` -2^63 ~ 2^63-1 `` | `` 0 ~ 2^64-1 `` | 8 |

**创建表示例：**

```sql
CREATE TABLE int_examples (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tiny_col TINYINT UNSIGNED,
    big_col BIGINT
);
```

**插入数据验证范围：**

```sql
INSERT INTO int_examples (tiny_col, big_col) VALUES (255, 9223372036854775807);
SELECT * FROM int_examples;
```

```
+----+-----------+---------------------+
| id | tiny_col  | big_col             |
+----+-----------+---------------------+
|  1 |       255 | 9223372036854775807 |
+----+-----------+---------------------+
```

#### 1.1.1 SERIAL 属性

`` SERIAL `` 是独立的数据类型，等价于 `` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT ``：

```sql
col_name SERIAL
-- 等价于
-- col_name BIGINT UNSIGNED NOT NULL AUTO_INCREMENT
```

> **注意**：`SERIAL` 隐含 `NOT NULL`，且 MySQL 会自动为其添加 `UNIQUE` 约束，因此不能在同一列上重复声明 `PRIMARY KEY`。

```sql
CREATE TABLE serial_demo (
    id SERIAL,
    name VARCHAR(50)
);
INSERT INTO serial_demo (name) VALUES ('Alice'), ('Bob');
SELECT * FROM serial_demo;
```

```
+----+-------+
| id | name  |
+----+-------+
|  1 | Alice |
|  2 | Bob   |
+----+-------+
2 rows in set (0.00 sec)
```

#### 1.1.2 整数类型默认值与生成列

数值类型列支持字面量默认值和表达式默认值，以及生成列（Generated Column）语法：

```sql
col_name data_type GENERATED ALWAYS AS (expr) [VIRTUAL | STORED]
```

| 参数 | 说明 |
|------|------|
| `` GENERATED ALWAYS AS (expr) `` | 定义表达式生成列，`expr` 可引用同一表中其他列 |
| `` VIRTUAL ``（默认） | 表达式在读取时实时计算，不占用额外存储 |
| `` STORED `` | 表达式在写入时计算并持久化存储，支持索引 |

> **生成列限制**：`expr` 中只能引用同一行的列，不能使用子查询、存储函数或非确定性函数（如 `NOW()`、`RAND()`）。

**创建表示例：**

```sql
CREATE TABLE num_default_demo (
    id INT PRIMARY KEY,
    score INT DEFAULT 0,
    rating DECIMAL(3,1) DEFAULT 5.0,
    multiplier DECIMAL(5,2) GENERATED ALWAYS AS (score * 1.5) STORED
);
INSERT INTO num_default_demo (id, score) VALUES (1, 80);
SELECT * FROM num_default_demo;
```

```
+----+-------+--------+--------------+
| id | score | rating | multiplier   |
+----+-------+--------+--------------+
|  1 |    80 |    5.0 |       120.00 |
+----+-------+--------+--------------+
```

#### 1.1.4 整数类型存储需求

| 类型 | 存储字节 |
|------|---------|
| `` TINYINT `` | 1 |
| `` SMALLINT `` | 2 |
| `` MEDIUMINT `` | 3 |
| `` INT `` / `` INTEGER `` | 4 |
| `` BIGINT `` | 8 |

---

### 1.2 定点类型（DECIMAL / NUMERIC）

`` DECIMAL `` 和 `` NUMERIC `` 用于存储精确数值，适用于货币金额等需要高精度的场景。语法如下：

```sql
col_name DECIMAL(precision, scale) [UNSIGNED]
```

其中 `` precision `` 为总位数（1~65），`` scale `` 为小数位数（0~30），且 `` scale ≤ precision ``。

| 参数 | 说明 | 示例 |
|------|------|------|
| `` DECIMAL(10, 2) `` | 总共10位数字，2位小数 | `` 12345678.12 `` |
| `` DECIMAL(5, 0) `` | 整数，5位 | `` 99999 `` |
| `` DECIMAL(3, 2) `` | 小数部分占2位 | `` 9.99 `` |

**创建表示例：**

```sql
CREATE TABLE decimal_demo (
    id INT PRIMARY KEY,
    price DECIMAL(10, 2) NOT NULL,
    quantity INT
);
INSERT INTO decimal_demo VALUES (1, 99.99, 5), (2, 1234.50, 2);
SELECT * FROM decimal_demo;
```

```
+----+---------+----------+
| id | price   | quantity |
+----+---------+----------+
|  1 |   99.99 |        5 |
|  2 | 1234.50 |        2 |
+----+---------+----------+
```

**类型计算示例（精确性验证）：**

```sql
SELECT price * quantity AS total FROM decimal_demo WHERE id = 1;
SELECT price FROM decimal_demo WHERE price = 99.99;
```

```
+---------+
| total   |
+---------+
| 499.95  |
+---------+
1 row in set (0.00 sec)

+---------+
| price   |
+---------+
|   99.99 |
+---------+
```

**DECIMAL 存储需求**：MySQL 8.4 采用二进制压缩格式存储 DECIMAL 值，整数部分和小数部分分别计算后相加。每 9 位数字占 4 字节，剩余 1~8 位数字按以下规则计字节：

| 剩余位数 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---------|---|---|---|---|---|---|---|---|---|
| 存储字节 | 0 | 1 | 1 | 2 | 2 | 3 | 3 | 4 | 4 |

> **计算公式**：存储 = `` ceil(整数位数 / 9) × 4 + ceil(小数位数 / 9) × 4 ``，其中 `` ceil(x) `` 为向上取整。

常用类型存储对照：

| 类型 | 整数位 | 小数位 | 整数部分存储 | 小数部分存储 | 总计 |
|------|--------|--------|------------|------------|------|
| `` DECIMAL(3,0) `` | 3 | 0 | 2 字节（3位→2字节） | 0 | 2 字节 |
| `` DECIMAL(5,2) `` | 3 | 2 | 2 字节 | 1 字节（2位→1字节） | 3 字节 |
| `` DECIMAL(9,0) `` | 9 | 0 | 4 字节（9位整除） | 0 | 4 字节 |
| `` DECIMAL(10,2) `` | 8 | 2 | 4 字节 | 1 字节 | **5 字节** |
| `` DECIMAL(10,5) `` | 5 | 5 | 3 字节（5位→3字节） | 3 字节 | 6 字节 |
| `` DECIMAL(15,2) `` | 13 | 2 | 6 字节（13位→6字节） | 1 字节 | 7 字节 |
| `` DECIMAL(18,0) `` | 18 | 0 | 8 字节（18位→8字节） | 0 | 8 字节 |
| `` DECIMAL(20,5) `` | 15 | 5 | 7 字节（15位→7字节） | 3 字节 | **10 字节** |
| `` DECIMAL(28,0) `` | 28 | 0 | 12 字节 | 0 | 12 字节 |
| `` DECIMAL(65,30) `` | 35 | 30 | 16 字节（35位→16字节） | 16 字节（30位→16字节） | 32 字节 |

---

### 1.3 浮点类型

浮点类型用于存储近似数值，包括 `` FLOAT `` 和 `` DOUBLE `` 两种。

```sql
col_name FLOAT(precision) [UNSIGNED]
col_name DOUBLE [UNSIGNED]
```

| 类型 | 存储字节 | 精度 | 说明 |
|------|---------|------|------|
| `` FLOAT `` | 4 | ~7 位十进制 | 可指定 `` FLOAT(p) ``，`` p ≤ 24 `` 时为单精度 |
| `` DOUBLE `` | 8 | ~15 位十进制 | `` DOUBLE PRECISION `` 的别名 |

**创建表示例：**

```sql
CREATE TABLE float_demo (
    id INT PRIMARY KEY,
    rate FLOAT(10, 4),
    ratio DOUBLE
);
INSERT INTO float_demo VALUES (1, 3.14159265, 3.141592653589793);
SELECT * FROM float_demo;
```

```
+----+------------+--------------------+
| id | rate       | ratio              |
+----+------------+--------------------+
|  1 |  3.1416    | 3.141592653589793  |
+----+------------+--------------------+
```

**近似值问题示例：**

```sql
SELECT CAST('0.1' AS FLOAT) + 0.1 + 0.1 - 0.3 AS float_sum;
SELECT CAST('0.1' AS DECIMAL(1,1)) + 0.1 + 0.1 - 0.3 AS decimal_sum;
```

```
+------------------------------------------+
| float_sum                                |
+------------------------------------------+
| 0.0000000014901161415892261             |
+------------------------------------------+
1 row in set (0.00 sec)

+---------------+
| decimal_sum   |
+---------------+
|           0.0 |
+---------------+
1 row in set (0.00 sec)
```

> ⚠️ 浮点数值计算存在精度误差，涉及精确比较或货币计算时优先使用 `` DECIMAL ``。

---

### 1.4 位值类型（BIT）

`` BIT `` 类型用于存储位域值（Bit-Value Type）。

```sql
col_name BIT(M)
```

`` M `` 指定位数，范围 1~64，默认为 1。

**创建表示例：**

```sql
CREATE TABLE bit_demo (
    id INT PRIMARY KEY,
    flags BIT(8)
);
INSERT INTO bit_demo VALUES (1, b'01010101'), (2, 255);
SELECT id, flags, BIN(flags), HEX(flags) FROM bit_demo;
```

```
+----+-------+-----------+------------+
| id | flags | BIN(flags)| HEX(flags) |
+----+-------+-----------+------------+
|  1 |    85 | 1010101   | 55         |
|  2 |   255 | 11111111  | FF         |
+----+-------+-----------+------------+
```

**位运算示例：**

```sql
SELECT flags, flags & b'01000000', flags | b'00000001' FROM bit_demo;
```

```
+-------+---------------------+----------------------+
| flags | flags & b'01000000' | flags|b'00000001'    |
+-------+---------------------+----------------------+
|    85 |                  64 |                   85 |
|   255 |                  64 |                  255 |
+-------+---------------------+----------------------+
```

**BIT 存储需求**：约 `` (M+7)/8 `` 字节。例如 `BIT(8)` 占用 1 字节，`BIT(16)` 占用 2 字节。

---

## 二、日期和时间类型

MySQL 8.4 的日期和时间类型包括 `` DATE ``、`` TIME ``、`` DATETIME ``、`` TIMESTAMP ``、`` YEAR `` 五种，用于存储日期、时间或两者的组合。

### 2.1 DATE 类型

`` DATE `` 类型用于存储日期值，格式为 `` 'YYYY-MM-DD' ``，范围 `` '1000-01-01' ~ '9999-12-31' ``。

```sql
col_name DATE
```

**示例：**

```sql
CREATE TABLE date_demo (
    id INT PRIMARY KEY,
    birth_date DATE
);
INSERT INTO date_demo VALUES (1, '1995-07-15'), (2, '2000-01-01');
SELECT * FROM date_demo;
```

```
+----+------------+
| id | birth_date |
+----+------------+
|  1 | 1995-07-15 |
|  2 | 2000-01-01 |
+----+------------+
```

**日期函数示例：**

```sql
SELECT CURDATE(), DATEDIFF('2026-03-25', birth_date) AS days_lived FROM date_demo;
```

```
+------------+-------------+
| CURDATE()  | days_lived  |
+------------+-------------+
| 2026-03-25 |      11215  |
| 2026-03-25 |       9584  |
+------------+-------------+
```

**DATE 存储需求**：固定 3 字节。

---

### 2.2 TIME 类型

`` TIME `` 类型用于存储时间值或时间间隔，格式为 `` 'HH:MM:SS' `` 或 `` 'HHH:MM:SS' ``（支持负值和大范围）。

```sql
col_name TIME [(fsp)]
```

`` fsp `` 为小数秒精度，范围 0~6。

| 格式 | 示例 | 说明 |
|------|------|------|
| `` 'HH:MM:SS' `` | `` '12:30:45' `` | 正常时间 |
| `` 'HHH:MM:SS' `` | `` '123:45:00' `` | 超过24小时的间隔 |
| `` '-HH:MM:SS' `` | `` '-12:00:00' `` | 负时间间隔 |

> **理解 TIME 的双重语义**：MySQL 中 `` TIME `` 既可以表示**一天内的时间点**（如 `08:30:00`），也可以表示**时间长度/间隔**（如项目工时 `100:00:00`）。这种双重语义是理解超24小时和负值的关键。

**超过24小时的间隔**：用于记录时间长度而非时刻。`100:00:00` 表示 100 小时的时长，可用于工时统计、项目累计耗时、倒班周期等场景。小时部分不限于 0~23。

**负时间间隔**：表示"向前或向后"的相对时间差，常用于计算结果为负的场景。

```sql
-- TIMEDIFF 计算两个时间点的差值，结果可能为负
SELECT TIMEDIFF('06:00:00', '08:00:00') AS time_diff;
SELECT TIMEDIFF('23:00:00', '08:30:00') AS work_hours;
```

```
+-------------+
| time_diff   |
+-------------+
| -02:00:00  |
+-------------+
1 row in set (0.00 sec)

+------------+
| work_hours |
+------------+
| 14:30:00   |
+------------+
```

**示例：**

```sql
CREATE TABLE time_demo (
    id INT PRIMARY KEY,
    duration TIME(3)
);
INSERT INTO time_demo VALUES (1, '02:30:45.123'), (2, '100:00:00'), (3, '-01:30:00');
SELECT * FROM time_demo;
```

```
+----+---------------+
| id | duration      |
+----+---------------+
|  1 | 02:30:45.123  |
|  2 | 100:00:00.000 |
|  3 | -01:30:00.000 |
+----+---------------+
```

**TIME 存储需求**：3 字节 + 0~3 字节（fsp）。`TIME(0)` 占 3 字节，`TIME(6)` 占 9 字节。

---

### 2.3 DATETIME 和 TIMESTAMP 类型

`` DATETIME `` 和 `` TIMESTAMP `` 都用于存储日期和时间的组合值，但行为上有重要区别：

```sql
col_name DATETIME [(fsp)]
col_name TIMESTAMP [(fsp)]
```

| 特性 | `` DATETIME `` | `` TIMESTAMP `` |
|------|---------------|----------------|
| 范围 | `` '1000-01-01 00:00:00.000000' ~ '9999-12-31 23:59:59.999999' `` | `` '1970-01-01 00:00:01.000000' ~ '2038-01-19 03:14:07.999999' `` |
| 时区 | 不受时区影响 | 存储时转为 UTC，读取时转回本地时区 |
| 自动更新 | 需显式设置 | 列可设 `` DEFAULT CURRENT_TIMESTAMP `` 和 `` ON UPDATE CURRENT_TIMESTAMP `` |
| 存储 | 固定 5 字节（不含fsp） | 固定 4 字节（不含fsp） |

**创建表示例：**

```sql
CREATE TABLE datetime_demo (
    id INT AUTO_INCREMENT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    event_time DATETIME
);
INSERT INTO datetime_demo (event_time) VALUES ('2026-03-25 10:00:00');
SELECT * FROM datetime_demo;
```

```
+----+---------------------+---------------------+---------------------+
| id | created_at          | updated_at          | event_time          |
+----+---------------------+---------------------+---------------------+
|  1 | 2026-03-25 08:54:00 | 2026-03-25 08:54:00 | 2026-03-25 10:00:00 |
+----+---------------------+---------------------+---------------------+
```

> **时区行为验证**：设置会话时区后，`TIMESTAMP` 值会自动转换，而 `DATETIME` 保持不变。

```sql
SET TIME_ZONE = '+06:00';
SELECT NOW(), FROM_UNIXTIME(UNIX_TIMESTAMP()) AS ts_test;
```

---

### 2.4 自动初始化与自动更新

在 MySQL 8.4 中，`` TIMESTAMP `` 和 `` DATETIME `` 列支持自动初始化和自动更新：

```sql
col_name TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
col_name DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
col_name DATETIME DEFAULT CURRENT_TIMESTAMP  -- 仅自动初始化
```

**多列场景示例：**

```sql
CREATE TABLE auto_demo (
    id INT PRIMARY KEY,
    create_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    create_dt DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_dt DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
INSERT INTO auto_demo (id) VALUES (1);
SELECT * FROM auto_demo;

-- 更新数据后，upudate事件会发生变化
UPDATE auto_demo SET id = 2 WHERE id = 1;
SELECT * FROM auto_demo;
```

```
+----+---------------------+---------------------+---------------------+---------------------+
| id | create_ts           | update_ts           | create_dt           | update_dt           |
+----+---------------------+---------------------+---------------------+---------------------+
|  1 | 2026-03-25 17:38:11 | 2026-03-25 17:38:11 | 2026-03-25 17:38:11 | 2026-03-25 17:38:11 |
+----+---------------------+---------------------+---------------------+---------------------


+----+---------------------+---------------------+---------------------+---------------------+
| id | create_ts           | update_ts           | create_dt           | update_dt           |
+----+---------------------+---------------------+---------------------+---------------------+
|  2 | 2026-03-25 17:38:11 | 2026-03-25 17:38:23 | 2026-03-25 17:38:11 | 2026-03-25 17:38:23 |
+----+---------------------+---------------------+---------------------+---------------------+

```

**DATETIME / TIMESTAMP 存储需求**：

| 类型 | 不含 fsp | 含 fsp (0~6) |
|------|---------|-------------|
| `` DATETIME `` | 5 字节 | 5 + fsp 字节 |
| `` TIMESTAMP `` | 4 字节 | 4 + fsp 字节 |

---

### 2.5 YEAR 类型

`` YEAR `` 类型用于存储年份值，格式为 4 位数字，范围 1901~2155，或 0000。

```sql
col_name YEAR
```

**示例：**

```sql
CREATE TABLE year_demo (
    id INT PRIMARY KEY,
    graduation_year YEAR
);
INSERT INTO year_demo VALUES (1, 2026), (2, '2025'), (3, 1901);
SELECT * FROM year_demo;
```

```
+----+------------------+
| id | graduation_year  |
+----+------------------+
|  1 |             2026 |
|  2 |             2025 |
|  3 |             1901 |
+----+------------------+
```

**YEAR 存储需求**：固定 1 字节。

---

## 三、字符串类型

MySQL 8.4 的字符串类型包括字符类型（CHAR/VARCHAR）、二进制类型（BINARY/VARBINARY）、文本类型（BLOB/TEXT）、枚举类型（ENUM）和集合类型（SET）。

### 3.1 CHAR 和 VARCHAR

`` CHAR `` 是固定长度字符串，`` VARCHAR `` 是可变长度字符串。

```sql
col_name CHAR(M) [CHARACTER SET charset_name] [COLLATE collation_name]
col_name VARCHAR(M) [CHARACTER SET charset_name] [COLLATE collation_name]
```

| 类型 | 长度范围 | 存储特性 |
|------|---------|---------|
| `` CHAR(M) `` | 0~255 | 固定长度，不足部分用空格填充，检索时自动去除 |
| `` VARCHAR(M) `` | 0~65535（受行限制） | 可变长度，只存储实际字符，末尾保留1~2字节存储长度 |

**创建表示例：**

```sql
CREATE TABLE string_demo (
    id INT PRIMARY KEY,
    code CHAR(5),
    name VARCHAR(100)
);
INSERT INTO string_demo VALUES (1, 'A', 'Alice'), (2, 'ABC', 'Bob');
SELECT id, code, LENGTH(code), name, LENGTH(name) FROM string_demo;
```

```
+----+------+-------------+-------+-------------+
| id | code | LENGTH(code)| name  | LENGTH(name)|
+----+------+-------------+-------+-------------+
|  1 | A    |           1 | Alice |           5 |
|  2 | ABC  |           3 | Bob   |           3 |
+----+------+-------------+-------+-------------+
```

**空格处理示例：**

```sql
SELECT CHAR_LENGTH('hello  ') AS len, CHAR_LENGTH(RTRIM('hello  ')) AS trimmed;
```

```
+------+----------+
| len  | trimmed  |
+------+----------+
|    7 |        5 |
+------+----------+
```

#### 3.1.1 字符集与排序规则

字符类型支持通过 `CHARACTER SET`（简称 `CHARSET`）指定字符集，`COLLATE` 指定排序规则：

```sql
-- 使用 utf8mb4 字符集，unicode 排序规则
name VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci

-- 简写形式
name VARCHAR(100) CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci
```

> **编码建议**：MySQL 8.4 推荐使用 `` utf8mb4 `` 字符集，它支持完整的 Unicode（包括 emoji），而旧的 `` utf8 `` 只支持 3 字节的 Unicode 子集。

**排序规则影响示例：**

```sql
CREATE TABLE collate_demo (
    id INT PRIMARY KEY,
    name VARCHAR(50) COLLATE utf8mb4_general_ci
);
INSERT INTO collate_demo VALUES (1, 'Alice'), (2, 'alice'), (3, 'ALICE');
SELECT * FROM collate_demo WHERE name = 'alice';
```

```
+----+-------+
| id | name  |
+----+-------+
|  1 | Alice |
|  2 | alice |
|  3 | ALICE |
+----+-------+
```

> `utf8mb4_general_ci` 不区分大小写（ci = case insensitive），所以三条记录都匹配。

#### 3.1.2 CHAR / VARCHAR 存储需求

| 类型 | 存储说明 |
|------|---------|
| `` CHAR(M) `` | `` M × W `` 字节（`` W `` 为字符集单字符最大字节数）。`CHAR(5)` 在 `utf8mb4` 下固定占 20 字节 |
| `` VARCHAR(M) `` | `` L + 1~2 `` 字节（`` L `` 为实际字符占用的字节数）。`utf8mb4` 字符最多占 4 字节，因此 `VARCHAR(100)` 最多约 401 字节 |

---

### 3.2 BINARY 和 VARBINARY

二进制类型与字符类型类似，但存储的是字节序列而非字符。比较和排序基于字节值。

```sql
col_name BINARY(M)
col_name VARBINARY(M)
```

| 类型 | 长度范围 | 说明 |
|------|---------|------|
| `` BINARY(M) `` | 0~255 | 固定长度，字节级比较 |
| `` VARBINARY(M) `` | 0~65535 | 可变长度，存储实际字节 |

**示例：**

```sql
CREATE TABLE binary_demo (
    id INT PRIMARY KEY,
    hash BINARY(32)
);
INSERT INTO binary_demo VALUES (1, UNHEX('616263'));
SELECT id, hash, HEX(hash) FROM binary_demo;
```

```
+----+----------------------------------+-------------+
| id | hash                             | HEX(hash)   |
+----+----------------------------------+-------------+
|  1 | 0x616263                         | 616263      |
+----+----------------------------------+-------------+
```

**BINARY / VARBINARY 存储需求**：与 CHAR/VARCHAR 类似，但以字节计：`BINARY(M)` 固定占 `M` 字节，`VARBINARY(M)` 为 `L + 1~2` 字节。

---

### 3.3 BLOB 和 TEXT 类型

BLOB（Binary Large Object）用于存储大型二进制数据，TEXT 用于存储大型字符串。

```sql
col_name TINYTEXT | TEXT | MEDIUMTEXT | LONGTEXT
col_name TINYBLOB | BLOB | MEDIUMBLOB | LONGBLOB
```

| 类型 | 最大长度 | 存储需求（额外字节） |
|------|---------|---------------------|
| `` TINYTEXT `` / `` TINYBLOB `` | 255 字节 | +1 字节 |
| `` TEXT `` / `` BLOB `` | 65,535 字节 | +2 字节 |
| `` MEDIUMTEXT `` / `` MEDIUMBLOB `` | 16,777,215 字节 | +3 字节 |
| `` LONGTEXT `` / `` LONGBLOB `` | 4,294,967,295 字节 | +4 字节 |

**创建表示例：**

```sql
CREATE TABLE blob_demo (
    id INT PRIMARY KEY,
    content TEXT,
    file_data LONGBLOB
);
INSERT INTO blob_demo VALUES (1, 'This is a long text content', NULL);
SELECT id, LEFT(content, 10), LENGTH(content) FROM blob_demo;
```

```
+----+------------------+---------------+
| id | LEFT(content,10) | LENGTH(content)|
+----+------------------+---------------+
|  1 | This is a       |             26 |
+----+------------------+---------------+
```

> **索引限制**：`TEXT` 和 `BLOB` 列在创建索引时必须指定前缀长度。`FULLTEXT` 索引仅支持 `CHAR`、`VARCHAR` 和 `TEXT`。

**BLOB / TEXT 存储需求**：实际字节数 + 额外字节（1/2/3/4 字节，用于记录长度）。

---

### 3.4 ENUM 类型

`` ENUM `` 是字符串对象，其值来自创建表时定义的枚举列表。**每个字段每行只能存储一个值**，存储的值必须是定义列表中的成员，不存在或超出均会报错。

```sql
col_name ENUM('value1', 'value2', ...) [CHARACTER SET charset] [COLLATE collation]
```

> **核心约束**：ENUM 是**强制单选**字段。尝试存储多个值（如 `'red,blue'`）或存储定义之外的值时，MySQL 会报错 `Data truncated`。

**创建表示例：**

```sql
CREATE TABLE order_status (
    id INT AUTO_INCREMENT PRIMARY KEY,
    status ENUM('pending', 'processing', 'completed', 'cancelled') DEFAULT 'pending'
);
INSERT INTO order_status (status) VALUES ('pending');
INSERT INTO order_status (status) VALUES ('completed');
SELECT * FROM order_status;
```

```
+----+-------------+
| id | status      |
+----+-------------+
|  1 | pending     |
|  2 | completed   |
+----+-------------+
```

**多值存储会报错：**

```sql
INSERT INTO order_status (status) VALUES ('pending,completed');
```

```
ERROR 1265 (01000): Data truncated for column 'status' at row 1
```

> MySQL 拒绝了 `pending,completed`，因为 ENUM 字段同一行只能存放一个成员。

**内部存储机制**：ENUM 成员在内部以整数索引存储（从 1 开始），这带来了两个重要特性：

```sql
SELECT id, status, status + 0 AS enum_index FROM order_status;
```

```
+----+-------------+------------+
| id | status      | enum_index |
+----+-------------+------------+
|  1 | pending     |          1 |
|  2 | completed   |          3 |
+----+-------------+------------+
```

> **按定义顺序排序**：ENUM 值按定义列表中的顺序（而非字母顺序）排序和比较。`pending` 是第1个，`completed` 是第3个，所以 `ORDER BY status` 会按定义顺序排列。

**典型使用场景**：

| 场景 | ENUM 成员示例 |
|------|-------------|
| 订单状态 | `'pending'`, `'processing'`, `'completed'`, `'cancelled'` |
| 性别 | `'male'`, `'female'`, `'other'` |
| 布尔开关 | `'yes'`, `'no'` |
| 会员等级 | `'bronze'`, `'silver'`, `'gold'`, `'platinum'` |
| 文章可见性 | `'draft'`, `'published'`, `'archived'` |

**ENUM 存储需求**：1 或 2 字节（取决于成员数量，≤255 个成员用 1 字节）。

---

### 3.5 SET 类型

`` SET `` 是字符串对象，**每行可以存储零个、一个或多个值**，所有值都必须来自定义列表。与 ENUM 的本质区别在于：SET 允许多选。

```sql
col_name SET('value1', 'value2', ...) [CHARACTER SET charset] [COLLATE collation]
```

> **核心约束**：SET 是**多选**字段。最多可定义 64 个成员，每行可以存储其中的任意组合（零个到全部），多个值之间以逗号分隔存储在同一字段中。

**创建表示例：**

```sql
CREATE TABLE user_permissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    permissions SET('read', 'write', 'delete', 'admin', 'audit') DEFAULT 'read'
);
INSERT INTO user_permissions (permissions) VALUES ('');                    -- 零个权限
INSERT INTO user_permissions (permissions) VALUES ('read');               -- 一个权限
INSERT INTO user_permissions (permissions) VALUES ('read,write');        -- 两个权限
INSERT INTO user_permissions (permissions) VALUES ('read,write,admin');  -- 三个权限
SELECT * FROM user_permissions;
```

```
+----+------------------------+
| id | permissions            |
+----+------------------------+
|  1 |                        |
|  2 | read                   |
|  3 | read,write             |
|  4 | read,write,admin      |
+----+------------------------+
```

**存储不存在的值会报错：**

```sql
INSERT INTO user_permissions (permissions) VALUES ('read,unknown');
```

```
ERROR 1265 (01000): Data truncated for column 'permissions' at row 1
```

**查询包含特定值的行**：SET 字段使用 `` FIND_IN_SET() `` 函数按成员名查询：

```sql
SELECT * FROM user_permissions WHERE FIND_IN_SET('admin', permissions) > 0;
```

```
+----+----------------------+
| id | permissions          |
+----+----------------------+
|  4 | read,write,admin    |
+----+----------------------+
```

**典型使用场景**：

| 场景 | SET 成员示例 |
|------|-------------|
| 用户权限 | `'read'`, `'write'`, `'delete'`, `'admin'` |
| 文章标签 | `'tech'`, `'news'`, `'life'`, `'ai'`, `'python'` |
| 商品特性 | `'hot'`, `'new'`, `'sale'`, `'gift'` |
| 用户兴趣 | `'music'`, `'sport'`, `'travel'`, `'reading'` |
| 通知渠道 | `'email'`, `'sms'`, `'push'`, `'wechat'` |

**ENUM 与 SET 的核心区别**：

| 特性 | ENUM | SET |
|------|------|-----|
| 每行可存值的数量 | **只能存 1 个** | **可以存 0~多个** |
| 多值存储 | 报错 `Data truncated` | 逗号分隔，正常存储 |
| 适用场景 | 单选字段 | 多选字段 |
| 最大成员数 | 65,535 | 64 |
| 典型用例 | 订单状态、性别 | 权限、标签、特性 |

> **选型建议**：如果字段在任何情况下都只会有一个选项，选 ENUM（更紧凑、有排序语义）；如果字段可能有多个选项，选 SET（同一字段支持任意组合）。

**SET 存储需求**：1、2、3、4 或 8 字节（取决于成员数量和实际存储的位图）。

---

## 四、JSON 数据类型

MySQL 8.4 原生支持 `` JSON `` 类型，用于存储和高效操作 JSON 文档。JSON 列会对存储的值进行验证，不合法的 JSON 会报错。

```sql
col_name JSON
```

### 4.1 插入 JSON 数据

```sql
CREATE TABLE json_demo (
    id INT PRIMARY KEY,
    meta JSON
);
INSERT INTO json_demo VALUES (1, '{"name": "Alice", "age": 28, "skills": ["Python", "MySQL"]}');
INSERT INTO json_demo VALUES (2, JSON_OBJECT('name', 'Bob', 'score', 95.5));
SELECT * FROM json_demo;
```

```
+----+----------------------------------------------------------+
| id | meta                                                     |
+----+----------------------------------------------------------+
|  1 | {"age": 28, "name": "Alice", "skills": ["Python", "MySQL"]}|
+----+----------------------------------------------------------+
|  2 | {"name": "Bob", "score": 95.5}                          |
+----+----------------------------------------------------------+
```

### 4.2 JSON 默认值

JSON 列支持字面量默认值和表达式默认值。表达式作为默认值时，需用圆括号包裹：

```sql
col_name JSON DEFAULT (expression)
```

> `JSON_OBJECT(...)` 等 JSON 函数作为默认值时，必须写在 `DEFAULT` 后的圆括号内，否则语法报错。

```sql
CREATE TABLE json_default_demo (
    id INT AUTO_INCREMENT PRIMARY KEY,
    meta JSON DEFAULT NULL,
    config JSON DEFAULT (JSON_OBJECT('theme', 'dark'))
);
INSERT INTO json_default_demo (id) VALUES (1);
SELECT * FROM json_default_demo;
```

```
+----+------+--------+
| id | meta | config             |
+----+------+--------+
|  1 | NULL | {"theme": "dark"}  |
+----+------+--------+
```

### 4.3 JSON 路径表达式

使用 `` $ `` 引用整个文档，点号 `` . `` 访问对象属性，方括号 `` [] `` 访问数组元素。

```sql
SELECT id, meta->>'$.name' AS name, meta->>'$.skills[0]' AS first_skill FROM json_demo;
```

```
+----+-------+--------------+
| id | name  | first_skill  |
+----+-------+--------------+
|  1 | Alice | Python       |
|  2 | Bob   | NULL         |
+----+-------+--------------+
```

### 4.4 JSON 函数

| 函数 | 说明 | 示例 |
|------|------|------|
| `` JSON_OBJECT(k, v, ...) `` | 创建 JSON 对象 | `` JSON_OBJECT('a', 1, 'b', 2) `` |
| `` JSON_ARRAY(val, ...) `` | 创建 JSON 数组 | `` JSON_ARRAY(1, 2, 3) `` |
| `` JSON_EXTRACT(json, path) `` | 提取路径下的值 | `` JSON_EXTRACT(meta, '$.name') `` |
| `` JSON_SET(json, path, val) `` | 设置路径下的值 | `` JSON_SET(meta, '$.age', 30) `` |
| `` JSON_MERGE_PATCH(a, b) `` | 合并两个 JSON（RFC 7396） | `` JSON_MERGE_PATCH(a, b) `` |
| `` JSON_KEYS(json) `` | 获取对象的所有键 | `` JSON_KEYS(meta) `` |
| `` JSON_LENGTH(json) `` | 获取元素数量 | `` JSON_LENGTH(meta) `` |

**JSON 操作示例：**

```sql
UPDATE json_demo SET meta = JSON_SET(meta, '$.age', 29) WHERE id = 1;
SELECT JSON_MERGE_PATCH('{"a":1}', '{"b":2}', '{"a":3}') AS merged;
SELECT JSON_KEYS(meta) AS key_list FROM json_demo WHERE id = 1;
```

```
+------------+
| merged     |
+------------+
| {"a":3,"b":2} |
+------------+

+------------+
| key_list  |
+------------+
| ["age", "name", "skills"] |
+------------+
```

### 4.5 JSON 索引

MySQL 8.4 支持在 JSON 列上创建函数索引：

```sql
CREATE TABLE json_indexed (
    id INT PRIMARY KEY,
    data JSON,
    name VARCHAR(50) GENERATED ALWAYS AS (data->>'$.name') STORED
);
CREATE INDEX idx_name ON json_indexed(name);
INSERT INTO json_indexed (id, data) VALUES (1, '{"name": "Alice"}');
```

> **性能优化**：`STORED` 生成列将计算结果持久化存储，可创建普通索引。`VIRTUAL` 生成列不占用额外存储，但无法直接索引。

### 4.6 JSON 存储需求

JSON 内部以 BLOB 形式存储，存储空间取决于文档的实际大小和序列化开销。

---
