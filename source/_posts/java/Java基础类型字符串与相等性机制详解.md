---
title: Java 基础类型、字符串与相等性机制
published: true
layout: post
date: 2026-06-30 19:23:18
permalink: /java/java-basic-types-string-equality.html
tags:
  - 基础类型
  - 包装类
  - 字符串
  - equals
  - hashCode
categories: Java
---

Java 基础语法里有几组概念很容易混在一起：基本类型与包装类、自动装箱与拆箱、`==` 与 `equals()`、`String` 常量池，以及 `StringBuilder` 和 `StringBuffer`。这些内容看起来都是小语法点，但它们直接影响对象比较、集合去重、空指针问题和字符串拼接性能。

本文按照“类型 -> 比较 -> 字符串 -> 实战陷阱”的顺序，把这些概念串起来。

## 一、基本类型与包装类

Java 有 8 种基本类型（primitive type），它们保存的是具体的值；每种基本类型都有一个对应的包装类（wrapper class），包装类是对象，可以参与泛型、集合、反射等面向对象场景。

| 基本类型 | 包装类型 | 默认值 | 常见用途 |
| --- | --- | --- | --- |
| `byte` | `Byte` | `0` | 小范围整数、二进制数据 |
| `short` | `Short` | `0` | 小范围整数 |
| `int` | `Integer` | `0` | 常用整数 |
| `long` | `Long` | `0L` | 大整数、ID、时间戳 |
| `float` | `Float` | `0.0f` | 单精度浮点数 |
| `double` | `Double` | `0.0d` | 双精度浮点数 |
| `char` | `Character` | `'\u0000'` | 单个字符 |
| `boolean` | `Boolean` | `false` | 布尔值 |

基本类型和包装类的核心区别如下：

| 对比项 | 基本类型 | 包装类 |
| --- | --- | --- |
| 保存内容 | 直接保存值 | 保存对象引用 |
| 是否可以为 `null` | 不可以 | 可以 |
| 能否作为泛型参数 | 不可以 | 可以，例如 `List<Integer>` |
| 是否有方法 | 没有 | 有，例如 `Integer.parseInt()` |
| 默认值 | 各类型固定默认值 | 引用类型字段默认为 `null` |

包装类存在的主要原因是：Java 的集合、泛型和大量 API 都基于对象工作。例如 `List<int>` 是非法的，应该写成 `List<Integer>`。包装类还提供了类型转换、比较、字符串解析等工具方法。

> 注意：`char` 的包装类是 `Character`，不是 `Char`。

## 二、自动装箱与自动拆箱

自动装箱（autoboxing）是把基本类型自动转换成包装类对象；自动拆箱（unboxing）是把包装类对象自动转换成基本类型。它们是编译器提供的语法糖，不代表基本类型和包装类真的变成了同一种类型。

示例：

```java
public class BoxingDemo {
    public static void main(String[] args) {
        Integer boxed = 10;
        int unboxed = boxed;

        System.out.println(boxed);
        System.out.println(unboxed + 5);
    }
}
```

运行结果：

```text
10
15
```

上面的代码中：

- `Integer boxed = 10;` 会被编译器处理成类似 `Integer.valueOf(10)` 的调用。
- `int unboxed = boxed;` 会被编译器处理成类似 `boxed.intValue()` 的调用。
- `unboxed + 5` 是基本类型运算。

### 2.1 使用 `javap -c` 观察编译结果

自动装箱和自动拆箱不是 JVM 在运行时临时猜测出来的行为，而是 Java 编译器在编译阶段插入了对应的方法调用。可以用 JDK 自带的 `javap -c` 查看 `.class` 文件里的字节码指令。

先准备一个简单类：

```java
public class AutoBoxingBytecodeDemo {
    public static void main(String[] args) {
        Integer boxed = 10;
        int unboxed = boxed;

        System.out.println(unboxed);
    }
}
```

编译并反编译字节码：

```bash
javac AutoBoxingBytecodeDemo.java
javap -c AutoBoxingBytecodeDemo
```

输出示例：

