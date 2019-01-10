{*******************************************************************************
  ����: dmzn@163.com 2019-01-09
  ����: �̳߳�
*******************************************************************************}
unit UThreadPool;

interface

uses
  System.Classes, System.SysUtils, Winapi.Windows, UWaitItem, UBaseObject;

type
  TThreadPoolManager = class;
  PThreadWorkerConfig = ^TThreadWorkerConfig;

  TThreadProcedure = procedure (const nConfig: PThreadWorkerConfig;
    const nThread: TThread);
  TThreadProcEvent = procedure (const nConfig: PThreadWorkerConfig;
    const nThread: TThread) of object;
  TThreadProcRefer = reference to procedure (const nConfig: PThreadWorkerConfig;
    const nThread: TThread);
  {*�߳������к���*}

  TThreadWorkerConfig = record
  private
  const
    cDim = 2;
    {*�����±�*}
  public
    FParentObj    : TObject;                     //�̵߳��÷�
    FParentDesc   : string;                      //���÷�����
    FDataString   : array[0..cDim] of string;    //�ַ���
    FDataInteger  : array[0..cDim] of Integer;   //����ֵ
    FDataFloat    : array[0..cDim] of Double;    //������
    FDataPointer  : array[0..cDim] of Pointer;   //����ָ��

    FCallTimes    : Cardinal;                    //ִ�д���
    FCallInterval : Cardinal;                    //ִ�м��(����)
    FProcedure    : TThreadProcedure;            //��ִ�к���
    FProcEvent    : TThreadProcEvent;            //��ִ���¼�
    FProcRefer    : TThreadProcRefer;            //��ִ������
  end;

  PThreadWorker = ^TThreadWorker;
  TThreadWorker = record
    FWorkerID     : Cardinal;                    //�����ʶ
    FWorker       : TThreadWorkerConfig;         //��������
    FLastCall     : Int64;                       //�ϴε���
    FStartCall    : Int64;                       //��ʼ����
    FStartDelete  : Int64;                       //��ʼɾ��
  end;

  TThreadRunner = class(TThread)
  private
    FOwner: TThreadPoolManager;
    {*ӵ����*}
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TThreadPoolManager);
    destructor Destroy; override;
    {*�����ͷ�*}
    procedure StopMe;
    {*ֹͣ�߳�*}
  end;

  TThreadMonitor = class(TThread)
  private
    FOwner: TThreadPoolManager;
    {*ӵ����*}
    FWaiter: TWaitObject;
    {*�ȴ�����*}
  protected
    procedure DoMonitor;
    procedure Execute; override;
  public
    constructor Create(AOwner: TThreadPoolManager);
    destructor Destroy; override;
    {*�����ͷ�*}
    procedure Wakeup;
    {*�����߳�*}
    procedure StopMe;
    {*ֹͣ�߳�*}
  end;

  TThreadPoolManager = class(TManagerBase)
  private
    FWorkers: TList;
    {*��������*}
    FMonitor: TThreadMonitor;
    {*�ػ��߳�*}
    FRunners: array of TThreadRunner;
    {*���ж���*}
  protected
    procedure StopRunners;
    procedure ClearWorkers(const nFree: Boolean);
    {*������Դ*}
  public
    constructor Create;
    destructor Destroy; override;
    {*�����ͷ�*}
    class procedure RegistMe(const nReg: Boolean); override;
    {*ע�����*}
    procedure GetStatus(const nList: TStrings;
      const nFriendly: Boolean = True); override;
    function GetHealth(const nList: TStrings = nil): TObjectHealth; override;
    {*��ȡ״̬*}
    procedure WorkerInit(var nWorker: TThreadWorkerConfig);
    function WorkerAdd(const nWorker: PThreadWorkerConfig;
      const nMulti: Boolean = True): Cardinal;
    procedure WorkerDelete(const nWorkerID: Cardinal); overload;
    procedure WorkerDelete(const nParent: TObject); overload;
    {*���ɾ��*}
    procedure WorkerStart(const nWorkerID: Cardinal;
      const nTimes: Cardinal = INFINITE); overload;
    procedure WorkerStart(const nParent: TObject;
      const nTimes: Cardinal = INFINITE); overload;
    procedure WorkerStop(const nWorkerID: Cardinal); overload;
    procedure WorkerStop(const nParent: TObject); overload;
    {*����ֹͣ*}
  end;

