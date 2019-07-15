{*******************************************************************************
  ����: dmzn@163.com 2019-07-04
  ����: ����OPC�����ݶ�д��Ԫ
*******************************************************************************}
unit UMgrOPC;

interface

uses
  Windows, Classes, SysUtils, Variants, SyncObjs, dOPCDA, dOPC, NativeXml, 
  UWaitItem, UMemDataPool, USysLoger, ULibFun;

const
  OPC_QUALITY_GOOD           = $C0; //good
  OPC_QUALITY_LOCAL_OVERRIDE = $D8; //ֵ������,����ʧȥ���Ӻ��ֶ���ǿ��
  OPC_QUALITY_UNCERTAIN      = $40; //û��ָ��ԭ��˵��ֵΪʲô��ȷ��
  OPC_QUALITY_LAST_USABLE    = $44; //���Ŀ���ֵ
  OPC_QUALITY_SENSOR_CAL     = $50; //�������ﵽ������һ����ֵ���߳�������������
  OPC_QUALITY_EGU_EXCEEDED   = $54; //����ֵԽ��
  OPC_QUALITY_SUB_NORMAL     = $58; //ֵ�м���Դ,���ҿ��õ�Դ���ڹ涨��Ʒ�ʺõ�Դ

  OPC_QUALITY_BAD            = $00; //ֵΪ����,û�б���ԭ��
  OPC_QUALITY_CONFIG_ERROR   = $04; //�������ض�����������
  OPC_QUALITY_NOT_CONNECTED  = $08; //����û�п��õ�����
  OPC_QUALITY_DEVICE_FAILURE = $0C; //�豸����
  OPC_QUALITY_SENSOR_FAILURE = $10; //����������
  OPC_QUALITY_LAST_KNOWN     = $14; //ͨѶʧ��,����ֵ�ǿ��õ�
  OPC_QUALITY_COMM_FAILURE   = $18; //ͨѶʧ��,����ֵ������
  OPC_QUALITY_OUT_OF_SERVICE = $1C; //������ɨ����߱���

