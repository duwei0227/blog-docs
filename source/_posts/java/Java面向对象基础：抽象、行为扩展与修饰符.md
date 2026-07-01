---
title: Java 面向对象基础：抽象、行为扩展与修饰符
published: true
layout: post
date: 2026-07-01 13:16:00
permalink: /java/java-oop-abstraction-overload-override-modifiers.html
tags:
  - 面向对象
  - 抽象类
  - 接口
  - 重载
  - 重写
  - 修饰符
categories: Java
---

Java 面向对象基础里有几组概念经常被分开记忆：抽象类、接口、重写、重载、访问修饰符、`static`、`final`、`abstract`。如果只背定义，很容易知道每个词的意思，却不知道在项目里为什么要这样写。

本文用一条主线串起来：

```text
抽象能力 -> 扩展行为 -> 控制边界
```

也就是说，先判断对象对外应该暴露什么能力，再决定不同实现之间的行为如何变化，最后用修饰符控制哪些内容可以访问、哪些流程可以扩展、哪些细节必须隐藏。

## 一、从业务场景理解面向对象设计

假设现在要设计一个支付功能。系统里可能有支付宝支付、微信支付、银行卡支付等多种实现。调用方通常不应该关心具体支付渠道，它只需要知道一个对象“能支付”。

这时可以把思考拆成三步：

| 问题 | 对应知识点 | 解决目标 |
| --- | --- | --- |
| 这个对象对外能做什么？ | 接口、抽象类 | 抽象能力和公共流程 |
| 不同对象的行为如何变化？ | 重写、重载 | 实现多态和同名方法扩展 |
| 哪些内容能被外部访问？ | 修饰符 | 控制访问范围和扩展边界 |

这条线比单独记忆概念更接近真实项目里的设计过程。

## 二、抽象能力：接口与抽象类

### 2.1 接口：定义对象能做什么

接口（interface）主要表达一种能力或契约。调用方依赖接口，具体实现类负责完成真实逻辑。

例如支付能力可以抽象成：

```java
interface PayService {
    void pay(String orderId, int amount);
}
```

这段代码没有规定支付宝、微信、银行卡分别怎么支付，只规定了一个事实：实现 `PayService` 的对象必须提供 `pay()` 方法。

接口适合以下场景：

| 场景 | 示例 |
| --- | --- |
| 定义能力 | `PayService`、`Runnable`、`Comparable` |
| 屏蔽具体实现 | 业务代码依赖 `PayService`，不直接依赖 `AliPayService` |
| 支持多实现扩展 | 新增 `BankCardPayService` 时，不影响调用方 |
| 多能力组合 | 一个类可以同时实现 `Serializable`、`Comparable` 等多个接口 |

接口强调的是“能做什么”。它不关心对象属于哪一类，只关心对象是否具备某种能力。

### 2.2 抽象类：沉淀公共状态和公共流程

抽象类（abstract class）适合表达一组对象的共同父类。它既可以定义抽象方法，也可以提供普通方法、字段和构造方法。

在支付场景中，不同支付方式可能都有共同流程：

1. 校验订单号和金额。
2. 执行具体支付。
3. 记录支付日志。

	这类公共流程适合放到抽象类里：

```java
interface PayService {
    void pay(String orderId, int amount);
}

abstract class AbstractPayService implements PayService {
    @Override
    public final void pay(String orderId, int amount) {
        check(orderId, amount);
        doPay(orderId, amount);
        recordLog(orderId);
    }

    protected void check(String orderId, int amount) {
        if (orderId == null || orderId.isBlank()) {
            throw new IllegalArgumentException("订单号不能为空");
        }
        if (amount <= 0) {
            throw new IllegalArgumentException("金额必须大于 0");
        }
        System.out.println("校验订单：" + orderId);
    }

    protected void recordLog(String orderId) {
        System.out.println("记录支付日志：" + orderId);
    }

    protected abstract void doPay(String orderId, int amount);
}

class AliPayService extends AbstractPayService {
    @Override
    protected void doPay(String orderId, int amount) {
        System.out.println("支付宝支付：" + amount + " 元");
    }
}

class WeChatPayService extends AbstractPayService {
    @Override
    protected void doPay(String orderId, int amount) {
        System.out.println("微信支付：" + amount + " 元");
    }
}

public class PayDemo {
    public static void main(String[] args) {
        PayService payService = new AliPayService();
        payService.pay("ORDER-1001", 99);
    }
}
```

