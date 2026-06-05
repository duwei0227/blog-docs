---
title: "[标准库] std::net 网络通信介绍与实战"
published: true
layout: post
date: 2026-05-28 15:00:00
permalink: /rust/std-net.html
tags:
  - TCP
  - UDP
  - Socket
  - 网络编程
  - IP地址
categories:
  - Rust
---

`std::net` 是 Rust 标准库提供的同步网络编程模块，覆盖了从 IP 地址表示到 `TCP`/`UDP` 套接字的完整接口。与 `tokio`、`async-std` 等异步框架相比，`std::net` 的每个 I/O 调用都阻塞当前线程——这使它非常适合命令行工具、测试辅助脚本或配合线程池构建的服务，无需引入异步运行时的额外开销。`std::net` 的接口是跨平台的：相同代码在 `Linux`、`macOS`、`Windows` 上均可运行，平台差异由标准库内部屏蔽。

## 一、模块概览

| 组件 | 类型 | 说明 |
|------|------|------|
| `Ipv4Addr` | `struct` | IPv4 地址，内部存储为 `[u8; 4]` |
| `Ipv6Addr` | `struct` | IPv6 地址，内部存储为 `[u16; 8]` |
| `IpAddr` | `enum` | IPv4 或 IPv6 地址的统一枚举，用于多态处理 |
| `SocketAddrV4` | `struct` | IPv4 套接字地址（IP + 端口） |
| `SocketAddrV6` | `struct` | IPv6 套接字地址（IP + 端口 + 流标签 + 作用域 ID） |
| `SocketAddr` | `enum` | V4 或 V6 套接字地址的统一枚举 |
| `TcpListener` | `struct` | TCP 服务端监听器，调用 `accept()` 得到入站连接 |
| `TcpStream` | `struct` | TCP 全双工字节流，实现 `io::Read` 和 `io::Write` |
| `UdpSocket` | `struct` | UDP 数据报套接字，支持有连接和无连接两种模式 |
| `ToSocketAddrs` | `trait` | 将字符串、元组等类型解析为一组 `SocketAddr` |
| `Shutdown` | `enum` | `TcpStream::shutdown()` 的方向参数 |
| `AddrParseError` | `struct` | IP 地址或套接字地址字符串解析失败时的错误类型 |
| `Incoming` | `struct` | `TcpListener::incoming()` 返回的无限接受迭代器 |

## 二、IP 地址

### 2.1 Ipv4Addr

**语法：**

```rust
pub fn new(a: u8, b: u8, c: u8, d: u8) -> Ipv4Addr
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `a` | - | 最高字节，即点分十进制中第一段（网络字节序） |
| `b` | - | 第二段 |
| `c` | - | 第三段 |
| `d` | - | 最低字节，第四段 |

`Ipv4Addr` 常用常量与判断方法：

| 常量 / 方法 | 说明 |
|-------------|------|
| `LOCALHOST` | `127.0.0.1` |
| `BROADCAST` | `255.255.255.255` |
| `UNSPECIFIED` | `0.0.0.0`，监听全部网卡时使用 |
| `is_loopback()` | `127.0.0.0/8` 范围内返回 `true` |
| `is_private()` | `10.0.0.0/8`、`172.16.0.0/12`、`192.168.0.0/16` 返回 `true` |
| `is_multicast()` | `224.0.0.0/4` 范围内返回 `true` |
| `is_broadcast()` | 仅 `255.255.255.255` 返回 `true` |
| `is_link_local()` | `169.254.0.0/16`（`APIPA`）返回 `true` |
| `octets()` | 返回 `[u8; 4]`，按网络字节序排列 |
| `to_ipv6_mapped()` | 转换为 `::ffff:a.b.c.d` 形式的 IPv4 映射 IPv6 地址 |

`is_private()` 实现的是 RFC 1918 定义的三个私有地址范围；`is_loopback()` 覆盖整个 `127.0.0.0/8` 而不只是 `127.0.0.1`，这两点容易被误解。

### 2.2 Ipv6Addr

**语法：**

```rust
pub fn new(a: u16, b: u16, c: u16, d: u16, e: u16, f: u16, g: u16, h: u16) -> Ipv6Addr
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `a`–`h` | - | 八个 16 位段，按网络字节序从高到低排列，对应冒号十六进制表示中的八组 |

