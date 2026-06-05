---
title: Trait 特征介绍与实战
published: true
layout: post
date: 2026-05-13 16:00:00
permalink: /rust/trait.html
tags:
  - Trait
  - 泛型
  - 动态派发
  - 关联类型
categories:
  - Rust
---

`trait` 是 Rust 表达“某种能力”的核心机制。它类似其他语言中的接口（`interface`），但和 Rust 的泛型、所有权、生命周期、静态派发、动态派发深度结合。理解 `trait`，才能写出可复用、可组合、又保持零成本抽象的 Rust 代码。

本文从基础语法开始，逐步介绍默认方法、`trait bound`、`impl Trait`、关联类型、`dyn Trait`、对象安全，以及常见标准库 `trait` 的使用方式。

## 一、Trait 基础概念

### 1.1 定义 Trait

`trait` 定义一组类型需要提供的方法签名：

```rust
trait Summary {
    fn summarize(&self) -> String;
}
```

`Summary` 表示“可以被摘要”的能力。任何类型只要实现了 `Summary`，就可以被当作具备摘要能力的类型使用。

`trait` 中的方法不一定都要包含 `self`。是否需要接收者，取决于这个方法是否依赖某个具体实例：

| 写法 | 是否是实例方法 | 含义 | 典型用途 |
|------|----------------|------|----------|
| `fn new() -> Self` | 否 | 关联函数，不接收实例 | 构造值、工具函数 |
| `fn name(&self) -> &str` | 是 | 不可变借用实例 | 读取数据 |
| `fn rename(&mut self, name: String)` | 是 | 可变借用实例 | 修改数据 |
| `fn into_inner(self) -> T` | 是 | 消耗实例所有权 | 类型转换、取出内部值 |
| `fn normalize(self) -> Self` | 是 | 消耗实例所有权 | 链式转换、builder 风格 |

其中 `mut self` 不是一种新的借用方式，它仍然会移动并消耗调用者的值；`mut` 只表示方法体内部的 `self` 变量可以被重新赋值或修改。需要注意：没有默认实现的方法签名中应写 `self`，不要写 `mut self`；如果实现时需要修改被移动进来的值，可以在 `impl` 的方法实现中写 `mut self`。若只想修改原实例而不消耗它，应使用 `&mut self`。

下面是几种接收者写法的完整示例：

```rust
struct Counter {
    value: i32,
}

trait CounterOps {
    fn new(value: i32) -> Self;
    fn value(&self) -> i32;
    fn increment(&mut self);
    fn reset(self) -> Self;
    fn into_value(self) -> i32;
}

impl CounterOps for Counter {
    fn new(value: i32) -> Self {
        Counter { value }
    }

    fn value(&self) -> i32 {
        self.value
    }

    fn increment(&mut self) {
        self.value += 1;
    }

    fn reset(mut self) -> Self {
        self.value = 0;
        self
    }

    fn into_value(self) -> i32 {
        self.value
    }
}

fn main() {
    let mut counter = Counter::new(10);
    counter.increment();
    println!("当前值: {}", counter.value());

    let counter = counter.reset();
    println!("重置后: {}", counter.value());

    let value = counter.into_value();
    println!("取出的值: {}", value);
}
```

运行结果：

```text
当前值: 11
重置后: 0
取出的值: 0
```

### 1.2 为类型实现 Trait

**语法：**

```rust
impl TraitName for TypeName {
    fn method_name(&self) -> ReturnType {
        // 方法实现
    }
}
```

其中 `TraitName` 是要实现的 `trait`，`TypeName` 是具体类型。`impl` 块中必须提供该 `trait` 要求的所有无默认实现的方法。

```rust
trait Summary {
    fn summarize(&self) -> String;
}

struct Article {
    title: String,
    author: String,
}

impl Summary for Article {
    fn summarize(&self) -> String {
        format!("《{}》 by {}", self.title, self.author)
    }
}

fn main() {
    let article = Article {
        title: String::from("Rust Trait 入门"),
        author: String::from("Alice"),
    };

    println!("{}", article.summarize());
}
```

运行结果：

```text
《Rust Trait 入门》 by Alice
```

`impl Summary for Article` 的含义是：为 `Article` 类型实现 `Summary` 这个 `trait`。

### 1.3 Trait 只描述行为，不保存字段

`trait` 可以定义方法、关联函数、关联类型、关联常量，但不能像 `struct` 一样直接定义实例字段：

```rust
trait Named {
    fn name(&self) -> &str;
}
```

字段仍然由具体类型保存：

```rust
struct User {
    name: String,
}

impl Named for User {
    fn name(&self) -> &str {
        &self.name
    }
}
```

## 二、默认方法

### 2.1 提供默认实现

`trait` 方法可以只有签名，也可以提供默认实现：

