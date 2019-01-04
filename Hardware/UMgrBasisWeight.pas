{*******************************************************************************
  ����: dmzn@163.com 2018-12-26
  ����: ���ڵذ��Ķ���װ��ҵ��
*******************************************************************************}
unit UMgrBasisWeight;

interface

uses
  Windows, Classes, SysUtils, SyncObjs, UMgrPoundTunnels, ULibFun,
  UWaitItem, USysLoger;

type
  TBWStatus = (bsInit, bsNew, bsStart, bsProcess, bsStable, bsDone, bsClose);
  //״̬: ��ʼ��;������;��ʼ;װ����;ƽ��;���;�ر�

  PBWTunnel = ^TBWTunnel;
  TBWTunnel = record
    FID           : string;            //ͨ����ʶ
    FBill         : string;            //��������
    FValue        : Double;            //��װ��
    FValHas       : Double;            //��װ��:ƽ�Ⱥ����Чֵ
    FValMax       : Double;            //�������:�ذ����ֵ������ֵ
    FValTunnel    : Double;            //ͨ������:��ǰ�ذ�����
    FValUpdate    : Int64;             //ͨ������:ͨ�����ݵĸ���ʱ��
    FValAdjust    : Double;            //�������:��ֵ,�����������������
    FValPercent   : Double;            //��������:�ٷֱ�,��ֹ�����ı�����
    FWeightMax    : Double;            //�������װ��:��ֵ,װ���������������

    FStatusNow    : TBWStatus;         //��ǰ״̬
    FStatusNew    : TBWStatus;         //��״̬
    FStableDone   : Boolean;           //ƽ��״̬
    FWeightDone   : Boolean;           //װ�����:���װ����
    FWeightOver   : Boolean;           //װ������:��ɲ��������

    //TimeOut
    FTONoData     : Integer;           //��ʱ��������
    FTONoWeight   : Integer;           //��ʱ��δ�ϰ�
    FInitWeight   : Int64;             //��ʼҵ���ʱ
    FTOProceFresh : Integer;           //װ������ˢ��
    FInitFresh    : Int64;             //����ˢ�¼�ʱ
    FValFresh     : Double;            //����ˢ������

    FTunnel       : PPTTunnelItem;     //ͨ������
    FParams       : TStrings;          //������
    FSampleIndex  : Integer;           //��������
    FValSamples   : array of Double;   //���ݲ���
  end;

  TBasisWeightManager = class;
  TBasisWeightWorker = class(TThread)
  private
    FOwner: TBasisWeightManager;
    //ӵ����
    FActive: PBWTunnel;
    //��ǰͨ��
    FWaiter: TWaitObject;
    //�ȴ�����
  protected
    procedure DoBasisWeight;
    procedure Execute; override;
    //ִ��ҵ��
    function IsValidSamaple(const nCheckMin: Boolean): Boolean;
    //��֤����
  public
    constructor Create(AOwner: TBasisWeightManager);
    destructor Destroy; override;
    //�����ͷ�
    procedure WakupMe;
    //�����߳�
    procedure StopMe;
    //ֹͣ�߳�
  end;

  TBWStatusChange = procedure (const nTunnel: PBWTunnel);
  TBWStatusChangeEvent = procedure (const nTunnel: PBWTunnel) of object;
  //�¼�����

  TBasisWeightManager = class(TObject)
  private
    FTunnelManager: TPoundTunnelManager;
    FTunnels: TList;
    //ͨ���б�
    FWorker: TBasisWeightWorker;
    //ɨ�����
    FChangeProc: TBWStatusChange;
    FchangeEvent: TBWStatusChangeEvent;
    //�¼�����
    FSyncLock: TCriticalSection;
    //ͬ������
  protected
    procedure ClearTunnels(const nFree: Boolean);
    //����ͨ��
    procedure OnTunnelData(const nValue: Double; const nPort: PPTPortItem);
    //ͨ������
    procedure InitTunnelData(const nTunnel: PBWTunnel; nSimpleOnly: Boolean);
    //��ʼ��
    function FindTunnel(const nTunnel: string; nLoged: Boolean): Integer;
    //����ͨ��
    procedure DoChangeEvent(const nTunnel: PBWTunnel; nNewStatus: TBWStatus);
    //��Ӧ�¼�
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    procedure LoadConfig(const nFile: string);
    //��ȡ����
    procedure StartService;
    procedure StopService;
    //��ͣ����
    function IsTunnelBusy(const nTunnel: string): Boolean;
    //ͨ��æ
    procedure StartWeight(const nTunnel,nBill: string; const nValue: Double;
     const nHasVal: Double = 0; const nParams: string = '');
    procedure StopWeight(const nTunnel: string);
    //��ͣ����
    property OnStatusChange: TBWStatusChange read FChangeProc write FChangeProc;
    property OnStatusEvent: TBWStatusChangeEvent read FchangeEvent write FchangeEvent;
    //�������
  end;

