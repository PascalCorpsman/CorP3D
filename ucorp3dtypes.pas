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
Unit ucorp3dtypes;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, uvectormath;

Type
  TAABB = Record // Achsis Aligned Bounding Box
    A, B: TVector3; // defined by 2 Vectors
  End;

Function AABB(a, b: TVector3): TAABB;

Operator = (a, b: TAABB): Boolean;
Operator * (m: TMatrix4x4; v: TVector3): Tvector3;

Function CalculateEncapsulatingSphere(Const Points: TVector3Array): TSphere;

Procedure Nop();

Implementation

Uses math;

Function CalculateEncapsulatingSphere(Const Points: TVector3Array): TSphere;
Var
  minV, maxV: TVector3;
  i: Integer;
Begin
  // Calc a AABB
  minV := Points[0];
  maxV := Points[0];
  For i := 1 To high(Points) Do Begin
    minV := MinV3(minV, Points[i]);
    maxV := MaxV3(maxV, Points[i]);
  End;
  // Put Sphere in the middle of AABB ;)
  result.Center := (MinV + MaxV) / 2;
  result.Radius := LenV3(MaxV - MinV) / 2;
End;

Function AABB(a, b: TVector3): TAABB;
Begin
  result.a := minv3(a, b);
  result.B := maxv3(a, b);
End;

Operator = (a, b: TAABB): Boolean;
Begin
  result :=
    (abs(min(a.A.x, a.b.x) - min(b.a.x, b.b.x)) < Epsilon)
    And (abs(min(a.A.y, a.b.y) - min(b.a.y, b.b.y)) < Epsilon)
    And (abs(min(a.A.z, a.b.z) - min(b.a.z, b.b.z)) < Epsilon);
End;

Operator * (m: TMatrix4x4; v: TVector3): Tvector3;
Var
  tmp: TVector4;
Begin
  tmp := v4(v, 1);
  tmp := m * tmp;
  result := tmp;
End;

Procedure Nop();
Begin
  // Just for debugging
End;

End.

