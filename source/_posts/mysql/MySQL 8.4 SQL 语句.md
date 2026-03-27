---
title: MySQL 8.4 SQL 语句
published: true
layout: post
date: 2026-03-26 14:00:00
permalink: /mysql/mysql-84-sql-statements.html
categories: [MySQL]
tags: [内置函数, 运算符]
---

## 一、数据定义语句（DDL）

### 1.1 TABLE
`` TABLE `` 用于定义表结构及相关操作，包含创建、修改、重命名、清空、删除等。
##### 1.1.1 CREATE TABLE

`` CREATE TABLE `` 用于在数据库中创建新表，可指定列定义、索引、存储引擎等选项。

```sql
CREATE [TEMPORARY] TABLE [IF NOT EXISTS] tbl_name (
    col_name type
        [NOT NULL | NULL]
        [DEFAULT val]
        [AUTO_INCREMENT]
        [COMMENT 'string']
        [COLLATE collation]
        [[PRIMARY KEY] | [UNIQUE [KEY]]]
    [, col_name type [constraint...]]
    [, INDEX|KEY [idx_name] (col, ...) [COMMENT 'string']]
    [, PRIMARY KEY (col, ...) [USING {BTREE | HASH}]]
    [, UNIQUE [INDEX|KEY] [idx_name] (col, ...) [USING {BTREE | HASH}]]
    [, FOREIGN KEY (col) REFERENCES tbl(col)]
) [ENGINE = engine]
  [AUTO_INCREMENT = n]
  [CHARSET = charset]
  [COMMENT = 'string']

LIKE old_tbl_name | AS SELECT ...
```

| 表级子句 | 说明 |
|------|------|
| `` [TEMPORARY] `` | 临时表，会话结束自动删除 |
| `` [IF NOT EXISTS] `` | 表不存在时才创建 |
| `` [ENGINE = engine] `` | 存储引擎 |
| `` [AUTO_INCREMENT = n] `` | 初始自增值 |
| `` [CHARSET = charset] `` | 字符集 |
| `` [COMMENT = 'string'] `` | 表注释 |
| `` [INDEX|KEY [idx] (col, ...)] `` | 普通索引 |
| `` [PRIMARY KEY (col, ...)] `` | 主键 |
| `` [UNIQUE [INDEX|KEY] [idx] (col, ...)] `` | 唯一索引 |
| `` [FOREIGN KEY (col) REFERENCES tbl(col)] `` | 外键约束 |

| 替代形式 | 说明 |
|------|------|
| `` LIKE old_tbl_name `` | 复制表结构（不含数据） |
| `` AS SELECT ... `` | 基于查询结果创建表（不含数据） |

| 列级子句 | 说明 |
|------|------|
| `` col_name type `` | 列名和字段类型 |
| `` [NOT NULL | NULL] `` | 可空性 |
| `` [DEFAULT val] `` | 默认值 |
| `` [AUTO_INCREMENT] `` | 自增主键 |
| `` [COMMENT 'string'] `` | 列注释 |
| `` [COLLATE collation] `` | 列级排序规则 |
| `` [PRIMARY KEY] `` | 主键约束 |
| `` [UNIQUE [KEY]] `` | 唯一约束 |

**CREATE TABLE 示例：**

```sql
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    age INT DEFAULT 18,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '用户表';
```

**复制表结构：**

```sql
CREATE TABLE users_copy LIKE users;
```

**基于查询结果创建表：**

```sql
CREATE TABLE users_backup AS SELECT * FROM users;
```

---

##### 1.1.2 ALTER TABLE

`` ALTER TABLE `` 用于修改已存在表的结构，包括添加/删除列、修改列属性、添加索引等操作。

```sql
ALTER TABLE tbl_name
    [ADD|DROP COLUMN col_name type]
    [MODIFY|CHANGE COLUMN old new type]
    [ADD|DROP INDEX idx_name (col, ...)]
    [ADD|DROP PRIMARY KEY (col, ...)]
    [ADD|DROP FOREIGN KEY (col) REFERENCES tbl(col)]
    [RENAME TO new_tbl]
    [ENGINE = engine_name]
```

| 子句 | 说明 |
|------|------|
| `` ADD|DROP COLUMN `` | 添加或删除一列 |
| `` MODIFY COLUMN `` | 修改列类型或属性（不改列名） |
| `` CHANGE COLUMN `` | 修改列类型或属性（同时改列名） |
| `` ADD|DROP INDEX `` | 添加或删除索引 |
| `` ADD|DROP PRIMARY KEY `` | 添加或删除主键 |
| `` ADD|DROP FOREIGN KEY `` | 添加或删除外键约束 |
| `` RENAME TO `` | 重命名表 |
| `` ENGINE = ... `` | 更换存储引擎 |

**ALTER TABLE 示例：**

```sql
ALTER TABLE users ADD COLUMN phone VARCHAR(20) AFTER email;
ALTER TABLE users MODIFY COLUMN age SMALLINT DEFAULT 0;
ALTER TABLE users CHANGE COLUMN created_at create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE users ADD INDEX idx_name (name);
```

---

##### 1.1.3 RENAME TABLE

`` RENAME TABLE `` 用于重命名一张或多张表，也可跨库移动表。

```sql
RENAME TABLE old_name TO new_name [, old_name2 TO new_name2] ...
```

| 子句 | 说明 |
|------|------|
| `` old_name TO new_name `` | 重命名一个表 |
| `` 逗号分隔 `` | 可同时重命名多个表 |

**RENAME TABLE 示例：**

```sql
RENAME TABLE t1 TO t2, t3 TO t4;
```

---

##### 1.1.4 TRUNCATE TABLE

`` TRUNCATE TABLE `` 用于快速清空表中所有数据，本质是删除并重建表，比 `` DELETE `` 更快。

```sql
TRUNCATE [TABLE] tbl_name
```

| 子句 | 说明 |
|------|------|
| `` [TABLE] `` | TABLE 关键字可省略，效果相同 |
| `` AUTO_INCREMENT `` | 值重置为初始值 |
| `` 触发器 `` | 不触发 ON DELETE 触发器 |
| `` 事务 `` | 隐式提交，不能回滚 |
| `` 外键 `` | 有外键引用的 InnoDB 表无法执行 |

**TRUNCATE TABLE 示例：**

```sql
TRUNCATE TABLE users;
```

---

##### 1.1.5 DROP TABLE

`` DROP TABLE `` 用于永久删除一张或多张表，删除后数据和表结构不可恢复。

```sql
DROP [TEMPORARY] TABLE [IF EXISTS] tbl_name [, tbl_name2] ...
```

| 子句 | 说明 |
|------|------|
| `` [TEMPORARY] `` | 仅删除临时表，不影响普通表 |
| `` [IF EXISTS] `` | 表不存在时不报错（仅警告） |
| `` 事务 `` | 操作直接提交，不可回滚 |

**DROP TABLE 示例：**

```sql
DROP TABLE IF EXISTS temp_data;
```

---

### 1.2 DATABASE
`` DATABASE `` 用于定义数据库结构及相关操作，包含创建、删除等。
##### 1.2.1 CREATE DATABASE

`` CREATE DATABASE `` 用于创建新数据库，可指定默认字符集和排序规则。

```sql
CREATE {DATABASE | SCHEMA} [IF NOT EXISTS] db_name
    [DEFAULT] CHARACTER SET [=] charset_name
    [DEFAULT] COLLATE [=] collation_name
```

| 子句 | 说明 |
|------|------|
| `` DATABASE | SCHEMA `` | 两者等价 |
| `` [IF NOT EXISTS] `` | 数据库已存在时不报错 |
| `` CHARACTER SET `` | 指定默认字符集，如 utf8mb4 |
| `` COLLATE `` | 指定默认排序规则，如 utf8mb4_general_ci |

**CREATE DATABASE 示例：**

```sql
CREATE DATABASE IF NOT EXISTS test_db DEFAULT CHARACTER SET utf8mb4;
```

---

##### 1.2.2 DROP DATABASE

`` DROP DATABASE `` 用于删除数据库，同时删除其中所有表，操作不可回滚。

```sql
DROP {DATABASE | SCHEMA} [IF EXISTS] db_name
```

