---
title: MySQL 日志类型与配置
date: 2026-03-30 15:38:00
tags:
  - 错误日志
  - 二进制日志
  - 通用查询日志
  - 慢查询日志
  - 日志配置
categories: MySQL
---

## 一、MySQL 日志类型概述

MySQL Server 在运行过程中会生成多种日志，用于记录服务器状态、客户端请求、语句执行和故障排查等信息。

| 日志类型 | 作用 | 默认状态 |
|---------|------|---------|
| `error log` | 记录服务器启动、运行和停止过程中的关键事件 | 始终启用 |
| `general query log` | 记录所有客户端连接和接收到的 SQL 语句 | 默认关闭 |
| `binary log` | 记录数据变更（用于复制和增量恢复） | 默认启用 |
| `slow query log` | 记录执行时间超过阈值的查询 | 默认关闭 |

## 二、错误日志

错误日志记录服务器启动、运行、停止过程中的关键事件，以及警告和错误信息，是排查 MySQL 故障的主要信息来源。

### 2.1 默认路径与配置

在 Unix/Linux 系统中，`mysqld` 通过 `--log-error` 选项决定错误日志的默认目标：

| 启动方式 | 默认行为 |
|---------|---------|
| 未指定 `--log-error` | 输出到控制台（stderr） |
| `--log-error`（无文件名） | 输出到 `host_name.err`，位于数据目录 |
| `--log-error=file_name` | 输出到指定文件，自动添加 `.err` 后缀 |

**验证：**

```sql
SELECT @@log_error;
```

```
+-------------------------+
| @@log_error             |
+-------------------------+
| /var/log/mysql/mysqld.log |
+-------------------------+
```

本机错误日志路径为 `/var/log/mysql/mysqld.log`。

修改日志路径示例（在配置文件中，路径为 `/etc/my.cnf.d/mysql-server.cnf`）：

```ini
[mysqld]
log-error=/var/log/mysql/mysqld.log
```

> RPM 或 APT 包安装时通常配置为 `/var/log/mysqld.log`。移除路径名后，改为数据目录下的 `host_name.err`。

### 2.2 日志格式

`log_sink_internal` 产生的传统错误日志格式为：

```
time thread [label] [err_code] [subsystem] msg
```

每条消息包含：时间戳、线程 ID、优先级标签、错误码、子系统、消息内容。

`label` 为优先级的字符串形式，对应关系如下：

| 优先级 | `prio` 值 | `label` 字符串 |
|--------|-----------|---------------|
| `SYSTEM` | 0 | `System` |
| `ERROR` | 1 | `Error` |
| `WARNING` | 2 | `Warning` |
| `INFORMATION` | 3 | `Note` 或 `Information` |

> SYSTEM 优先级为启动/关闭等系统消息，无法被过滤。

`subsystem` 标识产生该事件的 MySQL 子系统：

| `subsystem` 值 | 说明 |
|---------------|------|
| `InnoDB` | InnoDB 存储引擎 |
| `Repl` | 复制子系统 |
| `Server` | 服务器通用部分 |

**时间戳格式**由 `log_timestamps` 控制：

```sql
SELECT @@log_timestamps;
```

```
+-------------------+
| @@log_timestamps  |
+-------------------+
| UTC               |
+-------------------+
```

可选值为 `UTC`（默认）和 `SYSTEM`（本地时区）。时间戳格式为 `ISO 8601`/`RFC 3339`：

```
2020-08-07T15:02:00.832521Z       # UTC
2020-08-07T10:02:00.832521-05:00  # SYSTEM（本地时区）
```

### 2.3 日志过滤

错误日志组件体系由过滤器（filter）和写入器（sink）组成。过滤器处理日志事件，写入器负责输出到具体目的地。

#### 2.3.1 优先级过滤（`log_filter_internal`）

`log_filter_internal` 是内置的优先级过滤器，受 `log_error_verbosity` 控制：

```sql
SELECT @@log_error_verbosity;
```

```
+------------------------+
| @@log_error_verbosity  |
+------------------------+
|                      2 |
+------------------------+
```

| `log_error_verbosity` 值 | 记录的优先级 |
|------------------------|-------------|
| 1 | ERROR |
| 2 | ERROR, WARNING（默认） |
| 3 | ERROR, WARNING, INFORMATION |

