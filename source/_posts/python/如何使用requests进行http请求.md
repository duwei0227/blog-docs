---
title: 如何使用requests进行HTTP请求
date: 2026-03-18 16:50:00
tags:
  - Python
  - HTTP
  - requests
  - 网络编程
categories:
  - Python
---

Requests是Python中最流行的HTTP客户端库，以其简洁优雅的API设计而闻名。它简化了HTTP请求的复杂性，让开发者能够专注于业务逻辑而不是网络细节。

## 安装

### 使用pip安装

```bash
pip install requests
```

### 验证安装

```python
import requests
print(requests.__version__)
```

## 快速入门

### 发送GET请求

**语法说明：**
`requests.get(url, params=None, **kwargs)` 发送GET请求到指定URL。

**参数说明：**
- `url`: 请求的目标URL（字符串）
- `params`: URL查询参数（字典或字节序列）
- `**kwargs`: 其他可选参数，如headers、timeout等

```python
import requests

# 最基本的GET请求
response = requests.get('https://httpbin.org/get')
print(f"状态码: {response.status_code}")  # 200
print("响应内容:")
print(response.json())       # 查看响应内容
```

### 发送POST请求

**语法说明：**
`requests.post(url, data=None, json=None, **kwargs)` 发送POST请求到指定URL。

**参数说明：**
- `url`: 请求的目标URL
- `data`: 表单数据（字典、字节或文件对象）
- `json`: JSON数据（自动序列化并设置Content-Type）
- `**kwargs`: 其他可选参数

```python
import requests

# 发送JSON数据
data = {'key': 'value'}
response = requests.post('https://httpbin.org/post', json=data)
print(f"状态码: {response.status_code}")
print("响应内容:")
print(response.json())
```

## 核心功能详解

### 1. 各种HTTP方法

Requests支持所有常见的HTTP方法，每个方法都有对应的函数：

**语法说明：**
- `requests.get(url, **kwargs)`
- `requests.post(url, data=None, json=None, **kwargs)`
- `requests.put(url, data=None, **kwargs)`
- `requests.delete(url, **kwargs)`
- `requests.head(url, **kwargs)`
- `requests.options(url, **kwargs)`
- `requests.patch(url, data=None, **kwargs)`

**参数说明：**
- `url`: 请求的目标URL
- `data`: 请求体数据（表单数据）
- `json`: JSON格式的请求体数据
- `**kwargs`: 其他可选参数，如headers、params、timeout等

```python
import requests

# GET请求
response = requests.get('https://httpbin.org/get')
print(f"GET请求状态码: {response.status_code}")

# POST请求
response = requests.post('https://httpbin.org/post', data={'key': 'value'})
print(f"POST请求状态码: {response.status_code}")

# PUT请求
response = requests.put('https://httpbin.org/put', data={'key': 'new-value'})
print(f"PUT请求状态码: {response.status_code}")

# DELETE请求
response = requests.delete('https://httpbin.org/delete')
print(f"DELETE请求状态码: {response.status_code}")

# HEAD请求（只获取头部信息）
response = requests.head('https://httpbin.org/headers')
print(f"HEAD请求状态码: {response.status_code}")

# OPTIONS请求（获取服务器支持的HTTP方法）
response = requests.options('https://httpbin.org/')
print(f"OPTIONS请求状态码: {response.status_code}")

# PATCH请求（部分更新）
response = requests.patch('https://httpbin.org/patch', data={'field': 'new-value'})
print(f"PATCH请求状态码: {response.status_code}")
```

### 2. 传递URL参数

**语法说明：**
`params`参数用于传递URL查询参数，可以是字典或包含两个元素的元组列表。

**参数说明：**
- `params`: 查询参数字典或列表，例如 `{'q': 'python', 'page': 1}`

