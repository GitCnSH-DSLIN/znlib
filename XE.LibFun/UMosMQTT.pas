{*******************************************************************************
  ����: dmzn@163.com 2019-06-10
  ����: ����mosquitto��MQTT�ͻ���

  ��ע:
  *.TMQTTPublishItem.FQos: ��Ϣ�ȼ�
    level 0: ���һ�εĴ���,��Ϣ���ܵ��������1��,Ҳ���ܸ������ᵽ��.
    level 1: ����һ�εĴ���,���������յ���Ϣ�ᱻȷ��,ͨ������һ��PUBACK��Ϣ.
      �����һ�����Ա��ϵĴ���ʧ��,������ͨѶ���ӻ��Ƿ����豸,���ǹ���һ��ʱ��
      ȷ����Ϣû���յ�,���ͷ����Ὣ��Ϣͷ��DUPλ��1,Ȼ���ٴη�����Ϣ.
    level 2: ֻ��һ�εĴ���,��level 1�ϸ��ӵ�Э������֤���ظ�����Ϣ���ᴫ�͵�
      ���յ�Ӧ��.
  *.TMQTTPublishItem.FRetain: ������Ϣ����
    Broker��洢ÿ��Topic�����һ��������Ϣ����Qos,�����ĸ�Topic�Ŀͻ������ߺ�,
    Broker��Ҫ������ϢͶ�ݸ���.
*******************************************************************************}
unit UMosMQTT;

interface

uses
  System.Classes, System.SysUtils, System.SyncObjs, Winapi.Windows, UMosquitto,
  UManagerGroup, UThreadPool, ULibFun, System.AnsiStrings;

type
  PMQTTTopicItem = ^TMQTTTopicItem;
  TMQTTTopicItem = record
    FEnabled: Boolean;                       //��Ч��ʶ
    FTopic: AnsiString;                      //��������
    FChannel: Integer;                       //���ı��
    FQos: Integer;                           //qos
    FHasSub: Boolean;                        //�Ѷ���
    FLastSub: Cardinal;                      //������
  end;
  TMQTTTopicItems = array of TMQTTTopicItem;

  PMQTTPublishItem = ^TMQTTPublishItem;
  TMQTTPublishItem = record
    FEnabled: Boolean;                       //��Ч��ʶ
    FTopic: AnsiString;                      //����
    FPayload: string;                        //����
    FQos: Integer;                           //qos
    FRetain: Boolean;                        //�Ƿ���
    FLastPub: Cardinal;                      //����ʱ��
  end;
  TMQTTPublishItems = array of TMQTTPublishItem;

  PMQTTClientData = ^TMQTTClientData;
  TMQTTClientData = record
    FClient: TObject;                        //�ͻ��˶���
    FServerHost: string;
    FServerPort: Integer;                    //Broker

    FThreadRunning: Boolean;                 //������
    FDisconnecting: Boolean;                 //���ڶϿ�
    FSubscribeAllTopics: Boolean;            //ȫ������
    FHasNewPublishItem: Boolean;             //�д�����Ϣ
  end;

  TMQTTOnConnect = procedure (const nServer: string; const nPort: Integer;
    const nConnected: Boolean);
  TMQTTOnMessage = procedure (const nTopic,nPayload: string);

  TMQTTClient = class(TObject)
  private
    FServerHost: string;
    FServerPort: Integer;
    FUserName: string;
    FPassword: string;
    FKeepAlive: Integer;
    {*������*}
    FClientID: string;
    FClient: p_mosquitto;
    FClientData: TMQTTClientData;
    {*�ͻ���*}
    FTopics: TMQTTTopicItems;
    FPublishs: TMQTTPublishItems;
    FNowPublish: TMQTTPublishItem;
    {*���ķ���*}
    FDetailLog: Boolean;
    {*��ϸ��־*}
    FSyncLock: TCriticalSection;
    {*ͬ������*}
    FOnConnect: TMQTTOnConnect;
    FOnMessage: TMQTTOnMessage;
    {*�¼����*}
  protected
    procedure DoThreadWork(const nConfig: PThreadWorkerConfig;
      const nThread: TThread);
    {*�߳�ҵ��*}
    function FindTopic(const nTopic: AnsiString): Integer;
    {*��������*}
    procedure SubscribeTopics();
    {*��������*}
    procedure PublishData(const nThread: TThread);
    {*������Ϣ*}
    procedure ResetAllTopicStatus();
    {*����״̬*}
  public
    constructor Create;
    destructor Destroy; override;
    {*�����ͷ�*}
    procedure ConnectBroker;
    procedure Disconnect;
    {*���ӶϿ�*}
    procedure AddTopic(const nTopic: string; const nQos: Integer = MOSQ_QOS_0);
    procedure DelTopic(const nTopic: string);
    {*��������*}
    procedure Publish(const nTopic, nPayload: string;
      const nRetain: Boolean = False; const nQos: Integer = MOSQ_QOS_0);
    {*������Ϣ*}
    property ServerHost: string read FServerHost write FServerHost;
    property ServerPort: Integer read FServerPort write FServerPort;
    property UserName: string read FUserName write FUserName;
    property Password: string read FPassword write FPassword;
    property KeepAlive: Integer read FKeepAlive write FKeepAlive;
    property DetailLog: Boolean read FDetailLog write FDetailLog;
    property OnConnect: TMQTTOnConnect read FOnConnect write FOnConnect;
    property OnMessage: TMQTTOnMessage read FOnMessage write FOnMessage;
    {*�����¼�*}
  end;

