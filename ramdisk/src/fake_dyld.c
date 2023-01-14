/*
 * bakera1n - fake_dyld.c
 *
 * Copyright (c) 2023 dora2ios
 *
 */

#include <stdint.h>
#include "printf.h"
#include "log.h"
#include "fake_dyld_utils.h"

#include "haxx_dylib.h"
#include "haxz_dylib.h"
#include "haxx.h"
#include "loaderd.h"
#include "fakedyld.h"
#include "fsutil.h"

asm(
    ".globl __dyld_start    \n"
    ".align 4               \n"
    "__dyld_start:          \n"
    "movn x8, #0xf          \n"
    "mov  x7, sp            \n"
    "and  x7, x7, x8        \n"
    "mov  sp, x7            \n"
    "bl   _main             \n"
    "movz x16, #0x1         \n"
    "svc  #0x80             \n"
    );

static checkrain_option_t pflags;
static char *root_device = NULL;
static int isOS = 0;
static char statbuf[0x400];

static inline __attribute__((always_inline)) int checkrain_option_enabled(checkrain_option_t flags, checkrain_option_t opt)
{
    if(flags == checkrain_option_failure)
    {
        switch(opt)
        {
            case checkrain_option_safemode:
                return 1;
            default:
                return 0;
        }
    }
    return (flags & opt) != 0;
}

static inline __attribute__((always_inline)) int getFlags(void)
{
    uint32_t err = 0;
    
    size_t sz = 0;
    struct kerninfo info;
    int fd = open("/dev/rmd0", O_RDONLY|O_RDWR, 0);
    if (fd >= 0x1)
    {
        read(fd, &sz, 4);
        lseek(fd, (long)(sz), SEEK_SET);
        if(read(fd, &info, sizeof(struct kerninfo)) == sizeof(struct kerninfo))
        {
            pflags = info.flags;
            LOG("got flags: %d from stage1", pflags);
            err = 0;
        } else
        {
            ERR("Read kinfo failed");
            err = -1;
        }
        close(fd);
    }
    else
    {
        ERR("Open rd failed");
        err = -1;
    }
    
    return err;
}


