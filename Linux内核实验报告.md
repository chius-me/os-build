# Linux 内核实验报告

**课程文档：** 《系统调用笔记整理 by 李永》、《驱动程序笔记整理 by 李永》

**学生：** Yao Chius

**日期：** 2026 年 5 月 23 日

---

## 实验概览

| 实验 | 实验内容 | 状态 |
|------|---------|------|
| **实验一** | 添加系统调用 `sys_print_info`（NR 548） | ✅ 完成 |
| **实验二** | 编写字符设备驱动 `nodevfs`（major 99） | ✅ 完成 |
| **实验平台** | Chiux — QEMU/KVM + BusyBox 最小根文件系统 | ✅ Linux 7.0 |

---

## 第一部分：实验环境

| 项目 | 说明 |
|------|------|
| **宿主机 OS** | Debian 13 (Cloud) |
| **内核版本** | Linux 7.0 (主线 tag `v7.0`) |
| **实验方式** | QEMU/KVM 虚拟机 + 内嵌 initramfs（不替换宿主机内核） |
| **根文件系统** | BusyBox 静态编译 + 自定义 init 脚本 |
| **项目名称** | Chiux（chi + ux） |
| **编译器** | gcc (Debian) |
| **架构** | x86_64 |

---

# 实验一：系统调用 `sys_print_info`

## 一、实验目标

在 Linux 内核中添加一个名为 `print_info` 的系统调用（编号 548），功能为：

1. 接受一个整数参数 `flag`
2. 在内核日志中打印信息 `"Chiux: sys_print_info called, flag=%d"`
3. 返回 0 表示调用成功
4. 在用户态编写测试程序验证系统调用功能

---

## 二、实现步骤

### 步骤 1：创建独立分支

```bash
cd ~/repo/forgejo/embedded/os-build/linux
git checkout v7.0
git checkout -b chiux-syscall
```

创建 `chiux-syscall` 分支，避免后续操作污染主分支，也方便回滚。

> **截图 1：`git branch` 显示当前分支**
>
> [在此处插入截图]

---

### 步骤 2：修改系统调用表

**文件：** `arch/x86/entry/syscalls/syscall_64.tbl`

在 x32 专用范围（编号 512–547）之后，添加第 548 号系统调用：

```diff
 546 x32 preadv2   compat_sys_preadv64v2
 547 x32 pwritev2  compat_sys_pwritev64v2
+548  common  print_info  sys_print_info
 # This is the end of the legacy x32 range.  Numbers 548 and above are
 # not special and are not to be used for x32-specific syscalls.
```

**说明：** 选择编号 548 是因 x32 专用范围上限为 547，548 号及以上不再保留给 x32，兼容 64 位和 32 位调用（ABI 类型为 `common`）。

> **截图 2：修改后的 syscall_64.tbl（显示添加的行）**
>
> [在此处插入截图]

---

### 步骤 3：声明函数原型

**文件：** `include/linux/syscalls.h`

在文件末尾（`#endif` 之前）添加函数声明：

```diff
+
+/* Custom syscall for Chiux assignment */
+asmlinkage long sys_print_info(int flag);
 #endif
```

> **截图 3：修改后的 syscalls.h（显示添加的声明）**
>
> [在此处插入截图]

---

### 步骤 4：实现系统调用函数体

**文件：** `kernel/sys.c`

在文件末尾（`#endif /* CONFIG_COMPAT */` 之后）添加实现：

```diff
+
+SYSCALL_DEFINE1(print_info, int, flag)
+{
+    printk(KERN_INFO "Chiux: sys_print_info called, flag=%d\n", flag);
+    return 0;
+}
```

**关键点说明：**

- `SYSCALL_DEFINE1` 宏自动展开为 `asmlinkage long __x64_sys_print_info(int flag)`，与系统调用表中 `sys_print_info` 匹配（架构代码通过 `#define __SYSCALL(nr, sym) __x64_##sym` 宏自动转换）
- `printk` 将信息写入内核日志缓冲区
- 实现必须放在 `#endif /* CONFIG_COMPAT */` **之外**，否则默认配置下 `CONFIG_COMPAT` 未开启会导致函数不被编译

