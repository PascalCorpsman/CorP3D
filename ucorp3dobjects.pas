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

  TInterval = Record
    val_min, val_max: TBaseType;
  End;

  (*
   * Most basic Collider Class
   *)

  { TCorP3DCollider }

  TCorP3DCollider = Class
  private
    (*
     * Used during creation
     *)
    fRestitution: Single;
    fConvexHullFaces: TFaceArray;
    fFinished: Boolean; // True if all collision precalculations are made
    fMaterial: integer;
    fMass: Single;
    fCenterOfMass: TVector3;
    fVertices: TVector3Array;
    fSATAchsis: TVector3Array;
    (*
     * Used during simulation
     *)
    fColliderSphere: TSphere; // For fast collision detection
    fTransformedCenterOfMass: TVector3;
    fTransformedVertices: TVector3Array;
    fTransformedSATAchsis: TVector3Array;

    fForce: TVector3;
    fVelocity: TVector3;
    fMatrix: TMatrix4x4; // Transformation Matrix
  protected
    Procedure setMass(AValue: Single); virtual;
    Function getPosition: TVector3; virtual;
    Procedure setPosition(AValue: TVector3); virtual;
    Function getVertex(index: integer): TVector3; virtual;
    Function getVertexCount: integer; virtual;
    Function Getinterval(Const Axis: TVector3): TInterval;
    Procedure UpdateTransformedValues(); virtual;
    Function GetContactPoints(Const SATAchsisIndex: Integer): TVector3Array;
  public
    UserData: PtrInt;

    Property CenterOfMass: TVector3 read fCenterOfMass write fCenterOfMass;
    Property Force: TVector3 read FForce write FForce;
    Property Material: integer read fMaterial write fMaterial;
    Property Matrix: TMatrix4x4 read fMatrix write fMatrix;
    Property Mass: Single read fMass write setMass; // 0 = solid / not moveable !
    Property Position: TVector3 read getPosition write setPosition;
    Property Restitution: Single read fRestitution write fRestitution; // 0 = No bounce, 1 = perfect bounce

    Property Vertex[index: integer]: TVector3 read getVertex;
    Property VertexCount: integer read getVertexCount;

    Property Velocity: TVector3 read fVelocity write fVelocity;

    Constructor Create(); virtual;
    Destructor Destroy(); override;

    Procedure SetPoints(Const aPoints: TVector3Array); virtual; // Do not call in derived classes

    Function AABB: TAABB; virtual;
    Function Collide(Const other: TCorP3DCollider): Boolean; virtual;

    Procedure Finish; virtual; // Needed to be called every time after the vertex data is changed
    Procedure Step(aDelta: Single);
  End;


  { TCorP3Plane }

  TCorP3Plane = Class(TCorP3DCollider)
  private
    fNormVector, fBasePoint: TVector3;
  protected
    Procedure setMass(AValue: Single); override;
  public
    Constructor Create(NormVector, BasePoint: TVector3); reintroduce;
    Procedure Finish; override;
  End;

  { TCorP3DBox }

  TCorP3DBox = Class(TCorP3DCollider)
  private
    fDim: TVector3;
  protected
  public
    Constructor Create(Dim: TVector3); reintroduce;
  End;

  { TCorP3DCompoundCollider }

  TCorP3DCompoundCollider = Class(TCorP3DCollider)
  private
    fCollider: Array Of TCorP3DCollider;
    Function getCollider(index: integer): TCorP3DCollider;
    Function getColliderCount: integer;
  protected
  public
    Property Collider[index: integer]: TCorP3DCollider read getCollider;
    Property ColliderCount: integer read getColliderCount;
    Constructor Create(); override;
  End;

Implementation

Uses math
  , unit1 // Debug !
  ;

Function col_overlap_axis(Const shape1, shape2: TCorP3DCollider; Const axis: TVector3; Out Overlap: Single): Boolean;
Var
  a, b: TInterval;
  overlapStart, overlapEnd: Single;
Begin
  a := shape1.GetInterval(axis);
  b := shape2.GetInterval(axis);
  result := (b.val_min <= a.val_max) And (a.val_min <= b.val_max);
  If result Then Begin
    overlapStart := Max(a.val_min, b.val_min);
    overlapEnd := Min(a.val_max, b.val_max);
    Overlap := overlapEnd - overlapStart;
  End;
End;