var
  gThreadPoolManager: TThreadPoolManager = nil;
  //ȫ��ʹ��

implementation

uses
  UManagerGroup;

constructor TThreadPoolManager.Create;
begin
  FWorkers := TList.Create;
  SetLength(FRunners, 0);
  FMonitor := TThreadMonitor.Create(Self);
end;

destructor TThreadPoolManager.Destroy;
begin
  FMonitor.StopMe;
  FMonitor := nil;
  StopRunners;

  ClearWorkers(True);
  inherited;
end;

procedure TThreadPoolManager.StopRunners;
var nIdx: Integer;
begin
  for nIdx := Low(FRunners) to High(FRunners) do
  if Assigned(FRunners[nIdx]) then
  begin
    FRunners[nIdx].StopMe;
    FRunners[nIdx] := nil;
  end;

  SetLength(FRunners, 0);
end;

procedure TThreadPoolManager.ClearWorkers(const nFree: Boolean);
var nIdx: Integer;
    nWorker: PThreadWorker;
begin
  for nIdx := FWorkers.Count-1 downto 0 do
  begin
    nWorker := FWorkers[nIdx];
    Dispose(nWorker);
  end;

  if nFree then
       FreeAndNil(FWorkers)
  else FWorkers.Clear;
end;

//Date: 2019-01-09
//Parm: �Ƿ�ע��
//Desc: ��ϵͳע�����������
class procedure TThreadPoolManager.RegistMe(const nReg: Boolean);
var nIdx: Integer;
begin
  nIdx := GetMe(TThreadPoolManager);
  if nReg then
  begin
    if not Assigned(FManagers[nIdx].FManager) then
      FManagers[nIdx].FManager := TThreadPoolManager.Create;
    gMG.FThreadPool := FManagers[nIdx].FManager as TThreadPoolManager;
  end else
  begin
    gMG.FThreadPool := nil;
    FreeAndNil(FManagers[nIdx].FManager);
  end;
end;

