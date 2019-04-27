{*******************************************************************************
  ����: dmzn@163.com 2019-04-24
  ����: ����PLC�ļ̵���������

  ��ע:
  *.��Ʊ�׼:
    1,24·���������롣
    2,16·���ϼ̵��������
    3,һ·485�����
    4,TCP ServerģʽͨѶ��
  *.ͨѶЭ���ʽ��
    ��ʼ֡---|---������---|---���ݳ���---|---����---|---У��λ
     3�ֽ�	     1�ֽ�	       1�ֽ�	      N*1�ֽ�     1�ֽ�
    У���㷨����"��ʼ֡->����N���һ���ֽ�"�������õ���ֵ��
*******************************************************************************}
unit UMgrERelayPLC;

{$DEFINE Debug}
interface

uses
  Windows, Classes, SysUtils, NativeXml, IdTCPConnection, IdTCPClient, IdGlobal,
  SyncObjs, UWaitItem, ULibFun, USysLoger;

const
  cERelay_AddrNum          = 64;        //ͨ������
  cERelay_Null             = $FF;       //��

  cERelay_FrameBegin       = Char($FF) + Char($FF) + Char($FF); //��ʼ֡
  cERelay_QueryStatus      = $01;       //״̬��ѯ(in)
  cERelay_RelaysOC         = $02;       //ͨ������(open close)
  cERelay_DataForward      = $03;       //485����ת��

  cERelay_SignIn_On        = $01;       //�������ź�
  cERelay_SignIn_Off       = $00;       //�������ź�
  cERelay_SignOut_Close    = $00;       //���:�ر�
  cERelay_SignOut_Open     = $01;       //���:��
  cERelay_SignOut_Ignore   = $02;       //���:����

