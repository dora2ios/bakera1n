/*
 * bakera1n - fake_dyld_utils.c
 *
 * Copyright (c) 2023 dora2ios
 *
 */

#include <stdint.h>
#include "printf.h"
#include "log.h"
#include "fake_dyld_utils.h"

static __attribute__((naked)) kern_return_t thread_switch(mach_port_t new_thread, int option, mach_msg_timeout_t time) {
    asm(
        "movn x16, #0x3c    \n"
        "svc 0x80           \n"
        "ret                \n"
        );
}

static __attribute__((naked)) uint64_t msyscall(uint64_t syscall, ...) {
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
    return msyscall(90, from, to);
}

int stat(void *path, void *ub)
{
    return msyscall(188, path, ub);
}

int mount(char *type, char *path, int flags, void *data)
{
    return msyscall(167, type, path, flags, data);
}

void *mmap(void *addr, size_t length, int prot, int flags, int fd, uint64_t offset)
{
    return (void *)msyscall(197, addr, length, prot, flags, fd, offset);
}

uint64_t write(int fd, void* cbuf, size_t nbyte)
{
    return msyscall(4, fd, cbuf, nbyte);
}

int close(int fd)
{
    return msyscall(6, fd);
}

int open(void *path, int flags, int mode)
{
    return msyscall(5, path, flags, mode);
}

int execve(char *fname, char *const argv[], char *const envp[])
{
    return msyscall(59, fname, argv, envp);
}

int unlink(void *path)
{
    return msyscall(10, path);
}

uint64_t read(int fd, void *cbuf, size_t nbyte)
{
    return msyscall(3, fd, cbuf, nbyte);
}

uint64_t lseek(int fd, int32_t offset, int whence)
{
    return msyscall(199, fd, offset, whence);
}

int mkdir(char* path, int mode)
{
    return msyscall(136, path, mode);
}


void _putchar(char character)
{
    static size_t chrcnt = 0;
    static char buf[0x100];
    buf[chrcnt++] = character;
    if (character == '\n' || chrcnt == sizeof(buf)){
        write(STDOUT_FILENO, buf, chrcnt);
        chrcnt = 0;
    }
}

void spin(void)
{
    ERR("WTF?!");
    while(1) {
        sleep(1);
    }
}

void memcpy(void *dst, void *src, size_t n)
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

