---
title: "[标准库] std::alloc 内存分配模块介绍"
published: true
layout: post
date: 2026-05-11 10:30:00
permalink: /rust/std-alloc.html
tags:
  - Rust
  - 内存管理
  - alloc
  - GlobalAlloc
categories:
  - Rust
---

每次写 `Box::new(val)` 或 `Vec::with_capacity(n)`，背后都隐藏着一次内存分配请求——它们通过 Rust 的**全局分配器**（`global allocator`）完成。`std::alloc` 模块正是这套机制的公开接口，提供了描述内存布局的 `Layout`、定义分配行为的 `GlobalAlloc` trait、以及直接调用全局分配器的裸函数。理解它，既能写出正确的 `unsafe` 内存操作，也能为嵌入式系统或性能敏感场景定制专属分配器。

## 一、模块概述

`std::alloc` 于 `Rust 1.28.0` 稳定，核心职责是管理程序中唯一的**全局内存分配器**。标准库的所有堆分配类型——`Box<T>`、`Vec<T>`、`String`、`HashMap` 等——最终都通过该模块的接口申请和释放内存。

| 组件 | 类型 | 说明 |
|------|------|------|
| `Layout` | `struct` | 描述内存块的大小与对齐要求 |
| `LayoutError` | `struct` | `Layout` 构造失败时返回的错误类型 |
| `System` | `struct` | 委托操作系统 `malloc`/`free` 的默认分配器 |
| `GlobalAlloc` | `trait` | 自定义全局分配器必须实现的接口 |
| `alloc` | `fn` | 申请内存，不初始化；`unsafe` |
| `alloc_zeroed` | `fn` | 申请内存并清零；`unsafe` |
| `dealloc` | `fn` | 释放内存；`unsafe` |
| `realloc` | `fn` | 调整已分配内存大小；`unsafe` |
| `handle_alloc_error` | `fn` | 分配失败时触发 `abort` 并输出诊断信息 |

> Rust 保证：对于 `cdylib` 和 `staticlib` 目标，默认全局分配器为 `System`；对于 `bin` 目标，标准库会提供一个平台相关的默认实现，但可通过 `#[global_allocator]` 替换。

## 二、Layout：内存布局描述符

`Layout` 描述一块内存的两个核心属性：**大小**（字节数）和**对齐**（地址对齐要求）。所有分配/释放操作都需要配套的 `Layout`，分配器依赖它返回满足要求的指针。

### 2.1 构造方法

**语法：**

```rust
// 根据类型自动推导
Layout::new::<T>() -> Layout

// 手动指定大小和对齐
Layout::from_size_align(size: usize, align: usize) -> Result<Layout, LayoutError>

// 数组布局（n 个 T 连续排列）
Layout::array::<T>(n: usize) -> Result<Layout, LayoutError>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `size` | - | 内存块的字节数；必须满足 `size ≤ isize::MAX` |
| `align` | - | 对齐字节数；**必须是 2 的幂**（`1`、`2`、`4`、`8`…），否则返回 `LayoutError` |
| `n(array)` | - | 元素个数；`size_of::<T>() * n` 不能溢出 `usize` |

`Layout::new::<T>()` 等价于 `from_size_align(size_of::<T>(), align_of::<T>()).unwrap()`，零大小类型（`ZST`）的 `size` 为 0，合法。

---

#### align 的本质：CPU 格子模型

`align` 规定分配器返回的指针地址必须是 `align` 的整数倍，本质上是硬件读取内存的方式决定的。

64-bit `CPU` 每次从内存总线读取数据时，以 **8 字节为一格**，且只能从 8 的倍数地址开始：

```
地址:   0        8        16       24
        |--------|--------|--------|
        [ 格子0  ][ 格子1  ][ 格子2  ]
