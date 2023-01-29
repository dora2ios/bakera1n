/*
 * pongoOS - https://checkra.in
 *
 * Copyright (C) 2019-2022 checkra1n team
 *
 * This file is part of pongoOS.
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
#include <errno.h>
#include <fcntl.h>              // open
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>             // exit, strtoull
#include <string.h>             // strlen, strerror, memcpy, memmove
#include <unistd.h>             // close
#include <wordexp.h>
#include <sys/mman.h>           // mmap, munmap
#include <sys/stat.h>           // fstst
#include <getopt.h>

#include "../build/kpf.h"
#include "../build/ramdisk.h"
#include "../build/overlay.h"

#define checkrain_option_none               0x00000000
// KPF options
#define checkrain_option_verbose_boot       (1 << 0)
#define checkrain_kpf_option_rootfull       (1 << 8)
#define checkrain_kpf_option_fakelaunchd    (1 << 9)
#define checkrain_kpf_option_vnode_check_open   (1 << 10)

// Global options
#define checkrain_option_safemode           (1 << 0)
#define checkrain_option_bind_mount         (1 << 1)
#define checkrain_option_overlay            (1 << 2)
#define checkrain_option_force_revert       (1 << 7) /* keep this at 7 */
#define checkrain_option_rootfull           (1 << 8)
#define checkrain_option_not_snapshot       (1 << 9)

enum AUTOBOOT_STAGE {
    NONE,
    SETUP_STAGE_FUSE,
    SETUP_STAGE_SEP,
    SEND_STAGE_KPF,
    SETUP_STAGE_KPF,
    SEND_STAGE_RAMDISK,
    SETUP_STAGE_RAMDISK,
    SEND_STAGE_OVERLAY,
    SETUP_STAGE_OVERLAY,
    SETUP_STAGE_KPF_FLAGS,
    SETUP_STAGE_CHECKRAIN_FLAGS,
    SETUP_STAGE_XARGS,
    SETUP_STAGE_ROOTDEV,
    BOOTUP_STAGE,
    USB_TRANSFER_ERROR,
};

enum AUTOBOOT_STAGE CURRENT_STAGE = NONE;

static bool use_autoboot = false;
static bool use_bindfs = false;
static bool use_rootful = false;
static bool use_safemode = false;
static bool no_snapshot = false;
static bool use_verbose_boot = false;
static bool use_hook_vnode_check_open = false;

static char* root_device = NULL;

static char* bootArgs = NULL;
static uint32_t kpf_flags = checkrain_option_none;
static uint32_t checkra1n_flags = checkrain_option_none;

#define LOG(fmt, ...) do { fprintf(stderr, "\x1b[1;96m" fmt "\x1b[0m\n", ##__VA_ARGS__); } while(0)
#define ERR(fmt, ...) do { fprintf(stderr, "\x1b[1;91m" fmt "\x1b[0m\n", ##__VA_ARGS__); } while(0)

// Keep in sync with Pongo
#define PONGO_USB_VENDOR    0x05ac
#define PONGO_USB_PRODUCT   0x4141
#define CMD_LEN_MAX         512
#define UPLOADSZ_MAX        (1024 * 1024 * 128)

static uint8_t gBlockIO = 1;

typedef struct stuff stuff_t;

static void io_start(stuff_t *stuff);
static void io_stop(stuff_t *stuff);

/********** ********** ********** ********** **********
 * Platform-specific code must define:
 * - usb_ret_t
 * - usb_device_handle_t
 * - USB_RET_SUCCESS
 * - USB_RET_NOT_RESPONDING
 * - usb_strerror
 * - struct stuff, which must contain the fields "handle"
 *   and "th", but may contain more than just that.
 * - USBControlTransfer
 * - USBBulkUpload
 * - pongoterm_main
 ********** ********** ********** ********** **********/

#include <mach/mach.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/IOCFPlugIn.h>

typedef IOReturn usb_ret_t;
typedef IOUSBInterfaceInterface245 **usb_device_handle_t;

#define USB_RET_SUCCESS         KERN_SUCCESS
#define USB_RET_NOT_RESPONDING  kIOReturnNotResponding

static inline const char *usb_strerror(usb_ret_t err)
{
    return mach_error_string(err);
}

