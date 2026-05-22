unit uSessionService;

{$mode delphi}{$H+}

interface

uses
  SysUtils, uModels;

type
  TSessionService = class
  public
    class function GetOpenSession(out ASession: TSessionRec): Boolean;
    class function OpenSession(AUserId: Integer; AStartingCash, AStartingWallet: Double;
      const ANotes: string): Integer;
    class procedure CloseSession(ASessionId, AUserId: Integer;
      AActualCash, AActualWallet: Double; const ANotes: string);
    class function GetSession(ASessionId: Integer; out ASession: TSessionRec): Boolean;
    class function ListSessions(ALimit: Integer = 100): TArray<TSessionRec>;
    class procedure ExpectedTotals(ASessionId: Integer;
      out AExpectedCash, AExpectedWallet, AFeesEarned: Double);
  end;

implementation

uses
  sqldb, uDM, uAuditService;

class function TSessionService.GetOpenSession(out ASession: TSessionRec): Boolean;
var
  Q: TSQLQuery;
begin
  Result := False;
  FillChar(ASession, SizeOf(ASession), 0);
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'SELECT id, session_date, opened_by, opened_at, closed_by, closed_at, ' +
      '       starting_cash, starting_wallet, actual_cash, actual_wallet, status, notes ' +
      'FROM sessions WHERE status = ''Open'' ORDER BY id DESC LIMIT 1';
    Q.Open;
    if not Q.EOF then
    begin
      ASession.Id := Q.FieldByName('id').AsInteger;
      ASession.SessionDate := DBToDateTime(Q.FieldByName('session_date'));
      ASession.OpenedBy := Q.FieldByName('opened_by').AsInteger;
      ASession.OpenedAt := DBToDateTime(Q.FieldByName('opened_at'));
      ASession.ClosedBy := Q.FieldByName('closed_by').AsInteger;
      if not Q.FieldByName('closed_at').IsNull then
        ASession.ClosedAt := DBToDateTime(Q.FieldByName('closed_at'));
      ASession.StartingCash := Q.FieldByName('starting_cash').AsFloat;
      ASession.StartingWallet := Q.FieldByName('starting_wallet').AsFloat;
      ASession.ActualCash := Q.FieldByName('actual_cash').AsFloat;
      ASession.ActualWallet := Q.FieldByName('actual_wallet').AsFloat;
      ASession.Status := Q.FieldByName('status').AsString;
      ASession.Notes := Q.FieldByName('notes').AsString;
      Result := True;
    end;
    Q.Close;
  finally
    Q.Free;
  end;
end;

class function TSessionService.OpenSession(AUserId: Integer;
  AStartingCash, AStartingWallet: Double; const ANotes: string): Integer;
var
  Q: TSQLQuery;
  Existing: TSessionRec;
begin
  if GetOpenSession(Existing) then
    raise Exception.Create('There is already an open session. Close it before opening a new one.');

  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'INSERT INTO sessions(session_date, opened_by, opened_at, starting_cash, ' +
      ' starting_wallet, status, notes) ' +
      'VALUES(:d, :ub, :oa, :sc, :sw, ''Open'', :n)';
    Q.ParamByName('d').AsString := FormatDateTime('yyyy-mm-dd', Now);
    Q.ParamByName('ub').AsInteger := AUserId;
    Q.ParamByName('oa').AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    Q.ParamByName('sc').AsFloat := AStartingCash;
    Q.ParamByName('sw').AsFloat := AStartingWallet;
    Q.ParamByName('n').AsString := ANotes;
    Q.ExecSQL;
    DM.Commit;
    Result := DM.LastInsertRowId;
  finally
    Q.Free;
  end;
  TAuditService.Log(AUserId, 'OPEN_SESSION', 'session', Result,
    Format('cash=%.2f wallet=%.2f', [AStartingCash, AStartingWallet]));
end;

class procedure TSessionService.CloseSession(ASessionId, AUserId: Integer;
  AActualCash, AActualWallet: Double; const ANotes: string);
var
  Q: TSQLQuery;
begin
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'UPDATE sessions SET closed_by = :cb, closed_at = :ca, ' +
      ' actual_cash = :ac, actual_wallet = :aw, status = ''Closed'', ' +
      ' notes = COALESCE(notes,'''') || CASE WHEN :n != '''' THEN '' | ''||:n ELSE '''' END ' +
      'WHERE id = :id AND status = ''Open''';
    Q.ParamByName('cb').AsInteger := AUserId;
    Q.ParamByName('ca').AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    Q.ParamByName('ac').AsFloat := AActualCash;
    Q.ParamByName('aw').AsFloat := AActualWallet;
    Q.ParamByName('n').AsString := ANotes;
    Q.ParamByName('id').AsInteger := ASessionId;
    Q.ExecSQL;
    DM.Commit;
    if Q.RowsAffected = 0 then
      raise Exception.Create('Session not found or already closed.');
  finally
    Q.Free;
  end;
  TAuditService.Log(AUserId, 'CLOSE_SESSION', 'session', ASessionId,
    Format('actual_cash=%.2f actual_wallet=%.2f', [AActualCash, AActualWallet]));
