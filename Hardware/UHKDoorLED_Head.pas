{*******************************************************************************
  ����: dmzn@163.com 2019-06-11
  ����: �������Ÿ�LED������������ͷ�ļ�
*******************************************************************************}
unit UHKDoorLED_Head;

interface

const
  cVTDLL = 'vtLEDProtocol.DLL';

  //��ʾ����ɫ���Ͷ���
  VT_SIGNLE_COLOR             = 1; //��ɫ��ʾ��
  VT_DOUBLE_COLOR             = 2; //˫ɫ��ʾ�� ����ʾ �� �� �� ��ɫ
  VT_FULL_COLOR               = 3; //ȫ����ʾ�� ����ʾ 7 ��ɫ

  //������ʽ����
  VT_ACTION_HOLD              = $01; //��ֹ��ʾ/������ʾ/��ҳ��ʾ
  VT_ACTION_UP                = $1A; //�����ƶ�
  VT_ACTION_DOWN              = $1B; //�����ƶ�
  VT_ACTION_LEFT              = $1C; //�����ƶ�
  VT_ACTION_RIGHT             = $1D; //�����ƶ�
  VT_ACTION_CUP               = $1E; //���������ƶ�
  VT_ACTION_CDOWN             = $1F; //���������ƶ�
  VT_ACTION_CLEFT             = $20; //���������ƶ�
  VT_ACTION_CRIGHT            = $21; //���������ƶ�
  VT_ACTION_FLASH             = $29; //��˸
  
  //��ʾ��ɫ����
  VT_COLOR_RED                = $01; //��
  VT_COLOR_GREEN              = $02; //��
  VT_COLOR_YELLOW             = $04; //��(��+��)
  VT_COLOR_BLUE               = $08; //��
  VT_COLOR_Cyan               = $10; //��(��+��)
  VT_COLOR_Purple             = $20; //��(��+��)
  VT_COLOR_WHITE              = $40; //��(��+��+��)

  //��ʾ���嶨��
  VT_FONT_16                  = $10; //16 �������
  VT_FONT_24                  = $18; //24 �������
  VT_FONT_32                  = $20; //32 �������
  //ʱ�����Ͷ���
  VT_TIME_TYPE_CALENDAR       = $00; //����ʱ��
  VT_TIME_TYPE_COUNT_DOWN     = $01; //����ʱ

  //Сʱ���Ͷ���
  VT_HOUR_TYPE_24H            = $00; //24 Сʱ����
  VT_HOUR_TYPE_12H            = $01; //12 Сʱ����

  //ʱ������
  VT_TIMEZONE_TYPE_BEIJING    = $00; //����ʱ��
  VT_TIMEZONE_TYPE_E          = $01; //����
  VT_TIMEZONE_TYPE_W          = $02; //����

  //����״̬
  VT_PAR_OK                   = 0; //������ȷ
  VT_PAR_DEV_NOT_INIT_ERROR   = -1; //�豸����δ����
  VT_PAR_PROGRAM_ID_ERROR     = -2; //��Ŀ ID �Ŵ���
  VT_PAR_NO_PROGRAM_ERROR     = -3; //��Ŀδ��ʼ��
  VT_PAR_AREA_ID_ERROR        = -4; //���� ID �Ŵ���
  VT_PAR_AREA_ERROR           = -5; //�����������ô���
  VT_PAR_COLOR_ERROR          = -6; //��ɫ���ô���
  VT_PAR_ACTION_ERROR         = -7; //������ʽ���ô���
  VT_PAR_FONT_ERROR           = -8; //�������ô���
  VT_PAR_SOUND_ONLY_ERROR     = -9; //һ����Ŀ��ֻ�ܺ���һ������
  VT_PAR_DATA_SIZE_ERROR      = -10; //���ݳ������ô���
  VT_PAR_MEM_ERROR            = -11; //ϵͳ�������
  VT_PAR_FRAME_FLAG_ERROR     = -12; //Э������֡��־����
  VT_PAR_FRAME_SIZE_ERROR     = -13; //Э������֡���ȴ���
  VT_PAR_CMD_ERROR            = -14; //ָ�����
  