implementation

procedure WriteLog(const nEvent: string);
begin
  gMG.FLogManager.AddLog(TMQTTClient, 'MQTT-Client', nEvent);
end;

//Date: 2019-06-26
//Desc: ����Broker����
procedure on_connect(mosq: p_mosquitto; obj: Pointer; rc: Integer); cdecl;
var nStr: string;
    nClient: TMQTTClient;
    nData: PMQTTClientData;
begin
  case rc of
    0: nStr := '�ɹ�';
    1: nStr := '���ӱ��ܾ�(��֧�ֵ�Э��汾)';
    2: nStr := '���ӱ�����(identifier���ܾ�)';
    3: nStr := '���ӱ��ܾ�(Զ�̷��񲻿���)'
    else
      nStr := 'δ֪';
  end;

  nData := obj;
  WriteLog(Format('����Զ�̷���[ %s,%d ]: %s', [nData.FServerHost,
    nData.FServerPort, nStr]));
  //conn log

  if rc = 0 then
  begin
    nClient := nData.FClient as TMQTTClient;
    //client obj

    if Assigned(nClient.FOnConnect) then
      nClient.FOnConnect(nData.FServerHost, nData.FServerPort, True);
    //event
  end;
end;

//Date: 2019-06-26
//Desc: Զ��Broker�Ͽ�
procedure on_disconnect(mosq: p_mosquitto; obj: Pointer; rc: Integer); cdecl;
var nStr: string;
    nClient: TMQTTClient;
    nData: PMQTTClientData;
begin
  if rc = 0 then
       nStr := '�ͻ��������Ͽ�'
  else nStr := '�����쳣�Ͽ�';

  nData := obj;
  WriteLog(Format('Զ�̷���[ %s,%d ]�ѶϿ�: %s', [nData.FServerHost,
    nData.FServerPort, nStr]));
  //conn log

  if rc = 0 then
  begin
    nClient := nData.FClient as TMQTTClient;
    //client obj

    if Assigned(nClient.FOnConnect) then
      nClient.FOnConnect(nData.FServerHost, nData.FServerPort, False);
    //event
  end;
end;

//Date: 2019-06-26
//Desc: ���ⶩ�����
procedure on_subscribe(mosq: p_mosquitto; obj: Pointer; mid: Integer;
 qos_count: Integer; const granted_qos: PInteger); cdecl;
var nIdx: Integer;
    nClient: TMQTTClient;
    nData: PMQTTClientData;
