; Inno Setup script for OpenMontage Studio (Windows installer).
; Compiled in CI by ISCC; pass the version with /DMyAppVersion=1.2.3.
; SourceDir is the repo root (this script lives in windows/).

#define MyAppName "OpenMontage Studio"
#define MyAppPublisher "OpenMontage"
#define MyAppURL "https://get.opencli.ai"
#define MyAppExeName "openmontage_studio.exe"
#ifndef MyAppVersion
  #define MyAppVersion "1.1.1"
#endif

[Setup]
; A stable AppId keeps upgrades in place across versions.
AppId={{7C9F2E84-3B5A-4C1D-9E6F-2A8B1D4F6C30}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\OpenMontage Studio
DefaultGroupName=OpenMontage Studio
DisableProgramGroupPage=yes
SourceDir=..
OutputDir=dist
OutputBaseFilename=OpenMontageStudio-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\OpenMontage Studio"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\OpenMontage Studio"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch OpenMontage Studio"; Flags: nowait postinstall skipifsilent
