;在此文档的文档工具栏项目上单击右键->参数属性

.686
.model flat, stdcall
option casemap :none

include windows.inc
include user32.inc
include kernel32.inc

includelib user32.lib
includelib kernel32.lib

PingMiniMapEx proto x:DWORD, y:DWORD, duration:DWORD, color:DWORD, extraEffects:DWORD
DisplayText proto pString:DWORD, dwDuration:DWORD
MainProc proto u1:DWORD, u2:DWORD, idEvent:DWORD, u4:DWORD

GameOriginalBase equ 6F000000h

OFFS macro p, s:=<START>
	exitm <(offset p - offset s)>
endm

RLC macro p, basereg:=<ebx>
	exitm <[basereg+OFFS(p)]>
endm

push_offset_RLC macro p, basereg:=<ebx>
	push OFFS(p)
	add DWORD ptr [esp], basereg
endm

GetBase macro reg:=<ebx>
local l
	call l
	l:
	pop reg
	sub reg, OFFS(l)
endm

T macro t
local l, l1
	jmp l1
	l:
	db t, 0
	l1:
	exitm <l>
endm

RLCInvoke MACRO FunArgs:VARARG
	LOCAL txt, arg,curr,buseeax,lpquot,local_text
	txt TEXTEQU <>
	buseeax = 0
	;反转参数
	%FOR arg, <FunArgs>
	  txt CATSTR <arg>, <!,>, txt
	ENDM
	txt SUBSTR  txt, 1, @SizeStr( %txt ) - 1
	;压入所有参数
	:PushNext
		curr INSTR 1,txt,<!,>
		IF curr NE 0
			lpquot SUBSTR txt,1,1
			arg  SUBSTR txt,1,curr-1
			txt  SUBSTR txt,curr+1,@SizeStr(% txt)-curr
			IF @SizeStr(% txt) GE 1
				curr INSTR 1,arg,<!addr>
				IF curr NE 0
					arg SUBSTR arg,6,@SizeStr(% arg)-5
					buseeax=1
					lea eax,arg								;使用了eax,做一个标记,如果在这之后直接使用push eax时,显示错误
					push eax
				ELSE
					ifidn lpquot,<!">
						push_offset_RLC T(arg)
					elseIF buseeax EQ 1
						ifidn arg,<!eax>
							.err <addr overwrite eax>	;显示错误在使用eax之前使用了addr,中止编译
						endif
						push arg
					else
						push arg
					ENDIF
				ENDIF
				goto PushNext
			ENDIF
		ENDIF
		IF buseeax EQ 1									;如果已经修改了eax,检查函数调用是否使用了eax
			ifidn txt,<!eax>
				.err <addr overwrite Function [eax]>	;显示错误在使用eax之前使用了addr,中止编译
			endif
		ENDIF
		txt CATSTR <p>, txt
		call DWORD ptr RLC(txt)
ENDM

GetGameAddr macro _addr, reg:=<eax>, basereg:=<ebx>
	mov reg, RLC(hGameDll, basereg)
	add reg, (_addr - GameOriginalBase)
endm

GameCall macro _addr, reg:=<eax>, basereg:=<ebx>
	GetGameAddr _addr, reg, basereg
	call reg
