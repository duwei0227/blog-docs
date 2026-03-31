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

## 3.1 数据库与模式

### SCHEMATA 表

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

### SCHEMATA_EXTENSIONS 表

`SCHEMATA_EXTENSIONS` 表对 `SCHEMATA` 进行了扩展，添加了 `OPTIONS` 列，用于指示数据库是否为只读状态。当数据库设置了 `READ ONLY = 1` 时，`OPTIONS` 列值为 `READ ONLY=1`。

## 3.2 表结构信息

### TABLES 表

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

### TABLE_CONSTRAINTS 表

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

## 3.3 列信息

### COLUMNS 表

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

## 3.4 索引与统计

### STATISTICS 表

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

## 3.5 约束键使用

### KEY_COLUMN_USAGE 表

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

### REFERENTIAL_CONSTRAINTS 表

`REFERENTIAL_CONSTRAINTS` 表提供外键约束的详细信息，包括级联更新/删除行为。以下示例查询某数据库中的所有外键约束及其级联策略：

```sql
SELECT CONSTRAINT_NAME, TABLE_NAME, REFERENCED_TABLE_NAME,
       UPDATE_RULE, DELETE_RULE
FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'test_charsets';
```

> 💡 当前 `mysql` 系统数据库中没有用户自定义外键，因此该查询在系统表上返回空结果。在实际业务数据库中，可将 `CONSTRAINT_SCHEMA` 替换为实际数据库名进行查询。

## 3.6 分区信息

### PARTITIONS 表

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

## 3.7 存储过程与函数

### ROUTINES 表

`ROUTINES` 表记录了所有存储过程和存储函数的信息。

关键列说明：

- `ROUTINE_NAME`：例程名称
- `ROUTINE_TYPE`：`PROCEDURE`（存储过程）或 `FUNCTION`（存储函数）
- `ROUTINE_DEFINITION`：SQL 定义体
- `DETERMINISTIC`：`YES` 或 `NO`，指示是否为确定性函数
- `SQL_DATA_ACCESS`：`CONTAINS SQL`、`NO SQL`、`READS SQL DATA`、`MODIFIES SQL DATA`
- `SECURITY_TYPE`：`DEFINER` 或 `INVOKER`

### PARAMETERS 表

`PARAMETERS` 表记录了存储例程的参数信息。对于存储函数，还包含一条表示返回值（`ORDINAL_POSITION = 0`）的行。

## 3.8 事件调度器

### EVENTS 表

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

## 3.9 视图

### VIEWS 表

`VIEWS` 表记录了所有视图的定义信息，包括视图体、是否可更新、检查选项等。

```sql
SELECT TABLE_SCHEMA, TABLE_NAME, VIEW_DEFINITION,
       CHECK_OPTION, IS_UPDATABLE
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'sys'
LIMIT 3;
```

### VIEW_ROUTINE_USAGE 与 VIEW_TABLE_USAGE

这两个表分别记录了视图中使用的存储函数和表/视图的依赖关系，可用于分析视图依赖链。

## 3.10 字符集与排序规则

### CHARACTER_SETS 表

`CHARACTER_SETS` 表列出了 MySQL 支持的所有字符集，包括字符集名、默认排序规则、描述和最大长度。

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

### COLLATIONS 表

`COLLATIONS` 表列出了所有排序规则及其属性，包括是否为默认排序规则、是否编译进服务器、排序长度和填充属性。

```sql
SELECT COLLATION_NAME, CHARACTER_SET_NAME,
       IS_DEFAULT, IS_COMPILED, PAD_ATTRIBUTE
FROM information_schema.COLLATIONS
WHERE CHARACTER_SET_NAME = 'utf8mb4'
ORDER BY COLLATION_NAME
LIMIT 5;
```

```output
+--------------------+--------------------+-----------+-------------+--------------+
| COLLATION_NAME     | CHARACTER_SET_NAME | IS_DEFAULT | IS_COMPILED | PAD_ATTRIBUTE |
+--------------------+--------------------+-----------+--------------+---------------+
| utf8mb4_general_ci  | utf8mb4            |            | YES         | PAD SPACE     |
| utf8mb4_bin         | utf8mb4            |            | YES         | PAD SPACE     |
| utf8mb4_unicode_ci  | utf8mb4            |            | YES         | PAD SPACE     |
| utf8mb4_0900_ai_ci  | utf8mb4            | YES        | YES         | NO PAD        |
| utf8mb4_0900_as_cs  | utf8mb4            |            | YES         | NO PAD        |
+--------------------+--------------------+-----------+--------------+---------------+
```

