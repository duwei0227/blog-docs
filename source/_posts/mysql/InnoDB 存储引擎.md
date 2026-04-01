---
title: InnoDB 存储引擎
date: 2026-04-01 18:49:00
tags: [InnoDB, MVCC, ACID, 锁, 事务, 缓冲池, B+Tree]
categories: MySQL
---

## 一、InnoDB 简介

MySQL 8.4 中，`InnoDB` 是默认的存储引擎。创建表时不指定 `ENGINE` 子句，默认得到的就是 `InnoDB` 表。

### 1.1 核心优势

InnoDB 的核心优势在于以下特性：

- **ACID 事务支持**：提供提交、回滚和崩溃恢复能力，保护用户数据
- **行级锁与一致性读取**：支持多用户并发，性能更高
- **聚集索引**：按主键组织数据，最小化主键查询的 I/O
- **外键约束**：维护引用完整性，支持级联删除和更新
- **MVCC 多版本并发控制**：读不阻塞写，写不阻塞读

表 17.1 展示了 InnoDB 的功能特性。

| 特性 | 支持 |
|------|------|
| B-tree 索引 | 是 |
| 备份/时间点恢复 | 是 |
| 聚集索引 | 是 |
| 压缩数据 | 是 |
| 数据缓存 | 是 |
| 加密数据 | 是 |
| 外键约束 | 是 |
| 全文索引 | 是 |
| 哈希索引 | 否（InnoDB 使用 Adaptive Hash Index） |
| 锁粒度 | 行级 |
| MVCC | 是 |
| 事务 | 是 |
| 存储限制 | 64TB |

### 1.2 使用建议

- **为每张表指定主键**：使用最频繁的查询列，或使用自增列。操作主键列的查询、排序、分组和关联性能最优
- **使用外键关联表**：外键确保引用列被索引，提升关联性能，同时防止插入子表中不存在于父表的数据
- **关闭自动提交**：`autocommit` 每秒提交数百次会限制性能（受存储设备写入速度约束）
- **合理分组事务**：将相关 DML 操作用 `START TRANSACTION` 和 `COMMIT` 包裹，不要长时间运行大量 DML 而不提交
- **避免 `LOCK TABLES`**：InnoDB 能处理多个会话同时读写同一张表。使用 `SELECT ... FOR UPDATE` 替代锁表
- **启用 `innodb_file_per_table`**：将每张表的数据和索引放在独立表空间中，支持单独备份和快速截断

## 二、ACID 事务模型

ACID 模型是一组强调可靠性数据库设计的原则。InnoDB 严格遵循 ACID 模型。

### 2.1 原子性（Atomicity）

主要涉及 `InnoDB` 事务机制，相关特性包括：

- `autocommit` 设置
- `COMMIT` 语句
- `ROLLBACK` 语句

### 2.2 一致性（Consistency）

主要涉及 InnoDB 内部崩溃保护机制：

- **Doublewrite Buffer**：将数据页先写入双写缓冲区，再写入数据文件，防止部分写导致的数据损坏
- **崩溃恢复**：重启后自动完成崩溃前已提交事务的变更，撤销未提交事务的变更

### 2.3 隔离性（Isolation）

主要涉及事务隔离级别：

- `autocommit` 设置
- 事务隔离级别和 `SET TRANSACTION` 语句

### 2.4 持久性（Durability）

涉及 MySQL 软件特性与硬件配置的配合：

- Doublewrite Buffer
- `innodb_flush_log_at_trx_commit` 变量
- `sync_binlog` 变量
- `innodb_file_per_table` 变量
- 存储设备的写缓存（电池保护）
- UPS 不间断电源保护
- 备份策略

## 三、InnoDB 多版本并发控制（MVCC）

InnoDB 是一个多版本存储引擎。它保存已修改行的旧版本信息，以支持事务特性和并发控制。这些信息存储在 Undo 表空间的回滚段中。

### 3.1 隐藏列

InnoDB 在每个数据行内部添加三个字段：