```python
import requests

# 方法1：直接在URL中添加参数
response = requests.get('https://httpbin.org/get?name=value&page=1')
print(f"方法1请求URL: {response.url}")
print(f"方法1响应状态码: {response.status_code}")

# 方法2：使用params参数（推荐）
params = {
    'name': 'value',
    'page': 1,
    'sort': 'desc',
    'limit': 10
}
response = requests.get('https://httpbin.org/get', params=params)

print(f"方法2请求URL: {response.url}")
print(f"方法2响应状态码: {response.status_code}")
```

### 3. 请求体数据

#### 发送表单数据

**语法说明：**
使用`data`参数发送表单数据，数据格式为字典。

**参数说明：**
- `data`: 表单数据字典，例如 `{'username': 'user123', 'password': 'secret'}`

```python
import requests

# 发送表单数据
form_data = {
    'username': 'user123',
    'password': 'secret',
    'remember_me': True
}
response = requests.post('https://httpbin.org/post', data=form_data)
print(f"表单POST请求状态码: {response.status_code}")
print("响应内容:")
print(response.json())
```

#### 发送JSON数据

**语法说明：**
使用`json`参数发送JSON数据，Requests会自动序列化并设置正确的Content-Type头。

**参数说明：**
- `json`: Python对象（字典、列表等），会自动序列化为JSON字符串

```python
import requests
import json

# 方法1：使用json参数（自动序列化并设置Content-Type）
json_data = {
    'name': 'John Doe',
    'email': 'john@example.com',
    'age': 30
}
response = requests.post('https://httpbin.org/post', json=json_data)
print("方法1 - 使用json参数:")
print(f"状态码: {response.status_code}")
print(f"Content-Type头: {response.request.headers.get('Content-Type')}")

# 方法2：手动序列化
json_string = json.dumps(json_data)
response = requests.post('https://httpbin.org/post', 
                        data=json_string,
                        headers={'Content-Type': 'application/json'})
print("\n方法2 - 手动序列化:")
print(f"状态码: {response.status_code}")
print(f"Content-Type头: {response.request.headers.get('Content-Type')}")
```

#### 发送文件

**语法说明：**
使用`files`参数上传文件，可以是单个文件或多个文件。

**参数说明：**
- `files`: 文件字典，格式为 `{'name': file_object}` 或 `{'name': (filename, fileobj, content_type)}`

```python
import requests
import io

# 创建虚拟文件内容用于演示
text_content = b"This is a test file content."
file_like_object = io.BytesIO(text_content)

# 上传单个文件
files = {'file': ('test.txt', file_like_object, 'text/plain')}
response = requests.post('https://httpbin.org/post', files=files)
print("上传单个文件:")
print(f"状态码: {response.status_code}")

# 重置文件指针
file_like_object.seek(0)

# 上传多个文件
files = [
    ('files', ('test1.txt', file_like_object, 'text/plain')),
    ('files', ('test2.txt', io.BytesIO(b"Second file content"), 'text/plain'))
]
response = requests.post('https://httpbin.org/post', files=files)
print("\n上传多个文件:")
print(f"状态码: {response.status_code}")

# 上传文件并附带其他数据
files = {'file': ('test.txt', io.BytesIO(b"File with description"), 'text/plain')}
data = {'description': 'Test file with description'}
response = requests.post('https://httpbin.org/post', files=files, data=data)
print("\n上传文件并附带其他数据:")
print(f"状态码: {response.status_code}")
```

### 4. 自定义请求头

**语法说明：**
使用`headers`参数设置自定义HTTP头。

**参数说明：**
- `headers`: 头信息字典，例如 `{'User-Agent': 'MyApp/1.0', 'Authorization': 'Bearer token'}`

```python
import requests

headers = {
    'User-Agent': 'MyApp/1.0',
    'Authorization': 'Bearer YOUR_TOKEN_HERE',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-Custom-Header': 'CustomValue'
}

response = requests.get('https://httpbin.org/headers', headers=headers)
print(f"自定义请求头状态码: {response.status_code}")
print("响应内容:")
print(response.json())
```

