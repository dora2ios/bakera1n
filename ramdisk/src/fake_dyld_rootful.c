#include <stdint.h>
#include "printf.h"

#define DEVBUILD 1

#define LOG(x, ...) \
do { \
printf("[LOG] "x"\n", ##__VA_ARGS__); \
} while(0)

#define ERR(x, ...) \
do { \
printf("[ERR] "x"\n", ##__VA_ARGS__); \
} while(0)

#define FATAL(x, ...) \
do { \
printf("[FATAL] "x"\n", ##__VA_ARGS__); \
} while(0)


#ifdef DEVBUILD
#define DEVLOG(x, ...) \
do { \
printf("[DEV] "x"\n", ##__VA_ARGS__); \
} while(0)
#else
#define DEVLOG(x, ...)
#endif

#define ROOTFS_IOS15        "/dev/disk0s1s1"
#define ROOTFS_IOS16        "/dev/disk1s1"

#define LAUNCHD_PATH        "/sbin/launchd"
#define PAYLOAD_PATH        "/haxx"
#define LIBRARY_PATH        "/haxz.dylib"
#define CUSTOM_DYLD_PATH    "/fs/gen/dyld"

#define IS_IOS16    (1900)
#define IS_IOS15    (1800)

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

typedef uint32_t kern_return_t;
typedef uint32_t mach_port_t;
typedef uint64_t mach_msg_timeout_t;

#define STDOUT_FILENO   (1)
#define getpid()        msyscall(20)
#define exit(err)       msyscall(1, err)
#define fork()          msyscall(2)
#define puts(str)       write(STDOUT_FILENO, str, sizeof(str) - 1)

#define O_RDONLY        0
#define O_WRONLY        1
#define O_RDWR          2
#define O_CREAT         0x00000200      /* create if nonexistant */

#define SEEK_SET        0
#define SEEK_CUR        1
#define SEEK_END        2

#define PROT_NONE       0x00    /* [MC2] no permissions */
#define PROT_READ       0x01    /* [MC2] pages can be read */
#define PROT_WRITE      0x02    /* [MC2] pages can be written */
#define PROT_EXEC       0x04    /* [MC2] pages can be executed */

#define MAP_FILE        0x0000  /* map from file (default) */
#define MAP_ANON        0x1000  /* allocated from memory, swap space */
#define MAP_ANONYMOUS   MAP_ANON
#define MAP_SHARED      0x0001          /* [MF|SHM] share changes */
#define MAP_PRIVATE     0x0002          /* [MF|SHM] changes are private */


#define MNT_RDONLY      0x00000001
#define MNT_LOCAL       0x00001000
#define MNT_ROOTFS      0x00004000      /* identifies the root filesystem */
#define MNT_UNION       0x00000020
#define MNT_UPDATE      0x00010000      /* not a real mount, just an update */
#define MNT_NOBLOCK     0x00020000      /* don't block unmount if not responding */
#define MNT_RELOAD      0x00040000      /* reload filesystem data */
#define MNT_FORCE       0x00080000      /* force unmount or readonly change */

#define MOUNT_WITH_SNAPSHOT                 (0)
#define MOUNT_WITHOUT_SNAPSHOT              (1)

static char *root_device = NULL;
static int isOS = 0;
static char statbuf[0x400];

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

static void inline __attribute__((always_inline)) sleep(int secs) {
    thread_switch(0, 2, secs*0x400);
}

static int inline __attribute__((always_inline)) sys_dup2(int from, int to) {
    return msyscall(90, from, to);
}

static int inline __attribute__((always_inline)) stat(void *path, void *ub) {
    return msyscall(188, path, ub);
}

static int inline __attribute__((always_inline)) mount(char *type, char *path, int flags, void *data) {
    return msyscall(167, type, path, flags, data);
}

static void inline __attribute__((always_inline)) *mmap(void *addr, size_t length, int prot, int flags, int fd, uint64_t offset) {
    return (void *)msyscall(197, addr, length, prot, flags, fd, offset);
}

static uint64_t inline __attribute__((always_inline)) write(int fd, void* cbuf, size_t nbyte) {
    return msyscall(4, fd, cbuf, nbyte);
}

static int inline __attribute__((always_inline)) close(int fd) {
    return msyscall(6, fd);
}

static int inline __attribute__((always_inline)) open(void *path, int flags, int mode) {
    return msyscall(5, path, flags, mode);
}

static int inline __attribute__((always_inline)) execve(char *fname, char *const argv[], char *const envp[]) {
    return msyscall(59, fname, argv, envp);
}

static int inline __attribute__((always_inline)) unlink(void *path) {
    return msyscall(10, path);
}

static uint64_t inline __attribute__((always_inline)) read(int fd, void *cbuf, size_t nbyte) {
    return msyscall(3, fd, cbuf, nbyte);
}

static uint64_t inline __attribute__((always_inline)) lseek(int fd, int32_t offset, int whence) {
    return msyscall(199, fd, offset, whence);
}

static int inline __attribute__((always_inline)) mkdir(char* path, int mode) {
    return msyscall(136, path, mode);
}


void inline __attribute__((always_inline)) _putchar(char character) {
    static size_t chrcnt = 0;
    static char buf[0x100];
    buf[chrcnt++] = character;
    if (character == '\n' || chrcnt == sizeof(buf)){
        write(STDOUT_FILENO, buf, chrcnt);
        chrcnt = 0;
    }
}

static void inline __attribute__((always_inline)) spin(void) {
    ERR("WTF?!");
    while(1) {
        sleep(1);
    }
}

void memcpy(void *dst, void *src, size_t n) {
    uint8_t *s =(uint8_t *)src;
    uint8_t *d =(uint8_t *)dst;
    for (size_t i = 0; i < n; i++) *d++ = *s++;
}

void memset(void *dst, int c, size_t n) {
    uint8_t *d =(uint8_t *)dst;
    for (size_t i = 0; i < n; i++) *d++ = c;
}

static inline __attribute__((always_inline)) int main2_rootfull(void)
{
    
    DEVLOG("Searching writable partition");
    char rwpt[64];
    {
        int i = 8;
        
        while(1) {
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
        err = mount("apfs", mntpath, MNT_UPDATE, &arg);
        if (err) {
            ERR("Failed to mount rootfs (%d)", err);
            sleep(1);
            goto retry_haxx_rootfs_mount;
        }
        if (stat("/private/", statbuf)) {
            FATAL("Failed to find directory.");
            goto fatal_err;
        }
        if (stat("/fs/fake", statbuf)) {
            FATAL("Failed to find directory.");
            goto fatal_err;
        }
    }
    
    LOG("Binding rootfs");
    {
        if (mount("bindfs", "/fs/gen", 0, "/fs/fake")) goto error_bindfs;
        
        if(0) {
        error_bindfs:
            FATAL("Failed to bind mount");
            goto fatal_err;
        }
    }
    
    void *data = mmap(NULL, 0x4000, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    DEVLOG("data: 0x%016llx", data);
    if (data == (void*)-1) {
        FATAL("Failed to mmap");
        goto fatal_err;
    }
    
    {
        if (stat(LAUNCHD_PATH, statbuf)) {
            FATAL("%s: No such file or directory", LAUNCHD_PATH);
            goto fatal_err;
        }
        if (stat(PAYLOAD_PATH, statbuf)) {
            FATAL("%s: No such file or directory", PAYLOAD_PATH);
            goto fatal_err;
        }
        if (stat(LIBRARY_PATH, statbuf)) {
            FATAL("%s: No such file or directory", PAYLOAD_PATH);
            goto fatal_err;
        }
    }
    
    /*
     Launchd doesn't like it when the console is open already
     */
    
    for (size_t i = 0; i < 10; i++) {
        close(i);
    }
    
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

int main(void) {
    int console = open("/dev/console", O_RDWR, 0);
    sys_dup2(console, 0);
    sys_dup2(console, 1);
    sys_dup2(console, 2);
    
    printf("#==================\n");
    printf("#\n");
    printf("# bakera1n loader rootful %s\n", VERSION);
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
        return main2_rootfull();
    }
    
fatal_err:
    FATAL("see you my friend...");
    spin();
    
    return 0;
}
