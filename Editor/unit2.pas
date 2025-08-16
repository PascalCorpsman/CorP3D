Unit Unit2;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  uEditor, ucorp3dobjects;

Type

  { TForm2 }

  TForm2 = Class(TForm)
    Button1: TButton;
    Button2: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Edit4: TEdit;
    Edit5: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    PageControl1: TPageControl;
    BoxTab: TTabSheet;
    Procedure FormCreate(Sender: TObject);
  private
    Procedure LoadTEditorBox(Const Box: TEditorBox);
    Procedure SaveTEditorBox(Const Box: TEditorBox);

  public
    Procedure EditObjectProperties(Const Obj: TCorP3DCollider);

  End;

Var
  Form2: TForm2;

Implementation

{$R *.lfm}

{ TForm2 }

Procedure TForm2.FormCreate(Sender: TObject);
Begin
  caption := 'Propterty editor';
  PageControl1.ShowTabs := false;
End;

Procedure TForm2.LoadTEditorBox(Const Box: TEditorBox);
Begin
  BoxTab.Visible := true;
  edit1.text := format('%0.2f', [box.Mass]);
  edit2.text := format('%0.2f', [box.Restitution]);


End;

Procedure TForm2.SaveTEditorBox(Const Box: TEditorBox);
Begin
  box.Mass := strtofloatdef(edit1.text, 0);
End;

Procedure TForm2.EditObjectProperties(Const Obj: TCorP3DCollider);
Var
  i: integer;
Begin
  For i := 0 To PageControl1.PageCount - 1 Do Begin
    PageControl1.Pages[i].Visible := false;
  End;
  i := -1;
  // 1. Laden
  If (obj Is TEditorBox) And (i = -1) Then Begin
    LoadTEditorBox(obj As TEditorBox);
    i := 0;
  End;
  If i = -1 Then Begin
    Raise exception.Create('Error, unknown obj: ' + obj.ClassName);
  End;
  If ShowModal = mrOK Then Begin
    // 2. Übernehmen
    Case i Of
      0: SaveTEditorBox(obj As TEditorBox);
    End;

  End;
End;

End.