type
  POPCGroup = ^TOPCGroup;
  POPCItem = ^TOPCItem;
  TOPCItem = record
    FID         : string;                    //�ڵ���
    FName       : string;                    //��Ŀ����
    FOPCItem    : TdOPCItem;                 //��Ŀ����
    FGroup      : POPCGroup;                 //��������
    FServerItem : Integer;                   //����������

    FValue      : string;                    //��ǰ�ַ�ֵ
    FValueWant  : OleVariant;                //������ֵ
    FLastUpdate : Cardinal;                  //��ǰֵ����ʱ��
  end;
  TOPCItems = array of TOPCItem;

  TOPCGroup = record
    FID         : string;                    //������
    FName       : string;                    //��������
    FGroupItem  : TdOPCGroup;                //�������

    FActive     : Boolean;                   //�Ƿ�����
    FDeadBand   : Integer;                   //��������
    FUpdateRate : Integer;                   //ˢ��Ƶ��
    FOptions    : TStrings;                  //���Ӳ���
    FItems      : TOPCItems;                 //���Ա
  end;
  TOPCGroups = array of TOPCGroup;

  POPCServer = ^TOPCServer;
  TOPCServer = record
    FEnabled    : Boolean;                   //���ñ�ʶ
    FID         : string;                    //������
    FName       : string;                    //��������
    FServerID   : string;                    //�����ʶ
    FServerObj  : TdOPCServer;               //�������

    FLastUpdate : Cardinal;                  //������
    FItems      : TOPCItems;                 //������
  end;

  POPCManagerStatus = ^TOPCManagerStatus;
  TOPCManagerStatus = record
    FConnected  : Boolean;                   //������
    FLastConn   : Cardinal;                  //�ϴ�����
  end;

  TOPCManager = class;
  TOPCThread = class(TThread)
  private
    FOwner: TOPCManager;
    //ӵ����
    FWaiter: TWaitObject;
    //�ȴ�����
  protected
    procedure DoExecute;
    procedure Execute; override;
    //ִ���߳�
    procedure DoConnectServer();
    //���ӷ���
  public
    constructor Create(AOwner: TOPCManager);
    destructor Destroy; override;
    //�����ͷ�
    procedure Wakeup;
    procedure StopMe;
    //��ͣ�߳�
  end;

  TOPCOnDataChange = procedure (const nServer: POPCServer) of object;
  TOPCOnDataChangeProc = procedure (const nServer: POPCServer);
  TOPCOnItemChange = procedure (const nItem: POPCItem) of object;
  TOPCOnItemChangeProc = procedure (const nItem: POPCItem);
  //�¼�����

  TOPCManager = class(TObject)
  private
    FServer: TOPCServer;
    //�������
    FGroups: TOPCGroups;
    //���ݷ���
    FThread: TOPCThread;
    //�����߳�
    FStatus: TOPCManagerStatus;
    //����״̬
    FSyncLock: TCriticalSection;
    //ͬ������
    FOnDataChange: TOPCOnDataChange;
    FOnDataChangeProc: TOPCOnDataChangeProc;
    FOnItemChange: TOPCOnItemChange;
    FOnItemChangeProc: TOPCOnItemChangeProc;
    //�¼����
  protected
    function FindPoint(const nID: string): Integer;
    function FindGroup(const nID: string): Integer;
    //��������
    function ReadData(const nGroup,nPoint: string; var nSData: string;
      var nOData: OleVariant; const nReadStr: Boolean;
      const nTimeout: Integer): Boolean;
    //��ȡ����
    procedure OnServerConnect(Sender: TObject);
    procedure OnServerDisconnect(Sender: TObject);
    procedure OnServerDatachange(Sender: TObject; nList: TdOPCItemList);
    procedure OnServer_Shutdown(Sender: TObject; nReason: string);
    procedure OnServerTimeout(Sender: TObject);
    //OPC�¼�
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    procedure LoadConfig(const nFile: string);
    //��ȡ����
    procedure StartService;
    procedure StopService;
    //��ͣ����
    function Read(const nPoint: string; var nData: string;
      const nTimeout: Integer = -1; const nGroup: string = ''): Boolean; overload;
    function Read(const nPoint: string; var nData: OleVariant;
      const nTimeout: Integer = -1; const nGroup: string = ''): Boolean; overload;
    //��д����
    property OnDataChange: TOPCOnDataChange read FOnDataChange write FOnDataChange;
    property OnDataChangeProc: TOPCOnDataChangeProc read FOnDataChangeProc
     write FOnDataChangeProc;
    property OnItemChange: TOPCOnItemChange read FOnItemChange write FOnItemChange;
    property OnItemChangeProc: TOPCOnItemChangeProc read FOnItemChangeProc
     write FOnItemChangeProc;
    //�¼����
  end;

var
  gOPCManager: TOPCManager = nil;
  //ȫ��ʹ��

implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TOPCManager, 'OPC���ݷ���', nEvent);
end;

