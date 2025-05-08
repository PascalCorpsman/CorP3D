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
Unit ucorp3dobjects;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, uvectormath, ucorp3dtypes;

Type

  (*
   * Most basic Collider Class
   *)

  { TCorP3DCollider }

  TCorP3DCollider = Class
  private
    fColliderSphere: TSphere; // For fast collision detection

    fFinished: Boolean; // True if all collision precalculations are made
    FForce: TVector3;
    fMaterial: integer;
    fCenterOfMass: TVector3;
    fMass: Single;
    fMatrix: TMatrix4x4;
    fvertices: TVector3Array;
    fVelocity: TVector3;
    finside: TVector3;
    Function getTransformedVertex(index: integer): TVector3;
  protected
    Procedure setMass(AValue: Single); virtual;
    Function getPosition: TVector3; virtual;
    Procedure setPosition(AValue: TVector3); virtual;
    Function getVertex(index: integer): TVector3; virtual;
    Function getVertexCount: integer; virtual;
    Procedure SetPoints(Const aPoints: TVector3Array);
  public
    UserData: PtrInt;

    Property CenterOfMass: TVector3 read fCenterOfMass write fCenterOfMass;
    Property Force: TVector3 read FForce write FForce;
    Property Material: integer read fMaterial write fMaterial;
    Property Matrix: TMatrix4x4 read fMatrix write fMatrix;
    Property Mass: Single read fMass write setMass; // 0 = solid / not moveable !
    Property Position: TVector3 read getPosition write setPosition;

    Property TransformedVertex[index: integer]: TVector3 read getTransformedVertex;
    Property Vertex[index: integer]: TVector3 read getVertex;
    Property VertexCount: integer read getVertexCount;

    Property Velocity: TVector3 read fVelocity write fVelocity;

    Constructor Create(); virtual;
    Destructor Destroy(); override;

    Function AABB: TAABB; virtual;
    Function Collide(Const other: TCorP3DCollider): Boolean; virtual;

    Procedure Finish; virtual; // Needed to be called every time after the vertex data is changed
  End;


  { TCorP3Plane }

  TCorP3Plane = Class(TCorP3DCollider)
  private
    fRestitution: Single;
    fNormVector, fBasePoint: TVector3;
  protected
    Procedure setMass(AValue: Single); override;
  public
    Property Restitution: Single read fRestitution write fRestitution; // 0 = No bounce, 1 = perfect bounce
    Constructor Create(NormVector, BasePoint: TVector3); reintroduce;
    Procedure Finish; override;
  End;

  { TCorP3DBox }

  TCorP3DBox = Class(TCorP3DCollider)
  private
    fDim: TVector3;
  public
    Constructor Create(Dim: TVector3); reintroduce;
  End;

  { TCorP3DCompoundCollider }

  TCorP3DCompoundCollider = Class(TCorP3DCollider)
  private
    fCollider: Array Of TCorP3DCollider;
    Function getCollider(index: integer): TCorP3DCollider;
    Function getColliderCount: integer;
  public
    Property Collider[index: integer]: TCorP3DCollider read getCollider;
    Property ColliderCount: integer read getColliderCount;
    Constructor Create(); override;
  End;

Implementation

Uses math;

Function Collide2Objects(Const A, B: TCorP3DCollider): Boolean;
Var
  p: TCorP3Plane;
  i: Integer;
  d: Single;
  c1, c2: TVector3;
Begin
  result := false;
  If (a.Mass = 0) And (b.Mass = 0) Then exit; // both have no mass -> collision will have no effect..
  If (a Is TCorP3Plane) And (b Is TCorP3Plane) Then exit; // 2 planes do not collide, as they both has no mass
  // Sort a to be a plane
  If b Is TCorP3Plane Then Begin
    result := Collide2Objects(b, a);
    exit;
  End;
  If a Is TCorP3Plane Then Begin
    p := TCorP3Plane(a);
    d := 1;
    For i := 0 To high(B.fvertices) Do Begin
      d := min(d, (B.TransformedVertex[i] - p.fBasePoint) * p.fNormVector);
    End;
    If d < 0 Then Begin
      // Move B object "above" the plane
      B.Position := B.Position - p.fNormVector * d;
      B.Velocity := B.Velocity - (1 + p.fRestitution) * (B.Velocity * p.fNormVector) * p.fNormVector;
      result := true;
    End;
    exit;
  End;
  If (a Is TCorP3DBox) And (b Is TCorP3DBox) Then Begin
    // 1. "Fast" Check to early skip collision detection by comparing the collision spheres ..
    c1 := a.Matrix * a.fColliderSphere.Center;
    c2 := b.Matrix * b.fColliderSphere.Center;
    If LenV3SQR(c1 - c2) <= sqr(a.fColliderSphere.Radius + b.fColliderSphere.Radius) Then Begin
      // TODO: implement collision detection between 2 convex colliders
      nop();
    End;
    exit;
  End;
  Raise exception.create('Error unhandled collision detection between ' + a.ClassName + ' and ' + b.ClassName);
End;

{ TCorP3DCollider }