优先级含义：

| 优先级 | 数字值 | 说明 |
|--------|--------|------|
| SYSTEM | 0 | 启动/关闭等系统消息，无法过滤 |
| ERROR | 1 | 错误 |
| WARNING | 2 | 警告 |
| INFORMATION | 3 | 信息 |

另外，`log_error_suppression_list` 可按错误码压制特定消息（仅对 WARNING 和 INFORMATION 生效）：

```sql
SET GLOBAL log_error_suppression_list = 'ER_PARSER_TRACE,MY-010001,10002';
```

错误码支持符号名（如 `ER_PARSER_TRACE`）、带 `MY-` 前缀（如 `MY-010001`）或纯数字（如 `10002`）。符号名优于数字，可读性更好。

**优先级过滤规则（与 `log_error_verbosity` 等效）：**

| 规则 | 等效 `log_error_verbosity` |
|------|---------------------------|
| `IF prio > ERROR THEN drop.` | 1（仅 ERROR） |
| `IF prio > WARNING THEN drop.` | 2（ERROR + WARNING） |
| `IF prio > INFORMATION THEN drop.` | 3（全部） |

#### 2.3.2 规则过滤（`log_filter_dragnet`）

`log_filter_dragnet` 支持用户自定义规则过滤。先加载组件，再配置：

```sql
INSTALL COMPONENT 'file://component_log_filter_dragnet';
SET GLOBAL log_error_services = 'log_filter_dragnet; log_sink_internal';
```

通过 `dragnet.log_error_filter_rules` 设置规则，规则以 `IF condition THEN action.` 格式编写：

```sql
SET GLOBAL dragnet.log_error_filter_rules =
'IF prio>=INFORMATION THEN drop. IF EXISTS source_line THEN unset source_line.';
```

支持的 action 包括：

| action | 说明 |
|--------|------|
| `drop` | 丢弃该日志事件 |
| `throttle count` 或 `count/window_size` | 限流，限制单位时间内的记录次数 |
| `set field = value` | 设置字段值 |
| `unset field` | 移除字段 |

限流示例——每 60 秒最多记录 1 条 INFORMATION 级别事件：

```sql
SET GLOBAL dragnet.log_error_filter_rules =
'IF prio>=INFORMATION THEN throttle 1/60.';
```

> `log_filter_dragnet` 启用后，`log_error_suppression_list` 不再生效。

### 2.4 JSON 格式输出

`log_sink_json` 将错误日志输出为 JSON 格式。先加载组件：

```sql
INSTALL COMPONENT 'file://component_log_sink_json';
SET PERSIST log_error_services = 'log_filter_internal; log_sink_json';
```

JSON 格式每条消息包含键值对，例如：

```json
{
  "prio": 3,
  "err_code": 10051,
  "source_line": 561,
  "source_file": "event_scheduler.cc",
  "msg": "Event Scheduler: scheduler thread started with id 5",
  "time": "2020-08-06T14:25:03.109022Z",
  "ts": 1596724012005,
  "thread": 5,
  "err_symbol": "ER_SCHEDULER_STARTED",
  "SQL_state": "HY000",
  "subsystem": "Server",
  "label": "Note"
}
```

其中 `ts` 为毫秒级 Unix 时间戳，可用 `FROM_UNIXTIME()` 转换：

```sql
SELECT FROM_UNIXTIME(1596724012005/1000.0);
```

```
+-------------------------------------+
| FROM_UNIXTIME(1596724012005/1000.0)|
+-------------------------------------+
| 2020-08-06 14:26:52.0050            |
+-------------------------------------+
```

`log_sink_json` 允许多次出现，可同时写入未过滤和已过滤的事件：

```sql
SET PERSIST log_error_services = 'log_sink_json; log_filter_internal; log_sink_json';
```

多个实例的输出文件以 `.00.json`、`.01.json` 递增编号。

### 2.5 输出到系统日志

`log_sink_syseventlog` 将错误日志写入系统日志（Unix 的 `syslog` 或 Windows 的 Event Log）：

```sql
INSTALL COMPONENT 'file://component_log_sink_syseventlog';
SET PERSIST log_error_services = 'log_filter_internal; log_sink_syseventlog';
```

