---
title: MySQL 分区
date: 2026-04-01 08:27:00
tags: [分区, RANGE, LIST, HASH, KEY, 子分区]
categories: MySQL
---

## 一、分区概述

MySQL 分区（Partitioning）将一张表的数据按规则拆分到多个物理分区中，每个分区作为独立对象存储。分区函数基于用户给定的表达式计算整数值，从而决定数据行属于哪个分区。

分区属于**水平分区**——即同一表的不同行分配到不同物理分区。MySQL 8.4 不支持垂直分区（将不同列分配到不同分区），也没有引入垂直分区的计划。

### 1.1 支持的存储引擎

MySQL 8.4 中，仅 `InnoDB` 和 `NDB` 两个存储引擎支持分区。分区表的所有分区必须使用同一存储引擎，但不同分区表可以使用不同引擎。

使用 `ENGINE` 选项指定存储引擎时，该选项必须出现在所有分区选项之前：

```sql
CREATE TABLE ti (id INT, amount DECIMAL(7,2), tr_date DATE)
ENGINE=INNODB
PARTITION BY HASH(MONTH(tr_date))
PARTITIONS 6;
```

### 1.2 分区与主键/唯一键的关系

这是分区表中最重要的约束：**分区键必须是表中每个唯一键的超集**——即每个唯一键的所有列必须全部出现在分区键中。反过来说，MySQL 8.4 要求分区键是每个唯一键的子集。

以下表定义中，唯一键 `uk(name)` 与主键 `pk(id)` 没有共同列。由于主键 `(id)` 和唯一键 `(name)` 之间没有交集，不存在任何分区键能同时是两者的超集，因此该表**无法分区**：

```sql
CREATE TABLE tnp (
    id INT NOT NULL AUTO_INCREMENT,
    ref BIGINT NOT NULL,
    name VARCHAR(255),
    PRIMARY KEY pk (id),
    UNIQUE KEY uk (name)
);
-- 表本身可以正常创建

-- 尝试按 id 分区：唯一键 uk(name) 不包含列 id，报错
ALTER TABLE tnp PARTITION BY HASH(id) PARTITIONS 4;
-- ERROR 1503 (HY000): A UNIQUE INDEX must include all columns
-- in this partitioned table's partitioning function

-- 尝试按 name 分区：主键 pk(id) 不包含列 name，报错
ALTER TABLE tnp PARTITION BY KEY(name) PARTITIONS 4;
-- ERROR 1503 (HY000): A PRIMARY KEY must include all columns
-- in this partitioned table's partitioning function
```

解决方式：

- **将 `name` 加入主键**：主键改为 `(id, name)`，唯一键变为仅 `(id)`，此时可以按 `name` 进行 `KEY` 分区
- **将 `id` 加入唯一键**：唯一键改为 `(id, name)`，主键仍为 `(id)`，此时可以按 `id` 进行 `HASH` 分区
- **移除唯一键**：只保留主键，直接按 `id` 分区

### 1.3 分区的优势

- **容纳更多数据**：单表数据量可以超过单个磁盘分区的容量
- **快速删除旧数据**：通过 `DROP PARTITION` 删除整个分区，比 `DELETE` 高效得多
- **查询优化**：分区裁剪使查询只扫描相关分区，大幅提升性能
- **灵活维护**：可以单独对某个分区执行检查、修复、优化操作

## 二、分区类型

MySQL 8.4 支持以下分区类型：`RANGE`、`LIST`、`HASH`、`KEY`，以及基于它们的 `COLUMNS` 变体和 `LINEAR` 变体。

### 2.1 RANGE 分区

按连续范围划分分区，使用 `VALUES LESS THAN` 定义。范围必须**严格递增**，不重叠。建议在最后使用 `MAXVALUE` 作为"兜底"分区，接收所有超出定义范围的行。

语法格式：

```sql
PARTITION BY RANGE (expression) (
    PARTITION partition_name VALUES LESS THAN (expr),
    PARTITION partition_name VALUES LESS THAN (expr),
    ...
    PARTITION partition_name VALUES LESS THAN (MAXVALUE)
);
```

以下按 `store_id` 将员工表分为 4 个分区：

```sql
CREATE TABLE employees (
    id INT NOT NULL,
    fname VARCHAR(30),
    lname VARCHAR(30),
    hired DATE NOT NULL DEFAULT '1970-01-01',
    separated DATE NOT NULL DEFAULT '9999-12-31',
    job_code INT NOT NULL,
    store_id INT NOT NULL
)
PARTITION BY RANGE (store_id) (
    PARTITION p0 VALUES LESS THAN (6),
    PARTITION p1 VALUES LESS THAN (11),
    PARTITION p2 VALUES LESS THAN (16),
    PARTITION p3 VALUES LESS THAN (21)
);
```

插入数据，验证各行是否落入预期分区：

```sql
INSERT INTO employees VALUES
(1, 'Alice', 'Smith', '1998-03-15', '2005-06-01', 100, 3),   -- store_id=3 → p0
(2, 'Bob', 'Jones', '2000-07-20', '2010-12-31', 200, 8),    -- store_id=8 → p1
(3, 'Carol', 'White', '2005-01-10', '2015-03-15', 150, 12), -- store_id=12 → p2
(4, 'Dave', 'Brown', '2010-09-01', '2020-05-20', 300, 18); -- store_id=18 → p3

SELECT PARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employees';
```

添加带 `MAXVALUE` 的兜底分区，避免插入超出范围的 `store_id` 时报错：

