---
title: "[标准库] std::fs 文件系统操作介绍与实战"
published: true
layout: post
date: 2026-05-28 11:00:00
permalink: /rust/std-fs.html
tags:
  - 文件读写
  - 目录遍历
  - 元数据查询
  - 权限管理
  - 符号链接
categories:
  - Rust
---

文件系统是应用程序持久化数据的主要通道。`std::fs` 提供了 Rust 跨平台的文件系统操作接口：从读写单个文件、遍历目录树，到查询元数据、管理权限和创建链接，所有常见操作都在这一模块中完成。与直接调用系统调用相比，`std::fs` 在 `io::Result` 的包装下统一了 `Linux`、`macOS`、`Windows` 的行为差异，同时通过 `OpenOptions` 提供了对文件打开模式的精确控制。文件系统操作天然存在 `TOCTOU`（`time-of-check time-of-use`）竞态窗口——"检查文件是否存在然后创建"这类两步操作在并发环境下并不安全，`std::fs` 提供的 `File::create_new` 等原子操作可规避这一问题。

## 一、模块概览

`std::fs` 的主要组件如下：

| 组件 | 类型 | 说明 |
|------|------|------|
| `read` / `read_to_string` / `write` | `fn` | 单次读写文件的便捷函数 |
| `copy` / `rename` / `remove_file` | `fn` | 文件管理操作 |
| `create_dir` / `create_dir_all` | `fn` | 创建目录 |
| `remove_dir` / `remove_dir_all` | `fn` | 删除目录（后者递归删除） |
| `read_dir` | `fn` | 返回目录条目迭代器 |
| `metadata` / `symlink_metadata` | `fn` | 查询文件或目录元信息 |
| `canonicalize` / `exists` | `fn` | 路径规范化与存在性检查 |
| `hard_link` / `read_link` | `fn` | 硬链接创建与符号链接目标读取 |
| `set_permissions` | `fn` | 修改文件或目录权限 |
| `File` | `struct` | 已打开文件的句柄，实现 `Read` / `Write` / `Seek` |
| `OpenOptions` | `struct` | 文件打开模式构建器 |
| `Metadata` | `struct` | 文件元数据（大小、类型、时间戳等） |
| `FileType` | `struct` | 文件类型（普通文件 / 目录 / 符号链接） |
| `Permissions` | `struct` | 文件权限表示 |
| `DirEntry` | `struct` | `ReadDir` 迭代器的单条目类型 |
| `ReadDir` | `struct` | 目录条目迭代器 |
| `FileTimes` | `struct` | 文件时间戳修改构建器 |
| `DirBuilder` | `struct` | 带选项的目录创建构建器 |

## 二、便捷读写函数

`std::fs` 提供三个不需要手动管理文件句柄的便捷函数，适合一次性读写小文件。

### 2.1 write

**语法：**

```rust
fn write(path: impl AsRef<Path>, contents: impl AsRef<[u8]>) -> io::Result<()>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `path` | - | 文件路径；文件不存在时自动创建，已存在时截断清空 |
| `contents` | - | 写入内容；接受 `&str`、`&[u8]`、`Vec<u8>` 等任意实现 `AsRef<[u8]>` 的类型 |

`write` 等价于 `OpenOptions::new().write(true).create(true).truncate(true).open(path)` 加 `write_all`。父目录不存在时返回错误，不会自动创建。

### 2.2 read 与 read_to_string

**语法：**

```rust
fn read(path: impl AsRef<Path>) -> io::Result<Vec<u8>>
fn read_to_string(path: impl AsRef<Path>) -> io::Result<String>
```

`read` 返回原始字节 `Vec<u8>`，适合读取图片、序列化数据等二进制文件；`read_to_string` 在返回 `String` 之前对全部字节执行 `UTF-8` 校验，遇到无效字节时返回 `InvalidData` 错误。两者均将整个文件一次性加载入内存——对于大文件，应改用 `BufReader` 逐行或逐块处理。

```rust
use std::fs;
use std::io;

