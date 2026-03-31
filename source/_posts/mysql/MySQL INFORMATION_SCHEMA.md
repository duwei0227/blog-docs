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
### 3.1 数据库与模式 SCHEMATA_EXTENSIONS 表

### 3.2 表结构信息 TABLES 表
### 3.2 表结构信息 TABLE_CONSTRAINTS 表

### 3.3 列信息 COLUMNS 表

### 3.4 索引与统计 STATISTICS 表

### 3.5 约束键使用 KEY_COLUMN_USAGE 表
### 3.5 约束键使用 REFERENTIAL_CONSTRAINTS 表

### 3.6 分区信息 PARTITIONS 表

### 3.7 存储过程与函数 ROUTINES 表

### 3.8 事件调度器 EVENTS 表

### 3.9 视图 VIEWS 表

### 3.10 字符集与排序规则 CHARACTER_SETS 表
### 3.10 字符集与排序规则 COLLATIONS 表
### 3.10 字符集与排序规则 COLLATION_CHARACTER_SET_APPLICABILITY 表

### 3.11 插件与存储引擎 PLUGINS 表
### 3.11 插件与存储引擎 ENGINES 表
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


### 3.14 资源组 RESOURCE_GROUPS 表

### 3.15 文件与表空间 FILES 表

### 3.16 优化器跟踪 OPTIMIZER_TRACE 表

### 3.17 语句分析（已弃用） PROFILING 表

### 3.18 连接与进程（已弃用） PROCESSLIST 表

### 3.19 关键字 KEYWORDS 表

### 3.20 列统计信息 COLUMN_STATISTICS 表

### 3.21 CHECK 约束 CHECK_CONSTRAINTS 表

### 3.22 空间数据 ST_SPATIAL_REFERENCE_SYSTEMS 表
### 3.22 空间数据 ST_GEOMETRY_COLUMNS 表

### 3.23 用户属性 USER_ATTRIBUTES 表

### 3.24 NDB Cluster 专用表 ndb_transid_mysql_connection_map 表
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
