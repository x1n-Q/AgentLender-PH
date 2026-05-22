unit uSeedService;

{$mode delphi}{$H+}

interface

type
  TSeedService = class
  public
    class procedure SeedFeeRules;
    class procedure SeedSampleData;
    class function HasFeeRules: Boolean;
    class function HasCustomers: Boolean;
  end;

implementation

uses
  SysUtils, uDM, uModels, uAuthService, uFeeService, uCustomerService;

class function TSeedService.HasFeeRules: Boolean;
begin
  Result := DM.ScalarInt('SELECT COUNT(*) FROM fee_rules', []) > 0;
end;

class function TSeedService.HasCustomers: Boolean;
begin
  Result := DM.ScalarInt('SELECT COUNT(*) FROM customers', []) > 0;
end;

class procedure TSeedService.SeedFeeRules;
  procedure AddRule(T: TTxnType; AMin, AMax, AFee: Double; APct: Boolean);
  var R: TFeeRule;
  begin
    R.Id := 0;
    R.TxnType := T;
    R.MinAmount := AMin;
    R.MaxAmount := AMax;
    R.Fee := AFee;
    R.IsPercentage := APct;
    R.IsActive := True;
    TFeeService.AddRule(R);
  end;
begin
  if HasFeeRules then Exit;

  AddRule(ttCashIn,     1,    500,    5,  False);
  AddRule(ttCashIn,   501,   1000,   10,  False);
  AddRule(ttCashIn,  1001,   1500,   15,  False);
  AddRule(ttCashIn,  1501,   2000,   20,  False);
  AddRule(ttCashIn,  2001,   2500,   25,  False);
  AddRule(ttCashIn,  2501,   3000,   30,  False);
  AddRule(ttCashIn,  3001,   5000,   50,  False);
  AddRule(ttCashIn,  5001,  10000,  100,  False);
  AddRule(ttCashIn, 10001,  20000,  150,  False);

  AddRule(ttCashOut,     1,    500,    5,  False);
  AddRule(ttCashOut,   501,   1000,   10,  False);
  AddRule(ttCashOut,  1001,   1500,   15,  False);
  AddRule(ttCashOut,  1501,   2000,   20,  False);
  AddRule(ttCashOut,  2001,   2500,   25,  False);
  AddRule(ttCashOut,  2501,   5000,   50,  False);
  AddRule(ttCashOut,  5001,  10000,  100,  False);
  AddRule(ttCashOut, 10001,  20000,  150,  False);

  AddRule(ttELoad, 5, 9999, 3, True);

  AddRule(ttBillsPayment, 1, 1000, 10, False);
  AddRule(ttBillsPayment, 1001, 5000, 15, False);
  AddRule(ttBillsPayment, 5001, 99999, 20, False);

  AddRule(ttSendMoney, 1, 1000, 10, False);
  AddRule(ttSendMoney, 1001, 5000, 15, False);
  AddRule(ttSendMoney, 5001, 99999, 25, False);
end;

class procedure TSeedService.SeedSampleData;
var
  C: TCustomer;
begin
  SeedFeeRules;

  if not HasCustomers then
  begin
    C.Id := 0; C.Name := 'Walk-in Customer'; C.Mobile := ''; C.Notes := 'Default walk-in';
    TCustomerService.Add(C);
    C.Id := 0; C.Name := 'Maria Santos'; C.Mobile := '09171234567'; C.Notes := '';
    TCustomerService.Add(C);
    C.Id := 0; C.Name := 'Juan dela Cruz'; C.Mobile := '09181234567'; C.Notes := 'Regular';
    TCustomerService.Add(C);
    C.Id := 0; C.Name := 'Aling Nena'; C.Mobile := '09191234567'; C.Notes := 'Sometimes utang';
    TCustomerService.Add(C);
  end;

  if DM.ScalarInt('SELECT COUNT(*) FROM users WHERE username = :u', ['staff1']) = 0 then
    TAuthService.CreateUser('staff1', 'staff123', 'Demo Staff', urStaff);
  if DM.ScalarInt('SELECT COUNT(*) FROM users WHERE username = :u', ['viewer1']) = 0 then
    TAuthService.CreateUser('viewer1', 'viewer123', 'Demo Viewer', urViewer);
end;

end.