### 5. 处理响应

#### 响应状态码

**语法说明：**
响应对象的`status_code`属性包含HTTP状态码，`raise_for_status()`方法会在状态码不是2xx时抛出异常。

```python
import requests

# 测试成功状态码
response = requests.get('https://httpbin.org/status/200')
print(f"200状态码: {response.status_code}")

# 状态码判断
if response.status_code == 200:
    print("请求成功")
elif response.status_code == 404:
    print("资源未找到")
elif response.status_code == 500:
    print("服务器内部错误")

# 使用内置状态码常量
if response.status_code == requests.codes.ok:
    print("内置常量验证: 请求成功")

# 测试错误状态码
try:
    response = requests.get('https://httpbin.org/status/404')
    response.raise_for_status()  # 如果状态码不是2xx，会抛出HTTPError异常
except requests.exceptions.HTTPError as e:
    print(f"HTTP错误: {e}")
```

#### 响应内容

**语法说明：**
响应对象提供了多种方式访问响应内容：
- `text`: Unicode文本内容
- `content`: 字节内容
- `json()`: 解析JSON响应
- `raw`: 原始响应对象

```python
import requests

response = requests.get('https://httpbin.org/json')

print(f"状态码: {response.status_code}")
print(f"编码方式: {response.encoding}")

# 文本内容
print("\n文本内容（前200字符）:")
print(response.text[:200])

# 字节内容
print("\n字节内容（前100字节）:")
print(response.content[:100])

# JSON内容
if response.headers.get('content-type') == 'application/json':
    data = response.json()
    print("\nJSON内容:")
    print(data)
```

#### 响应头

**语法说明：**
响应对象的`headers`属性是一个大小写不敏感的字典，包含所有响应头。

```python
import requests

response = requests.get('https://httpbin.org/headers')

print(f"状态码: {response.status_code}")

# 获取所有响应头
print("\n所有响应头:")
for key, value in response.headers.items():
    print(f"{key}: {value}")

# 获取特定响应头
print(f"\nContent-Type头: {response.headers['Content-Type']}")
print(f"Content-Type头（使用get方法）: {response.headers.get('Content-Type')}")

# 响应头是大小写不敏感的
print(f"content-type（小写）: {response.headers['content-type']}")  # 同样有效
```

#### Cookies

**语法说明：**
使用`cookies`参数发送cookies，响应对象的`cookies`属性包含服务器返回的cookies。

**参数说明：**
- `cookies`: cookies字典或RequestsCookieJar对象

```python
import requests
from requests.cookies import RequestsCookieJar

# 发送请求时携带cookies
cookies = {'session_id': 'abc123', 'user_id': '456'}
response = requests.get('https://httpbin.org/cookies', cookies=cookies)
print("发送cookies:")
print(f"状态码: {response.status_code}")
print(f"响应内容: {response.json()}")

# 从响应中获取cookies
response = requests.get('https://httpbin.org/cookies/set?session_id=xyz789&user_id=123')
print("\n从响应获取cookies:")
print(f"状态码: {response.status_code}")
print(f"所有cookies: {response.cookies}")
print(f"session_id cookie: {response.cookies.get('session_id')}")

# 使用RequestsCookieJar
jar = RequestsCookieJar()
jar.set('session_id', 'abc123', domain='httpbin.org', path='/cookies')
jar.set('user_id', '789', domain='httpbin.org', path='/cookies')
response = requests.get('https://httpbin.org/cookies', cookies=jar)
print("\n使用RequestsCookieJar:")
print(f"状态码: {response.status_code}")
print(f"响应内容: {response.json()}")
```

### 6. 超时设置

**语法说明：**
使用`timeout`参数设置请求超时时间，可以是单个数值（总超时）或元组（连接超时，读取超时）。

**参数说明：**
- `timeout`: 超时时间（秒），例如 `5` 或 `(3.05, 27)`

