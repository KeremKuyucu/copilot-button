; =====================================================================
;  Inno Setup 6 Script - Copilot Button Controller
; =====================================================================

#ifndef MyAppVersion
#define MyAppVersion "1.1.0"
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

[Tasks]
Name: "startupicon"; Description: "{cm:AutoStartProgram,Copilot Button}"; GroupDescription: "{cm:AdditionalIcons}"

[CustomMessages]
turkish.AutoStartProgram=Windows ile birlikte otomatik başlat
english.AutoStartProgram=Start automatically with Windows
turkish.AdditionalIcons=Ek Seçenekler:
english.AdditionalIcons=Additional Options:

[Files]
Source: "{#SourceExePath}"; DestDir: "{app}"; Flags: ignoreversion
Source: "logo.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "logo_muted.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "config.ini"; DestDir: "{app}"; Flags: onlyifdoesntexist

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\logo.ico"
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\logo.ico"; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall

[UninstallDelete]
Type: files; Name: "{app}\config.ini"
Type: dirifempty; Name: "{app}"