```

- **`u64`（8 字节）放在地址 0**：恰好在格子 0 内，一次读取完成 ✓
- **`u64` 放在地址 3**：横跨格子 0 和格子 1，`CPU` 须读两次再拼接——`x86` 上变慢，`ARM` 上直接触发对齐异常 ✗

```
地址:   0    3              11
        |----|[=====u64=====]---|
             ↑ 跨越格子边界，需两次读取
```

- **`u8`（1 字节）放在任意地址**：1 字节不会跨格，`CPU` 读取整格后取出对应字节即可 ✓

因此对齐的下限由**数据类型本身**决定，不是优化选项——`u64` 必须 `align=8`，`u8` 只需 `align=1`。

> `align` 的最小合法值 = 结构体中**对齐要求最大字段**的 `align_of`。不能为省内存碎片而随意降低，否则是未定义行为。

---

#### `size` 与 `align` 的关系

两者相互独立——`size` 不必是 `align` 的倍数。`size` 是实际需要的字节数，`align` 只约束起始地址。

| 情形 | 说明 |
|------|------|
| 单次分配 | 申请 `size` 字节，起始地址满足 `align` 即可 |
| 数组元素 | 每个元素的起始地址也须满足 `align`，实际步长（`stride`）= `pad_to_align().size()` |
| `C` 兼容结构体 | 末尾须调用 `pad_to_align()` 补尾部填充，否则相邻实例地址计算错误 |

以 `size=10, align=8` 为例：单次分配占 10 字节，作数组元素时 `stride`=16（补 6 字节填充）。

---

#### 分配器如何查找对齐地址

分配器在堆上找到空闲区域后，若起始地址不满足 `align`，会向后跳过若干字节直到找到第一个对齐地址，跳过的字节成为**内部碎片**，调用方不可见：

```
申请 size=20, align=2（空闲区从地址 1001 开始）：

地址:  1001  1002                      1022
        |     |                         |
     跳过1B  |<===== 20 字节数据 =======>|
              ↑ addr%2==0 ✓

申请 size=20, align=4（空闲区从地址 1001 开始）：

地址:  1001        1004                      1024
        |           |                         |
     跳过3B        |<===== 20 字节数据 =======>|
                    ↑ addr%4==0 ✓
```

内部碎片上限 = `align - 1`，`align` 越大，潜在浪费越多。

---

#### 超对齐（`align` 大于类型最小要求）

`align` 可以设为大于 `align_of::<T>()` 的值，这称为**超对齐**（`over-alignment`）。

| `align`（以 `u64` 为例） | 用途 | 数组 `stride` | 内存代价 |
|---------|------|------------|---------|
| 8（最小） | 普通读写 | 8 字节 | 无浪费 |
| 16 | `SSE` 批量加载两个 `u64` | 16 字节 | 每元素多 8 字节 |
| 32 | `AVX` 批量加载四个 `u64` | 32 字节 | 每元素多 24 字节 |
| 64 | 独占缓存行，避免 `false sharing` | 64 字节 | 每元素多 56 字节 |

数组分配时 `stride` 增大，总占用确实增多。`repeat(n)` 末尾元素不补填充，公式为：

```
total = stride × (n-1) + size
```

以 `size=8, align=16` 的 4 元素数组为例：`total = 16×3 + 8 = 56`（而非 `16×4 = 64`）。

> 超对齐是为满足 `SIMD` 指令或缓存行隔离等上层需求，而非正确性要求。若无性能测试支撑，不要随意超对齐。

---

#### 如何合理设置 `align`

| 场景 | 推荐 `align` | 说明 |
|------|------------|------|
| 普通类型 | `align_of::<T>()` | 用 `Layout::new::<T>()` 自动推导 |
| `SSE` / `__m128` | 16 | 128-bit `SIMD` 寄存器要求 |
| `AVX` / `__m256` | 32 | 256-bit `SIMD` 寄存器要求 |
| `AVX-512` / `__m512` | 64 | 512-bit `SIMD` 寄存器要求 |
| 多线程热点数据 | 64 | 独占 `CPU` 缓存行（`cache line`），避免 `false sharing` |
| `DMA` / 页对齐 | 4096 | 操作系统页大小，`mmap` 和设备驱动要求 |

三条规则：
1. **不要猜**：优先用 `align_of::<T>()`，手动值只在有明确文档要求时才覆盖。
2. **只能放大，不能缩小**：`align` 必须 ≥ `align_of::<T>()`，否则是未定义行为。
3. **必须是 2 的幂**：`3`、`6`、`12` 等会被 `from_size_align` 直接拒绝并返回 `LayoutError`。

---

```rust
use std::alloc::Layout;

