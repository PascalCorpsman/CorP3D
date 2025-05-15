(******************************************************************************)
(* CorP3D Editor                                                   12.05.2025 *)
(*                                                                            *)
(* Version     : 0.01                                                         *)
(*                                                                            *)
(* Author      : Uwe Schächterle (Corpsman)                                   *)
(*                                                                            *)
(* Support     : www.Corpsman.de                                              *)
(*                                                                            *)
(* Description : a generic editor to create physics elements and play with    *)
(*               them.                                                        *)
(*                                                                            *)
(* License     : See the file license.md, located under:                      *)
(*  https://github.com/PascalCorpsman/Software_Licenses/blob/main/license.md  *)
(*  for details about the license.                                            *)
(*                                                                            *)
(*               It is not allowed to change or remove this text from any     *)
(*               source file of the project.                                  *)
(*                                                                            *)
(* Warranty    : There is no warranty, neither in correctness of the          *)
(*               implementation, nor anything other that could happen         *)
(*               or go wrong, use at your own risk.                           *)
(*                                                                            *)
(* Known Issues: none                                                         *)
(*                                                                            *)
(* History     : 0.01 - Initial version                                       *)
(*                                                                            *)
(******************************************************************************)

Unit Unit1;

{$MODE objfpc}{$H+}
{$DEFINE DebuggMode}

Interface

Uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls,
  OpenGlcontext,
  (*
   * Kommt ein Linkerfehler wegen OpenGL dann: sudo apt-get install freeglut3-dev
   *)
  dglOpenGL // http://wiki.delphigl.com/index.php/dglOpenGL.pas
  , uCorP3D, ucorp3dobjects, uvectormath
  , uopengl_camera, Types, uEditor;

Const
  Gravity: TVector3 = (x: 0; y: - 9.8; z: 0);

Type

  TMouseInfo = Record
    Down: Boolean;
    DownPos: TPoint;
  End;

  { TForm1 }

  TForm1 = Class(TForm)
    Button1: TButton;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    OpenGLControl1: TOpenGLControl;
    Timer1: TTimer;
    Procedure Button1Click(Sender: TObject);
    Procedure FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
    Procedure FormCreate(Sender: TObject);
    Procedure FormKeyDown(Sender: TObject; Var Key: Word; Shift: TShiftState);
    Procedure OpenGLControl1MakeCurrent(Sender: TObject; Var Allow: boolean);
    Procedure OpenGLControl1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    Procedure OpenGLControl1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    Procedure OpenGLControl1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    Procedure OpenGLControl1MouseWheelDown(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; Var Handled: Boolean);
    Procedure OpenGLControl1MouseWheelUp(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; Var Handled: Boolean);
    Procedure OpenGLControl1Paint(Sender: TObject);
    Procedure OpenGLControl1Resize(Sender: TObject);
    Procedure Timer1Timer(Sender: TObject);
  private
    { private declarations }
    Eye: TOpenGLCamera;
    EyeZoom: Single;
    MouseInfo: TMouseInfo;
    EditorObjects: Array Of TCorP3DCollider;
    PickedEditorObjectIndex: integer;

    Procedure OnForceAndTorque(Const aCollider: TCorP3DCollider; delta: Single);
    Procedure RenderSzene;
    Procedure PickEditorObject(x, y: Integer);
    Procedure CheckCollision;
  public
    { public declarations }
  End;

Var
  Form1: TForm1;
  Initialized: Boolean = false; // Wenn True dann ist OpenGL initialisiert

Implementation

{$R *.lfm}

Uses LCLType;

Const
  MouseSensitivity = 0.5;

  { TForm1 }

Var
  allowcnt: Integer = 0;

Procedure TForm1.OpenGLControl1MakeCurrent(Sender: TObject; Var Allow: boolean);
Begin
  If allowcnt > 2 Then Begin
    exit;
  End;
  inc(allowcnt);
  // Sollen Dialoge beim Starten ausgeführt werden ist hier der Richtige Zeitpunkt
  If allowcnt = 1 Then Begin
    // Init dglOpenGL.pas , Teil 2
    ReadExtensions; // Anstatt der Extentions kann auch nur der Core geladen werden. ReadOpenGLCore;
    ReadImplementationProperties;
  End;
  If allowcnt = 2 Then Begin // Dieses If Sorgt mit dem obigen dafür, dass der Code nur 1 mal ausgeführt wird.
    (*
    Man bedenke, jedesmal wenn der Renderingcontext neu erstellt wird, müssen sämtliche Graphiken neu Geladen werden.
    Bei Nutzung der TOpenGLGraphikengine, bedeutet dies, das hier ein clear durchgeführt werden mus !!
    *)
    glenable(GL_TEXTURE_2D); // Texturen
    glEnable(GL_DEPTH_TEST); // Tiefentest
    glDepthFunc(gl_less);

    // Der Anwendung erlauben zu Rendern.
    Initialized := True;
    OpenGLControl1Resize(Nil);
  End;
  Form1.Invalidate;
End;

Procedure TForm1.OpenGLControl1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
Begin
  MouseInfo.Down := true;
  MouseInfo.DownPos := point(x, y);
  If ssleft In shift Then Begin
    PickEditorObject(x, y);
  End;
End;

Procedure TForm1.OpenGLControl1MouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
Var
  dx, dy: single;
Begin
  dx := (MouseInfo.DownPos.x - x) * MouseSensitivity;
  dy := (MouseInfo.DownPos.Y - y) * MouseSensitivity;
  If (ssRight In shift) Then Begin
    If PickedEditorObjectIndex <> -1 Then Begin
      If EditorObjects[PickedEditorObjectIndex] Is IDebugInterface Then Begin
        If ssShift In Shift Then Begin
          (EditorObjects[PickedEditorObjectIndex] As IDebugInterface).Translate((dx / 10) * EyeZoom, (dy / 10) * EyeZoom, 0);
        End
        Else Begin
          (EditorObjects[PickedEditorObjectIndex] As IDebugInterface).Translate((dx / 10) * EyeZoom, 0, (dy / 10) * EyeZoom);
        End;
        CheckCollision;
      End;
    End
    Else Begin
      If ssShift In Shift Then Begin
        eye.TranslateByWorld((-dx / 2) * EyeZoom, (dy / 2) * EyeZoom, 0);
      End
      Else Begin
        eye.TranslateByWorld(-(dx / 2) * EyeZoom, 0, -(dy / 2) * EyeZoom);
      End;
    End;
  End;
  If (ssLeft In shift) Then Begin
    If PickedEditorObjectIndex <> -1 Then Begin
      // TODO: Object Rotation..

    End
    Else Begin
      eye.Rotate(-dy, dx, 0);
    End;
  End;
  MouseInfo.DownPos := point(x, y);
End;

Procedure TForm1.OpenGLControl1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
Begin
  MouseInfo.Down := false;
End;

Procedure TForm1.OpenGLControl1MouseWheelDown(Sender: TObject;
  Shift: TShiftState; MousePos: TPoint; Var Handled: Boolean);
Begin
  EyeZoom := EyeZoom * 1.1;
  Eye.Zoom(1.1);
End;

Procedure TForm1.OpenGLControl1MouseWheelUp(Sender: TObject;
  Shift: TShiftState; MousePos: TPoint; Var Handled: Boolean);
Begin
  EyeZoom := EyeZoom / 1.1;
  Eye.Zoom(1 / 1.1);
End;

Procedure TForm1.OpenGLControl1Paint(Sender: TObject);
Begin
  If Not Initialized Then Exit;
  // Render Szene
  glClearColor(0, 0, 0, 0);
  glClear(GL_COLOR_BUFFER_BIT Or GL_DEPTH_BUFFER_BIT);
  glLoadIdentity();
  eye.SetCam;
  Eye.RenderGizmo(10, 80, 80, 3);
  // Zielpunkt der Camera
  If CheckBox2.Checked Then Begin
    glColor3f(1, 1, 1);
    glPointSize(10);
    glBegin(GL_POINTS);
    glVertex3f(Eye.Target.x, Eye.Target.y, Eye.Target.z);
    glEnd();
    glPointSize(1);
  End;

  RenderSzene;

  OpenGLControl1.SwapBuffers;
End;

Procedure TForm1.OpenGLControl1Resize(Sender: TObject);
Begin
  If Initialized Then Begin
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glViewport(0, 0, OpenGLControl1.Width, OpenGLControl1.Height);
    gluPerspective(45.0, OpenGLControl1.Width / OpenGLControl1.Height, 0.1, 100);
    glMatrixMode(GL_MODELVIEW);
  End;
End;

Procedure TForm1.FormCreate(Sender: TObject);
Begin
  caption := 'CorP3D basic example';
  // Init dglOpenGL.pas , Teil 1
  If Not InitOpenGl Then Begin
    showmessage('Error, could not init dglOpenGL.pas');
    Halt;
  End;
  (*
  60 - FPS entsprechen
  01666666 ms
  Ist Interval auf 16 hängt das gesamte system, bei 17 nicht.
  Generell sollte die Interval Zahl also dynamisch zum Rechenaufwand, mindestens aber immer 17 sein.
  *)
  Timer1.Interval := 17;
  MouseInfo.Down := false;
  Eye := TOpenGLCamera.Create(v3(0, 5, -10), v3(0, 0, 0), v3(0, 1, 0));
  // World := TCorP3DWorld.Create();
  // world.OnForceAndTorqueCallback := @OnForceAndTorque;
  Button1Click(Nil); // Rest eye
  PickedEditorObjectIndex := -1;
End;

Procedure TForm1.FormKeyDown(Sender: TObject; Var Key: Word; Shift: TShiftState
  );
Var
  i: Integer;
Begin
  If key = VK_B Then Begin
    If ssShift In shift Then Begin
      setlength(EditorObjects, high(EditorObjects) + 2);
      EditorObjects[high(EditorObjects)] := TEditorBox.create(v3(2, 2, 2));
      EditorObjects[high(EditorObjects)].Mass := 8; // Mass = Volume
      EditorObjects[high(EditorObjects)].Finish;
    End
    Else Begin
      setlength(EditorObjects, high(EditorObjects) + 2);
      EditorObjects[high(EditorObjects)] := TEditorBox.create(v3(1, 1, 1));
      EditorObjects[high(EditorObjects)].Mass := 1; // Mass = Volume
      EditorObjects[high(EditorObjects)].Finish;
    End;
  End;
  // Löschen des Aktuell angewählten Objects
  If (key = VK_DELETE) And (PickedEditorObjectIndex <> -1) Then Begin
    EditorObjects[PickedEditorObjectIndex].Free;
    For i := PickedEditorObjectIndex To high(EditorObjects) - 1 Do Begin
      EditorObjects[i] := EditorObjects[i + 1];
    End;
    setlength(EditorObjects, high(EditorObjects));
  End;
End;

Procedure TForm1.FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
Begin
  Initialized := false;
  Eye.free;
  Eye := Nil;
  //world.free;
  //world := Nil;
End;

Procedure TForm1.Button1Click(Sender: TObject);
Begin
  eye.Reset;
  EyeZoom := 1;
End;

Procedure TForm1.Timer1Timer(Sender: TObject);
{$IFDEF DebuggMode}
Var
  i: Cardinal;
  p: Pchar;
{$ENDIF}
Begin
  If Initialized Then Begin
    OpenGLControl1.Invalidate;
{$IFDEF DebuggMode}
    i := glGetError();
    If i <> 0 Then Begin
      Timer1.Enabled := false;
      p := gluErrorString(i);
      showmessage('OpenGL Error (' + inttostr(i) + ') occured.' + LineEnding + LineEnding +
        'OpenGL Message : "' + p + '"' + LineEnding + LineEnding +
        'Applikation will be terminated.');
      close;
    End;
{$ENDIF}
  End;
End;

Procedure TForm1.RenderSzene;
Const
  GridSize = 25;
Var
  i: Integer;
Begin
  // Render a virtual "floor"
  If CheckBox3.Checked Then Begin
    glbegin(GL_LINES);
    For i := -GridSize To GridSize Do Begin
      If i = 0 Then Begin
        glcolor3f(1, 1, 1);
      End
      Else Begin
        glcolor3f(0.5, 0.5, 0.5);
      End;
      glvertex3f(i, 0, GridSize);
      glvertex3f(i, 0, -GridSize);
      glvertex3f(GridSize, 0, i);
      glvertex3f(-GridSize, 0, i);
    End;
    glend();
  End;
  For i := 0 To high(EditorObjects) Do Begin
    // Normal Render
    If EditorObjects[i] Is IRenderInterface Then Begin
      (EditorObjects[i] As IRenderInterface).Render;
    End;
    // End Normal Render *)

    (* // Debug Render
    If EditorObjects[i] Is IIsPickableInterface Then Begin
      (EditorObjects[i] As IIsPickableInterface).RenderForPicking(255);
    End;
    // End Debug Render *)
  End;
End;

Procedure TForm1.PickEditorObject(x, y: Integer);
Var
  i: Integer;
Begin
  PickedEditorObjectIndex := -1;
  glPushMatrix;
  // Löschen des Framebuffers
  glClear(GL_COLOR_BUFFER_BIT Or GL_DEPTH_BUFFER_BIT);
  // TODO: Abschalten von Lightning und allem was die Farben Stören könnte !
  // Render for Picking
  For i := 0 To high(EditorObjects) Do Begin
    If EditorObjects[i] Is IIsPickableInterface Then Begin
      (EditorObjects[i] As IIsPickableInterface).RenderForPicking(i + 1);
    End;
  End;
  // Read the Element Color = ID
  glReadPixels(X, OpenGLControl1.Height - Y, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, @i);
  PickedEditorObjectIndex := (i And $FFFFFF) - 1;
  If PickedEditorObjectIndex <> -1 Then Begin
    (EditorObjects[PickedEditorObjectIndex] As IIsPickableInterface).Select;
  End;
  glPopMatrix;
End;

Procedure TForm1.CheckCollision;
Var
  i: Integer;
Begin
  If PickedEditorObjectIndex = -1 Then exit;
  For i := 0 To high(EditorObjects) Do Begin
    If EditorObjects[i] Is IDebugInterface Then Begin
      (EditorObjects[i] As IDebugInterface).UpdateTransformedValues();
    End;
  End;
  For i := 0 To high(EditorObjects) Do Begin
    If i = PickedEditorObjectIndex Then Continue;
    If EditorObjects[i] Is IDebugInterface Then Begin
      If Collide2Objects(EditorObjects[i], EditorObjects[PickedEditorObjectIndex]) Then Begin
        label1.Visible := true;
        exit;
      End;
    End;
  End;
  label1.Visible := false;
End;

Procedure TForm1.OnForceAndTorque(Const aCollider: TCorP3DCollider;
  delta: Single);
Begin
  aCollider.Force := Gravity * aCollider.Mass;
End;

End.



