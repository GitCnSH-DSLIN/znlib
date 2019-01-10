{*******************************************************************************
  ����: dmzn@163.com 2017-04-16
  ����: ʵ�ֵȴ�����͸����ܵȴ�������

  ����:
  &.TWaitObject��EnterWait���������,ֱ��Wakeup����.
  &.�ö�����̰߳�ȫ,��A�߳�EnterWait,B�߳�Wakeup.
  &.TWaitTimerʵ��΢�뼶�������.
*******************************************************************************}
unit UWaitItem;

interface

uses
  System.Classes, System.SysUtils, Winapi.Windows;

type
  TWaitObject = class(TObject)
  strict private
    const
      cIsIdle    = $02;
      cIsWaiting = $27;
    {*��������*}
  private     
    FEvent: THandle;
    {*�ȴ��¼�*}
    FInterval: Cardinal;
    {*�ȴ����*}
    FStatus: Integer;
    {*�ȴ�״̬*}
    FWaitResult: Cardinal;
    {*�ȴ����*}
  public
    constructor Create(nEventName: string = '');
    destructor Destroy; override;
    {*�����ͷ�*}
    procedure InitStatus(const nWakeup: Boolean);
    {*��ʼ״̬*}
    function EnterWait: Cardinal;
    procedure Wakeup(const nForce: Boolean = False);
    {*�ȴ�.����*}
    function IsWaiting: Boolean;
    function IsTimeout: Boolean;
    function IsWakeup: Boolean;
    {*�ȴ�״̬*}
    property WaitResult: Cardinal read FWaitResult;
    property Interval: Cardinal read FInterval write FInterval;
  end;

  TCrossProcWaitObject = class(TObject)
  private
    FEvent: THandle;
    {*ͬ���¼�*}
    FLockStatus: Boolean;
    {*����״̬*}
  public
    constructor Create(nEventName: string = '');
    destructor Destroy; override;
    {*�����ͷ�*}
    function SyncLockEnter(const nWaitFor: Boolean = False): Boolean;
    procedure SyncLockLeave(const nOnlyMe: Boolean = True);
    {*ͬ������*}
  end;

  TWaitTimer = class(TObject)
  strict private
    type
      PTimerItem = ^TTimerItem;
      TTimerItem = record
        FThread: THandle;    //�߳̾��
        FLastActive: UInt64; //�ϴλ
      end;
  private
    FFrequency: Int64;
    {*CPUƵ��*}
    FFlagFirst: Int64;
    {*��ʼ���*}
    FTimeResult: Int64;
    {*��ʱ���*}
  public
    constructor Create;
    class procedure ManageTimer; static;
    {*�����ͷ�*}
    procedure StartTime;
    class procedure StartHighResolutionTimer; static;
    {*��ʼ��ʱ*}    
    function EndTime: Int64;
    class function GetHighResolutionTimerResult: Int64; static;
    {*������ʱ*}
    property TimeResult: Int64 read FTimeResult;
    {*�������*}
  end;

implementation

uses
  UManagerGroup, ULibFun;

constructor TWaitObject.Create(nEventName: string);
begin
  inherited Create;
  FStatus := cIsIdle;
  FInterval := INFINITE;

  if Trim(nEventName) = '' then
    nEventName := 'evt_waitobj_' + TDateTimeHelper.DateTimeSerial;
  FEvent := CreateEvent(nil, False, False, PChar(nEventName));

  if FEvent = 0 then
    raise Exception.Create('Create TCrossProcWaitObject.FEvent Failure');
  //xxxxx
end;

destructor TWaitObject.Destroy;
begin
  if FEvent > 0 then
    CloseHandle(FEvent);
  inherited;
end;

function TWaitObject.IsWaiting: Boolean;
begin
  Result := FStatus = cIsWaiting;
end;

function TWaitObject.IsTimeout: Boolean;
begin
  if IsWaiting then
       Result := False
  else Result := FWaitResult = WAIT_TIMEOUT;
end;

function TWaitObject.IsWakeup: Boolean;
begin
  if IsWaiting then
       Result := False
  else Result := FWaitResult = WAIT_OBJECT_0;
end;

procedure TWaitObject.InitStatus(const nWakeup: Boolean);
begin
  if nWakeup then
       SetEvent(FEvent)
  else ResetEvent(FEvent);
end;

function TWaitObject.EnterWait: Cardinal;
begin
  InterlockedExchange(FStatus, cIsWaiting);
  Result := WaitForSingleObject(FEvent, FInterval);

  FWaitResult := Result;
  InterlockedExchange(FStatus, cIsIdle);
end;

procedure TWaitObject.Wakeup(const nForce: Boolean);
begin
  if (FStatus = cIsWaiting) or nForce then
    SetEvent(FEvent);
  //xxxxx
end;

//------------------------------------------------------------------------------
constructor TCrossProcWaitObject.Create(nEventName: string);
var nStr: string;
begin
  inherited Create;
  FLockStatus := False;

  if Trim(nEventName) = '' then
    nEventName := 'evt_crosswait_' + TDateTimeHelper.DateTimeSerial;
  FEvent := CreateEvent(nil, False, True, PChar(nEventName));

  if FEvent = 0 then
  begin
    nStr := 'Create TCrossProcWaitObject.FSyncEvent Failure.';
    if GetLastError = ERROR_INVALID_HANDLE then
    begin
      nStr := nStr + #13#10#13#10 +
              'The name of an existing semaphore,mutex,or file-mapping object.';
      //xxxxx
    end;

    raise Exception.Create(nStr);
  end;
