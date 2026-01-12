---
title: Python类
published: true
layout: post
date: 2026-01-09 16:00:00
permalink: /python/class.html
categories: [Python]
---



## 一、概念

**什么是类？**

*类*是对现实世界事物的一种抽象，这些事物拥有相同的数据属性，相同的行为，只是在个体表达上具有独立的数据。例如：我们可以将现实世界的小狗抽象为Python中的类，它们都拥有年龄，毛色等属性数据，吃、跑等相同的行为，只是不同品种的小狗拥有不同的属性数据。



**为什么需要类？**

我们学习过函数、模块和包，都是在不同维度对数据或逻辑的一种抽象，实现代码的复用；然而随着程序复杂度增加，数据和处理逻辑变多，代码管理开始变得混乱，**类**让数据和操作这些数据的函数“住到一个地方”—— 同一对象的数据和行为耦合在一起，更好组织代码。 同时，通过类，我们可以让调用方不直接操作属性，属性对外不可见，属性的获取或着修改都必须通过行为函数，达到数据的封装目的。



## 二、类的定义

### 1、基本语法结构

**类的定义：**

```python
class ClassName:
    <语句-1>
    .
    .
    .
    <语句-N>
    
```

**类的实例化：**

```python
变量名 = 类名()
```





**示例：**

```python
class MyClass:
    """一个简单的示例类"""
    i = 12345

    def f(self):
        return 'hello world'
```



**类的实例化使用：**

```python
x = MyClass()
```



### 2、对象实例创建方法 `__new__`

`__new__`是一个特殊的方法，名称前后各有两对下划线，它在对象实例化过程的最前面执行，用于**真正创建一个对象实例**。



**是否需要自定义实现`__new__方法`？**

答：在大多数日常情况下，不需要重写`__new__`，只需要重写`__init__`完成对象初始化即可。



**什么时候需要自定义`__new__`方法？**

答：需要自定义对象的创建过程的时候。



**示例：**

```python
class Demo:
    def __new__(cls, *args, **kwargs):
        print(">>> __new__ called")
        obj = super().__new__(cls)
        return obj

    def __init__(self, val):
        print(">>> __init__ called")
        self.val = val

d = Demo(42)
print("Value:", d.val)

```

输出：

```
>>> __new__ called
>>> __init__ called
Value: 42

```



### 3、初始化方法 `__init__`

`__init__`是一个特殊的方法，名称前后各有两对下划线，它不需要也不应该手动调用，它是由解释器在对象创建时自动执行的。



**用途：**

* 初始化对象属性
* 设置参数默认值，使对象处于有效状态
* 执行其他初始化行为



**基本语法：**

```python
class ClassName:
    def __init__(self, …):
        # 初始化代码

```

* 首个参数为`self`，表示当前方法属于实例，而非`class`
* 后边可以可选的接收多个参数，在构造实例对象时必须传入的值，接受位置参数，默认参数，任意数量参数。



**示例：**

```python
class Point:
    def __init__(self, x=0, y=0):
        self.x = x
        self.y = y

p1 = Point()         # 默认为 (0, 0)
p2 = Point(5, 10)    # 自定义坐标

print(p1.x, p1.y)   # 0 0
print(p2.x, p2.y)   # 5 10

```



### 4、类的属性

**属性（attribute）** 指的是 **与某个对象相关联的数据或特性**。它可以是变量、值，表示这个对象有哪些“状态/特征”。可以通过 **点号语法** (`obj.attribute`) 来访问它，相当于描述这个对象“拥有什么”。



#### 4.1 类属性

定义在类体中 **但不在 `__init__()` 里** 的变量。

- 属于类本身
- 所有该类的实例共享这个属性
- 用于存放所有对象共有的数据



```python
class Dog:
    species = "Canis familiaris"  # 类属性

print(Dog.species)  # 访问类属性

```

所有 `Dog()` 对象默认都有相同的 `species` 属性。



#### 4.2 实例属性

定义在对象实例中，通常在 `__init__()` 内用 `self` 赋值。

- 属于某个对象实例
- 每个实例可以有自己独立的值
- 表示该实例的特定状态

```python
class Dog:
    def __init__(self, name, age):
        self.name = name        # 实例属性
        self.age = age          # 实例属性

d1 = Dog("Buddy", 5)
print(d1.name, d1.age)

```

