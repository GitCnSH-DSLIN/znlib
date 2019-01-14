{*******************************************************************************
  ����: dmzn@163.com 2019-01-09
  ����: �̳߳ع�����

  ��ע:
  *.ʹ�÷���:
    var nWorker: TThreadWorkerConfig;
    //0.������������
    begin
      WorkerInit(nWorker);
      //1.��ʼ��

      with nWorker do
      begin
        FWorkerName := '���ټ�ʱ��';
        FParentObj := Self;
        FParentDesc := '������';
        FDataInteger[0] := nIdx;
        FCallInterval := 100;

        //4.��������֧��3���̺߳���,��FProc��ͷ,�������߳���
        FProcRefer := procedure (const nConfig: PThreadWorkerConfig;
         const nThread: TThread)
        begin
          TWaitTimer.StartHighResolutionTimer;
          Sleep(100);
          nInt := TWaitTimer.GetHighResolutionTimerResult;

          TThread.Synchronize(nThread, procedure
          begin
            case nConfig.FDataInteger[0] of
             0: Form1.Edit1.Text := IntToStr(nInt);
             1: Form1.Edit2.Text := IntToStr(nInt);
             2: Form1.Edit3.Text := IntToStr(nInt);
            end;
          end);
        end;
      end; //2.��д����������Ϣ

      WorkerAdd(@nWorker);
      //3.Ͷ�ݹ�������
    end;
*******************************************************************************}
unit UThreadPool;

interface

uses
  System.Classes, System.SysUtils, Winapi.Windows, UWaitItem, UBaseObject;

const
  cThreadMin              = 1;     //��С�߳���
  cThreadMax              = 32;    //����߳���
  cThreadMaxWorkInterval  = 1000;  //�߳����ɨ����

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
    FWorkerName   : string;                      //��������
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
    FRunner       : Integer;                     //���ж���
    FLastCall     : Cardinal;                    //�ϴε���
    FStartCall    : Cardinal;                    //��ʼ����
    FStartDelete  : Cardinal;                    //��ʼɾ��
  end;

  TThreadWorkerStatus = record
    FWorkerName   : string;                      //��������
    FHistoryValue : Cardinal;                    //��ʷ��¼
  end;

  TThreadManagerStatus = record
    FNumWorkers   : Cardinal;                    //��������
    FNumRunners   : Cardinal;                    //���ж���
    FNumRunning   : Cardinal;                    //������
    FNumWorkerRun : UInt64;                      //���ô���
    FNumWorkerMax : Cardinal;                    //��๤������
    FNumRunnerMax : Cardinal;                    //������ж���

    FRunDelayNow  : Cardinal;                    //�����ӳ�
    FRunDelayMax  : Cardinal;                    //��������ӳ�
    FRunMostFast  : TThreadWorkerStatus;         //��������¼
    FRunMostSlow  : TThreadWorkerStatus;         //����������¼
    FMaxWorkInterval: Cardinal;                  //���ɨ����
    FMaxWorkIdleLong: Cardinal;                  //�մ���м�ʱ
  end;

  TThreadRunner = class(TThread)
  private
    FOwner: TThreadPoolManager;
    {*ӵ����*}
    FTag: Integer;
    {*�̱߳�ʶ*}
    FActiveWorker: PThreadWorker;
    {*��ǰ����*}
    FWorkInterval: Cardinal;
    FWorkIdleStart: Cardinal;
    {*���м�ʱ*}
  protected
    procedure DoRun;
    procedure Execute; override;
    {*ִ��ҵ��*}
  public
    constructor Create(AOwner: TThreadPoolManager; ATag: Integer);
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
    {*ִ���ػ�*}
    procedure AdjustRunner(const nInc: Boolean; const nNum: Word = 1;
      const nIndex: Integer = -1);
    {*��������*}
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
    FStatus: TThreadManagerStatus;
    {*����״̬*}
    FWorkerIndex: Integer;
    FWorkers: TList;
    {*��������*}
    FMonitor: TThreadMonitor;
    {*�ػ��߳�*}
    FRunnerMin: Word;
    FRunnerMax: Word;
    FRunners: array of TThreadRunner;
    {*���ж���*}
  protected
    procedure StopRunners;
    procedure ClearWorkers(const nFree: Boolean);
    {*������Դ*}
    procedure SetRunnerMin(const nValue: Word);
    procedure SetRunnerMax(const nValue: Word);
    {*���ò���*}
    function MaxWorkInterval(const nIleTime: PCardinal = nil;
      const nLock: Boolean = False): Cardinal;
    {*ɨ����*}
    function ValidWorkerNumber(const nLock: Boolean = False): Cardinal;
    {*��Ч����*}
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
    property ThreadMin: Word read FRunnerMin write SetRunnerMin;
    property ThreadMax: Word read FRunnerMax write SetRunnerMax;
  end;

