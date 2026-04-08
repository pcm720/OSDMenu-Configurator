#include "devices/pad.h"
#include <kernel.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static char padBuf[256] __attribute__((aligned(64)));

int port, slot;

static int waitPadReadyState(int p, int s, int maxPolls) {
  int state = PAD_STATE_DISCONN;
  int polls = (maxPolls > 0) ? maxPolls : 1;
  for (int i = 0; i < polls; ++i) {
    state = padGetState(p, s);
    if ((state == PAD_STATE_STABLE) || (state == PAD_STATE_FINDCTP1) || (state == PAD_STATE_DISCONN))
      break;
    DelayThread(1000);
  }
  return state;
}

static void tryEnableAnalogMode(int p, int s) {
  int state = waitPadReadyState(p, s, 2000);
  if (state == PAD_STATE_DISCONN) {
    printf("devices_pad: controller disconnected; analog mode skipped\n");
    return;
  }

  int modeCount = padInfoMode(p, s, PAD_MODETABLE, -1);
  if (modeCount <= 0) {
    int cur = padInfoMode(p, s, PAD_MODECURID, 0);
    printf("devices_pad: mode table unavailable (count=%d, current=%d)\n", modeCount, cur);
    return;
  }

  int hasDualShock = 0;
  for (int i = 0; i < modeCount; ++i) {
    int mode = padInfoMode(p, s, PAD_MODETABLE, i);
    if (mode == PAD_TYPE_DUALSHOCK) {
      hasDualShock = 1;
      break;
    }
  }

  if (!hasDualShock) {
    int cur = padInfoMode(p, s, PAD_MODECURID, 0);
    printf("devices_pad: no dualshock mode in table (count=%d, current=%d)\n", modeCount, cur);
    return;
  }

  int setRet = padSetMainMode(p, s, PAD_MMODE_DUALSHOCK, PAD_MMODE_LOCK);
  waitPadReadyState(p, s, 300);
  int cur = padInfoMode(p, s, PAD_MODECURID, 0);
  printf("devices_pad: analog request ret=%d current_mode=%d\n", setRet, cur);
}

struct padButtonStatus readPad(int port, int slot) {
  struct padButtonStatus buttons;
  int ret;

  do {
    ret = padGetState(port, slot);
  } while ((ret != PAD_STATE_STABLE) && (ret != PAD_STATE_FINDCTP1));

  ret = padRead(port, slot, &buttons);

  return buttons;
}

int isButtonPressed(uint32_t button) {
  int ret;
  uint32_t paddata;

  struct padButtonStatus padbuttons;

  while (((ret = padGetState(0, 0)) != PAD_STATE_STABLE) && (ret != PAD_STATE_FINDCTP1) && (ret != PAD_STATE_DISCONN))
    ; // more error check ?
  if (padRead(0, 0, &padbuttons) != 0) {
    paddata = 0xffff ^ padbuttons.btns;
    if (paddata & button)
      return 1;
  }
  return 0;
}

void pad_init() {
  printf("devices_pad: initializing\n");
  int ret;

  padInit(0);

  port = 0; // 0 -> Connector 1, 1 -> Connector 2
  slot = 0; // Always zero if not using multitap

  if ((ret = padPortOpen(port, slot, padBuf)) == 0) {
    printf("devices_pad: padOpenPort failed: %d\n", ret);
    SleepThread();
  }

  tryEnableAnalogMode(port, slot);
}

void pad_deinit(void) {
  printf("devices_pad: closing\n");
  padPortClose(port, slot);
  padEnd();
}
