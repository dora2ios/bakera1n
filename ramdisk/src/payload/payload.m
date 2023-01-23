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

checkrain_option_t pflags = checkrain_option_none;
bool userspace_reboot = false;
static uint64_t gEnvFlag = 0;

int main(int argc, char **argv)
{
    init();
    
    gEnvFlag = 0;
    
    printf("#==================\n");
    printf("#\n");
    printf("# bakera1n %s %s\n", argv[0], VERSION);
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
    
    if(argc == 3)
    {
        if(!strcmp(argv[1], "-i"))
        {
            userspace_reboot = true;
        }
        
        if(!strcmp(argv[2], "-u"))
        {
            gEnvFlag = kBRBakeEnvironment_Rootfull;
        }
        
        if(!strcmp(argv[2], "-r"))
        {
            gEnvFlag = kBRBakeEnvironment_Rootless;
        }
    }
    
    if(!gEnvFlag)
    {
        goto end;
    }
    
    DEVLOG("userspace_reboot: %d", userspace_reboot);
    
    // setup ssh, do uicache (called by launchd(libpayload))
    if(strcmp(argv[0], "bakera1nd") == 0x0)
    {
        return bakera1nEntry(gEnvFlag);
    }
    
    // setup substrate, load deamons (called by sysstatuscheck)
    if((strcmp(argv[0], "stage4lessd") == 0x0) ||(strcmp(argv[0], "stage4fulld") == 0x0))
    {
        // rootless entry
        return stage4Entry(gEnvFlag);
    }
    
    // sysstatuscheck (called by launchd(libpayload))
    if((strcmp(argv[0], "bakera1nlessd") == 0x0) ||(strcmp(argv[0], "bakera1nfulld") == 0x0))
    {
        sysstatuscheck(gEnvFlag);
        
        pid_t pd = fork();
        if (pd == 0)
        {
            // Parent
            DEVLOG("running sysstatuscheck");
            close(0x0);
            close(0x1);
            close(0x2);
            
            char *args[] = { "/usr/libexec/sysstatuscheck", NULL };
            execve("/usr/libexec/sysstatuscheck", args, environ);
            return -1;
        }
        close(0x0);
        close(0x1);
        close(0x2);
        return -1;
    }
    
end:
    ERR("What the HELL?!");
    close(0x0);
    close(0x1);
    close(0x2);
    
    return -1;
}
