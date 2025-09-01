#include <am.h>
#include <nemu.h>

#define SYNC_ADDR (VGACTL_ADDR + 4)

void __am_gpu_init()
{
}

void __am_gpu_config(AM_GPU_CONFIG_T *cfg)
{
  uint32_t config = inl(VGACTL_ADDR);
  *cfg = (AM_GPU_CONFIG_T){
      .present = true, .has_accel = false, .width = config >> 16, .height = config & 0xffff, .vmemsz = 0};
}

void __am_gpu_fbdraw(AM_GPU_FBDRAW_T *ctl)
{
  // ctl params: 在ctl->x、ctl->y位置上绘制ctl->w ctl->h大小的矩形 像素来自于ctl->pixels
  uint32_t config = inl(VGACTL_ADDR);
  uint32_t screen_w = config >> 16;
  uint32_t screen_h = config & 0xffff;
  uint32_t *pixels = (uint32_t *)ctl->pixels;
  uint32_t *fb = (uint32_t *)(uintptr_t)FB_ADDR;

  // i表示行坐标 j表示列坐标
  for (int j = 0; j < ctl->h && ctl->y + j < screen_h; ++j)
  {
    uint32_t fb_begin = screen_w * (ctl->y + j) + ctl->x;
    uint32_t pixels_begin = j * ctl->w;
    for (int i = 0; i < ctl->w && ctl->x + i < screen_w; ++i)
      *(fb + fb_begin + i) = *(pixels + pixels_begin + i);
  }

  if (ctl->sync)
    outl(SYNC_ADDR, 1);
}

void __am_gpu_status(AM_GPU_STATUS_T *status)
{
  status->ready = true;
}
