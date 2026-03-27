---
title: Rust notify 文件系统监控使用指南
date: 2026-03-24 11:35:00
tags:
  - Rust
  - 文件系统
  - notify
categories:
  - Rust
---

`notify` 是 Rust 生态中用于监控文件系统变化的跨平台库，支持 Linux、macOS、Windows 等系统。本文基于 notify 8.2.0 版本讲解其核心用法。

## 一、安装与依赖

### 1.1 添加依赖

**语法格式**

```toml
[dependencies]
notify = "8.2.0"
```

**示例**

```toml
[dependencies]
notify = "8.2.0"
```

### 1.2 Feature 特性

| Feature | 说明 |
|---------|------|
| `serde` | 启用事件序列化支持 |

**示例**

```toml
[dependencies]
notify = { version = "8.2.0", features = ["serde"] }
```

## 二、快速开始

### 2.1 recommended_watcher() 推荐监听器

**语法格式**

```
notify::recommended_watcher(event_handler) -> Result<RecommendedWatcher>
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `event_handler` | 事件处理函数/闭包 | `move \|res\| { ... }` |

**说明**：`recommended_watcher()` 会自动为当前平台选择最佳的后端实现。

**示例**

```rust
use notify::{Event, Result, Watcher};
use std::path::Path;

fn main() -> Result<()> {
    let mut watcher = notify::recommended_watcher(|res: Result<Event>| {
        match res {
            Ok(event) => println!("事件: {:?}", event),
            Err(e) => println!("监听错误: {:?}", e),
        }
    })?;

    // 监听当前目录及子目录
    watcher.watch(Path::new("."), notify::RecursiveMode::Recursive)?;

    println!("监听中，按 Ctrl+C 退出...");
    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}
```

**输出示例**

```
事件: Event { kind: Create(Any), paths: [...], attrs: [...] }
事件: Event { kind: Modify(Data(Any)), paths: [...], attrs: [...] }
```

### 2.2 使用 mpsc 通道

**说明**：通过标准库的 `mpsc` 通道接收事件。

**示例**

```rust
use notify::{Event, RecursiveMode, Result, Watcher};
use std::path::Path;
use std::sync::mpsc;

fn main() -> Result<()> {
    let (tx, rx) = mpsc::channel::<Result<Event>>();

    let mut watcher = notify::recommended_watcher(tx)?;

    watcher.watch(Path::new("."), RecursiveMode::Recursive)?;

    for res in rx {
        match res {
            Ok(event) => println!("收到事件: {:?}", event.kind),
            Err(e) => eprintln!("错误: {:?}", e),
        }
    }

    Ok(())
}
```

## 三、核心类型

### 3.1 Watcher trait 监听器接口

**语法格式**

```
pub trait Watcher {
    fn watch(&mut self, path: &Path, mode: RecursiveMode) -> Result<()>;
    fn unwatch(&mut self, path: &Path) -> Result<()>;
}
```

**方法说明**

| 方法 | 说明 |
|------|------|
| `watch(path, mode)` | 开始监听指定路径 |
| `unwatch(path)` | 停止监听指定路径 |

**示例**

```rust
use notify::{RecursiveMode, Result, Watcher};
use std::path::Path;

fn manage_watcher(watcher: &mut impl Watcher) -> Result<()> {
    // 监听单个文件
    watcher.watch(Path::new("/path/to/file.txt"), RecursiveMode::NonRecursive)?;

    // 监听目录（递归）
    watcher.watch(Path::new("/path/to/dir"), RecursiveMode::Recursive)?;

    // 取消监听
    watcher.unwatch(Path::new("/path/to/file.txt"))?;

    Ok(())
}
```

### 3.2 Event 事件结构

**语法格式**

```
pub struct Event {
    pub kind: EventKind,           // 事件类型
    pub paths: Vec<PathBuf>,      // 涉及的路径
    pub attrs: EventAttributes,    // 额外属性
}
```

**字段说明**

| 字段 | 说明 |
|------|------|
| `kind` | 事件类型，详见 EventKind |
| `paths` | 受影响的文件路径列表 |
| `attrs` | 事件附加属性（追踪ID、标志等） |

**方法说明**

| 方法 | 说明 |
|------|------|
| `need_rescan()` | 是否可能遗漏了事件 |
| `tracker_id()` | 获取追踪器 ID |
| `flag()` | 获取事件标志 |

**示例**

```rust
use notify::{Event, EventKind};