```python
import requests

# 设置连接和读取超时（秒）- 正常情况
try:
    response = requests.get('https://httpbin.org/delay/1', timeout=5)
    print(f"正常请求状态码: {response.status_code}")
except requests.exceptions.Timeout:
    print("请求超时")

# 测试超时情况
try:
    response = requests.get('https://httpbin.org/delay/10', timeout=2)
except requests.exceptions.Timeout:
    print("请求超时（预期行为）")

# 分别设置连接超时和读取超时
try:
    response = requests.get('https://httpbin.org/delay/1', timeout=(3.05, 27))
    print(f"分别设置超时状态码: {response.status_code}")
except requests.exceptions.ConnectTimeout:
    print("连接超时")
except requests.exceptions.ReadTimeout:
    print("读取超时")
```

### 7. 错误处理

**语法说明：**
Requests定义了多个异常类用于处理不同类型的错误：
- `HTTPError`: HTTP错误（状态码>=400）
- `ConnectionError`: 连接错误
- `Timeout`: 超时错误
- `RequestException`: 所有请求异常的基类

```python
import requests
from requests.exceptions import HTTPError, ConnectionError, Timeout, RequestException

# 测试HTTP错误
try:
    response = requests.get('https://httpbin.org/status/404', timeout=5)
    response.raise_for_status()  # 检查HTTP错误
except HTTPError as http_err:
    print(f'HTTP错误: {http_err}')
    print(f'错误状态码: {http_err.response.status_code}')
except ConnectionError as conn_err:
    print(f'连接错误: {conn_err}')
except Timeout as timeout_err:
    print(f'超时错误: {timeout_err}')
except RequestException as req_err:
    print(f'请求错误: {req_err}')
except Exception as err:
    print(f'其他错误: {err}')
else:
    print("请求成功")

# 测试成功请求
print("\n测试成功请求:")
try:
    response = requests.get('https://httpbin.org/status/200', timeout=5)
    response.raise_for_status()
    print("请求成功")
except HTTPError as http_err:
    print(f'HTTP错误: {http_err}')
```

## 高级用法

### 1. 会话对象（Session）

**语法说明：**
`requests.Session()`创建会话对象，可以保持某些参数跨多个请求，如cookies、headers等，还能实现连接池重用。

```python
import requests

# 创建会话
session = requests.Session()

# 设置会话级别的参数
session.headers.update({'User-Agent': 'MyApp/1.0'})

# 使用会话发送请求 - 保持cookies
response1 = session.get('https://httpbin.org/cookies/set/sessioncookie/123456789')
print(f"第一次请求状态码: {response1.status_code}")

response2 = session.get('https://httpbin.org/cookies')
print(f"第二次请求状态码: {response2.status_code}")
print("第二次请求的cookies:")
print(response2.json())  # 会显示之前设置的cookies

# 临时覆盖会话参数
response3 = session.get('https://httpbin.org/headers', 
                       headers={'X-Test': 'true'})
print(f"\n临时覆盖头状态码: {response3.status_code}")
print("响应头:")
print(response3.json())

# 关闭会话
session.close()
print("\n会话已关闭")
```

### 2. 代理设置

**语法说明：**
使用`proxies`参数设置代理服务器。

**参数说明：**
- `proxies`: 代理字典，格式为 `{'http': 'http://proxy:port', 'https': 'https://proxy:port'}`

```python
import requests

# HTTP代理
proxies = {
    'http': 'http://10.10.1.10:3128',
    'https': 'http://10.10.1.10:1080',
}

# SOCKS代理（需要安装requests[socks]）
# pip install requests[socks]
proxies = {
    'http': 'socks5://user:pass@host:port',
    'https': 'socks5://user:pass@host:port'
}

response = requests.get('https://httpbin.org/ip', proxies=proxies, timeout=10)
print(f"使用代理状态码: {response.status_code}")
print("IP信息:")
print(response.json())

# 环境变量代理（自动检测）
# 设置环境变量：
# export HTTP_PROXY="http://10.10.1.10:3128"
# export HTTPS_PROXY="http://10.10.1.10:1080"
```