static usb_ret_t USBControlTransfer(usb_device_handle_t handle, uint8_t bmRequestType, uint8_t bRequest, uint16_t wValue, uint16_t wIndex, uint32_t wLength, void *data, uint32_t *wLenDone)
{
    IOUSBDevRequest request =
    {
        .bmRequestType = bmRequestType,
        .bRequest = bRequest,
        .wValue = wValue,
        .wIndex = wIndex,
        .wLength = wLength,
        .pData = data,
    };
    usb_ret_t ret = (*handle)->ControlRequest(handle, 0, &request);
    if(wLenDone) *wLenDone = request.wLenDone;
    return ret;
}

static usb_ret_t USBBulkUpload(usb_device_handle_t handle, void *data, uint32_t len)
{
    return (*handle)->WritePipe(handle, 2, data, len);
}

struct stuff
{
    pthread_t th;
    volatile uint64_t regID;
    IOUSBDeviceInterface245 **dev;
    usb_device_handle_t handle;
};

static void FoundDevice(void *refCon, io_iterator_t it)
{
    stuff_t *stuff = refCon;
    if(stuff->regID)
    {
        return;
    }
    io_service_t usbDev = MACH_PORT_NULL;
    while((usbDev = IOIteratorNext(it)))
    {
        uint64_t regID;
        kern_return_t ret = IORegistryEntryGetRegistryEntryID(usbDev, &regID);
        if(ret != KERN_SUCCESS)
        {
            ERR("IORegistryEntryGetRegistryEntryID: %s", mach_error_string(ret));
            goto next;
        }
        SInt32 score = 0;
        IOCFPlugInInterface **plugin = NULL;
        ret = IOCreatePlugInInterfaceForService(usbDev, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score);
        if(ret != KERN_SUCCESS)
        {
            ERR("IOCreatePlugInInterfaceForService(usbDev): %s", mach_error_string(ret));
            goto next;
        }
        HRESULT result = (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID*)&stuff->dev);
        (*plugin)->Release(plugin);
        if(result != 0)
        {
            ERR("QueryInterface(dev): 0x%x", result);
            goto next;
        }
        ret = (*stuff->dev)->USBDeviceOpenSeize(stuff->dev);
        if(ret != KERN_SUCCESS)
        {
            ERR("USBDeviceOpenSeize: %s", mach_error_string(ret));
        }
        else
        {
            ret = (*stuff->dev)->SetConfiguration(stuff->dev, 1);
            if(ret != KERN_SUCCESS)
            {
                ERR("SetConfiguration: %s", mach_error_string(ret));
            }
            else
            {
                IOUSBFindInterfaceRequest request =
                {
                    .bInterfaceClass = kIOUSBFindInterfaceDontCare,
                    .bInterfaceSubClass = kIOUSBFindInterfaceDontCare,
                    .bInterfaceProtocol = kIOUSBFindInterfaceDontCare,
                    .bAlternateSetting = kIOUSBFindInterfaceDontCare,
                };
                io_iterator_t iter = MACH_PORT_NULL;
                ret = (*stuff->dev)->CreateInterfaceIterator(stuff->dev, &request, &iter);
                if(ret != KERN_SUCCESS)
                {
                    ERR("CreateInterfaceIterator: %s", mach_error_string(ret));
                }
                else
                {
                    io_service_t usbIntf = MACH_PORT_NULL;
                    while((usbIntf = IOIteratorNext(iter)))
                    {
                        ret = IOCreatePlugInInterfaceForService(usbIntf, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score);
                        IOObjectRelease(usbIntf);
                        if(ret != KERN_SUCCESS)
                        {
                            ERR("IOCreatePlugInInterfaceForService(usbIntf): %s", mach_error_string(ret));
                            continue;
                        }
                        result = (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), (LPVOID*)&stuff->handle);
                        (*plugin)->Release(plugin);
                        if(result != 0)
                        {
                            ERR("QueryInterface(intf): 0x%x", result);
                            continue;
                        }
                        ret = (*stuff->handle)->USBInterfaceOpen(stuff->handle);
                        if(ret != KERN_SUCCESS)
                        {
                            ERR("USBInterfaceOpen: %s", mach_error_string(ret));
                        }
                        else
                        {
                            io_start(stuff);
                            stuff->regID = regID;
                            while((usbIntf = IOIteratorNext(iter))) IOObjectRelease(usbIntf);
                            IOObjectRelease(iter);
                            while((usbDev = IOIteratorNext(it))) IOObjectRelease(usbDev);
                            IOObjectRelease(usbDev);
                            return;
                        }
                        (*stuff->handle)->Release(stuff->handle);
                        stuff->handle = NULL;
                    }
                    IOObjectRelease(iter);
                }
            }
        }

    next:;
        if(stuff->dev)
        {
            (*stuff->dev)->USBDeviceClose(stuff->dev);
            (*stuff->dev)->Release(stuff->dev);
            stuff->dev = NULL;
        }
        IOObjectRelease(usbDev);
    }
}

