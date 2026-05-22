unit uReportService;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Generics.Collections, uModels;

type
  TDailyClosingReport = record
    SessionId: Integer;
    SessionDate: TDate;
    StartingCash: Double;
    StartingWallet: Double;
    ExpectedCash: Double;
    ExpectedWallet: Double;
    ActualCash: Double;
    ActualWallet: Double;
    CashShortOver: Double;
    WalletShortOver: Double;
    TxnCount: Integer;
    FeesEarned: Double;
    TotalCashIn: Double;
    TotalCashOut: Double;
    TotalELoad: Double;
    TotalBills: Double;
    TotalSendMoney: Double;
    TotalUtangPayments: Double;
  end;

  TFeeProfitRow = record
    TxnType: string;
    TxnCount: Integer;
    GrossAmount: Double;
    Fees: Double;
  end;

  TStaffActivityRow = record
    UserId: Integer;
    Username: string;
    FullName: string;
    TxnCount: Integer;
    GrossAmount: Double;
    FeesEarned: Double;
  end;

  TCashFlowRow = record
    DateLabel: string;
    CashIn: Double;
    CashOut: Double;
    Net: Double;
  end;

  TReportService = class
  public
    class function DailyClosing(ASessionId: Integer): TDailyClosingReport;
    class function FeeProfit(ADateFrom, ADateTo: TDate): TArray<TFeeProfitRow>;
    class function StaffActivity(ADateFrom, ADateTo: TDate): TArray<TStaffActivityRow>;
    class function CashFlow(ADateFrom, ADateTo: TDate): TArray<TCashFlowRow>;
  end;

implementation

uses
  sqldb, uDM, uSessionService;

class function TReportService.DailyClosing(ASessionId: Integer): TDailyClosingReport;
var
  Sess: TSessionRec;
  Q: TSQLQuery;
  ExpCash, ExpWallet, Fees: Double;
begin
  FillChar(Result, SizeOf(Result), 0);
  if not TSessionService.GetSession(ASessionId, Sess) then Exit;

  Result.SessionId := Sess.Id;
  Result.SessionDate := Sess.SessionDate;
  Result.StartingCash := Sess.StartingCash;
  Result.StartingWallet := Sess.StartingWallet;
  Result.ActualCash := Sess.ActualCash;
  Result.ActualWallet := Sess.ActualWallet;

  TSessionService.ExpectedTotals(ASessionId, ExpCash, ExpWallet, Fees);
  Result.ExpectedCash := ExpCash;
  Result.ExpectedWallet := ExpWallet;
  Result.FeesEarned := Fees;
  Result.CashShortOver := Sess.ActualCash - ExpCash;
  Result.WalletShortOver := Sess.ActualWallet - ExpWallet;

  Result.TxnCount := DM.ScalarInt(
    'SELECT COUNT(*) FROM transactions WHERE session_id = :s AND is_void = 0',
    [ASessionId]);

  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'SELECT txn_type, COALESCE(SUM(amount),0) AS gross ' +
      'FROM transactions WHERE session_id = :s AND is_void = 0 GROUP BY txn_type';
    Q.ParamByName('s').AsInteger := ASessionId;
    Q.Open;
    while not Q.EOF do
    begin
      case StrToTxnType(Q.FieldByName('txn_type').AsString) of
        ttCashIn:       Result.TotalCashIn := Q.FieldByName('gross').AsFloat;
        ttCashOut:      Result.TotalCashOut := Q.FieldByName('gross').AsFloat;
        ttELoad:        Result.TotalELoad := Q.FieldByName('gross').AsFloat;
        ttBillsPayment: Result.TotalBills := Q.FieldByName('gross').AsFloat;
        ttSendMoney:    Result.TotalSendMoney := Q.FieldByName('gross').AsFloat;
        ttUtangPayment: Result.TotalUtangPayments := Q.FieldByName('gross').AsFloat;
      end;
      Q.Next;
    end;
    Q.Close;
  finally
    Q.Free;
  end;
end;

