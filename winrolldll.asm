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

include winroll.inc
include winprop.inc

includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

;include \masm32\include\masm32.inc
;include \masm32\include\debug.inc
;includelib \masm32\lib\masm32.lib
;includelib \masm32\lib\debug.lib
;DBGWIN_DEBUG_ON = 1 ; include debug info into the program
;DBGWIN_EXT_INFO = 0 ; include extra debug info into the program

NotifyParent macro dwMessage
    ; save return code
    push eax
    ; send message
    mov hCopyData.dwData, dwMessage
    mov hCopyData.cbData, 0
    mov hCopyData.lpData, 0
    invoke SendMessage, hWndParent, WM_COPYDATA, hWnd, addr hCopyData
    ; restore return code
    pop eax
endm

NotifyParent2 macro dwMessage, dwCode
    ; send message
    mov dwBuffer, dwCode
    mov hCopyData.dwData, dwMessage
    mov hCopyData.cbData, 4
    mov hCopyData.lpData, offset dwBuffer
    invoke SendMessage, hWndParent, WM_COPYDATA, hWnd, addr hCopyData
endm

WR_Start          proto
WR_Stop           proto
WR_RollupAll      proto
WR_UnrollAll      proto
WR_InvertRollAll  proto
WR_ToTrayAll      proto
WR_FromTrayAll    proto
WR_ToAlphaAll     proto
WR_FromAlphaAll   proto
WR_InvertAlphaAll proto
WR_SetConfig      proto :DWORD
WR_Rollup         proto :DWORD
WR_Unroll         proto :DWORD
WR_InvertRoll     proto :DWORD
WR_ToBack         proto :DWORD
WR_OnTop          proto :DWORD
WR_ToTray         proto :DWORD
WR_FromTray       proto :DWORD
WR_ToAlpha        proto :DWORD
WR_FromAlpha      proto :DWORD
WR_InvertAlpha    proto :DWORD
Subclass          proto :DWORD
UnSubclass        proto :DWORD
IsWinValid        proto :DWORD
GetWinRect        proto :DWORD, :DWORD
MouseProc         proto :DWORD, :DWORD, :DWORD
GetMsgProc        proto :DWORD, :DWORD, :DWORD
MsgProc           proto :DWORD, :DWORD, :DWORD, :DWORD

.const
KEY_DOWN          equ 80000000h
szUser32          db  "user32.dll",0
szSetWinLA        db  "SetLayeredWindowAttributes",0

WS_EX_LAYERED     equ 00080000h
LWA_COLORKEY      equ 00000001h
LWA_ALPHA         equ 00000002h

.data
hModule           dd 0
hWndParent        dd 0
hMouseHook        dd 0
hGetMsgHook       dd 0
hUser32           dd 0
WM_WINROLL        dd 0
RollCount         dd 0
TrayCount         dd 0
AlphaCount        dd 0
lpSetWinLA        dd 0
dwOptions         dd CFG_TRANSPARENCY
osVersion         OSVERSIONINFO <0>

.data?
hPrevProc         dd ?
hCopyData         COPYDATASTRUCT <?>
dwBuffer          dd ?

.code

;-------------------------------------------------------------------------------

DllEntry proc hInst:HINSTANCE, reason:DWORD, unused:DWORD

    .if reason == DLL_PROCESS_ATTACH

        ; disable threads to optimise code size
        invoke DisableThreadLibraryCalls, hInst

        ; first load, initialise
        .if hModule == 0
            mov eax, hInst
            mov hModule, eax
            invoke RegisterWindowMessage, addr szAppTitle
            mov WM_WINROLL, eax
            mov osVersion.dwOSVersionInfoSize, sizeof OSVERSIONINFO
            invoke GetVersionEx, addr osVersion
            .if osVersion.dwMajorVersion >= 5
                ; statically linking to SetLayeredWindowAttributes
                ; makes this dll not load under Win9x, so
                ; dynamically load it on Win2k or above
                invoke GetModuleHandle, addr szUser32
                invoke GetProcAddress, eax, addr szSetWinLA
                mov lpSetWinLA, eax
            .endif
        .endif
    .endif

    ; return true to continue load/unload
    mov eax, TRUE
    ret
