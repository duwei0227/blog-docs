---
title: chrono 日期时间处理与时区实战
published: true
layout: post
date: 2026-06-15 20:30:00
permalink: /rust/chrono.html
tags:
  - chrono
  - 日期时间
  - 时区
categories: Rust
---

标准库的 `std::time` 只能回答"现在距离某个起点过了多少纳秒"，它有 `Instant` 和 `SystemTime`，却没有"年月日"的概念，更不懂时区。一旦业务需要"把用户提交的 `2026-06-15 09:10:11` 转成上海时间、再换算成纽约时间、最后存成时间戳"，标准库就无能为力了。`chrono` 正是为此而生：它把时间拆成两层——一层是**朴素类型**（`NaiveDate`、`NaiveTime`、`NaiveDateTime`），像一张没贴时区标签的日历加时钟，只描述"墙上显示的时间"；另一层是**带时区类型**（`DateTime<Tz>`），给墙上时间贴上时区牌，从而对应到全球唯一的某个瞬间。理解这条"朴素 vs 带时区"的分界线，是用好 `chrono` 的关键。

## 一、安装与核心类型

在 `Cargo.toml` 中添加依赖：

```toml
[dependencies]
chrono = "0.4"
# 需要 IANA 时区（如 Asia/Shanghai）时再加这个
chrono-tz = "0.10"
```

`chrono` 默认开启 `clock` 和 `std` 两个 feature。`clock` 提供 `Local::now()` 这类读取系统本地时钟的能力（会拉入 `iana-time-zone` 依赖）；如果你的程序只处理外部传入的时间、从不读取本地时钟，可以用 `default-features = false` 关掉它以减小体积。若需要把日期时间序列化进 `JSON`，再额外开启 `serde` feature：

```toml
chrono = { version = "0.4", features = ["serde"] }
```

`chrono` 的核心是下面六个类型。前三个不带时区信息，后三个是同一个泛型 `DateTime<Tz>` 在不同时区参数下的具体化：

| 类型 | 是否带时区 | 含义 | 典型用途 |
|------|-----------|------|---------|
| `NaiveDate` | 否 | 仅日期（年月日） | 生日、账单日 |
| `NaiveTime` | 否 | 仅时间（时分秒纳秒） | 每天的闹钟时刻 |
| `NaiveDateTime` | 否 | 日期 + 时间，无时区 | 数据库 `DATETIME` 列、日志里的墙上时间 |
| `DateTime<Utc>` | 是（UTC） | 全球统一时间 | 服务端存储、跨系统传输 |
| `DateTime<Local>` | 是（系统本地） | 跟随机器时区 | 给本机用户展示 |
| `DateTime<FixedOffset>` | 是（固定偏移） | 形如 `+08:00` 的固定偏移 | 解析带偏移的字符串 |

为什么要把"朴素"单独拆出来？因为 `2026-06-15 09:10:11` 这串文字本身是**有歧义**的——它在北京是一个瞬间，在伦敦是另一个瞬间。`chrono` 用类型系统强制你表态：当你拿到的是 `NaiveDateTime`，编译器就提醒你"这还不是一个确定的时刻，要先指定时区"；只有贴上时区变成 `DateTime<Tz>`，它才对应全球唯一的瞬间。这种"未定时区不能当作绝对时间用"的约束，把一类常见的时区 bug 挡在了编译期。

> 时区相关的 trait 是 `TimeZone`，`Utc`、`Local`、`FixedOffset` 以及 `chrono-tz` 的 `Tz` 都实现了它。取字段（年月日时分秒）的能力来自 `Datelike` 和 `Timelike` 两个 trait，使用前需要 `use chrono::{Datelike, Timelike}`。

## 二、日期处理

### 2.1 创建与读取 NaiveDate

**语法：**

```rust
NaiveDate::from_ymd_opt(year: i32, month: u32, day: u32) -> Option<NaiveDate>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `year` | - | 年份（公历，支持负数表示公元前） |
| `month` | - | 月份，取值 `1..=12` |
| `day` | - | 日，取值 `1..=31`，须是该月真实存在的日期 |

注意方法名以 `_opt` 结尾、返回 `Option` 而不是直接返回 `NaiveDate`。这是 `chrono` 的刻意设计：像 `2026-02-30` 这样的非法日期在编译期无法拦截，只能在运行期返回 `None`。早期版本曾提供会 `panic` 的 `from_ymd`，现已废弃，就是为了逼使用者显式处理非法输入，而不是在生产环境里突然崩溃。

```rust
use chrono::{NaiveDate, Datelike, Weekday};

