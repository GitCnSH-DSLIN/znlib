{*******************************************************************************
  ����: dmzn@163.com 2018-05-03
  ����: ҵ��������ݷ�װ��
*******************************************************************************}
unit UBusinessPacker;

interface

uses
  Windows, Classes, SyncObjs, SysUtils, UBase64, ULibFun;

type
  PBWWorkerInfo = ^TBWWorkerInfo;
  TBWWorkerInfo = record
    FUser   : string;              //������
    FIP     : string;              //IP��ַ
    FMAC    : string;              //������ʶ
    FTime   : TDateTime;           //����ʱ��
    FKpLong : Int64;               //����ʱ��
  end;

  TBWWorkerInfoType = (itFrom, itVia, itFinal);
  //��Ϣ����

  PBWDataBase = ^TBWDataBase;
  TBWDataBase = record
    FWorker   : string;            //��װ��
    FFrom     : TBWWorkerInfo;     //Դ
    FVia      : TBWWorkerInfo;     //����
    FFinal    : TBWWorkerInfo;     //����

    FMsgNO    : string;            //��Ϣ��
    FKey      : string;            //��¼���
    FParam    : string;            //��չ����

    FResult   : Boolean;           //ִ�н��
    FErrCode  : string;            //�������
    FErrDesc  : string;            //��������
  end;

  TBusinessPackerBase = class(TObject)
  protected
    FEnabled: Boolean;
    //���ñ��
    FStrBuilder: TStrings;
    //�ַ�������
    FCodeEnable: Boolean;
    //���ñ���
    procedure DoInitIn(const nData: Pointer); virtual;
    procedure DoInitOut(const nData: Pointer); virtual;
    procedure DoPackIn(const nData: Pointer); virtual;
    procedure DoUnPackIn(const nData: Pointer); virtual;
    procedure DoPackOut(const nData: Pointer); virtual;
    procedure DoUnPackOut(const nData: Pointer); virtual;
    //����ʵ��
    function PackerEncode(const nStr: string): string; overload;
    function PackerEncode(const nDT: TDateTime): string; overload;
    function PackerEncode(const nVal: Boolean): string; overload;
    procedure PackerDecode(const nStr: string; var nValue: string); overload;
    procedure PackerDecode(const nStr: string; var nValue: Boolean); overload;
    procedure PackerDecode(const nStr: string; var nValue: Integer); overload;
    procedure PackerDecode(const nStr: string; var nValue: Cardinal); overload;
    procedure PackerDecode(const nStr: string; var nValue: Int64); overload;
    procedure PackerDecode(const nStr: string; var nValue: Double); overload;
    procedure PackerDecode(const nStr: string; var nValue: TDateTime); overload;
    //�������
    procedure PackWorkerInfo(const nBuilder: TStrings; var nInfo: TBWWorkerInfo;
      const nPrefix: string; const nEncode: Boolean = True);
    //���������
  public
    constructor Create;
    destructor Destroy; override;
    //�����ͷ�
    class function PackerName: string; virtual;
    //������
    procedure InitData(const nData: Pointer; const nIn: Boolean;
      const nSub: Boolean = True; const nBase: Boolean = True);
    //��ʼ��
    function PackIn(const nData: Pointer; nCode: Boolean = True): string;
    procedure UnPackIn(const nStr: string; const nData: Pointer;
      nCode: Boolean = True);
    //��δ���
    function PackOut(const nData: Pointer; nCode: Boolean = True): string;
    procedure UnPackOut(const nStr: string; const nData: Pointer;
      nCode: Boolean = True);
    //���δ���
    property StrBuilder: TStrings read FStrBuilder;
    //�������
  end;

function PackerEncodeStr(const nStr: string): string;
function PackerDecodeStr(const nStr: string): string;
//�ַ�����

implementation

function PackerEncodeStr(const nStr: string): string;
begin
  Result := EncodeBase64(nStr);
end;

function PackerDecodeStr(const nStr: string): string;
begin
  Result := DecodeBase64(nStr);
end;

//------------------------------------------------------------------------------
constructor TBusinessPackerBase.Create;
begin
  FEnabled := True;
  FStrBuilder := TStringList.Create;
end;

destructor TBusinessPackerBase.Destroy;
begin
  FStrBuilder.Free;
  inherited;
end;

class function TBusinessPackerBase.PackerName: string;
begin
  Result := '';
end;

//Date: 2012-3-14
//Parm: ����;���;����;����
//Desc: �������ʼ��nData����
procedure TBusinessPackerBase.InitData(const nData: Pointer;
 const nIn,nSub,nBase: Boolean);
