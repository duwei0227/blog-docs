---
title: Python urllib HTTP请求指南
date: 2026-03-24 08:30:00
tags:
  - Python
  - HTTP
  - urllib
categories:
  - Python
---

`urllib` 是 Python 标准库中用于处理 URL 的模块，包含 `urllib.request`（发送请求）、`urllib.parse`（URL 解析和编码）、`urllib.error`（异常处理）三个子模块。无需安装第三方库即可发送 HTTP 请求。

## 一、urllib.request 发送请求

### 1.1 urlopen() 简单请求

**语法格式**

```
urllib.request.urlopen(url, data=None, timeout=None, context=None)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `url` | URL 字符串或 Request 对象 | `'https://httpbin.org/get'` |
| `data` | POST 数据，需编码为字节 | `b'key=value'` |
| `timeout` | 超时秒数 | `10` |
| `context` | SSL 上下文 | `ssl.create_default_context()` |

**返回值**：返回一个类文件对象，包含 `read()`、`status`、`headers` 属性。

**示例**

```python
import urllib.request

# GET 请求
with urllib.request.urlopen('https://httpbin.org/get') as response:
    print(f"状态码: {response.status}")
    print(f"响应内容: {response.read().decode('utf-8')}")

# 输出
# 状态码: 200
# 响应内容: {"args": {}, "headers": {...}, "origin": "...", "url": "https://httpbin.org/get"}
```

### 1.2 Request 对象构建请求

**语法格式**

```
urllib.request.Request(url, data=None, headers={}, method=None)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `url` | 请求 URL | `'https://httpbin.org/post'` |
| `data` | 请求数据（字节） | `b'key=value'` |
| `headers` | 请求头字典 | `{'User-Agent': 'MyBot'}` |
| `method` | HTTP 方法 | `'GET'`、`'POST'`、`'PUT'` |

**示例**

```python
import urllib.request
import json

# POST JSON 请求
url = 'https://httpbin.org/post'
data = json.dumps({'name': 'Alice', 'age': 25}).encode('utf-8')

req = urllib.request.Request(
    url,
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)

with urllib.request.urlopen(req) as response:
    result = json.loads(response.read().decode('utf-8'))
    print(f"服务器收到的JSON: {result['json']}")

# 输出
# 服务器收到的JSON: {'name': 'Alice', 'age': 25}
```

### 1.3 添加请求头

**语法格式**

```
Request.add_header(key, value)
Request.add_unredirected_header(key, value)
```

**说明**：`add_header()` 添加的请求头会跟随重定向，`add_unredirected_header()` 不会。

**示例**

```python
import urllib.request
import json

req = urllib.request.Request('https://httpbin.org/headers')
req.add_header('User-Agent', 'MyApp/1.0')
req.add_header('Accept', 'application/json')
req.add_header('Referer', 'https://example.com')

with urllib.request.urlopen(req) as response:
    headers = json.loads(response.read().decode('utf-8'))['headers']
    print(f"User-Agent: {headers.get('User-Agent')}")
    print(f"Accept: {headers.get('Accept')}")

# 输出
# User-Agent: MyApp/1.0
# Accept: application/json
```

### 1.4 设置代理

**语法格式**

```
urllib.request.ProxyHandler(proxies)
urllib.request.build_opener(handler)
```

**示例**

```python
import urllib.request

# 设置代理
proxies = {
    'http': 'http://proxy.example.com:8080',
    'https': 'http://proxy.example.com:8080'
}

proxy_handler = urllib.request.ProxyHandler(proxies)
opener = urllib.request.build_opener(proxy_handler)

# 使用 opener 发送请求
response = opener.open('https://httpbin.org/ip')
print(response.read().decode('utf-8'))

# 禁用代理（覆盖环境变量）
no_proxy_handler = urllib.request.ProxyHandler({})
opener_no_proxy = urllib.request.build_opener(no_proxy_handler)
```

### 1.5 build_opener() 自定义 opener

**语法格式**

```
urllib.request.build_opener(*handlers)
urllib.request.install_opener(opener)
```

**说明**：`build_opener()` 创建 opener，`install_opener()` 将其安装为全局默认。