| 字段 | 长度 | 作用 |
|------|------|------|
| `DB_TRX_ID` | 6 字节 | 记录最近一次插入或更新该行的事务 ID。删除操作在内部被视为更新（标记删除位）|
| `DB_ROLL_PTR` | 7 字节 | 回滚指针，指向回滚段中的 Undo Log 记录。如果行被更新，该记录包含重建更新前行内容所需信息 |
| `DB_ROW_ID` | 6 字节 | 单调递增的行 ID。如果 InnoDB 自动生成聚集索引，则索引包含行 ID 值；否则该字段不出现在任何索引中 |

### 3.2 Undo Log

回滚段中的 Undo Log 分为两类：

- **Insert Undo Log**：仅用于事务回滚，事务提交后即可丢弃
- **Update Undo Log**：还用于一致性读取，只在没有任何活跃事务可能需要它来构建早期版本时才能被清除

定期提交事务（包括仅做读取的事务）非常重要。否则 InnoDB 无法丢弃 Update Undo Log，回滚段可能无限增长，最终填满 Undo 表空间。

### 3.3 读视图与快照读

MVCC 的核心机制在于**一致性非锁定读**（Consistent Nonlocking Read）：读取操作创建快照，基于行版本链和 ReadView 判断可见性。

### 3.4 MVCC 与辅助索引

InnoDB 对辅助索引的处理与聚集索引不同：

- **聚集索引**：行被原地更新，隐藏系统列指向 Undo Log，可重建早期版本
- **辅助索引**：不包含隐藏系统列，也不原地更新

当辅助索引列被更新时，旧辅助索引记录被标记为删除，新记录被插入，标记删除的记录最终被清除（Purge）。

读取辅助索引时，InnoDB 在聚集索引中查找记录，根据 `DB_TRX_ID` 判断版本。如果辅助索引记录被标记删除或被更新过，`覆盖索引`优化失效，MySQL 需要回聚集索引获取正确版本。

## 四、InnoDB 架构

InnoDB 由内存结构和磁盘结构组成：

- **内存结构**：缓冲池、Change Buffer、自适应哈希索引、日志缓冲区
- **磁盘结构**：表空间、索引、Redo Log、Undo Log、Doublewrite Buffer

## 五、InnoDB 内存结构

### 5.1 缓冲池（Buffer Pool）

缓冲池是 InnoDB 在内存中缓存表和索引数据的主要区域。常用数据直接从内存处理，减少磁盘 I/O。在专用数据库服务器上，通常将最多 80% 的物理内存分配给缓冲池。

**缓冲池的页管理**：缓冲池被组织为页（Page），采用 LRU（Least Recently Used）链表管理。链表分为两部分：

- **年轻区（Young）**：最近访问的页
- **老区（Old）**：长时间未访问的页

新页首先插入老区头（`innodb_old_blocks_pct` 控制老区比例，默认 37%）。在老区停留足够时间或被访问多次后，页才会移入年轻区。这防止突发扫描将热点数据挤出缓冲池。

**预读机制**：InnoDB 提供两种预读策略：

- **线性预读**：顺序访问某区（extent）的页超过阈值（`innodb_read_ahead_threshold`，默认 56），预测下一区也被访问，提前将下一区读入缓冲池
- **随机预读**：某页在缓冲池中时，其同区（extent）内其他页的访问频率达到阈值（`innodb_random_read_ahead`，默认关闭），则将同区所有页读入缓冲池

**配置参数**：

```sql
-- 查看缓冲池大小
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
-- 查看缓冲池实例数
SHOW VARIABLES LIKE 'innodb_buffer_pool_instances';
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `innodb_buffer_pool_size` | 缓冲池总大小 | 128MB |
| `innodb_buffer_pool_instances` | 缓冲池实例数（每个不超过 1GB）| 1（自动调整）|
| `innodb_old_blocks_pct` | 老区占比 | 37 |
| `innodb_old_blocks_time` | 页移入年轻区前必须在老区停留的时间（毫秒）| 1000 |

### 5.2 Change Buffer

Change Buffer 是缓冲池中的一块特殊区域，用来缓存不在缓冲池中的次级索引页上的修改操作（INSERT、UPDATE、DELETE），待相关页被加载到缓冲池后再合并。

Change Buffer 节省了大量磁盘 I/O：次级索引的随机访问被合并为顺序写入。

```sql
-- 查看 Change Buffer 大小
SHOW VARIABLES LIKE 'innodb_change_buffer%';
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `innodb_change_buffer_max_size` | Change Buffer 最大占缓冲池的比例（%）| 25 |
| `innodb_change_buffering` | 哪些操作被缓存 | none |