| 子句 | 说明 |
|------|------|
| `` DATABASE | SCHEMA `` | 两者等价 |
| `` [IF EXISTS] `` | 数据库不存在时不报错 |

**DROP DATABASE 示例：**

```sql
DROP DATABASE IF EXISTS test_db;
```

---

### 1.3 PROCEDURE
`` PROCEDURE `` 用于定义存储过程，包含创建、删除等。
##### 1.3.1 CREATE PROCEDURE

`` CREATE PROCEDURE `` 用于创建存储过程，将一段 SQL 逻辑保存在数据库中，可接受输入输出参数。

```sql
CREATE PROCEDURE proc_name([IN | OUT | INOUT] param type, ...)
BEGIN
    [DECLARE variable type [DEFAULT value]; ...]
    [DECLARE condition_name CONDITION FOR {SQLSTATE 'sqlstate' | MySQL_error_code};]
    [DECLARE handler_type HANDLER FOR condition_value [, ...] statement;]
    SET var = value;
    SELECT col INTO var FROM ...;
    IF condition THEN statements;
    [ELSEIF condition THEN statements;]
    [ELSE statements;]
    END IF;
    [label:] LOOP ... END LOOP [label];
    [label:] WHILE condition DO ... END WHILE [label];
    [label:] REPEAT ... UNTIL condition END REPEAT [label];
    CASE value WHEN val THEN statements; [...] END CASE;
    [LEAVE label;]
    [ITERATE label;]
END
```

| 子句 | 说明 |
|------|------|
| `` IN param type `` | 输入参数，调用时传入值 |
| `` OUT param type `` | 输出参数，过程中赋值供调用方接收 |
| `` INOUT param type `` | 既是输入也是输出 |
| `` BEGIN...END `` | 过程体，所有 SQL 逻辑写在此区间 |
| `` DECLARE var type [DEFAULT val] `` | 声明局部变量 |
| `` SET var = value `` | 直接赋值 |
| `` SELECT col INTO var `` | 从查询结果取列值赋给变量 |
| `` IF/ELSEIF/ELSE END IF `` | 条件分支 |
| `` WHILE DO...END WHILE `` | 条件为真时循环 |
| `` REPEAT...UNTIL cond END REPEAT `` | 先执行后判断 |
| `` LOOP...END LOOP `` | 无限循环，配合 LEAVE 退出 |
| `` CASE WHEN...END CASE `` | 多值分支 |
| `` LEAVE label `` | 退出指定标签的循环或块 |
| `` ITERATE label `` | 跳到指定标签继续下一次循环 |
| `` DECLARE CONDITION `` | 定义异常别名 |
| `` DECLARE {EXIT|CONTINUE} HANDLER `` | 声明异常处理器 |

> 使用 `` DELIMITER `` 临时修改语句分隔符，避免过程体内的分号被客户端提前解析。

**DECLARE 与 SET 的区别：**

- `` DECLARE `` 在 `` BEGIN...END `` 块的最前面**声明**变量（创建），可选带默认值
- `` SET `` 给已声明的变量**赋值**（使用），可多次执行
- `` SELECT col INTO var `` 也是一种赋值方式，将查询结果赋给变量

**DECLARE 变量声明：**

```sql
DELIMITER //
CREATE PROCEDURE add_user(IN p_name VARCHAR(50), IN p_age INT)
BEGIN
    DECLARE v_count INT DEFAULT 0;
    SELECT COUNT(*) INTO v_count FROM users;
    INSERT INTO users (name, age) VALUES (p_name, p_age);
    SELECT CONCAT('当前用户数：', v_count + 1) AS msg;
END//
DELIMITER ;
```

```sql
CALL add_user('Alice', 25);
```

**SELECT INTO 赋值：**

```sql
DELIMITER //
CREATE PROCEDURE get_stats(OUT p_min INT, OUT p_max INT, OUT p_avg DECIMAL(10,2))
BEGIN
    SELECT MIN(age), MAX(age), AVG(age) INTO p_min, p_max, p_avg FROM users;
END//
DELIMITER ;
```

```sql
CALL get_stats(@min, @max, @avg);
SELECT @min, @max, @avg;
```

**条件判断（IF/ELSEIF/ELSE）：**

```sql
DELIMITER //
CREATE PROCEDURE get_age_level(IN p_age INT, OUT p_level VARCHAR(10))
BEGIN
    IF p_age < 18 THEN
        SET p_level = '未成年';
    ELSEIF p_age < 30 THEN
        SET p_level = '青年';
    ELSEIF p_age < 60 THEN
        SET p_level = '中年';
    ELSE
        SET p_level = '老年';
    END IF;
END//
DELIMITER ;
```

```sql
CALL get_age_level(35, @level);
SELECT @level;
```

**循环（WHILE）：**

```sql
DELIMITER //
CREATE PROCEDURE sum_1_to_n(IN n INT, OUT p_result INT)
BEGIN
    DECLARE v_i INT DEFAULT 1;
    SET p_result = 0;
    WHILE v_i <= n DO
        SET p_result = p_result + v_i;
        SET v_i = v_i + 1;
    END WHILE;
END//
DELIMITER ;
```

```sql
CALL sum_1_to_n(100, @result);
SELECT @result;
```

**循环（REPEAT...UNTIL）：**

```sql
DELIMITER //
CREATE PROCEDURE sum_1_to_n_repeat(IN n INT, OUT p_result INT)
BEGIN
    DECLARE v_i INT DEFAULT 1;
    SET p_result = 0;
    REPEAT
        SET p_result = p_result + v_i;
        SET v_i = v_i + 1;
    UNTIL v_i > n END REPEAT;
END//
DELIMITER ;
```

**循环（LOOP/LEAVE）：**

```sql
DELIMITER //
CREATE PROCEDURE sum_1_to_n_loop(IN n INT, OUT p_result INT)
BEGIN
    DECLARE v_i INT DEFAULT 1;
    SET p_result = 0;
    sum_loop: LOOP
        SET p_result = p_result + v_i;
        SET v_i = v_i + 1;
        IF v_i > n THEN
            LEAVE sum_loop;
        END IF;
    END LOOP sum_loop;
END//
DELIMITER ;
```

**CASE 语句：**

```sql
DELIMITER //
CREATE PROCEDURE get_grade(IN p_score INT, OUT p_grade CHAR(1))
BEGIN
    CASE p_score
        WHEN 100 THEN SET p_grade = 'S';
        WHEN 90  THEN SET p_grade = 'A';
        WHEN 80  THEN SET p_grade = 'B';
        WHEN 60  THEN SET p_grade = 'C';
        ELSE SET p_grade = 'D';
    END CASE;
END//
DELIMITER ;
```

**异常处理（DECLARE HANDLER）：**

异常处理用于捕获并响应存储过程执行中的错误或特定状态。

**语法结构：**

```sql
-- 1. 定义异常别名（可选）
DECLARE cond_name CONDITION FOR SQLSTATE 'sqlstate_value';
-- 2. 声明异常处理器
DECLARE {EXIT | CONTINUE} HANDLER
    FOR {condition_name | SQLSTATE 'value' | SQLWARNING | NOT FOUND | SQLEXCEPTION}
    [, ...]
BEGIN
    handler_body;
END;
```

**HANDLER 类型：**

| HANDLER 类型 | 说明 |
|------|------|
| `` EXIT HANDLER `` | 异常处理后退出当前 `` BEGIN...END `` 块 |
| `` CONTINUE HANDLER `` | 异常处理后继续执行下一条语句 |

**condition_value（触发条件）：**

| condition_value | 说明 |
|------|------|
| `` cond_name `` | 前面用 `` DECLARE CONDITION `` 定义的条件别名 |
| `` SQLSTATE 'value' `` | 直接指定 SQLSTATE 值（如 `` '45000' `` 自定义异常） |
| `` MySQL_error_code `` | 直接指定 MySQL 错误码（如 `` 1146 `` 表不存在） |
| `` SQLEXCEPTION `` | 捕获所有异常（SQLSTATE 不以 `` 00 ``、`` 02 ``、`` 03 `` 开头） |
| `` SQLWARNING `` | 捕获所有警告（SQLSTATE 以 `` 01 `` 开头） |
| `` NOT FOUND `` | 捕获游标或 `` SELECT INTO `` 无数据（SQLSTATE `` 02000 ``） |