```text
Compiled from "AutoBoxingBytecodeDemo.java"
public class AutoBoxingBytecodeDemo {
  public AutoBoxingBytecodeDemo();
    Code:
         0: aload_0
         1: invokespecial #1                  // Method java/lang/Object."<init>":()V
         4: return

  public static void main(java.lang.String[]);
    Code:
         0: bipush        10
         2: invokestatic  #7                  // Method java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
         5: astore_1
         6: aload_1
         7: invokevirtual #13                 // Method java/lang/Integer.intValue:()I
        10: istore_2
        11: getstatic     #17                 // Field java/lang/System.out:Ljava/io/PrintStream;
        14: iload_2
        15: invokevirtual #23                 // Method java/io/PrintStream.println:(I)V
        18: return
}
```

关键位置有两处：

| 字节码位置 | 指令 | 说明 |
| --- | --- | --- |
| `2` | `invokestatic Integer.valueOf(int)` | `Integer boxed = 10;` 被编译成调用 `Integer.valueOf(10)`，这就是自动装箱 |
| `7` | `invokevirtual Integer.intValue()` | `int unboxed = boxed;` 被编译成调用 `boxed.intValue()`，这就是自动拆箱 |

因此，自动装箱和拆箱可以理解为编译器帮我们补全了包装类和基本类型之间的转换代码。写源码时看起来只是普通赋值，编译后已经变成了明确的方法调用。

自动装箱和拆箱让代码更简洁，但也会隐藏空指针风险。最典型的问题是包装类为 `null` 时发生自动拆箱。

```java
public class UnboxingNullDemo {
    public static void main(String[] args) {
        Integer value = null;

        try {
            int number = value;
            System.out.println(number);
        } catch (NullPointerException e) {
            System.out.println("自动拆箱触发 NullPointerException");
        }
    }
}
```

运行结果：

```text
自动拆箱触发 NullPointerException
```

`int number = value;` 看起来只是赋值，实际会调用 `value.intValue()`。当 `value` 是 `null` 时，就会触发 `NullPointerException`。

常见触发拆箱的场景包括：

| 场景 | 示例 | 风险 |
| --- | --- | --- |
| 赋值给基本类型 | `int n = wrapper;` | `wrapper` 为 `null` 时 NPE |
| 参与算术运算 | `wrapper + 1` | 运算前先拆箱 |
| 与基本类型比较 | `wrapper == 1` | 比较前先拆箱 |
| 三目运算符 | `flag ? wrapper : 0` | 类型推断可能触发拆箱 |

推荐做法是：业务字段如果允许缺失，用包装类表达 `null`；真正参与运算前，先判断是否为 `null`，或者提供明确默认值。

## 三、`Integer` 缓存机制

`Integer` 有一个容易让人误判的现象：有些 `Integer` 对象用 `==` 比较是 `true`，有些是 `false`。

```java
public class IntegerCacheDemo {
    public static void main(String[] args) {
        Integer a = 127;
        Integer b = 127;
        Integer c = 128;
        Integer d = 128;

        System.out.println(a == b);
        System.out.println(c == d);
        System.out.println(c.equals(d));
    }
}
```

运行结果：

```text
true
false
true
```

原因在于 `Integer a = 127;` 这类自动装箱会使用 `Integer.valueOf()`。`Integer.valueOf()` 会复用一段缓存范围内的对象，默认缓存范围是 `-128` 到 `127`。因此 `a` 和 `b` 引用的是同一个缓存对象，而 `c` 和 `d` 通常是两个不同对象。

`c.equals(d)` 返回 `true`，因为 `Integer` 重写了 `equals()`，比较的是数值内容。

> 注意：不要把 `Integer` 缓存当成业务逻辑的一部分。包装类数值比较应优先使用 `equals()`，或者先拆成基本类型再比较。

### 3.1 `IntegerCache` 的工作机制

在 HotSpot/OpenJDK 中，`Integer` 内部有一个静态内部类 `Integer.IntegerCache`。这个缓存类会在 `Integer` 类初始化时提前创建一批 `Integer` 对象，后续 `Integer.valueOf(int)` 遇到缓存范围内的数值时，直接从数组中取对象。

