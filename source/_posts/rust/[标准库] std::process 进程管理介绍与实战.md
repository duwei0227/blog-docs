---
title: "[标准库] std::process 进程管理介绍与实战"
published: true
layout: post
date: 2026-05-29 10:00:00
permalink: /rust/std-process.html
tags:
  - 子进程
  - 管道
  - Command
categories:
  - Rust
---

操作系统的进程模型让每个程序运行在独立的地址空间中，程序既要能控制自身的生命周期（优雅退出、异常中止），也常常需要启动子进程完成外部工具调用、Shell 脚本执行或多进程并行任务。`std::process` 是 Rust 标准库中处理这两类需求的统一接口：它提供 `exit`/`abort` 控制当前进程、`Command` 构建并启动子进程、`Stdio` 精确配置子进程的标准流，以及 `Child` 管理子进程的生命周期和 I/O 交互。

## 一、模块概览

`std::process` 自 `Rust 1.0.0` 起稳定，核心组件如下：

| 组件 | 类型 | 说明 |
|------|------|------|
| `id` | `fn` | 返回当前进程的 `PID` |
| `exit` | `fn` | 以指定退出码终止当前进程 |
| `abort` | `fn` | 以异常方式终止进程（不运行析构函数） |
| `Command` | `struct` | 子进程构建器，支持参数、环境变量、工作目录、I/O 重定向 |
| `Child` | `struct` | 已启动子进程的句柄，可等待、杀死、读写 I/O |
| `ChildStdin` | `struct` | 子进程标准输入句柄，实现 `Write` |
| `ChildStdout` | `struct` | 子进程标准输出句柄，实现 `Read` |
| `ChildStderr` | `struct` | 子进程标准错误句柄，实现 `Read` |
| `Output` | `struct` | 子进程完成后的 `status` + `stdout` + `stderr` |
| `ExitCode` | `struct` | 当前进程向父进程返回的退出码，可用作 `main` 返回值 |
| `ExitStatus` | `struct` | 子进程终止状态，包含退出码或信号信息 |
| `Stdio` | `struct` | 子进程标准流配置，描述继承、管道、丢弃等模式 |
| `Termination` | `trait` | 允许 `main` 函数返回自定义类型 |

## 二、进程控制函数

### 2.1 id

**语法：**

```rust
pub fn id() -> u32
```

返回当前进程的操作系统分配的进程标识符（`PID`）。返回值类型为 `u32`，在 `Linux` 和 `macOS` 上对应 `pid_t`，`Windows` 上对应 `DWORD`。

```rust
use std::process;

fn main() {
    let pid = process::id();
    println!("当前进程 PID: {pid}");
    println!("PID 类型: u32，范围 0–4294967295");
}
```

运行结果：

```
当前进程 PID: 88438
PID 类型: u32，范围 0–4294967295
```

> `PID` 每次运行都不同，由操作系统分配。`PID 0` 通常是内核进程，用户进程不会得到 0。

### 2.2 exit

**语法：**

```rust
pub fn exit(code: i32) -> !
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `code` | - | 退出码；`0` 表示成功，非零表示失败；`Unix` 只使用低 8 位（0–255） |

`exit` 会立即终止当前进程，并且**不会运行 Rust 变量的析构函数**（`Drop`）。因此若有未 `flush` 的 `BufWriter` 或需要显式释放的资源，应在调用 `exit` 之前手动处理，或使用 `ExitCode` 作为 `main` 的返回值（后者会正常走析构流程）。

```rust
use std::process;

fn check_config(path: &str) -> Result<(), String> {
    if path.is_empty() {
        Err("配置文件路径不能为空".to_string())
    } else {
        Ok(())
    }
}

fn main() {
    if let Err(e) = check_config("") {
        eprintln!("Fatal: {e}");
        process::exit(1);
    }
    println!("配置加载成功");
}
```

如果只是把业务校验结果转换成进程退出码，更推荐让 `main` 返回 `ExitCode`。这样错误分支仍然可以返回非零状态码，但函数返回前会正常离开作用域，局部变量的 `Drop` 析构逻辑也会运行。

```rust
use std::process::ExitCode;

