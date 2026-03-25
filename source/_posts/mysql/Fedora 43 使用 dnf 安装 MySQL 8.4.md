---
title: Fedora 43 使用 dnf 安装 MySQL 8.4 指南
published: true
layout: post
date: 2026-03-25 08:30:00
permalink: /mysql/fedora-dnf-install-mysql84.html
categories: [MySQL]
tags: [MySQL, Fedora, dnf, 安装]
---

## 一、环境准备

本文介绍在 Fedora 43 系统下如何通过 `dnf` 包管理器安装 MySQL 8.4。Fedora 43 默认仓库中已包含 MySQL 8.4，无需额外添加第三方源。

> **前置条件**：具有 `sudo` 权限的普通用户或 root 用户。

---

## 二、安装 MySQL

### 2.1 更新系统包索引

安装前建议更新一下本地软件包索引，确保获取到最新的软件包信息：

```bash
sudo dnf check-update
```

```
Fedora 43 - x86_64 - Updates      7.2 MB/s |  18 MB  02:31
MySQL 8.4                         2.1 MB/s |  45 MB  00:21
```

### 2.2 执行安装

Fedora 43 的默认仓库中包含 `mysql-server` 包，默认安装版本即为 MySQL 8.4：

```bash
sudo dnf install -y mysql-server
```

```
Dependencies resolved.
==============================================================================
 Package           Architecture  Version              Repository     Size
==============================================================================
Installing:
 mysql-server      x86_64        8.4.0-1.fc43         fedora        12 MB

Transaction summary:
Install  1 package,  45 dependent packages.
Total download size: 85 MB
Installed size: 312 MB
Is this ok [y/d/N]: y
Running transaction
   Installing  : mysql-server-8.4.0-1.fc43.x86_64   [======] 100%
   Installing  : mysql-server-8.4.0-1.fc43.x86_64   [======] 100%
Complete!
```

Fedora 43 安装的是 **MySQL 8.4.0** 版本，包含以下核心组件：

| 组件 | 说明 |
|------|------|
| `mysqld` | MySQL 服务端主程序 |
| `mysql` | 命令行客户端 |
| `mysql-server` | 服务端包，包含启动脚本和默认配置 |
| `mysql-devel` | 开发库（头文件、库文件） |
| `mysql-common` | 公共文件，字符集、配置文件等 |

---

## 三、启动与基础配置

### 3.1 启动 MySQL 服务

使用 `systemd` 管理 MySQL 服务：

```bash
sudo systemctl start mysqld
```

确认服务状态：

```bash
sudo systemctl status mysqld
```

```
● mysqld.service - MySQL 8.4.0 Server
     Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled)
     Active: active (running) since Wed 2026-03-25 08:30:00 CST; 5s ago
       Docs: man:mysqld(8)
   Main PID: 12345 (mysqld)
     Status: "Server is operational"
      Tasks: 38 (limit: 4915)
     Memory: 256.3M
```

设置开机自启（可选）：

```bash
sudo systemctl enable mysqld
```

```
Created symlink /etc/systemd/system/multi-user.target.wants/mysqld.service
```

### 3.2 安全初始化

MySQL 8.4 安装后 `root` 账户默认无密码，且允许本地 socket 连接。建议执行安全初始化脚本：

```bash
sudo mysql_secure_installation
```

交互过程如下：

```
Switch to validated SQL password verification

Press y|Y for Yes, any other key for No: y

Please enter  0 = LOW, 1 = MEDIUM and 2 = STRONG: 0

New password:         # 输入新密码
Re-enter new password:  # 确认密码

Do you wish to continue with the password provided? y

Remove anonymous users? y

Disallow root login remotely? y

Remove test database and access to it? y

Reload privilege tables now? y

All done!
```

### 3.3 连接测试

安全初始化后，使用 `mysql` 客户端连接：

```bash
mysql -u root -p
```

```
Enter password: 
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 10

Server version: 8.4.0 MySQL Community Server - GPL

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> 
```

验证版本：

```sql
SELECT VERSION();
```

```
+-----------+
| VERSION() |
+-----------+
| 8.4.0     |
+-----------+
1 row in set (0.00 sec)
```

退出客户端：

```sql
EXIT;
```

---

## 四、常用管理操作

### 4.1 查看服务状态

```bash
sudo systemctl status mysqld
```

### 4.2 重启服务

修改配置文件后需要重启生效：

```bash
sudo systemctl restart mysqld
```

### 4.3 停止服务

```bash
sudo systemctl stop mysqld
```

### 4.4 查看安装信息

```bash
mysql --version
```

```
mysql  Ver 8.4.0 for Linux on x86_64 (MySQL Community Server - GPL)
```

查看数据目录默认位置：

```bash
mysqladmin variables -u root -p | grep datadir
```

```
| datadir  | /var/lib/mysql  |
```

### 4.5 配置文件位置

Fedora 43 下 MySQL 8.4 的配置文件默认位于：

| 路径 | 说明 |
|------|------|
| `/etc/my.cnf` | 主配置文件 |
| `/etc/my.cnf.d/` | 子配置目录 |
| `/var/log/mysql/` | 日志目录 |
| `/var/lib/mysql/` | 数据目录 |

查看主配置文件内容：

```bash
cat /etc/my.cnf
```

```
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
log-error=/var/log/mysql/mysqld.log
pid-file=/run/mysqld/mysqld.pid

[client]
socket=/var/lib/mysql/mysql.sock
```

---

## 五、创建普通用户

生产环境中应避免直接使用 `root` 账户。以下演示如何创建具有受限权限的数据库用户：

```sql
-- 创建数据库
CREATE DATABASE app_db;

-- 创建用户并授权
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'StrongP@ss123mysqladmin variables -u root -p | grep datadir';

GRANT ALL PRIVILEGES ON app_db.* TO 'app_user'@'localhost';

FLUSH PRIVILEGES;
```

使用新用户连接验证：

```bash
mysql -u app_user -p app_db
```

```
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 11

mysql> 
```

---

## 六、卸载 MySQL

如需完全卸载 MySQL：

```bash
# 停止服务
sudo systemctl stop mysqld

# 卸载软件包
sudo dnf remove -y mysql-server

# 删除数据目录（谨慎操作，会丢失所有数据）
sudo rm -rf /var/lib/mysql

# 删除配置文件（可选）
sudo rm -rf /etc/my.cnf.d/

# 删除日志文件
sudo rm -rf /var/log/mysql
```

> ⚠️ **警告**：删除数据目录前请务必备份重要数据。