如果索引包含唯一列（需唯一性检查），则该索引上的操作不能使用 Change Buffer，因为写入时必须读取磁盘验证唯一性。

### 5.3 自适应哈希索引（Adaptive Hash Index）

自适应哈希索引（AHI）是 InnoDB 根据查询频率自动在内存中构建的哈希索引。对于等值查询（`WHERE col = value`），命中 AHI 后可直接从内存获取数据，无需遍历 B+Tree。

AHI 基于已访问的 B+Tree 页构建，使用前缀哈希：索引键的前缀被哈希，对应的指针指向 B+Tree 页中的记录。

```sql
-- 查看自适应哈希索引统计
SHOW ENGINE INNODB STATUS\G
```

在 `BUFFER POOL AND MEMORY` 部分可看到 `Hash table size`、`Adaptive hash` 相关指标。

### 5.4 日志缓冲区（Log Buffer）

日志缓冲区是存储即将写入磁盘 Redo Log 内容的内存区域。

```sql
SHOW VARIABLES LIKE 'innodb_log_buffer_size';
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `innodb_log_buffer_size` | 日志缓冲区大小 | 16MB |

日志从缓冲区写入磁盘的频率由 `innodb_flush_log_at_trx_commit` 控制：

| 值 | 行为 |
|----|------|
| 1（默认值）| 每次事务提交时，将日志写入磁盘并刷新。保证最强的持久性 |
| 0 | 每秒将日志写入并刷新一次，不保证事务提交时日志已落盘 |
| 2 | 每次事务提交时将日志写入操作系统缓存，由操作系统负责每秒刷新 |

## 六、InnoDB 磁盘结构

### 6.1 表（Tables）

InnoDB 表的数据存储在表空间中，既可以使用每表独立表空间文件，也可以存储在系统表空间中。

```sql
-- 查看存储引擎
SHOW CREATE TABLE t\G

-- 查看表使用的表空间
SELECT NAME, SPACE, SPACE_TYPE FROM INFORMATION_SCHEMA.INNODB_TABLES WHERE NAME LIKE 'test/%';
```

### 6.2 索引（Indexes）

#### 6.2.1 聚集索引与辅助索引

InnoDB 表的数据按主键顺序存储在 B+Tree 结构中，每个表都有一个聚集索引（Clustered Index）。

- **聚集索引**：叶节点存储完整的行数据。表数据按主键排序，主键查询只需一次 I/O（沿 B+Tree 从根到叶）
- **辅助索引**：叶节点存储索引列值和对应的主键值。查询时先在辅助索引中找到主键值，再通过主键值到聚集索引中查找完整行（回表）

设计建议：为每张表选择最频繁查询的列或列组合作为主键，以优化主键查找、排序、分组和关联操作。

```sql
-- 查看表的索引
SHOW INDEX FROM employees\G