var
  gBasisWeightManager: TBasisWeightManager = nil;
  //ȫ��ʹ��

implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TBasisWeightManager, '����װ������', nEvent);
end;

constructor TBasisWeightManager.Create;
begin
  FWorker := nil;
  FTunnels := TList.Create;
  FSyncLock := TCriticalSection.Create;

  FTunnelManager := TPoundTunnelManager.Create;
  FTunnelManager.OnData := OnTunnelData;
end;

destructor TBasisWeightManager.Destroy;
begin
  if Assigned(FWorker) then
  begin
    FWorker.StopMe;
    FWorker := nil;
  end;

  ClearTunnels(True);
  FreeAndNil(FTunnelManager);
  FreeAndNil(FSyncLock);
  inherited;
end;

procedure TBasisWeightManager.ClearTunnels(const nFree: Boolean);
var nIdx: Integer;
    nTunnel: PBWTunnel;
begin
  for nIdx:=FTunnels.Count-1 downto 0 do
  begin
    nTunnel := FTunnels[nIdx];
    FreeAndNil(nTunnel.FParams);

    Dispose(nTunnel);
    FTunnels.Delete(nIdx);
  end;

  if nFree then
    FreeAndNil(FTunnels);
  //xxxxx
end;

procedure TBasisWeightManager.DoChangeEvent(const nTunnel: PBWTunnel;
 nNewStatus: TBWStatus);
begin
  try
    nTunnel.FStatusNew := nNewStatus;
    if Assigned(FChangeProc) then FChangeProc(nTunnel);
    if Assigned(FChangeEvent) then FchangeEvent(nTunnel);
  except
    on nErr: Exception do
    begin
      WriteLog(nErr.Message);
    end;
  end;

  nTunnel.FStatusNow := nNewStatus;
  //apply status
end;

procedure TBasisWeightManager.StartService;
var nIdx: Integer;
begin
  if FTunnels.Count < 1 then
    raise Exception.Create('TBasisWeightManager Need LoadConfig() First.');
  //xxxxx

  if not Assigned(FWorker) then
    FWorker := TBasisWeightWorker.Create(Self);
  //xxxxx

  for nIdx:=FTunnels.Count-1 downto 0 do
    FTunnelManager.ActivePort(PBWTunnel(FTunnels[nIdx]).FID, nil, True);
  //�����˿�
end;

procedure TBasisWeightManager.StopService;
var nIdx: Integer;
begin
  if Assigned(FWorker) then
  begin
    FWorker.StopMe;
    FWorker := nil;
  end;

  for nIdx:=FTunnels.Count-1 downto 0 do
    FTunnelManager.ClosePort(PBWTunnel(FTunnels[nIdx]).FID);
  //�����˿�
end;

//Desc: ��ʼ��ͨ������
procedure TBasisWeightManager.InitTunnelData(const nTunnel: PBWTunnel;
 nSimpleOnly: Boolean);
var nIdx: Integer;
begin
  if not nSimpleOnly then
  begin
    nTunnel.FBill := '';
    nTunnel.FParams.Clear;
    nTunnel.FStableDone := False;
    nTunnel.FWeightOver := False;
    nTunnel.FWeightDone := False;

    nTunnel.FValue := 0;
    nTunnel.FValHas := 0;
    nTunnel.FValMax := 0;
    nTunnel.FValTunnel := 0;
    nTunnel.FValUpdate := GetTickCount;

    nTunnel.FValFresh := 0;
    nTunnel.FInitFresh := 0;
    nTunnel.FInitWeight := GetTickCount;
  end;

  for nIdx:=Low(nTunnel.FValSamples) to High(nTunnel.FValSamples) do
    nTunnel.FValSamples[nIdx] := 0;
  nTunnel.FSampleIndex := 0;