| 常量 / 方法 | 说明 |
|-------------|------|
| `LOCALHOST` | `::1` |
| `UNSPECIFIED` | `::` |
| `is_loopback()` | 仅 `::1` 返回 `true` |
| `is_multicast()` | `ff00::/8` 范围内返回 `true` |
| `is_unicast_link_local()` | `fe80::/10` 返回 `true` |
| `segments()` | 返回 `[u16; 8]`，对应八个段 |
| `to_ipv4_mapped()` | 尝试从 IPv4 映射地址中提取 `Ipv4Addr` |

### 2.3 IpAddr 统一枚举

`IpAddr` 是 `V4(Ipv4Addr)` 和 `V6(Ipv6Addr)` 的枚举，用于编写不关心具体 IP 版本的通用代码。它也是 `SocketAddr::ip()` 的返回类型。直接从字符串解析时，Rust 会根据格式自动推断版本；用 `match` 可以分支处理两种情况。

```rust
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};

fn main() {
    let loopback = Ipv4Addr::LOCALHOST;
    let private = Ipv4Addr::new(192, 168, 1, 100);
    let broadcast = Ipv4Addr::BROADCAST;

    println!("回环地址: {}", loopback);
    println!("私有地址: {} is_private={}", private, private.is_private());
    println!("广播地址: {} is_broadcast={}", broadcast, broadcast.is_broadcast());
    println!("octets: {:?}", private.octets());

    let v6 = Ipv6Addr::new(0x2001, 0x0db8, 0, 0, 0, 0, 0, 1);
    println!("\nIPv6: {}", v6);
    println!("IPv6 回环: {} is_loopback={}", Ipv6Addr::LOCALHOST, Ipv6Addr::LOCALHOST.is_loopback());
    println!("IPv6 segments: {:?}", v6.segments());

    let addr: IpAddr = "10.0.0.1".parse().unwrap();
    println!("\n解析: {} is_ipv4={}", addr, addr.is_ipv4());

    match addr {
        IpAddr::V4(v4) => println!("匹配到 IPv4: {}", v4),
        IpAddr::V6(v6) => println!("匹配到 IPv6: {}", v6),
    }
}
```

运行结果：

```
回环地址: 127.0.0.1
私有地址: 192.168.1.100 is_private=true
广播地址: 255.255.255.255 is_broadcast=true
octets: [192, 168, 1, 100]

IPv6: 2001:db8::1
IPv6 回环: ::1 is_loopback=true
IPv6 segments: [8193, 3512, 0, 0, 0, 0, 0, 1]

解析: 10.0.0.1 is_ipv4=true
匹配到 IPv4: 10.0.0.1
```

## 三、Socket 地址

### 3.1 SocketAddr

`SocketAddr` = IP 地址 + 端口号，是网络连接的端点标识。`SocketAddrV4` 和 `SocketAddrV6` 对应两个版本，`SocketAddr` 是统一枚举。

**常用 API：**

| 方法 / 构造方式 | 说明 |
|----------------|------|
| `"127.0.0.1:8080".parse::<SocketAddr>()` | 从字符串解析，类型可由上下文推断省略 |
| `SocketAddr::from(([127, 0, 0, 1], 8080))` | 从 IP 字节数组 + 端口构造，无需先构造 `Ipv4Addr` |
| `SocketAddrV6::new(ip, port, flowinfo, scope_id)` | 构造 IPv6 地址，`flowinfo` 和 `scope_id` 通常传 `0` |
| `addr.ip()` | 返回 `IpAddr` |
| `addr.port()` | 返回 `u16` 端口 |
| `addr.set_port(p)` | 原地修改端口（需要 `mut`） |
| `addr.is_ipv4()` / `addr.is_ipv6()` | 判断版本 |

