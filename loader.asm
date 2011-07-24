;MASMPlus 代码模板 - 控制台程序

.386
.model flat, stdcall
option casemap :none

include windows.inc
include user32.inc
include kernel32.inc
include masm32.inc
include gdi32.inc

includelib gdi32.lib
includelib user32.lib
includelib kernel32.lib
includelib masm32.lib
include macro.asm

GetProcessIdByName proto :DWORD

.data
	bCode db 1000h dup(0)
	
.data?
	buffer	db MAX_PATH dup(?)
	hProc dd ?
	dwPid dd ?
	pMem dd ?
.CODE
START:
	invoke GetModuleHandle, offset CTEXT("ntdll.dll")
	invoke GetProcAddress, eax, offset CTEXT("RtlAdjustPrivilege")
	push offset buffer ; old enable
	push 0 ; current thread ?
	push 1 ; enable ?
	push 14h ; 14h = SE_DEBUG_PRIVILEGE
	call eax
	.while 1
		invoke GetProcessIdByName, offset CTEXT("war3.exe")
		.break .if eax
		invoke Sleep, 500
	.endw
	mov esi, eax
	
	invoke OpenProcess, PROCESS_CREATE_THREAD OR PROCESS_VM_OPERATION OR PROCESS_VM_WRITE, NULL, esi
	mov hProc, eax
	invoke VirtualAllocEx, eax, NULL, 1000h, MEM_COMMIT, PAGE_EXECUTE_READWRITE
	mov pMem, eax
	
	invoke WriteProcessMemory, hProc, pMem, offset bCode, sizeof bCode, offset buffer
	invoke GetModuleHandle, CTEXT("kernel32.dll")
	invoke GetProcAddress, eax, CTEXT("GetProcAddress")
	invoke CreateRemoteThread, hProc, NULL, NULL, pMem, eax, NULL, offset buffer
	
	invoke MessageBox, 0, offset CTEXT("Loaded!"), offset CTEXT("Proton's Dota Cheater"), MB_ICONINFORMATION
	
	invoke ExitProcess,0

GetProcessIdByName proc uses esi ebx lpProcessName:DWORD
LOCAL pe:PROCESSENTRY32
	
	invoke CreateToolhelp32Snapshot, TH32CS_SNAPPROCESS, NULL
	mov esi, eax
	mov eax, sizeof PROCESSENTRY32
	mov pe.dwSize, eax
	lea ebx, pe
	
	invoke Process32First, esi, ebx
	
	assume ebx: ptr PROCESSENTRY32
	.while TRUE
		invoke Process32Next, esi, ebx
		.break .if eax == 0
		invoke CompareString, LOCALE_USER_DEFAULT, NORM_IGNORECASE, lpProcessName, -1, addr [ebx].szExeFile, -1
		.if eax == 2
			mov eax, [ebx].th32ProcessID
			ret
		.endif
	.endw
	xor eax, eax
	ret
	assume ebx: nothing
	
GetProcessIdByName endp

end START