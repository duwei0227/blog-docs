---

title: Python模块与包
published: true
layout: post
date: 2026-01-08 19:00:00
permalink: /python/module_pack.html
categories: [Python]
---

## 模块

**什么是模块？**

模块是包含 Python 定义和语句的文件，其文件名是模块名加后缀名 `.py` ，简而言之，在Python中，一个`.py`文件就是一个模块。在模块内部，通过全局变量 `__name__` 可以获取模块名（即字符串）。



**为什么需要模块？**

​     在不引入模块的情况下，编写一个功能简单的程序，代码行数在千行以内时，看起来好像也不是什么大的问题；然而当我们在编写一个非常大的程序时，程序代码量可能上万行甚至更多，在如此大的一个文件中进行功能的完善和维护，可以想象是如何的困难。

​    基于此，Python引入了模块，可以将功能逻辑上相同的代码放在一个独立的文件中。这样，每个独立文件可以表示一部分功能，在进行功能的维护时，只需要修改这一个独立文件即可，不需要大海捞针。



### 模块的导入

我们使用独立的文件定义好模块，接下来就需要在上层引入模块，执行模块内部定义的逻辑。

**语法：**

```python
import 模块名
import 模块名 as 别名
from 模块名 import 函数或其他
from 模块名 import *
```



* `as`是用来声明导入模块的别名，一个情况是可以将模块进行重命名，另一个方面是：如果在当前模块中导入了两个不同的模块，而这两个模块名称可能相同，为了避免命名冲突，使用`as`进行重命名
* `*`会导入所有不以下划线（`_`）开头的名称。大多数情况下，不要用这个功能，这种方式向解释器导入了一批未知的名称，可能会覆盖已经定义的名称。



**示例：**

![image-20260108131616923](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20260108131616923.png)





定义 `mymath.py`模块

```python
# add
def add(a, b):
    return a + b

# subtract
def subtract(a, b):
    return a - b

# multiply
def multiply(a, b):
    return a * b

# divide
def divide(a, b):
    if b == 0:
        raise ValueError("Cannot divide by zero.")
    return a / b
```



1、在 `test.py`中使用`mymath`模块

```python
import mymath

print("Addition of 5 and 3:", mymath.add(5, 3))
print("Subtraction of 5 and 3:", mymath.subtract(5, 3))
print("Multiplication of 5 and 3:", mymath.multiply(5, 3))
print("Division of 5 and 3:", mymath.divide(5, 3))

# 输出
Addition of 5 and 3: 8
Subtraction of 5 and 3: 2
Multiplication of 5 and 3: 15
Division of 5 and 3: 1.6666666666666667
```



2、使用别名：

```python
import mymath as my

print("Addition of 5 and 3:", my.add(5, 3))
print("Subtraction of 5 and 3:", my.subtract(5, 3))
print("Multiplication of 5 and 3:", my.multiply(5, 3))
print("Division of 5 and 3:", my.divide(5, 3))
```



3、导入具体的函数:

```python
from mymath import add, divide

print("Addition of 5 and 3:", add(5, 3))
print("Subtraction of 5 and 3:", subtract(5, 3))
print("Multiplication of 5 and 3:",multiply(5, 3))
print("Division of 5 and 3:", divide(5, 3))
```

由于已经使用`import`直接导入了模块内部具体的函数，所以在调用的时候，就不需要在函数名前增加模块名。

另外由于我们只导入了`add`和`divide`函数，所以在执行`substract`时会报错：`NameError: name 'subtract' is not defined`



4、使用`*`导入全部

```python
from mymath import *

print("Addition of 5 and 3:", add(5, 3))
print("Subtraction of 5 and 3:", subtract(5, 3))
print("Multiplication of 5 and 3:",multiply(5, 3))
print("Division of 5 and 3:", divide(5, 3))
```

`*`会把`mymath`模块下所有不以`_`开头的内容都导入，函数调用前不需要在添加模块名





## 包

包是在模块的基础上，将模块在按照逻辑分类，在导入模块的时候，包名称也作为导入路径的一部分。定义包的时候，需要在包目录下新建一个`__init__.py`文件，文件内容可以为空。

