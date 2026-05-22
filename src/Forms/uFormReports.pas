unit uFormReports;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, ComCtrls, Grids,
  DateTimePicker;

type

  { TFormReports }

  TFormReports = class(TForm)
    PanelTop: TPanel;
    LabelKind: TLabel;
    ComboKind: TComboBox;
    LabelFrom: TLabel;
    DateFrom: TDateTimePicker;
    LabelTo: TLabel;
    DateTo: TDateTimePicker;
    ButtonRun: TButton;
    ButtonClose: TButton;
    StringGridReport: TStringGrid;
    MemoSummary: TMemo;
    LabelSessions: TLabel;
    ComboSession: TComboBox;
    procedure FormShow(Sender: TObject);
    procedure ComboKindChange(Sender: TObject);
    procedure ButtonRunClick(Sender: TObject);
    procedure ButtonCloseClick(Sender: TObject);
  private
    FSessionIds: array of Integer;
    procedure LoadSessions;
    procedure RunDailyClosing;
    procedure RunFeeProfit;
    procedure RunStaffActivity;
    procedure RunCashFlow;
    procedure ClearReport;
  end;

var
  FormReports: TFormReports;

implementation

{$R *.lfm}

uses
  uReportService, uSessionService, uModels;

procedure TFormReports.FormShow(Sender: TObject);
begin
  ComboKind.Items.Clear;
  ComboKind.Items.Add('Daily Closing');
  ComboKind.Items.Add('Service Fee Profit');
  ComboKind.Items.Add('Cash-In vs Cash-Out');
  ComboKind.Items.Add('Staff Activity');
  ComboKind.ItemIndex := 0;

  DateFrom.Date := Date - 30;
  DateTo.Date := Date;

  LoadSessions;
  ComboKindChange(nil);
  ClearReport;
end;

procedure TFormReports.LoadSessions;
var
  Sessions: TArray<TSessionRec>;
  I: Integer;
begin
  Sessions := TSessionService.ListSessions(100);
  ComboSession.Items.Clear;
  SetLength(FSessionIds, Length(Sessions));
  for I := 0 to High(Sessions) do
  begin
    ComboSession.Items.Add(
      Format('#%d  %s  [%s]', [Sessions[I].Id,
        FormatDateTime('yyyy-mm-dd', Sessions[I].SessionDate),
        Sessions[I].Status]));
    FSessionIds[I] := Sessions[I].Id;
  end;
  if Length(Sessions) > 0 then ComboSession.ItemIndex := 0;
end;

procedure TFormReports.ComboKindChange(Sender: TObject);
var
  IsDaily: Boolean;
begin
  IsDaily := ComboKind.ItemIndex = 0;
  LabelSessions.Visible := IsDaily;
  ComboSession.Visible := IsDaily;
  LabelFrom.Visible := not IsDaily;
  LabelTo.Visible := not IsDaily;
  DateFrom.Visible := not IsDaily;
  DateTo.Visible := not IsDaily;
end;

procedure TFormReports.ClearReport;
begin
  StringGridReport.ColCount := 1;
  StringGridReport.RowCount := 2;
  StringGridReport.Cells[0, 0] := '';
  StringGridReport.Cells[0, 1] := '';
  MemoSummary.Clear;
end;

procedure TFormReports.RunDailyClosing;
var
  Sid: Integer;
  R: TDailyClosingReport;