运行结果：

```text
校验订单：ORDER-1001
支付宝支付：99 元
记录支付日志：ORDER-1001
```

这个例子里有几个关键点：

- `PayService` 定义对外契约，调用方只依赖接口。
- `AbstractPayService` 固定支付主流程，复用校验和日志逻辑。
- `doPay()` 是抽象方法，强制子类实现具体支付渠道。
- `pay()` 使用 `final` 修饰，表示子类不能改动整体流程顺序。

这种写法常见于模板方法模式：父类定义流程骨架，子类只补充变化点。

### 2.3 抽象类和接口的核心区别

| 对比项 | 接口 | 抽象类 |
| --- | --- | --- |
| 设计含义 | 定义能力、规范、契约 | 定义共同父类和公共流程 |
| 关系 | can-do，能做什么 | is-a，是什么 |
| 继承限制 | 一个类可以实现多个接口 | 一个类只能继承一个类 |
| 字段 | 通常只放常量 | 可以有实例字段 |
| 构造方法 | 没有构造方法 | 可以有构造方法 |
| 方法实现 | 可以有抽象方法、默认方法、静态方法 | 可以有抽象方法和普通方法 |
| 适合场景 | 解耦调用方和实现方 | 复用公共状态、公共步骤、模板流程 |

> 注意：Java 8 之后接口可以有 `default` 方法和 `static` 方法，Java 9 之后接口还可以有 `private` 辅助方法。但接口的主要定位仍然是能力契约，不适合承载大量状态和复杂流程。

### 2.4 实际项目中如何选择

一般可以按下面规则选择：

| 需求 | 推荐选择 | 原因 |
| --- | --- | --- |
| 只定义对外能力 | 接口 | 调用方依赖契约，方便替换实现 |
| 多个类需要具备同一种能力 | 接口 | Java 支持多接口实现 |
| 多个实现有共同字段和流程 | 抽象类 | 可以复用状态和普通方法 |
| 既要对外解耦，又要复用公共逻辑 | 接口 + 抽象类 | 接口负责契约，抽象类负责公共骨架 |
| 只是复用一两个无状态工具方法 | 工具类或组合 | 不必为了少量复用强行建立继承层次 |

实践中常见结构是：

```text
PayService              对外接口
AbstractPayService      内部公共模板
AliPayService           具体实现
WeChatPayService        具体实现
```

调用方依赖 `PayService`，公共流程放在 `AbstractPayService`，具体渠道类只实现差异部分。

## 三、扩展行为：重写与重载

抽象能力解决的是“对象能做什么”。接下来要解决的是“行为如何变化”。

Java 里容易混淆的两个概念是重写和重载：

- 重写（override）：子类重新实现父类已有方法。
- 重载（overload）：同名方法通过不同参数提供多个版本。

### 3.1 重写：子类改变父类行为

重写发生在继承关系中。子类对父类已有方法提供新的实现，运行时根据对象的真实类型决定调用哪个方法。

```java
class Animal {
    void speak() {
        System.out.println("动物发出声音");
    }
}

class Dog extends Animal {
    @Override
    void speak() {
        System.out.println("狗叫");
    }
}

public class OverrideDemo {
    public static void main(String[] args) {
        Animal animal = new Dog();
        animal.speak();
    }
}
```

运行结果：

```text
狗叫
```

虽然变量声明类型是 `Animal`，但实际对象是 `Dog`，所以运行时调用的是 `Dog` 的 `speak()` 方法。这就是运行时多态。