//Date: 2019-01-09
//Parm: ������
//Desc: ��ʼ��nConfig
procedure TThreadPoolManager.WorkerInit(var nWorker: TThreadWorkerConfig);
var nInit: TThreadWorkerConfig;
begin
  FillChar(nInit, SizeOf(nInit), #0);
  nWorker := nInit;

  with nWorker do
  begin
    FCallTimes := INFINITE;
    //���޴���
  end;
end;

//Date: 2019-01-09
//Parm: ��������;��������
//Desc: ���nWorker
function TThreadPoolManager.WorkerAdd(const nWorker: PThreadWorkerConfig;
  const nMulti: Boolean): Cardinal;
var nIdx: Integer;
    nPWorker: PThreadWorker;
begin
  Result := 0;
  gMG.CheckSupport('TThreadPoolManager', ['TSerialIDManager']);

  SyncEnter;
  try
    if not nMulti then
    begin
      for nIdx := FWorkers.Count-1 downto 0 do
      begin
        nPWorker := FWorkers[nIdx];
        if nPWorker.FWorker.FParentObj = nWorker.FParentObj then Exit;
        //���÷���ͬ
      end;
    end;

    New(nPWorker);
    FWorkers.Add(nPWorker);
    nPWorker.FWorkerID := gMG.FSerialIDManager.GetID;

    nPWorker.FLastCall := 0;
    nPWorker.FStartCall := 0;
    nPWorker.FStartDelete := 0;
    nPWorker.FWorker := nWorker^;
  finally
    SyncLeave;
  end;

  FMonitor.Wakeup;
  //�ػ��߳�ƽ������
end;

//Date: 2019-01-10
//Parm: ���÷�
//Desc: ɾ��nParent������Worker
procedure TThreadPoolManager.WorkerDelete(const nParent: TObject);
var nIdx,nLen: Integer;
    nWorker: PThreadWorker;
    nWorkers: array of Cardinal;
begin
  SyncEnter;
  try
    SetLength(nWorkers, 0);
    for nIdx := FWorkers.Count-1 downto 0 do
    begin
      nWorker := FWorkers[nIdx];
      if nWorker.FWorker.FParentObj = nParent then
      begin
        nWorker.FStartDelete := GetTickCount;
        //ɾ�����

        nLen := Length(nWorkers);
        SetLength(nWorkers, nLen + 1);
        nWorkers[nLen] := nWorker.FWorkerID;
      end;
    end;
  finally
    SyncLeave;
  end;

  for nIdx := Low(nWorkers) to High(nWorkers) do
    WorkerDelete(nWorkers[nIdx]);
  //xxxxx
end;

//Date: 2019-01-10
//Parm: �����ʶ
//Desc: ɾ����ʶΪnWorker��Worker
procedure TThreadPoolManager.WorkerDelete(const nWorkerID: Cardinal);
var nIdx: Integer;
    nExists: Boolean;
    nWorker: PThreadWorker;
begin
  while True do
  begin
    SyncEnter;
    try
      nExists := False;
      for nIdx := FWorkers.Count-1 downto 0 do
      begin
        nWorker := FWorkers[nIdx];
        if nWorker.FWorkerID <> nWorkerID then Continue;

        if nWorker.FStartCall = 0 then //δ������
        begin
          Dispose(nWorker);
          FWorkers.Delete(nIdx);
          Exit;
        end;

        nExists := True;
        Break;
      end;
    finally
      SyncLeave;
    end;

    if nExists then
         Sleep(10) //�����еȴ�
    else Exit;
  end;
end;

//Date: 2019-01-10
//Parm: ���÷�;���ô���
//Desc: ����nParent������Worker
procedure TThreadPoolManager.WorkerStart(const nParent: TObject;
  const nTimes: Cardinal);
var nIdx: Integer;
    nWorker: PThreadWorker;
begin
  SyncEnter;
  try
    for nIdx := FWorkers.Count-1 downto 0 do
    begin
      nWorker := FWorkers[nIdx];
      if nWorker.FWorker.FParentObj = nParent then
        nWorker.FWorker.FCallTimes := nTimes;
      //xxxxx
    end;
  finally
    SyncLeave;
  end;
end;

//Date: 2019-01-10
//Parm: �����ʶ;���ô���
//Desc: ������ʶΪnWorkerID��Worker
procedure TThreadPoolManager.WorkerStart(const nWorkerID, nTimes: Cardinal);
var nIdx: Integer;
    nWorker: PThreadWorker;
begin
  SyncEnter;
  try
    for nIdx := FWorkers.Count-1 downto 0 do
    begin
      nWorker := FWorkers[nIdx];
      if nWorker.FWorkerID = nWorkerID then
      begin
        nWorker.FWorker.FCallTimes := nTimes;
        Break;
      end;
    end;
  finally
    SyncLeave;
  end;
end;

//Date: 2019-01-10
//Parm: ���÷�
//Desc: ֹͣnParent������Worker
procedure TThreadPoolManager.WorkerStop(const nParent: TObject);
var nIdx,nLen: Integer;
    nWorker: PThreadWorker;
    nWorkers: array of Cardinal;
begin
  SyncEnter;
  try
    SetLength(nWorkers, 0);
    for nIdx := FWorkers.Count-1 downto 0 do
    begin
      nWorker := FWorkers[nIdx];
      if nWorker.FWorker.FParentObj = nParent then
      begin
        nLen := Length(nWorkers);
        SetLength(nWorkers, nLen + 1);
        nWorkers[nLen] := nWorker.FWorkerID;
      end;
    end;
  finally
    SyncLeave;
  end;

  for nIdx := Low(nWorkers) to High(nWorkers) do
    WorkerStop(nWorkers[nIdx]);
  //xxxxx
end;

//Date: 2019-01-10
//Parm: �����ʶ
//Desc: ֹͣ��ʶΪnWorkerID��Worker
procedure TThreadPoolManager.WorkerStop(const nWorkerID: Cardinal);
var nIdx: Integer;
    nExists: Boolean;
    nWorker: PThreadWorker;
begin
  while True do
  begin
    SyncEnter;
    try
      nExists := False;
      for nIdx := FWorkers.Count-1 downto 0 do
      begin
        nWorker := FWorkers[nIdx];
        if nWorker.FWorkerID <> nWorkerID then Continue;

        if nWorker.FStartCall = 0 then //δ������
        begin
          nWorker.FWorker.FCallTimes := 0;
          Exit;
        end;

        nExists := True;
        Break;
      end;
    finally
      SyncLeave;
    end;

    if nExists then
         Sleep(10) //�����еȴ�
    else Exit;
  end;
end;

//Date: 2019-01-09
//Parm: �б�;�Ƿ��Ѻ���ʾ
//Desc: ��������״̬���ݴ���nList
procedure TThreadPoolManager.GetStatus(const nList: TStrings;
  const nFriendly: Boolean);
begin
  with TObjectStatusHelper do
  try
    SyncEnter;
    inherited GetStatus(nList, nFriendly);

    if not nFriendly then
    begin
      nList.Add('NumThread=' + Length(FRunners).ToString);
      nList.Add('NumWorker=' + FWorkers.Count.ToString);
      Exit;
    end;

    nList.Add(FixData('NumThread:', Length(FRunners)));
    nList.Add(FixData('NumWorker:', FWorkers.Count));
  finally
    SyncLeave;
  end;
end;

//Date: 2019-01-09
//Desc: ��ȡ������������
function TThreadPoolManager.GetHealth(const nList: TStrings): TObjectHealth;
var nStr: string;
    nInt: Integer;
begin
  SyncEnter;
  try
    Result := hlNormal;
    nInt := Length(FRunners);

    if (nInt >= 20) and (Result < hlLow) then
    begin
      if Assigned(nList) then
      begin
        nStr := '�̳߳ض���[Runner: %d]����.';
        nList.Add(Format(nStr, [nInt]));
      end;

      Result := hlLow;
    end;

    if (nInt >= 50) and (Result < hlBad) then
    begin
      if Assigned(nList) then
      begin
        nStr := '�̳߳ض���[Runner: %d]�ﵽ����ֵ.';
        nList.Add(Format(nStr, [nInt]));
      end;

      Result := hlBad;
    end;
  finally
    SyncLeave;
  end;
end;

//------------------------------------------------------------------------------
constructor TThreadMonitor.Create(AOwner: TThreadPoolManager);
begin
  inherited Create(False);
  FreeOnTerminate := False;

  FOwner := AOwner;
  FWaiter := TWaitObject.Create();
  FWaiter.Interval := 1000;
end;

destructor TThreadMonitor.Destroy;
begin
  FreeAndNil(FWaiter);
  inherited;
end;

procedure TThreadMonitor.Wakeup;
begin
  FWaiter.Wakeup();
end;

procedure TThreadMonitor.StopMe;
begin
  Terminate;
  FWaiter.Wakeup();

  WaitFor;
  Free;
end;

procedure TThreadMonitor.Execute;
begin
  while not Terminated do
  try
    FWaiter.EnterWait;
    if not Terminated then
      DoMonitor;
    //xxxxx
  except
    //ignor any error
  end;
end;

procedure TThreadMonitor.DoMonitor;
begin

end;

//------------------------------------------------------------------------------
constructor TThreadRunner.Create(AOwner: TThreadPoolManager);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FOwner := AOwner;
end;

destructor TThreadRunner.Destroy;
begin

  inherited;
end;

procedure TThreadRunner.StopMe;
begin
  Terminate;
  WaitFor;
  Free;
end;

procedure TThreadRunner.Execute;
begin
  inherited;

end;

end.
