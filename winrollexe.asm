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
include \masm32\include\shell32.inc
include \masm32\include\gdi32.inc
include \masm32\include\comctl32.inc

includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib
includelib \masm32\lib\shell32.lib
includelib \masm32\lib\gdi32.lib
includelib \masm32\lib\comctl32.lib

include winroll.inc
include winreg.inc

include winrolldll.inc
includelib winrolldll.lib

;include \masm32\include\masm32.inc
;include \masm32\include\debug.inc
;includelib \masm32\lib\masm32.lib
;includelib \masm32\lib\debug.lib
;DBGWIN_DEBUG_ON = 1 ; include debug info into the program
;DBGWIN_EXT_INFO = 0 ; include extra debug info into the program

SetIcon macro dwMessage
    invoke Shell_NotifyIcon, dwMessage, addr hTrayData
endm

SetString macro uID
    mov eax, dwTextID
    .if eax != uID
        mov dwTextID, uID
        invoke LoadString, hInstance, uID, addr szBuffer, BUFFER_SIZE
        invoke SetDlgItemText, hWnd, IDC_HOWTO, addr szBuffer
    .endif
endm

WinMain        proto
WndUpdate      proto
AddToTray      proto :DWORD
AddTrayIcon    proto :DWORD
AddTrayMenu    proto :DWORD
RemoveFromTray proto :DWORD, :DWORD
RemoveTrayIcon proto :DWORD
RemoveTrayMenu proto :DWORD
GetMenuHwnd    proto :DWORD
GetWinRect     proto :DWORD, :DWORD
WndProc        proto :DWORD, :DWORD, :DWORD, :DWORD
OptionsProc    proto :DWORD, :DWORD, :DWORD, :DWORD
AboutProc      proto :DWORD, :DWORD, :DWORD, :DWORD
LinksProc      proto :DWORD, :DWORD, :DWORD, :DWORD

.const
IDI_TRAY       equ 0

IDD_ABOUT      equ 100
IDC_HOWTO      equ 101
IDC_EMAIL      equ 102
IDC_WEBSITE    equ 103

IDD_OPTIONS    equ 110
IDC_AUTOSTART  equ 111
IDC_HIDEICON   equ 112
IDC_NOMIDDLE   equ 113
IDC_ALPHA      equ 114
IDC_ASICON     equ 115
IDC_ASMENU     equ 116

IDM_MENU       equ 120
IDM_MINMENU    equ 121
IDM_MINNONE    equ 122
IDM_ENABLE     equ 123
IDM_OPTIONS    equ 124
IDM_ABOUT      equ 125
IDM_EXIT       equ 126

IDS_DEFAULT    equ 131
IDS_CAPTION    equ 132
IDS_MINIMIZE   equ 133
IDS_MAXIMIZE   equ 134
IDS_CLOSE      equ 135
IDS_NOMIN      equ 136

IDI_ICON1      equ 141
IDI_ICON2      equ 142

IDC_FINGER     equ 151

BUFFER_SIZE    equ MAX_PATH

MENU_FIRST     equ 1000

TIMER_DELAY    equ 1
TIMER_EXIT     equ 2

szTaskbarMsg   db "TaskbarCreated",0
szEmail        db "mailto:wilpalma@hotmail.com",0
szWebsite      db "http://www.palma.com.au/winroll/",0

szKeyWinRoll   db "Software\WinRoll",0
szValConfig    db "Configuration",0
szKeyAutoRun   db "Software\Microsoft\Windows\CurrentVersion\Run",0

.data
hMutex         dd 0
hInstance      dd 0
hProcess       dd 0
hPopMenu       dd 0
hWndOptions    dd 0
hWndAbout      dd 0
lOptionsProc   dd 0
lAboutProc     dd 0
WM_TASKBAR     dd 0
WM_WINROLL     dd 0
hLinksCursor   dd 0
dwBuffer       dd 0
dwConfig       dd 0
dwTextID       dd 0
hMinMenu       dd 0
dwMenuID       dd MENU_FIRST
hTrayData      NOTIFYICONDATA <0>
hCopyData      COPYDATASTRUCT <0>
rcAbout        RECT <0>
osVersion      OSVERSIONINFO <0>
ctlCommon      INITCOMMONCONTROLSEX <0>
szBuffer       db BUFFER_SIZE dup (0)

