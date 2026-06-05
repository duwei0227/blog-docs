---
title: struct 结构体介绍与实战
published: true
layout: post
date: 2026-05-13 10:00:00
permalink: /rust/struct.html
tags:
  - struct
categories:
  - Rust
---

`struct` 是 Rust 中组织相关数据的核心工具，地位类似于其他语言的类（`class`），但没有继承、没有隐式构造器。理解 `struct` 的定义、方法绑定、所有权语义，是写出地道 Rust 代码的第一步。本文从基本语法出发，逐步覆盖元组结构体、`impl` 块、`derive` 宏以及生命周期标注。

## 一、基本定义与实例化

**语法：**

```rust
struct StructName {
    field1: Type1,
    field2: Type2,
}
```

字段名使用 `snake_case`，访问通过点语法 `instance.field`。`struct` 默认不可变；若需修改字段，整个实例必须声明为 `mut`（Rust 不支持单独标记某个字段可变）。

```rust
#[derive(Debug)]
struct User {
    username: String,
    email: String,
    age: u32,
    active: bool,
}

fn main() {
    let user1 = User {
        username: String::from("alice"),
        email: String::from("alice@example.com"),
        age: 30,
        active: true,
    };

    println!("用户名: {}", user1.username);
    println!("邮箱: {}", user1.email);
    println!("年龄: {}", user1.age);
    println!("激活: {}", user1.active);
}
```

运行结果：

```
用户名: alice
邮箱: alice@example.com
年龄: 30
激活: true
```

### 1.1 字段初始化简写

当变量名与字段名相同时，可省略重复的 `field: field` 写法：

```rust
fn build_user(username: String, email: String) -> User {
    User {
        username,   // 等价于 username: username
        email,      // 等价于 email: email
        age: 0,
        active: true,
    }
}
```

## 二、元组结构体与单元结构体

### 2.1 元组结构体（`Tuple Struct`）

元组结构体有类型名但没有字段名，适合为基础类型创建语义包装，防止不同含义的同类型数据被混用：

```rust
#[derive(Debug, PartialEq)]
struct Color(u8, u8, u8);

#[derive(Debug, PartialEq)]
struct Point(f64, f64);

fn main() {
    let red = Color(255, 0, 0);
    let origin = Point(0.0, 0.0);

    println!("红色: {:?}", red);
    println!("原点: ({}, {})", origin.0, origin.1);

    // 解构
    let Color(r, g, b) = red;
    println!("R={r}, G={g}, B={b}");
}
```

运行结果：

```
红色: Color(255, 0, 0)
原点: (0, 0)
R=255, G=0, B=0
```

> `Color` 与 `Point` 虽然都是三个数字，但类型系统会阻止两者相互传递，编译期就能捕获逻辑错误。

用索引 `.0`、`.1` 访问字段，也支持模式解构。

### 2.2 单元结构体（`Unit Struct`）

没有任何字段的结构体，常用于实现 `trait` 而不需要持有数据，或作为泛型占位符：

```rust
#[derive(Debug)]
struct Marker;

fn main() {
    let m = Marker;
    println!("标记: {:?}", m);
}
```

运行结果：

```
标记: Marker
```

单元结构体不占内存（`ZST`，`zero-sized type`），编译器会将其优化掉。

## 三、`impl` 块：方法与关联函数

### 3.1 方法

方法定义在 `impl` 块内，第一个参数是 `self`（接收者）。接收者有三种形式：

| 接收者 | 语义 | 典型用途 |
|--------|------|----------|
| `&self` | 不可变借用 | 读取数据、计算结果 |
| `&mut self` | 可变借用 | 修改字段 |
| `self` | 消耗所有权 | 转换为另一类型（builder 模式） |

```rust
#[derive(Debug)]
struct Rectangle {
    width: f64,
    height: f64,
}

impl Rectangle {
    fn area(&self) -> f64 {
        self.width * self.height
    }

    fn perimeter(&self) -> f64 {
        2.0 * (self.width + self.height)
    }

    fn is_square(&self) -> bool {
        self.width == self.height
    }

    fn scale(&mut self, factor: f64) {
        self.width *= factor;
        self.height *= factor;
    }
}

fn main() {
    let mut rect = Rectangle { width: 4.0, height: 3.0 };
    println!("面积: {}", rect.area());
    println!("周长: {}", rect.perimeter());
    println!("是正方形: {}", rect.is_square());

    rect.scale(2.0);
    println!("缩放后: {:?}", rect);
}
```

运行结果：

```
面积: 12
周长: 14
是正方形: false
缩放后: Rectangle { width: 8.0, height: 6.0 }
```

### 3.2 关联函数

关联函数不接受 `self`，通过 `TypeName::function()` 调用，最常见的用途是构造器：

```rust
impl Rectangle {
    fn new(width: f64, height: f64) -> Self {
        Rectangle { width, height }
    }

    fn square(size: f64) -> Self {
        Rectangle { width: size, height: size }
    }
}

fn main() {
    let sq = Rectangle::square(5.0);
    println!("正方形面积: {}", sq.area());
}
```

