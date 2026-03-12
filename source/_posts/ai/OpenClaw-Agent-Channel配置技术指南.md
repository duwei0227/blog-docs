---
title: OpenClaw Agent-Channel 配置技术指南
published: true
layout: post
date: 2026-03-12 19:00:00
permalink: /ai/openclaw-agent-channel-config-guide.html
categories: [AI]
---



## 1. Channel 配置多个账户信息

通过配置 `accounts`配置多个账户，后续通过绑定`account_id`来关联，`account_id`不能重复

编辑 `.openclaw/openclaw.json`文件，修改`channels`节点

### 1.1 Telegram

```json5
"channels": {
  "telegram": {
    "accounts": {
      "account_id1": {
        "botToken": "xxxx"
      },
      "account_id2": {
        "botToken": "yyyy"
      }
    },
    "groupPolicy": "allowlist",
    "allowFrom": ["+1 XXXXXXXXXX"] // 白名单
  }
}
```



### 1.2 Feishu 

```json5
"feishu": {
  "accounts": {
    "账户1定义id": {
      "enabled": true,
      "appId": "xxx",
      "appSecret": "xxxx",
      "botName": "学习助手",
      "connectionMode": "websocket",
      "domain": "feishu",
      "groupPolicy": "allowlist"
    },
    "账户2定义id": {
      "enabled": true,
      "appId": "yyy",
      "appSecret": "yyy",
      "botName": "学习助手",
      "connectionMode": "websocket",
      "domain": "feishu",
      "groupPolicy": "allowlist"
    }
  }
}
```



## 2. 建立agent和channel的绑定关系

```bash
# 1. 新增绑定规则
openclaw agents bind --agent <agent_id> --bind <channel>:<channel_account_id>
```

* `agent_id`: `agent`的`ID`，可以通过`openclaw agents list` 获取
* `channel`:  `channel`的名称，例如 `telegram`
* `channel_account_id`: 在上一步



## 3. 重启gateway

```shell
openclaw gateway restart
```



## 4、启用机器人

进入机器人聊天窗口，重新发送一个消息，此时`OpenClaw`应该会让我们进行配对：

```
OpenClaw: access not configured.

Your Telegram user id: xxxx

Pairing code: yyy

Ask the bot owner to approve with:
openclaw pairing approve telegram yyy
```



在终端下执行 `pairing approve`进行授权绑定

```
openclaw pairing approve telegram yyy
```

