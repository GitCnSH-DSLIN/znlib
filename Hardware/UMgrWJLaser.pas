{*******************************************************************************
  ����: dmzn@163.com 2019-10-09
  ����: �򼯼�����WLR-711����
*******************************************************************************}
unit UMgrWJLaser;

{.$DEFINE DEBUG}
interface

uses
  Windows, Classes, SysUtils, NativeXml, IdTCPConnection, IdTCPClient, IdGlobal,
  SyncObjs, UWaitItem, ULibFun, USysLoger;

const
  cLaserDataMax             = 720 * 2;
  //�״��ɨ��180��,�ֱ���Ϊ0.5ʱ,��360����,ÿ����2���ֽ�,����720���ֽ�.
  //���ֱ���Ϊ0.25ʱ,����Ϊ720 x 2
  cLaserDataParse           = Trunc(cLaserDataMax / 2);

  cWJLaserMaxThread         = 10;
  //����߳���

  cWJLaser_Wait_Short       = 2 * 1000;
  cWJLaser_Wait_Long        = 5 * 1000;       //�̵߳ȴ�

type
  TWJLaserData = packed record
    FHead        : array[0..1] of Byte;       //֡ͷ
    FLength      : array[0..1] of Byte;       //��Ч����(��ȥ֡ͷ,֡β)
    FSerial      : array[0..1] of Byte;       //0-65535�����ۼ�
    FTimeStamp   : Integer;                   //ʱ���
    FVerifyType  : Byte;                      //У������
    FrameType    : Byte;                      //֡����
    FDeviceType  : array[0..1] of Byte;       //�豸����
    FReserved    : array[0..7] of Byte;       //Ԥ���ֽ�
    FCommand     : Byte;                      //��ָ���
    FSubCmd      : Byte;                      //��ָ���
    FParams      : array[0..1] of Byte;       //�������
    FData        : array[0..cLaserDataMax-1] of Byte;//����
    FVerify      : array[0..1] of Byte;       //У��ֵ
    FFrameEnd    : array[0..1] of Byte;       //֡β
  end;

const
  cSize_WJLaserData = SizeOf(TWJLaserData);   //���ݴ�С

