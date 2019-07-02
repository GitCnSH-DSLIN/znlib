{*******************************************************************************
  ����: dmzn@163.com 2019-06-28
  ����: ֧��FireMoney������PostMessage����

  ��ע:
  *.PostMessage�̰߳�ȫ.
  *.��Ϣ������˳���Ⱥ����,��: ��Post����Ϣ��ִ��.
*******************************************************************************}
unit FMX.PostMsg;

interface

uses
  System.Classes, System.SysUtils, System.Messaging, FMX.Types, ULibFun,
  ULibConst;

procedure SyncPostMessage(const nHandle: TMessageHandle;
  const nSender: TObject; const nMsg: Integer;
  const nWParam,nLParam: NativeInt); overload;
procedure SyncPostMessage(const nHandle: TMessageHandleRef;
  const nSender: TObject; const nMsg: Integer;
  const nWParam,nLParam: NativeInt); overload;
//sync message
procedure SyncPostAbort(const nSender: TObject);
//abort sync

implementation

type
  TMessageQueue = class(TObject)
  private
    class var FQueue:TMessageQueue;
    {*���ж���*}
  protected
    FMsgID: Integer;
    {*��Ϣ��ʶ*}
    FItems: TMessageItems;
    {*��Ϣ�б�*}
    FHasMessage: Boolean;
    FNowItem: TMessageItem;
    {*��Ϣ��ʶ*}
    procedure ProcessMessage;
    {*������Ϣ*}
  public
    constructor Create;
    destructor Destroy; override;
    {*�����ͷ�*}
    class function DefaultQueue(const nRelease: Boolean = False): TMessageQueue;
    {*Ĭ��ʵ��*}
    procedure Post(const nHandle: TMessageHandle;
      const nHandleRef: TMessageHandleRef; const nSender: TObject;
      const nMsg: Integer; const nWParam,nLParam: NativeInt);
    {*�����Ϣ*}
    procedure AbortPost(const nSender: TObject);
    {*������Ϣ*}
  end;

constructor TMessageQueue.Create;
begin
  inherited Create;
  FHasMessage := False;
  SetLength(FItems, 0);

  FMsgID := TMessageManager.DefaultManager.SubscribeToMessage(TIdleMessage,
    procedure (const Sender: TObject; const nMsg: TMessage)
    begin
      ProcessMessage();
    end
  );
end;

destructor TMessageQueue.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(TIdleMessage, FMsgID);
  inherited;
end;

class function TMessageQueue.DefaultQueue(const nRelease: Boolean): TMessageQueue;
begin
  if nRelease then
  begin
    if Assigned(FQueue) then
      FreeAndNil(FQueue);
    //xxxxx
  end else
  begin
    if not Assigned(FQueue) then
      FQueue := TMessageQueue.Create;
    //xxxxx
  end;

  Result := FQueue;
end;

procedure TMessageQueue.Post(const nHandle: TMessageHandle;
  const nHandleRef: TMessageHandleRef; const nSender: TObject;
  const nMsg: Integer; const nWParam,nLParam: NativeInt);
var nIdx,nInt,nOldest: Integer;
    nOld,nTD: Cardinal;
