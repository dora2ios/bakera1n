/*
 * bakera1n - stage4.m
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

static void loadSystem(uint64_t envflag)
{
    int isSubstrateLoaded = 0;
    uint64_t substrateFlag = 0;
    uint64_t pathflag = 0;
    struct stat st;
    
    // mount overlay
    const char* ramfilepath = "ramfile://checkra1n";
    int notBinpack = 0;
    
    if(checkrain_option_enabled(checkrain_option_overlay, pflags))
    {
        notBinpack = stat("/cores/binpack/.installed_overlay", &st);
        if(notBinpack)
        {
            notBinpack = mount_overlay(ramfilepath, "hfs", "/cores/binpack", MNT_RDONLY);
        }
    }
    
    // just mark
    close(creat("/private/var/tmp/.bakera1n_firstboot", 0x1ed));
    
    // remount preboot
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
        if(!stat("/var/jb/.installed_bakera1n", &st))
        {
            pathflag = kBRBakeBinaryPath_Rootless;
        }
        else
        {
            pathflag = kBRBakeBinaryPath_Binpack;
        }
    }
    
    // load substrate etc
    {
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
            
            if(userspace_reboot)
            {
                DEVLOG("Detected userspace reboot, skip it.");
                isSubstrateLoaded = 1;
            }
            if(stat("/.installed_bakera1n", &st))
            {
                open("/.installed_bakera1n", O_RDWR|O_CREAT);
            }
            
        } /* kBRBakeEnvironment_Rootfull */
        
        if(envflag & kBRBakeEnvironment_Rootless)
        {
            if((!stat("/var/jb/usr/libexec/ellekit/loader", &st)) && (pathflag & kBRBakeBinaryPath_Rootless))
            {
                substrateFlag |= kBRBakeSubstrate_Ellekit;
            }
        } /* kBRBakeEnvironment_Rootless && kBRBakeBinaryPath_Rootless */
        
        // load substrate
        if(!isSubstrateLoaded &&
           !checkrain_option_enabled(checkrain_option_safemode, pflags))
        {
            if(!startSubstrate(substrateFlag, envflag))
            {
                isSubstrateLoaded = 1;
            }
        }
    }
    
    DEVLOG("loading jb deamons");
    startJBDeamons(pathflag, envflag);
    
    return;
}

int stage4Entry(uint64_t envflag)
{
    DEVLOG("stage4Entry");
    
    struct stat st;
    
    if(!(envflag & kBRBakeEnvironment_Rootfull))
    {
        if(getFlags())
        {
            pflags = checkrain_option_failure;
        }
    }
    else
    {
        // rootfull
        rootfullFlags();
    }
    
    unmount("/Developer", 0x80000);
    
    if(stat("/private/var/tmp/.bakera1n_firstboot", &st))
    {
        loadSystem(envflag);
    }
    
    close(0x0);
    close(0x1);
    close(0x2);
    
    return 0;
}

