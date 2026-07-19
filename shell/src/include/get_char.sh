#!/bin/bash

# 从终端读取单个字符，无需按回车键。
# stty -g：以机器可读格式保存当前所有终端设置
# stty -echo 关闭回显，禁止终端显示输入的字符
# stty cbreak 启用字符模式，cbreak 模式：字符一输入就立即传递给程序，无需等待换行符
#             原始模式 (raw)：完全禁用所有特殊处理
#             cbreak 模式：保留中断、退出、挂起等控制字符的处理
#             规范模式 (cooked)：默认模式，需要按回车才提交
# dd if=/dev/tty bs=1 count=1 2> /dev/null 读取单个字符
#             dd：数据复制工具
#             if=/dev/tty：从当前终端设备读取（不是标准输入）
#             bs=1：块大小为 1 字节
#             count=1：只读取 1 个字符
#             2> /dev/null：将错误信息重定向到空设备（静默模式）
# 恢复终端设置
# stty -raw    # 退出原始模式（如果设置了的话）
# stty echo    # 重新启用回显
# stty $SAVEDSTTY  # 恢复所有原始设置

[[ -n "${_GET_CHAR_SH:-}" ]] && return
readonly _GET_CHAR_SH=1

get_char() {
  SAVEDSTTY=$(stty -g)
  stty -echo
  stty cbreak
  dd if=/dev/tty bs=1 count=1 2> /dev/null
  stty -raw
  stty echo
  stty $SAVEDSTTY
}
