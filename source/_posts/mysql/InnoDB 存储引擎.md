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

**概念**：一个事务中的所有操作要么全部成功，要么全部失败，不存在中间状态。事务是最小执行单位，不可再分。

**要解决什么问题**：在没有原子性保护的情况下，事务执行中途失败（如断电、网络中断、语法错误）时，已执行的部分操作无法撤销，导致数据处于不一致状态。例如转账操作中，扣款成功但转账失败，账户金额凭空减少。

以下示例演示原子性缺失导致的数据不一致问题：

```sql
USE test;
-- 初始化：Alice 和 Bob 余额各 1000 元
UPDATE account SET balance = 1000 WHERE id IN (1, 2);
SELECT 'Init' AS st, id, name, balance FROM account;
```

运行结果：

```
st        id   name   balance
Init       1   Alice  1000.00
Init       2   Bob    1000.00
```

执行一笔从 Alice 到 Bob 的转账：

```sql
-- 开启事务：Alice 账户减 500 元
START TRANSACTION;
UPDATE account SET balance = balance - 500 WHERE id = 1;  -- 扣款成功，Alice = 500
UPDATE account SET balance = balance + 500 WHERE id = 999;  -- Bob 不存在，语句失败
COMMIT;  -- COMMIT 仍会执行（错误后的语句不会被跳过）
SELECT 'After COMMIT' AS st, id, name, balance FROM account;
```

运行结果：

```
st            id   name   balance
After COMMIT   1   Alice   500.00
After COMMIT   2   Bob    1000.00
```

Alice 被扣了 500，但 Bob 没收到转账，500 元凭空消失——这就是**原子性缺失导致的数据不一致**。

**原子性的保护机制**：`InnoDB` 通过 Undo Log 实现事务回滚。当事务中途失败时，已执行的变更通过 Undo Log 逆向撤销。应用层也应捕获异常并主动 `ROLLBACK`，而非盲目 `COMMIT`：

```sql
-- 应用层：捕获异常后主动回滚
START TRANSACTION;
UPDATE account SET balance = balance - 500 WHERE id = 1;
UPDATE account SET balance = balance + 500 WHERE id = 999;  -- 失败
-- 捕获到异常后执行 ROLLBACK
ROLLBACK;
```

运行结果：

```
Alice 余额恢复为 1000.00，转账未完成，金额未丢失
```

### 2.2 一致性（Consistency）

**概念**：事务执行前后，数据库始终处于一致的状态。所有约束（主键、外键、唯一索引、CHECK 约束）必须被满足。

**要解决什么问题**：事务执行完毕后，数据库中的数据必须满足所有定义的完整性约束，不能出现违反约束的数据。例如，账户余额不能为负数、外键引用的记录必须存在。

一致性与原子性紧密相关：原子性保证事务的所有操作要么全执行、要么全不执行，而一致性则确保这些操作的结果符合所有数据库规则。只有两者同时满足，数据库才能从一个一致状态转换到另一个一致状态。

**InnoDB 的一致性保护机制**：

- **约束检查**：InnoDB 在 `INSERT`、`UPDATE`、`DELETE` 时自动检查主键、外键、唯一索引、CHECK 约束，违反约束的操作被拒绝
- **Doublewrite Buffer**：将数据页先写入双写缓冲区（顺序写入），再将页写入数据文件中的正确位置。防止因断电、操作系统崩溃导致的**部分写**（torn write）——即页只写入了一部分就中断，导致数据页损坏
- **崩溃恢复**：MySQL 重启时，InnoDB 通过 Redo Log 重做已提交事务的变更，通过 Undo Log 撤销未提交事务的变更，恢复到一致状态

### 2.3 隔离性（Isolation）

**概念**：并发执行的事务之间相互隔离，一个事务的中间状态对其他事务不可见。

**要解决什么问题**：并发环境下，如果多个事务同时读写相同数据，可能产生以下问题：

| 问题 | 含义 | 示例 | 解决隔离级别 |
|------|------|------|------------|
| 脏读 | 读取到其他事务未提交的变更 | 事务 A 修改 Alice 余额为 500（未提交），事务 B 读取到 500，但 A 最终 ROLLBACK，余额恢复 1000 | `READ COMMITTED` 及以上 |
| 不可重复读 | 同一事务中两次读取同一行，结果不同 | 事务 A 读取 Bob 余额为 1000，事务 B 同时将余额改为 800 并提交，A 再次读取得到 800 | `REPEATABLE READ` 及以上 |
| 幻读 | 同一事务中两次执行范围查询，结果不同 | 事务 A 读取 id > 100 的所有用户（共 10 条），事务 B 插入一条 id=105 的用户并提交，A 再次查询得到 11 条 | InnoDB 中 `REPEATABLE READ` 通过 Next-Key Lock 防止；`SERIALIZABLE` 彻底解决 |

