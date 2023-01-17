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

#include "utils.h"

extern kern_return_t
task_policy_set(
                task_t                  task,
                task_policy_flavor_t    flavor,
                task_policy_t           policy_info,
                mach_msg_type_number_t  count);

checkrain_option_t pflags;
bool userspace_reboot = false;


void reloadSystem(uint64_t envflag)
{
    int isSubstrateLoaded = 0;
    uint64_t substrateFlag = 0;
    uint64_t pathflag = 0;
    
    const char* ramfilepath = "ramfile://checkra1n";
    
    struct stat st;
    int notBinpack = stat("/binpack/.installed_overlay", &st);
    
    if( ((envflag & kBRBakeEnvironment_Rootfull) && checkrain_option_enabled(checkrain_option_overlay, pflags)) ||
        ((envflag & kBRBakeEnvironment_Rootless) && checkrain_option_enabled(checkrain_option_overlay, pflags)) )
    {
        if(notBinpack)
        {
            notBinpack = mount_overlay(ramfilepath, "hfs", "/binpack", MNT_RDONLY);
        }
    }
    
    close(creat("/private/var/tmp/.bakera1n_firstboot", 0x1ed));
    
    {
        char *mntp[] = { "/sbin/mount", "-uw", "/private/preboot", NULL };
        runCmd(mntp[0], mntp);
    }
    
    // set path
    if(envflag & kBRBakeEnvironment_Rootfull)
    {
        pathflag = kBRBakeBinaryPath_Rootfull;
    }
    else if(envflag & kBRBakeEnvironment_Rootless)
    {
        pathflag = kBRBakeBinaryPath_Rootless;
    }
    
    if(envflag & kBRBakeEnvironment_Rootfull)
    {
        if(!stat("/etc/rc.d/substitute-launcher", &st))
        {
            substrateFlag |= kBRBakeSubstrate_Substitute;
        }
        
        if(!stat("/usr/libexec/ellekit/loader", &st))
        {
            substrateFlag |= kBRBakeSubstrate_Ellekit;
        }
        
        
        // linking dyld_cache
        if(userspace_reboot)
        {
            DEVLOG("Detected userspace reboot, skip it.");
            isSubstrateLoaded = 1;
        }
        else if(!userspace_reboot &&
                (kCFCoreFoundationVersionNumber <= kCFCoreFoundationVersionNumber_iOS_16_1_2) &&
                (kCFCoreFoundationVersionNumber > kCFCoreFoundationVersionNumber_iOS_16))
        {
            if(stat("/System/Library/Caches/com.apple.dyld", &st))
            {
                mkdir("/System/Library/Caches/com.apple.dyld", 0755);
            }
            
            if(!stat("/System/Cryptexes/OS/System/Library/Caches/com.apple.dyld", &st) &&
               !stat("/System/Library/Caches/com.apple.dyld", &st) &&
               stat("/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64", &st))
            {
                DEVLOG("Binding fs");
                int err = mount("bindfs", "/System/Library/Caches/com.apple.dyld", 0, "/System/Cryptexes/OS/System/Library/Caches/com.apple.dyld");
                if (!err)
                {
                    // ok
                    sync();
                    sleep(1);
                }
                else
                {
                    // err
                    ERR("Failed to bind fs (%d)", err);
                    substrateFlag = 0;
                }
            }
        }
        else if((substrateFlag & kBRBakeSubstrate_Substitute) &&
                (kCFCoreFoundationVersionNumber > kCFCoreFoundationVersionNumber_iOS_16_1_2))
        {
            DEVLOG("Substitute is not supported on iOS 16.2+");
            substrateFlag = 0;
        }
        
        if(stat("/.installed_kok3shi", &st))
        {
            open("/.installed_kok3shi", O_RDWR|O_CREAT);
        }
        
    } /* kBRBakeEnvironment_Rootfull */
    
    if(envflag & kBRBakeEnvironment_Rootless)
    {
        if(!stat("/var/jb/usr/libexec/ellekit/loader", &st))
        {
            substrateFlag |= kBRBakeSubstrate_Ellekit;
        }
        
        if(stat("/var/jb/.installed_kok3shi", &st))
        {
            open("/.installed_kok3shi", O_RDWR|O_CREAT);
        }
        
    } /* kBRBakeEnvironment_Rootless */
    
    // load substrate
    if(!isSubstrateLoaded && !checkrain_option_enabled(checkrain_option_safemode, pflags))
    {
        if(!startSubstrate(substrateFlag, envflag))
        {
            // userspace reboot
            isSubstrateLoaded = 1;
            rebootUserspace(pathflag, envflag);
            sleep(3);
            // why still here...
            return;
        }
    }
    
    if(!notBinpack)
    {
        DEVLOG("running makeRSA");
        makeRSA();
        DEVLOG("running startDropbear");
        startDropbear();
        
        NSMutableDictionary* md = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
        if([md objectForKey:@"SBShowNonDefaultSystemApps"] == nil)
        {
            DEVLOG("injecting SBShowNonDefaultSystemApps");
            char *arg1[] = { "/binpack/usr/bin/killall", "-SIGSTOP", "cfprefsd", NULL };
            runCmd(arg1[0], arg1);
            
            [md setObject:[NSNumber numberWithBool:YES] forKey:@"SBShowNonDefaultSystemApps"];
            [md writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
            
            char *arg2[] = { "/binpack/usr/bin/killall", "-9", "cfprefsd", NULL };
            runCmd(arg2[0], arg2);
            
            char *arg3[] = { "/binpack/usr/sbin/chown", "501:501", "/var/mobile/Library/Preferences/com.apple.springboard.plist", NULL };
            runCmd(arg3[0], arg3);
        }
    }
    
    DEVLOG("loading deamons");
    sync();
    startJBDeamons(pathflag, envflag);
    sync();
    doUICache(pathflag, envflag);
    sync();
    
    return;
}


static inline __attribute__((always_inline)) int Stage4EntryGang(int argc, char **argv)
{
    DEVLOG("Enter rootless stage4");
    
    task_policy_t *policy_info = (task_policy_t*)1;
    task_policy_set(mach_task_self(), 1, (task_policy_t)&policy_info, 1);
    
    struct stat st;
    
    if(getFlags())
    {
        if(stat("/dev/rmd0", &st))
        {
            // TODO
            pflags = checkrain_option_none;
            pflags |= checkrain_option_overlay;
            if(!stat("/var/jb/.bakera1n_safe_mode", &st))
            {
                pflags |= checkrain_option_safemode;
            }
        }
        else
        {
            // ramdisk boot
            pflags = checkrain_option_failure;
        }
    }
    
    unmount("/Developer", 0x80000);
    
    if(stat("/private/var/tmp/.bakera1n_firstboot", &st))
        reloadSystem(kBRBakeEnvironment_Rootless);
    
    close(0x0);
    close(0x1);
    close(0x2);
    
    return 0;
}


static inline __attribute__((always_inline)) int Stage4RootFullGang(int argc, char **argv)
{
    DEVLOG("Enter rootfull stage4");
    
    task_policy_t *policy_info = (task_policy_t*)1;
    task_policy_set(mach_task_self(), 1, (task_policy_t)&policy_info, 1);
    
    struct stat st;
    
    {
        // TODO
        pflags = checkrain_option_none;
        pflags |= checkrain_option_overlay;
        if(!stat("/.bakera1n_safe_mode", &st))
        {
            pflags |= checkrain_option_safemode;
        }
    }
    
    unmount("/Developer", 0x80000);
    
    if(stat("/private/var/tmp/.bakera1n_firstboot", &st))
        reloadSystem(kBRBakeEnvironment_Rootfull);
    
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
