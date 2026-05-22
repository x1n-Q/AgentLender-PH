unit uDM;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LazFileUtils, db, sqldb, SQLite3Conn, Variants;

type

  { TDM }

  TDM = class(TDataModule)
    SQLConnection: TSQLite3Connection;
    SQLTransaction: TSQLTransaction;
    procedure DataModuleCreate(Sender: TObject);
  private
    FDatabaseFile: string;
    procedure CreateSchema;
    procedure EnsureDefaultOwner;
  public
    procedure InitializeDatabase;
    function NewQuery: TSQLQuery;
    procedure ExecSQL(const ASQL: string);
    procedure Commit;
    function LastInsertRowId: Int64;
    function ScalarInt(const ASQL: string; const AParams: array of Variant): Integer;
    function ScalarFloat(const ASQL: string; const AParams: array of Variant): Double;
    function ScalarStr(const ASQL: string; const AParams: array of Variant): string;
    property DatabaseFile: string read FDatabaseFile;
  end;

var
  DM: TDM;

function DBToDateTime(F: TField): TDateTime;

implementation

{$R *.lfm}

uses
  sha1, DateUtils;

function DBToDateTime(F: TField): TDateTime;
var
  S: string;
  Y, M, D, H, N, Sec: Integer;
begin
  Result := 0;
  if (F = nil) or F.IsNull then Exit;
  S := F.AsString;
  if Length(S) < 10 then Exit;
  Y := StrToIntDef(Copy(S, 1, 4), 0);
  M := StrToIntDef(Copy(S, 6, 2), 0);
  D := StrToIntDef(Copy(S, 9, 2), 0);
  if (Y < 1) or (M < 1) or (D < 1) then Exit;
  try
    Result := EncodeDate(Y, M, D);
    if Length(S) >= 19 then
    begin
      H := StrToIntDef(Copy(S, 12, 2), 0);
      N := StrToIntDef(Copy(S, 15, 2), 0);
      Sec := StrToIntDef(Copy(S, 18, 2), 0);
      Result := Result + EncodeTime(H, N, Sec, 0);
    end;
  except
    Result := 0;
  end;
end;

procedure TDM.DataModuleCreate(Sender: TObject);
begin
  FDatabaseFile := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0)))
                 + 'data' + PathDelim + 'agentledger.db';
end;

procedure TDM.InitializeDatabase;
var
  DataDir: string;
begin
  DataDir := ExtractFileDir(FDatabaseFile);
  if not DirectoryExists(DataDir) then
    ForceDirectories(DataDir);

  SQLConnection.Close;
  SQLConnection.DatabaseName := FDatabaseFile;
  SQLConnection.Transaction := SQLTransaction;
  SQLTransaction.Database := SQLConnection;
  SQLConnection.LoginPrompt := False;
  SQLConnection.Open;

  if not SQLTransaction.Active then
    SQLTransaction.StartTransaction;

  // Foreign keys must be enabled per-connection
  SQLConnection.ExecuteDirect('PRAGMA foreign_keys = ON;');

  CreateSchema;
  Commit;
  EnsureDefaultOwner;
end;