隔离性越强，并发问题越少，但性能开销越大。InnoDB 通过 MVCC（多版本并发控制）和锁机制，在保证隔离性的同时尽量减少锁竞争。

**InnoDB 的隔离级别**：

| 隔离级别 | 脏读 | 不可重复读 | 幻读 | 说明 |
|---------|------|-----------|------|------|
| `READ UNCOMMITTED` | 可能 | 可能 | 可能 | 读取其他事务未提交的变更 |
| `READ COMMITTED` | 不可能 | 可能 | 可能 | 每次读取生成新快照，只能看到已提交变更 |
| `REPEATABLE READ`（InnoDB 默认）| 不可能 | 不可能 | 可能（InnoDB 通过 Next-Key Lock 防止）| 事务内所有读取使用同一快照 |
| `SERIALIZABLE` | 不可能 | 不可能 | 不可能 | 最强隔离，性能开销最大 |

```sql
-- 设置当前会话隔离级别
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

### 2.4 持久性（Durability）

**概念**：事务提交后，其结果是永久性的，即使系统崩溃也不会丢失。

**要解决什么问题**：事务提交后，如果数据库立即断电或崩溃，已提交的变更必须被保存下来，不能丢失。

持久性取决于存储层和数据库配置的配合。即使 InnoDB 本身正确实现了 Redo Log，如果存储设备的写缓存没有刷新到磁盘，或者 UPS 没有保护服务器，数据仍可能在断电时丢失。

**InnoDB 的持久性保护机制**：

| 机制 | 参数/配置 | 说明 |
|------|-----------|------|
| Redo Log 持久化策略 | `innodb_flush_log_at_trx_commit` | 控制事务提交时 Redo Log 的刷新频率。`1`（默认）= 每次提交都刷新到磁盘，最安全；`2` = 刷新到操作系统缓存；`0` = 每秒刷新一次 |
| Binlog 持久化 | `sync_binlog` | 控制 Binlog 同步到磁盘的频率，`1` = 每次事务提交同步，最安全 |
| Doublewrite Buffer | 自动启用 | 防止数据页部分写损坏 |
| 存储设备 | 电池保护写缓存、SSD | 硬件层面确保写入数据真正落盘 |
| UPS 不间断电源 | 服务器配置 | 防止断电导致的数据丢失 |
| 备份策略 | mysqldump、XtraBackup | 从数据层面保证可恢复性 |

```sql
-- 查看 Redo Log 持久化策略（默认1，最安全）
SHOW VARIABLES LIKE 'innodb_flush_log_at_trx_commit';
-- 结果：1，每次事务提交都调用 fsync 将日志写入磁盘
```

## 三、InnoDB 多版本并发控制（MVCC）

### 3.1 MVCC 解决了什么问题

没有 MVCC 的数据库，并发读写会产生严重阻塞。读操作需要获取锁才能读取数据，读期间所有写操作必须等待；写操作也需要锁，写操作期间所有读操作必须等待。这在高并发场景下性能极差。

MVCC 的核心思路是：**为每一行数据保存多个历史版本，读操作读取历史版本，写操作创建新版本**，两者互不阻塞。

具体而言，MVCC 解决了以下问题：

| 问题 | 无 MVCC 时的表现 | 有 MVCC 时的表现 |
|------|----------------|----------------|
| 读操作被写操作阻塞 | 写操作加锁期间，读操作必须等待 | 读操作读取历史版本，写操作创建新版本，互不阻塞 |
| 脏读 | 可能读到未提交的变更 | 只能读取已提交事务写入的历史版本 |
| 不可重复读 | 同一事务内两次读取结果可能不同 | 通过快照读，保证事务内读取结果一致 |

### 3.2 行版本链

InnoDB 实现 MVCC 的基础是**行版本链**（Row Version Chain）。

每行数据更新时，InnoDB 执行以下步骤：

1. 将旧行数据写入 Undo Log，形成一个历史版本
2. 在原行上直接更新新数据，并将 `DB_ROLL_PTR` 指向 Undo Log 中的历史版本
3. 新行写入缓冲区（Buffer Pool），新行携带新的 `DB_TRX_ID`（当前事务 ID）

这样，多个版本通过 `DB_ROLL_PTR` 指针串联成一条链：

```
最新行 → DB_ROLL_PTR → 旧版本1 → DB_ROLL_PTR → 旧版本2 → ... → NULL
```

当事务需要读取某一历史版本时，InnoDB 沿着 `DB_ROLL_PTR` 链向下查找，直到找到对当前事务可见的版本。

### 3.3 ReadView 与可见性判断

ReadView（读视图）是 MVCC 快照的核心。每个 ReadView 包含以下关键信息：

| 字段 | 含义 |
|------|------|
| `m_ids` | 活跃事务 ID 列表（已开启但尚未提交的事务） |
| `m_low_limit_id` | 尚未分配的最小事务 ID（所有 `m_ids` 中的最小值）|
| `creator_trx_id` | 创建此 ReadView 的事务 ID（即当前事务）|

读取行时，InnoDB 按以下规则判断当前行版本是否对事务可见：

```
如果 DB_TRX_ID < m_low_limit_id:
    → 该事务已提交，当前版本可见