endm
	
	;PLoadString equ 6F4C5130h							; Private, fastcall, stringid -> char *
	PSaveString equ 6F3BB560h							; Private, fastcall, char * -> stringid
	PAddNative equ 6F455C20h							; Private, fastcall, funcaddr, funcname, funcsig
	PSIdToPointer equ 6F45A150h						; Private, thiscall, jassenv, stringid -> ptr to a struct
	PGetCurrentJassEnv equ 6F44BDF0h					; Private, fastcall, id = 1 => main jass, id = 2 => ai jass (guessed)
	;RunJassNative_HookPoint equ 6F45DCC2h			; Inside of func RunJassNative. overwritten instruction: add esp, 0ch; call DWORD ptr [esp-8]
	
	PInitNatives equ 6F3D4B60h							; Private, used for hooking
	
	;constant native GetLocalPlayer      takes nothing returns player
	JNGetLocalPlayer equ 6F3BC6A0h
	
	;native DisplayTimedTextToPlayer     takes player toPlayer, real x, real y, real duration, string message returns nothing
	JNDisplayTimedTextToPlayer equ 6F3CC4F0h 
	
	;native PingMinimapEx takes real x, real y, real duration, integer red, integer green, integer blue, boolean extraEffects returns nothing
	JNPingMinimapEx equ 6F3B91A0h
	
	;constant native GetUnitX takes unit whichUnit returns real
	JNGetUnitX equ 6F3C6050h
	;constant native GetUnitY takes unit whichUnit returns real
	JNGetUnitY equ 6F3C6090h
	
	;native SetUnitX takes unit whichUnit, real newX returns nothing
	JNSetUnitX equ 6F3C64B0h
	
	;constant native IsUnitType takes unit whichUnit, unittype whichUnitType returns boolean
	JNIsUnitType equ 6F3C89D0h
	
	;constant native IsUnitIllusion takes unit whichUnit returns boolean
	JNIsUnitIllusion equ 6F3C8690h
	
	;constant native IsUnitVisible takes unit whichUnit, player whichPlayer returns boolean
	JNIsUnitVisible equ 6F3C8630h
	
	;constant native GetOwningPlayer takes unit whichUnit returns player
	JNGetOwningPlayer equ 6F3C8CD0h
	
	;native GetPlayerColor takes player whichPlayer returns playercolor
	JNGetPlayerColor equ 6F3C1D80h
	
	;constant native GetUnitState takes unit whichUnit, unitstate whichUnitState returns real
	JNGetUnitState equ 6F3C5F40h
	
	;native CreateUnit takes player id, integer unitid, real x, real y, real face returns unit
	JNCreateUnit equ 6F3C5D70h
	
	;native CreateItem takes integer itemid, real x, real y returns item
	JNCreateItem equ 6F3BC4E0h
	
	;native SetUnitVertexColor takes unit whichUnit, integer red, integer green, integer blue, integer alpha returns nothing
	JNSetUnitVertexColor equ 6F3C6E80h
	
	;native GetUnitAbilityLevel takes unit whichUnit, integer abilcode returns integer
	JNGetUnitAbilityLevel equ 6F3C7DD0h
	
	;native IsUnitAlly takes unit whichUnit, player whichPlayer returns boolean
	JNIsUnitAlly equ 6F3C85B0h
	
	;native GetUnitTypeId takes unit whichUnit returns integer
	JNGetUnitTypeId equ 6F3C6450h
	
.code
START:
jmp codestart

align 4

hGameDll dd 0

hTimer dd 0

datastart:
dwStatus dd 0
dwMyHero dd 0

dwPingHeroTick dd 0

dwHeroIds dd 20 dup(?)

;dwLastJassEnv dd 0
dataend:

dwColors dd 0FFFF0202h ; red
			dd 0FF0041FFh ; blue
			dd 0FF1BE5B8h ; cyan
			dd 0FF530080h ; purple
			dd 0FFFFFC00h ; yellow
			dd 0FFFE890Dh ; orange
			dd 0FF1FBF00h ; green
			dd 0FFE45AAFh ; pink
			dd 0FF949596h ; light gray
			dd 0FF7DBEF1h ; light blue
			dd 0FF0F6145h ; aqua
			dd 0FF4D2903h ; brown

hookcode db 68h ; PUSH imm32
hookaddr dd 0
db 0c3h ; RET

DllFunc macro fn
	local l, t
	l CATSTR <p>, <fn>
	t CATSTR <">, <fn>, <">
	l db t, 0
endm

dllKernel32 db "kernel32.dll", 0
DllFunc CloseHandle
DllFunc GetModuleHandleA
DllFunc GetProcAddress
DllFunc GetThreadContext
DllFunc GetThreadSelectorEntry
DllFunc LoadLibraryA
DllFunc MultiByteToWideChar
DllFunc OpenThread
DllFunc ResumeThread
DllFunc RtlZeroMemory
DllFunc RtlMoveMemory
DllFunc SetThreadContext
DllFunc Sleep
DllFunc SuspendThread
DllFunc WideCharToMultiByte
DllFunc ExitThread
DllFunc VirtualProtect
dd 0

