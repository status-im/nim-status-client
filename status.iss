#define   Name       "Status"
#define   Version    "0.0.1"
#define   Publisher  "Status.im"
#define   URL        "https://status.im"
#define   ExeName    "Status.exe"

[Setup]

; Generated from Tools -> Generate GUID
AppId={{F3E2EDB6-78E8-4539-9C8B-A78F059D8647}}

AppName={#Name}
AppVersion={#Version}
AppPublisher={#Publisher}
AppPublisherURL={#URL}
AppSupportURL={#URL}
AppUpdatesURL={#URL}

; Defalut install path
DefaultDirName={pf}\{#Name}

DefaultGroupName={#Name}

; output dir for installer
OutputDir=.
OutputBaseFileName=status-setup

; Icon file
SetupIconFile=resources\status.ico

; Compression
Compression=lzma
SolidCompression=yes

;[Languages] - if needed
;Name: "english"; MessagesFile: "compiler:Default.isl"; LicenseFile: "License_ENG.txt"
;Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"; LicenseFile: "License_RUS.txt"

[Files]

; Path to exe on 
Source: "Status.exe"; DestDir: "{app}"; Flags: ignoreversion

; Resources
Source: "bin\Status.exe"; DestDir: "{app}\bin"; Flags: ignoreversion recursesubdirs createallsubdirs

Source: "resources\*"; DestDir: "{app}\resources"; Flags: ignoreversion recursesubdirs createallsubdirs

Source: "vendor\*"; DestDir: "{app}\vendor"; Flags: ignoreversion recursesubdirs createallsubdirs


[Registry]
Root: HKCU; Subkey: "Software\Classes\status-im"; ValueType: "string"; ValueData: "URL:status-im protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\status-im"; ValueType: "string"; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\status-im\DefaultIcon"; ValueType: "string"; ValueData: "{app}\Status.exe,1"
Root: HKCU; Subkey: "Software\Classes\status-im\shell\open\command"; ValueType: "string"; ValueData: """{app}\Status.exe"" "--url="%1"""