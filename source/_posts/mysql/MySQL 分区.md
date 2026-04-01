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

这是分区表中最重要的约束：**所有分区表达式使用的列，必须是表中每个唯一键（包括主键）的超集**。换句话说，分区键必须包含表的所有唯一键。

以下表定义中，唯一键 `uk(name)` 与主键 `pk(id)` 没有共同列。如果尝试对该表进行分区，会因为无法选择分区键而失败：

```sql
CREATE TABLE tnp (
    id INT NOT NULL AUTO_INCREMENT,
    ref BIGINT NOT NULL,
    name VARCHAR(255),
    PRIMARY KEY pk (id),
    UNIQUE KEY uk (name)
);
-- 表本身可以正常创建

-- 但如果尝试分区，则报错：
ALTER TABLE tnp PARTITION BY HASH(id) PARTITIONS 4;
-- ERROR 1503 (HY000): A PRIMARY KEY must include all columns used in this partitioned table's partitioning function
```

解决方式：要么将 `name` 加入主键（`PRIMARY KEY pk (id, name)`），要么将 `id` 加入唯一键（`UNIQUE KEY uk (id, name)`），要么移除唯一键。

### 1.3 分区的优势

- **容纳更多数据**：单表数据量可以超过单个磁盘分区的容量
- **快速删除旧数据**：通过 `DROP PARTITION` 删除整个分区，比 `DELETE` 高效得多
- **查询优化**：分区裁剪使查询只扫描相关分区，大幅提升性能
- **灵活维护**：可以单独对某个分区执行检查、修复、优化操作

## 二、分区类型

MySQL 8.4 支持以下分区类型：`RANGE`、`LIST`、`HASH`、`KEY`，以及基于它们的 `COLUMNS` 变体和 `LINEAR` 变体。

### 2.1 RANGE 分区

按连续范围划分分区，使用 `VALUES LESS THAN` 定义。范围必须**严格递增**，不重叠。建议在最后使用 `MAXVALUE` 作为"兜底"分区，接收所有超出定义范围的行。

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
-- 插入不匹配的值会报错
INSERT INTO h2 VALUES (3, 5);
-- ERROR 1525 (HY000): Table has no partition for value 3

-- 使用 IGNORE 静默跳过
INSERT IGNORE INTO h2 VALUES (2, 5), (6, 10), (7, 5), (3, 1), (1, 9);
-- Query OK, 3 rows affected, 2 warnings (2 rows skipped)
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

**RANGE COLUMNS** 的核心语义与 `RANGE` 不同：比较的是**元组（元组即多列值的列表）**，而不是标量值。例如：

```sql
CREATE TABLE rc1 (
    a INT,
    b INT
)
PARTITION BY RANGE COLUMNS(a, b) (
    PARTITION p0 VALUES LESS THAN (5, 12),
    PARTITION p3 VALUES LESS THAN (MAXVALUE, MAXVALUE)
);

INSERT INTO rc1 VALUES (5,10), (5,11), (5,12);
```

| PARTITION_NAME | TABLE_ROWS |
|----------------|-----------|
| p0             | 2         |
| p3             | 1         |

原因：`ROW(5,10) < ROW(5,12)` 和 `ROW(5,11) < ROW(5,12)` 为真，但 `ROW(5,12) < ROW(5,12)` 为假（相等），所以值 `(5,12)` 落入 `p3`。

使用字符串列进行 `RANGE COLUMNS` 分区（按姓氏首字母划分）：

```sql
CREATE TABLE employees_by_lname (
    id INT NOT NULL,
    fname VARCHAR(30),
    lname VARCHAR(30),
    hired DATE NOT NULL DEFAULT '1970-01-01',
    separated DATE NOT NULL DEFAULT '9999-12-31',
    job_code INT NOT NULL,
    store_id INT NOT NULL
)
PARTITION BY RANGE COLUMNS (lname) (
    PARTITION p0 VALUES LESS THAN ('g'),
    PARTITION p1 VALUES LESS THAN ('m'),
    PARTITION p2 VALUES LESS THAN ('t'),
    PARTITION p3 VALUES LESS THAN (MAXVALUE)
);
```

使用 `DATE` 列进行 `LIST COLUMNS` 分区：

```sql
CREATE TABLE customers (
    first_name VARCHAR(25),
    last_name VARCHAR(25),
    renewal DATE
)
PARTITION BY LIST COLUMNS(renewal) (
    PARTITION pWeek_1 VALUES IN('2010-02-01', '2010-02-02', '2010-02-03',
        '2010-02-04', '2010-02-05', '2010-02-06', '2010-02-07'),
    PARTITION pWeek_2 VALUES IN('2010-02-08', '2010-02-09', '2010-02-10',
        '2010-02-11', '2010-02-12', '2010-02-13', '2010-02-14')
);
```