dllUser32 db "user32.dll", 0
DllFunc wsprintfA
DllFunc FindWindowA
DllFunc GetWindowThreadProcessId
DllFunc KillTimer
DllFunc SetTimer
dd 0

codestart:

FirstRun proc pMyGetProcAddress:DWORD
LOCAL stContext:CONTEXT
LOCAL stLdt:LDT_ENTRY
LOCAL hKernel32:DWORD
	
	GetBase
	
	mov eax, pMyGetProcAddress ; find HMODULE of kernel32.dll
	and eax, not (0FFFh)
	.while WORD ptr [eax] != 'ZM'
		sub eax, 1000h
	.endw
	mov ecx, eax
	mov hKernel32, eax
	
	lea eax, RLC(T("LoadLibraryA"))
	push eax
	push ecx
	call DWORD ptr pMyGetProcAddress
	
	mov esi, eax
	mov edi, pMyGetProcAddress
	
	lea eax, RLC(dllKernel32)
	call resolve_imports
	
	lea eax, RLC(dllUser32)
	call resolve_imports
	
	RLCInvoke LoadLibrary, "Game.dll"
	
	mov RLC(hGameDll), eax
	
	.while 1
		RLCInvoke FindWindow, "Warcraft III", NULL
		.break .if eax
		RLCInvoke Sleep, 500
	.endw
	push 0
	RLCInvoke GetWindowThreadProcessId, eax, esp
	pop edx
	mov esi, eax
	
	RLCInvoke GetModuleHandle, "ntdll.dll"
	RLCInvoke GetProcAddress, eax, "RtlAdjustPrivilege"
	push 0 ; old enable stor
	push esp ; ptr old enable
	push 0 ; current thread ?
	push 1 ; enable ?
	push 14h ; 14h = SE_DEBUG_PRIVILEGE
	call eax
	pop eax
	
	RLCInvoke OpenThread, THREAD_ALL_ACCESS, FALSE, esi
	mov esi, eax
	
	RLCInvoke SuspendThread, esi
	
	mov edi, hKernel32
	mov eax, (IMAGE_DOS_HEADER ptr [edi]).e_lfanew
	add edi, eax
	
	mov eax, (IMAGE_NT_HEADERS32 ptr [edi]).OptionalHeader.SizeOfImage
	push 0
	RLCInvoke VirtualProtect, hKernel32, eax, PAGE_EXECUTE_READWRITE, esp
	pop eax
	
	push edi
	
	xor eax, eax
	mov ax, (IMAGE_NT_HEADERS32 ptr [edi]).FileHeader.SizeOfOptionalHeader
	lea edi, [edi+eax+(sizeof(DWORD)+sizeof(IMAGE_FILE_HEADER))]
	
	mov edi, (IMAGE_SECTION_HEADER ptr [edi+sizeof(IMAGE_SECTION_HEADER)]).VirtualAddress ; Start of 2nd section (RVA)
	add edi, hKernel32
	
	sub edi, 40h
	
	lea eax, RLC(BreakpointHandler)
	lea edx, RLC(hookaddr)
	mov DWORD ptr [edx], eax
	dec edx
	
	RLCInvoke RtlMoveMemory, edi, edx, 6
	
	pop edx ; pair with 'push edi' above
	
	mov eax, (IMAGE_NT_HEADERS32 ptr [edx]).OptionalHeader.DataDirectory[SIZEOF(IMAGE_DATA_DIRECTORY)*IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG].VirtualAddress
	.if eax
		add eax, hKernel32
		.if DWORD ptr [eax] == 48h ; dwSize
			mov eax, DWORD ptr [eax+40h] ; SafeSEH Table ptr, VA
			;sub eax, (IMAGE_NT_HEADERS32 ptr [edx]).OptionalHeader.ImageBase
			;add eax, hKernel32
			mov ecx, edi
			sub ecx, hKernel32
			mov [eax+4], ecx ; The first one won't work
		.endif
	.endif
	
	push edi
	lea edi, stContext
	RLCInvoke RtlZeroMemory, edi, sizeof stContext
	
	mov stContext.ContextFlags, CONTEXT_DEBUG_REGISTERS OR CONTEXT_FULL
	RLCInvoke GetThreadContext, esi, edi
	pop edi
	
	mov edx, stContext.regFs
	RLCInvoke GetThreadSelectorEntry, esi, edx, addr stLdt
	mov ah, stLdt.HighWord1.Bytes.BaseHi
	mov al, stLdt.HighWord1.Bytes.BaseMid
	shl eax, 16
	mov ax, stLdt.BaseLow
	
	.while DWORD ptr [eax] != -1
		mov eax, [eax]
	.endw
	
	mov DWORD ptr [eax+4], edi ; handler, replaces the system default
	
	GetGameAddr PInitNatives
	mov stContext.iDr0, eax
	GetGameAddr JNCreateUnit
	mov stContext.iDr1, eax
	
	mov stContext.iDr7,0101b ; DR0 DR1 valid, global, execute, 1 byte
	
	mov stContext.ContextFlags, CONTEXT_DEBUG_REGISTERS
	RLCInvoke SetThreadContext, esi, addr stContext
	
	RLCInvoke ResumeThread, esi
	RLCInvoke CloseHandle, esi
	
	mov DWORD ptr RLC(dwStatus), 0
	
	;RLCInvoke AllocConsole
	RLCInvoke ExitThread, 0
	
	ret
	