```java
public static Integer valueOf(int i) {
        if (i >= IntegerCache.low && i <= IntegerCache.high)
            return IntegerCache.cache[i + (-IntegerCache.low)];
        return new Integer(i);
    }
```



缓存数组的索引要做一次偏移，因为数组下标从 `0` 开始，而缓存最小值是 `-128`：

| 数值 | 数组下标计算 | 结果 |
| --- | --- | --- |
| `-128` | `-128 + 128` | `0` |
| `0` | `0 + 128` | `128` |
| `127` | `127 + 128` | `255` |

所以默认缓存 `-128` 到 `127` 时，一共会缓存 `256` 个 `Integer` 对象。

### 3.2 为什么默认范围是 `-128` 到 `127`

这个范围不是随意选择的，主要有两层原因：

| 层面 | 原因 |
| --- | --- |
| Java 语言规范 | 对 `boolean`、`byte`、部分 `char`，以及 `short`、`int`、`long` 中 `-128` 到 `127` 范围内的常量表达式，装箱后要求相同值可以得到不可区分的引用结果 |
| 工程实现 | `-128` 到 `127` 是 `byte` 的完整取值范围，也是程序里最常见的小整数范围，缓存成本低，复用收益高 |

`IntegerCache` 的下限固定为 `-128`，上限默认是 `127`。这样既满足语言规范对小整数装箱引用复用的要求，又避免默认缓存过多整数对象。

### 3.3 自定义 `Integer` 最大缓存值

在 HotSpot/OpenJDK 中，可以通过 JVM 参数调大 `Integer` 缓存的最大值：

```bash
java -XX:AutoBoxCacheMax=200 IntegerCacheHighDemo
```

示例代码：

```java
public class IntegerCacheHighDemo {
    public static void main(String[] args) {
        Integer a = 200;
        Integer b = 200;
        Integer c = 1000;
        Integer d = 1000;

        System.out.println(a == b);
        System.out.println(c == d);
    }
}
```

默认运行：

```bash
java IntegerCacheHighDemo
```

运行结果：

```text
false
false
```

调大缓存上限后运行：

```bash
java -XX:AutoBoxCacheMax=200 IntegerCacheHighDemo
```

运行结果：

```text
true
false
```

`200` 已经进入缓存范围，所以 `a == b` 为 `true`；`1000` 仍然不在缓存范围内，所以 `c == d` 还是 `false`。

也可以看到这个 JVM 参数会影响 `AutoBoxCacheMax`：

```text
intx AutoBoxCacheMax = 200 {C2 product} {command line}
```

> 注意：`-XX:AutoBoxCacheMax` 是 HotSpot/OpenJDK 的 JVM 参数，不是 Java 语言层面的通用语法。即使可以调大缓存范围，也不应该在业务代码里依赖 `Integer` 的引用相等结果。

常见包装类缓存规则可以这样理解：

| 包装类 | 常见缓存情况 |
| --- | --- |
| `Byte` | 全部缓存 |
| `Short` | 通常缓存 `-128` 到 `127` |
| `Integer` | 默认缓存 `-128` 到 `127` |
| `Long` | 通常缓存 `-128` 到 `127` |
| `Character` | 通常缓存 `0` 到 `127` |
| `Boolean` | 缓存 `TRUE` 和 `FALSE` |
| `Float` / `Double` | 不使用整数包装类这种缓存机制 |

## 四、`==`、`equals()` 与 `hashCode()`

`==` 的含义取决于比较对象的类型：

| 类型 | `==` 比较内容 |
| --- | --- |
| 基本类型 | 比较值 |
| 引用类型 | 比较两个引用是否指向同一个对象 |

`equals()` 是 `Object` 提供的方法。默认情况下，`Object.equals()` 的行为和引用比较类似；很多类会重写它，例如 `String`、`Integer`、`Long` 等，用来比较对象内容。

`hashCode()` 用于返回对象的哈希值，常见于 `HashMap`、`HashSet` 等哈希集合。它和 `equals()` 有一条关键契约：