这里 `name` 和 `age` 是各个对象独立的属性。



##### 4.2.1 `@property`装饰器

`@property`的作用：

* 把一个普通方法变成 属性访问方式
* 可以在读取、设置、删除属性时加入逻辑（如验证，计算等）



>  换句话说，Python 允许你像访问成员变量一样访问方法，但这个方法可以在内部执行任意逻辑，通过 `@property`装饰器，可以对实例属性的访问和设置增加自定义保护逻辑



**基本语法：**

```python
class MyClass:
    @property
    def prop(self):
        return ...
    @prop.setter
    def prop(self, value):
        ...

    @prop.deleter
    def prop(self):
        ...
```



**示例：**

```python
class Person:
    def __init__(self, name, age):
        # 通常把实际存储属性设为带下划线的内部变量
        self._name = name
        self._age = age

    # —— getter：读取属性
    @property
    def name(self):
        return self._name

    # —— setter：设置属性
    @name.setter
    def name(self, value):
        if not isinstance(value, str):
            raise ValueError("名字必须是字符串")
        self._name = value

    # —— deleter：删除属性
    @name.deleter
    def name(self):
        print("删除 name 属性 …")
        del self._name

    @property
    def age(self):
        return self._age

    @age.setter
    def age(self, value):
        if not isinstance(value, int) or value < 0:
            raise ValueError("年龄必须是非负整数")
        
        if value > 120:
            raise ValueError("年龄不应超过120岁")
        self._age = value

    @age.deleter
    def age(self):
        print("删除 age 属性 …")
        del self._age


p = Person("Alice", 30)

# —— 获取（get）
print(p.name)  # Alice
print(p.age)   # 30

# —— 修改（set）
p.name = "Bob" 
p.age = 25
print(p.name, p.age)  # Bob 25

# 修改 age  ，触发 set 验证逻辑
# p.age = 130  # 会抛出 ValueError: 年龄不应超过120岁

# —— 删除（del）
del p.name        # 调用 name.deleter
# print(p.name)   # 访问时如果内部属性被删掉将抛 AttributeError

del p.age         # 调用 age.deleter
# print(p.age)    # 同样会抛出错误，因为内部的 _age 属性被删掉

```



*装饰器后续介绍*



#### 4.3 类属性 vs 实例属性 对比

| 特性       | 类属性                          | 实例属性                           |
| ---------- | ------------------------------- | ---------------------------------- |
| 定义位置   | 类体内部                        | 通常在 `__init__` 中用 `self` 定义 |
| 所属       | 属于类                          | 属于对象实例                       |
| 是否共享   | ✔️ 全部实例共享                  | ❌ 每个对象自己的值                 |
| 访问方式   | `Class.attr` 或 `instance.attr` | `instance.attr`                    |
| 修改作用域 | 修改类属性影响所有实例          | 修改只影响当前实例                 |

**示例：**

```python
class Car:
    # 类属性
    wheels = 4

    def __init__(self, brand, model):
        # 实例属性
        self.brand = brand
        self.model = model

car1 = Car("Toyota", "Camry")
car2 = Car("Honda", "Civic")

print(Car.wheels)        # 4
print(car1.wheels)       # 4（实例访问类属性）
print(car1.brand)        # Toyota
print(car2.model)        # Civic

```



### 5、私有变量和属性

在`python`的`class`中，“私有变量/私有方法“不是语言层面的强制私有，而是通过**命名约定**的方式来实现，告诉外部，我定义的是一个私有的，不要直接引用。



**定义：**

* **单下划线 `_name`**：约定式“内部使用”，*外部还是可以访问到*



**示例：**

```python
class User:
    def __init__(self):
        self._token = "abc123"

    def _refresh_token(self):
        print("refresh token")


u = User()
print(u._token)        # 可以，但不推荐
u._refresh_token()     # 可以，但不推荐

# 输出
abc123
refresh token
```



**推荐使用私有变量+`@property`的方式实现属性在约定上的隐藏，并可以对属性的获取和设置有保护机制**



### 6、方法的定义

#### 6.1 实例方法

类定义中最常见的类方法，它第一个参数是 `self`，表示当前对象实例。必须通过实例对象来调用，能访问对象的属性和方法。

**示例：**

```python
class A:
    def instance_method(self):
        print(self)

```



#### 6.2 类方法

