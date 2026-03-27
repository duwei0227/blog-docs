---
title: Python文件压缩与解压
published: true
layout: post
date: 2026-03-23 19:40:00
permalink: /python/compression.html
categories: [Python]
---

Python标准库提供了多个模块用于文件压缩和解压操作，包括 `gzip` 、 `zipfile` 和 `tarfile` 模块。本文档介绍这三个模块的核心用法。

## 一、`gzip` 模块

`gzip` 模块提供了对 gzip 格式文件的读写支持，功能类似于 GNU 应用程序 gzip 和 gunzip。数据压缩由 `zlib` 模块提供。

### 1. gzip.open() 函数

**语法格式**

```
gzip.open(filename, mode='rb', compresslevel=9, encoding=None, errors=None, newline=None)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `filename` | 文件名或文件对象 | `gzip.open('file.gz')` |
| `mode` | 模式：`'rb'`/`'wb'`/`'ab'` 等 | `mode='wb'` |
| `compresslevel` | 压缩等级（0-9） | `compresslevel=9` |
| `encoding` | 文本模式编码 | `encoding='utf-8'` |

**示例**

```python
import gzip

# 写入gzip压缩文件
content = b"Hello, World! This is a test file."
with gzip.open('test.txt.gz', 'wb') as f:
    f.write(content)

# 读取gzip压缩文件
with gzip.open('test.txt.gz', 'rb') as f:
    decompressed_data = f.read()
    print(f"解压内容: {decompressed_data}")

# 文本模式读写
with gzip.open('test.txt.gz', 'rt', encoding='utf-8') as f:
    text = f.read()
    print(f"文本内容: {text}")
```

输出：
```
解压内容: b'Hello, World! This is a test file.'
文本内容: Hello, World! This is a test file.
```

### 2. GzipFile 类

**语法格式**

```
gzip.GzipFile(filename=None, mode='rb', compresslevel=9, fileobj=None, mtime=None)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `filename` | 文件名 | `filename='test.txt'` |
| `mode` | 模式 | `mode='wb'` |
| `compresslevel` | 压缩等级 | `compresslevel=6` |
| `fileobj` | 文件对象 | `fileobj=f` |
| `mtime` | 修改时间 | `mtime=time.time()` |

**属性说明**

| 属性 | 说明 |
|------|------|
| `mtime` | 最后修改时间戳 |
| `name` | 文件路径 |
| `mode` | 读写模式 |

**示例**

```python
import gzip

# 使用GzipFile类
fileobj = open('test.txt.gz', 'wb')
gzip_file = gzip.GzipFile(
    filename='test.txt',
    mode='wb',
    compresslevel=6,
    fileobj=fileobj
)

gzip_file.write(b"Content written via GzipFile")
gzip_file.close()
fileobj.close()

# 读取并查看属性
with gzip.open('test.txt.gz', 'rb') as f:
    print(f"文件名: {f.name}")
    print(f"模式: {f.mode}")
    print(f"压缩内容: {f.read()}")
```

### 3. compress() 和 decompress() 函数

**语法格式**

```
gzip.compress(data, compresslevel=9)
gzip.decompress(data)
```

**函数说明**

| 函数 | 说明 | 示例 |
|------|------|------|
| `compress(data)` | 压缩数据 | `gzip.compress(b'data')` |
| `decompress(data)` | 解压数据 | `gzip.decompress(data)` |

**示例**

```python
import gzip

# 内存压缩
original_data = b"This is some data to compress"
compressed = gzip.compress(original_data, compresslevel=6)
print(f"原始大小: {len(original_data)} bytes")
print(f"压缩后: {len(compressed)} bytes")

# 内存解压
decompressed = gzip.decompress(compressed)
print(f"解压内容: {decompressed}")
```

## 二、`zipfile` 模块

`zipfile` 模块用于读取和写入 ZIP 格式的归档文件。

### 1. ZipFile 类

**语法格式**

```
zipfile.ZipFile(file, mode='r', compression=ZIP_STORED, allowZip64=True, ...)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `file` | 文件路径或文件对象 | `ZipFile('archive.zip')` |
| `mode` | 模式：`'r'`/`'w'`/`'a'` | `mode='w'` |
| `compression` | 压缩方式 | `compression=ZIP_DEFLATED` |
| `allowZip64` | 是否支持ZIP64 | `allowZip64=True` |

**模式说明**

| 模式 | 说明 | 示例 |
|------|------|------|
| `'r'` | 读取已存在的ZIP文件 | `mode='r'` |
| `'w'` | 创建新ZIP文件（覆盖） | `mode='w'` |
| `'a'` | 追加到已存在的ZIP文件 | `mode='a'` |
| `'x'` | 创建新ZIP文件（不存在则创建） | `mode='x'` |

**示例**

```python
import zipfile
import os

