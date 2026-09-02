; =====================================================================
;  Inno Setup 6 Script - Copilot Button Controller
; =====================================================================

#ifndef MyAppVersion
#define FileHandle
#define FileLine
#define TempLine
#define MyAppVersion ""
#if FileHandle = FileOpen(AddBackslash(SourcePath) + "lib\Globals.ahk")
#for {FileLine = ""; !FileEof(FileHandle); FileLine = FileRead(FileHandle)}
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
#define SourceExePath "C:\Users\Kerem\Projects\Outputs\CopilotButton.exe"
#endif

#ifndef OutputDirPath
#define OutputDirPath "C:\Users\Kerem\Projects\Outputs"
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

SetupIconFile=logo.ico
UninstallDisplayIcon={app}\logo.ico

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
Source: "logo.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "logo_muted.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "config.ini"; DestDir: "{app}"; Flags: onlyifdoesntexist

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "CopilotButton"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue

[InstallDelete]
; Eski sürümlerin oluşturduğu Startup kısayollarını temizle
Type: files; Name: "{userstartup}\CopilotButton.lnk"
Type: files; Name: "{userstartup}\Copilot Button.lnk"

; Eski Başlat Menüsü kısayollarını temizle
Type: files; Name: "{autoprograms}\CopilotButton.lnk"
Type: files; Name: "{autoprograms}\Copilot Button.lnk"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall

[UninstallDelete]
Type: files; Name: "{app}\config.ini"
Type: dirifempty; Name: "{app}"

; Startup kısayolları
Type: files; Name: "{userstartup}\CopilotButton.lnk"
Type: files; Name: "{userstartup}\Copilot Button.lnk"

; Başlat Menüsü kısayolları
Type: files; Name: "{autoprograms}\CopilotButton.lnk"
Type: files; Name: "{autoprograms}\Copilot Button.lnk"