struct Cleanup;

impl Drop for Cleanup {
    fn drop(&mut self) {
        println!("清理临时资源");
    }
}

fn check_config(path: &str) -> Result<(), String> {
    if path.is_empty() {
        Err("配置文件路径不能为空".to_string())
    } else if !path.ends_with(".toml") {
        Err("配置文件必须使用 .toml 后缀".to_string())
    } else {
        Ok(())
    }
}

fn main() -> ExitCode {
    let _cleanup = Cleanup;
    let config_path = std::env::args().nth(1).unwrap_or_default();

    match check_config(&config_path) {
        Ok(()) => {
            println!("配置加载成功: {config_path}");
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("Fatal: {e}");
            ExitCode::from(2)
        }
    }
}
```

执行结果示例：

```bash
$ cargo run --quiet -- ./app.toml
配置加载成功: ./app.toml
清理临时资源

$ cargo run --quiet --
Fatal: 配置文件路径不能为空
清理临时资源
```

`ExitCode::SUCCESS` 等价于退出码 `0`，`ExitCode::FAILURE` 通常用于普通失败场景，自定义错误码可用 `ExitCode::from(u8)` 构造。若上例改成 `process::exit(2)`，程序会立即终止，`Cleanup::drop` 不会执行。

> 优先使用 `main() -> ExitCode` 而非 `process::exit`，前者保证析构函数运行，适合持有文件句柄、网络连接等资源的程序。只在确实需要立即终止（如信号处理、不可恢复错误）时才调用 `exit`。

### 2.3 abort

**语法：**

```rust
pub fn abort() -> !
```

以异常方式终止进程，相当于 C 的 `abort()`。与 `exit` 的关键区别：

| 行为 | `exit` | `abort` |
|------|--------|---------|
| 运行 Rust `Drop` 析构函数 | 否 | 否 |
| 生成 `core dump`（`Unix`） | 否 | 是（取决于系统配置） |
| 父进程感知的退出信号 | `SIGCHLD`（正常退出） | `SIGABRT` |
| 典型退出码 | 指定值 | 非零（平台决定） |

`abort` 的典型用途是在检测到内存安全违规或不可恢复的内部状态时触发，避免继续运行可能污染数据。Rust 的双重 `panic`（`double-panic`）默认就会调用 `abort`。

```rust
use std::process;

fn check_invariant(x: usize, limit: usize) {
    if x > limit {
        eprintln!("内部不变量违反: {x} > {limit}，立即中止");
        process::abort();
    }
}

fn main() {
    check_invariant(10, 100);
    println!("检查通过");
    // check_invariant(200, 100); // 取消注释触发 abort
}
```

运行结果：

```
检查通过
```

## 三、退出状态

### 3.1 ExitCode

**语法：**

```rust
pub struct ExitCode(_);

impl ExitCode {
    pub const SUCCESS: ExitCode;   // 0
    pub const FAILURE: ExitCode;   // 1
    pub fn from(code: u8) -> ExitCode
}
```

`ExitCode` 实现了 `Termination` 特征，因此可以直接作为 `main` 函数的返回类型。与调用 `process::exit` 相比，返回 `ExitCode` 会让 Rust 运行时正常完成析构流程后再终止，是更安全的惯用方式。

注意 `ExitCode` 的底层类型接受 `u8`（0–255），而 `process::exit` 接受 `i32`——在 `Unix` 上两者都只使用低 8 位，但语义上 `ExitCode` 强调的是"正常终止的状态码"，`exit(i32)` 更接近"立即退出"。

```rust
use std::process::ExitCode;

fn validate(value: i32) -> Result<i32, String> {
    if value < 0 {
        Err(format!("无效值: {value}"))
    } else {
        Ok(value)
    }
}

