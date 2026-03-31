---
title: MySQL INFORMATION_SCHEMA
date: 2026-03-31 08:56:00
tags:
  - INFORMATION_SCHEMA
  - 元数据
  - 数据字典
categories: MySQL
---

# 一、概述

MySQL 的 `INFORMATION_SCHEMA` 是一个特殊的数据库，充当 MySQL 服务器的元数据（metadata）仓库。它存储了数据库中所有其他数据库的描述信息，包括数据库名、表名、列的数据类型、访问权限等。业界通常也用"数据字典"（data dictionary）或"系统目录"（system catalog）来指代这类信息。

`INFORMATION_SCHEMA` 的设计遵循 ANSI/ISO SQL:2003 标准 Part 11 Schemata（基础信息模式），意图符合 SQL:2003 核心特性 F021 的要求。与其他 DBMS（如 Oracle、SQL Server）使用 `syscat`、`system` 等名称不同，MySQL 采用了标准名称 `INFORMATION_SCHEMA`。

`INFORMATION_SCHEMA` 中的表实际上是视图（view），而非基础表（base table）。这带来几个重要特性：

- 没有对应的物理文件存储
- 无法在其上创建触发器（trigger）
- 不存在名为 `INFORMATION_SCHEMA` 的数据库目录
- 所有操作都是只读的，不支持 `INSERT`、`UPDATE`、`DELETE`

以下示例展示了一条典型的元数据查询——列出 `mysql` 系统数据库中的所有表及其存储引擎：

```sql
SELECT TABLE_NAME, TABLE_TYPE, ENGINE
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'mysql'
ORDER BY TABLE_NAME
LIMIT 10;
```

```output
+------------+------------+--------+
| TABLE_NAME | TABLE_TYPE | ENGINE |
+------------+------------+--------+
| columns_priv    | BASE TABLE | InnoDB |
| component       | BASE TABLE | InnoDB |
| db              | BASE TABLE | InnoDB |
| default_roles   | BASE TABLE | InnoDB |
| engine_cost     | BASE TABLE | InnoDB |
| func            | BASE TABLE | MyISAM |
| general_log     | BASE TABLE | CSV    |
| help_relation   | BASE TABLE | MyISAM |
| help_topic      | BASE TABLE | MyISAM |
| innodb_index_stats | BASE TABLE | InnoDB |
+------------+------------+--------+
```

## 1.1 与 SHOW 语句的对比

`SELECT ... FROM INFORMATION_SCHEMA` 是获取元数据的标准化方式，相比传统的 `SHOW` 语句有以下优势：

- **符合 Codd 规则**：所有访问都在表上进行，符合关系数据库理论
- **语法一致**：可使用熟悉的 `SELECT` 语法，只需学习表和列名
- **可编程性**：可自由过滤、排序、拼接、转换结果，适用于构建管理工具
- **跨系统兼容**：熟悉 Oracle 数据字典的用户可以平滑迁移

尽管如此，`SHOW` 语句因其简洁直观而被广泛使用，实际上两者在底层使用相同的权限检查机制，对某个对象没有适当权限的用户，无论通过哪种方式都无法看到相关信息。

## 1.2 字符集注意事项

`INFORMATION_SCHEMA` 中字符类型列的定义通常是 `VARCHAR(N) CHARACTER SET utf8mb3`，其中 `N` 至少为 64。MySQL 使用该字符集的默认排序规则（`utf8mb3_general_ci`）执行所有搜索、排序、比较和其他字符串操作。

由于某些 MySQL 对象以文件形式表示，`INFORMATION_SCHEMA` 字符串列上的搜索可能受到文件系统大小写敏感性的影响。具体行为取决于 `lower_case_table_names` 系统变量的设置。

## 1.3 权限与安全

大多数 `INFORMATION_SCHEMA` 表的访问规则是：每个 MySQL 用户都有权访问这些表，但只能看到与该用户拥有适当访问权限的对象对应的行。在某些情况下（例如 `ROUTINES` 表中的 `ROUTINE_DEFINITION` 列），权限不足的用户会看到 `NULL` 值。

需要特别注意的是，InnoDB 相关的 `INFORMATION_SCHEMA` 表（名称以 `INNODB_` 开头的表）要求 `PROCESS` 权限才能查询。

## 1.4 性能考量

跨多个数据库的 `INFORMATION_SCHEMA` 查询可能耗时较长并影响性能。建议使用 `EXPLAIN` 检查查询效率。MySQL 8.4 提供 `information_schema_stats_expiry` 系统变量控制缓存统计信息的过期时间（默认 86400 秒，即 24 小时）。若将此值设为 0，则始终直接从存储引擎获取最新统计信息。

# 二、INFORMATION_SCHEMA 表索引总览

MySQL 8.4 的 `INFORMATION_SCHEMA` 共包含约 78 个表（视图），主要分为以下两大类：

| 类别 | 说明 |
|------|------|
| 通用表（General Tables） | 不与特定存储引擎、组件或插件关联的表，约 49 个 |
| InnoDB 表 | InnoDB 存储引擎专用的元数据表，共 29 个 |

实际环境中 `INFORMATION_SCHEMA` 表数量如下：

```sql
SELECT COUNT(*) AS total_tables
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'information_schema';
```

```output
+-------------+
| total_tables |
+-------------+
| 78          |
+-------------+
```

> ⚠️ 注意：`INFORMATION_SCHEMA` 中的表类型为 `SYSTEM VIEW`，而非 `BASE TABLE`。这一区别反映了其作为虚拟视图而非物理基础表的本质。

# 三、通用表详解

通用表是 `INFORMATION_SCHEMA` 的核心组成部分，覆盖了数据库元数据的方方面面。以下按功能模块逐一说明。

### 3.1 数据库与模式 SCHEMATA 表

`SCHEMATA` 表即数据库本身，记录了 MySQL 实例中所有数据库的信息。每个数据库对应一行。

核心列说明：

- `CATALOG_NAME`：所属目录名，恒为 `def`
- `SCHEMA_NAME`：数据库名
- `DEFAULT_CHARACTER_SET_NAME`：默认字符集
- `DEFAULT_COLLATION_NAME`：默认排序规则
- `DEFAULT_ENCRYPTION`：默认加密设置（MySQL 8.0 新增）

以下示例查询所有可访问的数据库及其默认排序规则：

```sql
SELECT SCHEMA_NAME, DEFAULT_CHARACTER_SET_NAME, DEFAULT_COLLATION_NAME
FROM information_schema.SCHEMATA
ORDER BY SCHEMA_NAME;
```

```output
+--------------------+------------------------+----------------------+
| SCHEMA_NAME        | DEFAULT_CHARACTER_SET_ | DEFAULT_COLLATION_   |
+--------------------+------------------------+----------------------+
| information_schema | utf8mb3                | utf8mb3_general_ci   |
| mysql              | utf8mb4                | utf8mb4_0900_ai_ci   |
| performance_schema | utf8mb3                | utf8mb3_general_ci   |
| sys                | utf8mb4                | utf8mb4_0900_ai_ci   |
+--------------------+------------------------+----------------------+
```

### 3.1 数据库与模式 SCHEMATA_EXTENSIONS 表

`SCHEMATA_EXTENSIONS` 表对 `SCHEMATA` 进行了扩展，添加了 `OPTIONS` 列，用于指示数据库是否为只读状态。当数据库设置了 `READ ONLY = 1` 时，`OPTIONS` 列值为 `READ ONLY=1`。

### 3.2 表结构信息 TABLES 表

