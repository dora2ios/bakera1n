#ifndef DYLD_UTILS
#define DYLD_UTILS

#include <stdint.h>

// syscalls
#define    SYS_exit           1
#define    SYS_fork           2
#define    SYS_read           3
#define    SYS_write          4
#define    SYS_open           5
#define    SYS_close          6
#define    SYS_unlink         10
#define    SYS_getpid         20
#define    SYS_execve         59
#define    SYS_dup2           90
#define    SYS_mkdir          136
#define    SYS_mount          167
#define    SYS_stat           188
#define    SYS_mmap           197
#define    SYS_lseek          199


#define ROOTFS_IOS15        "/dev/disk0s1s1"
#define ROOTFS_IOS16        "/dev/disk1s1"
#define ROOTFS_RAMDISK      "/dev/md0"

#define LAUNCHD_PATH        "/sbin/launchd"
#define PAYLOAD_PATH        "/cores/haxx"
#define CUSTOM_DYLD_PATH    "/fs/gen/dyld"

#ifdef ROOTFULL
#define LIBRARY_PATH        "/cores/haxz.dylib"
#else
#define LIBRARY_PATH        "/cores/haxx.dylib"
#endif

#define IS_IOS16        (1900)
#define IS_IOS15        (1800)

#define STDOUT_FILENO   (1)
#define getpid()        msyscall(SYS_getpid)
#define exit(err)       msyscall(SYS_exit, err)
#define fork()          msyscall(SYS_fork)
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

// pongoOS
#define checkrain_option_none               0x00000000
#define checkrain_option_all                0x7fffffff
#define checkrain_option_failure            0x80000000

#define checkrain_option_safemode           (1 << 0)
#define checkrain_option_bind_mount         (1 << 1)
#define checkrain_option_overlay            (1 << 2)
#define checkrain_option_force_revert       (1 << 7) /* keep this at 7 */
#define checkrain_option_rootfull           (1 << 8)
#define checkrain_option_not_snapshot       (1 << 9)

typedef uint32_t checkrain_option_t, *checkrain_option_p;

struct kerninfo {
    uint64_t size;
    uint64_t base;
    uint64_t slide;
    checkrain_option_t flags;
};

typedef uint32_t kern_return_t;
typedef uint32_t mach_port_t;
typedef uint64_t mach_msg_timeout_t;

void sleep(int secs);
int sys_dup2(int from, int to);
int stat(const char *path, void *ub);
int mount(const char *type, const char *path, int flags, void *data);
void *mmap(void *addr, size_t length, int prot, int flags, int fd, uint64_t offset);
uint64_t write(int fd, const void *cbuf, size_t nbyte);
int close(int fd);
int open(const char *path, int flags, int mode);
int execve(const char *fname, char *const argv[], char *const envp[]);
int unlink(const char *path);
uint64_t read(int fd, void *cbuf, size_t nbyte);
uint64_t lseek(int fd, int32_t offset, int whence);
int mkdir(const char *path, int mode);
void _putchar(char character);
void spin(void);
void memcpy(void *dst, const void *src, size_t n);
void memset(void *dst, int c, size_t n);
int sys_sysctlbyname(const char *name, size_t namelen, void *old, size_t *oldlenp, void *new, size_t newlen);

int mount_bindfs(const char* mountpoint, void* dir);
int mount_devfs(const char* mountpoint);
int deploy_file_from_memory(char* path, const void *buf, size_t size);

#endif