fn main() -> ExitCode {
    match validate(42) {
        Ok(v) => {
            println!("验证通过: {v}");
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("错误: {e}");
            ExitCode::FAILURE
        }
    }
}
```

运行结果：

```
验证通过: 42
```

### 3.2 ExitStatus

`ExitStatus` 描述子进程的终止状态，由 `Child::wait` 或 `Command::output` 返回。

**主要方法：**

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `success()` | `bool` | 退出码为 0 时返回 `true` |
| `code()` | `Option<i32>` | 返回退出码；`Unix` 上被信号杀死时为 `None` |
| `signal()` | `Option<i32>` | `Unix` 专有：返回终止信号编号 |

`code()` 返回 `Option` 而非直接是 `i32`，原因在于 `Unix` 进程可以被信号终止（如 `SIGSEGV`、`SIGKILL`），此时没有退出码概念，`code()` 返回 `None`，`signal()` 返回对应信号编号。`Windows` 上进程不被信号终止，`code()` 始终是 `Some`。

下面的示例启动一个子进程，让它主动以退出码 `7` 结束，然后通过 `ExitStatus` 判断子进程是否成功、具体退出码是多少。为了兼容不同平台，示例在 `Unix` 上使用 `sh -c "exit 7"`，在 `Windows` 上使用 `cmd /C "exit /B 7"`。

```rust
use std::process::{Command, ExitStatus};

fn build_exit_command() -> Command {
    #[cfg(unix)]
    {
        let mut command = Command::new("sh");
        command.args(["-c", "exit 7"]);
        command
    }

    #[cfg(windows)]
    {
        let mut command = Command::new("cmd");
        command.args(["/C", "exit /B 7"]);
        command
    }
}

fn print_status(status: ExitStatus) {
    println!("状态展示: {status}");
    println!("是否成功: {}", status.success());

    match status.code() {
        Some(code) => println!("退出码: {code}"),
        None => println!("没有退出码，进程可能被信号终止"),
    }
}

fn main() -> std::io::Result<()> {
    let status = build_exit_command().status()?;
    print_status(status);
    Ok(())
}
```

运行结果：

```bash
状态展示: exit status: 7
是否成功: false
退出码: 7
```

`success()` 只是对"是否为成功退出"的快速判断；如果业务需要区分不同失败原因，应继续读取 `code()` 并按退出码分支处理。`code()` 返回 `None` 的情况主要出现在 `Unix` 子进程被信号杀死时，此时应结合平台专有的 `ExitStatusExt::signal()` 进一步判断。

## 四、Command 构建器

### 4.1 创建与基础执行

**语法：**

```rust
pub fn new<S: AsRef<OsStr>>(program: S) -> Command
pub fn output(&mut self) -> io::Result<Output>
pub fn status(&mut self) -> io::Result<ExitStatus>
pub fn spawn(&mut self) -> io::Result<Child>
```

`Command::new` 接受程序名或完整路径。三种执行方式的区别：

| 方法 | 行为 | 适用场景 |
|------|------|----------|
| `output()` | 等待完成，收集 `stdout`/`stderr` | 需要读取输出 |
| `status()` | 等待完成，只返回退出状态 | 只关心成功与否 |
| `spawn()` | 立即返回 `Child`，不等待 | 需要并发或 I/O 交互 |

```rust
use std::process::Command;

