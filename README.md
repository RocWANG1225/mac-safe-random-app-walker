# Mac Safe Random App Walker

一个 macOS 自动浏览脚本，会在允许的工作时间内定期切换已启动 App，并执行偏浏览性质的操作。

## 运行方式

双击桌面脚本：

```bash
/Users/wangpeng5/Desktop/运行Mac安全随机浏览.command
```

运行日志会写入：

```bash
/Users/wangpeng5/Desktop/运行Mac安全随机浏览.log
```

## 执行时间策略

正常运行时，每 3 到 5 分钟执行一轮。

暂停时间内，每 2 小时检查一次，直到进入允许执行时间。

允许执行时间：

- 工作日 09:00-12:00
- 工作日 14:00-19:00

暂停时间：

- 周六、周日
- 中国假期
- 工作日 12:00-14:00
- 工作日 19:00-第二天 09:00

当前内置的 2026 中国假期区间：

- 元旦：2026-01-01 至 2026-01-03
- 春节：2026-02-16 至 2026-02-23
- 清明节：2026-04-04 至 2026-04-06
- 劳动节：2026-05-01 至 2026-05-05
- 端午节：2026-06-19 至 2026-06-21
- 中秋节：2026-09-25 至 2026-09-27
- 国庆节：2026-10-01 至 2026-10-07

## App 行为

浏览器：

- Safari、Chrome、Edge、Brave、Opera 等会优先读取当前窗口真实标签页数量。
- ChatGPT Atlas 会先读取当前窗口实际标签数量，再用键盘逐个切换标签页。
- 每个标签页切换后会把鼠标移动到网页内容区，再执行长滚动。

飞书：

- 进入“消息”区域。
- 在消息列表和消息内容区域执行随机点击和长滚动。
- 不输入文字。

Excel：

- 访问当前 workbook 的所有 sheet。
- 每个 sheet 都执行滚动。
- 如果脚本临时创建了空 workbook，结束后会不保存关闭。

其它 App：

- 优先在侧边栏或顶部导航区域做安全点击。
- 对可滚动内容执行长滚动。
- 如果 App 没有窗口，会尝试打开新窗口；若是脚本临时打开的窗口，操作完成后会关闭。

## 权限

首次运行时，macOS 可能要求授权：

- 辅助功能权限：允许“终端”控制鼠标和键盘。
- 自动化权限：允许“终端”控制 Safari、Chrome、ChatGPT Atlas、Excel 等 App。

路径：

```text
系统设置 -> 隐私与安全性 -> 辅助功能
系统设置 -> 隐私与安全性 -> 自动化
```

## 测试命令

只列出候选 App，不执行点击：

```bash
CLANG_MODULE_CACHE_PATH=/private/tmp/codex-clang-module-cache swift safe_random_app_walker.swift --dry-run
```

只测试 ChatGPT Atlas：

```bash
CLANG_MODULE_CACHE_PATH=/private/tmp/codex-clang-module-cache swift safe_random_app_walker.swift --atlas-only
```