**CONDITION 与 HANDLER 的区别：**

- `` CONDITION ``：仅为异常定义一个别名，使代码更易读，不执行任何动作
- `` HANDLER ``：定义当异常发生时执行的处理逻辑（处理体），必须配合 `` BEGIN...END `` 块

**示例一：使用 SQLSTATE 值：**

```sql
DELIMITER //
CREATE PROCEDURE safe_divide(IN a INT, IN b INT, OUT p_result DECIMAL(10,2), OUT p_error VARCHAR(100))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @errno = MYSQL_ERRNO, @msg = MESSAGE_TEXT;
        SET p_result = NULL;
        SET p_error = CONCAT('Error ', @errno, ': ', @msg);
    END;
    IF b = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Division by zero';
    END IF;
    SET p_result = a / b;
    SET p_error = NULL;
END//
DELIMITER ;
```

```sql
CALL safe_divide(10, 0, @result, @error);
SELECT @result, @error;
```

**示例二：使用 CONDITION 定义别名：**

```sql
DELIMITER //
CREATE PROCEDURE insert_user(IN p_name VARCHAR(50), OUT p_id INT)
BEGIN
    DECLARE duplicate_entry CONDITION FOR SQLSTATE '23000';
    DECLARE EXIT HANDLER FOR duplicate_entry
    BEGIN
        SET p_id = -1;
    END;
    INSERT INTO users (name) VALUES (p_name);
    SET p_id = LAST_INSERT_ID();
END//
DELIMITER ;
```

**示例三：NOT FOUND 处理：**

```sql
DELIMITER //
CREATE PROCEDURE find_user(IN p_name VARCHAR(50), OUT p_id INT)
BEGIN
    DECLARE v_found INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_found = 1;
    SELECT id INTO p_id FROM users WHERE name = p_name;
    IF v_found = 1 THEN
        SET p_id = NULL;
    END IF;
END//
DELIMITER ;
```

> `` GET DIAGNOSTICS `` 可在处理器内获取错误编号和信息。`` SIGNAL `` 主动抛出自定义异常。


---

##### 1.3.2 DROP PROCEDURE

`` DROP PROCEDURE `` 用于删除已存在的存储过程。

```sql
DROP PROCEDURE [IF EXISTS] proc_name
```

| 子句 | 说明 |
|------|------|
| `` [IF EXISTS] `` | 过程不存在时不报错 |

**DROP PROCEDURE 示例：**

```sql
DROP PROCEDURE IF EXISTS get_user_count;
```

---

### 1.4 TRIGGER
`` TRIGGER `` 用于定义触发器，包含创建、删除等。
##### 1.4.1 CREATE TRIGGER

`` CREATE TRIGGER `` 用于创建触发器，在 `` INSERT ``、`` UPDATE ``、`` DELETE `` 事件发生时自动执行。

```sql
CREATE TRIGGER trigger_name
    {BEFORE | AFTER}
    {INSERT | UPDATE | DELETE}
    ON tbl_name
    [FOR EACH ROW]
BEGIN
    trigger_body
END
```

| 子句 | 说明 |
|------|------|
| `` BEFORE `` / `` AFTER `` | 触发时机，行操作前或后 |
| `` INSERT `` / `` UPDATE `` / `` DELETE `` | 触发事件类型 |
| `` ON tbl_name `` | 触发器所属的表 |
| `` FOR EACH ROW `` | 逐行触发（MySQL 仅支持此模式） |

`` trigger_body `` 是触发器激活时执行的语句体：

- **单条语句**：直接书写，无需 `` BEGIN...END `` 包裹
- **多条语句**：必须用 `` BEGIN...END `` 包裹，构成复合语句
- **允许使用的语句**包括 `` SET ``、`` INSERT ``、`` UPDATE ``、`` DELETE ``、`` SELECT ``（但必须into变量或作为表达式，不能返回行结果集给客户端）等
- **禁止使用的语句**包括 `` START TRANSACTION ``（触发器在事务中隐式执行，不允许嵌套开启新事务）、`` PREPARE `` / `` EXECUTE `` 等动态语句（预编译语句的作用域问题，无法在触发器中正确管理）
- 触发器中不能有 `` RETURN `` 语句，也不能向客户端返回结果集
- **NEW** 和 **OLD** 用于在 `` trigger_body `` 内部引用行数据：
  - `` NEW.col_name ``：引用变更后的列值，`` INSERT `` 时为待插入值，`` UPDATE `` 时为更新后的值
  - `` OLD.col_name ``：引用变更前的列值，`` UPDATE `` 时为修改前的旧值，`` DELETE `` 时为被删除的值

**CREATE TRIGGER 示例：**

```sql
CREATE TABLE audit_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(200),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

```sql
DELIMITER //
CREATE TRIGGER after_user_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (action) VALUES (CONCAT('Inserted: ', NEW.name));
END//
DELIMITER ;
```

```sql
INSERT INTO users (name, email, age) VALUES ('TestUser', 'test@test.com', 22);
```

---

##### 1.4.2 DROP TRIGGER

`` DROP TRIGGER `` 用于删除已存在的触发器。

```sql
DROP TRIGGER [IF EXISTS] [schema_name.]trigger_name
```

| 子句 | 说明 |
|------|------|
| `` [IF EXISTS] `` | 触发器不存在时不报错 |
| `` [schema_name.] `` | 可指定数据库名，默认为当前数据库 |

**DROP TRIGGER 示例：**

```sql
DROP TRIGGER IF EXISTS after_user_insert;
```

---

### 1.5 INDEX
`` INDEX `` 用于为表中列创建索引数据结构，加速数据查询。数据库表中数据以无序堆存储，查询时需全表扫描——数据量大时效率极低。索引如同书籍目录，将列值按结构组织（如 B+ 树），让数据库无需遍历全表即可快速定位目标行。
##### 1.5.1 CREATE INDEX

`` CREATE INDEX `` 用于在表上创建索引，加速查询，可创建普通索引、唯一索引或全文索引。

```sql
CREATE [UNIQUE | FULLTEXT] INDEX idx_name
    ON tbl_name (col [(length)], ...)
```

| 子句 | 说明 |
|------|------|
| `` INDEX `` | 普通索引，允许重复值 |
| `` UNIQUE `` | 唯一索引，值不可重复 |
| `` FULLTEXT `` | 全文索引，仅支持 CHAR/VARCHAR/TEXT 列 |
| `` idx_name `` | 索引名称，可省略（系统自动命名） |
| `` col [(length)] `` | 列名或前缀长度（前缀索引） |

三种索引的区别和使用场景：

| 类型 | 允许重复 | 数据结构 | 适用场景 | 注意事项 |
|------|---------|---------|---------|---------|
| 普通索引 | ✅ | B+ 树 | 加速等值查询、范围查询，如按 email 查用户、按时间查订单 | 索引本身不约束数据，仅提升查询性能 |
| 唯一索引 | ❌ | B+ 树 | 保证数据唯一性，如手机号、身份证号、用户名 | 除加速查询外，还约束列值不重复 |
| 全文索引 | N/A | 倒排索引 | 模糊关键词搜索，如文章标题或正文中搜索关键词 | 不支持精确等值查询，需用 `MATCH() ... AGAINST()` 语法 |

选择建议：
- 只需加速查询且允许重复 → 普通索引
- 既要加速查询又要保证唯一性 → 唯一索引
- 需要在文本列中搜索关键词 → 全文索引

**CREATE INDEX 示例：**

```sql
CREATE INDEX idx_email ON users (email);
CREATE UNIQUE INDEX idx_phone ON users (phone);
CREATE FULLTEXT INDEX idx_bio ON users (bio);
```

---

##### 1.5.2 DROP INDEX

`` DROP INDEX `` 用于删除表中已存在的索引。

```sql
DROP INDEX idx_name ON tbl_name
```

| 子句 | 说明 |
|------|------|
| `` idx_name `` | 索引名称，必须指定 |

**DROP INDEX 示例：**

```sql
DROP INDEX idx_phone ON users;
```

---

## 二、数据操作语句（DML）

### 2.1 INSERT
`` INSERT `` 用于向表中插入新行数据，支持单行插入、批量插入和基于查询结果插入。
```sql
INSERT [IGNORE]
    [INTO] tbl_name [(col_name, ...)]
    {VALUES | VALUE} (value_list) [, (value_list)] ...
    [ON DUPLICATE KEY UPDATE col=expr [, col=expr] ...]
