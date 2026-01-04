---
title: Python安装与入门
published: true
layout: post
date: 2026-01-04 19:00:00
permalink: /python/begin.html
categories: [Python]

---




## 一、安装Python

下载链接： https://www.python.org/downloads/windows/




在下载页面选择 `Stable Releases` 稳定版本，下载文件可以选择`exe`或`zip`包

* Windows installer (64-bit)：`exe`格式的安装包，目前`Windows`系统一般都是`64`位的，选择第一个即可
* Windows embeddable package (64-bit)：`zip` 格式，解压后配置环境变量后使用`Python`解释器，相对于`exe`方式安装，提供的功能相对较少

![image-20251229131643659](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20251229131643659.png)



### 1. exe格式安装（建议选择）

* 运行下载后的`exe`文件，首先会让我们选择需要安装的功能，此处主要选择 `pip`即可，后续就不需要单独安装`pip`模块

  ![image-20251229132832044](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20251229132832044.png)

* 下一步选择`Python`解释器安装目录和其他高级功能，选择创建快捷指令和添加`Python`到环境变量（后续不需要人工配置环境变量）即可

  ![image-20251229133027226](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20251229133027226.png)

* 点击`Install` 安装

* 验证，**采用`exe`的优点在于不用手动配置环境变量和安装`pip`模块**

  ![image-20251229133226623](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20251229133226623.png)



### 2. zip格式安装

* 将下载下来的zip包解压，例如解压到 `D:/python-3.14.2-embed-amd64` 目录，具体路径和命名可以根据个人喜好设置

* 配置环境变量，将上一步的`D:/python-3.14.2-embed-amd64(包含python.exe)`的路径添加到`Path`环境变量上，**添加路径：系统->系统信息->高级系统设置->环境变量->系统变量->Path->新建** 

  ![image-20251229131944926](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20251229131944926.png)

* 检查配置正确性

  打开`cmd`窗口，输入 `python -V` 查看`python`版本，如果显示正确表明安装成功

  ![image-20251229132200244](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20251229132200244.png)



使用`zip`包安装存在的问题：

* 无法使用`pip`安装第三方模块

![image-20251229132345358](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20251229132345358.png)

![image-20251229132351852](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20251229132351852.png)



**通过get-pip.py手动安装pip**

* 获取get-pip.py文件

    ```python
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    ```

* 运行get-pip.py文件安装pip

  ```python
  python get-pip.py
  ```

  

  ![image-20251229132545972](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20251229132545972.png)





## 二、安装编码客户端

`Python`解释器安装好以后，我们开始进入编码阶段，编码不要工具，此处介绍免费的`VS Code`的安装和配置，用于后续的学习。



### 1. 安装 VS Code

访问：https://code.visualstudio.com/download 根据系统选择下载

![image-20251229152859065](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20251229152859065.png)



### 2. 安装Python插件

![image-20251229153320867](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20251229153320867.png)





## 三、Hello World

使用VS Code打开一个目录用于后续代码开发

![image-20251229171859046](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20251229171859046.png)



新建一个 `test.py` 文件并写入以下内容打印`Hello World`

```python
print("Hello World")

# 或 

if __name__ == '__main__':
    print("Hello World")
```



* `Python` 是从上到下解释执行代码
* `__name__`是一个内置变量，表示当前模块的名称，当使用`python xx.py`时，`__name__` 被设置为`__main__`， 当文件作为模块被其他文件引用时，`__name__`被设置为文件名（不含扩展名）















