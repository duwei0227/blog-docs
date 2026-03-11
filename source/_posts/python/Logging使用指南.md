---
title: Python日志使用指南
published: true
layout: post
date: 2026-03-11 16:00:00
permalink: /python/logging-guide.html
categories: [Python]
---



## 1. 基本概念

**日志层级（Level）枚举值**：`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`

**常用 Handler 类枚举**：`StreamHandler`, `FileHandler`, `RotatingFileHandler`, `TimedRotatingFileHandler`


| 名称 | 解释 |
|------|------|
| **Logger** | 负责产生日志记录的对象，通常通过 `logging.getLogger(name)` 获取。日志层级（level）决定哪些记录会被处理。 |
| **Handler** | 将日志输出到不同目标（控制台、文件、网络、SMTP 等）。每个 `Handler` 也有自己的 level。 |
| **Formatter** | 定义日志记录的文本格式，常用的占位符有 `%(asctime)s`、`%(levelname)s`、`%(name)s`、`%(message)s` 等。 |
| **Filter** | 用来进一步筛选日志记录，能够基于 `logger` 名称、level 或自定义条件过滤。 |

> **日志层级（Level）**（从低到高）：`DEBUG`、`INFO`、`WARNING`、`ERROR`、`CRITICAL`。

---

### 1.1 示例 – “Hello World”

```python
import logging

# 只需要一行代码即可完成基本配置，默认输出到控制台，level 为 INFO
logging.basicConfig(level=logging.INFO)

logging.debug('这条不会显示，因为默认 level 为 INFO')
logging.info('程序启动')
logging.warning('这是一条警告')
logging.error('出现错误')
logging.critical('严重错误')
```

运行后会在终端看到 `INFO` 以上级别的日志。`



## 2. 完整的配置方式

### 2.1 `logging.basicConfig`

`basicConfig` 适合一次性配置，常用参数如下：

| 参数 | 可选枚举值 / 取值范围 | 作用 |
|------|-------------------|------|
| `level` | `logging.DEBUG`, `logging.INFO`, `logging.WARNING`, `logging.ERROR`, `logging.CRITICAL` | 根 logger 的最低级别 |
| `format` | 任意符合 `logging.Formatter` 语法的字符串，例如 `'%(asctime)s %(levelname)s %(message)s'` | 全局日志格式 |
| `datefmt` | 任意 `strftime` 格式字符串，例如 `'%Y-%m-%d %H:%M:%S'` | 日期时间的格式 |
| `filename` | 任意合法文件路径 | 若提供，则日志写入文件而非控制台 |
| `filemode` | `'a'`（追加，默认），`'w'`（覆盖），`'x'`（新建） | 文件打开模式 |
| `handlers` | `list`，元素为 `logging.Handler` 实例，如 `logging.StreamHandler()`、`logging.FileHandler('app.log')` 等 | 自定义 Handler 列表，覆盖 `filename`/`stream`|

#### 示例：日志同时写文件和控制台

```python
import logging

log_format = '%(asctime)s | %(levelname)-8s | %(name)s | %(message)s'
logging.basicConfig(
    level=logging.DEBUG,
    format=log_format,
    datefmt='%Y-%m-%d %H:%M:%S',
    handlers=[
        logging.FileHandler('app.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger('myapp')
logger.debug('调试信息')
logger.info('业务启动')
```

### 2.2 使用字典（`dictConfig`）

对于较复杂的需求，推荐 `logging.config.dictConfig`。它能够一次性声明多个 logger、handler、formatter。

#### 完整示例（控制台 + rotating file + 邮件）

```python
import logging
import logging.config

CONFIG = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'standard': {
            'format': '%(asctime)s | %(levelname)s | %(name)s | %(message)s',
            'datefmt': '%Y-%m-%d %H:%M:%S'
        },
        'simple': {
            'format': '%(levelname)s: %(message)s'
        }
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'level': 'INFO',
            'formatter': 'simple',
            'stream': 'ext://sys.stdout'
        },
        'file_rotating': {
            'class': 'logging.handlers.RotatingFileHandler',
            'level': 'DEBUG',
            'formatter': 'standard',
            'filename': 'myapp.log',
            'maxBytes': 1024*1024,  # 1 MiB
            'backupCount': 3,
            'encoding': 'utf-8'
        }
    },
    'loggers': {
        'myapp': {
            'level': 'DEBUG',
            'handlers': ['console', 'file_rotating', 'mail'],
            'propagate': False
        }
    }
}