`TABLES` 表是最常用的元数据表之一，记录了所有表和视图的信息。其 `ENGINE` 列是 MySQL 对标准 SQL 的扩展，标准中并不存在此列。

核心列说明：

- `TABLE_SCHEMA`：所属数据库名
- `TABLE_NAME`：表名
- `TABLE_TYPE`：`BASE TABLE`（基础表）或 `VIEW`（视图）
- `ENGINE`：存储引擎（MySQL 扩展）
- `TABLE_ROWS`：估算的行数（对于 InnoDB 为近似值）
- `DATA_LENGTH`：数据长度（字节）
- `INDEX_LENGTH`：索引长度（字节）
- `AUTO_INCREMENT`：下一个自增值

以下示例展示如何查询某数据库中所有 InnoDB 表及其占用空间：

```sql
SELECT TABLE_NAME, TABLE_ROWS,
       FORMAT(DATA_LENGTH / 1024, 2) AS data_kb,
       FORMAT(INDEX_LENGTH / 1024, 2) AS index_kb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'mysql'
  AND ENGINE = 'InnoDB'
ORDER BY DATA_LENGTH DESC
LIMIT 5;
```

```output
+------------+------------+---------+---------+
| TABLE_NAME | TABLE_ROWS | data_kb | index_kb |
+------------+------------+---------+---------+
| server_cost  | 6      | 16.00   | 0.00    |
| engine_cost  | 2      | 16.00   | 0.00    |
| servers     | 0      | 16.00   | 0.00    |
| default_roles | 0    | 16.00   | 16.00   |
| role_edges  | 0      | 16.00   | 16.00   |
+------------+------------+---------+---------+
```

### 3.2 表结构信息 TABLE_CONSTRAINTS 表

`TABLE_CONSTRAINTS` 表记录了所有表的约束信息，包括主键（`PRIMARY KEY`）、唯一键（`UNIQUE`）、外键（`FOREIGN KEY`）和检查约束（`CHECK`）。

```sql
SELECT CONSTRAINT_SCHEMA, TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'mysql'
ORDER BY TABLE_NAME
LIMIT 5;
```

```output
+---------------+------------+------------------+------------------+
| CONSTRAINT_SCH | TABLE_NAME  | CONSTRAINT_NAME  | CONSTRAINT_TYPE |
+---------------+------------+------------------+------------------+
| mysql         | columns_priv | PRIMARY          | PRIMARY KEY     |
| mysql         | component    | PRIMARY          | PRIMARY KEY     |
| mysql         | db           | PRIMARY          | PRIMARY KEY     |
| mysql         | default_roles | PRIMARY         | PRIMARY KEY     |
| mysql         | engine_cost   | PRIMARY          | PRIMARY KEY     |
+---------------+------------+------------------+------------------+
```

### 3.3 列信息 COLUMNS 表

`COLUMNS` 表记录了所有表的列定义信息，是另一个使用频率极高的元数据表。

核心列说明：

- `ORDINAL_POSITION`：列在表中的位置（从 1 开始）
- `DATA_TYPE`：数据类型（纯类型名）
- `COLUMN_TYPE`：完整列类型（含精度、长度等信息）
- `COLUMN_KEY`：`PRI`（主键）、`UNI`（唯一键）、`MUL`（普通索引）
- `EXTRA`：额外属性（`auto_increment`、`STORED GENERATED`、`VIRTUAL GENERATED` 等）
- `GENERATION_EXPRESSION`：生成列的表达式

以下示例展示如何查询某表的所有列及其类型：

```sql
SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE,
       IS_NULLABLE, COLUMN_KEY, EXTRA
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'mysql' AND TABLE_NAME = 'user'
ORDER BY ORDINAL_POSITION
LIMIT 10;
```

```output
+------------------------+-------------+------------------+-------------+------------+-------+
| COLUMN_NAME            | DATA_TYPE   | COLUMN_TYPE      | IS_NULLABLE | COLUMN_KEY | EXTRA |
+------------------------+-------------+------------------+-------------+------------+-------+
| Host                   | char        | char(255)        | NO          | PRI        |       |
| User                   | char        | char(32)         | NO          | PRI        |       |
| Select_priv            | enum        | enum('N','Y')    | NO          |            |       |
| Insert_priv            | enum        | enum('N','Y')    | NO          |            |       |
| Update_priv            | enum        | enum('N','Y')    | NO          |            |       |
| Delete_priv            | enum        | enum('N','Y')    | NO          |            |       |
| Index_priv             | enum        | enum('N','Y')    | NO          |            |       |
| Create_priv            | enum        | enum('N','Y')    | NO          |            |       |
| Drop_priv              | enum        | enum('N','Y')    | NO          |            |       |
| Reload_priv            | enum        | enum('N','Y')    | NO          |            |       |
+------------------------+-------------+------------------+-------------+------------+-------+
```

`COLUMN_KEY` 列的取值含义常引起混淆，以下是详细说明：

- **空值**：列未建立索引，或仅作为多列非唯一索引的次要列
- `PRI`：列是 `PRIMARY KEY` 的一部分，或为多列 `PRIMARY KEY` 中的某一列
- `UNI`：列是 `UNIQUE` 索引的第一列（注意：可含多个 `NULL` 值）
- `MUL`：列是普通索引的第一列，该索引允许重复值

### 3.4 索引与统计 STATISTICS 表

`STATISTICS` 表记录了所有表的索引信息。统计信息默认缓存 24 小时，可通过 `information_schema_stats_expiry` 控制。

核心列说明：

- `NON_UNIQUE`：索引是否可含重复值（1=可以，0=不可以）
- `INDEX_NAME`：索引名（主键索引始终为 `PRIMARY`）
- `SEQ_IN_INDEX`：索引中列的顺序号
- `COLUMN_NAME`：被索引的列名
- `CARDINALITY`：基数估计值（唯一值数量）
- `INDEX_TYPE`：索引类型（`BTREE`、`HASH`、`FULLTEXT`、`RTREE`）
- `IS_VISIBLE`：索引是否对优化器可见

以下示例展示如何查看某表的索引详情：

```sql
SELECT INDEX_NAME, COLUMN_NAME, SEQ_IN_INDEX,
       NON_UNIQUE, COLLATION, INDEX_TYPE, IS_VISIBLE
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'mysql' AND TABLE_NAME = 'db'
ORDER BY INDEX_NAME, SEQ_IN_INDEX;
```

```output
+-------------+-------------+---------------+-------------+-----------+------------+-------------+
| INDEX_NAME  | COLUMN_NAME | SEQ_IN_INDEX  | NON_UNIQUE  | COLLATION | INDEX_TYPE | IS_VISIBLE  |
+-------------+-------------+---------------+-------------+------------+------------+-------------+
| PRIMARY     | Host        | 1             | 0           | A         | BTREE      | YES         |
| PRIMARY     | Db          | 2             | 0           | A         | BTREE      | YES         |
| PRIMARY     | User        | 3             | 0           | A         | BTREE      | YES         |
| idx_db      | Db          | 1             | 1           | A         | BTREE      | YES         |
+-------------+-------------+---------------+-------------+------------+------------+-------------+
```

### 3.5 约束键使用 KEY_COLUMN_USAGE 表

`KEY_COLUMN_USAGE` 表描述了哪些列具有键约束。它提供了比 `SHOW INDEX` 更丰富的约束上下文信息，包括外键引用的目标表和列。

关键列说明：

- `CONSTRAINT_NAME`：约束名（主键约束名为 `PRIMARY`）
- `TABLE_NAME`：拥有约束的表
- `COLUMN_NAME`：受约束的列
- `REFERENCED_TABLE_NAME`：被引用的表（仅外键）
- `REFERENCED_COLUMN_NAME`：被引用的列（仅外键）

