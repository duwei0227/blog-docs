---
title: "[标准库] std::collections 集合类型原理与实战"
published: true
layout: post
date: 2026-05-27 10:00:00
permalink: /rust/std-collections.html
tags:
  - 集合
  - HashMap
  - BTreeMap
  - 数据结构
categories:
  - Rust
---

`std::collections` 是 Rust 标准库中提供通用集合类型的模块，涵盖动态数组、双端队列、链表、哈希表、B 树映射、集合与优先队列共 8 种类型。与其他语言不同，Rust 的集合 API 始终将**所有权**和**借用**融入设计：迭代方式决定是否转移元素所有权，容量管理完全显式，没有隐式的 `GC` 收缩。本文逐一介绍每种集合的内部数据结构与时间复杂度，覆盖核心 API，并在最后以多集合协作的文本分析器收尾。

## 一、序列类集合

序列类集合按插入顺序保存元素，支持通过下标或迭代器访问，包含 `Vec`、`VecDeque`、`LinkedList` 三种类型。

### 1.1 Vec — 动态数组

**内部原理**

`Vec<T>` 在栈上维护一个三元组 `(ptr, len, capacity)`：`ptr` 指向堆上连续分配的内存块，`len` 是当前元素数量，`capacity` 是已分配但不一定使用的槽位数。当 `push` 导致 `len == capacity` 时，`Vec` 触发一次 `realloc`——通常将容量翻倍——并把旧数据 `memcpy` 到新地址。这一策略使 `push` 的均摊代价为 O(1)，单次最坏为 O(n)。

```
栈：[ ptr → 堆 | len=3 | cap=4 ]
堆：[ 1 | 2 | 3 | _ ]   ← 第 4 格空闲，尚未初始化
```

**`Vec::new()` 的初始分配行为**

`Vec::new()` 不触发任何堆分配，`capacity` 为 0，`ptr` 是一个对齐的悬空指针（非 `null` 但不指向有效内存）。第一次 `push` 时才真正申请内存，初始容量由 `RawVec` 内部的 `MIN_NON_ZERO_CAP` 常量决定：

```rust
// 标准库 alloc/src/raw_vec.rs
const MIN_NON_ZERO_CAP: usize = if mem::size_of::<T>() == 1 {
    8
} else if mem::size_of::<T>() <= 1024 {
    4
} else {
    1
};
```

增长公式为 `new_cap = max(2 × old_cap, 1)`，当 `old_cap = 0` 时结果为 1，随后被 clamp 到 `MIN_NON_ZERO_CAP`。设计意图是：小元素（如 `u8`）批量存储更常见，给 8 减少早期 `realloc`；超大结构体（> 1024 B）则保守给 1，避免首次分配就浪费大量内存。

| 元素类型 | `size_of` | `MIN_NON_ZERO_CAP` | 第一次 `push` 后 `capacity` |
|----------|-----------|--------------------|---------------------------|
| `u8` | 1 B | 8 | 8 |
| `i32` | 4 B | 4 | 4 |
| `i64` | 8 B | 4 | 4 |
| `[u8; 32]` | 32 B | 4 | 4 |
| `[u8; 2048]` | 2048 B | 1 | 1 |

> 这是实现细节，不属于语言规范，不同 Rust 版本可能调整。已知元素数量时应始终用 `Vec::with_capacity(n)` 显式预分配，而不依赖默认增长行为。

正因为元素必须连续存放，`insert(i, val)` 和 `remove(i)` 需要将索引 `i` 之后的所有元素向后/向前移动一格，代价为 O(n − i)——其中 n 是当前元素总数，i 是操作位置。最坏情况在 i = 0（头部操作）时退化为 O(n)，最好情况在 i = len − 1（尾部）时为 O(1)（等同于 `pop`）。写作 O(n) 是大 O 取最坏情况的惯例。

**语法：**

