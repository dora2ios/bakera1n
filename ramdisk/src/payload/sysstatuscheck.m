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

checkrain_option_t pflags;
bool userspace_reboot = false;

int rootless(void)
{
    if(userspace_reboot)
    {
        char *arg[] = { "stage4lessd", "-i", NULL };
        runCmd("/haxx", arg);
    }
    else
    {
        char *arg[] = { "stage4lessd", NULL };
        runCmd("/haxx", arg);
    }
    return 0;
}

int rootful(void)
{
    if(userspace_reboot)
    {
        char *arg[] = { "stage4fulld", "-i", NULL };
        runCmd("/haxx", arg);
    }
    else
    {
        char *arg[] = { "stage4fulld", NULL };
        runCmd("/haxx", arg);
    }
    return 0;
}

int main(int argc, char **argv)
{
    init();
    
    printf("#==================\n");
    printf("#\n");
    printf("# bakera1n sysstatuscheck %s\n", VERSION);
    printf("#\n");
    printf("# (c) 2023 bakera1n developer\n");
    printf("#==================\n");
    
    DEVLOG("Hello check!");
    
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
    
    // ayyy
    if(strcmp(argv[0], "bakera1nlessd") == 0x0)
    {
        rootless();
    }
    
    if(strcmp(argv[0], "bakera1nfulld") == 0x0)
    {
        rootful();
    }
    
    // end
    close(0x0);
    close(0x1);
    close(0x2);
    
    pid_t pd = fork();
    if (pd != 0) {
        // Parent
        char *args[] = { "/usr/libexec/sysstatuscheck", NULL };
        execve("/usr/libexec/sysstatuscheck", args, environ);
        return -1;
    }
    
    return 0;
}