```rust
trait Summary {
    fn author(&self) -> &str;

    fn summarize(&self) -> String {
        format!("作者: {}", self.author())
    }
}

struct Post {
    author: String,
}

impl Summary for Post {
    fn author(&self) -> &str {
        &self.author
    }
}

fn main() {
    let post = Post {
        author: String::from("Bob"),
    };

    println!("{}", post.summarize());
}
```

运行结果：

```text
作者: Bob
```

`Post` 只实现了 `author()`，但可以直接使用 `summarize()` 的默认实现。

### 2.2 覆盖默认实现

具体类型可以覆盖默认方法：

```rust
trait Summary {
    fn summarize(&self) -> String {
        String::from("默认摘要")
    }
}

struct News {
    headline: String,
}

impl Summary for News {
    fn summarize(&self) -> String {
        format!("新闻: {}", self.headline)
    }
}

fn main() {
    let news = News {
        headline: String::from("Rust 发布新版本"),
    };

    println!("{}", news.summarize());
}
```

运行结果：

```text
新闻: Rust 发布新版本
```

> 注意：覆盖默认方法后，不能在覆盖实现中直接调用“父级默认实现”。如果需要复用默认逻辑，应把公共逻辑拆成独立函数。

## 三、Trait 作为参数

### 3.1 使用 `impl Trait`

函数参数可以声明为“任何实现了某个 `trait` 的类型”：

```rust
trait Summary {
    fn summarize(&self) -> String;
}

struct Article {
    title: String,
}

impl Summary for Article {
    fn summarize(&self) -> String {
        format!("文章: {}", self.title)
    }
}

fn notify(item: &impl Summary) {
    println!("通知: {}", item.summarize());
}

fn main() {
    let article = Article {
        title: String::from("Trait 作为参数"),
    };

    notify(&article);
}
```

运行结果：

```text
通知: 文章: Trait 作为参数
```

`&impl Summary` 表示参数是某个实现了 `Summary` 的类型的引用。

### 3.2 使用泛型 Trait Bound

`impl Trait` 适合简单参数；当函数签名更复杂时，通常使用泛型约束（`trait bound`）：

```rust
trait Summary {
    fn summarize(&self) -> String;
}

struct Comment {
    user: String,
    body: String,
}

impl Summary for Comment {
    fn summarize(&self) -> String {
        format!("{}: {}", self.user, self.body)
    }
}

fn notify<T: Summary>(item: &T) {
    println!("通知: {}", item.summarize());
}

fn main() {
    let comment = Comment {
        user: String::from("Carol"),
        body: String::from("写得很清楚"),
    };

    notify(&comment);
}
```

运行结果：

```text
通知: Carol: 写得很清楚
```

`fn notify<T: Summary>(item: &T)` 与 `fn notify(item: &impl Summary)` 在这个例子中效果相同。

### 3.3 多个参数是否必须同类型

`impl Trait` 写法中，每个 `impl Summary` 都可以是不同的具体类型：

```rust
fn compare(a: &impl Summary, b: &impl Summary) {
    println!("{}", a.summarize());
    println!("{}", b.summarize());
}
```

如果希望两个参数必须是同一种具体类型，应使用同一个泛型参数：

```rust
fn compare_same_type<T: Summary>(a: &T, b: &T) {
    println!("{}", a.summarize());
    println!("{}", b.summarize());
}
```

## 四、多个 Trait Bound 与 `where` 子句

### 4.1 使用 `+` 组合多个约束

一个泛型参数可以同时要求实现多个 `trait`。这种约束表示：调用函数时传入的具体类型必须同时具备这些能力，否则编译器会拒绝调用。

例如，`println!("{}", value)` 需要类型实现 `Display`，`println!("{:?}", value)` 需要类型实现 `Debug`。如果函数内部同时使用这两种格式化方式，就需要把两个约束都写出来。

**语法：**

```rust
fn function_name<T: TraitA + TraitB>(value: T) {
    // value 同时具备 TraitA 和 TraitB 的能力
}
```

也可以用于 `impl Trait` 参数：

```rust
fn function_name(value: impl TraitA + TraitB) {
    // value 同时具备 TraitA 和 TraitB 的能力
}
```

下面的例子要求参数同时实现 `Display` 和 `Debug`：

```rust
use std::fmt::{Debug, Display};

fn print_value<T: Display + Debug>(value: T) {
    println!("Display: {}", value);
    println!("Debug: {:?}", value);
}

fn main() {
    print_value(42);
}
```

运行结果：

```text
Display: 42
Debug: 42
```

### 4.2 使用 `where` 提高可读性

当泛型参数很多，或者约束本身很长时，把所有约束都放在函数名后面会让签名难以阅读。`where` 子句可以把“泛型参数列表”和“约束条件”分开，让函数的参数和返回值更突出。

`where` 子句不会改变类型系统语义，它只是另一种写法。下面两种形式等价：

```rust
fn print_value<T: Display>(value: T) {
    println!("{}", value);
}
```