运行结果：

```
正方形面积: 25
```

> 一个类型可以有多个 `impl` 块，编译器会将它们合并。在同一个 `impl` 块内可以同时定义方法和关联函数，没有顺序限制。

## 四、`struct` 更新语法

用 `..other` 从已有实例填充未显式指定的字段，常见于配置覆盖场景：

```rust
#[derive(Debug)]
struct User {
    username: String,
    email: String,
    age: u32,
    active: bool,
}

fn main() {
    let user1 = User {
        username: String::from("alice"),
        email: String::from("alice@example.com"),
        age: 30,
        active: true,
    };

    let user2 = User {
        email: String::from("bob@example.com"),
        username: String::from("bob"),
        ..user1   // age 和 active 来自 user1
    };

    println!("{:?}", user2);
}
```

运行结果：

```
User { username: "bob", email: "bob@example.com", age: 0, active: true }
```

> 注意：`..user1` 会**移动**（`move`）`user1` 中未被 `Copy` 的字段（例如 `String`）。若 `user1` 的 `String` 字段被移入 `user2`，则 `user1` 此后不可再使用。若所有剩余字段均实现了 `Copy`（如本例中只剩 `u32`、`bool`），则 `user1` 仍可用。

## 五、`struct` 的所有权与借用

### 5.1 所有权转移与字段解构

将 `struct` 赋值给新变量或传入函数，会移动整个实例。通过解构可以精确控制哪些字段被移出：

```rust
#[derive(Debug)]
struct Config {
    host: String,
    port: u16,
}

fn print_host(cfg: &Config) {
    println!("主机: {}", cfg.host);
}

fn main() {
    let cfg = Config {
        host: String::from("localhost"),
        port: 8080,
    };

    // 借用：cfg 所有权不转移
    print_host(&cfg);
    println!("端口: {}", cfg.port);

    // 解构移出 String 字段
    let Config { host, port } = cfg;
    println!("host 已移出: {host}, port: {port}");
    
    // println!("{:?}", cfg.host); // 这里会报错，因为 cfg.host 已经被移出，cfg 现在是无效的
}
```

运行结果：

```
主机: localhost
端口: 8080
host 已移出: localhost, port: 8080
```

### 5.2 带生命周期标注的借用字段

若 `struct` 的字段是引用，必须用生命周期参数标注，确保引用的存活时间不短于 `struct` 本身：

**语法：**

```rust
struct StructName<'a> {
    field: &'a str,
}
```

**参数：**

| 参数 | 说明 |
|------|------|
| `'a` | 生命周期参数，表示借用字段的存活范围至少覆盖 `struct` 实例的存活范围 |

```rust
#[derive(Debug)]
struct Excerpt<'a> {
    text: &'a str,
}

impl<'a> Excerpt<'a> {
    fn first_word(&self) -> &str {
        self.text.split_whitespace().next().unwrap_or("")
    }
}

fn main() {
    let novel = String::from("Call me Ishmael. Some years ago...");
    let first_sentence = novel.split('.').next().unwrap();

    let excerpt = Excerpt { text: first_sentence };
    println!("摘录: {}", excerpt.text);
    println!("第一个词: {}", excerpt.first_word());
}
```

运行结果：

```
摘录: Call me Ishmael
第一个词: Call
```

> 生命周期标注不改变引用的存活时间，只是向编译器描述各引用之间的约束关系。大多数情况下，借用检查器可以通过**生命周期省略规则**自动推断，无需手动标注。

### 5.3 借用字段 vs 拥有所有权字段

**大多数场景直接用拥有所有权的类型（`String`、`Vec<T>` 等）即可**，不必引入生命周期。借用字段的使用场景非常具体：

| 场景 | 原因 |
|------|------|
| 零拷贝解析（`HTTP` 头、`JSON`、`CSV`） | 直接切片指向原始 `buffer`，避免复制整段数据 |
| `no_std` / 嵌入式，无堆分配 | 没有 `String`，只能用 `&str` |
| 临时"视图"结构体 | 生命周期短、明确依附于某个已有数据，如迭代器、访问者模式 |
| 数据量极大，复制代价不可接受 | 例如持有几 MB 文件内容的切片 |

借用字段的代价是：`struct` 的生命周期被"钉"在数据源上，不能轻易放入 `Vec`、跨线程传递，也不能自由地从函数中返回；在异步代码里这个约束尤为棘手。

实践中推荐的决策路径：

```
先用 String / Vec<T>（拥有所有权）
  ↓ 遇到明显性能瓶颈或 no_std 约束
再换 &'a str / &'a [T]（借用字段）
```

Rust 生态里大量库（`serde`、`nom`）的零拷贝路径才会用借用字段；普通业务结构体几乎全用拥有所有权的类型。

## 六、`derive` 宏常用用法

`#[derive(...)]` 让编译器自动生成常用 `trait` 的实现，省去大量模板代码。

