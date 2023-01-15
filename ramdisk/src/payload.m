/*
 * bakera1n - payload.m
 *
 * Copyright (c) 2023 dora2ios
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

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
#include "log.h"

#include "dropbear.h"

#define kCFCoreFoundationVersionNumber_iOS_16       (1900.0)
#define kCFCoreFoundationVersionNumber_iOS_16_1_2   (1953.1)

extern kern_return_t
task_policy_set(
                task_t                  task,
                task_policy_flavor_t    flavor,
                task_policy_t           policy_info,
                mach_msg_type_number_t  count);

#define checkrain_option_none               0x00000000
#define checkrain_option_all                0x7fffffff
#define checkrain_option_failure            0x80000000

#define checkrain_option_safemode           (1 << 0)
#define checkrain_option_bind_mount         (1 << 1)
#define checkrain_option_overlay            (1 << 2)
#define checkrain_option_force_revert       (1 << 7) /* keep this at 7 */

typedef uint32_t checkrain_option_t, *checkrain_option_p;

static checkrain_option_t pflags;
static bool userspace_reboot = false;

struct kerninfo {
    uint64_t size;
    uint64_t base;
    uint64_t slide;
    checkrain_option_t flags;
};

extern char **environ;

static inline __attribute__((always_inline)) bool checkrain_option_enabled(checkrain_option_t flags, checkrain_option_t opt)
{
    if(flags == checkrain_option_failure)
    {
        switch(opt)
        {
            case checkrain_option_safemode:
                return true;
            default:
                return false;
        }
    }
    return (flags & opt) != 0;
}

static inline __attribute__((always_inline)) int getFlags(void)
{
    uint32_t err = 0;
    
    struct statfs *mntbufp;
    int mntinfo = getmntinfo(&mntbufp, 0);
    if (mntinfo >= 0x1) {
        size_t sz = 0;
        struct kerninfo info;
        int fd = open("/dev/rmd0", O_RDONLY|O_RDWR);
        if (fd >= 0x1) {
            read(fd, &sz, 4);
            lseek(fd, (long)(sz), SEEK_SET);
            if(read(fd, &info, sizeof(struct kerninfo)) == sizeof(struct kerninfo)) {
                pflags = info.flags;
                printf("got flags: %d from stage1\n", pflags);
                err = 0;
            } else {
                printf("Read kinfo failed\n");
                err = -1;
            }
            close(fd);
        } else {
            printf("Open rd failed\n");
            err = -1;
        }
    } else {
        printf("Get mntinfo failed\n");
        err = -1;
    }
    
    return err;
}


