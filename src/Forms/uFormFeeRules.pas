unit uFormFeeRules;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, Grids,
  uModels;

type

  { TFormFeeRules }

  TFormFeeRules = class(TForm)
    PanelEditor: TPanel;
    LabelType: TLabel;
    ComboType: TComboBox;
    LabelMin: TLabel;
    EditMin: TEdit;
    LabelMax: TLabel;
    EditMax: TEdit;
    LabelFee: TLabel;
    EditFee: TEdit;
    CheckBoxPct: TCheckBox;
    CheckBoxActive: TCheckBox;
    ButtonNew: TButton;
    ButtonSave: TButton;
    ButtonDelete: TButton;
    ButtonClose: TButton;
    StringGridRules: TStringGrid;
    LabelHeader: TLabel;
    procedure FormShow(Sender: TObject);
    procedure StringGridRulesClick(Sender: TObject);
    procedure ButtonNewClick(Sender: TObject);
    procedure ButtonSaveClick(Sender: TObject);
    procedure ButtonDeleteClick(Sender: TObject);
    procedure ButtonCloseClick(Sender: TObject);
  private
    FList: TArray<TFeeRule>;
    FSelectedId: Integer;
    procedure LoadList;
    procedure ClearEditor;
    procedure FillEditor(ARow: Integer);
  end;

var
  FormFeeRules: TFormFeeRules;

implementation

{$R *.lfm}

uses
  uSession, uFeeService;

procedure TFormFeeRules.FormShow(Sender: TObject);
var
  T: TTxnType;
begin
  if not AppState.CanEditFees then
  begin
    MessageDlg('Only Owner can edit fee rules.', mtError, [mbOk], 0);
    ButtonSave.Enabled := False;
    ButtonDelete.Enabled := False;
    ButtonNew.Enabled := False;
  end;
  ComboType.Items.Clear;
  for T in AllTxnTypes do
    ComboType.Items.Add(TxnTypeToStr(T));
  ComboType.ItemIndex := 0;
  ClearEditor;
  LoadList;
end;

procedure TFormFeeRules.LoadList;
var
  I: Integer;
  S: string;
begin
  FList := TFeeService.ListRules;
  StringGridRules.ColCount := 7;
  StringGridRules.RowCount := Length(FList) + 1;
  StringGridRules.Cells[0, 0] := 'ID';
  StringGridRules.Cells[1, 0] := 'Type';
  StringGridRules.Cells[2, 0] := 'Min';
  StringGridRules.Cells[3, 0] := 'Max';
  StringGridRules.Cells[4, 0] := 'Fee';
  StringGridRules.Cells[5, 0] := 'Pct?';
  StringGridRules.Cells[6, 0] := 'Active?';
  for I := 0 to High(FList) do
  begin
    StringGridRules.Cells[0, I+1] := IntToStr(FList[I].Id);
    StringGridRules.Cells[1, I+1] := TxnTypeToStr(FList[I].TxnType);
    StringGridRules.Cells[2, I+1] := FormatFloat('#,##0.00', FList[I].MinAmount);
    StringGridRules.Cells[3, I+1] := FormatFloat('#,##0.00', FList[I].MaxAmount);
    if FList[I].IsPercentage then
      S := FormatFloat('0.00', FList[I].Fee) + '%'
    else
      S := FormatFloat('#,##0.00', FList[I].Fee);
    StringGridRules.Cells[4, I+1] := S;
    StringGridRules.Cells[5, I+1] := BoolToStr(FList[I].IsPercentage, True);
    StringGridRules.Cells[6, I+1] := BoolToStr(FList[I].IsActive, True);
  end;
end;

procedure TFormFeeRules.StringGridRulesClick(Sender: TObject);
begin
  FillEditor(StringGridRules.Row);
end;

procedure TFormFeeRules.FillEditor(ARow: Integer);
var
  Idx: Integer;
  R: TFeeRule;
begin
  Idx := ARow - 1;
  if (Idx < 0) or (Idx > High(FList)) then Exit;
  R := FList[Idx];
  FSelectedId := R.Id;
  ComboType.ItemIndex := ComboType.Items.IndexOf(TxnTypeToStr(R.TxnType));
  EditMin.Text := FormatFloat('0.00', R.MinAmount);
  EditMax.Text := FormatFloat('0.00', R.MaxAmount);
  EditFee.Text := FormatFloat('0.00', R.Fee);
  CheckBoxPct.Checked := R.IsPercentage;
  CheckBoxActive.Checked := R.IsActive;
end;

procedure TFormFeeRules.ClearEditor;
begin
  FSelectedId := 0;
  EditMin.Text := '0.00';
  EditMax.Text := '0.00';
  EditFee.Text := '0.00';
  CheckBoxPct.Checked := False;
  CheckBoxActive.Checked := True;
end;

procedure TFormFeeRules.ButtonNewClick(Sender: TObject);
begin
  ClearEditor;
end;

procedure TFormFeeRules.ButtonSaveClick(Sender: TObject);
var
  R: TFeeRule;
  Mn, Mx, Fee: Double;
begin
  if not TryStrToFloat(StringReplace(EditMin.Text, ',', '', [rfReplaceAll]), Mn) then
  begin
    MessageDlg('Invalid min amount.', mtWarning, [mbOk], 0); Exit;
  end;
  if not TryStrToFloat(StringReplace(EditMax.Text, ',', '', [rfReplaceAll]), Mx) then
  begin
    MessageDlg('Invalid max amount.', mtWarning, [mbOk], 0); Exit;
  end;
  if not TryStrToFloat(StringReplace(EditFee.Text, ',', '', [rfReplaceAll]), Fee) then
  begin
    MessageDlg('Invalid fee value.', mtWarning, [mbOk], 0); Exit;
  end;
  if Mx < Mn then
  begin
    MessageDlg('Max must be >= Min.', mtWarning, [mbOk], 0); Exit;
  end;
  R.Id := FSelectedId;
  R.TxnType := StrToTxnType(ComboType.Items[ComboType.ItemIndex]);
  R.MinAmount := Mn;
  R.MaxAmount := Mx;
  R.Fee := Fee;
  R.IsPercentage := CheckBoxPct.Checked;
  R.IsActive := CheckBoxActive.Checked;
  if FSelectedId = 0 then
    TFeeService.AddRule(R)
  else
    TFeeService.UpdateRule(R);
  ClearEditor;
  LoadList;
end;

procedure TFormFeeRules.ButtonDeleteClick(Sender: TObject);
begin
  if FSelectedId = 0 then Exit;
  if MessageDlg('Delete this rule?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  TFeeService.DeleteRule(FSelectedId);
  ClearEditor;
  LoadList;
end;

procedure TFormFeeRules.ButtonCloseClick(Sender: TObject);
begin
  Close;
end;

end.