以下示例展示如何查询所有主键约束的列信息：

```sql
SELECT DISTINCT kcu.TABLE_SCHEMA, kcu.TABLE_NAME, kcu.COLUMN_NAME,
       kcu.CONSTRAINT_NAME, kcu.ORDINAL_POSITION
FROM information_schema.KEY_COLUMN_USAGE kcu
JOIN information_schema.TABLE_CONSTRAINTS tc
  ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
  AND kcu.TABLE_SCHEMA = 'mysql'
ORDER BY kcu.TABLE_NAME, kcu.ORDINAL_POSITION
LIMIT 5;
```

```output
+-------------+--------------+-------------+------------------+-----------------+
| TABLE_SCHEMA | TABLE_NAME   | COLUMN_NAME | CONSTRAINT_NAME   | ORDINAL_POSITION |
+-------------+--------------+-------------+------------------+-----------------+
| mysql        | columns_priv | Host        | PRIMARY           |               1 |
| mysql        | columns_priv | User        | PRIMARY           |               2 |
| mysql        | columns_priv | Db          | PRIMARY           |               3 |
| mysql        | columns_priv | Table_name | PRIMARY           |               4 |
| mysql        | columns_priv | Column_name | PRIMARY           |               5 |
+-------------+--------------+-------------+------------------+-----------------+
```

### 3.5 约束键使用 REFERENTIAL_CONSTRAINTS 表

`REFERENTIAL_CONSTRAINTS` 表提供外键约束的详细信息，包括级联更新/删除行为。以下示例查询某数据库中的所有外键约束及其级联策略：

```sql
SELECT CONSTRAINT_NAME, TABLE_NAME, REFERENCED_TABLE_NAME,
       UPDATE_RULE, DELETE_RULE
FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'test_charsets';
```

> 💡 当前 `mysql` 系统数据库中没有用户自定义外键，因此该查询在系统表上返回空结果。在实际业务数据库中，可将 `CONSTRAINT_SCHEMA` 替换为实际数据库名进行查询。

### 3.6 分区信息 PARTITIONS 表

`PARTITIONS` 表记录了分区表的分区和子分区信息。对于非分区表，该表仍然包含一行，但大部分分区相关列为 `NULL`。

核心列说明：

- `PARTITION_NAME` / `SUBPARTITION_NAME`：分区/子分区名
- `PARTITION_METHOD`：`RANGE`、`LIST`、`HASH`、`LINEAR HASH`、`KEY`、`LINEAR KEY`
- `PARTITION_EXPRESSION`：分区表达式
- `TABLE_ROWS`：分区中的行数（InnoDB 分区表为估算值）
- `DATA_FREE`：已分配但未使用的空间

```sql
SELECT PARTITION_NAME, PARTITION_METHOD, PARTITION_EXPRESSION,
       TABLE_ROWS, DATA_FREE
FROM information_schema.PARTITIONS
WHERE TABLE_SCHEMA = 'mysql'
ORDER BY PARTITION_ORDINAL_POSITION;
```

```output
+-----------------+------------------+----------------------+------------+----------+
| PARTITION_NAME  | PARTITION_METHOD | PARTITION_EXPRESSION | TABLE_ROWS | DATA_FREE |
+-----------------+------------------+----------------------+------------+----------+
| p_galera_2      | KEY              | node_id              |          0 |   327680 |
| p_galera_1      | KEY              | node_id              |          0 |   327680 |
| p_galera_0      | KEY              | node_id              |          0 |   327680 |
+-----------------+------------------+----------------------+------------+----------+
```

### 3.7 存储过程与函数 ROUTINES 表

`ROUTINES` 表记录了所有存储过程和存储函数的信息。

关键列说明：

- `ROUTINE_NAME`：例程名称
- `ROUTINE_TYPE`：`PROCEDURE`（存储过程）或 `FUNCTION`（存储函数）
- `ROUTINE_DEFINITION`：SQL 定义体
- `IS_DETERMINISTIC`：`YES` 或 `NO`，指示是否为确定性函数
- `SQL_DATA_ACCESS`：`CONTAINS SQL`、`NO SQL`、`READS SQL DATA`、`MODIFIES SQL DATA`
- `SECURITY_TYPE`：`DEFINER` 或 `INVOKER`

### 3.8 事件调度器 EVENTS 表

`EVENTS` 表记录了事件调度器（Event Scheduler）中所有事件的信息。事件是按计划在给定时间执行的任务。

关键列说明：

- `EVENT_NAME`：事件名
- `EVENT_TYPE`：`ONE TIME`（一次性）或 `RECURRING`（重复）
- `STATUS`：`ENABLED`、`DISABLED` 或 `REPLICA_SIDE_DISABLED`
- `EXECUTE_AT`：一次性事件的执行时间
- `INTERVAL_VALUE` / `INTERVAL_FIELD`：重复事件的间隔

```sql
SELECT EVENT_SCHEMA, EVENT_NAME, EVENT_TYPE, STATUS, DEFINER
FROM information_schema.EVENTS
WHERE EVENT_SCHEMA = 'mysql';
```

> 💡 当前实例中系统事件调度器（Event Scheduler）默认关闭，因此 `mysql` 数据库中没有预设事件。以上查询返回空结果。

### 3.9 视图 VIEWS 表

`VIEWS` 表记录了所有视图的定义信息，包括视图体、是否可更新、检查选项等。

关键列说明：
- `TABLE_CATALOG`：所属目录名，恒为 `def`
- `TABLE_SCHEMA`：视图所属数据库名
- `TABLE_NAME`：视图名
- `VIEW_DEFINITION`：视图定义（`SELECT` 语句）
- `CHECK_OPTION`：`NONE`、`CASCADED` 或 `LOCAL`，表示检查选项
- `IS_UPDATABLE`：`YES` 或 `NO`，视图是否可更新
- `DEFINER`：定义者（`'user_name'@'host_name'` 格式）
- `SECURITY_TYPE`：`DEFINER` 或 `INVOKER`
- `CHARACTER_SET_CLIENT`：定义视图时的字符集
- `COLLATION_CONNECTION`：定义视图时的排序规则

```sql
SELECT TABLE_SCHEMA, TABLE_NAME, CHECK_OPTION,
       IS_UPDATABLE, DEFINER, SECURITY_TYPE
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'sys'
LIMIT 3;
```

```output
+-------------+-----------------------------+---------------+---------------+-------------------------+---------------+
| TABLE_SCHEMA | TABLE_NAME                  | CHECK_OPTION | IS_UPDATABLE | DEFINER                 | SECURITY_TYPE |
+-------------+-----------------------------+---------------+---------------+-------------------------+---------------+
| sys         | host_summary                | NONE         | NO           | mysql.sys@localhost     | INVOKER       |
| sys         | host_summary_by_file_io     | NONE         | NO           | mysql.sys@localhost     | INVOKER       |
| sys         | host_summary_by_file_io_type | NONE         | YES          | mysql.sys@localhost     | INVOKER       |
+-------------+-----------------------------+---------------+---------------+-------------------------+---------------+
```

### 3.10 字符集与排序规则 CHARACTER_SETS 表

`CHARACTER_SETS` 表列出了 MySQL 支持的所有字符集，包括字符集名、默认排序规则、描述和最大长度。

关键列说明：
- `CHARACTER_SET_NAME`：字符集名
- `DEFAULT_COLLATE_NAME`：默认排序规则名
- `DESCRIPTION`：描述
- `MAXLEN`：最大字节长度

