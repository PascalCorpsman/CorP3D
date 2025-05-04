(******************************************************************************)
(*                                                                            *)
(* Author      : Uwe Schächterle (Corpsman)                                   *)
(*                                                                            *)
(* This file is part of CorP3D                                                *)
(*                                                                            *)
(*  See the file license.md, located under:                                   *)
(*  https://github.com/PascalCorpsman/Software_Licenses/blob/main/license.md  *)
(*  for details about the license.                                            *)
(*                                                                            *)
(*               It is not allowed to change or remove this text from any     *)
(*               source file of the project.                                  *)
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
  , uCorP3D, ucorp3dobjects, ucorp3dtypes, uvectormath;


Const
  Gravity: TVector3 = (x: 0; y: - 9.8; z: 0);

Type

  { TForm1 }

  TForm1 = Class(TForm)
    Button1: TButton;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    OpenGLControl1: TOpenGLControl;
    Timer1: TTimer;
    Procedure Button1Click(Sender: TObject);
    Procedure CheckBox1Click(Sender: TObject);
    Procedure CheckBox2Click(Sender: TObject);
    Procedure FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
    Procedure FormCreate(Sender: TObject);
    Procedure OpenGLControl1MakeCurrent(Sender: TObject; Var Allow: boolean);
    Procedure OpenGLControl1Paint(Sender: TObject);
    Procedure OpenGLControl1Resize(Sender: TObject);
    Procedure Timer1Timer(Sender: TObject);
  private
    { private declarations }
    LastTick: QWord;
    World: TCorP3DWorld;
    box: TCorP3DBox;
    Procedure CreateWorldContent;
    Procedure UpdatePhysics;
    Procedure RenderSzene;
    Procedure OnForceAndTorque(Const aCollider: TCorP3DCollider; delta: Single);
  public
    { public declarations }
    Procedure Go2d();
    Procedure Exit2d();
  End;

Var
  Form1: TForm1;
  Initialized: Boolean = false; // Wenn True dann ist OpenGL initialisiert

Implementation

{$R *.lfm}

Const
  (*
   * Its used in create and reset, so therefore provide it as a constant
   *)
  MoveableBoxStartingPosition: TVector3 = (X: 1.5; y: 3; Z: 0);

  { TForm1 }

Procedure TForm1.Go2d;
Begin
  glMatrixMode(GL_PROJECTION);
  glPushMatrix(); // Store The Projection Matrix
  glLoadIdentity(); // Reset The Projection Matrix
  //  glOrtho(0, 640, 0, 480, -1, 1); // Set Up An Ortho Screen
  glOrtho(0, OpenGLControl1.Width, OpenGLControl1.height, 0, -1, 1); // Set Up An Ortho Screen
  glMatrixMode(GL_MODELVIEW);
  glPushMatrix(); // Store old Modelview Matrix
  glLoadIdentity(); // Reset The Modelview Matrix
End;

Procedure TForm1.Exit2d;
Begin
  glMatrixMode(GL_PROJECTION);
  glPopMatrix(); // Restore old Projection Matrix
  glMatrixMode(GL_MODELVIEW);
  glPopMatrix(); // Restore old Projection Matrix
End;

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
    {
    OpenGL_GraphikEngine.clear;
    glenable(GL_TEXTURE_2D); // Texturen
    glEnable(GL_DEPTH_TEST); // Tiefentest
    glDepthFunc(gl_less);
    }
    // Der Anwendung erlauben zu Rendern.
    Initialized := True;
    OpenGLControl1Resize(Nil);
  End;
  Form1.Invalidate;
End;

Procedure TForm1.OpenGLControl1Paint(Sender: TObject);
Begin
  If Not Initialized Then Exit;
  // Render Szene
  glClearColor(0.0, 0.0, 0.0, 0.0);
  glClear(GL_COLOR_BUFFER_BIT Or GL_DEPTH_BUFFER_BIT);
  glLoadIdentity();

  // Move the Viewpoint a little, so that we can see whats going on
  gluLookAt(5, 11, -20, 5, 5, 0, 0, 1, 0);
  // Give the Physics Engine time to do it's things..
  UpdatePhysics;
  // Render the updated world
  RenderSzene;

  OpenGLControl1.SwapBuffers;
End;

Procedure TForm1.OpenGLControl1Resize(Sender: TObject);
Begin
  If Initialized Then Begin
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glViewport(0, 0, OpenGLControl1.Width, OpenGLControl1.Height);
    gluPerspective(45.0, OpenGLControl1.Width / OpenGLControl1.Height, 0.1, 100.0);
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
  0.01666666 ms
  Ist Interval auf 16 hängt das gesamte system, bei 17 nicht.
  Generell sollte die Interval Zahl also dynamisch zum Rechenaufwand, mindestens aber immer 17 sein.
  *)
  Timer1.Interval := 17;
  World := TCorP3DWorld.Create();
  world.OnForceAndTorqueCallback := @OnForceAndTorque;
  CreateWorldContent;