FirstRun endp

resolve_imports:
	push esi ; LoadLibrary
	push edi ; GetProcAddress
	mov esi, eax
	push esi
	call DWORD ptr [esp+8h] ; LoadLibrary
	mov edi, eax
	
	call next_str
	.while DWORD ptr [esi]
		push esi
		push edi
		call DWORD ptr [esp+8h] ; GetProcAddress
		mov DWORD ptr [esi], eax
		call next_str
	.endw
	pop edi
	pop esi
	ret
	
next_str:
	.while BYTE ptr [esi]
		inc esi
	.endw
	inc esi
	ret

MainProc proc uses ebx u1:DWORD, u2:DWORD, idEvent:DWORD, u4:DWORD
	
	GetBase
	
	mov ecx, 1
	GameCall PGetCurrentJassEnv
;	.if eax != DWORD ptr RLC(dwLastJassEnv)
;		RLCInvoke KillTimer, 0, RLC(hTimer)
;		mov DWORD ptr RLC(hTimer), 0
;		mov DWORD ptr RLC(dwStatus), 0
;		ret
;	.endif
	.if !eax
		ret
	.endif
	call PingHeros
	call AxeCullingBladePrompt
	ret
MainProc endp

CP_UTF8 equ 65001
DisplayText proc pString:DWORD, dwDuration:DWORD
LOCAL unicode [400h]:BYTE
LOCAL utf8 [400h]:BYTE
LOCAL junk:DWORD
	
	pushad
	
	GetBase
	
	RLCInvoke MultiByteToWideChar,CP_ACP,NULL,pString,-1,addr unicode,400h
	RLCInvoke WideCharToMultiByte,CP_UTF8,NULL,addr unicode, -1, addr utf8, 400h, NULL, NULL
	
	lea ecx, utf8
	GameCall PSaveString
	
	push eax ; string id -> SIdToPointer
	mov ecx, 1
	GameCall PGetCurrentJassEnv
	mov ecx, eax ; jassenv -> SIdToPointer
	GameCall PSIdToPointer
	
	push eax ; message -> DisplayTimedTextToPlayer
	
	fild dwDuration
	fstp dwDuration
	
	lea eax, dwDuration
	push eax ; duration-> DisplayTimedTextToPlayer
	
	xor eax, eax
	lea ecx, junk
	mov [ecx], eax
	push ecx ; y -> DisplayTimedTextToPlayer
	push ecx ; x -> DisplayTimedTextToPlayer
	
	GameCall JNGetLocalPlayer
	push eax ; player -> DisplayTimedTextToPlayer
	GameCall JNDisplayTimedTextToPlayer
	add esp, 20
	popad
	ret
	
	;native DisplayTimedTextToPlayer takes player toPlayer, real x, real y, real duration, string message returns nothing
	
