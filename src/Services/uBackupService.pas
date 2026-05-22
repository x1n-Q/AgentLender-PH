unit uBackupService;

{$mode delphi}{$H+}

interface

uses
  SysUtils, FileUtil, LazFileUtils;

type
  TBackupService = class
  public
    class function Backup(const ADestinationFile: string): Boolean;
    class function Restore(const ASourceFile: string): Boolean;
    class function DefaultBackupFolder: string;
    class function MakeTimestampedFilename: string;
  end;

implementation

uses
  uDM, uSession, uAuditService;

class function TBackupService.DefaultBackupFolder: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'backups';
  if not DirectoryExists(Result) then
    ForceDirectories(Result);
end;

class function TBackupService.MakeTimestampedFilename: string;
begin
  Result := IncludeTrailingPathDelimiter(DefaultBackupFolder) +
    'agentledger_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.db';
end;

class function TBackupService.Backup(const ADestinationFile: string): Boolean;
var
  Src: string;
  WasConnected: Boolean;
begin
  Src := DM.DatabaseFile;
  if not FileExists(Src) then
    raise Exception.Create('Database file not found: ' + Src);

  WasConnected := DM.SQLConnection.Connected;
  try
    DM.SQLConnection.ExecuteDirect('PRAGMA wal_checkpoint(FULL);');
    DM.Commit;
  except
    // ignore if not in WAL mode
  end;

  DM.SQLConnection.Close;
  try
    Result := CopyFile(Src, ADestinationFile, [cffOverwriteFile, cffPreserveTime]);
  finally
    if WasConnected then
    begin
      DM.SQLConnection.Open;
      if not DM.SQLTransaction.Active then
        DM.SQLTransaction.StartTransaction;
    end;
  end;

  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'BACKUP', 'database', 0, ADestinationFile);
end;

class function TBackupService.Restore(const ASourceFile: string): Boolean;
var
  Dest: string;
begin
  if not FileExists(ASourceFile) then
    raise Exception.Create('Source backup not found: ' + ASourceFile);

  Dest := DM.DatabaseFile;
  DM.SQLConnection.Close;
  try
    if FileExists(Dest) then
      CopyFile(Dest, Dest + '.preRestore', [cffOverwriteFile]);
    Result := CopyFile(ASourceFile, Dest, [cffOverwriteFile]);
  finally
    DM.InitializeDatabase;
  end;

  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'RESTORE', 'database', 0, ASourceFile);
end;

end.