static inline __attribute__((always_inline)) int mount_overlay(const char* abspath, const char* disktype, const char* mntpoint, int mntflag)
{
    
    kern_return_t ret;
    
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHDIXController"));
    assert(service);
    io_connect_t connect;
    ret = IOServiceOpen(service, mach_task_self(), 0, &connect);
    if (!!ret) {
        fprintf(stderr, "IOServiceOpen: %d\n", ret);
    }
    assert(!ret);
    
    CFMutableDictionaryRef props = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFStringRef uuid = CFUUIDCreateString(NULL, CFUUIDCreate(kCFAllocatorDefault));
    CFDictionarySetValue(props, CFSTR("hdik-unique-identifier"), uuid);
    CFDataRef path = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (UInt8 *) abspath, strlen(abspath), kCFAllocatorNull);
    assert(path);
    CFDictionarySetValue(props, CFSTR("image-path"), path);
    CFDictionarySetValue(props, CFSTR("autodiskmount"), kCFBooleanFalse);
    
    CFMutableDictionaryRef images = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(images, CFSTR("checkra1n-overlay"), kCFBooleanTrue);
    CFDictionarySetValue(props, CFSTR("image-secrets"), images);
    
    CFDataRef props_data = CFPropertyListCreateData(kCFAllocatorDefault, props, 0x64, 0LL, 0LL);
    assert(props_data);
    
    struct HDIImageCreateBlock64 {
        uint32_t magic;
        uint32_t one;
        char *props;
        uint64_t props_size;
        char ignored[0xf8 - 16];
    } stru;
    memset(&stru, 0, sizeof(stru));
    stru.magic = 0xbeeffeed;
    stru.one = 1;
    stru.props = (char *) CFDataGetBytePtr(props_data);
    stru.props_size = CFDataGetLength(props_data);
    assert(offsetof(struct HDIImageCreateBlock64, props) == 8);
    
    uint32_t val;
    size_t val_size = sizeof(val);
    
    ret = IOConnectCallStructMethod(connect, 0, &stru, 0x100, &val, &val_size);
    if(ret) {
        fprintf(stderr, "returned %x\n", ret);
        return 1;
    }
    assert(val_size == sizeof(val));
    
    CFMutableDictionaryRef pmatch = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(pmatch, CFSTR("hdik-unique-identifier"), uuid);
    CFMutableDictionaryRef matching = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(matching, CFSTR("IOPropertyMatch"), pmatch);
    service = IOServiceGetMatchingService(kIOMainPortDefault, matching);
    if(!service) {
        fprintf(stderr, "successfully attached, but didn't find top entry in IO registry\n");
        return 1;
    }
    
    bool ok = false;
    io_iterator_t iter;
    assert(!IORegistryEntryCreateIterator(service, kIOServicePlane, kIORegistryIterateRecursively, &iter));
    while( (service = IOIteratorNext(iter)) ) {
        CFStringRef bsd_name = IORegistryEntryCreateCFProperty(service, CFSTR("BSD Name"), NULL, 0);
        if(bsd_name) {
            char buf[MAXPATHLEN];
            assert(CFStringGetCString(bsd_name, buf, sizeof(buf), kCFStringEncodingUTF8));
            puts(buf);
            char strr[512];
            memset(&strr, 0x0, 512);
            sprintf(strr, "/dev/%s", buf);
            char* nmr = strdup(strr);
            int mntr = mount(disktype, mntpoint, mntflag, &nmr);
            if(mntr == 0) ok = true;
        }
    }
    
    if(!ok) {
        fprintf(stderr, "successfully attached, but didn't find BSD name in IO registry\n");
        return 1;
    }
    return 0;
}

static inline __attribute__((always_inline)) void spin(void) {
    while(1) {
        sleep(3);
    }
}

#define NEWFILE  (O_WRONLY|O_SYNC)
#define CONSOLE "/dev/console"

static inline __attribute__((always_inline)) void init(void)
{
    int fd;
    fd = open(CONSOLE, NEWFILE, 0644);
    if(fd < 0) perror(CONSOLE);
    close(1);
    close(2);
    if(dup2(fd, 1) < 0) perror("dup");
    if(dup2(fd, 2) < 0) perror("dup");
    close(fd);
    printf("\n");
}

static inline __attribute__((always_inline)) int runCmd(const char *cmd, char * const *args)
{
    pid_t pid;
    posix_spawn_file_actions_t *actions = NULL;
    posix_spawn_file_actions_t actionsStruct;
    int out_pipe[2];
    bool valid_pipe = false;
    posix_spawnattr_t *attr = NULL;
    posix_spawnattr_t attrStruct;
    
    valid_pipe = pipe(out_pipe) == 0;
    if (valid_pipe && posix_spawn_file_actions_init(&actionsStruct) == 0) {
        actions = &actionsStruct;
        posix_spawn_file_actions_adddup2(actions, out_pipe[1], 1);
        posix_spawn_file_actions_adddup2(actions, out_pipe[1], 2);
        posix_spawn_file_actions_addclose(actions, out_pipe[0]);
        posix_spawn_file_actions_addclose(actions, out_pipe[1]);
    }
    
    int rv = posix_spawn(&pid, cmd, actions, attr, (char *const *)args, environ);
    
    if (valid_pipe) {
        close(out_pipe[1]);
    }
    
    if (rv == 0) {
        if (waitpid(pid, &rv, 0) == -1) {
            ERR("Waitpid failed");
        } else {
            LOG("completed with exit status %d[%s]", WEXITSTATUS(rv), cmd);
        }
    } else {
        ERR("posix_spawn failed (%d[%s]): %s", rv, cmd, strerror(rv));
    }
    if (valid_pipe) {
        close(out_pipe[0]);
    }
    
    return rv;
}

