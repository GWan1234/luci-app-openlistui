# OpenList LuCI App

简化的 OpenWrt LuCI 应用包构建，具有自动版本管理功能。

## 快速开始

```bash
# 编译默认架构 (x86_64)
./build.sh

# 编译指定架构
./build.sh aarch64
./build.sh mt7621

# 显示版本信息
./build.sh version

# 清理构建文件
./build.sh clean

# 显示帮助
./build.sh help
```

## 版本管理

本项目使用自动版本管理系统：

```bash
# 显示当前版本信息
./version.sh version

# 更新基础版本号
./version.sh bump 0.7

# 生成变更日志
./version.sh changelog

# 显示版本管理帮助
./version.sh help
```

### 版本号规则

- **基础版本**: 在 `Makefile` 中的 `PKG_VERSION_BASE` (如 0.6)
- **补丁版本**: 基于 git commit 数量自动计算
- **完整版本**: `基础版本.补丁版本` (如 0.6.42)
- **发布版本**: 构建时间戳 `YYYYMMDDHHMM`

### 构建输出

每次构建会生成：
- **IPK包**: `output/luci-app-openlistui_架构_时间戳.ipk`
- **构建信息**: `output/luci-app-openlistui_架构_时间戳.info`
- **构建日志**: `build-logs/build-架构-时间戳.log`
- **版本信息**: 包内 `/usr/lib/lua/luci/version-openlistui`

## 配置文件

可以通过 `build.conf` 自定义构建参数：
- 默认架构
- SDK URLs
- 构建选项
- 依赖包列表

## 输出

编译成功后，所有文件将在对应目录中：
- `output/` - IPK包和构建信息
- `build-logs/` - 详细构建日志
- `build-info/` - 调试用版本信息

## 注意

- 此包仅包含 LuCI 网页界面
- 配置文件和服务由核心 `openlist` 包提供
- 确保先安装核心 `openlist` 包，再安装此 LuCI 界面包
- 使用 `openlistui` 命名空间避免与原始 `luci-app-openlist` 冲突

## 开发

```bash
# 检查版本信息
make version

# 生成版本文件（调试用）
make gen-version

# 查看构建变量
grep "PKG_" Makefile
```
