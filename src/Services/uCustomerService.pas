unit uCustomerService;

{$mode delphi}{$H+}

interface

uses
  SysUtils, uModels;

type
  TCustomerService = class
  public
    class function ListAll: TArray<TCustomer>;
    class function Search(const AQuery: string): TArray<TCustomer>;
    class function GetById(AId: Integer; out ACustomer: TCustomer): Boolean;
    class function Add(const ACustomer: TCustomer): Integer;
    class procedure Update(const ACustomer: TCustomer);
    class procedure Delete(AId: Integer);
  end;

implementation

uses
  sqldb, uDM, uSession, uAuditService;

class function TCustomerService.ListAll: TArray<TCustomer>;
var
  Q: TSQLQuery;
  L: TCustomerList;
  C: TCustomer;
begin
  L := TCustomerList.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text := 'SELECT id, name, mobile, notes, created_at FROM customers ORDER BY name';
      Q.Open;
      while not Q.EOF do
      begin
        C.Id := Q.FieldByName('id').AsInteger;
        C.Name := Q.FieldByName('name').AsString;
        C.Mobile := Q.FieldByName('mobile').AsString;
        C.Notes := Q.FieldByName('notes').AsString;
        C.CreatedAt := DBToDateTime(Q.FieldByName('created_at'));
        L.Add(C);
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

class function TCustomerService.Search(const AQuery: string): TArray<TCustomer>;
var
  Q: TSQLQuery;
  L: TCustomerList;
  C: TCustomer;
begin
  L := TCustomerList.Create;
  try
    Q := DM.NewQuery;
    try
      Q.SQL.Text :=
        'SELECT id, name, mobile, notes, created_at FROM customers ' +
        'WHERE name LIKE :q OR mobile LIKE :q ORDER BY name LIMIT 50';
      Q.ParamByName('q').AsString := '%' + AQuery + '%';
      Q.Open;
      while not Q.EOF do
      begin
        C.Id := Q.FieldByName('id').AsInteger;
        C.Name := Q.FieldByName('name').AsString;
        C.Mobile := Q.FieldByName('mobile').AsString;
        C.Notes := Q.FieldByName('notes').AsString;
        C.CreatedAt := DBToDateTime(Q.FieldByName('created_at'));
        L.Add(C);
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

class function TCustomerService.GetById(AId: Integer; out ACustomer: TCustomer): Boolean;
var
  Q: TSQLQuery;
begin
  Result := False;
  FillChar(ACustomer, SizeOf(ACustomer), 0);
  Q := DM.NewQuery;
  try
    Q.SQL.Text := 'SELECT id, name, mobile, notes, created_at FROM customers WHERE id = :id';
    Q.ParamByName('id').AsInteger := AId;
    Q.Open;
    if not Q.EOF then
    begin
      ACustomer.Id := Q.FieldByName('id').AsInteger;
      ACustomer.Name := Q.FieldByName('name').AsString;
      ACustomer.Mobile := Q.FieldByName('mobile').AsString;
      ACustomer.Notes := Q.FieldByName('notes').AsString;
      ACustomer.CreatedAt := DBToDateTime(Q.FieldByName('created_at'));
      Result := True;
    end;
    Q.Close;
  finally
    Q.Free;
  end;
end;

class function TCustomerService.Add(const ACustomer: TCustomer): Integer;
var
  Q: TSQLQuery;
begin
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'INSERT INTO customers(name, mobile, notes) VALUES(:n, :m, :no)';
    Q.ParamByName('n').AsString := ACustomer.Name;
    Q.ParamByName('m').AsString := ACustomer.Mobile;
    Q.ParamByName('no').AsString := ACustomer.Notes;
    Q.ExecSQL;
    DM.Commit;
    Result := DM.LastInsertRowId;
  finally
    Q.Free;
  end;
  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'CREATE', 'customer', Result, ACustomer.Name);
end;

class procedure TCustomerService.Update(const ACustomer: TCustomer);
var
  Q: TSQLQuery;
begin
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'UPDATE customers SET name = :n, mobile = :m, notes = :no WHERE id = :id';
    Q.ParamByName('n').AsString := ACustomer.Name;
    Q.ParamByName('m').AsString := ACustomer.Mobile;
    Q.ParamByName('no').AsString := ACustomer.Notes;
    Q.ParamByName('id').AsInteger := ACustomer.Id;
    Q.ExecSQL;
    DM.Commit;
  finally
    Q.Free;
  end;
  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'UPDATE', 'customer', ACustomer.Id, ACustomer.Name);
end;

class procedure TCustomerService.Delete(AId: Integer);
var
  Q: TSQLQuery;
  Refs: Integer;
begin
  Refs := DM.ScalarInt('SELECT COUNT(*) FROM transactions WHERE customer_id = :id', [AId]);
  if Refs > 0 then
    raise Exception.CreateFmt('Cannot delete: customer has %d transaction(s).', [Refs]);
  Q := DM.NewQuery;
  try
    Q.SQL.Text := 'DELETE FROM customers WHERE id = :id';
    Q.ParamByName('id').AsInteger := AId;
    Q.ExecSQL;
    DM.Commit;
  finally
    Q.Free;
  end;
  if AppState.HasUser then
    TAuditService.Log(AppState.CurrentUser.Id, 'DELETE', 'customer', AId, '');
end;

end.
