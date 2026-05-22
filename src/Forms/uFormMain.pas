unit uFormMain;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, Dialogs, Menus, StdCtrls,
  ExtCtrls, ComCtrls, Grids, Graphics;

type

  { TFormMain }

  TFormMain = class(TForm)
    MainMenu1: TMainMenu;
    MenuFile: TMenuItem;
    MenuItemBackup: TMenuItem;
    MenuItemRestore: TMenuItem;
    MenuItemSeed: TMenuItem;
    N1: TMenuItem;
    MenuItemLogout: TMenuItem;
    MenuItemExit: TMenuItem;
    MenuSession: TMenuItem;
    MenuItemOpenSession: TMenuItem;
    MenuItemReconcile: TMenuItem;
    MenuTransactions: TMenuItem;
    MenuItemNewTxn: TMenuItem;
    MenuMaster: TMenuItem;
    MenuItemCustomers: TMenuItem;
    MenuItemUtang: TMenuItem;
    MenuItemFeeRules: TMenuItem;
    MenuItemUsers: TMenuItem;
    MenuReports: TMenuItem;
    MenuItemReports: TMenuItem;
    MenuItemAuditLog: TMenuItem;
    StatusBar1: TStatusBar;
    PanelTop: TPanel;
    LabelHeader: TLabel;
    LabelSession: TLabel;
    PanelDash: TPanel;
    GroupBoxSession: TGroupBox;
    LabelStartingCash: TLabel;
    LabelStartingWallet: TLabel;
    LabelExpectedCash: TLabel;
    LabelExpectedWallet: TLabel;
    LabelFeesEarned: TLabel;
    LabelTxnCount: TLabel;
    LabelStartingCashV: TLabel;
    LabelStartingWalletV: TLabel;
    LabelExpectedCashV: TLabel;
    LabelExpectedWalletV: TLabel;
    LabelFeesEarnedV: TLabel;
    LabelTxnCountV: TLabel;
    PanelButtons: TPanel;
    ButtonOpenSession: TButton;
    ButtonNewTxn: TButton;
    ButtonReconcile: TButton;
    ButtonCustomers: TButton;
    ButtonUtang: TButton;
    ButtonReports: TButton;
    StringGridTxns: TStringGrid;
    LabelTxnHeader: TLabel;
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure MenuItemOpenSessionClick(Sender: TObject);
    procedure MenuItemNewTxnClick(Sender: TObject);
    procedure MenuItemCustomersClick(Sender: TObject);
    procedure MenuItemUtangClick(Sender: TObject);
    procedure MenuItemFeeRulesClick(Sender: TObject);
    procedure MenuItemUsersClick(Sender: TObject);
    procedure MenuItemReconcileClick(Sender: TObject);
    procedure MenuItemReportsClick(Sender: TObject);
    procedure MenuItemAuditLogClick(Sender: TObject);
    procedure MenuItemBackupClick(Sender: TObject);
    procedure MenuItemRestoreClick(Sender: TObject);
    procedure MenuItemSeedClick(Sender: TObject);
    procedure MenuItemLogoutClick(Sender: TObject);
    procedure MenuItemExitClick(Sender: TObject);
  private
    procedure RefreshDashboard;
    procedure ApplyRolePermissions;
  public
    procedure FullRefresh;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.lfm}

uses
  uDM, uSession, uModels, uSessionService, uTransactionService, uAuthService,
  uBackupService, uSeedService,
  uFormSession, uFormTransaction, uFormCustomers, uFormUtang,
  uFormFeeRules, uFormUsers, uFormReconciliation, uFormReports, uFormAuditLog;

procedure TFormMain.FormShow(Sender: TObject);
begin
  ApplyRolePermissions;
  FullRefresh;
end;

procedure TFormMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  TAuthService.Logout;
end;

procedure TFormMain.ApplyRolePermissions;
begin
  MenuItemUsers.Enabled := AppState.CanManageUsers;
  MenuItemFeeRules.Enabled := AppState.CanEditFees;
  MenuItemReconcile.Enabled := AppState.CanReconcile;
  ButtonReconcile.Enabled := AppState.CanReconcile;
  MenuItemNewTxn.Enabled := AppState.CanCreateTransactions;
  ButtonNewTxn.Enabled := AppState.CanCreateTransactions;
  MenuItemOpenSession.Enabled := AppState.CanCreateTransactions;
  ButtonOpenSession.Enabled := AppState.CanCreateTransactions;
end;

procedure TFormMain.FullRefresh;
begin
  RefreshDashboard;
end;

