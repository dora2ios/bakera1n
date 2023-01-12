
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <string.h>
#include <sys/sysctl.h>
#include <sys/mount.h>
#include <errno.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <pthread.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <dirent.h>
#include <stdarg.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>

typedef void* xpc_object_t;
typedef void* xpc_type_t;
typedef void* launch_data_t;
typedef bool (^xpc_dictionary_applier_t)(const char *key, xpc_object_t value);

xpc_object_t xpc_dictionary_create(const char * const *keys, const xpc_object_t *values, size_t count);
void xpc_dictionary_set_uint64(xpc_object_t dictionary, const char *key, uint64_t value);
void xpc_dictionary_set_string(xpc_object_t dictionary, const char *key, const char *value);
int64_t xpc_dictionary_get_int64(xpc_object_t dictionary, const char *key);
xpc_object_t xpc_dictionary_get_value(xpc_object_t dictionary, const char *key);
bool xpc_dictionary_get_bool(xpc_object_t dictionary, const char *key);
void xpc_dictionary_set_fd(xpc_object_t dictionary, const char *key, int value);
void xpc_dictionary_set_bool(xpc_object_t dictionary, const char *key, bool value);
const char *xpc_dictionary_get_string(xpc_object_t dictionary, const char *key);
void xpc_dictionary_set_value(xpc_object_t dictionary, const char *key, xpc_object_t value);
xpc_type_t xpc_get_type(xpc_object_t object);
bool xpc_dictionary_apply(xpc_object_t xdict, xpc_dictionary_applier_t applier);
int64_t xpc_int64_get_value(xpc_object_t xint);
char *xpc_copy_description(xpc_object_t object);
void xpc_dictionary_set_int64(xpc_object_t dictionary, const char *key, int64_t value);
const char *xpc_string_get_string_ptr(xpc_object_t xstring);
xpc_object_t xpc_array_create(const xpc_object_t *objects, size_t count);
xpc_object_t xpc_string_create(const char *string);
size_t xpc_dictionary_get_count(xpc_object_t dictionary);
void xpc_array_append_value(xpc_object_t xarray, xpc_object_t value);

#define XPC_ARRAY_APPEND ((size_t)(-1))
#define XPC_ERROR_CONNECTION_INVALID XPC_GLOBAL_OBJECT(_xpc_error_connection_invalid)
#define XPC_ERROR_TERMINATION_IMMINENT XPC_GLOBAL_OBJECT(_xpc_error_termination_imminent)
#define XPC_TYPE_ARRAY (&_xpc_type_array)
#define XPC_TYPE_BOOL (&_xpc_type_bool)
#define XPC_TYPE_DICTIONARY (&_xpc_type_dictionary)
#define XPC_TYPE_ERROR (&_xpc_type_error)
#define XPC_TYPE_STRING (&_xpc_type_string)

extern const struct _xpc_dictionary_s _xpc_error_connection_invalid;
extern const struct _xpc_dictionary_s _xpc_error_termination_imminent;
extern const struct _xpc_type_s _xpc_type_array;
extern const struct _xpc_type_s _xpc_type_bool;
extern const struct _xpc_type_s _xpc_type_dictionary;
extern const struct _xpc_type_s _xpc_type_error;
extern const struct _xpc_type_s _xpc_type_string;

#define DYLD_INTERPOSE(_replacment,_replacee) \
__attribute__((used)) static struct{ const void* replacment; const void* replacee; } _interpose_##_replacee \
__attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacment, (const void*)(unsigned long)&_replacee };

xpc_object_t my_xpc_dictionary_get_value(xpc_object_t dict, const char *key)
{
    xpc_object_t ret = xpc_dictionary_get_value(dict, key);
    if (strcmp(key, "LaunchDaemons") == 0)
    {
        // payload
        xpc_object_t programArguments = xpc_array_create(NULL, 0);
        xpc_array_append_value(programArguments, xpc_string_create("stage4gang"));
        if(getenv("XPC_USERSPACE_REBOOTED"))
        {
            xpc_array_append_value(programArguments, xpc_string_create("-i"));
        }
        
        xpc_object_t job = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_bool(job, "KeepAlive", false);
        xpc_dictionary_set_string(job, "Label", "com.ayakurume.payload");
        xpc_dictionary_set_bool(job, "LaunchOnlyOnce", true);
        xpc_dictionary_set_string(job, "Program", "/haxx");
        xpc_dictionary_set_bool(job, "RunAtLoad", true);
        xpc_dictionary_set_value(job, "ProgramArguments", programArguments);
        xpc_dictionary_set_value(ret, "/System/Library/LaunchDaemons/com.ayakurume.payload.plist", job);
    }
    return ret;
}
DYLD_INTERPOSE(my_xpc_dictionary_get_value, xpc_dictionary_get_value);

//int my_NSGetExecutablePath(char* buf, uint32_t* bufsize) {
//    if (getpid() == 1)
//    {
//        *bufsize = sizeof("/payload");
//        strncpy(buf, "/payload", (size_t)(*bufsize));
//    }
//    return _NSGetExecutablePath(buf, bufsize);
//}
//DYLD_INTERPOSE(my_NSGetExecutablePath, _NSGetExecutablePath);

void SIGBUSHandler(int __unused _) {}
__attribute__((constructor))
static void customConstructor(int argc, const char **argv)
{
    signal(SIGBUS, SIGBUSHandler);
}
