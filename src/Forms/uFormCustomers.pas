unit uFormCustomers;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, Grids,
  uModels;

type

  { TFormCustomers }

  TFormCustomers = class(TForm)
    PanelTop: TPanel;
    LabelSearch: TLabel;
    EditSearch: TEdit;
    ButtonRefresh: TButton;
    PanelEditor: TPanel;
    LabelName: TLabel;
    EditName: TEdit;
    LabelMobile: TLabel;
    EditMobile: TEdit;
    LabelNotes: TLabel;
    EditNotes: TEdit;
    ButtonNew: TButton;
    ButtonSave: TButton;
    ButtonDelete: TButton;
    ButtonClose: TButton;
    StringGridCustomers: TStringGrid;
    procedure FormShow(Sender: TObject);
    procedure ButtonRefreshClick(Sender: TObject);
    procedure EditSearchChange(Sender: TObject);
    procedure StringGridCustomersClick(Sender: TObject);
    procedure ButtonNewClick(Sender: TObject);
    procedure ButtonSaveClick(Sender: TObject);
    procedure ButtonDeleteClick(Sender: TObject);
    procedure ButtonCloseClick(Sender: TObject);
  private
    FList: TArray<TCustomer>;
    FSelectedId: Integer;
    procedure LoadList(const AQuery: string);
    procedure FillEditorFromRow(ARow: Integer);
    procedure ClearEditor;
  end;

var
  FormCustomers: TFormCustomers;

implementation

{$R *.lfm}

uses
  uCustomerService, uSession;

procedure TFormCustomers.FormShow(Sender: TObject);
begin
  ClearEditor;
  LoadList('');
end;

procedure TFormCustomers.LoadList(const AQuery: string);
var
  I: Integer;
begin
  if AQuery = '' then
    FList := TCustomerService.ListAll
  else
    FList := TCustomerService.Search(AQuery);

  StringGridCustomers.ColCount := 4;
  StringGridCustomers.RowCount := Length(FList) + 1;
  StringGridCustomers.Cells[0, 0] := 'ID';
  StringGridCustomers.Cells[1, 0] := 'Name';
  StringGridCustomers.Cells[2, 0] := 'Mobile';
  StringGridCustomers.Cells[3, 0] := 'Notes';
  for I := 0 to High(FList) do
  begin
    StringGridCustomers.Cells[0, I+1] := IntToStr(FList[I].Id);
    StringGridCustomers.Cells[1, I+1] := FList[I].Name;
    StringGridCustomers.Cells[2, I+1] := FList[I].Mobile;
    StringGridCustomers.Cells[3, I+1] := FList[I].Notes;
  end;
end;

procedure TFormCustomers.ButtonRefreshClick(Sender: TObject);
begin
  LoadList(EditSearch.Text);
end;

procedure TFormCustomers.EditSearchChange(Sender: TObject);
begin
  LoadList(EditSearch.Text);
end;

procedure TFormCustomers.StringGridCustomersClick(Sender: TObject);
begin
  FillEditorFromRow(StringGridCustomers.Row);
end;

procedure TFormCustomers.FillEditorFromRow(ARow: Integer);
var
  Idx: Integer;
begin
  Idx := ARow - 1;
  if (Idx < 0) or (Idx > High(FList)) then Exit;
  FSelectedId := FList[Idx].Id;
  EditName.Text := FList[Idx].Name;
  EditMobile.Text := FList[Idx].Mobile;
  EditNotes.Text := FList[Idx].Notes;
end;

procedure TFormCustomers.ClearEditor;
begin
  FSelectedId := 0;
  EditName.Clear;
  EditMobile.Clear;
  EditNotes.Clear;
end;

procedure TFormCustomers.ButtonNewClick(Sender: TObject);
begin
  ClearEditor;
  EditName.SetFocus;
end;

procedure TFormCustomers.ButtonSaveClick(Sender: TObject);
var
  C: TCustomer;
begin
  if AppState.IsReadOnly then
  begin
    MessageDlg('Viewer role cannot edit.', mtError, [mbOk], 0);
    Exit;
  end;
  if Trim(EditName.Text) = '' then
  begin
    MessageDlg('Name is required.', mtWarning, [mbOk], 0);
    EditName.SetFocus;
    Exit;
  end;
  C.Id := FSelectedId;
  C.Name := Trim(EditName.Text);
  C.Mobile := Trim(EditMobile.Text);
  C.Notes := EditNotes.Text;
  if FSelectedId = 0 then
    TCustomerService.Add(C)
  else
    TCustomerService.Update(C);
  ClearEditor;
  LoadList(EditSearch.Text);
end;

procedure TFormCustomers.ButtonDeleteClick(Sender: TObject);
begin
  if FSelectedId = 0 then Exit;
  if not AppState.CanManageUsers then
  begin
    MessageDlg('Only Owner can delete customers.', mtError, [mbOk], 0);
    Exit;
  end;
  if MessageDlg('Delete this customer?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  try
    TCustomerService.Delete(FSelectedId);
    ClearEditor;
    LoadList(EditSearch.Text);
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOk], 0);
  end;
end;

procedure TFormCustomers.ButtonCloseClick(Sender: TObject);
begin
  Close;
end;

end.