这里需要注意 `PAD_ATTRIBUTE` 列的两个取值：`PAD SPACE` 表示排序比较时考虑尾部空格（`utf8mb4_general_ci` 等旧排序规则），而 `NO PAD` 表示尾部空格在比较中被忽略（`utf8mb4_0900_ai_ci` 等 MySQL 8.0 新排序规则）。

### COLLATION_CHARACTER_SET_APPLICABILITY 表

该表建立了字符集与排序规则之间的对应关系，与 `SHOW COLLATION` 的前两列等价。

## 3.11 插件与存储引擎

### PLUGINS 表

`PLUGINS` 表记录了服务器已安装的所有插件信息，包括插件名、类型、状态、加载方式等。

```sql
SELECT PLUGIN_NAME, PLUGIN_TYPE, PLUGIN_STATUS, LOAD_OPTION
FROM information_schema.PLUGINS
WHERE PLUGIN_TYPE IN ('STORAGE ENGINE', 'AUTHENTICATION')
ORDER BY PLUGIN_TYPE, PLUGIN_NAME;
```

```output
+----------------------+------------------+---------------+-------------+
| PLUGIN_NAME          | PLUGIN_TYPE      | PLUGIN_STATUS | LOAD_OPTION |
+----------------------+------------------+---------------+-------------+
| mysql_native_password | AUTHENTICATION   | ACTIVE        | ON          |
| sha256_password       | AUTHENTICATION   | ACTIVE        | ON          |
| caching_sha2_password | AUTHENTICATION   | ACTIVE        | ON          |
| InnoDB                | STORAGE ENGINE   | ACTIVE        | ON          |
| MyISAM                | STORAGE ENGINE   | ACTIVE        | ON          |
| MEMORY                | STORAGE ENGINE   | ACTIVE        | ON          |
+----------------------+------------------+---------------+-------------+
```

### ENGINES 表

`ENGINES` 表列出 MySQL 支持的所有存储引擎及其属性。`SUPPORT` 列的可能值为：

| 值 | 含义 |
|----|------|
| `YES` | 支持且已启用 |
| `DEFAULT` | 支持、已启用且为默认引擎 |
| `NO` | 不支持（编译时未包含） |
| `DISABLED` | 支持但已禁用 |

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

## 3.12 权限管理

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

## 3.13 角色与角色授权

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

## 3.14 资源组

### RESOURCE_GROUPS 表

MySQL 8.0 引入的资源组功能允许将线程绑定到特定 CPU 或设置优先级。该表记录了所有资源组的信息。

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

## 3.15 文件与表空间

### FILES 表

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

## 3.16 优化器跟踪

### OPTIMIZER_TRACE 表

`OPTIMIZER_TRACE` 表提供了优化器跟踪功能产生的信息，用于调试和理解查询优化过程。启用跟踪需要设置 `optimizer_trace` 系统变量。

```sql
SET optimizer_trace = 'enabled=on';
SELECT COUNT(*) FROM mysql.user;  -- 执行待分析的查询
SELECT QUERY, LEFT(TRACE, 200) AS trace_preview,
       MISSING_BYTES_BEYOND_MAX_MEM_SIZE
FROM information_schema.OPTIMIZER_TRACE
LIMIT 1;
```

## 3.17 语句分析（已弃用）

### PROFILING 表

> ⚠️ 注意：`PROFILING` 表已在 MySQL 8.0 中弃用，建议迁移到 Performance Schema 的语句分析功能。

该表提供语句性能分析信息，与已弃用的 `SHOW PROFILE` 和 `SHOW PROFILES` 语句产生的信息相同。内容包括每个执行状态的时间、CPU 使用、上下文切换、块 I/O 操作等。

## 3.18 连接与进程（已弃用）

### PROCESSLIST 表

> ⚠️ 注意：`PROCESSLIST` 表已在 MySQL 8.0 中弃用，建议使用 Performance Schema 的 `threads` 表。

该表提供 MySQL 当前执行的线程信息。查询此表需要 `PROCESS` 权限。

```sql
SELECT ID, USER, HOST, DB, COMMAND, TIME, STATE
FROM information_schema.PROCESSLIST
ORDER BY TIME DESC
LIMIT 5;
```