# 创建ZIP文件
with zipfile.ZipFile('test.zip', 'w') as zf:
    # 写入字符串内容
    zf.writestr('hello.txt', 'Hello, World!')
    zf.writestr('data.txt', 'Some data here')

# 读取ZIP文件
with zipfile.ZipFile('test.zip', 'r') as zf:
    print("ZIP文件内容:")
    for info in zf.infolist():
        print(f"  {info.filename}: {info.file_size} bytes")
    
    # 读取单个文件
    content = zf.read('hello.txt')
    print(f"\nhello.txt内容: {content.decode()}")

os.remove('test.zip')
```

输出：
```
ZIP文件内容:
  hello.txt: 13 bytes
  data.txt: 14 bytes

hello.txt内容: Hello, World!
```

### 2. ZipFile 读写方法

**语法格式**

```
zf.write(filename, arcname=None, compress_type=None, ...)
zf.writestr(zinfo_or_arcname, data, compress_type=None)
zf.read(name)
zf.extract(member, path=None)
zf.extractall(path=None, members=None)
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `write(filename, arcname)` | 写入文件到ZIP | `zf.write('file.txt')` |
| `writestr(zinfo, data)` | 写入字符串/字节 | `zf.writestr('a.txt', 'data')` |
| `read(name)` | 读取文件内容 | `zf.read('a.txt')` |
| `extract(member, path)` | 解压单个文件 | `zf.extract('a.txt')` |
| `extractall(path)` | 解压所有文件 | `zf.extractall('.')` |

**示例**

```python
import zipfile
import os

# 创建ZIP并写入多个文件
with zipfile.ZipFile('files.zip', 'w') as zf:
    zf.writestr('readme.txt', '这是一个README文件')
    zf.writestr('config.json', '{"name": "test", "version": 1}')
    zf.writestr('data.csv', 'id,name\n1,Alice\n2,Bob')

# 读取特定文件
with zipfile.ZipFile('files.zip', 'r') as zf:
    print("读取readme.txt:")
    print(zf.read('readme.txt').decode('utf-8'))
    
    print("\n读取config.json:")
    print(zf.read('config.json').decode('utf-8'))

os.remove('files.zip')
```

### 3. ZipInfo 对象

**语法格式**

```
zipfile.ZipInfo(filename='/', date_time=(1980,1,1,0,0,0), ...)
```

**ZipInfo属性说明**

| 属性 | 说明 | 示例 |
|------|------|------|
| `filename` | 文件名 | `info.filename` |
| `file_size` | 原始文件大小 | `info.file_size` |
| `compress_size` | 压缩后大小 | `info.compress_size` |
| `date_time` | 修改时间 | `info.date_time` |
| `compress_type` | 压缩类型 | `info.compress_type` |

**示例**

```python
import zipfile
import os

# 创建ZIP并获取ZipInfo
with zipfile.ZipFile('info.zip', 'w') as zf:
    zf.writestr('document.txt', 'Document content')

# 获取详细信息
with zipfile.ZipFile('info.zip', 'r') as zf:
    for info in zf.infolist():
        print(f"文件名: {info.filename}")
        print(f"原始大小: {info.file_size} bytes")
        print(f"压缩大小: {info.compress_size} bytes")
        print(f"压缩比: {info.file_size / info.compress_size:.1f}x")
        print(f"修改时间: {info.date_time}")

os.remove('info.zip')
```

## 三、`tarfile` 模块

`tarfile` 模块用于读取和写入 tar 归档文件，支持 gzip、bz2 和 lzma 压缩。

### 1. tarfile.open() 函数

**语法格式**

```
tarfile.open(name=None, mode='r', fileobj=None, bufsize=10240, **kwargs)
```

**mode模式说明**

| 模式 | 说明 | 示例 |
|------|------|------|
| `'r'` | 读取透明压缩文件 | `mode='r'` |
| `'r:'` | 读取未压缩tar | `mode='r:'` |
| `'r:gz'` | 读取gzip压缩tar | `mode='r:gz'` |
| `'r:bz2'` | 读取bz2压缩tar | `mode='r:bz2'` |
| `'r:xz'` | 读取xz压缩tar | `mode='r:xz'` |
| `'w'` | 写入透明压缩tar | `mode='w'` |
| `'w:gz'` | 写入gzip压缩tar | `mode='w:gz'` |
| `'w:xz'` | 写入xz压缩tar | `mode='w:xz'` |

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `name` | 文件名 | `name='archive.tar.gz'` |
| `mode` | 打开模式 | `mode='w:gz'` |
| `fileobj` | 文件对象 | `fileobj=f` |

