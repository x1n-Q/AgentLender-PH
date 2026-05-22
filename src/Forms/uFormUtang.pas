unit uFormUtang;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, Grids,
  uUtangService;

type

  { TFormUtang }

  TFormUtang = class(TForm)
    PanelTop: TPanel;
    LabelHeader: TLabel;
    PanelPay: TPanel;
    LabelSelected: TLabel;
    LabelAmount: TLabel;
    EditAmount: TEdit;
    LabelNotes: TLabel;
    EditNotes: TEdit;
    ButtonPay: TButton;
    ButtonRefresh: TButton;
    ButtonClose: TButton;
    StringGridUtang: TStringGrid;
    procedure FormShow(Sender: TObject);
    procedure StringGridUtangClick(Sender: TObject);
    procedure ButtonPayClick(Sender: TObject);
    procedure ButtonRefreshClick(Sender: TObject);
    procedure ButtonCloseClick(Sender: TObject);
  private
    FList: TArray<TUtangSummary>;
    FSelectedId: Integer;
    procedure LoadList;
  end;

var
  FormUtang: TFormUtang;

implementation

{$R *.lfm}

uses
  uSession;

procedure TFormUtang.FormShow(Sender: TObject);
begin
  LabelSelected.Caption := 'Select a utang from the list above.';
  FSelectedId := 0;
  EditAmount.Clear;
  EditNotes.Clear;
  LoadList;
end;

procedure TFormUtang.LoadList;
var
  I: Integer;
begin
  FList := TUtangService.ListOutstanding;
  StringGridUtang.ColCount := 6;
  StringGridUtang.RowCount := Length(FList) + 1;
  StringGridUtang.Cells[0, 0] := 'ID';
  StringGridUtang.Cells[1, 0] := 'Customer';
  StringGridUtang.Cells[2, 0] := 'Principal';
  StringGridUtang.Cells[3, 0] := 'Paid';
  StringGridUtang.Cells[4, 0] := 'Balance';
  StringGridUtang.Cells[5, 0] := 'Notes';
  for I := 0 to High(FList) do
  begin
    StringGridUtang.Cells[0, I+1] := IntToStr(FList[I].Utang.Id);
    StringGridUtang.Cells[1, I+1] := FList[I].CustomerName;
    StringGridUtang.Cells[2, I+1] := FormatFloat('#,##0.00', FList[I].Utang.Principal);
    StringGridUtang.Cells[3, I+1] := FormatFloat('#,##0.00', FList[I].TotalPaid);
    StringGridUtang.Cells[4, I+1] := FormatFloat('#,##0.00', FList[I].Utang.Balance);
    StringGridUtang.Cells[5, I+1] := FList[I].Utang.Notes;
  end;
end;

procedure TFormUtang.StringGridUtangClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := StringGridUtang.Row - 1;
  if (Idx < 0) or (Idx > High(FList)) then Exit;
  FSelectedId := FList[Idx].Utang.Id;
  LabelSelected.Caption :=
    Format('Utang #%d - %s - balance %s',
      [FList[Idx].Utang.Id, FList[Idx].CustomerName,
       FormatFloat('#,##0.00', FList[Idx].Utang.Balance)]);
end;

procedure TFormUtang.ButtonPayClick(Sender: TObject);
var
  Amt: Double;
  Tmp: string;
begin
  if FSelectedId = 0 then
  begin
    MessageDlg('Select a utang first.', mtWarning, [mbOk], 0);
    Exit;
  end;
  if AppState.IsReadOnly then
  begin
    MessageDlg('Viewer role cannot record payments.', mtError, [mbOk], 0);
    Exit;
  end;
  Tmp := StringReplace(EditAmount.Text, ',', '', [rfReplaceAll]);
  if not TryStrToFloat(Tmp, Amt) or (Amt <= 0) then
  begin
    MessageDlg('Invalid payment amount.', mtWarning, [mbOk], 0);
    EditAmount.SetFocus;
    Exit;
  end;
  try
    TUtangService.PayPartial(FSelectedId, Amt, AppState.CurrentUser.Id, EditNotes.Text);
    EditAmount.Clear;
    EditNotes.Clear;
    LoadList;
    MessageDlg('Payment recorded.', mtInformation, [mbOk], 0);
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOk], 0);
  end;
end;

procedure TFormUtang.ButtonRefreshClick(Sender: TObject);
begin
  LoadList;
end;

procedure TFormUtang.ButtonCloseClick(Sender: TObject);
begin
  Close;
end;

end.