```sql
SELECT CHARACTER_SET_NAME, DEFAULT_COLLATE_NAME, DESCRIPTION, MAXLEN
FROM information_schema.CHARACTER_SETS
WHERE CHARACTER_SET_NAME IN ('utf8mb4', 'latin1', 'gbk', 'utf8mb3')
ORDER BY CHARACTER_SET_NAME;
```

```output
+--------------------+------------------------+--------------------------------+--------+
| CHARACTER_SET_NAME | DEFAULT_COLLATE_NAME   | DESCRIPTION                    | MAXLEN |
+--------------------+------------------------+--------------------------------+--------+
| gbk                | gbk_chinese_ci         | GBK Simplified Chinese         |      2 |
| latin1             | latin1_swedish_ci      | cp1252 West European           |      1 |
| utf8mb3            | utf8mb3_general_ci     | UTF-8 Unicode                  |      3 |
| utf8mb4            | utf8mb4_0900_ai_ci     | UTF-8 Unicode                  |      4 |
+--------------------+------------------------+--------------------------------+--------+
```

### 3.11 字符集与排序规则 COLLATIONS 表

`COLLATIONS` 表列出了所有排序规则及其属性，包括是否为默认排序规则、是否编译进服务器、排序长度和填充属性。

关键列说明：
- `COLLATION_NAME`：排序规则名
- `CHARACTER_SET_NAME`：所属字符集
- `ID`：排序规则 ID
- `IS_DEFAULT`：是否为该字符集默认排序规则
- `IS_COMPILED`：是否编译进服务器
- `SORTLEN`：排序长度
- `PAD_ATTRIBUTE`：`PAD SPACE` 或 `NO PAD`

```sql
SELECT COLLATION_NAME, CHARACTER_SET_NAME,
       ID, IS_DEFAULT, IS_COMPILED, SORTLEN, PAD_ATTRIBUTE
FROM information_schema.COLLATIONS
WHERE CHARACTER_SET_NAME = 'utf8mb4'
ORDER BY COLLATION_NAME
LIMIT 5;
```

```output
+----------------------+--------------------+------+------------+-------------+---------+--------------+
| COLLATION_NAME       | CHARACTER_SET_NAME | ID   | IS_DEFAULT | IS_COMPILED | SORTLEN | PAD_ATTRIBUTE |
+----------------------+--------------------+------+------------+-------------+---------+--------------+
| utf8mb4_0900_ai_ci   | utf8mb4            |  255 | Yes        | Yes         |       0 | NO PAD        |
| utf8mb4_0900_as_ci   | utf8mb4            |  305 |            | Yes         |       0 | NO PAD        |
| utf8mb4_0900_as_cs   | utf8mb4            |  278 |            | Yes         |       0 | NO PAD        |
| utf8mb4_0900_bin    | utf8mb4            |  309 |            | Yes         |       1 | NO PAD        |
| utf8mb4_bg_0900_ai_ci| utf8mb4            |  318 |            | Yes         |       0 | NO PAD        |
+----------------------+--------------------+------+------------+-------------+---------+--------------+
```

这里需要注意 `PAD_ATTRIBUTE` 列的两个取值：`PAD SPACE` 表示排序比较时考虑尾部空格（`utf8mb4_general_ci` 等旧排序规则），而 `NO PAD` 表示尾部空格在比较中被忽略（`utf8mb4_0900_ai_ci` 等 MySQL 8.0 新排序规则）。

### 3.12 插件 PLUGINS 表

`PLUGINS` 表记录了服务器已安装的所有插件信息，包括插件名、类型、状态、加载方式等。

关键列说明：
- `PLUGIN_NAME`：插件名
- `PLUGIN_VERSION`：插件版本
- `PLUGIN_STATUS`：状态（`ACTIVE`、`INACTIVE` 等）
- `PLUGIN_TYPE`：类型（`STORAGE ENGINE`、`AUTHENTICATION` 等）
- `PLUGIN_LIBRARY`：共享库文件名（可为 `NULL` 表示内置）
- `PLUGIN_AUTHOR`：作者
- `PLUGIN_DESCRIPTION`：描述
- `PLUGIN_LICENSE`：许可证
- `LOAD_OPTION`：`ON`、`OFF` 或 `FORCE`

```sql
SELECT PLUGIN_NAME, PLUGIN_TYPE, PLUGIN_VERSION,
       PLUGIN_STATUS, PLUGIN_AUTHOR, LOAD_OPTION
FROM information_schema.PLUGINS
WHERE PLUGIN_TYPE IN ('STORAGE ENGINE', 'AUTHENTICATION')
ORDER BY PLUGIN_TYPE, PLUGIN_NAME;
```

```output
+-------------------------+------------------+----------------+---------------+------------------+------------+
| PLUGIN_NAME             | PLUGIN_TYPE      | PLUGIN_VERSION | PLUGIN_STATUS | PLUGIN_AUTHOR    | LOAD_OPTION |
+-------------------------+------------------+----------------+---------------+------------------+------------+
| caching_sha2_password   | AUTHENTICATION   | 1.0            | ACTIVE        | Oracle Corporation | FORCE     |
| mysql_native_password   | AUTHENTICATION   | 1.1            | DISABLED      | Oracle Corporation | OFF       |
| sha256_password         | AUTHENTICATION   | 1.1            | ACTIVE        | Oracle Corporation | FORCE     |
| ARCHIVE                 | STORAGE ENGINE  | 3.0            | ACTIVE        | Oracle Corporation | ON        |
| binlog                  | STORAGE ENGINE  | 1.0            | ACTIVE        | Oracle Corporation | FORCE     |
| BLACKHOLE               | STORAGE ENGINE  | 1.0            | ACTIVE        | Oracle Corporation | ON        |
| CSV                     | STORAGE ENGINE  | 1.0            | ACTIVE        | Oracle Corporation | FORCE     |
| FEDERATED               | STORAGE ENGINE  | 1.0            | DISABLED      | Oracle Corporation | OFF       |
| InnoDB                  | STORAGE ENGINE  | 8.4            | ACTIVE        | Oracle Corporation | FORCE     |
| MEMORY                  | STORAGE ENGINE  | 1.0            | ACTIVE        | Oracle Corporation | ON        |
| MRG_MYISAM              | STORAGE ENGINE  | 1.0            | ACTIVE        | Oracle Corporation | ON        |
| MyISAM                  | STORAGE ENGINE  | 1.0            | ACTIVE        | Oracle Corporation | ON        |
| ndbcluster              | STORAGE ENGINE  | 1.0            | DISABLED      | Oracle Corporation | OFF       |
| ndbinfo                 | STORAGE ENGINE  | 0.1            | DISABLED      | Oracle Corporation | OFF       |
| PERFORMANCE_SCHEMA      | STORAGE ENGINE  | 0.1            | ACTIVE        | Oracle Corporation | FORCE     |
| TempTable               | STORAGE ENGINE  | 1.0            | ACTIVE        | Oracle Corporation | FORCE     |
+-------------------------+------------------+----------------+---------------+------------------+------------+
```

### 3.13 存储引擎 ENGINES 表

`ENGINES` 表列出 MySQL 支持的所有存储引擎及其属性。

关键列说明：