end;

//Date: 2018-12-27
//Parm: ͨ����;��¼��־
//Desc: ����nTunnel����
function TBasisWeightManager.FindTunnel(const nTunnel: string;
 nLoged: Boolean): Integer;
var nIdx: Integer;
begin
  Result := -1;
  //default
  
  for nIdx:=FTunnels.Count-1 downto 0 do
  if CompareText(nTunnel, PBWTunnel(FTunnels[nIdx]).FID) = 0 then
  begin
    Result := nIdx;
    Break;
  end;

  if (Result < 0) and nLoged then
    WriteLog(Format('ͨ��[ %s ]������.', [nTunnel]));
  //xxxxx
end;

//Date: 2018-12-27
//Parm: ͨ����
//Desc: �ж�nTunnel�Ƿ����
function TBasisWeightManager.IsTunnelBusy(const nTunnel: string): Boolean;
var nIdx: Integer;
    nPT: PBWTunnel;
begin
  Result := False;
  nIdx := FindTunnel(nTunnel, True);
  if nIdx < 0 then Exit;

  FSyncLock.Enter;
  try
    nPT := FTunnels[nIdx];
    Result := (nPT.FBill <> '') and
              (nPT.FValue > 0) and (nPT.FValue < nPT.FValHas);
    //δװ��
  finally
    FSyncLock.Leave;
  end;   
end;

//Date: 2018-12-27
//Parm: ͨ����;������;Ӧװ;��װ;����
//Desc: �����µĳ���ҵ��
procedure TBasisWeightManager.StartWeight(const nTunnel, nBill: string;
  const nValue, nHasVal: Double; const nParams: string);
var nIdx: Integer;
    nPT: PBWTunnel;
begin
  nIdx := FindTunnel(nTunnel, True);
  if nIdx < 0 then Exit;

  FSyncLock.Enter;
  try
    nPT := FTunnels[nIdx];
    if nPT.FBill <> nBill then
    begin
      InitTunnelData(nPT, False);
      nPT.FBill := nBill;
      nPT.FValue := nValue;
      nPT.FWeightMax := nValue + nPT.FValAdjust - nValue * nPT.FValPercent;
    end;

    if nParams <> '' then
      SplitStr(nParams, nPT.FParams, 0, ';');
    DoChangeEvent(nPT, bsNew);
  finally
    FSyncLock.Leave;
  end;
end;

//Date: 2018-12-27
//Parm: ͨ����
//Desc: ֹͣ����ҵ��
procedure TBasisWeightManager.StopWeight(const nTunnel: string);
var nIdx: Integer;
begin
  nIdx := FindTunnel(nTunnel, True);
  if nIdx < 0 then Exit;

  FSyncLock.Enter;
  try
    InitTunnelData(FTunnels[nIdx], False);
    DoChangeEvent(FTunnels[nIdx], bsClose);
  finally
    FSyncLock.Leave;
  end;
end;

procedure TBasisWeightManager.LoadConfig(const nFile: string);
var nStr: string;
    nIdx: Integer;
    nTunnel: PBWTunnel;