type
  TERelayAddress = array[0..cERelay_AddrNum-1] of Byte;
  //in-out address,8x8

  PERelayHost = ^TERelayHost;
  TERelayHost = record
    FEnable        : Boolean;           //�Ƿ�����
    FID            : string;            //������ʶ
    FName          : string;            //��������
    FHost          : string;            //����IP
    FPort          : Integer;           //�����˿�
    FInNum         : Integer;           //����ͨ��
    FInSignalOn    : Byte;
    FInSignalOff   : Byte;              //�����ź�
    FOutNum        : Integer;           //���ͨ��
    FOutSignalOn   : Byte;
    FOutSignalOff  : Byte;              //����ź�

    FLastActive    : Cardinal;          //�ϴλ
    FStatusIn      : TERelayAddress;    //����״̬
    FStatusOut     : TERelayAddress;    //���״̬
    FStatusLast    : Cardinal;          //״̬����

    FLocked        : Boolean;           //�Ƿ�����
    FClient        : TIdTCPClient;      //ͨ����·
    FReadBuf       : TIdBytes;          //���ջ���
  end;
  TERelayHosts = array of TERelayHost;

  PERelayTunnel = ^TERelayTunnel;
  TERelayTunnel = record
    FEnable        : Boolean;           //�Ƿ�����
    FID            : string;            //ͨ����ʶ
    FName          : string;            //ͨ������
    FHost          : Integer;           //��������
    FIn            : TERelayAddress;    //�����ַ
    FOut           : TERelayAddress;    //�����ַ
    FAutoOFF       : Integer;           //�Զ��ر�
    FLastOn        : Cardinal;          //�ϴδ�
    FScreen        : Integer;           //��ʾ����
  end;
  TERelayTunnels = array of TERelayTunnel;

  PERelayTunnelCommand = ^TERelayTunnelCommand;
  TERelayTunnelCommand = record
    FUsed          : Boolean;           //ʹ�ñ��  
    FTunnel        : string;            //ͨ����ʶ
    FCommand       : Byte;              //��������
    FData          : TIdBytes;          //��������
  end;
  TERelayTunnelCommands = array of TERelayTunnelCommand;

  TERelayThreadType = (ttAll, ttActive);
  //�߳�ģʽ: ȫ��;ֻ���

  TERelayManager = class;
  TERelayThread = class(TThread)
  private
    FOwner: TERelayManager;
    //ӵ����
    FBuffer: TList;
    //����������
    FWaiter: TWaitObject;
    //�ȴ�����
    FActiveHost: PERelayHost;
    //��ǰ��ͷ
    FThreadType: TERelayThreadType;
    //�߳�ģʽ
  protected
   { procedure Execute; override;
    procedure DoExecute;
    //ִ���߳�
    procedure ScanActiveHost(const nActive: Boolean);
    //ɨ�����
    procedure SendHostCommand(const nHost: PERelayHost);
    function SendData(const nHost: PERelayHost; var nData: TIdBytes;
      const nRecvLen: Integer): string;
    //��������
  public
    constructor Create(AOwner: TERelayManager; AType: TERelayThreadType);
    destructor Destroy; override;
    //�����ͷ�
    procedure Wakeup;
    procedure StopMe;
    //��ͣͨ��}
  end;

  TERelayManager = class(TObject)
  private
    FHosts: TERelayHosts;
    FTunnels: TERelayTunnels;
    //ͨ���б�
    FHostIndex: Integer;
    FHostActive: Integer;
    //��ͷ����
    FMonitorCount: Integer;
    FThreadCount: Integer;
    FReaders: array of TERelayThread;
    //���Ӷ���
    FCommands: TERelayTunnelCommands;
    //�����б�
    FSyncLock: TCriticalSection;
    //ͬ������
  protected
    procedure ClearHost(const nFree: Boolean);
    //��������
    procedure CloseHostConn(const nHost: Integer);
    //�ر�����
    function FindTunnel(const nTunnel: string): Integer;
    //����ͨ��
    function MakeNewCommand(const nCmd: Byte; const nTunnel: string;
      const nLock: Boolean = True): Integer;
    //��������
    function SendCommand(const nHost,nCommand: Integer;
      var nRecv: TIdBytes): Boolean;
    //����ָ��
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    procedure StartService;
    procedure StopService;
    //��ͣ����
    procedure LoadConfig(const nFile: string);
    //��ȡ����
    function OpenTunnel(const nTunnel: string): Boolean;
    function CloseTunnel(const nTunnel: string): Boolean;
    function TunnelOC(const nTunnel: string; nOC: Boolean): string;
    //����ͨ��
    function IsTunnelOK(const nTunnel: string): Boolean;
    function QueryStatus(const nHost: string; var nIn,nOut: TERelayAddress): Boolean;
    //��ѯ״̬
    procedure ShowText(const nTunnel,nText: string; nScreen: Integer = -1);
    //��ʾ����
  end;

var
  gERelayManager: TERelayManager = nil;
  //ȫ��ʹ��

implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TERelayManager, 'PLC��������', nEvent);
end;

constructor TERelayManager.Create;
begin
  FHostIndex := 0;
  FHostActive := 0;
  SetLength(FHosts, 0);
  SetLength(FTunnels, 0);

  FThreadCount := 2;
  FMonitorCount := 1;
  SetLength(FReaders, 0);

  SetLength(FCommands, 0);
  FSyncLock := TCriticalSection.Create;
end;

destructor TERelayManager.Destroy;
begin
  StopService();
  ClearHost(True);
  
  FSyncLock.Free;
  inherited;
end;

procedure TERelayManager.ClearHost(const nFree: Boolean);
var nIdx: Integer;
begin
  for nIdx:=Low(FHosts) to High(FHosts) do
    FreeAndNil(FHosts[nIdx].FClient);
  SetLength(FHosts, 0);
end;

//Desc: �ر�������·
procedure TERelayManager.CloseHostConn(const nHost: Integer);
begin
  with FHosts[nHost]  do
  begin
    if Assigned(FClient) then
    begin
      FClient.Disconnect;
      if Assigned(FClient.IOHandler) then
        FClient.IOHandler.InputBuffer.Clear;
      //xxxxx
    end;
  end;
end;

//Desc: ����
procedure TERelayManager.StartService;
var nIdx,nInt: Integer;
    nType: TERelayThreadType;
begin
  nInt := 0;
  for nIdx:=Low(FHosts) to High(FHosts) do
   if FHosts[nIdx].FEnable then
    Inc(nInt);
  //count enable host
                            
  if nInt < 1 then Exit;
  FHostIndex := 0;
  FHostActive := 0;

  StopService;
  SetLength(FReaders, FThreadCount);
  for nIdx:=Low(FReaders) to High(FReaders) do
    FReaders[nIdx] := nil;
  //xxxxx

  for nIdx:=Low(FReaders) to High(FReaders) do
  begin
    if nIdx >= nInt then Exit;
    //�̲߳���������������

    if nIdx < FMonitorCount then
         nType := ttAll
    else nType := ttActive;

    //FReaders[nIdx] := TERelayThread.Create(Self, nType);
    //xxxxx
  end;