class function TReportService.FeeProfit(ADateFrom, ADateTo: TDate): TArray<TFeeProfitRow>;
var
  Q: TSQLQuery;
  L: TList<TFeeProfitRow>;
  R: TFeeProfitRow;
begin
  L := TList<TFeeProfitRow>.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'SELECT txn_type, COUNT(*) AS cnt, COALESCE(SUM(amount),0) AS gross, ' +
        '       COALESCE(SUM(fee),0) AS fees ' +
        'FROM transactions ' +
        'WHERE is_void = 0 AND date(txn_datetime) BETWEEN :df AND :dt ' +
        'GROUP BY txn_type ORDER BY fees DESC';
      Q.ParamByName('df').AsString := FormatDateTime('yyyy-mm-dd', ADateFrom);
      Q.ParamByName('dt').AsString := FormatDateTime('yyyy-mm-dd', ADateTo);
      Q.Open;
      while not Q.EOF do
      begin
        R.TxnType := Q.FieldByName('txn_type').AsString;
        R.TxnCount := Q.FieldByName('cnt').AsInteger;
        R.GrossAmount := Q.FieldByName('gross').AsFloat;
        R.Fees := Q.FieldByName('fees').AsFloat;
        L.Add(R);
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

class function TReportService.StaffActivity(ADateFrom, ADateTo: TDate): TArray<TStaffActivityRow>;
var
  Q: TSQLQuery;
  L: TList<TStaffActivityRow>;
  R: TStaffActivityRow;
begin
  L := TList<TStaffActivityRow>.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'SELECT u.id, u.username, u.full_name, ' +
        '       COUNT(t.id) AS cnt, ' +
        '       COALESCE(SUM(t.amount),0) AS gross, ' +
        '       COALESCE(SUM(t.fee),0) AS fees ' +
        'FROM users u ' +
        'LEFT JOIN transactions t ON t.created_by = u.id ' +
        '  AND t.is_void = 0 AND date(t.txn_datetime) BETWEEN :df AND :dt ' +
        'GROUP BY u.id, u.username, u.full_name ' +
        'ORDER BY cnt DESC';
      Q.ParamByName('df').AsString := FormatDateTime('yyyy-mm-dd', ADateFrom);
      Q.ParamByName('dt').AsString := FormatDateTime('yyyy-mm-dd', ADateTo);
      Q.Open;
      while not Q.EOF do
      begin
        R.UserId := Q.FieldByName('id').AsInteger;
        R.Username := Q.FieldByName('username').AsString;
        R.FullName := Q.FieldByName('full_name').AsString;
        R.TxnCount := Q.FieldByName('cnt').AsInteger;
        R.GrossAmount := Q.FieldByName('gross').AsFloat;
        R.FeesEarned := Q.FieldByName('fees').AsFloat;
        L.Add(R);
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

class function TReportService.CashFlow(ADateFrom, ADateTo: TDate): TArray<TCashFlowRow>;
var
  Q: TSQLQuery;
  L: TList<TCashFlowRow>;
  R: TCashFlowRow;
begin
  L := TList<TCashFlowRow>.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'SELECT date(txn_datetime) AS d, ' +
        '       COALESCE(SUM(CASE WHEN txn_type=''Cash-In'' THEN amount ELSE 0 END),0) AS cin, ' +
        '       COALESCE(SUM(CASE WHEN txn_type=''Cash-Out'' THEN amount ELSE 0 END),0) AS cout ' +
        'FROM transactions ' +
        'WHERE is_void = 0 AND date(txn_datetime) BETWEEN :df AND :dt ' +
        'GROUP BY date(txn_datetime) ORDER BY d';
      Q.ParamByName('df').AsString := FormatDateTime('yyyy-mm-dd', ADateFrom);
      Q.ParamByName('dt').AsString := FormatDateTime('yyyy-mm-dd', ADateTo);
      Q.Open;
      while not Q.EOF do
      begin
        R.DateLabel := Q.FieldByName('d').AsString;
        R.CashIn := Q.FieldByName('cin').AsFloat;
        R.CashOut := Q.FieldByName('cout').AsFloat;
        R.Net := R.CashIn - R.CashOut;
        L.Add(R);
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

end.
