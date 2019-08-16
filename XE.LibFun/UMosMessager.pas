{*******************************************************************************
  ����: dmzn@163.com 2019-08-15
  ����: ����mosquitto����Ϣ����

  ��ע:
  *.MQTT������ʹ��·����ʽ����: Root/Path1/Path2/Path3/Path4...
    һ��Root:Broker����,��: TXYun37,ָ��������Ѷ����IPĩλ��37�ķ�����.
    ����Path:Ӧ������,��: Delivery,ָ��������ϵͳ
    ����Path:Ӧ��ʵ������,��:HuaXin_YX,ָ���¼������¹���
    �ļ�Path:Ӧ�ö����ʶ,��:TMgrOPC,ָOPC�������.
    �弶Path:��������,��:Info,Error,Warn��
    �����弶·��Ϊ��Ҫ·��,�����ѡ,·���������1024�ֽ�.
*******************************************************************************}
unit UMosMessager;

{$I LibFun.Inc}
interface

uses
  System.Classes, System.SysUtils, UMosMQTT, UBaseObject;

type
  TMsgType = (mtInfo, mtWarn, mtError, mtEvent, mtIRC, mtCmd, mtWaitCmd);
  //��Ϣ����: ��Ϣ;����;����;�¼�;��ʱͨѶ;����;����ȴ����
  TMsgTypes = set of TMsgType;

const
  sMsgType: array[0..6] of string = ('Info', 'Warn', 'Error', 'Event', 'IRC',
    'Command', 'CmdWait');
  //��Ϣ��������

type
  PMsgPath = ^TMsgPath;
  TMsgPath = record
    FServer    : string;                  //����������
    FAppName   : string;                  //Ӧ������
    FInstance  : string;                  //ʵ������
    FObject    : string;                  //�����ʶ
    FType      : TMsgType;                //��Ϣ����
    FExtend    : string;                  //��չ·��
  end;

  PMsgData = ^TMsgData;
  TMsgData = record
    FPath      : TMsgPath;                //��Ϣ·��
    FData      : string;                  //��Ϣ����
  end;

  TMQTTMessager = class(TManagerBase)
  private
    FChannel: TMQTTClient;
    {*��Ϣͨ��*}
    FDefaultPath: TMsgPath;
    {*Ĭ��·��*}
  protected
    procedure DoRecvMessage(const nTopic,nPayload: string);
    {*������Ϣ*}
  public
    constructor Create;
    destructor Destroy; override;
    {*�����ͷ�*}
    class procedure RegistMe(const nReg: Boolean); override;
    {*ע�����*}
    procedure RunAfterRegistAllManager; override;
    procedure RunBeforUnregistAllManager; override;
    {*�ӳ�ִ��*}
    procedure InitPath(const nServer,nAppName,nInstance: string);
    {*����·��*}
    property Channel: TMQTTClient read FChannel;
    property DefaultPath: TMsgPath read FDefaultPath;
    {*�������*}
  end;

var
  gMQTTMessager: TMQTTMessager = nil;
  //ȫ��ʹ��

implementation

uses
  UManagerGroup, ULibFun;

constructor TMQTTMessager.Create;
begin
  FChannel := nil;
  InitPath('Moquitto', 'Delivery', 'Factory');
end;

destructor TMQTTMessager.Destroy;
begin
  //xxx
  inherited;
end;

//Date: 2019-08-15
//Parm: �Ƿ�ע��
//Desc: ��ϵͳע�����������
class procedure TMQTTMessager.RegistMe(const nReg: Boolean);
var nIdx: Integer;
begin
  nIdx := GetMe(TMQTTMessager);
  if nReg then
  begin
    if not Assigned(gMG.FManagers[nIdx].FManager) then
      gMG.FManagers[nIdx].FManager := TMQTTMessager.Create;
    gMG.FMessageCenter := gMG.FManagers[nIdx].FManager as TMQTTMessager;
  end else
  begin
    gMG.FMessageCenter := nil;
    FreeAndNil(gMG.FManagers[nIdx].FManager);
  end;
end;

procedure TMQTTMessager.RunAfterRegistAllManager;
begin
  FChannel := TMQTTClient.Create;
  with FChannel do
  begin
    EventMode := emThread;
    OnMessageEvent := DoRecvMessage;
  end;
end;

procedure TMQTTMessager.RunBeforUnregistAllManager;
begin
  FChannel.Free;
end;

//Date: 2019-08-15
//Parm: ����;Ӧ��;ʵ��
//Desc: ��ʼ��Ĭ��·��
procedure TMQTTMessager.InitPath(const nServer, nAppName, nInstance: string);
var nDef: TMsgPath;
begin
  FillChar(nDef, SizeOf(TMsgPath), #0);
  FDefaultPath := nDef;

  with FDefaultPath do
  begin
    FServer   := nServer;
    FAppName  := nAppName;
    FInstance := nInstance;
    FType     := mtInfo;
  end;
end;

procedure TMQTTMessager.DoRecvMessage(const nTopic, nPayload: string);
begin

end;

end.
