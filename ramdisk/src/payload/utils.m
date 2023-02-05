
#include "utils.h"
#include "../dropbear.h"

bool checkrain_option_enabled(checkrain_option_t flags, checkrain_option_t opt)
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

int getFlags(void)
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
                LOG("got flags: %d from stage1", pflags);
                err = 0;
            } else {
                ERR("Read kinfo failed");
                err = -1;
            }
            close(fd);
        } else {
            ERR("Open rd failed");
            err = -1;
        }
    } else {
        ERR("Get mntinfo failed");
        err = -1;
    }
    
    return err;
}

int mount_overlay(const char* abspath, const char* disktype, const char* mntpoint, int mntflag)
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

void spin(void)
{
    while(1)
    {
        sleep(3);
    }
}

void init(void)
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

int runCmd(const char *cmd, char * const *args)
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

int makeRSA(void)
{
    pid_t pid;
    
    FILE *fd = fopen("/private/var/dropbear_rsa_host_key", "r");
    if (!fd)
    {
        DEVLOG("generating rsa key");
        char *args[] = { "/cores/binpack/usr/bin/dropbearkey", "-t", "rsa", "-f", "/private/var/dropbear_rsa_host_key", NULL };
        return runCmd(args[0], args);
    }
    
    return 0;
}

int startDropbear(void)
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
    
    char *args[] = { "/cores/binpack/bin/launchctl", "load", "/tmp/.req/dropbear.plist", NULL };
    return runCmd(args[0], args);
}

int doUICache(uint64_t pathflag, uint64_t envflag)
{
    char *path = NULL;
    if(pathflag & kBRBakeBinaryPath_Rootfull)
        path = "/usr/bin/uicache";
    else if(pathflag & kBRBakeBinaryPath_Rootless)
        path = "/var/jb/usr/bin/uicache";
    else if(pathflag & kBRBakeBinaryPath_Binpack)
        path = "/cores/binpack/usr/bin/uicache";
    
    if(!path)
    {
        ERR("path is not set");
        return -1;
    }
    
    if(!pathflag)
    {
        ERR("pathflag is not set");
        return -1;
    }
    
    if(!envflag)
    {
        ERR("envflag is not set");
        return -1;
    }
    
    if(envflag & kBRBakeEnvironment_Rootfull)
    {
        char *args[] = { path, "-a", NULL };
        return runCmd(args[0], args);
    }
    else if((envflag & kBRBakeEnvironment_Rootless) && (pathflag & kBRBakeBinaryPath_Rootless))
    {
        char *arg1[] = { path, "-a", NULL };
        if(runCmd(arg1[0], arg1))
            return -1;
        
        return 0;
    }
    
    return -1;
}

int startJBDeamons(uint64_t pathflag, uint64_t envflag)
{
    char *path = NULL;
    if(pathflag & kBRBakeBinaryPath_Rootfull)
        path = "/bin/launchctl";
    else if(pathflag & kBRBakeBinaryPath_Rootless)
        path = "/var/jb/bin/launchctl";
    else if(pathflag & kBRBakeBinaryPath_Binpack)
        path = "/cores/binpack/bin/launchctl";
    
    if(!path)
    {
        ERR("path is not set");
        return 0;
    }
    
    if(!pathflag)
    {
        ERR("pathflag is not set");
        return -1;
    }
    
    if(!envflag)
    {
        ERR("envflag is not set");
        return -1;
    }
    
    if(envflag & kBRBakeEnvironment_Rootfull)
    {
        char *args[] = { path, "load", "/Library/LaunchDaemons", NULL };
        return runCmd(args[0], args);
    }
    else if((envflag & kBRBakeEnvironment_Rootless) && (pathflag & kBRBakeBinaryPath_Rootless))
    {
        char *args[] = { path, "load", "/var/jb/Library/LaunchDaemons", NULL };
        return runCmd(args[0], args);
    }
    
    return -1;
}

int startRCD(uint64_t envflag)
{
    char *pdir = NULL;
    if(envflag & kBRBakeEnvironment_Rootfull)
    {
        pdir = "/etc/rc.d/";
    }
    else if(envflag & kBRBakeEnvironment_Rootless)
    {
        pdir = "/var/jb/etc/rc.d/";
    }
    else
    {
        ERR("not set");
        return -1;
    }
    
    DIR *d = NULL;
    struct dirent *dir = NULL;
    if ((d = opendir(pdir)))
    {
        while ((dir = readdir(d)))
        {
            //remove all subdirs and files
            if (strcmp(dir->d_name, ".") == 0 || strcmp(dir->d_name, "..") == 0)
            {
                continue;
            }
            char *pp = NULL;
            asprintf(&pp,"%s%s", pdir, dir->d_name);
            
            char *args[] = { pp, NULL };
            if(runCmd(args[0], args))
            {
                free(pp);
                closedir(d);
                return -1;
            }
            free(pp);
        }
        closedir(d);
    }
    
    return 0;
}

int startSubstrate(uint64_t typeflag, uint64_t envflag)
{
    char *path = NULL;
    
    if(typeflag & kBRBakeSubstrate_Substrate)
    {
        ERR("Substrate is not supported.");
        return -1;
    }
    else if(typeflag & kBRBakeSubstrate_Substitute)
    {
        if(envflag & kBRBakeEnvironment_Rootfull)
        {
            path = "/etc/rc.d/substitute-launcher";
        }
        else if(envflag & kBRBakeEnvironment_Rootless)
        {
            ERR("Rootless substitute is not supported.");
            return -1;
        }
    }
    else if(typeflag & kBRBakeSubstrate_Libhooker)
    {
        ERR("Libhooker is not supported.");
        return -1;
    }
    else if(typeflag & kBRBakeSubstrate_Ellekit)
    {
        if(envflag & kBRBakeEnvironment_Rootfull)
        {
            path = "/usr/libexec/ellekit/loader";
        }
        else if(envflag & kBRBakeEnvironment_Rootless)
        {
            path = "/var/jb/usr/libexec/ellekit/loader";
        }
    }

    if(!path)
    {
        ERR("path is not set");
        return -1;
    }
    
    char *args[] = { path, NULL };
    return runCmd(args[0], args);
}

void rootfullFlags(void)
{
    pflags = checkrain_option_none;
    
    // def
    pflags |= checkrain_option_overlay;
    pflags |= checkrain_option_rootfull;
    
    unsigned char buf[256];
    size_t length = 256;
    if(!sysctlbyname("kern.bootargs", buf, &length, NULL, 0))
    {
        if(strstr((const char *)buf, "BR_safemode="))
        {
            pflags |= checkrain_option_safemode;
        }
        if(strstr((const char *)buf, "BR_bind_mount="))
        {
            pflags |= checkrain_option_bind_mount;
        }
        if(strstr((const char *)buf, "BR_no_overlay="))
        {
            pflags &= ~checkrain_option_overlay;
        }
    }
}