| 规则 | 含义 |
| --- | --- |
| `a.equals(b)` 为 `true` | `a.hashCode()` 必须等于 `b.hashCode()` |
| `a.hashCode() == b.hashCode()` | `a.equals(b)` 不一定为 `true`，可能只是哈希冲突 |

如果自定义类重写了 `equals()`，就必须同时重写 `hashCode()`。否则对象在 `HashSet`、`HashMap` 中可能无法正确去重或查找。

### 4.1 重写 `equals()` 的规则

`equals()` 不是随便返回一个布尔值就可以，它需要满足“等价关系”的基本规则。否则集合、缓存、去重、对象比较都会出现不稳定行为。

| 规则 | 要求 | 示例说明 |
| --- | --- | --- |
| 自反性 | `x.equals(x)` 必须为 `true` | 一个对象必须等于它自己 |
| 对称性 | `x.equals(y)` 为 `true` 时，`y.equals(x)` 也必须为 `true` | 不能出现 A 认为等于 B，但 B 不认为等于 A |
| 传递性 | `x.equals(y)`、`y.equals(z)` 都为 `true` 时，`x.equals(z)` 必须为 `true` | 多个对象之间的相等关系要一致 |
| 一致性 | 对象参与比较的字段没有变化时，多次调用结果必须一致 | 不能第一次为 `true`，第二次无原因变成 `false` |
| 非空性 | `x.equals(null)` 必须为 `false` | 任意非空对象都不能等于 `null` |

实现 `equals()` 时通常按这个顺序写：

1. 先判断引用是否相同：`this == obj`。
2. 再判断类型是否匹配：`obj instanceof User other`。
3. 最后比较真正决定对象身份的字段。

示例中的 `User` 通过 `id` 和 `name` 判断是否相等，说明这两个字段共同定义了这个对象的业务身份。

### 4.2 重写 `hashCode()` 的要求

`hashCode()` 的核心要求是和 `equals()` 保持一致。

| 要求 | 说明 |
| --- | --- |
| 相等对象必须有相同哈希值 | 如果 `a.equals(b)` 为 `true`，则 `a.hashCode() == b.hashCode()` 必须为 `true` |
| 不相等对象可以有相同哈希值 | 哈希冲突允许存在，集合会继续用 `equals()` 判断 |
| 参与计算的字段要和 `equals()` 一致 | `equals()` 用了 `id` 和 `name`，`hashCode()` 也应该使用 `id` 和 `name` |
| 尽量使用稳定字段 | 如果对象放入 `HashSet` 后又修改了参与哈希计算的字段，后续可能查不到该对象 |

最常见的错误是：`equals()` 比较了业务字段，但 `hashCode()` 没有同步使用这些字段。例如两个用户 `id` 和 `name` 一样，`equals()` 返回 `true`，但哈希值不同，`HashSet` 就可能把它们放到不同桶里，导致去重失败。

推荐使用 `Objects.hash(...)` 或 IDE 生成的 `equals()` / `hashCode()`，但要自己确认字段选择是否符合业务身份。

正确示例：

```java
import java.util.HashSet;
import java.util.Objects;
import java.util.Set;

public class HashCodeDemo {
    static class User {
        private final long id;
        private final String name;

        User(long id, String name) {
            this.id = id;
            this.name = name;
        }

        @Override
        public boolean equals(Object obj) {
            if (this == obj) {
                return true;
            }
            if (!(obj instanceof User other)) {
                return false;
            }
            return id == other.id && Objects.equals(name, other.name);
        }

        @Override
        public int hashCode() {
            return Objects.hash(id, name);
        }
    }

    public static void main(String[] args) {
        Set<User> users = new HashSet<>();
        users.add(new User(1L, "Alice"));
        users.add(new User(1L, "Alice"));

        System.out.println(users.size());
    }
}
```

运行结果：

```text
1
```

两个 `User` 对象虽然是不同实例，但它们的 `id` 和 `name` 相同。`equals()` 判断它们内容相等，`hashCode()` 也基于同样字段计算，所以 `HashSet` 能正确去重。

## 五、`String` 不可变性

`String` 是不可变对象。创建后，字符串内容不能被原地修改。看起来像“修改字符串”的方法，实际都会返回一个新的字符串对象。