fn main() {
    let layout_u64 = Layout::new::<u64>();
    println!("u64:    size={}, align={}", layout_u64.size(), layout_u64.align());

    let layout_u8 = Layout::new::<u8>();
    println!("u8:     size={}, align={}", layout_u8.size(), layout_u8.align());

    let layout = Layout::from_size_align(24, 8).unwrap();
    println!("custom: size={}, align={}", layout.size(), layout.align());

    // align 非 2 的幂 → LayoutError
    match Layout::from_size_align(16, 3) {
        Ok(_)  => println!("ok"),
        Err(e) => println!("align=3 错误: {e}"),
    }
}
```

运行结果：

```
u64:    size=8, align=8
u8:     size=1, align=1
custom: size=24, align=8
align=3 错误: invalid parameters to Layout::from_size_align
```

### 2.2 关键方法

**语法：**

```rust
layout.size()  -> usize
layout.align() -> usize

layout.extend(next: Layout)    -> Result<(Layout, usize), LayoutError>
layout.pad_to_align()          -> Layout
layout.repeat(n: usize)        -> Result<(Layout, usize), LayoutError>
```

**参数：**

| 方法 | 参数 | 说明 |
|------|------|------|
| `extend` | `next: Layout` | 将 `next` 紧接在 `self` 之后排列（自动对齐填充）；返回 `(新布局, next字段的字节偏移)` |
| `pad_to_align` | 无 | 在 `size` 尾部添加填充，使 `size` 对齐到 `align` 的倍数；`C` 兼容结构体必须调用此方法 |
| `repeat` | `n: usize` | 将当前布局重复 `n` 次（等同于 `C` 数组）；返回 `(数组布局, 单元素步长 stride)` |

`extend` 在计算组合布局时会自动在 `self` 末尾插入对齐填充，使 `next` 的起始地址满足其对齐要求；`repeat(n)` 在内部调用 `pad_to_align` 后乘以 `n`，因此步长 = 对齐后的单元素大小。

```rust
use std::alloc::Layout;

fn main() {
    // extend — 组合 u32 + u64
    let a = Layout::new::<u32>(); // size=4, align=4
    let b = Layout::new::<u64>(); // size=8, align=8
    let (combined, offset) = a.extend(b).unwrap();
    println!("extend u32+u64: combined_size={}, offset_of_b={}", combined.size(), offset);

    // pad_to_align — size=10 对齐到 align=8 的倍数
    let unpadded = Layout::from_size_align(10, 8).unwrap();
    let padded = unpadded.pad_to_align();
    println!("pad_to_align(size=10,align=8): {} -> {}", unpadded.size(), padded.size());

    // repeat — u32 数组 × 4
    let elem = Layout::new::<u32>();
    let (arr_layout, stride) = elem.repeat(4).unwrap();
    println!("repeat u32×4: total_size={}, stride={}", arr_layout.size(), stride);
}
```

运行结果：

```
extend u32+u64: combined_size=16, offset_of_b=8
pad_to_align(size=10,align=8): 10 -> 16
repeat u32×4: total_size=16, stride=4
```

**`extend` 的顺序影响结果**

`extend` 只在两个字段之间插入"让第二个字段满足其 `align` 所需的最少填充"，因此 `a.extend(b)` 与 `b.extend(a)` 结果不同：

`a.extend(b)`：`u32`（4 字节）在前，`u64`（8 字节）在后

```
偏移:  0    4    8              16
       |----|----|--------------|
       [u32 ]    [    u64       ]
              ↑
          4 字节填充
          (u32 结束于 4，u64 需要 8 对齐，下一个 8 的倍数 = 8)