DllEntry Endp

;-------------------------------------------------------------------------------

WR_Start proc
    .if hMouseHook == 0 && hGetMsgHook == 0

        ; install hooks
        invoke SetWindowsHookEx, WH_MOUSE, addr MouseProc, hModule, NULL
        mov hMouseHook, eax
        invoke SetWindowsHookEx, WH_GETMESSAGE, addr GetMsgProc, hModule, NULL
        mov hGetMsgHook, eax

        .if hWndParent == 0
            invoke FindWindow, addr szAppClass, addr szAppTitle
            mov hWndParent, eax
        .endif

        ; return code
        mov eax, TRUE
    .else
        ; return code
        mov eax, FALSE
    .endif

    ret
WR_Start endp

;-------------------------------------------------------------------------------

WR_Stop proc
    .if hMouseHook != 0 && hGetMsgHook != 0

        push ebx

        ; restore translucent windows
        mov ebx, 5
        .while AlphaCount > 0
            invoke WR_FromAlphaAll
            invoke Sleep, 100
            sub ebx, 1
            .break .if (!ebx)
        .endw

        ; restore tray minimized windows
        mov ebx, 5
        .while TrayCount > 0
            invoke WR_FromTrayAll
            invoke Sleep, 100
            sub ebx, 1
            .break .if (!ebx)
        .endw

        ; unroll windows
        mov ebx, 5
        .while RollCount > 0
            invoke WR_UnrollAll
            invoke Sleep, 100
            sub ebx, 1
            .break .if (!ebx)
        .endw

        pop ebx

        ; uninstall hooks
        invoke UnhookWindowsHookEx, hMouseHook
        mov hMouseHook, 0
        invoke UnhookWindowsHookEx, hGetMsgHook
        mov hGetMsgHook, 0

        mov hWndParent, 0

        ; return code
        mov eax, TRUE
    .else
        ; return code
        mov eax, FALSE
    .endif

    ret
WR_Stop endp

;-------------------------------------------------------------------------------

WR_RollupAll proc
    invoke PostMessage, HWND_BROADCAST, WM_WINROLL, WM_WR_ROLLUP, 0
    ret
WR_RollupAll endp

;-------------------------------------------------------------------------------

WR_UnrollAll proc
    invoke PostMessage, HWND_BROADCAST, WM_WINROLL, WM_WR_UNROLL, 0
    ret
WR_UnrollAll endp

;-------------------------------------------------------------------------------

WR_InvertRollAll proc
    invoke PostMessage, HWND_BROADCAST, WM_WINROLL, WM_WR_INVERTROLL, 0
    ret
WR_InvertRollAll endp

;-------------------------------------------------------------------------------

WR_ToTrayAll proc
    invoke PostMessage, HWND_BROADCAST, WM_WINROLL, WM_WR_TOTRAY, 0
    ret
WR_ToTrayAll endp

;-------------------------------------------------------------------------------

WR_FromTrayAll proc
    invoke PostMessage, HWND_BROADCAST, WM_WINROLL, WM_WR_FROMTRAY, 0
    ret
WR_FromTrayAll endp

;-------------------------------------------------------------------------------

WR_ToAlphaAll proc
    invoke PostMessage, HWND_BROADCAST, WM_WINROLL, WM_WR_TOALPHA, 0
    ret
WR_ToAlphaAll endp

;-------------------------------------------------------------------------------

WR_FromAlphaAll proc
    invoke PostMessage, HWND_BROADCAST, WM_WINROLL, WM_WR_FROMALPHA, 0
    ret
WR_FromAlphaAll endp

;-------------------------------------------------------------------------------

WR_InvertAlphaAll proc
    invoke PostMessage, HWND_BROADCAST, WM_WINROLL, WM_WR_INVERTALPHA, 0
    ret
WR_InvertAlphaAll endp

;-------------------------------------------------------------------------------