fn main() {
    let d = NaiveDate::from_ymd_opt(2026, 6, 15).unwrap();
    println!("date = {}", d);

    let invalid = NaiveDate::from_ymd_opt(2026, 2, 30);
    println!("2026-02-30 => {:?}", invalid);

    println!("year={}, month={}, day={}", d.year(), d.month(), d.day());
    println!("weekday={:?}, ordinal={}", d.weekday(), d.ordinal());

    let iso = NaiveDate::from_isoywd_opt(2026, 25, Weekday::Mon).unwrap();
    println!("ISO 2026-W25-Mon = {}", iso);
}
```

运行结果：

```
date = 2026-06-15
2026-02-30 => None
year=2026, month=6, day=15
weekday=Mon, ordinal=166
ISO 2026-W25-Mon = 2026-06-15
```

`weekday()` 返回星期枚举，`ordinal()` 返回"一年中的第几天"（`2026-06-15` 是第 `166` 天）。`from_isoywd_opt` 按 `ISO 8601` 的"年-周数-星期"创建日期，适合处理周报、排班这类以"周"为单位的业务。

### 2.2 日期运算

日期可以直接加减 `Duration`（在新版本中是 `TimeDelta` 的别名），两个日期相减得到一个 `TimeDelta`，再用 `num_days()` 取出相差天数。

求相邻日期则用 `succ_opt` 和 `pred_opt`：`succ_opt()` 返回当前日期的后一天（successor），`pred_opt()` 返回前一天（predecessor）。二者都返回 `Option<NaiveDate>`，因为 `NaiveDate` 能表示的年份有上下界，在边界处求后继/前驱会得到 `None`。它们语义上等价于 `d + Duration::days(1)` 和 `d - Duration::days(1)`，但少了构造 `Duration` 的开销，意图也更直白：

```rust
use chrono::{NaiveDate, Duration};

fn main() {
    let d = NaiveDate::from_ymd_opt(2026, 6, 15).unwrap();

    let later = d + Duration::days(20);
    println!("+20 days = {}", later);
    println!("next day = {}", d.succ_opt().unwrap());
    println!("prev day = {}", d.pred_opt().unwrap());

    let d2 = NaiveDate::from_ymd_opt(2026, 1, 1).unwrap();
    let delta = d - d2;
    println!("days since new year = {}", delta.num_days());
}
```

运行结果：

```
+20 days = 2026-07-05
next day = 2026-06-16
prev day = 2026-06-14
days since new year = 165
```

相减得到的 `TimeDelta` 不只有 `num_days()`，还能用 `num_weeks()`、`num_hours()`、`num_seconds()` 等换算成不同粒度；它本身也能反过来加回某个日期。需要注意 `NaiveDate` 的年份上下界约为公元前 26 万年到公元 26 万年，日常业务远不会触及，这也是 `succ_opt`/`pred_opt` 几乎不会返回 `None` 的原因。

## 三、时间处理

### 3.1 创建与读取 NaiveTime

**语法：**

```rust
NaiveTime::from_hms_opt(hour: u32, min: u32, sec: u32) -> Option<NaiveTime>
NaiveTime::from_hms_milli_opt(hour: u32, min: u32, sec: u32, milli: u32) -> Option<NaiveTime>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `hour` | - | 小时，取值 `0..=23` |
| `min` | - | 分钟，取值 `0..=59` |
| `sec` | - | 秒，取值 `0..=59`（闰秒见下方说明） |
| `milli` | - | 毫秒，取值 `0..=999`（`_milli_opt` 专有，另有 `_micro_opt`/`_nano_opt`） |

```rust
use chrono::{NaiveTime, Timelike};

fn main() {
    let t = NaiveTime::from_hms_opt(9, 10, 11).unwrap();
    println!("time = {}", t);

    let t_ms = NaiveTime::from_hms_milli_opt(9, 10, 11, 250).unwrap();
    println!("with millis = {}", t_ms);

    println!(
        "hour={}, minute={}, second={}, nano={}",
        t.hour(), t.minute(), t.second(), t.nanosecond()
    );

    println!("25:00:00 => {:?}", NaiveTime::from_hms_opt(25, 0, 0));
}
```

运行结果：

```
time = 09:10:11
with millis = 09:10:11.250
hour=9, minute=10, second=11, nano=0
25:00:00 => None
```