combined_size=16, offset=8
```

`b.extend(a)`：`u64`（8 字节）在前，`u32`（4 字节）在后

```
偏移:  0              8    12
       |--------------|-----|
       [    u64       ][u32 ]
                      ↑
                  无需填充
                  (u64 结束于 8，u32 只需 4 对齐，8 已是 4 的倍数)

combined_size=12, offset=8
```

这正是 Rust / `C` 结构体字段排列的实践建议——**把对齐要求大的字段放前面**，可减少内部填充：

```rust
struct Bad  { a: u32, b: u64 }  // size=16（中间 4 字节填充）
struct Good { b: u64, a: u32 }  // size=12（无填充）
```

> `extend` 不会调用 `pad_to_align`，返回的组合布局末尾可能没有尾部填充。如需 `C` 兼容结构体的完整布局，在最后一次 `extend` 后调用 `pad_to_align()`。

### 2.3 LayoutError

`LayoutError` 在以下情况由构造方法返回：

| 触发条件 | 说明 |
|----------|------|
| `align` 不是 2 的幂 | 如 `align=3`、`align=0` |
| `size > isize::MAX` | 超出地址空间安全范围 |
| `repeat`/`array` 溢出 | `size * n` 超出 `usize::MAX` |

`LayoutError` 仅实现了 `Debug` 和 `Display`，不携带额外字段，错误信息固定为 `"invalid parameters to Layout::from_size_align"`。

## 三、GlobalAlloc Trait

`GlobalAlloc` 是实现自定义全局分配器的核心 `trait`，声明为 `unsafe trait`。实现方必须手动保证所有 `safety invariant`。

### 3.1 必需方法：alloc / dealloc

**语法：**

```rust
unsafe fn alloc(&self, layout: Layout) -> *mut u8
unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout)
```

**参数：**

| 参数 | 说明 |
|------|------|
| `layout(alloc)` | 必须满足 `size > 0`（零大小分配行为未定义） |
| `ptr(dealloc)` | 必须是同一分配器用相同 `layout` 分配的指针，且尚未释放 |
| `layout(dealloc)` | 必须与分配时完全相同（`size` 和 `align` 均须匹配） |

**Safety 约束（实现方必须遵守）：**

| 约束 | 说明 |
|------|------|
| 不能 `panic` / `unwind` | `alloc` 或 `dealloc` 内部 `panic` 会导致未定义行为 |
| 返回对齐指针或 `null` | `alloc` 成功时返回的指针地址必须是 `layout.align()` 的倍数 |
| `null` 表示失败 | 分配失败返回 `null`，调用方通过 `handle_alloc_error` 处理 |
| 不依赖分配发生 | 编译器可消除看似必要的分配；不可依赖分配次数做逻辑判断 |

```rust
use std::alloc::{GlobalAlloc, Layout, System};

struct SimpleAllocator;

unsafe impl GlobalAlloc for SimpleAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let ptr = unsafe { System.alloc(layout) };
        println!("[alloc]   size={}, align={}, success={}", layout.size(), layout.align(), !ptr.is_null());
        ptr
    }
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        println!("[dealloc] size={}, align={}", layout.size(), layout.align());
        unsafe { System.dealloc(ptr, layout) }
    }
}