procedure TFormMain.RefreshDashboard;
var
  Sess: TSessionRec;
  ExpCash, ExpWallet, Fees: Double;
  Txns: TArray<TTransaction>;
  I, RowIdx: Integer;
  HasOpen: Boolean;
begin
  HasOpen := TSessionService.GetOpenSession(Sess);
  if HasOpen then
  begin
    AppState.CurrentSessionId := Sess.Id;
    LabelSession.Caption := Format('Open Session #%d - %s (since %s)',
      [Sess.Id, FormatDateTime('yyyy-mm-dd', Sess.SessionDate),
       FormatDateTime('hh:nn', Sess.OpenedAt)]);

    TSessionService.ExpectedTotals(Sess.Id, ExpCash, ExpWallet, Fees);
    LabelStartingCashV.Caption := FormatFloat('PHP #,##0.00', Sess.StartingCash);
    LabelStartingWalletV.Caption := FormatFloat('PHP #,##0.00', Sess.StartingWallet);
    LabelExpectedCashV.Caption := FormatFloat('PHP #,##0.00', ExpCash);
    LabelExpectedWalletV.Caption := FormatFloat('PHP #,##0.00', ExpWallet);
    LabelFeesEarnedV.Caption := FormatFloat('PHP #,##0.00', Fees);

    Txns := TTransactionService.ListBySession(Sess.Id);
    LabelTxnCountV.Caption := IntToStr(Length(Txns));

    StringGridTxns.RowCount := Length(Txns) + 1;
    StringGridTxns.ColCount := 7;
    StringGridTxns.Cells[0, 0] := 'ID';
    StringGridTxns.Cells[1, 0] := 'Time';
    StringGridTxns.Cells[2, 0] := 'Type';
    StringGridTxns.Cells[3, 0] := 'Amount';
    StringGridTxns.Cells[4, 0] := 'Fee';
    StringGridTxns.Cells[5, 0] := 'Ref #';
    StringGridTxns.Cells[6, 0] := 'Status';
    RowIdx := 1;
    for I := 0 to High(Txns) do
    begin
      StringGridTxns.Cells[0, RowIdx] := IntToStr(Txns[I].Id);
      StringGridTxns.Cells[1, RowIdx] := FormatDateTime('hh:nn:ss', Txns[I].TxnDateTime);
      StringGridTxns.Cells[2, RowIdx] := TxnTypeToStr(Txns[I].TxnType);
      StringGridTxns.Cells[3, RowIdx] := FormatFloat('#,##0.00', Txns[I].Amount);
      StringGridTxns.Cells[4, RowIdx] := FormatFloat('#,##0.00', Txns[I].Fee);
      StringGridTxns.Cells[5, RowIdx] := Txns[I].ReferenceNo;
      if Txns[I].IsVoid then
        StringGridTxns.Cells[6, RowIdx] := 'VOID'
      else
        StringGridTxns.Cells[6, RowIdx] := 'OK';
      Inc(RowIdx);
    end;
  end
  else
  begin
    AppState.CurrentSessionId := 0;
    LabelSession.Caption := 'No open session. Click "Open Session" to start.';
    LabelStartingCashV.Caption := '-';
    LabelStartingWalletV.Caption := '-';
    LabelExpectedCashV.Caption := '-';
    LabelExpectedWalletV.Caption := '-';
    LabelFeesEarnedV.Caption := '-';
    LabelTxnCountV.Caption := '-';
    StringGridTxns.RowCount := 2;
    StringGridTxns.Cells[0, 0] := 'ID';
    StringGridTxns.Cells[1, 0] := 'Time';
    StringGridTxns.Cells[2, 0] := 'Type';
    StringGridTxns.Cells[3, 0] := 'Amount';
    StringGridTxns.Cells[4, 0] := 'Fee';
    StringGridTxns.Cells[5, 0] := 'Ref #';
    StringGridTxns.Cells[6, 0] := 'Status';
    StringGridTxns.Cells[2, 1] := '(no transactions)';
  end;

  StatusBar1.Panels[0].Text :=
    Format('User: %s [%s]',
      [AppState.CurrentUser.FullName, RoleToStr(AppState.CurrentUser.Role)]);
  StatusBar1.Panels[1].Text := 'DB: ' + ExtractFileName(DM.DatabaseFile);
end;

procedure TFormMain.MenuItemOpenSessionClick(Sender: TObject);
begin
  if FormSession = nil then FormSession := TFormSession.Create(Self);
  FormSession.ShowModal;
  FullRefresh;
end;