- `ENGINE`：存储引擎的名称，如 `InnoDB`、`MyISAM`、`MEMORY`、`CSV`
- `SUPPORT`：服务器对该引擎的支持级别，可能值为 `YES`（支持且已启用）、`DEFAULT`（支持且为默认引擎）、`NO`（不支持）、`DISABLED`（支持但已禁用）
- `COMMENT`：引擎的简短描述
- `TRANSACTIONS`：是否支持事务，可能值为 `YES`、`NO`、`NULL`（未知）
- `XA`：是否支持 XA 两阶段提交，可能值为 `YES`、`NO`、`NULL`（未知）
- `SAVEPOINTS`：是否支持 `SAVEPOINT`，可能值为 `YES`、`NO`、`NULL`（未知）

```sql
SELECT ENGINE, SUPPORT, COMMENT, TRANSACTIONS, XA, SAVEPOINTS
FROM information_schema.ENGINES
ORDER BY SUPPORT DESC, ENGINE;
```

```output
+---------+---------+-------------------------------------------+---------------+----+-------------+
| ENGINE  | SUPPORT | COMMENT                                   | TRANSACTIONS | XA | SAVEPOINTS  |
+---------+---------+-------------------------------------------+---------------+----+-------------+
| InnoDB  | DEFAULT | Transactional tables with ACID commit...  | YES           | YES| YES         |
| MyISAM  | YES     | Non-transactional table...                | NO            | NO | NO          |
| MEMORY  | YES     | Hash based, stored in memory...           | NO            | NO | NO          |
| CSV     | YES     | CSV storage engine                        | NO            | NO | NO          |
| InnoDB  | YES     | Transactional tables with ACID commit...  | YES           | YES| YES         |
+---------+---------+-------------------------------------------+---------------+----+-------------+
```

## 3.14 权限管理

`INFORMATION_SCHEMA` 提供了多个与权限相关的表，覆盖了从全局到列级别的完整权限体系：

| 表名 | 级别 | 来源 |
|------|------|------|
| `USER_PRIVILEGES` | 全局 | `mysql.user` |
| `SCHEMA_PRIVILEGES` | 数据库 | `mysql.db` |
| `TABLE_PRIVILEGES` | 表 | `mysql.tables_priv` |
| `COLUMN_PRIVILEGES` | 列 | `mysql.columns_priv` |

```sql
SELECT GRANTEE, TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME,
       PRIVILEGE_TYPE, IS_GRANTABLE
FROM information_schema.COLUMN_PRIVILEGES
LIMIT 5;
```

## 3.15 角色与角色授权

MySQL 8.0 引入的角色功能通过以下 `INFORMATION_SCHEMA` 表进行管理：

| 表名 | 说明 |
|------|------|
| `APPLICABLE_ROLES` | 当前用户可用的所有角色 |
| `ENABLED_ROLES` | 当前会话中已启用的角色 |
| `ADMINISTRABLE_ROLE_AUTHORIZATIONS` | 当前用户可授权给他人的角色 |
| `ROLE_COLUMN_GRANTS` | 当前启用角色的列级权限 |
| `ROLE_ROUTINE_GRANTS` | 当前启用角色的例程级权限 |
| `ROLE_TABLE_GRANTS` | 当前启用角色的表级权限 |

```sql
SELECT ROLE_NAME, IS_DEFAULT, IS_MANDATORY
FROM information_schema.ENABLED_ROLES;
```

### 3.14 资源组 RESOURCE_GROUPS 表

MySQL 8.0 引入的资源组功能允许将线程绑定到特定 CPU 或设置优先级。该表记录了所有资源组的信息。

关键列说明：
- `RESOURCE_GROUP_NAME`：资源组名
- `RESOURCE_GROUP_TYPE`：`SYSTEM` 或 `USER`
- `RESOURCE_GROUP_ENABLED`：`0`（禁用）或 `1`（启用）
- `VCPU_IDS`：分配的 CPU ID 列表
- `THREAD_PRIORITY`：线程优先级（系统资源组为负数，用户资源组为正数）

```sql
SELECT RESOURCE_GROUP_NAME, RESOURCE_GROUP_TYPE,
       RESOURCE_GROUP_ENABLED, VCPU_IDS, THREAD_PRIORITY
FROM information_schema.RESOURCE_GROUPS;
```

```output
+----------------------+----------------------+----------------------+-----------+----------------+
| RESOURCE_GROUP_NAME | RESOURCE_GROUP_TYPE  | RESOURCE_GROUP_ENABLD | VCPU_IDS  | THREAD_PRIORITY |
+----------------------+----------------------+----------------------+-----------+----------------+
| SYS_default         | SYSTEM               |                    1 | 0-7       |               0 |
| USR_default         | USER                 |                    1 | 0-7       |               0 |
+----------------------+----------------------+----------------------+-----------+----------------+
```

`THREAD_PRIORITY` 的取值范围中，负数表示高优先级（系统资源组从 -20 到 0），正数表示低优先级（用户资源组从 0 到 19）。

### 3.15 文件与表空间 FILES 表

`FILES` 表记录了 MySQL 表空间数据存储所在的文件信息，包括 InnoDB 数据文件、NDB Cluster 磁盘数据文件等。

关键列说明：

- `FILE_ID`：表空间 ID（InnoDB）
- `FILE_NAME`：数据文件名（含路径）
- `FILE_TYPE`：`TABLESPACE`（表空间文件）、`TEMPORARY`（临时表空间）、`UNDO LOG`（回滚段表空间）
- `TABLESPACE_NAME`：所属表空间名
- `FREE_EXTENTS` / `TOTAL_EXTENTS`：空闲/总 extent 数量

```sql
SELECT FILE_ID, FILE_NAME, FILE_TYPE, TABLESPACE_NAME,
       FREE_EXTENTS, TOTAL_EXTENTS, DATA_FREE
FROM information_schema.FILES
WHERE ENGINE = 'InnoDB'
ORDER BY FILE_ID;
```

```output
+--------+---------------------------+-------------+------------------+-------------+----------------+----------+
| FILE_ID | FILE_NAME                 | FILE_TYPE   | TABLESPACE_NAME  | FREE_EXTENTS | TOTAL_EXTENTS | DATA_FREE |
+--------+---------------------------+-------------+------------------+-------------+----------------+----------+
|      0 | innodb_system             | TABLESPACE  | innodb_system    |             |               |    65536 |
|      1 | ./mysql.ibd               | TABLESPACE  | mysql             |        4096 |           4096 |  67108864 |
...
+--------+---------------------------+-------------+------------------+-------------+----------------+----------+
```
# 四、InnoDB 专用表详解

InnoDB `INFORMATION_SCHEMA` 表（共 29 个）提供了 InnoDB 存储引擎内部的元数据和运行时状态信息。这些表对于理解 InnoDB 内部结构、诊断性能和锁问题至关重要。

> ⚠️ 注意：查询所有 InnoDB 相关的 `INFORMATION_SCHEMA` 表需要 `PROCESS` 权限。

## 4.1 InnoDB 表结构元数据

### 4.1 InnoDB 表结构元数据 INNODB_TABLES 表

`INNODB_TABLES` 表记录了 InnoDB 表的元数据，存储了表级别的内部信息。

关键列说明：

- `TABLE_ID`：表 ID，在实例内唯一
- `NAME`：表名，格式为 `schema_name/table_name`
- `FLAG`：表格式和存储特性的位级信息
- `N_COLS`：列数（含 3 个隐藏列：`DB_ROW_ID`、`DB_TRX_ID`、`DB_ROLL_PTR`）
- `SPACE`：表所在表空间 ID
- `ROW_FORMAT`：行格式（`Dynamic`、`Compressed`、`Compact`、`Redundant`）
- `SPACE_TYPE`：`System`（系统表空间）、`General`（通用表空间）、`Single`（独立表空间）
- `TOTAL_ROW_VERSIONS`：ALGORITHM=INSTANT 操作后的行版本计数

