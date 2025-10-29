---
title: Fedora系统自动删除历史kernel
published: true
layout: post
date: 2025-10-29 19:28:07
permalink: /linux/fedora/removal_old_kernel.html
tags: Fedora
categories: [Linux]
---


### 一、编辑 dnf.conf 文件
```bash
sudo vi /etc/dnf/dnf.conf
```



### 二、在[main]下边添加 installonly_limit
```bash
installonly_limit=2
```



数字 **2**表示需要保留的内核数量，包含当前在使用的最新内核

### 三、执行 sudo dnf update 删除旧内核
```bash
duwei@probiecoder:~$ sudo dnf update
Updating and loading repositories:
dRepositories loaded.
Package                  Arch    Version                  Repository        Size
Removing:
 kernel                  x86_64  6.17.4-200.fc42          <unknown>      0.0   B
 kernel-core             x86_64  6.17.4-200.fc42          <unknown>     98.8 MiB
 kernel-modules          x86_64  6.17.4-200.fc42          <unknown>     95.6 MiB
 kernel-modules-core     x86_64  6.17.4-200.fc42          <unknown>     68.3 MiB
 kernel-modules-extra    x86_64  6.17.4-200.fc42          <unknown>      4.2 MiB

Transaction Summary:
 Removing:           5 packages

```