```rust
fn print_value<T>(value: T)
where
    T: Display,
{
    println!("{}", value);
}
```

**语法：**

```rust
fn function_name<T, U>(t: T, u: U) -> ReturnType
where
    T: TraitA + TraitB,
    U: TraitC,
{
    // 函数体
}
```

下面的例子同时使用生命周期参数和泛型参数。`'a` 说明返回的字符串切片来自 `x` 或 `y`，`where T: Display` 说明 `message` 必须可以被 `{}` 格式化输出：

```rust
use std::fmt::Display;

fn longest_with_message<'a, T>(
    x: &'a str,
    y: &'a str,
    message: T,
) -> &'a str
where
    T: Display,
{
    println!("提示: {}", message);
    if x.len() >= y.len() { x } else { y }
}

fn main() {
    let left = "trait";
    let right = "generic";
    let result = longest_with_message(left, right, "开始比较字符串长度");

    println!("更长的是: {}", result);
}
```

运行结果：

```text
提示: 开始比较字符串长度
更长的是: generic
```

> **提示**：`where` 子句不改变语义，只改善复杂泛型签名的可读性。

## 五、返回实现了 Trait 的类型

函数返回值也可以使用 `impl Trait`，表示“返回某个实现了指定 `trait` 的具体类型”。调用者只知道返回值具备这个 `trait` 的能力，不需要知道真实类型名称。

这种写法常用于隐藏复杂返回类型，尤其是迭代器、闭包、构建器结果等场景。但要注意：`impl Trait` 返回值背后仍然必须是**一个确定的具体类型**，不能在不同分支返回不同结构体。

**语法：**

```rust
fn function_name() -> impl TraitName {
    ConcreteType
}
```

如果返回值还需要同时满足多个约束，可以继续使用 `+`：

```rust
fn function_name() -> impl TraitA + TraitB {
    ConcreteType
}
```

下面的例子隐藏了真实返回类型 `Article`，调用者只依赖 `Summary` 提供的 `summarize()` 方法：

```rust
trait Summary {
    fn summarize(&self) -> String;
}

struct Article {
    title: String,
}

impl Summary for Article {
    fn summarize(&self) -> String {
        format!("文章: {}", self.title)
    }
}

fn create_summary() -> impl Summary {
    Article {
        title: String::from("返回 impl Trait"),
    }
}

fn main() {
    let item = create_summary();
    println!("{}", item.summarize());
}
```

运行结果：

```text
文章: 返回 impl Trait
```

`-> impl Summary` 的真实返回类型仍然是一个确定的具体类型，只是调用者不用知道这个具体类型。

下面这种写法不能通过编译，因为两个分支返回了不同的具体类型：

```rust
// 不能直接运行：两个分支的具体返回类型不同
fn create(flag: bool) -> impl Summary {
    if flag {
        Article { title: String::from("文章") }
    } else {
        Comment { body: String::from("评论") }
    }
}
```

如果确实需要根据条件返回不同类型，应使用动态派发，例如 `Box<dyn Summary>`。

## 六、关联类型

### 6.1 什么是关联类型

关联类型（`associated type`）把“实现者需要指定的类型”放在 `trait` 内部。它适合表达“这个 `trait` 的每个实现都会关联一个结果类型、元素类型或错误类型”这类关系。

标准库的 `Iterator` 就使用了关联类型：每个迭代器实现都要声明自己每次迭代产生的 `Item` 类型。

**语法：**

```rust
trait TraitName {
    type AssociatedType;

    fn method(&self) -> Self::AssociatedType;
}
```

实现时通过 `type AssociatedType = ConcreteType;` 指定具体类型：

```rust
impl TraitName for TypeName {
    type AssociatedType = ConcreteType;

    fn method(&self) -> Self::AssociatedType {
        // 返回 ConcreteType
    }
}
```

下面用一个简化版迭代器说明关联类型的完整用法。`Counter` 把 `Item` 指定为 `u32`，因此 `next()` 返回 `Option<u32>`：

```rust
struct Counter {
    current: u32,
    end: u32,
}

trait SimpleIterator {
    type Item;

    fn next(&mut self) -> Option<Self::Item>;
}

impl SimpleIterator for Counter {
    type Item = u32;

    fn next(&mut self) -> Option<Self::Item> {
        if self.current >= self.end {
            None
        } else {
            self.current += 1;
            Some(self.current)
        }
    }
}

fn main() {
    let mut counter = Counter { current: 0, end: 3 };

    while let Some(value) = counter.next() {
        println!("value = {}", value);
    }
}
```

运行结果：

```text
value = 1
value = 2
value = 3
```

### 6.2 关联类型与泛型 Trait 的区别

关联类型和泛型 `trait` 都能表达“某个行为涉及另一个类型”，但它们强调的建模关系不同。

泛型 `trait<T>` 把类型参数交给使用者或实现者选择。同一个类型可以针对不同的 `T` 实现多次，只要这些实现不冲突。