```sql
SELECT TABLE_ID, NAME, FLAG, N_COLS, SPACE,
       ROW_FORMAT, SPACE_TYPE, TOTAL_ROW_VERSIONS
FROM information_schema.INNODB_TABLES
WHERE NAME LIKE 'mysql/%'
ORDER BY TABLE_ID
LIMIT 5;
```

### 4.1 InnoDB 表结构元数据 INNODB_COLUMNS 表

`INNODB_COLUMNS` 表记录了 InnoDB 表列的内部元数据。

关键列说明：

- `TABLE_ID`：所属表的 ID
- `NAME`：列名
- `POS`：列在表中的位置（从 0 开始）
- `MTYPE`：主类型（1=VARCHAR, 6=INT, 14=GEOMETRY 等）
- `PRTYPE`：精确类型（含 MySQL 数据类型、字符集代码和可空性）
- `LEN`：列长度（字节）

```sql
SELECT TABLE_ID, NAME, POS, MTYPE, PRTYPE, LEN
FROM information_schema.INNODB_COLUMNS
WHERE TABLE_ID = (
    SELECT TABLE_ID FROM information_schema.INNODB_TABLES
    WHERE NAME = 'mysql/user'
)
ORDER BY POS;
```

```output
+---------+--------+-----+-------+---------+-----+
| TABLE_ID | NAME   | POS | MTYPE | PRTYPE  | LEN |
+---------+--------+-----+-------+---------+-----+
|    1026 | Host   |   0 |    13 |  721406 | 255 |
|    1026 | User   |   1 |    13 | 5439998 |  96 |
|    1026 | Select_priv | 2 |  6 |  1022 |   1 |
|    1026 | Insert_priv | 3 |  6 |  1022 |   1 |
|    1026 | Update_priv | 4 |  6 |  1022 |   1 |
+---------+--------+-----+-------+---------+-----+
```

### 4.1 InnoDB 表结构元数据 INNODB_INDEXES 表

`INNODB_INDEXES` 表记录了 InnoDB 索引的元数据。

关键列说明：

- `INDEX_ID`：索引 ID
- `NAME`：索引名（主键索引为 `GEN_CLUST_INDEX`）
- `TABLE_ID`：所属表的 ID
- `TYPE`：索引类型（0=二级索引, 1=唯一索引, 2=主键索引等）
- `N_FIELDS`：索引中列的数量
- `PAGE_NO`：B-tree 页编号
- `SPACE`：表空间 ID

```sql
SELECT INDEX_ID, NAME, TABLE_ID, TYPE, N_FIELDS, SPACE
FROM information_schema.INNODB_INDEXES
WHERE TABLE_ID = (
    SELECT TABLE_ID FROM information_schema.INNODB_TABLES
    WHERE NAME = 'mysql/user'
)
ORDER BY INDEX_ID;
```

### 4.1 InnoDB 表结构元数据 INNODB_FIELDS 表

`INNODB_FIELDS` 表记录了 InnoDB 索引键列的元数据，与 `INNODB_INDEXES` 表配合使用可以完整还原索引定义。

关键列说明：

- `INDEX_ID`：所属索引 ID
- `NAME`：列名
- `POS`：列在索引中的位置

```sql
SELECT i.NAME AS index_name, f.NAME AS column_name, f.POS AS position
FROM information_schema.INNODB_FIELDS f
JOIN information_schema.INNODB_INDEXES i ON f.INDEX_ID = i.INDEX_ID
WHERE i.TABLE_ID = (
    SELECT TABLE_ID FROM information_schema.INNODB_TABLES
    WHERE NAME = 'mysql/innodb_table_stats'
)
ORDER BY f.POS;
```

### 4.2 InnoDB 外键元数据 INNODB_FOREIGN 表

`INNODB_FOREIGN` 表记录了 InnoDB 外键的元数据。

关键列说明：

- `ID`：外键名（含数据库名前缀）
- `FOR_NAME`：子表名
- `REF_NAME`：父表名

```sql
SELECT ID, FOR_NAME, REF_NAME
FROM information_schema.INNODB_FOREIGN
WHERE FOR_NAME LIKE 'mysql/%'
LIMIT 5;
```

### 4.2 InnoDB 外键元数据 INNODB_FOREIGN_COLS 表

`INNODB_FOREIGN_COLS` 表记录了外键列的状态信息，补充了 `INNODB_FOREIGN` 表。

关键列说明：

- `ID`：外键 ID
- `FOR_COL_NAME`：子表列名
- `REF_COL_NAME`：父表列名
- `POS`：列在外键中的位置

```sql
SELECT f.ID AS foreign_key_name,
       fc.FOR_COL_NAME AS from_column,
       fc.REF_COL_NAME AS referenced_column
FROM information_schema.INNODB_FOREIGN f
JOIN information_schema.INNODB_FOREIGN_COLS fc ON f.ID = fc.ID
WHERE f.FOR_NAME LIKE 'mysql/%'
LIMIT 5;
```

## 4.3 InnoDB 表空间元数据

### 4.3 InnoDB 表空间元数据 INNODB_TABLESPACES 表

`INNODB_TABLESPACES` 表记录了 InnoDB 表空间的详细元数据，覆盖文件表空间、通用表空间和回滚表空间。

关键列说明：

- `SPACE`：表空间 ID
- `NAME`：表空间名
- `FLAG`：表空间格式的位级信息
- `ROW_FORMAT`：行格式
- `PAGE_SIZE`：页大小
- `SPACE_TYPE`：`System`、`General`、`Single`、`Undo`
- `FS_BLOCK_SIZE`：文件系统块大小（用于透明页压缩的空洞打孔）
- `FILE_SIZE`：表空间表观大小
- `ALLOCATED_SIZE`：实际分配大小
- `ENCRYPTION`：是否加密
- `STATE`：表空间状态（`normal`、`discarded`、`corrupted`）

```sql
SELECT SPACE, NAME, SPACE_TYPE, ROW_FORMAT,
       FILE_SIZE, ALLOCATED_SIZE, ENCRYPTION, STATE
FROM information_schema.INNODB_TABLESPACES
WHERE SPACE_TYPE IN ('Single', 'General')
ORDER BY SPACE
LIMIT 10;
```

### 4.3 InnoDB 表空间元数据 INNODB_TABLESPACES_BRIEF 表

`INNODB_TABLESPACES_BRIEF` 表提供了表空间元数据的精简版本，加载速度更快。

关键列说明：

- `SPACE`：表空间 ID
- `NAME`：表空间名
- `PATH`：数据文件路径
- `FLAG`：表空间格式标志
- `SPACE_TYPE`：`System`、`General`、`Single` 等

```sql
SELECT SPACE, NAME, PATH
FROM information_schema.INNODB_TABLESPACES_BRIEF
LIMIT 5;
```

```output
+-------+------------------+--------------------------+
| SPACE | NAME             | PATH                     |
+-------+------------------+--------------------------+
|    45 | learn/accounts   | ./learn/accounts.ibd     |
|    12 | learn/auto_demo  | ./learn/auto_demo.ibd    |
|    16 | learn/binary_demo| ./learn/binary_demo.ibd  |
|     7 | learn/bit_demo   | ./learn/bit_demo.ibd     |
|    17 | learn/blob_demo  | ./learn/blob_demo.ibd    |
+-------+------------------+--------------------------+
```

### 4.3 InnoDB 表空间元数据 INNODB_DATAFILES 表

