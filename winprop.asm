;-------------------------------------------------------------------------------
;
;  WinRoll 2.0 - WinRoll easily manages multiple open windows.
;  Copyright (C) 2003-2004 Wil Palma <wilpalma@hotmail.com>
;
;  This software is provided 'as-is', without any express or implied
;  warranty.  In no event will the authors be held liable for any damages
;  arising from the use of this software.
;
;  Permission is granted to anyone to use this software for any purpose,
;  including commercial applications, and to alter it and redistribute it
;  freely, subject to the following restrictions:
;
;  1. The origin of this software must not be misrepresented; you must not
;     claim that you wrote the original software. If you use this software
;     in a product, an acknowledgment in the product documentation would be
;     appreciated but is not required.
;  2. Altered source versions must be plainly marked as such, and must not be
;     misrepresented as being the original software.
;  3. This notice may not be removed or altered from any source distribution.
;
;-------------------------------------------------------------------------------

.386
.model flat, stdcall
option casemap: none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc

;include \masm32\include\masm32.inc
;include \masm32\include\debug.inc
;includelib \masm32\lib\masm32.lib
;includelib \masm32\lib\debug.lib
;DBGWIN_DEBUG_ON = 1 ; include debug info into the program
;DBGWIN_EXT_INFO = 0 ; include extra debug info into the program

FindWinNode     proto :DWORD
GetWinHeight    proto :DWORD
GetWinProc      proto :DWORD
GetWinAlpha     proto :DWORD
GetWinTray      proto :DWORD
SetWinHeight    proto :DWORD, :DWORD
SetWinProc      proto :DWORD, :DWORD
SetWinAlpha     proto :DWORD, :DWORD
SetWinTray      proto :DWORD, :DWORD
RemoveWinHeight proto :DWORD
RemoveWinProc   proto :DWORD
RemoveWinAlpha  proto :DWORD
RemoveWinTray   proto :DWORD

.const
szWinHeight     db "wrWinHeight",0
szMsgProc       db "wrMsgProc",0
szWinAlpha      db "wrWinAlpha",0
szWinTray       db "wrWinTray",0

WR_LISTSIZE     equ 8
WR_LISTNODE     STRUC
  hWnd     DWORD ?
  Height   DWORD ?
WR_LISTNODE     ENDS

.data
WR_NodeList     WR_LISTNODE WR_LISTSIZE dup (<0>)

.code

;-------------------------------------------------------------------------------

FindWinNode proc uses ebx hWnd:DWORD
    ; window not found, return zero
    xor eax, eax
    mov ebx, offset WR_NodeList
    mov ecx, WR_LISTSIZE
    .while ecx > 0
        mov edx, (WR_LISTNODE PTR [ebx]).hWnd
        .if edx == hWnd
            ; window found, return pointer
            mov eax, ebx
            .break
        .endif
        add ebx, sizeof WR_LISTNODE
        sub ecx, 1
    .endw
    ; return node pointer or zero
    ret
FindWinNode endp

;-------------------------------------------------------------------------------

GetWinHeight proc hWnd:DWORD
    ; attempt to get a window property
    invoke GetProp, hWnd, addr szWinHeight
    .if eax == 0
        ; else find an existing window node
        invoke FindWinNode, hWnd
        ; if a window node is found get property
        .if eax != 0
            mov edx, eax
            mov eax, (WR_LISTNODE PTR [edx]).Height
        .endif
    .endif
    ; return height or zero
    ret
GetWinHeight endp

;-------------------------------------------------------------------------------

GetWinProc proc hWnd:DWORD
    ; attempt to get a window property
    invoke GetProp, hWnd, addr szMsgProc
    ; return msg proc or zero
    ret
GetWinProc endp

;-------------------------------------------------------------------------------

GetWinAlpha proc hWnd:DWORD
    ; attempt to get a window property
    invoke GetProp, hWnd, addr szWinAlpha
    ; return alpha or zero
    ret
GetWinAlpha endp

;-------------------------------------------------------------------------------

GetWinTray proc hWnd:DWORD
    ; attempt to get a window property
    invoke GetProp, hWnd, addr szWinTray
    ; return tray flag or zero
    ret
GetWinTray endp

;-------------------------------------------------------------------------------

SetWinHeight proc hWnd:DWORD, dwHeight:DWORD
    ; attempt to save to a window property
    invoke SetProp, hWnd, addr szWinHeight, dwHeight
    .if eax == 0
        ; else find an existing window node
        invoke FindWinNode, hWnd
        .if eax == 0
            ; else find an empty window node
            invoke FindWinNode, 0
        .endif
        ; if a window node is found store property
        .if eax != 0
            mov edx, eax
            mov eax, hWnd
            mov (WR_LISTNODE PTR [edx]).hWnd, eax
            mov eax, dwHeight
            mov (WR_LISTNODE PTR [edx]).Height, eax
        .endif
    .endif
    ; return non zero value if height is set
    ret
SetWinHeight endp

;-------------------------------------------------------------------------------

SetWinProc proc hWnd:DWORD, lpMsgProc:DWORD
    ; attempt to save to a window property
    invoke SetProp, hWnd, addr szMsgProc, lpMsgProc
    ; return non zero value if msg proc is set
    ret
SetWinProc endp

;-------------------------------------------------------------------------------

SetWinAlpha proc hWnd:DWORD, dwAlpha:DWORD
    ; attempt to save to a window property
    invoke SetProp, hWnd, addr szWinAlpha, dwAlpha
    ; return non zero value if alpha is set
    ret
SetWinAlpha endp

;-------------------------------------------------------------------------------

SetWinTray proc hWnd:DWORD, dwTray:DWORD
    ; attempt to save to a window property
    invoke SetProp, hWnd, addr szWinTray, dwTray
    ; return non zero value if tray flag is set
    ret
SetWinTray endp

;-------------------------------------------------------------------------------

RemoveWinHeight proc hWnd:DWORD
    ; attempt to remove a window property
    invoke RemoveProp, hWnd, addr szWinHeight
    .if eax == 0
        ; else find an existing window node
        invoke FindWinNode, hWnd
        ; if a window node is found remove property
        .if eax != 0
            mov edx, eax
            mov (WR_LISTNODE PTR [edx]).hWnd, 0
            mov eax, (WR_LISTNODE PTR [edx]).Height
            mov (WR_LISTNODE PTR [edx]).Height, 0
        .endif
    .endif
    ; return height or zero
    ret
RemoveWinHeight endp

;-------------------------------------------------------------------------------

RemoveWinProc proc hWnd:DWORD
    ; attempt to remove a window property
    invoke RemoveProp, hWnd, addr szMsgProc
    ; return msg proc or zero
    ret
RemoveWinProc endp

;-------------------------------------------------------------------------------

RemoveWinAlpha proc hWnd:DWORD
    ; attempt to remove a window property
    invoke RemoveProp, hWnd, addr szWinAlpha
    ; return alpha or zero
    ret
RemoveWinAlpha endp

;-------------------------------------------------------------------------------

RemoveWinTray proc hWnd:DWORD
    ; attempt to remove a window property
    invoke RemoveProp, hWnd, addr szWinTray
    ; return tray flag or zero
    ret
RemoveWinTray endp

;-------------------------------------------------------------------------------

end
