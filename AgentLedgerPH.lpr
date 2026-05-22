program AgentLedgerPH;

{$mode delphi}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // LCL widgetset
  Forms,
  Controls,
  Dialogs,
  SysUtils,
  uDM,
  uModels,
  uSession,
  uAuthService,
  uSessionService,
  uTransactionService,
  uCustomerService,
  uFeeService,
  uUtangService,
  uAuditService,
  uBackupService,
  uSeedService,
  uReportService,
  uFormLogin,
  uFormMain,
  uFormSession,
  uFormTransaction,
  uFormCustomers,
  uFormUtang,
  uFormFeeRules,
  uFormUsers,
  uFormReconciliation,
  uFormReports,
  uFormAuditLog;

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Title := 'AgentLedger PH';
  Application.Initialize;

  Application.CreateForm(TDM, DM);
  try
    DM.InitializeDatabase;
  except
    on E: Exception do
    begin
      MessageDlg('Database init failed: ' + E.Message, mtError, [mbOk], 0);
      Halt(1);
    end;
  end;

  FormLogin := TFormLogin.Create(Application);
  try
    if FormLogin.ShowModal = mrOk then
    begin
      Application.CreateForm(TFormMain, FormMain);
      Application.Run;
    end;
  finally
    FormLogin.Free;
    FormLogin := nil;
  end;
end.