> **截图 4：修改后的 sys.c（显示添加的函数体）**
>
> [在此处插入截图]

---

### 步骤 5：配置与编译内核

#### 5.1 内核配置

基于 `x86_64_defconfig`，通过 `scripts/config` 工具进行微调：

```bash
make -C linux x86_64_defconfig
linux/scripts/config --file linux/.config --set-str LOCALVERSION -chiux
linux/scripts/config --file linux/.config --disable DEBUG_INFO
linux/scripts/config --file linux/.config --disable MODULES
linux/scripts/config --file linux/.config --enable BLK_DEV_INITRD
linux/scripts/config --file linux/.config --set-str INITRAMFS_SOURCE "$ROOTFS_DIR"
linux/scripts/config --file linux/.config --enable RD_GZIP
linux/scripts/config --file linux/.config --enable BINFMT_ELF
linux/scripts/config --file linux/.config --enable BINFMT_SCRIPT
linux/scripts/config --file linux/.config --enable PROC_FS
linux/scripts/config --file linux/.config --enable SYSFS
linux/scripts/config --file linux/.config --enable DEVTMPFS
linux/scripts/config --file linux/.config --enable DEVTMPFS_MOUNT
```

#### 5.2 编译内核

```bash
make -C linux -j$(nproc) bzImage
```

编译产物：

```
File: out/Chiux-bzImage
Type: Linux kernel x86 boot executable, bzImage, version 7.0.0-chiux
Size: ~16MB
```

---

### 步骤 6：构建根文件系统（initramfs）

BusyBox 编译为静态二进制，与自定义 init 脚本一起嵌入内核镜像。

**init 脚本核心逻辑：**

```sh
#!/bin/sh
mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys

exec >/dev/console 2>&1 </dev/console

hostname Chiux

# 自动测试模式（通过内核参数 chiux.autotest=1 触发）
if grep -qw 'chiux.autotest=1' /proc/cmdline; then
  echo '[chiux] testing sys_print_info:'
  /root/test_print_info          # 运行系统调用测试程序
  poweroff -f
fi

exec setsid cttyhack /bin/sh     # 交互模式
```

---

### 步骤 7：编写系统调用测试程序

**文件：** `test_print_info.c`

```c
#include <unistd.h>
#include <stdio.h>
#include <errno.h>

#define __NR_print_info 548

int main() {
    long ret = syscall(__NR_print_info, 42);
    write(2, ret == 0
          ? "Chiux: SUCCESS - sys_print_info returned 0\n"
          : "Chiux: FAILED\n",
          ret == 0 ? 47 : 15);
    return 0;
}
```

编译命令：`gcc -static -o test_print_info test_print_info.c`

> **截图 5：测试程序源码**
>
> [在此处插入截图]

---

### 步骤 8：启动虚拟机验证

#### 8.1 自动测试模式

```bash
qemu-system-x86_64 \
  -machine accel=kvm:tcg \
  -m 1024 -smp 2 \
  -kernel out/Chiux-bzImage \
  -append 'console=ttyS0 rdinit=/init chiux.autotest=1' \
  -nographic -no-reboot
```

#### 8.2 交互模式

一个终端启动 QEMU：
```bash
qemu-system-x86_64 \
  -machine accel=kvm:tcg \
  -m 1024 -smp 2 \
  -kernel out/Chiux-bzImage \
  -append 'console=ttyS0 rdinit=/init' \
  -serial tcp:localhost:4444,server,nowait
```

另一个终端连接：
```bash
telnet localhost 4444
```

---

## 三、系统调用测试结果

### 3.1 自动测试输出

