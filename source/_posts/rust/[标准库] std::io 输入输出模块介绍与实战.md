---
title: "[标准库] std::io 输入输出模块介绍与实战"
published: true
layout: post
date: 2026-05-28 15:00:00
permalink: /rust/std-io.html
tags:
  - 字节流
  - 标准输入输出
categories:
  - Rust
---

`std::io` 是 Rust 标准库的 I/O 基础层，它不面向任何具体资源，而是定义了四个通用的字节流 `trait`：`Read`（从源读取字节）、`Write`（向目标写入字节）、`Seek`（在流中移动游标）和 `BufRead`（带内部缓冲区的逐行读取）。凡是实现了这些 `trait` 的类型——文件、套接字、管道、内存缓冲区——都能无缝接入 `BufReader`、`io::copy`、`Lines` 等通用适配器，而调用方无需关心底层是什么资源。模块还提供了 `io::Error` 与 `ErrorKind`，将操作系统的数百种底层错误码规范为可精确匹配的枚举变体，是 Rust I/O 错误处理的统一入口。

## 一、模块概览

| 组件 | 类型 | 说明 |
|------|------|------|
| `Read` | `trait` | 字节源：从 reader 读取原始字节 |
| `Write` | `trait` | 字节目标：向 writer 写入原始字节 |
| `Seek` | `trait` | 流内游标移动 |
| `BufRead` | `trait` | 带内部缓冲区的 reader，支持逐行读取 |
| `BufReader<R>` | `struct` | 为任意 `Read` 类型添加读缓冲 |
| `BufWriter<W>` | `struct` | 为任意 `Write` 类型添加写缓冲 |
| `LineWriter<W>` | `struct` | 遇到换行符自动 `flush` 的写缓冲 |
| `Cursor<T>` | `struct` | 将内存缓冲区包装为可 `seek` 的 reader/writer |
| `Stdin` / `Stdout` / `Stderr` | `struct` | 进程标准输入输出流句柄 |
| `Lines<B>` | `struct` | `BufRead::lines()` 返回的行迭代器 |
| `Bytes<R>` | `struct` | `Read::bytes()` 返回的字节迭代器 |
| `Chain<T, U>` | `struct` | `Read::chain()` 返回的串联读取器 |
| `Take<R>` | `struct` | `Read::take()` 返回的限字节读取器 |
| `Empty` | `struct` | 永远返回 `EOF` 的 reader，同时丢弃所有写入 |
| `Repeat` | `struct` | 无限重复某字节的 reader |
| `Sink` | `struct` | 丢弃所有写入数据的 writer |
| `Error` | `struct` | I/O 错误类型，包含系统错误码或自定义错误 |
| `ErrorKind` | `enum` | 错误类别，用于模式匹配 |
| `Result<T>` | 类型别名 | `std::result::Result<T, io::Error>` 的缩写 |
| `copy` | `fn` | 从 reader 复制全部字节到 writer |
| `empty` / `repeat` / `sink` | `fn` | 创建占位用 reader/writer |
| `stdin` / `stdout` / `stderr` | `fn` | 获取标准流句柄 |

## 二、核心 trait

### 2.1 Read

**语法：**

```rust
pub trait Read {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize>;
    fn read_exact(&mut self, buf: &mut [u8]) -> io::Result<()>;
    fn read_to_end(&mut self, buf: &mut Vec<u8>) -> io::Result<usize>;
    fn read_to_string(&mut self, buf: &mut String) -> io::Result<usize>;
    fn bytes(self) -> Bytes<Self>;
    fn chain<R: Read>(self, next: R) -> Chain<Self, R>;
    fn take(self, limit: u64) -> Take<Self>;
}
```

