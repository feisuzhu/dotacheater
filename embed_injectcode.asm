;MASMPlus 代码模板 - 使用动态链接库
;这个工程模板演示了 MASMPlus 的多工程方式,由一个主程序与动态库组成
;动态库文件有自己的编译/链接设置,工程文件总是优先于主程序编译.
;模板每个工程组都还有res资源模块,使用资源编辑器编辑.编译时会自动链接.
;同时,请设置主程序文件与动态库文件工程组属性,两个模块之间的辅助输入才不会混乱.
;如果添加了新文件,首先请设置它的组ID,否则默认新文件总是被所有工程文件共享
;按下Ctrl点击文档选择栏多选,再单击右键,即可设置组,参数设置请在单个项目上单击右键

.386
.Model Flat, StdCall
Option Casemap :None

include windows.inc
include user32.inc
include kernel32.inc
include macro.asm

includelib kernel32.lib
includelib user32.lib

assume fs:nothing

.data?
	buf db 1000h dup(?)
.CODE
START:

invoke CreateFile, offset CTEXT("DLL.dll"),GENERIC_READ,FILE_SHARE_READ,0,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
mov esi, eax
invoke CreateFile, offset CTEXT("..\loader\console.exe"),GENERIC_WRITE,FILE_SHARE_READ,0,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
mov edi, eax
invoke SetFilePointer, esi, 400h,0,FILE_BEGIN
invoke SetFilePointer, edi, 800h,0,FILE_BEGIN
invoke ReadFile, esi, offset buf, 1000h,esp,0
invoke WriteFile, edi, offset buf, 1000h, esp, 0
invoke ExitProcess, 0

END START