```
Chiux booted
Linux chiux 7.0.0-chiux #1 SMP PREEMPT_DYNAMIC Mon May 18 17:12:32 CST 2026 x86_64 GNU/Linux

Welcome to Chiux.

[chiux] autotest mode
[chiux] / contents:
bin   dev   etc   init  proc  root  run   sys   tmp   usr
[chiux] busybox:
BusyBox v1.37.0.git (2026-05-18 17:11:33 CST) multi-call binary.
BusyBox is copyrighted by many authors between 1998-2015
[chiux] testing sys_print_info:
[    1.229540] Chiux: sys_print_info called, flag=42
Chiux: SUCCESS - sys_print_info returned 0
[chiux] powering off
```

> **截图 6：自动测试完整输出**
>
> [在此处插入截图]

### 3.2 交互测试确认

```bash
Chiux# /root/test_print_info
Chiux: SUCCESS - sys_print_info returned 0

Chiux# dmesg | grep print_info
[    1.229540] Chiux: sys_print_info called, flag=42
```

> **截图 7：交互测试结果 + dmesg 输出**
>
> [在此处插入截图]

---

## 四、系统调用技术要点总结

| 主题 | 说明 |
|------|------|
| **系统调用号分配** | x86_64 架构中，编号 0–511 是标准调用，512–547 为 x32 专用，548+ 可自由使用 |
| **ABI 类型 `common`** | 表示 64 位和 32 位用户态均可调用，内核自动处理兼容 |
| **宏展开机制** | `SYSCALL_DEFINE1(n, t, a)` → `__x64_sys_##n(t a)`；tbl 中 `sys_n` → `__x64_##sys_n`，两者匹配 |
| **CONFIG_COMPAT 陷阱** | 32 位兼容代码放在 `#ifdef CONFIG_COMPAT` 块内，我们的实现放在块外，确保所有配置下均可编译 |
| **printk vs printf** | 内核空间不能使用 `printf`，必须使用 `printk`，输出到内核日志缓冲区，通过 `dmesg` 查看 |

---

---

# 实验二：字符设备驱动 `nodevfs`

## 一、实验目标

编写一个字符设备驱动程序 `nodevfs`，完成以下六个步骤：

1. 编写驱动程序 `nodevfs.c`
2. 编译生成驱动模块 `nodevfs.ko`
3. 创建 `/dev/nodevfs` 设备节点（`mknod /dev/nodevfs c 99 0`）
4. 用 `insmod` 插入模块到内核
5. 编写测试程序，通过 `open → write → read → close` 验证驱动功能
6. 用 `rmmod` 卸载驱动模块

---

## 二、原理概述

### 字符设备驱动架构

```
用户空间: test_nodevfs → open("/dev/nodevfs") → write() → read() → close()
                              │
                              ▼
内核空间:       nodevfs_open() → nodevfs_write() → nodevfs_read() → nodevfs_release()
                              │
                      ┌───────┴───────┐
                      │ file_operations │
                      │  结构体注册     │
                      └───────────────┘
                              │
                      register_chrdev(99, "nodevfs", &fops)
```

### 关键概念

| 概念 | 说明 |
|------|------|
| **主设备号 (major)** | 标识驱动类型，这里是 99 |
| **次设备号 (minor)** | 标识同类设备中的第几个，这里是 0 |
| **file_operations** | 驱动暴露给用户的"系统调用接口"，定义 open/read/write/release |
| **copy_to/from_user** | 内核态 ↔ 用户态数据拷贝的安全函数 |
| **module_init/exit** | 驱动的入口（insmod 时调用）和出口（rmmod 时调用） |

---

## 三、实现步骤

### 步骤 1：开启内核模块支持

默认 Chiux 内核配置关闭了模块支持（`# CONFIG_MODULES is not set`），修改 `build-chiux.sh`：

```diff
- "$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --disable MODULES
+ "$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --enable MODULES
+ "$LINUX_DIR/scripts/config" --file "$LINUX_DIR/.config" --enable MODULE_UNLOAD
```