Function Collide2Objects(Const A, B: TCorP3DCollider): Boolean;
Var
  p: TCorP3Plane;
  i: Integer;
  d: Single;
  c1, c2, ptA, ptB: TVector3;
  AchsisDepth, Depth: Single;
  TiniestAchsisIndex: Integer;
  SatColliderA, SatColliderB: TCorP3DCollider;
  ContactPointsA: TVector3Array;
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
      d := min(d, (B.fTransformedVertices[i] - p.fBasePoint) * p.fNormVector);
    End;
    If d < 0 Then Begin
      // Move B object "above" the plane
      B.Position := B.Position - p.fNormVector * d;
      B.Velocity := B.Velocity - (1 + p.fRestitution) * (B.Velocity * p.fNormVector) * p.fNormVector;
      result := true;
    End;
    exit;
  End;
  If (a Is TCorP3DCollider) And (b Is TCorP3DCollider) Then Begin
    // 1. "Fast" Check to early skip collision detection by comparing the collision spheres ..
    c1 := a.Matrix * a.fColliderSphere.Center;
    c2 := b.Matrix * b.fColliderSphere.Center;
    If LenV3SQR(c1 - c2) <= sqr(a.fColliderSphere.Radius + b.fColliderSphere.Radius) Then Begin
      // Detect collision by SAT algorithm inspired by https://www.youtube.com/watch?v=VmtNPguCTjQ
      result := true;
      AchsisDepth := max(a.fColliderSphere.Radius, b.fColliderSphere.Radius) * 2;
      TiniestAchsisIndex := -1;
      SatColliderA := a;
      SatColliderB := b;
      For i := 0 To high(A.fSATAchsis) Do Begin
        If col_overlap_axis(A, B, A.fTransformedSATAchsis[i], Depth) Then Begin
          If AchsisDepth > depth Then Begin
            TiniestAchsisIndex := i;
            AchsisDepth := Depth;
          End;
        End
        Else Begin
          result := false;
          exit;
        End;
      End;
      // We need to check all achsis of Both Objects ..
      For i := 0 To high(B.fSATAchsis) Do Begin
        If col_overlap_axis(B, A, B.fTransformedSATAchsis[i], Depth) Then Begin
          If AchsisDepth > depth Then Begin
            TiniestAchsisIndex := i;
            AchsisDepth := Depth;
            SatColliderA := b;
            SatColliderB := a;
          End;
        End
        Else Begin
          result := false;
          exit;
        End;
      End;
      // Berechnen des möglichst exakten "Kollisionspunktes"
//      ContactPointsA := SatColliderA.GetContactPoints(TiniestAchsisIndex);

      //      Das geht nicht, warum ?

//      ptA := SatColliderA.GetContactPoint(-SatColliderA.fTransformedSATAchsis[TiniestAchsisIndex]);
//      ptB := SatColliderB.GetContactPoint(SatColliderA.fTransformedSATAchsis[TiniestAchsisIndex]);
//      ContactPoint := (pta + ptb) / 2;
//      ColP := ContactPoint;

      //      SatColliderA.Mass := 0;
      //      SatColliderB.Mass := 0;

      //      exit;
            // Calculate Contact Point
            // We have a collision now move the Objects in order to not collide anymore
            // Case SatColliderA.Mass = 0 and SatColliderA.Mass = 0 is excluded on entry !
      If SatColliderA.Mass <> 0 Then Begin
        If SatColliderB.Mass <> 0 Then Begin
          // Both move 50 %
          // TODO: Hier fehlt noch die Beschleunigung, bzw damit auch die Berücksichtigung der Masse ...
          SatColliderA.Position := SatColliderA.Position - SatColliderA.fTransformedSATAchsis[TiniestAchsisIndex] * AchsisDepth / 2;
          SatColliderB.Position := SatColliderB.Position + SatColliderA.fTransformedSATAchsis[TiniestAchsisIndex] * AchsisDepth / 2;
        End
        Else Begin
          // Only A Moves
          SatColliderA.Position := SatColliderA.Position - SatColliderA.fTransformedSATAchsis[TiniestAchsisIndex] * AchsisDepth;
          SatColliderA.Velocity := SatColliderA.Velocity - (1 + SatColliderB.fRestitution) * (SatColliderA.Velocity * SatColliderA.fTransformedSATAchsis[TiniestAchsisIndex]) * SatColliderA.fTransformedSATAchsis[TiniestAchsisIndex];
        End;
      End
      Else Begin
        // Only B Moves
        SatColliderB.Position := SatColliderB.Position + SatColliderA.fTransformedSATAchsis[TiniestAchsisIndex] * AchsisDepth;
        SatColliderB.Velocity := SatColliderB.Velocity - (1 + SatColliderA.fRestitution) * (SatColliderB.Velocity * SatColliderA.fTransformedSATAchsis[TiniestAchsisIndex]) * SatColliderA.fTransformedSATAchsis[TiniestAchsisIndex];
      End;
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
  result.a := fTransformedVertices[0];
  result.B := result.a;
  For i := 1 To high(fvertices) Do Begin
    tmp := fTransformedVertices[i];
    result.a := MinV3(result.a, tmp);
    result.B := MaxV3(result.B, tmp);
  End;
End;

Function TCorP3DCollider.Collide(Const other: TCorP3DCollider): Boolean;
Begin
  result := Collide2Objects(self, other);
End;