## 3.19 关键字

### KEYWORDS 表

`KEYWORDS` 表列出 MySQL 视为关键字的所有词语，并标明是否为保留字。保留关键字在某些上下文中需要特殊引用处理（使用反引号）。

```sql
SELECT WORD, RESERVED
FROM information_schema.KEYWORDS
WHERE RESERVED = 1
ORDER BY WORD
LIMIT 10;
```

```output
+----------+-----------+
| WORD     | RESERVED  |
+----------+-----------+
| accessible |       1   |
| add         |       1   |
| admin       |       1   |
| after       |       1   |
| against     |       1   |
| algorithm   |       1   |
| all         |       1   |
| alter       |       1   |
| always      |       1   |
| analyze     |       1   |
+----------+-----------+
```

## 3.20 列统计信息

### COLUMN_STATISTICS 表

`COLUMN_STATISTICS` 表提供列值直方图统计信息，以 JSON 格式存储。这是优化器选择执行计划的重要依据，通过 `ANALYZE TABLE` 命令更新。

```sql
SELECT SCHEMA_NAME, TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMN_STATISTICS
WHERE SCHEMA_NAME = 'mysql'
LIMIT 5;
```

## 3.21 CHECK 约束

### CHECK_CONSTRAINTS 表

`CHECK_CONSTRAINTS` 表记录了表和列级 CHECK 约束的定义信息。`CHECK_CLAUSE` 列包含约束条件的表达式文本。

## 3.22 空间数据

### ST_SPATIAL_REFERENCE_SYSTEMS 表

该表列出了所有可用的空间参考系统（SRS），基于 EPSG 数据集构建。`SRS_ID = 0` 表示无单位的笛卡尔平面坐标系，是特殊的合法空间参考系统。

```sql
SELECT SRS_NAME, SRS_ID, ORGANIZATION, DESCRIPTION
FROM information_schema.ST_SPATIAL_REFERENCE_SYSTEMS
WHERE SRS_ID IN (0, 4326, 3857)
ORDER BY SRS_ID;
```

```output
+----------+-------+--------------+-----------------------------+
| SRS_NAME | SRS_ID | ORGANIZATION | DESCRIPTION                  |
+----------+-------+--------------+-----------------------------+
| SRS 0    |     0 |              | Cartesian coordinate system |
| WGS 84   |  4326 | EPSG         |                             |
| WGS 84 / |  3857 | EPSG         |                             |
+----------+-------+--------------+-----------------------------+
```

### ST_GEOMETRY_COLUMNS 表（已弃用）

> ⚠️ 注意：该表已在 MySQL 8.4 中弃用，建议直接使用 `COLUMNS` 表。

该表记录了存储空间数据（`GEOMETRY`、`POINT`、`LINESTRING` 等类型）的列信息，基于 SQL/MM 标准实现。

## 3.23 用户属性

### USER_ATTRIBUTES 表

`USER_ATTRIBUTES` 表提供用户账户的注释和属性信息，存储在 `mysql.user` 系统表的 `ATTRIBUTE` 和 `UNIQUE_ATTRIBUTES` 列中。

## 3.24 NDB Cluster 专用表

### ndb_transid_mysql_connection_map 表

此表是 NDB Cluster 专用的 `INFORMATION_SCHEMA` 插件，提供 NDB 事务、事务协调器与 MySQL 服务器之间的映射关系。仅在使用 NDB Cluster 时可用。

# 四、InnoDB 专用表详解

InnoDB `INFORMATION_SCHEMA` 表（共 29 个）提供了 InnoDB 存储引擎内部的元数据和运行时状态信息。这些表对于理解 InnoDB 内部结构、诊断性能和锁问题至关重要。

> ⚠️ 注意：查询所有 InnoDB 相关的 `INFORMATION_SCHEMA` 表需要 `PROCESS` 权限。

## 4.1 InnoDB 表结构元数据

### INNODB_TABLES 表

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

### INNODB_COLUMNS 表

`INNODB_COLUMNS` 表记录了 InnoDB 表列的内部元数据。

关键列说明：

- `TABLE_ID`：所属表的 ID
- `NAME`：列名
- `POS`：列在表中的位置（从 0 开始）
- `MTYPE`：主类型（1=VARCHAR, 6=INT, 14=GEOMETRY 等）
- `PRTYPE`：精确类型（含 MySQL 数据类型、字符集代码和可空性）
- `LEN`：列长度（字节）
- `HAS_DEFAULT` / `DEFAULT_VALUE`：是否即时添加列及其默认值

