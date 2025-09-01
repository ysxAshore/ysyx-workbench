/***************************************************************************************
 * Copyright (c) 2014-2024 Zihao Yu, Nanjing University
 *
 * NEMU is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 *          http://license.coscl.org.cn/MulanPSL2
 *
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
 * EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
 * MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 *
 * See the Mulan PSL v2 for more details.
 ***************************************************************************************/

#include <common.h>
#include <device/map.h>
#include <SDL2/SDL.h>

enum
{
  reg_freq,
  reg_channels,
  reg_samples,
  reg_sbuf_size,
  reg_init,
  reg_count,
  nr_reg
};

static uint8_t *sbuf = NULL;
static uint32_t *audio_base = NULL;
static int sbuf_point = 0;

static void audio_callback(void *userdata, Uint8 *stream, int len)
{
  // 初始化音频数据为静音
  SDL_memset(stream, 0, len);

  // 获取缓冲区长度 取缓冲区已用长度和len中的最小值
  uint32_t useSize = audio_base[reg_count];
  uint32_t size = useSize < len ? useSize : len;

  if (sbuf_point + size > CONFIG_SB_SIZE)
  {
    SDL_MixAudio(stream, sbuf + sbuf_point, CONFIG_SB_SIZE - sbuf_point, SDL_MIX_MAXVOLUME);
    SDL_MixAudio(stream + CONFIG_SB_SIZE - sbuf_point, sbuf, size - CONFIG_SB_SIZE + sbuf_point, SDL_MIX_MAXVOLUME);
    // sbuf_point = (size - CONFIG_SB_SIZE + sbuf_point) % CONFIG_SB_SIZE;
  }
  else
  {
    SDL_MixAudio(stream, sbuf + sbuf_point, size, SDL_MIX_MAXVOLUME);
    // sbuf_point = (sbuf_point + size) % CONFIG_SB_SIZE; //这里应该是需要%CONFIG_SIZE
  }
  sbuf_point = (sbuf_point + size) % CONFIG_SB_SIZE;
  audio_base[reg_count] -= size; // 播放完了可以释放空间
}

static void init_SDL()
{
  SDL_AudioSpec s = {};
  s.format = AUDIO_S16SYS;
  s.userdata = NULL;
  s.channels = audio_base[reg_channels];
  s.samples = audio_base[reg_samples];
  s.freq = audio_base[reg_freq];
  s.callback = audio_callback;

  SDL_InitSubSystem(SDL_INIT_AUDIO);
  SDL_OpenAudio(&s, NULL);
  SDL_PauseAudio(0);
}

static void audio_io_handler(uint32_t offset, int len, bool is_write)
{
  if (audio_base[reg_init])
  {
    init_SDL();
    audio_base[reg_init] = 0;
  }
}

void init_audio()
{
  uint32_t space_size = sizeof(uint32_t) * nr_reg;
  audio_base = (uint32_t *)new_space(space_size);
#ifdef CONFIG_HAS_PORT_IO
  add_pio_map("audio", CONFIG_AUDIO_CTL_PORT, audio_base, space_size, audio_io_handler);
#else
  add_mmio_map("audio", CONFIG_AUDIO_CTL_MMIO, audio_base, space_size, audio_io_handler);
#endif

  sbuf = (uint8_t *)new_space(CONFIG_SB_SIZE);
  add_mmio_map("audio-sbuf", CONFIG_SB_ADDR, sbuf, CONFIG_SB_SIZE, NULL);

  audio_base[reg_sbuf_size] = CONFIG_SB_SIZE;
}