begin
  if (ComboSession.ItemIndex < 0) or (ComboSession.ItemIndex > High(FSessionIds)) then
  begin
    MessageDlg('Select a session.', mtWarning, [mbOk], 0); Exit;
  end;
  Sid := FSessionIds[ComboSession.ItemIndex];
  R := TReportService.DailyClosing(Sid);

  StringGridReport.ColCount := 2;
  StringGridReport.RowCount := 16;
  StringGridReport.Cells[0, 0] := 'Field'; StringGridReport.Cells[1, 0] := 'Value';
  StringGridReport.Cells[0, 1] := 'Session ID';        StringGridReport.Cells[1, 1] := IntToStr(R.SessionId);
  StringGridReport.Cells[0, 2] := 'Session date';      StringGridReport.Cells[1, 2] := FormatDateTime('yyyy-mm-dd', R.SessionDate);
  StringGridReport.Cells[0, 3] := 'Starting cash';     StringGridReport.Cells[1, 3] := FormatFloat('#,##0.00', R.StartingCash);
  StringGridReport.Cells[0, 4] := 'Starting wallet';   StringGridReport.Cells[1, 4] := FormatFloat('#,##0.00', R.StartingWallet);
  StringGridReport.Cells[0, 5] := 'Expected cash';     StringGridReport.Cells[1, 5] := FormatFloat('#,##0.00', R.ExpectedCash);
  StringGridReport.Cells[0, 6] := 'Expected wallet';   StringGridReport.Cells[1, 6] := FormatFloat('#,##0.00', R.ExpectedWallet);
  StringGridReport.Cells[0, 7] := 'Actual cash';       StringGridReport.Cells[1, 7] := FormatFloat('#,##0.00', R.ActualCash);
  StringGridReport.Cells[0, 8] := 'Actual wallet';     StringGridReport.Cells[1, 8] := FormatFloat('#,##0.00', R.ActualWallet);
  StringGridReport.Cells[0, 9] := 'Cash short/over';   StringGridReport.Cells[1, 9] := FormatFloat('+#,##0.00;-#,##0.00;0.00', R.CashShortOver);
  StringGridReport.Cells[0, 10] := 'Wallet short/over';StringGridReport.Cells[1, 10] := FormatFloat('+#,##0.00;-#,##0.00;0.00', R.WalletShortOver);
  StringGridReport.Cells[0, 11] := 'Txn count';        StringGridReport.Cells[1, 11] := IntToStr(R.TxnCount);
  StringGridReport.Cells[0, 12] := 'Fees earned';      StringGridReport.Cells[1, 12] := FormatFloat('#,##0.00', R.FeesEarned);
  StringGridReport.Cells[0, 13] := 'Cash-In total';    StringGridReport.Cells[1, 13] := FormatFloat('#,##0.00', R.TotalCashIn);
  StringGridReport.Cells[0, 14] := 'Cash-Out total';   StringGridReport.Cells[1, 14] := FormatFloat('#,##0.00', R.TotalCashOut);
  StringGridReport.Cells[0, 15] := 'E-Load total';     StringGridReport.Cells[1, 15] := FormatFloat('#,##0.00', R.TotalELoad);

  MemoSummary.Lines.Clear;
  MemoSummary.Lines.Add(Format('Daily closing for session #%d (%s)',
    [R.SessionId, FormatDateTime('yyyy-mm-dd', R.SessionDate)]));
  MemoSummary.Lines.Add(Format('Cash:   start %.2f + flow = expected %.2f vs actual %.2f -> %+.2f',
    [R.StartingCash, R.ExpectedCash, R.ActualCash, R.CashShortOver]));
  MemoSummary.Lines.Add(Format('Wallet: start %.2f + flow = expected %.2f vs actual %.2f -> %+.2f',
    [R.StartingWallet, R.ExpectedWallet, R.ActualWallet, R.WalletShortOver]));
  MemoSummary.Lines.Add(Format('Fees earned: %.2f from %d txn(s)', [R.FeesEarned, R.TxnCount]));
end;

procedure TFormReports.RunFeeProfit;
var
  Rows: TArray<TFeeProfitRow>;
  I: Integer;
  TotalFees: Double;
begin
  Rows := TReportService.FeeProfit(DateFrom.Date, DateTo.Date);
  StringGridReport.ColCount := 4;
  StringGridReport.RowCount := Length(Rows) + 1;
  StringGridReport.Cells[0, 0] := 'Type';
  StringGridReport.Cells[1, 0] := 'Count';
  StringGridReport.Cells[2, 0] := 'Gross';
  StringGridReport.Cells[3, 0] := 'Fees';
  TotalFees := 0;
  for I := 0 to High(Rows) do
  begin
    StringGridReport.Cells[0, I+1] := Rows[I].TxnType;
    StringGridReport.Cells[1, I+1] := IntToStr(Rows[I].TxnCount);
    StringGridReport.Cells[2, I+1] := FormatFloat('#,##0.00', Rows[I].GrossAmount);
    StringGridReport.Cells[3, I+1] := FormatFloat('#,##0.00', Rows[I].Fees);
    TotalFees := TotalFees + Rows[I].Fees;
  end;
  MemoSummary.Lines.Clear;
  MemoSummary.Lines.Add(Format('Period: %s to %s',
    [FormatDateTime('yyyy-mm-dd', DateFrom.Date),
     FormatDateTime('yyyy-mm-dd', DateTo.Date)]));
  MemoSummary.Lines.Add(Format('Total fee profit: %.2f', [TotalFees]));
