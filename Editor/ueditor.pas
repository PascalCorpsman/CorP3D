Unit uEditor;

{$MODE ObjFPC}{$H+}

{$INTERFACES CORBA}

Interface

Uses
  Classes, SysUtils, uCorP3D, ucorp3dobjects, ucorp3dtypes;

Type

  IRenderInterface = Interface
    Procedure Render();
  End;

  { TEditorBox }

  TEditorBox = Class(TCorP3DBox, IRenderInterface)
  public
    Procedure Render(); virtual;
  End;

Implementation

Uses dglOpenGL;

{ TEditorBox }

Procedure TEditorBox.Render();
Begin
  glPushMatrix;
  glcolor3f(1, 1, 1);
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

End.

