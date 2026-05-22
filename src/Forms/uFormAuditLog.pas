unit uFormAuditLog;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, ComCtrls, Grids,
  DateTimePicker;

type

  { TFormAuditLog }

  TFormAuditLog = class(TForm)
    PanelTop: TPanel;
    LabelHeader: TLabel;
    LabelFrom: TLabel;
    DateFrom: TDateTimePicker;
    LabelTo: TLabel;
    DateTo: TDateTimePicker;
    LabelFilter: TLabel;
    EditFilter: TEdit;
    ButtonRefresh: TButton;
    ButtonClose: TButton;
    StringGridLogs: TStringGrid;
    procedure FormShow(Sender: TObject);
    procedure ButtonRefreshClick(Sender: TObject);
    procedure ButtonCloseClick(Sender: TObject);
  private
    procedure LoadLogs;
  end;

var
  FormAuditLog: TFormAuditLog;

implementation

{$R *.lfm}

uses
  sqldb, uDM;

procedure TFormAuditLog.FormShow(Sender: TObject);
begin
  DateFrom.Date := Date - 7;
  DateTo.Date := Date;
  LoadLogs;
end;

procedure TFormAuditLog.LoadLogs;
var
  Q: TSQLQuery;
  I: Integer;
  Filter: string;
begin
  Q := DM.NewQuery;
  try
    Filter := Trim(EditFilter.Text);
    Q.SQL.Text :=
      'SELECT a.id, a.log_datetime, u.username, a.action, a.entity, a.entity_id, a.details ' +
      'FROM audit_logs a LEFT JOIN users u ON u.id = a.user_id ' +
      'WHERE date(a.log_datetime) BETWEEN :df AND :dt ' +
      '  AND (:ft = '''' OR a.action LIKE ''%''||:ft||''%'' OR a.entity LIKE ''%''||:ft||''%'' OR a.details LIKE ''%''||:ft||''%'' OR u.username LIKE ''%''||:ft||''%'') ' +
      'ORDER BY a.id DESC LIMIT 500';
    Q.ParamByName('df').AsString := FormatDateTime('yyyy-mm-dd', DateFrom.Date);
    Q.ParamByName('dt').AsString := FormatDateTime('yyyy-mm-dd', DateTo.Date);
    Q.ParamByName('ft').AsString := Filter;
    Q.Open;

    StringGridLogs.ColCount := 7;
    StringGridLogs.Cells[0, 0] := 'ID';
    StringGridLogs.Cells[1, 0] := 'When';
    StringGridLogs.Cells[2, 0] := 'User';
    StringGridLogs.Cells[3, 0] := 'Action';
    StringGridLogs.Cells[4, 0] := 'Entity';
    StringGridLogs.Cells[5, 0] := 'Entity ID';
    StringGridLogs.Cells[6, 0] := 'Details';

    StringGridLogs.RowCount := Q.RecordCount + 1;
    if Q.RecordCount = 0 then
      StringGridLogs.RowCount := 2;

    I := 1;
    while not Q.EOF do
    begin
      StringGridLogs.Cells[0, I] := Q.FieldByName('id').AsString;
      StringGridLogs.Cells[1, I] := Q.FieldByName('log_datetime').AsString;
      StringGridLogs.Cells[2, I] := Q.FieldByName('username').AsString;
      StringGridLogs.Cells[3, I] := Q.FieldByName('action').AsString;
      StringGridLogs.Cells[4, I] := Q.FieldByName('entity').AsString;
      StringGridLogs.Cells[5, I] := Q.FieldByName('entity_id').AsString;
      StringGridLogs.Cells[6, I] := Q.FieldByName('details').AsString;
      Inc(I);
      Q.Next;
    end;
    Q.Close;
  finally
    Q.Free;
  end;
end;

procedure TFormAuditLog.ButtonRefreshClick(Sender: TObject);
begin
  LoadLogs;
end;

procedure TFormAuditLog.ButtonCloseClick(Sender: TObject);
begin
  Close;
end;

end.
