---
title: 自定义Jmeter插件--实现Java Request
published: true
layout: post
date: 2026-02-03 19:00:00
permalink: /java/jmeter_plugin.html
categories: [Java]
---



##  一、maven配置

### 1、添加ApacheJMeter_java依赖

`ApacheJMeter_java`是我们实现自定义`Java Request`的核心且唯一依赖。

```xml
<dependency>
  <groupId>org.apache.jmeter</groupId>
  <artifactId>ApacheJMeter_java</artifactId>
  <version>5.6.3</version>
  <scope>provided</scope>
</dependency>
```



### 2、添加maven-compiler-plugin构建jar包

我们需要将代码打包成一个`jar`用于`Jmeter`加载插件，`jar`的生成需要配置`maven build`

```xml
<build>
    <plugins>
      <!-- maven-compiler-plugin -->
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <configuration>
          <source>1.8</source>
          <target>1.8</target>
          <encoding>UTF-8</encoding>
        </configuration>
      </plugin>
    </plugins>   
</build>
```

*默认生成的jar包名称为 `${artifactId}-${version}`，可以通过指定 `finalName`自定义`jar`包名称*

```xml
<build>
	<finalName>xxxx</finalName>
</build>
```



## 二、自定义实现类

完成自定义`Java Request`插件的第二步就是实现`JavaSamplerClient`接口或继承`AbstractJavaSamplerClient`类。

`AbstractJavaSamplerClient`对`JavaSamplerClient`提供的方法进行了一些默认实现，除必须自定义`runTest`以外，其他方法可以按需实现，所以建议通过继承来实现自定义逻辑。



###  `JavaSamplerClient`核心方法

#### 1、getDefaultParameters

用于定义插件在 GUI 界面上显示的**参数列表**及其**默认值**，通过此方法可以确保用户能在界面直观的看到自定义插件所需要的参数。

示例：

```java
public Arguments getDefaultParameters() {
    Arguments params = new Arguments();
    params.addArgument("username", null);
    params.addArgument("password", null);
    return params;
}
```



#### 2、setupTest(JavaSamplerContext context)

用于执行一些初始化操作，每个测试线程启动时执行一次。（单独的一个`Java Request`是一个独立的线程，使用 `While` 或 `Loop` 组建重复执行时，`sestupTest`只执行一次）。

**应用场景**：

- 读取一次性配置参数。
- 建立数据库连接或实例化 `OkHttpClient`。
- 预加载测试数据到内存。



#### 3、runTest(JavaSamplerContext context)：SampleResult

自定义插件的核心，所有的逻辑操作都放在该方法中。

**线程池或其他只需要初始化一次的不应该放在`runTest`方法中，循环多次调用时，`runTest`也会执行多次**

* `JavaSamplerContext`：入参，用于获取界面上用户填写的实时参数值（循环执行过程中，如果入参会动态变化，就应该在此时获取实际值）
* `SampleResult`：用于返回执行内容，执行结果（正确或错误），响应码以及时间等属性信息，信息会展示在查看结果树的`Sampler result`中



**`SampleResult`主要方法：**