**泛型 trait 语法：**

```rust
trait Convert<T> {
    fn convert(&self) -> T;
}
```

关联类型则把相关类型固定到某个具体实现中。对于同一个 `trait` 和同一个类型，关联类型只能在该实现里指定一次，通常表示“这个实现只有一种自然输出类型”。

**关联类型语法：**

```rust
trait Parser {
    type Output;

    fn parse(&self, input: &str) -> Self::Output;
}
```

选择建议：

| 写法 | 适合场景 |
|------|----------|
| 泛型 `trait<T>` | 同一个类型可能针对多个 `T` 分别实现 |
| 关联类型 `type Output` | 每个实现者只有一个明确的输出类型 |

## 七、静态派发与动态派发

### 7.1 静态派发

泛型约束默认使用静态派发（`static dispatch`）。所谓“静态”，指方法调用目标在编译期就能确定；程序运行时不需要再根据对象里的类型信息查找应该调用哪个方法。

关键原因在于 Rust 泛型会在编译期进行单态化（`monomorphization`）：编译器会根据每个调用点传入的具体类型，把泛型函数生成对应的具体版本。

以 `fn render<T: Draw>(component: &T)` 为例：

1. 函数定义阶段，`T` 只是一个类型参数，约束是“必须实现 `Draw`”。
2. 调用 `render(&button)` 时，变量 `button` 的类型已经由 `let button = Button;` 确定为 `Button`。
3. 编译器由实参 `&button` 推导出本次调用的 `T = Button`。
4. 单态化后，编译器可以把这次调用理解成类似 `render_for_button(component: &Button)` 的专门版本。
5. 在这个专门版本里，`component.draw()` 的目标就是 `<Button as Draw>::draw(component)`，不需要运行时查表。

可以把单态化后的形态理解为下面的伪代码：

```rust
fn render_for_button(component: &Button) {
    <Button as Draw>::draw(component);
}
```

这就是“运行时没有虚表查找开销”的来源：调用目标已经在编译期固定，生成的机器码可以直接调用 `Button` 的 `draw()` 实现。进一步地，编译器还可能内联这个方法，把 `draw()` 的方法体直接展开到调用处。

静态派发的代价是：如果同一个泛型函数分别用于 `Button`、`Input`、`Image` 等多个具体类型，编译器可能为这些类型各生成一份专门代码，编译产物体积会变大。

**语法：**

```rust
fn function_name<T: TraitName>(value: &T) {
    value.method();
}
```

或使用参数位置的 `impl Trait`：

```rust
fn function_name(value: &impl TraitName) {
    value.method();
}
```

下面的 `render()` 在编译期就知道传入的是 `Button`：

```rust
trait Draw {
    fn draw(&self);
}

struct Button;

impl Draw for Button {
    fn draw(&self) {
        println!("绘制按钮");
    }
}

fn render<T: Draw>(component: &T) {
    component.draw();
}

fn main() {
    let button = Button;
    render(&button);
}
```

运行结果：

```text
绘制按钮
```

### 7.2 动态派发与 `dyn Trait`

动态派发（dynamic dispatch）把方法调用推迟到运行时决定。`dyn Trait` 表示一个 `trait object`：调用方只知道它实现了某个 `trait`，不知道它背后的具体类型。

由于 `dyn Trait` 的大小在编译期不固定，不能直接作为普通局部变量或 `Vec<dyn Trait>` 元素使用，必须通过指针间接访问。常用选择主要有下面几类：

| 写法 | 所有权关系 | 适合场景 |
|------|------------|----------|
| `&dyn Trait` | 不拥有值，只是不可变借用 | 临时调用，不需要保存对象 |
| `&mut dyn Trait` | 不拥有值，只是可变借用 | 临时调用，并需要修改对象 |
| `Box<dyn Trait>` | 独占拥有堆上的值 | 把不同实现放进集合、返回不同实现 |
| `Rc<dyn Trait>` | 单线程引用计数共享所有权 | 多个所有者共享同一个对象，不跨线程 |
| `Arc<dyn Trait>` | 线程安全引用计数共享所有权 | 多线程共享同一个对象 |

这些写法都属于胖指针（fat pointer）：除了指向真实数据的地址，还会携带一份指向虚表（vtable）的地址。虚表里保存了该具体类型对 `trait` 方法的实现入口，所以运行时可以通过虚表找到应该调用哪个方法。

**语法：**

```rust
let value: &dyn TraitName = &concrete_value;
let mutable: &mut dyn TraitName = &mut concrete_value;
let boxed: Box<dyn TraitName> = Box::new(concrete_value);
let shared: std::rc::Rc<dyn TraitName> = std::rc::Rc::new(concrete_value);
let thread_shared: std::sync::Arc<dyn TraitName> = std::sync::Arc::new(concrete_value);
```

常见容器写法：

