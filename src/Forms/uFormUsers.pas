unit uFormUsers;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, Grids,
  uModels;

type

  { TFormUsers }

  TFormUsers = class(TForm)
    PanelEditor: TPanel;
    LabelUsername: TLabel;
    EditUsername: TEdit;
    LabelFullName: TLabel;
    EditFullName: TEdit;
    LabelRole: TLabel;
    ComboRole: TComboBox;
    LabelPassword: TLabel;
    EditPassword: TEdit;
    CheckBoxActive: TCheckBox;
    ButtonAdd: TButton;
    ButtonChangePass: TButton;
    ButtonSetActive: TButton;
    ButtonClose: TButton;
    StringGridUsers: TStringGrid;
    LabelHeader: TLabel;
    procedure FormShow(Sender: TObject);
    procedure StringGridUsersClick(Sender: TObject);
    procedure ButtonAddClick(Sender: TObject);
    procedure ButtonChangePassClick(Sender: TObject);
    procedure ButtonSetActiveClick(Sender: TObject);
    procedure ButtonCloseClick(Sender: TObject);
  private
    FList: TArray<TUser>;
    FSelectedId: Integer;
    procedure LoadList;
  end;

var
  FormUsers: TFormUsers;

implementation

{$R *.lfm}

uses
  uSession, uAuthService;

procedure TFormUsers.FormShow(Sender: TObject);
begin
  if not AppState.CanManageUsers then
  begin
    MessageDlg('Only Owner can manage users.', mtError, [mbOk], 0);
    ButtonAdd.Enabled := False;
    ButtonChangePass.Enabled := False;
    ButtonSetActive.Enabled := False;
  end;
  ComboRole.Items.Clear;
  ComboRole.Items.Add('Owner');
  ComboRole.Items.Add('Staff');
  ComboRole.Items.Add('Viewer');
  ComboRole.ItemIndex := 1;
  CheckBoxActive.Checked := True;
  LoadList;
end;

procedure TFormUsers.LoadList;
var
  I: Integer;
begin
  FList := TAuthService.ListUsers;
  StringGridUsers.ColCount := 5;
  StringGridUsers.RowCount := Length(FList) + 1;
  StringGridUsers.Cells[0, 0] := 'ID';
  StringGridUsers.Cells[1, 0] := 'Username';
  StringGridUsers.Cells[2, 0] := 'Full name';
  StringGridUsers.Cells[3, 0] := 'Role';
  StringGridUsers.Cells[4, 0] := 'Active?';
  for I := 0 to High(FList) do
  begin
    StringGridUsers.Cells[0, I+1] := IntToStr(FList[I].Id);
    StringGridUsers.Cells[1, I+1] := FList[I].Username;
    StringGridUsers.Cells[2, I+1] := FList[I].FullName;
    StringGridUsers.Cells[3, I+1] := RoleToStr(FList[I].Role);
    StringGridUsers.Cells[4, I+1] := BoolToStr(FList[I].IsActive, True);
  end;
end;

procedure TFormUsers.StringGridUsersClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := StringGridUsers.Row - 1;
  if (Idx < 0) or (Idx > High(FList)) then Exit;
  FSelectedId := FList[Idx].Id;
  EditUsername.Text := FList[Idx].Username;
  EditFullName.Text := FList[Idx].FullName;
  ComboRole.ItemIndex := ComboRole.Items.IndexOf(RoleToStr(FList[Idx].Role));
  CheckBoxActive.Checked := FList[Idx].IsActive;
  EditPassword.Clear;
end;

procedure TFormUsers.ButtonAddClick(Sender: TObject);
begin
  if Trim(EditUsername.Text) = '' then
  begin
    MessageDlg('Username required.', mtWarning, [mbOk], 0); Exit;
  end;
  if Length(EditPassword.Text) < 4 then
  begin
    MessageDlg('Password must be at least 4 characters.', mtWarning, [mbOk], 0); Exit;
  end;
  try
    TAuthService.CreateUser(Trim(EditUsername.Text), EditPassword.Text,
      Trim(EditFullName.Text),
      StrToRole(ComboRole.Items[ComboRole.ItemIndex]));
    EditUsername.Clear;
    EditFullName.Clear;
    EditPassword.Clear;
    LoadList;
    MessageDlg('User created.', mtInformation, [mbOk], 0);
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOk], 0);
  end;
end;

procedure TFormUsers.ButtonChangePassClick(Sender: TObject);
begin
  if FSelectedId = 0 then
  begin
    MessageDlg('Select a user.', mtWarning, [mbOk], 0); Exit;
  end;
  if Length(EditPassword.Text) < 4 then
  begin
    MessageDlg('Password must be at least 4 characters.', mtWarning, [mbOk], 0); Exit;
  end;
  TAuthService.ChangePassword(FSelectedId, EditPassword.Text);
  EditPassword.Clear;
  MessageDlg('Password updated.', mtInformation, [mbOk], 0);
end;

procedure TFormUsers.ButtonSetActiveClick(Sender: TObject);
begin
  if FSelectedId = 0 then Exit;
  TAuthService.SetActive(FSelectedId, CheckBoxActive.Checked);
  LoadList;
end;

procedure TFormUsers.ButtonCloseClick(Sender: TObject);
begin
  Close;
end;

end.
