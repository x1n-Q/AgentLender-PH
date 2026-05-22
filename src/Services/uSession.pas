unit uSession;

{$mode delphi}{$H+}

interface

uses
  SysUtils, uModels;

type
  TAppState = class
  private
    FCurrentUser: TUser;
    FCurrentSessionId: Integer;
    FHasUser: Boolean;
  public
    procedure SetUser(const AUser: TUser);
    procedure ClearUser;
    function CurrentUser: TUser;
    function HasUser: Boolean;
    function CanManageUsers: Boolean;
    function CanEditFees: Boolean;
    function CanReconcile: Boolean;
    function CanEditTransactions: Boolean;
    function CanCreateTransactions: Boolean;
    function IsReadOnly: Boolean;
    property CurrentSessionId: Integer read FCurrentSessionId write FCurrentSessionId;
  end;

function AppState: TAppState;

implementation

var
  GAppState: TAppState;

function AppState: TAppState;
begin
  if GAppState = nil then
    GAppState := TAppState.Create;
  Result := GAppState;
end;

procedure TAppState.SetUser(const AUser: TUser);
begin
  FCurrentUser := AUser;
  FHasUser := True;
end;

procedure TAppState.ClearUser;
begin
  FHasUser := False;
  FCurrentSessionId := 0;
end;

function TAppState.CurrentUser: TUser;
begin
  Result := FCurrentUser;
end;

function TAppState.HasUser: Boolean;
begin
  Result := FHasUser;
end;

function TAppState.CanManageUsers: Boolean;
begin
  Result := FHasUser and (FCurrentUser.Role = urOwner);
end;

function TAppState.CanEditFees: Boolean;
begin
  Result := FHasUser and (FCurrentUser.Role = urOwner);
end;

function TAppState.CanReconcile: Boolean;
begin
  Result := FHasUser and (FCurrentUser.Role in [urOwner, urStaff]);
end;

function TAppState.CanEditTransactions: Boolean;
begin
  Result := FHasUser and (FCurrentUser.Role = urOwner);
end;

function TAppState.CanCreateTransactions: Boolean;
begin
  Result := FHasUser and (FCurrentUser.Role in [urOwner, urStaff]);
end;

function TAppState.IsReadOnly: Boolean;
begin
  Result := (not FHasUser) or (FCurrentUser.Role = urViewer);
end;

initialization

finalization
  FreeAndNil(GAppState);

end.