```java
public class StringImmutableDemo {
    public static void main(String[] args) {
        String text = "Java";
        String upper = text.toUpperCase();

        System.out.println(text);
        System.out.println(upper);
        System.out.println(text == upper);
    }
}
```

运行结果：

```text
Java
JAVA
false
```

`toUpperCase()` 没有修改原来的 `text`，而是返回了新的字符串 `upper`。因此原字符串仍然是 `Java`。

`String` 不可变有几个重要好处：

| 好处 | 原因 |
| --- | --- |
| 线程安全 | 多线程共享同一个字符串时，不会被其他线程改坏 |
| 适合作为 `HashMap` key | 哈希值和内容不会在放入集合后变化 |
| 支持常量池复用 | 字符串字面量可以安全共享 |
| 减少防御性拷贝 | API 接收字符串后，不必担心调用方后续修改其内容 |

需要注意的是，循环中频繁使用 `+` 拼接字符串可能产生多个中间对象。对于大量、动态的拼接，应使用 `StringBuilder`。

## 六、字符串常量池与 `intern()`

字符串常量池用于复用字符串字面量。相同的字符串字面量通常会指向常量池里的同一个字符串对象。

```java
public class StringPoolDemo {
    public static void main(String[] args) {
        String a = "hello";
        String b = "he" + "llo";
        String part = "llo";
        String c = "he" + part;
        String d = new String("hello");
        String e = d.intern();

        System.out.println(a == b);
        System.out.println(a == c);
        System.out.println(a == d);
        System.out.println(a == e);
        System.out.println(a.equals(d));
    }
}
```

运行结果：

```text
true
false
false
true
true
```

逐行解释：

- `a == b` 为 `true`，因为 `"he" + "llo"` 是编译期常量表达式，编译后等价于 `"hello"`。
- `a == c` 为 `false`，因为 `part` 是变量，拼接发生在运行期，会产生新的字符串对象。
- `a == d` 为 `false`，因为 `new String("hello")` 显式创建了新对象。
- `a == e` 为 `true`，因为 `d.intern()` 返回常量池中 `"hello"` 的规范引用。
- `a.equals(d)` 为 `true`，因为两者内容相同。

`intern()` 的作用是返回字符串在常量池中的规范引用。如果常量池已有内容相同的字符串，就返回池中的引用；如果没有，就把当前字符串对应的内容放入池中，并返回池中的引用。

实际开发中，不要为了普通字符串比较主动使用 `intern()`。字符串内容比较直接使用 `equals()`：

```java
if ("success".equals(status)) {
    System.out.println("处理成功");
}
```

把常量写在左边可以避免 `status` 为 `null` 时触发空指针。

## 七、`StringBuilder` 与 `StringBuffer`

`StringBuilder` 和 `StringBuffer` 都表示可变字符序列，适合做多次追加、插入、删除等字符串构造操作。它们和 `String` 的核心差别是：`String` 不可变，而这两个类内部维护可变缓冲区。

```java
public class StringBuilderBufferDemo {
    public static void main(String[] args) {
        StringBuilder builder = new StringBuilder();
        builder.append("user=").append("alice").append(", score=").append(95);

        StringBuffer buffer = new StringBuffer();
        buffer.append("status=").append("ok");

        System.out.println(builder);
        System.out.println(buffer);
    }
}
```

运行结果：

```text
user=alice, score=95
status=ok
```

两者 API 很像，主要差异在同步策略：

| 类型 | 是否可变 | 线程安全 | 适用场景 |
| --- | --- | --- | --- |
| `String` | 不可变 | 是 | 少量字符串、常量、Map key |
| `StringBuilder` | 可变 | 否 | 单线程、方法内部局部拼接 |
| `StringBuffer` | 可变 | 是，方法带同步 | 多线程共享同一个缓冲区 |

推荐选择规则：

- 少量简单拼接：直接使用 `+`，编译器通常会优化。
- 方法内部循环拼接：使用 `StringBuilder`。
- 多线程共享同一个可变字符串缓冲区：考虑 `StringBuffer`，或者使用外部同步控制。