> **闰秒的坑**：`chrono` 用"纳秒字段超过 10 亿"来表示闰秒。比如 `from_hms_milli_opt(23, 59, 59, 1_000)` 表示的是 `23:59:60`（闰秒），而非进位到下一分钟。绝大多数业务用不到闰秒，但如果你直接对 `nanosecond()` 的返回值做断言，要记得它可能 ≥ `1_000_000_000`，否则会在极少数时刻出现意外。

## 四、日期时间组合

### 4.1 从朴素类型升级到带时区类型

`NaiveDate` 提供 `and_hms_opt` 拼上时间得到 `NaiveDateTime`；再调用 `and_utc()` 或 `and_local_timezone()` 贴上时区，就升级成了带时区的 `DateTime`。这条链路清晰地体现了"先有墙上时间、再指定时区"的分层：

```rust
use chrono::{DateTime, NaiveDate, NaiveDateTime, Utc};

fn main() {
    let ndt: NaiveDateTime = NaiveDate::from_ymd_opt(2026, 6, 15)
        .unwrap()
        .and_hms_opt(9, 10, 11)
        .unwrap();
    println!("naive = {}", ndt);

    let dt_utc: DateTime<Utc> = ndt.and_utc();
    println!("utc = {}", dt_utc);

    let ts = dt_utc.timestamp();
    println!("timestamp = {}", ts);
    println!("timestamp_millis = {}", dt_utc.timestamp_millis());

    let back = DateTime::from_timestamp(ts, 0).unwrap();
    println!("from_timestamp = {}", back);
}
```

运行结果：

```
naive = 2026-06-15 09:10:11
utc = 2026-06-15 09:10:11 UTC
timestamp = 1781514611
timestamp_millis = 1781514611000
from_timestamp = 2026-06-15 09:10:11 UTC
```

### 4.2 当前时间与时间戳互转

获取当前时间用 `Utc::now()`（推荐服务端用）或 `Local::now()`（跟随机器时区）。`DateTime` 与 `Unix` 时间戳的互转是最常用的存储手段：

| 方法 | 方向 | 说明 |
|------|------|------|
| `Utc::now()` | - | 当前 UTC 时间，返回 `DateTime<Utc>` |
| `Local::now()` | - | 当前本地时间，返回 `DateTime<Local>` |
| `timestamp()` | DateTime → i64 | 秒级 Unix 时间戳 |
| `timestamp_millis()` | DateTime → i64 | 毫秒级时间戳 |
| `timestamp_micros()` | DateTime → i64 | 微秒级时间戳 |
| `DateTime::from_timestamp(secs, nanos)` | i64 → DateTime | 由秒 + 纳秒还原 `DateTime<Utc>`，越界返回 `None` |

> 时间戳本身不带时区——它就是"距离 `1970-01-01 00:00:00 UTC` 的秒数"。所以 `from_timestamp` 还原出来的永远是 `DateTime<Utc>`，要展示给特定地区用户时，再用第六节的 `with_timezone` 转换即可。

## 五、字符串与日期类型转换

字符串与日期的互转是日常使用频率最高的部分，分"格式化"（日期 → 字符串）和"解析"（字符串 → 日期）两个方向，二者都基于 `strftime` 风格的格式占位符。

### 5.1 格式化：日期转字符串

**语法：**

```rust
dt.format(fmt: &str) -> DelayedFormat
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `fmt` | - | `strftime` 风格格式串，由占位符与字面量混排组成 |

`format()` 返回的是一个延迟求值的 `DelayedFormat`，它实现了 `Display`——意味着真正的字符串拼接发生在 `println!` 或 `.to_string()` 那一刻，没有用到就不会有开销。常用占位符如下：

| 占位符 | 含义 | 示例输出 |
|--------|------|---------|
| `%Y` | 四位年份 | `2026` |
| `%m` | 两位月份 | `06` |
| `%d` | 两位日 | `15` |
| `%H` | 24 小时制小时 | `09` |
| `%M` | 分钟 | `10` |
| `%S` | 秒 | `11` |
| `%A` | 星期全称 | `Monday` |
| `%a` | 星期缩写 | `Mon` |
| `%B` | 月份全称 | `June` |
| `%e` | 空格补位的日 | `15` |
| `%j` | 一年中的第几天 | `166` |
| `%z` | 时区偏移 | `+0000` |
| `%Z` | 时区名称缩写 | `UTC` |
| `%F` | 等价于 `%Y-%m-%d` | `2026-06-15` |
| `%T` | 等价于 `%H:%M:%S` | `09:10:11` |

```rust
use chrono::{TimeZone, Utc};