### 2.4 HASH 分区

`HASH` 分区根据分区键表达式的**模运算结果**决定分区。MySQL 计算 `MOD(expr, num)`，其中 `num` 为分区数。

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

分区号计算示例——插入 `col3 = '2005-09-15'` 的行：

```
MOD(YEAR('2005-09-15'), 4) = MOD(2005, 4) = 1
-- 存储到分区 1
```

如果省略 `PARTITIONS num`，默认只有 1 个分区。

### 2.5 LINEAR HASH 分区

`LINEAR HASH` 使用**线性 2 的幂算法**，而非模运算。分区号通过以下步骤计算：

1. 设 `V = 2^CEILING(LOG2(num))`
2. 设 `N = F(column) & (V - 1)`
3. 当 `N >= num` 时，循环：`V = V / 2; N = N & (V - 1)`

```sql
CREATE TABLE t1 (
    col1 INT,
    col2 CHAR(5),
    col3 DATE
)
PARTITION BY LINEAR HASH(YEAR(col3))
PARTITIONS 6;
```

插入 `col3 = '2003-04-14'` 时：

```
V = POWER(2, CEILING(LOG2(6))) = 8
N = 2003 & (8 - 1) = 2003 & 7 = 3
3 >= 6 为假 → 存储到分区 3
```

`LINEAR HASH` 的优势在于分区分裂、合并操作更快，适合 TB 级数据表。劣势是数据分布可能不如标准 `HASH` 均匀。

### 2.6 KEY 分区

`KEY` 分区与 `HASH` 类似，但**哈希函数由 MySQL 自动提供**，无需用户指定表达式。分区键默认为主键（或唯一键），如果表无主键/唯一键，则使用所有 `NOT NULL` 列。

```sql
-- 主键作为分区键
CREATE TABLE k1 (
    id INT NOT NULL PRIMARY KEY,
    name VARCHAR(20)
)
PARTITION BY KEY()
PARTITIONS 2;

-- 无主键但有唯一键，唯一键作为分区键
CREATE TABLE k2 (
    id INT NOT NULL,
    name VARCHAR(20),
    UNIQUE KEY (id)
)
PARTITION BY KEY()
PARTITIONS 2;
```

`KEY` 分区的一个独特优势：分区键可以是**非整数类型**（`TEXT` 和 `BLOB` 除外），因为 MySQL 内部哈希函数会处理各种数据类型：

```sql
CREATE TABLE tm1 (
    s1 CHAR(32) PRIMARY KEY
)
PARTITION BY KEY(s1)
PARTITIONS 10;
```

### 2.7 子分区

子分区（Subpartitioning，组合分区）在 `RANGE` 或 `LIST` 分区的基础上，再按 `HASH` 或 `KEY` 划分。总分区数 = 外层分区数 × 子分区数。

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

上例中：3 个 RANGE 分区 × 2 个 HASH 子分区 = 6 个物理分区。

显式指定子分区名称和选项：

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

## 四、分区管理