`INNODB_DATAFILES` 表记录了表空间数据文件的路径信息。

关键列说明：

- `SPACE`：表空间 ID
- `PATH`：数据文件路径

```sql
SELECT SPACE, PATH
FROM information_schema.INNODB_DATAFILES
WHERE SPACE IN (1, 2, 3)
ORDER BY SPACE;
```

```output
+-------+-----------------------------+
| SPACE | PATH                        |
+-------+-----------------------------+
|     1 | ./sys/sys_config.ibd       |
|     2 | ./learn/int_examples.ibd   |
|     3 | ./learn/serial_demo.ibd    |
+-------+-----------------------------+
```

### 4.4 InnoDB 表统计信息 INNODB_TABLESTATS 表

`INNODB_TABLESTATS` 表提供了 InnoDB 表的低层状态信息视图，这些数据由优化器用于计算查询计划。

关键列说明：

- `STATS_INITIALIZED`：`Initialized`（已收集）或 `Uninitialized`（未收集）
- `NUM_ROWS`：当前估算行数
- `CLUST_INDEX_SIZE`：主键索引占用的页数
- `OTHER_INDEX_SIZE`：所有二级索引占用的页数
- `MODIFIED_COUNTER`：DML 操作修改的行数
- `REF_COUNT`：引用计数，归零时表元数据可从缓存中驱逐

```sql
SELECT TABLE_ID, NAME, STATS_INITIALIZED, NUM_ROWS,
       CLUST_INDEX_SIZE, OTHER_INDEX_SIZE, MODIFIED_COUNTER
FROM information_schema.INNODB_TABLESTATS
WHERE NAME LIKE 'mysql/%'
LIMIT 5;
```

### 4.5 InnoDB 事务与锁 INNODB_TRX 表

`INNODB_TRX` 表是最重要的 InnoDB 诊断表之一，提供了当前在 InnoDB 中执行的所有事务的详细信息。

关键列说明：

- `TRX_ID`：事务 ID（只读非锁定事务不生成）
- `TRX_STATE`：事务状态（`RUNNING`、`LOCK WAIT`、`ROLLING BACK`、`COMMITTING`）
- `TRX_STARTED`：事务开始时间
- `TRX_MYSQL_THREAD_ID`：MySQL 线程 ID
- `TRX_QUERY`：正在执行的 SQL 语句
- `TRX_OPERATION_STATE`：当前操作状态
- `TRX_ROWS_LOCKED`：锁定行数（含删除标记行）
- `TRX_ROWS_MODIFIED`：修改行数

以下示例查询当前所有运行中的事务及其执行的语句：

```sql
SELECT TRX_ID, TRX_STATE, TRX_STARTED,
       TRX_MYSQL_THREAD_ID AS thread_id,
       LEFT(TRX_QUERY, 50) AS query
FROM information_schema.INNODB_TRX
WHERE TRX_STATE = 'RUNNING';
```

> 💡 诊断技巧：`INNODB_TRX` 与 Performance Schema 的 `data_locks` 表可以通过 `TRX_REQUESTED_LOCK_ID` 和 `ENGINE_LOCK_ID` 进行关联，获取完整的锁等待信息。

### 4.6 InnoDB 虚拟生成列 INNODB_VIRTUAL 表

`INNODB_VIRTUAL` 表记录了 InnoDB 虚拟生成列的元数据。虚拟生成列的值在读取时实时计算，不存储在磁盘上。

关键列说明：

- `TABLE_ID`：所属表的 ID
- `POS`：列位置（含编码信息）
- `BASE_POS`：基础列位置

```sql
SELECT TABLE_ID, POS, BASE_POS
FROM information_schema.INNODB_VIRTUAL
ORDER BY TABLE_ID, POS
LIMIT 5;
```

```output
+---------+-------+----------+
| TABLE_ID | POS   | BASE_POS |
+---------+-------+----------+
|    1055 | 65540 |        0 |
|    1056 | 65542 |        2 |
+---------+-------+----------+
```

### 4.7 InnoDB 缓冲池信息 INNODB_BUFFER_PAGE 表

记录缓冲池中每个页的详细信息，包括页类型（`INDEX`、`UNDO_LOG`、`INODE`、`SYSTEM`、`TRX_SYSTEM` 等）、表空间 ID、页编号和 LRU 位置。

关键列说明：

- `POOL_ID`：缓冲池实例 ID
- `SPACE`：表空间 ID
- `PAGE_NUMBER`：页编号
- `PAGE_TYPE`：页类型（`INDEX`、`UNDO_LOG`、`BLOB` 等）
- `LRU_POSITION`：在 LRU 列表中的位置

```sql
SELECT POOL_ID, SPACE, PAGE_NUMBER, PAGE_TYPE
FROM information_schema.INNODB_BUFFER_PAGE
WHERE PAGE_TYPE = 'INDEX'
LIMIT 5;
```

```output
+---------+-------------+-------------+-----------+
| POOL_ID | SPACE       | PAGE_NUMBER | PAGE_TYPE |
+---------+-------------+-------------+-----------+
|       0 | 4294967294  |         385 | INDEX     |
|       0 | 4294967294  |           4 | INDEX     |
|       0 | 4294967294  |          67 | INDEX     |
|       0 | 4294967294  |          68 | INDEX     |
|       0 | 4294967294  |          69 | INDEX     |
+---------+-------------+-------------+-----------+
```

### 4.7 InnoDB 缓冲池信息 INNODB_BUFFER_PAGE_LRU 表

以 LRU（最近最少使用）顺序记录缓冲池中的页信息，可用于分析缓冲池的冷热数据分布。

关键列说明：

- `POOL_ID`：缓冲池实例 ID
- `SPACE`：表空间 ID
- `LRU_POSITION`：在 LRU 列表中的位置
- `PAGE_NUMBER`：页编号

```sql
SELECT POOL_ID, SPACE, LRU_POSITION, PAGE_NUMBER
FROM information_schema.INNODB_BUFFER_PAGE_LRU
WHERE POOL_ID = 0
LIMIT 5;
```

```output
+---------+-------+--------------+-------------+
| POOL_ID | SPACE | LRU_POSITION | PAGE_NUMBER |
+---------+-------+--------------+-------------+
|       0 |     0 |            0 |           7 |
|       0 |     0 |            1 |           3 |
|       0 |     0 |            2 |           2 |
|       0 |     0 |            3 |           4 |
|       0 |     0 |            4 |           6 |
+---------+-------+--------------+-------------+
```

### 4.7 InnoDB 缓冲池信息 INNODB_BUFFER_POOL_STATS 表

提供缓冲池的整体统计信息，包括缓冲池大小、已使用页数、空闲页数、命中率等。

关键列说明：

- `POOL_ID`：缓冲池实例 ID
- `DATABASE_PAGES`：当前页数
- `MODIFIED_DATABASE_PAGES`：脏页数
- `NUMBER_PAGES_READ`：`NUMBER_PAGES_READ` 读取页数
- `NUMBER_PAGES_WRITTEN`：写入页数
- `HIT_RATE`：命中率

```sql
SELECT POOL_ID, DATABASE_PAGES, MODIFIED_DATABASE_PAGES,
       NUMBER_PAGES_READ, NUMBER_PAGES_WRITTEN,
       HIT_RATE
FROM information_schema.INNODB_BUFFER_POOL_STATS
LIMIT 3;
```