static void LostDevice(void *refCon, io_iterator_t it)
{
    stuff_t *stuff = refCon;
    io_service_t usbDev = MACH_PORT_NULL;
    while((usbDev = IOIteratorNext(it)))
    {
        uint64_t regID;
        kern_return_t ret = IORegistryEntryGetRegistryEntryID(usbDev, &regID);
        IOObjectRelease(usbDev);
        if(ret == KERN_SUCCESS && stuff->regID == regID)
        {
            io_stop(stuff);
            stuff->regID = 0;
            (*stuff->handle)->USBInterfaceClose(stuff->handle);
            (*stuff->handle)->Release(stuff->handle);
            (*stuff->dev)->USBDeviceClose(stuff->dev);
            (*stuff->dev)->Release(stuff->dev);
        }
    }
}

static int pongoterm_main(void)
{
    kern_return_t ret;
    stuff_t stuff = {};
    io_iterator_t found, lost;
    NSDictionary *dict =
    @{
        @"IOProviderClass": @"IOUSBDevice",
        @"idVendor":  @PONGO_USB_VENDOR,
        @"idProduct": @PONGO_USB_PRODUCT,
    };
    CFDictionaryRef cfdict = (__bridge CFDictionaryRef)dict;
    IONotificationPortRef notifyPort = IONotificationPortCreate(kIOMainPortDefault);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notifyPort), kCFRunLoopDefaultMode);

    CFRetain(cfdict);
    ret = IOServiceAddMatchingNotification(notifyPort, kIOFirstMatchNotification, cfdict, &FoundDevice, &stuff, &found);
    if(ret != KERN_SUCCESS)
    {
        ERR("IOServiceAddMatchingNotification: %s", mach_error_string(ret));
        return -1;
    }
    FoundDevice(&stuff, found);

    CFRetain(cfdict);
    ret = IOServiceAddMatchingNotification(notifyPort, kIOTerminatedNotification, cfdict, &LostDevice, &stuff, &lost);
    if(ret != KERN_SUCCESS)
    {
        ERR("IOServiceAddMatchingNotification: %s", mach_error_string(ret));
        return -1;
    }
    LostDevice(&stuff, lost);
    CFRunLoopRun();
    return -1;
}

static void write_stdout(char *buf, uint32_t len)
{
    while(len > 0)
    {
        ssize_t s = write(1, buf, len);
        if(s < 0)
        {
            ERR("write: %s", strerror(errno));
            exit(-1); // TODO: ok with libusb?
        }
        buf += s;
        len -= s;
    }
}

