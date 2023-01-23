/*
 * bakera1n - dyld_utils.c
 *
 * Copyright (c) 2023 dora2ios
 *
 */

#include <stdint.h>
#include <plog.h>

#include "printf.h"
#include "dyld_utils.h"

static __attribute__((naked)) kern_return_t thread_switch(mach_port_t new_thread, int option, mach_msg_timeout_t time)
{
    asm(
        "movn x16, #0x3c    \n"
        "svc 0x80           \n"
        "ret                \n"
        );
}

static __attribute__((naked)) uint64_t msyscall(uint64_t syscall, ...)
{
    asm(
        "mov x16, x0            \n"
        "ldp x0, x1, [sp]       \n"
        "ldp x2, x3, [sp, 0x10] \n"
        "ldp x4, x5, [sp, 0x20] \n"
        "ldp x6, x7, [sp, 0x30] \n"
        "svc 0x80               \n"
        "ret                    \n"
        );
}

void sleep(int secs)
{
    thread_switch(0, 2, secs*0x400);
}

int sys_dup2(int from, int to)
{
    return msyscall(SYS_dup2, from, to);
}

int stat(const char *path, void *ub)
{
    return msyscall(SYS_stat, path, ub);
}

int mount(const char *type, const char *path, int flags, void *data)
{
    return msyscall(SYS_mount, type, path, flags, data);
}

void *mmap(void *addr, size_t length, int prot, int flags, int fd, uint64_t offset)
{
    return (void *)msyscall(SYS_mmap, addr, length, prot, flags, fd, offset);
}

uint64_t write(int fd, const void *cbuf, size_t nbyte)
{
    return msyscall(SYS_write, fd, cbuf, nbyte);
}

int close(int fd)
{
    return msyscall(SYS_close, fd);
}

int open(const char *path, int flags, int mode)
{
    return msyscall(SYS_open, path, flags, mode);
}

int execve(const char *fname, char *const argv[], char *const envp[])
{
    return msyscall(SYS_execve, fname, argv, envp);
}

int unlink(const char *path)
{
    return msyscall(SYS_unlink, path);
}

uint64_t read(int fd, void *cbuf, size_t nbyte)
{
    return msyscall(SYS_read, fd, cbuf, nbyte);
}

uint64_t lseek(int fd, int32_t offset, int whence)
{
    return msyscall(SYS_lseek, fd, offset, whence);
}

int mkdir(const char *path, int mode)
{
    return msyscall(SYS_mkdir, path, mode);
}

int sys_sysctlbyname(const char *name, size_t namelen, void *old, size_t *oldlenp, void *new, size_t newlen)
{
    return msyscall(274, name, namelen, old, oldlenp, new, newlen);
}

void _putchar(char character)
{
    static size_t chrcnt = 0;
    static char buf[0x100];
    buf[chrcnt++] = character;
    if (character == '\n' || chrcnt == sizeof(buf))
    {
        write(STDOUT_FILENO, buf, chrcnt);
        chrcnt = 0;
    }
}

void spin(void)
{
    ERR("WTF?!");
    while(1)
        sleep(1);
}

void memcpy(void *dst, const void *src, size_t n)
{
    uint8_t *s =(uint8_t *)src;
    uint8_t *d =(uint8_t *)dst;
    for (size_t i = 0; i < n; i++) *d++ = *s++;
}

void memset(void *dst, int c, size_t n)
{
    uint8_t *d =(uint8_t *)dst;
    for (size_t i = 0; i < n; i++) *d++ = c;
}

int mount_bindfs(const char* mountpoint, void* dir)
{
    return mount("bindfs", mountpoint, 0, dir);
}

int mount_devfs(const char* mountpoint)
{
    char *path = "devfs";
    return mount("devfs", mountpoint, 0, path);
}

int deploy_file_from_memory(char* path, const void *buf, size_t size)
{
    unlink(path);
    int fd = open(path, O_WRONLY|O_CREAT, 0755);
    if (fd == -1)
        return -1;
    write(fd, buf, size);
    close(fd);
    return 0;
}