```sql
ALTER TABLE employees PARTITION BY RANGE (store_id) (
    PARTITION p0 VALUES LESS THAN (6),
    PARTITION p1 VALUES LESS THAN (11),
    PARTITION p2 VALUES LESS THAN (16),
    PARTITION p3 VALUES LESS THAN MAXVALUE
);
```

按年份删除离职员工数据（删除分区即删除数据，比 `DELETE` 高效得多）：

```sql
-- 按年分区后，删除 1991 年前离职的员工
ALTER TABLE employees DROP PARTITION p0;
```

`VALUES LESS THAN` 中也可以使用表达式，只要表达式结果可与 `<` 比较：

```sql
CREATE TABLE employees (
    id INT NOT NULL,
    fname VARCHAR(30),
    lname VARCHAR(30),
    hired DATE NOT NULL DEFAULT '1970-01-01',
    separated DATE NOT NULL DEFAULT '9999-12-31',
    job_code INT,
    store_id INT
)
PARTITION BY RANGE (YEAR(separated)) (
    PARTITION p0 VALUES LESS THAN (1991),
    PARTITION p1 VALUES LESS THAN (1996),
    PARTITION p2 VALUES LESS THAN (2001),
    PARTITION p3 VALUES LESS THAN MAXVALUE
);
```

### 2.2 LIST 分区

按离散值列表划分分区，使用 `VALUES IN` 定义。分区之间不需要有序，但同一值不能出现在多个分区中。

语法格式：

```sql
PARTITION BY LIST (expression) (
    PARTITION partition_name VALUES IN (val1, val2, ...),
    PARTITION partition_name VALUES IN (val1, val2, ...),
    ...
);
```

按地区划分员工表（4 个地区对应不同 `store_id` 集合）：

```sql
CREATE TABLE employees (
    id INT NOT NULL,
    fname VARCHAR(30),
    lname VARCHAR(30),
    hired DATE NOT NULL DEFAULT '1970-01-01',
    separated DATE NOT NULL DEFAULT '9999-12-31',
    job_code INT,
    store_id INT
)
PARTITION BY LIST(store_id) (
    PARTITION pNorth VALUES IN (3,5,6,9,17),
    PARTITION pEast VALUES IN (1,2,10,11,19,20),
    PARTITION pWest VALUES IN (4,12,13,14,18),
    PARTITION pCentral VALUES IN (7,8,15,16)
);
```

与 `RANGE` 不同，`LIST` 没有类似 `MAXVALUE` 的兜底机制。如果插入的值不在任何分区列表中，语句报错。使用 `IGNORE` 关键字可以静默跳过不匹配的行：

```sql
-- 插入不匹配的值会报错：store_id=21 不属于任何地区分区
INSERT INTO employees VALUES (99, 'Zara', 'Lee', '2024-01-01', '2024-01-01', 999, 21);
-- ERROR 1526 (HY000): Table has no partition for value 21

-- 使用 IGNORE 静默跳过不匹配的行
INSERT IGNORE INTO employees VALUES
(99, 'Zara', 'Lee', '2024-01-01', '2024-01-01', 999, 21),
(100, 'Tom', 'Green', '2024-02-01', '2024-02-01', 100, 1),
(101, 'Amy', 'Brown', '2024-03-01', '2024-03-01', 101, 12);
-- Query OK, 2 rows affected, 1 warning
-- Records: 3  Duplicates: 0  Warnings: 1
-- Warning: Table has no partition for value 21（该行被静默跳过）
```

清空某个地区的所有数据，使用 `TRUNCATE PARTITION`：

```sql
-- 清空西部地区数据，但保留分区结构
ALTER TABLE employees TRUNCATE PARTITION pWest;
```

### 2.3 COLUMNS 分区

`RANGE COLUMNS` 和 `LIST COLUMNS` 是 `RANGE` 和 `LIST` 的扩展，支持以下特性：

- 支持**多列**作为分区键
- 支持**非整数类型**：整数类型、`DATE`、`DATETIME`、`CHAR`、`VARCHAR`、`BINARY`、`VARBINARY`

语法格式：

```sql
PARTITION BY RANGE COLUMNS (col1, col2, ...) (
    PARTITION partition_name VALUES LESS THAN (val1, val2, ...),
    ...
    PARTITION partition_name VALUES LESS THAN (MAXVALUE, MAXVALUE, ...)
);

PARTITION BY LIST COLUMNS (col1, col2, ...) (
    PARTITION partition_name VALUES IN (val1, val2, ...),
    ...
);
```

**RANGE COLUMNS** 的核心语义与 `RANGE` 不同：比较的是**元组（元组即多列值的列表）**，而不是标量值。

以下示例演示元组比较语义——插入 `(5,10)`、`(5,11)`、`(5,12)` 三个元组：

```sql
CREATE TABLE rc1 (a INT, b INT)
PARTITION BY RANGE COLUMNS(a, b) (
    PARTITION p0 VALUES LESS THAN (5, 12),
    PARTITION p3 VALUES LESS THAN (MAXVALUE, MAXVALUE)
);

INSERT INTO rc1 VALUES (5,10), (5,11), (5,12);

SELECT PARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rc1';
```

元组比较规则：`ROW(5,10) < ROW(5,12)` 和 `ROW(5,11) < ROW(5,12)` 为真，但 `ROW(5,12) < ROW(5,12)` 为假（相等），所以值 `(5,12)` 落入 `p3`。

#### 2.3.1 RANGE COLUMNS 字符串列分区

按姓氏首字母进行 `RANGE COLUMNS` 分区，验证字符串分区键的行为：