**示例**

```python
import tarfile
import os

# 创建tar.gz归档
with tarfile.open('test.tar.gz', 'w:gz') as tf:
    # 添加字符串内容
    import io
    info = tarfile.TarInfo(name='readme.txt')
    data = b'Readme content'
    info.size = len(data)
    tf.addfile(info, io.BytesIO(data))
    
    # 添加文件（如果有的话）
    # tf.add('existing_file.txt', arcname='file.txt')

# 读取tar.gz归档
with tarfile.open('test.tar.gz', 'r:gz') as tf:
    print("归档内容:")
    for member in tf.getmembers():
        print(f"  {member.name}: {member.size} bytes")
    
    # 提取单个文件
    member = tf.getmember('readme.txt')
    f = tf.extractfile(member)
    if f:
        print(f"\nreadme.txt内容: {f.read().decode()}")

os.remove('test.tar.gz')
```

### 2. TarFile 常用方法

**语法格式**

```
tf.add(name, arcname=None, recursive=True, ...)
tf.addfile(tarinfo, fileobj=None)
tf.extract(member, path='.')
tf.extractall(path='.', members=None)
tf.getmembers()
tf.getnames()
tf.list(members=None)
```

**方法说明**

| 方法 | 说明 | 示例 |
|------|------|------|
| `add(name, arcname)` | 添加文件/目录 | `tf.add('file.txt')` |
| `addfile(tarinfo, fileobj)` | 添加TarInfo文件 | `tf.addfile(info, f)` |
| `extract(member, path)` | 解压单个文件 | `tf.extract('a.txt')` |
| `extractall(path)` | 解压所有文件 | `tf.extractall('.')` |
| `getmembers()` | 获取所有成员列表 | `tf.getmembers()` |
| `getnames()` | 获取所有成员名称 | `tf.getnames()` |
| `list(members)` | 列出成员信息 | `tf.list()` |

**示例**

```python
import tarfile
import os

# 创建tar归档
with tarfile.open('archive.tar', 'w') as tf:
    # 创建TarInfo
    info = tarfile.TarInfo(name='config.txt')
    content = b'key=value\ndebug=true'
    info.size = len(content)
    
    # 添加到归档
    import io
    tf.addfile(info, io.BytesIO(content))

# 列出归档内容
with tarfile.open('archive.tar', 'r') as tf:
    print("归档成员:")
    for m in tf.getmembers():
        print(f"  {m.name}: {m.size} bytes")
    
    # 列出详细信息
    print("\n详细信息:")
    tf.list()

os.remove('archive.tar')
```

### 3. TarInfo 对象

**语法格式**

```
tarfile.TarInfo(name='')
```

**TarInfo属性说明**

| 属性 | 说明 | 示例 |
|------|------|------|
| `name` | 文件名 | `info.name` |
| `size` | 文件大小 | `info.size` |
| `mtime` | 修改时间 | `info.mtime` |
| `type` | 文件类型 | `info.type` |
| `mode` | 文件权限 | `info.mode` |
| `uid` | 用户ID | `info.uid` |
| `gid` | 组ID | `info.gid` |

**示例**

```python
import tarfile
import os

# 创建带详细信息的tar文件
with tarfile.open('detailed.tar', 'w') as tf:
    info = tarfile.TarInfo(name='myfile.txt')
    info.size = 100
    info.mtime = 1234567890
    info.mode = 0o644
    info.uid = 1000
    info.gid = 1000
    
    import io
    tf.addfile(info, io.BytesIO(b'x' * 100))

# 读取并验证信息
with tarfile.open('detailed.tar', 'r') as tf:
    member = tf.getmember('myfile.txt')
    print(f"文件名: {member.name}")
    print(f"大小: {member.size} bytes")
    print(f"权限: {oct(member.mode)}")
    print(f"UID/GID: {member.uid}/{member.gid}")

os.remove('detailed.tar')
```

## 四、模块对比与选择

| 模块 | 用途 | 压缩格式 | 特点 |
|------|------|----------|------|
| `gzip` | 单文件压缩 | gzip | 简单高效，适合单个文件 |
| `zipfile` | ZIP归档 | ZIP | 多文件归档，可读可写 |
| `tarfile` | tar归档 | tar/gz/bz2/xz | 多文件归档，支持多种压缩 |

**选择建议**：
- 压缩单个文件使用 `gzip`
- 需要读写ZIP格式使用 `zipfile`
- 需要tar格式或多种压缩格式使用 `tarfile`
- 多文件且需要压缩可用 `tarfile` + 压缩模式