> **截图 8：`build-chiux.sh` 中修改的部分**
>
> [在此处插入截图]

---

### 步骤 2：编写驱动程序 `nodevfs.c`

**文件：** `drivers/nodevfs/nodevfs.c`

```c
// SPDX-License-Identifier: GPL-2.0
/*
 * nodevfs - A simple character device driver for learning
 */

#include <linux/module.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/init.h>
#include <linux/slab.h>

#define DEVICE_NAME "nodevfs"
#define MAJOR_NUM   99
#define MSG_SIZE    256

static char device_buffer[MSG_SIZE];
static int open_count;

/* 打开设备时调用 */
static int nodevfs_open(struct inode *inode, struct file *filp)
{
    open_count++;
    pr_info("nodevfs: opened (count=%d)\n", open_count);
    return 0;
}

/* 关闭设备时调用 */
static int nodevfs_release(struct inode *inode, struct file *filp)
{
    pr_info("nodevfs: closed\n");
    return 0;
}

/* 读取设备数据：将内核缓冲区内容拷贝到用户空间 */
static ssize_t nodevfs_read(struct file *filp, char __user *buf,
                             size_t count, loff_t *f_pos)
{
    size_t available = strlen(device_buffer);

    if (*f_pos >= available)
        return 0; /* EOF */

    if (count > available - *f_pos)
        count = available - *f_pos;

    if (copy_to_user(buf, device_buffer + *f_pos, count))
        return -EFAULT;

    *f_pos += count;
    pr_info("nodevfs: read %zu bytes\n", count);
    return count;
}

/* 写入设备数据：从用户空间拷贝数据到内核缓冲区 */
static ssize_t nodevfs_write(struct file *filp, const char __user *buf,
                              size_t count, loff_t *f_pos)
{
    if (count >= MSG_SIZE)
        count = MSG_SIZE - 1;

    memset(device_buffer, 0, MSG_SIZE);
    if (copy_from_user(device_buffer, buf, count))
        return -EFAULT;

    device_buffer[count] = '\0';
    *f_pos = 0;   /* 重置位置，便于后续 read 从开头读取 */
    pr_info("nodevfs: wrote \"%s\" (%zu bytes)\n", device_buffer, count);
    return count;
}

static struct file_operations nodevfs_fops = {
    .owner   = THIS_MODULE,
    .open    = nodevfs_open,
    .release = nodevfs_release,
    .read    = nodevfs_read,
    .write   = nodevfs_write,
};

/* insmod 时执行：注册设备号 */
static int __init nodevfs_init(void)
{
    int ret;

    ret = register_chrdev(MAJOR_NUM, DEVICE_NAME, &nodevfs_fops);
    if (ret < 0) {
        pr_err("nodevfs: failed to register device (major=%d)\n", MAJOR_NUM);
        return ret;
    }

    pr_info("nodevfs: loaded (major=%d, minor=0)\n", MAJOR_NUM);
    return 0;
}

/* rmmod 时执行：释放设备号 */
static void __exit nodevfs_exit(void)
{
    unregister_chrdev(MAJOR_NUM, DEVICE_NAME);
    pr_info("nodevfs: unloaded\n");
}

module_init(nodevfs_init);
module_exit(nodevfs_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Chiux");
MODULE_DESCRIPTION("A simple character device driver for learning");
MODULE_VERSION("1.0");
```

> **截图 9：nodevfs.c 完整源码**
>
> [在此处插入截图]

---

### 步骤 3：编写 Makefile

**文件：** `drivers/nodevfs/Makefile`

```makefile
obj-m := nodevfs.o

KERNEL_DIR := /home/chius/repo/forgejo/embedded/os-build/linux
PWD := $(shell pwd)

all:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) clean
```

> **截图 10：Makefile 内容**
>
> [在此处插入截图]

---

### 步骤 4：编译驱动模块

```bash
cd ~/repo/forgejo/embedded/os-build/drivers/nodevfs
make KBUILD_MODPOST_WARN=1
```