fn handle_event(event: Event) {
    println!("事件类型: {:?}", event.kind);
    println!("涉及路径: {:?}", event.paths);

    if event.need_rescan() {
        println!("警告: 可能遗漏了某些事件");
    }

    // 匹配事件类型
    match event.kind {
        EventKind::Create(_) => println!("文件被创建"),
        EventKind::Modify(_) => println!("文件被修改"),
        EventKind::Remove(_) => println!("文件被删除"),
        _ => println!("其他事件"),
    }
}
```

### 3.3 RecursiveMode 递归模式

**语法格式**

```
pub enum RecursiveMode {
    Recursive,      // 递归监听子目录
    NonRecursive,   // 仅监听当前目录
}
```

**说明**

| 变体 | 说明 |
|------|------|
| `Recursive` | 监听目录及其所有子目录，包括后续创建的子目录 |
| `NonRecursive` | 仅监听指定目录，不包含子目录 |

**示例**

```rust
use notify::{RecursiveMode, Watcher};
use std::path::Path;

fn main() -> notify::Result<()> {
    let mut watcher = notify::recommended_watcher(|_| {})?;

    // 仅监听当前目录，不含子目录
    watcher.watch(Path::new("/tmp"), RecursiveMode::NonRecursive)?;

    // 监听当前目录及所有子目录
    watcher.watch(Path::new("/var/log"), RecursiveMode::Recursive)?;

    Ok(())
}
```

### 3.4 EventKind 事件类型

**语法格式**

```
pub enum EventKind {
    Any,                    // 未知/所有事件
    Access(AccessKind),     // 文件访问事件
    Create(CreateKind),     // 文件创建事件
    Modify(ModifyKind),      // 文件修改事件
    Remove(RemoveKind),     // 文件删除事件
    Other,                  // 其他事件
}
```

**事件类型说明**

| 类型 | 说明 | 平台支持 |
|------|------|----------|
| `Access` | 文件被打开/执行 | 部分平台 |
| `Create` | 文件或目录被创建 | 全部 |
| `Modify` | 内容、名称或元数据变更 | 全部 |
| `Remove` | 文件或目录被删除 | 全部 |

**示例**

```rust
use notify::EventKind;

fn classify_event(kind: &EventKind) -> &'static str {
    match kind {
        EventKind::Any(_) => "任意事件",
        EventKind::Access(_) => "访问事件",
        EventKind::Create(_) => "创建事件",
        EventKind::Modify(_) => "修改事件",
        EventKind::Remove(_) => "删除事件",
        EventKind::Other => "其他事件",
    }
}
```

### 3.5 ModifyKind 修改详情

**语法格式**

```
pub enum ModifyKind {
    Any,
    Data(DataChange),          // 内容变更
    Metadata(MetadataKind),   // 元数据变更
    Name(RenameMode),          // 名称变更（重命名）
    Other,                     // 其他修改
}
```

**说明**

| 变体 | 说明 |
|------|------|
| `Data` | 文件内容被修改 |
| `Metadata` | 文件权限、时间戳等元数据变更 |
| `Name` | 文件名变更（重命名） |

**示例**

```rust
use notify::event::{EventKind, ModifyKind};

fn describe_modify(kind: &EventKind) {
    if let EventKind::Modify(modify) = kind {
        match modify {
            ModifyKind::Data(_) => println!("文件内容变更"),
            ModifyKind::Metadata(_) => println!("元数据变更"),
            ModifyKind::Name(_) => println!("文件名变更"),
            ModifyKind::Other => println!("其他修改"),
            ModifyKind::Any => println!("未知修改"),
        }
    }
}
```

## 四、配置选项

### 4.1 Config 配置结构

**语法格式**

```
notify::Config::default()
    .with_poll_interval(interval)
    .with_compare_contents(enabled)
    .with_follow_links(enabled)