相关系统变量：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `syseventlog.facility` | `syslog` 的 facility 类型 | `daemon` |
| `syseventlog.include_pid` | 是否包含进程 ID | 取决于平台 |
| `syseventlog.tag` | 在 `mysqld` 标识后追加的标签 | 未设置 |

Windows 上日志来源标记为 `MySQL`（或 `MySQL-tag`），Unix 上写入 `syslog`。

### 2.6 日志刷新与重命名

手动刷新错误日志时，服务器关闭并重新打开日志文件。操作前应先重命名旧文件：

```bash
mv /var/log/mysql/mysqld.log /var/log/mysql/mysqld.log-old
mysqladmin flush-logs error
mv /var/log/mysql/mysqld.log-old /backup-directory/
```

> 如果服务器无法写入日志文件（例如 `/var/log` 目录属主为 `root`），刷新操作无法创建新文件，此时需手动创建文件并赋予正确权限。

## 三、通用查询日志

通用查询日志记录所有客户端的连接断开信息和接收到的每条 SQL 语句。当怀疑客户端发送了错误语句时，可通过该日志精确还原客户端请求。

```sql
-- 验证：默认状态
SELECT @@general_log, @@general_log_file;
```

```
+--------------+----------------------------------+
| general_log  | general_log_file                 |
+--------------+----------------------------------+
|            0 | /var/lib/mysql/probiecoder.log |
+--------------+----------------------------------+
```

默认关闭。启用并指定输出目标：

```sql
SET GLOBAL general_log = 1;
SET GLOBAL log_output = 'FILE';  -- 或 TABLE，或 FILE,TABLE
```

> 默认输出目标为 `FILE`。如果设为 `NONE`，即使 `general_log = 1` 也不会记录。

**永久配置：** 在配置文件中设置（`/etc/my.cnf.d/mysql-server.cnf`）：

```ini
[mysqld]
general_log = 1
log_output = TABLE
general_log_file = /var/lib/mysql/general.log
```

**临时配置：** 运行时 `SET GLOBAL`（重启后失效）：

```sql
SET GLOBAL general_log = 1;
SET GLOBAL log_output = 'TABLE';
SET GLOBAL general_log_file = '/var/lib/mysql/general.log';
```

### 3.1 输出目标为 TABLE 时的存储

`log_output = 'TABLE'` 时，日志数据存储在 `mysql.general_log` 表中：

```sql
SELECT @@log_output;
SHOW CREATE TABLE mysql.general_log\G
```

```
+-------------+
| log_output  |
+-------------+
| FILE        |
+-------------+
*************************** 1. row ***************************
       Table: general_log
Create Table: CREATE TABLE `general_log` (
  `event_time` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `user_host` mediumtext NOT NULL,
  `thread_id` bigint unsigned NOT NULL,
  `server_id` int unsigned NOT NULL,
  `command_type` varchar(64) NOT NULL,
  `argument` mediumblob NOT NULL
) ENGINE=CSV DEFAULT CHARSET=utf8mb3 COMMENT='General log'
```

表结构说明：

| 字段 | 说明 |
|------|------|
| `event_time` | 事件时间戳，精度到微秒 |
| `user_host` | 客户端用户和主机信息 |
| `thread_id` | 连接线程 ID |
| `server_id` | 服务器 ID |
| `command_type` | 命令类型 |
| `argument` | 执行的语句内容（二进制格式） |

`command_type` 字段支持的类型：

| `command_type` 值 | 说明 |
|------------------|------|
| `Connect` | 客户端连接或断开连接 |
| `Query` | 执行的 SQL 查询语句 |
| `Quit` | 客户端退出连接 |
| `Prepare` | 预处理语句（`PREPARE`） |
| `Execute` | 执行预处理语句（`EXECUTE`） |
| `Init DB` | 切换数据库（`USE db_name`） |

查看日志内容：

```sql
-- argument 是 mediumblob（二进制），需要转换后查看
SELECT event_time, thread_id, command_type,
       CONVERT(argument USING utf8mb4) AS argument_text
FROM mysql.general_log
ORDER BY event_time DESC
LIMIT 10;
```

> `argument` 字段类型为 `mediumblob`，存储的是二进制内容。使用 `CONVERT(argument USING utf8mb4)` 或 `CAST(argument AS CHAR)` 将其转换为可读字符串。