end;

class function TSessionService.GetSession(ASessionId: Integer;
  out ASession: TSessionRec): Boolean;
var
  Q: TSQLQuery;
begin
  Result := False;
  FillChar(ASession, SizeOf(ASession), 0);
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'SELECT id, session_date, opened_by, opened_at, closed_by, closed_at, ' +
      '       starting_cash, starting_wallet, actual_cash, actual_wallet, status, notes ' +
      'FROM sessions WHERE id = :id';
    Q.ParamByName('id').AsInteger := ASessionId;
    Q.Open;
    if not Q.EOF then
    begin
      ASession.Id := Q.FieldByName('id').AsInteger;
      ASession.SessionDate := DBToDateTime(Q.FieldByName('session_date'));
      ASession.OpenedBy := Q.FieldByName('opened_by').AsInteger;
      ASession.OpenedAt := DBToDateTime(Q.FieldByName('opened_at'));
      ASession.ClosedBy := Q.FieldByName('closed_by').AsInteger;
      if not Q.FieldByName('closed_at').IsNull then
        ASession.ClosedAt := DBToDateTime(Q.FieldByName('closed_at'));
      ASession.StartingCash := Q.FieldByName('starting_cash').AsFloat;
      ASession.StartingWallet := Q.FieldByName('starting_wallet').AsFloat;
      ASession.ActualCash := Q.FieldByName('actual_cash').AsFloat;
      ASession.ActualWallet := Q.FieldByName('actual_wallet').AsFloat;
      ASession.Status := Q.FieldByName('status').AsString;
      ASession.Notes := Q.FieldByName('notes').AsString;
      Result := True;
    end;
    Q.Close;
  finally
    Q.Free;
  end;
end;

class function TSessionService.ListSessions(ALimit: Integer): TArray<TSessionRec>;
var
  Q: TSQLQuery;
  L: TSessionList;
  S: TSessionRec;
begin
  L := TSessionList.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'SELECT id, session_date, opened_by, opened_at, closed_by, closed_at, ' +
        '       starting_cash, starting_wallet, actual_cash, actual_wallet, status, notes ' +
        'FROM sessions ORDER BY id DESC LIMIT :lim';
      Q.ParamByName('lim').AsInteger := ALimit;
      Q.Open;
      while not Q.EOF do
      begin
        S.Id := Q.FieldByName('id').AsInteger;
        S.SessionDate := DBToDateTime(Q.FieldByName('session_date'));
        S.OpenedBy := Q.FieldByName('opened_by').AsInteger;
        S.OpenedAt := DBToDateTime(Q.FieldByName('opened_at'));
        S.ClosedBy := Q.FieldByName('closed_by').AsInteger;
        if not Q.FieldByName('closed_at').IsNull then
          S.ClosedAt := DBToDateTime(Q.FieldByName('closed_at'))
        else
          S.ClosedAt := 0;
        S.StartingCash := Q.FieldByName('starting_cash').AsFloat;
        S.StartingWallet := Q.FieldByName('starting_wallet').AsFloat;
        S.ActualCash := Q.FieldByName('actual_cash').AsFloat;
        S.ActualWallet := Q.FieldByName('actual_wallet').AsFloat;
        S.Status := Q.FieldByName('status').AsString;
        S.Notes := Q.FieldByName('notes').AsString;
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

class procedure TSessionService.ExpectedTotals(ASessionId: Integer;
  out AExpectedCash, AExpectedWallet, AFeesEarned: Double);
var
  Sess: TSessionRec;
  CashSum, WalletSum, FeeSum: Double;
begin
  AExpectedCash := 0;
  AExpectedWallet := 0;
  AFeesEarned := 0;
  if not GetSession(ASessionId, Sess) then Exit;

  CashSum := DM.ScalarFloat(
    'SELECT COALESCE(SUM(cash_impact),0) FROM transactions WHERE session_id = :s AND is_void = 0',
    [ASessionId]);
  WalletSum := DM.ScalarFloat(
    'SELECT COALESCE(SUM(wallet_impact),0) FROM transactions WHERE session_id = :s AND is_void = 0',
    [ASessionId]);
  FeeSum := DM.ScalarFloat(
    'SELECT COALESCE(SUM(fee),0) FROM transactions WHERE session_id = :s AND is_void = 0',
    [ASessionId]);

  AExpectedCash := Sess.StartingCash + CashSum;
  AExpectedWallet := Sess.StartingWallet + WalletSum;
  AFeesEarned := FeeSum;
end;

end.
