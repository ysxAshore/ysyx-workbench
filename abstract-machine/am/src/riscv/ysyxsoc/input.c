#include <am.h>
#include <ysyxsoc.h>

void __am_input_config(AM_INPUT_CONFIG_T *cfg)
{
  cfg->present = false;
}

void __am_input_keybrd(AM_INPUT_KEYBRD_T *kbd)
{
  kbd->keydown = 0;
  kbd->keycode = AM_KEY_NONE;
}