```

| 子句 | 说明 |
|------|------|
| `` IGNORE `` | 忽略错误（如唯一键冲突）继续执行 |
| `` [INTO] `` | 可省略，不影响语义 |
| `` VALUES | VALUE `` | 两者等价 |
| `` (value_list) `` | 每个括号对应一行数据 |
| `` ON DUPLICATE KEY UPDATE `` | 唯一键或主键冲突时执行更新 |
| `` REPLACE INTO `` | 冲突时先删后插（等效于 DELETE + INSERT） |

**INSERT 示例：**

```sql
INSERT INTO users (name, email, age) VALUES ('Alice', 'alice@example.com', 25);
```

**批量插入：**

```sql
INSERT INTO users (name, email, age) VALUES
    ('Dave', 'dave@example.com', 22),
    ('Eve', 'eve@example.com', 28),
    ('Frank', 'frank@example.com', 35);
```

**ON DUPLICATE KEY UPDATE（键冲突时更新）：**

```sql
INSERT INTO users (name, email, age) VALUES ('Alice', 'alice@example.com', 26)
ON DUPLICATE KEY UPDATE age = VALUES(age);
```

**REPLACE（键冲突时替换）：**

```sql
REPLACE INTO users (id, name, email, age) VALUES (1, 'Alice', 'alice@example.com', 27);
```

---

### 2.2 UPDATE
`` UPDATE `` 用于修改表中已存在的行数据，支持条件更新、排序限制更新。
```sql
UPDATE [IGNORE] tbl_name [, tbl_name2] ...
SET col_name1={expr1 | DEFAULT} [, col_name2={expr2 | DEFAULT}] ...
[WHERE where_condition]
[ORDER BY ...]
[LIMIT row_count]
```

| 子句 | 说明 |
|------|------|
| `` WHERE condition `` | 筛选条件，缺省则更新全表 |
| `` ORDER BY ... LIMIT n `` | 先排序后限制更新行数 |
| `` IGNORE `` | 忽略错误继续执行 |

**UPDATE 示例：**

```sql
UPDATE users SET age = 26 WHERE name = 'Alice';
```

---

### 2.3 DELETE
`` DELETE `` 用于删除表中满足条件的行，可按排序限制删除数量。
```sql
DELETE [LOW_PRIORITY] [QUICK] [IGNORE]
    FROM tbl_name [, tbl_name2] ...
    [WHERE where_condition]
    [ORDER BY ...]
    [LIMIT row_count]
```

| 子句 | 说明 |
|------|------|
| `` WHERE condition `` | 筛选条件，缺省则清空全表 |
| `` ORDER BY ... LIMIT n `` | 先排序后删除限定行数 |
| `` QUICK `` | 快速模式，不合并索引叶子节点 |
| `` LOW_PRIORITY `` | 等待其他读操作完成后再删除 |
| `` IGNORE `` | 忽略错误继续执行 |

**DELETE 示例：**

```sql
DELETE FROM users WHERE id = 10;
```

---

### 2.4 SELECT
`` SELECT `` 是最常用的数据查询语句，支持条件过滤、分组、排序、连接、子查询等丰富功能。
```sql
SELECT [ALL | DISTINCT]
    select_expr [, select_expr]...
    [FROM table_references]
    [WHERE where_condition]
    [GROUP BY {col_name | expr | position} [ASC | DESC], ...]
    [HAVING where_condition]
    [ORDER BY {col_name | expr | position} [ASC | DESC], ...]
    [LIMIT {[offset,] row_count | row_count OFFSET offset}]
    [FOR UPDATE | LOCK IN SHARE MODE]
```

| 子句 | 说明 |
|------|------|
| `` ALL | DISTINCT `` | 返回全部或去除重复行（默认 ALL） |
| `` select_expr `` | 查询表达式，可为列、聚合函数、常量、表达式 |
| `` FROM table_references `` | 数据来源，支持单表、多表 JOIN |
| `` WHERE condition `` | 行级过滤条件 |
| `` GROUP BY col [ASC|DESC] `` | 按列或表达式分组 |
| `` HAVING condition `` | 分组后过滤，可使用聚合函数 |
| `` ORDER BY col [ASC|DESC] `` | 对结果集排序 |
| `` LIMIT n [OFFSET m] `` | 限制返回行数（分页） |
| `` FOR UPDATE `` | 排他锁，阻止其他事务修改 |
| `` LOCK IN SHARE MODE `` | 共享锁，允许并发读 |

**条件过滤：**

```sql
SELECT * FROM users WHERE age >= 18 AND email LIKE '%example%';
```

**聚合统计：**

```sql
SELECT
    COUNT(*) AS total,
    AVG(age) AS avg_age,
    MAX(age) AS max_age,
    MIN(age) AS min_age
FROM users;
```

**分组与过滤：**

```sql
SELECT department, COUNT(*) AS cnt, AVG(salary) AS avg_sal
FROM employees
GROUP BY department
HAVING AVG(salary) > 50000
ORDER BY avg_sal DESC;
```

**分页查询：**

```sql
SELECT * FROM users ORDER BY id LIMIT 3 OFFSET 0;
```

**JOIN 连接查询：**

```sql
SELECT u.name, o.order_id, o.amount
FROM users u
INNER JOIN orders o ON u.id = o.user_id
WHERE o.amount > 100
ORDER BY o.amount DESC;
```

**子查询：**

```sql
SELECT * FROM users WHERE age > (SELECT AVG(age) FROM users);
```

---

### 2.5 CALL
`` CALL `` 用于调用已创建的存储过程，配合 OUT 参数接收返回值。
```sql
CALL proc_name([param [, param ...]])
```

| 子句 | 说明 |
|------|------|
| `` IN param `` | 直接传值 |
| `` OUT param `` | 传用户变量（`` @var ``）接收 |
| `` INOUT param `` | 传用户变量，过程内可读写 |

**CALL 示例：**

```sql
CALL get_user_count();
```

```sql
CALL get_stats(@min, @max);
SELECT @min, @max, @avg;
```

---

### 2.6 LOAD DATA
`` LOAD DATA `` 用于从文件批量导入数据到表中，比多次 `` INSERT `` 效率高得多。
```sql
LOAD DATA [LOCAL]
    INFILE 'file_name'
    [REPLACE | IGNORE]
    INTO TABLE tbl_name
    [CHARACTER SET charset_name]
    [FIELDS TERMINATED BY 'char']
    [LINES TERMINATED BY 'string']
    [IGNORE n LINES]
    [(col_name, ...)]