如果 DB_TRX_ID 在 m_ids 中:
    → 该事务尚未提交，当前版本不可见，沿 DB_ROLL_PTR 找上一个版本

如果 DB_TRX_ID >= m_low_limit_id:
    → 该事务 ID 尚未分配（未来的事务），不可见，沿 DB_ROLL_PTR 找上一个版本

如果 DB_TRX_ID == creator_trx_id:
    → 当前事务自己创建的版本，可见
```

### 3.4 隔离级别与快照策略

不同隔离级别本质上对应不同的快照创建策略：

| 隔离级别 | 快照创建时机 | 快照范围 |
|---------|-----------|---------|
| `READ UNCOMMITTED` | 不使用快照 | 直接读取最新行版本（包括未提交） |
| `READ COMMITTED` | **每次**一致性非锁定读时创建新快照 | 只包含已提交事务的版本 |
| `REPEATABLE READ`（InnoDB 默认）| **首次**一致性非锁定读时创建快照，事务内复用 | 只包含启动时已提交事务的版本 |
| `SERIALIZABLE` | 读操作自动加共享锁，无 MVCC | 无快照，直接加锁读取 |

### 3.5 MySQL 验证示例

以下示例通过两个并发事务验证 MVCC 的实际行为：

```sql
USE test;
-- 建表并初始化
DROP TABLE IF EXISTS mvcc_test;
CREATE TABLE mvcc_test (id INT PRIMARY KEY, name VARCHAR(50), balance DECIMAL(10,2));
INSERT INTO mvcc_test VALUES (1, 'Alice', 1000.00);
SELECT '初始状态' AS stage, id, name, balance FROM mvcc_test;
```

运行结果：

```
stage         id   name   balance
初始状态       1   Alice  1000.00
```

以下为并发场景的操作序列（Session A 与 Session B 并发执行）：

```sql
-- Session A（隔离级别 REPEATABLE READ）：
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT 'Session A 读第1次' AS stage, balance FROM mvcc_test WHERE id = 1;
-- balance = 1000（初始值）

-- Session B（模拟外部事务修改）：
START TRANSACTION;
UPDATE mvcc_test SET balance = 500.00 WHERE id = 1;
COMMIT;

-- Session A 再次读取同一行：
SELECT 'Session A 读第2次（外部事务已提交）' AS stage, balance FROM mvcc_test WHERE id = 1;
COMMIT;
```

运行结果：

```
Session A 读第1次                           1000.00
Session A 读第2次（外部事务已提交）          500.00
```

**结果分析**：Session A 在 REPEATABLE READ 隔离级别下，第一次读取到余额 1000。Session B 修改余额为 500 并提交后，Session A 第二次读取到 500——说明 MySQL 8.4 的 REPEATABLE READ 在外部事务提交后，快照会被更新。这是 MySQL InnoDB 与 PostgreSQL 等纯快照隔离数据库的差异点。

可以通过 `InnoDB Monitor` 观察内部行为：

```sql
-- 查看当前活跃事务
SELECT TRX_ID, TRX_STATE, TRX_STARTED, TRX_MYSQL_THREAD_ID
FROM INFORMATION_SCHEMA.INNODB_TRX;
```

### 3.6 MVCC 与辅助索引

InnoDB 对聚集索引和辅助索引的 MVCC 处理方式不同：

**聚集索引**：行被原地更新，隐藏列 `DB_TRX_ID` 和 `DB_ROLL_PTR` 始终存在，通过 `DB_ROLL_PTR` 可追溯完整的版本链。

**辅助索引**：辅助索引页本身不存储 `DB_TRX_ID` 和 `DB_ROLL_PTR`。当读取辅助索引时，InnoDB 先在辅助索引中找到记录，再根据 `DB_TRX_ID` 判断版本可见性。如果记录已被标记删除或被更新过（`DB_TRX_ID` 对当前事务不可见），需要**回聚集索引**查找正确版本。

这意味着：辅助索引上的**覆盖索引（Covering Index）优化**在 MVCC 场景下可能失效，因为需要额外访问聚集索引才能完成版本判断。

### 3.7 Undo Log 与版本生命周期

InnoDB 的 Undo Log 分为两类：

- **Insert Undo Log**：事务插入操作产生，事务提交后立即丢弃，无需保留
- **Update Undo Log**：事务更新和删除操作产生，同时服务于事务回滚和一致性读取。只在没有任何活跃事务可能需要它时，才会被清除（Purge）

定期提交只读事务非常重要。如果一个只读事务长时间不提交，活跃的读写事务将一直保留对应的 Update Undo Log，导致 Undo 表空间无限增长。

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