begin
  if FTunnels.Count > 0 then
    ClearTunnels(False);
  FTunnelManager.LoadConfig(nFile);

  for nIdx:=FTunnelManager.Tunnels.Count-1 downto 0 do
  begin
    New(nTunnel);
    FTunnels.Add(nTunnel);
    nTunnel.FTunnel := FTunnelManager.Tunnels[nIdx];
    
    nTunnel.FID := nTunnel.FTunnel.FID;
    nTunnel.FParams := TStringList.Create;
    SetLength(nTunnel.FValSamples, nTunnel.FTunnel.FSampleNum);

    if Assigned(nTunnel.FTunnel.FOptions) then
    begin
      nStr := nTunnel.FTunnel.FOptions.Values['NoDataTimeOut'];
      if IsNumber(nStr, False) then
           nTunnel.FTONoData := StrToInt(nStr) * 1000
      else nTunnel.FTONoData := 10 * 1000;

      nStr := nTunnel.FTunnel.FOptions.Values['EmptyIdleLong'];
      if IsNumber(nStr, False) then
           nTunnel.FTONoWeight := StrToInt(nStr) * 1000
      else nTunnel.FTONoWeight := 60 * 1000;

      nStr := nTunnel.FTunnel.FOptions.Values['ProceFresh'];
      if IsNumber(nStr, False) then
           nTunnel.FTOProceFresh := StrToInt(nStr) * 1000
      else nTunnel.FTOProceFresh := 1 * 1000;

      nStr := nTunnel.FTunnel.FOptions.Values['PreKd'];
      if IsNumber(nStr, True) then
           nTunnel.FValPercent := StrToFloat(nStr)
      else nTunnel.FValPercent := 0;

      nStr := nTunnel.FTunnel.FOptions.Values['PreKdFix'];
      if IsNumber(nStr, True) then
           nTunnel.FValAdjust := StrToFloat(nStr)
      else nTunnel.FValAdjust := 0;
    end;

    InitTunnelData(nTunnel, False);
    nTunnel.FStatusNow := bsInit;
    DoChangeEvent(nTunnel, bsInit);
  end;
end;

//Date: 2018-12-26
//Parm: ͨ��ֵ;ͨ���˿�
//Desc: ������nPort������������
procedure TBasisWeightManager.OnTunnelData(const nValue: Double;
  const nPort: PPTPortItem);
var nIdx: Integer;
    nTunnel: PBWTunnel;
begin
  FSyncLock.Enter;
  try
    for nIdx:=FTunnels.Count-1 downto 0 do
    begin
      nTunnel := FTunnels[nIdx];
      if nTunnel.FTunnel <> nPort.FEventTunnel then Continue;
      nTunnel.FValUpdate := GetTickCount;

      if (nPort.FMinValue > 0) and (nValue <= nPort.FMinValue) then
           nTunnel.FValTunnel := 0
      else nTunnel.FValTunnel := nValue;

      if nTunnel.FValTunnel > nTunnel.FValMax then
        nTunnel.FValMax := nTunnel.FValTunnel;
      Break;
    end;
  finally
    FSyncLock.Leave;
  end;
end;

//------------------------------------------------------------------------------
constructor TBasisWeightWorker.Create(AOwner: TBasisWeightManager);
begin
  inherited Create(False);
  FreeOnTerminate := False;

  FOwner := AOwner;
  FWaiter := TWaitObject.Create;
  FWaiter.Interval := 200;
end;

destructor TBasisWeightWorker.Destroy;
begin
  FWaiter.Free;
  inherited;
end;

procedure TBasisWeightWorker.StopMe;
begin
  Terminate;
  FWaiter.Wakeup;

  WaitFor;
  Free;
end;

procedure TBasisWeightWorker.WakupMe;
begin
  FWaiter.Wakeup;
end;

procedure TBasisWeightWorker.Execute;
var nIdx: Integer;
    nItv: Int64;
begin
  while not Terminated do
  try
    FWaiter.EnterWait;
    if Terminated then Exit;

    for nIdx:=FOwner.FTunnels.Count-1 downto 0 do
    try
      FOwner.FSyncLock.Enter;
      FActive := FOwner.FTunnels[nIdx];
      if (FActive.FBill = '') or (FActive.FValue <= 0) then Continue; //��ҵ��

      nItv := GetTickCount - FActive.FInitFresh;
      if nItv >= FActive.FTOProceFresh then
      begin
        if FActive.FValFresh <> FActive.FValTunnel then
        begin
          if (FActive.FValFresh = 0) and (FActive.FValTunnel > 0) then
               FOwner.DoChangeEvent(FActive, bsStart)
          else FOwner.DoChangeEvent(FActive, bsProcess);

          FActive.FValFresh := FActive.FValTunnel;
        end;

        FActive.FInitFresh := GetTickCount;
        //ˢ���Ǳ���ֵ
      end;

      nItv := GetTickCount - FActive.FInitWeight;
      if (FActive.FValMax <= 0) and (nItv >= FActive.FTONoWeight) then
      begin
        FOwner.DoChangeEvent(FActive, bsClose);
        FOwner.InitTunnelData(FActive, False);

        WriteLog(Format('ͨ��[ %s.%s ]ҵ��ʱ,���˳�.', [
          FActive.FID, FActive.FTunnel.FName]));
        Continue;
      end;
      
      nItv := GetTickCount - FActive.FValUpdate;
      if nItv >= FActive.FTONoData then //�ذ�����
      begin
        FOwner.DoChangeEvent(FActive, bsClose);
        FOwner.InitTunnelData(FActive, False);

        WriteLog(Format('ͨ��[ %s.%s ]����,������Ӧ��.', [
          FActive.FID, FActive.FTunnel.FName]));
        Continue;
      end;

      if (nItv >= 3200) or (nItv < 300) then Continue;
      //���³�ʱ �� ���¹�Ƶ

      DoBasisWeight;
      if Terminated then Break;
    finally
      FOwner.FSyncLock.Leave;
    end;
  except
    on E: Exception do
    begin
      WriteLog(E.Message);
      Sleep(500);
    end;
  end;