```sql
CREATE TABLE employees_by_lname (
    id INT NOT NULL, fname VARCHAR(30), lname VARCHAR(30),
    hired DATE NOT NULL DEFAULT '1970-01-01',
    separated DATE NOT NULL DEFAULT '9999-12-31',
    job_code INT NOT NULL, store_id INT NOT NULL
)
PARTITION BY RANGE COLUMNS (lname) (
    PARTITION p0 VALUES LESS THAN ('g'),
    PARTITION p1 VALUES LESS THAN ('m'),
    PARTITION p2 VALUES LESS THAN ('t'),
    PARTITION p3 VALUES LESS THAN (MAXVALUE)
);

INSERT INTO employees_by_lname VALUES
(1, 'Alice', 'Brown', '1990-01-01', '2010-01-01', 100, 1),  -- lname='Brown'  < 'g' → p0
(2, 'Bob', 'Green', '1992-03-15', '2012-03-15', 200, 2),     -- lname='Green'  < 'm' → p1
(3, 'Carol', 'Orange', '1994-06-20', '2014-06-20', 300, 3); -- lname='Orange' < 't' → p2

SELECT PARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employees_by_lname';
```

| PARTITION_NAME | TABLE_ROWS |
|----------------|-----------|
| p0             | 1         |
| p1             | 1         |
| p2             | 1         |
| p3             | 0         |

实际排序依赖列的字符集和排序规则。此处使用默认的 `utf8mb4_0900_ai_ci`（大小写不敏感），字母 G 排在 F 之后、M 之前。

#### 2.3.2 LIST COLUMNS 日期分区

使用 `DATE` 列进行 `LIST COLUMNS` 分区：

```sql
CREATE TABLE customers (
    first_name VARCHAR(25), last_name VARCHAR(25), renewal DATE
)
PARTITION BY LIST COLUMNS(renewal) (
    PARTITION pWeek_1 VALUES IN('2010-02-01', '2010-02-02', '2010-02-03',
        '2010-02-04', '2010-02-05', '2010-02-06', '2010-02-07'),
    PARTITION pWeek_2 VALUES IN('2010-02-08', '2010-02-09', '2010-02-10',
        '2010-02-11', '2010-02-12', '2010-02-13', '2010-02-14')
);

INSERT INTO customers VALUES
('Alice', 'Anderson', '2010-02-03'), -- renewal='2010-02-03' → pWeek_1
('Bob', 'Miller', '2010-02-10'),    -- renewal='2010-02-10' → pWeek_2
('Carol', 'Taylor', '2010-02-07');  -- renewal='2010-02-07' → pWeek_1

SELECT PARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'customers';
```

| PARTITION_NAME | TABLE_ROWS |
|----------------|-----------|
| pWeek_1        | 2         |
| pWeek_2        | 1         |

### 2.4 HASH 分区

`HASH` 分区根据分区键表达式的**模运算结果**决定分区。MySQL 计算 `MOD(expr, num)`，其中 `num` 为分区数。

语法格式：

```sql
PARTITION BY HASH (expression)
PARTITIONS num;
```

```sql
CREATE TABLE employees (
    id INT NOT NULL,
    fname VARCHAR(30),
    lname VARCHAR(30),
    hired DATE NOT NULL DEFAULT '1970-01-01',
    separated DATE NOT NULL DEFAULT '9999-12-31',
    job_code INT,
    store_id INT
)
PARTITION BY HASH(store_id)
PARTITIONS 4;
```

插入数据，验证按 `store_id` 的模运算结果分配分区：

```sql
INSERT INTO employees VALUES
(1, 'Alice', 'Smith', '1998-03-15', '2005-06-01', 100, 3),  -- MOD(3,4)=3 → p3
(2, 'Bob', 'Jones', '2000-07-20', '2010-12-31', 200, 7),   -- MOD(7,4)=3 → p3
(3, 'Carol', 'White', '2005-01-10', '2015-03-15', 150, 12), -- MOD(12,4)=0 → p0
(4, 'Dave', 'Brown', '2010-09-01', '2020-05-20', 300, 18); -- MOD(18,4)=2 → p2

SELECT PARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employees';

| PARTITION_NAME | TABLE_ROWS |
|----------------|-----------|
| p0             | 1         |
| p1             | 0         |
| p2             | 1         |
| p3             | 2         |

模运算规则：`partition_number = MOD(expr, num)`，其中 `num` 为分区数，MySQL 自动计算表达式结果并取模，余数即为目标分区号（从 0 开始编号）。例如 `MOD(12, 4) = 0`，对应分区 `p0`。

如果省略 `PARTITIONS num`，默认只有 1 个分区。

**为什么不直接用 `store_id` 作为分区键？** `store_id` 的值可能集中在某个范围，导致数据分布不均。用 `MOD(store_id, 4)` 可以将连续值打散到 4 个分区中，使数据更均匀。

```

### 2.5 KEY 分区

`KEY` 分区与 `HASH` 类似，但**哈希函数由 MySQL 自动提供**，无需用户指定表达式。分区键默认为主键（或唯一键），如果表无主键/唯一键，则使用所有 `NOT NULL` 列。

语法格式：

```sql
PARTITION BY KEY (column_name)
PARTITIONS num;
```

MySQL 内部的哈希函数对不同类型的列有不同的处理方式：

- **整数类型列**：`MOD(column_value, num)`，与 `HASH(expr)` 类似，通过模运算得到分区号
- **字符串类型列**：MySQL 使用内部的哈希算法将字符串映射为整数值，再进行模运算。

无论哪种类型，最终都是通过 `MOD(hash_value, num_partitions)` 确定分区。关键区别在于：`HASH` 分区的表达式由用户指定，`KEY` 分区的哈希函数由 MySQL 自动选择，用户无法干预。