```rust
use std::net::{SocketAddr, SocketAddrV4, SocketAddrV6, Ipv4Addr, Ipv6Addr};

fn main() {
    let addr: SocketAddr = "127.0.0.1:8080".parse().unwrap();
    println!("地址: {}, IP: {}, 端口: {}", addr, addr.ip(), addr.port());
    println!("是否回环: {}", addr.ip().is_loopback());

    let v4 = SocketAddrV4::new(Ipv4Addr::new(0, 0, 0, 0), 3000);
    println!("全网卡监听地址: {}", v4);

    let v6 = SocketAddrV6::new(Ipv6Addr::LOCALHOST, 8080, 0, 0);
    println!("IPv6 地址: {}", v6);

    let from_tuple: SocketAddr = SocketAddr::from(([127, 0, 0, 1], 9000));
    println!("元组构造: {}", from_tuple);

    // 修改端口
    let mut mutable_addr: SocketAddr = "0.0.0.0:3000".parse().unwrap();
    mutable_addr.set_port(4000);
    println!("修改端口后: {}", mutable_addr);
}
```

运行结果：

```
地址: 127.0.0.1:8080, IP: 127.0.0.1, 端口: 8080
是否回环: true
全网卡监听地址: 0.0.0.0:3000
IPv6 地址: [::1]:8080
元组构造: 127.0.0.1:9000
修改端口后: 0.0.0.0:4000
```

### 3.2 ToSocketAddrs

`ToSocketAddrs` 是 `TcpStream::connect`、`TcpListener::bind`、`UdpSocket::bind` 等接口的地址参数约束，使它们能同时接受 `&str`、`String`、`SocketAddr`、`(IpAddr, u16)` 等多种类型。`&str` 或 `(&str, u16)` 形式包含主机名时会触发 DNS 解析，可能返回多个 `SocketAddr`；直接传入 `SocketAddr` 或 IP 类型则跳过 DNS。

| 类型 | 示例 | 是否触发 DNS |
|------|------|-------------|
| `&str` | `"127.0.0.1:8080"` | 仅对主机名部分 |
| `(&str, u16)` | `("localhost", 80)` | 仅对主机名部分 |
| `SocketAddr` | 直接传入 | 否 |
| `(IpAddr, u16)` | `(IpAddr::V4(...), 8080)` | 否 |
| `&[SocketAddr]` | 地址数组切片 | 否 |

> 当传入 `&[SocketAddr]` 切片时，`bind`/`connect` 会依次尝试每个地址，返回第一个成功的结果。这在同时支持 IPv4 和 IPv6 时很有用。

## 四、TCP 网络编程

### 4.1 TcpListener

**语法：**

```rust
pub fn bind<A: ToSocketAddrs>(addr: A) -> io::Result<TcpListener>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `addr` | - | 绑定地址，接受所有实现 `ToSocketAddrs` 的类型；端口为 `0` 时由 OS 自动分配 |

`TcpListener` 的常用方法：

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `accept()` | `io::Result<(TcpStream, SocketAddr)>` | 阻塞等待并接受一个入站连接 |
| `incoming()` | `Incoming<'_>` | 返回无限迭代器，每次产生 `io::Result<TcpStream>`，底层循环调用 `accept()` |
| `local_addr()` | `io::Result<SocketAddr>` | 查询自身绑定地址；端口为 `0` 时可用此方法查询实际分配的端口 |
| `set_nonblocking(bool)` | `io::Result<()>` | 设置非阻塞模式；非阻塞下 `accept()` 在无连接时返回 `WouldBlock` 错误 |
| `try_clone()` | `io::Result<TcpListener>` | 克隆监听器，多个线程可并发调用 `accept()` |