begin
  nData := obj;
  nClient := nData.FClient as TMQTTClient;
  //client obj

  with nClient do
  begin
    for nIdx := Low(FTopics) to High(FTopics) do
    if FTopics[nIdx].FChannel = mid then
    begin
      FTopics[nIdx].FHasSub := True;
      //sub flag

      WriteLog(Format('Զ�̷���[ %s,%d ]����: %s,�ɹ�', [nData.FServerHost,
        nData.FServerPort, nClient.FTopics[nIdx].FTopic]));
      //conn log
    end;
  end;
end;

//Date: 2019-06-26
//Desc: ȡ�����ⶩ��
procedure on_unsubscribe(mosq: p_mosquitto; obj: Pointer; mid: Integer); cdecl;
var nIdx: Integer;
    nClient: TMQTTClient;
    nData: PMQTTClientData;
begin
  nData := obj;
  nClient := nData.FClient as TMQTTClient;
  //client obj

  with nClient do
  begin
    for nIdx := Low(FTopics) to High(FTopics) do
    if FTopics[nIdx].FChannel = mid then
    begin
      FTopics[nIdx].FHasSub := False;
      //sub flag

      WriteLog(Format('Զ�̷���[ %s,%d ]ȡ������: %s,�ɹ�', [nData.FServerHost,
        nData.FServerPort, nClient.FTopics[nIdx].FTopic]));
      //conn log
    end;
  end;
end;

//Date: 2019-06-26
//Desc: ������ϸ��־
procedure on_log(mosq: p_mosquitto; obj: Pointer; level: Integer;
 const str: PAnsiChar); cdecl;
begin
  WriteLog(Format('%s,%d: %s', [PMQTTClientData(obj).FServerHost,
    PMQTTClientData(obj).FServerPort, System.AnsiStrings.StrPas(str)]));
  //conn log
end;

//Date: 2019-06-26
//Desc: ��������
procedure on_publish(mosq: p_mosquitto; obj: Pointer; mid: Integer); cdecl;
begin
  //nothing
end;

//Date: 2019-06-26
//Desc: �յ���Ϣ
procedure on_message(mosq: p_mosquitto; obj: Pointer;
 const msg: p_mosquitto_message); cdecl;
var nTopic,nPayload: string;
    nClient: TMQTTClient;
begin
  nClient := PMQTTClientData(obj).FClient as TMQTTClient;
  //client obj

  if Assigned(nClient.FOnMessage) then
  begin
    nTopic := UTF8ToUnicodeString(msg.topic);
    nPayload := UTF8ToUnicodeString(PAnsiChar(msg.payload));

    if Assigned(nClient.FOnMessage) then
      nClient.FOnMessage(nTopic, nPayload);
    //xxxxx
  end;
end;

//------------------------------------------------------------------------------
constructor TMQTTClient.Create;
var nStr: string;
    nRes: Integer;
    major,minor,revision: Integer;
    nWorker: TThreadWorkerConfig;
