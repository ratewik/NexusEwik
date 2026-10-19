; NexusEwik — Copyright (C) 2026 ratewik. GPL-3.0, see LICENSE.
; NSIS hooks for electron-builder (installer/build.js). The installer runs elevated (per-machine),
; so it adds the same firewall rules the app's Fix button would (firewall.js), for every network
; profile so a standard account on a Public network never needs Fix; the uninstaller removes them. A helper (or our adb server) left running would lock its .exe, so it is stopped first.

!macro customInit
  nsExec::Exec 'taskkill /f /im nexusewik-winhelper.exe'
  nsExec::Exec '"$INSTDIR\resources\app\windows\vendor\adb\adb.exe" kill-server'
!macroend

!macro customUnInit
  nsExec::Exec 'taskkill /f /im nexusewik-winhelper.exe'
  nsExec::Exec '"$INSTDIR\resources\app\windows\vendor\adb\adb.exe" kill-server'
!macroend

; In place of electron-builder's "NexusEwik is running, close it" check, before the old version's
; uninstaller and the file copy: a running NexusEwik is closed rather than asked about, and the old
; app folder goes, so every file is the new version's (none left over from earlier releases).
!macro customCheckAppRunning
  nsExec::Exec 'taskkill /f /t /im NexusEwik.exe'
  nsExec::Exec 'taskkill /f /im nexusewik-winhelper.exe'
  Sleep 500
  RMDir /r "$INSTDIR\resources\app"
!macroend

!macro customInstall
  ; Renamed from NexusEwik: its rules (and its Program Files folder's exe) go.
  nsExec::Exec 'netsh advfirewall firewall delete rule name="NexusEwik"'
  nsExec::Exec 'netsh advfirewall firewall delete rule name="NexusEwik (TCP 47600)"'
  nsExec::Exec 'netsh advfirewall firewall delete rule name="NexusEwik" program="$INSTDIR\NexusEwik.exe"'
  nsExec::Exec 'netsh advfirewall firewall add rule name="NexusEwik" dir=in action=allow program="$INSTDIR\NexusEwik.exe" profile=any enable=yes'
  ; This PC also listens (PC ↔ PC host), so the port gets its own rule.
  nsExec::Exec 'netsh advfirewall firewall delete rule name="NexusEwik (TCP 47600)"'
  nsExec::Exec 'netsh advfirewall firewall add rule name="NexusEwik (TCP 47600)" dir=in action=allow protocol=TCP localport=47600 program="$INSTDIR\NexusEwik.exe" profile=any enable=yes'
  ; A phone: adb finds its wireless debugging over mDNS (phone-bridge.js).
  nsExec::Exec 'netsh advfirewall firewall delete rule name="NexusEwik (adb)"'
  nsExec::Exec 'netsh advfirewall firewall add rule name="NexusEwik (adb)" dir=in action=allow program="$INSTDIR\resources\app\windows\vendor\adb\adb.exe" profile=any enable=yes'
!macroend

!macro customUnInstall
  nsExec::Exec 'netsh advfirewall firewall delete rule name="NexusEwik" program="$INSTDIR\NexusEwik.exe"'
  nsExec::Exec 'netsh advfirewall firewall delete rule name="NexusEwik (TCP 47600)"'
  nsExec::Exec 'netsh advfirewall firewall delete rule name="NexusEwik (adb)"'
  ; The pinned Mac apps' Start menu folder is per user (the app makes it in Roaming).
  SetShellVarContext current
  RMDir /r "$APPDATA\Microsoft\Windows\Start Menu\Programs\NexusEwik Apps"
  RMDir /r "$APPDATA\Microsoft\Windows\Start Menu\Programs\NexusEwik Apps"
  ; Explorer › Send to › "<peer> (NexusEwik)" (sendto.js).
  Delete "$APPDATA\Microsoft\Windows\SendTo\* (NexusEwik).lnk"
  Delete "$APPDATA\Microsoft\Windows\SendTo\* (NexusEwik).lnk"
  SetShellVarContext all
!macroend