static inline __attribute__((always_inline)) int makeRSA(void)
{
    pid_t pid;
    
    FILE *fd = fopen("/private/var/dropbear_rsa_host_key", "r");
    if (!fd)
    {
        DEVLOG("generating rsa key");
        char *args[] = { "/binpack/usr/bin/dropbearkey", "-t", "rsa", "-f", "/private/var/dropbear_rsa_host_key", NULL };
        return runCmd(args[0], args);
    }
    
    return 0;
}

static inline __attribute__((always_inline)) int startDropbear(void)
{
    rmdir("/tmp/.req");
    mkdir("/tmp/.req", 0755);
    FILE *outFile = fopen("/tmp/.req/dropbear.plist", "w");
    if (!outFile) {
        ERR("error opening file");
        return -1;
    }
    
    fwrite(dropbear_plist, dropbear_plist_len, 1, outFile);
    fflush(outFile);
    fclose(outFile);
    
    char *args[] = { "/binpack/bin/launchctl", "load", "/tmp/.req/dropbear.plist", NULL };
    return runCmd(args[0], args);
}

static inline __attribute__((always_inline)) int UICacheForRootFul(void)
{
    char *args[] = { "/usr/bin/uicache", "-a", NULL };
    return runCmd(args[0], args);
}

static inline __attribute__((always_inline)) int UICacheForLoader(void)
{
    char *args[] = { "/binpack/usr/bin/uicache", "-f", "-p", "/binpack/Applications/loader.app", NULL };
    return runCmd(args[0], args);
}

static inline __attribute__((always_inline)) void UICacheForRootlessApplications(void)
{
    DIR *d = NULL;
    struct dirent *dir = NULL;
    if ((d = opendir("/var/jb/Applications/"))){
        while ((dir = readdir(d))) { //remove all subdirs and files
            if (strcmp(dir->d_name, ".") == 0 || strcmp(dir->d_name, "..") == 0) {
                continue;
            }
            char *pp = NULL;
            asprintf(&pp,"/var/jb/Applications/%s", dir->d_name);

            char *args[] = { "/var/jb/usr/bin/uicache", "-p", pp, NULL };
            runCmd(args[0], args);

            free(pp);
        }
        closedir(d);
    }
}

static inline __attribute__((always_inline)) int startJBDeamons(void)
{
    char *args[] = { "/var/jb/bin/launchctl", "load", "/var/jb/Library/LaunchDaemons", NULL };
    return runCmd(args[0], args);
}

static inline __attribute__((always_inline)) void startRCD(void)
{
    DIR *d = NULL;
    struct dirent *dir = NULL;
    if ((d = opendir("/var/jb/etc/rc.d/"))){
        while ((dir = readdir(d))) { //remove all subdirs and files
            if (strcmp(dir->d_name, ".") == 0 || strcmp(dir->d_name, "..") == 0) {
                continue;
            }
            char *pp = NULL;
            asprintf(&pp,"/var/jb/etc/rc.d/%s", dir->d_name);
            
            char *args[] = { pp, NULL };
            runCmd(args[0], args);
            
            free(pp);
        }
        closedir(d);
    }
}

static inline __attribute__((always_inline)) int startJBDeamonsRootFull(void)
{
    char *args[] = { "/bin/launchctl", "load", "/Library/LaunchDaemons", NULL };
    return runCmd(args[0], args);
}

