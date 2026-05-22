unit uFormReconciliation;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Dialogs, StdCtrls, ExtCtrls;

type

  { TFormReconciliation }

  TFormReconciliation = class(TForm)
    GroupBoxExpected: TGroupBox;
    LabelExpCash: TLabel;
    LabelExpWallet: TLabel;
    LabelFees: TLabel;
    LabelTxns: TLabel;
    LabelExpCashV: TLabel;
    LabelExpWalletV: TLabel;
    LabelFeesV: TLabel;
    LabelTxnsV: TLabel;
    GroupBoxActual: TGroupBox;
    LabelActualCash: TLabel;
    EditActualCash: TEdit;
    LabelActualWallet: TLabel;
    EditActualWallet: TEdit;
    LabelNotes: TLabel;
    EditNotes: TEdit;
    LabelShortOverCash: TLabel;
    LabelShortOverWallet: TLabel;
    LabelShortOverCashV: TLabel;
    LabelShortOverWalletV: TLabel;
    ButtonCompute: TButton;
    ButtonCloseSession: TButton;
    ButtonCancel: TButton;
    LabelHeader: TLabel;
    LabelSessionInfo: TLabel;
    procedure FormShow(Sender: TObject);
    procedure ButtonComputeClick(Sender: TObject);
    procedure ButtonCloseSessionClick(Sender: TObject);
    procedure ButtonCancelClick(Sender: TObject);
  private
    FSessionId: Integer;
    FExpCash, FExpWallet: Double;
  public
    procedure PrepareForSession(ASessionId: Integer);
  end;

var
  FormReconciliation: TFormReconciliation;

implementation

{$R *.lfm}

uses
  uDM, uSession, uModels, uSessionService;

procedure TFormReconciliation.PrepareForSession(ASessionId: Integer);
begin
  FSessionId := ASessionId;
end;

procedure TFormReconciliation.FormShow(Sender: TObject);
var
  Sess: TSessionRec;
  Fees: Double;
  TxnCount: Integer;
begin
  if not TSessionService.GetSession(FSessionId, Sess) then
  begin
    MessageDlg('Session not found.', mtError, [mbOk], 0);
    Close;
    Exit;
  end;
  LabelSessionInfo.Caption :=
    Format('Session #%d - %s, opened by user #%d',
      [Sess.Id, FormatDateTime('yyyy-mm-dd', Sess.SessionDate), Sess.OpenedBy]);

  TSessionService.ExpectedTotals(FSessionId, FExpCash, FExpWallet, Fees);

  LabelExpCashV.Caption := FormatFloat('#,##0.00', FExpCash);
  LabelExpWalletV.Caption := FormatFloat('#,##0.00', FExpWallet);
  LabelFeesV.Caption := FormatFloat('#,##0.00', Fees);

  TxnCount := DM.ScalarInt(
    'SELECT COUNT(*) FROM transactions WHERE session_id = :s AND is_void = 0',
    [FSessionId]);
  LabelTxnsV.Caption := IntToStr(TxnCount);

  EditActualCash.Text := FormatFloat('0.00', FExpCash);
  EditActualWallet.Text := FormatFloat('0.00', FExpWallet);
  LabelShortOverCashV.Caption := '-';
  LabelShortOverWalletV.Caption := '-';
end;

procedure TFormReconciliation.ButtonComputeClick(Sender: TObject);
var
  AC, AW: Double;
  S: string;
begin
  S := StringReplace(EditActualCash.Text, ',', '', [rfReplaceAll]);
  if not TryStrToFloat(S, AC) then AC := 0;
  S := StringReplace(EditActualWallet.Text, ',', '', [rfReplaceAll]);
  if not TryStrToFloat(S, AW) then AW := 0;
  LabelShortOverCashV.Caption := FormatFloat('+#,##0.00;-#,##0.00;0.00', AC - FExpCash);
  LabelShortOverWalletV.Caption := FormatFloat('+#,##0.00;-#,##0.00;0.00', AW - FExpWallet);
end;

procedure TFormReconciliation.ButtonCloseSessionClick(Sender: TObject);
var
  AC, AW: Double;
begin
  if not AppState.CanReconcile then
  begin
    MessageDlg('Viewer cannot close the session.', mtError, [mbOk], 0);
    Exit;
  end;
  if not TryStrToFloat(StringReplace(EditActualCash.Text, ',', '', [rfReplaceAll]), AC) then
  begin
    MessageDlg('Invalid actual cash amount.', mtWarning, [mbOk], 0); Exit;
  end;
  if not TryStrToFloat(StringReplace(EditActualWallet.Text, ',', '', [rfReplaceAll]), AW) then
  begin
    MessageDlg('Invalid actual wallet amount.', mtWarning, [mbOk], 0); Exit;
  end;
  if MessageDlg(Format('Close session #%d?', [FSessionId]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  try
    TSessionService.CloseSession(FSessionId, AppState.CurrentUser.Id,
      AC, AW, EditNotes.Text);
    MessageDlg('Session closed.', mtInformation, [mbOk], 0);
    ModalResult := mrOk;
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOk], 0);
  end;
end;

procedure TFormReconciliation.ButtonCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