**示例**

```python
import urllib.request

# 创建带有自定义处理器的 opener
opener = urllib.request.build_opener()

# 添加默认处理器（代理、Cookie、重定向等）
class CustomHandler(urllib.request.BaseHandler):
    def default_open(self, req):
        print(f"拦截请求: {req.full_url}")
        return None  # 返回 None 继续执行其他处理器

opener.add_handler(CustomHandler())

# 全局安装后，urlopen() 将使用此 opener
urllib.request.install_opener(opener)
```

### 1.6 HTTP 基本认证

**语法格式**

```
urllib.request.HTTPBasicAuthHandler()
urllib.request.HTTPPasswordMgr()
handler.add_password(realm, uri, user, password)
```

**示例**

```python
import urllib.request

# 创建密码管理器
password_mgr = urllib.request.HTTPPasswordMgr()
password_mgr.add_password(
    realm='Private Area',
    uri='https://httpbin.org/basic-auth/user/passwd',
    user='user',
    passwd='passwd'
)

# 创建认证处理器
auth_handler = urllib.request.HTTPBasicAuthHandler(password_mgr)
opener = urllib.request.build_opener(auth_handler)

# 发送请求
response = opener.open('https://httpbin.org/basic-auth/user/passwd')
print(f"状态码: {response.status}")
print(response.read().decode('utf-8'))

# 输出
# 状态码: 200
# {"authenticated": true, "user": "user"}
```

### 1.7 处理 Cookie

**语法格式**

```
urllib.request.HTTPCookieProcessor(cookiejar=None)
```

**示例**

```python
import urllib.request
import http.cookiejar

# 创建 CookieJar 保存 Cookie
cookie_jar = http.cookiejar.CookieJar()
cookie_handler = urllib.request.HTTPCookieProcessor(cookie_jar)
opener = urllib.request.build_opener(cookie_handler)

# 第一次请求（登录）
opener.open('https://httpbin.org/cookies/set/session_id/abc123')

# 第二次请求（带 Cookie）
opener.open('https://httpbin.org/cookies')

# 查看 Cookie
for cookie in cookie_jar:
    print(f"{cookie.name} = {cookie.value}")

# 输出
# session_id = abc123
```

### 1.8 urlretrieve() 下载文件

**语法格式**

```
urllib.request.urlretrieve(url, filename=None, reporthook=None, data=None)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `url` | 下载链接 | `'https://httpbin.org/image/png'` |
| `filename` | 保存路径，None 则为临时文件 | `'/path/to/file'` |
| `reporthook` | 下载进度回调函数 | `hook_func` |
| `data` | POST 数据 | `None` |

**返回值**：元组 `(filename, headers)`

**示例**

```python
import urllib.request

# 下载图片
url = 'https://httpbin.org/image/png'
local_filename, headers = urllib.request.urlretrieve(url, '/tmp/test.png')

print(f"保存至: {local_filename}")
print(f"文件大小: {headers.get('Content-Length')} bytes")

# 清理临时文件
urllib.request.urlcleanup()
```

## 二、urllib.parse URL 解析与编码

### 2.1 urlsplit() URL 分解

**语法格式**

```
urllib.parse.urlsplit(urlstring, scheme=None, allow_fragments=True)
```

**返回值**：SplitResult 命名元组

| 属性 | 说明 |
|------|------|
| `scheme` | 协议 |
| `netloc` | 网络位置（含端口） |
| `path` | 路径 |
| `query` | 查询参数 |
| `fragment` | 片段标识符 |
| `hostname` | 主机名（仅主机） |
| `port` | 端口号 |
| `username` | 用户名 |
| `password` | 密码 |

**示例**

```python
from urllib.parse import urlsplit

url = 'https://user:pass@example.com:8080/path?query=1#section'
result = urlsplit(url)

print(f"scheme: {result.scheme}")
print(f"hostname: {result.hostname}")
print(f"port: {result.port}")
print(f"path: {result.path}")
print(f"query: {result.query}")
print(f"username: {result.username}")
print(f"password: {result.password}")