```sql
-- 主键作为分区键
CREATE TABLE k1 (
    id INT NOT NULL PRIMARY KEY,
    name VARCHAR(20)
)
PARTITION BY KEY()
PARTITIONS 2;

INSERT INTO k1 VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Carol');

SELECT PARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'k1';
```

| PARTITION_NAME | TABLE_ROWS |
|----------------|-----------|
| p0             | 2         |
| p1             | 1         |

```sql
-- 无主键但有唯一键，唯一键作为分区键
CREATE TABLE k2 (
    id INT NOT NULL,
    name VARCHAR(20),
    UNIQUE KEY (id)
)
PARTITION BY KEY()
PARTITIONS 2;

INSERT INTO k2 VALUES (1, 'Apple'), (4, 'Google'), (7, 'Meta');

SELECT PARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'k2';

| PARTITION_NAME | TABLE_ROWS |
|----------------|-----------|
| p0             | 2         |
| p1             | 1         |
```

`KEY` 分区的一个独特优势：分区键可以是**非整数类型**（`TEXT` 和 `BLOB` 除外），因为 MySQL 内部哈希函数会处理各种数据类型：

```sql
CREATE TABLE tm1 (
    s1 CHAR(32) PRIMARY KEY
)
PARTITION BY KEY(s1)
PARTITIONS 10;

INSERT INTO tm1 VALUES ('Alice'), ('Bob'), ('Carol');

SELECT PARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tm1';

| PARTITION_NAME | TABLE_ROWS |
|----------------|-----------|
| p0             | 1         |
| p1             | 1         |
| p2             | 0         |
| p3             | 1         |
| p4–p9          | 0         |
```

### 2.6 子分区

子分区（Subpartitioning，组合分区）在 `RANGE` 或 `LIST` 分区的基础上，再按 `HASH` 或 `KEY` 划分。总分区数 = 外层分区数 × 子分区数。

语法格式：

```sql
PARTITION BY RANGE (expression)
SUBPARTITION BY HASH (expression)
SUBPARTITIONS num (
    PARTITION partition_name VALUES LESS THAN (expr) (
        SUBPARTITION subpartition_name,
        SUBPARTITION subpartition_name
    ),
    ...
);
```

以下示例演示数据分布过程：外层按年份 `RANGE` 分区，内层按 `HASH(TO_DAYS(purchased))` 再分：

```sql
CREATE TABLE ts (id INT, purchased DATE)
PARTITION BY RANGE(YEAR(purchased))
SUBPARTITION BY HASH(TO_DAYS(purchased))
SUBPARTITIONS 2 (
    PARTITION p0 VALUES LESS THAN (1990),
    PARTITION p1 VALUES LESS THAN (2000),
    PARTITION p2 VALUES LESS THAN MAXVALUE
);
```

插入 6 条数据：

```sql
INSERT INTO ts VALUES
(1, '1985-06-15'),
(2, '1995-03-20'),
(3, '2005-09-10'),
(4, '1989-12-31'),
(5, '1998-07-08'),
(6, '2010-01-01');
```

查询各子分区的数据分布：

```sql
SELECT PARTITION_NAME, SUBPARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ts'
ORDER BY PARTITION_NAME, SUBPARTITION_NAME;
```

| PARTITION_NAME | SUBPARTITION_NAME | TABLE_ROWS |
|---------------|-------------------|------------|
| p0            | p0sp0             | 2          |
| p0            | p0sp1             | 0          |
| p1            | p1sp0             | 0          |
| p1            | p1sp1             | 2          |
| p2            | p2sp0             | 2          |
| p2            | p2sp1             | 0          |

分布规则分两步计算：

1. **先定外层分区**：根据 `YEAR(purchased)` 落入哪个 `RANGE`
   - id=1、id=4 → `YEAR` 分别为 1985、1989 → `< 1990` → **p0**
   - id=2、id=5 → `YEAR` 分别为 1995、1998 → `1990 ≤ YEAR < 2000` → **p1**
   - id=3、id=6 → `YEAR` 分别为 2005、2010 → `≥ 2000` → **p2**

2. **再定子分区**：在已确定的 RANGE 分区内部，用 `MOD(TO_DAYS(purchased), 2)` 确定子分区
   - p0 中：id=1 → `MOD(725172, 2) = 0` → **p0sp0**；id=4 → `MOD(726832, 2) = 0` → **p0sp0**
   - p1 中：id=2 → `MOD(728737, 2) = 1` → **p1sp1**；id=5 → `MOD(729943, 2) = 1` → **p1sp1**
   - p2 中：id=3 → `MOD(732564, 2) = 0` → **p2sp0**；id=6 → `MOD(734138, 2) = 0` → **p2sp0**

本例中外层 `RANGE` 与内层 `HASH` 相配合，6 条数据均落入各自的子分区中。

显式指定子分区名称（便于维护和管理）：

```sql
CREATE TABLE ts (id INT, purchased DATE)
PARTITION BY RANGE(YEAR(purchased))
SUBPARTITION BY HASH(TO_DAYS(purchased)) (
    PARTITION p0 VALUES LESS THAN (1990) (
        SUBPARTITION s0,
        SUBPARTITION s1
    ),
    PARTITION p1 VALUES LESS THAN (2000) (
        SUBPARTITION s2,
        SUBPARTITION s3
    ),
    PARTITION p2 VALUES LESS THAN MAXVALUE (
        SUBPARTITION s4,
        SUBPARTITION s5
    )
);
```

