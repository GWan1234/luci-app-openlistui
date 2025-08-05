#!/bin/bash

# luci-app-openlistui 编译脚本

# set -e  # 注释掉严格模式，避免单个架构失败导致整个脚本退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 项目信息
PKG_NAME="luci-app-openlistui"
DEFAULT_ARCH="x86_64"

# 支持的架构（使用清华大学镜像源）
declare -A ARCH_CONFIG=(
    ["x86_64"]="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/23.05.0/targets/x86/64/openwrt-sdk-23.05.0-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
    ["aarch64"]="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/23.05.0/targets/armsr/armv8/openwrt-sdk-23.05.0-armsr-armv8_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
    ["mips"]="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/23.05.0/targets/ath79/generic/openwrt-sdk-23.05.0-ath79-generic_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
    ["mipsel"]="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/23.05.0/targets/ramips/mt76x8/openwrt-sdk-23.05.0-ramips-mt76x8_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
    ["arm"]="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/23.05.0/targets/bcm27xx/bcm2708/openwrt-sdk-23.05.0-bcm27xx-bcm2708_gcc-12.3.0_musl_eabi.Linux-x86_64.tar.xz"
    ["armv7"]="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/23.05.0/targets/bcm27xx/bcm2709/openwrt-sdk-23.05.0-bcm27xx-bcm2709_gcc-12.3.0_musl_eabi.Linux-x86_64.tar.xz"
)

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    echo "OpenList LuCI App 简化编译脚本"
    echo ""
    echo "用法: $0 [选项|架构]"
    echo ""
    echo "支持的架构:"
    echo "  x86_64   - x86 64位 (默认)"
    echo "  aarch64  - ARM 64位"
    echo "  mips     - MIPS 大端序 (ath79)"
    echo "  mipsel   - MIPS 小端序 (ramips)"
    echo "  arm      - ARM 32位 (bcm2708)"
    echo "  armv7    - ARMv7 (bcm2709)"
    echo "  all      - 编译所有支持的架构"
    echo ""
    echo "构建选项:"
    echo "  -f, --fast   - 跳过feeds更新 (适用于重复构建)"
    echo "  --dev        - 开发模式，为包文件名添加时间戳"
    echo ""
    echo "其他选项:"
    echo "  version  - 显示版本信息"
    echo "  clean    - 清理构建文件"
    echo "  help     - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0              # 编译默认架构 (x86_64)"
    echo "  $0 aarch64      # 编译 ARM64"
    echo "  $0 all          # 编译所有支持的架构"
    echo "  $0 -f x86_64    # 快速编译 x86_64 (跳过feeds更新)"
    echo "  $0 --fast       # 快速编译默认架构"
    echo "  $0 --dev x86_64 # 开发模式编译 x86_64 (包含时间戳)"
    echo "  $0 version      # 显示版本信息"
    echo "  $0 clean        # 清理构建文件"
}

