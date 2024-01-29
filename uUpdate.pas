unit uUpdate;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ExtCtrls, Vcl.Imaging.GIFImg, Vcl.StdCtrls, ZAbstractConnection,
  ZConnection, IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,
  IdExplicitTLSClientServerBase, IdFTP, Data.DB, ZAbstractRODataset,
  ZAbstractDataset, ZDataset, BackgroundWorker, IOUtils, ShellApi;

type
  TfrmUpdate = class(TForm)
    img1: TImage;
    Label1: TLabel;
    IdFTP1: TIdFTP;
    tmrUpdate: TTimer;
    con1: TZConnection;
    qUpdate: TZQuery;
    qUpdateID: TIntegerField;
    qUpdateFILE_NAME: TWideStringField;
    qUpdateSIZE: TLargeintField;
    qUpdateDATE_MODIFIED: TDateTimeField;
    mmo1: TMemo;
    bg1: TBackgroundWorker;
    lblProses: TLabel;
    qTgl: TZQuery;
    qTglTGL: TDateTimeField;
    qSetup: TZQuery;
    qLokal: TZQuery;
    btnClose: TButton;
    tmrBtn: TTimer;
    procedure FormShow(Sender: TObject);
    procedure bg1Work(Worker: TBackgroundWorker);
    procedure bg1WorkComplete(Worker: TBackgroundWorker; Cancelled: Boolean);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnCloseClick(Sender: TObject);
    procedure tmrBtnTimer(Sender: TObject);
  private
    { Private declarations }
    vClose: Integer;
    vDownloadLokal: Boolean;
    vFileDownloadLokal, LServer, LDatabase, LDirServer: string;
    function updateExe(): Boolean;
    function updateTemplateInv(): Boolean;
  public
    { Public declarations }
  end;

var
  frmUpdate: TfrmUpdate;

implementation

{$R *.dfm}

procedure TfrmUpdate.bg1Work(Worker: TBackgroundWorker);
var
  vServer, vPort: string;
  vSearchPort: Integer;
  searchResult: TSearchRec;
  directoryPath: string;
//  vFilePath: string;
begin
  vClose := 3;
  {
  vFilePath := ExtractFilePath(Application.ExeName);
  if (FileExists(vFilePath + '7soft.txt')) then
  begin
    mmo1.Lines.LoadFromFile(ExtractFilePath(Application.ExeName) + '7soft.txt');
  end
  else
  begin
    ShowMessage('File path tidak ditemukan');
    Application.Terminate;
  end;
  }

  vSearchPort := pos(':', LServer);
  if vSearchPort = 0 then
  begin
    vServer := LServer;
    vPort := '3306';
  end
  else
  begin
    vServer := copy(LServer, 1, vSearchPort - 1);
    vPort := copy(LServer, vSearchPort + 1, length(LServer));
  end;

  lblProses.Caption := 'Connecting database...';
  Sleep(1000);

  try
    con1.HostName := vServer;
    con1.Password := '73fangfang';
    con1.Port := StrToInt(vPort);
    con1.Database := LDatabase;
    con1.LibraryLocation := ExtractFilePath(Application.ExeName) + 'libmySQL.dll';
    con1.Connect;
  except
    on E: Exception do
    begin
      lblProses.Caption := e.Message;
      Worker.AcceptCancellation;
    end;
  end;

  if not DirectoryExists(LDirServer) then
  begin
    qSetup.Active := True;
    if (qSetup.FindField('HOST_FTP') = nil) and (qSetup.FindField('USER_FTP') = nil) and (qSetup.FindField('PASWORD_FTP') = nil) and (qSetup.FindField('PORT_FTP') = nil) then
    begin
      lblProses.Caption := 'Setting setup ada kesalahan';
      Sleep(1000);
      Worker.AcceptCancellation;
      Exit;
    end;
  end
  else
  begin
    directoryPath := LDirServer;
    qLokal.Close;
    qLokal.Open;
    if FindFirst(directoryPath + '\*.*', faAnyFile, searchResult) = 0 then
    begin
      try
        repeat
        // Display the file name
          if (searchResult.Attr and faDirectory) = 0 then
          begin
            qLokal.Append;
            qLokal.FieldByName('FILE_NAME').AsString := searchResult.Name;
            qLokal.FieldByName('DATE_MODIFIED').AsDateTime := FileDateToDateTime(searchResult.Time);
            qLokal.Post;
          end;
        until FindNext(searchResult) <> 0;
      finally
      // Close the search handle
        FindClose(searchResult);
      end;
    end;

  end;

  if not updateExe then
    Worker.AcceptCancellation;

  Worker.ReportProgress(100);
end;