绑定 `0.0.0.0:port` 表示监听所有 IPv4 网卡；`[::]:port` 在大多数系统上同时接受 IPv4 和 IPv6 连接（由 OS 的 `IPV6_V6ONLY` 选项控制）。

### 4.2 TcpStream

**语法：**

```rust
pub fn connect<A: ToSocketAddrs>(addr: A) -> io::Result<TcpStream>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `addr` | - | 服务端地址；传入多个地址时依次尝试，返回第一个成功建立的连接 |

`TcpStream` 实现了 `io::Read` 和 `io::Write`，可直接使用 `read()`、`write_all()` 等方法。其余关键方法：

| 方法 | 说明 |
|------|------|
| `shutdown(how)` | 半关闭或全关闭；`Shutdown::Write` 发送 `FIN`，`Shutdown::Read` 停止接收，`Shutdown::Both` 全关闭 |
| `peer_addr()` | 返回对端 `SocketAddr` |
| `local_addr()` | 返回本端 `SocketAddr` |
| `set_read_timeout(Option<Duration>)` | 设置读超时；超时时 `read()` 返回 `ErrorKind::WouldBlock` |
| `set_write_timeout(Option<Duration>)` | 设置写超时 |
| `set_nodelay(bool)` | `true` 禁用 Nagle 算法，降低小包延迟，适合实时交互；`false` 启用（默认），合并小包减少网络开销 |
| `try_clone()` | 克隆流，读写端可在独立线程中各自操作 |

> `TcpStream` 没有显式 `close()` 方法——`drop` 时会自动发送 `FIN`。如需通知对方本端已发送完毕同时还能继续接收剩余数据，应调用 `shutdown(Shutdown::Write)`，这是优雅关闭连接的标准做法。

### 4.3 实战：TCP 回声服务

下面的示例在同一进程中通过线程分别运行服务端和客户端。服务端接受一个连接并原样回写每条消息；客户端发送两条消息并打印回声。用 `mpsc::sync_channel` 传递就绪信号，确保服务端在调用 `accept()` 后客户端再发起连接。

```rust
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream, Shutdown};
use std::sync::mpsc;
use std::thread;

fn handle_client(mut stream: TcpStream) -> std::io::Result<()> {
    let peer = stream.peer_addr()?;
    let mut buf = [0u8; 512];
    loop {
        match stream.read(&mut buf)? {
            0 => break,
            n => {
                stream.write_all(&buf[..n])?;
            }
        }
    }
    println!("[服务端] 断开连接: {}", peer);
    Ok(())
}

fn main() -> std::io::Result<()> {
    let listener = TcpListener::bind("127.0.0.1:0")?;
    let server_addr = listener.local_addr()?;
    println!("[服务端] 监听: {}", server_addr);

    let (ready_tx, ready_rx) = mpsc::sync_channel(1);

    let server_thread = thread::spawn(move || {
        ready_tx.send(()).unwrap();
        let (stream, peer) = listener.accept().unwrap();
        println!("[服务端] 客户端接入: {}", peer);
        handle_client(stream).unwrap();
    });

    ready_rx.recv().unwrap();

    let mut client = TcpStream::connect(server_addr)?;
    println!("[客户端] 已连接到 {}", server_addr);

    let mut buf = [0u8; 512];
    for msg in &["Hello, TCP", "Rust std::net"] {
        client.write_all(msg.as_bytes())?;
        let n = client.read(&mut buf)?;
        println!("[客户端] 回声: {}", std::str::from_utf8(&buf[..n]).unwrap());
    }

    client.shutdown(Shutdown::Both)?;
    server_thread.join().unwrap();
    Ok(())
}
```

运行结果：

```
[服务端] 监听: 127.0.0.1:44349
[客户端] 已连接到 127.0.0.1:44349
[服务端] 客户端接入: 127.0.0.1:58098
[客户端] 回声: Hello, TCP
[客户端] 回声: Rust std::net
[服务端] 断开连接: 127.0.0.1:58098
```

> 端口号由 OS 随机分配，每次运行不同。`[服务端] 客户端接入: ...` 与 `[客户端] 已连接到 ...` 两行可能以任意顺序出现，这是多线程并发输出的正常现象。

## 五、UDP 网络编程

### 5.1 UdpSocket

UDP 是无连接协议，没有握手和重传机制。`UdpSocket` 支持两种使用模式：

| 模式 | 发送 API | 接收 API | 特点 |
|------|---------|---------|------|
| 无连接 | `send_to(buf, addr)` | `recv_from(buf)` | 每次发送指定目标，每次接收获取来源地址 |
| 有连接 | `send(buf)` | `recv(buf)` | 调用 `connect()` 设置默认目标；不做真实握手，仅在内核层过滤来源 |

**语法：**

```rust
pub fn bind<A: ToSocketAddrs>(addr: A) -> io::Result<UdpSocket>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `addr` | - | 本地绑定地址，接受所有实现 `ToSocketAddrs` 的类型 |