fn main() -> io::Result<()> {
    fs::write("/tmp/demo.txt", "Hello, std::fs!\n第二行内容\n")?;

    let bytes = fs::read("/tmp/demo.txt")?;
    println!("字节数: {}", bytes.len());

    let text = fs::read_to_string("/tmp/demo.txt")?;
    println!("内容:\n{text}");

    // write 对已有文件执行截断覆写
    fs::write("/tmp/demo.txt", b"overwritten")?;
    println!("覆写后: {}", fs::read_to_string("/tmp/demo.txt")?);

    fs::remove_file("/tmp/demo.txt")?;
    Ok(())
}
```

运行结果：

```
字节数: 32
内容:
Hello, std::fs!
第二行内容

覆写后: overwritten
```

> 三个便捷函数在每次调用时都会重新打开和关闭文件。频繁调用（如循环内追加日志）会产生大量系统调用开销，此时应保持 `File` 句柄打开并复用。

## 三、File 与 OpenOptions

`File::open` 和 `File::create` 是两个最常用的快捷构造函数，`OpenOptions` 则提供对打开模式的完整控制。

### 3.1 File 的三个构造函数

**语法：**

```rust
fn File::open(path: impl AsRef<Path>) -> io::Result<File>
fn File::create(path: impl AsRef<Path>) -> io::Result<File>
fn File::create_new(path: impl AsRef<Path>) -> io::Result<File>  // Rust 1.77.0
```

| 函数 | 等效 OpenOptions | 说明 |
|------|-----------------|------|
| `File::open` | `read(true)` | 只读打开；文件不存在时返回 `NotFound` |
| `File::create` | `write(true).create(true).truncate(true)` | 创建或截断；结果始终是空文件 |
| `File::create_new` | `write(true).create_new(true)` | 原子性创建；文件已存在时返回 `AlreadyExists` |

> `File::create` 是危险的：对已有文件调用会**静默清空**其内容。若只想写入新文件而不意外破坏已有文件，应使用 `File::create_new`（`Rust 1.77.0` 起稳定）。

### 3.2 OpenOptions

**语法：**

```rust
OpenOptions::new()
    .read(bool)
    .write(bool)
    .append(bool)
    .truncate(bool)
    .create(bool)
    .create_new(bool)
    .open(path: impl AsRef<Path>) -> io::Result<File>
```

**选项说明：**

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `read(bool)` | `false` | 允许从文件读取 |
| `write(bool)` | `false` | 允许向文件写入；写指针初始位于文件头 |
| `append(bool)` | `false` | 追加模式；每次写入前内核将写指针原子性地移至末尾 |
| `truncate(bool)` | `false` | 打开时将文件截断为空；需同时启用 `write(true)` |
| `create(bool)` | `false` | 文件不存在时创建；已存在则直接打开，不截断 |
| `create_new(bool)` | `false` | 原子性创建：文件不存在时创建并独占打开；已存在时返回 `AlreadyExists` |

`write` 与 `append` 的核心区别：`write` 打开时写指针在文件头，若不截断会覆盖已有字节；`append` 由内核保证每次写入追加到末尾，在多进程日志写入场景下比 `write + seek_to_end` 更安全，因为后者在 `seek` 和 `write` 之间存在竞态窗口。

```rust
use std::fs::{self, OpenOptions};
use std::io::{self, BufRead, BufReader, Write};