```

**配置项说明**

| 方法 | 说明 | 适用后端 |
|------|------|----------|
| `with_poll_interval` | 设置轮询间隔 | PollWatcher |
| `with_compare_contents` | 启用内容比较（哈希） | PollWatcher |
| `with_follow_links` | 是否跟随符号链接 | 所有 |

**示例**

```rust
use notify::{Config, Watcher};
use std::time::Duration;

fn create_config() -> Config {
    Config::default()
        // PollWatcher: 每 2 秒轮询一次
        .with_poll_interval(Duration::from_secs(2))
        // PollWatcher: 通过内容哈希检测变更
        .with_compare_contents(true)
        // 递归监听时是否跟随符号链接
        .with_follow_links(true)
}
```

### 4.2 使用配置创建监听器

**示例**

```rust
use notify::{Config, RecommendedWatcher, Result, Watcher};
use std::time::Duration;

fn main() -> Result<()> {
    let config = Config::default()
        .with_poll_interval(Duration::from_secs(5));

    let mut watcher = RecommendedWatcher::new(
        |res| println!("{:?}", res),
        config,
    )?;

    watcher.watch("/path/to/dir".as_ref(), notify::RecursiveMode::Recursive)?;

    Ok(())
}
```

## 五、跨平台后端

### 5.1 后端类型

| 后端 | 平台 | 说明 |
|------|------|------|
| INotify | Linux | 基于 inotify，高效 |
| Kqueue | macOS/BSD | 基于 kqueue |
| FSEvent | macOS | macOS 原生事件 |
| Poll | 所有 | 轮询方式，兼容性最好 |
| ReadDirectoryChangesW | Windows | Windows 原生 |

### 5.2 手动指定后端

**示例**

```rust
use notify::{Config, INotifyWatcher, Result, Watcher};
use std::path::Path;

fn main() -> Result<()> {
    // Linux: 使用 inotify 后端
    let mut watcher = INotifyWatcher::new(
        |res| println!("{:?}", res),
        Config::default(),
    )?;

    watcher.watch(Path::new("/tmp"), notify::RecursiveMode::Recursive)?;

    Ok(())
}
```

### 5.3 PollWatcher 轮询后端

**语法格式**

```
notify::PollWatcher::new(event_handler, config) -> Result<PollWatcher>
```

**说明**：PollWatcher 通过定期扫描文件系统来检测变化，兼容性最好但性能较低。适用于不支持原生事件通知的平台（如网络文件系统）。

**示例**

```rust
use notify::{Config, PollWatcher, Result, Watcher};
use std::path::Path;
use std::time::Duration;

fn main() -> Result<()> {
    let config = Config::default()
        .with_poll_interval(Duration::from_secs(3));

    let mut watcher = PollWatcher::new(
        |res| println!("{:?}", res),
        config,
    )?;

    watcher.watch(Path::new("."), notify::RecursiveMode::Recursive)?;

    Ok(())
}
```

## 六、实战示例

### 6.1 监控配置文件变更自动重载

**示例**

```rust
use notify::{Config, Event, RecommendedWatcher, Result, Watcher};
use std::path::Path;
use std::sync::mpsc;

struct ConfigManager {
    config_data: String,
}

impl ConfigManager {
    fn new() -> Self {
        Self {
            config_data: String::new(),
        }
    }

    fn load(&mut self, path: &Path) -> std::io::Result<()> {
        self.config_data = std::fs::read_to_string(path)?;
        println!("配置已加载: {} 字节", self.config_data.len());
        Ok(())
    }

    fn reload(&mut self, path: &Path) -> std::io::Result<()> {
        println!("检测到配置变更，重新加载...");
        self.load(path)
    }
}