### 3. SSL证书验证

**语法说明：**
使用`verify`参数控制SSL证书验证，使用`cert`参数指定客户端证书。

**参数说明：**
- `verify`: True/False或CA证书路径
- `cert`: 客户端证书路径，可以是单个文件（包含私钥）或元组（证书路径，私钥路径）

```python
import requests

# 禁用SSL证书验证（不推荐用于生产环境）
response = requests.get('https://httpbin.org/get', verify=False)
print(f"禁用SSL验证状态码: {response.status_code}")

# 注意：以下示例需要实际证书文件，这里只展示语法
# 指定自定义CA证书
# response = requests.get('https://httpbin.org/get', verify='/path/to/certfile')
# print(f"自定义CA证书状态码: {response.status_code}")

# 客户端证书
# response = requests.get('https://httpbin.org/get', 
#                        cert=('/path/client.cert', '/path/client.key'))
# print(f"客户端证书状态码: {response.status_code}")
```

### 4. 流式请求

**语法说明：**
使用`stream=True`参数启用流式传输，然后使用`iter_content()`或`iter_lines()`方法迭代内容。

**参数说明：**
- `stream`: True启用流式传输
- `iter_content(chunk_size)`: 按指定块大小迭代内容
- `iter_lines()`: 按行迭代内容

```python
import requests

# 流式下载
print("开始流式下载...")
response = requests.get('https://httpbin.org/stream/5', stream=True)

chunk_count = 0
for chunk in response.iter_content(chunk_size=1024):
    if chunk:  # 过滤掉keep-alive的chunk
        chunk_count += 1
        print(f"收到第{chunk_count}个chunk，大小: {len(chunk)}字节")

print(f"总共收到 {chunk_count} 个chunk")

# 流式上传
def generate_large_file():
    for i in range(5):  # 减少数量用于演示
        yield f"Line {i}: This is test data for streaming upload.\n".encode()

print("\n开始流式上传...")
response = requests.post('https://httpbin.org/post', data=generate_large_file())
print(f"流式上传状态码: {response.status_code}")
```

### 5. 认证

**语法说明：**
使用`auth`参数进行HTTP认证，支持Basic、Digest等认证方式。

**参数说明：**
- `auth`: 认证信息，可以是元组（用户名，密码）或认证对象

```python
import requests
from requests.auth import HTTPBasicAuth, HTTPDigestAuth

# Basic认证
response = requests.get('https://httpbin.org/basic-auth/user/passwd', 
                       auth=HTTPBasicAuth('user', 'passwd'))
print(f"Basic认证状态码: {response.status_code}")
print(f"Basic认证响应: {response.json()}")

# 简写形式
response = requests.get('https://httpbin.org/basic-auth/user/passwd', 
                       auth=('user', 'passwd'))
print(f"\nBasic认证简写形式状态码: {response.status_code}")

# 测试错误密码
response = requests.get('https://httpbin.org/basic-auth/user/passwd', 
                       auth=('user', 'wrong'))
print(f"\n错误密码状态码: {response.status_code}")

# Digest认证
response = requests.get('https://httpbin.org/digest-auth/auth/user/passwd',
                       auth=HTTPDigestAuth('user', 'passwd'))
print(f"\nDigest认证状态码: {response.status_code}")

# 注意：OAuth认证需要实际的OAuth配置，这里只展示语法
# from requests_oauthlib import OAuth1
# auth = OAuth1('YOUR_APP_KEY', 
#               'YOUR_APP_SECRET',
#               'USER_OAUTH_TOKEN', 
#               'USER_OAUTH_TOKEN_SECRET')
# response = requests.get('https://httpbin.org/oauth', auth=auth)
# print(f"OAuth认证状态码: {response.status_code}")
```

