unit uModels;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Generics.Collections;

type
  TUserRole = (urOwner, urStaff, urViewer);

  TTxnType = (
    ttCashIn,
    ttCashOut,
    ttELoad,
    ttBillsPayment,
    ttSendMoney,
    ttUtangPayment,
    ttManualAdjustment
  );

  TUser = record
    Id: Integer;
    Username: string;
    FullName: string;
    Role: TUserRole;
    IsActive: Boolean;
    CreatedAt: TDateTime;
  end;

  TSessionRec = record
    Id: Integer;
    SessionDate: TDate;
    OpenedBy: Integer;
    OpenedAt: TDateTime;
    ClosedBy: Integer;
    ClosedAt: TDateTime;
    StartingCash: Double;
    StartingWallet: Double;
    ActualCash: Double;
    ActualWallet: Double;
    Status: string;
    Notes: string;
  end;

  TCustomer = record
    Id: Integer;
    Name: string;
    Mobile: string;
    Notes: string;
    CreatedAt: TDateTime;
  end;

  TFeeRule = record
    Id: Integer;
    TxnType: TTxnType;
    MinAmount: Double;
    MaxAmount: Double;
    Fee: Double;
    IsPercentage: Boolean;
    IsActive: Boolean;
  end;

  TTransaction = record
    Id: Integer;
    SessionId: Integer;
    TxnDateTime: TDateTime;
    TxnType: TTxnType;
    CustomerId: Integer;
    Amount: Double;
    Fee: Double;
    CashImpact: Double;
    WalletImpact: Double;
    ReferenceNo: string;
    Notes: string;
    CreatedBy: Integer;
    IsVoid: Boolean;
  end;

  TUtang = record
    Id: Integer;
    CustomerId: Integer;
    TransactionId: Integer;
    Principal: Double;
    Balance: Double;
    Notes: string;
    CreatedAt: TDateTime;
  end;

  TUtangPayment = record
    Id: Integer;
    UtangId: Integer;
    Amount: Double;
    PaidAt: TDateTime;
    ReceivedBy: Integer;
    Notes: string;
  end;

  TAuditLog = record
    Id: Integer;
    UserId: Integer;
    Action: string;
    Entity: string;
    EntityId: Integer;
    Details: string;
    LogDateTime: TDateTime;
  end;

  TUserList = TList<TUser>;
  TSessionList = TList<TSessionRec>;
  TCustomerList = TList<TCustomer>;
  TFeeRuleList = TList<TFeeRule>;
  TTransactionList = TList<TTransaction>;
  TUtangList = TList<TUtang>;

function RoleToStr(R: TUserRole): string;
function StrToRole(const S: string): TUserRole;
function TxnTypeToStr(T: TTxnType): string;
function StrToTxnType(const S: string): TTxnType;
function AllTxnTypes: TArray<TTxnType>;

implementation

function RoleToStr(R: TUserRole): string;
begin
  case R of
    urOwner:  Result := 'Owner';
    urStaff:  Result := 'Staff';
    urViewer: Result := 'Viewer';
  else
    Result := 'Viewer';
  end;
end;

function StrToRole(const S: string): TUserRole;
begin
  if SameText(S, 'Owner') then Exit(urOwner);
  if SameText(S, 'Staff') then Exit(urStaff);
  Result := urViewer;
end;

function TxnTypeToStr(T: TTxnType): string;
begin
  case T of
    ttCashIn:           Result := 'Cash-In';
    ttCashOut:          Result := 'Cash-Out';
    ttELoad:            Result := 'E-Load';
    ttBillsPayment:     Result := 'Bills Payment';
    ttSendMoney:        Result := 'Send Money';
    ttUtangPayment:     Result := 'Utang Payment';
    ttManualAdjustment: Result := 'Manual Adjustment';
  else
    Result := 'Unknown';
  end;
end;

function StrToTxnType(const S: string): TTxnType;
begin
  if SameText(S, 'Cash-In') then Exit(ttCashIn);
  if SameText(S, 'Cash-Out') then Exit(ttCashOut);
  if SameText(S, 'E-Load') then Exit(ttELoad);
  if SameText(S, 'Bills Payment') then Exit(ttBillsPayment);
  if SameText(S, 'Send Money') then Exit(ttSendMoney);
  if SameText(S, 'Utang Payment') then Exit(ttUtangPayment);
  if SameText(S, 'Manual Adjustment') then Exit(ttManualAdjustment);
  Result := ttCashIn;
end;

function AllTxnTypes: TArray<TTxnType>;
begin
  Result := [
    ttCashIn, ttCashOut, ttELoad, ttBillsPayment,
    ttSendMoney, ttUtangPayment, ttManualAdjustment
  ];
end;

end.