WR_SetConfig proc dwConfig:DWORD
    ; alpha range is 0-100(%), 100 is invisible
    ; convert to range of 0-255, 255 is opaque
    mov eax, dwConfig
    and eax, CFG_TRANSPARENCY
    mov ecx, 255
    mul cl
    mov ecx, 100
    div cl
    not al
    and eax, CFG_TRANSPARENCY
    ; save options
    mov ecx, eax
    mov eax, dwConfig
    and eax, not CFG_TRANSPARENCY
    or eax, ecx
    mov dwOptions, eax
    ret
WR_SetConfig endp

;-------------------------------------------------------------------------------

WR_Rollup proc hWnd:DWORD
    local rc:RECT
    local height:DWORD
    local wp:WINDOWPLACEMENT

    invoke IsWinValid, hWnd
    .if eax != 0
        ; get stored window height
        invoke GetWinHeight, hWnd
        .if eax == 0
            ; get system minimum height
            invoke GetSystemMetrics, SM_CYMIN
            mov height, eax

            invoke IsIconic, hWnd
            .if eax == 0
                ; get window dimensions
                invoke GetWinRect, hWnd, addr rc
                ; save window height
                invoke SetWinHeight, hWnd, eax
                .if eax != 0
                    invoke Subclass, hWnd
                    ; reduce height
                    invoke MoveWindow, hWnd, rc.left, rc.top, rc.right, height, TRUE
                    ; report to owner process
                    NotifyParent WM_WR_ROLLUP
                .endif
            .else
                ; get window dimensions
                mov wp.iLength, sizeof WINDOWPLACEMENT
                invoke GetWindowPlacement, hWnd, addr wp
                .if eax != 0
                    mov eax, wp.rcNormalPosition.bottom
                    sub eax, wp.rcNormalPosition.top
                    ; save window height
                    invoke SetWinHeight, hWnd, eax
                    .if eax != 0
                        invoke Subclass, hWnd
                        ; reduce height
                        mov eax, wp.rcNormalPosition.top
                        add eax, height
                        mov wp.rcNormalPosition.bottom, eax
                        invoke SetWindowPlacement, hWnd, addr wp
                        ; report to owner process
                        NotifyParent WM_WR_ROLLUP
                    .endif
                .endif
            .endif
        .endif
    .endif

    ret
WR_Rollup endp

;-------------------------------------------------------------------------------

WR_Unroll proc hWnd:DWORD
    local rc:RECT
    local height:DWORD
    local wp:WINDOWPLACEMENT

    ; get stored window height
    invoke GetWinHeight, hWnd
    .if eax != 0
        mov height, eax

        invoke IsIconic, hWnd
        .if eax == 0
            ; get window dimensions
            invoke GetWinRect, hWnd, addr rc
            ; delete saved window height
            invoke RemoveWinHeight, hWnd
            .if eax != 0
                invoke UnSubclass, hWnd
                invoke IsWindowVisible, hWnd
                ; restore height
                invoke MoveWindow, hWnd, rc.left, rc.top, rc.right, height, eax
                ; report to owner process
                NotifyParent WM_WR_UNROLL
            .endif
        .else
            ; get window dimensions
            mov wp.iLength, sizeof WINDOWPLACEMENT
            invoke GetWindowPlacement, hWnd, addr wp
            .if eax != 0
                ; delete saved window height
                invoke RemoveWinHeight, hWnd
                .if eax != 0
                    invoke UnSubclass, hWnd
                    invoke IsWindowVisible, hWnd
                    .if eax == 0
                        mov wp.showCmd, SW_HIDE
                    .endif
                    ; restore height
                    mov eax, wp.rcNormalPosition.top
                    add eax, height
                    mov wp.rcNormalPosition.bottom, eax
                    invoke SetWindowPlacement, hWnd, addr wp
                    ; report to owner process
                    NotifyParent WM_WR_UNROLL
                .endif
            .endif
        .endif
    .endif

    ret
WR_Unroll endp

;-------------------------------------------------------------------------------

WR_InvertRoll proc hWnd:DWORD

    invoke GetWinHeight, hWnd
    .if eax != 0
        invoke WR_Unroll, hWnd
    .else
        invoke WR_Rollup, hWnd
    .endif

    ret
WR_InvertRoll endp

;-------------------------------------------------------------------------------