```

| 子句 | 说明 |
|------|------|
| `` [LOCAL] `` | 从客户端读取文件；不加则从服务器端读取 |
| `` INFILE 'file_name' `` | 数据文件路径，受 secure_file_priv 限制 |
| `` REPLACE | IGNORE `` | 唯一键冲突时替换或忽略 |
| `` CHARACTER SET `` | 文件字符编码，如 utf8mb4 |
| `` FIELDS TERMINATED BY `` | 字段分隔符，CSV 通常为 , |
| `` LINES TERMINATED BY `` | 行分隔符，通常为 \\n |
| `` IGNORE n LINES `` | 跳过文件前 n 行（如表头） |
| `` (col_name, ...) `` | 指定导入的列及顺序 |

**LOAD DATA 示例：**

```sql
LOAD DATA LOCAL INFILE '/home/duwei/data.csv'
INTO TABLE users
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(name, email, age);
```

> ⚠️ **ERROR 1290 / ERROR 13 错误处理**（服务端读取）
> - **错误原因**：`LOAD DATA INFILE`（无 `LOCAL`）由服务端读取文件，受 `secure_file_priv` 限制，只能读取指定目录；若路径允许但 MySQL 服务进程无权限读取，则报 ERROR 13
> - **解决方法一（推荐）**：改用 `LOAD DATA LOCAL INFILE`，从客户端读取文件，完全绕过 `secure_file_priv` 和路径权限限制
> - **解决方法二**：将 `secure_file_priv` 设为空，编辑 MySQL 配置文件（`/etc/my.cnf.d/mysql-server.cnf`），在 `[mysqld]` 段落下添加：
>
> ```ini
> [mysqld]
> secure_file_priv=
> ```
>
> 然后重启 MySQL：`sudo systemctl restart mysqld`
>
> ⚠️ **ERROR 3948 错误处理**（客户端读取）
> - **错误原因**：`LOAD DATA LOCAL INFILE` 需服务端开启 `local_infile=ON`，否则拒绝客户端请求；此错误与 `secure_file_priv` 无关
> - **解决方法**：编辑 MySQL 配置文件（`/etc/my.cnf.d/mysql-server.cnf`），在 `[mysqld]` 段落下添加：
>
> ```ini
> [mysqld]
> local_infile=ON
> ```
>
> 然后重启 MySQL：`sudo systemctl restart mysqld`
>
> ⚠️ **安全警告**：`secure_file_priv` 是重要的安全防护机制，设为空后 MySQL 服务进程对所有可读文件均有读取权限。生产环境中不建议长期关闭此限制，正确做法是将待导入文件放入 `secure_file_priv` 指定的目录后再导入。

---

## 三、事务控制语句

### 3.1 START TRANSACTION / COMMIT / ROLLBACK
事务语句用于控制一组 DML 操作是否生效，支持原子性提交或全部回滚。
```sql
START TRANSACTION [READ ONLY | READ WRITE] [WITH CONSISTENT SNAPSHOT]
COMMIT [AND {CHAIN | NO CHAIN}] [[SAVEPOINT] RELEASE]
ROLLBACK [AND {CHAIN | NO CHAIN}]
    [[SAVEPOINT] RELEASE]
    [TO [SAVEPOINT] savepoint_name]
SET autocommit = {0 | 1}
```

| 子句 | 说明 |
|------|------|
| `` START TRANSACTION `` | 开启新事务 |
| `` READ ONLY | READ WRITE `` | 只读或读写模式（默认读写） |
| `` WITH CONSISTENT SNAPSHOT `` | 开启一致性快照（仅 InnoDB） |
| `` COMMIT `` | 提交事务，所有变更永久生效 |
| `` ROLLBACK `` | 回滚事务，取消所有未提交变更 |
| `` AND CHAIN | NO CHAIN `` | 提交/回滚后是否自动开启新事务 |
| `` RELEASE SAVEPOINT `` | 提交/回滚后自动删除保存点 |
| `` TO SAVEPOINT name `` | 回滚到指定保存点 |
| `` SET autocommit = 0 `` | 关闭自动提交，改为手动提交 |

**事务示例：**

```sql
START TRANSACTION;
UPDATE accounts SET balance = balance - 1000 WHERE user_id = 1;
UPDATE accounts SET balance = balance + 1000 WHERE user_id = 2;
COMMIT;
```

**回滚示例：**

```sql
START TRANSACTION;
UPDATE accounts SET balance = balance - 500 WHERE user_id = 1;
ROLLBACK;
```

---

### 3.2 SAVEPOINT
保存点用于在事务内部标记位置，允许只回滚到指定点而非全部回滚。
```sql
SAVEPOINT savepoint_name
ROLLBACK [WORK] TO [SAVEPOINT] savepoint_name
RELEASE SAVEPOINT savepoint_name
```

| 子句 | 说明 |
|------|------|
| `` SAVEPOINT sp1 `` | 创建保存点 |
| `` ROLLBACK TO SAVEPOINT sp1 `` | 回滚到保存点 sp1 |
| `` RELEASE SAVEPOINT sp1 `` | 删除保存点（不执行回滚） |

**SAVEPOINT 示例：**

```sql
START TRANSACTION;
INSERT INTO users (name) VALUES ('User1');
SAVEPOINT sp1;
INSERT INTO users (name) VALUES ('User2');
SAVEPOINT sp2;
ROLLBACK TO SAVEPOINT sp1;
COMMIT;
```

**RELEASE SAVEPOINT 示例：**

```sql
START TRANSACTION;
INSERT INTO users (name) VALUES ('Alice');
SAVEPOINT sp1;
INSERT INTO users (name) VALUES ('Bob');
RELEASE SAVEPOINT sp1;
INSERT INTO users (name) VALUES ('Carol');
ROLLBACK TO SAVEPOINT sp1;
COMMIT;
```

执行结果：三条记录全部被提交。`RELEASE SAVEPOINT` 仅仅是删除保存点，不执行任何回滚操作。删除后 `ROLLBACK TO SAVEPOINT sp1` 将无法使用，报错 `Unknown savepoint 'sp1'`。

> 注意：`RELEASE SAVEPOINT` 的主要作用是在事务内提前删除不再需要的保存点，释放内存。若未执行，事务结束时保存点自动释放，不需要手动处理。

---

## 四、实用语句

### 4.1 USE
`` USE `` 用于将指定数据库设为当前会话的默认数据库。
```sql
USE db_name
```

| 子句 | 说明 |
|------|------|
| `` db_name `` | 数据库名称 |

**USE 示例：**

```sql
USE learn;
```

---

### 4.2 DESCRIBE

`` DESCRIBE ``（或 `` DESC ``）用于查看表的列结构、类型、约束等信息。

```sql
{DESCRIBE | DESC} tbl_name [col_name | wild]
```

| 子句 | 说明 |
|------|------|
| `` tbl_name `` | 表名 |
| `` col_name | wild `` | 指定列名或使用通配符过滤 |

**DESCRIBE 示例：**

```sql
DESCRIBE users;
```

---

### 4.3 EXPLAIN

`` EXPLAIN `` 用于分析 MySQL 如何执行查询，返回执行计划信息，帮助判断是否走索引、是否全表扫描、关联顺序是否最优等；`` EXPLAIN ANALYZE `` 在此基础上实际执行语句，返回每步的真实耗时和实际扫描行数。

```sql
EXPLAIN [FORMAT = {TRADITIONAL | JSON | TREE}]
    {SELECT | DELETE | INSERT | REPLACE | UPDATE | TABLE} ...
EXPLAIN [FORMAT = {TRADITIONAL | JSON | TREE}]
    FOR CONNECTION connection_id
EXPLAIN ANALYZE
    {SELECT | DELETE | INSERT | REPLACE | UPDATE | TABLE} ...
```

| 子句 | 说明 |
|------|------|
| `` EXPLAIN SELECT ... `` | 分析查询计划，不执行语句 |
| `` EXPLAIN ANALYZE `` | 执行语句并返回每步真实耗时（MySQL 8.0.18+） |
| `` FORMAT = TRADITIONAL `` | 默认格式，以表格形式输出 |
| `` FORMAT = JSON `` | 以 JSON 格式输出，字段最全 |
| `` FORMAT = TREE `` | 树形格式，比 TRADITIONAL 描述更精确，是唯一显示 hash join 的格式 |
| `` FOR CONNECTION id `` | 分析指定连接中正在执行的语句计划 |
| `` FOR SCHEMA db_name `` | 以指定数据库上下文分析语句（MySQL 8.4+） |

**EXPLAIN 示例：**

```sql
EXPLAIN SELECT * FROM users WHERE email LIKE 'a%';
```

**EXPLAIN FORMAT=JSON 示例：**

```sql
EXPLAIN FORMAT=JSON SELECT * FROM users WHERE id = 1;
```

**EXPLAIN FORMAT=TREE 示例：**

```sql
EXPLAIN FORMAT=TREE SELECT * FROM users WHERE id > 10;
```

**EXPLAIN ANALYZE 示例：**

```sql
EXPLAIN ANALYZE SELECT u.name, o.amount
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE u.status = 'active';
```

执行结果示例：

```
EXPLAIN: -> Inner hash join (o.user_id = u.id) (cost=3.5 rows=5)
(actual time=0.121..0.131 rows=1 loops=1)
    -> Table scan on o (cost=0.07 rows=5)
    (actual time=0.0126..0.0221 rows=5 loops=1)
    -> Hash
    -> Table scan on u (cost=0.75 rows=5)
    (actual time=0.0372..0.0534 rows=5 loops=1)