type
  vt_int8_t                   = ShortInt;
  vt_int16_t                  = Smallint;
  vt_int32_t                  = Integer;
  vt_uint8_t                  = Byte;
  vt_uint16_t                 = Word;
  vt_uint32_t                 = Longword;

  pvt_int8_t                  = ^ShortInt;
  pvt_int16_t                 = ^Smallint;
  pvt_int32_t                 = ^Integer;
  pvt_uint8_t                 = PChar;
  pvt_uint16_t                = ^Word;
  pvt_uint32_t                = ^Longword;

function vt_ProtocolAnalyze(pData: pvt_uint8_t; nSize: vt_uint32_t;
  pOut: pvt_uint8_t; pnLen: pvt_uint32_t): vt_int32_t; stdcall; external cVTDLL;
function vtInitialize(nWidth,nHeight: vt_uint16_t; nColor: vt_uint8_t;
  nCardType: vt_uint8_t): vt_int32_t; stdcall; external cVTDLL;
function vtUninitialize(): vt_int32_t; stdcall; external cVTDLL;

function vtAddProgram(nProgramID: vt_uint8_t): vt_int32_t; stdcall; external cVTDLL;
function vtGetProgramPack(nDeviceGUID: vt_uint8_t; nType: vt_uint8_t;
  pOut: pvt_uint8_t; pnLen: pvt_uint32_t): vt_int32_t; stdcall; external cVTDLL;
function vtAddTextAreaItem(nProgramID: vt_uint8_t; nAreaID: vt_uint8_t;
  nX,nY,nWidth,nHeight: vt_uint16_t; pText: pvt_uint8_t; nTextSize: vt_uint16_t;
  nTextColor,nStyle,nFontType,nShowSpeed,nStayTime: vt_uint8_t): vt_int32_t;
  stdcall; external cVTDLL;
function vtAddSoundItem(nProgramID: vt_uint8_t; nAreaID: vt_uint8_t;
  SoundPerson,SoundVolume,SoundSpeed: vt_uint8_t;
  pSoundText: pvt_uint8_t; sound_len: vt_uint16_t): vt_int32_t;
  stdcall; external cVTDLL;

//------------------------------------------------------------------------------
const
  cPlayDLL = 'ListenPlayDll.DLL';

