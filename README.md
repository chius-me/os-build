# Chiux

一个最小可启动 Linux 系统，用于 Linux 内核编程学习。

基于 QEMU/KVM + BusyBox 最小根文件系统 + 内嵌 initramfs，单文件可启动内核镜像。

## 快速开始

```bash
# 一键构建
./build-chiux.sh

# 交互模式启动（screen 分离）
screen -dmS chiux bash -c './run-chiux.sh'

# 连接 QEMU 控制台
screen -r chiux
```

## 目录结构

```
├── build-chiux.sh           # 一键构建脚本（编译内核 + rootfs + 测试程序）
├── run-chiux.sh             # QEMU 交互模式启动脚本
├── drivers/
│   └── nodevfs/             # 字符设备驱动实验
│       ├── nodevfs.c        # 驱动源码（major 99）
│       ├── Makefile          # 内核模块编译规则
│       └── test_nodevfs.c    # 驱动测试程序
├── rootfs/
│   ├── init                 # initramfs 入口脚本
│   └── root/
│       ├── test_print_info  # 系统调用测试程序（静态编译）
│       └── test_nodevfs     # 驱动测试程序（静态编译）
└── out/
    └── Chiux-bzImage        # 构建产物：可启动内核镜像
```

## 实验内容

### 实验一：系统调用 `sys_print_info`（NR 548）

在 Linux v7.0 中添加自定义系统调用，编号 548，功能为在内核日志中打印传入的参数。

- 修改文件：`arch/x86/entry/syscalls/syscall_64.tbl`、`include/linux/syscalls.h`、`kernel/sys.c`
- 测试：`screen -r chiux` → `/root/test_print_info`

### 实验二：字符设备驱动 `nodevfs`（major 99）

编写一个完整的字符设备驱动，实现 `open/write/read/close` 四个回调函数。

- 源码：`drivers/nodevfs/nodevfs.c`
- 测试流程：
  ```bash
  insmod /lib/modules/nodevfs.ko
  mknod /dev/nodevfs c 99 0
  /root/test_nodevfs
  rmmod nodevfs
  ```

## 构建产物

```bash
./build-chiux.sh
```

脚本自动完成：
1. 检出 `chiux-syscall` 分支（Linux v7.0 + 自定义系统调用）
2. 编译 BusyBox（静态链接）
3. 创建 initramfs 目录结构
4. 生成 init 脚本
5. 编译测试程序
6. 配置并编译 Linux 内核（bzImage，嵌入 initramfs）
7. 输出 `Chiux-bzImage` 到 `out/` 目录

## 依赖

- qemu-system-x86_64
- gcc, make
- git
- rsync
- (可选) KVM: 将用户加入 `kvm` 组

## 关键来源

- Linux: `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` (tag `v7.0`)
- BusyBox: `https://git.busybox.net/busybox` (commit `fb10ad3`)