fn main() {
    let allocator = SimpleAllocator;
    unsafe {
        let layout = Layout::from_size_align(16, 8).unwrap();
        let ptr = allocator.alloc(layout);
        assert!(!ptr.is_null());
        *(ptr as *mut u64) = 42;
        println!("写入值: {}", *(ptr as *const u64));
        allocator.dealloc(ptr, layout);
    }
}
```

运行结果：

```
[alloc]   size=16, align=8, success=true
写入值: 42
[dealloc] size=16, align=8
```

### 3.2 可选方法：realloc / alloc_zeroed

这两个方法有默认实现（基于 `alloc`/`dealloc` 实现），可按需覆盖以提升性能。

**语法：**

```rust
unsafe fn realloc(&self, ptr: *mut u8, layout: Layout, new_size: usize) -> *mut u8
unsafe fn alloc_zeroed(&self, layout: Layout) -> *mut u8
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `ptr` | - | 原分配指针，必须与 `layout` 匹配 |
| `layout` | - | 原始分配的布局 |
| `new_size` | - | 新的字节大小；必须 `> 0` |

`realloc` 保证在范围 `0..min(layout.size(), new_size)` 内的字节内容不变；返回 `null` 时原 `ptr` 仍然有效（调用方负责继续使用或释放原指针）。`alloc_zeroed` 分配后将所有字节初始化为 0，等价于 `C` 的 `calloc`。

以下 `SimpleAllocator` 仅实现 `alloc`/`dealloc`（静默），覆盖 `realloc` 和 `alloc_zeroed` 以添加日志，演示两个可选方法的行为：

```rust
use std::alloc::{GlobalAlloc, Layout, System};

struct SimpleAllocator;

unsafe impl GlobalAlloc for SimpleAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        unsafe { System.alloc(layout) }
    }
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        unsafe { System.dealloc(ptr, layout) }
    }
    unsafe fn realloc(&self, ptr: *mut u8, layout: Layout, new_size: usize) -> *mut u8 {
        let new_ptr = unsafe { System.realloc(ptr, layout, new_size) };
        println!("[realloc]      {} -> {} 字节, success={}", layout.size(), new_size, !new_ptr.is_null());
        new_ptr
    }
    unsafe fn alloc_zeroed(&self, layout: Layout) -> *mut u8 {
        let ptr = unsafe { System.alloc_zeroed(layout) };
        println!("[alloc_zeroed] size={}, success={}", layout.size(), !ptr.is_null());
        ptr
    }
}

fn main() {
    let allocator = SimpleAllocator;
    unsafe {
        let layout = Layout::from_size_align(16, 8).unwrap();
        let ptr = allocator.alloc(layout);
        assert!(!ptr.is_null());
        *(ptr as *mut u64) = 0xDEAD_BEEF;

        let new_ptr = allocator.realloc(ptr, layout, 32);
        assert!(!new_ptr.is_null());
        assert_eq!(*(new_ptr as *const u64), 0xDEAD_BEEF);
        println!("realloc 后原值保留: 0x{:X}", *(new_ptr as *const u64));
        allocator.dealloc(new_ptr, Layout::from_size_align(32, 8).unwrap());

        let zptr = allocator.alloc_zeroed(Layout::from_size_align(8, 8).unwrap());
        assert!(!zptr.is_null());
        let all_zero = (0..8usize).all(|i| *zptr.add(i) == 0);
        println!("alloc_zeroed 全零: {all_zero}");
        allocator.dealloc(zptr, Layout::from_size_align(8, 8).unwrap());
    }
}
```

运行结果：

```
[realloc]      16 -> 32 字节, success=true
realloc 后原值保留: 0xDEADBEEF
[alloc_zeroed] size=8, success=true
alloc_zeroed 全零: true
```

> `realloc` 和 `alloc_zeroed` 有默认实现（基于 `alloc`/`dealloc`），但效率较低。此处通过覆盖这两个方法直接委托给 `System`，可利用平台原生的 `realloc` 和 `calloc` 提升性能。

## 四、System 分配器

`System` 是 Rust 内置的操作系统分配器实现，始终可用，不依赖任何外部 `crate`。

```rust
use std::alloc::{GlobalAlloc, Layout, System};

fn main() {
    unsafe {
        let layout = Layout::new::<u64>();
        let ptr = System.alloc(layout);
        assert!(!ptr.is_null());
        *(ptr as *mut u64) = 42;
        println!("值: {}", *(ptr as *const u64));
        System.dealloc(ptr, layout);
    }
}
```