# 输出
# scheme: https
# hostname: example.com
# port: 8080
# path: /path
# query: query=1
# username: user
# password: pass
```

### 2.2 urlparse() URL 分解（含 params）

**语法格式**

```
urllib.parse.urlparse(urlstring, scheme=None, allow_fragments=True)
```

**返回值**：ParseResult 命名元组，比 urlsplit 多一个 `params` 属性。

**示例**

```python
from urllib.parse import urlparse

# 注意：现代 URL 语法中 params 已很少使用
url = 'http://example.com/path;params?query=1#frag'
result = urlparse(url)

print(f"scheme: {result.scheme}")
print(f"netloc: {result.netloc}")
print(f"path: {result.path}")
print(f"params: {result.params}")  # 历史遗留字段
print(f"query: {result.query}")

# 输出
# scheme: http
# netloc: example.com
# path: /path
# params: params
# query: query=1
```

### 2.3 urlencode() 查询参数编码

**语法格式**

```
urllib.parse.urlencode(query, doseq=False, safe='', quote_via=quote_plus)
```

**参数说明**

| 参数 | 说明 | 示例 |
|------|------|------|
| `query` | 字典或元组列表 | `{'name': 'Alice', 'age': 25}` |
| `doseq` | 序列值是否展开为多个参数 | `True` |
| `safe` | 不转义的字符 | `''` |
| `quote_via` | 编码函数 | `quote`（保留空格为 %20） |

**示例**

```python
from urllib.parse import urlencode, quote, quote_plus

# 字典编码
params = {'name': 'Alice', 'city': 'New York'}
query_string = urlencode(params)
print(f"urlencode: {query_string}")

# 序列值展开
params_multi = {'tag': ['python', 'http']}
print(f"doseq=True: {urlencode(params_multi, doseq=True)}")

# 使用 quote（空格转义为 %20）
print(f"quote: {quote('hello world')}")

# 使用 quote_plus（空格转义为 +）
print(f"quote_plus: {quote_plus('hello world')}")

# 输出
# urlencode: name=Alice&city=New+York
# doseq=True: tag=python&tag=http
# quote: hello%20world
# quote_plus: hello+world
```

### 2.4 quote() URL 编码

**语法格式**

```
urllib.parse.quote(string, safe='/', encoding=None, errors=None)
urllib.parse.quote_plus(string, safe='', encoding=None, errors=None)
```

**说明**：`quote()` 默认不编码 `/`，`quote_plus()` 将空格转为 `+`。

**示例**

```python
from urllib.parse import quote, quote_plus, unquote, unquote_plus

# 编码特殊字符
text = '/path/to file?name=Alice&age=25'

print(f"quote: {quote(text)}")
print(f"quote_plus: {quote_plus(text)}")

# 编码中文
chinese = '你好世界'
print(f"中文编码: {quote(chinese)}")

# 解码
encoded = 'hello%20world'
print(f"unquote: {unquote(encoded)}")
print(f"unquote_plus: {hello+world}")

# 输出
# quote: /path/to%20file?name%3DAlice&age%3D25
# quote_plus: %2Fpath%2Fto+file%3Dname%3DAlice%26age%3D25
# 中文编码: %E4%BD%A0%E5%A5%BD%E4%B8%96%E7%95%8C
# unquote: hello world
# unquote_plus: hello world
```

### 2.5 parse_qs() 查询字符串解析

**语法格式**

```
urllib.parse.parse_qs(qs, keep_blank_values=False, encoding='utf-8')
urllib.parse.parse_qsl(qs, keep_blank_values=False, encoding='utf-8')
```

**返回值**：`parse_qs` 返回字典，`parse_qsl` 返回列表。

**示例**

```python
from urllib.parse import parse_qs, parse_qsl

query_string = 'name=Alice&age=25&city=NYC&tag=python&tag=http'

# 返回字典
print(f"parse_qs: {parse_qs(query_string)}")

# 返回列表
print(f"parse_qsl: {parse_qsl(query_string)}")

# 保留空值
query_with_blank = 'name=Alice&age=&city=NYC'
print(f"保留空值: {parse_qs(query_with_blank, keep_blank_values=True)}")