var nBW: TBWDataBase;
begin
  if nBase then
  begin
    FillChar(nBW, SizeOf(nBW), #0);
    nBW.FMsgNO := PBWDataBase(nData).FMsgNO;
    nBW.FKey := PBWDataBase(nData).FKey;
    PBWDataBase(nData)^ := nBW;

    with PBWDataBase(nData)^ do
    begin
      FFrom.FTime := Now;
      FVia.FTime := Now;
      FFinal.FTime := Now;
      FResult := False;
    end;
  end;

  if nSub then
  begin
    if nIn then
         DoInitIn(nData)
    else DoInitOut(nData);
  end;
end;

//Date: 2012-3-7
//Parm: ��������;�Ƿ����
//Desc: ����������nData�������
function TBusinessPackerBase.PackIn(const nData: Pointer; nCode: Boolean): string;
begin
  FStrBuilder.Clear;
  FCodeEnable := nCode;

  DoPackIn(nData);
  Result := FStrBuilder.Text;
end;

//Date: 2012-3-7
//Parm: �ַ�����;����
//Desc: ��nStr�������
procedure TBusinessPackerBase.UnPackIn(const nStr: string; const nData: Pointer;
  nCode: Boolean);
begin
  FStrBuilder.Text := nStr;
  FCodeEnable := nCode;
  DoUnPackIn(nData);
end;

//Date: 2012-3-7
//Parm: �ṹ����;�Ƿ����
//Desc: �Խṹ����nData�������
function TBusinessPackerBase.PackOut(const nData: Pointer; nCode: Boolean): string;
begin
  FStrBuilder.Clear;
  FCodeEnable := nCode;

  DoPackOut(nData);
  Result := FStrBuilder.Text;
end;

//Date: 2012-3-7
//Parm: �ַ�����
//Desc: ��nStr�������
procedure TBusinessPackerBase.UnPackOut(const nStr: string;
 const nData: Pointer; nCode: Boolean);
begin
  FStrBuilder.Text := nStr;
  FCodeEnable := nCode;
  DoUnPackOut(nData);
end;

//Date: 2012-3-7
//Parm: ������;��Ϣ;ǰ׺;�Ƿ����
//Desc: ����nInfo����Ϣ
procedure TBusinessPackerBase.PackWorkerInfo(const nBuilder: TStrings;
  var nInfo: TBWWorkerInfo; const nPrefix: string; const nEncode: Boolean);
begin
  with nBuilder,nInfo do
  begin
    if nEncode  then
    begin
      Values[nPrefix + '_User']    := PackerEncode(FUser);
      Values[nPrefix + '_MAC']     := PackerEncode(FMAC);
      Values[nPrefix + '_IP']      := PackerEncode(FIP);
      Values[nPrefix + '_Time']    := PackerEncode(FTime);
      Values[nPrefix + '_KpLong']  := IntToStr(FKpLong);
    end else
    begin
      PackerDecode(Values[nPrefix + '_User'], FUser);
      PackerDecode(Values[nPrefix + '_IP'], FIP);
      PackerDecode(Values[nPrefix + '_MAC'], FMAC);
      PackerDecode(Values[nPrefix + '_Time'], FTime);
      PackerDecode(Values[nPrefix + '_KpLong'], FKpLong);
    end;
  end;
end;

//------------------------------------------------------------------------------
//Desc: ��nStr����
function TBusinessPackerBase.PackerEncode(const nStr: string): string;
begin
  if FCodeEnable then
       Result := PackerEncodeStr(nStr)
  else Result := nStr;
end;

//Desc: ������
function TBusinessPackerBase.PackerEncode(const nDT: TDateTime): string;
begin
  with TDateTimeHelper do
  try
    Result := DateTime2Str(nDT);
  except
    Result := DateTime2Str(Now);
  end;
end;

//Desc: ������
function TBusinessPackerBase.PackerEncode(const nVal: Boolean): string;
begin
  if nVal then
       Result := 'Y'
  else Result := 'N';
end;

//Desc: �ַ���
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: string);
begin
  if nStr = '' then
  begin
    nValue := '';
  end else

  if FCodeEnable then
       nValue := PackerDecodeStr(nStr)
  else nValue := nStr;
end;

//Desc: ������
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: Boolean);
begin
  nValue := nStr = 'Y';
end;

//Desc: �з�������
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: Integer); 
begin
  if nStr = '' then
       nValue := 0
  else nValue := StrToInt(nStr)
end;

//Desc: �޷�������
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: Cardinal);
begin
  if nStr = '' then
       nValue := 0
  else nValue := StrToInt(nStr)
end;

//Desc: 64��������
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: Int64);
begin
  if nStr = '' then
       nValue := 0
  else nValue := StrToIntDef(nStr, 0)
end;

//Desc: ������
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: Double);
begin
  if nStr = '' then
       nValue := 0
  else nValue := StrToFloat(nStr);
end;

//Desc: ����
procedure TBusinessPackerBase.PackerDecode(const nStr: string;
 var nValue: TDateTime);
begin
  with TDateTimeHelper do
  begin
    if nStr = '' then
         nValue := 0
    else nValue := Str2DateTime(nStr);
  end;
end;

//------------------------------------------------------------------------------  
procedure TBusinessPackerBase.DoInitIn(const nData: Pointer);
begin

end;

procedure TBusinessPackerBase.DoInitOut(const nData: Pointer);
begin

end;

procedure TBusinessPackerBase.DoPackIn(const nData: Pointer);
begin

end;

procedure TBusinessPackerBase.DoPackOut(const nData: Pointer);
begin

end;

procedure TBusinessPackerBase.DoUnPackIn(const nData: Pointer);
begin

end;

procedure TBusinessPackerBase.DoUnPackOut(const nData: Pointer);
begin

end;

end.


