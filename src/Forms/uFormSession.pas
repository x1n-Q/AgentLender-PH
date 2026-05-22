unit uFormSession;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, Grids;

type

  { TFormSession }

  TFormSession = class(TForm)
    PanelOpen: TPanel;
    GroupBoxOpen: TGroupBox;
    LabelStartingCash: TLabel;
    EditStartingCash: TEdit;
    LabelStartingWallet: TLabel;
    EditStartingWallet: TEdit;
    LabelNotes: TLabel;
    EditNotes: TEdit;
    ButtonOpen: TButton;
    ButtonClose: TButton;
    LabelCurrent: TLabel;
    LabelCurrentInfo: TLabel;
    LabelHistory: TLabel;
    StringGridHistory: TStringGrid;
    procedure FormShow(Sender: TObject);
    procedure ButtonOpenClick(Sender: TObject);
    procedure ButtonCloseClick(Sender: TObject);
  private
    procedure RefreshList;
  end;

var
  FormSession: TFormSession;

implementation

{$R *.lfm}

uses
  uSession, uModels, uSessionService;

function TryStrToFloatLocal(const S: string; out V: Double): Boolean;
var
  Tmp: string;
begin
  Tmp := StringReplace(S, ',', '', [rfReplaceAll]);
  Result := TryStrToFloat(Tmp, V);
end;

procedure TFormSession.FormShow(Sender: TObject);
begin
  RefreshList;
end;

procedure TFormSession.RefreshList;
var
  Sess: TSessionRec;
  HasOpen: Boolean;
  Sessions: TArray<TSessionRec>;
  I: Integer;
begin
  HasOpen := TSessionService.GetOpenSession(Sess);
  ButtonOpen.Enabled := (not HasOpen) and AppState.CanCreateTransactions;
  EditStartingCash.Enabled := ButtonOpen.Enabled;
  EditStartingWallet.Enabled := ButtonOpen.Enabled;
  EditNotes.Enabled := ButtonOpen.Enabled;

  if HasOpen then
    LabelCurrentInfo.Caption :=
      Format('Open session #%d - %s, opened %s. Starting cash: %s, starting wallet: %s.',
        [Sess.Id, FormatDateTime('yyyy-mm-dd', Sess.SessionDate),
         FormatDateTime('hh:nn', Sess.OpenedAt),
         FormatFloat('#,##0.00', Sess.StartingCash),
         FormatFloat('#,##0.00', Sess.StartingWallet)])
  else
    LabelCurrentInfo.Caption := 'No session is currently open.';

  Sessions := TSessionService.ListSessions(50);
  StringGridHistory.ColCount := 8;
  StringGridHistory.RowCount := Length(Sessions) + 1;
  StringGridHistory.Cells[0, 0] := 'ID';
  StringGridHistory.Cells[1, 0] := 'Date';
  StringGridHistory.Cells[2, 0] := 'Start Cash';
  StringGridHistory.Cells[3, 0] := 'Start Wallet';
  StringGridHistory.Cells[4, 0] := 'Actual Cash';
  StringGridHistory.Cells[5, 0] := 'Actual Wallet';
  StringGridHistory.Cells[6, 0] := 'Status';
  StringGridHistory.Cells[7, 0] := 'Notes';
  for I := 0 to High(Sessions) do
  begin
    StringGridHistory.Cells[0, I+1] := IntToStr(Sessions[I].Id);
    StringGridHistory.Cells[1, I+1] := FormatDateTime('yyyy-mm-dd', Sessions[I].SessionDate);
    StringGridHistory.Cells[2, I+1] := FormatFloat('#,##0.00', Sessions[I].StartingCash);
    StringGridHistory.Cells[3, I+1] := FormatFloat('#,##0.00', Sessions[I].StartingWallet);
    if Sessions[I].Status = 'Closed' then
    begin
      StringGridHistory.Cells[4, I+1] := FormatFloat('#,##0.00', Sessions[I].ActualCash);
      StringGridHistory.Cells[5, I+1] := FormatFloat('#,##0.00', Sessions[I].ActualWallet);
    end
    else
    begin
      StringGridHistory.Cells[4, I+1] := '-';
      StringGridHistory.Cells[5, I+1] := '-';
    end;
    StringGridHistory.Cells[6, I+1] := Sessions[I].Status;
    StringGridHistory.Cells[7, I+1] := Sessions[I].Notes;
  end;
end;

procedure TFormSession.ButtonOpenClick(Sender: TObject);
var
  SC, SW: Double;
begin
  if not TryStrToFloatLocal(EditStartingCash.Text, SC) then
  begin
    MessageDlg('Invalid starting cash amount.', mtWarning, [mbOk], 0);
    EditStartingCash.SetFocus;
    Exit;
  end;
  if not TryStrToFloatLocal(EditStartingWallet.Text, SW) then
  begin
    MessageDlg('Invalid starting wallet amount.', mtWarning, [mbOk], 0);
    EditStartingWallet.SetFocus;
    Exit;
  end;
  try
    TSessionService.OpenSession(AppState.CurrentUser.Id, SC, SW, EditNotes.Text);
    MessageDlg('Session opened.', mtInformation, [mbOk], 0);
    EditStartingCash.Clear;
    EditStartingWallet.Clear;
    EditNotes.Clear;
    RefreshList;
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOk], 0);
  end;
end;

procedure TFormSession.ButtonCloseClick(Sender: TObject);
begin
  Close;
end;

end.