Procedure TCorP3DCollider.Finish;
Var
  i, j: Integer;
  found: Boolean;
Begin
  If Not assigned(fvertices) Then Begin
    Raise exception.create('calling finish with no vertices');
  End;
  If fFinished Then exit;
  fFinished := true;
  (*
   * Precalc as much as possible !
   *)
  fColliderSphere := CalculateEncapsulatingSphere(fvertices);
  fConvexHullFaces := PointsToConvexHull(fvertices);
  // All Achses for SAT Calculation
  setlength(fSATAchsis, 0);
  For i := 0 To high(fConvexHullFaces) Do Begin
    found := false;
    For j := 0 To high(fSATAchsis) Do Begin
      If IsLinearDependent(fSATAchsis[j], fConvexHullFaces[i].Normal) Then Begin
        found := true;
        break;
      End;
    End;
    If Not found Then Begin
      setlength(fSATAchsis, high(fSATAchsis) + 2);
      fSATAchsis[high(fSATAchsis)] := fConvexHullFaces[i].Normal;
    End;
  End;
  setlength(fTransformedSATAchsis, length(fSATAchsis));
  setlength(fTransformedVertices, length(fVertices));
  UpdateTransformedValues();
End;

Procedure TCorP3DCollider.Step(aDelta: Single);
Var
  Acceleration: TVector3;
Begin
  If fMass = 0 Then exit;
  // Irgendwie muss die "interne" Verdrehung noch berücksichtigt werden
  Acceleration := fForce / fMass;

  fVelocity := fVelocity + Acceleration * aDelta;

  Position := Position + fVelocity * aDelta;
  // Update the Colliders Internals
  UpdateTransformedValues();
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
  fSATAchsis := Nil;
  fRestitution := 0;
End;

Destructor TCorP3DCollider.Destroy;
Begin
  setlength(fvertices, 0);
End;

Procedure TCorP3DCollider.SetPoints(Const aPoints: TVector3Array);
Begin
  fFinished := false;
  fvertices := aPoints;
End;

Function TCorP3DCollider.Getinterval(Const Axis: TVector3): TInterval;
Var
  i: integer;
  tmp: TBaseType;
Begin
  // Project all Vertices onto the axis and calculate min / max interval
  result.val_min := DotV3(fTransformedVertices[0], Axis);
  result.val_max := result.val_min;
  For i := 1 To high(fvertices) Do Begin
    tmp := DotV3(fTransformedVertices[i], Axis);
    result.val_min := min(result.val_min, tmp);
    result.val_max := max(result.val_max, tmp);
  End;
End;

Procedure TCorP3DCollider.UpdateTransformedValues;
Var
  i: Integer;
Begin
  For i := 0 To high(fVertices) Do Begin
    fTransformedVertices[i] := fMatrix * v4(fVertices[i], 1);
  End;
  fTransformedCenterOfMass := fMatrix * v4(fCenterOfMass, 1);
  For i := 0 To high(fSATAchsis) Do Begin
    fTransformedSATAchsis[i] := fMatrix * v4(fSATAchsis[i], 0);
  End;
End;

Function TCorP3DCollider.GetContactPoints(Const SATAchsisIndex: Integer
  ): TVector3Array;
Var
  i, j: Integer;
  v: TVector3;
  found: Boolean;
Begin
  result := Nil;
  // Search all convex hull faces by comparing the satAchsis Normals and collect
  // The their points
  For i := 0 To high(fConvexHullFaces) Do Begin
    If LenV3SQR(fConvexHullFaces[i].Normal - fSATAchsis[SATAchsisIndex]) <= Epsilon * Epsilon Then Begin
      // Add all Points of the face to result if not already existing.
      // TODO: rework code so that repetitive part is separated
      v := fTransformedVertices[fConvexHullFaces[i].a];
      found := false;
      For j := 0 To high(result) Do Begin
        If LenV3SQR(result[j] - v) <= Epsilon * Epsilon Then Begin
          found := true;
          break;
        End;
      End;
      If Not found Then Begin
        setlength(result, high(result) + 2);
        result[high(result)] := v;
      End;
      v := fTransformedVertices[fConvexHullFaces[i].b];
      found := false;
      For j := 0 To high(result) Do Begin
        If LenV3SQR(result[j] - v) <= Epsilon * Epsilon Then Begin
          found := true;
          break;
        End;
      End;
      If Not found Then Begin
        setlength(result, high(result) + 2);
        result[high(result)] := v;
      End;

      v := fTransformedVertices[fConvexHullFaces[i].c];
      found := false;
      For j := 0 To high(result) Do Begin
        If LenV3SQR(result[j] - v) <= Epsilon * Epsilon Then Begin
          found := true;
          break;
        End;
      End;
      If Not found Then Begin
        setlength(result, high(result) + 2);
        result[high(result)] := v;
      End;

    End;
  End;
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