procedure TFormMain.MenuItemNewTxnClick(Sender: TObject);
var
  Sess: TSessionRec;
begin
  if not TSessionService.GetOpenSession(Sess) then
  begin
    MessageDlg('Open a session first.', mtWarning, [mbOk], 0);
    Exit;
  end;
  if FormTransaction = nil then FormTransaction := TFormTransaction.Create(Self);
  FormTransaction.PrepareForNew(Sess.Id);
  FormTransaction.ShowModal;
  FullRefresh;
end;

procedure TFormMain.MenuItemCustomersClick(Sender: TObject);
begin
  if FormCustomers = nil then FormCustomers := TFormCustomers.Create(Self);
  FormCustomers.ShowModal;
end;

procedure TFormMain.MenuItemUtangClick(Sender: TObject);
begin
  if FormUtang = nil then FormUtang := TFormUtang.Create(Self);
  FormUtang.ShowModal;
end;

procedure TFormMain.MenuItemFeeRulesClick(Sender: TObject);
begin
  if FormFeeRules = nil then FormFeeRules := TFormFeeRules.Create(Self);
  FormFeeRules.ShowModal;
end;

procedure TFormMain.MenuItemUsersClick(Sender: TObject);
begin
  if FormUsers = nil then FormUsers := TFormUsers.Create(Self);
  FormUsers.ShowModal;
end;

procedure TFormMain.MenuItemReconcileClick(Sender: TObject);
var
  Sess: TSessionRec;
begin
  if not TSessionService.GetOpenSession(Sess) then
  begin
    MessageDlg('No open session to reconcile.', mtWarning, [mbOk], 0);
    Exit;
  end;
  if FormReconciliation = nil then FormReconciliation := TFormReconciliation.Create(Self);
  FormReconciliation.PrepareForSession(Sess.Id);
  FormReconciliation.ShowModal;
  FullRefresh;
end;

procedure TFormMain.MenuItemReportsClick(Sender: TObject);
begin
  if FormReports = nil then FormReports := TFormReports.Create(Self);
  FormReports.ShowModal;
end;

procedure TFormMain.MenuItemAuditLogClick(Sender: TObject);
begin
  if FormAuditLog = nil then FormAuditLog := TFormAuditLog.Create(Self);
  FormAuditLog.ShowModal;
end;

procedure TFormMain.MenuItemBackupClick(Sender: TObject);
var
  SaveDlg: TSaveDialog;
  DestFile: string;
begin
  SaveDlg := TSaveDialog.Create(Self);
  try
    SaveDlg.Title := 'Backup database';
    SaveDlg.Filter := 'SQLite DB (*.db)|*.db|All files|*.*';
    SaveDlg.DefaultExt := 'db';
    SaveDlg.InitialDir := TBackupService.DefaultBackupFolder;
    SaveDlg.FileName := ExtractFileName(TBackupService.MakeTimestampedFilename);
    if SaveDlg.Execute then
    begin
      DestFile := SaveDlg.FileName;
      TBackupService.Backup(DestFile);
      MessageDlg('Backup created: ' + DestFile, mtInformation, [mbOk], 0);
    end;
  finally
    SaveDlg.Free;
  end;
end;

procedure TFormMain.MenuItemRestoreClick(Sender: TObject);
var
  OpenDlg: TOpenDialog;
begin
  if not AppState.CanManageUsers then
  begin
    MessageDlg('Only Owner can restore.', mtError, [mbOk], 0);
    Exit;
  end;
  if MessageDlg('Restore will replace the current database. Continue?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  OpenDlg := TOpenDialog.Create(Self);
  try
    OpenDlg.Title := 'Restore database from backup';
    OpenDlg.Filter := 'SQLite DB (*.db)|*.db|All files|*.*';
    OpenDlg.InitialDir := TBackupService.DefaultBackupFolder;
    if OpenDlg.Execute then
    begin
      TBackupService.Restore(OpenDlg.FileName);
      MessageDlg('Restored. The app will refresh.', mtInformation, [mbOk], 0);
      FullRefresh;
    end;
  finally
    OpenDlg.Free;
  end;
end;

procedure TFormMain.MenuItemSeedClick(Sender: TObject);
begin
  if MessageDlg('Seed default fee rules and sample data?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  TSeedService.SeedSampleData;
  MessageDlg('Seeding complete.', mtInformation, [mbOk], 0);
  FullRefresh;
end;

procedure TFormMain.MenuItemLogoutClick(Sender: TObject);
begin
  Close;
end;

procedure TFormMain.MenuItemExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

end.