```rust
Vec::new() -> Vec<T>
Vec::with_capacity(capacity: usize) -> Vec<T>
vec![val1, val2, ...]
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `capacity` | - | 预分配槽位数；已知元素总量时传入，避免多次 `realloc` |

**常用方法速查：**

| 方法                     | 复杂度      | 说明                                              |
| ---------------------- | -------- | ----------------------------------------------- |
| `push(val)`            | O(1) 均摊  | 追加到末尾                                           |
| `pop()`                | O(1)     | 移除并返回末尾元素                                       |
| `insert(i, val)`       | O(n − i) | 在索引 `i` 处插入，`i` 之后的元素右移一格；头部插入最慢 O(n)，尾部为 O(1)  |
| `remove(i)`            | O(n − i) | 移除索引 `i` 的元素，`i` 之后的元素左移一格；头部删除最慢 O(n)，尾部为 O(1) |
| `retain(\|x\| pred)`   | O(n)     | 原地保留满足谓词的元素                                     |
| `drain(range)`         | O(n)     | 取出并返回指定范围的元素；`range` 支持所有区间写法，见下表          |
| `truncate(len)`        | O(n)     | 将长度截断到 `len`，多余元素 `drop`                        |
| `len()` / `capacity()` | O(1)     | 返回当前长度 / 已分配容量                                  |

**`drain` 区间写法（`RangeBounds<usize>`）：**

| 写法 | 区间 | 说明 |
|------|------|------|
| `a..b` | [a, b) | 从索引 a 取到 b 的前一个，**不含 b** |
| `a..=b` | [a, b] | 从索引 a 取到 b，**含 b** |
| `a..` | [a, len) | 从索引 a 取到末尾 |
| `..b` | [0, b) | 从头取到 b 的前一个 |
| `..=b` | [0, b] | 从头取到 b |
| `..` | [0, len) | 取走全部元素 |

> `drain` 返回惰性迭代器，元素在迭代器被消耗时才逐个取出。若迭代器被提前 `drop`，区间内剩余元素也会全部 `drop`，不会留在 `Vec` 里。区间越界会 `panic`，行为与切片索引一致。

```rust
fn main() {
    // 预分配容量，避免多次 realloc
    let mut v: Vec<i32> = Vec::with_capacity(8);
    for i in 0..5 {
        v.push(i);
    }
    println!("len={}, cap={}", v.len(), v.capacity());

    // drain 取出子范围并返回迭代器
    let drained: Vec<i32> = v.drain(1..3).collect();
    println!("drained={:?}, remaining={:?}", drained, v);

    // retain：原地过滤
    let mut nums = vec![1, 2, 3, 4, 5, 6];
    nums.retain(|&x| x % 2 == 0);
    println!("retain 偶数: {:?}", nums);

    // insert / remove
    let mut v2 = vec![1, 2, 4, 5];
    v2.insert(2, 3);
    println!("insert(2, 3): {:?}", v2);
    let removed = v2.remove(0);
    println!("remove(0)={}, remaining={:?}", removed, v2);
}
```

运行结果：

```
len=5, cap=8
drained=[1, 2], remaining=[0, 3, 4]
retain 偶数: [2, 4, 6]
insert(2, 3): [1, 2, 3, 4, 5]
remove(0)=1, remaining=[2, 3, 4, 5]
```

> `Vec` 是绝大多数场景下的首选序列类型。频繁在**头部**插入或删除时，应换用 `VecDeque`——`Vec` 的头部操作是 O(n)，因为每次都要移动所有元素。

### 1.2 VecDeque — 环形缓冲队列

**内部原理**

`VecDeque<T>` 同样在堆上分配一块连续内存，但通过 `head` 和 `len` 两个整数模拟**环形缓冲区**（`ring buffer`）。头部弹出时只需将 `head = (head + 1) % capacity`，头部插入时将 `head = (head - 1 + capacity) % capacity`，无需移动任何元素。因此 `push_front` 和 `pop_front` 均摊 O(1)，这是 `VecDeque` 相比 `Vec` 的核心优势。

```
cap=6, head=2, len=3
索引:  0    1    2    3    4    5
      [ _  | _  | 10 | 20 | 30 | _ ]
                  ↑ head
```

随机访问 `[i]` 也是 O(1)——实际下标 = `(head + i) % capacity`。

**语法：**

```rust
use std::collections::VecDeque;

