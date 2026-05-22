unit uAuditService;

{$mode delphi}{$H+}

interface

uses
  SysUtils;

type
  TAuditService = class
  public
    class procedure Log(AUserId: Integer; const AAction, AEntity: string;
      AEntityId: Integer; const ADetails: string);
  end;

implementation

uses
  sqldb, uDM;

class procedure TAuditService.Log(AUserId: Integer;
  const AAction, AEntity: string; AEntityId: Integer; const ADetails: string);
var
  Q: TSQLQuery;
begin
  if DM = nil then Exit;
  Q := DM.NewQuery;
  try
    Q.SQL.Text :=
      'INSERT INTO audit_logs(user_id, action, entity, entity_id, details, log_datetime) ' +
      'VALUES(:u, :a, :e, :eid, :d, :dt)';
    Q.ParamByName('u').AsInteger := AUserId;
    Q.ParamByName('a').AsString := AAction;
    Q.ParamByName('e').AsString := AEntity;
    if AEntityId = 0 then
      Q.ParamByName('eid').Clear
    else
      Q.ParamByName('eid').AsInteger := AEntityId;
    Q.ParamByName('d').AsString := ADetails;
    Q.ParamByName('dt').AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    Q.ExecSQL;
    DM.Commit;
  finally
    Q.Free;
  end;
end;

end.