多数业务代码中，字符串拼接发生在单线程的局部变量里，优先选择 `StringBuilder`。

### 7.1 循环中字符串拼接方式对比

在循环里拼接字符串时，`String`、`StringBuilder`、`StringBuffer` 的差异会被放大。核心原因是 `String` 不可变，每次 `result += "a"` 都要生成新的字符串结果；而 `StringBuilder` 和 `StringBuffer` 会在内部可变缓冲区上追加内容。

下面用一个简单示例观察三种写法的耗时差异：

```java
public class StringConcatLoopBenchmark {
    private static final int COUNT = 30_000;

    public static void main(String[] args) {
        runOnce("warmup +", StringConcatLoopBenchmark::concatWithPlus);
        runOnce("warmup builder", StringConcatLoopBenchmark::concatWithBuilder);
        runOnce("warmup buffer", StringConcatLoopBenchmark::concatWithBuffer);

        runOnce("String +", StringConcatLoopBenchmark::concatWithPlus);
        runOnce("StringBuilder", StringConcatLoopBenchmark::concatWithBuilder);
        runOnce("StringBuffer", StringConcatLoopBenchmark::concatWithBuffer);
    }

    private static void runOnce(String name, ConcatTask task) {
        long start = System.nanoTime();
        String result = task.run();
        long costMicros = (System.nanoTime() - start) / 1_000;
        System.out.printf("%-14s time=%7d us, length=%d%n", name, costMicros, result.length());
    }

    private static String concatWithPlus() {
        String result = "";
        for (int i = 0; i < COUNT; i++) {
            result += "a";
        }
        return result;
    }

    private static String concatWithBuilder() {
        StringBuilder builder = new StringBuilder(COUNT);
        for (int i = 0; i < COUNT; i++) {
            builder.append("a");
        }
        return builder.toString();
    }

    private static String concatWithBuffer() {
        StringBuffer buffer = new StringBuffer(COUNT);
        for (int i = 0; i < COUNT; i++) {
            buffer.append("a");
        }
        return buffer.toString();
    }

    @FunctionalInterface
    private interface ConcatTask {
        String run();
    }
}
```

一次运行结果示例：

```text
warmup +       time=  87683 us, length=30000
warmup builder time=   2192 us, length=30000
warmup buffer  time=   1773 us, length=30000
String +       time=  60251 us, length=30000
StringBuilder  time=   1113 us, length=30000
StringBuffer   time=   1318 us, length=30000
```

这个例子只用于观察趋势，不能替代严谨的基准测试。JVM JIT 编译、GC、机器负载都会影响具体时间；如果要做正式性能评估，应使用 JMH 这类基准测试工具。

从时间和内存角度，可以这样比较：

| 写法 | 时间特点 | 内存特点 | 适用场景 |
| --- | --- | --- | --- |
| `result += item` | 循环次数越多越慢，因为每轮都要基于旧字符串生成新字符串 | 会产生大量中间 `String` 对象和字符数据拷贝，GC 压力大 | 少量、简单、非循环拼接 |
| `StringBuilder` | 单线程下通常最快，没有同步开销 | 复用内部缓冲区，配合初始容量可减少扩容和拷贝 | 方法内部、单线程循环拼接 |
| `StringBuffer` | 比 `StringBuilder` 多同步开销，单线程下通常略慢 | 同样复用内部缓冲区，但同步方法有额外成本 | 多线程共享同一个可变拼接对象 |

这里的 `new StringBuilder(COUNT)` 和 `new StringBuffer(COUNT)` 都预先指定了容量。预估容量的好处是减少缓冲区扩容次数；如果不指定容量，内容增长到超过当前容量时，内部数组需要扩容并复制旧内容。

实际开发中可以按下面规则选择：

- 循环内大量拼接：优先使用 `StringBuilder`。
- 多线程共享同一个可变拼接对象：使用 `StringBuffer` 或外部锁。
- SQL、日志、响应内容等能预估长度的拼接：给 `StringBuilder` 设置合理初始容量。
- 少量固定片段拼接：直接使用 `+`，代码更清晰，编译器也会做优化。