| 属性 | 说明 |
|------|------|
| 线程安全 | 实现了 `Send + Sync`，可在多线程中使用 |
| 底层实现 | `Linux` → `malloc`/`free`（`glibc`/`musl`），`macOS` → `malloc`/`free`，`Windows` → `HeapAlloc`/`HeapFree` |
| 失败行为 | 返回 `null`，不 `abort` |
| 大小调整 | `realloc` 委托给平台 `realloc`，效率优于手动 `alloc`+`dealloc` |

> `System` 可作为自定义分配器的委托后端，避免从零实现平台适配。

## 五、模块级函数

这些函数直接操作**当前程序的全局分配器**，全部为 `unsafe`。

**语法：**

```rust
pub unsafe fn alloc(layout: Layout) -> *mut u8
pub unsafe fn alloc_zeroed(layout: Layout) -> *mut u8
pub unsafe fn dealloc(ptr: *mut u8, layout: Layout)
pub unsafe fn realloc(ptr: *mut u8, layout: Layout, new_size: usize) -> *mut u8
pub fn handle_alloc_error(layout: Layout) -> !
```

**函数速查：**

| 函数 | 返回值 | 说明 |
|------|--------|------|
| `alloc(layout)` | `*mut u8` 或 `null` | 向全局分配器申请内存，不初始化 |
| `alloc_zeroed(layout)` | `*mut u8` 或 `null` | 申请后清零，等价于 `calloc` |
| `dealloc(ptr, layout)` | `()` | 释放指针；`layout` 必须与分配时一致 |
| `realloc(ptr, layout, new_size)` | `*mut u8` 或 `null` | 调整大小；返回 `null` 时原 `ptr` 仍有效 |
| `handle_alloc_error(layout)` | `!`（不返回） | 触发分配失败处理（默认 `abort`），优于直接 `panic` |

```rust
use std::alloc::{alloc, alloc_zeroed, dealloc, realloc, Layout};

fn main() {
    unsafe {
        let layout = Layout::array::<u8>(16).unwrap();
        let ptr = alloc(layout);
        assert!(!ptr.is_null(), "分配失败");

        for i in 0..16usize {
            *ptr.add(i) = i as u8;
        }
        println!("alloc: 成功分配 {} 字节", layout.size());

        let new_ptr = realloc(ptr, layout, 32);
        assert!(!new_ptr.is_null(), "realloc 失败");

        let preserved = (0..16usize).all(|i| *new_ptr.add(i) == i as u8);
        println!("realloc: 扩展至 32 字节，原数据保留={preserved}");

        let new_layout = Layout::array::<u8>(32).unwrap();
        dealloc(new_ptr, new_layout);
        println!("dealloc: 释放完毕");

        let layout2 = Layout::array::<u8>(8).unwrap();
        let zero_ptr = alloc_zeroed(layout2);
        assert!(!zero_ptr.is_null());
        let all_zero = (0..8usize).all(|i| *zero_ptr.add(i) == 0);
        println!("alloc_zeroed: 全零={all_zero}");
        dealloc(zero_ptr, layout2);
    }
}
```

运行结果：

```
alloc: 成功分配 16 字节
realloc: 扩展至 32 字节，原数据保留=true
dealloc: 释放完毕
alloc_zeroed: 全零=true
```

> 分配失败时**不要** `panic`，应调用 `handle_alloc_error(layout)`，它会触发 `abort` 并输出分配失败的诊断信息。

## 六、#[global_allocator] 实战

`#[global_allocator]` 属性将一个实现了 `GlobalAlloc` 的静态变量注册为全局分配器，替换默认的 `System`。**每个二进制 crate 只能有一个**。

### 6.1 委托 System 的基础示例

最简实现：将所有操作委托给 `System`，保持默认行为不变，同时为后续扩展留出钩子。