`UdpSocket` 的常用方法：

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `send_to(buf, addr)` | `io::Result<usize>` | 发送数据报到指定地址，返回已发送字节数 |
| `recv_from(buf)` | `io::Result<(usize, SocketAddr)>` | 接收数据报，返回字节数和发送方地址 |
| `connect(addr)` | `io::Result<()>` | 设置默认目标地址，之后可用 `send`/`recv` |
| `send(buf)` | `io::Result<usize>` | 向 `connect()` 设置的地址发送数据 |
| `recv(buf)` | `io::Result<usize>` | 仅接收来自 `connect()` 地址的数据报，其他来源的包会被内核丢弃 |
| `local_addr()` | `io::Result<SocketAddr>` | 查询本地绑定地址 |
| `set_read_timeout(Option<Duration>)` | `io::Result<()>` | 设置接收超时 |
| `set_broadcast(bool)` | `io::Result<()>` | 启用/禁用广播发送 |

> UDP 数据报超过网络 `MTU`（通常约 1500 字节）会在 IP 层分片，若任一分片丢失则整个数据报丢失。实际应用中单次 UDP 负载建议控制在 1400 字节以内，为 IP/UDP 头部留出空间。

### 5.2 实战：UDP 消息收发

```rust
use std::net::UdpSocket;
use std::sync::mpsc;
use std::thread;

fn main() -> std::io::Result<()> {
    let server = UdpSocket::bind("127.0.0.1:0")?;
    let server_addr = server.local_addr()?;
    println!("[服务端] 监听: {}", server_addr);

    let (ready_tx, ready_rx) = mpsc::sync_channel(1);

    let server_thread = thread::spawn(move || -> std::io::Result<()> {
        ready_tx.send(()).unwrap();
        let mut buf = [0u8; 512];
        for _ in 0..3 {
            let (n, peer) = server.recv_from(&mut buf)?;
            let msg = std::str::from_utf8(&buf[..n]).unwrap();
            println!("[服务端] 收到来自 {} 的消息: {}", peer, msg);
            server.send_to(&buf[..n], peer)?;
        }
        Ok(())
    });

    ready_rx.recv().unwrap();

    let client = UdpSocket::bind("127.0.0.1:0")?;
    let client_addr = client.local_addr()?;
    println!("[客户端] 地址: {}", client_addr);

    let mut buf = [0u8; 512];
    for msg in &["UDP 消息 1", "UDP 消息 2", "UDP 消息 3"] {
        client.send_to(msg.as_bytes(), server_addr)?;
        let (n, from) = client.recv_from(&mut buf)?;
        let echo = std::str::from_utf8(&buf[..n]).unwrap();
        println!("[客户端] 收到来自 {} 的回声: {}", from, echo);
    }

    server_thread.join().unwrap()?;
    Ok(())
}
```