VecDeque::new() -> VecDeque<T>
VecDeque::with_capacity(capacity: usize) -> VecDeque<T>
VecDeque::from(vec: Vec<T>) -> VecDeque<T>
```

**Vec vs VecDeque 操作复杂度对比：**

| 操作 | Vec | VecDeque |
|------|-----|----------|
| `push_back` / `pop_back` | O(1) 均摊 | O(1) 均摊 |
| `push_front` / `pop_front` | O(n) | O(1) 均摊 |
| 随机访问 `[i]` | O(1) | O(1)（常数略大） |
| 内存连续性 | 保证 | 环形，可能断裂 |
| 切片视图 | `&[T]` 直接 | 需 `make_contiguous()` |

```rust
use std::collections::VecDeque;

fn main() {
    let mut dq: VecDeque<i32> = VecDeque::new();
    dq.push_back(1);
    dq.push_back(2);
    dq.push_front(0);    // O(1) 头部插入
    println!("{:?}", dq);

    // pop_front 模拟 BFS 队列消费
    while let Some(node) = dq.pop_front() {
        println!("处理节点: {}", node);
    }

    // make_contiguous：将环形布局展平为连续切片
    let mut dq2: VecDeque<i32> = VecDeque::from([3, 1, 2]);
    dq2.push_front(10);
    dq2.push_front(20);
    let slice = dq2.make_contiguous();
    println!("连续切片: {:?}", slice);
}
```

运行结果：

```
[0, 1, 2]
处理节点: 0
处理节点: 1
处理节点: 2
连续切片: [20, 10, 3, 1, 2]
```

> `make_contiguous()` 在需要将 `VecDeque` 当作普通切片传递给函数时非常有用，它原地重排内存使数据连续，返回 `&mut [T]`，不发生额外分配。

### 1.3 LinkedList — 双向链表

**内部原理**

`LinkedList<T>` 是真正的**堆分配节点**双向链表。每个节点独立分配在堆上，包含 `prev` 和 `next` 裸指针以及数据本体。链表头尾各有一个哨兵指针，访问任意节点需从头或尾顺序遍历，随机访问代价 O(n)。

正因为节点散布在堆的不同位置，缓存局部性（`cache locality`）远不如 `Vec` 或 `VecDeque`——遍历时每次 `next` 指针跳转都可能触发缓存未命中（`cache miss`）。在大多数实际测试中，即便是需要频繁在中间插入/删除的场景，`Vec` 的连续内存优势也足以弥补 O(n) 的移位代价。

| 操作 | 复杂度 | 备注 |
|------|--------|------|
| `push_front` / `push_back` | O(1) | |
| `pop_front` / `pop_back` | O(1) | |
| 随机访问 | O(n) | 无 `[]` 索引，只能迭代 |
| `split_off(at)` | O(n) | 需先走到分割点 |
| `append(&mut other)` | O(1) | 直接拼接两条链 |

```rust
use std::collections::LinkedList;