**参数（主要方法）：**

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `read` | `buf: &mut [u8]` | `io::Result<usize>` | 最多读满 `buf`，返回实际读取字节数；`Ok(0)` 表示 `EOF` |
| `read_exact` | `buf: &mut [u8]` | `io::Result<()>` | 恰好读满 `buf`；字节不足时返回 `UnexpectedEof` |
| `read_to_end` | `buf: &mut Vec<u8>` | `io::Result<usize>` | 读到 `EOF`，追加到 `Vec`，返回追加的字节数 |
| `read_to_string` | `buf: &mut String` | `io::Result<usize>` | 读到 `EOF` 并进行 `UTF-8` 校验后追加到 `String` |
| `bytes` | — | `Bytes<Self>` | 转为按字节迭代的迭代器 |
| `chain` | `next: R` | `Chain<Self, R>` | 串联另一个 reader，当前 reader 耗尽后继续读 `next` |
| `take` | `limit: u64` | `Take<Self>` | 最多读取 `limit` 字节后返回 `EOF` |

`read` 与 `read_exact` 的关键差异：`read` 是**允许短读**的——即使缓冲区还有剩余空间，底层也可以只返回部分字节，在网络 `socket` 上尤为常见。`read_exact` 通过内部循环确保恰好填满缓冲区，但若在填满之前遇到 `EOF` 则返回 `UnexpectedEof`。协议解析中读取固定长度字段时应使用 `read_exact`，随机访问场景才需要手动处理短读。

```rust
use std::fs;
use std::io::{self, Read};

fn main() -> io::Result<()> {
    let path = "/tmp/read_demo.txt";
    fs::write(path, "Hello, std::io!")?;

    let mut f = fs::File::open(path)?;
    let mut buffer = [0u8; 8];

    // read 允许短读，返回实际读取字节数
    loop {
        let n = f.read(&mut buffer)?;
        if n == 0 { break; }
        println!("读取 {n} 字节: {:?}", std::str::from_utf8(&buffer[..n]).unwrap());
    }

    // read_exact 恰好读满缓冲区
    let mut f2 = fs::File::open(path)?;
    let mut exact = [0u8; 5];
    f2.read_exact(&mut exact)?;
    println!("精确读取5字节: {:?}", std::str::from_utf8(&exact).unwrap());

    fs::remove_file(path)?;
    Ok(())
}
```

运行结果：

```
读取 8 字节: "Hello, s"
读取 7 字节: "td::io!"
精确读取5字节: "Hello"
```

> 对网络流调用 `read` 时，即使传入 4096 字节的缓冲区，每次也可能只返回几十字节——这是正常行为，不是错误。必须循环调用直到收到完整的消息边界，而不能假设单次 `read` 会填满缓冲区。

### 2.2 Write

**语法：**

```rust
pub trait Write {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize>;
    fn write_all(&mut self, buf: &[u8]) -> io::Result<()>;
    fn flush(&mut self) -> io::Result<()>;
    fn write_fmt(&mut self, fmt: fmt::Arguments<'_>) -> io::Result<()>;
    fn write_vectored(&mut self, bufs: &[IoSlice<'_>]) -> io::Result<usize>;
}
```

**参数（主要方法）：**

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `write` | `buf: &[u8]` | `io::Result<usize>` | 写入部分或全部字节，返回实际写入数；允许短写 |
| `write_all` | `buf: &[u8]` | `io::Result<()>` | 循环写直到 `buf` 全部写出，或遇到非 `Interrupted` 错误 |
| `flush` | — | `io::Result<()>` | 将内部缓冲区全部刷到底层写目标 |
| `write_fmt` | `fmt::Arguments` | `io::Result<()>` | `write!` / `writeln!` 宏的底层入口 |

`write` 与 `write_all` 的关系与 `read` / `read_exact` 对称：`write` 可以写出少于请求的字节（短写），调用方必须检查返回值并重新提交剩余数据；`write_all` 封装了这一循环。大多数场景直接用 `write_all`；仅在需要精确控制已写字节数时（如非阻塞 I/O）才直接使用 `write`。

`flush` 对 `BufWriter` 等带缓冲 writer 尤为关键——若忘记调用，程序退出前最后一批积压在缓冲区的数据可能丢失。