end;

procedure TFormReports.RunStaffActivity;
var
  Rows: TArray<TStaffActivityRow>;
  I: Integer;
begin
  Rows := TReportService.StaffActivity(DateFrom.Date, DateTo.Date);
  StringGridReport.ColCount := 5;
  StringGridReport.RowCount := Length(Rows) + 1;
  StringGridReport.Cells[0, 0] := 'Username';
  StringGridReport.Cells[1, 0] := 'Name';
  StringGridReport.Cells[2, 0] := 'Txns';
  StringGridReport.Cells[3, 0] := 'Gross';
  StringGridReport.Cells[4, 0] := 'Fees';
  for I := 0 to High(Rows) do
  begin
    StringGridReport.Cells[0, I+1] := Rows[I].Username;
    StringGridReport.Cells[1, I+1] := Rows[I].FullName;
    StringGridReport.Cells[2, I+1] := IntToStr(Rows[I].TxnCount);
    StringGridReport.Cells[3, I+1] := FormatFloat('#,##0.00', Rows[I].GrossAmount);
    StringGridReport.Cells[4, I+1] := FormatFloat('#,##0.00', Rows[I].FeesEarned);
  end;
  MemoSummary.Lines.Clear;
  MemoSummary.Lines.Add(Format('Period: %s to %s',
    [FormatDateTime('yyyy-mm-dd', DateFrom.Date),
     FormatDateTime('yyyy-mm-dd', DateTo.Date)]));
end;

procedure TFormReports.RunCashFlow;
var
  Rows: TArray<TCashFlowRow>;
  I: Integer;
  TotIn, TotOut: Double;
begin
  Rows := TReportService.CashFlow(DateFrom.Date, DateTo.Date);
  StringGridReport.ColCount := 4;
  StringGridReport.RowCount := Length(Rows) + 1;
  StringGridReport.Cells[0, 0] := 'Date';
  StringGridReport.Cells[1, 0] := 'Cash-In';
  StringGridReport.Cells[2, 0] := 'Cash-Out';
  StringGridReport.Cells[3, 0] := 'Net (In - Out)';
  TotIn := 0; TotOut := 0;
  for I := 0 to High(Rows) do
  begin
    StringGridReport.Cells[0, I+1] := Rows[I].DateLabel;
    StringGridReport.Cells[1, I+1] := FormatFloat('#,##0.00', Rows[I].CashIn);
    StringGridReport.Cells[2, I+1] := FormatFloat('#,##0.00', Rows[I].CashOut);
    StringGridReport.Cells[3, I+1] := FormatFloat('+#,##0.00;-#,##0.00;0.00', Rows[I].Net);
    TotIn := TotIn + Rows[I].CashIn;
    TotOut := TotOut + Rows[I].CashOut;
  end;
  MemoSummary.Lines.Clear;
  MemoSummary.Lines.Add(Format('Period: %s to %s',
    [FormatDateTime('yyyy-mm-dd', DateFrom.Date),
     FormatDateTime('yyyy-mm-dd', DateTo.Date)]));
  MemoSummary.Lines.Add(Format('Total Cash-In:  %.2f', [TotIn]));
  MemoSummary.Lines.Add(Format('Total Cash-Out: %.2f', [TotOut]));
  MemoSummary.Lines.Add(Format('Net:            %+.2f', [TotIn - TotOut]));
end;

procedure TFormReports.ButtonRunClick(Sender: TObject);
begin
  ClearReport;
  case ComboKind.ItemIndex of
    0: RunDailyClosing;
    1: RunFeeProfit;
    2: RunCashFlow;
    3: RunStaffActivity;
  end;
end;

procedure TFormReports.ButtonCloseClick(Sender: TObject);
begin
  Close;
end;

end.