```rust
let items: Vec<Box<dyn TraitName>> = vec![
    Box::new(TypeA),
    Box::new(TypeB),
];
```

下面的例子把 `Button` 和 `Input` 放进同一个集合中统一调用：

```rust
trait Draw {
    fn draw(&self);
}

struct Button {
    text: String,
}

struct Input {
    placeholder: String,
}

impl Draw for Button {
    fn draw(&self) {
        println!("Button: {}", self.text);
    }
}

impl Draw for Input {
    fn draw(&self) {
        println!("Input: {}", self.placeholder);
    }
}

fn main() {
    let components: Vec<Box<dyn Draw>> = vec![
        Box::new(Button {
            text: String::from("提交"),
        }),
        Box::new(Input {
            placeholder: String::from("请输入用户名"),
        }),
    ];

    for component in components {
        component.draw();
    }
}
```

运行结果：

```text
Button: 提交
Input: 请输入用户名
```

这个例子使用 `Vec<Box<dyn Draw>>`，原因是 `Vec` 的每个元素必须有固定大小，而 `Box<dyn Draw>` 这个指针本身大小固定；真实的 `Button` 和 `Input` 存放在堆上，通过 `Box` 间接访问。循环调用 `component.draw()` 时，程序通过虚表找到 `Button` 或 `Input` 各自的 `draw()` 实现。

### 7.3 静态派发与动态派发对比

| 方式 | 写法 | 优点 | 代价 |
|------|------|------|------|
| 静态派发 | `T: Trait` / `impl Trait` | 性能好，可内联 | 不适合异构集合 |
| 动态派发 | `dyn Trait` | 支持不同具体类型统一处理 | 有虚表调用开销，限制更多 |

一般建议：优先使用泛型和 `impl Trait`；只有在需要异构集合、插件化结构、运行时选择实现时，再使用 `dyn Trait`。

## 八、对象安全

并非所有 `trait` 都能变成 `dyn Trait`。能作为 `trait object` 使用的 `trait` 必须满足对象安全（`object safety`）规则。

对象安全的核心问题是：通过 `dyn Trait` 调用方法时，编译器只知道虚表中的方法入口，不知道背后的具体类型。因此，方法签名不能要求调用方在运行时凭空知道具体的 `Self` 类型，也不能让虚表需要支持无限多种泛型实例。

常见限制：

| 不对象安全的写法 | 原因 |
|------------------|------|
| 方法返回 `Self` | 动态派发时调用者不知道具体返回类型 |
| 方法带泛型参数 | 虚表无法为无限多种泛型实例准备入口 |
| 要求 `Self: Sized` 的方法 | 只能在具体类型上调用，不能通过 `dyn Trait` 调用 |

**语法结构：**

```rust
trait TraitName {
    fn object_safe_method(&self);

    fn concrete_only_method(self) -> Self
    where
        Self: Sized;
}
```

带有 `where Self: Sized` 的方法不会进入 `dyn Trait` 的可调用接口，但它允许整个 `trait` 继续作为 `trait object` 使用。

可以把不适合动态派发的方法限制为 `Self: Sized`：

```rust
trait CloneLike {
    fn name(&self) -> &str;

    fn duplicate(&self) -> Self
    where
        Self: Sized;
}

struct Service {
    name: String,
}

impl CloneLike for Service {
    fn name(&self) -> &str {
        &self.name
    }

    fn duplicate(&self) -> Self {
        Service {
            name: self.name.clone(),
        }
    }
}

fn print_name(service: &dyn CloneLike) {
    println!("service = {}", service.name());
}

fn main() {
    let service = Service {
        name: String::from("user-service"),
    };

    print_name(&service);
    let copied = service.duplicate();
    println!("copied = {}", copied.name());
}
```

运行结果：

```text
service = user-service
copied = user-service
```

`duplicate()` 不能通过 `&dyn CloneLike` 调用，但 `name()` 可以，这样整个 `trait` 仍然可以作为对象使用。

## 九、常见标准库 Trait

### 9.1 `Debug` 与 `Display`

`Debug` 面向开发调试，使用 `{:?}` 输出，通常通过 `#[derive(Debug)]` 自动生成。`Display` 面向用户展示，使用 `{}` 输出，标准库无法自动判断展示格式，因此通常需要手动实现。

**语法：**

```rust
#[derive(Debug)]
struct TypeName;

impl std::fmt::Display for TypeName {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "...")
    }
}
```

下面的例子同时支持调试输出和用户友好的坐标输出：

```rust
use std::fmt;

#[derive(Debug)]
struct Point {
    x: i32,
    y: i32,
}

impl fmt::Display for Point {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
    }
}

fn main() {
    let point = Point { x: 3, y: 4 };

    println!("Debug: {:?}", point);
    println!("Display: {}", point);
}
```

运行结果：

```text
Debug: Point { x: 3, y: 4 }
Display: (3, 4)
```