```rust
use std::fs;
use std::io::{self, Write};

fn main() -> io::Result<()> {
    let path = "/tmp/write_demo.txt";
    let mut f = fs::File::create(path)?;

    let n = f.write(b"Hello")?;
    println!("write 写入: {n} 字节");

    f.write_all(b", world")?;
    write!(f, "\n第 {} 行", 2)?;
    f.flush()?;

    let content = fs::read_to_string(path)?;
    println!("文件内容:\n{content}");

    fs::remove_file(path)?;
    Ok(())
}
```

运行结果：

```
write 写入: 5 字节
文件内容:
Hello, world
第 2 行
```

### 2.3 Seek 与 SeekFrom

`Seek` 允许在 I/O 流中任意移动读/写游标，类似 C 的 `fseek`。

**语法：**

```rust
pub trait Seek {
    fn seek(&mut self, pos: SeekFrom) -> io::Result<u64>;
    fn rewind(&mut self) -> io::Result<()>;
    fn stream_position(&mut self) -> io::Result<u64>;
}
```

**参数：**

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `seek` | `pos: SeekFrom` | `io::Result<u64>` | 移动游标到指定位置，返回新的绝对字节偏移量 |
| `rewind` | — | `io::Result<()>` | 等价于 `seek(SeekFrom::Start(0))` |
| `stream_position` | — | `io::Result<u64>` | 返回当前游标位置（等价于 `seek(SeekFrom::Current(0))`） |

**`SeekFrom` 变体：**

| 变体 | 偏移类型 | 说明 |
|------|---------|------|
| `SeekFrom::Start(u64)` | `u64` | 从流开头计算；不能为负 |
| `SeekFrom::End(i64)` | `i64` | 从流末尾计算；负值向前，如 `-3` 表示末尾前3字节 |
| `SeekFrom::Current(i64)` | `i64` | 从当前游标位置计算；可正可负 |

```rust
use std::fs;
use std::io::{self, Read, Seek, SeekFrom};

fn main() -> io::Result<()> {
    let path = "/tmp/seek_demo.txt";
    fs::write(path, "ABCDEFGHIJ")?;  // 10 字节

    let mut f = fs::File::open(path)?;
    let mut buf = [0u8; 3];

    f.read_exact(&mut buf)?;
    println!("读取前3字节: {}", std::str::from_utf8(&buf).unwrap());
    println!("当前位置:   {}", f.stream_position()?);

    // seek(End(0)) 获取文件长度（不修改有意义的位置前先保存）
    let len = f.seek(SeekFrom::End(0))?;
    println!("文件长度:   {}", len);

    // 从末尾倒退 3 字节
    f.seek(SeekFrom::End(-3))?;
    f.read_exact(&mut buf)?;
    println!("末尾3字节:  {}", std::str::from_utf8(&buf).unwrap());

    // 相对当前位置后退 5 字节
    f.seek(SeekFrom::Current(-5))?;
    println!("后退后位置: {}", f.stream_position()?);

    // 回到开头
    f.rewind()?;
    f.read_exact(&mut buf)?;
    println!("rewind后:   {}", std::str::from_utf8(&buf).unwrap());

    fs::remove_file(path)?;
    Ok(())
}
```

运行结果：

```
读取前3字节: ABC
当前位置:   3
文件长度:   10
末尾3字节:  HIJ
后退后位置: 5
rewind后:   ABC
```

### 2.4 BufRead

`BufRead` 在 `Read` 基础上增加了内部缓冲区，使逐行读取和按字节分隔符读取成为可能。实现该 `trait` 的类型必须维护一块内部缓冲区，并通过 `fill_buf` 暴露缓冲区内容、通过 `consume` 标记已处理字节。

**语法：**

```rust
pub trait BufRead: Read {
    fn fill_buf(&mut self) -> io::Result<&[u8]>;
    fn consume(&mut self, amt: usize);
    fn read_line(&mut self, buf: &mut String) -> io::Result<usize>;
    fn lines(self) -> Lines<Self>;
    fn split(self, byte: u8) -> Split<Self>;
    fn has_data_left(&mut self) -> io::Result<bool>;
}
```