```

**输出字段说明：**

| 字段 | JSON 名称 | 说明 |
|------|---------|------|
| `` id `` | select_id | SELECT 的编号，子查询或 UNION 中区分各部分 |
| `` select_type `` | 无 | SELECT 类型（见下表） |
| `` table `` | table_name | 本行对应的表名 |
| `` partitions `` | partitions | 匹配的分区（非分区表为 NULL） |
| `` type `` | access_type | 关联类型（见下节），ALL 最差 |
| `` possible_keys `` | possible_keys | 可供选择的所有索引 |
| `` key `` | key | 实际使用的索引 |
| `` key_len `` | key_length | 使用索引的字节长度，可判断复合索引使用了多少列；变长列额外加 2 字节，可空列额外加 1 字节 |
| `` ref `` | ref | 与索引比较的列或常量 |
| `` rows `` | rows | 预计扫描的行数（InnoDB 为估算值） |
| `` filtered `` | filtered | 通过条件过滤后剩余的百分比，最大 100 |
| `` Extra `` | 无（分散在各属性中） | 附加信息（见下节） |

**select_type 类型：**

| 类型 | 说明 |
|------|------|
| `` SIMPLE `` | 简单 SELECT，不含 UNION 或子查询 |
| `` PRIMARY `` | 最外层 SELECT |
| `` UNION `` | UNION 中第二个及之后的 SELECT |
| `` DEPENDENT UNION `` | UNION 中第二个及之后的 SELECT，依赖外层查询 |
| `` UNION RESULT `` | UNION 的结果集 |
| `` SUBQUERY `` | 子查询中的第一个 SELECT |
| `` DEPENDENT SUBQUERY `` | 子查询中第一个 SELECT，依赖外层查询 |
| `` DERIVED `` | FROM 子句中的派生表（子查询） |
| `` DEPENDENT DERIVED `` | 派生表依赖其他表 |
| `` MATERIALIZED `` | 物化子查询，结果写入临时表 |
| `` UNCACHEABLE SUBQUERY `` | 结果不可缓存的子查询，每行重新评估 |
| `` UNCACHEABLE UNION `` | 属于不可缓存子查询的 UNION |

**type（关联类型），从最优到最差排序：**

| 类型 | 说明 |
|------|------|
| `` system `` | 表只有一行（系统表），const 的特例 |
| `` const `` | 至多一行匹配，主键或唯一索引与常量等值比较时使用 |
| `` eq_ref `` | 关联时通过主键或唯一索引等值读取每行，JOIN 中最优 |
| `` ref `` | 通过索引前缀或非唯一索引等值读取所有匹配行 |
| `` fulltext `` | 使用 FULLTEXT 索引 |
| `` ref_or_null `` | 类似 ref，同时额外搜索 NULL 值 |
| `` index_merge `` | 使用 Index Merge 优化，多索引合并 |
| `` unique_subquery `` | IN 子查询中用主键查找替代 |
| `` index_subquery `` | 类似 unique_subquery，用于非唯一索引 |
| `` range `` | 使用索引范围扫描（`` =``、`` <>``、`` >``、`` >=``、`` <``、`` <=``、`` IN``、`` BETWEEN``、`` LIKE``） |
| `` index `` | 索引全扫描（覆盖索引时比 ALL 快） |
| `` ALL `` | 全表扫描，最差，应尽量避免 |

**Extra 常见值：**

| 值 | 说明 |
|------|------|
| `` Using index `` | 覆盖索引，直接从索引返回数据，无需回表 |
| `` Using where `` | WHERE 条件在存储引擎之后应用，需回表过滤 |
| `` Using filesort `` | 无法利用索引排序，使用文件排序（额外开销） |
| `` Using temporary `` | 使用临时表保存中间结果（如 GROUP BY、DISTINCT） |
| `` Using index condition `` | 索引条件下推（ICP），部分条件在索引层先过滤 |
| `` Using join buffer `` | 关联时使用 join buffer 批量处理 |
| `` Impossible WHERE `` | WHERE 条件永假，无行可返回 |
| `` No matching min/max row `` | MIN/MAX 查询无匹配行 |
| `` const row not found `` | 表为空 |
| `` Distinct `` | 查找 DISTINCT 值，找到后停止搜索 |
| `` Not exists `` | LEFT JOIN 优化，找到匹配行后不再检查同一表的更多行 |
| `` Backward index scan `` | 倒序扫描索引（InnoDB 支持降序索引） |
| `` Select tables optimized away `` | 无需执行阶段，优化阶段即可确定结果 |
| `` Using withrolled validation `` | 写入时强制校验（For UPDATE 写锁场景） |

**key_len 详解**：

`key_len` 表示 MySQL 实际使用的索引字节长度，可用于判断复合索引被使用了多少列。计算方式为每列索引长度之和，每列长度由列类型决定：

| 列类型 | 索引字节长度 |
|--------|------------|
| `` TINYINT `` | 1 |
| `` SMALLINT `` | 2 |
| `` MEDIUMINT `` | 3 |
| `` INT `` | 4 |
| `` BIGINT `` | 8 |
| `` CHAR(n) `` | n × 字符集字节数（latin1 为 1，utf8mb4 为 4） |
| `` VARCHAR(n) `` | 变长，额外加 2 字节存储长度 |
| `` DATETIME `` | 5 |
| `` TIMESTAMP `` | 4 |
| 列可为空 | 再加 1 字节 |

实际计算示例：`` users `` 表的复合索引 `` INDEX idx_name_age_email (name(10), age, email(20)) ``。

```
mysql> SHOW INDEX FROM users WHERE Key_name = 'idx_name_age_email';
+-------+------------+----------+-----------+------+
| Seq   | Column_name | Sub_part | Null     |
+-------+------------+----------+-----------+------+
| 1     | name       | 10       |           |
| 2     | age        | NULL     | YES       |
| 3     | email      | 20       | YES       |
+-------+------------+----------+-----------+------+
```

列属性：name 为 `` VARCHAR ``（NOT NULL，utf8mb4），age 为 `` INT ``（可空），email 为 `` VARCHAR ``（可空，utf8mb4）。

按公式计算各列索引字节长度：name 前缀 10×4+2=42；age 为 INT，4 字节，可空再加 1 = 5；email 前缀 20×4+2=82，可空再加 1 = 83。三列 total = 42 + 5 + 83 = 130。

实际 EXPLAIN 验证：

```sql
-- 查询使用 name + age，email 未用到
mysql> EXPLAIN SELECT * FROM users WHERE name = 'Alice' AND age = 18\G
          key: idx_name_age_email
       key_len: 47
         ref: const,const
-- 47 = name(42) + age(5)，符合预期

-- 查询只使用 name 前缀
mysql> EXPLAIN SELECT * FROM users WHERE name = 'Alice'\G
          key: idx_name_age_email
       key_len: 42
         ref: const
-- 42 = name(42)，age 列未使用

-- 查询三列全部使用
mysql> EXPLAIN SELECT * FROM users WHERE name = 'Bob' AND age = 18 AND email IS NULL\G
          key: idx_name_age_email
       key_len: 130
         ref: const,const,const