fn main() -> Result<()> {
    let config_path = Path::new("config.toml");
    let (tx, rx) = mpsc::channel();

    let mut config_mgr = ConfigManager::new();
    config_mgr.load(config_path)?;

    let mut watcher = RecommendedWatcher::new(
        move |res: Result<Event>| {
            if let Ok(event) = res {
                let _ = tx.send(event);
            }
        },
        Config::default(),
    )?;

    watcher.watch(config_path, notify::RecursiveMode::NonRecursive)?;

    println!("监听配置文件变更中...");

    loop {
        match rx.recv() {
            Ok(event) => {
                if matches!(event.kind, notify::EventKind::Modify(_)) {
                    if let Err(e) = config_mgr.reload(config_path) {
                        eprintln!("重载失败: {}", e);
                    }
                }
            }
            Err(_) => break,
        }
    }

    Ok(())
}
```

> **说明**：`matches!(event.kind, notify::EventKind::Modify(_))` 用于判断事件类型是否为修改事件。第一个参数为要匹配的表达式，第二个参数为匹配模式。`_` 是通配符，匹配任意值。如果匹配成功返回 `true`，否则返回 `false`。这里使用 `notify::EventKind::Modify(_)` 匹配任意类型的修改事件（文件内容修改、权限修改等）。

### 6.2 监听目录自动执行命令

**示例**

```rust
use notify::{Config, EventKind, RecommendedWatcher, RecursiveMode, Result, Watcher};
use std::path::Path;
use std::process::Command;

fn main() -> Result<()> {
    let watch_path = Path::new("./src");
    let mut watcher = RecommendedWatcher::new(
        |res: Result<notify::Event>| {
            if let Ok(event) = res {
                handle_event(&event);
            }
        },
        Config::default(),
    )?;

    watcher.watch(watch_path, RecursiveMode::Recursive)?;
    println!("监听 {:?} 目录中...", watch_path);

    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}

fn handle_event(event: &notify::Event) {
    match event.kind {
        EventKind::Create(_) => {
            println!("检测到新文件: {:?}", event.paths);
        }
        EventKind::Modify(_) => {
            println!("文件已修改: {:?}", event.paths);
            // 可以在这里触发构建
            let _ = Command::new("cargo")
                .args(["build"])
                .spawn();
        }
        EventKind::Remove(_) => {
            println!("文件已删除: {:?}", event.paths);
        }
        _ => {}
    }
}
```

### 6.3 文件变化去重（防止重复处理）

**说明**：某些编辑器会快速触发多个事件，可以使用计时器去重。

**示例**

```rust
use notify::{Config, RecommendedWatcher, RecursiveMode, Result, Watcher};
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

struct Debouncer {
    events: HashSet<PathBuf>,
    last_flush: Instant,
    debounce_time: Duration,
}

impl Debouncer {
    fn new(debounce_ms: u64) -> Self {
        Self {
            events: HashSet::new(),
            last_flush: Instant::now(),
            debounce_time: Duration::from_millis(debounce_ms),
        }
    }

    fn add(&mut self, paths: Vec<PathBuf>) {
        for path in paths {
            self.events.insert(path);
        }
        // 如果距上次刷新超过去重时间，刷新并处理
        if self.last_flush.elapsed() > self.debounce_time {
            self.flush();
        }
    }

    fn flush(&mut self) {
        if !self.events.is_empty() {
            println!("处理 {} 个变更:", self.events.len());
            for path in &self.events {
                println!("  - {:?}", path);
            }
            self.events.clear();
            self.last_flush = Instant::now();
        }
    }
}

fn main() -> Result<()> {
    // 使用 Arc<Mutex<>> 共享 debouncer 到闭包和主循环（线程安全）
    let debouncer = Arc::new(Mutex::new(Debouncer::new(500)));
    let debouncer_clone = debouncer.clone();

    let mut watcher = RecommendedWatcher::new(
        move |res: Result<notify::Event>| {
            if let Ok(event) = res {
                if let Ok(mut debouncer) = debouncer_clone.lock() {
                    debouncer.add(event.paths);
                }
            }
        },
        Config::default(),
    )?;

    watcher.watch(Path::new("."), RecursiveMode::Recursive)?;

    // 定期刷新去重缓冲区
    loop {
        std::thread::sleep(Duration::from_millis(100));
        if let Ok(mut debouncer) = debouncer.lock() {
            debouncer.flush();
        }
    }
}
```

## 七、已知问题与限制

### 7.1 网络文件系统

网络挂载的文件系统（如 NFS）可能无法正常发送事件。可使用 `PollWatcher` 作为替代方案。

**示例**

```rust
use notify::{Config, PollWatcher, Result};
use std::time::Duration;