static inline __attribute__((always_inline)) void startRCDRootFull(void)
{
    
    DIR *d = NULL;
    struct dirent *dir = NULL;
    if ((d = opendir("/etc/rc.d/"))){
        while ((dir = readdir(d))) { //remove all subdirs and files
            if (strcmp(dir->d_name, ".") == 0 || strcmp(dir->d_name, "..") == 0) {
                continue;
            }
            char *pp = NULL;
            asprintf(&pp,"/etc/rc.d/%s", dir->d_name);
            
            char *args[] = { pp, NULL };
            runCmd(args[0], args);
            
            free(pp);
        }
        closedir(d);
    }
}

static inline __attribute__((always_inline)) int startRootlessEllekit(void)
{
    char *args[] = { "/var/jb/usr/libexec/ellekit/loader", NULL };
    return runCmd(args[0], args);
}

static inline __attribute__((always_inline)) int startSubstitute(void)
{
    char *args[] = { "/etc/rc.d/substitute-launcher", NULL };
    return runCmd(args[0], args);
}

static inline __attribute__((always_inline)) int ReloadSystem(void)
{
    struct stat st;
    int notBinpack = stat("/binpack/.installed_overlay", &st);
    if(notBinpack && checkrain_option_enabled(checkrain_option_overlay, pflags))
    {
        const char* path = "ramfile://checkra1n";
        notBinpack = mount_overlay(path, "hfs", "/binpack", MNT_RDONLY);
    }
    
    close(creat("/private/var/tmp/.kok3shi_firstboot", 0x1ed));
    
    {
        char *args[] = { "/sbin/mount", "-uw", "/private/preboot", NULL };
        runCmd(args[0], args);
    }
    
    if(!notBinpack)
    {
        if(stat("/private/var/dropbear_rsa_host_key", &st))
        {
            // first boot time
            DEVLOG("injecting SBShowNonDefaultSystemApps");
            
            char *arg1[] = { "/binpack/usr/bin/killall", "-SIGSTOP", "cfprefsd", NULL };
            runCmd(arg1[0], arg1);
            
            NSMutableDictionary* md = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
            [md setObject:[NSNumber numberWithBool:YES] forKey:@"SBShowNonDefaultSystemApps"];
            [md writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
            
            char *arg2[] = { "/binpack/usr/bin/killall", "-9", "cfprefsd", NULL };
            runCmd(arg2[0], arg2);
            
            char *arg3[] = { "/binpack/usr/sbin/chown", "501:501", "/var/mobile/Library/Preferences/com.apple.springboard.plist", NULL };
            runCmd(arg3[0], arg3);
        }
        
        DEVLOG("running makeRSA");
        makeRSA();
        DEVLOG("running startDropbear");
        startDropbear();
    }
    
    if(!userspace_reboot && !stat("/var/jb/usr/libexec/ellekit/loader", &st))
    {
        // ellekit
        startRootlessEllekit();
        
        DEVLOG("rebooting userspace...");
        char* lauchchctl_path = NULL;
        if(!stat("/binpack/bin/launchctl", &st))
            lauchchctl_path = "/binpack/bin/launchctl";
        else if(!stat("/var/jb/bin/launchctl", &st))
            lauchchctl_path = "/var/jb/bin/launchctl";
        
        if(lauchchctl_path)
        {
            char *args[] = { lauchchctl_path, "reboot", "userspace", NULL };
            return runCmd(args[0], args);
        }
        
    }
    else
    {
        // launchdeamons
        startJBDeamons();
        UICacheForRootlessApplications();
    }
    
    return 0;
}

static inline __attribute__((always_inline)) int Stage4EarlyGang(int argc, char **argv)
{
    DEVLOG("Early stage4");
    
    task_policy_t *policy_info = (task_policy_t*)1;
    task_policy_set(mach_task_self(), 1, (task_policy_t)&policy_info, 1);
    
    // WEN ETA
    
    close(0x0);
    close(0x1);
    close(0x2);
    
    return 0;
}

static inline __attribute__((always_inline)) int Stage4EntryGang(int argc, char **argv)
{
    DEVLOG("Enter stage4");
    
    task_policy_t *policy_info = (task_policy_t*)1;
    task_policy_set(mach_task_self(), 1, (task_policy_t)&policy_info, 1);
    
    if(getFlags())
    {
        pflags = checkrain_option_failure;
    }
    
    unmount("/Developer", 0x80000);
    
    struct stat st;
    if(stat("/private/var/tmp/.kok3shi_firstboot", &st))
        ReloadSystem();
    
    close(0x0);
    close(0x1);
    close(0x2);
    
    return 0;
}

static inline __attribute__((always_inline)) int ReloadSystemRootFull(void)
{
    struct stat st;
    int notBinpack = stat("/binpack/.installed_overlay", &st);
    
    // rootfull does not have kinfo
    if(notBinpack)
    {
        const char* path = "ramfile://checkra1n";
        notBinpack = mount_overlay(path, "hfs", "/binpack", MNT_RDONLY);
    }
    
    close(creat("/private/var/tmp/.kok3shi_firstboot", 0x1ed));
    
    {
        char *args[] = { "/sbin/mount", "-uw", "/private/preboot", NULL };
        runCmd(args[0], args);
    }
    
    int hasDYLDcache = 0;
    // ios 16.0 - 16.1.2
    if( // !stat("/etc/rc.d/substitute-launcher", &st) &&
       !userspace_reboot &&
       stat("/.rootless_test", &st) &&
       (kCFCoreFoundationVersionNumber <= kCFCoreFoundationVersionNumber_iOS_16_1_2) &&
       (kCFCoreFoundationVersionNumber > kCFCoreFoundationVersionNumber_iOS_16))
    {
        if(stat("/System/Library/Caches/com.apple.dyld", &st))
            mkdir("/System/Library/Caches/com.apple.dyld", 0755);
        
        if(!stat("/System/Cryptexes/OS/System/Library/Caches/com.apple.dyld", &st) &&
           !stat("/System/Library/Caches/com.apple.dyld", &st) &&
           stat("/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64", &st))
        {
            DEVLOG("Binding fs");
            int err = mount("bindfs", "/System/Library/Caches/com.apple.dyld", 0, "/System/Cryptexes/OS/System/Library/Caches/com.apple.dyld");
            if (!err) {
                hasDYLDcache = 1;
                sync();
                sleep(1);
            }
            else
            {
                ERR("Failed to bind fs (%d)", err);
            }
        }
    }
    else if(userspace_reboot)
    {
        DEVLOG("already loaded");
    }
    else if(kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_16)
    {
        // ios 15
        hasDYLDcache = 1;
    }
    else
    {
        DEVLOG("substitute is not supported yet.");
    }
    
    if(hasDYLDcache && !userspace_reboot && !stat("/etc/rc.d/substitute-launcher", &st) && stat("/.rootless_test", &st))
    {
        DEVLOG("loading substitute");
        startSubstitute();
        
        DEVLOG("rebooting userspace...");
        
        char* lauchchctl_path = NULL;
        if(!stat("/binpack/bin/launchctl", &st))
            lauchchctl_path = "/binpack/bin/launchctl";
        else if(!stat("/bin/launchctl", &st))
            lauchchctl_path = "/bin/launchctl";
        
        if(lauchchctl_path)
        {
            char *args[] = { lauchchctl_path, "reboot", "userspace", NULL };
            return runCmd(args[0], args);
        }
        
    }
    else if(!stat("/.rootless_test", &st) && !userspace_reboot && !stat("/var/jb/usr/libexec/ellekit/loader", &st))
    {
        // ellekit
        startRootlessEllekit();
        
        DEVLOG("rebooting userspace...");
        char* lauchchctl_path = NULL;
        if(!stat("/binpack/bin/launchctl", &st))
            lauchchctl_path = "/binpack/bin/launchctl";
        else if(!stat("/var/jb/bin/launchctl", &st))
            lauchchctl_path = "/var/jb/bin/launchctl";
        
        if(lauchchctl_path)
        {
            char *args[] = { lauchchctl_path, "reboot", "userspace", NULL };
            return runCmd(args[0], args);
        }
    }
    
    if(!notBinpack)
    {
        DEVLOG("running makeRSA");
        makeRSA();
        DEVLOG("running startDropbear");
        startDropbear();
        
        if(stat("/.installed_kok3shi", &st))
        {
            DEVLOG("injecting SBShowNonDefaultSystemApps");
            
            char *arg1[] = { "/binpack/usr/bin/killall", "-SIGSTOP", "cfprefsd", NULL };
            runCmd(arg1[0], arg1);
            
            NSMutableDictionary* md = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
            [md setObject:[NSNumber numberWithBool:YES] forKey:@"SBShowNonDefaultSystemApps"];
            [md writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
            
            char *arg2[] = { "/binpack/usr/bin/killall", "-9", "cfprefsd", NULL };
            runCmd(arg2[0], arg2);
            
            char *arg3[] = { "/binpack/usr/sbin/chown", "501:501", "/var/mobile/Library/Preferences/com.apple.springboard.plist", NULL };
            runCmd(arg3[0], arg3);
            
            open("/.installed_kok3shi", O_RDWR|O_CREAT);
        }
    }
    
    if(stat("/.rootless_test", &st))
    {
        DEVLOG("loading deamons");
        startJBDeamonsRootFull();
        sync();
        UICacheForRootFul();
        sync();
        sync();
    }
    else
    {
        DEVLOG("loading deamons");
        startJBDeamons();
        sync();
        UICacheForRootlessApplications();
        sync();
        sync();
    }
    
    return 0;
}


static inline __attribute__((always_inline)) int Stage4RootFullGang(int argc, char **argv)
{
    DEVLOG("Enter stage4");
    
    task_policy_t *policy_info = (task_policy_t*)1;
    task_policy_set(mach_task_self(), 1, (task_policy_t)&policy_info, 1);
    
    unmount("/Developer", 0x80000);
    
    struct stat st;
    if(stat("/private/var/tmp/.kok3shi_firstboot", &st))
        ReloadSystemRootFull();
    
    close(0x0);
    close(0x1);
    close(0x2);
    
    return 0;
}

int main(int argc, char **argv)
{
    init();
    
    printf("#==================\n");
    printf("#\n");
    printf("# bakera1n payload %s\n", VERSION);
    printf("#\n");
    printf("# (c) 2023 bakera1n developer\n");
    printf("#==================\n");
    
    DEVLOG("Hello gang!");
    
    pid_t pid = getpid();
    DEVLOG("pid: %d", pid);
    DEVLOG("arg: %s", argv[0]);
    
    
    int i = 0;
    while(environ[i] != NULL)
    {
        DEVLOG("env[%d]: %s", i, environ[i]);
        i++;
    }
    
    i = 0;
    while(argv[i] != NULL)
    {
        DEVLOG("argv[%d]: %s", i, argv[i]);
        i++;
    }
    
    if(argc == 2)
    {
        if(!strcmp(argv[1], "-i"))
            userspace_reboot = true;
    }
    
    DEVLOG("userspace_reboot: %d", userspace_reboot);
    
    if(strcmp(argv[0], "stage4early") == 0x0)
    {
        return Stage4EarlyGang(argc, argv);
    }
    
    if(strcmp(argv[0], "stage4gang") == 0x0)
    {
        return Stage4EntryGang(argc, argv);
    }
    
    if(strcmp(argv[0], "stage4rootfull") == 0x0)
    {
        return Stage4RootFullGang(argc, argv);
    }
    
    ERR("What the HELL?!");
    
    return 0;
}
