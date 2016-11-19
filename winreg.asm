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
include \masm32\include\advapi32.inc

includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\advapi32.lib

;include \masm32\include\masm32.inc
;include \masm32\include\debug.inc
;includelib \masm32\lib\masm32.lib
;includelib \masm32\lib\debug.lib
;DBGWIN_DEBUG_ON = 1 ; include debug info into the program
;DBGWIN_EXT_INFO = 0 ; include extra debug info into the program

GetRegNumber  proto :DWORD, :DWORD, :DWORD
SetRegNumber  proto :DWORD, :DWORD, :DWORD
GetRegString  proto :DWORD, :DWORD, :DWORD, :DWORD
SetRegString  proto :DWORD, :DWORD, :DWORD, :DWORD
RemoveRegVal  proto :DWORD, :DWORD

.code

;-------------------------------------------------------------------------------

GetRegNumber proc lKeyName:DWORD, lValName:DWORD, lValData:DWORD
    local hKey:DWORD
    local lValSize:DWORD

    invoke RegOpenKeyEx, HKEY_CURRENT_USER, lKeyName, 0, KEY_ALL_ACCESS, addr hKey
    .if eax == ERROR_SUCCESS
        mov lValSize, 4
        invoke RegQueryValueEx, hKey, lValName, 0, 0, lValData, addr lValSize
        invoke RegCloseKey, hKey
    .endif

    ret
GetRegNumber endp

;-------------------------------------------------------------------------------

SetRegNumber proc lKeyName:DWORD, lValName:DWORD, lValData:DWORD
    local hKey:DWORD

    invoke RegCreateKeyEx, HKEY_CURRENT_USER, lKeyName, 0, 0, 0,
                           KEY_ALL_ACCESS, 0, addr hKey, 0
    .if eax == ERROR_SUCCESS
        invoke RegSetValueEx, hKey, lValName, 0, REG_DWORD, lValData, 4
        invoke RegCloseKey, hKey
    .endif

    ret
SetRegNumber endp

;-------------------------------------------------------------------------------

GetRegString proc lKeyName:DWORD, lValName:DWORD, lValData:DWORD, lValSize:DWORD
    local hKey:DWORD

    invoke RegOpenKeyEx, HKEY_CURRENT_USER, lKeyName, 0, KEY_ALL_ACCESS, addr hKey
    .if eax == ERROR_SUCCESS
        invoke RegQueryValueEx, hKey, lValName, 0, 0, lValData, lValSize
        invoke RegCloseKey, hKey
    .endif

    ret
GetRegString endp

;-------------------------------------------------------------------------------

SetRegString proc lKeyName:DWORD, lValName:DWORD, lValData:DWORD, lValSize:DWORD
    local hKey:DWORD

    invoke RegCreateKeyEx, HKEY_CURRENT_USER, lKeyName, 0, 0, 0,
                           KEY_ALL_ACCESS, 0, addr hKey, 0
    .if eax == ERROR_SUCCESS
        invoke RegSetValueEx, hKey, lValName, 0, REG_SZ, lValData, lValSize
        invoke RegCloseKey, hKey
    .endif

    ret
SetRegString endp

;-------------------------------------------------------------------------------

RemoveRegVal proc lKeyName:DWORD, lValName:DWORD
    local hKey:DWORD

    invoke RegOpenKeyEx, HKEY_CURRENT_USER, lKeyName, 0, KEY_ALL_ACCESS, addr hKey
    .if eax == ERROR_SUCCESS
        invoke RegDeleteValue, hKey, lValName
    .endif

    ret
RemoveRegVal endp

;-------------------------------------------------------------------------------

end