-- 查看索引使用情况
SELECT IX.INDEX_ID, IX.NAME AS INDEX_NAME, T.NAME AS TABLE_NAME
FROM INFORMATION_SCHEMA.INNODB_INDEXES IX
JOIN INFORMATION_SCHEMA.INNODB_TABLES T ON IX.TABLE_ID = T.TABLE_ID
WHERE T.NAME LIKE '%employees%';
```

### 6.3 表空间（Tablespaces）

InnoDB 支持多种类型的表空间：

#### 6.3.1 系统表空间（System Tablespace）

系统表空间存储了 InnoDB 数据字典（表和索引定义）、双写缓冲区、修改缓冲区、Undo Log（未使用独立 Undo 表空间时），以及表的行数据和索引。

默认情况下，系统表空间文件名为 `ibdata1`。`innodb_data_file_path` 控制数据文件的配置。

```sql
SHOW VARIABLES LIKE 'innodb_data_file_path';
```

| 文件 | 初始大小 | 用途 |
|------|---------|------|
| `ibdata1` | 12MB（自动扩展）| 系统表空间 |

#### 6.3.2 每表独立表空间（File-Per-Table Tablespace）

启用 `innodb_file_per_table`（默认）后，每张表的数据和索引存储在独立的 `.ibd` 文件中，表 ID 号作为文件名的编号。

```sql
SHOW VARIABLES LIKE 'innodb_file_per_table';
```

独立表空间的优势：

- 单独备份和恢复
- `TRUNCATE TABLE` 释放的空间直接归还操作系统
- 删除表时直接删除文件，回收空间更高效

#### 6.3.3 Undo 表空间（Undo Tablespaces）

Undo 表空间包含 Undo Log，记录事务修改前的值。从 MySQL 8.0.14 起支持创建额外 Undo 表空间实现 Undo 表空间在线调整。

```sql
SHOW VARIABLES LIKE 'innodb_undo_tablespaces';
```

#### 6.3.4 临时表空间（Temporary Tablespaces）

临时表空间存储用户创建的临时表和内部临时表的 InnoDB 内存映射。`innodb_temp_data_file_path` 定义临时数据文件的路径和大小。

### 6.4 Doublewrite Buffer

Doublewrite Buffer 是系统表空间中一块 2MB 的缓冲区。InnoDB 将脏页先写入 Doublewrite Buffer（顺序写入），再将页写入数据文件中的正确位置。

崩溃恢复时，如果数据页在写入过程中不完整（仅写入了部分），InnoDB 从 Doublewrite Buffer 中恢复该页，保证数据页的一致性。

此机制在大多数文件系统上防止了部分写（torn write）问题。

### 6.5 Redo Log

Redo Log 记录了修改数据的物理操作，是 InnoDB 崩溃恢复的核心。每个 Redo Log 文件有固定大小，文件循环使用（从日志序列号 LSN 开始）。

```sql
SHOW VARIABLES LIKE 'innodb_redo_log_capacity';
```

从 MySQL 8.0.30 起，Redo Log 容量由 `innodb_redo_log_capacity` 控制（默认 100MB）。之前版本使用 `innodb_log_file_size` 和 `innodb_log_files_in_group`。

Redo Log 的写入流程：

1. 事务修改行时，变更写入 Redo Log Buffer
2. 事务提交时，根据 `innodb_flush_log_at_trx_commit` 将日志从 Buffer 刷新到 Redo Log 文件
3. Checkpoint 机制将已持久化的脏页标记为已写入，确保 Redo Log 可以被覆盖

崩溃恢复流程：

1. 确定最近的 Checkpoint，记录其 LSN
2. 从 Checkpoint LSN 开始，应用 Redo Log 中的记录，重做所有已提交事务的修改
3. 回滚未提交事务的修改（通过 Undo Log）

### 6.6 Undo Log

Undo Log 存储在 Undo 表空间中，分为 Insert Undo Log 和 Update Undo Log：

- **Insert Undo Log**：事务提交后立即可丢弃
- **Update Undo Log**：用于事务回滚和一致性读取，需等待没有活跃事务需要时才可清除

定期提交事务是保持 Undo 表空间不过分增长的关键。

## 七、InnoDB 锁与事务模型

### 7.1 锁类型

#### 7.1.1 共享锁与排他锁

InnoDB 实现标准的行级锁：

- **共享锁（S）**：允许事务读取一行。多个事务可以同时持有同一行的共享锁
- **排他锁（X）**：允许事务更新或删除一行。一次只能有一个事务持有某行的排他锁

锁的兼容性矩阵：

|      | S    | X    |
|------|------|------|
| S    | 兼容 | 不兼容 |
| X    | 不兼容 | 不兼容 |

#### 7.1.2 意向锁

InnoDB 使用**意向锁**协调表锁与行锁的兼容性判断：

- **意向共享锁（IS）**：事务即将在表中某行加共享锁
- **意向排他锁（IX）**：事务即将在表中某行加排他锁

意向锁在事务获取行锁之前自动获取，且意向锁之间互相兼容。

```sql
-- 意向锁兼容矩阵
-- IS 与 IS/IX/S/X 的关系：
-- IS 与 S 兼容，IS 与 IX 兼容
-- IX 与 S 不兼容，IX 与 X 不兼容
```

#### 7.1.3 记录锁（Record Lock）

记录锁锁定索引记录，而非物理行。如果表没有定义索引，InnoDB 创建隐式聚集索引作为锁定依据。

```sql
-- 对 id=5 的行加排他记录锁
SELECT * FROM t WHERE id = 5 FOR UPDATE;
```

#### 7.1.4 间隙锁（Gap Lock）

间隙锁锁定索引记录之间的间隙，防止其他事务在该间隙中插入新记录。

```sql
-- 锁定 id > 5 且 id < 10 的间隙
SELECT * FROM t WHERE id > 5 AND id < 10 FOR UPDATE;
```

间隙锁在 `REPEATABLE READ` 隔离级别下默认启用，作用是防止幻读（Phantom Rows）。

#### 7.1.5 Next-Key Lock

Next-Key Lock 是记录锁与间隙锁的组合，锁定索引记录本身及其前面的间隙。

### 7.2 事务隔离级别

InnoDB 支持四种标准隔离级别：

```sql
SET TRANSACTION ISOLATION LEVEL {
    READ UNCOMMITTED
    | READ COMMITTED
    | REPEATABLE READ  -- InnoDB 默认
    | SERIALIZABLE
};
```

| 隔离级别 | 脏读 | 不可重复读 | 幻读 |
|---------|------|-----------|------|
| READ UNCOMMITTED | 可能 | 可能 | 可能 |
| READ COMMITTED | 不可能 | 可能 | 可能 |
| REPEATABLE READ | 不可能 | 不可能 | 可能（InnoDB 通过 Next-Key Lock 防止）|
| SERIALIZABLE | 不可能 | 不可能 | 不可能 |

#### 7.2.1 读已提交（READ COMMITTED）

每次读取都生成新的 ReadView，事务只能看到其他已提交事务的修改。解决了脏读问题，但可能出现不可重复读（同一事务中两次读取结果不同）。

#### 7.2.2 可重复读（REPEATABLE READ）

InnoDB 默认隔离级别。事务启动时生成 ReadView，事务内所有读取都使用同一快照。同一事务中多次读取同一行结果相同，除非自己修改。

通过 MVCC + Next-Key Lock 同时防止脏读、不可重复读和幻读。

#### 7.2.3 一致性非锁定读（Consistent Nonlocking Read）

在 READ COMMITTED 和 REPEATABLE READ 级别下，普通 `SELECT` 语句（非锁定读取）使用一致性快照读取，不加锁，不阻塞写操作。

```sql
-- 可重复读隔离级别下的普通 SELECT（不加锁）
SELECT * FROM t WHERE id > 100;
```

### 7.3 不同 SQL 语句的加锁行为

| 语句 | 锁类型 |
|------|--------|
| `SELECT ... FROM ...` | 无锁（一致性非锁定读）|
| `SELECT ... FROM ... FOR UPDATE` | 排他 Next-Key Lock |
| `SELECT ... FROM ... LOCK IN SHARE MODE` | 共享 Next-Key Lock |
| `INSERT INTO ...` | 排他记录锁 |
| `UPDATE ... WHERE ...` | 排他 Next-Key Lock |
| `DELETE ... WHERE ...` | 排他 Next-Key Lock |

### 7.4 幻读（Phantom Rows）

幻读指同一事务中，两次执行相同范围查询得到不同结果集（因为其他事务插入了新行）。

InnoDB 在 `REPEATABLE READ` 下通过 **Next-Key Lock** 防止幻读：锁定查询范围的所有间隙，不允许其他事务插入新记录。

### 7.5 死锁（Deadlocks）

死锁是两个或多个事务互相持有对方需要的锁，形成循环等待。

```sql
-- 死锁示例
-- 事务 A：先锁 id=1，再等 id=2
-- 事务 B：先锁 id=2，再等 id=1
SELECT * FROM t WHERE id=1 FOR UPDATE;  -- A 锁住 1
SELECT * FROM t WHERE id=2 FOR UPDATE;  -- A 等 2

