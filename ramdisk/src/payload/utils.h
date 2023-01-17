#ifndef BAKERA1N_UTILS_H
#define BAKERA1N_UTILS_H

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <spawn.h>
#include <dirent.h>
#include <pthread.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFSerialize.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include <assert.h>
#include <sys/param.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <plog.h>

#define kCFCoreFoundationVersionNumber_iOS_16       (1900.0)
#define kCFCoreFoundationVersionNumber_iOS_16_1_2   (1953.1)

#define kBRBakeBinaryPath_Rootfull      (1 << 0)
#define kBRBakeBinaryPath_Rootless      (1 << 1)
#define kBRBakeBinaryPath_Binpack       (1 << 2)

#define kBRBakeEnvironment_Rootfull     (1 << 0)
#define kBRBakeEnvironment_Rootless     (1 << 1)

#define kBRBakeSubstrate_Substrate      (1 << 0)
#define kBRBakeSubstrate_Substitute     (1 << 1)
#define kBRBakeSubstrate_Libhooker      (1 << 2)
#define kBRBakeSubstrate_Ellekit        (1 << 3)

#define NEWFILE  (O_WRONLY|O_SYNC)
#define CONSOLE "/dev/console"

// ramdisk boot only
#define checkrain_option_none               0x00000000
#define checkrain_option_all                0x7fffffff
#define checkrain_option_failure            0x80000000

#define checkrain_option_safemode           (1 << 0)
#define checkrain_option_bind_mount         (1 << 1)
#define checkrain_option_overlay            (1 << 2)
#define checkrain_option_force_revert       (1 << 7) /* keep this at 7 */

typedef uint32_t checkrain_option_t, *checkrain_option_p;

struct kerninfo {
    uint64_t size;
    uint64_t base;
    uint64_t slide;
    checkrain_option_t flags;
};

extern checkrain_option_t pflags;
extern bool userspace_reboot;
extern char **environ;

bool checkrain_option_enabled(checkrain_option_t flags, checkrain_option_t opt);
int getFlags(void);
int mount_overlay(const char* abspath, const char* disktype, const char* mntpoint, int mntflag);
void spin(void);
void init(void);

int runCmd(const char *cmd, char * const *args);
int makeRSA(void);
int startDropbear(void);
int doUICache(uint64_t pathflag, uint64_t envflag);
int startJBDeamons(uint64_t pathflag, uint64_t envflag);
int startSubstrate(uint64_t typeflag, uint64_t envflag);
int rebootUserspace(uint64_t pathflag, uint64_t envflag);

#endif
