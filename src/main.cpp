#include "devices/init.h"
#include "devices/pad.h"
#include "devices/utils.h"
#include "devices/vfs.h"
#include "graphics/graphics.h"
#include "graphics/splash.h"
#include "lua/player.h"
#include "lua/system.h"
#include <fcntl.h>
#include <malloc.h>
#include <string.h>
#include <unistd.h>

// Root Lua script
extern uint8_t boot_lua[];
extern uint32_t size_boot_lua;
#ifdef EMBED_VFS
// Embedded virtual filesystem
extern uint8_t vfs[];
extern uint32_t size_vfs;
#endif

// Attempts to detect root device and load device drivers required for accessing CWD
char *resolveRootDevice(char *argv0);
static char *dup_path(const char *src);

static char *dup_path(const char *src) {
  size_t len;
  char *dst;
  if (!src)
    return NULL;
  len = strlen(src) + 1;
  dst = (char *)malloc(len);
  if (!dst)
    return NULL;
  memcpy(dst, src, len);
  return dst;
}

int main(int argc, char *argv[]) {
  // Show splash
  initGraphics();
  showSplashScreen();

  printf("\n******\nOSDMenu Configurator %s by pcm720\nBased on Enceladus by DanielSant0s\nhttps://github.com/DanielSant0s/Enceladus\n******\n\n", APP_VERSION);

  // Init basic device drivers
  if (device_init()) {
    init_scr();
    scr_setfontcolor(0x0000ff);
    scr_clear();
    scr_setXY(5, 2);
    scr_printf("Enceladus ERROR!\n");
    scr_printf("Failed to initialize modules");
    sleep(10);
    Exit(-1);
  }

  char *rootPath = resolveRootDevice(argv[0]);
  lua_set_root(rootPath);
  if (argv[0] != rootPath)
    free(rootPath);

#ifdef EMBED_VFS
  vfs_init(vfs, size_vfs);
#endif

  const char *errMsg = NULL;
  printf("main: entering main loop\n");
  while (1) {
    // if no parameters are specified, use the default boot
    errMsg = runScript(reinterpret_cast<const char *>(boot_lua), true);

    init_scr();
    if (errMsg != NULL) {
      scr_setfontcolor(0x0000ff);
      scr_clear();
      scr_setXY(5, 2);
      scr_printf("Enceladus ERROR!\n");
      scr_printf(errMsg);
      puts(errMsg);
      scr_printf("\nPress [start] to restart\n");
      while (!isButtonPressed(PAD_START)) {
        sleep(1);
      }
      scr_setfontcolor(0xffffff);
    }
  }

  return 0;
}

// Attempts to detect root device and load device drivers required for accessing CWD
// Returns root path to device ELF
char *resolveRootDevice(char *argv0) {
  if (argv0 == NULL)
    return argv0;
  char *result = argv0;
  int ownsResult = 0;
  // Load device drivers for boot path
  printf("argv[0] is %s, guessing device type\n", argv0);
  uint32_t device = devices_guess_device_type(argv0);
  if (device & Device_MMCE) {
    printf("main: loading MMCE drivers\n");
    device_init_load_modules("mmce");
    return result;
  } else if (device & Device_HDD) {
    printf("main: loading HDD drivers\n");
    device_init_load_modules("hdd");
    devices_probe(argv0, 10);
    return result;
  } else if (device & Device_BDM) {
    printf("main: loading BDM drivers\n");
    device_init_load_modules("hdd");
    device_init_load_modules("usb");
    device_init_load_modules("mx4sio");
  } else
    return result;

  // Find current working directory for BDM
  if (device & Device_BDM) {
    size_t argvLen = strlen(argv0);
    int hasExpectedMassPrefix = 0;
    printf("main: probing root path for BDM device\n");
    if (argvLen >= 7 && argv0[4] >= '0' && argv0[4] <= '7' && argv0[5] == ':' && argv0[6] == '/')
      hasExpectedMassPrefix = 1;
    if (!hasExpectedMassPrefix) {
      // argv[0] is "mass:" or doesn't have a trailing slash, fix it to "mass?:/".
      const char *tail = strchr(argv0, ':');
      if (tail) {
        tail++;
        while (*tail == '/')
          tail++;
      } else {
        tail = argv0;
      }
      size_t arglen = strlen(tail) + 8;
      result = (char *)malloc(arglen);
      if (!result)
        return argv0;
      snprintf(result, arglen, "mass?:/%s", tail);
      ownsResult = 1;
    } else if (result == argv0) {
      // Never mutate argv[0] directly while probing.
      result = dup_path(argv0);
      if (!result)
        return argv0;
      ownsResult = 1;
    }

    int fd = 0;
    for (int i = 0; i < 8; i++) {
      if (strlen(result) <= 4) {
        if (ownsResult)
          free(result);
        return argv0;
      }
      result[4] = '0' + i;
      printf("main: probing %s\n", result);
      if (devices_probe(result, 2)) {
        printf("main: failed to probe\n");
        if (ownsResult)
          free(result);
        return argv0; // No BDM devices were found
      }
      fd = open(result, O_RDONLY);
      if (fd >= 0) {
        printf("main: found root path\n");
        close(fd);
        return result;
      }
    }
    if (ownsResult)
      free(result);
  }
  return argv0;
}