fn main() {
    let mut list: LinkedList<i32> = LinkedList::new();
    list.push_back(1);
    list.push_back(2);
    list.push_back(3);
    list.push_front(0);
    println!("{:?}", list);

    // split_off + append：O(1) 拼接
    let mut tail = list.split_off(2);
    println!("前半: {:?}", list);
    println!("后半: {:?}", tail);
    list.append(&mut tail);
    println!("合并后: {:?}", list);
}
```

运行结果：

```
[0, 1, 2, 3]
前半: [0, 1]
后半: [2, 3]
合并后: [0, 1, 2, 3]
```

> 不要将 `LinkedList` 作为默认列表选项。Rust 中推荐在以下极少数场景使用它：需要频繁 O(1) `append`/`split_off` 且不能承受摊销成本的场景。其余场景首选 `Vec` 或 `VecDeque`。

## 二、映射类集合

映射类集合存储键值对，通过 Key 快速查找 Value，包含 `HashMap` 和 `BTreeMap` 两种类型。

### 2.1 HashMap — 哈希表

**内部原理**

Rust 1.36 将 `hashbrown` crate 合并进标准库，`HashMap<K, V>` 底层采用 **Swiss Table** 实现——一种改进的开放寻址哈希表。其核心创新是"控制字节"（`control byte`）：每个槽位额外分配 1 字节，存储该槽的状态（空/已删除/已占用）以及哈希值的高 7 位。查找时，SIMD 指令可同时比较 16 个控制字节，在一次缓存行加载中完成 16 路并行探测，显著提升吞吐量。

默认哈希函数是 `SipHash-1-3`，能抵御哈希洪泛攻击（`hash flooding`），但速度不是最优。如需更高性能且输入不受用户控制，可换用 `ahash` 等第三方哈希器。负载因子约 87.5% 时触发扩容，扩容代价 O(n)。

**`HashMap::new()` 的初始分配行为**

`HashMap::new()` 创建时容量为 0，不触发任何堆分配；第一次 `insert` 时才真正分配内存，行为与 `Vec::new()` 一致。

**`with_capacity` 的容量取整**

`with_capacity(n)` 接受任意 `usize`，但 hashbrown 内部始终以 **2 的幂次** 作为桶数。实际分配规则：找最小的 2 的幂 `b`，使 `b × 7/8 ≥ n`，保证不触发 resize 前至少能存 `n` 个元素，实际 capacity 可能略大于请求值。

| `with_capacity(n)` | 内部桶数 | 实际 capacity（触发 resize 前） |
|--------------------|---------|--------------------------------|
| `0` | 0 | 0 |
| `7` | 8 | 7 |
| `8` | 16 | 14 |
| `10` | 16 | 14 |
| `100` | 128 | 112 |

> 这是 hashbrown 的实现细节，不属于语言规范，不同版本可能调整。已知元素数量时应始终用 `HashMap::with_capacity(n)` 预分配以避免多次扩容，但无需将 `n` 手动对齐到 2 的幂次——hashbrown 会自动处理。

**语法：**

```rust
use std::collections::HashMap;

HashMap::new() -> HashMap<K, V>
HashMap::with_capacity(capacity: usize) -> HashMap<K, V>
HashMap::from([(k1, v1), (k2, v2), ...])  // Rust 1.56+
```

**Entry API 参数：**

| 方法 | 说明 |
|------|------|
| `entry(key).or_insert(val)` | Key 不存在则插入 `val`，返回 `&mut V` |
| `entry(key).or_insert_with(f)` | Key 不存在则调用 `f()` 懒求值插入 |
| `entry(key).or_default()` | Key 不存在则插入 `T::default()` |
| `entry(key).and_modify(\|v\| ...)` | Key 存在则修改，链式调用后可接 `or_insert` |

`Entry` API 只做**一次**哈希查找。相比先 `contains_key` 再 `insert` 的写法（两次哈希 + 两次探测），性能更优，是累加计数、懒初始化等模式的首选。

```rust
use std::collections::HashMap;