| `derive` 目标 | 功能 | 前提条件 |
|---------------|------|----------|
| `Debug` | 支持 `{:?}` 格式化输出 | 所有字段实现 `Debug` |
| `Clone` | 支持 `.clone()` 深拷贝 | 所有字段实现 `Clone` |
| `Copy` | 赋值时自动复制，不移动 | 所有字段实现 `Copy`；需同时 `derive Clone` |
| `PartialEq` | 支持 `==` / `!=` 比较 | 所有字段实现 `PartialEq` |
| `Eq` | 完全等价关系 | 需同时 `derive PartialEq` |
| `Hash` | 支持作为 `HashMap` 的键 | 需同时 `derive PartialEq` |
| `Default` | 提供 `Type::default()` 零值构造 | 所有字段实现 `Default` |
| `PartialOrd` / `Ord` | 支持大小比较与排序 | 字段顺序决定比较顺序 |

```rust
#[derive(Debug, Clone, PartialEq, Hash)]
struct Point {
    x: i32,
    y: i32,
}

#[derive(Debug, Clone, PartialEq, Default)]
struct Config {
    debug: bool,
    workers: usize,
    name: String,
}

fn main() {
    let p1 = Point { x: 1, y: 2 };
    let p2 = p1.clone();
    println!("p1 == p2: {}", p1 == p2);
    println!("{:?}", p1);

    let cfg = Config::default();
    println!("默认配置: {:?}", cfg);

    let cfg2 = Config {
        debug: true,
        workers: 4,
        name: String::from("app"),
    };
    println!("自定义配置: {:?}", cfg2);
}
```

运行结果：

```
p1 == p2: true
Point { x: 1, y: 2 }
默认配置: Config { debug: false, workers: 0, name: "" }
自定义配置: Config { debug: true, workers: 4, name: "app" }
```

> `Default` 对各类型的零值：`bool` → `false`，数字 → `0`，`String` → `""`，`Vec<T>` → 空向量，`Option<T>` → `None`。

## 七、自定义 `trait` 实现

`derive` 只能处理标准 `trait`；复杂的格式化或运算逻辑需要手动 `impl`。以 `Display` 为例：

```rust
use std::fmt;

struct Matrix {
    data: [[f64; 2]; 2],
}

impl fmt::Display for Matrix {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "[{:.1}, {:.1}]\n[{:.1}, {:.1}]",
            self.data[0][0], self.data[0][1],
            self.data[1][0], self.data[1][1]
        )
    }
}

fn main() {
    let m = Matrix {
        data: [[1.0, 2.0], [3.0, 4.0]],
    };
    println!("{}", m);
}
```

运行结果：

```
[1.0, 2.0]
[3.0, 4.0]
```

`Debug` 用于调试输出（`{:?}`），`Display` 用于面向用户的展示（`{}`）。两者都可以手动实现；若两者都需要，通常先 `#[derive(Debug)]` 再手写 `Display`。

## 八、实战：任务管理器

综合以上知识点，构建一个简单的任务管理器，演示 `struct` 嵌套、`enum` 字段、`impl` 封装以及集合操作：

```rust
#[derive(Debug, Clone, PartialEq)]
enum Priority {
    Low,
    Medium,
    High,
}

#[derive(Debug, Clone)]
struct Task {
    id: u32,
    title: String,
    done: bool,
    priority: Priority,
}

impl Task {
    fn new(id: u32, title: &str, priority: Priority) -> Self {
        Task {
            id,
            title: title.to_string(),
            done: false,
            priority,
        }
    }

    fn complete(&mut self) {
        self.done = true;
    }
}

struct TaskManager {
    tasks: Vec<Task>,
    next_id: u32,
}

impl TaskManager {
    fn new() -> Self {
        TaskManager { tasks: Vec::new(), next_id: 1 }
    }

    fn add(&mut self, title: &str, priority: Priority) -> u32 {
        let id = self.next_id;
        self.tasks.push(Task::new(id, title, priority));
        self.next_id += 1;
        id
    }

    fn complete(&mut self, id: u32) -> bool {
        if let Some(task) = self.tasks.iter_mut().find(|t| t.id == id) {
            task.complete();
            true
        } else {
            false
        }
    }

    fn pending(&self) -> Vec<&Task> {
        self.tasks.iter().filter(|t| !t.done).collect()
    }
}

fn main() {
    let mut mgr = TaskManager::new();
    mgr.add("写文档", Priority::High);
    mgr.add("修复 Bug", Priority::Medium);
    mgr.add("代码审查", Priority::Low);

    mgr.complete(1);

    println!("待处理任务:");
    for task in mgr.pending() {
        println!("  [{}] {:?} - {}", task.id, task.priority, task.title);
    }
}
```

运行结果：

```
待处理任务:
  [2] Medium - 修复 Bug
  [3] Low - 代码审查
```

这个示例展示了几个典型模式：`new()` 作为惯用构造器、内部状态封装（`next_id` 由 `TaskManager` 独自管理）、通过 `&mut self` 修改集合、通过 `&self` 返回借用切片。实际项目中可以在此基础上增加持久化、序列化（`serde` 的 `Serialize`/`Deserialize`）等能力，只需在 `struct` 上添加对应的 `derive` 即可。