function StartSend(): Integer; stdcall; external cPlayDLL;
{
���ܣ�
  ����ͨѶ�Ự
����ֵ��
  �Ự���,��ֵ�������������
}
function EndSend(nHandle: Integer): Integer; stdcall; external cPlayDLL;
{
���ܣ�
  ����ͨѶ�Ự
����ֵ��
  1���ɹ�
  2�����ɹ�
}
function SetTransMode(nHandle,nTransMode,nMark,nType,
  nMarkID: Integer): Integer; stdcall; external cPlayDLL;
{
���ܣ�
  ����ͨѶģʽ
������
  Handle:�Ự���,StartSend����ֵ
  TransMode:����ģʽ   1 ���ڴ��� 2 ���ڴ���
  mark:Ĭ����Ϊ0.�����rfͨѶ������1
  controlType���ͺš�2��Tϵ�У�3��E��Qϵ�п�
  Markid����������ֵ��
����ֵ��
1���ɹ�
0�����ɹ�
}
function SetNetworkPara(nHandle,nPNum: Integer;
  nIP: PWideChar): Integer; stdcall; external cPlayDLL;
{
���ܣ�
  �����������
����:
 Handle:�Ự���,StartSend����ֵ
  pno:����
  ip:������IP��ַ
����ֵ��
  1���ɹ�
  2�����ɹ�
}
function SendScreenPara(nHandle,nColor,nWidth,
  nHeight: Integer): Integer; stdcall; external cPlayDLL;
{
���ܣ�
  ������Ļ����
����:
 Handle:�Ự���,StartSend����ֵ
 nColor:��ɫ 1,��ɫ;2,˫ɫ
 nWidth,nHeight:���
����ֵ��
  1���ɹ�
  2�����ɹ�
}
function AddControl(nHandle,nPNum,nDBColor: Integer): Integer;
  stdcall; external cPlayDLL;
{
���ܣ������ʾ��
������
  Handle:  �Ự���,StartSend����ֵ
  Pno:����
  DBColor����˫ɫ(��ɫΪ1 ��˫ɫΪ2,����ɫ3)
����ֵ��
  1���ɹ�
  2����������
}
function AddProgram (nHandle,nJNum,nPlayTime: Integer): Integer;
  stdcall; external cPlayDLL;
{
���ܣ���ӽ�Ŀ
������
  Handle:  �Ự���,StartSend����ֵ
  jno����Ŀ��
  playTime����Ŀ����ʱ��
����ֵ��
  1���ɹ�
  2����������
}
function AddNeiMaTxtArea1(const nHandle,nJNum,nQNum,nLeft,nTop,nWidth,
  nHeight: Integer; nText: PWideChar; nShowStyle,nFontName,nFontColor,
  nPlayStyle,nQuitStyle,nPlayspeed,nTimes: Integer): Integer;
  stdcall; external cPlayDLL;
{
���ܣ������������
������
  handle��	���
  Pno:       ����
  jno��		��Ŀ�� (>=1)
  qno��		����� (>=1)
  left��		�������ϽǶ���x���꣺8�ı�������λ������
  top��		�������ϽǶ���y����
  width��		�����ȣ�8�ı�������λ������
  height��		����߶�
  Showtext   ���͵����ݣ���"��ӭ����"��
  ShowStyle  �����С��ȡֵΪ16��32��16��ʾ16����32��ʾ32��������ȡֵ��Ч��
  Fontname   ����������ȡֵΪ0��ʾ���壬����Ϊ��Чֵ)
  Fontcolor   ������ɫ(ȡֵΪ1��2��3��1--��ɫ��2--��ɫ��3--��ɫ)
  PlayStyle   �����ؼ�
  QuitStyle   �˳��ؼ�---Ĭ��ֵ255
  PlaySpeed  �����ٶȣ�ȡֵ1--255����ʾ�ȼ�����ֵԽ�ߣ��ٶ�Խ����
  Times      ͣ��ʱ�䣨ȡֵ1-255��
����ֵ��
  5.�ɹ�
  6.ʧ��
}
function AddLnTxtString(nHandle,nJNum,nQNum,nLeft,nTop,nWidth,nHeight: Integer;
  nText,nFontName: PWideChar; nFontSize,nFontColor,nBold,nItalic,nUnderline,
  nPlayStyle,nPlaySpeed,nTimes: Integer): Integer; stdcall; external cPlayDLL;
{
���ܣ�
  ��ӵ����ı���ʹ���ַ�����
������
  jno��		��Ŀ�� (>=1)
  qno��		����� (>=1)

  left��		�������ϽǶ���x���꣺8�ı�������λ������
  top��		�������ϽǶ���y����
  width��		�����ȣ�8�ı�������λ������
  height��		����߶�

  Fontname    ��������
  Fontsize     �����С
  Fontcolor    ������ɫ��255������ɫ��65280������ɫ��65535������ɫ);
  Bold        �Ƿ����
  Italic        �Ƿ�б��
  Underline    �Ƿ��»���

  PlayStyle��  		��ʾ�ؼ���֧�����ơ����ơ����ơ����ƣ�
  Playspeed��		��ʾ�ٶ�
  Times           ������������δʹ�ã�
����ֵ��
  1���ɹ�
  2����������
}
function SendControl(nHandle,nSendType: Integer;nHWnd: THandle): Integer;
  stdcall; external cPlayDLL;
{
���ܣ���������
������
  SendType:����ģʽ1Ϊ��ͨ 2ΪSD������
  Hwnd:���ھ�� ,һ��ȡ0����
����ֵ��
  0��ԭ��1,û����ӽ�Ŀ2.��Ϊ���緢�ͣ���˿ڱ�ռ�� 3.��Ϊ���ڷ����򴮿ڱ�ռ�û򲻴���
  1�����ͳɹ�
  2��ͨѶʧ��
  3�����͹����г���
}

implementation

end.
