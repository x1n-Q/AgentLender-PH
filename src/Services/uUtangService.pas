unit uUtangService;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Generics.Collections, uModels;

type
  TUtangSummary = record
    Utang: TUtang;
    CustomerName: string;
    TotalPaid: Double;
  end;

  TUtangService = class
  public
    class function CreateUtang(ACustomerId, ATransactionId: Integer;
      APrincipal: Double; const ANotes: string): Integer;
    class function PayPartial(AUtangId: Integer; AAmount: Double;
      AReceivedBy: Integer; const ANotes: string): Boolean;
    class function GetBalance(AUtangId: Integer): Double;
    class function ListOutstanding: TArray<TUtangSummary>;
    class function ListByCustomer(ACustomerId: Integer): TArray<TUtangSummary>;
    class function ListPayments(AUtangId: Integer): TArray<TUtangPayment>;
  end;

implementation

uses
  sqldb, uDM, uSession, uAuditService;

class function TUtangService.CreateUtang(ACustomerId, ATransactionId: Integer;
  APrincipal: Double; const ANotes: string): Integer;
var
  Q: TSQLQuery;
begin
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'INSERT INTO utang(customer_id, transaction_id, principal, balance, notes) ' +
      'VALUES(:c, :t, :p, :p2, :n)';
    Q.ParamByName('c').AsInteger := ACustomerId;
    if ATransactionId = 0 then
      Q.ParamByName('t').Clear
    else
      Q.ParamByName('t').AsInteger := ATransactionId;
    Q.ParamByName('p').AsFloat := APrincipal;
    Q.ParamByName('p2').AsFloat := APrincipal;
    Q.ParamByName('n').AsString := ANotes;
    Q.ExecSQL;
    DM.Commit;
    Result := DM.LastInsertRowId;
  finally
    Q.Free;
  end;
  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'CREATE', 'utang', Result,
      Format('principal=%.2f', [APrincipal]));
end;

class function TUtangService.PayPartial(AUtangId: Integer; AAmount: Double;
  AReceivedBy: Integer; const ANotes: string): Boolean;
var
  Q: TSQLQuery;
  CurrentBal: Double;
begin
  CurrentBal := GetBalance(AUtangId);
  if AAmount <= 0 then
    raise Exception.Create('Payment amount must be positive.');
  if AAmount > CurrentBal + 0.001 then
    raise Exception.CreateFmt('Payment %.2f exceeds outstanding balance %.2f.',
      [AAmount, CurrentBal]);

  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'INSERT INTO utang_payments(utang_id, amount, paid_at, received_by, notes) ' +
        'VALUES(:u, :a, :p, :r, :n)';
      Q.ParamByName('u').AsInteger := AUtangId;
      Q.ParamByName('a').AsFloat := AAmount;
      Q.ParamByName('p').AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
      Q.ParamByName('r').AsInteger := AReceivedBy;
      Q.ParamByName('n').AsString := ANotes;
      Q.ExecSQL;

      Q.SQL.Text := 'UPDATE utang SET balance = balance - :a WHERE id = :id';
      Q.ParamByName('a').AsFloat := AAmount;
      Q.ParamByName('id').AsInteger := AUtangId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
    DM.Commit;
    Result := True;
  except
    DM.SQLTransaction.Rollback;
    raise;
  end;

  TAuditService.Log(AReceivedBy, 'PAY', 'utang', AUtangId,
    Format('amount=%.2f', [AAmount]));
end;

class function TUtangService.GetBalance(AUtangId: Integer): Double;
begin
  Result := DM.ScalarFloat('SELECT balance FROM utang WHERE id = :id', [AUtangId]);
end;

class function TUtangService.ListOutstanding: TArray<TUtangSummary>;
var
  Q: TSQLQuery;
  L: TList<TUtangSummary>;
  S: TUtangSummary;
begin
  L := TList<TUtangSummary>.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'SELECT u.id, u.customer_id, u.transaction_id, u.principal, u.balance, ' +
        '       u.notes, u.created_at, c.name AS cname, ' +
        '       (u.principal - u.balance) AS total_paid ' +
        'FROM utang u JOIN customers c ON c.id = u.customer_id ' +
        'WHERE u.balance > 0 ORDER BY u.created_at DESC';
      Q.Open;
      while not Q.EOF do
      begin
        S.Utang.Id := Q.FieldByName('id').AsInteger;
        S.Utang.CustomerId := Q.FieldByName('customer_id').AsInteger;
        S.Utang.TransactionId := Q.FieldByName('transaction_id').AsInteger;
        S.Utang.Principal := Q.FieldByName('principal').AsFloat;
        S.Utang.Balance := Q.FieldByName('balance').AsFloat;
        S.Utang.Notes := Q.FieldByName('notes').AsString;
        S.Utang.CreatedAt := DBToDateTime(Q.FieldByName('created_at'));
        S.CustomerName := Q.FieldByName('cname').AsString;
        S.TotalPaid := Q.FieldByName('total_paid').AsFloat;
        L.Add(S);
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

class function TUtangService.ListByCustomer(ACustomerId: Integer): TArray<TUtangSummary>;
var
  Q: TSQLQuery;
  L: TList<TUtangSummary>;
  S: TUtangSummary;
begin
  L := TList<TUtangSummary>.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'SELECT u.id, u.customer_id, u.transaction_id, u.principal, u.balance, ' +
        '       u.notes, u.created_at, c.name AS cname, ' +
        '       (u.principal - u.balance) AS total_paid ' +
        'FROM utang u JOIN customers c ON c.id = u.customer_id ' +
        'WHERE u.customer_id = :c ORDER BY u.created_at DESC';
      Q.ParamByName('c').AsInteger := ACustomerId;
      Q.Open;
      while not Q.EOF do
      begin
        S.Utang.Id := Q.FieldByName('id').AsInteger;
        S.Utang.CustomerId := Q.FieldByName('customer_id').AsInteger;
        S.Utang.TransactionId := Q.FieldByName('transaction_id').AsInteger;
        S.Utang.Principal := Q.FieldByName('principal').AsFloat;
        S.Utang.Balance := Q.FieldByName('balance').AsFloat;
        S.Utang.Notes := Q.FieldByName('notes').AsString;
        S.Utang.CreatedAt := DBToDateTime(Q.FieldByName('created_at'));
        S.CustomerName := Q.FieldByName('cname').AsString;
        S.TotalPaid := Q.FieldByName('total_paid').AsFloat;
        L.Add(S);
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

class function TUtangService.ListPayments(AUtangId: Integer): TArray<TUtangPayment>;
var
  Q: TSQLQuery;
  L: TList<TUtangPayment>;
  P: TUtangPayment;
begin
  L := TList<TUtangPayment>.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'SELECT id, utang_id, amount, paid_at, received_by, notes ' +
        'FROM utang_payments WHERE utang_id = :u ORDER BY paid_at DESC';
      Q.ParamByName('u').AsInteger := AUtangId;
      Q.Open;
      while not Q.EOF do
      begin
        P.Id := Q.FieldByName('id').AsInteger;
        P.UtangId := Q.FieldByName('utang_id').AsInteger;
        P.Amount := Q.FieldByName('amount').AsFloat;
        P.PaidAt := DBToDateTime(Q.FieldByName('paid_at'));
        P.ReceivedBy := Q.FieldByName('received_by').AsInteger;
        P.Notes := Q.FieldByName('notes').AsString;
        L.Add(P);
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
