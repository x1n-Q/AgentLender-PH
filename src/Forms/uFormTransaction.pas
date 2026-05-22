unit uFormTransaction;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Dialogs, StdCtrls, ExtCtrls;

type

  { TFormTransaction }

  TFormTransaction = class(TForm)
    GroupBoxTxn: TGroupBox;
    LabelType: TLabel;
    ComboType: TComboBox;
    LabelAmount: TLabel;
    EditAmount: TEdit;
    LabelFee: TLabel;
    EditFee: TEdit;
    ButtonCalcFee: TButton;
    LabelCustomer: TLabel;
    ComboCustomer: TComboBox;
    LabelRef: TLabel;
    EditRef: TEdit;
    LabelNotes: TLabel;
    EditNotes: TEdit;
    LabelImpact: TLabel;
    LabelImpactValues: TLabel;
    ButtonSave: TButton;
    ButtonCancel: TButton;
    CheckBoxUtang: TCheckBox;
    LabelUtangNote: TLabel;
    procedure FormShow(Sender: TObject);
    procedure ComboTypeChange(Sender: TObject);
    procedure EditAmountChange(Sender: TObject);
    procedure ButtonCalcFeeClick(Sender: TObject);
    procedure ButtonSaveClick(Sender: TObject);
    procedure ButtonCancelClick(Sender: TObject);
  private
    FSessionId: Integer;
    FCustomerIds: array of Integer;
    procedure LoadCustomers;
    procedure RecomputeImpact;
  public
    procedure PrepareForNew(ASessionId: Integer);
  end;

var
  FormTransaction: TFormTransaction;

implementation

{$R *.lfm}

uses
  uSession, uModels, uTransactionService, uFeeService, uCustomerService,
  uUtangService;

function ParseFloatLoose(const S: string; out V: Double): Boolean;
var
  Tmp: string;
begin
  Tmp := StringReplace(S, ',', '', [rfReplaceAll]);
  Result := TryStrToFloat(Tmp, V);
end;

procedure TFormTransaction.PrepareForNew(ASessionId: Integer);
begin
  FSessionId := ASessionId;
end;

procedure TFormTransaction.FormShow(Sender: TObject);
var
  T: TTxnType;
begin
  ComboType.Items.Clear;
  for T in AllTxnTypes do
    ComboType.Items.Add(TxnTypeToStr(T));
  ComboType.ItemIndex := 0;

  LoadCustomers;

  EditAmount.Text := '';
  EditFee.Text := '0.00';
  EditRef.Text := '';
  EditNotes.Text := '';
  CheckBoxUtang.Checked := False;
  LabelImpactValues.Caption := '-';
end;

procedure TFormTransaction.LoadCustomers;
var
  Customers: TArray<TCustomer>;
  I: Integer;
begin
  Customers := TCustomerService.ListAll;
  ComboCustomer.Items.Clear;
  ComboCustomer.Items.Add('(none)');
  SetLength(FCustomerIds, Length(Customers) + 1);
  FCustomerIds[0] := 0;
  for I := 0 to High(Customers) do
  begin
    ComboCustomer.Items.Add(Customers[I].Name + ' ' + Customers[I].Mobile);
    FCustomerIds[I+1] := Customers[I].Id;
  end;
  ComboCustomer.ItemIndex := 0;
end;

procedure TFormTransaction.ComboTypeChange(Sender: TObject);
begin
  RecomputeImpact;
end;

procedure TFormTransaction.EditAmountChange(Sender: TObject);
begin
  RecomputeImpact;
end;

procedure TFormTransaction.ButtonCalcFeeClick(Sender: TObject);
var
  T: TTxnType;
  Amt, Fee: Double;
begin
  if ComboType.ItemIndex < 0 then Exit;
  if not ParseFloatLoose(EditAmount.Text, Amt) then Exit;
  T := StrToTxnType(ComboType.Items[ComboType.ItemIndex]);
  Fee := TFeeService.ComputeFee(T, Amt);
  EditFee.Text := FormatFloat('0.00', Fee);
  RecomputeImpact;
end;

procedure TFormTransaction.RecomputeImpact;
var
  T: TTxnType;
  Amt, Fee: Double;
  Imp: TCashWalletImpact;
begin
  if ComboType.ItemIndex < 0 then Exit;
  if not ParseFloatLoose(EditAmount.Text, Amt) then Amt := 0;
  if not ParseFloatLoose(EditFee.Text, Fee) then Fee := 0;
  T := StrToTxnType(ComboType.Items[ComboType.ItemIndex]);
  Imp := TTransactionService.ComputeImpact(T, Amt, Fee);
  LabelImpactValues.Caption :=
    Format('Cash drawer: %+,.2f    |    Wallet: %+,.2f',
      [Imp.Cash, Imp.Wallet]);
  if T = ttManualAdjustment then
    LabelUtangNote.Caption :=
      'Manual Adjustment: enter signed Cash in Amount field and signed Wallet in Fee field.'
  else
    LabelUtangNote.Caption := '';
end;

procedure TFormTransaction.ButtonSaveClick(Sender: TObject);
var
  T: TTxnType;
  Amt, Fee, ShortAmt: Double;
  Txn: TTransaction;
  TxnId: Integer;
  CustomerId: Integer;
begin
  if ComboType.ItemIndex < 0 then
  begin
    MessageDlg('Choose a transaction type.', mtWarning, [mbOk], 0);
    Exit;
  end;
  T := StrToTxnType(ComboType.Items[ComboType.ItemIndex]);
  if not ParseFloatLoose(EditAmount.Text, Amt) then
  begin
    MessageDlg('Invalid amount.', mtWarning, [mbOk], 0);
    EditAmount.SetFocus;
    Exit;
  end;
  if not ParseFloatLoose(EditFee.Text, Fee) then Fee := 0;

  if (T <> ttManualAdjustment) and (Amt <= 0) then
  begin
    MessageDlg('Amount must be positive (except for Manual Adjustment).',
      mtWarning, [mbOk], 0);
    EditAmount.SetFocus;
    Exit;
  end;

  CustomerId := 0;
  if (ComboCustomer.ItemIndex > 0)
     and (ComboCustomer.ItemIndex < Length(FCustomerIds)) then
    CustomerId := FCustomerIds[ComboCustomer.ItemIndex];

  Txn.Id := 0;
  Txn.SessionId := FSessionId;
  Txn.TxnDateTime := Now;
  Txn.TxnType := T;
  Txn.CustomerId := CustomerId;
  Txn.Amount := Amt;
  Txn.Fee := Fee;
  Txn.ReferenceNo := EditRef.Text;
  Txn.Notes := EditNotes.Text;
  Txn.CreatedBy := AppState.CurrentUser.Id;
  Txn.IsVoid := False;

  try
    TxnId := TTransactionService.RecordTxn(Txn);

    if CheckBoxUtang.Checked and (CustomerId > 0)
       and (T in [ttCashIn, ttCashOut, ttELoad, ttBillsPayment, ttSendMoney]) then
    begin
      ShortAmt := Amt + Fee;
      TUtangService.CreateUtang(CustomerId, TxnId, ShortAmt,
        'Auto-utang from txn #' + IntToStr(TxnId));
    end;

    MessageDlg('Transaction saved (#' + IntToStr(TxnId) + ').',
      mtInformation, [mbOk], 0);
    ModalResult := mrOk;
  except
    on E: Exception do
      MessageDlg('Save failed: ' + E.Message, mtError, [mbOk], 0);
  end;
end;

procedure TFormTransaction.ButtonCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
