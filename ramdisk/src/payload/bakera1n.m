/*
 * bakera1n - bakera1n.m
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

int bakera1nEntry(uint64_t envflag)
{
    DEVLOG("bakera1nEntry");
    
    int notBinpack = 0;
    uint64_t pathflag = 0;
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
    
    if(checkrain_option_enabled(checkrain_option_overlay, pflags))
    {
        notBinpack = stat("/cores/binpack/.installed_overlay", &st);
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
            char *arg1[] = { "/cores/binpack/usr/bin/killall", "-SIGSTOP", "cfprefsd", NULL };
            runCmd(arg1[0], arg1);
            
            [md setObject:[NSNumber numberWithBool:YES] forKey:@"SBShowNonDefaultSystemApps"];
            [md writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
            
            char *arg2[] = { "/cores/binpack/usr/bin/killall", "-9", "cfprefsd", NULL };
            runCmd(arg2[0], arg2);
            
            char *arg3[] = { "/cores/binpack/usr/sbin/chown", "501:501", "/var/mobile/Library/Preferences/com.apple.springboard.plist", NULL };
            runCmd(arg3[0], arg3);
        }
    }
    
    DEVLOG("loading jb deamons");
    startJBDeamons(pathflag, envflag);
    
    doUICache(pathflag, envflag);
    
    close(0x0);
    close(0x1);
    close(0x2);
    
    return 0;
}