**参数（主要方法）：**

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `fill_buf` | — | `io::Result<&[u8]>` | 填充内部缓冲区，返回可读字节切片（不消费） |
| `consume` | `amt: usize` | — | 标记 `amt` 字节已处理，与 `fill_buf` 配合使用 |
| `read_line` | `buf: &mut String` | `io::Result<usize>` | 读取一行（含 `\n`）追加到 `buf`；`EOF` 时返回 `Ok(0)` |
| `lines` | — | `Lines<Self>` | 转为行迭代器；每行自动剥离末尾 `\n`（及可选 `\r`） |
| `split` | `byte: u8` | `Split<Self>` | 以指定字节分割，每段以 `Vec<u8>` 返回 |

`lines()` 与 `read_line` 的区别：`lines()` 自动剥离换行符，错误通过 `Item = io::Result<String>` 传播，适合绝大多数场景；`read_line` 保留换行符，适合需要区分 `\n` 与 `\r\n` 的精确解析。

```rust
use std::fs;
use std::io::{self, BufRead, BufReader};

fn main() -> io::Result<()> {
    let path = "/tmp/bufread_demo.txt";
    fs::write(path, "first line\nsecond line\nthird line\n")?;

    // lines() 迭代器：自动去掉 \n
    let reader = BufReader::new(fs::File::open(path)?);
    for (i, line) in reader.lines().enumerate() {
        println!("[{}] {}", i + 1, line?);
    }

    // split() 以任意字节分隔
    let reader2 = BufReader::new(fs::File::open(path)?);
    let chunks: Vec<_> = reader2
        .split(b'\n')
        .filter_map(|r| r.ok())
        .filter(|b| !b.is_empty())
        .collect();
    println!("共 {} 段", chunks.len());

    // read_line 手动循环（保留 \n）
    let mut reader3 = BufReader::new(fs::File::open(path)?);
    let mut line = String::new();
    loop {
        line.clear();
        let n = reader3.read_line(&mut line)?;
        if n == 0 { break; }
        println!("read_line: {:?}", line);
    }

    fs::remove_file(path)?;
    Ok(())
}
```

运行结果：

```
[1] first line
[2] second line
[3] third line
共 3 段
read_line: "first line\n"
read_line: "second line\n"
read_line: "third line\n"
```

## 三、缓冲适配器

### 3.1 BufReader

`BufReader<R>` 为任意 `Read` 类型添加内部缓冲区，将多次小额 `read` 系统调用合并为少数几次大块读取，显著降低系统调用开销。它同时实现了 `BufRead`，因此可以直接调用 `.lines()`。

**语法：**

```rust
pub struct BufReader<R: Read> { }

impl<R: Read> BufReader<R> {
    pub fn new(inner: R) -> BufReader<R>;
    pub fn with_capacity(capacity: usize, inner: R) -> BufReader<R>;
    pub fn capacity(&self) -> usize;
    pub fn get_ref(&self) -> &R;
    pub fn get_mut(&mut self) -> &mut R;
    pub fn buffer(&self) -> &[u8];
    pub fn into_inner(self) -> R;
}
```

**参数：**

| 方法 | 默认值 | 说明 |
|------|--------|------|
| `new(inner)` | 缓冲区 8192 字节 | 创建默认缓冲大小的 `BufReader` |
| `with_capacity(cap, inner)` | — | 指定缓冲区大小；大文件可适当增大 |
| `into_inner()` | — | 消费 `BufReader`，返回内层 reader；已缓冲但未消费的字节会丢失 |

`BufReader` 适合**顺序读取**场景。需要随机访问时，调用 `seek` 会使内部缓冲区作废并重新触发系统调用，此时应直接操作底层 `File`，不要套 `BufReader`。

```rust
use std::fs;
use std::io::{self, BufRead, BufReader};

fn main() -> io::Result<()> {
    let path = "/tmp/bufcap.txt";
    let content: String = (1..=5).map(|i| format!("Line {i}\n")).collect();
    fs::write(path, &content)?;

    let f = fs::File::open(path)?;
    let reader = BufReader::with_capacity(32, f);
    println!("缓冲区大小: {} 字节", reader.capacity());

    let mut count = 0;
    for line in reader.lines() {
        let _ = line?;
        count += 1;
    }
    println!("读取了 {count} 行");

    fs::remove_file(path)?;
    Ok(())
}
```

