{ @abstract(This file is part of the KControls component suite for Delphi and Lazarus.)
  @author(Tomas Krysl)

  Copyright (c) 2020 Tomas Krysl<BR><BR>

  <B>License:</B><BR>
  This code is licensed under BSD 3-Clause Clear License, see file License.txt or https://spdx.org/licenses/BSD-3-Clause-Clear.html.
}

unit kmemodlgimage; // lowercase name because of Lazarus/Linux

interface

uses
{$IFDEF FPC}
  LCLType, LCLIntf, LMessages, LCLProc, LResources,
{$ELSE}
  Windows, Messages,
{$ENDIF}
  SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, KControls, KMemo, ExtCtrls, ExtDlgs, KButtons, KEdits,
  ComCtrls;

type

  { TKMemoImageForm }

  TKMemoImageForm = class(TForm)
    BUOk: TButton;
    BUCancel: TButton;
    BUBrowse: TButton;
    ODMain: TOpenPictureDialog;
    PCMain: TPageControl;
    TSBasic: TTabSheet;
    TSAdvanced: TTabSheet;
    GBShading: TGroupBox;
    LBBorderWidth: TLabel;
    LBBorderColor: TLabel;
    LBShading: TLabel;
    EDBorderWidth: TKNumberEdit;
    CLBBorder: TKColorButton;
    CLBShading: TKColorButton;
    GBCrop: TGroupBox;
    LBCropLeft: TLabel;
    LBCropRight: TLabel;
    LBCropTop: TLabel;
    LBCropBottom: TLabel;
    EDCropLeft: TKNumberEdit;
    EDCropRight: TKNumberEdit;
    EDCropTop: TKNumberEdit;
    EDCropBottom: TKNumberEdit;
    GBPosition: TGroupBox;
    RBPositionText: TRadioButton;
    RBPositionRelative: TRadioButton;
    RBPositionAbsolute: TRadioButton;
    EDOffsetX: TKNumberEdit;
    EDOffsetY: TKNumberEdit;
    GBSize: TGroupBox;
    EDScaleX: TKNumberEdit;
    EDScaleY: TKNumberEdit;
    CBProportional: TCheckBox;
    GBWrap: TGroupBox;
    RBWrapAround: TRadioButton;
    RBWrapAroundLeft: TRadioButton;
    RBWrapAroundRight: TRadioButton;
    RBWrapTopBottom: TRadioButton;
    GBPreview: TGroupBox;
    MEPreview: TKMemo;
    EDExplicitWidth: TKNumberEdit;
    EDExplicitHeight: TKNumberEdit;
    BUResetOriginalSize: TButton;
    procedure BUBrowseClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure EDScaleXChange(Sender: TObject);
    procedure EDScaleYChange(Sender: TObject);
    procedure RBPositionTextClick(Sender: TObject);
    procedure EDScaleXExit(Sender: TObject);
    procedure CBProportionalClick(Sender: TObject);
    procedure BUResetOriginalSizeClick(Sender: TObject);
  private
    { Private declarations }
    FMemo: TKMemo;
    FPreviewImage: TKMemoImageBlock;
    FLockUpdate: Boolean;
    procedure UpdateFields;
  public
    { Public declarations }
    procedure Clear;
    procedure Load(AMemo: TKMemo; AItem: TKMemoImageBlock);
    procedure Save(AItem: TKMemoImageBlock);
  end;

implementation

{$IFDEF FPC}
 {$R *.lfm}
{$ELSE}
 {$R *.dfm}
{$ENDIF}

uses
  KEditCommon, KGraphics;

{ TKMemoHyperlinkForm }

procedure TKMemoImageForm.BUBrowseClick(Sender: TObject);
begin
  if ODMain.Execute then
    FPreviewImage.LoadFromFile(ODMain.FileName);
end;

procedure TKMemoImageForm.BUResetOriginalSizeClick(Sender: TObject);
begin
  FLockUpdate := True;
  try
    EDExplicitWidth.Value := 0;
    EDExplicitHeight.Value := 0;
    EDScaleX.ValueAsInt := 100;
    EDScaleY.ValueAsInt := 100;
  finally
    FLockUpdate := False;
  end;
  EDScaleXExit(Sender);
end;

procedure TKMemoImageForm.CBProportionalClick(Sender: TObject);
begin
  EDScaleXChange(Sender);
  EDScaleXExit(Sender);
end;

procedure TKMemoImageForm.Clear;
begin
end;

procedure TKMemoImageForm.EDScaleXChange(Sender: TObject);
begin
  if CBProportional.Checked and not FLockUpdate then
  begin
    FLockUpdate := True;
    try
      EDScaleY.ValueAsInt := EDScaleX.ValueAsInt;
    finally
      FLockUpdate := False;
    end;
  end;
end;

procedure TKMemoImageForm.EDScaleXExit(Sender: TObject);
begin
  if not FLockUpdate then
    Save(FPreviewImage);
end;

procedure TKMemoImageForm.EDScaleYChange(Sender: TObject);
begin
  if CBProportional.Checked and not FLockUpdate then
  begin
    FLockUpdate := True;
    try
      EDScaleX.ValueAsInt := EDScaleY.ValueAsInt;
    finally
      FLockUpdate := False;
    end;
  end;
end;

procedure TKMemoImageForm.FormCreate(Sender: TObject);
begin
  PCMain.ActivePageIndex := 0;
end;