> 该表默认使用 `CSV` 存储引擎，也可转换为 `MyISAM` 引擎。`INSERT`、`DELETE`、`UPDATE` 操作只能在服务器内部进行，用户无法直接修改日志表。

### 3.2 会话级禁用

会话级禁用通用查询日志（需 `general_log = 1` 前提下）：

```sql
SET SESSION sql_log_off = ON;  -- 当前会话禁用
SET SESSION sql_log_off = OFF; -- 恢复记录
```

密码在日志中会被自动重写，不会明文出现。如果需要诊断目的查看原始语句，可使用 `--log-raw` 选项启动服务器（生产环境慎用）。

日志记录顺序为服务器接收顺序，与执行顺序可能不一致。不同于二进制日志（先执行后记录），通用查询日志可能包含未实际执行的语句。

## 四、二进制日志

二进制日志记录数据库的数据变更事件，用于复制和增量恢复。默认启用。

### 4.1 默认配置

```sql
SELECT @@log_bin, @@log_bin_basename;
```

```
+--------+------------------------+
| log_bin| log_bin_basename       |
+--------+------------------------+
|      1 | /var/lib/mysql/binlog  |
+--------+------------------------+
```

二进制日志文件位于 `/var/lib/mysql/` 目录下：

```bash
ls -la /var/lib/mysql/binlog*
```

```
-rw-r-----. 1 mysql mysql  2569 Mar 25 11:57 binlog.000001
-rw-r-----. 1 mysql mysql  1158 Mar 25 16:37 binlog.000002
-rw-r-----. 1 mysql mysql 12874 Mar 25 20:02 binlog.000003
...
-rw-r-----. 1 mysql mysql   144 Mar 30 08:19 binlog.index
```

日志文件说明：

| 文件 | 说明 |
|------|------|
| `binlog.000001` 等 | 二进制日志文件，编号递增 |
| `binlog.index` | 二进制日志索引文件，记录所有日志文件名 |

### 4.2 查看二进制日志内容

**方式一：SQL 语句**

```sql
SHOW BINLOG EVENTS IN 'binlog.000009' LIMIT 10;
```

```
+-----------+-----+---------------+-----------+-------------+---------------------------------------+
| Log_name  | Pos | Event_type    | Server_id | End_log_pos | Info                                  |
+-----------+-----+---------------+-----------+-------------+---------------------------------------+
| binlog.000009 |   4 | Format_desc     |         1 |         127 | Server ver: 8.4.8, Binlog ver: 4  |
| binlog.000009 | 127 | Previous_gtids |         1 |         158 |                                      |
| binlog.000009 | 158 | Anonymous_Gtid |         1 |         235 | SET @@SESSION.GTID_NEXT= 'ANONYMOUS' |
| binlog.000009 | 235 | Query          |         1 |         384 | CREATE DATABASE IF NOT EXISTS test... |
| binlog.000009 | 384 | Anonymous_Gtid |         1 |         461 | SET @@SESSION.GTID_NEXT= 'ANONYMOUS' |
+-----------+-----+---------------+-----------+-------------+---------------------------------------+
```

主要事件类型说明：

| Event_type | 说明 |
|------------|------|
| `Format_desc` | 日志格式描述 |
| `Previous_gtids` | 前一个日志的 GTID 集合 |
| `Gtid` | GTID 事务标识 |
| `Query` | DDL/DML 语句 |
| `Xid` | 事务提交标识 |
| `Table_map` | 表结构映射 |
| `Write_rows` / `Update_rows` / `Delete_rows` | 行数据变更（ROW 格式） |

**查看最近的日志事件：**

```sql
-- 按时间倒序查看最近 10 条
SHOW BINLOG EVENTS IN 'binlog.000009' LIMIT 10;

-- 从指定位置开始查看后续事件
SHOW BINLOG EVENTS IN 'binlog.000009' FROM 1000 LIMIT 20;
```

**过滤特定数据库的变更：**

```sql
-- 使用 LIMIT 控制返回数量（从文件开头遍历，性能较差）
SHOW BINLOG EVENTS IN 'binlog.000009' LIMIT 20;
```