fn main() -> io::Result<()> {
    let path = "/tmp/opts.txt";

    // 创建并写入
    let mut f = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(path)?;
    writeln!(f, "line1")?;

    // 追加两行
    let mut f = OpenOptions::new().append(true).open(path)?;
    writeln!(f, "line2")?;
    writeln!(f, "line3")?;

    // 逐行读取
    let f = fs::File::open(path)?;
    for (i, line) in BufReader::new(f).lines().enumerate() {
        println!("[{}] {}", i + 1, line?);
    }

    fs::remove_file(path)?;
    Ok(())
}
```

运行结果：

```
[1] line1
[2] line2
[3] line3
```

## 四、目录操作

### 4.1 create_dir 与 create_dir_all

**语法：**

```rust
fn create_dir(path: impl AsRef<Path>) -> io::Result<()>
fn create_dir_all(path: impl AsRef<Path>) -> io::Result<()>
```

| 函数 | 父目录不存在时 | 目录已存在时 |
|------|--------------|------------|
| `create_dir` | 返回 `NotFound` 错误 | 返回 `AlreadyExists` 错误 |
| `create_dir_all` | 递归创建所有缺失的父目录 | 静默成功，幂等操作 |

`create_dir_all` 的幂等性使它可在启动代码中安全地重复调用，常见于初始化日志目录、缓存目录等场景。

### 4.2 read_dir 与 DirEntry

**语法：**

```rust
fn read_dir(path: impl AsRef<Path>) -> io::Result<ReadDir>
```

`ReadDir` 实现 `Iterator<Item = io::Result<DirEntry>>`，每个条目包装在 `Result` 中——这是因为在迭代过程中，单个条目的读取也可能失败（如权限拒绝）。

`DirEntry` 的主要方法：

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `path()` | `PathBuf` | 条目的完整路径 |
| `file_name()` | `OsString` | 条目名称（不含父目录部分） |
| `file_type()` | `io::Result<FileType>` | 文件类型；在部分平台上可避免额外的 `stat` 系统调用 |
| `metadata()` | `io::Result<Metadata>` | 完整元数据 |

> `read_dir` 返回的顺序由操作系统决定，不保证字母序。若需排序，必须先 `collect` 成 `Vec` 再排序。

### 4.3 remove_dir 与 remove_dir_all

**语法：**

```rust
fn remove_dir(path: impl AsRef<Path>) -> io::Result<()>
fn remove_dir_all(path: impl AsRef<Path>) -> io::Result<()>
```

`remove_dir` 只能删除**空目录**，否则返回 `DirectoryNotEmpty` 错误（`Rust 1.83.0` 起稳定该变体，此前为 `Other`）。`remove_dir_all` 递归删除整个目录树，相当于 `rm -rf`，操作不可逆，调用前务必确认路径正确。

```rust
use std::fs;
use std::io;

fn main() -> io::Result<()> {
    // 递归创建目录树
    fs::create_dir_all("/tmp/app/data/cache")?;
    fs::write("/tmp/app/data/a.txt", "file a")?;
    fs::write("/tmp/app/data/b.txt", "file b")?;
    fs::write("/tmp/app/data/cache/c.txt", "cached")?;

    // 遍历 data 目录
    println!("data 目录内容:");
    let mut entries: Vec<_> = fs::read_dir("/tmp/app/data")?
        .filter_map(|e| e.ok())
        .collect();
    entries.sort_by_key(|e| e.file_name());
    for e in &entries {
        let ft = e.file_type()?;
        let kind = if ft.is_dir() { "dir " } else { "file" };
        println!("  [{kind}] {}", e.file_name().to_string_lossy());
    }

    // remove_dir 拒绝非空目录
    match fs::remove_dir("/tmp/app/data") {
        Err(e) => println!("remove_dir 非空目录: {:?}", e.kind()),
        Ok(()) => unreachable!(),
    }

    // remove_dir_all 递归删除
    fs::remove_dir_all("/tmp/app")?;
    println!("remove_dir_all 完成");
    println!("目录存在: {}", fs::exists("/tmp/app")?);

    Ok(())
}
```

运行结果：

```
data 目录内容:
  [file] a.txt
  [file] b.txt
  [dir ] cache
remove_dir 非空目录: DirectoryNotEmpty
remove_dir_all 完成
目录存在: false
```

## 五、元数据查询

### 5.1 metadata 与 symlink_metadata

**语法：**

```rust
fn metadata(path: impl AsRef<Path>) -> io::Result<Metadata>
fn symlink_metadata(path: impl AsRef<Path>) -> io::Result<Metadata>
```

两者的区别在于对符号链接的处理：`metadata` 跟随符号链接，返回**链接目标**的元数据；`symlink_metadata` 不跟随，返回**链接文件本身**的元数据（此时 `is_symlink()` 为 `true`）。

### 5.2 Metadata 方法一览

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `is_file()` | `bool` | 是否为普通文件 |
| `is_dir()` | `bool` | 是否为目录 |
| `is_symlink()` | `bool` | 是否为符号链接（需通过 `symlink_metadata` 获取才有意义） |
| `len()` | `u64` | 文件字节数；目录大小含义因平台而异 |
| `permissions()` | `Permissions` | 文件权限 |
| `file_type()` | `FileType` | 精确的文件类型信息 |
| `modified()` | `io::Result<SystemTime>` | 最后修改时间；不是所有平台都支持 |
| `accessed()` | `io::Result<SystemTime>` | 最后访问时间；`Linux` 可通过 `noatime` 挂载选项禁用更新 |
| `created()` | `io::Result<SystemTime>` | 文件创建时间；大多数 `Linux` 文件系统不支持，返回 `Unsupported` |

```rust
use std::fs;
use std::io;
use std::time::{SystemTime, UNIX_EPOCH};