运行结果：

```
[服务端] 监听: 127.0.0.1:33778
[客户端] 地址: 127.0.0.1:35871
[服务端] 收到来自 127.0.0.1:35871 的消息: UDP 消息 1
[客户端] 收到来自 127.0.0.1:33778 的回声: UDP 消息 1
[服务端] 收到来自 127.0.0.1:35871 的消息: UDP 消息 2
[客户端] 收到来自 127.0.0.1:33778 的回声: UDP 消息 2
[服务端] 收到来自 127.0.0.1:35871 的消息: UDP 消息 3
[客户端] 收到来自 127.0.0.1:33778 的回声: UDP 消息 3
```

## 六、常见模式与注意事项

### 6.1 超时设置

所有阻塞 I/O 调用（`accept()`、`read()`、`recv_from()` 等）在不设置超时时会无限阻塞。生产代码应始终设置合理的超时：

```rust
use std::net::TcpStream;
use std::time::Duration;

fn main() {
    let stream = TcpStream::connect("127.0.0.1:8080").unwrap();
    stream.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
    stream.set_write_timeout(Some(Duration::from_secs(5))).unwrap();
}
```

> 超时触发时，`read()`/`recv_from()` 返回 `io::ErrorKind::WouldBlock`（`Windows` 上为 `TimedOut`）。应通过 `error.kind()` 区分超时和真实 I/O 错误，不能统一当作致命错误处理。

### 6.2 多连接并发模式

`TcpListener::accept()` 每次只接受一个连接。处理多个并发连接的标准模式是每接受一个连接就 `spawn` 一个线程：

```rust
use std::net::TcpListener;
use std::thread;

fn main() {
    let listener = TcpListener::bind("0.0.0.0:8080").unwrap();
    for stream in listener.incoming() {
        let stream = stream.unwrap();
        thread::spawn(move || {
            // 在独立线程中处理 stream
            drop(stream);
        });
    }
}
```

`incoming()` 是对 `accept()` 的迭代器封装，等价于 `loop { listener.accept() }`，仅在 `accept()` 返回致命错误时终止迭代。

### 6.3 TCP vs UDP 选型

| 维度 | TCP | UDP |
|------|-----|-----|
| 连接方式 | 有连接（三次握手） | 无连接 |
| 可靠性 | 保证有序、无丢失 | 不保证，可能乱序或丢失 |
| 延迟 | 相对较高（流控、重传、拥塞控制） | 低延迟 |
| 消息边界 | 无（字节流，需自行分帧） | 有（每次 `send_to` 对应一个完整数据报） |
| 适用场景 | HTTP、数据库协议、文件传输 | DNS、视频流、游戏状态同步 |

TCP 的"无消息边界"是初学者常见的陷阱：一次 `write_all("hello")` 对应的 `read()` 可能只读到 `"hel"`，剩余字节在下次调用才出现。可靠的协议设计通常使用固定长度前缀或换行符分隔标识消息边界，仅依赖单次 `read()` 读到完整消息是不安全的。

### 6.4 TCP 连接的建立与关闭

`TcpStream::connect()` 之所以可能阻塞或返回错误，是因为它在底层完成了 TCP 的**三次握手**；而 `drop` 或 `shutdown(Shutdown::Write)` 之所以"优雅"，是因为它触发了 TCP 的**四次挥手**。理解这两个过程，才能解释 4.2 节中"`drop` 时自动发送 `FIN`"以及 6.1 节中各类连接超时背后发生了什么。

#### 三次握手（建立连接）

握手的目的是让双方各自确认"我能发、你能收"和"你能发、我能收"，并交换初始序列号（`ISN`）。其中 `SYN` 是同步标志，`ACK` 是确认标志，`seq` 是本端序列号，`ack` 是期望对方下一个字节的序列号。