### 9.2 `Clone` 与 `Copy`

`Clone` 表示显式复制，需要调用 `clone()` 或由其他 API 触发复制逻辑。`Copy` 表示赋值、传参、返回时自动复制，原变量仍然可用。

从内存层面看，`Copy` 是按位复制（bitwise copy）：把栈上的那一段字节直接复制一份，不调用任何自定义逻辑，也不会分配新内存。整数、布尔值、字符、浮点数、只包含 `Copy` 字段的结构体都属于这种情况。

`Clone` 则是显式复制协议：调用 `clone()` 时，类型可以自己决定如何复制。对于只在栈上保存简单值的类型，`clone()` 可能和按位复制效果一样；但对于 `String`、`Vec<T>` 这类拥有堆内存的类型，`clone()` 通常会分配新的堆内存，并把堆上的数据也复制过去。

以 `String` 为例，它在栈上保存的是指针、长度、容量，真实字符串内容在堆上：

| 操作 | 栈上元数据 | 堆上数据 | 原变量是否还能使用 |
|------|------------|----------|--------------------|
| `let s2 = s1;` | 指针、长度、容量移动给 `s2` | 不复制 | `s1` 失效 |
| `let s2 = s1.clone();` | 新建一份元数据 | 分配并复制字符串内容 | `s1` 仍可用 |

如果 `String` 允许 `Copy`，赋值时就会出现两个变量持有同一块堆内存的指针，作用域结束时可能重复释放同一块内存。因此 Rust 禁止拥有堆资源或自定义析构逻辑的类型实现 `Copy`。

`Copy` 只能用于复制成本低且不会涉及资源所有权转移的类型。实现 `Copy` 的类型必须同时实现 `Clone`，所以通常一起派生。

**语法：**

```rust
#[derive(Clone, Copy)]
struct TypeName {
    field: CopyType,
}
```

下面的 `Pixel` 只包含 `u8` 字段，可以安全地实现 `Copy`：

```rust
#[derive(Clone, Copy, Debug)]
struct Pixel {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

fn main() {
    let p1 = Pixel { r: 255, g: 0, b: 0 };
    let p2 = p1;
    let _rgb_total = u16::from(p1.r) + u16::from(p1.g) + u16::from(p1.b);

    println!("p1 = {:?}", p1);
    println!("p2 = {:?}", p2);
}
```

运行结果：

```text
p1 = Pixel { r: 255, g: 0, b: 0 }
p2 = Pixel { r: 255, g: 0, b: 0 }
```

如果结构体包含 `String`、`Vec<T>` 等非 `Copy` 字段，就不能实现 `Copy`。

### 9.3 `PartialEq`

`PartialEq` 支持 `==` 和 `!=`。如果结构体的所有字段都实现了 `PartialEq`，通常可以直接使用 `#[derive(PartialEq)]`。

**语法：**

```rust
#[derive(PartialEq)]
struct TypeName(FieldType);
```

也可以手动实现自定义比较规则：

```rust
impl PartialEq for TypeName {
    fn eq(&self, other: &Self) -> bool {
        // 返回两个值是否相等
    }
}
```

下面的例子用新类型 `UserId` 避免把普通整数和用户 ID 混用，同时支持相等比较：

```rust
#[derive(Debug, PartialEq)]
struct UserId(u64);

fn main() {
    let a = UserId(1001);
    let b = UserId(1001);
    let c = UserId(1002);

    println!("a == b: {}", a == b);
    println!("a == c: {}", a == c);
}
```

运行结果：

```text
a == b: true
a == c: false
```

### 9.4 `From` 与 `Into`

`From` 定义“不会失败的类型转换”。实现了 `From<T> for U` 后，标准库会自动提供 `Into<U> for T`，所以实际代码中通常优先实现 `From`，使用时可按需要调用 `from()` 或 `into()`。

**语法：**

```rust
impl From<SourceType> for TargetType {
    fn from(value: SourceType) -> Self {
        TargetType
    }
}
```

下面的例子把 `&str` 规范化为小写用户名：

```rust
#[derive(Debug)]
struct Username(pub String);

impl From<&str> for Username {
    fn from(value: &str) -> Self {
        Username(value.trim().to_lowercase())
    }
}

fn main() {
    let name = Username::from(" Alice ");
    let other: Username = " Bob ".into();
    let _normalized_len = name.0.len() + other.0.len();

    println!("{:?}", name);
    println!("{:?}", other);
}
```

运行结果：

```text
Username("alice")
Username("bob")
```

## 十、实战示例：通知系统

下面用 `trait` 构建一个简单的通知系统：不同通知渠道实现同一个 `Notifier`，调用方只关心“能发送消息”这个能力。

这个例子的设计步骤如下：