WR_ToBack proc hWnd:DWORD

    invoke IsWinValid, hWnd
    .if eax != 0
        invoke SetWindowPos, hWnd, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE + SWP_NOSIZE
        ; report to owner process
        NotifyParent WM_WR_TOBACK
    .endif

    ret
WR_ToBack endp

;-------------------------------------------------------------------------------

WR_OnTop proc hWnd:DWORD

    invoke IsWinValid, hWnd
    .if eax != 0
        invoke GetWindowLong, hWnd, GWL_EXSTYLE
        .if eax & WS_EX_TOPMOST
            mov eax, HWND_NOTOPMOST
        .else
            mov eax, HWND_TOPMOST
        .endif
        invoke SetWindowPos, hWnd, eax, 0, 0, 0, 0, SWP_NOMOVE + SWP_NOSIZE
        ; report to owner process
        NotifyParent WM_WR_ONTOP
    .endif

    ret
WR_OnTop endp

;-------------------------------------------------------------------------------

WR_ToTray proc hWnd:DWORD

    invoke IsWinValid, hWnd
    .if eax != 0
        ; save tray flag
        invoke SetWinTray, hWnd, -1
        .if eax != 0
            ; report to owner process
            NotifyParent2 WM_WR_TOTRAY, 0
            invoke SetWinTray, hWnd, eax
            invoke ShowWindow, hWnd, SW_HIDE
            add TrayCount, 1
        .endif
    .endif

    ret
WR_ToTray endp

;-------------------------------------------------------------------------------

WR_FromTray proc hWnd:DWORD

    invoke GetWinTray, hWnd
    .if eax != 0
        ; delete saved tray flag
        invoke RemoveWinTray, hWnd
        .if eax != 0
            ; report to owner process
            NotifyParent2 WM_WR_FROMTRAY, eax
            invoke ShowWindow, hWnd, SW_SHOW
            sub TrayCount, 1
        .endif
    .endif

    ret
WR_FromTray endp

;-------------------------------------------------------------------------------

WR_ToAlpha proc hWnd:DWORD

    ; Win2K or above
    .if osVersion.dwMajorVersion >= 5
        invoke IsWinValid, hWnd
        .if eax != 0
            invoke GetWinAlpha, hWnd
            .if eax == 0
                invoke SetWinAlpha, hWnd, -1
                add AlphaCount, 1

                ; add window style
                invoke GetWindowLong, hWnd, GWL_EXSTYLE
                or eax, WS_EX_LAYERED
                invoke SetWindowLong, hWnd, GWL_EXSTYLE, eax

                mov eax, dwOptions
                and eax, CFG_TRANSPARENCY

                ; invoke SetLayeredWindowAttributes, hWnd, 0, eax, LWA_ALPHA
                push LWA_ALPHA
                push eax
                push 0
                push hWnd
                call lpSetWinLA

                ; re-paint the window
                invoke UpdateWindow, hWnd
                ; report to owner process
                NotifyParent WM_WR_TOALPHA
            .endif
        .endif
    .endif

    ret
WR_ToAlpha endp

;-------------------------------------------------------------------------------

WR_FromAlpha proc hWnd:DWORD

    ; Win2K or above
    .if osVersion.dwMajorVersion >= 5
        invoke GetWinAlpha, hWnd
        .if eax != 0
            invoke RemoveWinAlpha, hWnd
            sub AlphaCount, 1
            mov eax, 255

            ; invoke SetLayeredWindowAttributes, hWnd, 0, eax, LWA_ALPHA
            push LWA_ALPHA
            push eax
            push 0
            push hWnd
            call lpSetWinLA

            ; remove window style
            invoke GetWindowLong, hWnd, GWL_EXSTYLE
            xor eax, WS_EX_LAYERED
            invoke SetWindowLong, hWnd, GWL_EXSTYLE, eax

            ; re-paint the window
            invoke UpdateWindow, hWnd
            ; report to owner process
            NotifyParent WM_WR_FROMALPHA
        .endif
    .endif

    ret
WR_FromAlpha endp

;-------------------------------------------------------------------------------

WR_InvertAlpha proc hWnd:DWORD

    invoke GetWinAlpha, hWnd
    .if eax != 0
        invoke WR_FromAlpha, hWnd
    .else
        invoke WR_ToAlpha, hWnd
    .endif

    ret