-- 130 = name(42) + age(5) + email(83)，符合预期
```

通过 `` key_len `` 值即可反推索引被使用了多少列。

---

### 4.4 SHOW

`` SHOW `` 用于查看数据库、表、列、索引、变量、状态等各类元数据信息，是日常开发和运维中最常用的诊断语句之一。

```sql
SHOW DATABASES [LIKE 'pattern' | WHERE expr]
SHOW TABLES [FROM db_name] [LIKE 'pattern' | WHERE expr]
SHOW [FULL] COLUMNS FROM tbl_name [FROM db_name] [LIKE 'pattern' | WHERE expr]
SHOW INDEX FROM tbl_name [FROM db_name]
SHOW CREATE TABLE tbl_name
SHOW TABLE STATUS [FROM db_name] [LIKE 'pattern' | WHERE expr]
SHOW [FULL] PROCESSLIST
SHOW [GLOBAL | SESSION] VARIABLES [LIKE 'pattern' | WHERE expr]
SHOW [GLOBAL | SESSION] STATUS [LIKE 'pattern' | WHERE expr]
SHOW GRANTS [FOR user_or_role]
SHOW WARNINGS [LIMIT [offset,] row_count]
SHOW ERRORS [LIMIT [offset,] row_count]
SHOW ENGINES
SHOW TRIGGERS [FROM db_name] [LIKE 'pattern']
```

其中 `` LIKE 'pattern' `` 支持 `` % `` 和 `` _ `` 通配符，`` WHERE expr `` 支持更灵活的过滤条件。

**SHOW DATABASES 示例：**

```sql
SHOW DATABASES;
-- 显示当前用户有权限访问的所有数据库
```

> 注意：用户只能看到有权限的数据库，除非拥有全局 `` SHOW DATABASES `` 权限。

**SHOW TABLES 示例：**

```sql
SHOW TABLES FROM learn;
SHOW TABLES LIKE '%user%';
SHOW TABLES FROM learn WHERE Tables_in_learn LIKE '%user%';
```

不加 `` FULL `` 时仅显示表名；加 `` FULL `` 会额外显示 `` BASE TABLE ``（普通表）、`` VIEW ``（视图）或 `` SYSTEM VIEW ``（系统视图）类型。

**SHOW COLUMNS / DESCRIBE 示例：**

```sql
SHOW COLUMNS FROM users;
SHOW FULL COLUMNS FROM users;
DESCRIBE users;
DESC users name;
```

| 字段 | 说明 |
|------|------|
| Field | 列名 |
| Type | 数据类型 |
| Null | YES 表示可空，NO 表示不可空 |
| Key | PRI（主键）、UNI（唯一索引）、MUL（非唯一索引第一列） |
| Default | 默认值，NULL 表示无显式默认值 |
| Extra | auto_increment、on update CURRENT_TIMESTAMP、VIRTUAL GENERATED 等 |
| Collation | 字符集排序规则（需 FULL 关键字） |
| Privileges | 当前用户的列级权限（需 FULL 关键字） |
| Comment | 列注释（需 FULL 关键字） |

> `` Key `` 列注意：若唯一索引包含 NULL 值，显示为 `` MUL `` 而非 `` UNI ``，因为唯一索引允许多个 NULL；复合唯一索引的每一列都显示为 `` MUL ``。

**SHOW INDEX 示例：**

```sql
SHOW INDEX FROM users;
SHOW EXTENDED INDEX FROM users;
```

| 字段 | 说明 |
|------|------|
| Table | 表名 |
| Non_unique | 0=唯一索引，1=非唯一索引 |
| Key_name | 索引名，主键始终为 PRIMARY |
| Seq_in_index | 列在索引中的序号，从 1 开始 |
| Column_name | 被索引的列名；若为函数索引则为 NULL |
| Collation | A（升序）、D（降序）、NULL（未排序） |
| Cardinality | 索引中唯一值数量的估算值；执行 ANALYZE TABLE 更新 |
| Sub_part | 前缀索引长度；NULL 表示索引了整个列 |
| Null | YES=列可空，''=不可空 |
| Index_type | 索引类型：BTREE、FULLTEXT、HASH、RTREE |
| Visible | YES=对优化器可见，NO=不可见（Invisible Index） |
| Expression | 函数索引的表达式；普通索引为 NULL |

> `` Cardinality `` 是估算值，对于 InnoDB 由统计数据估算，不要求精确；该值越大，优化器越倾向于使用该索引进行 JOIN。

**SHOW CREATE TABLE 示例：**

```sql
SHOW CREATE TABLE users;
```

显示建表语句，包含完整的列定义、索引、引擎、字符集等。可用于快速复制定义或查看建表 DDL。

**SHOW TABLE STATUS 示例：**

```sql
SHOW TABLE STATUS FROM learn LIKE 'users';
```

| 字段 | 说明 |
|------|------|
| Name | 表名 |
| Engine | 存储引擎（InnoDB、MyISAM 等） |
| Row_format | 行存储格式（Dynamic、Compact、Fixed 等） |
| Rows | 行数；InnoDB 为估算值，不精确 |
| Avg_row_length | 平均行长度（字节） |
| Data_length | 聚簇索引占用的空间（InnoDB 为数据文件大小） |
| Index_length | 非聚簇索引占用空间 |
| Data_free | 已分配但未使用的空间（InnoDB 表空间级） |
| Auto_increment | 下一个 AUTO_INCREMENT 值 |
| Create_time | 建表时间 |
| Update_time | 数据文件最后修改时间（InnoDB 不准确） |
| Check_time | 最后 CHECK TABLE 时间 |

> InnoDB 的 `` Rows `` 为估算值，最多可能偏差 40%~50%；需要精确行数应使用 `` SELECT COUNT(*) ``。

**SHOW PROCESSLIST 示例：**

```sql
SHOW PROCESSLIST;
SHOW FULL PROCESSLIST;
```

| 字段 | 说明 |
|------|------|
| Id | 连接标识符，可用于 KILL 命令 |
| User | 执行操作的用户；system user 表示内部线程 |
| Host | 客户端主机名（IP:端口） |
| db | 当前默认数据库，NULL 表示未选择 |
| Command | 连接状态：Query（执行中）、Sleep（空闲）、Binlog Dump（主从复制）等 |
| Time | 线程已处于当前状态的秒数 |
| State | 当前执行阶段（如 Waiting for source to send event） |
| Info | 正在执行的 SQL 语句（无 FULL 时截断为 100 字符） |

> 有 `` PROCESS `` 权限可查看所有连接；否则只能看自己的。连接数满时，拥有 `` CONNECTION_ADMIN `` 权限的账户仍保留一个专属连接可用。

**SHOW VARIABLES 示例：**

```sql
SHOW VARIABLES;
SHOW VARIABLES LIKE 'max_connect%';
SHOW GLOBAL VARIABLES LIKE 'innodb_buffer_pool_size';
```

- 无修饰符：默认显示当前会话的变量值
- `` SESSION ``：显示当前连接的变量值
- `` GLOBAL ``：显示服务器级别的初始值（供新连接使用）

**SHOW STATUS 示例：**

```sql
SHOW STATUS;
SHOW STATUS LIKE 'Threads%';
SHOW GLOBAL STATUS LIKE 'Connections';
```

常见变量：

| 变量 | 说明 |
|------|------|
| Threads_connected | 当前打开的连接数 |
| Threads_running | 当前正在执行的连接数 |
| Questions | 服务器启动以来处理的查询总数 |
| Connections | 尝试连接的总次数 |
| Aborted_connects | 失败的连接尝试次数 |
| Table_locks_immediate | 立即获得的表锁次数 |
| Table_locks_waited | 需要等待的表锁次数（值越大竞争越严重） |

**SHOW WARNINGS / SHOW ERRORS 示例：**

```sql
INSERT INTO users (name, email, age) VALUES ('TestUser', 'test@example.com', 300);
SHOW WARNINGS;
-- Level: Warning  Code: 1264  Message: Out of range value for column 'age' at row 1

SHOW COUNT(*) WARNINGS;
SELECT @@warning_count;
```

| 字段 | 说明 |
|------|------|
| Level | 消息级别：Note、Warning、Error |
| Code | MySQL 错误码 |
| Message | 具体提示信息 |

> `` SHOW WARNINGS `` 显示最近一条 SQL 产生的所有警告和提示；`` SHOW ERRORS `` 仅显示错误，不含警告。`` max_error_count `` 控制服务器存储的消息数量上限。

**SHOW ENGINES 示例：**

```sql
SHOW ENGINES;
```

显示服务器支持的存储引擎及当前状态（DEFAULT 表示默认引擎）。

**SHOW TRIGGERS 示例：**

```sql
SHOW TRIGGERS FROM learn LIKE '%user%';
```

显示当前数据库或指定数据库中的所有触发器列表。

---

## 五、账户管理语句

### 5.1 CREATE USER
`` CREATE USER `` 用于在 MySQL 中创建新账户，可设置密码、密码过期策略、账户锁定状态等。
```sql
CREATE USER [IF NOT EXISTS]
    user [auth_option]...
    [DEFAULT ROLE role [, role]...]
    [PASSWORD EXPIRE INTERVAL n DAY | PASSWORD EXPIRE NEVER]
    [ACCOUNT {LOCK | UNLOCK}]