// 对于网络文件系统使用 PollWatcher
fn watch_network_path() -> Result<()> {
    let config = Config::default()
        .with_poll_interval(Duration::from_secs(10));

    let _watcher = PollWatcher::new(
        |res| println!("{:?}", res),
        config,
    )?;

    Ok(())
}
```

### 7.2 Linux inotify 限制

Linux 的 inotify 有系统级限制：

```bash
# 增加监听实例数量
sudo sysctl fs.inotify.max_user_instances=8192
# 增加监听文件数量
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl -p
```

### 7.3 编辑器行为差异

不同编辑器保存文件的方式不同：
- 部分编辑器会截断文件后写入
- 部分编辑器会先删除旧文件再创建新文件

这会导致观察到的事件类型不一致。

### 7.4 父目录删除

如果想监听 `/a/b/` 目录被删除，需要监听其父目录 `/a`。

**示例**

```rust
use notify::{Config, RecommendedWatcher, RecursiveMode, Result, Watcher};
use std::path::Path;

fn main() -> Result<()> {
    let mut watcher = RecommendedWatcher::new(
        |res| println!("{:?}", res),
        Config::default(),
    )?;

    // 监听父目录才能检测到子目录被删除
    watcher.watch(Path::new("/a"), RecursiveMode::Recursive)?;

    Ok(())
}
```

## 八、完整项目模板

### 8.1 Cargo.toml

```toml
[package]
name = "file-watcher"
version = "0.1.0"
edition = "2021"

[dependencies]
notify = "8.2.0"
```

### 8.2 src/main.rs

```rust
use notify::{Config, EventKind, RecommendedWatcher, RecursiveMode, Result, Watcher};
use std::path::Path;

fn main() -> Result<()> {
    let watch_path = std::env::args()
        .nth(1)
        .unwrap_or_else(|| ".".to_string());

    println!("监听目录: {}", watch_path);

    let mut watcher = RecommendedWatcher::new(
        |res: Result<notify::Event>| {
            match res {
                Ok(event) => {
                    let action = match event.kind {
                        EventKind::Create(_) => "创建",
                        EventKind::Modify(_) => "修改",
                        EventKind::Remove(_) => "删除",
                        EventKind::Access(_) => "访问",
                        _ => "其他",
                    };
                    println!("[{}] {:?}", action, event.paths);
                }
                Err(e) => eprintln!("错误: {:?}", e),
            }
        },
        Config::default(),
    )?;

    watcher.watch(
        Path::new(&watch_path),
        RecursiveMode::Recursive,
    )?;

    println!("按 Ctrl+C 退出");
    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}
```

**运行**

```bash
cargo run -- /path/to/watch
```

## 九、相关扩展

### 9.1 notify-debouncer-mini

轻量级去抖库，对事件进行简单的时间窗口去重。同一文件在指定时间间隔内的多次变更只会触发一次回调。

**主要功能**
- 时间窗口去重：在指定时间间隔内，同一文件的多次变更只会触发一次事件
- 轻量级：依赖少，API 简洁
- 回调模式：使用闭包处理事件

**使用场景**
- 简单需求：只需要过滤重复事件，不关心事件顺序
- 编辑器热重载：避免保存文件时触发多次重载
- 日志文件监控：避免频繁更新 UI

**依赖**

```toml
notify-debouncer-mini = "0.5"
```

**函数签名**

```rust
pub fn new_debouncer<F: DebounceEventHandler>(
    timeout: Duration,
    event_handler: F,
) -> Result<Debouncer<RecommendedWatcher>, Error>
```

**参数说明**

| 参数 | 类型 | 说明 |
|------|------|------|
| `timeout` | `Duration` | 去重时间窗口，同一文件在此时间内多次变更只触发一次事件 |
| `event_handler` | 闭包/函数 | 事件处理回调，接收 `DebounceEventResult` 类型参数 |

**返回值**：`Result<Debouncer<RecommendedWatcher>, Error>`

**timeout 设置建议**

| 场景 | 推荐值 | 说明 |
|------|--------|------|
| 编辑器热重载 | 100-300ms | 大多数编辑器保存操作在 200ms 内完成 |
| 构建系统触发 | 500ms-1s | 确保文件写入完全结束 |
| UI 更新 | 300-500ms | 平衡响应速度和频繁更新 |
| 日志监控 | 1-2s | 日志写入通常较快但可能批量写入 |

> **提示**：timeout 过短可能导致事件被遗漏，过长则响应延迟。对于不确定的场景，建议先使用 500ms 作为默认值。

**示例**

```rust
use notify_debouncer_mini::{new_debouncer, DebounceEventResult, notify::RecursiveMode};
use std::path::Path;