运行结果：

```
缓冲区大小: 32 字节
读取了 5 行
```

### 3.2 BufWriter

`BufWriter<W>` 为任意 `Write` 类型添加写缓冲，将多次小写操作积攒到缓冲区，一次性提交到底层 writer，减少系统调用次数。

**语法：**

```rust
pub struct BufWriter<W: Write> { }

impl<W: Write> BufWriter<W> {
    pub fn new(inner: W) -> BufWriter<W>;
    pub fn with_capacity(capacity: usize, inner: W) -> BufWriter<W>;
    pub fn capacity(&self) -> usize;
    pub fn get_ref(&self) -> &W;
    pub fn get_mut(&mut self) -> &mut W;
    pub fn buffer(&self) -> &[u8];
    pub fn into_inner(self) -> Result<W, IntoInnerError<BufWriter<W>>>;
    pub fn flush(&mut self) -> io::Result<()>;
}
```

**参数：**

| 方法 | 默认值 | 说明 |
|------|--------|------|
| `new(inner)` | 缓冲区 8192 字节 | 创建默认缓冲大小的 `BufWriter` |
| `with_capacity(cap, inner)` | — | 指定缓冲区大小 |
| `into_inner()` | — | 先 `flush` 再消费，返回底层 writer；`flush` 失败则返回 `IntoInnerError` |

`BufWriter` 在 `Drop` 时会尝试 `flush`，但 `Drop` 中产生的 `flush` 错误会被**静默丢弃**。若最后一批写入数据至关重要，必须手动调用 `flush()` 并处理其 `Result`，不能依赖 `drop` 隐式刷新。

```rust
use std::fs;
use std::io::{self, BufWriter, Write};

fn main() -> io::Result<()> {
    let path = "/tmp/bufwriter_demo.txt";
    let f = fs::File::create(path)?;
    let mut writer = BufWriter::new(f);

    for i in 1..=5 {
        writeln!(writer, "行 {i}: {}", "★".repeat(i))?;
    }

    // 显式 flush，确保数据落盘
    writer.flush()?;

    let content = fs::read_to_string(path)?;
    print!("{content}");

    fs::remove_file(path)?;
    Ok(())
}
```

运行结果：

```
行 1: ★
行 2: ★★
行 3: ★★★
行 4: ★★★★
行 5: ★★★★★
```

### 3.3 LineWriter

`LineWriter<W>` 是 `BufWriter` 的变体，在每次检测到 `\n` 字节后自动执行 `flush`，适合需要实时输出的场景，例如写入终端、日志转发管道。

**语法：**

```rust
pub struct LineWriter<W: Write> { }

impl<W: Write> LineWriter<W> {
    pub fn new(inner: W) -> LineWriter<W>;
    pub fn with_capacity(capacity: usize, inner: W) -> LineWriter<W>;
    pub fn into_inner(self) -> Result<W, IntoInnerError<LineWriter<W>>>;
}
```

> `stdout()` 在终端下默认即为行缓冲（`LineWriter` 语义），但当 `stdout` 被重定向到文件或管道时，Rust 进程切换为全缓冲（`BufWriter` 语义），`println!` 的输出不会逐行立即出现——这是管道中"没有输出"的常见原因。

## 四、标准输入输出

### 4.1 stdin / stdout / stderr

**语法：**

```rust
pub fn stdin()  -> Stdin
pub fn stdout() -> Stdout
pub fn stderr() -> Stderr
```

三个函数分别返回进程标准流的句柄：

| 句柄 | 默认连接 | 典型用途 |
|------|---------|---------|
| `Stdin` | 键盘 / 管道输入 | 读取用户输入、处理管道数据 |
| `Stdout` | 终端输出 | 程序正常输出 |
| `Stderr` | 终端错误输出 | 错误、警告、调试信息（不受 `>` 重定向影响） |

