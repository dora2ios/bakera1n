/*
 * bakera1n - dyld_generic.c
 *
 * Copyright (c) 2023 dora2ios
 *
 */

#include <stdint.h>
#include <plog.h>

#include "printf.h"
#include "dyld_utils.h"

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

static inline __attribute__((always_inline)) int main2_generic(void)
{
    
    DEVLOG("Searching writable partition");
    char rwpt[64];
    {
        int i = 8;
        
        while(1)
        {
            if(i < 5)
            {
                FATAL("Rootfs not found");
                goto fatal_err;
            }
            memset(&rwpt, 0x0, 64);
            // set pt
            if(isOS == IS_IOS16)
                sprintf(rwpt, "/dev/disk1s%d", i);
            else
                sprintf(rwpt, "/dev/disk0s1s%d", i);
            DEVLOG("Checking %s", rwpt);
            if (!stat(rwpt, statbuf)) // found
                break;
            i-=1;
        }
        DEVLOG("Found writable rootfs: %s", rwpt);
    }
    
    {
        char *mntpath = "/";
        DEVLOG("Mounting writable rootfs to %s", mntpath);
        
        int mntflag = MNT_UPDATE;
        
        int err = 0;
        char buf[0x100];
        struct mounarg {
            char *path;
            uint64_t _null;
            uint64_t mountAsRaw;
            uint32_t _pad;
            char snapshot[0x100];
        } arg = {
            rwpt,
            0,
            MOUNT_WITHOUT_SNAPSHOT,
            0,
        };
        
    retry_haxx_rootfs_mount:
        err = mount("apfs", mntpath, mntflag, &arg);
        if (err)
        {
            ERR("Failed to mount rootfs (%d)", err);
            sleep(1);
            goto retry_haxx_rootfs_mount;
        }
        if (stat("/private/", statbuf))
        {
            FATAL("Failed to find directory.");
            goto fatal_err;
        }
        if (stat("/fs/fake", statbuf))
        {
            FATAL("Failed to find directory.");
            goto fatal_err;
        }
        if (stat("/fs/orig", statbuf))
        {
            FATAL("Failed to find directory.");
            goto fatal_err;
        }
    }
    
    LOG("Binding...");
    {
        if (mount_bindfs("/fs/gen", "/fs/fake")) goto error_bindfs;
        
        if (stat("/System/Library/Frameworks/IOKit.framework", statbuf))
        {
            LOG("Mounting rootfs");
            {
                char *mntpath = "/fs/orig";
                DEVLOG("Mounting rootfs to %s", mntpath);
                
                int mntflag = MNT_RDONLY;
                
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
                err = mount("apfs", mntpath, mntflag, &arg);
                if (err)
                {
                    ERR("Failed to mount rootfs (%d)", err);
                    sleep(1);
                    goto retry_rootfs_mount;
                }
                if (stat("/fs/orig/private/", statbuf))
                {
                    FATAL("Failed to find directory.");
                    goto fatal_err;
                }
            }
            
            LOG("More binding...");
            
            if (mount_bindfs("/System/Library/Frameworks", "/fs/orig/System/Library/Frameworks")) goto error_bindfs;
            if (mount_bindfs("/System/Library/AccessibilityBundles", "/fs/orig/System/Library/AccessibilityBundles")) goto error_bindfs;
            if (mount_bindfs("/System/Library/Assistant", "/fs/orig/System/Library/Assistant")) goto error_bindfs;
            if (mount_bindfs("/System/Library/Audio", "/fs/orig/System/Library/Audio")) goto error_bindfs;
            if (mount_bindfs("/System/Library/Fonts", "/fs/orig/System/Library/Fonts")) goto error_bindfs;
            if (mount_bindfs("/System/Library/Health", "/fs/orig/System/Library/Health")) goto error_bindfs;
            if (mount_bindfs("/System/Library/LinguisticData", "/fs/orig/System/Library/LinguisticData")) goto error_bindfs;
            if (mount_bindfs("/System/Library/OnBoardingBundles", "/fs/orig/System/Library/OnBoardingBundles")) goto error_bindfs;
            if (mount_bindfs("/System/Library/Photos", "/fs/orig/System/Library/Photos")) goto error_bindfs;
            if (mount_bindfs("/System/Library/PreferenceBundles", "/fs/orig/System/Library/PreferenceBundles")) goto error_bindfs;
            if (mount_bindfs("/System/Library/PreinstalledAssetsV2", "/fs/orig/System/Library/PreinstalledAssetsV2")) goto error_bindfs;
            if (mount_bindfs("/System/Library/PrivateFrameworks", "/fs/orig/System/Library/PrivateFrameworks")) goto error_bindfs;
            if (mount_bindfs("/usr/standalone/update", "/fs/orig/usr/standalone/update")) goto error_bindfs;
            
            if(isOS == IS_IOS15)
                if (mount_bindfs("/System/Library/Caches", "/fs/orig/System/Library/Caches")) goto error_bindfs;
            
        }
        
        
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

int main(void)
{
    int console = open("/dev/console", O_RDWR, 0);
    sys_dup2(console, 0);
    sys_dup2(console, 1);
    sys_dup2(console, 2);
    
    printf("#==================\n");
    printf("#\n");
    printf("# bakera1n loader generic %s\n", VERSION);
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
    
    if(root_device)
    {
        // rootfull
        return main2_generic();
    }
    
fatal_err:
    FATAL("see you my friend...");
    spin();
    
    return 0;
}