fn main() {
    // 词频统计：entry API 经典用法
    let text = "hello world hello rust world hello";
    let mut freq: HashMap<&str, u32> = HashMap::new();
    for word in text.split_whitespace() {
        *freq.entry(word).or_insert(0) += 1;
    }
    let mut sorted: Vec<(&str, u32)> = freq.iter().map(|(&k, &v)| (k, v)).collect();
    sorted.sort_by_key(|&(k, _)| k);
    for (word, count) in &sorted {
        println!("{}: {}", word, count);
    }

    // and_modify + or_insert 组合
    freq.entry("rust").and_modify(|v| *v *= 10).or_insert(1);
    println!("rust 词频: {}", freq["rust"]);

    // or_insert_with 懒求值，避免不必要的 Vec 分配
    let mut cache: HashMap<&str, Vec<i32>> = HashMap::new();
    cache.entry("nums").or_insert_with(Vec::new).push(42);
    println!("cache: {:?}", cache);

    // or_default：利用类型的 Default 实现
    let mut counts: HashMap<char, u32> = HashMap::new();
    for ch in "aababc".chars() {
        *counts.entry(ch).or_default() += 1;
    }
    let mut cv: Vec<(char, u32)> = counts.into_iter().collect();
    cv.sort();
    println!("字符统计: {:?}", cv);
}
```

运行结果：

```
hello: 3
rust: 1
world: 2
rust 词频: 10
cache: {"nums": [42]}
字符统计: [('a', 3), ('b', 2), ('c', 1)]
```

> `HashMap` 的遍历顺序是**不确定的**，每次运行可能不同。如需稳定顺序输出，先 `collect` 到 `Vec` 后排序，或直接使用 `BTreeMap`。

### 2.2 BTreeMap — B 树有序映射

**内部原理**

`BTreeMap<K, V>` 基于 **B 树**实现，而非二叉搜索树。Rust 标准库中 B 树的阶数 `B=6`，每个内部节点最多存 11 个键，每个叶节点最多存 11 个键值对。节点内数据紧凑排列，比二叉树每节点存 1 个键的方式更缓存友好——一次缓存行加载可比对多个键，减少缓存未命中次数。

与 `HashMap` 的核心区别：B 树始终按 Key 的 `Ord` 顺序维护数据，有序遍历无需额外排序，并支持 `range()` 范围查询。代价是所有操作均为 O(log n)，而 `HashMap` 的点查询均摊 O(1)。

**`BTreeMap::new()` 的初始分配行为**

`BTreeMap::new()` 创建时不触发任何堆分配，根节点在第一次 `insert` 时才分配。与 `HashMap` 不同，`BTreeMap` **没有** `with_capacity()` 方法——B 树的内存用量由树形结构决定，节点按需分裂与合并，无法预先预留固定槽位。

**容量管理**

节点未满时插入原地写入（O(log n) 定位）；节点键数达到上限（11 个）时触发分裂，分配新节点；删除导致节点过少时合并相邻节点。整个生命周期内不提供 `capacity()`、`reserve()`、`shrink_to_fit()` 等容量管理 API。

| | HashMap | BTreeMap |
|--|---------|----------|
| `new()` 初始分配 | 无堆分配 | 无堆分配 |
| 预分配 API | `with_capacity(n)` | **不支持** |
| 容量管理 API | `reserve` / `shrink_to_fit` | **不支持** |
| 内存增长方式 | 桶数组翻倍扩容 | 节点按需分裂 |

**语法：**

```rust
use std::collections::BTreeMap;

BTreeMap::new() -> BTreeMap<K, V>
BTreeMap::from([(k1, v1), ...])  // Rust 1.56+
```

**HashMap vs BTreeMap 特性对比：**

| 特性 | HashMap | BTreeMap |
|------|---------|----------|
| Key 约束 | `Hash + Eq` | `Ord` |
| 查找 / 插入 / 删除 | O(1) 均摊 | O(log n) |
| 有序遍历 | 否（随机顺序） | 是（按 Key 升序） |
| 范围查询 `range()` | 否 | 是 |
| 内存布局 | 开放寻址哈希表 | B 树节点紧凑存储 |
| 适用场景 | 快速点查询、计数 | 有序输出、范围扫描 |

```rust
use std::collections::BTreeMap;

fn main() {
    let mut scores: BTreeMap<String, u32> = BTreeMap::new();
    scores.insert("alice".into(), 95);
    scores.insert("bob".into(), 87);
    scores.insert("carol".into(), 92);

    // 有序遍历（自动按 Key 升序）
    for (name, score) in &scores {
        println!("{}: {}", name, score);
    }

    // 范围查询："b" 到 "d"（不含 "d"）
    println!("--- 范围 b..d ---");
    for (k, v) in scores.range(String::from("b")..String::from("d")) {
        println!("{}: {}", k, v);
    }

    // first_key_value / last_key_value：O(log n)
    println!("最小键: {:?}", scores.first_key_value());
    println!("最大键: {:?}", scores.last_key_value());

    // split_off：从指定 Key 处分裂为两棵树
    let upper = scores.split_off("c");
    println!("split 前半: {:?}", scores);
    println!("split 后半: {:?}", upper);
}
```

运行结果：

```
alice: 95
bob: 87
carol: 92
--- 范围 b..d ---
bob: 87
carol: 92
最小键: Some(("alice", 95))
最大键: Some(("carol", 92))
split 前半: {"alice": 95, "bob": 87}
split 后半: {"carol": 92}
```

> `BTreeMap::range()` 的 Key 类型需与映射的 Key 类型一致（或可 `Borrow` 转换）。对 `BTreeMap<String, _>` 用 `&str` 作为范围端点时，需通过 `range::<str, _>(...)` 显式指定类型参数，或直接传入 `String` 值作为边界。

## 三、集合类集合

### 3.1 HashSet 与 BTreeSet

**内部原理**

`HashSet<T>` 就是 `HashMap<T, ()>` 的零成本包装——Value 固定为单元类型 `()`，编译器会将其优化掉，不占用额外存储。同理，`BTreeSet<T>` 包装 `BTreeMap<T, ()>`。因此两者的性能特征与对应的映射类型完全一致：`HashSet` 的成员查询均摊 O(1)，`BTreeSet` 的查询为 O(log n) 但保证有序。

集合运算（`union`、`intersection`、`difference`、`symmetric_difference`）均返回**惰性迭代器**，不会立即分配内存；只有调用 `.collect()` 时才真正求值并分配结果容器。

**语法：**

```rust
use std::collections::HashSet;