type
  TWJLaserMatrix = record
    FAngle       : Single;                    //�Ƕ�
    FDistance    : Word;                      //ֱ�߾���
    Fx           : Word;                      //ˮƽ����
    Fy           : Word;                      //��ֱ����
    FHigh        : Word;                      //��ؾ���
  end;

  PWJLaserHost = ^TWJLaserHost;
  TWJLaserHost = record
    FID          : string;                    //��ʶ
    FName        : string;                    //����
    FHost        : string;                    //��ַ
    FPort        : Integer;                   //�˿�
    FTunnel      : string;                    //ͨ����
    FEnable      : Boolean;                   //�Ƿ�����
    FLocked      : Boolean;                   //�Ƿ�����
    FLastActive  : Cardinal;                  //�ϴλ

    FHighLaser        : Cardinal;             //�������������(��װ)�߶�
    FHighUnderLaser   : Cardinal;             //���������·��߶�
    FHighFrontLaser   : Cardinal;             //���������·���ͷ����߶�
    FHighBackLaser    : Cardinal;             //���������·���β����߶�
    FOffsetFrontLaser : Integer;              //���������·���ͷƫ����
    FOffsetBackLaser  : Integer;              //���������·���βƫ����
    FTruckHighMin     : Cardinal;             //����߶�(��С)
    FTruckHigh        : Cardinal;             //��ǰ����
    FTruckLong        : Cardinal;             //��ǰ����
    
    FClient      : TIdTCPClient;              //ͨ����·
    FSerial      : Word;                      //֡���к�
    FData        : TWJLaserData;              //ԭʼ����
    FDataParse   : array[0..cLaserDataParse-1] of TWJLaserMatrix; //����������
    FOptions     : TStrings;                  //����ѡ��
  end;
  TWJLaserHosts = array of TWJLaserHost;

  TWJLaserThreadType = (ttAll, ttActive);
  //�߳�ģʽ: ȫ��;ֻ���

  TWJLaserManager = class;
  TWJLaserReader = class(TThread)
  private
    FOwner: TWJLaserManager;
    //ӵ����
    FWaiter: TWaitObject;
    //�ȴ�����
    FSingleRequst: TWJLaserData;
    //��֡��ȡ����
    FActiveHost: PWJLaserHost;
    //��ǰ��ͷ
    FThreadType: TWJLaserThreadType;
    //�߳�ģʽ
  protected
    procedure DoExecute;
    procedure Execute; override;
    //ִ���߳�
    procedure ScanActiveHost(const nActive: Boolean);
    //ɨ�����
    procedure InitSingleRequst;
    //����ָ��
    function SendHostCommand(const nHost: PWJLaserHost): Boolean;
    //����ָ��
    procedure ParseLaserData(const nHost: PWJLaserHost);
    //��������
  public
    constructor Create(AOwner: TWJLaserManager; AType: TWJLaserThreadType);
    destructor Destroy; override;
    //�����ͷ�
    procedure StopMe;
    //ֹͣ�߳�
  end;

  //----------------------------------------------------------------------------
  TWJLaserEventMode = (emThread, emMain);
  //�¼�ģʽ: �߳�;������

  TWJLaserProc = procedure (const nItem: PWJLaserHost);
  TWJLaserEvent = procedure (const nItem: PWJLaserHost) of Object;

  TWJLaserManager = class(TObject)
  private
    FEnable: Boolean;
    //�Ƿ�����
    FLaserHosts: TList;
    //�������б�
    FMonitorCount: Integer;
    FThreadCount: Integer;
    //ͨѶ�߳���
    FLaserIndex: Integer;
    FLaserActive: Integer;
    //����������
    FSyncLock: TCriticalSection;
    //ͬ������
    FThreads: array[0..cWJLaserMaxThread-1] of TWJLaserReader;
    //ͨѶ����
    FOnProc: TWJLaserProc;
    FOnEvent: TWJLaserEvent;
    FEventMode: TWJLaserEventMode;
    //�¼�����
  protected
    procedure ClearHosts(const nFree: Boolean);
    //������Դ
    procedure CloseHost(const nHost: PWJLaserHost);
    //�رն�ͷ
    function FindHost(const nHost: string): Integer;
    //������ͷ
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    procedure LoadConfig(const nFile: string);
    //��������
    procedure StartService;
    procedure StopService;
    //��ͣ����
    property Lasers: TList read FLaserHosts;
    property OnCardProc: TWJLaserProc read FOnProc write FOnProc;
    property OnCardEvent: TWJLaserEvent read FOnEvent write FOnEvent;
    property EventMode: TWJLaserEventMode read FEventMode write FEventMode;
    //�������
  end;

var
  gWJLaserManager: TWJLaserManager = nil;
  //ȫ��ʹ��

implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TWJLaserManager, '����װ�����', nEvent);
end;

constructor TWJLaserManager.Create;
var nIdx: Integer;
begin
  FEnable := False;
  FEventMode := emThread;
  FThreadCount := 1;
  FMonitorCount := 1;  

  for nIdx:=Low(FThreads) to High(FThreads) do
    FThreads[nIdx] := nil;
  //xxxxx

  FLaserHosts := TList.Create;
  FSyncLock := TCriticalSection.Create;
end;

destructor TWJLaserManager.Destroy;
begin
  StopService;
  ClearHosts(True);

  FSyncLock.Free;
  inherited;
end;

procedure TWJLaserManager.ClearHosts(const nFree: Boolean);
var nIdx: Integer;
    nItem: PWJLaserHost;
begin
  for nIdx:=FLaserHosts.Count - 1 downto 0 do
  begin
    nItem := FLaserHosts[nIdx];
    nItem.FClient.Free;
    nItem.FClient := nil;

    FreeAndNil(nItem.FOptions);
    Dispose(nItem);
    FLaserHosts.Delete(nIdx);
  end;

  if nFree then
    FLaserHosts.Free;
  //xxxxx
end;

procedure TWJLaserManager.CloseHost(const nHost: PWJLaserHost);
begin
  if Assigned(nHost) and Assigned(nHost.FClient) then
  begin
    nHost.FClient.Disconnect;
    if Assigned(nHost.FClient.IOHandler) then
      nHost.FClient.IOHandler.InputBuffer.Clear;
    //xxxxx
  end;
end;

procedure TWJLaserManager.StartService;
var nIdx,nNum: Integer;
    nType: TWJLaserThreadType;