fn main() {
    let dt = Utc.with_ymd_and_hms(2026, 6, 15, 9, 10, 11).unwrap();

    println!("{}", dt.format("%Y-%m-%d %H:%M:%S"));
    println!("{}", dt.format("%Y年%m月%d日 %H时%M分%S秒"));
    println!("{}", dt.format("%A, %B %e, %Y"));
    println!("day of year = {}", dt.format("%j"));
    println!("%F %T => {}", dt.format("%F %T"));

    println!("rfc3339 = {}", dt.to_rfc3339());
    println!("rfc2822 = {}", dt.to_rfc2822());
}
```

运行结果：

```
2026-06-15 09:10:11
2026年06月15日 09时10分11秒
Monday, June 15, 2026
day of year = 166
%F %T => 2026-06-15 09:10:11
rfc3339 = 2026-06-15T09:10:11+00:00
rfc2822 = Mon, 15 Jun 2026 09:10:11 +0000
```

格式串里可以直接夹中文字面量（`%Y年%m月`），`chrono` 会原样保留非占位符字符。对于跨系统传输，优先用 `to_rfc3339()`（即 `ISO 8601`）而非自定义格式——它是带时区偏移的标准格式，几乎所有语言都能正确解析。

### 5.2 解析：字符串转日期

解析是格式化的逆操作，但有一个**核心区分**：目标类型带不带时区，决定了用哪个方法、字符串里必须包含什么。

**语法：**

```rust
DateTime::parse_from_str(s: &str, fmt: &str) -> Result<DateTime<FixedOffset>, ParseError>
NaiveDateTime::parse_from_str(s: &str, fmt: &str) -> Result<NaiveDateTime, ParseError>
```

**参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `s` | - | 待解析的字符串 |
| `fmt` | - | 与 `s` 结构一致的 `strftime` 格式串 |

四种解析方式各有适用场景：

| 方法 | 返回类型 | 对字符串的要求 |
|------|---------|---------------|
| `DateTime::parse_from_str` | `DateTime<FixedOffset>` | **必须含偏移**（格式串里有 `%z`） |
| `NaiveDateTime::parse_from_str` | `NaiveDateTime` | 不含偏移的墙上时间 |
| `FromStr`（`.parse()`） | `DateTime<Utc>` 等 | 标准 `ISO 8601` / `RFC 3339` |
| `parse_from_rfc3339` / `parse_from_rfc2822` | `DateTime<FixedOffset>` | 对应 RFC 标准格式 |

```rust
use chrono::{DateTime, FixedOffset, NaiveDateTime, Utc};

fn main() {
    let dt: DateTime<FixedOffset> =
        DateTime::parse_from_str("2026-06-15 09:10:11 +08:00", "%Y-%m-%d %H:%M:%S %z").unwrap();
    println!("fixed offset = {}", dt);

    let ndt = NaiveDateTime::parse_from_str("2026-06-15 09:10:11", "%Y-%m-%d %H:%M:%S").unwrap();
    println!("naive = {}", ndt);

    let dt_utc: DateTime<Utc> = "2026-06-15T09:10:11Z".parse().unwrap();
    println!("from_str utc = {}", dt_utc);

    let r3339 = DateTime::parse_from_rfc3339("2026-06-15T09:10:11+08:00").unwrap();
    println!("rfc3339 = {}", r3339);
    let r2822 = DateTime::parse_from_rfc2822("Mon, 15 Jun 2026 09:10:11 +0800").unwrap();
    println!("rfc2822 = {}", r2822);

    let err = DateTime::parse_from_str("2026-06-15 09:10:11", "%Y-%m-%d %H:%M:%S");
    println!("no offset is_err => {:?}", err.is_err());
}
```

运行结果：

```
fixed offset = 2026-06-15 09:10:11 +08:00
naive = 2026-06-15 09:10:11
from_str utc = 2026-06-15 09:10:11 UTC
rfc3339 = 2026-06-15 09:10:11 +08:00
rfc2822 = 2026-06-15 09:10:11 +08:00
no offset is_err => true
```

> **最常见的解析报错**：拿 `DateTime::parse_from_str` 去解析一个**不带偏移**的字符串（如 `2026-06-15 09:10:11`）必然失败——返回 `DateTime<FixedOffset>` 的方法要求字符串里有偏移信息，否则无法确定它是哪个时区的瞬间。上面最后一行 `is_err => true` 正是这个原因。遇到这种字符串，应改用 `NaiveDateTime::parse_from_str` 解析成朴素类型，再根据业务用 `and_utc()` / `and_local_timezone()` 显式指定时区。

## 六、时区处理

### 6.1 三种时区类型

`chrono` 内置三种实现了 `TimeZone` trait 的时区类型，它们的区别在于"偏移量从哪来、何时确定"：

| 类型 | 偏移量来源 | 是否随日期变化 | 典型场景 |
|------|-----------|---------------|---------|
| `Utc` | 恒为 `+00:00` | 否 | 服务端存储、运算基准、跨系统传输 |
| `Local` | 运行时读取操作系统时区设置 | 是（会跟随系统的夏令时规则） | 命令行工具给本机用户展示 |
| `FixedOffset` | 创建时手动指定的固定偏移 | 否 | 解析/构造形如 `+08:00` 的带偏移时间 |

三者的关系可以这样理解：`Utc` 是"偏移恒为零"的特例，最适合做内部基准——所有运算都在 `UTC` 下进行，不会被夏令时干扰；`Local` 在每次需要偏移时去问操作系统（读取 `TZ` 环境变量或系统时区配置），所以同一份代码在不同机器上输出不同，**不要用它做需要跨机器一致的存储**；`FixedOffset` 则把一个写死的偏移随身带着。

`FixedOffset` 用 `east_opt`（东时区，偏移为正）或 `west_opt`（西时区，偏移为负）创建，参数是相对 `UTC` 的偏移**秒数**。比如东八区是 `east_opt(8 * 3600)`，美东标准时间则是 `west_opt(5 * 3600)`。它同样以 `_opt` 结尾返回 `Option`——当偏移量超过 `±86400` 秒（即超过一整天）这种非法值时返回 `None`：

```rust
use chrono::{FixedOffset, TimeZone};

