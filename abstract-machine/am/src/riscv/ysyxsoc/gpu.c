#include <am.h>
#include <stdint.h>
#include <ysyxsoc.h>

#define VGACTL_WIDTH 640
#define VGACTL_HEIGHT 480

void __am_gpu_init()
{
    int w = VGACTL_WIDTH;
    int h = VGACTL_HEIGHT;
    uint32_t *fb = (uint32_t *)(uintptr_t)FB_ADDR;
    for (int y = 0; y < h; y++)
    {
        for (int x = 0; x < w; x++)
        {
            fb[x << 9 | y] = 0; // 初始化为黑色
        }
    }
}

void __am_gpu_config(AM_GPU_CONFIG_T *cfg)
{
    *cfg = (AM_GPU_CONFIG_T){
        .present = true,
        .has_accel = false,
        .width = VGACTL_WIDTH,
        .height = VGACTL_HEIGHT,
        .vmemsz = VGACTL_WIDTH * VGACTL_HEIGHT * sizeof(uint32_t)};
}

void __am_gpu_fbdraw(AM_GPU_FBDRAW_T *ctl)
{
    int x0 = ctl->x, y0 = ctl->y, w = ctl->w, h = ctl->h;
    uint32_t *pixels = ctl->pixels;
    int W = VGACTL_WIDTH;
    int H = VGACTL_HEIGHT;
    uint32_t *fb = (uint32_t *)(uintptr_t)FB_ADDR;

    for (int j = 0; j < h && y0 + j < H; j++)
    {
        for (int i = 0; i < w && x0 + i < W; i++)
        {
            int index = (x0 + i) << 9 | (y0 + j);
            fb[index] = pixels[j * w + i] & 0xffffff;
        }
    }
}
void __am_gpu_status(AM_GPU_STATUS_T *status)
{
    status->ready = true;
}