> `SHOW BINLOG EVENTS` 不支持 `WHERE` 子句，也无法直接按数据库过滤。查看特定数据库的变更需要结合外部工具或使用 `mysqlbinlog` 命令（可能需要 sudo 权限）。

```bash
mysqlbinlog /var/lib/mysql/binlog.000009 | head -50
```

```
# The proper term is pseudo_replica_mode...
/*!50530 SET @@SESSION.PSEUDO_SLAVE_MODE=1*/;
/*!50003 SET @OLD_COMPLETION_TYPE=@@COMPLETION_TYPE,COMPLETION_TYPE=0*/;
DELIMITER /*!*/;
SET @@SESSION.GTID_NEXT= 'AUTOMATIC' /* added by mysqlbinlog */ /*!*/;
DELIMITER ;
# End of log file
/*!50003 SET COMPLETION_TYPE=@OLD_COMPLETION_TYPE*/;
/*!50530 SET @@SESSION.PSEUDO_SLAVE_MODE=0*/;
```

> `mysqlbinlog` 需要读取权限，可能需要 `sudo` 或调整文件权限。`-v` 选项可显示更详细的可读格式，`--base64-output=DECODE_ROWS` 解码行事件。

### 4.3 三种日志格式

`binlog_format` 系统变量控制二进制日志的格式：

| 格式 | 说明 |
|------|------|
| `STATEMENT` | 记录实际执行的 SQL 语句（基于语句的复制） |
| `ROW` | 记录每行数据的变更（基于行的复制，默认） |
| `MIXED` | 默认使用 `STATEMENT`，在特定条件下自动切换为 `ROW` |

运行时切换：

```sql
SET GLOBAL binlog_format = 'ROW';
SET SESSION binlog_format = 'MIXED';
```

**`MIXED` 模式自动切换为 `ROW` 的条件包括：**

- 语句中包含 `UUID()`
- 包含 `AUTO_INCREMENT` 列的表触发存储过程/函数
- 视图创建时需要 `ROW` 格式
- 调用了可加载函数
- 使用了 `FOUND_ROWS()`、`ROW_COUNT()`
- 使用了 `USER()`、`CURRENT_USER()`
- 涉及 `mysql` 数据库中的日志表
- 使用了 `LOAD_FILE()`
- 引用了某些系统变量

```sql
-- 查看当前格式
SELECT @@binlog_format;
```

```
+---------------+
| binlog_format |
+---------------+
| ROW           |
+---------------+
```

`ROW` 模式下，所有修改数据的语句都以行变化形式记录。但部分语句（如 `CREATE TABLE`、`ALTER TABLE` 等 DDL）仍以语句形式记录。

> 使用 `STATEMENT` 格式时，某些不确定的语句可能导致主从数据不一致。`ROW` 格式精度更高，但日志体积通常更大。

### 4.4 二进制日志事务压缩

MySQL 8.0.20+ 支持二进制日志事务压缩，使用 `zstd` 算法压缩事务载荷：

```sql
SET GLOBAL binlog_transaction_compression = 1;
```

压缩级别可通过 `binlog_transaction_compression_level_zstd` 设置（1 到 22，越高压缩率越大）：

```sql
SET GLOBAL binlog_transaction_compression_level_zstd = 5;
```

以下事件不压缩，始终以原始形式写入：

- GTID 相关事件
- 控制事件（视图变更、心跳等）
- 事件和事务（包含 incident 事件的事务）
- 非事务引擎的事件和事务
- 语句格式的日志记录

加密和压缩可同时启用。启用后，副本接收到压缩载荷，直接写入中继日志，解压后应用事件，再压缩写入自己的二进制日志。

可通过 `performance_schema.binary_log_transaction_compression_stats` 表监控压缩效果。

## 五、慢查询日志

慢查询日志记录执行时间超过 `long_query_time` 秒且检查行数至少达到 `min_examined_row_limit` 的查询。默认关闭。

```sql
SELECT @@slow_query_log, @@slow_query_log_file, @@long_query_time;
```

```
+----------------+------------------------------------+----------------+
| slow_query_log | slow_query_log_file                | long_query_time|
+----------------+------------------------------------+----------------+
|              0 | /var/lib/mysql/probiecoder-slow.log|    10.000000  |
+----------------+------------------------------------+----------------+
```

`long_query_time` 默认 10 秒，最小值 0，可精确到微秒：