begin
  TMonitor.Enter(Self);
  try
    nInt := -1;
    nOld := 0;
    nOldest := -1;

    for nIdx := Low(FItems) to High(FItems) do
    with FItems[nIdx] do
    begin
      if FEnabled then
      begin
        nTD := TDateTimeHelper.GetTickCountDiff(FLastUsed);
        if nTD > nOld then
        begin
          nOld := nTD;
          nOldest := nIdx;
        end;
      end else
      begin
        nInt := nIdx; //1.����ʹ����Ч��
        Break;
      end;
    end;

    if nInt < 0 then
    begin
      nIdx := Length(FItems);
      if nIdx < cMessageBufferMax then //2.�½���
      begin
        nInt := nIdx;
        SetLength(FItems, nInt + 1);
      end;
    end;

    if nInt < 0 then
      nInt := nOldest; //3.���Ǿ�����
    //xxxxx

    if nInt < 0 then
    begin
      if Assigned(WakeMainThread) then
        WakeMainThread(nSender); //֪ͨ���̼߳ӿ촦��
      Exit;
    end;

    with FItems[nInt] do
    begin
      FEnabled   := True;
      FHandle    := nHandle;
      FHandleRef := nHandleRef;

      FSender    := nSender;
      FMsg       := nMsg;
      FWParam    := nWParam;
      FLParam    := nLParam;

      FIsFirst   := True;
      FNextItem  := -1;
    end;

    for nIdx := Low(FItems) to High(FItems) do
    begin
      if (not FItems[nIdx].FEnabled) or (nIdx = nInt) then Continue;
      //invalid

      if FItems[nIdx].FNextItem = -1 then
      begin
        FItems[nIdx].FNextItem := nInt;
        FItems[nInt].FIsFirst := False;
        Break;
      end;
    end;

    FHasMessage := True;
    //set flag
  finally
    TMonitor.Exit(Self);
  end;

  if Assigned(WakeMainThread) then
    WakeMainThread(nSender);
  //xxxxx
end;

procedure TMessageQueue.AbortPost(const nSender: TObject);
var nIdx: Integer;
begin
  TMonitor.Enter(Self);
  try
    for nIdx := Low(FItems) to High(FItems) do
    with FItems[nIdx] do
    begin
      if FEnabled and (FSender = nSender) then
        FEnabled := False;
      //xxxxx
    end;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TMessageQueue.ProcessMessage;
var nIdx: Integer;
begin
  while True do
  begin
    TMonitor.Enter(Self);
    try
      if not FHasMessage then Exit;
      //no message
      FNowItem.FEnabled := False;

      for nIdx := Low(FItems) to High(FItems) do
      with FItems[nIdx] do
      begin
        if not (FEnabled and FIsFirst) then Continue;
        //invalid

        FNowItem := FItems[nIdx];
        FEnabled := False;
        FIsFirst := False;

        if FNextItem <> -1 then
          FItems[FNextItem].FIsFirst := True;
        Break;
      end;

      if not FNowItem.FEnabled then
      begin
        FHasMessage := False;
        //set flag

        if Length(FItems) >= 10 then
          SetLength(FItems, 5);
        Exit;
      end; //no message
    finally
      TMonitor.Exit(Self);
    end;

    with FNowItem do
    begin
      if Assigned(FHandle) then
        FHandle(FSender, FMsg, FWParam, FLParam);
      //xxxxx

      if Assigned(FHandleRef) then
        FHandleRef(FSender, FMsg, FWParam, FLParam);
      //xxxxx
    end;
  end;
end;

//------------------------------------------------------------------------------
//Date: 2019-06-28
//Parm: �ص�;���÷�;��Ϣ;�ߵͲ���
//Desc: ������Ϣ����Ϣ����
procedure SyncPostMessage(const nHandle: TMessageHandle; const nSender: TObject;
  const nMsg: Integer; const nWParam,nLParam: NativeInt);
begin
  TMessageQueue.DefaultQueue.Post(nHandle, nil, nSender, nMsg, nWParam, nLParam);
end;

procedure SyncPostMessage(const nHandle: TMessageHandleRef; const nSender: TObject;
  const nMsg: Integer; const nWParam,nLParam: NativeInt);
begin
  TMessageQueue.DefaultQueue.Post(nil, nHandle, nSender, nMsg, nWParam, nLParam);
end;

//Date: 2019-07-02
//Parm: ���÷�
//Desc: ����nSender��������Ϣ
procedure SyncPostAbort(const nSender: TObject);
begin
  TMessageQueue.DefaultQueue.AbortPost(nSender);
end;

initialization
  TMessageQueue.FQueue := nil;
  TMessageQueue.DefaultQueue(False);
finalization
  TMessageQueue.DefaultQueue(True);
end.