fn main() -> io::Result<()> {
    let path = "/tmp/meta.txt";
    fs::write(path, "metadata demo content")?;

    let meta = fs::metadata(path)?;
    println!("是文件:   {}", meta.is_file());
    println!("是目录:   {}", meta.is_dir());
    println!("大小:     {} 字节", meta.len());
    println!("只读:     {}", meta.permissions().readonly());

    if let Ok(t) = meta.modified() {
        let secs = t.duration_since(UNIX_EPOCH).unwrap().as_secs();
        println!("修改时间: Unix 时间戳 {secs}");
    }

    // 目录元数据
    let dir_meta = fs::metadata("/tmp")?;
    println!("/tmp 是目录: {}", dir_meta.is_dir());
    println!("/tmp 只读:   {}", dir_meta.permissions().readonly());

    fs::remove_file(path)?;
    Ok(())
}
```

运行结果：

```
是文件:   true
是目录:   false
大小:     21 字节
只读:     false
修改时间: Unix 时间戳 1779961294
/tmp 是目录: true
/tmp 只读:   false
```

> 修改时间的具体数值在每次运行时不同，此处仅展示格式。

## 六、文件管理操作

### 6.1 copy

**语法：**

```rust
fn copy(from: impl AsRef<Path>, to: impl AsRef<Path>) -> io::Result<u64>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `from` | - | 源文件路径 |
| `to` | - | 目标文件路径；不存在时创建，已存在时覆写 |

返回值为复制的字节数。`copy` 同时复制文件内容和权限位，但不复制时间戳。在 `Linux` 上底层使用 `copy_file_range` 系统调用，可在内核态完成数据传输而无需经过用户空间缓冲区。

### 6.2 rename

**语法：**

```rust
fn rename(from: impl AsRef<Path>, to: impl AsRef<Path>) -> io::Result<()>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `from` | - | 源路径 |
| `to` | - | 目标路径；若已存在则原子性替换（同一文件系统内） |

`rename` 在同一文件系统内是原子操作，要么成功要么失败，不会出现"目标文件只写了一半"的中间状态。跨文件系统移动时会退化为复制后删除，不再是原子操作。

### 6.3 remove_file、exists 与 canonicalize

**语法：**

```rust
fn remove_file(path: impl AsRef<Path>) -> io::Result<()>
fn exists(path: impl AsRef<Path>) -> io::Result<bool>       // Rust 1.81.0
fn canonicalize(path: impl AsRef<Path>) -> io::Result<PathBuf>
```

| 函数 | 说明 |
|------|------|
| `remove_file` | 删除文件；路径为目录时返回错误 |
| `exists` | 检查路径是否存在；返回 `Ok(false)` 而非 `Err`（路径不存在本身不是错误） |
| `canonicalize` | 解析所有 `..`、`.` 和符号链接，返回绝对路径；路径必须实际存在 |

```rust
use std::fs;
use std::io;