end;

//Desc: ֹͣ
procedure TERelayManager.StopService;
var nIdx: Integer;
begin
  for nIdx:=Low(FReaders) to High(FReaders) do
   if Assigned(FReaders[nIdx]) then
    FReaders[nIdx].Terminate;
  //�����˳����

  for nIdx:=Low(FReaders) to High(FReaders) do
  begin
    if Assigned(FReaders[nIdx]) then
     // FReaders[nIdx].StopMe;
    FReaders[nIdx] := nil;
  end;

  FSyncLock.Enter;
  try
    for nIdx:=Low(FHosts) to High(FHosts) do
      CloseHostConn(nIdx);
    //�ر���·
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2019-04-25
//Parm: ͨ����ʶ
//Desc: ����nTunnelλ������
function TERelayManager.FindTunnel(const nTunnel: string): Integer;
var nIdx: Integer;
begin
  Result := -1;

  for nIdx:=Low(FTunnels) to High(FTunnels) do
  if CompareText(nTunnel, FTunnels[nIdx].FID) = 0 then
  begin
    Result := nIdx;
    Break;
  end;
end;

//Date: 2019-04-25
//Parm: ����;ͨ��;����
//Desc: ����������,�ϲ���ͬ����
function TERelayManager.MakeNewCommand(const nCmd: Byte; const nTunnel: string;
  const nLock: Boolean): Integer;
var nIdx: Integer;
    nInit: TERelayTunnelCommand;
