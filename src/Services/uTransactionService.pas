unit uTransactionService;

{$mode delphi}{$H+}

interface

uses
  SysUtils, uModels;

type
  TCashWalletImpact = record
    Cash: Double;
    Wallet: Double;
  end;

  TTransactionService = class
  public
    class function ComputeImpact(ATxnType: TTxnType; AAmount, AFee: Double): TCashWalletImpact;
    class function RecordTxn(const ATxn: TTransaction): Integer;
    class procedure Update(const ATxn: TTransaction);
    class procedure VoidTxn(AId, AUserId: Integer; const AReason: string);
    class function GetById(AId: Integer; out ATxn: TTransaction): Boolean;
    class function ListBySession(ASessionId: Integer): TArray<TTransaction>;
    class function ListByDate(ADateFrom, ADateTo: TDate): TArray<TTransaction>;
  end;

implementation

uses
  sqldb, uDM, uSession, uAuditService;

class function TTransactionService.ComputeImpact(ATxnType: TTxnType;
  AAmount, AFee: Double): TCashWalletImpact;
begin
  Result.Cash := 0;
  Result.Wallet := 0;
  case ATxnType of
    ttCashIn:
      begin
        Result.Cash := AAmount + AFee;
        Result.Wallet := -AAmount;
      end;
    ttCashOut:
      begin
        Result.Cash := -AAmount;
        Result.Wallet := AAmount + AFee;
      end;
    ttELoad:
      begin
        Result.Cash := AAmount + AFee;
        Result.Wallet := -AAmount;
      end;
    ttBillsPayment:
      begin
        Result.Cash := AAmount + AFee;
        Result.Wallet := -AAmount;
      end;
    ttSendMoney:
      begin
        Result.Cash := AAmount + AFee;
        Result.Wallet := -AAmount;
      end;
    ttUtangPayment:
      begin
        Result.Cash := AAmount;
        Result.Wallet := 0;
      end;
    ttManualAdjustment:
      begin
        // Amount field = signed cash impact, Fee field = signed wallet impact
        Result.Cash := AAmount;
        Result.Wallet := AFee;
      end;
  end;
end;

class function TTransactionService.RecordTxn(const ATxn: TTransaction): Integer;
var
  Q: TSQLQuery;
  Impact: TCashWalletImpact;
begin
  Impact := ComputeImpact(ATxn.TxnType, ATxn.Amount, ATxn.Fee);

  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'INSERT INTO transactions(session_id, txn_datetime, txn_type, customer_id, ' +
      ' amount, fee, cash_impact, wallet_impact, reference_no, notes, created_by) ' +
      'VALUES(:s, :dt, :t, :c, :a, :f, :ci, :wi, :r, :n, :cb)';
    Q.ParamByName('s').AsInteger := ATxn.SessionId;
    Q.ParamByName('dt').AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    Q.ParamByName('t').AsString := TxnTypeToStr(ATxn.TxnType);
    if ATxn.CustomerId = 0 then
      Q.ParamByName('c').Clear
    else
      Q.ParamByName('c').AsInteger := ATxn.CustomerId;
    Q.ParamByName('a').AsFloat := ATxn.Amount;
    Q.ParamByName('f').AsFloat := ATxn.Fee;
    Q.ParamByName('ci').AsFloat := Impact.Cash;
    Q.ParamByName('wi').AsFloat := Impact.Wallet;
    Q.ParamByName('r').AsString := ATxn.ReferenceNo;
    Q.ParamByName('n').AsString := ATxn.Notes;
    Q.ParamByName('cb').AsInteger := ATxn.CreatedBy;
    Q.ExecSQL;
    DM.Commit;
    Result := DM.LastInsertRowId;
  finally
    Q.Free;
  end;

  TAuditService.Log(ATxn.CreatedBy, 'CREATE', 'transaction', Result,
    Format('%s amount=%.2f fee=%.2f',
      [TxnTypeToStr(ATxn.TxnType), ATxn.Amount, ATxn.Fee]));
end;

class procedure TTransactionService.Update(const ATxn: TTransaction);
var
  Q: TSQLQuery;
  Impact: TCashWalletImpact;
begin
  Impact := ComputeImpact(ATxn.TxnType, ATxn.Amount, ATxn.Fee);
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'UPDATE transactions SET txn_type = :t, customer_id = :c, amount = :a, ' +
      ' fee = :f, cash_impact = :ci, wallet_impact = :wi, reference_no = :r, notes = :n ' +
      'WHERE id = :id AND is_void = 0';
    Q.ParamByName('t').AsString := TxnTypeToStr(ATxn.TxnType);
    if ATxn.CustomerId = 0 then
      Q.ParamByName('c').Clear
    else
      Q.ParamByName('c').AsInteger := ATxn.CustomerId;
    Q.ParamByName('a').AsFloat := ATxn.Amount;
    Q.ParamByName('f').AsFloat := ATxn.Fee;
    Q.ParamByName('ci').AsFloat := Impact.Cash;
    Q.ParamByName('wi').AsFloat := Impact.Wallet;
    Q.ParamByName('r').AsString := ATxn.ReferenceNo;
    Q.ParamByName('n').AsString := ATxn.Notes;
    Q.ParamByName('id').AsInteger := ATxn.Id;
    Q.ExecSQL;
    DM.Commit;
  finally
    Q.Free;
  end;
  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'UPDATE', 'transaction', ATxn.Id,
      Format('amount=%.2f fee=%.2f', [ATxn.Amount, ATxn.Fee]));
end;

class procedure TTransactionService.VoidTxn(AId, AUserId: Integer; const AReason: string);
var
  Q: TSQLQuery;