.code

;-------------------------------------------------------------------------------

WinEntry:
    ; check for previous instance
    invoke OpenMutex, MUTANT_ALL_ACCESS, 0, addr szAppClass
    .if eax == 0
        ; first instance, create application
        invoke CreateMutex, 0, 0, addr szAppClass
        mov hMutex, eax
        invoke WinMain
        invoke ReleaseMutex, hMutex
    .else
        ; second instance, show tray icon
        mov hCopyData.dwData, WM_WR_ICON
        invoke FindWindow, addr szAppClass, addr szAppTitle
        invoke SendMessage, eax, WM_COPYDATA, 0, addr hCopyData
    .endif
    invoke ExitProcess, 0

;-------------------------------------------------------------------------------

WinMain proc
    local wc:WNDCLASSEX
    local msg:MSG

    mov osVersion.dwOSVersionInfoSize, sizeof OSVERSIONINFO
    invoke GetVersionEx, addr osVersion

    mov ctlCommon.dwSize, sizeof INITCOMMONCONTROLSEX
    mov ctlCommon.dwICC, ICC_BAR_CLASSES
    invoke InitCommonControlsEx, addr ctlCommon

    invoke GetCurrentProcess
    mov hProcess, eax

    invoke GetModuleHandle, 0
    mov hInstance, eax

    mov wc.cbSize, sizeof WNDCLASSEX
    mov wc.style, 0
    mov wc.lpfnWndProc, offset WndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov wc.hInstance, eax
    mov wc.hIcon, 0
    mov wc.hIconSm, 0
    mov wc.hCursor, 0
    mov wc.hbrBackground, 0
    mov wc.lpszMenuName, 0
    mov wc.lpszClassName, offset szAppClass
    invoke RegisterClassEx, addr wc

    invoke CreateWindowEx, 0, addr szAppClass, addr szAppTitle,
                           0, 0, 0, 0, 0, 0, 0, hInstance, 0

    .while TRUE
        invoke GetMessage, addr msg, 0, 0, 0
        .break .if (!eax)
        invoke TranslateMessage, addr msg
        invoke DispatchMessage, addr msg
    .endw

    mov eax, msg.wParam
    ret
WinMain endp

;-------------------------------------------------------------------------------

WndUpdate proc
    .if dwConfig & CFG_ENABLE
        ; set tray icon
        invoke LoadIcon, hInstance, IDI_ICON1
        mov hTrayData.hIcon, eax
        ; enable winroll
        invoke WR_Start
    .else
        ; set tray icon
        invoke LoadIcon, hInstance, IDI_ICON2
        mov hTrayData.hIcon, eax
        ; disable winroll
        invoke WR_Stop
    .endif
    ret
WndUpdate endp

;-------------------------------------------------------------------------------

AddToTray proc hWnd:DWORD
    .if dwConfig & CFG_MINASMENU
        invoke AddTrayMenu, hWnd
    .else
        invoke AddTrayIcon, hWnd
    .endif
    ret
AddToTray endp

;-------------------------------------------------------------------------------

AddTrayIcon proc hWnd:DWORD
    local nid:NOTIFYICONDATA

    invoke RtlZeroMemory, addr nid, sizeof NOTIFYICONDATA
    mov nid.cbSize, sizeof NOTIFYICONDATA

    ; initialize icon item
    mov eax, hTrayData.hwnd
    mov nid.hwnd, eax
    mov eax, hWnd
    mov nid.uID, eax
    invoke GetClassLong, eax, GCL_HICONSM
    mov nid.hIcon, eax
    mov nid.uFlags, NIF_ICON + NIF_TIP + NIF_MESSAGE
    mov nid.uCallbackMessage, WM_WR_ICON
    invoke GetWindowText, hWnd, addr szBuffer, 64 - 1
    invoke lstrcpy, addr nid.szTip, addr szBuffer

    ; add icon item
    invoke Shell_NotifyIcon, NIM_ADD, addr nid

    mov eax, -1
    ret
