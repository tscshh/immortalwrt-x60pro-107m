#!/usr/bin/env python3
"""为 ImmortalWrt filogic.mk 添加 WR30U 112M (Yuzhii U-Boot 布局) 设备定义。"""
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

marker = 'TARGET_DEVICES += xiaomi_mi-router-wr30u-stock\n'
addition = '''
define Device/xiaomi_mi-router-wr30u-112m
  DEVICE_VENDOR := Xiaomi
  DEVICE_MODEL := Mi Router WR30U
  DEVICE_VARIANT := (Yuzhii U-Boot 112M layout)
  DEVICE_DTS := mt7981b-xiaomi-mi-router-wr30u-112m
  DEVICE_DTS_DIR := ../dts
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 114688k
  KERNEL_IN_UBI := 1
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware luci-app-upnp luci-i18n-upnp-zh-cn
  IMAGES += factory.bin
  IMAGE/factory.bin := append-ubi | check-size $$$$(IMAGE_SIZE)
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += xiaomi_mi-router-wr30u-112m
'''

if marker not in content:
    print('ERROR: xiaomi_mi-router-wr30u-stock definition not found')
    sys.exit(1)

content = content.replace(marker, marker + addition, 1)
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('112m device definition added')
