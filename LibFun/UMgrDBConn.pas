{*******************************************************************************
  ����: dmzn@163.com 2011-10-22
  ����: ���ݿ����ӹ�����

  ��ע:
  *.�������ӹ�����,ά��һ�����ݿ����Ӳ���,����̬�������Ӷ���.
  *.ÿ�����Ӳ���ʹ��һ��ID��ʶ,����ڸ��ٹ�ϣ����.
  *.ÿ�����Ӷ���ʹ��һ��ID��ʶ,��ʾ��ͬһ�����ݿ�,���ж����������.
  *.ÿ�����Ӷ�Ӧһ�����ݿ�,ÿ��������ӦN��Workerʵ�ʸ���Connection,������
    ����
*******************************************************************************}
unit UMgrDBConn;

interface

uses
  ActiveX, ADODB, Classes, DB, Windows, SysUtils, SyncObjs, UMgrHashDict,
  UWaitItem, USysLoger, UBaseObject, UMemDataPool, ULibFun, UFormCtrl;

const
  cErr_GetConn_NoParam     = $0001;            //�����Ӳ���
  cErr_GetConn_NoAllowed   = $0002;            //��ֹ����
  cErr_GetConn_Closing     = $0003;            //�������Ͽ�
  cErr_GetConn_MaxConn     = $0005;            //���������
  cErr_GetConn_BuildFail   = $0006;            //����ʧ��

type
  PDBParam = ^TDBParam;
  TDBParam = record
    FID        : string;                       //������ʶ
    FName      : string;                       //��ʶ����
    FHost      : string;                       //������ַ
    FPort      : Integer;                      //����˿�
    FDB        : string;                       //���ݿ���
    FUser      : string;                       //�û���
    FPwd       : string;                       //�û�����
    FConn      : string;                       //�����ַ�
    
    FEnable    : Boolean;                      //���ò���
    FNumWorker : Integer;                      //����������
  end;

  PDBWorker = ^TDBWorker;
  TDBWorker = record
    FIdle : Boolean;                            //δ����
    FConn : TADOConnection;                     //���Ӷ���
    FQuery: TADOQuery;                          //��ѯ����
    FExec : TADOQuery;                          //��������

    FWaiter: TWaitObject;                       //�ӳٶ���
    FUsed : Integer;                            //�ŶӼ���
    FLock : TCriticalSection;                   //ͬ������

    FThreadID: THandle;                         //�����߳�
    FCallNum: Integer;                          //���ü���
    FConnItem: Pointer;                         //����������(ר��)
  end;

  PDBConnItem = ^TDBConnItem;
  TDBConnItem = record
    FID   : string;                             //���ӱ�ʶ
    FUsed : Integer;                            //�ŶӼ���
    FLast : Cardinal;                           //�ϴ�ʹ��
    FWorker: array of PDBWorker;                //��������
  end;

  TDBASyncType = (stSQLServer, stMySQL, stOracle, stPostgres);
  //��������
  TDBASyncRelation = (arGreater, arGE, arEqual, arLE, arLess, arSame);
  //���ݹ�ϵ(>, >=, =, <=, <, �ı���ͬ)

  PDBASyncItem = ^TDBASyncItem;
  TDBASyncItem = record
    FSerialNo  : string;                        //��ˮ��
    FPairKey   : string;                        //ҵ���ʶ
    FSQL       : string;                        //��ִ��

    FIfQuery   : string;                        //������ѯ
    FIfField   : string;                        //�����ֶ�
    FIfType    : TDBASyncRelation;              //�ȽϹ�ϵ
    FIfValue   : string;                        //���Ƚ�����
    FIfSQL     : string;                        //�����ִ��

    FRecordID  : Int64;                         //��¼��
    FStartNow  : Boolean;                       //����ִ��
    FStatus    : string;                        //״̬��ʶ
    FMemo      : string;                        //��ע����
  end;

  TDBASyncWaitItem = record
    FEnabled   : Boolean;                       //�Ƿ�����
    FSerialNo  : string;                        //��ˮ��
    FWaiter    : TWaitObject;                   //�ȴ�����
  end;
  TDBASyncWaitItems = array of TDBASyncWaitItem;

  PDBConnStatus = ^TDBConnStatus;
  TDBConnStatus = record
    FNumConnParam: Integer;                     //���������ݿ����
    FNumConnItem: Integer;                      //������(���ݿ�)����
    FNumConnObj: Integer;                       //���Ӷ���(Connection)����
    FNumObjConned: Integer;                     //�����Ӷ���(Connection)����
    FNumObjReUsed: Cardinal;                    //�����ظ�ʹ�ô���
    FNumObjRequest: Cardinal;                   //������������
    FNumObjRequestErr: Cardinal;                //����������
    FNumObjWait: Integer;                       //�Ŷ��ж���(Worker.FUsed)����
    FNumWaitMax: Integer;                       //�Ŷ�����������ж������
    FNumMaxTime: TDateTime;                     //�Ŷ����ʱ��
  end;

  TDBActionCallback = function (const nWorker: PDBWorker;
    const nData: Pointer): Boolean;
  TDBActionCallbackObj = function (const nWorker: PDBWorker;
    const nData: Pointer): Boolean of object;
  //�ص�����

  TDBConnManager = class;
  TDBASyncWriter = class(TThread)
  private
    FOwner: TDBConnManager;
    //ӵ����
    FWaiter: TWaitObject;
    //�ȴ�����
    FBuffer: TList;
    FDBWorker: PDBWorker;
    //��������
  protected
    procedure ClearBuffer(const nFree: Boolean);
    //������
    procedure DoExecute_SQLServer;
    procedure Execute; override;
    //ִ���߳�
    procedure WriteData_SQLServer(const nData: PDBASyncItem;
      const nCombineSerial: Boolean = True);
    //д�붯��
  public
    constructor Create(AOwner: TDBConnManager);
    destructor Destroy; override;
    //�����ͷ�
    procedure Wakeup;
    procedure StopMe;
    //����ֹͣ
  end;

  TDBConnManager = class(TCommonObjectBase)
  private
    FWorkers: TList;
    //��������
    FConnDef: string;
    FConnItems: TList;
    //�����б�
    FParams: THashDictionary;
    //�����б�
    FConnClosing: Integer;
    FAllowedRequest: Integer;
    FSyncLock: TCriticalSection;
    //ͬ����
    FStatus: TDBConnStatus;
    //����״̬
    FIDASyncItem: Integer;
    FASyncDBType: TDBASyncType;
    FASyncWriter: TDBASyncWriter;
    FASyncWaiter: TDBASyncWaitItems;
    //�첽���ݿ�
  protected
    procedure DoFreeDict(const nType: Word; const nData: Pointer);
    //�ͷ��ֵ�
    procedure FreeDBConnItem(const nItem: PDBConnItem);
    procedure ClearConnItems(const nFreeMe: Boolean);
    //��������
    procedure ClearWorkers(const nFreeMe: Boolean);
    //�������
    procedure WorkerAction(const nWorker: PDBWorker; const nIdx: Integer = -1;
     const nFree: Boolean = True);
    function GetIdleWorker(const nLocked: Boolean): PDBWorker;
    //�������
    function CloseWorkerConnection(const nWorker: PDBWorker): Boolean;
    function CloseConnection(const nID: string; const nLock: Boolean): Integer;
    //�ر�����
    procedure DoAfterConnection(Sender: TObject);
    procedure DoAfterDisconnection(Sender: TObject);
    //ʱ���
    function GetRunStatus: TDBConnStatus;
    //��ȡ״̬
    function GetMaxConn: Integer;
    procedure SetMaxConn(const nValue: Integer);
    //����������
    procedure RegisterDataType;
    //ע������ 
    function ASyncWaiteFor(const nSerial: string; nWaitFor: Word): TWaitObject;
    procedure ASyncWaiteOver(const nSerial: string);
    procedure ASyncClearWaiters;
    //�첽�ȴ�����
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    procedure AddParam(const nParam: TDBParam);
    procedure DelParam(const nID: string = '');
    procedure ClearParam;
    //��������
    function GetConnectionStr(const nID: string): string;
    class function MakeDBConnection(const nParam: TDBParam): string;
    //�����ַ���
    function GetConnection(const nID: string; var nErrCode: Integer;
     const nThreadUnion: Boolean = False): PDBWorker;
    procedure ReleaseConnection(const nWorker: PDBWorker);
    //ʹ������
    function Disconnection(const nID: string = ''): Integer;
    //�Ͽ�����
    function WorkerQuery(const nWorker: PDBWorker; const nSQL: string): TDataSet;
    function WorkerExec(const nWorker: PDBWorker; const nSQL: string): Integer;
    //��������
    function SQLQuery(const nSQL: string; var nWorker: PDBWorker;
      nID: string = ''): TDataSet;
    function ExecSQLs(const nSQLs: TStrings; const nTrans: Boolean;
      nID: string = ''): Boolean;
    function ExecSQL(const nSQL: string; nID: string = ''): Integer;
    //��д����
    procedure ASyncStart;
    procedure ASyncStop;
    //��ͣ�첽�߳�
    procedure ASyncInitDB;
    procedure ASyncInitItem(const nSQLItem: PDBASyncItem;
      const nNewSerial: Boolean = False);
    //�첽��ʼ��
    procedure ASyncAdd(const nItem: PDBASyncItem);
    procedure ASyncAddSimple(const nSQL: string);
    procedure ASyncAddItem(const nItem: PDBASyncItem; const nSQL: string;
      const nPair: string = '');
    procedure ASyncApply(nSerialNo: string = ''; const nWaitFor: Word = 0);
    //�첽д��
    function DBAction(const nAction: TDBActionCallback;
      const nData: Pointer = nil; nID: string = ''): Boolean; overload;
    function DBAction(const nAction: TDBActionCallbackObj;
      const nData: Pointer = nil; nID: string = ''): Boolean; overload;
    //��д�ص�ģʽ
    procedure GetStatus(const nList: TStrings); override;
    //����״̬
    property ASyncDBType: TDBASyncType read FASyncDBType write FASyncDBType;
    property Status: TDBConnStatus read GetRunStatus;
    property MaxConn: Integer read GetMaxConn write SetMaxConn;
    property DefaultConnection: string read FConnDef write FConnDef;
    //�������
  end;