procedure TKMemoImageForm.Load(AMemo: TKMemo; AItem: TKMemoImageBlock);
begin
  Assert(AMemo <> nil);
  Assert(AItem <> nil);
  FMemo := AMemo;
  FLockUpdate := True; // lock scaling constraint
  try
    MEPreview.Clear;
    FPreviewImage := MEPreview.Blocks.AddImageBlock(nil);
    FPreviewImage.Assign(AItem);
    FPreviewImage.Position := mbpRelative;
    FPreviewImage.LeftOffset := 0;
    FPreviewImage.TopOffset := 0;
    FPreviewImage.Select(-1, 0, False);
    case AItem.Position of
      mbpText: RBPositionText.Checked := True;
      mbpRelative: RBPositionRelative.Checked := True;
      mbpAbsolute: RBPositionAbsolute.Checked := True;
    end;
    EDOffsetX.Value := FMemo.Px2PtX(AItem.LeftOffset);
    EDOffsetY.Value := FMemo.Px2PtY(AItem.TopOffset);
    EDExplicitWidth.Value := FMemo.Px2PtX(AItem.ExplicitWidth);
    EDExplicitHeight.Value := FMemo.Px2PtY(AItem.ExplicitHeight);
    EDScaleX.ValueAsInt := AItem.LogScaleX;
    EDScaleY.ValueAsInt := AItem.LogScaleY;
    CBProportional.Checked := AItem.ScaleX = AItem.ScaleY;
    case AItem.ImageStyle.WrapMode of
      wrAround, wrTight: RBWrapAround.Checked := True;
      wrAroundLeft, wrTightLeft: RBWrapAroundLeft.Checked := True;
      wrAroundRight, wrTightRight: RBWrapAroundRight.Checked := True;
    else
      RBWrapTopBottom.Checked := True;
    end;
    EDBorderWidth.Value := FMemo.Px2PtX(AItem.ImageStyle.BorderWidth);
    CLBBorder.DlgColor := AItem.ImageStyle.BorderColor;
    if AItem.ImageStyle.Brush.Style <> bsClear then
      CLBShading.DlgColor := AItem.ImageStyle.Brush.Color
    else
      CLBShading.DlgColor := clNone;
    EDCropLeft.Value := FMemo.Px2PtX(AItem.Crop.Left);
    EDCropRight.Value := FMemo.Px2PtX(AItem.Crop.Right);
    EDCropTop.Value := FMemo.Px2PtY(AItem.Crop.Top);
    EDCropBottom.Value := FMemo.Px2PtY(AItem.Crop.Bottom);
    UpdateFields;
  finally
    FLockUpdate := False;
  end;
end;

procedure TKMemoImageForm.RBPositionTextClick(Sender: TObject);
begin
  UpdateFields;
end;

procedure TKMemoImageForm.Save(AItem: TKMemoImageBlock);
begin
  Assert(AItem <> nil);
  AItem.LockUpdate;
  try
    if AItem <> FPreviewImage then
    begin
      AItem.Image := FPreviewImage.Image;
      if RBPositionText.Checked then
        AItem.Position := mbpText
      else if RBPositionRelative.Checked then
        AItem.Position := mbpRelative
      else
        AItem.Position := mbpAbsolute;
      if AItem.Position = mbpText then
      begin
        AItem.LeftOffset := 0;
        AItem.TopOffset := 0;
      end else
      begin
        AItem.LeftOffset := FMemo.Pt2PxX(EDOffsetX.Value);
        AItem.TopOffset := FMemo.Pt2PxY(EDOffsetY.Value);
      end;
    end;
    AItem.ExplicitWidth := FMemo.Pt2PxX(EDExplicitWidth.Value);
    AItem.ExplicitHeight := FMemo.Pt2PxY(EDExplicitHeight.Value);
    AItem.LogScaleX := EDScaleX.ValueAsInt;
    AItem.LogScaleY := EDScaleY.ValueAsInt;
    if RBWrapAround.Checked then
      AItem.ImageStyle.WrapMode := wrAround
    else if RBWrapAroundLeft.Checked then
      AItem.ImageStyle.WrapMode := wrAroundLeft
    else if RBWrapAroundRight.Checked then
      AItem.ImageStyle.WrapMode := wrAroundRight
    else
      AItem.ImageStyle.WrapMode := wrTopBottom;
    AItem.ImageStyle.BorderWidth := FMemo.Pt2PxX(EDBorderWidth.Value);
    AItem.ImageStyle.BorderColor := CLBBorder.DlgColor;
    if CLBShading.DlgColor <> clNone then
      AItem.ImageStyle.Brush.Color := CLBShading.DlgColor;
    AItem.Crop.Left := FMemo.Pt2PxX(EDCropLeft.Value);
    AItem.Crop.Right := FMemo.Pt2PxX(EDCropRight.Value);
    AItem.Crop.Top := FMemo.Pt2PxY(EDCropTop.Value);
    AItem.Crop.Bottom := FMemo.Pt2PxY(EDCropBottom.Value);
  finally
    AItem.UnLockUpdate;
  end;
end;

procedure TKMemoImageForm.UpdateFields;
var
  RelOrAbs: Boolean;
begin
  RelOrAbs := not RBPositionText.Checked;
  RBWrapAround.Enabled := RelOrAbs;
  RBWrapAroundLeft.Enabled := RelOrAbs;
  RBWrapAroundRight.Enabled := RelOrAbs;
  RBWrapTopBottom.Enabled := RelOrAbs;
  EDOffsetX.Enabled := RelOrAbs;
  EDOffsetY.Enabled := RelOrAbs;
end;

end.
