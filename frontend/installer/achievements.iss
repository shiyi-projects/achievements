; Inno Setup script for Achievements (Flutter Windows)
; Build prerequisite:  flutter build windows --release
; Compile:             ISCC.exe installer\achievements.iss
; Output:              installer\Output\AchievementsSetup-<ver>.exe

#define MyAppName            "Achievements"
#define MyAppExeName         "achievements.exe"
#define MyAppVersion         "0.1.0"
#define MyAppPublisher       "shiyi0x7f"
#define MyAppURL             "https://github.com/shiyi0x7f/achievements"
; 项目根 (相对 .iss 所在目录)
#define ProjectRoot          ".."
#define ReleaseDir           ProjectRoot + "\build\windows\x64\runner\Release"
#define IconFile             ProjectRoot + "\windows\runner\resources\app_icon.ico"

[Setup]
; AppId 一旦确定就不要改 — 改了等于新应用,老用户升级不了
AppId={{8F2D4E1A-9B3C-4D5E-A6F7-1A2B3C4D5E6F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
VersionInfoVersion={#MyAppVersion}.0

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
DisableDirPage=no
AllowNoIcons=yes

; 64-bit only
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; 安装到 Program Files 需要管理员;若想免管理员可改 lowest 并把 DefaultDirName 换成 {userpf}
PrivilegesRequired=admin

; 输出
OutputDir=Output
OutputBaseFilename=AchievementsSetup-{#MyAppVersion}
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

; 压缩
Compression=lzma2/ultra64
SolidCompression=yes

; 体验
WizardStyle=modern
ShowLanguageDialog=auto
CloseApplications=force
RestartApplications=no

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english";          MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon";  Description: "{cm:CreateDesktopIcon}";                              GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon";  Description: "开机自启动 {#MyAppName} (后台运行,最小化到托盘)";    GroupDescription: "启动选项:"; Flags: unchecked

[Files]
; 主程序 + 所有运行时依赖 (含 data 子目录)
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}";              Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";        Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
; 开机自启 (HKCU Run 替代方案 — 简单可靠,优于 Startup 文件夹)
Name: "{userstartup}\{#MyAppName}";        Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
; 安装完成后可选立即运行
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; 卸载前先把可能驻留托盘的进程干掉,避免 .exe / .dll 占用导致删不干净
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM {#MyAppExeName}"; Flags: runhidden; RunOnceId: "KillAchievements"

[Code]
// 阻止重复运行安装程序时把正在跑的应用文件锁住
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM {#MyAppExeName}',
       '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := True;
end;
