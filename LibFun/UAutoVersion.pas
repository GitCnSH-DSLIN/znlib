{*******************************************************************************
  ����: dmzn@163.com 2019-05-05
  ����: �Զ����Ӱ汾��

  ��ע:
  *.�汾�Ÿ��·�ʽ:
    1.MajorVersion: ���汾�ű��ֲ���.
    2.MinorVersion: �ΰ汾�ű��ֲ���.
    3.Release: �����汾��Ϊ: �·�2λ,����2λ,���1λ
    4.Build: �����汾��Ϊ: �����汾����.
*******************************************************************************}
program UAutoVersion;

uses
  SysUtils, Classes, CnCommon, CnWizUtils;

var
  gStr: string;
  gOptions: IOTAProjectOptions;
  gYear,gMonth,gDay: Word;
  gMajor,gMinor,gRelease,gBuildNo: Integer;
begin
  if CnOtaGetCurrentProject = nil then Exit;  
  gOptions := CnOtaGetActiveProjectOptions(nil);
  if gOptions = nil then Exit;

  gMajor   := gOptions.GetOptionValue('MajorVersion');
  gMinor   := gOptions.GetOptionValue('MinorVersion');
  gRelease := gOptions.GetOptionValue('Release');
  gBuildNo := gOptions.GetOptionValue('Build');

  CnOtaSetProjectOptionValue(gOptions, 'MajorVersion', Format('%d', [gMajor]));
  CnOtaSetProjectOptionValue(gOptions, 'MinorVersion', Format('%d', [gMinor]));

  DecodeDate(Now(), gYear, gMonth, gDay);
  gStr := Format('%.2d', [gMonth]) + Format('%.2d', [gDay]) +
          Copy(Format('%d', [gYear]), 4, 1);
  CnOtaSetProjectOptionValue(gOptions, 'Release', gStr);

  if gRelease <> StrToInt(gStr) then
       gBuildNo := 1
  else gBuildNo := gBuildNo + 1;
  CnOtaSetProjectOptionValue(gOptions, 'Build', Format('%d', [gBuildNo]));
end.
