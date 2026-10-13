<p align="center">
  <img src="docs/app-icon.png" width="128" alt="Kurumi">
</p>

<h1 align="center">Kurumi</h1>

<p align="center">一个常驻 macOS 菜单栏的美股实时行情小工具，原生 SwiftUI 编写，数据来自 Yahoo Finance。</p>

## 功能

- 菜单栏只显示一个图标，左键点击弹出行情面板，右键点击弹出菜单（退出）
- 面板顶部是搜索框：边输入边给出美股候选（NASDAQ / NYSE / NYSE Arca 等交易所的股票和 ETF），上下键选择、回车或点击加入 watchlist
- watchlist 垂直排列，每行显示代码、公司名、现价、涨跌额和涨跌幅（绿涨红跌）
- 盘前 / 盘后时段，在该行下方额外显示盘前或盘后价格及相对收盘价的涨跌
- 拖拽调整顺序；右键菜单可在浏览器打开 Yahoo Finance 页面或删除
- 底部显示最后更新时间和当前市场状态（盘前 / 交易中 / 盘后 / 休市）
- watchlist 自动保存，重启后保留

## 刷新策略

Yahoo Finance 的免费接口不提供推送，Kurumi 采用轮询：

| 场景 | 刷新间隔 |
| --- | --- |
| 交易时段（含盘前盘后），面板打开 | 5 秒 |
| 交易时段（含盘前盘后），面板关闭 | 60 秒 |
| 休市 | 暂停，到下一个盘前开盘时自动恢复（最长每 30 分钟检查一次） |

## 环境要求

- macOS 14 Sonoma 及以上
- Swift 工具链：只装 Command Line Tools 即可（`xcode-select --install`），不需要 Xcode

## 构建与运行

```bash
./scripts/build-app.sh
open build/Kurumi.app
```

脚本会编译 release 版本，生成应用图标，并打包成 `build/Kurumi.app`（不显示 Dock 图标，使用本地临时签名）。可以把它拖到「应用程序」文件夹里长期使用。

开发调试也可以直接运行：

```bash
swift run --build-system native
```

> 只装 Command Line Tools 时，SwiftPM 默认的构建后端无法使用，所以这里显式指定 `--build-system native`。也因为 Command Line Tools 不带 SwiftUI 的宏插件，代码里的界面状态都放在 `@Observable` 对象中，而不是使用 `@State`。

## 自定义图标

把白色、透明背景的图形放在项目根目录，命名为 `icon.svg`（推荐，矢量更清晰）或 `icon.png`，重新运行 `./scripts/build-app.sh`：

- 菜单栏图标直接使用该图形，并作为模板图像随深色 / 浅色模式自动变色
- 应用图标由 `scripts/make-icon.swift` 生成：把图形居中绘制在 `#73d13d` 的圆角方块上，再用 `iconutil` 打包成 `AppIcon.icns`

## 项目结构

```
Sources/Kurumi/
├── App/                   # 入口、菜单栏图标、弹出面板、快捷键菜单
├── Models/                # 数据模型、交易时段判断、价格与涨跌格式化
├── Services/              # Yahoo Finance 接口、watchlist 持久化与轮询刷新
├── State/                 # 面板导航 / 排序 / 拖拽状态，搜索状态与防抖
├── Views/
│   ├── Panel/             # 面板整体布局、顶栏、底栏、布局常量
│   ├── Watchlist/         # watchlist 列表、行视图、价格与涨跌标签
│   ├── Search/            # 搜索页、搜索框、搜索候选列表
│   └── Detail/            # 股票详情页与分时图
└── Support/               # AppKit 桥接：拖拽、鼠标指针、Esc 监听等
scripts/
├── build-app.sh           # 编译并打包 Kurumi.app
└── make-icon.swift        # 生成应用图标
```

## 数据来源与免责声明

行情数据来自 Yahoo Finance 的公开网页接口（与 [yfinance](https://github.com/ranaroussi/yfinance) 使用的接口相同）。这些接口并非官方开放 API，随时可能变更或限流，数据可能存在延迟。本项目仅供个人学习与参考，不构成任何投资建议。