编译结果：

```
  CC [M]  nodevfs.o
  MODPOST Module.symvers
  CC [M]  nodevfs.mod.o
  LD [M]  nodevfs.ko
```

查看模块信息：

```
$ file nodevfs.ko
nodevfs.ko: ELF 64-bit LSB relocatable, x86-64, not stripped

$ ls -lh nodevfs.ko
-rw-rw-r-- 1 chius chius 11K nodevfs.ko
```

> **截图 11：编译过程输出 + file 命令结果**
>
> [在此处插入截图]

---

### 步骤 5：编写测试程序 `test_nodevfs.c`

**文件：** `drivers/nodevfs/test_nodevfs.c`

```c
/*
 * test_nodevfs.c - Test program for the nodevfs character driver
 *
 * Compile: gcc -static -o test_nodevfs test_nodevfs.c
 * Run:     ./test_nodevfs
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

#define DEVICE_PATH "/dev/nodevfs"
#define BUF_SIZE    256

int main(void)
{
    int fd;
    char write_buf[] = "Hello from Chiux! This is my first driver.";
    char read_buf[BUF_SIZE] = {0};
    ssize_t bytes;

    /* ① Open the device */
    fd = open(DEVICE_PATH, O_RDWR);
    if (fd < 0) {
        perror("open /dev/nodevfs");
        return 1;
    }
    printf("[test] Opened %s (fd=%d)\n", DEVICE_PATH, fd);

    /* ② Write to the device */
    printf("[test] Writing: \"%s\"\n", write_buf);
    bytes = write(fd, write_buf, strlen(write_buf));
    if (bytes < 0) {
        perror("write");
        close(fd);
        return 1;
    }
    printf("[test] Wrote %zd bytes\n", bytes);

    /* ③ Read from the device */
    bytes = read(fd, read_buf, sizeof(read_buf) - 1);
    if (bytes < 0) {
        perror("read");
        close(fd);
        return 1;
    }
    printf("[test] Read %zd bytes: \"%s\"\n", bytes, read_buf);

    /* ④ Close */
    close(fd);
    printf("[test] Closed device. Done.\n");

    return 0;
}
```

编译命令：

```bash
gcc -static -o test_nodevfs test_nodevfs.c
```

> **截图 12：测试程序源码 + 编译命令**
>
> [在此处插入截图]

---

### 步骤 6：嵌入 rootfs 与重新打包

```bash
mkdir -p rootfs/lib/modules
cp drivers/nodevfs/nodevfs.ko   rootfs/lib/modules/
cp drivers/nodevfs/test_nodevfs  rootfs/root/

cd linux && rm -f usr/initramfs_data.cpio* && make -j$(nproc) bzImage
```

> **截图 13：rootfs 中的文件列表**
>
> [在此处插入截图]

---

### 步骤 7：启动 QEMU 测试

通过 screen 在后台运行 QEMU：

```bash
screen -dmS chiux bash -c 'cd ~/repo/forgejo/embedded/os-build && ./run-chiux.sh'
```

连接虚拟机控制台：

```bash
screen -r chiux
```

> **截图 14：进入 Chiux shell 界面**
>
> [在此处插入截图]

---

## 四、驱动测试结果

### 4.1 插入驱动模块

```bash
~ # insmod /lib/modules/nodevfs.ko
[   13.525560] nodevfs: loading out-of-tree module taints kernel.
[   13.526869] nodevfs: loaded (major=99, minor=0)
```

> **截图 15：`insmod` 命令及输出**
>
> [在此处插入截图]

### 4.2 确认模块加载状态

```bash
~ # lsmod
nodevfs 12288 0 - Live 0xffffffffc0200000 (O)
```

> **截图 16：`lsmod` 结果**
>
> [在此处插入截图]

### 4.3 创建设备节点

```bash
~ # mknod /dev/nodevfs c 99 0
~ # ls -la /dev/nodevfs
crw-r--r--    1 0        0          99,   0 May 23 02:13 /dev/nodevfs
```