end;

//Date: 2018-12-27
//Parm: �Ƿ���֤��Сֵ
//Desc: ��֤�����Ƿ��ȶ�
function TBasisWeightWorker.IsValidSamaple(const nCheckMin: Boolean): Boolean;
var nIdx: Integer;
    nVal: Integer;
begin
  Result := False;
  //default

  for nIdx:=High(FActive.FValSamples) downto 1 do
  begin
    if nCheckMin and (FActive.FValSamples[nIdx] < 0.02) then Exit;
    //����������

    nVal := Trunc(FActive.FValSamples[nIdx] * 1000 -
                  FActive.FValSamples[nIdx-1] * 1000);
    if Abs(nVal) >= FActive.FTunnel.FSampleFloat then Exit; //����ֵ����
  end;
  
  Result := True;
end;

procedure TBasisWeightWorker.DoBasisWeight;
begin
  if (not FActive.FWeightDone) and
     (FActive.FValTunnel >= FActive.FWeightMax) then //δװ�����
  begin
    FActive.FWeightDone := True;
    FOwner.DoChangeEvent(FActive, bsDone);
  end; 

  FActive.FValSamples[FActive.FSampleIndex] := FActive.FValTunnel;
  Inc(FActive.FSampleIndex);

  if FActive.FSampleIndex >= FActive.FTunnel.FSampleNum then
    FActive.FSampleIndex := Low(FActive.FValSamples);
  //ѭ������

  if FActive.FStableDone then
    FActive.FStableDone := FActive.FValHas = FActive.FValTunnel;
  //ƽ�����ݱ��

  if not FActive.FStableDone then
  begin
    {**************************** FActive.FStableDone **************************
    ���λ�÷�:
     1.���������,��ͨ������FValTunnelû�仯,��DoChangeEventֻ����һ��.
     2.��DoChangeEvent����ĳЩԭ��,�����դ�ж�ʧ��,����Ҫ�ٴδ���ҵ��,���ֶ�
       ����FStableDone=False.
    ***************************************************************************}

    if IsValidSamaple(True) then //��Ч����ƽ��
    begin
      FActive.FStableDone := True;
      FActive.FValHas := FActive.FValTunnel;

      if not FActive.FWeightOver then //δ��ɱ���
      begin
        FOwner.DoChangeEvent(FActive, bsStable);
        if not FActive.FStableDone then
          FOwner.InitTunnelData(FActive, True);
        //reset simples

        if FActive.FStableDone and FActive.FWeightDone then
          FActive.FWeightOver := True;
        //װ������ҳɹ�����
      end;
    end;

    if (FActive.FValTunnel = 0) and
       (FActive.FValMax > 0) and IsValidSamaple(False) then //װ���°�
    begin
      if not FActive.FWeightOver then //δ����ƽ������
      begin
        FActive.FValHas := FActive.FValMax;
        FOwner.DoChangeEvent(FActive, bsStable);
      end;

      FActive.FStableDone := True;
      FOwner.DoChangeEvent(FActive, bsClose); //�ر�ҵ��
      FOwner.InitTunnelData(FActive, False);

      WriteLog(Format('ͨ��[ %s.%s ]�������°�.', [
        FActive.FID, FActive.FTunnel.FName]));
      //xxxxx
    end;
  end;
end;

initialization
  gBasisWeightManager := nil;
finalization
  FreeAndNil(gBasisWeightManager);
end.