begin
  if not FEnable then Exit;
  FLaserIndex := 0;
  FLaserActive := 0;

  nNum := 0;
  //init
  
  for nIdx:=Low(FThreads) to High(FThreads) do
  begin
    if (nNum >= FThreadCount) or
       (nNum >= FLaserHosts.Count) then Exit;
    //�̲߳��ܳ���Ԥ��ֵ,�򲻶��༤��������

    if nNum < FMonitorCount then
         nType := ttAll
    else nType := ttActive;

    if not Assigned(FThreads[nIdx]) then
      FThreads[nIdx] := TWJLaserReader.Create(Self, nType);
    Inc(nNum);
  end;
end;

procedure TWJLaserManager.StopService;
var nIdx: Integer;
begin
  for nIdx:=Low(FThreads) to High(FThreads) do
   if Assigned(FThreads[nIdx]) then
    FThreads[nIdx].Terminate;
  //�����˳����

  for nIdx:=Low(FThreads) to High(FThreads) do
  begin
    if Assigned(FThreads[nIdx]) then
      FThreads[nIdx].StopMe;
    FThreads[nIdx] := nil;
  end;

  FSyncLock.Enter;
  try
    for nIdx:=FLaserHosts.Count - 1 downto 0 do
      CloseHost(FLaserHosts[nIdx]);
    //�ر���·
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2019-10-09
//Parm: ��������ʶ
//Desc: ����nReader������
function TWJLaserManager.FindHost(const nHost: string): Integer;
var nIdx: Integer;
begin
  Result := -1;

  for nIdx:=FLaserHosts.Count-1 downto 0 do
  if CompareText(PWJLaserHost(FLaserHosts[nIdx]).FID, nHost) = 0 then
  begin
    Result := nIdx;
    Exit;
  end;
end;

procedure TWJLaserManager.LoadConfig(const nFile: string);
var nIdx: Integer;
    nXML: TNativeXml;
    nHost: PWJLaserHost;
    nDefHost: TWJLaserHost;
    nRoot,nNode,nTmp: TXmlNode;