重写需要满足这些规则：

| 规则 | 说明 |
| --- | --- |
| 方法名 | 必须相同 |
| 参数列表 | 必须相同 |
| 返回值 | 相同，或返回父类返回类型的子类型 |
| 访问权限 | 不能比父类方法更严格 |
| 异常 | 不能抛出比父类方法更宽泛的受检异常 |
| 静态方法 | 静态方法不能被真正重写，只能被隐藏 |

建议使用 `@Override` 注解。它能让编译器帮你检查是否真的发生了重写，避免因为参数写错导致变成重载。

### 3.2 重载：同名方法支持不同参数

重载通常发生在同一个类中。它的作用是让同一个动作支持不同参数形式。

```java
class OrderService {
    void createOrder(String productId) {
        System.out.println("创建普通订单：" + productId);
    }

    void createOrder(String productId, int count) {
        System.out.println("创建多件商品订单：" + productId + "，数量：" + count);
    }

    void createOrder(String productId, int count, String couponId) {
        System.out.println("创建优惠订单：" + productId + "，数量：" + count + "，优惠券：" + couponId);
    }
}

public class OverloadDemo {
    public static void main(String[] args) {
        OrderService orderService = new OrderService();
        orderService.createOrder("BOOK-1");
        orderService.createOrder("BOOK-1", 2);
        orderService.createOrder("BOOK-1", 2, "COUPON-8");
    }
}
```

运行结果：

```text
创建普通订单：BOOK-1
创建多件商品订单：BOOK-1，数量：2
创建优惠订单：BOOK-1，数量：2，优惠券：COUPON-8
```

编译器会根据调用时传入的参数个数、类型和顺序，在编译期选择具体调用哪个方法。

重载判断依据如下：

| 能否构成重载 | 示例 | 说明 |
| --- | --- | --- |
| 参数个数不同 | `add(int, int)` 和 `add(int, int, int)` | 可以 |
| 参数类型不同 | `add(int, int)` 和 `add(double, double)` | 可以 |
| 参数顺序不同 | `save(String, int)` 和 `save(int, String)` | 可以，但可读性要谨慎 |
| 只有返回值不同 | `int get()` 和 `String get()` | 不可以 |
| 只有参数名不同 | `save(String name)` 和 `save(String title)` | 不可以 |

> 注意：重载不应该滥用。如果多个同名方法的语义差别很大，使用不同方法名反而更清楚。

### 3.3 重写和重载的区别

| 对比项 | 重写 | 重载 |
| --- | --- | --- |
| 英文 | override | overload |
| 发生位置 | 父类和子类之间 | 同一个类中，或继承体系内 |
| 方法名 | 相同 | 相同 |
| 参数列表 | 必须相同 | 必须不同 |
| 返回值 | 相同或协变返回 | 可不同，但不能只靠返回值区分 |
| 决定时机 | 运行时根据真实对象决定 | 编译期根据参数决定 |
| 主要目的 | 改变父类行为 | 提供同一动作的多个参数版本 |

一句话区分：

```text
重写看对象是谁，重载看参数是什么。
```

## 四、控制边界：Java 修饰符

当能力和行为都设计好以后，还需要控制边界：什么可以暴露给调用方，什么只能给子类使用，什么必须隐藏在类内部，什么流程不允许被修改。

Java 修饰符可以分为两类：

- 访问控制修饰符：控制谁能访问。
- 非访问修饰符：控制类、方法、变量具有什么特性。

### 4.1 访问控制修饰符

访问控制修饰符包括 `public`、`protected`、默认访问权限、`private`。

| 修饰符 | 同类 | 同包 | 不同包子类 | 其他包 |
| --- | --- | --- | --- | --- |
| `public` | 可以 | 可以 | 可以 | 可以 |
| `protected` | 可以 | 可以 | 可以 | 不可以 |
| 默认，不写 | 可以 | 可以 | 不可以 | 不可以 |
| `private` | 可以 | 不可以 | 不可以 | 不可以 |