使用装饰器 `@classmethod` 定义，**第一个参数是类本身 `cls`**，表示当前类，方法属于类。

- 不需要创建实例，也可以通过类名调用。
- 可以访问类属性、调用类方法、创建实例（例如工厂方法）。
- 方法的行为是实例无关的，和类紧密相关的



```python
class Person:
    species = "Human"

    def __init__(self, name):
        self.name = name

    @classmethod
    def change_species(cls, new_species):
        cls.species = new_species

    @classmethod
    def from_fullname(cls, fullname):
        # 作为另一种构造方式（工厂方法）
        first, last = fullname.split()
        return cls(first + " " + last)

print(Person.species)  # Human

Person.change_species("Homo sapiens")
print(Person.species)  # Homo sapiens

p = Person.from_fullname("John Doe")
print(p.name)          # John Doe

```



#### 6.3 静态方法

使用装饰器 `@staticmethod` 定义，**不会自动接收 `self` 或 `cls` 参数**，方法不依赖任何类或实例上下文，仅作为分类组织的工具函数，与类逻辑相关但不操作状态。

- 它更像一个归类到类里边的普通函数，**与类状态和实例状态无关**。
- 常用于把一些逻辑组织在类的命名空间下，但这个逻辑不依赖类的数据。



#### 6.4 对比

| 特征             | 实例方法      | 类方法               | 静态方法         |
| ---------------- | ------------- | -------------------- | ---------------- |
| 第一个参数       | `self`        | `cls`                | 无特殊参数       |
| 是否需要实例调用 | 是            | 否                   | 否               |
| 访问实例属性     | ✅             | ❌                    | ❌                |
| 访问类属性       | ✅（via self） | ✅                    | ❌                |
| 常见用途         | 操作对象状态  | 工厂方法、操作类状态 | 辅助工具、算法等 |



**示例：**

```python
class Demo:
    count = 0

    def __init__(self):
        Demo.count += 1

    @classmethod
    def get_count(cls):
        return cls.count     # 访问类属性

    @staticmethod
    def hello(msg):
        return f"Hello {msg}"

d1 = Demo()
d2 = Demo()

print(Demo.get_count())          # 2  
print(Demo.hello("world"))       # Hello world

```





### 7、类的继承

**继承** 是指一个类（子类）从另一个类（父类/基类）**继承属性和方法** 的机制

* 父类（Parent / Base Class / Superclass）定义通用行为和数据，更基础的数据和行为，例如父类定义为汽车，都具备鸣笛行为

* 子类（Child / Derived Class / Subclass）继承这些行为/数据，还能 **扩展或覆盖（override）** 它们，例如汽车子类中，越野车可能具备新的行为，越野能力，同时鸣笛行为也有自己的个性化。



*扩展：* 子类拥有自己的行为或属性

*覆盖：* 从父类继承的行为，子类有不同的表现形式时，可以通过覆写父类的方法达成



**作用：**

* 定义一次方法或属性，在多个子类中都能自动使用，避免重复编码。 
* 建立层次化的代码结构，反映现实世界的层次关系
* 通过扩展或覆盖增加子类的个性化



**语法：**

子类中使用 `super()` 访问父类的属性或方法

```python
class BaseClass:
    # 父类定义

class SubClass(BaseClass):
    # 子类定义

```



**基础示例：**

```python
class Animal:
    def speak(self):
        print("Animal makes a sound")

class Dog(Animal):
    def bark(self):
        print("Dog barks")

d = Dog()
d.speak()  # 从父类继承的方法
d.bark()   # 子类自己的方法

```



**super()示例：**

```python
class Animal:
    def speak(self):
        print("Animal makes a sound")

class Dog(Animal):
    def speak(self):
        super().speak()  # 调用父类的 speak 方法
        print("Dog says: Woof!")

dog = Dog()
dog.speak() # 输出： Animal makes a sound
            #       Dog says: Woof!

```



**覆写override示例：**

```python
class Animal:
    def speak(self):
        print("Animal makes a generic sound")

class Dog(Animal):
    pass
        
class Cat(Animal):
    # 重写父类方法
    def speak(self):
        print("Cat says: Meow!")

a = Animal()
d = Dog()
c = Cat()

a.speak()  # Animal makes a generic sound
# 继承父类的方法
d.speak()  # Dog says: Animal makes a generic sound
c.speak()  # Cat says: Meow!

```