fn main() {
    let output = Command::new("echo")
        .arg("Hello, std::process!")
        .output()
        .expect("执行命令失败");

    println!("成功: {}", output.status.success());
    println!("退出码: {}", output.status.code().unwrap_or(-1));
    print!("标准输出: {}", String::from_utf8_lossy(&output.stdout));
}
```

运行结果：

```
成功: true
退出码: 0
标准输出: Hello, std::process!
```

### 4.2 参数传递

**语法：**

```rust
pub fn arg<S: AsRef<OsStr>>(&mut self, arg: S) -> &mut Command
pub fn args<I, S>(&mut self, args: I) -> &mut Command
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
```

**参数：**

| 方法 | 说明 |
|------|------|
| `arg(s)` | 添加单个参数 |
| `args(iter)` | 批量添加参数 |

每个 `arg` 调用对应一个独立参数——`Command` 在 `Unix` 上通过 `execve` 的参数数组传递，不经过 Shell 解析，因此**不需要对空格或特殊字符转义**。这与直接在 Shell 中执行不同：`Command::new("ls").arg("-la /tmp")` 会把 `-la /tmp` 作为整体传给 `ls`（通常会报错），而 `.arg("-la").arg("/tmp")` 才是正确写法。

```rust
use std::process::Command;

fn main() {
    let files = vec!["/tmp", "/var"];

    let output = Command::new("ls")
        .arg("-1")
        .args(&files)
        .output()
        .expect("执行失败");

    print!("{}", String::from_utf8_lossy(&output.stdout));
}
```

> 在 `Windows` 上，参数最终以单个命令行字符串传递给子进程，`Command` 会自动按 `MSVC C runtime` 规则转义引号和空格。如需绕过转义（调用自行解析命令行的程序），使用 `raw_arg`（`Windows` 专有）。

### 4.3 环境变量与工作目录

**语法：**

```rust
pub fn env<K, V>(&mut self, key: K, val: V) -> &mut Command
pub fn envs<I, K, V>(&mut self, vars: I) -> &mut Command
pub fn env_remove<K: AsRef<OsStr>>(&mut self, key: K) -> &mut Command
pub fn env_clear(&mut self) -> &mut Command
pub fn current_dir<P: AsRef<Path>>(&mut self, dir: P) -> &mut Command
```

**参数：**

| 方法 | 说明 |
|------|------|
| `env(key, val)` | 为子进程设置单个环境变量；已存在则覆盖 |
| `envs(iter)` | 批量设置环境变量 |
| `env_remove(key)` | 从子进程继承的环境中删除指定变量 |
| `env_clear()` | 清除所有继承的环境变量，只保留通过 `env` 显式设置的 |
| `current_dir(dir)` | 设置子进程的工作目录；父进程 `CWD` 不受影响 |

默认情况下子进程继承父进程的全部环境变量，`env` 在此基础上叠加或覆盖。若需要完全隔离的沙箱环境，先调用 `env_clear()` 再按需 `env` 注入。

```rust
use std::process::Command;

fn main() {
    let output = Command::new("sh")
        .arg("-c")
        .arg("echo \"$GREETING from $(pwd)\"")
        .env("GREETING", "Hello")
        .current_dir("/tmp")
        .output()
        .expect("执行命令失败");

    print!("{}", String::from_utf8_lossy(&output.stdout));
}
```

运行结果：

```
Hello from /tmp
```

## 五、标准 I/O 配置（Stdio）

### 5.1 Stdio 模式

`Stdio` 描述子进程某路标准流（`stdin`/`stdout`/`stderr`）的连接方式。

| 构造方式 | 说明 |
|----------|------|
| `Stdio::inherit()` | 继承父进程的对应流（默认行为） |
| `Stdio::piped()` | 创建匿名管道，父进程持有另一端 |
| `Stdio::null()` | 连接到 `/dev/null`（`Unix`）或 `NUL`（`Windows`），丢弃读写 |
| `Stdio::from(file)` | 将现有文件句柄或另一子进程的 I/O 作为输入/输出 |

`inherit` 是默认模式，适合交互式工具；`piped` 用于捕获或提供数据；`null` 适合抑制噪声输出的后台任务；`from` 是进程管道的基础，将一个子进程的 `stdout` 直接接到另一个的 `stdin`。

### 5.2 输出捕获

通过 `Stdio::piped()` 捕获 `stdout` 和 `stderr`，配合 `output()` 一次性拿到两者：

```rust
use std::process::{Command, Stdio};

