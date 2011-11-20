unit formMain;

interface

uses
  SysUtils, Types, Classes, Variants, QTypes, QGraphics, QControls, QForms, 
  QDialogs, QStdCtrls, IdBaseComponent, IdComponent, IdTCPConnection,
  IdTCPClient, IdFTP, QComCtrls, QExtCtrls, QButtons, QDBCtrls, QDBLogDlg,
  httpapp;

type
  TfrmMain = class(TForm)
    IdFTP: TIdFTP;
    PageControl: TPageControl;
    tabIntro: TTabSheet;
    tabVerificacao: TTabSheet;
    Label1: TLabel;
    Panel1: TPanel;
    Label2: TLabel;
    Label3: TLabel;
    lbSoftware: TLabel;
    lbVersao: TLabel;
    tabConfirma: TTabSheet;
    tabDownload: TTabSheet;
    tabFinaliza: TTabSheet;
    Label4: TLabel;
    btnNext: TBitBtn;
    Label5: TLabel;
    lbEmpresa: TLabel;
    Label7: TLabel;
    lbPasta: TLabel;
    Label6: TLabel;
    ProgressBar1: TProgressBar;
    StatusBar: TStatusBar;
    lbDownload: TLabel;
    ProgressBarParcial: TProgressBar;
    ProgressBarTotal: TProgressBar;
    Label9: TLabel;
    memoLista: TMemo;
    lbRemoto1: TLabel;
    lbRemoto: TLabel;
    lbLocal1: TLabel;
    lbLocal: TLabel;
    Label8: TLabel;
    procedure btnNextClick(Sender: TObject);
    procedure PageControlChange(Sender: TObject);
    procedure IdFTPConnected(Sender: TObject);
    procedure IdFTPDisconnected(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure IdFTPStatus(ASender: TObject; const AStatus: TIdStatus;
      const AStatusText: String);
    procedure IdFTPWork(Sender: TObject; AWorkMode: TWorkMode;
      const AWorkCount: Integer);
    procedure IdFTPWorkBegin(Sender: TObject; AWorkMode: TWorkMode;
      const AWorkCountMax: Integer);
    procedure IdFTPWorkEnd(Sender: TObject; AWorkMode: TWorkMode);
    procedure IdFTPAfterGet(ASender: TObject; VStream: TStream);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    PodeAvancar:  boolean;
    Path, Empresa, Software:  string;
    hostname, rootdir, login, password: string;
    majorversion, minorversion: integer;
    nmajorversion, nminorversion: integer;
    //Indica se o programa deve fechar
    sair: boolean;
    //Indica se o arquivo sendo descarregado já chegou
    chegou :Boolean;

    //Arquivo que deve ser executado ao acabarem os downloads
    updateAppPath:  string;
    //Lista de arquivos a serem descarregados da internet
    FileList: TStringList;
    pathlocal, pathremoto:  string;
  public
    { Public declarations }
    function CreateRecursiveDir(pasta:  string): Boolean;
    procedure GravarLogin(user, pass: string);
  end;

var
  frmMain: TfrmMain;

const
  CONFIGFILE = '../data/version.cfg';
  REMOTECONFIGFILE='filelist.txt';

implementation

{$R *.xfm}

uses windows, funcoes;

procedure TfrmMain.btnNextClick(Sender: TObject);
begin
  if sair = true then close;
  if (PageControl.ActivePageIndex<PageControl.PageCount-1) and (PodeAvancar) then
    PageControl.ActivePageIndex := PageControl.ActivePageIndex+1;
end;

procedure TfrmMain.IdFTPConnected(Sender: TObject);
begin
  StatusBar.SimpleText := 'Conectado.   HOST: '+idftp.Host;
end;

procedure TfrmMain.IdFTPDisconnected(Sender: TObject);
begin
  StatusBar.SimpleText := 'Desconectado.   HOST: '+idftp.Host;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  stltemp: TStringList;
begin
  FileList:= TStringList.Create;
  sair:=False;
  PodeAvancar := True;
  PageControl.Style := tsNoTabs;
  PageControl.ActivePageIndex := 0;
  //Carrega opções do arquivo de configuração
  Path    :='';
  Empresa :='';
  Software:='';
  hostname:='';
  rootdir:='';
  login:='';
  password:='';
  majorversion:=0;
  minorversion:=0;
  stltemp := TStringList.Create;
  try
    stltemp.LoadFromFile(ExtractFilePath(Application.ExeName)+CONFIGFILE);
    Path    :=  ExtractFilePath(Application.ExeName);

    if (trim(stltemp.Values['MAJORVERSION'])='') or
      (trim(stltemp.Values['MINORVERSION'])='') or
      (trim(stltemp.Values['EMPRESA'])='') or
      (trim(stltemp.Values['HOSTNAME'])='') or
      (trim(stltemp.Values['ROOTDIR'])='') or
      {(trim(stltemp.Values['LOGIN'])='') or
      (trim(stltemp.Values['PASSWORD'])='') or}
      (trim(stltemp.Values['SOFTWARE'])='') then begin
      //beep;
      ShowMessage('Formato inválido do arquivo de versão de software! Não será possível utilizar a atualização automática!');
      sair := True;
      exit;
    end;

    Empresa :=  trim(stltemp.Values['EMPRESA']);
    Software:=  trim(stltemp.Values['SOFTWARE']);
    majorversion := StrToInt(trim(stltemp.Values['MAJORVERSION']));;
    minorversion := StrToInt(trim(stltemp.Values['MINORVERSION']));;
    hostname := trim(stltemp.Values['HOSTNAME']);
    rootdir := trim(stltemp.Values['ROOTDIR']);
    login := trim(stltemp.Values['LOGIN']);
    password := Desencriptar(trim(stltemp.Values['PASSWORD']));
    lbEmpresa.Caption  := Empresa;
    lbSoftware.Caption := Software;
    lbPasta.Caption    := Path;
    lbVersao.Caption   := IntToStr(majorversion)+'.'+IntToStr(minorversion);

{**}if (login = '') or (password = '') then
    begin
      RemoteLoginDialog(login, password);
      GravarLogin(login,password);
    end;
    //ATUALIZAR: Se a senha ou o login estiverem em branco, deve-se pedir
    //o login e a senha para o usuário
  except
    //beep;
    ShowMessage('Erro ao carregar opções de configuração! Não será possível fazer atualização automática.');
    sair := true;
    raise;
    exit;
  end;
  stltemp.Destroy;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  if sair = true then close;
end;

procedure TfrmMain.IdFTPStatus(ASender: TObject; const AStatus: TIdStatus;
  const AStatusText: String);
begin
  StatusBar.SimpleText := AStatusText;
end;

procedure TfrmMain.PageControlChange(Sender: TObject);
var
  stltemp:    TStringList;
  streamTemp: TStringStream;
  atual:  boolean;
  i, j:  integer;
  localfile, remotefile:  string;
begin
  stltemp := TStringList.Create;
  streamTemp := TStringStream.Create('');
  if PageControl.ActivePage = tabVerificacao then begin
    if MessageDlg('Seu computador está atrás de um Firewall? Clique em "SIM" caso se conecte à internet por um firewall de rede.',
            mtConfirmation, [mbYes, mbNo], 0, mbYes) = mrYes then begin
      IdFTP.Passive := True;
    end else
      IdFTP.Passive := False;
    ProgressBar1.Position := 0;
    try
      idftp.Host := hostname;
      idftp.Username := login;
      idftp.Password := password;
      idftp.Connect;
//      idftp.Login;
      idftp.ChangeDir(rootdir+'/'+Empresa);
      chegou := False;
      idftp.Get(REMOTECONFIGFILE, streamTemp);
      //A variável chegou é tornada true no evento IDFTP.AfterGet
      while not chegou do
        Application.ProcessMessages;
      stltemp.Text := streamTemp.DataString;
      if (trim(stltemp.Values['MAJORVERSION'])='') or
        (trim(stltemp.Values['MINORVERSION'])='') then begin
        //beep;
        ShowMessage('Erro ao ler versão do software na internet! Contate o desenvolvedor!');
        sair := true;
      end;
      nmajorversion := StrToInt(trim(stltemp.Values['MAJORVERSION']));
      nminorversion := StrToInt(trim(stltemp.Values['MINORVERSION']));
      atual := False;
      if (nmajorversion>majorversion) then begin
        atual := true;
      end else if nmajorversion=majorversion then begin
        if nminorversion>minorversion then
          atual := true;
      end;
      if not atual then begin
        //beep;
        ShowMessage('O software atual já está atualizado! Nenhuma atualização disponível na internet. O Easy Update irá fechar agora.');
        sair := true;
      end;
      updateAppPath := trim(stltemp.Values['EXECFILE']);
      if updateAppPath='' then begin
        //beep;
        ShowMessage('Erro no servidor. Executável de atualização não encontrado!');
        sair := true;
      end;
      FileList.Clear;
      //Retira strings incorretas
      stltemp.Strings[stltemp.IndexOfName('EXECFILE')] := '';
      stltemp.Strings[stltemp.IndexOfName('MAJORVERSION')] := '';
      stltemp.Strings[stltemp.IndexOfName('MINORVERSION')] := '';
      filelist.Text := trim(stltemp.Text);
      //Adiciona atualizador à lista de arquivos a serem descarregados
      filelist.Add(updateAppPath+','+updateAppPath);
      filelist.Add('version.cfg,version.cfg');
      //passa o arquivo filelist.txt, para que o programa update.exe saiba com quais arquivos trabalhar
{**}  filelist.Add(REMOTECONFIGFILE+', '+REMOTECONFIGFILE);
      btnNextClick(Sender);
    except
      //beep;
      ShowMessage('Erro ao achar configurações no servidor. A Atualização automática falhou!');
      sair := true;
      raise;
    end;
  end else if PageControl.ActivePage = tabConfirma then begin
    memoLista.Clear;
    pathlocal  := ExtractFilePath(Application.ExeName)+'../download/';
    pathremoto := rootdir+'/'+Empresa+'/';
    memoLista.Lines.Add('Path local:  ' + pathlocal);
    memoLista.Lines.Add('Path remoto: ' + pathremoto);
    for i := 0 to filelist.Count-1 do  begin
      if trim(filelist.Strings[i])='' then continue;//Pula linhas em branco
      stltemp.CommaText := trim(filelist.Strings[i]);
      if (stltemp.count<=0) then begin
        //beep;
        ShowMessage('Erro ao receber lista de arquivos! "filelist.txt" Inválido! Contate o desenvolvedor!');
        sair := True;
        break;
      end;
      if (stltemp.count<=1) then begin
        stltemp.Strings[1]:=trim(stltemp.Strings[0]);
      end;
      memoLista.Lines.Add('Arquivo remoto: "'+stltemp.Strings[1]+'" arquivo local: "'+stltemp.Strings[0]+'"');
    end;
  end else if PageControl.ActivePage = tabDownload then begin
    PodeAvancar := false;
    ProgressBarTotal.Max := filelist.Count;
    ProgressBarTotal.Position := 0;
    for i := 0 to filelist.Count-1 do  begin
      if trim(filelist.Strings[i])='' then continue;//Pula linhas em branco
      stltemp.CommaText := trim(filelist.Strings[i]);
      if (stltemp.count<=0) then begin
        //beep;
        ShowMessage('Erro ao receber lista de arquivos! "filelist.txt" Inválido! Contate o desenvolvedor!');
        sair := True;
        break;
      end;
      if (stltemp.count<=1) then begin
        stltemp.Strings[1]:=trim(stltemp.Strings[0]);
      end;
      remotefile := pathremoto+trim(stltemp.Strings[1]);
      localfile  := pathlocal+trim(stltemp.Strings[0]);
      for j := 0 to length(localfile) do begin
        if localfile[j]='/' then
          localfile[j]:='\';
      end;
      lbRemoto.Caption := remotefile;
      lbLocal.Caption  := localfile;
      if not DirectoryExists(extractFilePath(localfile)) then
        if not CreateRecursiveDir(extractFilePath(localfile)) then
          raise Exception.Create('Não pude criar pasta '+extractFilePath(localfile));
      idftp.ChangeDir('/');
      chegou := false;
//      ShowMessage('/'+DosPathToUnixPath(extractFilePath(UnixPathToDosPath(remoteFile))));
//      ShowMessage(ExtractFileName(UnixPathToDosPath(remotefile)));
      {
      stltemp.Delimiter := '/';
      stltemp.DelimitedText := remotefile;
      //Vai para a raiz
      while (idftp.RetrieveCurrentDir <> '/') do
        idftp.ChangeDirUp;
      for j := 0 to stltemp.Count -1 do begin
        idftp.ChangeDir(idftp.RetrieveCurrentDir+stltemp.Strings[j]);
      end;
      }
      Application.ProcessMessages;
      idftp.Get(remotefile, localfile, true);

      while not chegou=true do
        Application.ProcessMessages;
    end;
    PodeAvancar := True;
    lbDownload.Caption := 'Download concluído! Clique em "SEGUIR" para concluir a instalação!';
  end else if PageControl.ActivePage = tabFinaliza then begin
    winexec(PAnsiChar(pathlocal+updateAppPath), SW_SHOW); //SW_HIDE
    sair := true;
    close;
  end else begin
  end;
  stltemp.Destroy;
  streamTemp.Destroy;
  if sair = true then close;
end;


procedure TfrmMain.IdFTPWork(Sender: TObject; AWorkMode: TWorkMode;
  const AWorkCount: Integer);
begin
  ProgressBar1.Position := AWorkCount;
  ProgressBarParcial.Position := AWorkCount;
end;

procedure TfrmMain.IdFTPWorkBegin(Sender: TObject; AWorkMode: TWorkMode;
  const AWorkCountMax: Integer);
begin
  ProgressBar1.Max := AWorkCountMax;
  ProgressBarParcial.Max := AWorkCountMax;
  ProgressBarParcial.Position := 0;
end;

procedure TfrmMain.IdFTPWorkEnd(Sender: TObject; AWorkMode: TWorkMode);
begin
  ProgressBar1.Position := ProgressBar1.Max-1;
  ProgressBarParcial.Position := ProgressBarParcial.Max-1;
end;

procedure TfrmMain.IdFTPAfterGet(ASender: TObject; VStream: TStream);
begin
  chegou := True;
  ProgressBarTotal.Position:=ProgressBarTotal.Position+1;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FileList.Destroy;
end;

function TfrmMain.CreateRecursiveDir(pasta:  string): boolean;
var
  stltemp:  TStringList;
  i, j: integer;
  dir : string;
  diratual : string;
begin
  stltemp := TStringList.Create;
  stltemp.Delimiter := '\';
  for i := 1 to length(pasta) do begin
    if pasta[i]=' ' then
      pasta[i]:='#';
  end;
  stltemp.DelimitedText := pasta;
  dir := '';
  Result := True;
  for i := 0 to stltemp.Count -1 do begin
    diratual := stltemp.Strings[i];
    for j := 1 to length(diratual) do begin
      if diratual[j]='#' then
        diratual[j]:=' ';
    end;
    dir := dir + trim(diratual);
    //Cria pastas recursivamente
    if not DirectoryExists(dir) then
      if not CreateDir(dir) then begin
        Result := False;
        exit;
      end;
    dir := dir + '\';
  end;
  stltemp.Destroy;
end;

procedure TfrmMain.GravarLogin(user, pass: string);
var stltemp: TStringList;
begin
  stltemp := TStringList.Create;
  stltemp.LoadFromFile(CONFIGFILE);
  stltemp.Strings[stltemp.IndexOfName('LOGIN')] := 'LOGIN='+user;
  stltemp.Strings[stltemp.IndexOfName('PASSWORD')] := 'PASSWORD='+Encriptar(pass);
  stltemp.SaveToFile(CONFIGFILE);
  stltemp.Destroy;
end;

end.