### INNODB_INDEXES 表

`INNODB_INDEXES` 表记录了 InnoDB 索引的元数据。

关键列说明：

- `INDEX_ID`：索引 ID
- `NAME`：索引名（主键索引为 `GEN_CLUST_INDEX`）
- `TABLE_ID`：所属表的 ID
- `TYPE`：索引类型（0=二级索引, 1=唯一索引, 2= 2=主键索引等）
- `N_FIELDS`：索引中列的数量
- `PAGE_NO`：B-tree 页编号
- `SPACE`：表空间 ID

### INNODB_FIELDS 表

`INNODB_FIELDS` 表记录了 InnoDB 索引键列的元数据，与 `INNODB_INDEXES` 表配合使用可以完整还原索引定义。

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

## 4.2 InnoDB 外键元数据

### INNODB_FOREIGN 表

`INNODB_FOREIGN` 表记录了 InnoDB 外键的元数据。

关键列说明：

- `ID`：外键名（含数据库名前缀）
- `FOR_NAME`：子表名
- `REF_NAME`：父表名

### INNODB_FOREIGN_COLS 表

`INNODB_FOREIGN_COLS` 表记录了外键列的状态信息，补充了 `INNODB_FOREIGN` 表。

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

### INNODB_TABLESPACES 表

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

### INNODB_TABLESPACES_BRIEF 表

`INNODB_TABLESPACES_BRIEF` 表提供了表空间元数据的精简版本，加载速度更快。

### INNODB_DATAFILES 表

`INNODB_DATAFILES` 表记录了表空间数据文件的路径信息。

```sql
SELECT SPACE, PATH
FROM information_schema.INNODB_DATAFILES
WHERE SPACE IN (1, 2, 3)
ORDER BY SPACE;
```

## 4.4 InnoDB 表统计信息

### INNODB_TABLESTATS 表

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

## 4.5 InnoDB 事务与锁

### INNODB_TRX 表

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

## 4.6 InnoDB 虚拟生成列

### INNODB_VIRTUAL 表

`INNODB_VIRTUAL` 表记录了 InnoDB 虚拟生成列的元数据。虚拟生成列的值在读取时实时计算，不存储在磁盘上。

关键列说明：

- `TABLE_ID`：所属表的 ID
- `POS`：列位置（含编码信息）
- `BASE_POS`：基础列位置

## 4.7 InnoDB 缓冲池信息

MySQL 8.4 提供了一组 InnoDB 缓冲池相关的 `INFORMATION_SCHEMA` 表，用于监控 InnoDB 缓冲池的内部状态：

### INNODB_BUFFER_PAGE 表

记录缓冲池中每个页的详细信息，包括页类型（`INDEX`、`UNDO_LOG`、`INODE`、`SYSTEM`、`TRX_SYSTEM` 等）、表空间 ID、页编号和 LRU 位置。

### INNODB_BUFFER_PAGE_LRU 表

以 LRU（最近最少使用）顺序记录缓冲池中的页信息，可用于分析缓冲池的冷热数据分布。

### INNODB_BUFFER_POOL_STATS 表

提供缓冲池的整体统计信息，包括缓冲池大小、已使用页数、空闲页数、命中率等。

```sql
SELECT POOL_ID, DATABASE_PAGES, MODIFIED_DATABASE_PAGES,
       NUMBER_PAGES_READ, NUMBER_PAGES_WRITTEN,
       HIT_RATE
FROM information_schema.INNODB_BUFFER_POOL_STATS;
```

### INNODB_CACHED_INDEXES 表

记录每个索引在缓冲池中缓存的索引页数量。

```sql
SELECT SPACE, INDEX_ID, N_CACHED_PAGES
FROM information_schema.INNODB_CACHED_INDEXES
LIMIT 10;
```

## 4.8 InnoDB 压缩信息（已弃用）

以下 InnoDB 压缩相关的 `INFORMATION_SCHEMA` 表已在 MySQL 8.4 中弃用：

- `INNODB_CMP` / `INNODB_CMP_RESET`：压缩操作状态
- `INNODB_CMP_PER_INDEX` / `INNODB_CMP_PER_INDEX_RESET`：按表/索引统计的压缩信息
- `INNODB_CMPMEM` / `INNODB_CMPMEM_RESET`：缓冲池中压缩页的状态