```rust
use std::alloc::{GlobalAlloc, Layout, System};

struct MyAllocator;

unsafe impl GlobalAlloc for MyAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        unsafe { System.alloc(layout) }
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        unsafe { System.dealloc(ptr, layout) }
    }
}

#[global_allocator]
static GLOBAL: MyAllocator = MyAllocator;

fn main() {
    // Box/Vec/String 等都通过 MyAllocator 分配
    let v: Vec<i32> = vec![1, 2, 3];
    println!("{:?}", v);
}
```

运行结果：

```
[1, 2, 3]
```

### 6.2 带统计的 CountingAllocator

在 `alloc` 时用原子操作累加计数，统计程序生命周期内的总分配次数和字节数。

```rust
use std::alloc::{GlobalAlloc, Layout, System};
use std::sync::atomic::{AtomicUsize, Ordering};

struct CountingAllocator {
    alloc_count: AtomicUsize,
    alloc_bytes: AtomicUsize,
}

unsafe impl GlobalAlloc for CountingAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let ptr = unsafe { System.alloc(layout) };
        if !ptr.is_null() {
            self.alloc_count.fetch_add(1, Ordering::Relaxed);
            self.alloc_bytes.fetch_add(layout.size(), Ordering::Relaxed);
        }
        ptr
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        unsafe { System.dealloc(ptr, layout) }
    }
}

#[global_allocator]
static ALLOCATOR: CountingAllocator = CountingAllocator {
    alloc_count: AtomicUsize::new(0),
    alloc_bytes: AtomicUsize::new(0),
};

fn main() {
    let _v: Vec<i32> = Vec::with_capacity(100);
    let _s = String::from("hello, allocator");
    let _b = Box::new(42u64);

    println!("累计分配次数: {}", ALLOCATOR.alloc_count.load(Ordering::Relaxed));
    println!("累计分配字节: {}", ALLOCATOR.alloc_bytes.load(Ordering::Relaxed));
}
```

运行结果：

```
累计分配次数: 5
累计分配字节: 1996
```

> 计数包含 Rust 运行时启动阶段的内部分配（如 `panic handler`、标准流初始化等），因此次数和字节数会高于用户代码的直接分配量。

### 6.3 内存限制 LimitedAllocator

超过总量上限时返回 `null`，阻止进一步分配。

```rust
use std::alloc::{GlobalAlloc, Layout, System};
use std::sync::atomic::{AtomicUsize, Ordering};

const MAX_BYTES: usize = 4 * 1024; // 4 KB 上限

struct LimitedAllocator {
    used: AtomicUsize,
}

unsafe impl GlobalAlloc for LimitedAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let size = layout.size();
        let prev = self.used.fetch_add(size, Ordering::Relaxed);
        if prev + size > MAX_BYTES {
            self.used.fetch_sub(size, Ordering::Relaxed);
            return std::ptr::null_mut();
        }
        unsafe { System.alloc(layout) }
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        self.used.fetch_sub(layout.size(), Ordering::Relaxed);
        unsafe { System.dealloc(ptr, layout) }
    }
}

#[global_allocator]
static ALLOCATOR: LimitedAllocator = LimitedAllocator {
    used: AtomicUsize::new(0),
};

fn main() {
    let small: Vec<u8> = Vec::with_capacity(100);
    println!("100 字节分配成功，当前用量: {}", ALLOCATOR.used.load(Ordering::Relaxed));
    drop(small);

    // 直接调用 alloc 以检测 null，避免 handle_alloc_error abort
    let layout = Layout::array::<u8>(5 * 1024).unwrap();
    let ptr = unsafe { std::alloc::alloc(layout) };
    if ptr.is_null() {
        println!("5 KB 分配被拒绝（超出 4 KB 限制）");
    } else {
        unsafe { std::alloc::dealloc(ptr, layout) };
    }
}
```

运行结果：

```
100 字节分配成功，当前用量: 648
5 KB 分配被拒绝（超出 4 KB 限制）
```