注意事项：

- 所有外层分区的**子分区数必须相同**
- 子分区名称在整个表中必须**唯一**
- 子分区只能是 `HASH` 或 `KEY`，`RANGE`/`LIST` 分区不能作为子分区
- `SUBPARTITION BY KEY` 必须显式指定列（不能省略，这是与 `PARTITION BY KEY` 的差异）

## 三、NULL 值处理

MySQL 分区将 `NULL` 视为小于任何非 NULL 值，但不同分区类型处理方式不同。

### 3.1 RANGE 分区中的 NULL

`NULL` 存入**编号最小的分区**（第一个分区）：

```sql
CREATE TABLE t1 (
    c1 INT,
    c2 VARCHAR(20)
)
PARTITION BY RANGE(c1) (
    PARTITION p0 VALUES LESS THAN (0),
    PARTITION p1 VALUES LESS THAN (10),
    PARTITION p2 VALUES LESS THAN MAXVALUE
);

INSERT INTO t1 VALUES (NULL, 'mothra');
```

查询验证：

```sql
SELECT PARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 't1';
```

| PARTITION_NAME | TABLE_ROWS |
|----------------|-----------|
| p0             | 1         |
| p1             | 0         |
| p2             | 0         |

`NULL` 值被存入 `p0`。

### 3.2 LIST 分区中的 NULL

`LIST` 分区中，`NULL` **只有在一个分区的值列表中显式包含 `NULL` 时**才被接受：

```sql
-- 无 NULL 值的分区，拒绝 NULL
CREATE TABLE ts1 (
    c1 INT,
    c2 VARCHAR(20)
)
PARTITION BY LIST(c1) (
    PARTITION p0 VALUES IN (0, 3, 6),
    PARTITION p1 VALUES IN (1, 4, 7),
    PARTITION p2 VALUES IN (2, 5, 8)
);

INSERT INTO ts1 VALUES (NULL, 'mothra');
-- ERROR 1504 (HY000): Table has no partition for value NULL
```

```sql
-- 显式包含 NULL
CREATE TABLE ts2 (
    c1 INT,
    c2 VARCHAR(20)
)
PARTITION BY LIST(c1) (
    PARTITION p0 VALUES IN (0, 3, 6),
    PARTITION p1 VALUES IN (1, 4, 7),
    PARTITION p2 VALUES IN (2, 5, 8),
    PARTITION p3 VALUES IN (NULL)
);

INSERT INTO ts2 VALUES (NULL, 'mothra');
-- Query OK, 1 row affected
```

### 3.3 HASH 和 KEY 分区中的 NULL

在 `HASH` 和 `KEY` 分区中，`NULL` 被视为 **0**：

```sql
CREATE TABLE th (
    c1 INT,
    c2 VARCHAR(20)
)
PARTITION BY HASH(c1)
PARTITIONS 2;

INSERT INTO th VALUES (NULL, 'mothra'), (0, 'gigan');
```

| PARTITION_NAME | TABLE_ROWS |
|----------------|-----------|
| p0             | 2         |
| p1             | 0         |

`NULL` 和 `0` 都被存入 `p0`。



### 3.4 RANGE/LIST 分区管理

**删除分区**（`DROP PARTITION`）会删除分区及其所有数据：

```sql
CREATE TABLE tr (id INT, name VARCHAR(50), purchased DATE)
PARTITION BY RANGE(YEAR(purchased)) (
    PARTITION p0 VALUES LESS THAN (1990),
    PARTITION p1 VALUES LESS THAN (1995),
    PARTITION p2 VALUES LESS THAN (2000),
    PARTITION p3 VALUES LESS THAN (2005)
);

-- 删除 1990-1994 年的分区
ALTER TABLE tr DROP PARTITION p1;
```

**添加分区**（`ADD PARTITION`）只能添加到 RANGE 分区的末端，或 LIST 分区的末尾：

```sql
CREATE TABLE tr_add (
    id INT, name VARCHAR(50), purchased DATE
)
PARTITION BY RANGE(YEAR(purchased)) (
    PARTITION p0 VALUES LESS THAN (1990),
    PARTITION p1 VALUES LESS THAN (2000),
    PARTITION p2 VALUES LESS THAN (2005)
);

-- RANGE 分区：只能添加在高端
ALTER TABLE tr_add ADD PARTITION (
    PARTITION p3 VALUES LESS THAN (2010)
);
```

尝试在中间添加分区会报错：

```sql
ALTER TABLE tr_add ADD PARTITION (
    PARTITION p4 VALUES LESS THAN (1970)
);
-- ERROR 1493 (HY000): VALUES LESS THAN value must be strictly increasing for each partition
```

需要在中间插入分区时，使用 `REORGANIZE PARTITION` 重新组织现有分区：

```sql
CREATE TABLE tr_split (
    id INT, name VARCHAR(50), purchased DATE
)
PARTITION BY RANGE(YEAR(purchased)) (
    PARTITION p0 VALUES LESS THAN (1990),
    PARTITION p1 VALUES LESS THAN (2000),
    PARTITION p2 VALUES LESS THAN (2010)
);

INSERT INTO tr_split VALUES (1, 'item1', '1985-06-15');
INSERT INTO tr_split VALUES (2, 'item2', '1988-12-20');
INSERT INTO tr_split VALUES (3, 'item3', '1995-03-10');

SELECT PARTITION_NAME, TABLE_ROWS FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tr_split';
```

| PARTITION_NAME | TABLE_ROWS |
|----------------|-----------|
| p0             | 2          |
| p1             | 1          |
| p2             | 0          |