```output
+---------+------------------+---------------------------+-----------------------+--------------------------+----------+
| POOL_ID | DATABASE_PAGES   | MODIFIED_DATABASE_PAGES  | NUMBER_PAGES_READ     | NUMBER_PAGES_WRITTEN     | HIT_RATE |
+---------+------------------+---------------------------+-----------------------+--------------------------+----------+
|       0 |             1275 |                         0 |                  1129  |                      411 |     1000 |
+---------+------------------+---------------------------+-----------------------+--------------------------+----------+
```

### 4.7 InnoDB 缓冲池信息 INNODB_CACHED_INDEXES 表

记录每个索引在缓冲池中缓存的索引页数量。

关键列说明：

- `SPACE_ID`：表空间 ID
- `INDEX_ID`：索引 ID
- `N_CACHED_PAGES`：缓存的索引页数

```sql
SELECT SPACE_ID, INDEX_ID, N_CACHED_PAGES
FROM information_schema.INNODB_CACHED_INDEXES
LIMIT 5;
```

```output
+----------+----------+----------------+
| SPACE_ID | INDEX_ID | N_CACHED_PAGES |
+----------+----------+----------------+
| 4294967294 |        1 |              1 |
| 4294967294 |        2 |              1 |
| 4294967294 |        3 |              1 |
| 4294967294 |        4 |              1 |
| 4294967294 |        5 |              1 |
+----------+----------+----------------+
```

## 4.8 InnoDB 压缩信息（已弃用）

InnoDB 压缩相关的 `INFORMATION_SCHEMA` 表已在 MySQL 8.4 中弃用，包括 `INNODB_CMP`、`INNODB_CMP_RESET`、`INNODB_CMP_PER_INDEX`、`INNODB_CMP_PER_INDEX_RESET`、`INNODB_CMPMEM` 和 `INNODB_CMPMEM_RESET`。

### 4.9 InnoDB 全文索引信息 INNODB_FT_INDEX_CACHE 表

记录最近插入行的全文索引令牌信息，用于增量构建倒排索引。

关键列说明：

- `WORD`：全文索引词
- `FIRST_DOC_ID`：首文档 ID
- `LAST_DOC_ID`：末文档 ID
- `DOC_COUNT`：包含该词的文档数
- `DOC_ID`：文档 ID
- `POSITION`：令牌在文档中的位置

```sql
SELECT WORD, POSITION FROM information_schema.INNODB_FT_INDEX_CACHE LIMIT 3;
```

```output
Empty set
```

### 4.9 InnoDB 全文索引信息 INNODB_FT_DELETED 表

记录从 InnoDB 全文索引中删除的行，物理删除延迟执行以避免性能冲击。

关键列说明：

- `DOC_ID`：已删除行的文档 ID

```sql
SELECT DOC_ID FROM information_schema.INNODB_FT_DELETED LIMIT 5;
```

```output
Empty set
```

### 4.9 InnoDB 全文索引信息 INNODB_FT_BEING_DELETED 表

`INNODB_FT_BEING_DELETED` 表是 `INNODB_FT_DELETED` 的快照，用于在 `OPTIMIZE TABLE` 时提供一致的视图。

关键列说明：

- `DOC_ID`：正在删除的文档 ID

```sql
SELECT DOC_ID FROM information_schema.INNODB_FT_BEING_DELETED LIMIT 5;
```

```output
Empty set
```

### 4.9 InnoDB 全文索引信息 INNODB_FT_CONFIG 表

记录全文索引的元数据，包括爬取状态、文档计数等。

关键列说明：

- `KEY`：配置项名称
- `VALUE`：配置值

```sql
SELECT `KEY`, VALUE FROM information_schema.INNODB_FT_CONFIG LIMIT 5;
```

```output
Empty set
```

### 4.9 InnoDB 全文索引信息 INNODB_FT_DEFAULT_STOPWORD 表

InnoDB 全文索引使用的默认停用词列表。

关键列说明：

- `VALUE`：停用词

```sql
SELECT VALUE FROM information_schema.INNODB_FT_DEFAULT_STOPWORD LIMIT 10;
```

```output
+------------+
| VALUE      |
+------------+
| a          |
| about      |
| an         |
| are        |
| as         |
| at         |
| be         |
| by         |
| com        |
| de         |
+------------+
```

### 4.10 InnoDB 性能指标 INNODB_METRICS 表

`INNODB_METRICS` 表提供了 InnoDB 内部的性能指标集合，涵盖计数器、 Gauge 和状态信息。可以通过 `STATUS` 列筛选不同类型的指标。

关键列说明：

- `NAME`：指标名称
- `SUBSYSTEM`：所属子系统
- `TYPE`：指标类型
- `COUNT`：累计值

```sql
SELECT NAME, SUBSYSTEM, TYPE, COUNT
FROM information_schema.INNODB_METRICS
WHERE STATUS = 'enabled'
ORDER BY SUBSYSTEM, NAME
LIMIT 5;
```

```output
+-------------------------------+----------------------+-------------+---------+
| NAME                          | SUBSYSTEM            | TYPE        | COUNT   |
+-------------------------------+----------------------+-------------+---------+
| adaptive_hash_searches        | adaptive_hash_index | status_counter |     0 |
| adaptive_hash_searches_btree  | adaptive_hash_index | status_counter | 990341 |
| buffer_data_reads             | buffer              | status_counter | 18582016 |
| buffer_data_written           | buffer              | status_counter | 6926336 |
| buffer_pages_created          | buffer              | status_counter |     250 |
+-------------------------------+----------------------+-------------+---------+
```

### 4.11 InnoDB 临时表 INNODB_TEMP_TABLE_INFO 表

`INNODB_TEMP_TABLE_INFO` 表记录了用户创建的 InnoDB 临时表信息。该表在首次查询时创建，仅存在于内存中，不持久化到磁盘。

```sql
CREATE TEMPORARY TABLE tmp_test (c1 INT PRIMARY KEY) ENGINE = InnoDB;

SELECT TABLE_ID, NAME, N_COLS, SPACE
FROM information_schema.INNODB_TEMP_TABLE_INFO;
```

```output
+----------+---------------+-------+-------+
| TABLE_ID | NAME          | N_COLS | SPACE |
+----------+---------------+-------+-------+
|       97 | #sql8c88_43_0 |     4 |    76 |
+----------+---------------+-------+-------+
```

### 4.11 InnoDB 临时表 INNODB_SESSION_TEMP_TABLESPACES 表

记录会话级临时表空间的元数据。

关键列说明：

- `ID`：临时表空间 ID
- `SPACE`：表空间 ID
- `PATH`：数据文件路径
- `SIZE`：文件大小（字节）
- `STATE`：状态（`ACTIVE`、`INACTIVE`）
- `PURPOSE`：用途（`INTRINSIC TEMPORARY TABLE` 等）

```sql
SELECT ID, SPACE, PATH, SIZE, STATE, PURPOSE
FROM information_schema.INNODB_SESSION_TEMP_TABLESPACES
LIMIT 3;
```

```output
+-----+-------------+---------------------------------+--------+---------+--------------------+
| ID  | SPACE       | PATH                            | SIZE   | STATE   | PURPOSE            |
+-----+-------------+---------------------------------+--------+---------+--------------------+
|  10 | 4243767290  | ./#innodb_temp/temp_10.ibt     |  98304 | ACTIVE  | INTRINSIC          |
| 104 | 4243767289  | ./#innodb_temp/temp_9.ibt       |  81920 | ACTIVE  | INTRINSIC          |
|   0 | 4243767281  | ./#innodb_temp/temp_1.ibt       |  81920 | INACTIVE| NONE               |
+-----+-------------+---------------------------------+--------+---------+--------------------+
```