| **分类**     | **方法名**                        | **功能说明**                 | **常见参数值 / 示例**              | **对应 JMeter 界面位置**       |
| ------------ | --------------------------------- | ---------------------------- | ---------------------------------- | ------------------------------ |
| **状态标识** | `setSuccessful(boolean)`          | **核心**：标记请求成功或失败 | `true` (绿), `false` (红)          | 结果列表颜色 & 状态图标        |
|              | `setResponseCode(String)`         | 设置响应状态码               | `"200"`, `"404"`, `"500"`          | 取样器结果 -> Response code    |
|              | `setResponseMessage(String)`      | 设置响应描述信息             | `"OK"`, `"Not Found"`, `"Timeout"` | 取样器结果 -> Response message |
|              | `setSampleLabel(String)`          | 设置该次请求的显示名称       | `"用户登录接口"`, `${name}`        | 结果树左侧列表项名称           |
| **计时统计** | `sampleStart()`                   | **开启计时**：记录请求起点   | 无                                 | 影响 "Load Time" 起算点        |
|              | `sampleEnd()`                     | **结束计时**：记录请求终点   | 无                                 | 影响 "Load Time" 计算结果      |
|              | `setConnectTime(long)`            | 设置连接建立耗时             | 单位：毫秒 (ms)                    | 取样器结果 -> Connect Time     |
| **内容填充** | `setResponseData(String, String)` | 设置响应体及编码             | `jsonString`, `"UTF-8"`            | **响应数据** 选项卡内容        |
|              | `setSamplerData(String)`          | 设置请求详情回显             | `"URL: http://...\nBody: ..."`     | **请求** 选项卡内容            |
|              | `setDataType(String)`             | 设置数据展现格式             | `SampleResult.TEXT`                | 决定结果树的渲染/搜索方式      |
|              | `setContentType(String)`          | 设置内容 MIME 类型           | `"application/json"`               | 响应数据 -> 自动高亮模式       |
|              | `setRequestHeaders(String)`       | 设置发送的请求头明细         | `"Auth: Bearer xxx"`               | 请求 -> Request Headers        |
|              | `setResponseHeaders(String)`      | 设置接收的响应头明细         | `"Set-Cookie: abc..."`             | 取样器结果 -> Response headers |



#### 4、teardownTest(JavaSamplerContext context)

是`setupTest`对等操作，用于资源的释放清理。

**应用场景**：

- 关闭网络连接池。
- 关闭文件流或数据库连接。
- 输出自定义的统计日志。



### **示例代码：**

```java
package cn.probiecoder;

import org.apache.jmeter.config.Arguments;
import org.apache.jmeter.protocol.java.sampler.JavaSamplerClient;
import org.apache.jmeter.protocol.java.sampler.JavaSamplerContext;
import org.apache.jmeter.samplers.SampleResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class JmeterPluginSampler implements JavaSamplerClient {
    private static final Logger LOGGER = LoggerFactory.getLogger(JmeterPluginSampler.class);

    private String username;
    private String password;

    @Override
    public Arguments getDefaultParameters() {
        Arguments params = new Arguments();
        params.addArgument("username", null);
        params.addArgument("password", null);
        return params;
    }

    @Override
    public SampleResult runTest(JavaSamplerContext context) {
        SampleResult result = new SampleResult();
        result.sampleStart();

        LOGGER.info("===========================");

        LOGGER.info(username);
        LOGGER.info(password);
        LOGGER.info("===========================");

        result.setSampleLabel("JmeterPluginSampler");
        result.setSuccessful(true);
        result.setResponseMessage("OK");
        result.setResponseCodeOK();
        result.setDataType(SampleResult.TEXT);
        result.setResponseData("Hello World!".getBytes());
        result.sampleEnd();
        return result;
    }

    @Override
    public void setupTest(JavaSamplerContext context) {
        LOGGER.info("===========================");
        LOGGER.info("Starting Jmeter Plugin Sampler");
        this.username = context.getParameter("username");
        LOGGER.info("Username: " + username);
        this.password = context.getParameter("password");
        LOGGER.info("===========================");

    }

    @Override
    public void teardownTest(JavaSamplerContext context) {
        LOGGER.info("===========================");
        LOGGER.info("Finished Jmeter Plugin Sampler");
        LOGGER.info("===========================");
    }

}

```



## 三、打包部署Jmeter

**1、打包`jar`**

```xml
mvn clean package
```

使用`mvn`打包为`jar`包

**2、部署Jmeter**

将上一步产生的`jar`拷贝到`Jmeter`的 `lib/ext` 目录下，并重启`Jmeter`用于加载

**3、使用**

创建好线程组以后，选择`Sampler -> Java Request`；选择注册的自定义类，并补充插件所需要的参数值

![image-20260205001222615](https://raw.githubusercontent.com/duwei0227/picbed/main/blogs/image-20260205001222615.png)



使用查看结果树可以查看自定义的`Java Request`的请求返回信息

