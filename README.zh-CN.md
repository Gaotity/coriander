# Coriander

[English](README.md) | **简体中文**

一款早期阶段的、本地优先的 iOS/iPadOS Rime 输入法键盘。

> **状态：** Pre-alpha —— 目前没有可安装的构建。

## 概览

Coriander 旨在将 Rime 输入引擎的灵活性，带到 iPhone 与 iPad 的原生键盘体验中。

项目目前处于规划与基础开发阶段。下列功能均为目标，而非已实现的能力。

## 设计目标

- **本地优先输入：** 核心输入处理留在设备上。基础键盘功能不依赖网络访问或完全访问权限（Full Access）。
- **Rime 灵活性：** 支持可配置的 Rime 输入方案，并定义、文档化兼容边界。
- **原生 Apple 平台体验：** 适配 iPhone 与 iPad 的布局、方向，以及紧凑或浮动键盘形态。
- **清晰的隐私行为：** 在请求任何可选权限之前，先解释键盘能访问什么数据、为什么。

这些目标将在 Apple 的[键盘扩展审核要求](https://developer.apple.com/app-store/review/guidelines/)内推进。

## 计划的 MVP

首个可用版本旨在：

- 将 [`librime`](https://github.com/rime/librime) 集成进 iOS 自定义键盘扩展。
- 提供基础的输入组合（composition）与候选选择界面。
- 导入并选择兼容的 Rime 方案。具体兼容性将随实现进展逐步定义。
- 适配 iPhone 与 iPad 的键盘界面，包括竖屏、横屏，以及支持时的浮动键盘形态。
- 提供用于设置、引导与配置的容器 App。

## 可用性

目前没有任何二进制文件、TestFlight 构建或 App Store 发布。当前预期的分发路径是先 TestFlight 测试，再 App Store 发布，不承诺发布日期。

## 从源码构建

前置要求:Xcode(含 iOS 平台支持)、[XcodeGen](https://github.com/yonaskolb/XcodeGen)、CMake 与 Ninja(`brew install xcodegen cmake ninja`)。

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer  # 若 xcode-select 指向他处
scripts/librime/fetch.sh        # 克隆锁定版本 librime + 子模块到 .scratch
scripts/librime/build-deps.sh   # 交叉编译第三方依赖(三切片)
scripts/librime/build-librime.sh # 组装 Rime.xcframework
xcodegen generate               # 由 project.yml 重新生成 Coriander.xcodeproj
```

然后打开 `Coriander.xcodeproj`,或用 `xcodebuild -scheme Coriander` 构建。构建产物位于 `.scratch/`(已 gitignore);`Coriander.xcodeproj` 由 `project.yml` 生成,不入库。

## 参与

欢迎提交 issue、设计反馈与用例讨论。请[提交 issue](https://github.com/Gaotity/coriander/issues) 参与。

代码贡献尚未开放。**暂时请不要提交代码 PR。** 代码贡献开放前，会公布一份经过评审的贡献者许可协议（CLA）流程。贡献者保留其作品的所有权，同时授予项目维护与再许可已接受贡献所需的权利。

## 许可证

除非另有说明，本仓库中项目原创代码当前以 [Apache License 2.0](LICENSE) 授权。

项目有权再许可的代码，未来可能以源码可得（source-available）条款提供。未来的许可证、限制或变更日期均未选定。

已以 Apache-2.0 发布的代码（包括仓库历史）将始终以该条款保持可用。既有权限不会被撤销或追溯替换。

第三方组件——包括 `librime`、Rime 方案、词典以及捆绑或导入的资源——仍受其各自许可证约束。

## 致谢

Coriander 构建于 [Rime 输入法引擎](https://rime.im/)社区与 [`librime`](https://github.com/rime/librime) 的工作之上，后者以 BSD 3-Clause 许可证分发。

Coriander 是独立项目，与 Rime 项目无隶属关系，亦未获其背书。
