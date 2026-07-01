# Mac 安全随机浏览脚本

这个脚本会每隔 3 到 5 分钟随机切换到一个已经启动的 App，并做一些偏浏览性质的动作：

- 浏览器：随机点击顶部标签页区域，并上下滚动页面。
- 飞书/Lark：随机点击左侧导航区域，例如消息、日历、任务等位置，并上下滚动。
- 其它已启动 App：只在窗口左侧导航区或顶部导航区做随机点击，并上下滚动。

脚本不会输入文字，不会按回车，不会主动点击 macOS 顶部菜单栏，也会避开 Finder、系统设置、终端、钥匙串、活动监视器等敏感应用。

## 第一次使用

1. 打开“系统设置”。
2. 进入“隐私与安全性”。
3. 进入“辅助功能”。
4. 给你运行脚本的程序授权，例如“终端”或“脚本编辑器”。

## 运行方式

在这个文件夹中双击：

```bash
run_safe_random_app_walker.command
```

或者在终端里运行：

```bash
swift safe_random_app_walker.swift
```

## 只测试一次

如果你想先只执行一轮，不进入 3 到 5 分钟循环：

```bash
swift safe_random_app_walker.swift --once
```

## 停止脚本

如果是在终端运行，按 `Control-C` 停止。

如果是双击 `.command` 文件运行，关闭弹出的终端窗口即可。

## 调整频率

打开 `safe_random_app_walker.swift`，修改顶部这两行：

```swift
let minDelaySeconds: UInt32 = 180
let maxDelaySeconds: UInt32 = 300
```

180 秒是 3 分钟，300 秒是 5 分钟。