```

| 子句 | 说明 |
|------|------|
| `` user `` | 格式为 `` 'username'@'host' ``，host 省略默认为 % |
| `` IDENTIFIED BY 'pass' `` | 创建用户并设置密码 |
| `` IDENTIFIED BY RANDOM PASSWORD `` | 创建用户并生成随机密码 |
| `` DEFAULT ROLE `` | 设置默认激活的角色 |
| `` PASSWORD EXPIRE INTERVAL n DAY `` | 密码 n 天后过期 |
| `` PASSWORD EXPIRE NEVER `` | 密码永不过期 |
| `` ACCOUNT LOCK | UNLOCK `` | 账户锁定或解锁 |
| `` [IF NOT EXISTS] `` | 已存在时仅警告而非报错 |

**CREATE USER 示例：**

```sql
CREATE USER 'alice'@'localhost' IDENTIFIED BY 'Alice@123';
CREATE USER 'bob'@'%' IDENTIFIED BY 'Bob@456' ACCOUNT LOCK;
```

---

### 5.2 ALTER USER
`` ALTER USER `` 用于修改已有账户的属性，包括密码、过期策略、锁定状态等。
```sql
ALTER USER [IF EXISTS]
    user [auth_option]...
    [DEFAULT ROLE role [, role]...]
    [PASSWORD EXPIRE INTERVAL n DAY | PASSWORD EXPIRE NEVER]
    [ACCOUNT {LOCK | UNLOCK}]
```

| 子句 | 说明 |
|------|------|
| 所有选项语义与 `` CREATE USER `` 相同 | |

**ALTER USER 示例：**

```sql
ALTER USER 'alice'@'localhost' IDENTIFIED BY 'NewAlice@789';
ALTER USER 'bob'@'%' PASSWORD EXPIRE INTERVAL 30 DAY;
ALTER USER 'bob'@'%' ACCOUNT UNLOCK;
```

---

### 5.3 DROP USER
`` DROP USER `` 用于删除 MySQL 账户，同时移除其所有权限。
```sql
DROP USER [IF EXISTS] user [, user]...
```

| 子句 | 说明 |
|------|------|
| `` [IF EXISTS] `` | 账户不存在时不报错 |

**DROP USER 示例：**

```sql
DROP USER IF EXISTS 'temp_user'@'localhost';
```

---

### 5.4 RENAME USER
`` RENAME USER `` 用于重命名 MySQL 账户，原账户持有的权限自动转移到新账户名下。
```sql
RENAME USER old_user TO new_user [, old_user TO new_user]...
```

| 子句 | 说明 |
|------|------|
| `` old_user TO new_user `` | 重命名一个账户 |
| `` 逗号分隔 `` | 可同时重命名多个账户 |

**RENAME USER 示例：**

```sql
RENAME USER 'old_name'@'localhost' TO 'new_name'@'localhost';
```

---

### 5.5 CREATE ROLE / DROP ROLE
角色是一组权限的命名集合，便于批量管理和授予权限。
```sql
CREATE ROLE [IF NOT EXISTS] role [, role]...
DROP ROLE [IF EXISTS] role [, role]...
```

| 子句 | 说明 |
|------|------|
| `` CREATE ROLE `` | 创建角色（默认为锁定状态） |
| `` DROP ROLE `` | 删除角色（同时撤销该角色授予的所有账户） |

**CREATE ROLE 示例：**

```sql
CREATE ROLE 'developer', 'analyst';
CREATE ROLE IF NOT EXISTS 'admin';
```

**DROP ROLE 示例：**

```sql
DROP ROLE IF EXISTS 'admin';
```

---

### 5.6 GRANT
`` GRANT `` 用于向账户或角色授予权限，支持库级、表级、列级权限控制。
```sql
GRANT
    priv_type [(column_list)] [, priv_type [(column_list)]]...
    ON [OBJECT_TYPE] priv_level
    TO user [auth_option]...
    [WITH GRANT OPTION]
GRANT role [, role]... TO user [, user]...
    [WITH ADMIN OPTION]
```

| 子句 | 说明 |
|------|------|
| `` priv_type `` | 权限类型，如 SELECT、INSERT、UPDATE、ALL PRIVILEGES |
| `` (column_list) `` | 列级权限，逗号分隔多列 |
| `` priv_level `` | 权限范围，*.*（全局）、db.*（库级）、db.tbl（表级） |
| `` WITH GRANT OPTION `` | 允许被授权者继续向他人授予相同权限 |

**GRANT 示例：**

```sql
GRANT 'developer' TO 'alice'@'localhost';
GRANT SELECT, INSERT ON *.* TO 'bob'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'dev'@'localhost' WITH GRANT OPTION;
```

---

### 5.7 REVOKE
`` REVOKE `` 用于撤销账户或角色的权限，与 `` GRANT `` 对应。
```sql
REVOKE
    priv_type [(column_list)] [, priv_type [(column_list)]]...
    ON [OBJECT_TYPE] priv_level
    FROM user [, user]...
REVOKE [, role [, role]...] FROM user [, user]...
REVOKE ALL [PRIVILEGES], GRANT OPTION FROM user [, user]...
```

| 子句 | 说明 |
|------|------|
| 第一种语法 | 撤销指定权限 |
| 第二种语法 | 撤销角色 |
| 第三种语法 | 撤销所有权限和授权传递权 |

**REVOKE 示例：**

```sql
REVOKE INSERT ON *.* FROM 'bob'@'%';
REVOKE 'developer' FROM 'alice'@'localhost';
```

---

### 5.8 SET PASSWORD
`` SET PASSWORD `` 用于修改当前用户或其他账户的密码。
```sql
SET PASSWORD [FOR user] = 'auth_string'
SET PASSWORD [FOR user] = RANDOM
```

| 子句 | 说明 |
|------|------|
| 不指定 `` FOR user `` | 修改当前会话用户密码 |
| 指定 `` FOR user `` | 修改指定账户密码（需相应权限） |
| `` = RANDOM `` | 生成随机密码 |

**SET PASSWORD 示例：**

```sql
SET PASSWORD = 'NewPass@2026';
SET PASSWORD FOR 'alice'@'localhost' = 'AliceNew@456';
```

---

### 5.9 SET ROLE / SET DEFAULT ROLE
角色需激活后才生效，`` SET ROLE `` 控制会话级激活，`` SET DEFAULT ROLE `` 控制账户级默认角色。
```sql
SET ROLE {role [, role]... | NONE}
SET DEFAULT ROLE {role [, role]... | NONE} TO user
```

| 子句 | 说明 |
|------|------|
| `` SET ROLE role `` | 激活指定角色（仅在当前会话有效） |
| `` SET ROLE ALL `` | 激活账户所有已授予的角色 |
| `` SET ROLE DEFAULT `` | 激活默认角色 |
| `` SET ROLE NONE `` | 禁用所有角色 |
| `` SET DEFAULT ROLE role TO user `` | 设置用户的默认角色（需管理员权限） |

**SET ROLE 示例：**

```sql
SET ROLE 'test_dev';
SELECT CURRENT_ROLE();
SET ROLE DEFAULT;
SELECT CURRENT_ROLE();
SET ROLE NONE;
SELECT CURRENT_ROLE();
```

---

### 5.10 SHOW GRANTS / SHOW CREATE USER
`` SHOW GRANTS `` 查看账户的权限信息；`` SHOW CREATE USER `` 查看账户的创建语句。
```sql
SHOW GRANTS [FOR user]
SHOW CREATE USER user
```

| 子句 | 说明 |
|------|------|
| `` SHOW GRANTS `` | 不指定 `` FOR `` 时查看当前用户权限 |
| `` SHOW GRANTS FOR 'user'@'host' `` | 查看指定账户的完整权限 |
| `` SHOW CREATE USER `` | 显示创建账户的完整 DDL 语句 |

**SHOW GRANTS 示例：**

```sql
SHOW GRANTS FOR 'alice'@'localhost';
```

**SHOW CREATE USER 示例：**

```sql
SHOW CREATE USER "bob"@'%';
```
