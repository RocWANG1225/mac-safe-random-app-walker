# Mac Safe Random App Walker

一个 macOS 自动浏览脚本。它会每隔 3 到 5 分钟随机切换到一个已经启动的 App，并只执行偏浏览性质的动作。

## 行为

- 浏览器：随机点击顶部标签页区域，并上下滚动页面。
- 飞书/Lark：随机点击左侧导航区域，例如消息、日历、任务等位置，并上下滚动。
- 其它已启动 App：只在窗口左侧导航区或顶部导航区做随机点击，并上下滚动。

脚本不会输入文字，不会按回车，不会主动点击 macOS 顶部菜单栏，并会避开 Finder、系统设置、终端、钥匙串、活动监视器等敏感应用。

## 第一次使用

1. 打开“系统设置”。
2. 进入“隐私与安全性”。
3. 进入“辅助功能”。
4. 给你运行脚本的程序授权，例如“终端”。

## 运行

双击：

```bash
run_safe_random_app_walker.command
```

或者在终端中运行：

```bash
swift safe_random_app_walker.swift
```

## 只测试一次

```bash
swift safe_random_app_walker.swift --once
```

## 停止

在终端窗口中按 `Control-C`，或者关闭运行窗口。