fn main() {
    let cst = FixedOffset::east_opt(8 * 3600).unwrap();
    let dt = cst.with_ymd_and_hms(2026, 6, 15, 9, 10, 11).unwrap();
    println!("fixed +08 = {}", dt);
}
```

运行结果：

```
fixed +08 = 2026-06-15 09:10:11 +08:00
```

`FixedOffset` 只是一个死板的偏移量，它不知道"夏令时"这回事。要处理真实地区（夏令时会自动切换偏移），需要 `chrono-tz` 提供的 `IANA` 时区数据库。

### 6.2 跨时区转换与综合实战

时区转换的核心方法是 `with_timezone(&tz)`——它**不改变所指向的瞬间**，只换一块"时区牌"重新展示。下面是一个完整链路：解析一个 `UTC` 字符串，转成上海时间和纽约时间，验证三者是同一瞬间，并计算两地时差。

```rust
use chrono::{DateTime, Utc};
use chrono_tz::America::New_York;
use chrono_tz::Asia::Shanghai;

fn main() {
    let utc: DateTime<Utc> = "2026-06-15T09:10:11Z".parse().unwrap();
    println!("UTC      = {}", utc);

    let sh = utc.with_timezone(&Shanghai);
    println!("Shanghai = {}", sh);

    let ny = utc.with_timezone(&New_York);
    println!("New York = {}", ny);

    // 同一瞬间，时间戳必然相同
    println!(
        "same instant: {}",
        utc.timestamp() == sh.timestamp() && sh.timestamp() == ny.timestamp()
    );

    // 用各自的墙上时间相减得到时差
    let diff = (sh.naive_local() - ny.naive_local()).num_hours();
    println!("Shanghai - New York = {} hours", diff);
}
```

运行结果：

```
UTC      = 2026-06-15 09:10:11 UTC
Shanghai = 2026-06-15 17:10:11 CST
New York = 2026-06-15 05:10:11 EDT
same instant: true
Shanghai - New York = 12 hours
```

注意纽约这里显示的是 `EDT`（东部夏令时，偏移 `-04:00`）而非冬季的 `EST`（`-05:00`）——`chrono-tz` 根据 `6` 月这个日期自动选对了夏令时偏移，所以上海与纽约的墙上时间差是 `12` 小时而非 `13` 小时。这正是 `FixedOffset` 做不到、必须用 `chrono-tz` 的原因。`naive_local()` 取出某时区下的"墙上时间"（朴素类型），`naive_utc()` 则取出对应的 `UTC` 墙上时间。

> 把朴素时间反向贴到 `IANA` 时区时（`tz.from_local_datetime(&naive)`），返回的是 `LocalResult` 而非直接的 `DateTime`，因为夏令时切换会导致某些墙上时间**不存在**或**出现两次**。常规时刻直接取 `.single().unwrap()` 即可；只有当你处理的恰好是夏令时切换那一两个小时的本地时间时，才需要分别处理这几种情况。