# 输出
# parse_qs: {'name': ['Alice'], 'age': ['25'], 'city': ['NYC'], 'tag': ['python', 'http']}
# parse_qsl: [('name', 'Alice'), ('age', '25'), ('city', 'NYC'), ('tag', 'python'), ('tag', 'http')]
# 保留空值: {'name': ['Alice'], 'age': [''], 'city': ['NYC']}
```

### 2.6 urljoin() URL 拼接

**语法格式**

```
urllib.parse.urljoin(base, url, allow_fragments=True)
```

**说明**：基于 base URL 拼接相对 URL。

**示例**

```python
from urllib.parse import urljoin

base = 'https://example.com/path/page.html'

# 相对路径
print(f"相对路径: {urljoin(base, 'about.html')}")

# 绝对路径
print(f"绝对路径: {urljoin(base, '/about.html')}")

# 绝对 URL
print(f"绝对URL: {urljoin(base, 'https://other.com/page')}")

# 上级目录
print(f"上级目录: {urljoin(base, '../contact.html')}")

# 输出
# 相对路径: https://example.com/path/about.html
# 绝对路径: https://example.com/about.html
# 绝对URL: https://other.com/page
# 上级目录: https://example.com/contact.html
```

### 2.7 urlunsplit() URL 拼接（反向）

**语法格式**

```
urllib.parse.urlunsplit(parts)
```

**说明**：将 urlsplit 结果重新组合为 URL。

**示例**

```python
from urllib.parse import urlsplit, urlunsplit

url = 'https://example.com/path?query=1#section'
parts = urlsplit(url)

# 修改部分组件
new_parts = (parts.scheme, parts.netloc, '/newpath', parts.query, '')
new_url = urlunsplit(new_parts)
print(f"新URL: {new_url}")

# 输出
# 新URL: https://example.com/newpath?query=1
```

### 2.8 urldefrag() 分离片段

**语法格式**

```
urllib.parse.urldefrag(url)
```

**返回值**：DefragResult 命名元组 `(url, fragment)`

**示例**

```python
from urllib.parse import urldefrag

url = 'https://example.com/page#section1'
base_url, fragment = urldefrag(url)

print(f"基础URL: {base_url}")
print(f"片段: {fragment}")

# 输出
# 基础URL: https://example.com/page
# 片段: section1
```

## 三、urllib.error 异常处理

### 3.1 URLError 网络错误

**语法格式**

```
urllib.error.URLError(reason)
```

**说明**：网络连接问题的基类异常，`reason` 属性包含具体错误信息。

**示例**

```python
import urllib.request
import urllib.error

try:
    urllib.request.urlopen('https://invalid-domain-12345.com', timeout=5)
except urllib.error.URLError as e:
    print(f"错误类型: {type(e.reason)}")
    print(f"错误信息: {e.reason}")

# 输出（可能）
# 错误类型: <class 'socket.gaierror'>
# 错误信息: [Errno -2] Name or service not known
```

### 3.2 HTTPError HTTP 错误

**语法格式**

```
urllib.error.HTTPError(url, code, msg, hdrs, fp)
```

**属性说明**

| 属性 | 说明 |
|------|------|
| `code` | HTTP 状态码 |
| `reason` | 错误原因描述 |
| `headers` | 响应头 |
| `url` | 请求 URL |

**示例**

```python
import urllib.request
import urllib.error
import json

try:
    # 请求一个不存在的路径
    urllib.request.urlopen('https://httpbin.org/status/404', timeout=5)
except urllib.error.HTTPError as e:
    print(f"状态码: {e.code}")
    print(f"原因: {e.reason}")
    print(f"URL: {e.url}")
    
    # 读取错误响应体
    try:
        error_body = json.loads(e.read().decode('utf-8'))
        print(f"响应内容: {error_body}")
    except:
        pass

# 输出
# 状态码: 404
# 原因: NOT FOUND
# URL: https://httpbin.org/status/404
```

### 3.3 异常处理流程

**示例**

```python
import urllib.request
import urllib.error