end;

destructor TCrossProcWaitObject.Destroy;
begin
  SyncLockLeave(True);
  //unlock
  
  if FEvent > 0 then
    CloseHandle(FEvent);
  inherited;
end;

//Date: 2017-04-16
//Parm: �ȴ��ź�
//Desc: ����ͬ���ź���,�����ɹ�����True
function TCrossProcWaitObject.SyncLockEnter(const nWaitFor: Boolean): Boolean;
begin
  if nWaitFor then
       Result := WaitForSingleObject(FEvent, INFINITE) = WAIT_OBJECT_0
  else Result := WaitForSingleObject(FEvent, 0) = WAIT_OBJECT_0;
  {*
    a.FEvent��ʼ״̬ΪTrue.
    b.�״�WaitFor����WAIT_OBJECT_0,�����ɹ�.
    c.FEvent��λ��ʽΪFalse,WaitFor���óɹ����Զ���Ϊ"���ź�".
    d.����WaitFor���᷵��WAIT_TIMEOUT,����ʧ��.
    e.LockRelease��,����.
  *}

  FLockStatus := Result;
  {*�Ƿ񱾶�������*}
end;

//Date: 2017-04-16
//Parm: ֻ���������������ź�
//Desc: ����ͬ���ź�
procedure TCrossProcWaitObject.SyncLockLeave(const nOnlyMe: Boolean);
begin
  if (not nOnlyMe) or FLockStatus then
    SetEvent(FEvent);
  //set event signal
end;

//------------------------------------------------------------------------------
constructor TWaitTimer.Create;
begin
  FTimeResult := 0;
  if not QueryPerformanceFrequency(FFrequency) then
    raise Exception.Create('not support high-resolution performance counter');
  //xxxxx
end;

procedure TWaitTimer.StartTime;
begin
  QueryPerformanceCounter(FFlagFirst);
end;

function TWaitTimer.EndTime: Int64;
var nNow: Int64;
begin
  QueryPerformanceCounter(nNow);
  Result := Trunc((nNow - FFlagFirst) / FFrequency * 1000 * 1000);
  FTimeResult := Result;
end;

//Date: 2017-04-17
//Desc: ע���ʱ������
class procedure TWaitTimer.ManageTimer;
var nItem: PTimerItem;
begin
  gMG.CheckSupport('TWaitTimer', ['TObjectPoolManager']);
  //�������

  gMG.FObjectPool.NewClass(TWaitTimer,
    function(var nData: Pointer):TObject
    begin
      Result := TWaitTimer.Create;
      New(nItem);
      nData := nItem;

      nItem.FThread := 0;
      nItem.FLastActive := 0;
    end,

    procedure(const nObj: TObject; const nData: Pointer)
    begin
      TWaitTimer(nObj).Free;
      Dispose(PTimerItem(nData));
    end);
  //xxxxx
end;

//Date: 2017-04-17
//Desc: ��ʼһ������
class procedure TWaitTimer.StartHighResolutionTimer;
var nCurID: THandle;
    nItem: PTimerItem;
    nTimer: TWaitTimer;
begin
  nTimer := nil;
  try
    nCurID := GetCurrentThreadId;
    nTimer := gMG.FObjectPool.Lock(TWaitTimer, nil, @nItem,
      function(const nObj: TObject; const nData: Pointer;
       var nTimes: Integer): Boolean
      begin
        nItem := nData;
        if nTimes = 1 then //����ɨ��
        begin
          Result := (not Assigned(nItem)) or (nItem.FThread = nCurID);
          //��ͬ�߳�
        end else
        begin
          Result := (not Assigned(nItem)) or ((nItem.FThread = 0) or
                    (GetTickCount - nItem.FLastActive > 60 * 60 * 1000));
          //���ж���
        end;

        if nTimes = 1 then
          nTimes := 2;
        //ɨ��2��
      end) as TWaitTimer;
    //xxxxx

    nTimer.StartTime;
    nItem.FThread := nCurID;
    nItem.FLastActive := GetTickCount64;
  finally
    gMG.FObjectPool.Release(nTimer);
  end;
end;

//Date: 2017-04-17
//Desc: ���ؼ������
class function TWaitTimer.GetHighResolutionTimerResult: Int64;
var nCurID: THandle;
    nItem: PTimerItem;
    nTimer: TWaitTimer;
begin
  nTimer := nil;
  try
    Result := 0;
    nCurID := GetCurrentThreadId;

    nTimer := gMG.FObjectPool.Lock(TWaitTimer, nil, @nItem,
      function(const nObj: TObject; const nData: Pointer;
       var nTimes: Integer): Boolean
      begin
        nItem := nData;
        Result := (not Assigned(nItem)) or (nItem.FThread = nCurID);
      end, True) as TWaitTimer;
    //xxxxx

    if Assigned(nTimer) then
    begin
      Result := nTimer.EndTime;
      nItem.FThread := 0;
      nItem.FLastActive := 0;
    end;
  finally
    gMG.FObjectPool.Release(nTimer);
  end;
end;

initialization
  TWaitTimer.ManageTimer;
finalization
  //nothing
end.