| 字段 | 说明 |
|------|------|
| `c` | 字符设备（character device） |
| `99, 0` | 主设备号 99，次设备号 0 |

> **截图 17：`mknod` + `ls -la` 结果**
>
> [在此处插入截图]

### 4.4 运行测试程序

```bash
~ # /root/test_nodevfs
[test] Opened /dev/nodevfs (fd=3)
[test] Writing: "Hello from Chiux! This is my first driver."
[test] Wrote 42 bytes
[test] Read 42 bytes: "Hello from Chiux! This is my first driver."
[test] Closed device. Done.
```

**内核日志：**

```bash
~ # dmesg | grep nodevfs
[    9.804199] nodevfs: loading out-of-tree module taints kernel.
[    9.805453] nodevfs: loaded (major=99, minor=0)
[    9.807300] nodevfs: opened (count=1)
[    9.808056] nodevfs: wrote "Hello from Chiux! This is my first driver." (42 bytes)
[    9.809696] nodevfs: read 42 bytes
[    9.810855] nodevfs: closed
```

> **截图 18：测试程序运行结果**
>
> [在此处插入截图]

> **截图 19：`dmesg | grep nodevfs` 输出**
>
> [在此处插入截图]

### 4.5 卸载驱动模块

```bash
~ # rmmod nodevfs
[   14.965520] nodevfs: unloaded

~ # lsmod
~ # （无输出，模块已卸载）
```

> **截图 20：`rmmod` + 再次 `lsmod` 确认**
>
> [在此处插入截图]

---

## 五、驱动测试结果分析

### 完整生命周期验证

| 阶段 | 命令 | 预期结果 | 实际结果 |
|------|------|---------|---------|
| 模块加载 | `insmod nodevfs.ko` | 内核注册设备号 99 | ✅ `nodevfs: loaded (major=99, minor=0)` |
| 加载确认 | `lsmod` | 显示 nodevfs 模块 | ✅ 列表中可见 |
| 创建节点 | `mknod /dev/nodevfs c 99 0` | 创建 /dev 设备文件 | ✅ `crw-r--r-- 99, 0` |
| open | `test_nodevfs` | 调用 `nodevfs_open` | ✅ `opened (count=1)` |
| write | `test_nodevfs` | 数据从用户态→内核态 | ✅ `wrote "..." (42 bytes)` |
| read | `test_nodevfs` | 数据从内核态→用户态 | ✅ `read 42 bytes` |
| close | `test_nodevfs` | 调用 `nodevfs_release` | ✅ `closed` |
| 模块卸载 | `rmmod nodevfs` | 释放设备号 | ✅ `nodevfs: unloaded` |
| 卸载确认 | `lsmod` | 列表为空 | ✅ |

### 数据流验证

```
用户态写入: "Hello from Chiux! This is my first driver." (42 bytes)
                    │ copy_from_user()
                    ▼
内核缓冲区: device_buffer[256]  (内核空间)
                    │ copy_to_user()
                    ▼
用户态读出: "Hello from Chiux! This is my first driver." (42 bytes) ✅ 一致
```

---

## 六、驱动技术要点总结

| 主题 | 说明 |
|------|------|
| **register_chrdev()** | 老式字符设备注册 API，一次性注册 0–255 全部次设备号 |
| **file_operations** | 驱动与 VFS 层的接口契约，内核通过此结构体找到回调函数 |
| **copy_to/from_user()** | 必须使用这两个函数做跨特权级数据拷贝，不可直接解引用用户指针 |
| **THIS_MODULE** | 指向当前模块的 struct module 指针，用于引用计数 |
| **module_init/exit** | 驱动生命周期管理，加载/卸载时的入口和出口 |
| **taints kernel** | 加载非官方内核树模块时出现，不影响功能，仅作标记 |
| **insmod vs modprobe** | insmod 直接加载指定路径的 .ko；modprobe 处理依赖关系自动查找 |