```sql
SET GLOBAL long_query_time = 1.5;
```

### 5.1 日志参数

| 参数 | 说明 |
|------|------|
| `log_slow_admin_statements` | 是否记录管理语句（`ALTER TABLE`、`ANALYZE TABLE` 等），默认关闭 |
| `log_queries_not_using_indexes` | 是否记录未使用索引的查询，默认关闭 |
| `log_throttle_queries_not_using_indexes` | 每分钟压制未使用索引的查询数量上限，默认 0（不压制） |
| `log_slow_extra` | 是否输出额外字段（`Thread_id`、`Bytes_received` 等），默认关闭 |

服务器判断是否记录某查询的顺序：

1. 管理语句必须 `log_slow_admin_statements = 1` 才能记录
2. 执行时间达到 `long_query_time` **或** `log_queries_not_using_indexes = 1` 且未使用索引
3. 检查行数达到 `min_examined_row_limit`
4. 未被 `log_throttle_queries_not_using_indexes` 压制

启用未使用索引的查询记录并压制（每分钟最多 10 条）：

```sql
SET GLOBAL log_queries_not_using_indexes = 1;
SET GLOBAL log_throttle_queries_not_using_indexes = 10;
```

### 5.2 日志内容

启用 `log_slow_extra` 后，FILE 输出的慢查询日志每条记录包含：

| 字段 | 说明 |
|------|------|
| `Query_time` | 执行时长（秒） |
| `Lock_time` | 锁等待时长 |
| `Rows_sent` | 发送给客户端的行数 |
| `Rows_examined` | 服务器层检查的行数（不含存储引擎内部处理） |
| `Thread_id` | 语句线程标识 |
| `Bytes_received` | 从客户端接收的字节数 |
| `Bytes_sent` | 发送给客户端的字节数 |
| `Read_first/Key/Next/Prev` 等 | 各类 Handler 读操作统计 |
| `Sort_merge_passes` | 排序合并遍历次数 |
| `Created_tmp_disk_tables` | 磁盘创建临时表数 |
| `Created_tmp_tables` | 内存创建临时表数 |
| `Start` / `End` | 执行开始和结束时间戳 |

日志文件分析工具 `mysqldumpslow` 可汇总慢查询日志：

```bash
mysqldumpslow /var/lib/mysql/probiecoder-slow.log
```

## 六、日志维护

### 6.1 日志刷新

执行 `FLUSH LOGS` 或 `mysqladmin flush-logs` 后，服务器重新打开各日志文件：

| 日志类型 | 刷新行为 |
|---------|---------|
| 二进制日志 | 关闭当前文件，创建新文件（递增编号） |
| 通用查询日志 / 慢查询日志 | 关闭并重新打开文件（不创建新文件） |
| 错误日志 | 关闭并重新打开文件（不创建新文件） |

> 刷新前应先重命名旧文件，否则日志内容被覆盖。

Unix 信号刷新日志（无需连接服务器）：

```bash
kill -SIGUSR1 $(cat /var/run/mysqld/mysqld.pid)
```

- `SIGHUP`：刷新所有日志，但有其他副作用
- `SIGUSR1`：仅刷新错误日志、通用查询日志、慢查询日志，更轻量

### 6.2 二进制日志清理

**自动过期：** 二进制日志默认 30 天后自动删除，通过 `binlog_expire_logs_seconds` 控制：

```sql
SET GLOBAL binlog_expire_logs_seconds = 604800;  -- 7 天
```

**手动清理：** 使用 `PURGE BINARY LOGS` 删除指定日期或文件之前的日志：

```sql
PURGE BINARY LOGS BEFORE '2026-03-01 00:00:00';
PURGE BINARY LOGS TO 'binlog.000005';  -- 删除该文件之前的所有日志
```

**全部删除：** `RESET BINARY LOGS AND GTIDS` 慎用，会删除所有二进制日志。

> 在主从复制环境中，删除二进制日志前应确保所有从库已完成同步。

### 6.3 日志文件权限问题

日志文件所在目录若无写权限（如 `/var/log` 属主为 `root`），日志刷新无法创建新文件。解决方案：

```bash
# 手动创建新文件并赋予正确权限
install -omysql -gmysql -m0644 /dev/null /var/log/mysqld.log
```
