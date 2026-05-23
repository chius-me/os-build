/*
 * test_nodevfs.c - Test program for the nodevfs character driver
 *
 * Compile: gcc -static -o test_nodevfs test_nodevfs.c
 * Run:     ./test_nodevfs
 *
 * What it does:
 *   - Opens /dev/nodevfs
 *   - Writes a message to it
 *   - Reads the message back
 *   - Prints the result
 *   - Closes the device
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