-- 事务 B 同时执行
SELECT * FROM t WHERE id=2 FOR UPDATE;  -- B 锁住 2
SELECT * FROM t WHERE id=1 FOR UPDATE;  -- B 等 1 → 死锁
```

**InnoDB 死锁检测**：InnoDB 自动检测死锁（等待图中有循环），选择一个事务作为受害者（victim）回滚，通常是 undo 量最小的事务。

```sql
-- 查看最近一次死锁信息
SHOW ENGINE INNODB STATUS\G
```

**最小化死锁**：

- 按固定顺序访问表和行（避免循环等待）
- 缩短事务时长，快速提交
- 尽量使用低隔离级别
- 显式锁定所需行，减少锁定范围

### 7.6 事务调度

InnoDB 通过自旋锁（Spin Lock）协调内部并发操作。高并发下，锁竞争严重时自旋开销可能成为瓶颈。`innodb_spin_wait_delay` 控制自旋等待的最大延迟（微秒）。

## 八、InnoDB 配置实践

### 8.1 关键配置参数

| 参数 | 说明 | 建议值 |
|------|------|--------|
| `innodb_buffer_pool_size` | 缓冲池大小 | 建议为物理内存的 50%~80% |
| `innodb_log_file_size` | Redo Log 单个文件大小 | 总 Redo Log 的 1/4 |
| `innodb_flush_log_at_trx_commit` | 日志刷新策略 | 1（最高持久性）|
| `innodb_file_per_table` | 每表独立表空间 | ON（默认）|
| `innodb_flush_method` | 数据文件刷新方式 | O_DIRECT（Linux）|
| `innodb_io_capacity` | InnoDB 后台 I/O 操作上限 | SSD: 2000~10000, HDD: 200~800 |
| `max_connections` | 最大连接数 | 根据实际并发需求设置 |

### 8.2 只读操作配置

将 InnoDB 配置为只读模式可减少开销：

```sql
SET GLOBAL transaction_read_only = ON;
```

或者在启动时使用 `--innodb-read-only=1`。

### 8.3 内存配置

```sql
-- 建议将 50%~80% 的物理内存分配给 InnoDB 缓冲池
-- 假设物理内存为 64GB