begin
  Result := -1;
  if nLock then FSyncLock.Enter;
  try
    for nIdx:=Low(FCommands) to High(FCommands) do
    begin
      if FCommands[nIdx].FUsed then
      begin
        if (CompareText(nTunnel, FCommands[nIdx].FTunnel) = 0) and
           (nCmd = FCommands[nIdx].FCommand) then 
        begin
          Result := nIdx;
          Break;
        end; //same tunnel,same command
      end else
      begin
        if Result < 0 then
          Result := nIdx;
        //xxxxx
      end;
    end;

    if Result < 0 then
    begin
      Result := Length(FCommands);
      SetLength(FCommands, Result + 1);
    end; //new command

    FillChar(nInit, SizeOf(nInit), #0);
    FCommands[Result] := nInit;
    //init

    with FCommands[Result] do
    begin
      FUsed    := True;
      FCommand := nCmd;
      FTunnel  := nTunnel;
    end;
  finally
    if nLock then FSyncLock.Leave;
  end;
end;

procedure LogHex(const nData: TIdBytes; const nPrefix: string = '');
var nStr: string;
    nIdx: Integer;
begin
  nStr := '';
  for nIdx:=Low(nData) to High(nData) do
    nStr := nStr + IntToHex(nData[nIdx], 1) + ' ';
  WriteLog(nPrefix + nStr);
end;

//Date: 2019-04-27
//Parm: ����;ƫ��
//Desc: ��nData�����У��
function VerifyData(var nData: TIdBytes; const nOffset: Integer = 0): Byte;
var nIdx,nHigh: Integer;
begin
  nHigh := High(nData);
  if nHigh < 0 then
  begin
    Result := 0;
    Exit;
  end;

  if nOffset < 0 then
    nHigh := nHigh + nOffset;
  //xxxxx
  
  Result := nData[0];
  for nIdx:=1 to nHigh do
    Result := Result xor nData[nIdx];
  //xxxxx
end;

//Date: 2019-04-26
//Parm: ����;����;���
//Desc: ��nHost����nCommand����
function TERelayManager.SendCommand(const nHost,nCommand: Integer;
  var nRecv: TIdBytes): Boolean;
var nIdx,nInt,nLen,nNum: Integer;
    nSendBuf: Boolean;
    nBuf: TIdBytes;
begin
  with FHosts[nHost],FCommands[nCommand] do
  try
    Result := False;
    nBuf := ToBytes(cERelay_FrameBegin, Indy8BitEncoding);    //��ʼ֡
    AppendByte(nBuf, FCommand);                               //������
    AppendByte(nBuf, Length(FData));                          //���ݳ���
    AppendBytes(nBuf, FData);                                 //����
    AppendByte(nBuf, VerifyData(nBuf));                       //У��λ

    nSendBuf := True;
    nNum := 1;
    //init
    
    while nNum < 3 do
    try
      Inc(nNum);
      if not FClient.Connected then
      begin
        FClient.Connect;
        FClient.IOHandler.ReadTimeout := 5 * 1000;
        //reset timeout
      end;

      if nSendBuf then
      begin
        FClient.IOHandler.Write(nBuf);
        //send data       
        FClient.IOHandler.ReadBytes(FReadBuf, Length(cERelay_FrameBegin));
        //read frame begin
      end;

      while True do
      begin
        FClient.IOHandler.CheckForDataOnSource(10);
        //fill the output buffer with a timeout

        if FClient.IOHandler.InputBufferIsEmpty then
             Break
        else FClient.IOHandler.InputBuffer.ExtractToBytes(FReadBuf);
      end;

      {$IFDEF Debug}
      LogHex(FReadBuf, 'ԭʼ: ');
      {$ENDIF}

      nSendBuf := False; //��д���������ط�
      nLen := Length(FReadBuf);
      if nLen < 1 then Continue;

      //------------------------------------------------------------------------
      if nLen > 100 then
      begin
        FReadBuf := ToBytes(FReadBuf, 100, nLen - 100);
        {$IFDEF Debug}
        LogHex(FReadBuf, '����: ');
        {$ENDIF}

        nLen := 100;
        WriteLog('���峬��,�ѽض�.');
      end;

      nIdx := nLen - 6;
      //��С����ʼλ: ��ʼ֡3 + ������1 + ���ݳ�1 + У��1

      while nIdx >= 0 do
      begin
        if (FReadBuf[nIdx] = $FF) and (FReadBuf[nIdx+1] = $FF) and
           (FReadBuf[nIdx+2] = $FF) then //֡ͷ
        begin
          nInt := FReadBuf[nIdx+4] + 6; //�������ݱ߽�
          if nIdx + nInt > nLen then //���ݲ�����
          begin
            Dec(nIdx);
            Continue;
          end;

          nRecv := ToBytes(FReadBuf, nInt, nIdx);
          if nRecv[High(nRecv)] <> VerifyData(nRecv, -1) then //У��ʧ��
          begin
            Dec(nIdx);
            Continue;
          end;

          nInt := nInt + nIdx;
          if nLen = nInt then
               SetLength(FReadBuf, 0)
          else FReadBuf := ToBytes(FReadBuf, nLen - nInt, nInt);

          Result := nRecv[3] = FCommand;
          //Ӧ��ƥ��
          Break;
        end else Dec(nIdx);
      end;

      {$IFDEF Debug}
      LogHex(nRecv, 'Э��: ');
      LogHex(FReadBuf, '����: ');
      {$ENDIF}
      if Result then Break;
    except
      on nErr: Exception do
      begin
        nSendBuf := True;
        CloseHostConn(nHost);
        //�Ͽ�����

        if nNum >= 3 then
          raise;
        //xxxxx
      end;
    end;
  except
    on nErr: Exception do
    begin
      WriteLog(Format('������[ %s:%s,%d ]��������ʧ��,����: %s', [FID,
        FClient.Host, FClient.Port, nErr.Message]));
      //xxxxx
    end;
  end;
end;

//------------------------------------------------------------------------------
//Date: 2019-04-25
//Parm: ͨ����ʶ
//Desc: ��nTunnelͨ��
function TERelayManager.OpenTunnel(const nTunnel: string): Boolean;
var nStr: string;
begin
  nStr := TunnelOC(nTunnel, False);
  Result := nStr = '';

  if not Result then
    WriteLog(nStr);
  //xxxxxx
end;

//Date: 2019-04-25
//Parm: ͨ����ʶ
//Desc: �ر�nTunnelͨ��
function TERelayManager.CloseTunnel(const nTunnel: string): Boolean;
var nStr: string;
begin
  nStr := TunnelOC(nTunnel, True);
  Result := nStr = '';

  if not Result then
    WriteLog(nStr);
  //xxxxxx
end;

//Date: 2019-04-25
//Parm: ͨ����ʶ
//Desc: ����nTunnelͨ��
function TERelayManager.TunnelOC(const nTunnel: string; nOC: Boolean): string;
var nIdx,nInt,nT,nCmd: Integer;
begin
  Result := '';
  //if (Length(FReaders) < 1) or (not Assigned(FReaders[0])) then Exit;
  nT := FindTunnel(nTunnel);

  if nT < 0 then
  begin
    Result := 'ͨ��[ %s ]�����Ч.';
    Result := Format(Result, [nTunnel]); Exit;
  end;

  with FTunnels[nT] do
  begin
    if not (FEnable and FHosts[FHost].FEnable ) then Exit;
    //������,������

    nInt := 0;
    for nIdx:=Low(FOut) to High(FOut) do
      if FOut[nIdx] <> cERelay_Null then Inc(nInt);
    //xxxxx

    if nInt < 1 then Exit;
    //�������ַ,��ʾ��ʹ���������

    FSyncLock.Enter;
    try
      nCmd := MakeNewCommand(cERelay_RelaysOC, nTunnel, False);
      with FCommands[nCmd] do
      begin
        SetLength(FData, FHosts[FHost].FOutNum);
        for nIdx:=Low(FData) to High(FData) do
          FData[nIdx] := cERelay_SignOut_Ignore;
        //default

        for nIdx:=Low(FOut) to High(FOut) do
        begin
          if FOut[nIdx] = cERelay_Null then Continue;
          //invalid address

          nInt := FOut[nIdx] - 1;
          //address base from 1
          if (nInt < 0) or (nInt >= FHosts[FHost].FOutNum) then Continue;

          if nOC then
               FData[nInt] := cERelay_SignOut_Open
          else FData[nInt] := cERelay_SignOut_Close;
        end;
      end;
    finally
      FSyncLock.Leave;
    end;
  end;
end;

//Date: 2019-04-27
//Parm: ��ַ��;��ʼ����;״̬�ֽ�
//Desc: ��nStatus�����nAddr��
procedure SpitStatus(var nAddr: TERelayAddress; const nStart: Integer;
  const nStatus: Byte);
var nIdx: Integer;
begin
  for nIdx:=0 to 7 do
  begin
    nAddr[nStart+nIdx] := GetNumberBit(nStatus, nIdx+1, Bit_8);
  end;
end;

//Date: 2019-04-26
//Parm: �������;IO״̬
//Desc: ��ѯnHost���������״̬
function TERelayManager.QueryStatus(const nHost: string; var nIn,
  nOut: TERelayAddress): Boolean;
var nIdx,nInt,nCmd: Integer;
    nInI,nOutI: Integer;
    nInit: Cardinal;
    nLockMe: Boolean;
    nRecv: TIdBytes;
begin
  Result := False;
  nInt := -1;
  //init

  for nIdx:=Low(FHosts) to High(FHosts) do
  if CompareText(nHost, FHosts[nIdx].FID) = 0 then
  begin
    nInt := nIdx;
    Break;
  end;

  if nInt < 0 then
  begin
    WriteLog(Format('����[ %s ]������.', [nHost]));
    Exit;
  end;

  if not FHosts[nInt].FEnable then
  begin
    WriteLog(Format('����[ %s ]��ͣ��.', [nHost]));
    Exit;
  end;

  nLockMe := False;
  nCmd := -1;
  nInit := GetTickCount();
  
  with FHosts[nInt] do
  try
    while True do
    try
      FSyncLock.Enter;
      if FLocked then
      begin
        if GetTickCountDiff(nInit) > 5 * 1000 then
        begin
          WriteLog(Format('�ȴ�����[ %s ]������ʱ.', [nHost]));
          Exit;
        end;

        Sleep(20);
        //������������,��ȴ�
      end else
      begin
        FLocked := True; //���ε�������
        nLockMe := True;
        Break;
      end;
    finally
      FSyncLock.Leave;
    end;

    if GetTickCountDiff(FStatusLast) > 1200 then //״̬��ʱ���ڿɸ���
    begin
      nCmd := MakeNewCommand(cERelay_QueryStatus, nHost, True);
      if not SendCommand(nInt, nCmd, nRecv) then Exit;
      FStatusLast := GetTickCount;
      
      nInI := 0;
      nOutI := 0;
      for nIdx:=5 to High(nRecv)-1 do
      begin
        if nInI < FInNum then //ǰ�����ֽ�������״̬
        begin
          SpitStatus(FStatusIn, nInI, nRecv[nIdx]);
          Inc(nInI, 8);
        end else

        if nOutI < FOutNum then //�󼸸��ֽ������״̬
        begin
          SpitStatus(FStatusOut, nOutI, nRecv[nIdx]);
          Inc(nOutI, 8);
        end;
      end;
    end;

    Result := True;
    nIn := FStatusIn;
    nOut := FStatusOut;
  finally
    if nLockMe then
    try
      FSyncLock.Enter;
      FLocked := False;
      
      if nCmd <> -1 then
        FCommands[nCmd].FUsed := False;
      //xxxxx
    finally
      FSyncLock.Leave;
    end;
  end;
end;

//Date: 2019-04-26
//Parm: ͨ����ʶ
//Desc: �ж�nTunnel״̬�Ƿ�����
function TERelayManager.IsTunnelOK(const nTunnel: string): Boolean;
var nIdx,nInt,nT: Integer;
    nIn,nOut: TERelayAddress;
begin
  Result := True;
  if Trim(nTunnel) = '' then Exit; //��ͨ��Ĭ������

  nT := FindTunnel(nTunnel);
  if nT < 0 then
  begin
    WriteLog(Format('ͨ��[ %s ]��Ч.',  [nTunnel]));
    Result := False;
    Exit;
  end;

  with FTunnels[nT] do
  begin
    if not (FEnable and FHosts[FHost].FEnable) then Exit; //δ����
    nInt := 0;

    for nIdx:=Low(FIn) to High(FIn) do
     if FIn[nIdx] <> cERelay_Null then Inc(nInt);
    if nInt < 1 then Exit; //�������ַ,��ʶ��ʹ��������

    Result := QueryStatus(FHosts[FHost].FID, nIn, FOut);
    if not Result then Exit;

  end;
end;

//Date: 2019-04-26
//Parm: ͨ��;����;����
//Desc: ��nTunnel��ʾnText����
procedure TERelayManager.ShowText(const nTunnel, nText: string;
  nScreen: Integer);
begin

end;

//Date: 2019-04-24
//Parm����ַ�ṹ;��ַ�ַ���,����: 1,2,3
//Desc����nStr��,����nAddr�ṹ��
procedure SplitAddr(var nAddr: TERelayAddress; const nStr: string);
var nIdx: Integer;
    nList: TStrings;
begin
  nList := TStringList.Create;
  try
    SplitStr(nStr, nList, 0 , ',');
    //���
    
    for nIdx:=Low(nAddr) to High(nAddr) do
    begin
      if nIdx < nList.Count then
           nAddr[nIdx] := StrToInt(nList[nIdx])
      else nAddr[nIdx] := cERelay_Null;
    end;
  finally
    nList.Free;
  end;
end;

//Desc: ����nFile�����ļ�
procedure TERelayManager.LoadConfig(const nFile: string);
var nXML: TNativeXml;
    nRoot,nNode,nTmp: TXmlNode;
    i,nIdx,nHost,nTunnel: Integer;
begin
  ClearHost(False);
  SetLength(FTunnels, 0);
  
  nXML := TNativeXml.Create;
  try
    nXML.LoadFromFile(nFile);
    //load config

    nRoot := nXML.Root.NodeByName('config');
    if Assigned(nRoot) then
    begin
      nNode := nRoot.NodeByName('thread');
      if Assigned(nNode) then
           FThreadCount := nNode.ValueAsInteger
      else FThreadCount := 2;

      if (FThreadCount < 1) or (FThreadCount > 5) then
        raise Exception.Create('ERelay Reader Thread-Num Need Between 1-5.');
      //xxxxx

      nNode := nRoot.NodeByName('monitor');
      if Assigned(nNode) then
           FMonitorCount := nNode.ValueAsInteger
      else FMonitorCount := 1;

      if (FMonitorCount < 1) or (FMonitorCount > FThreadCount) then
        raise Exception.Create(Format(
          'ERelay Reader Monitor-Num Need Between 1-%d.', [FThreadCount]));
      //xxxxx
    end;

    for nIdx:=0 to nXML.Root.NodeCount - 1 do
    begin
      nRoot := nXML.Root.Nodes[nIdx];
      if CompareText(nRoot.Name, 'host') <> 0 then Continue;
      //not host node

      nHost := Length(FHosts);
      SetLength(FHosts, nHost + 1);

      with FHosts[nHost],nRoot do
      begin
        FID    := AttributeByName['id'];
        FName  := AttributeByName['name'];
        FHost  := NodeByNameR('ip').ValueAsString;
        FPort  := NodeByNameR('port').ValueAsInteger;
        FEnable := NodeByNameR('enable').ValueAsInteger = 1;

        FStatusLast := 0;
        FLocked := False;
        FLastActive := GetTickCount;

        nTmp := nRoot.NodeByName('signal_in');
        if Assigned(nTmp) then
        begin
          FInNum := StrToInt(nTmp.AttributeByName['num']);
          if (FInNum > cERelay_AddrNum) or (FInNum mod 8 <> 0) then
          begin
            FInNum := 24;
            WriteLog(Format('����[ %s ]���������쳣.', [FID]));
          end;

          FInSignalOn := StrToInt(nTmp.AttributeByName['on']);
          FInSignalOff := StrToInt(nTmp.AttributeByName['off']);
        end else
        begin
          FInNum := 24;
          FInSignalOn := cERelay_SignIn_On;
          FInSignalOff := cERelay_SignIn_Off;
        end;

        nTmp := nRoot.NodeByName('signal_out');
        if Assigned(nTmp) then
        begin
          FOutNum := StrToInt(nTmp.AttributeByName['num']);
          if (FOutNum > cERelay_AddrNum) or (FOutNum mod 8 <> 0) then
          begin
            FInNum := 16;
            WriteLog(Format('����[ %s ]��������쳣.', [FID]));
          end;

          FOutSignalOn := StrToInt(nTmp.AttributeByName['on']);
          FOutSignalOff := StrToInt(nTmp.AttributeByName['off']);
        end else
        begin
          FOutNum := 16;
          FOutSignalOn := cERelay_SignOut_Open;
          FOutSignalOff := cERelay_SignOut_Close;
        end;

        for i:=Low(FStatusIn) to High(FStatusIn) do
          FStatusIn[i] := cERelay_Null;
        //default fill

        for i:=Low(FStatusOut) to High(FStatusOut) do
          FStatusOut[i] := cERelay_Null;
        //default fill

        if FEnable then
        begin
          FClient := TIdTCPClient.Create;
          //socket
          
          with FClient do
          begin
            Host := FHost;
            Port := FPort;
            ReadTimeout := 3 * 1000;
            ConnectTimeout := 3 * 1000;   
          end;
        end else FClient := nil;
      end;

      nRoot := nRoot.FindNode('tunnels');
      if not Assigned(nRoot) then Continue;

      for i:=0 to nRoot.NodeCount - 1 do
      begin
        nNode := nRoot.Nodes[i];
        nTunnel := Length(FTunnels);
        SetLength(FTunnels, nTunnel + 1);

        with FTunnels[nTunnel],nNode do
        begin
          FID    := AttributeByName['id'];
          FName  := AttributeByName['name'];
          FHost  := nHost;
          
          SplitAddr(FIn, NodeByName('in').ValueAsString);
          SplitAddr(FOut, NodeByName('out').ValueAsString);

          nTmp := nNode.FindNode('enable');
          FEnable := (not Assigned(nTmp)) or (nTmp.ValueAsString <> '0');
          FLastOn := 0;

          nTmp := nNode.FindNode('auto_off');           
          if Assigned(nTmp) then
               FAutoOFF := nTmp.ValueAsInteger
          else FAutoOFF := 0;

          nTmp := nNode.FindNode('screen_no');
          if Assigned(nTmp) then
               FScreen := nTmp.ValueAsInteger
          else FScreen := -1;
        end;
      end
    end;
  finally
    nXML.Free;
  end;
end;

initialization
  gERelayManager := nil;
finalization
  FreeAndNil(gERelayManager);
end.