Function TCorP3DCollider.AABB: TAABB;
Var
  i: Integer;
  tmp: TVector3;
Begin
  If Not assigned(fvertices) Then Raise exception.create('no points');
  result.a := fMatrix * fvertices[0];
  result.B := result.a;
  For i := 1 To high(fvertices) Do Begin
    tmp := TransformedVertex[i];
    result.a := MinV3(result.a, tmp);
    result.B := MaxV3(result.B, tmp);
  End;
End;

Function TCorP3DCollider.Collide(Const other: TCorP3DCollider): Boolean;
Begin
  result := Collide2Objects(self, other);
End;

Procedure TCorP3DCollider.Finish;
Begin
  If Not assigned(fvertices) Then Begin
    Raise exception.create('calling finish with no vertices');
  End;
  If fFinished Then exit;
  fFinished := true;
  fColliderSphere := CalculateEncapsulatingSphere(fvertices);
End;

Function TCorP3DCollider.getTransformedVertex(index: integer): TVector3;
Begin
  If (index < 0) Or (index > high(fvertices)) Then Raise exception.create('Error, out of bounds.');
  result := fMatrix * fvertices[index];
End;

Procedure TCorP3DCollider.setMass(AValue: Single);
Begin
  If fMass = AValue Then Exit;
  fMass := AValue;
End;

Function TCorP3DCollider.getPosition: TVector3;
Begin
  result.x := fMatrix[3, 0];
  result.y := fMatrix[3, 1];
  result.z := fMatrix[3, 2];
End;

Procedure TCorP3DCollider.setPosition(AValue: TVector3);
Begin
  fMatrix[3, 0] := AValue.x;
  fMatrix[3, 1] := AValue.y;
  fMatrix[3, 2] := AValue.z;
End;

Function TCorP3DCollider.getVertex(index: integer): TVector3;
Begin
  If (index < 0) Or (index > high(fvertices)) Then Raise exception.create('Error, out of bounds.');
  result := fvertices[index];
End;

Function TCorP3DCollider.getVertexCount: integer;
Begin
  result := length(fvertices);
End;

Constructor TCorP3DCollider.Create;
Begin
  Inherited create();
  fFinished := false;
  fMass := 0;
  fCenterOfMass := v3(0, 0, 0);
  fMaterial := 0;
  fMatrix := IdentityMatrix4x4;
  fvertices := Nil;
  fVelocity := v3(0, 0, 0);
End;

Destructor TCorP3DCollider.Destroy;
Begin
  setlength(fvertices, 0);
End;

Procedure TCorP3DCollider.SetPoints(Const aPoints: TVector3Array);
Var
  i: Integer;
Begin
  // TODO: die Punkte nicht einfach nur übernehmen, sondern tatsächlich noch mal die Convexe Hülle aus den Punkten berechnen
  fvertices := aPoints;
  fFinished := false;
  finside := fvertices[0];
  For i := 1 To high(fvertices) Do Begin
    finside := finside + fvertices[i];
  End;
  finside := finside / length(fvertices);
End;

{ TCorP3Plane }

Procedure TCorP3Plane.setMass(AValue: Single);
Begin
  // a Plane is not allowed to have a mass !
End;

Constructor TCorP3Plane.Create(NormVector, BasePoint: TVector3);
Begin
  fNormVector := NormVector;
  fBasePoint := BasePoint;
  fRestitution := 0;
End;

Procedure TCorP3Plane.Finish;
Begin
  // nothing to do, this is a plane !
End;

{ TCorP3DBox }

Constructor TCorP3DBox.Create(Dim: TVector3);
Var
  pts: TVector3Array;
Begin
  Inherited create();
  fDim := Dim;
  pts := Nil;
  setlength(pts, 8);
  pts[0] := v3(-fDim.x / 2, -fDim.y / 2, -fDim.z / 2);
  pts[1] := v3(-fDim.x / 2, -fDim.y / 2, fDim.z / 2);
  pts[2] := v3(fDim.x / 2, -fDim.y / 2, fDim.z / 2);
  pts[3] := v3(fDim.x / 2, -fDim.y / 2, -fDim.z / 2);
  pts[4] := v3(-fDim.x / 2, fDim.y / 2, -fDim.z / 2);
  pts[5] := v3(-fDim.x / 2, fDim.y / 2, fDim.z / 2);
  pts[6] := v3(fDim.x / 2, fDim.y / 2, fDim.z / 2);
  pts[7] := v3(fDim.x / 2, fDim.y / 2, -fDim.z / 2);
  SetPoints(pts);
End;

{ TCorP3DCompoundCollider }

Function TCorP3DCompoundCollider.getColliderCount: integer;
Begin
  result := length(fCollider);
End;

Function TCorP3DCompoundCollider.getCollider(index: integer): TCorP3DCollider;
Begin
  If (index < 0) Or (index > high(fCollider)) Then Raise exception.create('Error, out of bounds.');
  result := fCollider[index];
End;

Constructor TCorP3DCompoundCollider.Create;
Begin
  Inherited Create();
  fCollider := Nil;
End;

End.