> ⚠️ 注意：`INNODB_CMP_PER_INDEX` 和 `INNODB_CMP_PER_INDEX_RESET` 需要设置 `innodb_cmp_per_index_enabled = ON` 才会收集统计信息，否则始终为空。

## 4.9 InnoDB 全文索引信息

### INNODB_FT_INDEX_CACHE 表

记录最近插入行的全文索引令牌信息，用于增量构建倒排索引。

### INNODB_FT_DELETED 表

记录从 InnoDB 全文索引中删除的行，物理删除延迟执行以避免性能冲击。

### INNODB_FT_BEING_DELETED 表

`INNODB_FT_DELETED` 表的快照，用于在 `OPTIMIZE TABLE` 时提供一致的视图。

### INNODB_FT_CONFIG 表

记录全文索引的元数据，包括爬取状态、文档计数等。

### INNODB_FT_DEFAULT_STOPWORD 表

InnoDB 全文索引使用的默认停用词列表。

## 4.10 InnoDB 性能指标

### INNODB_METRICS 表

`INNODB_METRICS` 表提供了 InnoDB 内部的性能指标集合，涵盖计数器、 Gauge 和状态信息。可以通过 `STATUS` 列筛选不同类型的指标。

```sql
SELECT NAME, SUBSYSTEM, TYPE, COUNT, MAX_COUNT, AVG_COUNT
FROM information_schema.INNODB_METRICS
WHERE STATUS = 'enabled'
ORDER BY SUBSYSTEM, NAME
LIMIT 10;
```

## 4.11 InnoDB 临时表

### INNODB_TEMP_TABLE_INFO 表

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

### INNODB_SESSION_TEMP_TABLESPACES 表

记录会话级临时表空间的元数据。

# 五、SHOW 语句扩展

MySQL 在实现 `INFORMATION_SCHEMA` 的同时，也对 `SHOW` 语句进行了扩展：

## 8.1 查询 INFORMATION_SCHEMA 自身

`SHOW` 语句可以像查询普通数据库一样查询 `INFORMATION_SCHEMA`：

```sql
SHOW TABLES FROM information_schema
WHERE Tables_in_information_schema LIKE 'INNODB%';
```

## 8.2 WHERE 子句支持

多个 `SHOW` 语句支持 `WHERE` 子句，提供比 `LIKE` 更灵活的过滤能力：

```sql
SHOW CHARACTER SET WHERE Maxlen > 1;
```

该查询返回所有多字节字符集，与以下等价：

```sql
SELECT * FROM information_schema.CHARACTER_SETS
WHERE MAXLEN > 1;
```

支持 `WHERE` 子句的 `SHOW` 语句包括：`SHOW CHARACTER SET`、`SHOW COLLATION`、`SHOW COLUMNS`、`SHOW DATABASES`、`SHOW FUNCTION STATUS`、`SHOW INDEX`、`SHOW OPEN TABLES`、`SHOW PROCEDURE STATUS`、`SHOW STATUS`、`SHOW TABLE STATUS`、`SHOW TABLES`、`SHOW TRIGGERS`、`SHOW VARIABLES`。

# 六、总结

`INFORMATION_SCHEMA` 是 MySQL 提供的一套完整的元数据访问接口，覆盖了从数据库、表、列、索引、约束等结构信息，到权限、角色、事件、触发器等对象信息，再到 InnoDB 内部状态、事务、锁等运行时信息。其设计遵循 SQL 标准，同时通过 MySQL 扩展列（如 `TABLES.ENGINE`）满足自身需求。

使用 `INFORMATION_SCHEMA` 的核心优势在于元数据查询的标准化和可编程性。通过 `SELECT` 语句，可以灵活地组合、过滤和转换元数据，构建数据库管理工具和自动化脚本。相比之下，`SHOW` 语句虽然更简洁，但功能受限。

在 MySQL 8.4 中，部分早期 `INFORMATION_SCHEMA` 表（如 `PROCESSLIST`、`PROFILING` 等）已标记为弃用，官方建议迁移到 Performance Schema 的对应实现。InnoDB 相关的 `INFORMATION_SCHEMA` 表是诊断 InnoDB 内部行为的重要工具，尤其在分析锁等待、长事务等问题时不可或缺。