fn main() {
    let output = Command::new("ls")
        .arg("/nonexistent_path_xyz")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("执行命令失败");

    println!("退出码: {}", output.status.code().unwrap_or(-1));
    println!("stdout 字节数: {}", output.stdout.len());
    let stderr = String::from_utf8_lossy(&output.stderr);
    println!("stderr: {}", stderr.trim());
}
```

运行结果：

```
退出码: 2
stdout 字节数: 0
stderr: ls: cannot access '/nonexistent_path_xyz': No such file or directory
```

> `output()` 内部会同时读取 `stdout` 和 `stderr` 以防止缓冲区满导致死锁。如果使用 `spawn()` + 手动读取，必须注意在不同线程中分别消费两路输出，否则一路满缓冲区会阻塞子进程写另一路，从而死锁。

## 六、子进程管理（Child）

### 6.1 spawn 与 wait

`spawn()` 立即返回 `Child`，子进程在后台运行。`Child` 的主要方法：

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `wait()` | `io::Result<ExitStatus>` | 阻塞直到子进程退出，返回状态 |
| `wait_with_output()` | `io::Result<Output>` | 阻塞直到退出，同时收集 `stdout`/`stderr` |
| `kill()` | `io::Result<()>` | 向子进程发送终止信号（`Unix` 为 `SIGKILL`，`Windows` 为 `TerminateProcess`） |
| `id()` | `Option<u32>` | 返回子进程 `PID`；进程已退出时为 `None` |
| `try_wait()` | `io::Result<Option<ExitStatus>>` | 非阻塞检查子进程是否已退出 |

`wait` 与 `wait_with_output` 的选择取决于是否需要读取输出：如果已用 `Stdio::piped()` 配置了输出流，应用 `wait_with_output`，因为它会在等待的同时消费管道缓冲区，避免死锁；如果输出配置为 `inherit` 或 `null`，用 `wait` 即可。

不调用 `wait` 而直接丢弃 `Child` 并不会杀死子进程——子进程会成为孤儿进程，继续运行直到自然退出。若要确保子进程随父进程退出，需要显式调用 `kill` 或在析构时处理。

### 6.2 stdin 写入

向子进程的 `stdin` 写入数据需要两个步骤：用 `Stdio::piped()` 配置 `stdin`，然后在独立线程中写入，避免与读取 `stdout` 产生死锁：

```rust
use std::io::Write;
use std::process::{Command, Stdio};

fn main() {
    let mut child = Command::new("cat")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .expect("启动子进程失败");

    let mut stdin = child.stdin.take().expect("获取 stdin 失败");
    std::thread::spawn(move || {
        stdin
            .write_all(b"Hello from Rust!\nLine 2\n")
            .expect("写入 stdin 失败");
    });

    let output = child.wait_with_output().expect("等待子进程失败");
    print!("{}", String::from_utf8_lossy(&output.stdout));
}
```

运行结果：

```
Hello from Rust!
Line 2
```

这里使用 `thread::spawn` 的原因是：主线程随后要调用 `wait_with_output()` 等待子进程退出并收集 `stdout`，而子进程 `cat` 又要等父进程写完 `stdin` 并关闭写入端后才会退出。把写入逻辑放到独立线程后，执行流程变成：

1. 子线程持有 `ChildStdin`，负责调用 `write_all` 写入输入数据；
2. 子线程结束时 `stdin` 离开作用域，管道写入端自动关闭；
3. `cat` 读到 EOF 后退出；
4. 主线程的 `wait_with_output()` 完成等待并拿到输出。

`stdin.take()` 将 `stdin` 从 `Child` 中取出，移交给子线程——这一步也很关键：它让写入端的所有权不再留在 `Child` 结构里，写入线程结束后句柄可以及时关闭。若父线程一直持有 `stdin` 句柄，又直接调用 `wait_with_output()` 等子进程退出，子进程可能因为等不到 EOF 而继续等待输入，父子进程互相等待，最终造成死锁。

如果输入内容很小，也可以在主线程中写完后显式 `drop(stdin)`，再调用 `wait_with_output()`；文章示例使用线程，是为了展示更通用的模式，适合输入和输出都可能阻塞、或者子进程需要边读边处理的场景。

### 6.3 进程间管道

`Stdio::from` 可以将一个子进程的 `stdout` 直接作为另一个子进程的 `stdin`，无需经过父进程的内存缓冲，实现类似 Shell 管道（`cmd1 | cmd2`）的效果：

```rust
use std::process::{Command, Stdio};