WR_InvertAlpha endp

;-------------------------------------------------------------------------------

Subclass proc hWnd:DWORD
    local Unicode:DWORD

    invoke IsWindowUnicode, hWnd
    mov Unicode, eax
    invoke GetWinProc, hWnd
    .if eax == 0
        .if Unicode == 0
            invoke SetWindowLongA, hWnd, GWL_WNDPROC, addr MsgProc
        .else
            invoke SetWindowLongW, hWnd, GWL_WNDPROC, addr MsgProc
        .endif
        .if eax != 0
            invoke SetWinProc, hWnd, eax
            .if eax != 0
                add RollCount, 1
            .endif
        .endif
    .endif

    ret
Subclass endp

;-------------------------------------------------------------------------------

UnSubclass proc hWnd:DWORD
    local Unicode:DWORD

    invoke IsWindowUnicode, hWnd
    mov Unicode, eax
    invoke GetWinProc, hWnd
    .if eax != 0
        .if Unicode == 0
            invoke SetWindowLongA, hWnd, GWL_WNDPROC, eax
        .else
            invoke SetWindowLongW, hWnd, GWL_WNDPROC, eax
        .endif
        .if eax != 0
            invoke RemoveWinProc, hWnd
            .if eax != 0
                sub RollCount, 1
            .endif
        .endif
    .endif

    ret
UnSubclass endp

;-------------------------------------------------------------------------------

IsWinValid proc hWnd:DWORD
    ; top level window only
    invoke GetParent, hWnd
    .if eax == 0
        ; visible window only
        invoke IsWindowVisible, hWnd
        .if eax != 0
            ; windows with title text only
            invoke GetWindowTextLength, hWnd
            .if eax != 0
                ; window with minimize/maximize boxes only
                invoke GetWindowLong, hWnd, GWL_STYLE
                and eax, WS_OVERLAPPEDWINDOW
            .endif
        .endif
    .else
        xor eax, eax
    .endif
    ; return non zero if valid
    ret
IsWinValid endp

;-------------------------------------------------------------------------------

GetWinRect proc hWnd:DWORD, rcWnd:DWORD

    invoke GetWindowRect, hWnd, rcWnd

    assume edx:PTR RECT
    mov edx, rcWnd
    ; normalise width
    mov eax, [edx].right
    sub eax, [edx].left
    mov [edx].right, eax
    ; normalise height
    mov eax, [edx].bottom
    sub eax, [edx].top
    mov [edx].bottom, eax
    assume edx:NOTHING

    ; return window height
    ret
GetWinRect endp

;-------------------------------------------------------------------------------

MouseProc proc nCode:DWORD, wParam:DWORD, lParam:DWORD
    local hWnd:DWORD

    .if nCode < 0 || nCode == HC_NOREMOVE
        jmp MouseProcExit
    .endif

    ; get parent window
    invoke GetParent, eax

    mov edx, wParam

    ; detect left mouse button click on top level window
    .if eax == 0 && edx == WM_NCLBUTTONDOWN

        ; detect alt key down
        invoke GetAsyncKeyState, VK_MENU
        .if eax & KEY_DOWN

            mov edx, lParam
            ; get mouse hit
            mov eax, (MOUSEHOOKSTRUCT PTR [edx]).wHitTestCode

            .if eax == HTMINBUTTON
                invoke PostMessage, HWND_BROADCAST, WM_WINROLL, WM_WR_MIN, 0
                ret
            .elseif eax == HTMAXBUTTON
                invoke PostMessage, HWND_BROADCAST, WM_WINROLL, WM_WR_MAX, 0
                ret
            .elseif eax == HTCLOSE
                invoke PostMessage, HWND_BROADCAST, WM_WINROLL, WM_WR_CLOSE, 0
                ret
            .endif
        .endif

        ; X-Windows compatible sent to back

        ; detect shift key down
        invoke GetAsyncKeyState, VK_SHIFT
        .if eax & KEY_DOWN

            mov edx, lParam
            ; get window handle
            mov eax, (MOUSEHOOKSTRUCT PTR [edx]).hwnd
            mov hWnd, eax
            ; get mouse hit
            mov eax, (MOUSEHOOKSTRUCT PTR [edx]).wHitTestCode

            ; send to back
            .if eax == HTCAPTION
                invoke WR_ToBack, hWnd
                ret
            .endif
        .endif

    ; detect right mouse button click on top level window
    .elseif eax == 0 && edx == WM_NCRBUTTONDOWN

        mov edx, lParam
        ; get window handle
        mov eax, (MOUSEHOOKSTRUCT PTR [edx]).hwnd
        mov hWnd, eax
        ; get mouse hit
        mov eax, (MOUSEHOOKSTRUCT PTR [edx]).wHitTestCode

        .if eax == HTCAPTION
            ; detect alt key down
            invoke GetAsyncKeyState, VK_MENU
            .if eax & KEY_DOWN
                ; detect shift key down
                invoke GetAsyncKeyState, VK_SHIFT
                .if eax & KEY_DOWN
                    ; set transparency level
                    invoke WR_InvertAlphaAll
                .else
                    ; reverse height
                    invoke WR_InvertRollAll
                .endif
            .else
                ; detect shift key down
                invoke GetAsyncKeyState, VK_SHIFT
                .if eax & KEY_DOWN
                    ; set transparency level
                    invoke WR_InvertAlpha, hWnd
                .else
                    ; reverse height
                    invoke WR_InvertRoll, hWnd
                .endif
            .endif
            invoke BringWindowToTop, hWnd
            ret
        .elseif eax == HTMINBUTTON
            ; detect alt key down
            invoke GetAsyncKeyState, VK_MENU
            .if eax & KEY_DOWN
                ; detect shift key down
                invoke GetAsyncKeyState, VK_SHIFT
                .if eax & KEY_DOWN
                    ; minimize to tray
                    invoke WR_ToTrayAll
                .else
                    ; reduce height
                    invoke WR_RollupAll
                .endif
            .else
                ; detect shift key down
                invoke GetAsyncKeyState, VK_SHIFT
                .if eax & KEY_DOWN
                    ; minimize to tray
                    invoke WR_ToTray, hWnd
                .else
                    ; reduce height
                    invoke WR_Rollup, hWnd
                .endif
            .endif
            invoke BringWindowToTop, hWnd
            ret
        ; restore height
        .elseif eax == HTMAXBUTTON
            ; detect alt key down
            invoke GetAsyncKeyState, VK_MENU
            .if eax & KEY_DOWN
                invoke WR_UnrollAll
            .else
                invoke WR_Unroll, hWnd
            .endif
            invoke BringWindowToTop, hWnd
            ret
        .elseif eax == HTCLOSE
            ; detect shift key down
            invoke GetAsyncKeyState, VK_SHIFT
            .if eax & KEY_DOWN
                ; set/unset always on top
                invoke WR_OnTop, hWnd
            .else
                ; send to back
                invoke WR_ToBack, hWnd
            .endif
            ret
        .endif

    ; detect middle mouse button click
    .elseif edx == WM_NCMBUTTONDOWN

        ; avoid if necessary
        .if !(dwOptions & CFG_NOMIDDLE)

            mov edx, lParam
            ; get window handle
            mov eax, (MOUSEHOOKSTRUCT PTR [edx]).hwnd
            mov hWnd, eax
            ; get mouse hit
            mov eax, (MOUSEHOOKSTRUCT PTR [edx]).wHitTestCode

            ; set transparency level
            .if eax == HTCAPTION
                ; detect alt key down
                invoke GetAsyncKeyState, VK_MENU
                .if eax & KEY_DOWN
                    invoke WR_InvertAlphaAll
                .else
                    invoke WR_InvertAlpha, hWnd
                .endif
                invoke BringWindowToTop, hWnd
            ; set/unset always on top
            .elseif eax == HTCLOSE
                invoke WR_OnTop, hWnd
            ; minimize to tray
            .elseif eax == HTMINBUTTON
                ; detect alt key down
                invoke GetAsyncKeyState, VK_MENU
                .if eax & KEY_DOWN
                    invoke WR_ToTrayAll
                .else
                    invoke WR_ToTray, hWnd
                .endif
            .endif

        .endif

    .endif