# 编译所有架构
build_all_packages() {
    local fast_mode="${1:-false}"
    local dev_mode="${2:-false}"
    local all_archs=("x86_64" "aarch64" "mips" "mipsel" "arm" "armv7")
    local success_count=0
    local failed_archs=()
    
    log_info "开始编译所有支持的架构 $([ "$fast_mode" = "true" ] && echo "(快速模式)" || echo "")"
    log_info "总共需要编译 ${#all_archs[@]} 个架构: ${all_archs[*]}"
    echo ""
    
    for arch in "${all_archs[@]}"; do
        log_info "[${success_count}/${#all_archs[@]}] 开始编译架构: $arch"
        echo "========================================"
        
        if build_package "$arch" "$fast_mode" "$dev_mode"; then
            ((success_count++))
            log_success "架构 $arch 编译成功"
        else
            failed_archs+=("$arch")
            log_error "架构 $arch 编译失败"
        fi
        
        echo ""
    done
    
    # 显示编译结果汇总
    echo "========================================"
    log_info "编译完成汇总:"
    log_success "成功: $success_count/${#all_archs[@]} 个架构"
    
    if [ ${#failed_archs[@]} -gt 0 ]; then
        log_error "失败: ${#failed_archs[@]} 个架构 (${failed_archs[*]})"
        return 1
    else
        log_success "所有架构编译成功！"
        return 0
    fi
}

# 简化的构建函数
build_package() {
    local target_arch="${1:-$DEFAULT_ARCH}"
    local fast_mode="${2:-false}"
    local dev_mode="${3:-false}"
    
    if [[ -z "${ARCH_CONFIG[$target_arch]}" ]]; then
        log_error "不支持的架构: $target_arch"
        log_info "支持的架构: ${!ARCH_CONFIG[*]}"
        return 1
    fi
    
    log_info "编译 OpenList LuCI App [$target_arch] $([ "$fast_mode" = "true" ] && echo "(快速模式)" || echo "")"
    
    # 显示版本信息
    if [ -f "Makefile" ]; then
        log_info "检查版本信息..."
        if command -v make &> /dev/null; then
            make version 2>/dev/null || log_warning "无法显示版本信息"
        fi
    fi
    
    local SDK_URL="${ARCH_CONFIG[$target_arch]}"
    local BUILD_DIR="build-${target_arch}"
    
    # 创建并进入构建目录
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # 下载SDK（如果还没有）
    local SDK_FILE="sdk.tar.xz"
    if [ ! -f "$SDK_FILE" ]; then
        log_info "下载 OpenWrt SDK..."
        log_info "URL: $SDK_URL"
        if ! wget --timeout=30 --tries=3 --progress=bar:force "$SDK_URL" -O "$SDK_FILE"; then
            log_error "SDK下载失败"
            cd ..
            return 1
        fi
    fi
    
    # 解压SDK（如果还没有）
    if [ ! -d "sdk" ]; then
        log_info "解压 SDK..."
        mkdir -p sdk
        tar -xf "$SDK_FILE" --strip-components=1 -C sdk
    fi
    
    cd sdk
    
    # 复制包文件
    log_info "复制包文件..."
    rm -rf package/luci-app-openlistui
    mkdir -p package/luci-app-openlistui
    
    # 只复制必要的文件，包括 root 目录（包含 init.d 脚本）
    cp -r ../../Makefile ../../luasrc ../../po ../../root package/luci-app-openlistui/
    
    # 如果存在 htdocs 目录，也复制
    if [ -d "../../htdocs" ]; then
        cp -r ../../htdocs package/luci-app-openlistui/
    fi
    
    # 更新feeds并安装必要依赖
    if [ "$fast_mode" = "true" ]; then
        log_info "快速模式: 跳过feeds更新"
    else
        log_info "配置清华镜像源..."
        # 备份原始feeds配置
        [ -f feeds.conf.default.bak ] || cp feeds.conf.default feeds.conf.default.bak
        
        # 替换为清华镜像源
        sed -i 's|https://git.openwrt.org/feed/packages.git|https://mirrors.tuna.tsinghua.edu.cn/git/openwrt/feeds/packages.git|g' feeds.conf.default
        sed -i 's|https://git.openwrt.org/project/luci.git|https://mirrors.tuna.tsinghua.edu.cn/git/openwrt/luci.git|g' feeds.conf.default
        sed -i 's|https://git.openwrt.org/feed/routing.git|https://mirrors.tuna.tsinghua.edu.cn/git/openwrt/feeds/routing.git|g' feeds.conf.default
        sed -i 's|https://git.openwrt.org/feed/telephony.git|https://mirrors.tuna.tsinghua.edu.cn/git/openwrt/feeds/telephony.git|g' feeds.conf.default
        
        log_info "更新 feeds (这可能需要几分钟，请耐心等待)..."
        log_info "提示: 使用 -f 或 --fast 选项可跳过此步骤"
        
        # 显示进度的feeds更新
        timeout 300 ./scripts/feeds update -a 2>&1 | while IFS= read -r line; do
            echo "  $line"
        done || {
            log_warning "Feeds更新超时或失败，尝试继续..."
        }
    fi
    
    log_info "安装LuCI依赖包..."
    ./scripts/feeds install luci-base luci-lib-jsonc luci-lib-nixio >/dev/null 2>&1 || true
    
    # 安装构建依赖
    log_info "安装构建依赖..."
    ./scripts/feeds install liblua lua curl wget unzip >/dev/null 2>&1 || true
    
    # 简单配置
    echo "CONFIG_PACKAGE_luci-app-openlistui=y" > .config
    make defconfig >/dev/null 2>&1 || true
    
    # 编译包
    log_info "编译包..."
    
    # 创建构建日志目录
    mkdir -p ../../build-logs
    local build_log="../../build-logs/build-${target_arch}-$(date +%Y%m%d-%H%M%S).log"
    
    if make package/luci-app-openlistui/compile V=s 2>&1 | tee "$build_log"; then
        # 查找并复制IPK文件
        mkdir -p ../../output
        local ipk_file=$(find bin -name "*luci-app-openlistui*.ipk" | head -1)
        if [ -n "$ipk_file" ]; then
            # 从Makefile提取版本号
            local version="unknown"
            if [ -f "../../Makefile" ]; then
                local base_version=$(grep "^PKG_VERSION_BASE:=" ../../Makefile | head -1 | cut -d'=' -f2 | tr -d ' \n\r')
                local patch_version="1"
                if [ -d "../../.git" ]; then
                    patch_version=$(git -C ../.. rev-list --count HEAD 2>/dev/null || echo "1")
                fi
                if [ -n "$base_version" ]; then
                    version="${base_version}.${patch_version}"
                fi
            fi
            
            if [ "$dev_mode" = "true" ]; then
                local output_name="${PKG_NAME}_v${version}_${target_arch}_$(date +%Y%m%d-%H%M%S).ipk"
            else
                local output_name="${PKG_NAME}_v${version}_${target_arch}.ipk"
            fi
            cp "$ipk_file" "../../output/$output_name"
            
            # 生成构建信息文件
            local info_file="../../output/${output_name%.ipk}.info"
            {
                echo "# OpenList UI Build Information"
                echo "Build Date: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "Target Architecture: $target_arch"
                echo "Package Name: $PKG_NAME"
                echo "IPK File: $output_name"
                echo "Build Host: $(whoami)@$(hostname)"
                echo "Build Directory: $PWD"
                echo "Build Log: $build_log"
                if [ -d ../../.git ]; then
                    echo "Git Hash: $(git -C ../.. rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
                    echo "Git Branch: $(git -C ../.. branch --show-current 2>/dev/null || echo 'unknown')"
                fi
                echo ""
                echo "File Information:"
                ls -lh "../../output/$output_name"
            } > "$info_file"
            
            log_success "编译完成！"
            log_info "IPK文件: output/$output_name"
            log_info "构建信息: output/${output_name%.ipk}.info"
            log_info "构建日志: $build_log"
            ls -lh "../../output/$output_name"
        else
            log_error "未找到编译后的IPK文件"
            log_info "构建日志已保存: $build_log"
            cd ../..
            return 1
        fi
    else
        log_error "编译失败"
        log_info "构建日志已保存: $build_log"
        cd ../..
        return 1
    fi
    
    cd ../..
}

# 清理构建文件
clean_build() {
    log_info "清理构建文件..."
    rm -rf build-*
    rm -rf output
    rm -rf build-logs
    rm -rf build-info
    log_success "清理完成"
}

# 显示版本信息
show_version() {
    log_info "OpenList LuCI App 版本信息"
    echo ""
    
    if [ -f "Makefile" ]; then
        # 从Makefile提取版本信息
        if command -v make &> /dev/null; then
            make version 2>/dev/null
        else
            log_warning "make 命令不可用，从Makefile手动提取版本信息"
            
            # 手动解析Makefile中的版本信息
            echo "正在解析Makefile..."
            
            local base_version=$(grep "PKG_VERSION_BASE" Makefile | cut -d'=' -f2 | tr -d ' ')
            local build_date=$(date '+%Y-%m-%d %H:%M:%S')
            local build_host="$(whoami 2>/dev/null || echo 'unknown')@$(hostname 2>/dev/null || echo 'unknown')"
            
            echo "Base Version: $base_version"
            echo "Build Date: $build_date"
            echo "Build Host: $build_host"
            
            if [ -d ".git" ]; then
                local git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')
                local git_branch=$(git branch --show-current 2>/dev/null || echo 'unknown')
                local patch_version=$(git rev-list --count HEAD 2>/dev/null || echo '1')
                
                echo "Git Hash: $git_hash"
                echo "Git Branch: $git_branch"
                echo "Patch Version: $patch_version"
                echo "Full Version: ${base_version}.${patch_version}"
            else
                echo "Git Hash: unknown (not a git repository)"
                echo "Git Branch: unknown"
                echo "Patch Version: 1"
                echo "Full Version: ${base_version}.1"
            fi
        fi
    else
        log_error "Makefile 不存在"
        exit 1
    fi
    
    echo ""
    log_info "版本信息显示完毕"
}
main() {
    local fast_mode=false
    local arch="$DEFAULT_ARCH"
    local build_all=false
    local dev_mode=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            "-f"|"--fast")
                fast_mode=true
                shift
                ;;
            "--dev")
                dev_mode=true
                shift
                ;;
            "help"|"-h"|"--help")
                show_help
                exit 0
                ;;
            "version"|"-v"|"--version")
                show_version
                exit 0
                ;;
            "clean")
                clean_build
                exit 0
                ;;
            "all")
                build_all=true
                shift
                ;;
            *)
                arch="$1"
                shift
                ;;
        esac
    done
    
    # 构建包
    if [ "$build_all" = "true" ]; then
        build_all_packages "$fast_mode" "$dev_mode"
    else
        build_package "$arch" "$fast_mode" "$dev_mode"
    fi
}

# 检查基本环境
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    log_error "此脚本仅支持 Linux 系统"
    exit 1
fi

if ! command -v wget &> /dev/null || ! command -v make &> /dev/null; then
    log_error "请安装必要工具: wget make gcc"
    log_info "Ubuntu/Debian: sudo apt-get install build-essential wget"
    exit 1
fi

main "$@"