fn main() -> io::Result<()> {
    fs::write("/tmp/src.txt", "source content")?;

    // copy 返回复制的字节数
    let n = fs::copy("/tmp/src.txt", "/tmp/dst.txt")?;
    println!("复制了 {n} 字节");
    println!("目标内容: {}", fs::read_to_string("/tmp/dst.txt")?);

    // rename 是原子操作（同一文件系统内）
    fs::rename("/tmp/dst.txt", "/tmp/renamed.txt")?;
    println!("dst.txt 存在:     {}", fs::exists("/tmp/dst.txt")?);
    println!("renamed.txt 存在: {}", fs::exists("/tmp/renamed.txt")?);

    // canonicalize 解析符号链接并返回绝对路径
    let canon = fs::canonicalize("/tmp/renamed.txt")?;
    println!("规范化路径: {}", canon.display());

    // exists 检查路径是否存在（Rust 1.81.0 稳定）
    println!("不存在的文件: {}", fs::exists("/tmp/no_such_file.txt")?);

    fs::remove_file("/tmp/src.txt")?;
    fs::remove_file("/tmp/renamed.txt")?;
    Ok(())
}
```

运行结果：

```
复制了 14 字节
目标内容: source content
dst.txt 存在:     false
renamed.txt 存在: true
规范化路径: /tmp/renamed.txt
不存在的文件: false
```

## 七、链接操作

`Linux` 文件系统支持两种链接：硬链接直接指向 `inode`，符号链接（软链接）存储目标路径字符串。

### 7.1 hard_link

**语法：**

```rust
fn hard_link(original: impl AsRef<Path>, link: impl AsRef<Path>) -> io::Result<()>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `original` | - | 已存在的文件路径（不能是目录） |
| `link` | - | 新硬链接路径；必须与 `original` 在同一文件系统 |

硬链接与原文件共享同一个 `inode`，因此共享数据、权限和时间戳。删除任意一个目录项不影响数据，直到所有硬链接都被删除（`inode` 的引用计数归零）时内核才真正释放磁盘块。

### 7.2 符号链接的创建与读取

创建符号链接需要平台特定的扩展，在 `std::fs` 核心 API 中没有跨平台的 `symlink` 函数：

| 平台 | 创建符号链接的函数 |
|------|-----------------|
| `Linux` / `macOS` | `std::os::unix::fs::symlink(original, link)` |
| `Windows`（文件） | `std::os::windows::fs::symlink_file(original, link)` |
| `Windows`（目录） | `std::os::windows::fs::symlink_dir(original, link)` |

`read_link` 是跨平台的，读取符号链接指向的目标路径（不解析，不跟随）：

```rust
fn read_link(path: impl AsRef<Path>) -> io::Result<PathBuf>
```

```rust
use std::fs;
use std::io;
use std::os::unix::fs::symlink;

fn main() -> io::Result<()> {
    fs::write("/tmp/original.txt", "shared inode content")?;

    // 硬链接：两个目录项指向同一个 inode
    fs::hard_link("/tmp/original.txt", "/tmp/hardlink.txt")?;
    println!("原文件:   {}", fs::read_to_string("/tmp/original.txt")?);
    println!("硬链接:   {}", fs::read_to_string("/tmp/hardlink.txt")?);

    // 写入原文件，通过硬链接读取也能看到更新
    fs::write("/tmp/original.txt", "updated content")?;
    println!("更新后硬链接: {}", fs::read_to_string("/tmp/hardlink.txt")?);

    // 符号链接：指向路径而非 inode
    symlink("/tmp/original.txt", "/tmp/symlink.txt")?;
    println!("符号链接: {}", fs::read_to_string("/tmp/symlink.txt")?);
    println!("链接目标: {}", fs::read_link("/tmp/symlink.txt")?.display());

    // symlink_metadata 返回链接本身的元数据
    let sym_meta = fs::symlink_metadata("/tmp/symlink.txt")?;
    println!("是符号链接: {}", sym_meta.is_symlink());

    fs::remove_file("/tmp/original.txt")?;
    fs::remove_file("/tmp/hardlink.txt")?;
    fs::remove_file("/tmp/symlink.txt")?;
    Ok(())
}
```

运行结果：

```
原文件:   shared inode content
硬链接:   shared inode content
更新后硬链接: updated content
符号链接: updated content
链接目标: /tmp/original.txt
是符号链接: true
```

> 符号链接删除目标文件后变为"悬空链接"（`dangling symlink`）：`fs::read_to_string` 会返回 `NotFound` 错误，而 `fs::symlink_metadata` 仍能正常返回链接自身的元数据。

## 八、权限管理

### 8.1 Permissions 与 set_permissions

**语法：**