在项目里可以这样理解：

| 修饰符 | 设计含义 | 常见用法 |
| --- | --- | --- |
| `public` | 对外公开的 API | 接口方法、控制器入口、公共服务方法 |
| `protected` | 留给子类扩展 | 抽象类中的模板步骤、钩子方法 |
| 默认访问权限 | 包内部协作 | 同一包内的辅助类、内部实现 |
| `private` | 隐藏实现细节 | 字段、内部校验方法、私有工具方法 |

访问控制的核心不是“能不能访问”这么简单，而是代码边界设计。公开得越多，未来修改成本越高；隐藏得越好，内部实现越容易调整。

### 4.2 `static`：属于类本身

`static` 修饰的成员属于类，不属于某个对象实例。

常见用法包括：

| 用法 | 示例 | 说明 |
| --- | --- | --- |
| 静态变量 | `static int count` | 所有对象共享一份 |
| 静态方法 | `Math.max(a, b)` | 不依赖对象状态 |
| 静态常量 | `public static final String APP_NAME` | 全局固定值 |
| 静态内部类 | `Map.Entry` | 与外部类实例无关 |

适合用 `static` 的方法通常不依赖对象字段。如果方法需要访问大量实例状态，就不应该强行写成静态方法。

### 4.3 `final`：禁止再次改变

`final` 在不同位置含义不同：

| 修饰位置 | 含义 |
| --- | --- |
| 类 | 不能被继承 |
| 方法 | 不能被子类重写 |
| 变量 | 只能赋值一次 |

例如前面的支付示例中：

```java
public final void pay(String orderId, int amount) {
    check(orderId, amount);
    doPay(orderId, amount);
    recordLog(orderId);
}
```

`pay()` 被设计成模板流程入口。如果允许子类随意重写，子类可能跳过参数校验或日志记录。使用 `final` 可以把“流程顺序不能变”这个设计意图写进代码里。

> 注意：`final` 修饰引用变量时，表示引用不能再指向其他对象，不代表对象内部状态一定不可变。

### 4.4 `abstract`：声明必须由子类完成

`abstract` 可以修饰类和方法：

| 修饰位置 | 含义 |
| --- | --- |
| 抽象类 | 不能直接创建对象，可以包含抽象方法和普通方法 |
| 抽象方法 | 只有方法声明，没有方法体，必须由具体子类实现 |

抽象方法适合表达“父类知道有这个步骤，但不知道每个子类具体怎么做”。

```java
protected abstract void doPay(String orderId, int amount);
```

父类知道支付流程中一定有“执行支付”这一步，但支付宝、微信、银行卡的实现完全不同，所以把这个变化点留给子类。

### 4.5 `synchronized`、`volatile`、`transient`、`native`

除了常见的 `public`、`private`、`static`、`final`、`abstract`，Java 还有一些用于特定场景的修饰符。

| 修饰符 | 作用 | 常见场景 |
| --- | --- | --- |
| `synchronized` | 对方法或代码块加锁 | 多线程下保护共享状态 |
| `volatile` | 保证变量修改对其他线程可见 | 状态标记、停止标志 |
| `transient` | 序列化时忽略字段 | 密码、临时缓存、派生字段 |
| `native` | 方法由本地代码实现 | JVM、系统调用、JNI 集成 |

这些修饰符通常不用于日常实体类字段的简单封装，而是服务于并发、序列化或底层集成。

## 五、把修饰符放回设计里理解

下面这个例子把接口、抽象类、重写和修饰符放在一起：