procedure TDM.CreateSchema;
const
  SQL_USERS =
    'CREATE TABLE IF NOT EXISTS users (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  username TEXT UNIQUE NOT NULL,' +
    '  password_hash TEXT NOT NULL,' +
    '  full_name TEXT NOT NULL,' +
    '  role TEXT NOT NULL CHECK(role IN (''Owner'',''Staff'',''Viewer'')),' +
    '  is_active INTEGER NOT NULL DEFAULT 1,' +
    '  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)';

  SQL_SESSIONS =
    'CREATE TABLE IF NOT EXISTS sessions (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  session_date TEXT NOT NULL,' +
    '  opened_by INTEGER NOT NULL,' +
    '  opened_at TEXT NOT NULL,' +
    '  closed_by INTEGER,' +
    '  closed_at TEXT,' +
    '  starting_cash REAL NOT NULL,' +
    '  starting_wallet REAL NOT NULL,' +
    '  actual_cash REAL,' +
    '  actual_wallet REAL,' +
    '  status TEXT NOT NULL DEFAULT ''Open'',' +
    '  notes TEXT,' +
    '  FOREIGN KEY (opened_by) REFERENCES users(id),' +
    '  FOREIGN KEY (closed_by) REFERENCES users(id))';

  SQL_CUSTOMERS =
    'CREATE TABLE IF NOT EXISTS customers (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name TEXT NOT NULL,' +
    '  mobile TEXT,' +
    '  notes TEXT,' +
    '  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)';

  SQL_FEE_RULES =
    'CREATE TABLE IF NOT EXISTS fee_rules (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  txn_type TEXT NOT NULL,' +
    '  min_amount REAL NOT NULL,' +
    '  max_amount REAL NOT NULL,' +
    '  fee REAL NOT NULL,' +
    '  is_percentage INTEGER NOT NULL DEFAULT 0,' +
    '  is_active INTEGER NOT NULL DEFAULT 1)';

  SQL_TXNS =
    'CREATE TABLE IF NOT EXISTS transactions (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  session_id INTEGER NOT NULL,' +
    '  txn_datetime TEXT NOT NULL,' +
    '  txn_type TEXT NOT NULL,' +
    '  customer_id INTEGER,' +
    '  amount REAL NOT NULL,' +
    '  fee REAL NOT NULL DEFAULT 0,' +
    '  cash_impact REAL NOT NULL DEFAULT 0,' +
    '  wallet_impact REAL NOT NULL DEFAULT 0,' +
    '  reference_no TEXT,' +
    '  notes TEXT,' +
    '  created_by INTEGER NOT NULL,' +
    '  is_void INTEGER NOT NULL DEFAULT 0,' +
    '  FOREIGN KEY (session_id) REFERENCES sessions(id),' +
    '  FOREIGN KEY (customer_id) REFERENCES customers(id),' +
    '  FOREIGN KEY (created_by) REFERENCES users(id))';

  SQL_UTANG =
    'CREATE TABLE IF NOT EXISTS utang (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  customer_id INTEGER NOT NULL,' +
    '  transaction_id INTEGER,' +
    '  principal REAL NOT NULL,' +
    '  balance REAL NOT NULL,' +
    '  notes TEXT,' +
    '  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,' +
    '  FOREIGN KEY (customer_id) REFERENCES customers(id),' +
    '  FOREIGN KEY (transaction_id) REFERENCES transactions(id))';

  SQL_UTANG_PAY =
    'CREATE TABLE IF NOT EXISTS utang_payments (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  utang_id INTEGER NOT NULL,' +
    '  amount REAL NOT NULL,' +
    '  paid_at TEXT NOT NULL,' +
    '  received_by INTEGER NOT NULL,' +
    '  notes TEXT,' +
    '  FOREIGN KEY (utang_id) REFERENCES utang(id),' +
    '  FOREIGN KEY (received_by) REFERENCES users(id))';

  SQL_AUDIT =
    'CREATE TABLE IF NOT EXISTS audit_logs (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  user_id INTEGER NOT NULL,' +
    '  action TEXT NOT NULL,' +
    '  entity TEXT NOT NULL,' +
    '  entity_id INTEGER,' +
    '  details TEXT,' +
    '  log_datetime TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,' +
    '  FOREIGN KEY (user_id) REFERENCES users(id))';