将 `p0` 拆分为两个分区：

```sql
ALTER TABLE tr_split REORGANIZE PARTITION p0 INTO (
    PARTITION n0 VALUES LESS THAN (1970),
    PARTITION n1 VALUES LESS THAN (1990)
);
```

拆分后验证（注意执行 `ANALYZE TABLE` 刷新统计）：

```sql
ANALYZE TABLE tr_split;

SELECT PARTITION_NAME, TABLE_ROWS FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tr_split';
```

| PARTITION_NAME | TABLE_ROWS |
|----------------|-----------|
| n0             | 0          |
| n1             | 2          |
| p1             | 1          |
| p2             | 0          |

拆分后数据分布说明：`id=1` (`purchased=1985`) 落入 `n1`（`1970 ≤ 1985 < 1990`），`id=2` (`purchased=1988`) 也落入 `n1`（`1970 ≤ 1988 < 1990`），`id=3` 不变仍在 `p1`。

> **注意**：`INFORMATION_SCHEMA.PARTITIONS` 中的 `TABLE_ROWS` 是 MySQL 缓存的统计信息，`REORGANIZE PARTITION` 执行后不会立即更新。如果查询结果与实际数据不符，先执行 `ANALYZE TABLE table_name` 刷新统计，再重新查询。

**合并相邻分区**：

```sql
CREATE TABLE tr_merge (
    id INT, name VARCHAR(50), purchased DATE
)
PARTITION BY RANGE(YEAR(purchased)) (
    PARTITION p0 VALUES LESS THAN (1970),
    PARTITION p1 VALUES LESS THAN (1980),
    PARTITION p2 VALUES LESS THAN (2010)
);

INSERT INTO tr_merge VALUES (1, 'old', '1965-01-01');
INSERT INTO tr_merge VALUES (2, 'mid1', '1975-06-15');
INSERT INTO tr_merge VALUES (3, 'mid2', '1978-12-20');

ALTER TABLE tr_merge REORGANIZE PARTITION p0, p1 INTO (
    PARTITION p_merged VALUES LESS THAN (1980)
);
```

**拆分分区**：`REORGANIZE PARTITION` 既可以合并分区，也可以将一个分区拆分为多个。

**减少 LIST/HASH/KEY 分区的数量**：

```sql
CREATE TABLE clients (
    id INT,
    signed DATE
)
PARTITION BY HASH(MONTH(signed))
PARTITIONS 12;

-- 将分区数从 12 减少到 8
ALTER TABLE clients COALESCE PARTITION 4;
```

**增加分区数**：

```sql
-- 增加 6 个分区
ALTER TABLE clients ADD PARTITION PARTITIONS 6;
```



## 五、分区裁剪

分区裁剪（Partition Pruning）是 MySQL 分区最重要的查询优化手段。**裁剪的原理**：查询时只扫描可能包含匹配行的分区，排除不相关分区。执行效果可能使查询快一个数量级。

### 5.1 适用条件

建表并插入测试数据：

```sql
CREATE TABLE t1 (
    id INT,
    fname VARCHAR(50),
    lname VARCHAR(50),
    region_code TINYINT UNSIGNED
)
PARTITION BY HASH(region_code)
PARTITIONS 4;

INSERT INTO t1 VALUES
(1, 'Alice', 'Smith',   4),  -- MOD(4,4)=0 → p0
(2, 'Bob',   'Jones',    5),  -- MOD(5,4)=1 → p1
(3, 'Carol', 'White',   6),  -- MOD(6,4)=2 → p2
(4, 'Dave',  'Brown',    7),  -- MOD(7,4)=3 → p3
(5, 'Eve',   'Taylor',  10); -- MOD(10,4)=2 → p2
```

分区分布：`region_code=4→p0`、`5→p1`、`6→p2`、`7→p3`、`10→p2`。

当 `WHERE` 条件可以归约为以下形式时，MySQL 即可执行裁剪：

**形式一：分区列 = 常量**

```sql
SELECT * FROM t1 WHERE region_code = 6;
```

`EXPLAIN` 显示 `partitions: p2`，只扫描 `p2`：

```
 partitions: p2
```

**形式二：分区列 IN (常量列表)**

```sql
SELECT * FROM t1 WHERE region_code IN (6, 7);
```

`EXPLAIN` 显示 `partitions: p2,p3`，扫描 `p2` 和 `p3`：

```
 partitions: p2,p3
```

**形式三：短范围可转化为 IN 列表**

```sql
SELECT * FROM t1 WHERE region_code > 4 AND region_code < 8;
```

`EXPLAIN` 显示 `partitions: p1,p2,p3`，扫描 `p1`、`p2`、`p3`（对应 `region_code=5,6,7`）：

```
 partitions: p1,p2,p3
```

> **重要限制**：范围包含的值数量必须小于分区数，否则无法裁剪。如果范围覆盖 9 个值而表只有 8 个分区，优化器不会进行裁剪。

### 5.2 日期分区与裁剪

使用 `YEAR()` 或 `TO_DAYS()` 进行日期分区时，MySQL 也能利用裁剪：

```sql
CREATE TABLE t2 (
    fname VARCHAR(50),
    lname VARCHAR(50),
    region_code TINYINT UNSIGNED,
    dob DATE
)
PARTITION BY RANGE(YEAR(dob)) (
    PARTITION d0 VALUES LESS THAN (1970),
    PARTITION d1 VALUES LESS THAN (1975),
    PARTITION d2 VALUES LESS THAN (1980),
    PARTITION d3 VALUES LESS THAN (1985),
    PARTITION d4 VALUES LESS THAN (1990),
    PARTITION d5 VALUES LESS THAN (2000),
    PARTITION d6 VALUES LESS THAN (2005),
    PARTITION d7 VALUES LESS THAN MAXVALUE
);
```

