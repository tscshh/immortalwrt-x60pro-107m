#!/bin/bash
#
# ImmortalWrt 25.10 编译脚本 - 锐捷 X60 PRO (Yuzhii U-Boot 107M布局)
# 纯净版 (Clean Version)
#
# 使用方法:
#   chmod +x build.sh
#   ./build.sh
#
# 前置条件:
#   - Ubuntu 22.04/24.04 或 Debian 12 (推荐)
#   - 至少 4GB RAM, 30GB 磁盘空间
#   - 非 root 用户运行
#

set -e

# ============ 配置 ============
WORK_DIR="$HOME/immortalwrt-build"
IMMORTALWRT_VERSION="v25.10"
DEVICE_NAME="ruijie_rg-x60-pro-107m"
JOBS=$(nproc)

# 脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "ImmortalWrt 25.10 编译 - 锐捷 X60 PRO 107M"
echo "============================================"
echo "工作目录: $WORK_DIR"
echo "CPU核心数: $JOBS"
echo ""

# ============ 1. 安装依赖 ============
echo "[1/6] 安装编译依赖..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y \
        build-essential clang flex bison g++ gawk \
        gcc-multilib g++-multilib gettext git libncurses5-dev \
        libssl-dev python3-distutils python3-setuptools rsync \
        swig unzip zlib1g-dev file wget python3-pyelftools \
        libelf-dev ecj fastjar java-propose-classpath \
        python3 python2.7-dev python2.7 \
        time xsltproc docbook-utils fop dblatex xmlto \
        genisoimage grub-common p7zip-full
    echo "依赖安装完成"
else
    echo "警告: 无法自动安装依赖，请手动安装编译依赖"
fi

# ============ 2. 克隆源码 ============
echo ""
echo "[2/6] 克隆 ImmortalWrt $IMMORTALWRT_VERSION 源码..."
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

if [ ! -d "immortalwrt" ]; then
    git clone --depth 1 -b "$IMMORTALWRT_VERSION" https://github.com/immortalwrt/immortalwrt.git
    cd immortalwrt
else
    cd immortalwrt
    git fetch --depth 1 origin "$IMMORTALWRT_VERSION"
    git checkout "$IMMORTALWRT_VERSION"
    git clean -fdx
fi

echo "源码克隆完成"

# ============ 3. 应用107M布局修改 ============
echo ""
echo "[3/6] 应用107M布局设备树和设备定义..."

# 复制修改后的DTS文件
cp "$SCRIPT_DIR/mt7986a-ruijie-rg-x60-pro-107m.dts" \
   target/linux/mediatek/dts/mt7986a-ruijie-rg-x60-pro-107m.dts

# 应用filogic.mk补丁
if grep -q "ruijie_rg-x60-pro-107m" target/linux/mediatek/image/filogic.mk; then
    echo "filogic.mk 已包含107m设备定义，跳过"
else
    # 在ruijie_rg-x60-pro定义后插入107m定义
    cat >> /tmp/filogic_patch.py << 'PYEOF'
import re

with open('target/linux/mediatek/image/filogic.mk', 'r') as f:
    content = f.read()

# 在 TARGET_DEVICES += ruijie_rg-x60-pro 之后插入107m设备定义
insert_after = "TARGET_DEVICES += ruijie_rg-x60-pro\n"
new_device_def = """

define Device/ruijie_rg-x60-pro-107m
  DEVICE_VENDOR := Ruijie
  DEVICE_MODEL := RG-X60 Pro
  DEVICE_VARIANT := 107M (Yuzhii U-Boot Layout)
  DEVICE_DTS := mt7986a-ruijie-rg-x60-pro-107m
  DEVICE_DTS_DIR := ../dts
  DEVICE_PACKAGES := kmod-mt7986-firmware mt7986-wo-firmware
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += ruijie_rg-x60-pro-107m
"""

if insert_after in content:
    content = content.replace(insert_after, insert_after + new_device_def)
    with open('target/linux/mediatek/image/filogic.mk', 'w') as f:
        f.write(content)
    print("107m设备定义已添加到filogic.mk")
else:
    print("错误: 找不到ruijie_rg-x60-pro定义，请手动修改filogic.mk")
    exit(1)
PYEOF
    python3 /tmp/filogic_patch.py
    rm -f /tmp/filogic_patch.py
fi

echo "107M布局修改完成"

# ============ 4. 更新feeds ============
echo ""
echo "[4/6] 更新和安装 feeds..."
./scripts/feeds update -a
./scripts/feeds install -a
echo "feeds更新完成"

# ============ 5. 配置 ============
echo ""
echo "[5/6] 加载纯净版配置..."

# 使用配置种子
cp "$SCRIPT_DIR/config.107m-clean.seed" .config.seed

# 生成完整配置
make defconfig

# 验证配置
if grep -q "CONFIG_TARGET_mediatek_filogic_DEVICE_ruijie_rg-x60-pro-107m=y" .config; then
    echo "配置验证通过: 设备已正确选择"
else
    echo "错误: 配置验证失败，请检查.config"
    exit 1
fi

echo "配置完成"

# ============ 6. 编译 ============
echo ""
echo "[6/6] 开始编译 (使用 $JOBS 个核心)..."
echo "这可能需要 1-3 小时，请耐心等待..."
echo ""

# 下载所有源码包
make download -j$JOBS

# 编译
make -j$JOBS V=s 2>&1 | tee build.log

# ============ 完成 ============
echo ""
echo "============================================"
echo "编译完成！"
echo "============================================"

FIRMWARE_DIR="bin/targets/mediatek/filogic"
if ls "$FIRMWARE_DIR"/immortalwrt-*"$DEVICE_NAME"*sysupgrade.bin 1> /dev/null 2>&1; then
    echo "固件文件位置:"
    ls -lh "$FIRMWARE_DIR"/immortalwrt-*"$DEVICE_NAME"*
    echo ""
    echo "sysupgrade固件: $(ls $FIRMWARE_DIR/immortalwrt-*$DEVICE_NAME*squashfs-sysupgrade.bin)"
    echo "initramfs固件: $(ls $FIRMWARE_DIR/immortalwrt-*$DEVICE_NAME*initramfs-kernel.bin 2>/dev/null || echo '未生成')"
else
    echo "警告: 未找到生成的固件文件，请检查编译日志"
    echo "日志文件: $WORK_DIR/immortalwrt/build.log"
    exit 1
fi

echo ""
echo "编译完成！"
