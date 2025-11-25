---
layout: post
title: Typora配置GitHub图床
categories: [其他]
permalink: other/picbed.html
tags: PicBed
---

`Linux`环境下`Typora`通过`PicGo-Core`上传图片到`GitHub`配置：

`config.json`配置如下：

```json
{
    "picBed": {
        "current": "github",
        "github": {
            "repo": "duwei0227/picbed", // 仓库名，格式是 username/reponame
            "token": "g", // github token
            "path": "", // 自定义存储路径，比如 img/
            "customUrl": "", // 自定义域名，注意要加 http://或者 https://
            "branch": "main" // 分支名，默认是 main
        }
    },
    "picgoPlugins": {}
}
```



`token`生成： 
1、访问 [https://github.com/settings/tokens](https://github.com/settings/tokens)

2、点击 `New personal access token (classic)`

3、选择`token`实效时间，勾选`repo`

4、`Generate token`

5、复制生成的`token`信息（**重新访问页面时，token信息无法再次查看，需要自行保存**）



**注意事项**

* `branch`需要指定，默认提交会提示分支不存在