logging.config.dictConfig(CONFIG)
logger = logging.getLogger('myapp')

logger.debug('调试信息 – 会写入文件')
logger.info('普通信息 – 只显示在控制台')
logger.error('错误信息 – 控制台、文件')
```

> 只需把 `CONFIG` 写入 JSON/YAML 文件后，用 `logging.config.fileConfig('logging.conf')` 读取即可。



## 3. 常用 Handler 说明

| Handler 类 | 典型使用场景 |
|------------|----------------|
| `StreamHandler` | 输出到标准输出/错误，最常用的控制台日志。 |
| `FileHandler` | 写入单个日志文件。 |
| `RotatingFileHandler` | 当文件大小超过阈值自动切分，适合长期服务。 |
| `TimedRotatingFileHandler` | 按时间（每天/每周）切分文件。 |

### 各 Handler 支持的常用配置参数（示例）

#### 1. `StreamHandler`
| 参数 | 可选值 / 取值范围 | 说明 |
|------|-------------------|------|
| `stream` | `sys.stdout`（默认），`sys.stderr`，任意类 file‑like 对象 | 输出目标 |
| `level` | 同 `logging` 的日志级别枚举 | 该 handler 处理的最低级别 |
| `formatter` | 任意 `logging.Formatter` 实例 | 日志格式 |

#### 2. `FileHandler`
| 参数 | 可选值 / 取值范围 | 说明 |
|------|-------------------|------|
| `filename` | 文件路径（必填） | 日志文件位置 |
| `mode` | `'a'`（追加, 默认），`'w'`（覆盖），`'x'`（新建），`'b'`（二进制） | 打开模式 |
| `encoding` | `'utf-8'`、`'utf-16'` 等 | 文件编码 |
| `delay` | `True`/`False`（默认） | 是否延迟打开文件 |
| `level`、`formatter` | 同上 | 同上 |

#### 3. `RotatingFileHandler`
| 参数 | 可选值 / 取值范围 | 说明 |
|------|-------------------|------|
| `filename` | 文件路径（必填） |
| `mode` | 同 `FileHandler` |
| `maxBytes` | 正整数，触发切分的文件大小（字节） |
| `backupCount` | 正整数，保留的旧文件个数 |
| `encoding`、`delay`、`level`、`formatter` | 同 `FileHandler` |

#### 4. `TimedRotatingFileHandler`
| 参数 | 可选值 / 取值范围 | 说明 |
|------|-------------------|------|
| `filename` | 文件路径 |
| `when` | `'S'`（秒），`'M'`（分钟），`'H'`（小时），`'D'`（天），`'midnight'`，`'W0'`‑`'W6'`（周） |
| `interval` | 正整数，时间间隔 |
| `backupCount` | 正整数，保留的旧文件个数 |
| `encoding`、`delay`、`utc`、`atTime`、`level`、`formatter` | 同上 |



### 示例：TimedRotatingFileHandler（每日切分）

```python
import logging
from logging.handlers import TimedRotatingFileHandler

handler = TimedRotatingFileHandler(
    'daily.log', when='midnight', interval=1, backupCount=7, encoding='utf-8'
)
handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s %(message)s'))

logger = logging.getLogger('daily')
logger.setLevel(logging.INFO)
logger.addHandler(handler)

logger.info('今天的日志')
```



## 4. 进阶技巧

### 4.1 为不同模块设定独立 logger

```python
# module_a.py
import logging
log = logging.getLogger('myapp.module_a')
log.debug('module_a 调试')

# module_b.py
import logging
log = logging.getLogger('myapp.module_b')
log.info('module_b 正常运行')
```

在主配置中只需为 `myapp` 设置一次，子 logger 会自动继承（除非显式覆盖）

### 4.2 使用 `extra` 传递自定义字段

```python
import logging
logger = logging.getLogger('extra_demo')
formatter = logging.Formatter('%(asctime)s %(levelname)s %(user)s %(message)s')
handler = logging.StreamHandler()
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.INFO)

logger.info('登录成功', extra={'user': 'alice'})  # 2026-03-11 16:20:40,611 INFO alice 登录成功
```

