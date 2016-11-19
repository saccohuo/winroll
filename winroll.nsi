!define MUI_PRODUCT "WinRoll"
!define MUI_VERSION "2.0"

!include "MUI.nsh"

;--------------------------------
;Configuration

  ;General
  OutFile "${MUI_PRODUCT}-${MUI_VERSION}.exe"

  ;Folder selection page
  InstallDir "$PROGRAMFILES\${MUI_PRODUCT}"

  ;Remember install folder
  InstallDirRegKey HKCU "Software\${MUI_PRODUCT}" ""

  ;Remember the Start Menu Folder
  !define MUI_STARTMENUPAGE_REGISTRY_ROOT "HKCU" 
  !define MUI_STARTMENUPAGE_REGISTRY_KEY "Software\${MUI_PRODUCT}" 
  !define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "Start Menu Folder"
  !define TEMP $R0

;--------------------------------
;Modern UI Configuration

  !define MUI_BRANDINGTEXT " "

  !define MUI_WELCOMEPAGE
  !define MUI_LICENSEPAGE
  !define MUI_DIRECTORYPAGE
  !define MUI_STARTMENUPAGE
  !define MUI_FINISHPAGE
    !define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\readme.html"
    !define MUI_FINISHPAGE_RUN "$INSTDIR\winroll.exe"
  !define MUI_ABORTWARNING
  !define MUI_UNINSTALLER
  !define MUI_UNCONFIRMPAGE
  
;--------------------------------
;Languages
 
  !insertmacro MUI_LANGUAGE "English"
  
;--------------------------------
;Data
  
  LicenseData "license.txt"

;--------------------------------
;Installer Sections

Section "Install"

  SetOutPath "$INSTDIR"
  File "winroll.exe"
  File "winroll.dll"
  File "readme.html"
  File "winroll.png"

  ;Store install folder
  WriteRegStr HKCU "Software\${MUI_PRODUCT}" "" $INSTDIR
  ;Set to auto-start
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" ${MUI_PRODUCT} "$INSTDIR\winroll.exe"
  ;Uninstall info
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall" ${MUI_PRODUCT} "$INSTDIR\uninstall.exe"

  !insertmacro MUI_STARTMENU_WRITE_BEGIN

    ;Create shortcuts
    CreateDirectory "$SMPROGRAMS\${MUI_STARTMENUPAGE_VARIABLE}"
    CreateShortCut "$SMPROGRAMS\${MUI_STARTMENUPAGE_VARIABLE}\Winroll.lnk" "$INSTDIR\winroll.exe"
    CreateShortCut "$SMPROGRAMS\${MUI_STARTMENUPAGE_VARIABLE}\Readme.lnk" "$INSTDIR\readme.html"
    CreateShortCut "$SMPROGRAMS\${MUI_STARTMENUPAGE_VARIABLE}\Uninstall.lnk" "$INSTDIR\uninstall.exe"

  !insertmacro MUI_STARTMENU_WRITE_END

  ;Create uninstaller
  WriteUninstaller "$INSTDIR\uninstall.exe"

SectionEnd

;--------------------------------
;Uninstaller Section

Section "Uninstall"

  Delete "$INSTDIR\winroll.exe"
  Delete "$INSTDIR\winroll.dll"
  Delete "$INSTDIR\readme.html"
  Delete "$INSTDIR\winroll.png"
  Delete "$INSTDIR\uninstall.exe"

  ;Remove shortcut
  ReadRegStr ${TEMP} "${MUI_STARTMENUPAGE_REGISTRY_ROOT}" "${MUI_STARTMENUPAGE_REGISTRY_KEY}" "${MUI_STARTMENUPAGE_REGISTRY_VALUENAME}"

  StrCmp ${TEMP} "" noshortcuts

    Delete "$SMPROGRAMS\${TEMP}\Winroll.lnk"
    Delete "$SMPROGRAMS\${TEMP}\Readme.lnk"
    Delete "$SMPROGRAMS\${TEMP}\Uninstall.lnk"
    RMDir "$SMPROGRAMS\${TEMP}" ;Only if empty, so it won't delete other shortcuts

  noshortcuts:

  RMDir "$INSTDIR"

  DeleteRegKey HKCU "Software\${MUI_PRODUCT}"
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" ${MUI_PRODUCT}
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall" ${MUI_PRODUCT}

  ;Display the Finish header
  !insertmacro MUI_UNFINISHHEADER

SectionEnd

Function .onInit
  FindWindow $R1 "WinRollClass"
  IntCmp $R1 0 NoAbort
    MessageBox MB_OK|MB_ICONEXCLAMATION "Please exit ${MUI_PRODUCT} before continuing."
    Abort
  NoAbort:
FunctionEnd

Function un.onInit
  FindWindow $R1 "WinRollClass"
  IntCmp $R1 0 NoAbort
    MessageBox MB_OK|MB_ICONEXCLAMATION "Please exit ${MUI_PRODUCT} before continuing."
    Abort
  NoAbort:
FunctionEnd