static inline __attribute__((always_inline)) int main2_bindfs(void)
{
    
    LOG("Remounting fs");
    {
        char *path = ROOTFS_RAMDISK;
        if (mount("hfs", "/", MNT_UPDATE, &path))
        {
            FATAL("Failed to remount ramdisk");
            goto fatal_err;
        }
    }
    
    LOG("unlinking dyld");
    {
        unlink(CUSTOM_DYLD_PATH);
        if (!stat(CUSTOM_DYLD_PATH, statbuf))
        {
            FATAL("Why does that %s exist!?", CUSTOM_DYLD_PATH);
            goto fatal_err;
        }
    }
    
    LOG("Remounting fs");
    {
        char *path = ROOTFS_RAMDISK;
        if (mount("hfs", "/", MNT_UPDATE|MNT_RDONLY, &path))
        {
            ERR("Failed to remount ramdisk, why?");
        }
    }
    
    {
        char *mntpath = "/fs/orig";
        LOG("Mounting snapshot to %s", mntpath);
        
        int err = 0;
        char buf[0x100];
        struct mounarg {
            char *path;
            uint64_t _null;
            uint64_t mountAsRaw;
            uint32_t _pad;
            char snapshot[0x100];
        } arg = {
            root_device,
            0,
            MOUNT_WITH_SNAPSHOT,
            0,
        };
        
    retry_rootfs_mount:
        err = mount("apfs", mntpath, MNT_RDONLY, &arg);
        if (err)
        {
            ERR("Failed to mount rootfs (%d)", err);
            sleep(1);
        }
        
        if (stat("/fs/orig/private/", statbuf))
        {
            ERR("Failed to find directory, retry.");
            sleep(1);
            goto retry_rootfs_mount;
        }
    }
    
    LOG("Binding rootfs");
    {
        if (mount_bindfs("/Applications",   "/fs/orig/Applications")) goto error_bindfs;
        if (mount_bindfs("/Library",        "/fs/orig/Library")) goto error_bindfs;
        if (mount_bindfs("/bin",            "/fs/orig/bin")) goto error_bindfs;
        if (mount_bindfs("/sbin",           "/fs/orig/sbin")) goto error_bindfs;
        if (mount_bindfs("/usr",            "/fs/orig/usr")) goto error_bindfs;
        if (mount_bindfs("/private/etc",    "/fs/orig/private/etc")) goto error_bindfs;
        if (mount_bindfs("/System",         "/fs/orig/System")) goto error_bindfs;
        
        if(0)
        {
        error_bindfs:
            FATAL("Failed to bind mount");
            goto fatal_err;
        }
    }
    
    void *data = mmap(NULL, 0x4000, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    DEVLOG("data: 0x%016llx", data);
    if (data == (void*)-1)
    {
        FATAL("Failed to mmap");
        goto fatal_err;
    }
    
    {
        if (stat(LAUNCHD_PATH, statbuf))
        {
            FATAL("%s: No such file or directory", LAUNCHD_PATH);
            goto fatal_err;
        }
        if (stat(PAYLOAD_PATH, statbuf))
        {
            FATAL("%s: No such file or directory", PAYLOAD_PATH);
            goto fatal_err;
        }
        if (stat(LIBRARY_PATH, statbuf))
        {
            FATAL("%s: No such file or directory", PAYLOAD_PATH);
            goto fatal_err;
        }
    }
    
    /*
     Launchd doesn't like it when the console is open already
     */
    
    for (size_t i = 0; i < 10; i++)
        close(i);
    
    int err = 0;
    {
        char **argv = (char **)data;
        char **envp = argv+2;
        char *strbuf = (char*)(envp+2);
        argv[0] = strbuf;
        argv[1] = NULL;
        memcpy(strbuf, LAUNCHD_PATH, sizeof(LAUNCHD_PATH));
        strbuf += sizeof(LAUNCHD_PATH);
        envp[0] = strbuf;
        envp[1] = NULL;
        
        char dyld_insert_libs[] = "DYLD_INSERT_LIBRARIES";
        char dylibs[] = LIBRARY_PATH;
        uint8_t eqBuf = 0x3D;
        
        memcpy(strbuf, dyld_insert_libs, sizeof(dyld_insert_libs));
        memcpy(strbuf+sizeof(dyld_insert_libs)-1, &eqBuf, 1);
        memcpy(strbuf+sizeof(dyld_insert_libs)-1+1, dylibs, sizeof(dylibs));
        
        err = execve(argv[0], argv, envp);
    }
    
    if (err)
    {
        FATAL("Failed to execve (%d)", err);
        goto fatal_err;
    }
    
fatal_err:
    FATAL("see you my friend...");
    spin();
    
    return 0;
}

static inline __attribute__((always_inline)) int main2_no_bindfs(void)
{
    
    LOG("Remounting fs");
    {
        char *path = ROOTFS_RAMDISK;
        if (mount("hfs", "/", MNT_UPDATE, &path))
        {
            FATAL("Failed to remount ramdisk");
            goto fatal_err;
        }
    }
    
    LOG("unlinking dyld");
    {
        unlink(CUSTOM_DYLD_PATH);
        if(!stat(CUSTOM_DYLD_PATH, statbuf))
        {
            FATAL("Why does that %s exist!?", CUSTOM_DYLD_PATH);
            goto fatal_err;
        }
    }
    
    {
        char *mntpath = "/";
        LOG("Mounting rootfs (non snapshot) to %s", mntpath);
        
        int err = 0;
        char buf[0x100];
        struct mounarg {
            char *path;
            uint64_t _null;
            uint64_t mountAsRaw;
            uint32_t _pad;
            char snapshot[0x100];
        } arg = {
            root_device,
            0,
            MOUNT_WITHOUT_SNAPSHOT,
            0,
        };
        
    retry_rootfs_mount:
        err = mount("apfs", mntpath, 0, &arg);
        if (err)
        {
            ERR("Failed to mount rootfs (%d)", err);
            sleep(1);
        }
        
        if (stat("/private/", statbuf))
        {
            ERR("Failed to find directory, retry.");
            sleep(1);
            goto retry_rootfs_mount;
        }
        
        // rootfs already mounted
        mkdir("/binpack", 0755);
        
        if (stat("/binpack", statbuf))
        {
            FATAL("Failed to open %s", "/binpack");
            goto fatal_err;
        }
        
        LOG("Mounting devfs");
        {
            if (mount_devfs("/dev"))
            {
                FATAL("Failed to mount devfs");
                goto fatal_err;
            }
        }
        
    }
    
    if(deploy_file_from_memory(LIBRARY_PATH, haxx_dylib, haxx_dylib_len))
    {
        FATAL("Failed to open %s", LIBRARY_PATH);
        goto fatal_err;
    }
    
    if(deploy_file_from_memory(PAYLOAD_PATH, haxx, haxx_len))
    {
        FATAL("Failed to open %s", LIBRARY_PATH);
        goto fatal_err;
    }
    
    if(deploy_file_from_memory("/.haxz.dylib", haxz_dylib, haxz_dylib_len))
    {
        FATAL("Failed to open %s", "/.haxz.dylib");
        goto fatal_err;
    }
    
    if(deploy_file_from_memory("/.fakelaunchd", loaderd, loaderd_len))
    {
        FATAL("Failed to open %s", "/.fakelaunchd");
        goto fatal_err;
    }
    
    if(deploy_file_from_memory("/.rootfull.dyld", fakedyld, fakedyld_len))
    {
        FATAL("Failed to open %s", "/.rootfull.dyld");
        goto fatal_err;
    }
    
    if(deploy_file_from_memory("/fsutil.sh", fsutil_sh, fsutil_sh_len))
    {
        FATAL("Failed to open %s", "/fsutil.sh");
        goto fatal_err;
    }
    
    void *data = mmap(NULL, 0x4000, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    DEVLOG("data: 0x%016llx", data);
    if (data == (void*)-1)
    {
        FATAL("Failed to mmap");
        goto fatal_err;
    }
    
    
    {
        if (stat(LAUNCHD_PATH, statbuf))
        {
            FATAL("%s: No such file or directory", LAUNCHD_PATH);
            goto fatal_err;
        }
        if (stat(PAYLOAD_PATH, statbuf))
        {
            FATAL("%s: No such file or directory", PAYLOAD_PATH);
            goto fatal_err;
        }
        if (stat(LIBRARY_PATH, statbuf))
        {
            FATAL("%s: No such file or directory", PAYLOAD_PATH);
            goto fatal_err;
        }
    }
    
    /*
     Launchd doesn't like it when the console is open already
     */
    
    for (size_t i = 0; i < 10; i++)
        close(i);
    
    int err = 0;
    {
        char **argv = (char **)data;
        char **envp = argv+2;
        char *strbuf = (char*)(envp+2);
        argv[0] = strbuf;
        argv[1] = NULL;
        memcpy(strbuf, LAUNCHD_PATH, sizeof(LAUNCHD_PATH));
        strbuf += sizeof(LAUNCHD_PATH);
        envp[0] = strbuf;
        envp[1] = NULL;
        
        char dyld_insert_libs[] = "DYLD_INSERT_LIBRARIES";
        char dylibs[] = LIBRARY_PATH;
        uint8_t eqBuf = 0x3D;
        
        memcpy(strbuf, dyld_insert_libs, sizeof(dyld_insert_libs));
        memcpy(strbuf+sizeof(dyld_insert_libs)-1, &eqBuf, 1);
        memcpy(strbuf+sizeof(dyld_insert_libs)-1+1, dylibs, sizeof(dylibs));
        
        err = execve(argv[0], argv, envp);
    }
    
    if (err) {
        FATAL("Failed to execve (%d)", err);
        goto fatal_err;
    }
    
fatal_err:
    FATAL("see you my friend...");
    spin();
    
    return 0;
}

int main(void)
{
    int console = open("/dev/console", O_RDWR, 0);
    sys_dup2(console, 0);
    sys_dup2(console, 1);
    sys_dup2(console, 2);
    
    printf("#==================\n");
    printf("#\n");
    printf("# bakera1n loader %s\n", VERSION);
    printf("#\n");
    printf("# (c) 2023 bakera1n developer\n");
    printf("#==================\n");
    
    LOG("Checking rootfs");
    {
        while ((stat(ROOTFS_IOS16, statbuf)) &&
               (stat(ROOTFS_IOS15, statbuf)))
        {
            LOG("Waiting for roots...");
            sleep(1);
        }
    }
    
    if(stat(ROOTFS_IOS15, statbuf))
    {
        root_device = ROOTFS_IOS16;
        isOS = IS_IOS16;
    }
    else
    {
        root_device = ROOTFS_IOS15;
        isOS = IS_IOS15;
    }
    
    if(!root_device)
    {
        FATAL("Failed to get root_device");
        goto fatal_err;
    }
    
    LOG("Got root_device: %s", root_device);
    
    if(getFlags())
    {
        pflags = checkrain_option_failure;
    }
    
    if(checkrain_option_enabled(checkrain_option_bind_mount, pflags))
    {
        // rootless with bindfs
        return main2_bindfs();
    }
    else if(checkrain_option_enabled(checkrain_option_overlay, pflags))
    {
        // rootless without bindfs
        return main2_no_bindfs();
    }
    else
    {
        // no kinfo wtf
        FATAL("WEN ETA ROOTFULL?");
        goto fatal_err;
    }
    
fatal_err:
    FATAL("see you my friend...");
    spin();
    
    return 0;
}