begin
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'UPDATE transactions SET is_void = 1, ' +
      ' notes = COALESCE(notes,'''') || '' [VOID: ''||:reason||'']'' ' +
      'WHERE id = :id';
    Q.ParamByName('reason').AsString := AReason;
    Q.ParamByName('id').AsInteger := AId;
    Q.ExecSQL;
    DM.Commit;
  finally
    Q.Free;
  end;
  TAuditService.Log(AUserId, 'VOID', 'transaction', AId, AReason);
end;

class function TTransactionService.GetById(AId: Integer; out ATxn: TTransaction): Boolean;
var
  Q: TSQLQuery;
begin
  Result := False;
  FillChar(ATxn, SizeOf(ATxn), 0);
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'SELECT id, session_id, txn_datetime, txn_type, customer_id, amount, fee, ' +
      ' cash_impact, wallet_impact, reference_no, notes, created_by, is_void ' +
      'FROM transactions WHERE id = :id';
    Q.ParamByName('id').AsInteger := AId;
    Q.Open;
    if not Q.EOF then
    begin
      ATxn.Id := Q.FieldByName('id').AsInteger;
      ATxn.SessionId := Q.FieldByName('session_id').AsInteger;
      ATxn.TxnDateTime := DBToDateTime(Q.FieldByName('txn_datetime'));
      ATxn.TxnType := StrToTxnType(Q.FieldByName('txn_type').AsString);
      ATxn.CustomerId := Q.FieldByName('customer_id').AsInteger;
      ATxn.Amount := Q.FieldByName('amount').AsFloat;
      ATxn.Fee := Q.FieldByName('fee').AsFloat;
      ATxn.CashImpact := Q.FieldByName('cash_impact').AsFloat;
      ATxn.WalletImpact := Q.FieldByName('wallet_impact').AsFloat;
      ATxn.ReferenceNo := Q.FieldByName('reference_no').AsString;
      ATxn.Notes := Q.FieldByName('notes').AsString;
      ATxn.CreatedBy := Q.FieldByName('created_by').AsInteger;
      ATxn.IsVoid := Q.FieldByName('is_void').AsInteger = 1;
      Result := True;
    end;
    Q.Close;
  finally
    Q.Free;
  end;
end;

class function TTransactionService.ListBySession(ASessionId: Integer): TArray<TTransaction>;
var
  Q: TSQLQuery;
  L: TTransactionList;
  T: TTransaction;
begin
  L := TTransactionList.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'SELECT id, session_id, txn_datetime, txn_type, customer_id, amount, fee, ' +
        ' cash_impact, wallet_impact, reference_no, notes, created_by, is_void ' +
        'FROM transactions WHERE session_id = :s ORDER BY id DESC';
      Q.ParamByName('s').AsInteger := ASessionId;
      Q.Open;
      while not Q.EOF do
      begin
        T.Id := Q.FieldByName('id').AsInteger;
        T.SessionId := Q.FieldByName('session_id').AsInteger;
        T.TxnDateTime := DBToDateTime(Q.FieldByName('txn_datetime'));
        T.TxnType := StrToTxnType(Q.FieldByName('txn_type').AsString);
        T.CustomerId := Q.FieldByName('customer_id').AsInteger;
        T.Amount := Q.FieldByName('amount').AsFloat;
        T.Fee := Q.FieldByName('fee').AsFloat;
        T.CashImpact := Q.FieldByName('cash_impact').AsFloat;
        T.WalletImpact := Q.FieldByName('wallet_impact').AsFloat;
        T.ReferenceNo := Q.FieldByName('reference_no').AsString;
        T.Notes := Q.FieldByName('notes').AsString;
        T.CreatedBy := Q.FieldByName('created_by').AsInteger;
        T.IsVoid := Q.FieldByName('is_void').AsInteger = 1;
        L.Add(T);
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

class function TTransactionService.ListByDate(ADateFrom, ADateTo: TDate): TArray<TTransaction>;
var
  Q: TSQLQuery;
  L: TTransactionList;
  T: TTransaction;
begin
  L := TTransactionList.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'SELECT id, session_id, txn_datetime, txn_type, customer_id, amount, fee, ' +
        ' cash_impact, wallet_impact, reference_no, notes, created_by, is_void ' +
        'FROM transactions WHERE date(txn_datetime) BETWEEN :df AND :dt ' +
        'ORDER BY id DESC';
      Q.ParamByName('df').AsString := FormatDateTime('yyyy-mm-dd', ADateFrom);
      Q.ParamByName('dt').AsString := FormatDateTime('yyyy-mm-dd', ADateTo);
      Q.Open;
      while not Q.EOF do
      begin
        T.Id := Q.FieldByName('id').AsInteger;
        T.SessionId := Q.FieldByName('session_id').AsInteger;
        T.TxnDateTime := DBToDateTime(Q.FieldByName('txn_datetime'));
        T.TxnType := StrToTxnType(Q.FieldByName('txn_type').AsString);
        T.CustomerId := Q.FieldByName('customer_id').AsInteger;
        T.Amount := Q.FieldByName('amount').AsFloat;
        T.Fee := Q.FieldByName('fee').AsFloat;
        T.CashImpact := Q.FieldByName('cash_impact').AsFloat;
        T.WalletImpact := Q.FieldByName('wallet_impact').AsFloat;
        T.ReferenceNo := Q.FieldByName('reference_no').AsString;
        T.Notes := Q.FieldByName('notes').AsString;
        T.CreatedBy := Q.FieldByName('created_by').AsInteger;
        T.IsVoid := Q.FieldByName('is_void').AsInteger = 1;
        L.Add(T);
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