SET GLOBAL innodb_buffer_pool_size = 50 * 1024 * 1024 * 1024;  -- 50GB
```

## 九、InnoDB 崩溃恢复

### 9.1 崩溃恢复流程

1. **确定 Checkpoint**：找到最近的 Checkpoint 位置（LSN）
2. **应用 Redo Log**：从 Checkpoint LSN 开始重做所有已提交事务的修改
3. **回滚未提交事务**：通过 Undo Log 撤销未提交事务的修改

### 9.2 强制恢复

在严重崩溃导致 InnoDB 无法正常恢复时，可在 `my.cnf` 中设置 `innodb_force_recovery` 启动服务：

| 值 | 作用 |
|----|------|
| 1 | 跳过损坏页的恢复，继续正常启动 |
| 2 | 跳过崩溃恢复的回滚阶段（危险）|
| 3 | 跳过所有崩溃恢复（最危险，数据可能不一致）|
| 4~6 | 更激进的恢复选项，仅用于最后手段 |

> ⚠️ 非必要时不要使用强制恢复。设置后应尽快导出数据并重建数据库。

```ini
[mysqld]
innodb_force_recovery = 1
```

## 十、InnoDB INFORMATION_SCHEMA 表

InnoDB 提供多个 INFORMATION_SCHEMA 表用于监控和诊断：

| 表 | 用途 |
|----|------|
| `INNODB_BUFFER_PAGE` | 缓冲池中每个页的元数据 |
| `INNODB_BUFFER_PAGE_LRU` | 缓冲池 LRU 链表中页的信息 |
| `INNODB_TRX` | 当前运行的所有事务信息 |
| `INNODB_LOCKS` | 当前持有的锁信息 |
| `INNODB_LOCK_WAITS` | 锁等待关系 |
| `INNODB_TABLES` | 表的元数据 |
| `INNODB_INDEXES` | 索引的元数据 |

```sql
-- 查看当前运行的事务
SELECT * FROM INFORMATION_SCHEMA.INNODB_TRX\G

-- 查看当前锁等待
SELECT * FROM INFORMATION_SCHEMA.INNODB_LOCK_WAITS\G

-- 查看缓冲池页统计
SELECT TABLE_NAME, INDEX_NAME, NUMBER_RECORDS, DATA_SIZE
FROM INFORMATION_SCHEMA.INNODB_BUFFER_PAGE
WHERE TABLE_NAME IS NOT NULL
ORDER BY NUMBER_RECORDS DESC LIMIT 10;
```