fn main() -> Result<(), notify_debouncer_mini::notify::Error> {
    let mut debouncer = new_debouncer(
        std::time::Duration::from_secs(1),
        |res: DebounceEventResult| {
            match res {
                Ok(events) => {
                    for event in events {
                        println!("文件变更: {:?}", event.path);
                    }
                }
                Err(e) => eprintln!("错误: {:?}", e),
            }
        },
    )?;

    debouncer.watcher().watch(Path::new("/path"), RecursiveMode::Recursive)?;

    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}
```

### 9.2 notify-debouncer-full

功能完整的去抖库，在 mini 版本基础上增加了文件路径追踪、事件合并等高级功能。

**主要功能**
- 重命名事件合并：自动匹配文件的 rename From 和 To 事件
- 文件路径追踪：记录文件 ID，跨重命名事件保持路径一致
- 创建后不重复：在 Create 事件后不会重复触发 Modify 事件
- 目录删除优化：删除目录时只触发一次 Remove 事件
- 跨平台文件 ID：macOS/Windows 使用 FS Events 追踪文件

**使用场景**
- 复杂编辑场景：需要处理重命名、移动文件等复杂操作
- 构建系统：确保只在文件稳定后才触发构建
- IDE/编辑器：需要精确跟踪文件状态变化
- 数据同步：需要处理文件重命名等场景

**依赖**

```toml
notify-debouncer-full = "0.5"
```

**函数签名**

```rust
pub fn new_debouncer<F: DebounceEventHandler>(
    timeout: Duration,
    cache: Option<Box<dyn FileIdCache>>,
    event_handler: F,
) -> Result<Debouncer<RecommendedWatcher, FileIdMap>, Error>
```

**参数说明**

| 参数 | 类型 | 说明 |
|------|------|------|
| `timeout` | `Duration` | 去重时间窗口 |
| `cache` | `Option<Box<dyn FileIdCache>>` | 文件 ID 缓存，`None` 使用默认的 `FileIdMap` |
| `event_handler` | 闭包/函数 | 事件处理回调 |

**返回值**：`Result<Debouncer<RecommendedWatcher, FileIdMap>, Error>`

**timeout 设置建议**

| 场景 | 推荐值 | 说明 |
|------|--------|------|
| 简单热重载 | 200-500ms | 足够过滤编辑器保存时的重复事件 |
| 构建系统 | 1-2s | 确保文件稳定（写入、重命名都完成） |
| IDE 级别监控 | 2-3s | 需要处理复杂操作如 git 操作、IDE 自动保存 |
| 文件同步 | 2-5s | 给足时间处理大文件和多步骤操作 |

> **提示**：`notify-debouncer-full` 支持更精细的过滤，建议比 mini 版设置更长一些，以充分发挥其事件合并能力。如果对文件重命名有需求，建议至少 2 秒。

**示例**

```rust
use notify_debouncer_full::{new_debouncer, DebounceEventResult, notify::RecursiveMode};
use std::path::Path;

fn main() -> Result<(), notify_debouncer_full::notify::Error> {
    let mut debouncer = new_debouncer(
        std::time::Duration::from_secs(2),
        None,
        |result: DebounceEventResult| {
            match result {
                Ok(events) => {
                    for event in events {
                        println!("文件变更: {:?}", event.paths);
                    }
                }
                Err(errors) => {
                    for e in errors {
                        eprintln!("错误: {:?}", e);
                    }
                }
            }
        },
    )?;

    debouncer.watch(Path::new("/path"), RecursiveMode::Recursive)?;

    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}
```