| 步骤 | 说明 |
|------|------|
| 定义抽象能力 | `Notifier` 只声明 `send()`，不关心具体渠道 |
| 实现具体渠道 | 邮件和短信分别实现 `Notifier` |
| 面向抽象调用 | `broadcast()` 接收 `dyn Notifier` 集合 |
| 支持扩展 | 新增渠道时只需新增类型并实现 `Notifier` |

**语法结构：**

```rust
trait Capability {
    fn execute(&self, input: &str);
}

struct ConcreteType;

impl Capability for ConcreteType {
    fn execute(&self, input: &str) {
        // 具体实现
    }
}

fn run(items: &[Box<dyn Capability>]) {
    for item in items {
        item.execute("message");
    }
}
```

```rust
trait Notifier {
    fn send(&self, message: &str);
}

struct EmailNotifier {
    address: String,
}

struct SmsNotifier {
    phone: String,
}

impl Notifier for EmailNotifier {
    fn send(&self, message: &str) {
        println!("发送邮件到 {}: {}", self.address, message);
    }
}

impl Notifier for SmsNotifier {
    fn send(&self, message: &str) {
        println!("发送短信到 {}: {}", self.phone, message);
    }
}

fn broadcast(notifiers: &[Box<dyn Notifier>], message: &str) {
    for notifier in notifiers {
        notifier.send(message);
    }
}

fn main() {
    let notifiers: Vec<Box<dyn Notifier>> = vec![
        Box::new(EmailNotifier {
            address: String::from("admin@example.com"),
        }),
        Box::new(SmsNotifier {
            phone: String::from("13800000000"),
        }),
    ];

    broadcast(&notifiers, "服务已启动");
}
```

运行结果：

```text
发送邮件到 admin@example.com: 服务已启动
发送短信到 13800000000: 服务已启动
```

这个例子体现了 `trait` 的典型价值：

| 角色 | 职责 |
|------|------|
| `Notifier` | 定义统一能力 |
| `EmailNotifier` / `SmsNotifier` | 提供具体实现 |
| `broadcast` | 面向抽象编程，不依赖具体渠道 |
| `Box<dyn Notifier>` | 支持不同通知实现放入同一个集合 |

这里的参数类型 `&[Box<dyn Notifier>]` 可以拆开理解：

| 部分 | 含义 |
|------|------|
| `dyn Notifier` | 表示具体类型未知，只要求实现了 `Notifier` |
| `Box<dyn Notifier>` | 用 `Box` 拥有堆上的通知器对象，并让不同具体类型拥有统一的指针大小 |
| `Vec<Box<dyn Notifier>>` | 让 `EmailNotifier` 和 `SmsNotifier` 这类不同类型可以放进同一个 `Vec` |
| `&[Box<dyn Notifier>]` | 只借用这一组通知器，不转移 `Vec` 或其中对象的所有权 |

如果 `broadcast()` 写成 `fn broadcast(notifiers: Vec<Box<dyn Notifier>>, ...)`，调用函数时会把整个 `Vec` 的所有权移动进去，调用方之后不能继续使用 `notifiers`。当前写法使用切片借用，表示 `broadcast()` 只负责遍历并发送消息，不消费通知器列表。

如果业务只处理一种通知器类型，可以优先使用泛型版本：

```rust
fn broadcast_same_type<T: Notifier>(notifiers: &[T], message: &str) {
    for notifier in notifiers {
        notifier.send(message);
    }
}
```

泛型版本适合同构集合，动态派发版本适合异构集合。

## 十一、常见陷阱与最佳实践

### 11.1 不要把 Trait 设计得过大

`trait` 应该表达一组紧密相关的能力。过大的 `trait` 会让实现者被迫实现不需要的方法，也会降低复用性。

判断一个 `trait` 是否过大，可以看两个问题：

| 问题 | 如果答案是“是” |
|------|----------------|
| 是否有实现者只需要其中一部分方法 | 应考虑拆分 |
| 是否有调用方只依赖其中一两个方法 | 应考虑按调用场景定义更小的 `trait` |

**推荐结构：**

```rust
trait Readable {
    fn read(&self) -> String;
}

trait Writable {
    fn write(&mut self, content: &str);
}
```

比起一个同时包含读取、写入、刷新、关闭的大接口，拆成多个小 `trait` 更容易组合。

### 11.2 优先接收引用

如果函数只需要读取数据，优先接收 `&T` 或 `&impl Trait`，避免不必要的所有权转移：

**语法：**

```rust
fn read_only(value: &impl TraitName) {
    // 只读取，不获取所有权
}

fn mutate(value: &mut impl TraitName) {
    // 修改原值，但不获取所有权
}

fn consume(value: impl TraitName) {
    // 获取所有权，函数结束后原值不可再用
}
```

下面的例子只需要格式化输出字符串，因此接收 `&impl Display` 即可：

```rust
use std::fmt::Display;

fn print_item(item: &impl Display) {
    println!("{}", item);
}

fn main() {
    let text = String::from("hello");
    print_item(&text);
    println!("text 仍然可用: {}", text);
}
```

