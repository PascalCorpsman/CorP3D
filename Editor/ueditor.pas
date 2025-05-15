Unit uEditor;

{$MODE ObjFPC}{$H+}

{$INTERFACES CORBA}

Interface

Uses
  Classes, SysUtils, uCorP3D, ucorp3dobjects, ucorp3dtypes, uvectormath;

Type

  { IRenderInterface }

  IRenderInterface = Interface
    ['{5E62CC43-BDAF-486B-B88D-C8BA004AA9B7}'] // Created with https://www.guidgenerator.com/
    Procedure Render();
  End;

  { IIsPickableInterface }

  IIsPickableInterface = Interface
    ['{0D84213F-7D9F-4BD0-A5BA-9FFB0ECC7422}'] // Created with https://www.guidgenerator.com/
    Procedure RenderForPicking(Gid: Byte);
    Procedure Select;
  End;

  { IDebugInterface }

  IDebugInterface = Interface
    ['{35B936E0-38FC-423A-84A4-2662CC2F1E88}'] // Created with https://www.guidgenerator.com/
    Procedure Translate(x, y, z: Single);
    Procedure UpdateTransformedValues();
  End;

  { TEditorBox }

  TEditorBox = Class(TCorP3DBox, IRenderInterface, IIsPickableInterface, IDebugInterface)
    fSelected: Boolean;
  public

    Constructor Create(Dim: TVector3); override;

    // IDebugInterface
    Procedure Translate(x, y, z: Single);

    // IRenderInterface
    Procedure Render(); virtual;

    // IIsPickableInterface
    Procedure Select; virtual;
    Procedure RenderForPicking(Gid: Byte); virtual;
  End;

Implementation

Uses dglOpenGL;

{ TEditorBox }

Constructor TEditorBox.Create(Dim: TVector3);
Begin
  Inherited Create(Dim);
  fSelected := false;
End;

Procedure TEditorBox.Translate(x, y, z: Single);
Begin
  Position := Position + v3(x, y, z);
End;

Procedure TEditorBox.Render;
Begin
  glPushMatrix;
  If fSelected Then Begin
    glcolor3f(1, 0, 0);
  End
  Else Begin
    glcolor3f(1, 1, 1);
  End;
  glMultMatrixf(@Matrix);
  glBegin(GL_LINE_LOOP);
  glVertex3f(Vertex[0].x, Vertex[0].y, Vertex[0].z);
  glVertex3f(Vertex[1].x, Vertex[1].y, Vertex[1].z);
  glVertex3f(Vertex[2].x, Vertex[2].y, Vertex[2].z);
  glVertex3f(Vertex[3].x, Vertex[3].y, Vertex[3].z);
  glend;
  glBegin(GL_LINE_LOOP);
  glVertex3f(Vertex[4].x, Vertex[4].y, Vertex[4].z);
  glVertex3f(Vertex[5].x, Vertex[5].y, Vertex[5].z);
  glVertex3f(Vertex[6].x, Vertex[6].y, Vertex[6].z);
  glVertex3f(Vertex[7].x, Vertex[7].y, Vertex[7].z);
  glend;
  glbegin(GL_LINES);
  glVertex3f(Vertex[0].x, Vertex[0].y, Vertex[0].z);
  glVertex3f(Vertex[4].x, Vertex[4].y, Vertex[4].z);
  glVertex3f(Vertex[1].x, Vertex[1].y, Vertex[1].z);
  glVertex3f(Vertex[5].x, Vertex[5].y, Vertex[5].z);
  glVertex3f(Vertex[2].x, Vertex[2].y, Vertex[2].z);
  glVertex3f(Vertex[6].x, Vertex[6].y, Vertex[6].z);
  glVertex3f(Vertex[3].x, Vertex[3].y, Vertex[3].z);
  glVertex3f(Vertex[7].x, Vertex[7].y, Vertex[7].z);
  glend;
  glPopMatrix;
End;

Procedure TEditorBox.Select;
Begin
  fSelected := true;
End;

Procedure TEditorBox.RenderForPicking(Gid: Byte);
Begin
  fSelected := false;
  glPushMatrix;
  glMultMatrixf(@Matrix);
  glColor3ub(Gid, 0, 0);
  glbegin(GL_QUADS);
  // Top
  glVertex3f(Vertex[0].x, Vertex[0].y, Vertex[0].z);
  glVertex3f(Vertex[1].x, Vertex[1].y, Vertex[1].z);
  glVertex3f(Vertex[2].x, Vertex[2].y, Vertex[2].z);
  glVertex3f(Vertex[3].x, Vertex[3].y, Vertex[3].z);
  // Bottom
  glVertex3f(Vertex[4].x, Vertex[4].y, Vertex[4].z);
  glVertex3f(Vertex[5].x, Vertex[5].y, Vertex[5].z);
  glVertex3f(Vertex[6].x, Vertex[6].y, Vertex[6].z);
  glVertex3f(Vertex[7].x, Vertex[7].y, Vertex[7].z);
  glend();
  // Rest
  glbegin(GL_QUAD_STRIP);
  glVertex3f(Vertex[0].x, Vertex[0].y, Vertex[0].z);
  glVertex3f(Vertex[4].x, Vertex[4].y, Vertex[4].z);

  glVertex3f(Vertex[1].x, Vertex[1].y, Vertex[1].z);
  glVertex3f(Vertex[5].x, Vertex[5].y, Vertex[5].z);

  glVertex3f(Vertex[2].x, Vertex[2].y, Vertex[2].z);
  glVertex3f(Vertex[6].x, Vertex[6].y, Vertex[6].z);

  glVertex3f(Vertex[3].x, Vertex[3].y, Vertex[3].z);
  glVertex3f(Vertex[7].x, Vertex[7].y, Vertex[7].z);

  glVertex3f(Vertex[0].x, Vertex[0].y, Vertex[0].z);
  glVertex3f(Vertex[4].x, Vertex[4].y, Vertex[4].z);

  glend();
  glPopMatrix;
End;

End.