static void* io_main(void *arg)
{
    stuff_t *stuff = arg;
    int r = pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, NULL);
    if(r != 0)
    {
        ERR("pthread_setcancelstate: %s", strerror(r));
        exit(-1); // TODO: ok with libusb?
    }
    LOG("[Connected]");
    usb_ret_t ret = USB_RET_SUCCESS;
    char prompt[64] = "> ";
    uint32_t plen = 2;
    while(1)
    {
        char buf[0x2000] = {};
        uint32_t outpos = 0;
        uint32_t outlen = 0;
        uint8_t in_progress = 1;
        while(in_progress)
        {
            ret = USBControlTransfer(stuff->handle, 0xa1, 2, 0, 0, (uint32_t)sizeof(in_progress), &in_progress, NULL);
            if(ret == USB_RET_SUCCESS)
            {
                ret = USBControlTransfer(stuff->handle, 0xa1, 1, 0, 0, 0x1000, buf + outpos, &outlen);
                if(ret == USB_RET_SUCCESS)
                {
                    write_stdout(buf + outpos, outlen);
                    outpos += outlen;
                    if(outpos > 0x1000)
                    {
                        memmove(buf, buf + outpos - 0x1000, 0x1000);
                        outpos = 0x1000;
                    }
                }
            }
            if(ret != USB_RET_SUCCESS)
            {
                goto bad;
            }
        }
        if(outpos > 0)
        {
            // Record prompt
            uint32_t start = outpos;
            for(uint32_t end = outpos > 64 ? outpos - 64 : 0; start > end; --start)
            {
                if(buf[start-1] == '\n')
                {
                    break;
                }
            }
            plen = outpos - start;
            memcpy(prompt, buf + start, plen);
        }
        else
        {
            // Re-emit prompt
            write_stdout(prompt, plen);
        }
        ret = USBControlTransfer(stuff->handle, 0x21, 4, 0xffff, 0, 0, NULL, NULL);
        if(ret != USB_RET_SUCCESS)
        {
            goto bad;
        }
        r = pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);
        if(r != 0)
        {
            ERR("pthread_setcancelstate: %s", strerror(r));
            exit(-1); // TODO: ok with libusb?
        }
        size_t len = 0;
        while(1)
        {
            if(use_autoboot)
                break;
            
            char ch;
            ssize_t s = read(0, &ch, 1);
            if(s == 0)
            {
                break;
            }
            if(s < 0)
            {
                if(errno == EINTR)
                {
                    return NULL;
                }
                ERR("read: %s", strerror(errno));
                exit(-1); // TODO: ok with libusb?
            }
            if(len < sizeof(buf))
            {
                buf[len] = ch;
            }
            ++len;
            if(ch == '\n')
            {
                break;
            }
        }
        r = pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, NULL);
        if(r != 0)
        {
            ERR("pthread_setcancelstate: %s", strerror(r));
            exit(-1); // TODO: ok with libusb?
        }
        if(len == 0)
        {
            if(use_autoboot)
            {
                
                {
                    if(CURRENT_STAGE == NONE)
                        CURRENT_STAGE = SETUP_STAGE_FUSE;
                    
                    if(CURRENT_STAGE == SETUP_STAGE_FUSE)
                    {
                        ret = USBControlTransfer(stuff->handle, 0x21, 3, 0, 0, (uint32_t)(strlen("fuse lock\n")), "fuse lock\n", NULL);
                        if(ret == USB_RET_SUCCESS)
                        {
                            LOG("%s", "fuse lock");
                            CURRENT_STAGE = SETUP_STAGE_SEP;
                        }
                        else
                        {
                            CURRENT_STAGE = USB_TRANSFER_ERROR;
                        }
                        continue;
                    }
                    
                    if(CURRENT_STAGE == SETUP_STAGE_SEP)
                    {
                        ret = USBControlTransfer(stuff->handle, 0x21, 3, 0, 0, (uint32_t)(strlen("sep auto\n")), "sep auto\n", NULL);
                        if(ret == USB_RET_SUCCESS)
                        {
                            LOG("%s", "sep auto");
                            CURRENT_STAGE = SEND_STAGE_KPF;
                        }
                        else
                        {
                            CURRENT_STAGE = USB_TRANSFER_ERROR;
                        }
                        continue;
                    }
                    
                    if(CURRENT_STAGE == SEND_STAGE_KPF)
                    {
                        size_t size = kpf_len;
                        ret = USBControlTransfer(stuff->handle, 0x21, 1, 0, 0, 4, &size, NULL);
                        if(ret == USB_RET_SUCCESS)
                        {
                            ret = USBBulkUpload(stuff->handle, kpf, kpf_len);
                            if(ret == USB_RET_SUCCESS)
                            {
                                LOG("/send %s\n%s: %llu bytes", "kpf", "kpf", (unsigned long long)kpf_len);
                                CURRENT_STAGE = SETUP_STAGE_KPF;
                            }
                            else
                            {
                                CURRENT_STAGE = USB_TRANSFER_ERROR;
                            }
                        }
                        else
                        {
                            CURRENT_STAGE = USB_TRANSFER_ERROR;
                        }
                        continue;
                    }
                    
                    if(CURRENT_STAGE == SETUP_STAGE_KPF)
                    {
                        ret = USBControlTransfer(stuff->handle, 0x21, 3, 0, 0, (uint32_t)(strlen("modload\n")), "modload\n", NULL);
                        if(ret == USB_RET_SUCCESS)
                        {
                            LOG("%s", "modload");
                            if(!root_device)
                                CURRENT_STAGE = SEND_STAGE_RAMDISK;
                            else
                                CURRENT_STAGE = SETUP_STAGE_ROOTDEV;
                        }
                        else
                        {
                            CURRENT_STAGE = USB_TRANSFER_ERROR;
                        }
                        continue;
                    }
                    
                    if(CURRENT_STAGE == SEND_STAGE_RAMDISK)
                    {
                        size_t size = ramdisk_dmg_len;
                        ret = USBControlTransfer(stuff->handle, 0x21, 1, 0, 0, 4, &size, NULL);
                        if(ret == USB_RET_SUCCESS)
                        {
                            ret = USBBulkUpload(stuff->handle, ramdisk_dmg, ramdisk_dmg_len);
                            if(ret == USB_RET_SUCCESS)
                            {
                                LOG("/send %s\n%s: %llu bytes", "ramdisk", "ramdisk", (unsigned long long)ramdisk_dmg_len);
                                CURRENT_STAGE = SETUP_STAGE_RAMDISK;
                            }
                            else
                            {
                                CURRENT_STAGE = USB_TRANSFER_ERROR;
                            }
                        }
                        else
                        {
                            CURRENT_STAGE = USB_TRANSFER_ERROR;
                        }
                        continue;
                    }
                    
                    if(CURRENT_STAGE == SETUP_STAGE_RAMDISK)
                    {
                        ret = USBControlTransfer(stuff->handle, 0x21, 3, 0, 0, (uint32_t)(strlen("ramdisk\n")), "ramdisk\n", NULL);
                        if(ret == USB_RET_SUCCESS)
                        {
                            LOG("%s", "ramdisk");
                          CURRENT_STAGE = SEND_STAGE_OVERLAY;
                        }
                        else
                        {
                            CURRENT_STAGE = USB_TRANSFER_ERROR;
                        }
                        continue;
                    }
                    
                    if(CURRENT_STAGE == SETUP_STAGE_ROOTDEV)
                    {
                        if(root_device)
                        {
                            char str[64];
                            memset(&str, 0x0, 64);
                            sprintf(str, "set_rootdev %s\n", root_device);
                            ret = USBControlTransfer(stuff->handle, 0x21, 3, 0, 0, (uint32_t)(strlen(str)), str, NULL);
                            if(ret == USB_RET_SUCCESS)
                            {
                                memset(&str, 0x0, 64);
                                sprintf(str, "set_rootdev %s", root_device);
                                LOG("%s", str);
                                CURRENT_STAGE = SEND_STAGE_OVERLAY;
                            }
                            else
                            {
                                CURRENT_STAGE = USB_TRANSFER_ERROR;
                            }
                        }
                        else
                        {
                            ERR("root_device not found");
                            CURRENT_STAGE = USB_TRANSFER_ERROR;
                        }
                        continue;
                    }
                    
                    if(CURRENT_STAGE == SEND_STAGE_OVERLAY)
                    {
                        size_t size = overlay_dmg_len;
                        ret = USBControlTransfer(stuff->handle, 0x21, 1, 0, 0, 4, &size, NULL);
                        if(ret == USB_RET_SUCCESS)
                        {
                            ret = USBBulkUpload(stuff->handle, overlay_dmg, overlay_dmg_len);
                            if(ret == USB_RET_SUCCESS)
                            {
                                LOG("/send %s\n%s: %llu bytes", "overlay", "overlay", (unsigned long long)overlay_dmg_len);
                                CURRENT_STAGE = SETUP_STAGE_OVERLAY;
                            }
                            else
                            {
                                CURRENT_STAGE = USB_TRANSFER_ERROR;
                            }
                        }
                        continue;
                    }
                    
                    if(CURRENT_STAGE == SETUP_STAGE_OVERLAY)
                    {
                        
                        ret = USBControlTransfer(stuff->handle, 0x21, 3, 0, 0, (uint32_t)(strlen("overlay\n")), "overlay\n", NULL);
                        if(ret == USB_RET_SUCCESS)
                        {
                            LOG("%s", "overlay");
                            CURRENT_STAGE = SETUP_STAGE_KPF_FLAGS;
                        }
                        else
                        {
                            CURRENT_STAGE = USB_TRANSFER_ERROR;
                        }
                        continue;
                    }
                    
                    if(CURRENT_STAGE == SETUP_STAGE_KPF_FLAGS)
                    {
                        
                        if(root_device)
                        {
                            if(use_rootful)
                            {
                                kpf_flags |= checkrain_kpf_option_rootfull;
                            }
                            kpf_flags |= checkrain_kpf_option_fakelaunchd;
                        }
                        
                        if(use_verbose_boot)
                        {
                            kpf_flags |= checkrain_option_verbose_boot;
                        }
                        
                        if(use_hook_vnode_check_open)
                        {
                            kpf_flags |= checkrain_kpf_option_vnode_check_open;
                        }
                        
                        char str[64];
                        memset(&str, 0x0, 64);
                        sprintf(str, "kpf_flags 0x%08x\n", kpf_flags);
                        ret = USBControlTransfer(stuff->handle, 0x21, 3, 0, 0, (uint32_t)(strlen(str)), str, NULL);
                        if(ret == USB_RET_SUCCESS)
                        {
                            memset(&str, 0x0, 64);
                            sprintf(str, "kpf_flags 0x%08x", kpf_flags);
                            LOG("%s", str);
                            CURRENT_STAGE = SETUP_STAGE_CHECKRAIN_FLAGS;
                        }
                        else
                        {
                            CURRENT_STAGE = USB_TRANSFER_ERROR;
                        }
                        continue;
                    }
                    
                    if(CURRENT_STAGE == SETUP_STAGE_CHECKRAIN_FLAGS)
                    {
                        
                        if(use_bindfs)
                        {
                            checkra1n_flags |= checkrain_option_bind_mount;
                        }
                        
                        if(use_rootful)
                        {
                            checkra1n_flags |= checkrain_option_rootfull;
                        }
                        
                        if(use_safemode)
                        {
                            checkra1n_flags |= checkrain_option_safemode;
                        }
                        
                        if(no_snapshot)
                        {
                            checkra1n_flags |= checkrain_option_not_snapshot;
                        }
                        
                        char str[64];
                        memset(&str, 0x0, 64);
                        sprintf(str, "checkra1n_flags 0x%08x\n", checkra1n_flags);
                        ret = USBControlTransfer(stuff->handle, 0x21, 3, 0, 0, (uint32_t)(strlen(str)), str, NULL);
                        if(ret == USB_RET_SUCCESS)
                        {
                            memset(&str, 0x0, 64);
                            sprintf(str, "checkra1n_flags 0x%08x", checkra1n_flags);
                            LOG("%s", str);
                            CURRENT_STAGE = SETUP_STAGE_XARGS;
                        }
                        else
                        {
                            CURRENT_STAGE = USB_TRANSFER_ERROR;
                        }
                        continue;
                    }
                    
                    
                    if(CURRENT_STAGE == SETUP_STAGE_XARGS)
                    {
                        char str[256];
                        memset(&str, 0x0, 256);
                        
                        char* defaultBootArgs = NULL;
                        
                        defaultBootArgs = "serial=3";
                        if(!root_device)
                        {
                            defaultBootArgs = "serial=3 rootdev=md0";
                        }
                        
                        if(defaultBootArgs)
                        {
                            if(strlen(defaultBootArgs) > 256) {
                                ERR("defaultBootArgs is too large!");
                                CURRENT_STAGE = USB_TRANSFER_ERROR;
                                continue;
                            }
                            sprintf(str, "%s", defaultBootArgs);
                        }
                        
                        if(bootArgs)
                        {
                            // sprintf(str, "xargs %s\n", bootArgs);
                            if((strlen(str) + strlen(bootArgs)) > 256) {
                                ERR("bootArgs is too large!");
                                CURRENT_STAGE = USB_TRANSFER_ERROR;
                                continue;
                            }
                            sprintf(str, "%s %s", str, bootArgs);
                        }
                        
                        if(root_device)
                        {
                            {
                                if((strlen(str) + sizeof("rootdev=") + strlen(root_device)) > 256) {
                                    ERR("bootArgs is too large!");
                                    CURRENT_STAGE = USB_TRANSFER_ERROR;
                                    continue;
                                }
                                sprintf(str, "%s rootdev=%s", str, root_device);
                            }
                            
                            if(use_safemode)
                            {
                                if((strlen(str) + sizeof("BR_safemode=1")) > 256) {
                                    ERR("bootArgs is too large!");
                                    CURRENT_STAGE = USB_TRANSFER_ERROR;
                                    continue;
                                }
                                sprintf(str, "%s %s", str, "BR_safemode=1");
                            }
                            if(use_bindfs)
                            {
                                if((strlen(str) + sizeof("BR_bind_mount=1")) > 256) {
                                    ERR("bootArgs is too large!");
                                    CURRENT_STAGE = USB_TRANSFER_ERROR;
                                    continue;
                                }
                                sprintf(str, "%s %s", str, "BR_bind_mount=1");
                            }
                        }
                        
                        if(use_verbose_boot)
                        {
                            if((strlen(str) + sizeof("-v")) > 256) {
                                ERR("bootArgs is too large!");
                                CURRENT_STAGE = USB_TRANSFER_ERROR;
                                continue;
                            }
                            sprintf(str, "%s %s", str, "-v");
                        }
                        
                        
                        char xstr[256 + 7];
                        memset(&xstr, 0x0, 256 + 7);
                        sprintf(xstr, "xargs %s\n", str);
                        
                        ret = USBControlTransfer(stuff->handle, 0x21, 3, 0, 0, (uint32_t)(strlen(xstr)), xstr, NULL);
                        if(ret == USB_RET_SUCCESS)
                        {
                            LOG("%s", str);
                            CURRENT_STAGE = BOOTUP_STAGE;
                        }
                        else
                        {
                            CURRENT_STAGE = USB_TRANSFER_ERROR;
                        }
                        continue;
                    }
                    
                    if(CURRENT_STAGE == BOOTUP_STAGE)
                    {
                        ret = USBControlTransfer(stuff->handle, 0x21, 3, 0, 0, (uint32_t)(strlen("bootx\n")), "bootx\n", NULL);
                        if(ret == USB_RET_SUCCESS)
                        {
                            LOG("%s", "bootx");
                            exit(0);
                        }
                        else
                        {
                            CURRENT_STAGE = USB_TRANSFER_ERROR;
                        }
                        continue;
                    }
                    
                    if(CURRENT_STAGE == USB_TRANSFER_ERROR)
                    {
                        ERR("WTF?!");
                        exit(-1);
                    }
                }
            }
            
            
            exit(0); // TODO: ok with libusb?
        }
        if(len > sizeof(buf))
        {
            ERR("Discarding command of >%zu chars", sizeof(buf));
            continue;
        }
        if(buf[0] == '/')
        {
            buf[len-1] = '\0';
            wordexp_t we;
            r = wordexp(buf + 1, &we, WRDE_SHOWERR | WRDE_UNDEF);
            if(r != 0)
            {
                ERR("wordexp: %d", r);
                continue;
            }
            bool show_help = false;
            if(we.we_wordc == 0)
            {
                show_help = true;
            }
            else if(strcmp(we.we_wordv[0], "send") == 0)
            {
                if(we.we_wordc == 1)
                {
                    LOG("Usage: /send [file]");
                    LOG("Upload a file to PongoOS. This should be followed by a command such as \"modload\".");
                }
                else
                {
                    int fd = open(we.we_wordv[1], O_RDONLY);
                    if(fd < 0)
                    {
                        ERR("Failed to open file: %s", strerror(errno));
                    }
                    else
                    {
                        struct stat s;
                        r = fstat(fd, &s);
                        if(r != 0)
                        {
                            ERR("Failed to stat file: %s", strerror(errno));
                        }
                        else
                        {
                            void *addr = mmap(NULL, s.st_size, PROT_READ, MAP_FILE | MAP_PRIVATE, fd, 0);
                            if(addr == MAP_FAILED)
                            {
                                ERR("Failed to map file: %s", strerror(errno));
                            }
                            else
                            {
                                uint32_t newsz = s.st_size;
                                ret = USBControlTransfer(stuff->handle, 0x21, 1, 0, 0, 4, &newsz, NULL);
                                if(ret == USB_RET_SUCCESS)
                                {
                                    ret = USBBulkUpload(stuff->handle, addr, s.st_size);
                                    if(ret == USB_RET_SUCCESS)
                                    {
                                        LOG("Uploaded %llu bytes", (unsigned long long)s.st_size);
                                    }
                                }
                                munmap(addr, s.st_size);
                            }
                        }
                        close(fd);
                    }
                }
            }
            else
            {
                ERR("Unrecognised command: /%s", we.we_wordv[0]);
                show_help = true;
            }
            if(show_help)
            {
                LOG("Available commands:");
                LOG("/send [file] - Upload a file to PongoOS");
            }
            wordfree(&we);
        }
        else
        {
            if(len > CMD_LEN_MAX)
            {
                ERR("PongoOS currently only supports commands with %u characters or less", CMD_LEN_MAX);
                continue;
            }
            if(gBlockIO)
            {
                ret = USBControlTransfer(stuff->handle, 0x21, 4, 1, 0, 0, NULL, NULL);
            }
            if(ret == USB_RET_SUCCESS)
            {
                ret = USBControlTransfer(stuff->handle, 0x21, 3, 0, 0, (uint32_t)len, buf, NULL);
            }
        }
        if(ret != USB_RET_SUCCESS)
        {
            goto bad;
        }
    }