```rust
fn set_permissions(path: impl AsRef<Path>, perm: Permissions) -> io::Result<()>
```

`Permissions` 通过 `metadata().permissions()` 获取，然后调用 `set_readonly(bool)` 修改，再通过 `set_permissions` 写回。`readonly()` 在 `Unix` 上检查所有者的写权限位（`S_IWUSR`）；`set_readonly(true)` 会清除所有用户的写权限位（`owner`、`group`、`others`），`set_readonly(false)` 仅恢复所有者的写权限位。

> 若需要 `Unix` 权限的完整控制（`chmod` 语义），应使用 `std::os::unix::fs::PermissionsExt`，它提供 `mode()` 和 `set_mode(u32)` 方法，可直接操作 `rwxrwxrwx` 权限位。

```rust
use std::fs;
use std::io;

fn main() -> io::Result<()> {
    let path = "/tmp/perm.txt";
    fs::write(path, "permission test")?;

    let mut perms = fs::metadata(path)?.permissions();
    println!("初始只读: {}", perms.readonly());

    perms.set_readonly(true);
    fs::set_permissions(path, perms)?;
    println!("设为只读后: {}", fs::metadata(path)?.permissions().readonly());

    // 只读文件无法写入
    match fs::write(path, "try overwrite") {
        Err(e) => println!("写入只读文件: {:?}", e.kind()),
        Ok(())  => println!("写入成功（意外）"),
    }

    // 恢复可写权限
    let mut perms = fs::metadata(path)?.permissions();
    perms.set_readonly(false);
    fs::set_permissions(path, perms)?;
    println!("恢复可写后: {}", fs::metadata(path)?.permissions().readonly());

    fs::remove_file(path)?;
    Ok(())
}
```

运行结果：

```
初始只读: false
设为只读后: true
写入只读文件: PermissionDenied
恢复可写后: false
```

## 九、综合实战：`CSV` 文件过滤处理

以下示例综合使用 `create_dir_all`、`OpenOptions`、`BufReader`、`metadata`、`copy`、`read_dir` 和 `remove_dir_all`，实现一个 `CSV` 文件过滤流水线：跳过注释行和空行，将有效行转为大写后写入输出文件，最后备份并汇报统计信息。

```rust
use std::fs::{self, OpenOptions};
use std::io::{self, BufRead, BufReader, Write};
use std::path::Path;

fn filter_csv(input: &Path, output: &Path) -> io::Result<u32> {
    let reader = BufReader::new(fs::File::open(input)?);
    let mut out = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(output)?;

    let mut count = 0u32;
    for line in reader.lines() {
        let line = line?;
        if line.starts_with('#') || line.trim().is_empty() {
            continue;
        }
        writeln!(out, "{}", line.to_uppercase())?;
        count += 1;
    }
    Ok(count)
}

fn main() -> io::Result<()> {
    let dir = Path::new("/tmp/csv_demo");
    fs::create_dir_all(dir)?;

    let input = dir.join("input.csv");
    let output = dir.join("output.csv");

    fs::write(&input, "# comment\nname,age\nalice,30\nbob,25\n\njane,28\n")?;
    println!("输入文件大小: {} 字节", fs::metadata(&input)?.len());

    let count = filter_csv(&input, &output)?;
    println!("处理了 {count} 行");

    let result = fs::read_to_string(&output)?;
    print!("输出内容:\n{result}");

    // 备份输出文件
    let backup = dir.join("output.csv.bak");
    fs::copy(&output, &backup)?;

    // 列出目录内容
    println!("目录内容:");
    let mut entries: Vec<_> = fs::read_dir(dir)?.filter_map(|e| e.ok()).collect();
    entries.sort_by_key(|e| e.file_name());
    for e in &entries {
        println!("  {} ({} 字节)", e.file_name().to_string_lossy(), e.metadata()?.len());
    }

    fs::remove_dir_all(dir)?;
    Ok(())
}
```

运行结果：

```
输入文件大小: 44 字节
处理了 4 行
输出内容:
NAME,AGE
ALICE,30
BOB,25
JANE,28
目录内容:
  input.csv (44 字节)
  output.csv (33 字节)
  output.csv.bak (33 字节)
```
