(******************************************************************************)
(* CorP3D                                                          04.05.2025 *)
(*                                                                            *)
(* Version     : 0.01                                                         *)
(*                                                                            *)
(* Author      : Uwe Schächterle (Corpsman)                                   *)
(*                                                                            *)
(* Support     : www.Corpsman.de                                              *)
(*                                                                            *)
(* Description : Implementation of a 3D physics engine                        *)
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
Unit uCorP3D;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, ucorp3dtypes, ucorp3dobjects, uvectormath;

Type

  TForceAndTorqueCallback = Procedure(Const aCollider: TCorP3DCollider; delta: Single) Of Object;

  { TCorP3DWorld }

  TCorP3DWorld = Class
  private
    fDim: TAABB;
    fColliders: Array Of TCorP3DCollider;
    Function getCollider(index: integer): TCorP3DCollider;
    Function getColliderCount: Integer;
    Function getDim: TAABB;
    Procedure SetDim(AValue: TAABB);

  public
    OnForceAndTorqueCallback: TForceAndTorqueCallback;
    Property ColliderCount: Integer read getColliderCount;
    Property Collider[index: integer]: TCorP3DCollider read getCollider;
    Property Dim: TAABB read getDim write SetDim;

    Constructor Create(); virtual;
    Destructor Destroy(); override;

    Procedure AddCollider(Const aCollider: TCorP3DCollider);

    //    Procedure RemoveCollider(Const aCollider: TCorP3DCollider); // Removes the collider without freeing it

    Procedure ClearWorldContent; // Frees all collider that are registered to the world

    Procedure Step(aDelta: Single); // Simulates the scene for aDelta seconds..
  End;

Implementation

{ TCorP3DWorld }

Function TCorP3DWorld.getDim: TAABB;
Begin
  result := fDim;
End;

Function TCorP3DWorld.getCollider(index: integer): TCorP3DCollider;
Begin
  If (index < 0) Or (index > high(fColliders)) Then Raise exception.create('Error, out of bounds.');
  result := fColliders[index];
End;

Function TCorP3DWorld.getColliderCount: Integer;
Begin
  result := length(fColliders);
End;

Procedure TCorP3DWorld.SetDim(AValue: TAABB);
Begin
  If AValue = fDim Then exit;
  fDim := AValue;
End;

Constructor TCorP3DWorld.Create;
Begin
  Inherited Create;
  // Some values, so that the user at first glance does not need to care ..
  fdim.a := v3(-100, -100, -100);
  fdim.B := v3(100, 100, 100);
  fColliders := Nil;
  OnForceAndTorqueCallback := Nil;
End;

Destructor TCorP3DWorld.Destroy;
Begin
  ClearWorldContent();
End;

Procedure TCorP3DWorld.AddCollider(Const aCollider: TCorP3DCollider);
Begin
  setlength(fColliders, high(fColliders) + 2);
  fColliders[high(fColliders)] := aCollider;
  fColliders[high(fColliders)].Finish; // Finish collider if not yet done ..
End;

Procedure TCorP3DWorld.ClearWorldContent;
Var
  i: Integer;
Begin
  For i := high(fColliders) Downto 0 Do Begin
    fColliders[i].Free;
  End;
  setlength(fColliders, 0);
End;

Procedure TCorP3DWorld.Step(aDelta: Single);
Var
  i, j: Integer;
Begin
  If Not assigned(OnForceAndTorqueCallback) Then exit;
  For i := 0 To high(fColliders) Do Begin
    // 1. Apply all forces
    If fColliders[i].Mass = 0 Then Begin
      fColliders[i].Force := v3(0, 0, 0);
    End
    Else Begin
      OnForceAndTorqueCallback(fColliders[i], aDelta);
      fColliders[i].Step(aDelta);
    End;
  End;
  // Collide with others
  For i := 0 To high(fColliders) Do Begin
    For j := i + 1 To high(fColliders) Do Begin
      If fColliders[i].Collide(fColliders[j]) Then Begin

      End;
    End;
  End;
End;

End.