运行结果：

```text
hello
text 仍然可用: hello
```

### 11.3 区分 `impl Trait` 和 `dyn Trait`

`impl Trait` 和 `dyn Trait` 都能表达“某个值实现了某个 `trait`”，但它们解决的问题不同：

| 写法 | 决定具体类型的时间 | 主要用途 |
|------|--------------------|----------|
| `impl Trait` | 编译期 | 简化泛型签名、隐藏单一具体返回类型 |
| `dyn Trait` | 运行时 | 保存不同具体类型、插件式扩展 |

**语法对比：**

```rust
fn static_dispatch(value: &impl TraitName) {
    value.method();
}

fn dynamic_dispatch(value: &dyn TraitName) {
    value.method();
}
```

| 问题 | 推荐写法 |
|------|----------|
| 参数只需要某种能力 | `fn f(x: &impl Trait)` |
| 多个参数必须同一具体类型 | `fn f<T: Trait>(a: &T, b: &T)` |
| 返回单一隐藏具体类型 | `fn f() -> impl Trait` |
| 运行时保存不同具体类型 | `Box<dyn Trait>` |

### 11.4 遵守孤儿规则

Rust 的孤儿规则（`orphan rule`）要求：为某个类型实现某个 `trait` 时，`trait` 或类型至少有一个定义在当前 crate 中。

这条规则防止不同 crate 为同一组“外部类型 + 外部 trait”提供互相冲突的实现。

**允许的组合：**

| Trait 来源 | 类型来源 | 是否允许 |
|------------|----------|----------|
| 当前 crate | 当前 crate | 允许 |
| 当前 crate | 外部 crate | 允许 |
| 外部 crate | 当前 crate | 允许 |
| 外部 crate | 外部 crate | 不允许 |

因此，下面这种“外部 trait + 外部类型”的组合不能直接实现：

```rust
// 不能直接运行：Display 和 Vec<T> 都定义在标准库中
impl std::fmt::Display for Vec<String> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}
```

常见解决方式是使用新类型模式（`newtype pattern`）：

> 注意：类型别名不能解决这个问题。`type StringList = Vec<String>;` 只是给 `Vec<String>` 起了另一个名字，并没有创建新类型；对编译器来说它仍然是标准库类型 `Vec<String>`。

下面这种写法仍然违反孤儿规则：

```rust
// 不能直接运行：StringList 只是 Vec<String> 的别名，不是新类型
type StringList = Vec<String>;

impl std::fmt::Display for StringList {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.join(", "))
    }
}
```

必须定义一个当前 crate 拥有的新类型，再为这个新类型实现外部 `trait`：

```rust
use std::fmt;

struct StringList(Vec<String>);

impl fmt::Display for StringList {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0.join(", "))
    }
}

fn main() {
    let list = StringList(vec![String::from("rust"), String::from("trait")]);
    println!("{}", list);
}
```

运行结果：

```text
rust, trait
```

## 十二、速查表

| 主题 | 写法 | 说明 |
|------|------|------|
| 定义 `trait` | `trait Summary { fn summarize(&self) -> String; }` | 定义一组能力 |
| 实现 `trait` | `impl Summary for Article { ... }` | 为具体类型提供行为 |
| 默认方法 | 在 `trait` 中写方法体 | 实现者可直接使用或覆盖 |
| 参数简写 | `fn f(x: &impl Summary)` | 接收任意实现者 |
| 泛型约束 | `fn f<T: Summary>(x: &T)` | 可表达参数之间的类型关系 |
| 多约束 | `T: Display + Debug` | 要求同时实现多个 `trait` |
| `where` 子句 | `where T: Display` | 改善复杂签名可读性 |
| 返回抽象类型 | `-> impl Summary` | 隐藏具体返回类型 |
| 动态派发 | `Box<dyn Summary>` | 运行时通过虚表调用 |
| 关联类型 | `type Item;` | 由实现者指定相关类型 |
| 对象安全 | `dyn Trait` 的使用前提 | 不是所有 `trait` 都能动态派发 |

## 十三、总结

`trait` 是 Rust 抽象能力的基础：

- 用 `trait` 定义行为，用 `impl Trait for Type` 为类型提供行为。
- 简单参数优先使用 `impl Trait`，复杂泛型关系使用 `T: Trait` 和 `where`。
- 返回 `impl Trait` 时，真实返回类型必须是单一具体类型。
- 异构集合或插件式结构使用 `dyn Trait`，同时注意对象安全限制。
- 关联类型适合表达“每个实现者只有一个自然关联类型”的场景。
- 标准库大量依赖 `trait`，例如 `Debug`、`Display`、`Clone`、`Iterator`、`From`。

写 Rust 时，`trait` 不只是语法工具，更是拆分边界、表达约束、复用能力的设计工具。合理设计小而清晰的 `trait`，能让代码既灵活又保持强类型安全。