begin
  FEnable := False;
  if not FileExists(nFile) then Exit;

  nXML := nil;
  try
    nXML := TNativeXml.Create;
    nXML.LoadFromFile(nFile);
    nRoot := nXML.Root.FindNode('config');

    if not Assigned(nRoot) then
      raise Exception.Create('Invalid WJLaser Config File.');
    //xxxxx

    nNode := nRoot.FindNode('enable');
    if Assigned(nNode) then
      Self.FEnable := nNode.ValueAsString <> 'N';
    //xxxxx

    nNode := nRoot.FindNode('thread');
    if Assigned(nNode) then
         FThreadCount := nNode.ValueAsInteger
    else FThreadCount := 1;

    if (FThreadCount < 1) or (FThreadCount > cWJLaserMaxThread) then
      raise Exception.Create('WJLaser Thread-Num Need Between 1-10.');
    //xxxxx

    nNode := nRoot.FindNode('monitor');
    if Assigned(nNode) then
         FMonitorCount := nNode.ValueAsInteger
    else FMonitorCount := 1;

    if (FMonitorCount < 1) or (FMonitorCount > FThreadCount) then
      raise Exception.Create(Format(
        'WJLaser Monitor-Num Need Between 1-%d.', [FThreadCount]));
    //xxxxx

    //--------------------------------------------------------------------------
    nRoot := nXML.Root.FindNode('lasers');
    if not Assigned(nRoot) then Exit;

    FillChar(nDefHost, SizeOf(TWJLaserHost), #0);
    ClearHosts(False);

    for nIdx:=0 to nRoot.NodeCount - 1 do
    begin
      nNode := nRoot.Nodes[nIdx];
      if CompareText(nNode.Name, 'laser') <> 0 then Continue;

      New(nHost);
      FLaserHosts.Add(nHost);
      nHost^ := nDefHost;

      with nNode,nHost^ do
      begin
        FLocked := False;
        FLastActive := GetTickCount;

        FID := AttributeByName['id'];
        FHost := NodeByNameR('ip').ValueAsString;
        FPort := NodeByNameR('port').ValueAsInteger;
        FEnable := NodeByNameR('enable').ValueAsString <> 'N';

        FTunnel := NodeByNameR('tunnel').ValueAsString;
        FHighLaser := NodeByNameR('high').ValueAsInteger;
        FOffsetFrontLaser := NodeByNameR('offsetFront').ValueAsInteger;
        FOffsetBackLaser := NodeByNameR('offsetBack').ValueAsInteger;

        FClient := TIdTCPClient.Create;
        with FClient do
        begin
          Host := FHost;
          Port := FPort;
          ReadTimeout := 3 * 1000;
          ConnectTimeout := 3 * 1000;   
        end;

        nTmp := FindNode('options');
        if Assigned(nTmp) then
        begin
          FOptions := TStringList.Create;
          SplitStr(nTmp.ValueAsString, FOptions, 0, ';');
        end else FOptions := nil;
      end;
    end;
  finally
    nXML.Free;
  end;
end;

//------------------------------------------------------------------------------
constructor TWJLaserReader.Create(AOwner: TWJLaserManager;
  AType: TWJLaserThreadType);
begin
  inherited Create(False);
  FreeOnTerminate := False;

  FOwner := AOwner;
  FThreadType := AType;

  FWaiter := TWaitObject.Create;
  FWaiter.Interval := cWJLaser_Wait_Short;
end;

destructor TWJLaserReader.Destroy;
begin       
  FWaiter.Free;
  inherited;
end;

procedure TWJLaserReader.StopMe;
begin
  Terminate;
  FWaiter.Wakeup;

  WaitFor;
  Free;
end;

//Date: 2019-10-09
//Parm: �&���������
//Desc: ɨ��nActive������,�����ô���FActiveHost.
procedure TWJLaserReader.ScanActiveHost(const nActive: Boolean);
var nIdx: Integer;
    nReader: PWJLaserHost;
begin
  if nActive then //ɨ��
  with FOwner do
  begin
    if FLaserActive = 0 then
         nIdx := 1
    else nIdx := 0; //��0��ʼΪ����һ��

    while True do
    begin
      if FLaserActive >= FLaserHosts.Count then
      begin
        FLaserActive := 0;
        Inc(nIdx);

        if nIdx >= 2 then Break;
        //ɨ��һ��,��Ч�˳�
      end;

      nReader := FLaserHosts[FLaserActive];
      Inc(FLaserActive);
      if nReader.FLocked or (not nReader.FEnable) then Continue;

      if nReader.FLastActive > 0 then 
      begin
        FActiveHost := nReader;
        FActiveHost.FLocked := True;
        Break;
      end;
    end;
  end else

  with FOwner do //ɨ�費�
  begin
    if FLaserIndex = 0 then
         nIdx := 1
    else nIdx := 0; //��0��ʼΪ����һ��

    while True do
    begin
      if FLaserIndex >= FLaserHosts.Count then
      begin
        FLaserIndex := 0;
        Inc(nIdx);

        if nIdx >= 2 then Break;
        //ɨ��һ��,��Ч�˳�
      end;

      nReader := FLaserHosts[FLaserIndex];
      Inc(FLaserIndex);
      if nReader.FLocked or (not nReader.FEnable) then Continue;

      if nReader.FLastActive = 0 then 
      begin
        FActiveHost := nReader;
        FActiveHost.FLocked := True;
        Break;
      end;
    end;
  end;
end;

procedure TWJLaserReader.Execute;
begin
  InitSingleRequst;
  //��ʼ��ָ��
  
  while not Terminated do
  try
    FWaiter.EnterWait;
    if Terminated then Exit;

    FActiveHost := nil;
    try
      DoExecute;
    finally
      if Assigned(FActiveHost) then
      begin
        FOwner.FSyncLock.Enter;
        FActiveHost.FLocked := False;
        FOwner.FSyncLock.Leave;
      end;
    end;
  except
    on E: Exception do
    begin
      WriteLog(E.Message);
      Sleep(500);
    end;
  end;
end;

procedure TWJLaserReader.DoExecute;
begin
  FOwner.FSyncLock.Enter;
  try
    if FThreadType = ttAll then
    begin
      ScanActiveHost(False);
      //����ɨ�費�

      if not Assigned(FActiveHost) then
        ScanActiveHost(True);
      //����ɨ����
    end else

    if FThreadType = ttActive then //ֻɨ��߳�
    begin
      ScanActiveHost(True);
      //����ɨ��

      if Assigned(FActiveHost) then
      begin
        FWaiter.Interval := cWJLaser_Wait_Short;
        //�л,����
      end else
      begin
        FWaiter.Interval := cWJLaser_Wait_Long;
        //�޻,����
        ScanActiveHost(False);
        //����ɨ�費���
      end;
    end;
  finally
    FOwner.FSyncLock.Leave;
  end;

  if Assigned(FActiveHost) and (not Terminated) then
  try
    if SendHostCommand(FActiveHost) then
    begin
      ParseLaserData(FActiveHost);
      //��������
      
      if FThreadType = ttActive then
        FWaiter.Interval := cWJLaser_Wait_Short;
      FActiveHost.FLastActive := GetTickCount;
    end else
    begin
      if (FActiveHost.FLastActive > 0) and
         (GetTickCountDiff(FActiveHost.FLastActive) >= 5 * 1000) then
        FActiveHost.FLastActive := 0;
      //δ��⵽��Ч����,�Զ�תΪ���
    end;
  except
    on E:Exception do
    begin
      FActiveHost.FLastActive := 0;
      //��Ϊ���

      WriteLog(Format('Reader:[ %s:%d ] Msg: %s', [FActiveHost.FHost,
        FActiveHost.FPort, E.Message]));
      //xxxxx

      FOwner.CloseHost(FActiveHost);
      //focus reconnect
    end;
  end;
end;

//------------------------------------------------------------------------------
type
  TTwoByte = packed record
    FHi: Byte;
    FLo: Byte;
  end;

procedure FillWord(var nBuf: array of Byte; const nData: Word);
var nTB: TTwoByte;
begin
  nTB := TTwoByte(nData);
  nBuf[0] := nTB.FLo;
  nBuf[1] := nTB.FHi;
end;

function MakeWord(const nLo,nHi: Byte): Word;
var nTB: TTwoByte;
begin
  nTB.FLo := nLo;
  nTB.FHi := nHi;
  Result := Word(nTB);
end;

//Date: 2019-10-10
//Parm: ��У������;�Ƿ񸽼�У����;������0��ʼ,У������ݳ���
//Desc: ʹ������㷨У��nData����
function VerifyData(var nData: TIdBytes; const nAppend: Boolean;
  nLen: Integer = -1): Byte;
var nIdx: Integer;
begin
  Result := 0;
  if nLen < 0 then
       nLen := High(nData) - 4 //ĩ4λ���������
  else nLen := nLen - 5;
  if nLen < 2 then Exit;

  Result := nData[2];      //��λ֡ͷ���������
  for nIdx:=3 to nLen do
    Result := Result xor nData[nIdx];
  //xxxxx

  if nAppend then
  begin
    nData[nLen + 1] := $00;
    nData[nLen + 2] := Result;

    nData[nLen + 3] := $EE;
    nData[nLen + 4] := $EE;
  end;
end;

//Date: 2019-10-10
//Parm: ����;ǰ׺
//Desc: ��ӡnData�Ķ���������
procedure LogHex(const nData: TIdBytes; const nPrefix: string = '');
var nStr: string;
    nIdx: Integer;
begin
  nStr := '';
  for nIdx:=Low(nData) to High(nData) do
    nStr := nStr + IntToHex(nData[nIdx], 2) + ' ';
  WriteLog(nPrefix + nStr);
end;

//Date: 2019-10-10
//Desc: ������ȡ��֡����ָ��
procedure TWJLaserReader.InitSingleRequst;
begin
  FillChar(FSingleRequst, cSize_WJLaserData, #0);
  //init

  with FSingleRequst do
  begin
    FHead[0]         := $FF;
    FHead[1]         := $AA;

    FillWord(FLength, $1E);     //�ܳ�34,��ȥ֡ͷ֡β4���ֽ�
    FVerifyType      := $01;    //01,���У��
    FrameType        := $01;    //01,����;02,Ӧ��
    FDeviceType[0]   := $00;
    FDeviceType[1]   := $04;

    FCommand         := $02;    //02,��������
    FSubCmd          := $01;    //01,��֡����
    FFrameEnd[0]     := $EE;
    FFrameEnd[1]     := $EE;    //֡β
  end;
end;

//Date: 2019-10-14
//Parm: ������
//Desc: ��nHost�������ݲ�ѯָ��
function TWJLaserReader.SendHostCommand(const nHost: PWJLaserHost): Boolean;
var nBuf: TIdBytes;
    nLen,nInit: Cardinal;
begin
  Result := False;
  nHost.FClient.CheckForGracefulDisconnect(False);
  //check connection

  if not nHost.FClient.Connected then
    nHost.FClient.Connect;
  //make sure connect

  with FSingleRequst do
  begin
    FillWord(FSerial, nHost.FSerial);
    Inc(nHost.FSerial);

    FTimeStamp := DateTimeToTimeStamp(Now).Time;
    nBuf := RawToBytes(FSingleRequst, MakeWord(FLength[0], FLength[1]) + 4);
    VerifyData(nBuf, True); //���У��
  end;                     

  {$IFDEF DEBUG}
  LogHex(nBuf, 'Send Request ::: >>> ');
  {$ENDIF}

  nHost.FClient.IOHandler.Write(nBuf);
  //write data
  nHost.FClient.IOHandler.CheckForDataOnSource(100);
  //fill the output buffer with a long timeout

  nInit := GetTickCount();
  SetLength(nBuf, 0);

  repeat
    if nHost.FClient.IOHandler.InputBufferIsEmpty then
      nHost.FClient.IOHandler.CheckForDataOnSource(10);
    //fill the output buffer with a short timeout

    if not nHost.FClient.IOHandler.InputBufferIsEmpty then
      nHost.FClient.IOHandler.InputBuffer.ExtractToBytes(nBuf);
    //read data

    nLen := Length(nBuf);
    if (nLen < 5) or ((nBuf[0] <> $FF) or (nBuf[1] <> $AA)) then Continue;
    //invalid header

    if nLen >= MakeWord(nBuf[2], nBuf[3]) + 4 then Break;
    //frame done
  until GetTickCountDiff(nInit) >= nHost.FClient.ReadTimeout;

  if nLen < 5 then Exit;
  //no data

  {$IFDEF DEBUG}
  //LogHex(nBuf, 'Recv Data ::: <<< ');
  {$ENDIF}

  if nLen > cSize_WJLaserData then
    nLen := cSize_WJLaserData;
  //clip data

  BytesToRaw(nBuf, nHost.FData, nLen);
  with nHost.FData do
  begin
    FFrameEnd[1] := nBuf[nLen - 1];
    FFrameEnd[0] := nBuf[nLen - 2];
    FVerify[1]   := nBuf[nLen - 3];
    FVerify[0]   := nBuf[nLen - 4];
    //comine data

    if (FHead[0] <> $FF) or (FHead[1] <> $AA) then Exit; //invalid header
    if (FFrameEnd[0] <> $EE) or (FFrameEnd[1] <> $EE) then Exit; //invalid end

    if (FCommand <> $02) or (FSubCmd <> $01) then Exit;
    //invalid command

    if (FVerify[0] <> $00) or
       (FVerify[1] <> VerifyData(nBuf, False, nLen)) then Exit;
    //invalid verify
  end;

  Result := True;
end;

//Date: 2019-10-14
//Parm: ������
//Desc: ����nHost��FData����
procedure TWJLaserReader.ParseLaserData(const nHost: PWJLaserHost);
var nIdx,nInt: Integer;
    nDPrecision: Boolean;
begin
  with FOwner, nHost.FData do
  try
    FSyncLock.Enter;
    nIdx := MakeWord(FLength[0], FLength[1]);
    nDPrecision := nIdx > 1000;
    //�������ݳ����ж�������ɨ�辫��(������0.5��,˫����0.25��)

    nIdx := 0;
    nInt := 0;
    //init

    while True do
    begin
      with nHost.FDataParse[nInt] do
      begin
        if nDPrecision then
             FAngle := nInt * 0.25
        else FAngle := nInt * 0.5;

        FDistance := MakeWord(FData[nIdx], FData[nIdx + 1]);
        Fx := Trunc(FDistance * Cos(FAngle * Pi / 180));
        Fy := Trunc(FDistance * Sin(FAngle * Pi / 180));

        if nHost.FHighLaser >= Fy then
             FHigh := nHost.FHighLaser - Fy
        else FHigh := 0;
      end;

      Inc(nIdx, 2);
      Inc(nInt);

      if nDPrecision then
      begin
        if nInt >= 720 then //˫����720����ֵ
        begin
          if nInt < cLaserDataParse then
            nHost.FDataParse[nInt].FAngle := -1;
          Break;
        end;
      end else
      begin
        if nInt >= 360 then //������360����ֵ
        begin
          if nInt < cLaserDataParse then
            nHost.FDataParse[nInt].FAngle := -1;
          Break;
        end;
      end;
    end;
  finally
    FSyncLock.Leave;
  end;
end;

initialization
  gWJLaserManager := nil;
finalization
  FreeAndNil(gWJLaserManager);
end.