var
  gDBConnManager: TDBConnManager = nil;
  //ȫ��ʹ��

implementation

const
  cTrue  = $1101;
  cFalse = $1105; //��������

  cR_Low  = Ord(Low(TDBASyncRelation));
  cR_High = Ord(High(TDBASyncRelation));                   //���ݹ�ϵ�ٽ�

  cS_Run    = 'R';
  cS_Pause  = 'P';
  cS_Done   = 'O';                                         //�첽����״̬

  cAsyncNum = 3;                                           //�첽д�����
  cTable_ASync = 'Sys_DataASync';                          //�첽���ݱ�
  
resourcestring
  sNoAllowedWhenRequest = '���ӳض����ͷ�ʱ�յ�����,�Ѿܾ�.';
  sClosingWhenRequest   = '���ӳض���ر�ʱ�յ�����,�Ѿܾ�.';
  sNoParamWhenRequest   = '���ӳض����յ�����,����ƥ�����.';
  sBuildWorkerFailure   = '���ӳض��󴴽�DBWorkerʧ��.';

//------------------------------------------------------------------------------
//Desc: ��¼��־
procedure WriteLog(const nMsg: string);
begin
  if Assigned(gSysLoger) then
    gSysLoger.AddLog(TDBConnManager, '���ݿ����ӳ�', nMsg);
  //xxxxx
end;

constructor TDBConnManager.Create;
begin
  inherited;
  FConnClosing := cFalse;
  FAllowedRequest := cTrue;

  FASyncWriter := nil;
  FASyncDBType := stSQLServer;
  SetLength(FASyncWaiter, 0);
  
  FConnDef := '';
  FConnItems := TList.Create;

  FWorkers := TList.Create;
  FSyncLock := TCriticalSection.Create;
  
  FParams := THashDictionary.Create(3);
  FParams.OnDataFree := DoFreeDict;

  RegisterDataType;
  //���ڴ��������
end;

destructor TDBConnManager.Destroy;
begin
  ASyncStop;
  ASyncClearWaiters;

  ClearConnItems(True);
  ClearWorkers(True);

  FParams.Free;
  FSyncLock.Free;
  inherited;
end;

procedure OnNew(const nFlag: string; const nType: Word; var nData: Pointer);
var nItem: PDBASyncItem;
begin
  if nFlag = 'ASyncItem' then
  begin
    New(nItem);
    nData := nItem;
  end;
end;

procedure OnFree(const nFlag: string; const nType: Word; const nData: Pointer);
begin
  if nFlag = 'ASyncItem' then
  begin
    Dispose(PDBASyncItem(nData));
  end;
end;

//Desc: ע����������
procedure TDBConnManager.RegisterDataType;
begin
  if not Assigned(gMemDataManager) then
    raise Exception.Create('DBConnManager Needs MemDataManager Support.');
  //xxxxx

  with gMemDataManager do
  begin
    FIDASyncItem := RegDataType('ASyncItem', 'DBConnManager', OnNew, OnFree, 2);
  end;
end;

//Desc: ��ȡ���������
function TDBConnManager.GetMaxConn: Integer;
begin
  Result := FWorkers.Count;
end;

//Desc: ������������������(����ǰ����)
procedure TDBConnManager.SetMaxConn(const nValue: Integer);
var nIdx: Integer;
    nItem: PDBWorker;