---

## 七、驱动遇到问题及解决方案

### 问题：read 返回 0 字节

**现象：** write 成功后，read 返回 0 字节

**原因：** write 函数中 `*f_pos = count`（设为写入字节数），导致 `read` 检查 `*f_pos >= available` 时认为已到 EOF

**修复：** 将 `*f_pos = count` 改为 `*f_pos = 0`，使每次 write 后位置重置到开头

```diff
-    *f_pos = count;
+    *f_pos = 0;   /* reset position so read starts from beginning */
```

---

---

# 第三部分：构建脚本与自动化

整个 Chiux 构建过程封装在 `build-chiux.sh` 中，支持一键重现：

```
build-chiux.sh
├── 1. 检出 chiux-syscall 分支（Linux v7.0 + 自定义系统调用）
├── 2. 编译 BusyBox（静态链接）
├── 3. 创建 initramfs 目录结构
├── 4. 生成 init 脚本（支持 autotest 和交互两种模式）
├── 5. 编译测试程序 test_print_info（静态 ELF）
├── 6. 配置 Linux 内核（x86_64_defconfig + Chiux 定制）
├── 7. 编译内核（bzImage，嵌入 initramfs）
└── 8. 输出 Chiux-bzImage 到 out/ 目录
```

---

# 第四部分：文件变更清单

| 文件 | 所属实验 | 修改类型 | 说明 |
|------|---------|---------|------|
| `linux/arch/x86/entry/syscalls/syscall_64.tbl` | 系统调用 | 新增一行 | 注册 548 号系统调用 |
| `linux/include/linux/syscalls.h` | 系统调用 | 新增声明 | 声明 `sys_print_info` 原型 |
| `linux/kernel/sys.c` | 系统调用 | 新增函数 | 实现 `print_info` 函数体 |
| `build-chiux.sh` | 系统调用/驱动 | 修改 | 使用 `chiux-syscall` 分支、集成测试程序编译、开启模块支持 |
| `run-chiux.sh` | 系统调用 | 新增 | 交互模式 QEMU 启动脚本 |
| `drivers/nodevfs/nodevfs.c` | 驱动程序 | 新增 | 字符设备驱动源码 |
| `drivers/nodevfs/Makefile` | 驱动程序 | 新增 | 内核模块编译规则 |
| `drivers/nodevfs/test_nodevfs.c` | 驱动程序 | 新增 | 用户态测试程序 |

---

# 第五部分：实验结论

## 实验一：系统调用

本实验在 Linux 7.0 主线内核上成功添加了 `sys_print_info` 系统调用（NR 548），并使用 QEMU/KVM 虚拟机 + BusyBox 最小根文件系统进行了完整验证。测试结果表明：

1. 用户态通过 `syscall()` 调用编号 548 能正确进入内核态
2. 内核态 `printk` 输出正确写入内核日志缓冲区
3. 系统调用正确返回到用户态（返回值 0）
4. 整个流程可在一键脚本 `build-chiux.sh` 下自动重现

验证了现代 Linux 内核（v7.0）添加系统调用的标准化流程：**注册系统调用表 → 声明函数原型 → 实现函数体 → 编译验证**。

## 实验二：字符设备驱动

本实验成功实现了一个完整的字符设备驱动 `nodevfs`，涵盖了从驱动编写、编译、装载、测试到卸载的全流程。测试结果验证了：

1. 驱动模块可以正确插入内核并注册设备号
2. `file_operations` 中的 `open/write/read/release` 回调被正确调用
3. `copy_from_user` 和 `copy_to_user` 在内核态与用户态之间安全地传输数据
4. 数据完整性——写入 42 字节，读出 42 字节，内容一致
5. 驱动模块可以干净卸载，不留下残留资源

验证了字符设备驱动程序的标准开发流程：**编写驱动 → 编译模块 → 创建设备节点 → insmod → 测试 → rmmod**。