AddTrayIcon endp

;-------------------------------------------------------------------------------

AddTrayMenu proc hWnd:DWORD
    local mii:MENUITEMINFO

    invoke RtlZeroMemory, addr mii, sizeof MENUITEMINFO
    mov mii.cbSize, sizeof MENUITEMINFO

    ; Win95
    .if osVersion.dwMajorVersion == 4 && osVersion.dwMinorVersion == 0
        mov mii.fMask, MIIM_DATA + MIIM_ID
        mov mii.fType, MFT_STRING
    ; or above
    .elseif osVersion.dwMajorVersion >= 4
        mov mii.fMask, MIIM_BITMAP + MIIM_DATA + MIIM_ID + MIIM_STRING
        mov mii.hbmpItem, HBMMENU_SYSTEM
    ; or below
    .else
        ret
    .endif

    ; initialize menu item
    mov eax, hWnd
    mov mii.dwItemData, eax
    mov eax, dwMenuID
    add eax, 1
    mov mii.wID, eax
    invoke GetWindowText, hWnd, addr szBuffer, BUFFER_SIZE - 1
    mov mii.cch, eax
    mov mii.dwTypeData, offset szBuffer

    ; add menu item
    invoke InsertMenuItem, hMinMenu, 0, -1, addr mii
    .if eax != 0
        add dwMenuID, 1
        invoke DrawMenuBar, hTrayData.hwnd
    .endif

    ; remove menu empty item
    .if dwMenuID == MENU_FIRST + 1
        invoke RemoveMenu, hMinMenu, 1, MF_BYPOSITION
        invoke DrawMenuBar, hTrayData.hwnd
    .endif

    mov eax, dwMenuID
    ret
AddTrayMenu endp

;-------------------------------------------------------------------------------

RemoveFromTray proc hWnd:DWORD, dwID:DWORD

    mov eax, dwMenuID

    .if dwID == -1
        invoke RemoveTrayIcon, hWnd
    .else
        invoke RemoveTrayMenu, dwID
    .endif

    ret
RemoveFromTray endp

;-------------------------------------------------------------------------------

RemoveTrayIcon proc hWnd:DWORD
    local nid:NOTIFYICONDATA

    invoke RtlZeroMemory, addr nid, sizeof NOTIFYICONDATA
    mov nid.cbSize, sizeof NOTIFYICONDATA

    ; initialize icon item
    mov eax, hTrayData.hwnd
    mov nid.hwnd, eax
    mov eax, hWnd
    mov nid.uID, eax

    ; remove icon item
    invoke Shell_NotifyIcon, NIM_DELETE, addr nid

    ret
RemoveTrayIcon endp

;-------------------------------------------------------------------------------

RemoveTrayMenu proc wID:DWORD
    local mii:MENUITEMINFO

    invoke RtlZeroMemory, addr mii, sizeof MENUITEMINFO
    mov mii.cbSize, sizeof MENUITEMINFO

    ; remove menu item
    invoke RemoveMenu, hMinMenu, wID, MF_BYCOMMAND
    .if eax != 0
        sub dwMenuID, 1
        invoke DrawMenuBar, hTrayData.hwnd
    .endif

    ; add menu empty item
    .if dwMenuID == MENU_FIRST
        ; Win95
        .if osVersion.dwMajorVersion == 4 && osVersion.dwMinorVersion == 0
            mov mii.fType, MFT_STRING
        ; or above
        .else
            mov mii.fMask, MIIM_STRING
        .endif
        invoke LoadString, hInstance, IDS_NOMIN, addr szBuffer, BUFFER_SIZE
        mov mii.cch, eax
        mov mii.dwTypeData, offset szBuffer
        invoke InsertMenuItem, hMinMenu, 0, -1, addr mii
        invoke DrawMenuBar, hTrayData.hwnd
    .endif

    mov eax, dwMenuID
    ret