假设要为统一处理声音文件与声音数据设计一个模块集（“包”）。声音文件的格式很多（通常以扩展名来识别，例如：`.wav`，`.aiff`，`.au`），因此，为了不同文件格式之间的转换，需要创建和维护一个不断增长的模块集合。为了实现对声音数据的不同处理（例如，混声、添加回声、均衡器功能、创造人工立体声效果），还要编写无穷无尽的模块流。下面这个分级文件树展示了这个包的架构：

```
sound/                          最高层级的包
      __init__.py               初始化 sound 包
      song.py
      formats/                  用于文件格式转换的子包
              __init__.py
              wavread.py
              wavwrite.py
              aiffread.py
              aiffwrite.py
              auread.py
              auwrite.py
              ...
      effects/                  用于音效的子包
              __init__.py
              echo.py
              surround.py
              reverse.py
              ...
      filters/                  用于过滤器的子包
              __init__.py
              equalizer.py
              vocoder.py
              karaoke.py
              ...
```



### 包的导入

**语法：**

```python
import 父.子.模块
from 父.子 import 模块1,模块2
from 父.子 import *

# 相对导入
from . import 模块名 # 使用当前模块所在路径查找 导入模块
from .. import 模块名 # 使用当前模块的直接父模块
from ..同级包名 import 模块名  #引入同级包下的模块
```

* `*` 的使用需要在包的`__init__.py`文件中通过`__all__` 声明需要导出的模块
* 使用相对路径引入的时候，如果使用`python`运行文件的时候，如果模块`A`使用相对路径引入了其他模块，不能直接运行`python a.py`，否则会报错：`ImportError: attempted relative import with no known parent package`





**举例：**

![image-20260108191529667](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20260108191529667.png)



1、直接导入模块：

使用 `import`直接导入全路径模块时，在使用的时候也需要完整的模块路径，较为繁琐

```python
import sound.effects.echo

print(sound.effects.echo.echo_str("Hello"))
```



2、使用`from 包路径 import 模块`方式：

使用此种方式，在使用的时候可以直接使用最后的模块名，不需要前边的包路径，**推荐采用**

```python
from sound.effects import echo

print(echo.echo_str("Hello"))  # Expected output: "Hello Hello"
```



3、使用`from 包路径 import *`方式：

```python
# 在 sound.effercts.__init__py文件中添加 __all__ 声明导出 errercts包下的 echo 模块
__all__ = ['echo']

from sound.effects import *

print(echo.echo_str("Hello"))
print(reverse.reverse_str("Hello"))

# 由于没有在 __all__ 中声明导出 reverse，所以在执行 reverse.reverse_str时会报错
Hello Hello
Traceback (most recent call last):
  File "/test.py", line 4, in <module>
    print(reverse.reverse_str("Hello"))
          ^^^^^^^
NameError: name 'reverse' is not defined. Did you mean: 'reversed'?
```



4、使用相对路径 `.`：

在 `reverse.py`文件中通过相对路径引入 `echo`模块

```python
from . import echo

def reverse_str(s):
    """Reverses the given string s."""
    return s[::-1]

def call_echo():
    echo.echo_str("Test")
```

顶层 `test.py`中调用 `reverse`模块的`call_echo`函数

```python
from sound.effects import reverse

reverse.call_echo()

# 输出
Echoing string: Test
```



**注意实现：** 如果在effects目录下直接使用`python reverse.py`调用`echo`模块的函数，会发生错误：`ImportError: attempted relative import with no known parent package`



5、使用相对路径 `..`

在`wavread.py` 文件中通过相对引用，引入父包`sound`下的`song`模块

```python
from .. import song

def read_wav(filename):
    print(f"Reading WAV file: {filename}")

def sing_a_song():
    song.sing()
```

顶层`test.py`中引入`wavread`模块

```python
from sound.formats import wavread

wavread.sing_a_song()

# 输出
La la la...
```



6、使用相对路径引入同级包下的模块 `..同级包名` 

在`wavread.py` 文件中通过相对引用，引入当前模块所属包 `formats`的同级包`effects`下的`echo`模块

```python
from ..effects import echo

def read_wav(filename):
    print(f"Reading WAV file: {filename}")

def call_echo():
    echo.echo_str("Calling from wavread")
```

顶层`test.py`中引入`wavread`模块

```python
from sound.formats import wavread

wavread.call_echo()

# 输出
Echoing string: Calling from wavread
```