function TfrmUpdate.updateTemplateInv(): Boolean;
begin
  if not IdFTP1.Connected then
  begin
    IdFTP1.Host := qSetup.fieldbyname('HOST_FTP').AsString;
    IdFTP1.Username := qSetup.fieldbyname('USER_FTP').AsString;
    IdFTP1.Password := qSetup.fieldbyname('PASWORD_FTP').AsString;
    IdFTP1.Port := qSetup.fieldbyname('PORT_FTP').AsInteger;
    IdFTP1.Port := 21;
    IdFTP1.Connect();
    Sleep(1000);
  end;
  IdFTP1.ChangeDir('\');
  IdFTP1.List('*.*', True);
end;

function TfrmUpdate.updateExe(): Boolean;
var
  fileDate: Integer;
  vFilePath, vFileName, vFileDownload: string;
  vDate1: string;
begin
  if ParamCount = 0 then
  begin
    Result := False;
    exit;
  end;
  vFilePath := ExtractFilePath(Application.ExeName);
  vFileDownload := vFilePath + ParamStr(2) + '.exe';
  fileDate := FileAge(vFileDownload);
  vDate1 := FormatDateTime('dd-mm-yyyy hh:nn:ss', FileDateToDateTime(fileDate));
  vFileName := ParamStr(1) + '.exe';
  if DirectoryExists(mmo1.Lines[49]) then
  begin
//    ShowMessage(FormatDateTime('dd-mm-yyyy hh:nn:ss', qLokal.FieldByName('DATE_MODIFIED').AsDateTime));
    qLokal.Filtered := False;
    qLokal.Filter := 'FILE_NAME=' + QuotedStr(ParamStr(2) + '.exe') + ' AND DATE_MODIFIED > ' + QuotedStr(vDate1);
    qLokal.Filtered := True;
  end
  else
  begin
    try
      if not IdFTP1.Connected then
      begin
        lblProses.Caption := 'Connecting server...';
        IdFTP1.Host := qSetup.fieldbyname('HOST_FTP').AsString;
        IdFTP1.Username := qSetup.fieldbyname('USER_FTP').AsString;
        IdFTP1.Password := qSetup.fieldbyname('PASWORD_FTP').AsString;
        IdFTP1.Port := qSetup.fieldbyname('PORT_FTP').AsInteger;
        IdFTP1.Connect();
        Sleep(1000);
      end;
      IdFTP1.ChangeDir('\');
      IdFTP1.List('*.*', True);
    except
      on E: Exception do
      begin
        lblProses.Caption := e.Message;
        Sleep(1000);
        IdFTP1.Disconnect;
        Result := False;
        exit;
      end;
    end;

  end;
  if ParamCount = 2 then
  begin
    vFileDownload := ParamStr(2);
    qUpdate.SQL.Text := StringReplace(UpperCase(qUpdate.SQL.Text), '&KONDISI', ' AND FILE_NAME=' + QuotedStr(vFileDownload + '.exe'), [])
  end
  else
    qUpdate.SQL.Text := StringReplace(UpperCase(qUpdate.SQL.Text), '&KONDISI', '', []);

  if not DirectoryExists(mmo1.Lines[49]) then
  begin
    qUpdate.Active := True;
    qUpdate.First;
  end;

  qTgl.Active := True;
  lblProses.Caption := 'Downloading application...';
  Sleep(1000);

  if qLokal.Active then
  begin
    if qLokal.RecordCount > 0 then
    begin
      if not TDirectory.Exists(vFilePath + 'old') then
        TDirectory.CreateDirectory(vFilePath + 'old');
      CopyFile(pchar(vFilePath + vFileName), pchar(vFilePath + 'old\' + FormatDateTime('yyyymmddhhnn', qTglTGL.AsDateTime) + '.exe'), false);
      DeleteFile(vFilePath + vFileName);
      CopyFile(pchar(mmo1.Lines[49] + qLokal.FieldByName('FILE_NAME').AsString), PChar(ExtractFilePath(Application.ExeName) + vFileName), False);
    end;
  end
  else if qUpdate.Active then
  begin
    if qUpdate.RecordCount > 0 then
    begin
      if not TDirectory.Exists(vFilePath + 'old') then
        TDirectory.CreateDirectory(vFilePath + 'old');
      CopyFile(pchar(vFilePath + vFileName), pchar(vFilePath + 'old\' + FormatDateTime('yyyymmddhhnn', qTglTGL.AsDateTime) + '.exe'), false);
      DeleteFile(vFilePath + vFileName);
      IdFTP1.Get(qUpdateFILE_NAME.AsString, ExtractFilePath(Application.ExeName) + vFileName);
    end
  end
  else
  begin
    lblProses.Caption := 'Failed download application...';
    sleep(1000);
  end;

  lblProses.Caption := 'Opening application...';
  Sleep(1000);
  Result := True;
end;

procedure TfrmUpdate.bg1WorkComplete(Worker: TBackgroundWorker; Cancelled: Boolean);
begin
  if not Cancelled then
  begin
    if IdFTP1.Connected then
      IdFTP1.Disconnect;
    if qLokal.Active then
      qLokal.Close;
    ShellExecute(0, 'open', pchar(ExtractFilePath(Application.ExeName) + ParamStr(1)), nil, nil, SW_NORMAL);
  end;
  btnClose.Visible := True;
  tmrBtn.Enabled := True;
//  Application.Terminate;
end;

procedure TfrmUpdate.btnCloseClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TfrmUpdate.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if bg1.IsWorking then
  begin
    bg1.Cancel;
    bg1.WaitFor;
  end;
end;

procedure TfrmUpdate.FormShow(Sender: TObject);
var
  vFilePath: string;
begin

  (img1.Picture.Graphic as TGIFImage).Animate := True;
  (img1.Picture.Graphic as TGIFImage).AnimationSpeed := 80;
  vDownloadLokal := False;

  // pindah read memo sebelum bg1work
  vFilePath := ExtractFilePath(Application.ExeName);
  if (FileExists(vFilePath + '7soft.txt')) then
  begin
    mmo1.Lines.LoadFromFile(ExtractFilePath(Application.ExeName) + '7soft.txt');
  end
  else
  begin
    ShowMessage('File path tidak ditemukan');
    Application.Terminate;
  end;

  LServer := mmo1.Lines[0];
  LDatabase := mmo1.Lines[1];
  LDirServer := mmo1.Lines[49];

  bg1.Execute;
end;

procedure TfrmUpdate.tmrBtnTimer(Sender: TObject);
begin
  vClose := vClose - 1;
  btnClose.Caption := 'Close (' + IntToStr(vClose) + 's)';
  if vClose < 0 then
  begin
    tmrBtn.Enabled := False;
    PostMessage(Self.Handle, wm_close, 0, 0);
  end;

end;

end.