HashSet::new() -> HashSet<T>
HashSet::from([val1, val2, ...])  // Rust 1.56+
```

**集合运算方法：**

| 方法 | 返回 | 说明 |
|------|------|------|
| `a.union(&b)` | 惰性迭代器 `&T` | a ∪ b（两个集合的所有元素） |
| `a.intersection(&b)` | 惰性迭代器 `&T` | a ∩ b（同时在两个集合中的元素） |
| `a.difference(&b)` | 惰性迭代器 `&T` | a − b（在 a 但不在 b 中的元素） |
| `a.symmetric_difference(&b)` | 惰性迭代器 `&T` | (a ∪ b) − (a ∩ b)（恰好在一个集合中的元素） |
| `a.is_subset(&b)` | `bool` | a ⊆ b |
| `a.is_superset(&b)` | `bool` | a ⊇ b |
| `a.is_disjoint(&b)` | `bool` | a ∩ b = ∅ |

```rust
use std::collections::HashSet;

fn main() {
    let a: HashSet<i32> = [1, 2, 3, 4].into_iter().collect();
    let b: HashSet<i32> = [3, 4, 5, 6].into_iter().collect();

    // 交集（返回迭代器引用，.copied() 取得所有权）
    let mut inter: Vec<_> = a.intersection(&b).copied().collect();
    inter.sort();
    println!("交集: {:?}", inter);

    // 差集
    let mut diff: Vec<_> = a.difference(&b).copied().collect();
    diff.sort();
    println!("差集 a-b: {:?}", diff);

    // 并集
    let mut union: Vec<_> = a.union(&b).copied().collect();
    union.sort();
    println!("并集: {:?}", union);

    // 对称差
    let mut sym: Vec<_> = a.symmetric_difference(&b).copied().collect();
    sym.sort();
    println!("对称差: {:?}", sym);

    // 子集 / 不相交判断
    let c: HashSet<i32> = [1, 2].into_iter().collect();
    println!("c 是 a 的子集: {}", c.is_subset(&a));
    println!("a 和 b 不相交: {}", a.is_disjoint(&b));
}
```

运行结果：

```
交集: [3, 4]
差集 a-b: [1, 2]
并集: [1, 2, 3, 4, 5, 6]
对称差: [1, 2, 5, 6]
c 是 a 的子集: true
a 和 b 不相交: false
```

> 集合运算返回的迭代器元素类型是 `&T`。对于实现了 `Copy` 的基本类型，在 `collect` 前加 `.copied()` 可直接得到 `T`；对于堆类型需使用 `.cloned()`。

`BTreeSet` 的 API 与 `HashSet` 基本一致，额外提供 `range()`、`first()`、`last()` 用于有序访问，使用场景与 `BTreeMap` vs `HashMap` 的选择逻辑相同。

## 四、迭代器与所有权

### 4.1 三种迭代方式

集合的迭代方式决定元素的所有权归属，这是 Rust 集合 API 与其他语言最显著的差别之一。

**语法：**

```rust
// 不可变借用
collection.iter() -> Iterator<Item = &T>

// 可变借用
collection.iter_mut() -> Iterator<Item = &mut T>

