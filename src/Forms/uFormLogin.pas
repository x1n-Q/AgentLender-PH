unit uFormLogin;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, Graphics;

type

  { TFormLogin }

  TFormLogin = class(TForm)
    PanelMain: TPanel;
    LabelTitle: TLabel;
    LabelSubtitle: TLabel;
    LabelUsername: TLabel;
    EditUsername: TEdit;
    LabelPassword: TLabel;
    EditPassword: TEdit;
    ButtonLogin: TButton;
    ButtonExit: TButton;
    LabelHint: TLabel;
    procedure ButtonLoginClick(Sender: TObject);
    procedure ButtonExitClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure EditPasswordKeyPress(Sender: TObject; var Key: Char);
  end;

var
  FormLogin: TFormLogin;

implementation

{$R *.lfm}

uses
  uModels, uAuthService;

procedure TFormLogin.FormShow(Sender: TObject);
begin
  EditUsername.SetFocus;
end;

procedure TFormLogin.ButtonLoginClick(Sender: TObject);
var
  U: TUser;
begin
  if Trim(EditUsername.Text) = '' then
  begin
    MessageDlg('Enter username.', mtWarning, [mbOk], 0);
    EditUsername.SetFocus;
    Exit;
  end;
  if TAuthService.Login(Trim(EditUsername.Text), EditPassword.Text, U) then
  begin
    ModalResult := mrOk;
  end
  else
  begin
    MessageDlg('Invalid credentials, or account disabled.', mtError, [mbOk], 0);
    EditPassword.Clear;
    EditPassword.SetFocus;
  end;
end;

procedure TFormLogin.ButtonExitClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFormLogin.EditPasswordKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    ButtonLoginClick(Sender);
  end;
end;

end.