def fetch_url(url):
    """统一的异常处理示例"""
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            return {
                'status': response.status,
                'data': response.read().decode('utf-8')
            }
    except urllib.error.HTTPError as e:
        # HTTP 错误（4xx, 5xx）
        return {
            'error': 'HTTP_ERROR',
            'code': e.code,
            'reason': e.reason
        }
    except urllib.error.URLError as e:
        # 网络错误（连接失败、超时等）
        return {
            'error': 'URL_ERROR',
            'reason': str(e.reason)
        }
    except Exception as e:
        # 其他错误
        return {
            'error': 'UNKNOWN',
            'reason': str(e)
        }

# 测试
print(fetch_url('https://httpbin.org/get'))
print(fetch_url('https://httpbin.org/status/500'))
print(fetch_url('https://invalid-domain.com'))

# 输出
# {'status': 200, 'data': '{...}'}
# {'error': 'HTTP_ERROR', 'code': 500, 'reason': 'INTERNAL SERVER ERROR'}
# {'error': 'URL_ERROR', 'reason': '...'}
```

## 四、完整请求示例

### 4.1 GET 请求

```python
import urllib.request

def get_request(url, params=None, headers=None):
    """发送 GET 请求"""
    if params:
        from urllib.parse import urlencode
        url = f"{url}?{urlencode(params)}"
    
    req = urllib.request.Request(url)
    if headers:
        for key, value in headers.items():
            req.add_header(key, value)
    
    with urllib.request.urlopen(req) as response:
        return {
            'status': response.status,
            'headers': dict(response.headers),
            'body': response.read().decode('utf-8')
        }

# 使用
result = get_request(
    'https://httpbin.org/get',
    params={'key': 'value'},
    headers={'Accept': 'application/json'}
)
print(f"状态: {result['status']}")
```

### 4.2 POST 请求

```python
import urllib.request
import urllib.parse
import json

def post_request(url, data=None, json_data=None, headers=None):
    """发送 POST 请求"""
    if json_data:
        data = json.dumps(json_data).encode('utf-8')
        content_type = 'application/json'
    elif data:
        if isinstance(data, dict):
            data = urllib.parse.urlencode(data).encode('utf-8')
        else:
            data = data.encode('utf-8')
        content_type = 'application/x-www-form-urlencoded'
    
    req = urllib.request.Request(url, data=data)
    req.add_header('Content-Type', content_type)
    
    if headers:
        for key, value in headers.items():
            req.add_header(key, value)
    
    with urllib.request.urlopen(req) as response:
        return {
            'status': response.status,
            'body': json.loads(response.read().decode('utf-8'))
        }

# 使用
result = post_request(
    'https://httpbin.org/post',
    json_data={'name': 'Alice', 'age': 25}
)
print(f"服务器响应: {result['body']['json']}")

# 输出
# 服务器响应: {'name': 'Alice', 'age': 25}
```

### 4.3 文件上传

```python
import urllib.request
import urllib.parse
import json

def upload_file(url, field_name, file_content, filename, extra_fields=None):
    """上传文件（multipart/form-data）"""
    boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW'
    
    body = b''
    
    # 添加额外字段
    if extra_fields:
        for key, value in extra_fields.items():
            body += f'--{boundary}\r\n'.encode()
            body += f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode()
            body += f'{value}\r\n'.encode()
    
    # 添加文件字段
    body += f'--{boundary}\r\n'.encode()
    body += f'Content-Disposition: form-data; name="{field_name}"; filename="{filename}"\r\n'.encode()
    body += b'Content-Type: application/octet-stream\r\n\r\n'
    body += file_content
    body += b'\r\n'
    
    # 结束边界
    body += f'--{boundary}--\r\n'.encode()
    
    req = urllib.request.Request(url, data=body)
    req.add_header('Content-Type', f'multipart/form-data; boundary={boundary}')
    
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode('utf-8'))

# 使用
result = upload_file(
    'https://httpbin.org/post',
    field_name='file',
    file_content=b'Hello, this is file content!',
    filename='test.txt',
    extra_fields={'description': 'A test file'}
)
print(f"上传成功: {result['files']}")
```