RemoveTrayMenu endp

;-------------------------------------------------------------------------------

GetMenuHwnd proc wID:DWORD
    local mii:MENUITEMINFO

    invoke RtlZeroMemory, addr mii, sizeof MENUITEMINFO
    mov mii.cbSize, sizeof MENUITEMINFO
    mov mii.fMask, MIIM_DATA

    ; get menu item
    invoke GetMenuItemInfo, hMinMenu, wID, 0, addr mii

    mov eax, mii.dwItemData
    ret
GetMenuHwnd endp

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

WndProc proc hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    local pt:POINT

    mov eax, uMsg
    mov ecx, wParam
    mov edx, lParam

    .if eax == WM_WR_ICON
        .if ecx == IDI_TRAY
            .if edx == WM_LBUTTONUP
                ; change enable state
                jmp WndChange
            .elseif edx == WM_RBUTTONUP
                ; display context menu
                invoke GetCursorPos, addr pt
                invoke SetForegroundWindow, hWnd
                ; activate context menu
                invoke TrackPopupMenu, hPopMenu, 0, pt.x, pt.y, 0, hWnd, 0
                invoke PostMessage, hWnd, WM_NULL, 0, 0
            .endif
        .else
            .if edx == WM_LBUTTONUP
                ; remove icon
                invoke WR_FromTray, ecx
            .endif
        .endif
        ; reduce memory
        jmp Timeout
    .elseif eax == WM_COMMAND
        .if ecx > MENU_FIRST
            ; remove menu
            invoke GetMenuHwnd, ecx
            invoke WR_FromTray, eax
        .elseif ecx == IDM_ENABLE
WndChange:
            ; toggle winroll
            .if dwConfig & CFG_ENABLE
                xor dwConfig, CFG_ENABLE
            .else
                or dwConfig, CFG_ENABLE
            .endif
            invoke WndUpdate
            SetIcon NIM_MODIFY
        .elseif ecx == IDM_OPTIONS
            .if hWndOptions == 0
                invoke DialogBoxParam, hInstance, IDD_OPTIONS, hWnd,
                                                  addr OptionsProc, 0
            .else
                invoke SetWindowPos, hWndOptions, HWND_TOP, 0, 0, 0, 0,
                                                  SWP_NOMOVE + SWP_NOSIZE
            .endif
        .elseif ecx == IDM_ABOUT
            .if hWndAbout == 0
                invoke DialogBoxParam, hInstance, IDD_ABOUT, 0,
                                                  addr AboutProc, 0
            .else
                invoke SetWindowPos, hWndAbout, HWND_TOP, 0, 0, 0, 0,
                                                SWP_NOMOVE + SWP_NOSIZE
            .endif
        .elseif ecx == IDM_EXIT