// 消耗集合，转移所有权
collection.into_iter() -> Iterator<Item = T>
```

**三种迭代方式对比：**

| 调用方式 | 元素类型 | 集合所有权 | 适用场景 |
|----------|----------|------------|----------|
| `v.iter()` | `&T` | 集合保留 | 只读遍历、统计 |
| `v.iter_mut()` | `&mut T` | 集合保留 | 就地修改元素 |
| `v.into_iter()` | `T` | 集合消耗 | 转换、传递所有权 |
| `for x in &v` | `&T` | 集合保留 | `iter()` 的语法糖 |
| `for x in &mut v` | `&mut T` | 集合保留 | `iter_mut()` 的语法糖 |
| `for x in v` | `T` | 集合消耗 | `into_iter()` 的语法糖 |

`for` 循环在底层调用 `IntoIterator::into_iter()`：对 `&V` 调用时产生 `iter()`，对 `&mut V` 产生 `iter_mut()`，对 `V` 本身产生消耗式迭代。

```rust
fn main() {
    let mut v = vec![1, 2, 3];

    // iter(): 借用，v 之后仍可使用
    let sum: i32 = v.iter().sum();
    println!("sum={}, v still valid: {:?}", sum, v);

    // iter_mut(): 就地修改
    v.iter_mut().for_each(|x| *x *= 2);
    println!("doubled: {:?}", v);

    // into_iter(): 消耗集合
    let mapped: Vec<i32> = v.into_iter().map(|x| x + 1).collect();
    println!("mapped: {:?}", mapped);
    // v 在此行之后已失效，编译器会阻止使用
}
```

运行结果：

```
sum=6, v still valid: [1, 2, 3]
doubled: [2, 4, 6]
mapped: [3, 5, 7]
```

## 五、容量管理

### 5.1 预分配与收缩

所有基于堆分配的集合（`Vec`、`VecDeque`、`HashMap`、`HashSet`）都提供容量管理 API。Rust 的集合**永不自动收缩**：删除元素不会缩减已分配内存，必须显式调用收缩方法。

**语法：**

```rust
collection.with_capacity(n: usize)       // 构建时预分配
collection.reserve(additional: usize)    // 确保还能容纳 additional 个元素
collection.reserve_exact(additional)     // 精确预留（不超额，视分配器实现）
collection.shrink_to_fit()               // 收缩到与 len 匹配
collection.shrink_to(min_capacity)       // 收缩但保留至少 min_capacity（Rust 1.56+）
```

**参数说明：**

| 参数 | 说明 |
|------|------|
| `additional` | **额外**容量，不是目标总量。`len=10` 时 `reserve(5)` 保证 `cap ≥ 15` |
| `min_capacity` | `shrink_to` 的下限，不低于当前 `len` |

```rust
fn main() {
    // with_capacity：已知批量写入数量时预分配
    let mut v: Vec<i32> = Vec::with_capacity(100);
    v.extend(0..10);
    println!("len={}, cap={}", v.len(), v.capacity());

    // shrink_to_fit：批量写入结束后释放多余容量
    v.shrink_to_fit();
    println!("shrink_to_fit: len={}, cap={}", v.len(), v.capacity());

    // reserve：额外容量，非目标总量
    v.reserve(5);
    println!("reserve(5): cap={}", v.capacity());

    // reserve_exact：尽量精确分配
    let mut v2: Vec<i32> = Vec::with_capacity(100);
    v2.extend(0..10);
    v2.reserve_exact(5);
    println!("reserve_exact(5) on cap=100: cap={}", v2.capacity());
}
```

运行结果：

```
len=10, cap=100
shrink_to_fit: len=10, cap=10
reserve(5): cap=20
reserve_exact(5) on cap=100: cap=100
```

> `reserve(n)` 的参数是**额外**数量而非总量，这是一个常见误解。`reserve(5)` 在 `len=10` 时保证 `cap ≥ 15`，而不是把容量设为 5。`reserve_exact` 在当前容量已满足时不会收缩（输出中 `cap=100` 保持不变），仅在容量不足时才精确分配。

## 六、集合选择指南

### 6.1 决策依据与对比表

选择集合时主要考量三个维度：**访问模式**（随机 vs 顺序 vs 范围）、**操作位置**（头部/尾部/任意位置）、**Key 约束**（`Hash + Eq` vs `Ord`）。

**全集合操作复杂度总表：**

| 集合           | 随机访问  | 头部操作    | 尾部操作     | 任意插入  | 查找       | 有序    | 范围查询 |
| ------------ | ----- | ------- | -------- | ----- | -------- | ----- | ---- |
| `Vec`        | O(1)  | O(n)    | O(1) 均摊  | O(n)  | O(n)     | 否     | 否    |
| `VecDeque`   | O(1)  | O(1) 均摊 | O(1) 均摊  | O(n)  | O(n)     | 否     | 否    |
| `LinkedList` | O(n)  | O(1)    | O(1)     | O(1)† | O(n)     | 否     | 否    |
| `HashMap`    | —     | —       | O(1) 均摊  | —     | O(1) 均摊  | 否     | 否    |
| `BTreeMap`   | —     | —       | O(log n) | —     | O(log n) | 是     | 是    |
| `HashSet`    | —     | —       | O(1) 均摊  | —     | O(1) 均摊  | 否     | 否    |
| `BTreeSet`   | —     | —       | O(log n) | —     | O(log n) | 是     | 是    |

†`LinkedList` 任意位置插入需先遍历到目标位置 O(n)，游标 API（`nightly`）稳定后可 O(1) 就地插入。  


**选型决策：**

1. **需要键值对映射** → 映射类
   - 需要有序遍历 / 范围查询，或 Key 无法哈希（如浮点数）→ `BTreeMap`
   - 只需点查询，Key 实现了 `Hash + Eq` → `HashMap`（首选，性能更优）

2. **需要唯一值集合** → 集合类
   - 需要有序 / 范围操作 → `BTreeSet`
   - 只需成员判断 / 集合运算 → `HashSet`（首选）

3. **需要序列（按顺序存储）** → 序列类
   - 只在尾部追加，或需要随机索引 → `Vec`（首选）
   - 两端频繁操作（队列 / 滑动窗口）→ `VecDeque`
   - 需要 O(1) `append`/`split_off`，且元素地址不能变动 → `LinkedList`（极少用）


> 经验法则：先选 `Vec` 和 `HashMap`。只有当性能分析或功能需求（有序性、范围查询、双端操作）明确要求时，才切换到其他类型。

## 七、实战：多集合协作——文本分析器

### 7.1 场景设计

综合运用 `HashMap`、`HashSet`、`BTreeMap` 实现一个文本分析器：

1. `HashMap` + Entry API 统计词频
2. `HashSet` 过滤停用词
3. `BTreeMap` 按字母序输出完整词频表

```rust
use std::collections::{BTreeMap, HashMap, HashSet};