### 4.1 RANGE/LIST 分区管理

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
-- RANGE 分区：只能添加在高端
ALTER TABLE members ADD PARTITION (
    PARTITION p3 VALUES LESS THAN (2010)
);
```

尝试在中间添加分区会报错：

```sql
ALTER TABLE members ADD PARTITION (
    PARTITION n VALUES LESS THAN (1970)
);
-- ERROR 1463 (HY000): VALUES LESS THAN value must be strictly increasing
```

需要在中间插入分区时，使用 `REORGANIZE PARTITION` 重新组织现有分区：

```sql
-- 将 p0 拆分为两个分区
ALTER TABLE members REORGANIZE PARTITION p0 INTO (
    PARTITION n0 VALUES LESS THAN (1970),
    PARTITION n1 VALUES LESS THAN (1980)
);
```

**合并相邻分区**：

```sql
ALTER TABLE members REORGANIZE PARTITION s0, s1 INTO (
    PARTITION p0 VALUES LESS THAN (1970)
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

### 4.2 分区交换

分区交换（Exchange）允许将一个分区与一张**非分区表**互换，不触发任何触发器：

```sql
-- 原始分区表
CREATE TABLE e (
    id INT NOT NULL,
    fname VARCHAR(30),
    lname VARCHAR(30)
)
PARTITION BY RANGE (id) (
    PARTITION p0 VALUES LESS THAN (50),
    PARTITION p1 VALUES LESS THAN (100),
    PARTITION p2 VALUES LESS THAN (150),
    PARTITION p3 VALUES LESS THAN (MAXVALUE)
);

-- 创建非分区表
CREATE TABLE e2 LIKE e;
ALTER TABLE e2 REMOVE PARTITIONING;

-- 交换分区 p0 和非分区表 e2
ALTER TABLE e EXCHANGE PARTITION p0 WITH TABLE e2;
```

交换后，`p0` 的数据移入 `e2`，`e2` 的数据移入 `p0`。

**带验证的交换**：默认执行行级验证，交换的表中不能有不符合目标分区定义的数据：

```sql
-- 非分区表包含不符合的数据
INSERT INTO e2 VALUES (51, 'Ellen', 'McDonald');

ALTER TABLE e EXCHANGE PARTITION p0 WITH TABLE e2;
-- ERROR 1707 (HY000): Found row that does not match the partition

-- 跳过验证
ALTER TABLE e EXCHANGE PARTITION p0 WITH TABLE e2 WITHOUT VALIDATION;
-- Query OK, 0 rows affected
```

`WITHOUT VALIDATION` 在交换大量行时显著提升性能（跳过逐行验证），但需管理员自行确保数据合法性。

### 4.3 分区维护操作

| 语句                              | 作用                     |
|----------------------------------|--------------------------|
| `ANALYZE TABLE t;`               | 分析表，收集统计信息        |
| `CHECK TABLE t PARTITION (p0);`  | 检查指定分区的完整性         |
| `OPTIMIZE TABLE t PARTITION (p0);` | 整理碎片，回收空间          |
| `REPAIR TABLE t PARTITION (p0);` | 修复损坏的分区              |
| `ALTER TABLE t TRUNCATE PARTITION (p0);` | 清空分区数据，保留结构  |

## 五、分区裁剪

分区裁剪（Partition Pruning）是 MySQL 分区最重要的查询优化手段。**裁剪的原理**：查询时只扫描可能包含匹配行的分区，排除不相关分区。执行效果可能使查询快一个数量级。

### 5.1 适用条件

当 `WHERE` 条件可以归约为以下两种形式之一时，MySQL 即可执行裁剪：

**形式一：分区列 = 常量**

```sql
SELECT fname, lname, region_code, dob
FROM t1
WHERE region_code = 126;
```

MySQL 直接计算 `MOD(126, 4) = 2`，只扫描分区 `p1`。

**形式二：分区列 IN (常量列表)**

```sql
SELECT fname, lname, region_code, dob
FROM t1
WHERE region_code IN (126, 127, 128, 129);
```

MySQL 评估每个值对应的分区，仅扫描相关分区。

**形式三：短范围可转化为 IN 列表**

```sql
SELECT * FROM t4 WHERE region_code > 2 AND region_code < 6;
-- 优化器转化为 WHERE region_code IN (3, 4, 5)
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
    PARTITION p0 VALUES LESS THAN (5),
    PARTITION p1 VALUES LESS THAN (10),
    PARTITION p2 VALUES LESS THAN (15),
    PARTITION p3 VALUES LESS THAN MAXVALUE
);
```

查询分区 `p1` 中的所有行：

```sql
SELECT * FROM employees PARTITION (p1);
```

查询多个分区的交集（排除其他分区）：

```sql
SELECT * FROM employees PARTITION (p0, p2)
WHERE lname LIKE 'S%';
```

结合排序和聚合：

```sql
SELECT id, CONCAT(fname, ' ', lname) AS name
FROM employees PARTITION (p0) ORDER BY lname;

SELECT store_id, COUNT(department_id) AS c
FROM employees PARTITION (p1, p2, p3)
GROUP BY store_id HAVING c > 4;
```

### 6.3 DML 语句中的分区选择

分区选择支持 `SELECT`、`DELETE`、`INSERT`、`REPLACE`、`UPDATE`、`LOAD DATA`、`LOAD XML` 等多种语句。

**在 INSERT 中指定目标分区**：

```sql
INSERT INTO employees_copy
SELECT * FROM employees PARTITION (p2);
```

**在 DELETE 中指定分区**：

```sql
DELETE FROM employees PARTITION (p0, p1)
WHERE fname LIKE 'j%';
-- 只删除 p0 和 p1 中符合条件的行，其他分区不受影响
```

**在 UPDATE 中指定分区**：

```sql
UPDATE employees PARTITION (p2)
SET department_id = 5
WHERE store_id = 3;
```

### 6.4 子分区选择

显式命名的子分区可以直接选择：

```sql
SELECT id, CONCAT(fname, ' ', lname) AS name
FROM employees_sub PARTITION (p2sp1);
```

### 6.5 JOIN 中的分区选择

在 JOIN 中，每个表都可以单独指定分区：

```sql
SELECT e.id, e.fname, s.city, d.name
FROM employees AS e
JOIN stores PARTITION (p1) AS s ON e.store_id = s.id
JOIN departments PARTITION (p0) AS d ON e.department_id = d.id;
```

每个 `PARTITION` 选项位于表名之后、别名之前。

## 七、限制与注意事项

### 7.1 分区表达式限制

分区表达式必须满足以下约束：

- 允许使用 `+`、`-`、`*`、`DIV` 运算符，结果必须是整数或 `NULL`
- 不允许 `/`、`%`（模运算符）、位运算符（`|`、`&`、`^`、`<<`、`>>`、`~`）
- 不允许存储过程、存储函数、可加载函数或插件
- 不允许声明变量或用户变量

```sql
-- DIV 允许
PARTITION BY HASH(col1 DIV 2)

-- / 不允许
PARTITION BY HASH(col1 / 2)
-- ERROR: Division operator not allowed in partitioning function
```

### 7.2 Server SQL Mode 的影响

分区表达式的求值结果可能随 `SQL_MODE` 改变。**强烈建议创建分区表后不要修改 `SQL_MODE`**。

以下示例中，`BIGINT UNSIGNED` 列减去有符号整数时，`NO_UNSIGNED_SUBTRACTION` 模式决定了分区是否有效：

```sql
SET sql_mode = 'NO_UNSIGNED_SUBTRACTION';
CREATE TABLE tu (c1 BIGINT UNSIGNED)
PARTITION BY RANGE(c1 - 10) (
    PARTITION p0 VALUES LESS THAN (-5),
    PARTITION p1 VALUES LESS THAN (0),
    PARTITION p2 VALUES LESS THAN (5),
    PARTITION p3 VALUES LESS THAN (10),
    PARTITION p4 VALUES LESS THAN (MAXVALUE)
);

-- 修改 SQL_MODE 后，表无法访问
SET sql_mode = '';
SELECT * FROM tu;
-- ERROR 1563 (HY000): Partition constant is out of partition function domain
```

主从复制环境中，**源库和从库的 `SQL_MODE` 必须保持一致**，否则分区表达式求值结果可能不同，导致数据分布不一致或插入失败。

### 7.3 分区数量上限

不包含 `NDB` 存储引擎的表，**最大分区数为 8192**（包括子分区）。如果创建大量分区时遇到 "Out of resources" 错误，可尝试增大 `open_files_limit` 系统变量。

### 7.4 InnoDB 分区与外键

使用 `InnoDB` 存储引擎的分区表**不支持外键**：

- 分区表不能引用外键，也不能被外键引用
- 如果表定义中已存在外键，则不能对该表进行分区
- 反之，已分区的表无法创建外键

### 7.5 其他限制

- **FULLTEXT 索引**：分区表不支持 `FULLTEXT` 索引和全文搜索
- **临时表**：临时表不能分区
- **日志表**：MySQL 的日志表不能分区
- **分区键类型**：默认情况下分区键必须是整数或返回整数的表达式。`KEY` 分区和 `COLUMNS` 分区除外，它们支持更多数据类型
- **`ADD COLUMN ALGORITHM=INSTANT`**：对分区表执行此操作后，将无法再使用分区交换
- **分区裁剪限制**：`HASH`/`KEY` 分区的裁剪只支持整数列上的等值查询
- **子分区限制**：
  - `SUBPARTITION BY KEY` 必须显式指定列（不能省略）
  - 子分区数必须全局一致
  - 子分区名必须全局唯一
- **DATA DIRECTORY / INDEX DIRECTORY**：表级别的这两个选项被忽略，但可以在单个分区上指定
- **列前缀索引**：`KEY` 分区的分区键中不能包含带前缀的列索引

```sql
-- 以下语句报错，因为主键使用了列前缀
CREATE TABLE t1 (
    a VARCHAR(10000),
    b VARCHAR(25),
    c VARCHAR(10),
    PRIMARY KEY (a(10), b, c)
) PARTITION BY KEY() PARTITIONS 2;
-- ERROR 6123 (HY000): Column having prefix key part in PARTITION BY KEY clause is not supported
```
