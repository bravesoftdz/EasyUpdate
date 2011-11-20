program EasyUpdate;

uses
  QForms,
  formMain in 'formMain.pas' {frmMain},
  funcoes in '..\..\scn_l\src\main\funcoes.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
