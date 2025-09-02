#include <am.h>
#include <nemu.h>

static uint64_t start;
void __am_timer_init()
{
  uint32_t high = inl(RTC_ADDR + 0x4);
  uint32_t low = inl(RTC_ADDR);
  start = ((uint64_t)high << 32) + low;
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime)
{
  uint32_t high = inl(RTC_ADDR + 0x4);
  uint32_t low = inl(RTC_ADDR);
  uptime->us = ((uint64_t)high << 32) + low - start;
}

// 1970年之后每年天数（闰年为366天）
const int days_in_month[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

int is_leap(int year)
{
  return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
}
void my_localtime(long long seconds, AM_TIMER_RTC_T *tm)
{
  seconds += CONFIG_TIME_ZONE * 3600;
  // 1. 先求出时分秒
  tm->second = seconds % 60;
  seconds /= 60;
  tm->minute = seconds % 60;
  seconds /= 60;
  tm->hour = seconds % 24;
  seconds /= 24; // 剩下的是“自1970年以来的天数”

  // 2. 计算当前是哪一年
  int year = 1970;
  while (1)
  {
    int days_this_year = is_leap(year) ? 366 : 365;
    if (seconds >= days_this_year)
      seconds -= days_this_year, year++;
    else
      break;
  }
  tm->year = year;

  // 3. 当前是该年中的第几天
  int yday = seconds + 1;
  // tm->week_day = (4 + yday) % 7; // 1970-01-01 是星期四（第4天）

  // 4. 确定月份和日
  int mon = 0;
  while (1)
  {
    int dim = days_in_month[mon];
    if (mon == 2 && is_leap(year))
      dim++; // 处理闰年2月
    if (yday <= dim)
      break;
    yday -= dim;
    mon++;
  }
  tm->month = mon + 1;
  tm->day = yday;
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc)
{
  uint32_t high = inl(RTC_ADDR + 0x4);
  uint32_t low = inl(RTC_ADDR);
  uint64_t us = ((uint64_t)high << 32) + low;
  my_localtime(us / 1000000, rtc);
}