begin
  ExecSQL(SQL_USERS);
  ExecSQL(SQL_SESSIONS);
  ExecSQL(SQL_CUSTOMERS);
  ExecSQL(SQL_FEE_RULES);
  ExecSQL(SQL_TXNS);
  ExecSQL(SQL_UTANG);
  ExecSQL(SQL_UTANG_PAY);
  ExecSQL(SQL_AUDIT);
  ExecSQL('CREATE INDEX IF NOT EXISTS ix_txn_session ON transactions(session_id)');
  ExecSQL('CREATE INDEX IF NOT EXISTS ix_txn_date ON transactions(txn_datetime)');
  ExecSQL('CREATE INDEX IF NOT EXISTS ix_session_date ON sessions(session_date)');
  ExecSQL('CREATE INDEX IF NOT EXISTS ix_audit_user ON audit_logs(user_id)');
end;

procedure TDM.EnsureDefaultOwner;
var
  Q: TSQLQuery;
  Hash: string;
  Cnt: Integer;
  D: TSHA1Digest;
begin
  Cnt := ScalarInt('SELECT COUNT(*) FROM users', []);
  if Cnt > 0 then Exit;

  D := SHA1String('admin123' + 'AgentLedgerPH-Salt');
  Hash := LowerCase(SHA1Print(D));

  Q := NewQuery;
  try
    Q.SQL.Text :=
      'INSERT INTO users(username, password_hash, full_name, role, is_active) ' +
      'VALUES(:u, :p, :n, :r, 1)';
    Q.ParamByName('u').AsString := 'admin';
    Q.ParamByName('p').AsString := Hash;
    Q.ParamByName('n').AsString := 'Owner';
    Q.ParamByName('r').AsString := 'Owner';
    Q.ExecSQL;
    Commit;
  finally
    Q.Free;
  end;
end;

function TDM.NewQuery: TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := SQLConnection;
  Result.Transaction := SQLTransaction;
end;

procedure TDM.ExecSQL(const ASQL: string);
begin
  if not SQLTransaction.Active then
    SQLTransaction.StartTransaction;
  SQLConnection.ExecuteDirect(ASQL);
end;

procedure TDM.Commit;
begin
  if SQLTransaction.Active then
    SQLTransaction.CommitRetaining;
end;

function TDM.LastInsertRowId: Int64;
var
  Q: TSQLQuery;
begin
  Result := 0;
  Q := NewQuery;
  try
    Q.SQL.Text := 'SELECT last_insert_rowid()';
    Q.Open;
    if not Q.EOF then
      Result := Q.Fields[0].AsLargeInt;
    Q.Close;
  finally
    Q.Free;
  end;
end;

function TDM.ScalarInt(const ASQL: string; const AParams: array of Variant): Integer;
var
  Q: TSQLQuery;
  I: Integer;
begin
  Result := 0;
  Q := NewQuery;
  try
    Q.SQL.Text := ASQL;
    for I := 0 to High(AParams) do
      Q.Params[I].Value := AParams[I];
    Q.Open;
    if not Q.EOF then
      Result := Q.Fields[0].AsInteger;
    Q.Close;
  finally
    Q.Free;
  end;
end;

function TDM.ScalarFloat(const ASQL: string; const AParams: array of Variant): Double;
var
  Q: TSQLQuery;
  I: Integer;
begin
  Result := 0;
  Q := NewQuery;
  try
    Q.SQL.Text := ASQL;
    for I := 0 to High(AParams) do
      Q.Params[I].Value := AParams[I];
    Q.Open;
    if (not Q.EOF) and (not Q.Fields[0].IsNull) then
      Result := Q.Fields[0].AsFloat;
    Q.Close;
  finally
    Q.Free;
  end;
end;

function TDM.ScalarStr(const ASQL: string; const AParams: array of Variant): string;
var
  Q: TSQLQuery;
  I: Integer;
begin
  Result := '';
  Q := NewQuery;
  try
    Q.SQL.Text := ASQL;
    for I := 0 to High(AParams) do
      Q.Params[I].Value := AParams[I];
    Q.Open;
    if (not Q.EOF) and (not Q.Fields[0].IsNull) then
      Result := Q.Fields[0].AsString;
    Q.Close;
  finally
    Q.Free;
  end;
end;

end.