> `LimitedAllocator` 使用 `Relaxed` 内存序是有意为之：分配器本身不建立 `happens-before` 关系，仅计数；在多线程场景下可能存在少量超量分配（`TOCTOU`），若需严格限制应改用 `SeqCst` 或将检查+更新用 `compare_exchange` 原子化。

## 七、常见陷阱与最佳实践

### 7.1 优化器可能消除分配

Rust 编译器允许消除"未使用结果"的分配。不能通过计数分配次数来做业务逻辑判断：

```rust
// 错误示范：编译器可能优化掉 Box 的分配
let _b = Box::new(42); // 若结果未使用，分配可能被消除
```

如需阻止消除，通过 `std::hint::black_box` 或真实使用该值。

### 7.2 `GlobalAlloc` 实现中禁止 `panic`

`alloc`/`dealloc` 内部 `panic` 会触发 `double-panic`，导致 `abort` 或未定义行为。需要错误处理时，应返回 `null`（分配失败）或静默忽略。

```rust
// 错误示范
unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
    assert!(layout.size() > 0); // ← 禁止！panic 在分配器中是 UB
    unsafe { System.alloc(layout) }
}
```

### 7.3 零大小 Layout 的处理

`GlobalAlloc::alloc` 的 safety 要求 `layout.size() > 0`，传入零大小布局是未定义行为。Rust 高层类型（`ZST`）不会触发实际分配，但手动调用 `alloc` 时需自行检查：

```rust
if layout.size() == 0 {
    return layout.align() as *mut u8; // 返回对齐的非 null 哨兵指针
}
```

### 7.4 何时需要自定义分配器

| 场景 | 推荐方案 |
|------|---------|
| 性能分析 / 内存泄漏排查 | `CountingAllocator` + 统计日志 |
| 嵌入式 / `no_std` | 静态内存池分配器，替换 `System` |
| 内存用量限制（沙箱） | `LimitedAllocator`，返回 null 触发 `handle_alloc_error` |
| 内存对齐有特殊要求 | 覆盖 `alloc`，强制 `posix_memalign` / `aligned_alloc` |
| 调试：检测双重释放 | 维护已分配地址集合，`dealloc` 时断言 |

## 八、Layout 方法参数速查表

### 构造方法

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `Layout::new::<T>()` | 无（泛型） | `Layout` | 从类型推导 size 和 align |
| `Layout::from_size_align(size, align)` | `size: usize`，`align: usize` | `Result<Layout, LayoutError>` | align 须为 2 的幂；size ≤ isize::MAX |
| `Layout::array::<T>(n)` | `n: usize` | `Result<Layout, LayoutError>` | 等价于 `new::<T>().repeat(n)` |

### 访问方法

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `layout.size()` | 无 | `usize` | 内存块字节数 |
| `layout.align()` | 无 | `usize` | 对齐要求（2 的幂） |

### 组合方法

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `layout.extend(next)` | `next: Layout` | `Result<(Layout, usize), LayoutError>` | 组合两布局；返回 `(合并布局, next的偏移)` |
| `layout.pad_to_align()` | 无 | `Layout` | 补尾部填充，使 size 为 align 的倍数 |
| `layout.repeat(n)` | `n: usize` | `Result<(Layout, usize), LayoutError>` | 重复 n 次；返回 `(数组布局, 步长stride)` |

### GlobalAlloc 方法

| 方法 | 必需 | 参数 | 返回值 |
|------|------|------|--------|
| `alloc(layout)` | 是 | `layout: Layout`（size>0） | `*mut u8`（null=失败） |
| `dealloc(ptr, layout)` | 是 | `ptr: *mut u8`，`layout: Layout` | `()` |
| `realloc(ptr, layout, new_size)` | 否（有默认） | `ptr`，`layout`，`new_size: usize` | `*mut u8`（null=失败，原ptr仍有效） |
| `alloc_zeroed(layout)` | 否（有默认） | `layout: Layout`（size>0） | `*mut u8`（null=失败） |