以下查询均可触发裁剪：

```sql
-- 等值查询
SELECT * FROM t2 WHERE dob = '1982-06-23';

-- 范围查询
UPDATE t2 SET region_code = 8
WHERE dob BETWEEN '1991-02-15' AND '1997-04-25';

DELETE FROM t2 WHERE dob >= '1984-06-21' AND dob <= '1999-06-21';
```

范围查询的裁剪过程：找到低端值所在分区（`d3`）和高端值所在分区（`d5`），然后扫描这两个分区及其之间的所有分区（`d3`, `d4`, `d5`），其余分区直接跳过。

### 5.3 各分区类型的裁剪差异

| 分区类型 | 裁剪条件                          | 限制                          |
|---------|----------------------------------|------------------------------|
| RANGE   | `=`、`IN`、BETWEEN、短范围        | 无                            |
| LIST    | `=`、`IN`                        | 无                            |
| HASH/KEY | `=`                              | 只能用于整数列                 |

> ⚠️ `HASH`/`KEY` 分区中，如果分区键是 `DATE` 类型（如 `WHERE dob >= '2001-04-14'`），**无法裁剪**。因为 MySQL 无法将日期比较转化为模运算。如果用整数列存储年份，则 `WHERE year_col >= 2001 AND year_col <= 2005` 可以裁剪。

### 5.4 验证裁剪效果

使用 `EXPLAIN` 查看查询是否使用了分区裁剪：

```sql
EXPLAIN SELECT * FROM t2 WHERE YEAR(dob) = 1982;
```

输出中可以看到只扫描了相关分区，而不是所有分区。

## 六、分区选择

分区选择（Partition Selection）允许在 SQL 语句中**显式指定**要操作的分区或子分区，与分区裁剪不同，裁剪是优化器自动决定，选择是用户主动指定。

### 6.1 基本语法

```sql
SELECT * FROM table_name PARTITION (partition_name[, ...])
```

`PARTITION` 选项紧跟在表名之后，可指定多个分区名（以逗号分隔），分区顺序无关紧要，可以重叠。

### 6.2 查询中的分区选择

```sql
CREATE TABLE employees (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    fname VARCHAR(25),
    lname VARCHAR(25),
    store_id INT,
    department_id INT
)
PARTITION BY RANGE(id) (
    PARTITION p0 VALUES LESS THAN (5),     -- id 1-4
    PARTITION p1 VALUES LESS THAN (10),   -- id 5-9
    PARTITION p2 VALUES LESS THAN (15),  -- id 10-14
    PARTITION p3 VALUES LESS THAN MAXVALUE -- id 15+
);

INSERT INTO employees (fname, lname, store_id, department_id) VALUES
('Bob',    'Taylor',   3, 2),
('Frank',  'Williams', 1, 2),
('Ellen',  'Johnson',  3, 4),
('Jim',    'Smith',    2, 4),
('Mary',   'Jones',    1, 1),
('Linda',  'Black',    2, 3),
('Ed',     'Jones',    2, 1),
('June',   'Wilson',   3, 1),
('Andy',   'Smith',    1, 3),
('Lou',    'Waters',   2, 4),
('Jill',   'Stone',    1, 4),
('Roger',  'White',    3, 2),
('Howard', 'Andrews',  1, 2),
('Fred',   'Goldberg', 3, 3),
('Barbara','Brown',    2, 3),
('Alice',  'Rogers',   2, 2);
```

查询分区 `p1` 中的所有行：

```sql
SELECT * FROM employees PARTITION (p1);
```

| id | fname | lname | store_id | department_id |
|----|-------|-------|---------|--------------|
| 5  | Mary  | Jones | 1       | 1            |
| 6  | Linda | Black | 2       | 3            |
| 7  | Ed    | Jones | 2       | 1            |
| 8  | June  | Wilson| 3       | 1            |
| 9  | Andy  | Smith | 1       | 3            |

查询多个分区的交集（排除其他分区）：

```sql
SELECT * FROM employees PARTITION (p0, p2)
WHERE lname LIKE 'S%';
```

| id | fname | lname | store_id | department_id |
|----|-------|-------|---------|--------------|
| 4  | Jim   | Smith | 2       | 4            |
| 11 | Jill  | Stone | 1       | 4            |

结合排序和聚合：

```sql
SELECT id, CONCAT(fname, ' ', lname) AS name
FROM employees PARTITION (p0) ORDER BY lname;
```

| id | name              |
|----|-------------------|
| 3  | Ellen Johnson     |
| 4  | Jim Smith         |
| 1  | Bob Taylor        |
| 2  | Frank Williams    |

```sql
SELECT store_id, COUNT(department_id) AS c
FROM employees PARTITION (p1, p2, p3)
GROUP BY store_id HAVING c > 4;
```

| store_id | c |
|----------|---|
| 1        | 4 |
| 2        | 5 |
| 3        | 3 |

### 6.3 DML 语句中的分区选择

分区选择支持 `SELECT`、`DELETE`、`INSERT`、`REPLACE`、`UPDATE`、`LOAD DATA`、`LOAD XML` 等多种语句。

**在 INSERT 中指定源分区**：