fn main() {
    let echo = Command::new("echo")
        .arg("hello world rust")
        .stdout(Stdio::piped())
        .spawn()
        .expect("启动 echo 失败");

    let output = Command::new("tr")
        .arg("a-z")
        .arg("A-Z")
        .stdin(Stdio::from(echo.stdout.expect("获取 stdout 失败")))
        .stdout(Stdio::piped())
        .output()
        .expect("启动 tr 失败");

    print!("{}", String::from_utf8_lossy(&output.stdout));
}
```

运行结果：

```
HELLO WORLD RUST
```

`echo.stdout` 是 `Option<ChildStdout>`，`ChildStdout` 实现了 `Into<Stdio>`，因此可以直接传给 `Stdio::from`。这种方式将操作系统的管道文件描述符直接接入下一个子进程，数据不经过 Rust 堆，适合处理大量输出的场景。

## 七、综合实战

以下示例整合了本文的主要 API：用 `ExitCode` 作为 `main` 返回值，封装带错误处理的命令执行函数，并演示 `stdin` 写入与进程管道两种 I/O 模式：

```rust
use std::io::Write;
use std::process::{Command, ExitCode, Stdio};

fn run_command(cmd: &str, args: &[&str]) -> Result<String, String> {
    let output = Command::new(cmd)
        .args(args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| format!("启动命令失败: {e}"))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        let err = String::from_utf8_lossy(&output.stderr).trim().to_string();
        Err(format!(
            "退出码 {}: {err}",
            output.status.code().unwrap_or(-1)
        ))
    }
}

fn main() -> ExitCode {
    println!("=== 进程信息 ===");
    println!("当前 PID: {}", std::process::id());

    println!("\n=== 命令执行 ===");
    match run_command("uname", &["-sr"]) {
        Ok(output) => println!("系统信息: {output}"),
        Err(e) => {
            eprintln!("错误: {e}");
            return ExitCode::FAILURE;
        }
    }

    println!("\n=== stdin 写入 ===");
    let mut child = Command::new("cat")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .expect("启动 cat 失败");

    let mut stdin = child.stdin.take().expect("获取 stdin 失败");
    std::thread::spawn(move || {
        stdin
            .write_all(b"Rust process demo\n")
            .expect("写入失败");
    });
    let out = child.wait_with_output().expect("等待失败");
    print!("cat 回显: {}", String::from_utf8_lossy(&out.stdout));

    println!("\n=== 进程管道 ===");
    let producer = Command::new("sh")
        .arg("-c")
        .arg("printf 'apple\\nbanana\\ncherry\\napricot\\n'")
        .stdout(Stdio::piped())
        .spawn()
        .expect("启动失败");

    let result = Command::new("grep")
        .arg("^a")
        .stdin(Stdio::from(producer.stdout.expect("获取 stdout 失败")))
        .stdout(Stdio::piped())
        .output()
        .expect("grep 失败");

    println!("以 'a' 开头的水果:");
    for line in String::from_utf8_lossy(&result.stdout).trim().lines() {
        println!("  - {line}");
    }

    ExitCode::SUCCESS
}
```

运行结果：

```
=== 进程信息 ===
当前 PID: 91314

=== 命令执行 ===
系统信息: Linux 7.0.9-205.fc44.x86_64

=== stdin 写入 ===
cat 回显: Rust process demo

=== 进程管道 ===
以 'a' 开头的水果:
  - apple
  - apricot
```
