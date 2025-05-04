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
   * Most basic Collider Class -> do not directly create, use some derivatives
   *)

  { TCorP3DCollider }

  TCorP3DCollider = Class
  private
    FForce: TVector3;
    fMaterial: integer;
    fCenterOfMass: TVector3;
    fMass: Single;
    fMatrix: TMatrix4x4;
    fPoints: TVector3Array;
    fVelocity: TVector3;
  protected
    Function getPosition: TVector3; virtual;
    Procedure setPosition(AValue: TVector3); virtual;
    Function getVertex(index: integer): TVector3; virtual;
    Function getVertexCount: integer; virtual;
  public
    UserData: PtrInt;

    Property CenterOfMass: TVector3 read fCenterOfMass write fCenterOfMass;
    Property Force: TVector3 read FForce write FForce;
    Property Material: integer read fMaterial write fMaterial;
    Property Matrix: TMatrix4x4 read fMatrix write fMatrix;
    Property Mass: Single read fMass write fMass; // 0 = solid / not moveable !
    Property Position: TVector3 read getPosition write setPosition;

    Property Vertex[index: integer]: TVector3 read getVertex;
    Property VertexCount: integer read getVertexCount;

    Property Velocity: TVector3 read fVelocity write fVelocity;

    Constructor Create(); virtual;
    Destructor Destroy(); override;

    Procedure SetPoints(Const aPoints: TVector3Array);

    Function AABB: TAABB; virtual; // abstract;
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

{ TCorP3DCollider }

Function TCorP3DCollider.AABB: TAABB;
Var
  i: Integer;
  tmp: TVector3;
Begin
  If Not assigned(fPoints) Then Raise exception.create('no points');
  result.a := fMatrix * fPoints[0];
  result.B := result.a;
  For i := 1 To high(fPoints) Do Begin
    tmp := fMatrix * fPoints[i];
    result.a := MinV3(result.a, tmp);
    result.B := MaxV3(result.B, tmp);
  End;
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
  If (index < 0) Or (index > high(fPoints)) Then Raise exception.create('Error, out of bounds.');
  result := fPoints[index];
End;

Function TCorP3DCollider.getVertexCount: integer;
Begin
  result := length(fPoints);
End;

Constructor TCorP3DCollider.Create;
Begin
  Inherited create();
  fMass := 0;
  fCenterOfMass := v3(0, 0, 0);
  fMaterial := 0;
  fMatrix := IdentityMatrix4x4;
  fPoints := Nil;
  fVelocity := v3(0, 0, 0);
End;

Destructor TCorP3DCollider.Destroy;
Begin
  setlength(fPoints, 0);
End;

Procedure TCorP3DCollider.SetPoints(Const aPoints: TVector3Array);
Begin
  // TODO: die Punkte nicht einfach nur übernehmen, sondern tatsächlich noch mal die Convexe Hülle aus den Punkten berechnen
  fPoints := aPoints;
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