WndClose:
            ; stop winroll
            xor dwConfig, CFG_ENABLE
            invoke WndUpdate
            SetIcon NIM_DELETE
            ; create exit timer
            invoke SetTimer, hWnd, TIMER_EXIT, 1000, 0
        .endif
        ; reduce memory
        jmp Timeout
    .elseif eax == WM_INITMENUPOPUP
        .if dwConfig & CFG_ENABLE
            mov eax, MF_CHECKED
        .else
            mov eax, MF_UNCHECKED
        .endif
        invoke CheckMenuItem, hPopMenu, IDM_ENABLE, eax
        ; reduce memory
        jmp Timeout
    .elseif eax == WM_WINROLL
        ; just reduce memory
    .elseif eax == WM_TASKBAR
        ; show tray icon
        jmp ShowIcon
    .elseif eax == WM_COPYDATA
        mov eax, (COPYDATASTRUCT PTR [edx]).dwData
        .if eax == WM_WR_ICON
            ; show tray icon
            SetIcon NIM_ADD
        .elseif eax == WM_WR_TOTRAY
            ; add to tray
            invoke AddToTray, ecx
        .elseif eax == WM_WR_FROMTRAY
            ; remove from tray
            mov eax, (COPYDATASTRUCT PTR [edx]).lpData
            invoke RemoveFromTray, ecx, (DWORD PTR [eax])
        .endif
        ; save return code
        push eax
        ; reduce memory use
        invoke SetProcessWorkingSetSize, hProcess, -1, -1
        ; restore return code
        pop eax
        ret
    .elseif eax == WM_TIMER
        invoke KillTimer, hWnd, wParam
        .if wParam == TIMER_EXIT
            invoke DestroyWindow, hWnd
        .endif
    .elseif eax == WM_CREATE
        ; set tray data
        mov hTrayData.cbSize, sizeof NOTIFYICONDATA
        mov eax, hWnd
        mov hTrayData.hwnd, eax
        mov hTrayData.uID, IDI_TRAY
        mov hTrayData.uFlags, NIF_ICON + NIF_TIP + NIF_MESSAGE
        mov hTrayData.uCallbackMessage, WM_WR_ICON
        invoke lstrcpy, addr hTrayData.szTip, addr szAppTitle
        ; register taskbar message
        invoke RegisterWindowMessage, addr szTaskbarMsg
        mov WM_TASKBAR, eax
        ; register winroll message
        invoke RegisterWindowMessage, addr szAppTitle
        mov WM_WINROLL, eax
        ; retrieve context menus
        invoke LoadMenu, hInstance, IDM_MENU
        invoke GetSubMenu, eax, 0
        mov hPopMenu, eax
        invoke GetSubMenu, eax, 0
        mov hMinMenu, eax
        ; retrieve configuration
        invoke GetRegNumber, addr szKeyWinRoll, addr szValConfig, addr dwConfig
        invoke WR_SetConfig, dwConfig
        ; start winroll
        or dwConfig, CFG_ENABLE
        invoke WndUpdate
ShowIcon:
        .if !(dwConfig & CFG_HIDEICON)
            SetIcon NIM_ADD
        .endif
Timeout:
        ; create delay timer
        invoke SetTimer, hWnd, TIMER_DELAY, 500, 0
    .elseif eax == WM_CLOSE
        jmp WndClose
    .elseif eax == WM_DESTROY
        invoke PostQuitMessage, 0
    .else
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        ret
    .endif

    ; reduce memory use
    invoke SetProcessWorkingSetSize, hProcess, -1, -1

    xor eax, eax
    ret
WndProc endp

;-------------------------------------------------------------------------------