End;

Procedure TForm1.FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
Begin
  Initialized := false;
  world.free;
  world := Nil;
End;

Procedure TForm1.CheckBox1Click(Sender: TObject);
Begin
  // start "Timing", if needed
  If CheckBox1.Checked Then Begin
    // Reset last Time calculated when starting
    LastTick := GetTickCount64;
  End;
End;

Procedure TForm1.Button1Click(Sender: TObject);
Begin
  // Reset Box
  box.Matrix := IdentityMatrix4x4; // Reset Rotation
  box.Velocity := V3(0, 0, 0);
  box.Position := MoveableBoxStartingPosition;
End;

Procedure TForm1.CheckBox2Click(Sender: TObject);
Begin
  // Set / not Set Moving of Box
  If CheckBox2.Checked Then Begin
    box.Mass := 1;
    (*
     * Set the Body to moveable
     *)
    // box.unfreeze;
  End
  Else Begin
    box.Mass := 0;
    // If you also want to reset Rotation / Inertia and all that other stuff, see "reset" button code.
  End;
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

Procedure TForm1.CreateWorldContent;
Var
  b: TCorP3DBox;
Begin
  world.ClearWorldContent; // Cleanup
  // Create new World

  // 1. The Box that later can fall down
  box := TCorP3DBox.Create(v3(2, 1, 2));
  box.Position := MoveableBoxStartingPosition;
  world.AddCollider(box);

  // 2. Create something to collide with ;)
//  b := TCorP3DBox.Create(v3(2, 1, 2));
//  b.Position := v3(0, 0.5, 0);
//  world.AddCollider(b);


  //
  //  world.Dim := AABB(v3(-100, 0, -100), v3(100, 100, 100));
End;

Procedure TForm1.UpdatePhysics;
Var
  cnt, NewTick, Delta: uint64;
Begin
  If Not CheckBox1.Checked Then exit; // Is time evaluation enabled ?
  // Calculate time since last update -> delta
  NewTick := GetTickCount64;
  delta := NewTick - LastTick;
  (*
    Don't do this !

    World.Step(delta / 1000);

    In terms of accuracy, it is acually better to always use the same deltatime.

    So we call the Engine Step function as often as needed to simulate the given delta time.
   *)
  cnt := 1; // if delta is to short, we do not call the step function at all !
  While cnt < delta Do Begin
    World.Step(0.001); // Actually let the engine do its work
    inc(cnt);
  End;
  // Last thing accumulate the simulated time.
  LastTick := NewTick;
End;

Procedure TForm1.RenderSzene;
  Procedure RenderCollider(Const c: TCorP3DCollider);
  Var
    i: Integer;
    v: TVector3;
  Begin
    glbegin(GL_LINE_LOOP);
    For i := 0 To c.VertexCount - 1 Do Begin
      v := c.Vertex[i];
      glvertex3fv(@v);
    End;
    glend();
  End;

Var
  i, j: Integer;
  c: TCorP3DCollider;
Begin
  // Render a virtual "floor"
  glcolor3f(1, 0, 0);
  glbegin(GL_QUADS);
  glvertex3f(-100, 0, 100);
  glvertex3f(-100, 0, -100);
  glvertex3f(100, 0, -100);
  glvertex3f(100, 0, 100);
  glend();
  For i := 0 To World.ColliderCount - 1 Do Begin
    c := World.Collider[i];
    If c.Mass = 0 Then Begin
      // Static Objects will be rendered in white ;)
      glcolor3f(1, 1, 1);
    End
    Else Begin
      // Dynamic Objects will be rendered in Yellow
      glcolor3f(1, 1, 0);
    End;
    glPushMatrix;
    glMultMatrixf(@c.Matrix[0, 0]);
    If c Is TCorP3DCompoundCollider Then Begin
      For j := 0 To (c As TCorP3DCompoundCollider).ColliderCount - 1 Do Begin
        RenderCollider((c As TCorP3DCompoundCollider).Collider[j]);
      End;
    End
    Else Begin
      RenderCollider(c);
    End;
    glPopMatrix;
  End;
End;

Procedure TForm1.OnForceAndTorque(Const aCollider: TCorP3DCollider;
  delta: Single);
Begin
  aCollider.Force := Gravity * aCollider.Mass;
End;

End.