fn analyze<'a>(text: &'a str, stop_words: &HashSet<&str>) {
    // 1. 统计词频，跳过停用词
    let mut freq: HashMap<&str, u32> = HashMap::new();
    for word in text.split_whitespace() {
        if !stop_words.contains(word) {
            *freq.entry(word).or_insert(0) += 1;
        }
    }

    // 2. BTreeMap 按字母序输出完整词频表
    let sorted: BTreeMap<&str, u32> = freq.iter().map(|(&k, &v)| (k, v)).collect();
    println!("=== 完整词频（字母序）===");
    for (word, count) in &sorted {
        println!("  {}: {}", word, count);
    }
}

fn main() {
    let text = "rust is fast rust is safe safe code is good rust code is idiomatic";
    let stop_words: HashSet<&str> = ["is", "a", "the", "and"].into_iter().collect();
    analyze(text, &stop_words);
}
```

运行结果：

```
=== 完整词频（字母序）===
  code: 2
  fast: 1
  good: 1
  idiomatic: 1
  rust: 3
  safe: 2
```

**各步骤知识点对应：**

| 步骤 | 使用的集合 / API | 对应章节 |
|------|-----------------|----------|
| 词频统计 | `HashMap` + Entry API | 二、2.1 |
| 停用词过滤 | `HashSet::contains` | 三、3.1 |
| 有序输出 | `BTreeMap` 有序遍历 | 二、2.2 |
| 结果收集 | `into_iter().collect()` | 四、4.1 |
