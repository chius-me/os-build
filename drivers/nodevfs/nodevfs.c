// SPDX-License-Identifier: GPL-2.0
/*
 * nodevfs - A simple character device driver for learning
 *
 * Usage:
 *   - insmod  nodevfs.ko
 *   - mknod   /dev/nodevfs c 99 0
 *   - echo "hello" > /dev/nodevfs
 *   - cat /dev/nodevfs
 *   - rmmod   nodevfs
 */

#include <linux/module.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/init.h>
#include <linux/slab.h>

#define DEVICE_NAME "nodevfs"
#define MAJOR_NUM   99
#define MSG_SIZE    256

/* Driver buffer: anything written to the device is stored here */
static char device_buffer[MSG_SIZE];
static int open_count;

/* Called when userspace opens /dev/nodevfs */
static int nodevfs_open(struct inode *inode, struct file *filp)
{
    open_count++;
    pr_info("nodevfs: opened (count=%d)\n", open_count);
    return 0;
}

/* Called when userspace closes /dev/nodevfs */
static int nodevfs_release(struct inode *inode, struct file *filp)
{
    pr_info("nodevfs: closed\n");
    return 0;
}

/* Called when userspace reads from /dev/nodevfs */
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

/* Called when userspace writes to /dev/nodevfs */
static ssize_t nodevfs_write(struct file *filp, const char __user *buf,
                              size_t count, loff_t *f_pos)
{
    if (count >= MSG_SIZE)
        count = MSG_SIZE - 1;

    memset(device_buffer, 0, MSG_SIZE);
    if (copy_from_user(device_buffer, buf, count))
        return -EFAULT;

    device_buffer[count] = '\0';
    *f_pos = 0;   /* reset position so read starts from beginning */
    pr_info("nodevfs: wrote \"%s\" (%zu bytes)\n", device_buffer, count);
    return count;
}

/* File operations that the kernel will call on our device */
static struct file_operations nodevfs_fops = {
    .owner   = THIS_MODULE,
    .open    = nodevfs_open,
    .release = nodevfs_release,
    .read    = nodevfs_read,
    .write   = nodevfs_write,
};

/* Called when the module is loaded (insmod) */
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

/* Called when the module is unloaded (rmmod) */
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