```rust
use std::io::{self, Write};

fn main() -> io::Result<()> {
    // 向 stderr 写入（不受 > 重定向影响）
    let mut err = io::stderr();
    writeln!(err, "[warn] 这是一条警告信息")?;

    // 向 stdout 写入
    let mut out = io::stdout();
    writeln!(out, "正常输出内容")?;
    out.flush()?;

    Ok(())
}
```

运行结果：

```
[warn] 这是一条警告信息
正常输出内容
```

### 4.2 线程安全与 lock()

`Stdin`、`Stdout`、`Stderr` 内部都持有 `Mutex`，多线程并发访问是安全的，但每次操作都需要加锁解锁。在同一线程中需要连续读写多行时，应先调用 `lock()` 一次性获取锁句柄，在持有期间省去反复加解锁的开销。

**语法：**

```rust
impl Stdin  { pub fn lock(&self) -> StdinLock<'static>; }
impl Stdout { pub fn lock(&self) -> StdoutLock<'static>; }
impl Stderr { pub fn lock(&self) -> StderrLock<'static>; }
```

`StdinLock` 实现了 `BufRead`，可直接调用 `.lines()`；`StdoutLock` / `StderrLock` 实现了 `Write`。实际交互式使用示例如下（下面用 `Cursor` 模拟 `stdin` 使代码可运行）：

```rust
use std::io::{self, BufRead, BufReader, Cursor, Write};

fn main() -> io::Result<()> {
    // 用 Cursor 模拟 stdin 输入（实际使用时替换为 io::stdin().lock()）
    let fake_stdin = Cursor::new("hello\nworld\nquit\n");
    let mut out_buf = Vec::new();

    {
        let mut out = Cursor::new(&mut out_buf);
        write!(out, "echo 模式（输入 quit 退出）:\n")?;
        for line in BufReader::new(fake_stdin).lines() {
            let line = line?;
            if line == "quit" { break; }
            writeln!(out, "> {line}")?;
        }
    }

    print!("{}", String::from_utf8(out_buf).unwrap());
    Ok(())
}
```

运行结果：

```
echo 模式（输入 quit 退出）:
> hello
> world
```


## 五、错误处理

### 5.1 io::Error 与 ErrorKind

**语法：**

```rust
pub struct Error { }

impl Error {
    pub fn new<E: Into<Box<dyn error::Error + Send + Sync>>>(
        kind: ErrorKind,
        error: E,
    ) -> Error;
    pub fn from_raw_os_error(code: i32) -> Error;
    pub fn last_os_error() -> Error;
    pub fn kind(&self) -> ErrorKind;
    pub fn raw_os_error(&self) -> Option<i32>;
    pub fn get_ref(&self) -> Option<&(dyn error::Error + Send + Sync + 'static)>;
    pub fn into_inner(self) -> Option<Box<dyn error::Error + Send + Sync + 'static>>;
}
```

**参数：**

| 方法 | 说明 |
|------|------|
| `new(kind, error)` | 创建自定义 `io::Error`，`kind` 决定类别，`error` 提供描述消息 |
| `from_raw_os_error(code)` | 从操作系统错误码（如 `ENOENT=2`）创建，`kind()` 自动推导 |
| `last_os_error()` | 读取当前线程的 `errno` 值并创建错误，适合包装 `unsafe` 系统调用 |
| `kind()` | 返回 `ErrorKind`，用于模式匹配，是跨平台区分错误类别的标准方式 |
| `raw_os_error()` | 返回底层 OS 错误码；自定义错误（通过 `new` 创建）返回 `None` |

**常用 `ErrorKind` 变体：**