bad:;
    if(ret == USB_RET_NOT_RESPONDING)
    {
        return NULL;
    }
    ERR("USB error: %s", usb_strerror(ret));
    exit(-1); // TODO: ok with libusb?
}

static void io_start(stuff_t *stuff)
{
    int r = pthread_create(&stuff->th, NULL, &io_main, stuff);
    if(r != 0)
    {
        ERR("pthread_create: %s", strerror(r));
        exit(-1); // TODO: ok with libusb?
    }
}

static void io_stop(stuff_t *stuff)
{
    LOG("[Disconnected]");
    int r = pthread_cancel(stuff->th);
    if(r != 0)
    {
        ERR("pthread_cancel: %s", strerror(r));
        exit(-1); // TODO: ok with libusb?
    }
    r = pthread_join(stuff->th, NULL);
    if(r != 0)
    {
        ERR("pthread_join: %s", strerror(r));
        exit(-1); // TODO: ok with libusb?
    }
}

static void usage(const char* s)
{
    LOG("Usage: %s [-ahnsov] [-e <boot-args>] [-u <root_device>]", s);
    return;
}

int main(int argc, char** argv)
{
    if(argc < 2)
    {
        usage(argv[0]);
        return -1;
    }
    
    int opt = 0;
    static struct option longopts[] = {
        { "help",               no_argument,       NULL, 'h' },
        { "autoboot",           no_argument,       NULL, 'a' },
        { "noBlockIO",          no_argument,       NULL, 'n' },
        { "extra-bootargs",     required_argument, NULL, 'e' },
//      { "bindfs",             no_argument,       NULL, 'b' },
        { "rootful",            required_argument, NULL, 'u' },
//      { "stable-rootless",    required_argument, NULL, 'r' },
        { "safemode",           no_argument,       NULL, 's' },
        { "no-snapshot",        no_argument,       NULL, 'o' },
        { "verbose-boot",       no_argument,       NULL, 'v' },
        { "vnode_check_open",   no_argument,       NULL, 'k' },
        { NULL, 0, NULL, 0 }
    };
    
    while ((opt = getopt_long(argc, argv, "ahne:u:sovk", longopts, NULL)) > 0) {
        switch (opt) {
            case 'h':
                usage(argv[0]);
                return 0;
                
            case 'n':
                gBlockIO = 0;
                break;
                
            case 'a':
                use_autoboot = 1;
                LOG("selected: autoboot mode");
                break;
                
            case 'e':
                if (optarg) {
                    bootArgs = strdup(optarg);
                    LOG("set bootArgs: [%s]", bootArgs);
                }
                break;
                
//          case 'b':
//              use_bindfs = 1;
//              break;
                
            case 'u':
                use_rootful = 1;
                if (optarg) {
                    root_device = strdup(optarg);
                    LOG("rootdevice: [%s]", root_device);
                }
                break;
                
//          case 'r':
//              use_rootful = 0;
//              if (optarg) {
//                  root_device = strdup(optarg);
//                  LOG("rootdevice: [%s]", root_device);
//              }
//              break;
                
            case 's':
                use_safemode = 1;
                break;
                
            case 'o':
                no_snapshot = 1;
                break;
                
            case 'v':
                use_verbose_boot = 1;
                break;
                
            case 'k':
                use_hook_vnode_check_open = 1;
                break;
                
            default:
                usage(argv[0]);
                return -1;
        }
    }
    
    return pongoterm_main();
}
