#include <am.h>
#include <nemu.h>

#define AUDIO_FREQ_ADDR (AUDIO_ADDR + 0x00)
#define AUDIO_CHANNELS_ADDR (AUDIO_ADDR + 0x04)
#define AUDIO_SAMPLES_ADDR (AUDIO_ADDR + 0x08)
#define AUDIO_SBUF_SIZE_ADDR (AUDIO_ADDR + 0x0c)
#define AUDIO_INIT_ADDR (AUDIO_ADDR + 0x10)
#define AUDIO_COUNT_ADDR (AUDIO_ADDR + 0x14)

void __am_audio_init()
{
}

void __am_audio_config(AM_AUDIO_CONFIG_T *cfg)
{
  cfg->present = true; // 存在audio设备实现
  cfg->bufsize = inl(AUDIO_SBUF_SIZE_ADDR);
}

void __am_audio_ctrl(AM_AUDIO_CTRL_T *ctrl)
{
  outl(AUDIO_FREQ_ADDR, ctrl->freq);
  outl(AUDIO_CHANNELS_ADDR, ctrl->channels);
  outl(AUDIO_SAMPLES_ADDR, ctrl->samples);
  outl(AUDIO_INIT_ADDR, 1); // 可以初始化了
}

void __am_audio_status(AM_AUDIO_STATUS_T *stat)
{
  stat->count = inl(AUDIO_COUNT_ADDR); // 已用字节
}

static size_t sbuf_point = 0; // 不能使用已用大小去定义指针 因为可能是从中间计算的

void __am_audio_play(AM_AUDIO_PLAY_T *ctl)
{
  uint32_t sbuf_size = inl(AUDIO_SBUF_SIZE_ADDR);
  uint32_t size = ctl->buf.end - ctl->buf.start;
  uint8_t *sbuf = (uint8_t *)AUDIO_SBUF_ADDR;
  uint8_t *data = (uint8_t *)ctl->buf.start;
  // 发完所有字节再返回
  while (size--)
  {
    // 监测只要有一个空余就可以填充
    while (sbuf_size - inl(AUDIO_COUNT_ADDR) < 1)
      ;
    sbuf[sbuf_point++] = *(data++);
    // 迭代addr data
    if (sbuf_point >= sbuf_size) // 循环缓冲区
      sbuf_point = 0;

    outl(AUDIO_COUNT_ADDR, inl(AUDIO_COUNT_ADDR) + 1); // 更新已用大小
  }
}