{*******************************************************************************
  ����: dmzn@163.com 2019-01-02
  ����: �����������
*******************************************************************************}
unit UFunctions;

interface

uses
  Windows, Classes, SysUtils, USysLoger, UMgrTTCEDispenser;

function dispenser_init(nFile: PChar; nDir: PChar): Boolean; stdcall;
procedure dispenser_free; stdcall;
//��ʼ��
procedure dispenser_start; stdcall;
procedure dispenser_stop; stdcall;
//��ͣ����
function dispenser_getcard(nID,nCard: PChar; const nWaitFor: Boolean = True;
  const nTimeout: Integer = cDispenser_Wait_Timeout): Boolean; stdcall;
//��ȡ����
procedure dispenser_sendout(nID: PChar); stdcall;
//����
procedure dispenser_recovery(nID: PChar); stdcall;
//�տ�

implementation

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TDispenserManager, '��������������', nEvent);
end;

//Date: 2019-01-02
//Parm: �����ļ�;��־·��
//Desc: ��ʼ����������
function dispenser_init(nFile: PChar; nDir: PChar): Boolean;
begin
  Result := False;
  try
    if not Assigned(gSysLoger) then
      gSysLoger := TSysLoger.Create(nDir);
    gSysLoger.LogSync := False;

    if not Assigned(gDispenserManager) then
      gDispenserManager := TDispenserManager.Create;
    gDispenserManager.LoadConfig(nFile);
    Result := True;
  except
    on nErr: Exception do
    begin
      WriteLog(nErr.Message);
    end;
  end;
end;

//Date: 2019-01-02
//Desc: �ͷ�����
procedure dispenser_free;
begin
  FreeAndNil(gDispenserManager);
  FreeAndNil(gSysLoger);
end;

//Date: 2019-01-02
//Desc: ����
procedure dispenser_start; stdcall;
begin
  gDispenserManager.StartDispensers;
end;

//Date: 2019-01-02
//Desc: ֹͣ
procedure dispenser_stop; stdcall;
begin
  gDispenserManager.StopDispensers;
end;

//Date: 2019-01-02
//Parm: �豸��;�Ƿ�ȴ�;��ʱʱ��
//Desc: ��ȡnID��ǰ�Ŀ���
function dispenser_getcard(nID,nCard: PChar; const nWaitFor: Boolean;
  const nTimeout: Integer): Boolean;
var nStr,nData: string;
begin
  nData := gDispenserManager.GetCardNo(nID, nStr, nWaitFor, nTimeout);
  Result := nData <> '';

  if Result then
    StrPCopy(nCard, nData);
  if nStr <> '' then WriteLog(nStr);
end;

//Date: 2019-01-02
//Parm: �豸��
//Desc: nIDִ�з���
procedure dispenser_sendout(nID: PChar); stdcall;
var nStr: string;
begin
  gDispenserManager.SendCardOut(nID, nStr);
  if nStr <> '' then WriteLog(nStr);
end;

//Date: 2019-01-02
//Parm: �豸��
//Desc: nIDִ���տ�
procedure dispenser_recovery(nID: PChar);
var nStr: string;
begin
  gDispenserManager.RecoveryCard(nID, nStr);
  if nStr <> '' then WriteLog(nStr);
end;

end.