begin
  FSyncLock.Enter;
  try
    if FWorkers.Count <= nValue then
    begin
      for nIdx:=FWorkers.Count to nValue-1  do
      begin
        New(nItem);
        FWorkers.Add(nItem);
        FillChar(nItem^, SizeOf(TDBWorker), #0);

        with nItem^ do
        begin
          if not Assigned(FConn) then
          begin
            FConn := TADOConnection.Create(nil);
            InterlockedIncrement(FStatus.FNumConnObj);

            with FConn do
            begin
              ConnectionTimeout := 7;
              LoginPrompt := False;
              AfterConnect := DoAfterConnection;
              AfterDisconnect := DoAfterDisconnection;
            end;
          end;

          if not Assigned(FQuery) then
          begin
            FQuery := TADOQuery.Create(nil);
            FQuery.Connection := FConn;
          end;

          if not Assigned(FExec) then
          begin
            FExec := TADOQuery.Create(nil);
            FExec.Connection := FConn;
          end;

          if not Assigned(FWaiter) then
          begin
            FWaiter := TWaitObject.Create;
            FWaiter.Interval := 2 * 10;
          end;

          if not Assigned(FLock) then
            FLock := TCriticalSection.Create;
          FIdle := True;
        end;
      end; //add

      Exit;
    end;

    try
      InterlockedExchange(FConnClosing, cTrue);
      //close flag

      for nIdx:=FWorkers.Count - 1 downto nValue do
        WorkerAction(nil, nIdx, True);
      //delete 
    finally
      InterlockedExchange(FConnClosing, cFalse);
    end;
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2012-4-1
//Parm: ��������;����;�ͷ�,����
//Desc: ��nWorker��nIdx�����Ķ������ͷŻ���������
procedure TDBConnManager.WorkerAction(const nWorker: PDBWorker;
 const nIdx: Integer; const nFree: Boolean);
var i: Integer;
    nItem: PDBWorker;
begin
  if Assigned(nWorker) then
       i := FWorkers.IndexOf(nWorker)
  else i := nIdx;

  if i < 0 then Exit;
  nItem := FWorkers[i];
  if not Assigned(nItem) then Exit;

  if not nFree then
  begin
    nItem.FIdle := True;
    nItem.FUsed := 0;
    Exit;
  end;

  with nItem^ do
  begin
    FreeAndNil(FQuery);
    FreeAndNil(FExec);
    FreeAndNil(FConn);
    FreeAndNil(FLock);
    FreeAndNil(FWaiter);
  end;

  Dispose(nItem);
  FWorkers.Delete(nIdx);
end;

//Desc: ��ȡ���ж���
function TDBConnManager.GetIdleWorker(const nLocked: Boolean): PDBWorker;
var nIdx: Integer;
    nItem: PDBWorker;
begin
  Result := nil;

  for nIdx:=FWorkers.Count - 1 downto 0 do
  begin
    nItem := FWorkers[nIdx];
    if not nItem.FIdle then Continue;

    nItem.FIdle := not nLocked;
    Result := nItem;
    Break;
  end;
end;

//Desc: ��չ���������
procedure TDBConnManager.ClearWorkers(const nFreeMe: Boolean);
var nIdx: Integer;
begin
  for nIdx:=FWorkers.Count - 1 downto 0 do
    WorkerAction(nil, nIdx, True);
  //clear

  if nFreeMe then
    FWorkers.Free;
  //free
end;

//Desc: �ͷ��ֵ���
procedure TDBConnManager.DoFreeDict(const nType: Word; const nData: Pointer);
begin
  Dispose(PDBParam(nData));
end;

//Desc: �ͷ����Ӷ���
procedure TDBConnManager.FreeDBConnItem(const nItem: PDBConnItem);
var nIdx: Integer;
begin
  for nIdx:=Low(nItem.FWorker) to High(nItem.FWorker) do
  begin
    WorkerAction(nItem.FWorker[nIdx], -1, False);
    nItem.FWorker[nIdx] := nil;
  end;

  Dispose(nItem);
end;

//Desc: �������Ӷ���
procedure TDBConnManager.ClearConnItems(const nFreeMe: Boolean);
var nIdx: Integer;
begin
  if nFreeMe then
    InterlockedExchange(FAllowedRequest, cFalse);
  //����ر�

  FSyncLock.Enter;
  try
    CloseConnection('', False);
    //�Ͽ�ȫ������

    for nIdx:=FConnItems.Count - 1 downto 0 do
    begin
      FreeDBConnItem(FConnItems[nIdx]);
      FConnItems.Delete(nIdx);
    end;

    if nFreeMe then
      FreeAndNil(FConnItems);
    FillChar(FStatus, SizeOf(FStatus), #0);
  finally
    FSyncLock.Leave;
  end;
end;

//Desc: �Ͽ������ݿ������
function TDBConnManager.Disconnection(const nID: string): Integer;
begin
  Result := CloseConnection(nID, True);
end;

//Desc: �Ͽ�nWorker����������,�Ͽ��ɹ�����True.
function TDBConnManager.CloseWorkerConnection(const nWorker: PDBWorker): Boolean;
begin
  //�ó���,�ȴ����������ͷ�
  FSyncLock.Leave;
  try
    while nWorker.FUsed > 0 do
      nWorker.FWaiter.EnterWait;
    //�ȴ������˳�
  finally
    FSyncLock.Enter;
  end;

  try
    nWorker.FConn.Connected := False;
  except
    //ignor any error
  end;

  Result := not nWorker.FConn.Connected;
end;

//Desc: �ر�ָ������,���عرո���.
function TDBConnManager.CloseConnection(const nID: string;
  const nLock: Boolean): Integer;
var nIdx,nInt: Integer;
    nItem: PDBConnItem;
begin
  Result := 0;
  if InterlockedExchange(FConnClosing, cTrue) = cTrue then Exit;

  if nLock then FSyncLock.Enter;
  try
    for nIdx:=FConnItems.Count - 1 downto 0 do
    begin
      nItem := FConnItems[nIdx];
      if (nID <> '') and (CompareText(nItem.FID, nID) <> 0) then Continue;

      nItem.FUsed := 0;
      //���ü���

      for nInt:=Low(nItem.FWorker) to High(nItem.FWorker) do
      if Assigned(nItem.FWorker[nInt]) then
      begin
        if CloseWorkerConnection(nItem.FWorker[nInt]) then
          Inc(Result);
        nItem.FWorker[nInt].FUsed := 0;
      end;
    end;
  finally
    InterlockedExchange(FConnClosing, cFalse);
    if nLock then FSyncLock.Leave;
  end;
end;

//Desc: �������ӳɹ�
procedure TDBConnManager.DoAfterConnection(Sender: TObject);
begin
  InterlockedIncrement(FStatus.FNumObjConned);
end;

//Desc: ���ݶϿ��ɹ�
procedure TDBConnManager.DoAfterDisconnection(Sender: TObject);
begin
  InterlockedDecrement(FStatus.FNumObjConned);
end;

//------------------------------------------------------------------------------
//Desc: ���ɱ��������ݿ�����
class function TDBConnManager.MakeDBConnection(const nParam: TDBParam): string;
begin
  with nParam do
  begin
    Result := FConn;
    Result := StringReplace(Result, '$DBName', FDB, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '$Host', FHost, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '$User', FUser, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '$Pwd', FPwd, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '$Port', IntToStr(FPort), [rfReplaceAll, rfIgnoreCase]);
  end;
end;

//Desc: ��Ӳ���
procedure TDBConnManager.AddParam(const nParam: TDBParam);
var nPtr: PDBParam;
    nData: PDictData;
begin
  if nParam.FID = '' then Exit;

  FSyncLock.Enter;
  try
    nData := FParams.FindItem(nParam.FID);
    if not Assigned(nData) then
    begin
      New(nPtr);
      FParams.AddItem(nParam.FID, nPtr, 0, False);
      Inc(FStatus.FNumConnParam);
    end else nPtr := nData.FData;

    nPtr^ := nParam;
    nPtr.FConn := MakeDBConnection(nParam);

    if nPtr.FNumWorker < 1 then
      nPtr.FNumWorker := 3;
    //xxxxx

    if FConnDef = '' then
      FConnDef := nParam.FID;
    //first is default
  finally
    FSyncLock.Leave;
  end;
end;

//Desc: ɾ������
procedure TDBConnManager.DelParam(const nID: string);
begin
  FSyncLock.Enter;
  try
    if FParams.DelItem(nID) then
      Dec(FStatus.FNumConnParam);
    //xxxxx
  finally
    FSyncLock.Leave;
  end;
end;

//Desc: �������
procedure TDBConnManager.ClearParam;
begin
  FSyncLock.Enter;
  try
    FParams.ClearItem;
    FStatus.FNumConnParam := 0;
  finally
    FSyncLock.Leave;
  end;
end;

//Desc: ��ȡnID�����������ַ���
function TDBConnManager.GetConnectionStr(const nID: string): string;
var nPtr: PDBParam;
    nData: PDictData;
begin
  FSyncLock.Enter;
  try
    nData := FParams.FindItem(nID);
    if Assigned(nData) then
    begin
      nPtr := nData.FData;
      Result := nPtr.FConn;
    end else Result := '';
  finally
    FSyncLock.Leave;
  end;
end;

//------------------------------------------------------------------------------
//Date: 2011-10-23
//Parm: ���ӱ�ʶ;������;ͬ�߳�ʹ����ͬ��·
//Desc: ����nID���õ��������Ӷ���
function TDBConnManager.GetConnection(const nID: string; var nErrCode: Integer;
 const nThreadUnion: Boolean): PDBWorker;
var nIdx: Integer;
    nParam: PDictData;
    nWorker: PDBWorker;
    nItem,nIdle,nTmp: PDBConnItem;
begin
  Result := nil;
  nErrCode := cErr_GetConn_NoAllowed;

  if FAllowedRequest = cFalse then
  begin
    WriteLog(sNoAllowedWhenRequest);
    Exit;
  end;

  nErrCode := cErr_GetConn_Closing;
  if FConnClosing = cTrue then
  begin
    WriteLog(sClosingWhenRequest);
    Exit;
  end;

  FSyncLock.Enter;
  try
    nErrCode := cErr_GetConn_NoAllowed;
    if FAllowedRequest = cFalse then
    begin
      WriteLog(sNoAllowedWhenRequest);
      Exit;
    end;

    nErrCode := cErr_GetConn_Closing;
    if FConnClosing = cTrue then
    begin
      WriteLog(sClosingWhenRequest);
      Exit;
    end;
    //�ظ��ж�,����Get��close���������ص�(get.enter��close.enter�������ȴ�)

    Inc(FStatus.FNumObjRequest);
    nErrCode := cErr_GetConn_NoParam;
    nParam := FParams.FindItem(nID);
    
    if not Assigned(nParam) then
    begin
      WriteLog(sNoParamWhenRequest);
      Exit;
    end;

    //--------------------------------------------------------------------------
    nItem := nil;
    nIdle := nil;

    for nIdx:=FConnItems.Count - 1 downto 0 do
    begin
      nTmp := FConnItems[nIdx];
      if CompareText(nID, nTmp.FID) = 0 then
      begin
        nItem := nTmp; Break;
      end;

      if nTmp.FUsed < 1 then
       if (not Assigned(nIdle)) or (nIdle.FLast > nTmp.FLast) then
        nIdle := nTmp;
      //����ʱ�������
    end;

    if not Assigned(nItem) then
    begin
      nWorker := GetIdleWorker(False);
      if (not Assigned(nIdle)) and (not Assigned(nWorker)) then
      begin
        nErrCode := cErr_GetConn_MaxConn; Exit;
      end;

      if Assigned(nWorker) then
      begin
        New(nItem);
        FConnItems.Add(nItem);
        Inc(FStatus.FNumConnItem);

        nItem.FID := nID;
        nItem.FUsed := 0;
        SetLength(nItem.FWorker, PDBParam(nParam.FData).FNumWorker);

        for nIdx:=Low(nItem.FWorker) to High(nItem.FWorker) do
          nItem.FWorker[nIdx] := nil;
        //xxxxx
      end else
      begin
        nItem := nIdle;
        nItem.FID := nID;
        nItem.FUsed := 1;

        try
          for nIdx:=Low(nItem.FWorker) to High(nItem.FWorker) do
           if Assigned(nItem.FWorker[nIdx]) then
            CloseWorkerConnection(nItem.Fworker[nIdx]);
          Inc(FStatus.FNumObjReUsed);
        finally
          nItem.FUsed := 0;
        end;
      end;
    end;

    //--------------------------------------------------------------------------
    with nItem^ do
    begin
      for nIdx:=Low(FWorker) to High(FWorker) do
      begin
        if (Assigned(FWorker[nIdx])) and
           (FWorker[nIdx].FThreadID > 0) and
           (FWorker[nIdx].FThreadID = GetCurrentThreadId) then
        begin
          Result := FWorker[nIdx];
          Inc(Result.FCallNum);

          WriteLog(Format('ͬ�߳�[ %d ]ƥ��ɹ�.', [Result.FThreadID]));
          Break;
        end;
      end; //����ɨ��ͬ�߳���·

      if not Assigned(Result) then
      begin
        for nIdx:=Low(FWorker) to High(FWorker) do
        begin
          if Assigned(FWorker[nIdx]) then
          begin
            if FWorker[nIdx].FUsed < 1 then
            begin
              Result := FWorker[nIdx];
              Break;
            end;

            //�Ŷ����ٵĹ�������
            if (not Assigned(Result)) or
               (FWorker[nIdx].FUsed < Result.FUsed) then
            begin
              Result := FWorker[nIdx];
            end;
          end else
          begin
            Result := GetIdleWorker(True);
            FWorker[nIdx] := Result;
            if Assigned(Result) then Break;
          end; //�¹�������
        end;
      end; //ɨ�������·

      if Assigned(Result) then
      begin
        Inc(Result.FUsed);
        Inc(nItem.FUsed);
        Inc(FStatus.FNumObjWait);

        if nThreadUnion and (Result.FThreadID < 1) then
        begin
          Inc(Result.FCallNum);
          Result.FThreadID := GetCurrentThreadId;
        end;
        {-----------------------------------------------------------------------
        ԭ��:
        1.���÷�����Worker���ڵ�ThreadID.
        2.���ڱ����÷����ȼ���ͬ�̵߳�Worker,�����ɹ������ӵ��ü���.
        3.���÷�ʹ����Ϻ�,ɾ��ThreadID.
        -----------------------------------------------------------------------}

        if nItem.FUsed > FStatus.FNumWaitMax then
        begin
          FStatus.FNumWaitMax := nItem.FUsed;
          FStatus.FNumMaxTime := Now;
        end;

        if not Result.FConn.Connected then
          Result.FConn.ConnectionString := PDBParam(nParam.FData).FConn;
        Result.FConnItem := nItem;
      end;
    end;
  finally
    if not Assigned(Result) then
      Inc(FStatus.FNumObjRequestErr);
    FSyncLock.Leave;
  end;

  if Assigned(Result) then
  with Result^ do
  begin
    if Result.FCallNum <= 1 then
      FLock.Enter;
    //������������Ŷ�

    if FConnClosing = cTrue then
    try
      Result := nil;
      nErrCode := cErr_GetConn_Closing;

      InterlockedDecrement(FUsed);
      InterlockedDecrement(FStatus.FNumObjWait);
      FWaiter.Wakeup;
    finally
      FLock.Leave;
    end;

    if Result.FCallNum <= 1 then
      CoInitialize(nil);
    //��ʼ��COM����
  end;
end;

//Date: 2011-10-23
//Parm: ���ݶ���
//Desc: �ͷ�nWorker���Ӷ���
procedure TDBConnManager.ReleaseConnection(const nWorker: PDBWorker);
var nItem: PDBConnItem;
begin
  if not Assigned(nWorker) then Exit;
  //invalid worker to release

  FSyncLock.Enter;
  try
    if nWorker.FCallNum > 0 then
      Dec(nWorker.FCallNum);
    //ͬ�̵߳��ü���

    if nWorker.FCallNum < 1 then
    try
      nWorker.FThreadID := 0;
      //ͬ�̵߳��ý���,ɾ���̱߳�ʶ
      
      if nWorker.FQuery.Active then
        nWorker.FQuery.Close;
      //xxxxx
    except
      on E:Exception do
      begin
        WriteLog('Release Error:' + E.Message);
      end;
    end;

    nItem := nWorker.FConnItem;
    Dec(nItem.FUsed);
    nItem.FLast := GetTickCount;

    Dec(nWorker.FUsed);
    if nWorker.FCallNum < 1 then
      nWorker.FLock.Leave;
    Dec(FStatus.FNumObjWait);

    if FConnClosing = cTrue then
      nWorker.FWaiter.Wakeup;
    //xxxxx
  finally
    if nWorker.FCallNum < 1 then
      CoUnInitialize; //�ͷ�COM����    
    FSyncLock.Leave;
  end;
end;

//------------------------------------------------------------------------------
//Desc: ��ȡ����״̬
function TDBConnManager.GetRunStatus: TDBConnStatus;
begin
  FSyncLock.Enter;
  try
    Result := FStatus;
  finally
    FSyncLock.Leave;
  end;
end;

//Desc: ִ��д�������
function TDBConnManager.WorkerExec(const nWorker: PDBWorker;
  const nSQL: string): Integer;
var nStep: Integer;
    nException: string;
begin
  Result := -1;
  nException := '';
  nStep := 0;

  while nStep <= 2 do
  try
    if nStep = 1 then
    begin
      nWorker.FQuery.Close;
      nWorker.FQuery.SQL.Text := 'select 1';
      nWorker.FQuery.Open;

      nWorker.FQuery.Close;
      Break;
      //connection is ok
    end else

    if nStep = 2 then
    begin
      nWorker.FConn.Close;
      nWorker.FConn.Open;
    end; //reconnnect
           
    nWorker.FExec.Close;
    nWorker.FExec.SQL.Text := nSQL;
    Result := nWorker.FExec.ExecSQL;

    nException := '';
    Break;
  except
    on E:Exception do
    begin
      Inc(nStep);
      nException := E.Message;
    end;
  end;

  if nException <> '' then
  begin
    WriteLog('SQL: ' + nSQL + ' ::: ' + nException);
    raise Exception.Create(nException);
  end;
end;

//Desc: ִ�в�ѯ���
function TDBConnManager.WorkerQuery(const nWorker: PDBWorker;
  const nSQL: string): TDataSet;
var nStep: Integer;
    nException: string;
begin
  Result := nWorker.FQuery;
  nException := '';
  nStep := 0;

  while nStep <= 2 do
  try
    if nStep = 1 then
    begin
      nWorker.FQuery.Close;
      nWorker.FQuery.SQL.Text := 'select 1';
      nWorker.FQuery.Open;

      nWorker.FQuery.Close;
      Break;
      //connection is ok
    end else

    if nStep = 2 then
    begin
      nWorker.FConn.Close;
      nWorker.FConn.Open;
    end; //reconnnect
    
    nWorker.FQuery.Close;
    nWorker.FQuery.SQL.Text := nSQL;
    nWorker.FQuery.Open;

    nException := '';
    Break;
  except
    on E:Exception do
    begin
      Inc(nStep);
      nException := E.Message;
    end;
  end;

  if nException <> '' then
  begin
    WriteLog('SQL: ' + nSQL + ' ::: ' + nException);
    raise Exception.Create(nException);
  end;
end;

//Date: 2013-07-26
//Parm: ���;��������;���ӱ�ʶ
//Desc: ��nID���ݿ���ִ��nSQL��ѯ,���ؽ��.���ֶ��ͷ�nWorker.
function TDBConnManager.SQLQuery(const nSQL: string; var nWorker: PDBWorker;
  nID: string): TDataSet;
var nErrNum: Integer;
begin
  if nID = '' then
    nID := FConnDef;
  nWorker := GetConnection(nID, nErrNum);

  if not Assigned(nWorker) then
  begin
    nID := Format('����[ %s ]���ݿ�ʧ��(ErrCode: %d).', [nID, nErrNum]);
    WriteLog(nID);
    raise Exception.Create(nID);
  end;

  if not nWorker.FConn.Connected then
    nWorker.FConn.Connected := True;
  //conn db

  Result := WorkerQuery(nWorker, nSQL);
  //do query
end;

//Date: 2013-07-23
//Parm: ���;���ӱ�ʶ
//Desc: ��nID���ݿ���ִ��nSQL���
function TDBConnManager.ExecSQL(const nSQL: string; nID: string): Integer;
var nErrNum: Integer;
    nDBConn: PDBWorker;
begin
  nDBConn := nil;
  try
    Result := -1;
    if nID = '' then nID := FConnDef;
    nDBConn := GetConnection(nID, nErrNum);

    if not Assigned(nDBConn) then
    begin
      nID := Format('����[ %s ]���ݿ�ʧ��(ErrCode: %d).', [nID, nErrNum]);
      WriteLog(nID);
      raise Exception.Create(nID);
    end;

    if not nDBConn.FConn.Connected then
      nDBConn.FConn.Connected := True;
    //conn db

    Result := WorkerExec(nDBConn, nSQL);
    //do exec
  finally
    ReleaseConnection(nDBConn);
  end;
end;

//Date: 2013-07-23
//Parm: ����б�;�Ƿ�����;���ӱ�ʶ
//Desc: ��nID���ݿ���ִ��nSQLs���
function TDBConnManager.ExecSQLs(const nSQLs: TStrings; const nTrans: Boolean;
  nID: string): Boolean;
var nIdx: Integer;
    nErrNum: Integer;
    nDBConn: PDBWorker;
begin
  nDBConn := nil;
  try
    Result := False;
    if nID = '' then nID := FConnDef;
    nDBConn := GetConnection(nID, nErrNum);

    if not Assigned(nDBConn) then
    begin
      nID := Format('����[ %s ]���ݿ�ʧ��(ErrCode: %d).', [nID, nErrNum]);
      WriteLog(nID);
      raise Exception.Create(nID);
    end;

    if not nDBConn.FConn.Connected then
      nDBConn.FConn.Connected := True;
    //conn db

    if nTrans then
      nDBConn.FConn.BeginTrans;
    //trans
    try
      for nIdx:=0 to nSQLs.Count - 1 do
        WorkerExec(nDBConn, nSQLs[nIdx]);
      //execute sql list

      if nTrans then
        nDBConn.FConn.CommitTrans;
      Result := True;
    except
      on E:Exception do
      begin
        if nTrans then
          nDBConn.FConn.RollbackTrans;
        WriteLog('SQL: ' + nSQLs.Text + ' ::: ' + E.Message);
      end;
    end;
  finally
    ReleaseConnection(nDBConn);
  end;
end;

//Date: 2013-07-27
//Parm: ����;����;���ӱ�ʶ
//Desc: ��nID���ݿ���ִ��nAction�����ҵ��
function TDBConnManager.DBAction(const nAction: TDBActionCallback;
  const nData: Pointer; nID: string): Boolean;
var nErrNum: Integer;
    nDBConn: PDBWorker;
begin
  nDBConn := nil;
  try
    Result := False;
    if nID = '' then nID := FConnDef;
    nDBConn := GetConnection(nID, nErrNum);

    if not Assigned(nDBConn) then
    begin
      nID := Format('����[ %s ]���ݿ�ʧ��(ErrCode: %d).', [nID, nErrNum]);
      WriteLog(nID);
      raise Exception.Create(nID);
    end;

    if not nDBConn.FConn.Connected then
      nDBConn.FConn.Connected := True;
    //conn db

    Result := nAction(nDBConn, nData);
    //do action
  finally
    ReleaseConnection(nDBConn);
  end;
end;

//Date: 2013-07-27
//Parm: ����;���ӱ�ʶ
//Desc: ��nID���ݿ���ִ��nAction�����ҵ��
function TDBConnManager.DBAction(const nAction: TDBActionCallbackObj;
  const nData: Pointer; nID: string): Boolean;
var nErrNum: Integer;
    nDBConn: PDBWorker;
begin
  nDBConn := nil;
  try
    Result := False;
    if nID = '' then nID := FConnDef;
    nDBConn := GetConnection(nID, nErrNum);

    if not Assigned(nDBConn) then
    begin
      nID := Format('����[ %s ]���ݿ�ʧ��(ErrCode: %d).', [nID, nErrNum]);
      WriteLog(nID);
      raise Exception.Create(nID);
    end;

    if not nDBConn.FConn.Connected then
      nDBConn.FConn.Connected := True;
    //conn db

    Result := nAction(nDBConn, nData);
    //do action
  finally
    ReleaseConnection(nDBConn);
  end;
end;

procedure TDBConnManager.GetStatus(const nList: TStrings);
begin
  with GetRunStatus do
  begin
    nList.Add('NumConnParam: ' + #9 + IntToStr(FNumConnParam));
    nList.Add('NumConnItem: ' + #9 + IntToStr(FNumConnItem));
    nList.Add('NumConnObj: ' + #9 + IntToStr(FNumConnObj));
    nList.Add('NumObjConned: ' + #9 + IntToStr(FNumObjConned));
    nList.Add('NumObjReUsed: ' + #9 + IntToStr(FNumObjReUsed));
    nList.Add('NumObjRequest: ' + #9 + IntToStr(FNumObjRequest));
    nList.Add('NumObjReqErr: ' + #9 + IntToStr(FNumObjRequestErr));
    nList.Add('NumObjWait: ' + #9 + IntToStr(FNumObjWait));
    nList.Add('NumWaitMax: ' + #9 + IntToStr(FNumWaitMax));
    nList.Add('NumMaxTime: ' + #9 + DateTimeToStr(FNumMaxTime));
  end;
end;

//------------------------------------------------------------------------------
procedure TDBConnManager.ASyncStart;
begin
  if not Assigned(FASyncWriter) then
    FASyncWriter := TDBASyncWriter.Create(Self);
  FASyncWriter.Wakeup;
end;

procedure TDBConnManager.ASyncStop;
begin
  if Assigned(FASyncWriter) then
    FASyncWriter.StopMe;
  FASyncWriter := nil;
end;

//Date: 2017-12-27
//Parm: ��ˮ��;�ȴ���ʱʱ��(ms)
//Desc: ��ȡ���ͷ�nSerialNoָ���ĵȴ�����
function TDBConnManager.ASyncWaiteFor(const nSerial: string;
  nWaitFor: Word): TWaitObject;
var nIdx,nInt: Integer;
begin
  Result := nil;
  //init

  FSyncLock.Enter;
  try
    if nWaitFor < 1 then
    begin
      for nIdx:=Low(FASyncWaiter) to High(FASyncWaiter) do
       with FASyncWaiter[nIdx] do
        if CompareText(nSerial, FSerialNo) = 0 then
        begin
          FEnabled := False;
          Break;
        end;

      Exit;
    end; //����ȴ�����

    nInt := -1;
    //default

    for nIdx:=Low(FASyncWaiter) to High(FASyncWaiter) do
    if CompareText(nSerial, FASyncWaiter[nIdx].FSerialNo) = 0 then
    begin
      nInt := nIdx;
      Break;
    end; //ͬ��ˮ�Ŷ�ε���,ʹ����ͬ����

    if nInt < 0 then
    begin
      for nIdx:=Low(FASyncWaiter) to High(FASyncWaiter) do
      if not FASyncWaiter[nIdx].FEnabled then
      begin
        nInt := nIdx;
        Break;
      end;
    end; //����δʹ�õĶ���

    if nInt < 0 then
    begin
      nInt := Length(FASyncWaiter);
      SetLength(FASyncWaiter, nInt + 1);
      FASyncWaiter[nInt].FWaiter := TWaitObject.Create;
    end; //�¶���

    with FASyncWaiter[nInt] do
    begin
      FEnabled := True;
      FSerialNo := nSerial;

      Result := FWaiter;
      Result.Interval := nWaitFor;
      Result.InitStatus(False);
    end;
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2017-12-27
//Parm: ��ˮ��
//Desc: ����nSerial�ȴ�
procedure TDBConnManager.ASyncWaiteOver(const nSerial: string);
var nIdx: Integer;
begin
  FSyncLock.Enter;
  try
    for nIdx:=Low(FASyncWaiter) to High(FASyncWaiter) do
     with FASyncWaiter[nIdx] do
      if FEnabled and (CompareText(nSerial, FSerialNo) = 0) then
      begin
        FWaiter.Wakeup(True);
        Break;
      end;
  finally
    FSyncLock.Leave;
  end;   
end;

//Date: 2017-12-27
//Desc: �ͷŵȴ�����
procedure TDBConnManager.ASyncClearWaiters;
var nIdx: Integer;
begin
  for nIdx:=Low(FASyncWaiter) to High(FASyncWaiter) do
    FreeAndNil(FASyncWaiter[nIdx].FWaiter);
  SetLength(FASyncWaiter, 0);
end;

//Date: 2017-11-20
//Parm: ����ʼ����;������ˮ��
//Desc: ��ʼ���첽д��������
procedure TDBConnManager.ASyncInitItem(const nSQLItem: PDBASyncItem;
  const nNewSerial: Boolean);
var nDef: TDBASyncItem;
begin
  FillChar(nDef, SizeOf(TDBASyncItem), #0);
  //init

  with nDef do
  begin
    FStartNow := False;    
    if nNewSerial then
         FSerialNo := DateTimeSerial
    else FSerialNo := nSQLItem.FSerialNo;
  end;

  nSQLItem^ := nDef;
  //return default
end;

//Date: 2017-12-08
//Parm: ���ݿ�����
//Desc: ��ʼ���첽д���������ݿ�������
procedure TDBConnManager.ASyncInitDB;
var nStr: string;
    nList: TStrings;
    nWorker: PDBWorker;
begin
  nWorker := nil;
  nList := TStringList.Create;
  try
    if FASyncDBType = stSQLServer then
    begin
      nStr := 'Select * From dbo.SysObjects Where ID = object_id(' +
              'N''[%s]'') And ObjectProperty(ID, ''IsTable'') = 1';
      nStr := Format(nStr, [cTable_ASync]);

      with SQLQuery(nStr, nWorker) do
      if RecordCount > 0 then
      begin
        Exit;
        //table exists
      end;

      nStr := 'Create Table $TB(' +
        'R_ID Integer IDENTITY (1,1) PRIMARY KEY,' +
        'A_SerialNo varChar(32),' +
        'A_PairKey varChar(32),' +
        'A_SQL varchar(max),' +
        'A_IfQuery varchar(max),' +
        'A_IfField varChar(32),' +
        'A_IfType Integer,' +
        'A_IfValue varChar(32),' +
        'A_IfSQL varchar(max),' +

        'A_Status Char(1) default ''U'',' + //unknown
        'A_RunNum Integer default 0,' +
        'A_TimeIn DateTime,A_TimeDone DateTime,' +
        'A_Memo varchar(max));';
      //sql

      nStr := nStr +
        'Create Index idx_no on $TB(A_SerialNo DESC);' +
        'Create Index idx_status on $TB(A_Status ASC,A_RunNum ASC);';
      //index

      nStr := MacroValue(nStr, [MI('$TB', cTable_ASync)]);
      WorkerExec(nWorker, nStr);
      //create table
    end;
  finally
    nList.Free;
    ReleaseConnection(nWorker);
  end;
end;

//Date: 2017-12-10
//Parm: SQL;����or����
//Desc: ����nSQL�е������ַ�
function EncodeSQL(const nSQL: string; const nEncode: Boolean = False): string;
begin
  if nEncode then
  begin
    //Result := StringReplace(nSQL, '''', '\./', [rfReplaceAll]);
    Result := StringReplace(nSQL, '''', '''''', [rfReplaceAll]);
  end else
  begin
    //Result := StringReplace(nSQL, '\./', '''', [rfReplaceAll]);
    Result := nSQL;
  end;
end;

//Date: 2017-12-08
//Parm: �첽����
//Desc: ��Ӵ��첽�����������
procedure TDBConnManager.ASyncAdd(const nItem: PDBASyncItem);
var nStr: string;
begin
  if FASyncDBType = stSQLServer then
  begin
    nStr := MakeSQLByStr([
      SF('A_SerialNo', nItem.FSerialNo),
      SF('A_PairKey', nItem.FPairKey),
      SF('A_SQL', EncodeSQL(nItem.FSQL, True)),
      SF('A_IfQuery', EncodeSQL(nItem.FIfQuery, True)),
      SF('A_IfField', nItem.FIfField),
      SF('A_IfType', Ord(nItem.FIfType), sfVal),
      SF('A_IfValue', nItem.FIfValue),
      SF('A_IfSQL', EncodeSQL(nItem.FIfSQL, True)),

      SF_IF([SF('A_Status', cS_Run),
             SF('A_Status', cS_Pause)], nItem.FStartNow),
      //R,run;P,pause;O,over

      SF('A_TimeIn', 'getdate()', sfVal)
      ], cTable_ASync, '', True);
    //xxxxx

    ExecSQL(nStr);
    //д��Ĭ�Ͽ� 
  end;
end;

//Date: 2017-12-11
//Parm: ��ִ�����
//Desc: ���nSQL���첽ִ��ҵ��
procedure TDBConnManager.ASyncAddSimple(const nSQL: string);
var nItem: TDBASyncItem;
begin
  ASyncInitItem(@nItem, True);
  nItem.FSQL := nSQL;
  nItem.FStartNow := True;
  ASyncAdd(@nItem);
end;

//Date: 2017-12-20
//Parm: �첽����;SQL���;ҵ���ʶ
//Desc: ���nItem�첽ҵ��
procedure TDBConnManager.ASyncAddItem(const nItem: PDBASyncItem;
  const nSQL, nPair: string);
begin
  nItem.FSQL := nSQL;
  nItem.FPairKey := nPair;
  ASyncAdd(nItem);
end;

//Date: 2017-12-08
//Parm: ��ˮ��;�ȴ�ִ��ʱ��(����)
//Desc: ����nSeriaoNo��ʼ����
procedure TDBConnManager.ASyncApply(nSerialNo: string; const nWaitFor: Word);
var nStr: string;
    nInt: Integer;
    nWaiter: TWaitObject;
begin
  nSerialNo := Trim(nSerialNo);
  //regular
  nWaiter := nil;

  if FASyncDBType = stSQLServer then
  begin
    if nSerialNo <> '' then
    begin
      nStr := 'Update %s Set A_Status=''%s'',A_RunNum=0 ' +
              'Where A_SerialNo=''%s''';
      nStr := Format(nStr, [cTable_ASync, cS_Run, nSerialNo]);

      nInt := ExecSQL(nStr);
      if (nInt > 0) and (nWaitFor > 0) then
        nWaiter := ASyncWaiteFor(nSerialNo, nWaitFor);
      //wait for when have record
    end;
  end;

  try
    if Assigned(FASyncWriter) then
      FASyncWriter.Wakeup;
    //set status then run

    if Assigned(nWaiter) then
      nWaiter.EnterWait;
    //lock and wait
  finally
    if Assigned(nWaiter) then
      ASyncWaiteFor(nSerialNo, 0);
    //unlock
  end;
end;

//------------------------------------------------------------------------------
constructor TDBASyncWriter.Create(AOwner: TDBConnManager);
begin
  inherited Create(False);
  FreeOnTerminate := False;

  FOwner := AOwner;
  FBuffer := TList.Create;
    
  FWaiter := TWaitObject.Create;
  FWaiter.Interval := 5 * 1000;
end;

destructor TDBASyncWriter.Destroy;
begin
  ClearBuffer(True);
  FWaiter.Free;
  inherited;
end;

procedure TDBASyncWriter.ClearBuffer(const nFree: Boolean);
var nIdx: Integer;
begin
  if FBuffer.Count > 0 then
  begin
    for nIdx:=FBuffer.Count - 1 downto 0 do
      gMemDataManager.UnLockData(FBuffer[nIdx]);
    FBuffer.Clear;
  end;

  if nFree then
    FreeAndNil(FBuffer);
  //xxxxx
end;

procedure TDBASyncWriter.Wakeup;
begin
  FWaiter.Wakeup;
end;

procedure TDBASyncWriter.StopMe;
begin
  Terminate;
  FWaiter.Wakeup;

  WaitFor;
  Free;
end;

procedure TDBASyncWriter.Execute;
var nInit: Int64;
begin
  while not Terminated do
  try
    FWaiter.EnterWait;
    if Terminated then Exit;

    FDBWorker := nil;
    try
      if FBuffer.Count > 0 then
        ClearBuffer(False);
      //clear first

      nInit := GetTickCount;
      //init counter
      
      if FOwner.FASyncDBType = stSQLServer then
        DoExecute_SQLServer;
      //run sql server

      if FBuffer.Count > 0 then
      begin
        nInit := GetTickCount - nInit;
        WriteLog(Format('ASync Write %d Item(s) In %dms.', [FBuffer.Count, nInit]));
      end; //time consuming
    finally
      FOwner.ReleaseConnection(FDBWorker);
      ClearBuffer(False);
    end;
  except
    on E:Exception do
    begin
      WriteLog('ASync Error:' + E.Message);
    end;
  end;
end;

//Date: 2017-12-09
//Desc: ִ��SQLServer�첽ҵ��
procedure TDBASyncWriter.DoExecute_SQLServer;
var nStr: string;
    nIdx: Integer;
    nFirst,nLast: Int64;
    nItem: PDBASyncItem;
begin
  nStr := 'Select * From %s ' +
          'Where A_Status=''%s'' And A_RunNum<%d Order By R_ID ASC';
  nStr := Format(nStr, [cTable_ASync, cS_Run, cAsyncNum]);
  //first in,first run

  with FOwner.SQLQuery(nStr, FDBWorker) do
  begin
    if RecordCount < 1 then
      Exit;
    //no async data

    First;
    while not Eof do
    begin
      nItem := gMemDataManager.LockData(FOwner.FIDASyncItem);
      FBuffer.Add(nItem);

      with nItem^ do
      begin
        FRecordID  := FieldByName('R_ID').AsInteger;
        FSerialNo  := FieldByName('A_SerialNo').AsString;
        FPairKey   := FieldByName('A_PairKey').AsString;
        
        FSQL       := EncodeSQL(FieldByName('A_SQL').AsString);
        FIfQuery   := EncodeSQL(FieldByName('A_IfQuery').AsString);
        FIfField   := FieldByName('A_IfField').AsString;

        nIdx       := FieldByName('A_IfType').AsInteger;
        FStartNow  := (nIdx >= cR_Low) and (nIdx <= cR_High);
        
        if FStartNow then
        begin
          FIfType  := TDBASyncRelation(nIdx);
          FMemo    := '';
          FStatus  := cS_Run;
        end else
        begin
          FMemo    := '"A_IfType"Խ��';
          FStatus  := cS_Pause;
        end;

        FIfValue   := FieldByName('A_IfValue').AsString;
        FIfSQL     := EncodeSQL(FieldByName('A_IfSQL').AsString);
      end;

      Next;
    end;
  end;

  //----------------------------------------------------------------------------
  nFirst := PDBASyncItem(FBuffer[0]).FRecordID;
  nLast := PDBASyncItem(FBuffer[FBuffer.Count - 1]).FRecordID;
  //record range

  nStr := 'Update %s Set A_RunNum=A_RunNum+1 ' +
          'Where (R_ID>=%d And R_ID<=%d) And (A_Status=''%s'' And A_RunNum<%d)';
  //inc counter

  nStr := Format(nStr, [cTable_ASync, nFirst, nLast, cS_Run, cAsyncNum]);
  FOwner.WorkerExec(FDBWorker, nStr);

  for nIdx:=0 to FBuffer.Count-1 do
  begin
    nItem := FBuffer[nIdx];
    if not nItem.FStartNow then Continue;

    try
      WriteData_SQLServer(nItem);
    except
      on nErr: Exception do
      begin
        nItem.FMemo := nErr.Message;
      end;
    end;
  end;

  for nIdx:=FBuffer.Count-1 downto 0 do
  begin
    nItem := FBuffer[nIdx];
    if nItem.FMemo = '' then Continue;

    nStr := 'Update %s Set A_Memo=''%s'' Where R_ID=%d';
    nStr := Format(nStr, [cTable_ASync, nItem.FMemo, nItem.FRecordID]);
    FOwner.WorkerExec(FDBWorker, nStr);
  end;
end;

//Date: 2017-12-10
//Parm: ��д������;�ϲ�д��ͬ��ˮ������
//Desc: ��nDataд�����ݿ�
procedure TDBASyncWriter.WriteData_SQLServer(const nData: PDBASyncItem;
 const nCombineSerial: Boolean);
var nStr,nSQL: string;
    nFVal,nIVal: Double;
    nIdx: Integer;
    nItem: PDBASyncItem;
begin
  if nCombineSerial then
  begin
    if nCombineSerial then
    for nIdx:=FBuffer.Count - 1 downto 0 do
    begin
      nItem := FBuffer[nIdx];
      if nItem.FStartNow and (nItem.FSerialNo = nData.FSerialNo) then
        nItem.FStartNow := False;
      //�ϲ�д��ʱ,ͬ��ˮ�ż�¼ֻ��ִ��һ��,�ȹر�ִ�б��
    end;

    FDBWorker.FConn.BeginTrans;
    //trans start
  end;  

  try    
    nSQL := 'Update %s Set A_Status=''%s'',A_TimeDone=getdate() ' +
            'Where R_ID=%d';
    nSQL := Format(nSQL, [cTable_ASync, cS_Done, nData.FRecordID]);
    FOwner.WorkerExec(FDBWorker, nSQL);

    nSQL := nData.FSQL;
    if nData.FIfQuery <> '' then
    begin
      with FOwner.WorkerQuery(FDBWorker, nData.FIfQuery) do
      if RecordCount > 0 then
      begin
        if not Assigned(FindField(nData.FIfField)) then
        begin
          nStr := Format('�ֶ�"%s"������', [nData.FIfField]);
          raise Exception.Create(nStr);
        end;

        nFVal := 0;
        nIVal := 0;
        nStr := FieldByName(nData.FIfField).AsString;

        if nData.FIfType <> arSame then
        begin
          nFVal := StrToFloat(nStr);
          nIVal := StrToFloat(nData.FIfValue);
        end;

        case nData.FIfType of
         arGreater:
          begin
            if FloatRelation(nFVal, nIVal, rtGreater) then
              nSQL := nData.FIfSQL;
            //>
          end;  
         arGE:
          begin
            if FloatRelation(nFVal, nIVal, rtGE) then
              nSQL := nData.FIfSQL;
            //>=
          end;
         arEqual:
          begin
            if FloatRelation(nFVal, nIVal, rtEqual) then
              nSQL := nData.FIfSQL;
            //=
          end;
         arLE:
          begin
            if FloatRelation(nFVal, nIVal, rtLE) then
              nSQL := nData.FIfSQL;
            //<=
          end;
         arLess:
          begin
            if FloatRelation(nFVal, nIVal, rtLess) then
              nSQL := nData.FIfSQL;
            //<
          end;
         arSame:
          begin
            if CompareText(nStr, nData.FIfValue) = 0 then
              nSQL := nData.FIfSQL;
            //ignor case
          end;
        end;
      end;
    end;

    FOwner.WorkerExec(FDBWorker, nSQL);
    //write data
    
    if nCombineSerial then
    begin
      for nIdx:=0 to FBuffer.Count - 1 do //����˳��ִ��
      begin
        nItem := FBuffer[nIdx];
        if nItem = nData then Continue;

        if (nItem.FSerialNo = nData.FSerialNo) and (nItem.FStatus = cS_Run) then
          WriteData_SQLServer(nItem, False);
        //ͬ��ˮ
      end;

      FDBWorker.FConn.CommitTrans;
      //apply data

      FOwner.ASyncWaiteOver(nData.FSerialNo);
      //wakeup wait item
    end;
  except
    if nCombineSerial then
      FDBWorker.FConn.RollbackTrans;
    raise;
  end;
end;

initialization
  gDBConnManager := nil;
finalization
  FreeAndNil(gDBConnManager);
end.
