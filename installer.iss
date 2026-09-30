; =====================================================================
;  Inno Setup 6 Script - Copilot Button Controller
; =====================================================================

#ifndef MyAppVersion
#define FileHandle
#define FileLine
#define TempLine
#define MyAppVersion ""
#if FileHandle = FileOpen(AddBackslash(SourcePath) + "lib\Globals.ahk")
#for {FileLine = ""; !FileEof(FileHandle); FileLine = FileRead(FileHandle)} \
Pos("APP_VERSION :=", FileLine) ? (TempLine = Copy(FileLine, Pos('"', FileLine) + 1), MyAppVersion = Copy(TempLine, 1, Pos('"', TempLine) - 1)) : 0
#expr FileClose(FileHandle)
#endif
#endif

#define MyAppName "Copilot Button"
#define MyAppPublisher "Kerem Kuyucu"
#define MyAppURL "https://github.com/KeremKuyucu/copilot-button"
#define MyAppExeName "CopilotButton.exe"
#define MyAppId "{{B729352A-3A65-4EE3-8E57-1F4F9CE993E1}}"

#ifndef SourceExePath
#define SourceExePath "C:\Users\Kerem\Projects\Outputs\copilot-button\CopilotButton.exe"
#endif

#ifndef OutputDirPath
#define OutputDirPath "C:\Users\Kerem\Projects\Outputs\copilot-button"
#endif

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases

DefaultDirName={localappdata}\CopilotButton

DisableDirPage=no
DisableProgramGroupPage=yes

PrivilegesRequired=lowest

OutputDir={#OutputDirPath}
OutputBaseFilename=CopilotButton-Setup

SetupIconFile=assets\logo.ico
UninstallDisplayIcon={app}\assets\logo.ico

Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

CloseApplications=yes
CloseApplicationsFilter=CopilotButton.exe
RestartApplications=no

ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourceExePath}"; DestDir: "{app}"; Flags: ignoreversion
Source: "assets\logo.ico"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "assets\logo_muted.ico"; DestDir: "{app}\assets"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\assets\logo.ico"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "CopilotButton"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
Filename: "{app}\{#MyAppExeName}"; Flags: nowait; Check: WizardSilent

[UninstallDelete]
Type: files; Name: "{app}\config.ini"
Type: files; Name: "{app}\assets\*.ico"
Type: dirifempty; Name: "{app}\assets"
Type: dirifempty; Name: "{app}"
