; Inno Setup script for dlGrep.  Modeled on the PrettyReMark installer.
; Build it with "make installer" (which builds the Release exe first and passes the version
; from CHANGELOG.md), or compile it by hand:
;   D:\InnoSetup7\iscc.exe /DMyAppVersion=1.00 installer\dlGrep.iss
; Output: installer\output\dlGrepV<version>.setup.exe

#define MyAppName "dlGrep"
#define MyAppPublisher "Derell Licht"
#define MyAppURL "https://github.com/DerellLicht/dlGrep"
#define MyAppExeName "dlGrep.exe"
#define DoubleAmp(Value) StringChange(Value, "&", "&&")
; the folder that holds the repo (this script lives in <RepoRoot>\installer)
#define RepoRoot AddBackslash(SourcePath) + ".."
#ifndef BuildDir
#define BuildDir RepoRoot + "\dnGREP.WPF\bin\x64\Release\net10.0-windows"
#endif
; The version is set only in CHANGELOG.md; the Makefile passes it in as /DMyAppVersion=x.yy.
#ifndef MyAppVersion
#error MyAppVersion is not defined: build with "make installer", or pass /DMyAppVersion=x.yy (the newest version in CHANGELOG.md)
#endif

[Setup]
; NOTE: AppId uniquely identifies this program; never reuse it for another one.
AppId={{C29497A1-43B2-4F67-884E-B91380313D26}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
; Per-user install: {autopf} becomes %LocalAppData%\Programs, so there is no UAC prompt.
; dlGrep keeps its settings next to the exe when it can write there, which a per-user
; folder always allows.
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#MyAppName}
DisableDirPage=no
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
; 64-bit only
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile={#RepoRoot}\license.txt
OutputDir=output
OutputBaseFilename={#MyAppName}V{#MyAppVersion}.setup
SolidCompression=yes
WizardStyle=modern slate
; close a running dlGrep before replacing its files, and restart nothing
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The build already gathers everything dlGrep needs into this folder: the exe and its
; libraries, 7z64.dll, and the Plugins folder (OpenXml, PDF with xpdf, Word).
; Debug symbols and the shell-extension leftovers are not needed.
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
  Excludes: "*.pdb,dnGREP.ContextMenu.dll,dnGREP.msix,nGrep.ico"; \
  Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#RepoRoot}\license.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RepoRoot}\README.md"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#DoubleAmp(MyAppName)}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  // The .NET installer records every installed Desktop Runtime here, one value per version
  // (for example "10.0.1"), in the 64-bit registry view.
  DesktopRuntimeKey = 'SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.WindowsDesktop.App';

// True if the registry view RootKey holds a .NET Desktop Runtime whose major version is at least
// MinMajor.  Reads the version names under DesktopRuntimeKey and compares the number before the
// first dot, so "10.0.1" and "10.0.0-rc.2" both count as 10.
function DesktopRuntimeInView(RootKey: Integer; MinMajor: Integer): Boolean;
var
  Names: TArrayOfString;
  I, DotPos, Major: Integer;
begin
  Result := False;
  if not RegGetValueNames(RootKey, DesktopRuntimeKey, Names) then begin
    Exit;
  end;
  for I := 0 to GetArrayLength(Names) - 1 do begin
    DotPos := Pos('.', Names[I]);
    if DotPos > 1 then begin
      Major := StrToIntDef(Copy(Names[I], 1, DotPos - 1), 0);
      if Major >= MinMajor then begin
        Result := True;
        Exit;
      end;
    end;
  end;
end;

// True if a .NET Desktop Runtime of at least major version MinMajor is installed.  The .NET
// installer records its versions in the 32-bit registry view (same quirk as the WebView2 check in
// the PrettyReMark installer), while this installer runs in 64-bit mode, so look in both views.
function DesktopRuntimeInstalled(MinMajor: Integer): Boolean;
begin
  Result := DesktopRuntimeInView(HKLM32, MinMajor) or DesktopRuntimeInView(HKLM64, MinMajor);
end;

// Warns before installing if the .NET 10 Desktop Runtime is missing, because dlGrep will not
// start without it.  An interactive user may go ahead anyway (to install the runtime afterwards);
// a silent install just proceeds.
function InitializeSetup: Boolean;
begin
  Result := True;
  if not DesktopRuntimeInstalled(10) then begin
    if not WizardSilent then begin
      Result := MsgBox('dlGrep needs the .NET 10 Desktop Runtime, which does not appear to be ' +
                       'installed on this computer.' + #13#10#13#10 +
                       'You can install dlGrep now and add the runtime afterwards, or cancel ' +
                       'and install the runtime first.' + #13#10#13#10 +
                       'Continue with the installation?',
                       mbConfirmation, MB_YESNO) = IDYES;
    end;
  end;
end;