MouseProcExit:
    invoke CallNextHookEx, hMouseHook, nCode, wParam, lParam
    ret
MouseProc endp

;-------------------------------------------------------------------------------

GetMsgProc proc nCode:DWORD, wParam:DWORD, lParam:DWORD
    local hWnd:DWORD

    .if nCode < 0 || wParam == PM_NOREMOVE
        jmp GetMsgProcExit
    .endif

    mov edx, lParam
    mov eax, (MSG PTR [edx]).message

    .if eax == WM_WINROLL
        mov eax, (MSG PTR [edx]).hwnd
        mov hWnd, eax

        mov eax, (MSG PTR [edx]).wParam
        .if eax == WM_WR_ROLLUP
            invoke WR_Rollup, hWnd
        .elseif eax == WM_WR_UNROLL
            invoke WR_Unroll, hWnd
        .elseif eax == WM_WR_INVERTROLL
            invoke WR_InvertRoll, hWnd
        .elseif eax == WM_WR_TOTRAY
            invoke WR_ToTray, hWnd
        .elseif eax == WM_WR_FROMTRAY
            invoke WR_FromTray, hWnd
        .elseif eax == WM_WR_TOALPHA
            invoke WR_ToAlpha, hWnd
        .elseif eax == WM_WR_FROMALPHA
            invoke WR_FromAlpha, hWnd
        .elseif eax == WM_WR_INVERTALPHA
            invoke WR_InvertAlpha, hWnd
        .else
            invoke IsWinValid, hWnd
            .if eax != 0
                mov edx, lParam
                mov eax, (MSG PTR [edx]).wParam
                .if eax == WM_WR_MIN
                    invoke IsIconic, hWnd
                    .if eax == 0
                        mov eax, SW_MINIMIZE
                    .else
                        mov eax, SW_RESTORE
                    .endif
                    invoke ShowWindow, hWnd, eax
                .elseif eax == WM_WR_MAX
                    invoke IsZoomed, hWnd
                    .if eax == 0
                        mov eax, SW_MAXIMIZE
                    .else
                        mov eax, SW_RESTORE
                    .endif
                    invoke ShowWindow, hWnd, eax
                .elseif eax == WM_WR_CLOSE
                    invoke PostMessage, hWnd, WM_CLOSE, 0, 0
                .endif
            .endif
        .endif
    ; unroll when closed
    .elseif eax == WM_CLOSE
        mov eax, (MSG PTR [edx]).hwnd
        invoke WR_Unroll, eax
    .endif

GetMsgProcExit:
    invoke CallNextHookEx, hGetMsgHook, nCode, wParam, lParam
    ret
GetMsgProc endp

;-------------------------------------------------------------------------------

MsgProc proc hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD

    mov eax, uMsg

    ; set minimum height
    .if eax == WM_GETMINMAXINFO
        ; get system minimum height
        invoke GetSystemMetrics, SM_CYMIN
        mov edx, lParam
        mov (MINMAXINFO PTR [edx]).ptMinTrackSize.y, eax
        ; consume message
        xor eax, eax
        ret
    ; maintain minimum height
    .elseif eax == WM_WINDOWPOSCHANGING
        ; get system minimum height
        invoke GetSystemMetrics, SM_CYMIN
        mov edx, lParam
        mov (WINDOWPOS PTR [edx]).cy, eax
        ; consume message
        xor eax, eax
        ret
    ; maintain minimum height
    .elseif eax == WM_WINDOWPOSCHANGED
        ; consume message
        xor eax, eax
        ret
    ; unroll when closed
    .elseif eax == WM_CLOSE
        invoke WR_Unroll, hWnd
    .endif

    invoke GetWinProc, hWnd
    mov hPrevProc, eax

    invoke IsWindowUnicode, hWnd
    .if eax == 0
        invoke CallWindowProcA, hPrevProc, hWnd, uMsg, wParam, lParam
    .else
        invoke CallWindowProcW, hPrevProc, hWnd, uMsg, wParam, lParam
    .endif

    ret
MsgProc endp

;-------------------------------------------------------------------------------

End DllEntry