var
  gThreadPoolManager: TThreadPoolManager = nil;
  //ȫ��ʹ��

implementation

uses
  UManagerGroup, ULibFun;

constructor TThreadPoolManager.Create;
begin
  FRunnerMin := cThreadMin;
  FRunnerMax := cThreadMax;

  FWorkerIndex := 0;
  SetLength(FRunners, 0);
  FillChar(FStatus, SizeOf(FStatus), #0);

  FWorkers := TList.Create;
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

procedure TThreadPoolManager.SetRunnerMax(const nValue: Word);
begin
  if (nValue <> FRunnerMax) and (nValue <= cThreadMax) then
  begin
    SyncEnter;
    FRunnerMax := nValue;
    SyncLeave;

    FMonitor.Wakeup;
    //����ƽ��
  end;
end;

procedure TThreadPoolManager.SetRunnerMin(const nValue: Word);
begin
  if (nValue <> FRunnerMin) and (nValue >= cThreadMin) then
  begin
    SyncEnter;
    FRunnerMin := nValue;
    SyncLeave;

    FMonitor.Wakeup;
    //����ƽ��
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
    FillChar(nPWorker^, SizeOf(TThreadWorker), #0);

    nPWorker.FWorker := nWorker^;
    nPWorker.FWorkerID := gMG.FSerialIDManager.GetID;
    Inc(FStatus.FNumWorkers);

    if FStatus.FNumWorkers > FStatus.FNumWorkerMax then
      FStatus.FNumWorkerMax := FStatus.FNumWorkers;
    //xxxxx
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

          if FStatus.FNumWorkers > 0 then
            Dec(FStatus.FNumWorkers);
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

  FMonitor.Wakeup;
  //�ػ��߳�ƽ������
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

  FMonitor.Wakeup;
  //�ػ��߳�ƽ������
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

//Date: 2019-01-11
//Desc: ��ȡ��Ч�Ĺ����������
function TThreadPoolManager.ValidWorkerNumber(const nLock: Boolean): Cardinal;
var nIdx: Integer;
    nWorker: PThreadWorker;
begin
  Result := 0;
  if nLock then SyncEnter;
  try
    for nIdx := FWorkers.Count-1 downto 0 do
    begin
      nWorker := FWorkers[nIdx];
      if (nWorker.FStartDelete = 0) and (nWorker.FWorker.FCallTimes > 0) then
        Inc(Result);
      //valid worker
    end;
  finally
    if nLock then SyncLeave;
  end;
end;

//Date: 2019-01-14
//Parm: ����ʱ��;�Ƿ�����
//Desc: �����̵߳����ɨ����
function TThreadPoolManager.MaxWorkInterval(const nIleTime: PCardinal;
  const nLock: Boolean): Cardinal;
var nIdx: Integer;
    nVal: Cardinal;
begin
  if nLock then SyncEnter;
  try
    Result := 0;
    for nIdx := Low(FRunners) to High(FRunners) do
    if Assigned(FRunners[nIdx]) then
    begin
      if FRunners[nIdx].FWorkInterval > Result then
      begin
        Result := FRunners[nIdx].FWorkInterval;
        if Result > FStatus.FMaxWorkInterval then
          FStatus.FMaxWorkInterval := Result;
        //xxxxx
      end;

      if FRunners[nIdx].FWorkIdleStart > 0 then
      begin
        nVal := TDateTimeHelper.GetTickCountDiff(FRunners[nIdx].FWorkIdleStart);
        if nVal > FStatus.FMaxWorkIdleLong then
          FStatus.FMaxWorkIdleLong := nVal;
        //xxxxx

        if Assigned(nIleTime) and (nVal > nIleTime^) then
          nIleTime^ := nVal;
        //xxxxx
      end;
    end;
  finally
    if nLock then SyncLeave;
  end;
end;

//Date: 2019-01-09
//Parm: �б�;�Ƿ��Ѻ���ʾ
//Desc: ��������״̬���ݴ���nList
procedure TThreadPoolManager.GetStatus(const nList: TStrings;
  const nFriendly: Boolean);
var nInt: Integer;
    nVal: Cardinal;
begin
  with TObjectStatusHelper,FStatus do
  try
    SyncEnter;
    inherited GetStatus(nList, nFriendly);
    nInt := MaxWorkInterval(@nVal);

    if not nFriendly then
    begin
      nList.Add('NumWorkerMax' + FNumWorkerMax.ToString);
      nList.Add('NumWorker=' + FNumWorkers.ToString);
      nList.Add('NumWorkerValid=' + ValidWorkerNumber().ToString);
      nList.Add('NumThreadMax=' + FNumRunnerMax.ToString);
      nList.Add('NumThread=' + FNumRunners.ToString);
      nList.Add('NumRunning=' + FNumRunning.ToString);

      nList.Add('NumWorkerRun=' + FNumWorkerRun.ToString);
      nList.Add('NowRunDelay=' + FRunDelayNow.ToString);
      nList.Add('MaxRunDelay=' + FRunDelayMax.ToString);
      nList.Add('WorkerRunMostFast=' + FRunMostFast.FHistoryValue.ToString);
      nList.Add('WorkerRunMostSlow=' + FRunMostSlow.FHistoryValue.ToString);

      nList.Add('NowWorkInterval=' + nInt.ToString);
      nList.Add('NowWorkIdleLong=' + nVal.ToString);
      nList.Add('MaxWorkInterval=' + FMaxWorkInterval.ToString);
      nList.Add('MaxWorkIdleLong=' + FMaxWorkIdleLong.ToString);
      Exit;
    end;

    nList.Add(FixData('NumWorkerMax:', FStatus.FNumWorkerMax));
    nList.Add(FixData('NumWorker:', FStatus.FNumWorkers));
    nList.Add(FixData('NumWorkerValid:', ValidWorkerNumber()));
    nList.Add(FixData('NumThreadMax:', FStatus.FNumRunnerMax));
    nList.Add(FixData('NumThread:', FStatus.FNumRunners));
    nList.Add(FixData('NumRunning:', FStatus.FNumRunning));

    nList.Add(FixData('NowWorkInterval:', nInt));
    nList.Add(FixData('MaxWorkInterval:', FStatus.FMaxWorkInterval));
    nList.Add(FixData('NowWorkIdleLong:', nVal));
    nList.Add(FixData('MaxWorkIdleLong:', FStatus.FMaxWorkIdleLong));

    nList.Add(FixData('NowRunDelay:', FStatus.FRunDelayNow));
    nList.Add(FixData('MaxRunDelay:', FStatus.FRunDelayMax));
    nList.Add(FixData('NumWorkerRun:', FStatus.FNumWorkerRun));

    with FStatus.FRunMostFast do
      nList.Add(FixData('WorkerRunMostFast:', FHistoryValue.ToString + '(' +
                                        FWorkerName + ')'));
    //xxxxx

    with FStatus.FRunMostSlow do
      nList.Add(FixData('WorkerRunMostSlow:', FHistoryValue.ToString + '(' +
                                        FWorkerName + ')'));
    //xxxxx
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

    if (nInt >= cThreadMax * 0.8) and (Result < hlLow) then
    begin
      if Assigned(nList) then
      begin
        nStr := '�̳߳ض���[Runner: %d]����.';
        nList.Add(Format(nStr, [nInt]));
      end;

      Result := hlLow;
    end;

    if (nInt >= cThreadMax) and (Result < hlBad) then
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
  FWaiter.Interval := 10 * 1000;
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
    if Terminated then Break;

    FOwner.SyncEnter;
    try
      DoMonitor;
    finally
      FOwner.SyncLeave;
    end;
  except
    //ignor any error
  end;
end;

//Date: 2019-01-11
//Parm: ����;��������;ָ������
//Desc: ���ӻ�������ж���
procedure TThreadMonitor.AdjustRunner(const nInc: Boolean; const nNum: Word;
  const nIndex: Integer);
var nIdx,nInt: Integer;

    //Desc: �¶�������
    function GetNewRunner: Integer;
    var i: Integer;
    begin
      for i := Low(FOwner.FRunners) to High(FOwner.FRunners) do
      if not Assigned(FOwner.FRunners[i]) then
      begin
        Result := i;
        Exit;
      end;

      i := Length(FOwner.FRunners);
      SetLength(FOwner.FRunners, i + 1);
      Result := i;
    end;

    //Desc: ֹͣ���ж���
    procedure StopRunner;
    begin
      FOwner.SyncLeave;
      try
        FOwner.FRunners[nIdx].StopMe;
        //wait and stop
      finally
        FOwner.SyncEnter;
      end;

      FOwner.FRunners[nIdx] := nil;
      Dec(FOwner.FStatus.FNumRunners);
    end;
begin
  FOwner.FStatus.FRunDelayNow := 0;
  //�������ж���,�����¼����ӳ�

  if nInc then //add
  begin
    nIdx := FOwner.FStatus.FNumRunners + nNum - FOwner.FRunnerMax;
    if nIdx > 0 then
         nInt := nNum - nIdx
    else nInt := nNum;

    while nInt > 0 do
    begin
      nIdx := GetNewRunner();
      FOwner.FRunners[nIdx] := TThreadRunner.Create(FOwner, nIdx);

      Dec(nInt);
      Inc(FOwner.FStatus.FNumRunners);

      if FOwner.FStatus.FNumRunners > FOwner.FStatus.FNumRunnerMax then
        FOwner.FStatus.FNumRunnerMax := FOwner.FStatus.FNumRunners;
      //xxxxx
    end;
  end else //del
  begin
    if (nIndex >= 0) and (nIndex >= Low(FOwner.FRunners)) and
       (nIndex <= High(FOwner.FRunners)) and
       (FOwner.FStatus.FNumRunners > FOwner.FRunnerMin) then //ָ��ɾ������
    begin
      nIdx := nIndex;
      StopRunner;
      Exit;
    end;

    nIdx := FOwner.FRunnerMin - (FOwner.FStatus.FNumRunners - nNum);
    if nIdx > 0 then
         nInt := nNum - nIdx
    else nInt := nNum;

    if nInt < 1 then Exit;
    //invalid adjust

    for nIdx := Low(FOwner.FRunners) to High(FOwner.FRunners) do
    if Assigned(FOwner.FRunners[nIdx]) then
    begin
      StopRunner;
      Dec(nInt);
      if nInt <= 0 then Break;
    end;
  end;
end;

procedure TThreadMonitor.DoMonitor;
var nIdx: Integer;
    nVal: Cardinal;
begin
  nVal := FOwner.ValidWorkerNumber;
  if FOwner.FStatus.FNumRunners > nVal then
  begin
    AdjustRunner(False, FOwner.FStatus.FNumRunners - nVal);
    //����ÿ��Worker����ʹ��һ���߳�
  end;

  if (FOwner.FStatus.FNumRunners < FOwner.FRunnerMin) and (nVal > 0) then
  begin
    AdjustRunner(True, FOwner.FRunnerMin - FOwner.FStatus.FNumRunners);
    //������С�߳�
  end;

  for nIdx := Low(FOwner.FRunners) to High(FOwner.FRunners) do
  if Assigned(FOwner.FRunners[nIdx]) and (
     FOwner.FRunners[nIdx].FWorkIdleStart > 0) then //�����߳�
  begin
    with FOwner.FRunners[nIdx] do
      nVal := TDateTimeHelper.GetTickCountDiff(FWorkIdleStart);
    //xxxxx

    if nVal >= 60 * 1000 then
      AdjustRunner(False, 1, nIdx);
    //���г�ʱ��ر�
  end;

  if FOwner.FStatus.FRunDelayNow >= 1000 then
  begin
    FOwner.FStatus.FRunDelayNow := 0;
    AdjustRunner(True, 1);
    //�����ӳٹ���,�����߳�
  end;
end;

//------------------------------------------------------------------------------
constructor TThreadRunner.Create(AOwner: TThreadPoolManager; ATag: Integer);
begin
  inherited Create(False);
  FreeOnTerminate := False;

  FOwner := AOwner;
  FTag := ATag;
  FWorkInterval := 1;
  FWorkIdleStart := 0;
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
var nIdx: Integer;
    nLoop: Boolean;
    nInit,nVal: Cardinal;
    nWorker: PThreadWorker;

  //Desc: ɨ����ù�������
  procedure ScanActiveWorker;
  begin
    nLoop := False;
    nIdx := FOwner.FWorkerIndex;

    while FOwner.FWorkerIndex < FOwner.FWorkers.Count do
    begin
      if nLoop and (FOwner.FWorkerIndex = nIdx) then Break;
      //��һ�ֵ���ʼλ��,ɨ�����
      nWorker := FOwner.FWorkers[FOwner.FWorkerIndex];
      Inc(FOwner.FWorkerIndex);

      if FOwner.FWorkerIndex >= FOwner.FWorkers.Count then
      begin
        nLoop := True;
        FOwner.FWorkerIndex := 0;
      end; //��ʼ��һ��ɨ��

      if (nWorker.FStartCall > 0) or (nWorker.FStartDelete > 0) or
         (nWorker.FWorker.FCallTimes < 1) then Continue;
      //������;ɾ����;ִ�����
       
      if (nWorker.FWorker.FCallInterval > 0) and (nWorker.FLastCall > 0) then
      begin
        nVal := TDateTimeHelper.GetTickCountDiff(nWorker.FLastCall);
        if nVal < nWorker.FWorker.FCallInterval then Continue;
        //δ��ִ��ʱ��

        nVal := nVal - nWorker.FWorker.FCallInterval;
        if nVal > 0 then //���ε��ü��������Ҫ�ļ��
        begin
          if nVal > FOwner.FStatus.FRunDelayNow then
            FOwner.FStatus.FRunDelayNow := nVal;
          //��ǰ����ӳ�

          if nVal > FOwner.FStatus.FRunDelayMax then
            FOwner.FStatus.FRunDelayMax := nVal;
          //��ʷ����ӳ�
        end;
      end;
         
      FActiveWorker := nWorker;
      Break;
    end;

    if Assigned(FActiveWorker) then
    begin
      if FWorkIdleStart > 0 then
      begin
        nVal := TDateTimeHelper.GetTickCountDiff(FWorkIdleStart);
        if nVal > FOwner.FStatus.FMaxWorkIdleLong then
          FOwner.FStatus.FMaxWorkIdleLong := nVal;
        //����еȴ�
      end;

      FWorkInterval := 1;
      FWorkIdleStart := 0;

      FActiveWorker.FRunner := FTag;
      FActiveWorker.FStartCall := GetTickCount;
      Inc(FOwner.FStatus.FNumRunning);
    end else
    begin
      if FWorkInterval = 1 then
        FWorkIdleStart := GetTickCount();
      //��ʼ���м�ʱ

      if FWorkInterval < cThreadMaxWorkInterval then
      begin
        Inc(FWorkInterval);
        //����ʱ���ӵȴ�

        if FWorkInterval > FOwner.FStatus.FMaxWorkInterval then
          FOwner.FStatus.FMaxWorkInterval := FWorkInterval;
        //��ȴ����
      end;
    end;
  end;
begin
  while not Terminated do
  try
    nInit := 0;
    FActiveWorker := nil;
    try
      FOwner.SyncEnter;
      try
        ScanActiveWorker();
      finally
        FOwner.SyncLeave;
      end;

      if not Assigned(FActiveWorker) then
      begin
        Sleep(FWorkInterval);
        Continue;
      end;

      DoRun();
      nInit := TDateTimeHelper.GetTickCountDiff(FActiveWorker.FStartCall);

      if nInit < FWorkInterval then
        Sleep(FWorkInterval - nInit);
      //wait seconds
    finally
      if Assigned(FActiveWorker) then
      try
        FOwner.SyncEnter;
        FActiveWorker.FRunner := 0;
        FActiveWorker.FStartCall := 0;
        FActiveWorker.FLastCall := GetTickCount;

        if (FActiveWorker.FWorker.FCallTimes < INFINITE) and
           (FActiveWorker.FWorker.FCallTimes > 0) then
          Dec(FActiveWorker.FWorker.FCallTimes);
        //call times

        Inc(FOwner.FStatus.FNumWorkerRun);
        Dec(FOwner.FStatus.FNumRunning);

        if nInit > 0 then
        begin
          with FOwner.FStatus.FRunMostFast do
          begin
            if (nInit < FHistoryValue) or (FHistoryValue < 1) then //����¼
            begin
              FHistoryValue := nInit;
              FWorkerName := FActiveWorker.FWorker.FWorkerName;
            end;
          end;

          with FOwner.FStatus.FRunMostSlow do
          begin
            if nInit > FHistoryValue then //������¼
            begin
              FHistoryValue := nInit;
              FWorkerName := FActiveWorker.FWorker.FWorkerName;
            end;
          end;
        end;
      finally
        FOwner.SyncLeave;
      end;
    end;
  except
    //ignor any error
  end;
end;

procedure TThreadRunner.DoRun;
begin
  if Assigned(FActiveWorker.FWorker.FProcedure) then
    FActiveWorker.FWorker.FProcedure(@FActiveWorker.FWorker, Self);
  //xxxxx

  if Assigned(FActiveWorker.FWorker.FProcEvent) then
    FActiveWorker.FWorker.FProcEvent(@FActiveWorker.FWorker, Self);
  //xxxxx

  if Assigned(FActiveWorker.FWorker.FProcRefer) then
    FActiveWorker.FWorker.FProcRefer(@FActiveWorker.FWorker, Self);
  //xxxxx
end;

end.