DisplayText endp

;native SetUnitX takes unit whichUnit, real newX returns nothing
JNSetUnitXHook proc whichUnit:DWORD, pnewX:DWORD
	pushad
	GetBase
	
	push 0 ; type = hero
	push whichUnit
	GameCall JNIsUnitType
	mov esi, eax
	GameCall JNIsUnitIllusion
	not eax
	and esi, eax
	add esp, 8
	mov edi, whichUnit
	.if esi
		lea esi, RLC(dwHeroIds)
		.while 1
			lodsd
			.break .if !eax
			
			.if eax == edi
				jmp _end
			.endif
			
			push eax
			GameCall JNGetOwningPlayer
			push eax
			GameCall JNGetLocalPlayer
			pop edx
			sub edx, eax
			pop eax
			.if !edx
				mov RLC(dwMyHero), eax
			.endif
		.endw
		mov eax, edi
		lea edi, [esi-4]
		stosd
	.endif
	
_end:
	popad
	leave
	GetBase eax
	GetGameAddr JNSetUnitX, eax, eax
	jmp eax
JNSetUnitXHook endp

;native CreateItem takes integer itemid, real x, real y returns item
JNCreateItemHook proc itemid:DWORD, x:DWORD, y:DWORD
LOCAL buf[400h]:BYTE
	
	pushad
	GetBase
	mov eax, itemid
	
	.if eax == 'I00K'
		lea edx, RLC(T("|c000042ff双倍伤害|r"))
		mov esi, 0000042ffh
		jmp powerup
	.elseif eax == 'I006'
		lea edx, RLC(T("|c00ff0303极速|r"))
		mov esi, 000ff0303h
		jmp powerup
	.elseif eax == 'I007'
		lea edx, RLC(T("|c00fffc01幻象|r"))
		mov esi, 000fffc01h
		jmp powerup
	.elseif eax == 'I008'
		lea edx, RLC(T("|cff00ff00回复|r"))
		mov esi, 0ff00ff00h
		jmp powerup
	.elseif eax == 'I00J'
		lea edx, RLC(T("|cff99ccff隐形|r"))
		mov esi, 0ff99ccffh
		jmp powerup
	.endif
	
jmp _end
powerup:
	mov eax, y
	mov eax, [eax]
	push eax
	fld DWORD ptr [esp]
	fistp DWORD ptr [esp]
	pop eax
	.if eax == -2832
		lea ecx, RLC(T("下路"))
	.elseif eax == 1648
		lea ecx, RLC(T("上路"))
	.else
		jmp _end
	.endif
	
	lea eax, RLC(T("神符 %s 在 |cfffffc00%s|r 刷新了！"))
	RLCInvoke wsprintf, addr buf, eax, edx, ecx
	add esp, 16
	invoke DisplayText, addr buf, 10
	mov eax, x
	mov ecx, [eax]
	mov eax, y
	mov edx, [eax]
	invoke PingMiniMapEx, ecx, edx, 41800000h, esi, 1 ; 10.0
	
	jmp _end

_end:
	popad
	leave
	GetBase eax
	GetGameAddr JNCreateItem, eax, eax
	jmp eax
JNCreateItemHook endp

