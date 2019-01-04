{*******************************************************************************
  ����: dmzn@163.com 2019-01-02
  ����: ��������������
*******************************************************************************}
library Dispenser;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

uses
  Windows,
  Forms,
  UFunctions in 'UFunctions.pas';

{$R *.res}

exports
  dispenser_init, dispenser_free, dispenser_start, dispenser_stop,
  dispenser_getcard, dispenser_sendout, dispenser_recovery;

var
  gProc: TDllProc;
  //�ص�����
  gScr: TScreen;
  //ȫ����Ļ����
  gApp: TApplication;
  //ȫ�ֹ��̶���

//Desc: ��ԭ
procedure LibraryProc(const Reason: Integer);
begin
  if Reason = DLL_PROCESS_DETACH then
  begin
    Screen := gScr;
    Application := gApp;
    DllProc := gProc;
  end;
end;

begin
  gProc := DllProc;
  gScr := Screen;
  gApp := Application;
  DllProc := @LibraryProc;
end.
