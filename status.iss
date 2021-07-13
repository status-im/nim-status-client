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

WizardStyle=modern

; Defalut install path
DefaultDirName={commonpf}\{#Name}

DefaultGroupName={#Name}

; output dir for installer
OutputDir={#OUTPUTDIR}
OutputBaseFileName={#BaseName}

; Icon file
SetupIconFile=resources\status.ico

; Compression
Compression=lzma
SolidCompression=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "it"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "nl"; MessagesFile: "compiler:Languages\Dutch.isl"
Name: "pt_BR"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
Name: "ua"; MessagesFile: "compiler:Languages\Ukrainian.isl"

[Files]

; Path to exe on 
Source: "Status.exe"; DestDir: "{app}"; Flags: ignoreversion

; Resources
Source: "bin\*"; DestDir: "{app}\bin"; Flags: ignoreversion recursesubdirs createallsubdirs

Source: "resources\*"; DestDir: "{app}\resources"; Flags: ignoreversion recursesubdirs createallsubdirs

Source: "vendor\*"; DestDir: "{app}\vendor"; Flags: ignoreversion recursesubdirs createallsubdirs


[Registry]
Root: HKCU; Subkey: "Software\Classes\status-im"; ValueType: "string"; ValueData: "URL:status-im protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\status-im"; ValueType: "string"; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\status-im\DefaultIcon"; ValueType: "string"; ValueData: "{app}\Status.exe,1"
Root: HKCU; Subkey: "Software\Classes\status-im\shell\open\command"; ValueType: "string"; ValueData: """{app}\Status.exe"" ""--url=""%1"""