```sql
DROP TABLE IF EXISTS employees_copy;
CREATE TABLE employees_copy LIKE employees;
ALTER TABLE employees_copy REMOVE PARTITIONING;
INSERT INTO employees_copy SELECT * FROM employees WHERE id <= 4;  -- 模拟已存有其他分区数据

SELECT '复制前:' AS stage;
SELECT * FROM employees_copy;

INSERT INTO employees_copy
SELECT * FROM employees PARTITION (p2);

SELECT 'INSERT ... PARTITION (p2) 后:' AS stage;
SELECT * FROM employees_copy WHERE id BETWEEN 10 AND 14;
```

| id | fname | lname | store_id | department_id |
|----|-------|-------|---------|--------------|
| 10 | Lou    | Waters | 2       | 4            |
| 11 | Jill   | Stone  | 1       | 4            |
| 12 | Roger  | White  | 3       | 2            |
| 13 | Howard | Andrews| 1       | 2            |
| 14 | Fred   | Goldberg| 3      | 3            |

**在 DELETE 中指定分区**：

```sql
DELETE FROM employees PARTITION (p0) WHERE lname = 'Smith';

SELECT 'DELETE PARTITION (p0) WHERE lname="Smith" 后 p0:' AS stage;
SELECT * FROM employees PARTITION (p0);
```

| id | fname | lname | store_id | department_id |
|----|-------|-------|---------|--------------|
| 1  | Bob   | Taylor| 3       | 2            |
| 2  | Frank | Williams| 1      | 2            |
| 3  | Ellen | Johnson| 3       | 4            |

`id=4 (Jim Smith)` 被删除，其他分区不受影响。

**在 UPDATE 中指定分区**：

```sql
UPDATE employees PARTITION (p2) SET store_id = 99 WHERE id = 10;

SELECT 'UPDATE PARTITION (p2) SET store_id=99 WHERE id=10:' AS stage;
SELECT id, fname, store_id FROM employees WHERE id = 10;
```

| id | fname | store_id |
|----|-------|---------|
| 10 | Lou   | 99      |

### 6.4 子分区选择

```sql
CREATE TABLE employees_sub (
    id INT NOT NULL,
    fname VARCHAR(25),
    lname VARCHAR(25),
    store_id INT
)
PARTITION BY RANGE(id)
SUBPARTITION BY KEY(id)
SUBPARTITIONS 2 (
    PARTITION p0 VALUES LESS THAN (5),
    PARTITION p1 VALUES LESS THAN (10),
    PARTITION p2 VALUES LESS THAN MAXVALUE
);

INSERT INTO employees_sub VALUES
(1,'Bob','Taylor',3),(2,'Frank','Williams',1),(3,'Ellen','Johnson',3),
(4,'Jim','Smith',2),(5,'Mary','Jones',1),(6,'Linda','Black',2),
(7,'Ed','Jones',2),(8,'June','Wilson',3),
(10,'Alice','Rogers',2),(11,'Tom','Harris',3),(12,'Kate','Lee',1),(13,'Sam','Clark',2);
```

查询各子分区的数据分布：

```sql
SELECT PARTITION_NAME, SUBPARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employees_sub'
ORDER BY PARTITION_NAME, SUBPARTITION_NAME;
```

| PARTITION_NAME | SUBPARTITION_NAME | TABLE_ROWS |
|---------------|------------------|------------|
| p0            | p0sp0            | 2          |
| p0            | p0sp1            | 2          |
| p1            | p1sp0            | 2          |
| p1            | p1sp1            | 2          |
| p2            | p2sp0            | 2          |
| p2            | p2sp1            | 2          |

显式选择子分区：

```sql
SELECT * FROM employees_sub PARTITION (p2sp0);
```

| id | fname | lname | store_id |
|----|-------|-------|---------|
| 11 | Tom   | Harris| 3        |
| 13 | Sam   | Clark | 2        |

```sql
SELECT * FROM employees_sub PARTITION (p2sp1);
```

| id | fname | lname | store_id |
|----|-------|-------|---------|
| 10 | Alice | Rogers| 2        |
| 12 | Kate  | Lee   | 1        |

### 6.5 JOIN 中的分区选择

在 JOIN 中，每个表都可以单独指定分区，`PARTITION` 选项位于表名之后、别名之前：

```sql
CREATE TABLE stores (
    id INT,
    city VARCHAR(50)
)
PARTITION BY RANGE(id) (
    PARTITION p0 VALUES LESS THAN (2),    -- id 1
    PARTITION p1 VALUES LESS THAN (4),  -- id 2-3
    PARTITION p2 VALUES LESS THAN MAXVALUE
);

INSERT INTO stores VALUES
(1,'New York'),(2,'Los Angeles'),(3,'Chicago'),(4,'Houston');

CREATE TABLE departments (
    id INT,
    name VARCHAR(50)
)
PARTITION BY RANGE(id) (
    PARTITION p0 VALUES LESS THAN (2),    -- id 1
    PARTITION p1 VALUES LESS THAN (4),  -- id 2-3
    PARTITION p2 VALUES LESS THAN MAXVALUE
);

INSERT INTO departments VALUES
(1,'Sales'),(2,'Marketing'),(3,'Engineering'),(4,'Support');

SELECT e.id, e.fname, s.city, d.name
FROM employees e
JOIN stores PARTITION (p1) s ON e.store_id = s.id
JOIN departments PARTITION (p0) d ON e.department_id = d.id;
```

查询结果（`employees` 中 `store_id` 在 `p1`（2-3）、`department_id` 在 `p0`（1）的行）：

| id | fname | store_id | city        | department_id | name  |
|----|-------|----------|-------------|--------------|-------|
| 7  | Ed    | 2        | Los Angeles | 1            | Sales |
| 8  | June  | 3        | Chicago     | 1            | Sales |