```java
interface ReportExporter {
    void export(String reportId);
}

abstract class AbstractReportExporter implements ReportExporter {
    private static final String SYSTEM_NAME = "ReportCenter";

    @Override
    public final void export(String reportId) {
        validate(reportId);
        doExport(reportId);
        System.out.println("来源系统：" + SYSTEM_NAME);
    }

    protected abstract void doExport(String reportId);

    private void validate(String reportId) {
        if (reportId == null || reportId.isBlank()) {
            throw new IllegalArgumentException("报表 ID 不能为空");
        }
        System.out.println("校验报表：" + reportId);
    }
}

class PdfReportExporter extends AbstractReportExporter {
    @Override
    protected void doExport(String reportId) {
        System.out.println("导出 PDF 报表：" + reportId);
    }
}

public class ModifierDemo {
    public static void main(String[] args) {
        ReportExporter exporter = new PdfReportExporter();
        exporter.export("R-2026-07");
    }
}
```

运行结果：

```text
校验报表：R-2026-07
导出 PDF 报表：R-2026-07
来源系统：ReportCenter
```

这段代码的设计意图如下：

| 代码 | 设计含义 |
| --- | --- |
| `interface ReportExporter` | 对外只暴露“导出报表”能力 |
| `abstract class AbstractReportExporter` | 抽取公共导出流程 |
| `public final void export()` | 对外公开入口，但不允许子类改流程 |
| `private void validate()` | 校验逻辑只属于父类内部实现 |
| `protected abstract void doExport()` | 子类必须实现具体导出方式 |
| `private static final String SYSTEM_NAME` | 类级别常量，不暴露给外部修改 |
| `@Override` | 明确表示子类正在重写父类方法 |

这样看，修饰符不是零散语法，而是在表达设计边界：

- 哪些能力对外公开。
- 哪些步骤允许子类扩展。
- 哪些实现细节必须隐藏。
- 哪些流程不允许被重写。

## 六、常见错误与推荐做法

### 6.1 把接口当成工具方法集合

接口应该表达能力或契约，不应该随意堆放无关的静态工具方法。如果只是字符串处理、日期转换、金额格式化，更适合使用普通工具类。

### 6.2 为了复用代码滥用继承

抽象类会建立父子关系。如果两个类只是碰巧有几行相同代码，但业务含义不是同一类对象，不一定适合抽象父类。可以优先考虑组合、委托或工具方法。

### 6.3 重载方法参数过多

重载能减少方法名数量，但参数组合太多时，可读性会下降。例如：

```java
createOrder(String productId, int count, String couponId, boolean usePoint, String addressId)
```

这类方法可以考虑使用请求对象：

```java
class CreateOrderRequest {
    private String productId;
    private int count;
    private String couponId;
    private boolean usePoint;
    private String addressId;
}
```

参数对象能让字段含义更清楚，也方便后续扩展。

### 6.4 忘记使用 `@Override`

如果本来想重写父类方法，但参数写错，没有 `@Override` 时可能变成一个新的重载方法。建议所有重写方法都加 `@Override`。

### 6.5 过度使用 `public`

`public` 意味着对外承诺。一个方法一旦被外部大量调用，后续修改签名、调整行为、删除方法都会更困难。除非确实需要对外暴露，否则优先收窄访问范围。

## 七、总结

可以用下面这句话总结本文：

```text
接口和抽象类负责抽象能力，重写和重载负责组织行为变化，修饰符负责控制访问范围和扩展边界。
```

再具体一点：

| 知识点 | 解决的问题 |
| --- | --- |
| 接口 | 定义对象能做什么 |
| 抽象类 | 复用共同状态、公共逻辑和模板流程 |
| 重写 | 子类如何改变父类行为 |
| 重载 | 同一个动作如何支持不同参数 |
| 访问修饰符 | 谁能访问类、方法和字段 |
| `static` | 哪些成员属于类本身 |
| `final` | 哪些内容不能再改变或重写 |
| `abstract` | 哪些行为必须交给子类完成 |

实际项目中建议优先面向接口编程，需要复用公共流程时再引入抽象类；重写用于实现多态，重载用于简化同一语义下的多参数调用；修饰符则用来把设计意图明确地写进代码边界里。
