## 一、Hexo命令
### 1、清理缓存
```shell
hexo clean
```

### 2、生成静态文件
```shell
hexo g 
hexo generate
```

### 3、本地服务
```shell
hexo s
hexo server
```

### 4、部署
```shell
hexo d
hexo deploy
```

### 5、创建文章
```shell
hexo new -p path/文章名称
```
* `-p`： 指定文章路径，可选参数，不指定默认生成位置为 `_post` 目录

## 二、Fluid主题
### 1、更新主题
```shell
npm update --save hexo-theme-fluid
```

## 三、语法
### 1、Tag插件
```
{% note success %}
文字 或者 `markdown` 均可
{% endnote %}

```
可选変签：`primary` `secondary` `success` `danger` `warning` `info`  `light`