;native CreateUnit takes player id, integer unitid, real x, real y, real face returns unit
JNCreateUnitHook proc playerid:DWORD, unitid:DWORD, x:DWORD, y:DWORD
LOCAL buf[400h]:BYTE
	pushad
	GetBase
	.if !(DWORD ptr RLC(dwStatus))
		mov DWORD ptr RLC(dwStatus), 1
		lea eax, RLC(T("欢迎使用Proton制作的DotA“辅助”工具！"))
		invoke DisplayText, eax, 10
	;.endif
	
	;.if !(DWORD ptr RLC(hTimer))
		; well, the game started...
		;lea eax, RLC(MainProc)
		;RLCInvoke SetTimer, 0, 0, 1000, eax
		;mov RLC(hTimer), eax
		
		;mov ecx, 1
		;GameCall PGetCurrentJassEnv
		;mov DWORD ptr RLC(dwLastJassEnv), eax
		call AddNativeHooks
	.endif
	mov eax, unitid
		
	.if eax == 'n00L'
		lea eax, RLC(T("肉山大魔王又复活啦！！！"))
		invoke DisplayText, eax, 10
		jmp _end
	.endif
	
_end:
	popad
	leave
	GetBase eax
	push ecx
	push esi
	GetGameAddr 6F3B3430h, eax, eax
	call eax
	GetBase eax
	GetGameAddr JNCreateUnit+07h, eax, eax
	jmp eax
JNCreateUnitHook endp

PingMiniMapEx proc uses ebx x:DWORD, y:DWORD, duration:DWORD, color:DWORD, extraEffects:DWORD
		;native PingMinimapEx takes real x, real y, real duration, integer red, integer green, integer blue, boolean extraEffects returns nothing
		push extraEffects
		mov edx, color
		mov eax, edx
		and eax, 0ffh
		push eax ; blue
		mov eax, edx
		shr eax, 8
		and eax, 0ffh
		push eax ; green
		mov eax, edx
		shr eax, 16
		and eax, 0ffh
		push eax ; red
		lea eax, duration
		push eax
		lea eax, y
		push eax
		lea eax, x
		push eax
		GetBase
		GameCall JNPingMinimapEx
		add esp, 28
		ret
PingMiniMapEx endp

PingHeros proc
	pushad
	;GetBase
	
	inc DWORD ptr RLC(dwPingHeroTick)
	.if DWORD ptr RLC(dwPingHeroTick) == 3
		xor eax, eax
		mov RLC(dwPingHeroTick), eax
		jmp go
	.endif
	popad
	ret
	go:
	lea esi, RLC(dwHeroIds)
	.while 1
		mov edi, [esi]
		.break .if !edi
		
		GameCall JNGetLocalPlayer
		push eax
		push DWORD ptr [esi]
		GameCall JNIsUnitVisible
		not eax
		add esp, 8
		mov edi, eax
		push 0 ; life
		push DWORD ptr [esi]
		GameCall JNGetUnitState
		add esp, 8
		push eax
		fld DWORD ptr [esp]
		pop eax
		ftst
		fstsw ax
		sahf
		setg al
		movzx eax, al
		fstp st
		
		and edi, eax ; !IsUnitVisible and GetUnitState(life) > 0
		.if edi
			push DWORD ptr [esi]
			GameCall JNGetOwningPlayer
			pop edx
			push eax
			GameCall JNGetPlayerColor
			pop edx
			
			mov eax, DWORD ptr RLC(dwColors)[4*eax]
			
			push 0 ; extraEffects
			push eax ; color
			push 3F000000h ; duration, float 0.5
			
			push DWORD ptr [esi] ; unit id
			GameCall JNGetUnitY
			mov edi, eax
			GameCall JNGetUnitX
			mov edx, eax
			pop eax
			push edi ; y
			push edx ; x
			
			call PingMiniMapEx
		.endif
		add esi, 4
	.endw
	popad
	ret
PingHeros endp