| 变体 | 典型触发场景 |
|------|------------|
| `NotFound` | 文件或目录不存在（`ENOENT`） |
| `PermissionDenied` | 权限不足（`EACCES`） |
| `AlreadyExists` | 创建时目标已存在（`EEXIST`） |
| `WouldBlock` | 非阻塞操作暂时无法完成（`EAGAIN` / `EWOULDBLOCK`） |
| `InvalidInput` | 参数无效，如向只读文件写入 |
| `InvalidData` | 数据格式错误，如非 `UTF-8` 字节传给 `read_to_string` |
| `TimedOut` | 操作超时 |
| `WriteZero` | `write_all` 中 `write` 返回 `Ok(0)`，writer 拒绝写入 |
| `Interrupted` | 操作被信号中断（`EINTR`），通常应重试 |
| `UnexpectedEof` | `read_exact` 在填满缓冲区前遇到 `EOF` |
| `OutOfMemory` | 内存分配失败（`Rust 1.54.0` 起） |
| `BrokenPipe` | 向已关闭的管道写入（`EPIPE`） |
| `ConnectionRefused` | `TCP` 连接被拒绝（`ECONNREFUSED`） |
| `ConnectionReset` | 连接被对端重置（`ECONNRESET`） |
| `Other` | 不属于以上类别的其他系统错误 |

```rust
use std::fs;
use std::io::{self, ErrorKind};

fn open_and_handle(path: &str) -> io::Result<String> {
    fs::read_to_string(path).map_err(|e| {
        if e.kind() == ErrorKind::NotFound {
            io::Error::new(ErrorKind::NotFound, format!("配置文件 {path} 不存在"))
        } else {
            e
        }
    })
}

fn main() {
    let err = fs::File::open("/tmp/nonexistent_xyz.txt").unwrap_err();
    println!("ErrorKind: {:?}", err.kind());
    println!("OS 错误码: {:?}", err.raw_os_error());

    let custom = io::Error::new(ErrorKind::InvalidData, "解析失败：第3行格式错误");
    println!("自定义错误: {custom}");
    println!("自定义 kind: {:?}", custom.kind());
    println!("自定义 OS 码: {:?}", custom.raw_os_error());

    match err.kind() {
        ErrorKind::NotFound         => println!("文件不存在，请检查路径"),
        ErrorKind::PermissionDenied => println!("权限不足"),
        ErrorKind::InvalidData      => println!("数据损坏"),
        other                       => println!("其他错误: {other:?}"),
    }

    match open_and_handle("/tmp/missing_config.toml") {
        Err(e) => println!("错误: {e}"),
        Ok(s)  => println!("内容: {s}"),
    }
}
```

运行结果：

```
ErrorKind: NotFound
OS 错误码: Some(2)
自定义错误: 解析失败：第3行格式错误
自定义 kind: InvalidData
自定义 OS 码: None
文件不存在，请检查路径
错误: 配置文件 /tmp/missing_config.toml 不存在
```

## 六、实用函数

### 6.1 io::copy

**语法：**

```rust
pub fn copy<R: ?Sized, W: ?Sized>(reader: &mut R, writer: &mut W) -> io::Result<u64>
where
    R: Read,
    W: Write,
```

**参数：**

| 参数 | 说明 |
|------|------|
| `reader` | 数据源，实现 `Read` |
| `writer` | 写目标，实现 `Write` |

返回复制的总字节数。在 `Linux` 上，当 `reader` 和 `writer` 都是 `File` 时，`io::copy` 内部会尝试使用 `copy_file_range(2)` 系统调用，数据在内核态直接传输而无需经过用户空间缓冲区；当源或目标是套接字时，退而使用 `sendfile(2)`。这两种优化均对调用方透明。

```rust
use std::fs;
use std::io::{self, Cursor};

fn main() -> io::Result<()> {
    let src = "/tmp/copy_src.txt";
    let dst = "/tmp/copy_dst.txt";
    fs::write(src, "io::copy demo content")?;

    let mut reader = fs::File::open(src)?;
    let mut writer = fs::File::create(dst)?;
    let n = io::copy(&mut reader, &mut writer)?;
    println!("复制了 {n} 字节");
    println!("目标内容: {}", fs::read_to_string(dst)?);

    fs::remove_file(src)?;
    fs::remove_file(dst)?;
    Ok(())
}
```

运行结果：

```
复制了 21 字节
目标内容: io::copy demo content
```