```
   客户端 (connect)                            服务端 (listen)
   CLOSED                                       LISTEN
      |                                            |
      |   ① SYN, seq=x                             |
      | -----------------------------------------> |
   SYN_SENT                                     SYN_RCVD
      |                                            |
      |   ② SYN + ACK, seq=y, ack=x+1              |
      | <----------------------------------------- |
      |                                            |
      |   ③ ACK, seq=x+1, ack=y+1                  |
      | -----------------------------------------> |
   ESTABLISHED                                  ESTABLISHED
      |                                            |
      |============ 全双工数据传输开始 ============|
```

- **第一次**：客户端发送 `SYN`，携带初始序列号 `x`，进入 `SYN_SENT`。对应 `connect()` 调用开始。
- **第二次**：服务端回复 `SYN + ACK`，既确认了客户端的 `SYN`（`ack=x+1`），又发送自己的序列号 `y`，进入 `SYN_RCVD`。
- **第三次**：客户端发送 `ACK`（`ack=y+1`），双方进入 `ESTABLISHED`。此时 `connect()` 返回 `Ok(TcpStream)`，`accept()` 返回对应的连接。

> 为什么必须是三次而非两次？因为只有第三次握手才能让服务端确认"客户端确实收到了我的 `SYN`"。若省略第三次，一个在网络中滞留的旧 `SYN` 重传到达服务端时，服务端会误建一个客户端早已放弃的连接，造成资源浪费。

#### 四次挥手（关闭连接）

TCP 是全双工的，每个方向的数据流需要独立关闭，因此需要四个报文。下图以客户端主动关闭为例（服务端主动关闭过程对称）：

```
   主动关闭方 (shutdown/drop)                   被动关闭方
   ESTABLISHED                                  ESTABLISHED
      |                                            |
      |   ① FIN, seq=u                             |
      | -----------------------------------------> |
   FIN_WAIT_1                                   CLOSE_WAIT
      |                                            |
      |   ② ACK, ack=u+1                           |
      | <----------------------------------------- |
   FIN_WAIT_2                                       |  （仍可继续发送剩余数据）
      |                                            |
      |   ③ FIN, seq=w                             |
      | <----------------------------------------- |
      |                                         LAST_ACK
      |   ④ ACK, ack=w+1                           |
      | -----------------------------------------> |
   TIME_WAIT                                     CLOSED
      |  （等待 2*MSL）                             |
   CLOSED                                           |
```

- **第一次**：主动方调用 `shutdown(Shutdown::Write)` 或 `drop` 发送 `FIN`，表示"我没有数据要发了"，进入 `FIN_WAIT_1`。
- **第二次**：被动方回复 `ACK`，进入 `CLOSE_WAIT`。此时连接处于**半关闭**状态——主动方不再发送，但仍能接收被动方尚未发完的数据。
- **第三次**：被动方数据发送完毕后，也发送 `FIN`，进入 `LAST_ACK`。
- **第四次**：主动方回复 `ACK` 后进入 `TIME_WAIT`，被动方收到后即 `CLOSED`。

> 主动关闭方进入 `TIME_WAIT` 后会等待 `2*MSL`（`MSL` 为报文最大生存时间，通常 30 秒～2 分钟）才真正关闭。这是为了确保最后一个 `ACK` 到达对方（若丢失，对方会重传 `FIN`），并让本连接的旧报文在网络中彻底消散，避免干扰随后复用相同四元组的新连接。这也是服务端频繁重启时容易出现大量 `TIME_WAIT`、且短时间内无法立即重新 `bind` 同一端口的根本原因——可通过设置 `SO_REUSEADDR` 缓解。

第二次和第三次挥手之所以不能像握手那样合并，是因为被动方收到 `FIN` 时可能仍有数据未发送完，必须先回 `ACK` 占住连接，待自己的数据发完后再单独发 `FIN`。这正是 `Shutdown::Write` 半关闭语义存在的意义：它只关闭发送方向，保留接收方向，对应挥手过程中的"半关闭"窗口。