AxeCullingBladePrompt proc
LOCAL threshold:DWORD
	pushad
	mov eax, RLC(dwMyHero)
	.if !eax
		popad
		ret
	.endif
	
	push eax
	GameCall JNGetUnitTypeId
	pop edx
	.if eax != 'Opgh'
		popad
		ret
	.endif
	
	xor edi, edi
	push 'A0E2'
	push DWORD ptr RLC(dwMyHero)
	GameCall JNGetUnitAbilityLevel
	add edi, eax
	mov DWORD ptr [esp+4], 'A1MR'
	GameCall JNGetUnitAbilityLevel
	add edi, eax
	add esp, 8
	
	lea eax, RLC(_thresholds)
	mov eax, DWORD ptr [eax+4*edi]
	
	mov threshold, eax
	
	lea esi, RLC(dwHeroIds)
	.while 1
		mov edi, [esi]
		.break .if !edi
		GameCall JNGetLocalPlayer
		push eax
		push edi
		GameCall JNIsUnitAlly
		add esp, 8
		.if eax
			add esi, 4
			.continue
		.endif
		push 0
		push DWORD ptr [esi]
		GameCall JNGetUnitState
		add esp, 8
		push eax
		fld DWORD ptr [esp]
		fistp DWORD ptr [esp]
		pop eax
		
		.if eax < threshold
			push 255 ; alpha
			push 0 ; blue
			push 0 ; green
			push 255 ; red
			push DWORD ptr [esi] ; whichUnit
			GameCall JNSetUnitVertexColor
			add esp, 20
		.else
			push 255 ; alpha
			push 255 ; blue
			push 255 ; green
			push 255 ; red
			push DWORD ptr [esi] ; whichUnit
			GameCall JNSetUnitVertexColor
			add esp, 20
		.endif
		
		add esi, 4
	.endw
	
	popad
	ret
_thresholds:
dd 0, 300, 450, 625
AxeCullingBladePrompt endp

PInitNativesHook proc
	pushad
	GetBase
	lea eax, RLC(datastart)
	RLCInvoke RtlZeroMemory, eax, offset dataend - offset datastart
;	.if DWORD ptr RLC(hTimer)
;		RLCInvoke KillTimer, 0, RLC(hTimer)
;		mov DWORD ptr RLC(dwStatus), 0
;		mov DWORD ptr RLC(hTimer), 0
;	.endif
	.if !(DWORD ptr RLC(hTimer))
		lea eax, RLC(MainProc)
		RLCInvoke SetTimer, 0, 0, 200, eax
		mov RLC(hTimer), eax
	.endif
	; popad ; thank god, this func has no parameters, and has no return value
	
	push_offset_RLC @F
	GameCall 6F454710h ; hook overwritten code
	GetGameAddr 6F95D93Ch
	push eax
	GetGameAddr PInitNatives+0Ah
	jmp eax
	
@@:
	;pushad
	;GetBase
	
	call AddNativeHooks
	
	popad
	ret
PInitNativesHook endp

AddNativeHooks proc
	push_offset_RLC T("(Hunit;R)V")
	lea edx, RLC(T("SetUnitX"))
	lea ecx, RLC(JNSetUnitXHook)
	GameCall PAddNative
	
	push_offset_RLC T("(IRR)Hitem;")
	lea edx, RLC(T("CreateItem"))
	lea ecx, RLC(JNCreateItemHook)
	GameCall PAddNative
	ret
AddNativeHooks endp

BreakpointHandler proc uses esi ebx pExceptionRecord:DWORD, pFrame:DWORD, pContext:DWORD, pDispatcherContext:DWORD
	
	GetBase
	
	mov esi, pExceptionRecord
	mov eax, (EXCEPTION_RECORD ptr [esi]).ExceptionCode
	.if eax != EXCEPTION_SINGLE_STEP
		mov eax, ExceptionContinueSearch
		ret
	.endif
	mov eax, (EXCEPTION_RECORD ptr [esi]).ExceptionAddress
	sub eax, RLC(hGameDll)
	add eax, GameOriginalBase
	
	mov edx, pContext
	.if eax == PInitNatives
		lea eax, RLC(PInitNativesHook)
		mov (CONTEXT ptr [edx]).regEip, eax
	.elseif eax == JNCreateUnit
		lea eax, RLC(JNCreateUnitHook)
		mov (CONTEXT ptr [edx]).regEip, eax
	.endif
	
	xor eax, eax
	ret
BreakpointHandler endp

align 16

db "****************"
db "*   Proton's   *"
db "* Dota Cheater *"
db "* Version: 1.1 *"
db "* Proj starts: *"
db "*  2011-4-29   *"
db "* Proj finish: *"
db "*              *"
db "*Thx for using!*"
db "****************"

END START