OptionsProc proc hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD

    mov eax, uMsg
    .if eax == WM_COMMAND
        mov eax, wParam
        .if ax == IDOK
            ; handle auto-start checkbox
            invoke SendDlgItemMessage, hWnd, IDC_AUTOSTART, BM_GETCHECK, 0, 0
            .if eax == BST_CHECKED
                or dwConfig, CFG_AUTOSTART
                invoke GetCommandLine
                mov dwBuffer, eax
                invoke lstrlen, eax
                ; remove trailing space
                sub eax, 1
                invoke SetRegString, addr szKeyAutoRun, addr szAppTitle, dwBuffer, eax
            .else
                and dwConfig, not CFG_AUTOSTART
                invoke RemoveRegVal, addr szKeyAutoRun, addr szAppTitle
            .endif
            ; handle hide icon checkbox
            invoke SendDlgItemMessage, hWnd, IDC_HIDEICON, BM_GETCHECK, 0, 0
            .if eax == BST_CHECKED
                or dwConfig, CFG_HIDEICON
                SetIcon NIM_DELETE
            .else
                and dwConfig, not CFG_HIDEICON
            .endif
            ; handle ignore middle mouse button checkbox
            invoke SendDlgItemMessage, hWnd, IDC_NOMIDDLE, BM_GETCHECK, 0, 0
            .if eax == BST_CHECKED
                or dwConfig, CFG_NOMIDDLE
            .else
                and dwConfig, not CFG_NOMIDDLE
            .endif
            ; zero transparency
            and dwConfig, not CFG_TRANSPARENCY
            ; Win2K or above
            .if osVersion.dwMajorVersion >= 5
                ; handle transparency trackbar
                invoke SendDlgItemMessage, hWnd, IDC_ALPHA, TBM_GETPOS, 0, 0
                or dwConfig, eax
            .endif
            ; handle minimize to tray mode
            invoke SendDlgItemMessage, hWnd, IDC_ASMENU, BM_GETCHECK, 0, 0
            .if eax == BST_CHECKED
                or dwConfig, CFG_MINASMENU
            .else
                and dwConfig, not CFG_MINASMENU
            .endif
            ; save configuration
            invoke SetRegNumber, addr szKeyWinRoll, addr szValConfig, addr dwConfig
            invoke WR_SetConfig, dwConfig
            ; destroy window resources
            invoke DestroyWindow, hWnd
        .elseif ax == IDCANCEL
            ; destroy window resources
            invoke DestroyWindow, hWnd
        .endif
    .elseif eax == WM_INITDIALOG
        ; save window handle
        mov eax, hWnd
        mov hWndOptions, eax
        ; button gets input focus
        invoke GetDlgItem, hWnd, IDOK
        invoke SetFocus, eax
        ; initialise controls
        .if dwConfig & CFG_AUTOSTART
            invoke SendDlgItemMessage, hWnd, IDC_AUTOSTART, BM_SETCHECK, BST_CHECKED, 0
        .endif
        .if dwConfig & CFG_HIDEICON
            invoke SendDlgItemMessage, hWnd, IDC_HIDEICON, BM_SETCHECK, BST_CHECKED, 0
        .endif
        .if dwConfig & CFG_NOMIDDLE
            invoke SendDlgItemMessage, hWnd, IDC_NOMIDDLE, BM_SETCHECK, BST_CHECKED, 0
        .endif
        ; Win2K or above
        .if osVersion.dwMajorVersion >= 5
            mov eax, dwConfig
            and eax, CFG_TRANSPARENCY
            mov dwBuffer, eax
            invoke SendDlgItemMessage, hWnd, IDC_ALPHA, TBM_SETPOS, TRUE, dwBuffer
            invoke SendDlgItemMessage, hWnd, IDC_ALPHA, TBM_SETTICFREQ, 10, 0
            invoke SendDlgItemMessage, hWnd, IDC_ALPHA, TBM_SETPAGESIZE, 0, 10
        .else
            invoke SendDlgItemMessage, hWnd, IDC_ALPHA, WM_ENABLE, 0, 0
        .endif
        .if dwConfig & CFG_MINASMENU
            mov eax, IDC_ASMENU
        .else
            mov eax, IDC_ASICON
        .endif
        invoke SendDlgItemMessage, hWnd, eax, BM_SETCHECK, BST_CHECKED, 0
    .elseif eax == WM_CLOSE
        ; destroy window resources
        invoke DestroyWindow, hWnd
    .elseif eax == WM_DESTROY
        mov hWndOptions, 0
        invoke EndDialog, hWnd, 0
    .endif

    xor eax, eax
    ret
OptionsProc endp

;-------------------------------------------------------------------------------