begin
  inherited;
  FUserName := '';
  FPassword := '';
  FServerPort := 1883;
  FServerHost := '127.0.0.1';

  FKeepAlive := 600;
  FDetailLog := False;
  SetLength(FTopics, 0);
  SetLength(FPublishs, 0);
  FSyncLock := TCriticalSection.Create;

  FClient := nil;
  FClientID := GUIDToString(TGUID.NewGuid);
  FillChar(FClientData, SizeOf(FClientData), #0);

  mosquitto_lib_version(@major, @minor, @revision);
  if not ((major = LIBMOSQUITTO_MAJOR) and (minor = LIBMOSQUITTO_MINOR) and
          (revision = LIBMOSQUITTO_REVISION)) then
  begin
    nStr := Format('MOS��汾��ƥ��(%d.%d.%d - %d.%d.%d)', [major, minor,
      revision, LIBMOSQUITTO_MAJOR, LIBMOSQUITTO_MINOR, LIBMOSQUITTO_REVISION]);
    //xxxxx

    WriteLog(nStr);
    raise Exception.Create(nStr);
  end;
  //xxxxx

  nRes := mosquitto_lib_init();
  if nRes <> MOSQ_ERR_SUCCESS then
  begin
    nStr := Format('lib_init error: %d,%s', [nRes, mosquitto_strerror(nRes)]);
    WriteLog(nStr);
    raise Exception.Create(nStr);
  end;

  gMG.FThreadPool.WorkerInit(nWorker);
  with nWorker do
  begin
    FWorkerName   := 'TMQTTClient.DoWork';
    FParentObj    := Self;
    FParentDesc   := 'MQTT-Client';
    FCallTimes    := 0; //��ͣ
    FCallInterval := 100;
    FProcEvent    := DoThreadWork;
  end;

  gMG.FThreadPool.WorkerAdd(@nWorker);
  //����߳���ҵ
end;

destructor TMQTTClient.Destroy;
begin
  Disconnect;
  //clear conn first

  mosquitto_lib_cleanup();
  FreeAndNil(FSyncLock);
  inherited;
end;

//Date: 2019-06-21
//Parm: ����
//Desc: ����nTopic,��������
function TMQTTClient.FindTopic(const nTopic: AnsiString): Integer;
var nIdx: Integer;
begin
  Result := -1;
  //default

  for nIdx := Low(FTopics) to High(FTopics) do
  with FTopics[nIdx] do
  begin
    if (not FEnabled) or (FTopic <> nTopic) then Continue;
    //not match

    Result := nIdx;
    Break;
  end;
end;

//Date: 2019-06-21
//Parm: ��������;qos
//Desc: ���nTopic����
procedure TMQTTClient.AddTopic(const nTopic: string; const nQos: Integer);
var nIdx,nRes: Integer;
begin
  nRes := mosquitto_sub_topic_check(PAnsiChar(AnsiString(nTopic)));
  if nRes <> MOSQ_ERR_SUCCESS then
  begin
    WriteLog(Format('AddTopic Error: %d,%s', [nRes, mosquitto_strerror(nRes)]));
    Exit;
  end;

  FSyncLock.Enter;
  try
    nIdx := FindTopic(AnsiString(nTopic));
    if nIdx <> -1 then Exit; //exists

    nIdx := Length(FTopics);
    SetLength(FTopics, nIdx + 1);

    with FTopics[nIdx] do
    begin
      FEnabled  := True;
      FTopic    := AnsiString(nTopic);
      FChannel  := nIdx;
      FQos      := nQos;
      FHasSub   := False;
      FLastSub  := 0;
    end;

    FClientData.FSubscribeAllTopics := False;
    //subscribe flag
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2019-06-21
//Parm: ��������
//Desc: ȡ��nTopic����
procedure TMQTTClient.DelTopic(const nTopic: string);
var nIdx: Integer;
begin
  FSyncLock.Enter;
  try
    nIdx := FindTopic(AnsiString(nTopic));
    if nIdx <> -1 then
    begin
      FTopics[nIdx].FEnabled := False;
      if FTopics[nIdx].FHasSub then
        FClientData.FSubscribeAllTopics := False;
      //unsubscribe flag
    end;
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2019-06-21
//Parm: ����;����;�Ƿ���;qos
//Desc: ��nTopic����һ��nPayload��Ϣ
procedure TMQTTClient.Publish(const nTopic, nPayload: string;
  const nRetain: Boolean; const nQos: Integer);
var nRes: Integer;
    i,nIdx,nTimeout: Integer;
begin
  nRes := mosquitto_pub_topic_check(PAnsiChar(AnsiString(nTopic)));
  if nRes <> MOSQ_ERR_SUCCESS then
  begin
    WriteLog(Format('Publish Error: %d,%s', [nRes, mosquitto_strerror(nRes)]));
    Exit;
  end;

  FSyncLock.Enter;
  try
    nIdx := -1;
    nTimeout := -1;
    //init

    for i := Low(FPublishs) to High(FPublishs) do
    begin
      if FPublishs[i].FEnabled then
      begin
        if (nTimeout = -1) and (TDateTimeHelper.GetTickCountDiff
           (FPublishs[i].FLastPub) > 10 * 1000) then
          nTimeout := i;
        Continue;
      end;

      nIdx := i; //�ظ�ʹ����Ч�ڵ�
      Break;
    end;

    if nIdx = -1 then
      nIdx := nTimeout;
    //�ظ�ʹ�ó�ʱ�ڵ�

    if nIdx = -1 then
    begin
      nIdx := Length(FPublishs);
      SetLength(FPublishs, nIdx + 1);
    end;

    with FPublishs[nIdx] do
    begin
      FEnabled := True;
      FTopic   := AnsiString(nTopic);
      FPayload := nPayload;
      FQos     := nQos;
      FRetain  := nRetain;
      FLastPub := GetTickCount();
    end;

    FClientData.FHasNewPublishItem := True;
    //publish flag
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2019-06-21
//Desc: ������������Ϊδ����״̬
procedure TMQTTClient.ResetAllTopicStatus;
var nIdx: Integer;
begin
  FSyncLock.Enter;
  try
    for nIdx := Low(FTopics) to High(FTopics) do
      if FTopics[nIdx].FEnabled then
        FTopics[nIdx].FHasSub := False;
    //set flag

    FClientData.FSubscribeAllTopics := False;
    //subscribe flag
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2019-06-21
//Desc: ������������
procedure TMQTTClient.SubscribeTopics;
var nIdx,nInt,nRes: Integer;
begin
  FSyncLock.Enter;
  try
    nInt := 0;
    //init

    for nIdx := Low(FTopics) to High(FTopics) do
    with FTopics[nIdx] do
    begin
      if not FEnabled then
      begin
        if FHasSub then //ȡ������
        begin
          FHasSub := False;
          nRes := mosquitto_unsubscribe(FClient, @FChannel, PAnsiChar(FTopic));

          if nRes <> MOSQ_ERR_SUCCESS then
          begin
            WriteLog(Format('Unsubscribe Error: %d,%s', [nRes, mosquitto_strerror(nRes)]));
          end;
        end;

        Continue;
      end;

      if FHasSub then Continue;
      //sub done
      Inc(nInt);

      if TDateTimeHelper.GetTickCountDiff(FLastSub, tdNow) < 5 * 1000 then
        Continue;
      FLastSub := GetTickCount();

      nRes := mosquitto_subscribe(FClient, @FChannel, PAnsiChar(FTopic), FQos);
      if nRes <> MOSQ_ERR_SUCCESS then
      begin
        WriteLog(Format('Subscribe Error: %d,%s', [nRes, mosquitto_strerror(nRes)]));
      end;
    end;

    if nInt = 0 then
      FClientData.FSubscribeAllTopics := True;
    //xxxxx
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2019-06-26
//Desc: ��������
procedure TMQTTClient.PublishData(const nThread: TThread);
var nIdx: Integer;
    nBuf: AnsiString;
begin
  while not nThread.CheckTerminated do
  begin
    FSyncLock.Enter;
    try
      if FClientData.FDisconnecting then
        Exit;
      //try to disconn
      FNowPublish.FEnabled := False;

      for nIdx := Low(FPublishs) to High(FPublishs) do
      with FPublishs[nIdx] do
      begin
        if not FEnabled then Continue;
        //invalid item

        FNowPublish := FPublishs[nIdx];
        FEnabled := False;
        Break;
      end;

      if not FNowPublish.FEnabled then
      begin
        FClientData.FHasNewPublishItem := False;
        Exit;
      end;
    finally
      FSyncLock.Leave;
    end;

    with FNowPublish do
    begin
      nBuf := UTF8EncodeToShortString(FPayload);
      mosquitto_publish(FClient, nil, PAnsiChar(FTopic), Length(nBuf),
        PAnsiChar(nBuf), FQos, FRetain);
      //send message
    end;
  end;
end;

//------------------------------------------------------------------------------
//Date: 2019-06-21
//Desc: ����Զ�̷���
procedure TMQTTClient.ConnectBroker;
begin
  if not Assigned(FClient) then
  begin
    FClientData.FClient := Self;
    FClientData.FServerHost := FServerHost;
    FClientData.FServerPort := FServerPort;

    FClient := mosquitto_new(PAnsiChar(AnsiString(FClientID)), True, @FClientData);
    //new client

    mosquitto_connect_callback_set(FClient, on_connect);
    mosquitto_disconnect_callback_set(FClient, on_disconnect);
    mosquitto_message_callback_set(FClient, on_message);
    mosquitto_subscribe_callback_set(FClient, on_subscribe);
    mosquitto_unsubscribe_callback_set(FClient, on_unsubscribe);
    mosquitto_publish_callback_set(FClient, on_publish);
    //call back event

    if FDetailLog then
         mosquitto_log_callback_set(FClient, on_log)
    else mosquitto_log_callback_set(FClient, nil);

    if FUserName <> '' then
      mosquitto_username_pw_set(FClient, PAnsiChar(AnsiString(FUserName)),
        PAnsiChar(AnsiString(FPassword)));
    //set credentials
  end;

  FSyncLock.Enter;
  try
    FClientData.FDisconnecting := False;
  finally
    FSyncLock.Leave;
  end;

  mosquitto_loop_start(FClient);
  gMG.FThreadPool.WorkerStart(Self);
  //start thread
end;

//Date: 2019-06-21
//Desc: �Ͽ�Զ�̷���
procedure TMQTTClient.Disconnect;
var nClient: p_mosquitto;
begin
  while True do
  begin
    FSyncLock.Enter;
    try
      if not FClientData.FDisconnecting then
        FClientData.FDisconnecting := True;
      //set disconn flag

      if not FClientData.FThreadRunning then
        Break;
      //thread exit
    finally
      FSyncLock.Leave;
    end;

    Sleep(1);
  end;

  if Assigned(FClient) then
  begin
    nClient := FClient;
    FClient := nil;
    //try clear client

    mosquitto_loop_stop(nClient, True);
    mosquitto_disconnect(nClient);
    mosquitto_destroy(nClient);
  end;

  gMG.FThreadPool.WorkerStop(Self);
  //stop thread
end;

procedure TMQTTClient.DoThreadWork(const nConfig: PThreadWorkerConfig;
 const nThread: TThread);
var nRes: Integer;
begin
  try
    FSyncLock.Enter;
    try
      FClientData.FThreadRunning := True;
      //set running flag

      if FClientData.FDisconnecting then
      begin
        nConfig.FCallTimes := 0;
        Exit;
      end;
    finally
      FSyncLock.Leave;
    end;

    nRes := mosquitto_loop(FClient, 100, 1);
    if nRes <> MOSQ_ERR_SUCCESS then //any error
    begin
      if (nRes = MOSQ_ERR_NO_CONN) or (nRes = MOSQ_ERR_CONN_LOST) then
      begin
        WriteLog(Format('connect remote broker: %d,%s', [nRes,
          mosquitto_strerror(nRes)]));
        //xxxxx

        ResetAllTopicStatus();
        //set unsubcribe flag

        mosquitto_connect(FClient, PAnsiChar(AnsiString(FClientData.FServerHost)),
          FClientData.FServerPort, FKeepAlive);
        //conn broker
      end
      else
      begin
        WriteLog(Format('mosquitto_loop error: %d,%s', [nRes,
          mosquitto_strerror(nRes)]));
        //xxxxx
      end;

      Exit;
    end;

    if not FClientData.FSubscribeAllTopics then
    begin
      SubscribeTopics();
      Exit;
    end;

    if FClientData.FHasNewPublishItem then
      PublishData(nThread);
    //xxxxx
  finally
    FSyncLock.Enter;
    try
      FClientData.FThreadRunning := False;
    finally
      FSyncLock.Leave;
    end;
  end;
end;

end.
