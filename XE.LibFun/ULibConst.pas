{*******************************************************************************
  ����: dmzn@163.com 2019-07-01
  ����: ͨ�ú����⹫������
*******************************************************************************}
unit ULibConst;

{$I LibFun.Inc}
interface

uses
  System.Classes, System.SysUtils;

//------------------------------------------------------------------------------
//*** ���¶�������: Vcl.PostMsg,FMX.PostMsg
const
  cMessageBufferMax = 100;
  //max buffer record

type
  TMessageHandle = procedure (nSender: TObject; nMsg: Integer;
    nWParam,nLParam: NativeInt) of object;
  TMessageHandleRef = reference to procedure (nSender: TObject; nMsg: Integer;
    nWParam,nLParam: NativeInt);
  //call back function

  PMessageItem = ^TMessageItem;
  TMessageItem = record
    FEnabled   : Boolean;                              //��Ч��ʶ
    FLastUsed  : Cardinal;                             //����ʱ��
    FHandle    : TMessageHandle;                       //��Ϣ�¼�
    FHandleRef : TMessageHandleRef;                    //�����¼�

    FSender    : TObject;                              //����
    FMsg       : Integer;                              //��Ϣ��
    FWParam    : NativeInt;
    FLParam    : NativeInt;                            //�ߵͲ���

    FIsFirst   : Boolean;                              //�Ƿ�����
    FNextItem  : Integer;                              //��������
  end;
  TMessageItems = array of TMessageItem;

implementation

end.