AboutProc proc hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD

    mov eax, uMsg
    .if eax == WM_MOUSEMOVE
        ; set default message
        SetString IDS_DEFAULT
    .elseif eax == WM_NCMOUSEMOVE
        mov eax, wParam
        .if eax == HTCAPTION
            ; set caption message
            SetString IDS_CAPTION
        .elseif eax == HTMINBUTTON
            ; set caption message
            SetString IDS_MINIMIZE
        .elseif eax == HTMAXBUTTON
            ; set caption message
            SetString IDS_MAXIMIZE
        .elseif eax == HTCLOSE
            ; set caption message
            SetString IDS_CLOSE
        .endif
    .elseif eax == WM_COMMAND
        mov eax, wParam
        .if ax == IDOK || ax == IDCANCEL
            ; destroy window resources
            invoke DestroyWindow, hWnd
        .elseif ax == IDC_EMAIL || ax == IDC_WEBSITE
            invoke SendMessage, lParam, uMsg, wParam, lParam
        .endif
    .elseif eax == WM_CTLCOLORSTATIC
        invoke GetDlgCtrlID, lParam
        .if eax == IDC_EMAIL || eax == IDC_WEBSITE
            invoke SendMessage, lParam, uMsg, wParam, lParam
            ret
        .endif
    .elseif eax == WM_GETMINMAXINFO
        ; maintain original size
        mov edx, lParam
        mov eax, rcAbout.right
        mov (MINMAXINFO PTR [edx]).ptMinTrackSize.x, eax
        mov eax, rcAbout.bottom
        mov (MINMAXINFO PTR [edx]).ptMinTrackSize.y, eax
    .elseif eax == WM_INITDIALOG
        ; save window handle
        mov eax, hWnd
        mov hWndAbout, eax
        ; button gets input focus
        invoke GetDlgItem, hWnd, IDOK
        invoke SetFocus, eax
        ; subclass email control
        invoke GetDlgItem, hWnd, IDC_EMAIL
        invoke SetWindowLong, eax, GWL_WNDPROC, addr LinksProc
        ; subclass website control
        invoke GetDlgItem, hWnd, IDC_WEBSITE
        invoke SetWindowLong, eax, GWL_WNDPROC, addr LinksProc
        mov lAboutProc, eax
        ; load links cursor
        invoke LoadCursor, hInstance, IDC_FINGER
        mov hLinksCursor, eax
        ; reset text id
        mov dwTextID, 0
        ; set default message
        SetString IDS_DEFAULT
        ; get window dimensions
        invoke GetWinRect, hWnd, addr rcAbout
    .elseif eax == WM_CLOSE
        ; destroy window resources
        invoke DestroyWindow, hWnd
    .elseif eax == WM_DESTROY
        mov hWndAbout, 0
        invoke KillTimer, hWnd, 1
        invoke EndDialog, hWnd, 0
    .endif

    xor eax, eax
    ret
AboutProc endp

;-------------------------------------------------------------------------------

LinksProc proc hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    local rc:RECT
    local pt:POINT
    local lf:LOGFONT
    local hFont:DWORD

    mov eax, uMsg
    .if eax == WM_MOUSEMOVE
        ; show or hide links cursor
        invoke GetActiveWindow
        .if eax == hWndAbout
            invoke GetCursorPos, addr pt
            invoke GetWindowRect, hWnd, addr rc
            invoke PtInRect, addr rc, pt.x, pt.y
            .if eax != 0
                invoke GetCapture
                .if eax == 0
                    invoke SetCapture, hWnd
                    invoke InvalidateRect, hWnd, 0, 0
                    invoke SetCursor, hLinksCursor
                .endif
            .else
                invoke GetCapture
                .if eax != 0
                    invoke ReleaseCapture
                    invoke InvalidateRect, hWnd, 0, 0
                .endif
            .endif
        .endif
    .elseif eax == WM_CTLCOLORSTATIC
        ; set text to underlined blue
        invoke SendMessage, hWnd, WM_GETFONT, 0, 0
        mov hFont, eax
        invoke GetObject, hFont, sizeof LOGFONT, addr lf
        mov lf.lfUnderline, 1
        invoke CreateFontIndirect, addr lf
        mov hFont, eax
        invoke SelectObject, wParam, hFont
        invoke DeleteObject, hFont
        invoke SetTextColor, wParam, Blue
        invoke SetBkMode, wParam, TRANSPARENT
        ; must return a brush handle
        invoke GetStockObject, NULL_BRUSH
        ret
    .elseif eax == WM_COMMAND
        ; choose link text
        mov eax, wParam
        .if ax == IDC_EMAIL
            mov eax, offset szEmail
        .else
            mov eax, offset szWebsite
        .endif
        ; call shell to open link
        invoke ShellExecute, 0, 0, eax, 0, 0, SW_SHOWNORMAL
    .else
        invoke CallWindowProc, lAboutProc, hWnd, uMsg, wParam, lParam
        ret
    .endif

    xor eax, eax
    ret
LinksProc endp

;-------------------------------------------------------------------------------

End WinEntry
