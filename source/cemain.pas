unit ceMain;

{$mode objfpc}{$H+}

{$DEFINE USE_RICHMEMO}
{$IFDEF LCLGTK2}{$UNDEF USE_RICHMEMO}{$ENDIF}

interface

uses
  Classes, contnrs, SysUtils, FileUtil, IpHtml, Forms, Controls, Graphics,
  Dialogs, StdCtrls, ExtCtrls, Clipbrd, ComCtrls, ActnList, StdActns, Menus,
  LCLType,
  {$IFDEF USE_RICHMEMO}
  RichMemo, RichMemoRTF,
  {$ENDIF}
  KHexEditor;

type

  TClipboardItem = class
    Index: Integer;
    ClipboardType: TClipboardType;
    ClipboardFormat: TClipboardFormat;
    Description: String;
    Size: Int64;
  end;

  TClipboardItemList = class(TObjectList)
  public
    procedure AddItem(AType: TClipboardType; AFormat: TClipboardFormat; ASize: Int64);
  end;


  { TMainForm }

  TMainForm = class(TForm)
    AcRefresh: TAction;
    AcSettingsHexOffset: TAction;
    AcSettingsDecOffset: TAction;
    AcAbout: TAction;
    ActionList: TActionList;
    AcFileExit: TFileExit;
    AcSaveAs: TFileSaveAs;
    CoolBar: TCoolBar;
    Image: TImage;
    ImageList: TImageList;
    HtmlPanel: TIpHtmlPanel;
    LblImageInfo: TLabel;
    LvFormats: TListView;
    MainMenu: TMainMenu;
    Memo: TMemo;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    AcHelp: TMenuItem;
    MenuItem8: TMenuItem;
    MnuSettings: TMenuItem;
    MnuFile: TMenuItem;
    PageControl: TPageControl;
    DetailPanel: TPanel;
    FormatPanel: TPanel;
    Panel1: TPanel;
    ScrollBox1: TScrollBox;
    Splitter1: TSplitter;
    PgText: TTabSheet;
    PgHex: TTabSheet;
    PgImage: TTabSheet;
    PgHTML: TTabSheet;
    PgRichText: TTabSheet;
    ToolBar: TToolBar;
    ToolButton1: TToolButton;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    procedure AcAboutExecute(Sender: TObject);
    procedure AcRefreshExecute(Sender: TObject);
    procedure AcSaveAsAccept(Sender: TObject);
    procedure AcSettingsDecOffsetExecute(Sender: TObject);
    procedure AcSettingsHexOffsetExecute(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure LvFormatsClick(Sender: TObject);
    procedure LvFormatsColumnClick(Sender: TObject; Column: TListColumn);
    procedure LvFormatsCompare(Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer);
    procedure LvFormatsCompareIndex(Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer);
    procedure LvFormatsCompareText(Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer);
    procedure LvFormatsData(Sender: TObject; Item: TListItem);
  private
    { private declarations }
    FClipboardItems: TClipboardItemList;
    FGraphicMimeTypes: TStrings;
    FSortColumn: Integer;
    FSortDir: TSortDirection;
    HexEditor: TKHexEditor;
    {$IFDEF USE_RICHMEMO}
    FRichMemo: TRichMemo;
    {$ENDIF}
    function GetFormatSize(AType: TClipboardType; AFormat: TClipboardFormat): Int64;
    function GetSelectedClipboardFormat: TClipboardFormat;
    procedure HTMLGetImage(Sender: TIpHtmlNode; const URL: string; var Picture: TPicture);
    procedure UpdateFormatDetails(AIndex: Integer);
    procedure UpdateFormatList;
    procedure UpdateSortIcons;

    procedure ReadIni;
    procedure WriteIni;

  public
    { public declarations }
    procedure BeforeRun;
  end;

var
  MainForm: TMainForm;


implementation

{$R *.lfm}

uses
  Math, LazUTF8, LConvEncoding, LCLIntf, GraphType, IntfGraphics, IniFiles,
  ceAbout;

type
  TBom = (bomUtf8, bomUtf16BE, bomUtf16LE, bomUndefined);


{ Utilities }

function CreateIni: TCustomIniFile;
begin
  Result := TMemIniFile.Create(ChangeFileExt(GetAppConfigFile(false), '.ini'));
end;

function GetFixedFontName: String;
var
  idx: Integer;
begin
  Result := Screen.SystemFont.Name;
  idx := Screen.Fonts.IndexOf('Courier New');
  if idx = -1 then
    idx := Screen.Fonts.IndexOf('Courier 10 Pitch');
  if idx <> -1 then
    Result := Screen.Fonts[idx]
  else
    for idx := 0 to Screen.Fonts.Count-1 do
      if pos('courier', Lowercase(Screen.Fonts[idx])) = 1 then
      begin
        Result := Screen.Fonts[idx];
        exit;
      end;
end;

function GetBOMFromStream(Stream: TStream): TBom;
const
  Buf: Array[1..3] of Byte = (0,0,0);
begin
  Result := bomUndefined;
  Stream.Position := 0;
  if (Stream.Size > 2) then
    Stream.Read(Buf[1],3)
  else
  if (Stream.Size > 1) then
    Stream.Read(Buf[1],2);

  if ((Buf[1]=$FE) and (Buf[2]=$FF)) then
    Result := bomUtf16BE
  else
  if ((Buf[1]=$FF) and (Buf[2]=$FE)) then
    Result := bomUtf16LE
  else
  if ((Buf[1]=$EF) and (Buf[2]=$BB) and(Buf[3]=$BF)) then
    Result := bomUtf8;
end;

function ExtractUTF8Text(AStream: TMemoryStream): String;
var
  US: UnicodeString;
  isUTF16: Boolean;
  P, P0: PAnsiChar;
begin
  AStream.Position := AStream.Size;
  AStream.Write(#0#0, Length(#0#0));
  case GetBomFromStream(AStream) of
    bomUtf8:
      begin
        AStream.Position := 3;
        SetLength(Result, AStream.Size - 3);
        AStream.Read(Result, AStream.Size - 3);
        //ClipBoard may return a larger stream than the size of the string
        //this gets rid of it, since the string will end in a #0 (wide)char
        Result := PAnsiChar(Result);
      end;
    bomUTF16LE:
      begin
        AStream.Position := 2;
        SetLength(US, AStream.Size - 2);
        AStream.Read(US[1], AStream.Size - 2);
        //ClipBoard may return a larger stream than the size of the string
        //this gets rid of it, since the string will end in a #0 (wide)char
        US := PWideChar(US);
        Result := Utf16ToUtf8(US);
      end;
    bomUtf16BE:
      begin
        //this may need swapping of WideChars????
        AStream.Position := 2;
        SetLength(US, AStream.Size - 2);
        AStream.Read(US[1], AStream.Size - 2);
        //ClipBoard may return a larger stream than the size of the string
        //this gets rid of it, since the string will end in a #0 (wide)char
        US := PWideChar(US);
        Result := Utf16ToUtf8(US);
      end;
    bomUndefined:
      begin
        // There is no BOM marker. Look at the first 100 bytes if every
        // other byte (at odd index) is 0 --> UTF16LE probably
        isUTF16 := true;
        P0 := PAnsiChar(AStream.Memory);
        P := P0;
        inc(P);
        while (P - P0) < Min(100, AStream.Size) do begin
          if P^ <> #0 then begin
            isUTF16 := false;
            break;
          end;
          inc(P, 2);
        end;
        if isUTF16 then begin
          Result := Utf16toUtf8(PWideChar(AStream.Memory));
          exit;
        end;
        // Look at the first 100 bytes if every byte at even index pos is 0
        // --> UTF16BE probably
        isUTF16 := true;
        P := P0;
        while (P - P0 < Min(100, AStream.Size)) do begin
          if P^ <> #0 then begin
            isUTF16 := false;
            break;
          end;
          inc(P, 2);
        end;
        if isUTF16 then begin
          Result := UCS2BEToUTF8(PWideChar(AStream.Memory));
          exit;
        end;
        // Otherwise is could be UTF8
        Result := PAnsiChar(AStream.Memory);
      end;
  end;
end;

function RemoveHTMLHeader(AStream: TMemoryStream): String;
const
  SVersion           = 'Version:';
  SStartHTMLKey      = 'StartHTML:';
  SEndHTMLKey        = 'EndHTML:';
  SStartFragmentKey  = 'StartFragment:';
  SEndFragmentKey    = 'EndFragment:';
var
  P, PHtmlStart, PHtmlEnd: Integer;
  HtmlStart, HtmlEnd: Integer;
  s: String;
begin
  Result := ExtractUTF8Text(AStream);

  P := Pos(SVersion, Result);                     // "Version:"
  if (P = 0) then exit;

  P := Pos(SStartFragmentKey, Result);            // "StartFragment:"
  if (P = 0) then Exit;

  P := Pos(SEndFragmentKey, Result);              // "EndFragment:"
  if (P = 0) then Exit;

  PHTMLStart := Pos(SStartHTMLKey, Result);       // "StartHTML:"
  if (PHTMLStart = 0) then Exit;

  PHTMLEnd := Pos(SEndHTMLKey, Result) ;          // "EndHTML:"
  if (PHTMLEnd = 0) then Exit;

  PHtmlStart := Pos(SStartHTMLKey, Result);       // "StartHTML:"
  if (PHtmlStart = 0) then Exit;
  PHtmlStart := PHtmlStart + Length(SStartHTMLKey);
  P := PHtmlStart;
  while (P < Length(Result)) and (not (Result[P] in [#13,#10])) do Inc(P);
  if not (Result[P] in [#13,#10]) then Exit;
  s := Copy(Result, PHtmlStart, P - PHtmlStart);
  if not TryStrToInt(s, HtmlStart) then Exit;

  PHtmlEnd := Pos(SEndHTMLKey, Result);           // "EndHTML:"
  if (PHtmlEnd = 0) then Exit;
  PHtmlEnd := PHtmlEnd + Length(SEndHTMLKey);
  P := PHtmlEnd;
  while (P < Length(Result)) and (not (Result[P] in [#13,#10])) do Inc(P);
  if not (Result[P] in [#13,#10]) then Exit;
  s := Copy(Result, PHtmlEnd, P - PHtmlEnd);
  if not TryStrToInt(s, HtmlEnd) then Exit;

  Result := copy(Result, HtmlStart+1, HtmlEnd - HtmlStart);
end;

function LoadDIB(AStream: TStream; ABitmap: TBitmap): boolean;
var
  HBmp, HMask: HBitmap;
  IntfImg: TLazIntfImage;
  Reader: TLazReaderDIB;
begin
  Result := false;
  reader := TLazReaderDIB.Create;
  try
    if reader.CheckContents(AStream) then begin
      IntfImg := TLazIntfImage.Create(0, 0, [riqfRGB, riqfAlpha, riqfMask]);
      try
        IntfImg.LoadFromStream(AStream, reader);
        IntfImg.CreateBitmaps(HBmp, HMask);
        ABitmap.Handle := HBmp;
        ABitmap.MaskHandle := HMask;
        Result := true;
      finally
        IntfImg.Free;
      end;
    end;
  finally
    Reader.Free;
  end;
end;

function GetClipboardFormatDescription(AFormat: TClipboardFormat): String;
var
  mt: String;
begin
  Result := '';
  try
   {$ifdef Windows}
    case AFormat of
       1: Result := 'CF_TEXT';
       2: Result := 'CF_BITMAP';
       3: Result := 'CF_METAFILEPICT';
       4: Result := 'CF_SYLK';
       5: Result := 'CF_DIF';
       6: Result := 'CF_TIFF';
       7: Result := 'CF_OEMTEXT';
       8: Result := 'CF_DIB';
       9: Result := 'CF_PALETTE';
      10: Result := 'CF_PENDATA';
      11: Result := 'CF_RIFF';
      12: Result := 'CF_WAVE';
      13: Result := 'CF_UNICODETEXT';
      14: Result := 'CF_ENHMETAFILE';
      15: Result := 'CF_HDROP';
      16: Result := 'CF_LOCALE';
      17: Result := 'CF_DIBV5';
     $80: Result := 'CF_OWNERDISPLAY';
     $81: Result := 'CF_DSPTEXT';
     $82: Result := 'CF_DSPBITMAP';
     $83: Result := 'CF_DSPMETAFILEPICT';
     $8E: Result := 'CF_DSPENHMETAFILE';
    end;
    mt := ClipboardFormatToMimeType(AFormat);
    if (mt <> '') and (Result <> '') then
      Result := Format('%s (%s)', [Result, mt])
    else if (mt <> '') and (Result = '') then
      Result := mt;
   {$else}
    Result := ClipboardFormatToMimeType(AFormat);
   {$endif}
  except
    Result := '? (Format ID = ' + IntToStr(AFormat) + ')';
  end;
end;


function CompareIndexAsc(AItem1, AItem2: Pointer): Integer;
var
  P1: TClipboardItem absolute AItem1;
  P2: TClipboardItem absolute AItem2;
begin
  Result := CompareValue(P1.Index, P2.Index);
end;

function CompareIndexDesc(AItem1, AItem2: Pointer): Integer;
var
  P1: TClipboardItem absolute AItem1;
  P2: TClipboardItem absolute AItem2;
begin
  Result := -CompareValue(P1.Index, P2.Index);
end;

function CompareTypeAsc(AItem1, AItem2: Pointer): Integer;
var
  P1: TClipboardItem absolute AItem1;
  P2: TClipboardItem absolute AItem2;
begin
  Result := CompareText(ClipboardTypeName[P1.ClipboardType], ClipboardTypeName[P2.ClipboardType]);
  if Result = 0 then
    Result := CompareValue(P1.ClipboardFormat, P2.ClipboardFormat);
end;

function CompareTypeDesc(AItem1, AItem2: Pointer): Integer;
var
  P1: TClipboardItem absolute AItem1;
  P2: TClipboardItem absolute AItem2;
begin
  Result := -CompareText(ClipboardTypeName[P1.ClipboardType], ClipboardTypeName[P2.ClipboardType]);
  if Result = 0 then
    Result := -CompareValue(P1.ClipboardFormat, P2.ClipboardFormat);
end;

function CompareDescriptionAsc(AItem1, AItem2: Pointer): Integer;
var
  P1: TClipboardItem absolute AItem1;
  P2: TClipboardItem absolute AItem2;
begin
  Result := CompareText(P1.Description, P2.Description);
end;

function CompareDescriptionDesc(AItem1, AItem2: Pointer): Integer;
var
  P1: TClipboardItem absolute AItem1;
  P2: TClipboardItem absolute AItem2;
begin
  Result := -CompareText(P1.Description, P2.Description);
end;

function CompareFormatAsc(AItem1, AItem2: Pointer): Integer;
var
  P1: TClipboardItem absolute AItem1;
  P2: TClipboardItem absolute AItem2;
begin
  Result := CompareValue(P1.ClipboardFormat, P2.ClipboardFormat);
end;

function CompareFormatDesc(AItem1, AItem2: Pointer): Integer;
var
  P1: TClipboardItem absolute AItem1;
  P2: TClipboardItem absolute AItem2;
begin
  Result := -CompareValue(P1.ClipboardFormat, P2.ClipboardFormat);
end;

function CompareSizeAsc(AItem1, AItem2: Pointer): Integer;
var
  P1: TClipboardItem absolute AItem1;
  P2: TClipboardItem absolute AItem2;
begin
  Result := CompareValue(P1.Size, P2.Size);
  if Result = 0 then
    Result := CompareValue(P1.ClipboardFormat, P2.ClipboardFormat);
end;

function CompareSizeDesc(AItem1, AItem2: Pointer): Integer;
var
  P1: TClipboardItem absolute AItem1;
  P2: TClipboardItem absolute AItem2;
begin
  Result := -CompareValue(P1.Size, P2.Size);
  if Result = 0 then
    Result := -CompareValue(P1.ClipboardFormat, P2.ClipboardFormat);
end;

{ TClipboardItemList }

procedure TClipboardItemList.AddItem(AType: TClipboardType;
  AFormat: TClipboardFormat; ASize: Int64);
var
  P: TClipboardItem;
  i: Integer;
begin
  for i:=0 to Count-1 do begin
    P := TClipboardItem(Items[i]);
    if (P.ClipboardFormat = AFormat) then
      exit;
  end;

  P := TClipboardItem.Create;
  P.Index := Count;
  P.ClipboardType := AType;
  P.ClipboardFormat := AFormat;
  P.Size := ASize;
  P.Description := GetClipboardFormatDescription(AFormat);

  Add(P);
end;


{ TMainForm }

procedure TMainForm.AcRefreshExecute(Sender: TObject);
begin
  UpdateFormatList;
end;

procedure TMainForm.AcAboutExecute(Sender: TObject);
begin
  with TAboutForm.Create(nil) do
    try
      ShowModal;
    finally
      Free;
    end;
end;

procedure TMainForm.AcSaveAsAccept(Sender: TObject);
var
  fn: String;
  stream: TStream;
  ct: TClipboardType;
begin
  fn := AcSaveAs.Dialog.Filename;
  stream := TFileStream.Create(fn, fmCreate);
  try
    for ct in TClipboardType do
      if Clipboard(ct).GetFormat(GetSelectedClipboardFormat, stream) then
        break;
  finally
    stream.Free;
  end;
end;

procedure TMainForm.AcSettingsDecOffsetExecute(Sender: TObject);
begin
  HexEditor.AddressMode := eamDec;
  HexEditor.AddressPrefix := '0';
end;

procedure TMainForm.AcSettingsHexOffsetExecute(Sender: TObject);
begin
  HexEditor.AddressMode := eamHex;
  HexEditor.AddressPrefix := '$';
end;

procedure TMainForm.BeforeRun;
begin
  ReadIni;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if CanClose then
    try
      WriteIni;
    except
    end;
end;

type
  TIpHtmlAccess = class(TIpHtml);

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FClipboardItems := TClipboardItemList.Create;

  FGraphicMimeTypes := TStringList.Create;
  FGraphicMimeTypes.Add('image/bmp');
  FGraphicMimeTypes.Add('image/x-bmp');
  FGraphicMimeTypes.Add('image/x-ms-bmp');
  FGraphicMimeTypes.Add('image/x-win-bitmap');
  FGraphicMimeTypes.Add('image/png');
  FGraphicMimeTypes.Add('image/gif');
  FGraphicMimeTypes.Add('image/jpeg');
  FGraphicMimeTypes.Add('image/tiff');
  FGraphicMimeTypes.Add('image/x-icon');
  FGraphicMimeTypes.Add('application/x-qt-image');

  PgHTML.Hide;
  PgRichText.Hide;
  PgImage.Hide;
  PageControl.ActivePageIndex := 0;

  Memo.Font.Name := GetFixedFontName;

  HexEditor := TKHexEditor.Create(self);
  HexEditor.Parent := PgHex;
  HexEditor.Align := alClient;
  HexEditor.AddressPrefix := '$';
  HexEditor.AddressSize := 10;
  HexEditor.Colors.DigitBkGnd := clBtnFace;
  HexEditor.Colors.InactiveCaretBkGnd := clHighlight;
  HexEditor.Colors.InactiveCaretSelBkGnd := clHighlight;
  HexEditor.Colors.SelBkGnd := clHighlight;
  HexEditor.Colors.Separators := clSilver;
  HexEditor.DigitGrouping := 1;
  HexEditor.Font.CharSet := ANSI_CHARSET;
  HexEditor.Font.Height := -12;
  HexEditor.Font.Name := 'Courier New';
  HexEditor.Font.Pitch := fpFixed;
  HexEditor.Font.Style := [fsBold];
  HexEditor.ReadOnly := True;
  HexEditor.TabOrder := 0;
  HexEditor.Font.Assign(Memo.Font);
  HexEditor.Font.Style := [];

  {$IFDEF USE_RICHMEMO}
  {$IFDEF LINUX}RegisterRTFLoader;{$ENDIF}
  FRichMemo := TRichMemo.Create(Self);
  FRichMemo.Parent := PgRichText;
  FRichMemo.Align := alClient;
  FRichMemo.HideSelection := false;
  FRichMemo.ScrollBars := ssAutoBoth;
  {$ENDIF}
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FClipboardItems.Free;
  FGraphicMimeTypes.Free;
end;

function TMainForm.GetFormatSize(AType: TClipboardType;
  AFormat: TClipboardFormat): Int64;
var
  stream: TStream;
begin
  stream := TMemoryStream.Create;
  try
    try
      Clipboard(AType).GetFormat(AFormat, stream);
      Result := stream.Size;
    except
      Result := -1;
    end;
  finally
    stream.Free;
  end;
end;

function TMainForm.GetSelectedClipboardFormat: TClipboardFormat;
begin
  if LvFormats.ItemIndex = -1 then
    Result := TClipboardFormat(-1)
  else
    Result := TClipboardItem(FClipboardItems[LvFormats.ItemIndex]).ClipboardFormat;
end;

procedure TMainForm.HtmlGetImage(Sender: TIpHtmlNode; const URL: string;
  var Picture: TPicture);
begin
  Picture := nil;
end;

procedure TMainForm.LvFormatsClick(Sender: TObject);
begin
  UpdateFormatDetails(LvFormats.ItemIndex);
end;

procedure TMainForm.LvFormatsColumnClick(Sender: TObject; Column: TListColumn);
begin
  if Column.Index = FSortColumn then
    FSortDir := TSortDirection((ord(FSortDir)+1) mod 2)
  else
    FSortColumn := Column.Index;

  UpdateSortIcons;
  if FSortDir = sdAscending then
    case Column.Index of
      0: FClipboardItems.Sort(@CompareIndexAsc);
      1: FClipboardItems.Sort(@CompareTypeAsc);
      2: FClipboardItems.Sort(@CompareFormatAsc);
      3: FClipboardItems.Sort(@CompareDescriptionAsc);
      4: FClipboardItems.Sort(@CompareSizeAsc);
    end
  else
    case Column.Index of
      0: FClipboardItems.Sort(@CompareIndexDesc);
      1: FClipboardItems.Sort(@CompareTypeDesc);
      2: FClipboardItems.Sort(@CompareFormatDesc);
      3: FClipboardItems.Sort(@CompareDescriptionDesc);
      4: FClipboardItems.Sort(@CompareSizeDesc);
    end;
  LvFormats.Refresh; //Invalidate;
  {
  case Column.Index of
    0: LvFormats.OnCompare := @LvFormatsCompareIndex;
    1: LvFormats.OnCompare := @LvFormatsCompare;
    2: LvFormats.OnCompare := @LvFormatsCompareText; //SortType := stText;
    3: LvFormats.OnCompare := @LvFormatsCompare;
  end;
  LvFormats.Sort;
  }
end;

procedure TMainForm.LvFormatsCompare(Sender: TObject; Item1, Item2: TListItem;
  Data: Integer; var Compare: Integer);
var
  idx: Integer;
begin
  idx := FSortColumn - 1;
  Compare := CompareValue(StrToInt(Item1.SubItems[idx]), StrToInt(Item2.SubItems[idx]));
  if FSortDir = sdDescending then
    Compare := -Compare;
end;

procedure TMainForm.LvFormatsCompareIndex(Sender: TObject;
  Item1, Item2: TListItem; Data: Integer; var Compare: Integer);
begin
  Compare := CompareValue(StrToInt(Item1.Caption), StrToInt(Item2.Caption));
  if FSortDir = sdDescending then
    Compare := -Compare;
end;

procedure TMainForm.LvFormatsCompareText(Sender: TObject;
  Item1, Item2: TListItem; Data: Integer; var Compare: Integer);
var
  idx: Integer;
begin
  idx := FSortColumn - 1;
  Compare := CompareText(Item1.SubItems[idx], Item2.SubItems[idx]);
  if FSortDir = sdDescending then
    Compare := -Compare;
end;

procedure TMainForm.LvFormatsData(Sender: TObject; Item: TListItem);
var
  P: TClipboardItem;
begin
  P := TClipboardItem(FClipboardItems[Item.Index]);
  Item.Caption := IntToStr(P.Index);
  Item.SubItems.Add(Uppercase(ClipboardTypeName[P.ClipboardType][1]));
  Item.SubItems.Add(IntToStr(P.ClipboardFormat));
  Item.SubItems.Add(P.Description);
  if P.Size = -1 then
    Item.SubItems.Add('?')
  else
    Item.SubItems.Add(Format('%.0n', [P.Size*1.0]));
end;

procedure TMainForm.ReadIni;
var
  ini: TCustomIniFile;
  n, L, T, W, H: Integer;
begin
  ini := CreateIni;
  try
    if ini.ReadBool('MainForm', 'Maximized', WindowState = wsMaximized) then
      WindowState := wsMaximized else
      WindowState := wsNormal;
    if WindowState = wsNormal then
    begin
      L := ini.ReadInteger('MainForm', 'Left', Left);
      T := ini.ReadInteger('MainForm', 'Top', Top);
      W := ini.ReadInteger('MainForm', 'Width', Width);
      H := ini.ReadInteger('MainForm', 'Height', Height);
      SetBounds(L, T, W, H);
    end;
    FormatPanel.Height := ini.ReadInteger('MainForm', 'FormatListHeight', FormatPanel.Height);
    n := ini.ReadInteger('Mainform', 'ActivePage', PageControl.ActivePageIndex);
    if n < 2 then
      PageControl.ActivePageIndex := n else
      PageControl.ActivePageIndex := 0;

    n := ini.ReadInteger('FormatList', 'SortDirection', 0);
    if (n > 0) and (n < ord(High(TSortDirection))) then
      FSortDir := TSortDirection(n);
    FSortColumn := ini.ReadInteger('FormatList', 'SortColumn', -1);

    if ini.ReadBool('Settings', 'HexOffset', AcSettingsHexOffset.Checked) then
    begin
      AcSettingsHexOffset.Checked := true;
      AcSettingsHexOffsetExecute(nil);
    end else
    begin
      AcSettingsDecOffset.Checked := true;
      AcSettingsDecOffsetExecute(nil);
    end;
  finally
    ini.Free;
  end;
end;

procedure TMainForm.UpdateFormatDetails(AIndex: Integer);
var
  clipstream: TMemoryStream;
  P: TClipboardItem;
  fmtName: String;
  mimeName: String;
  s: String;
  ok: Boolean;
begin
  if AIndex < 0 then begin
    Memo.Lines.Clear;
    HexEditor.Clear;
    PgImage.TabVisible := false;
    PgRichText.TabVisible := false;
    PgHTML.TabVisible := false;
    exit;
  end;

  P := TClipboardItem(FClipboardItems[AIndex]);
  fmtName := Lowercase(GetClipboardFormatDescription(P.ClipboardFormat));
  if (fmtName <> '') and (pos('cf_', fmtName) = 1) then begin
    mimeName := Copy(fmtName, pos('(', fmtName)+1, MaxInt);
    if mimeName[Length(mimeName)] = ')' then
      Delete(mimeName, Length(mimeName), 1);
  end else
    mimeName := fmtName;

  ok := true;
  clipstream := TMemoryStream.Create;
  try
    try
      Clipboard(P.ClipboardType).GetFormat(P.ClipboardFormat, clipstream);
    except
      ok := false;
    end;

    if not ok or (clipstream.Size = 0) then
    begin
      PgImage.TabVisible := false;
      PgRichText.TabVisible := false;
      PgHTML.TabVisible := false;
      Memo.Lines.Clear;
      HexEditor.Clear;
      exit;
    end;

    s := ExtractUTF8Text(clipstream);
    Memo.Lines.Text := s;

    clipstream.Position := 0;
    HexEditor.LoadFromStream(clipstream);

    if pos('cf_dib', fmtname) = 1 then begin
      clipstream.Position := 0;
      if LoadDIB(clipstream, Image.Picture.Bitmap) then begin
        Image.Width := Image.Picture.Width;
        Image.Height := Image.Picture.Height;
        LblImageInfo.Caption := Format('Width = %d, Height = %d', [Image.Picture.Width, Image.Picture.Height]);
        PgImage.TabVisible := true
      end else
        PgImage.TabVisible := false;
    end else
    if FGraphicMimeTypes.IndexOf(mimeName) > -1 then begin
      try
        clipstream.Position := 0;
        Image.Picture.Clear;
        Image.Picture.LoadFromStream(clipstream);
        Image.Width := Image.Picture.Width;
        Image.Height := Image.Picture.Height;
        LblImageInfo.Caption := Format('Width = %d, Height = %d', [Image.Picture.Width, Image.Picture.Height]);
        PgImage.TabVisible := true;
      except
        PgImage.TabVisible := false;
      end;
    end else
    begin
      Image.Picture.Clear;
      PgImage.TabVisible := false;
    end;

    if ((mimeName = 'text/html') or (fmtName = 'html format')) then begin
      clipstream.Position := 0;
      try
        HTMLPanel.SetHTMLFromStr(RemoveHtmlHeader(clipstream));
        TIpHtmlAccess(HtmlPanel.MasterFrame.Html).OnGetImageX := @HTMLGetImage;
        PgHTML.TabVisible := true;
      except
        on E:Exception do MessageDlg(E.Message, mtError, [mbOK], 0);
      end;
    end else
      PgHTML.TabVisible := false;

    {$IFDEF USE_RICHMEMO}
    if (fmtName = 'rich text format') or (mimeName = 'text/richtext') then begin
      try
        clipstream.Position := 0;
        FRichMemo.LoadRichText(clipstream);
        PgRichText.TabVisible := true;
      except
      end;
    end else
      PgRichText.TabVisible := false;
    {$ENDIF}

    Caption := 'Clipboard Explorer - ' + fmtName;
  finally
    clipstream.Free;
  end;
end;

procedure TMainForm.UpdateFormatList;
const
  CLIPBOARD_TYPES: array[TClipboardType] of TClipboardType = (
    ctClipboard, ctPrimarySelection, ctSecondarySelection
  );
var
  n, i: Integer;
  ct: TClipboardType;
  cf: TClipboardFormat;
begin
  FClipboardItems.Clear;
  for ct in CLIPBOARD_TYPES do begin
    n := Clipboard(ct).FormatCount;
    for i := 0 to n-1 do begin
      cf := Clipboard(ct).Formats[i];
      FClipboardItems.AddItem(ct, cf, GetFormatSize(ct, cf));
    end;
  end;

  // LvFormats is in virtual mode.
  LvFormats.Items.Count := FClipboardItems.Count;
  LvFormats.Invalidate;
  UpdateFormatDetails(LvFormats.ItemIndex);

end;

procedure TMainForm.UpdateSortIcons;
var
  i: Integer;
begin
  for i:=0 to LvFormats.Columns.Count-1 do
    if LvFormats.Columns[i].Index = FSortColumn then
      case FSortDir of
        sdAscending  : LvFormats.Columns[i].ImageIndex := 3;
        sdDescending : LvFormats.Columns[i].ImageIndex := 4;
      end
    else
      LvFormats.Columns[i].ImageIndex := -1;
end;

procedure TMainForm.WriteIni;
var
  ini: TCustomIniFile;
begin
  ini := CreateIni;
  try
    ini.EraseSection('MainForm');
    if WindowState = wsNormal then
    begin
      ini.WriteInteger('MainForm', 'Left', Left);
      ini.WriteInteger('MainForm', 'Top', Top);
      ini.WriteInteger('MainForm', 'Width', Width);
      ini.WriteInteger('MainForm', 'Height', Height);
    end;
    ini.WriteBool   ('MainForm', 'Maximized', WindowState = wsMaximized);
    ini.WriteInteger('MainForm', 'FormatListHeight', FormatPanel.Height);
    ini.WriteInteger('Mainform', 'ActivePage', PageControl.ActivePageIndex);

    //ini.WriteInteger('FormatList', 'SortColumn', LvFormats.SortColumn);
    //ini.WriteInteger('FormatList', 'SortDirection', ord(LvFormats.SortDirection));

    ini.WriteInteger('FormatList', 'SortColumn', FSortColumn);
    ini.WriteInteger('FormatList', 'SortDirection', ord(FSortDir));

    ini.WriteBool('Settings', 'HexOffset', AcSettingsHexOffset.Checked);
  finally
    ini.Free;
  end;
end;


end.
