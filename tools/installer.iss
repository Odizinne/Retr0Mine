#define AppName "Retr0Mine"
#define AppVersion "1.0.0"
#define AppPublisher "Odizinne"
#define AppURL "https://github.com/Odizinne/Retr0Mine"
#define AppExeName "Retr0Mine.exe"
#define AppIcon "Resources\icons\icon.ico"

[Setup]
AppId={{8A9C6942-5CA3-4A02-B701-E7B4E862D635}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
OutputBaseFilename=Retr0Mine_installer
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UsedUserAreasWarning=no
DisableProgramGroupPage=yes
DisableWelcomePage=yes
SetupIconFile={#AppIcon}
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\Retr0Mine\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#AppExeName}"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent