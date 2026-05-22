unit uAuthService;

{$mode delphi}{$H+}

interface

uses
  SysUtils, uModels;

type
  TAuthService = class
  public
    class function HashPassword(const APassword: string): string;
    class function Login(const AUsername, APassword: string;
      out AUser: TUser): Boolean;
    class function ChangePassword(AUserId: Integer;
      const ANewPassword: string): Boolean;
    class function CreateUser(const AUsername, APassword, AFullName: string;
      ARole: TUserRole): Integer;
    class function ListUsers: TArray<TUser>;
    class procedure SetActive(AUserId: Integer; AActive: Boolean);
    class procedure Logout;
  end;

implementation

uses
  sha1, sqldb, uDM, uSession, uAuditService;

const
  PASSWORD_SALT = 'AgentLedgerPH-Salt';

class function TAuthService.HashPassword(const APassword: string): string;
begin
  Result := LowerCase(SHA1Print(SHA1String(APassword + PASSWORD_SALT)));
end;

class function TAuthService.Login(const AUsername, APassword: string;
  out AUser: TUser): Boolean;
var
  Q: TSQLQuery;
  Hash: string;
begin
  Result := False;
  Hash := HashPassword(APassword);
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'SELECT id, username, full_name, role, is_active, created_at ' +
      'FROM users WHERE username = :u AND password_hash = :p AND is_active = 1';
    Q.ParamByName('u').AsString := AUsername;
    Q.ParamByName('p').AsString := Hash;
    Q.Open;
    if not Q.EOF then
    begin
      AUser.Id := Q.FieldByName('id').AsInteger;
      AUser.Username := Q.FieldByName('username').AsString;
      AUser.FullName := Q.FieldByName('full_name').AsString;
      AUser.Role := StrToRole(Q.FieldByName('role').AsString);
      AUser.IsActive := Q.FieldByName('is_active').AsInteger = 1;
      AUser.CreatedAt := DBToDateTime(Q.FieldByName('created_at'));
      AppState.SetUser(AUser);
      TAuditService.Log(AUser.Id, 'LOGIN', 'user', AUser.Id, AUsername);
      Result := True;
    end;
    Q.Close;
  finally
    Q.Free;
  end;
end;

class function TAuthService.ChangePassword(AUserId: Integer;
  const ANewPassword: string): Boolean;
var
  Q: TSQLQuery;
begin
  Result := False;
  Q := DM.NewQuery;
  try
    Q.SQL.Text := 'UPDATE users SET password_hash = :p WHERE id = :id';
    Q.ParamByName('p').AsString := HashPassword(ANewPassword);
    Q.ParamByName('id').AsInteger := AUserId;
    Q.ExecSQL;
    DM.Commit;
    Result := Q.RowsAffected > 0;
  finally
    Q.Free;
  end;
  if Result and AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'CHANGE_PASSWORD', 'user', AUserId, '');
end;

class function TAuthService.CreateUser(const AUsername, APassword, AFullName: string;
  ARole: TUserRole): Integer;
var
  Q: TSQLQuery;
begin
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'INSERT INTO users(username, password_hash, full_name, role, is_active) ' +
      'VALUES(:u, :p, :n, :r, 1)';
    Q.ParamByName('u').AsString := AUsername;
    Q.ParamByName('p').AsString := HashPassword(APassword);
    Q.ParamByName('n').AsString := AFullName;
    Q.ParamByName('r').AsString := RoleToStr(ARole);
    Q.ExecSQL;
    DM.Commit;
    Result := DM.LastInsertRowId;
  finally
    Q.Free;
  end;
  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'CREATE', 'user', Result,
      Format('username=%s role=%s', [AUsername, RoleToStr(ARole)]));
end;

class function TAuthService.ListUsers: TArray<TUser>;
var
  Q: TSQLQuery;
  L: TUserList;
  U: TUser;
begin
  L := TUserList.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text := 'SELECT id, username, full_name, role, is_active, created_at FROM users ORDER BY username';
      Q.Open;
      while not Q.EOF do
      begin
        U.Id := Q.FieldByName('id').AsInteger;
        U.Username := Q.FieldByName('username').AsString;
        U.FullName := Q.FieldByName('full_name').AsString;
        U.Role := StrToRole(Q.FieldByName('role').AsString);
        U.IsActive := Q.FieldByName('is_active').AsInteger = 1;
        U.CreatedAt := DBToDateTime(Q.FieldByName('created_at'));
        L.Add(U);
        Q.Next;
      end;
      Q.Close;
    finally
      Q.Free;
    end;
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

class procedure TAuthService.SetActive(AUserId: Integer; AActive: Boolean);
var
  Q: TSQLQuery;
begin
  Q := DM.NewQuery;
  try
    Q.SQL.Text := 'UPDATE users SET is_active = :a WHERE id = :id';
    Q.ParamByName('a').AsInteger := Ord(AActive);
    Q.ParamByName('id').AsInteger := AUserId;
    Q.ExecSQL;
    DM.Commit;
  finally
    Q.Free;
  end;
  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id,
      'SET_ACTIVE', 'user', AUserId, BoolToStr(AActive, True));
end;

class procedure TAuthService.Logout;
begin
  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'LOGOUT', 'user',
      AppState.CurrentUser.Id, '');
  AppState.ClearUser;
end;

end.
