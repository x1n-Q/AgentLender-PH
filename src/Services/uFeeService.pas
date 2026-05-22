unit uFeeService;

{$mode delphi}{$H+}

interface

uses
  SysUtils, uModels;

type
  TFeeService = class
  public
    class function ComputeFee(ATxnType: TTxnType; AAmount: Double): Double;
    class function ListRules: TArray<TFeeRule>;
    class function ListRulesForType(ATxnType: TTxnType): TArray<TFeeRule>;
    class function AddRule(const ARule: TFeeRule): Integer;
    class procedure UpdateRule(const ARule: TFeeRule);
    class procedure DeleteRule(AId: Integer);
    class procedure SetActive(AId: Integer; AActive: Boolean);
  end;

implementation

uses
  sqldb, uDM, uSession, uAuditService;

class function TFeeService.ComputeFee(ATxnType: TTxnType; AAmount: Double): Double;
var
  Q: TSQLQuery;
  RuleFee: Double;
  IsPct: Boolean;
begin
  Result := 0;
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'SELECT fee, is_percentage FROM fee_rules ' +
      'WHERE txn_type = :t AND is_active = 1 AND :a >= min_amount AND :a <= max_amount ' +
      'ORDER BY min_amount LIMIT 1';
    Q.ParamByName('t').AsString := TxnTypeToStr(ATxnType);
    Q.ParamByName('a').AsFloat := AAmount;
    Q.Open;
    if not Q.EOF then
    begin
      RuleFee := Q.FieldByName('fee').AsFloat;
      IsPct := Q.FieldByName('is_percentage').AsInteger = 1;
      if IsPct then
        Result := AAmount * RuleFee / 100.0
      else
        Result := RuleFee;
    end;
    Q.Close;
  finally
    Q.Free;
  end;
end;

class function TFeeService.ListRules: TArray<TFeeRule>;
var
  Q: TSQLQuery;
  L: TFeeRuleList;
  R: TFeeRule;
begin
  L := TFeeRuleList.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'SELECT id, txn_type, min_amount, max_amount, fee, is_percentage, is_active ' +
        'FROM fee_rules ORDER BY txn_type, min_amount';
      Q.Open;
      while not Q.EOF do
      begin
        R.Id := Q.FieldByName('id').AsInteger;
        R.TxnType := StrToTxnType(Q.FieldByName('txn_type').AsString);
        R.MinAmount := Q.FieldByName('min_amount').AsFloat;
        R.MaxAmount := Q.FieldByName('max_amount').AsFloat;
        R.Fee := Q.FieldByName('fee').AsFloat;
        R.IsPercentage := Q.FieldByName('is_percentage').AsInteger = 1;
        R.IsActive := Q.FieldByName('is_active').AsInteger = 1;
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

class function TFeeService.ListRulesForType(ATxnType: TTxnType): TArray<TFeeRule>;
var
  Q: TSQLQuery;
  L: TFeeRuleList;
  R: TFeeRule;
begin
  L := TFeeRuleList.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'SELECT id, txn_type, min_amount, max_amount, fee, is_percentage, is_active ' +
        'FROM fee_rules WHERE txn_type = :t ORDER BY min_amount';
      Q.ParamByName('t').AsString := TxnTypeToStr(ATxnType);
      Q.Open;
      while not Q.EOF do
      begin
        R.Id := Q.FieldByName('id').AsInteger;
        R.TxnType := StrToTxnType(Q.FieldByName('txn_type').AsString);
        R.MinAmount := Q.FieldByName('min_amount').AsFloat;
        R.MaxAmount := Q.FieldByName('max_amount').AsFloat;
        R.Fee := Q.FieldByName('fee').AsFloat;
        R.IsPercentage := Q.FieldByName('is_percentage').AsInteger = 1;
        R.IsActive := Q.FieldByName('is_active').AsInteger = 1;
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

class function TFeeService.AddRule(const ARule: TFeeRule): Integer;
var
  Q: TSQLQuery;
begin
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'INSERT INTO fee_rules(txn_type, min_amount, max_amount, fee, is_percentage, is_active) ' +
      'VALUES(:t, :mn, :mx, :f, :p, :a)';
    Q.ParamByName('t').AsString := TxnTypeToStr(ARule.TxnType);
    Q.ParamByName('mn').AsFloat := ARule.MinAmount;
    Q.ParamByName('mx').AsFloat := ARule.MaxAmount;
    Q.ParamByName('f').AsFloat := ARule.Fee;
    Q.ParamByName('p').AsInteger := Ord(ARule.IsPercentage);
    Q.ParamByName('a').AsInteger := Ord(ARule.IsActive);
    Q.ExecSQL;
    DM.Commit;
    Result := DM.LastInsertRowId;
  finally
    Q.Free;
  end;
  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'CREATE', 'fee_rule', Result,
      Format('%s [%.2f-%.2f] fee=%.2f pct=%s',
        [TxnTypeToStr(ARule.TxnType), ARule.MinAmount, ARule.MaxAmount,
         ARule.Fee, BoolToStr(ARule.IsPercentage, True)]));
end;

class procedure TFeeService.UpdateRule(const ARule: TFeeRule);
var
  Q: TSQLQuery;
begin
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'UPDATE fee_rules SET txn_type = :t, min_amount = :mn, max_amount = :mx, ' +
      'fee = :f, is_percentage = :p, is_active = :a WHERE id = :id';
    Q.ParamByName('t').AsString := TxnTypeToStr(ARule.TxnType);
    Q.ParamByName('mn').AsFloat := ARule.MinAmount;
    Q.ParamByName('mx').AsFloat := ARule.MaxAmount;
    Q.ParamByName('f').AsFloat := ARule.Fee;
    Q.ParamByName('p').AsInteger := Ord(ARule.IsPercentage);
    Q.ParamByName('a').AsInteger := Ord(ARule.IsActive);
    Q.ParamByName('id').AsInteger := ARule.Id;
    Q.ExecSQL;
    DM.Commit;
  finally
    Q.Free;
  end;
  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'UPDATE', 'fee_rule', ARule.Id, '');
end;

class procedure TFeeService.DeleteRule(AId: Integer);
var
  Q: TSQLQuery;
begin
  Q := DM.NewQuery;
  try
    Q.SQL.Text := 'DELETE FROM fee_rules WHERE id = :id';
    Q.ParamByName('id').AsInteger := AId;
    Q.ExecSQL;
    DM.Commit;
  finally
    Q.Free;
  end;
  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'DELETE', 'fee_rule', AId, '');
end;

class procedure TFeeService.SetActive(AId: Integer; AActive: Boolean);
var
  Q: TSQLQuery;
begin
  Q := DM.NewQuery;
  try
    Q.SQL.Text := 'UPDATE fee_rules SET is_active = :a WHERE id = :id';
    Q.ParamByName('a').AsInteger := Ord(AActive);
    Q.ParamByName('id').AsInteger := AId;
    Q.ExecSQL;
    DM.Commit;
  finally
    Q.Free;
  end;
end;

end.