constructor TOPCManager.Create;
begin
  FThread := nil;
  FServer.FEnabled := False;
  FServer.FServerObj := nil;
  SetLength(FServer.FItems, 0);
  
  SetLength(FGroups, 0);
  FillChar(FStatus, SizeOf(FStatus), #0);
  FSyncLock := TCriticalSection.Create;
end;

destructor TOPCManager.Destroy;
var nIdx: Integer;
begin
  StopService;
  //stop first

  for nIdx:=Low(FGroups) to High(FGroups) do
  begin
    if Assigned(FGroups[nIdx].FOptions) then
      FreeAndNil(FGroups[nIdx].FOptions);
    //xxxxx
  end;

  FServer.FServerObj.Free;
  FSyncLock.Free;
  inherited;
end;

procedure TOPCManager.StartService;
begin
  if not FServer.FEnabled then Exit;
  //no service

  if not Assigned(FThread) then
    FThread := TOPCThread.Create(Self);
  FThread.Wakeup;
end;

procedure TOPCManager.StopService;
begin
  if Assigned(FThread) then
    FThread.StopMe;
  FThread := nil;

  if Assigned(FServer.FServerObj) then
  begin
    FServer.FServerObj.OPCGroups.Clear;
    FServer.FServerObj.Active := False;
  end;
  FStatus.FConnected := False;
end;

//Date: 2019-07-12
//Parm: ������ʶ
//Desc: ������ʶΪnID�Ľ����,��������
function TOPCManager.FindPoint(const nID: string): Integer;
var nIdx: Integer;
begin
  Result := -1;

  for nIdx:=Low(FServer.FItems) to High(FServer.FItems) do
  if CompareText(nID, FServer.FItems[nIdx].FID) = 0 then
  begin
    Result := nIdx;
    Break;
  end;
end;

//Date: 2019-07-15
//Parm: ���ʶ
//Desc: ������ʶΪnID����,��������
function TOPCManager.FindGroup(const nID: string): Integer;
var nIdx: Integer;
begin
  Result := -1;

  for nIdx:=Low(FGroups) to High(FGroups) do
  if CompareText(nID, FGroups[nIdx].FID) = 0 then
  begin
    Result := nIdx;
    Break;
  end;
end;

//Date: 2019-07-12
//Desc: ����Server�ɹ�
procedure TOPCManager.OnServerConnect(Sender: TObject);
begin
  FStatus.FConnected := True;
  WriteLog('Server Connected');
end;

//Date: 2019-07-12
//Desc: ��Server���ӶϿ�
procedure TOPCManager.OnServerDisconnect(Sender: TObject);
begin
  FStatus.FConnected := False;
  FStatus.FLastConn := GetTickCount(); //delay
  WriteLog('Server Disconnect');
end;

//Date: 2019-07-15
//Desc: ����ر�
procedure TOPCManager.OnServer_Shutdown(Sender: TObject; nReason: string);
begin
  FStatus.FConnected := False;
  FStatus.FLastConn := GetTickCount(); //delay
  WriteLog('Server Shutdown(' + nReason + ')');
end;

procedure TOPCManager.OnServerTimeout(Sender: TObject);
begin
  FStatus.FConnected := False;
  FStatus.FLastConn := GetTickCount(); //delay
  WriteLog('Server TimeOut');
end;

//Date: 2019-07-12
//Desc: ���ݱ��,����������
procedure TOPCManager.OnServerDatachange(Sender: TObject; nList: TdOPCItemList);
var nIdx: Integer;
    nItem: POPCItem;
begin
  FServer.FLastUpdate := GetTickCount();
  //time-stamp

  for nIdx:=nList.Count - 1 downto 0 do
  begin
    nItem := nList[nIdx].Data;
    try
      FSyncLock.Enter;
      try
        nItem.FValue := nItem.FOPCItem.ValueStr;
        nItem.FLastUpdate := FServer.FLastUpdate;

        with FServer.FItems[nItem.FServerItem] do
        begin
          FOPCItem    := nItem.FOPCItem;
          FValue      := nItem.FValue;
          FGroup      := nItem.FGroup;
          FLastUpdate := FServer.FLastUpdate;
        end;
      finally
        FSyncLock.Leave;
      end; 

      if Assigned(FOnItemChange) then
        FOnItemChange(nItem);
      //xxxxx

      if Assigned(FOnItemChangeProc) then
        FOnItemChangeProc(nItem);
      //xxxxx
    except
      on nErr: Exception do
      begin
        WriteLog(Format('Item %s.%s OnChange Error: %s', [nItem.FID,
          nItem.FName, nErr.Message]));
        //xxxxx
      end;
    end;
  end;

  try
    if Assigned(FOnDataChange) then
      FOnDataChange(@FServer);
    //xxxxx

    if Assigned(FOnDataChangeProc) then
      FOnDataChangeProc(@FServer);
    //xxxxx
  except
    on nErr: Exception do
    begin
      WriteLog(Format('Server %s.%s OnChange Error: %s', [FServer.FID,
        FServer.FName, nErr.Message]));
      //xxxxx
    end;
  end;
end;

//Date: 2019-07-15
//Parm: ���ʶ;�����;�ַ�����;���ϱ���;��ȡ�ַ�����;���ݳ�ʱ
//Desc: ��ȡnGroup.nPoint������
function TOPCManager.ReadData(const nGroup,nPoint: string; var nSData: string;
  var nOData: OleVariant; const nReadStr: Boolean; const nTimeout: Integer): Boolean;
var nIdx,nInt: Integer;
begin
  FSyncLock.Enter;
  try
    Result := False;
    if nGroup = '' then
    begin
      nIdx := FindPoint(nPoint);
      if nIdx < 0 then Exit;

      with FServer.FItems[nIdx] do
      begin
        if (nTimeout > 0) and (GetTickCountDiff(FLastUpdate) >= nTimeout) then
        begin
          if (not Assigned(FOPCItem)) or (FOPCItem.Quality <> OPC_QUALITY_GOOD) then
            Exit;
          //���³�ʱ,������������������
        end;

        Result := nReadStr or Assigned(FOPCItem);
        if Result then
        begin
          if nReadStr then
               nSData := FValue
          else nOData := FOPCItem.Value;
        end;
      end;
      
      Exit; //�������������
    end;

    nInt := FindGroup(nGroup);
    if nInt < 0 then Exit;

    for nIdx:=Low(FGroups[nInt].FItems) to High(FGroups[nInt].FItems) do
    with FGroups[nInt].FItems[nIdx] do
    begin
      if CompareText(nPoint, FID) <> 0 then Continue;
      //not match

      if (nTimeout > 0) and (GetTickCountDiff(FLastUpdate) >= nTimeout) then
      begin
        if (not Assigned(FOPCItem)) or (FOPCItem.Quality <> OPC_QUALITY_GOOD) then
          Exit;
        //���³�ʱ,������������������
      end;

       Result := nReadStr or Assigned(FOPCItem);
       if Result then
       begin
         if nReadStr then
              nSData := FValue
         else nOData := FOPCItem.Value;
       end;

      Break; //ָ�����µĽ��������
    end;                           
  finally
    FSyncLock.Leave;
  end;   
end;

function TOPCManager.Read(const nPoint: string; var nData: string;
  const nTimeout: Integer; const nGroup: string): Boolean;
var nOle: OleVariant;
begin
  Result := ReadData(nGroup, nPoint, nData, nOle, True, nTimeout);
end;

function TOPCManager.Read(const nPoint: string; var nData: OleVariant;
  const nTimeout: Integer; const nGroup: string): Boolean;
var nStr: string;
begin
  Result := ReadData(nGroup, nPoint, nStr, nData, False, nTimeout);
end;

//Date: 2019-07-12
//Parm: �����ļ�
//Desc: ����nFile������
procedure TOPCManager.LoadConfig(const nFile: string);
var nList: TStrings;
    nXML: TNativeXml;
    i,j,k,nIdx,nLen: Integer;
    nRoot,nNode,nTmp: TXmlNode;
begin
  nList := nil;
  nXML := TNativeXml.Create;
  try
    nXML.LoadFromFile(nFile);
    //load config
    nRoot := nXML.Root.NodeByNameR('enable');
    FServer.FEnabled := nRoot.ValueAsString <> 'N';

    nRoot := nXML.Root.NodeByNameR('server');
    with FServer do
    begin
      FID := nRoot.AttributeByName['id'];
      FName := nRoot.AttributeByName['name'];
      FServerID := nRoot.ValueAsString;
    end;

    nRoot := nXML.Root.NodeByNameR('points');
    SetLength(FServer.FItems, nRoot.NodeCount);
    nIdx := Low(FServer.FItems);

    for i:=0 to nRoot.NodeCount - 1 do
    begin
      nNode := nRoot.Nodes[i];
      with FServer.FItems[nIdx] do
      begin
        FID         := nNode.AttributeByName['id'];
        FName       := nNode.AttributeByName['name'];
        FValue      := nNode.AttributeByName['default'];

        FOPCItem    := nil;
        FLastUpdate := 0;
      end;

      Inc(nIdx);
    end;

    nList := TStringList.Create;
    nRoot := nXML.Root.NodeByNameR('groups');
    SetLength(FGroups, nRoot.NodeCount);
    nIdx := Low(FGroups);

    for i:=0 to nRoot.NodeCount - 1 do
    begin
      nNode := nRoot.Nodes[i];
      with FGroups[nIdx] do
      begin
        FID         := nNode.AttributeByName['id'];
        FName       := nNode.AttributeByName['name'];
        FGroupItem  := nil;
        
        FActive     := nNode.NodeByNameR('active').ValueAsString <> 'N';
        FDeadBand   := nNode.NodeByNameR('deadband').ValueAsInteger;
        FUpdateRate := nNode.NodeByNameR('updaterate').ValueAsInteger;

        nTmp := nNode.NodeByName('options');
        if Assigned(nTmp) then
        begin
          FOptions := TStringList.Create;
          SplitStr(nTmp.ValueAsString, FOptions, 0, ';');
        end else FOptions := nil;

        SetLength(FItems, 0);
        SplitStr(nNode.NodeByNameR('points').ValueAsString, nList, 0, ',');

        for j:=nList.Count-1 downto 0 do
        begin
          k := FindPoint(nList[j]);
          if k < 0 then
          begin
            WriteLog(Format('��ڵ�[ %s.%s ]������', [FID, nList[j]]));
            Continue;
          end;

          nLen := Length(FItems);
          SetLength(FItems, nLen + 1);
          FItems[nLen] := FServer.FItems[k];
          FItems[nLen].FServerItem := k;
        end;
      end;

      Inc(nIdx);
    end;
  finally
    nList.Free;
    nXML.Free;
  end;
end;

//------------------------------------------------------------------------------
constructor TOPCThread.Create(AOwner: TOPCManager);
begin
  inherited Create(False);
  FreeOnTerminate := False;

  FOwner := AOwner;
  FWaiter := TWaitObject.Create;
  FWaiter.Interval := 300;
end;

destructor TOPCThread.Destroy;
begin
  FWaiter.Free;
  inherited;
end;

procedure TOPCThread.Wakeup;
begin
  FWaiter.Wakeup;
end;

procedure TOPCThread.StopMe;
begin
  Terminate;
  FWaiter.Wakeup;

  WaitFor;
  Free;
end;

procedure TOPCThread.Execute;
begin
  while not Terminated do
  try
    FWaiter.EnterWait;
    if Terminated then Break;

    with FOwner do
    try
      DoExecute();
    finally
      //ClearServiceDataList(False, soThread);
    end;
  except
    on nErr: Exception do
    begin
      WriteLog(Format('OPC-Service Error: %s %s', [nErr.Message, nerr.ClassName]));
      //log any error
    end;
  end;
end;

procedure TOPCThread.DoExecute;
begin
  with FOwner.FStatus do
   if (not FConnected) and (GetTickCountDiff(FLastConn) > 3 * 1000) then
    Synchronize(DoConnectServer);
  //reconn
end;

//Date: 2019-07-12
//Desc: ���ӷ�����,��������ͽ����
procedure TOPCThread.DoConnectServer;
var i,nIdx: Integer;
    nItem: TdOPCItem;
begin
  with FOwner do
  try
    FSyncLock.Enter;
    //lock first

    WriteLog(Format('Connect OPC-Server(%s.%s)', [FServer.FID, FServer.FName]));
    //logged
    FStatus.FLastConn := GetTickCount();

    if Assigned(FServer.FServerObj) then
    begin
      FServer.FServerObj.Active := False;
      //stop first

      for nIdx:=Low(FGroups) to High(FGroups) do
       with FGroups[nIdx] do
        for i:=Low(FItems) to High(FItems) do
         FItems[i].FOPCItem := nil;
      //reset group's item

      for nIdx:=Low(FServer.FItems) to High(FServer.FItems) do
        FServer.FItems[nIdx].FOPCItem := nil;
      //reset server's item
    end else
    begin
      FServer.FServerObj := TdOPCServer.Create(nil);
      with FServer.FServerObj do
      begin
        KeepAlive := 3200;
        //check the OPC server accessibility

        OnConnect := OnServerConnect;
        OnDisconnect := OnServerDisconnect;
        OnDataChange := OnServerDatachange;
        OnServerShutdown := OnServer_Shutdown;
      end;
    end;

    with FServer.FServerObj do
    begin
      OPCGroups.Clear;
      ServerName := FServer.FServerID;
      Active := True;
    end;

    for nIdx:=Low(FGroups) to High(FGroups) do
    with FGroups[nIdx] do
    begin
      with FServer.FServerObj do
      begin
        FGroupItem := OPCGroups.GetOPCGroup(FID);
        if not Assigned(FGroupItem) then
          FGroupItem := OPCGroups.Add(FID);
        //xxxxx
      end;

      with FGroupItem do
      begin
        OPCItems.RemoveAll;
        FGroupItem.Name := FGroups[nIdx].FID;

        UpdateRate := FUpdateRate;
        DeadBand   := FDeadBand;
        IsActive   := FActive;
      end;

      for i:=Low(FItems) to High(FItems) do
      try
        FItems[i].FGroup := @FGroups[nIdx];
        FItems[i].FOPCItem := nil;
        nItem := FGroupItem.OPCItems.AddItem(FItems[i].FName);

        FItems[i].FOPCItem := nItem;
        FItems[i].FOPCItem.Data := @FItems[i];
      except
        on nErr: Exception do
        begin
          WriteLog(Format('New Group %s.%s Item %s.%s Error: %s', [
            FID, FName, FItems[i].FID, FItems[i].FName, nErr.Message]));
          //xxxxx
        end;
      end;
    end;
  finally
    FSyncLock.Leave;
  end;
end;

initialization
  gOPCManager := nil;
finalization
  FreeAndNil(gOPCManager);
end.
