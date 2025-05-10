# CorP3D

Cor(psman)P(hysic)3D is my try to implement a 3D-Physics engine.

>
> ! Attention !
>
> This is a work in progress, don't expect anything to work yet, writing a 3D Physics engine
> is a really tough task, ..
> 

#### Why this engine?

When i started coding 3D games i used [Newton](http://newtondynamics.com/forum/newton.php), but since version 3 i have had to much trouble getting it to work, and the older versions are not available as source, so i was not able to continue using Newton.

Next i tried [Kraft](https://github.com/BeRo1985/kraft) which is written in FreePascal and used in Castle Game Engine. I even tried to create first [Examples](https://github.com/PascalCorpsman/kraft_examples) as there is barely no documentation for Kraft. Creating this examples i figured out some "issues" and did not get any responce from the creator. So i had no choice as to abandon this work too :/.

So what's next, well trying to write a own Physic engine ;).

To be honest i am not shure whether i will be ever able to get a working version, but at least i give it a try and even if i am not getting it to work, i hopefully will be able to learn something .. 

### What is the aim of this engine ?

- First priority is: understanding and writing 3D physics (i am a ok in IT, but with nearly no knowlege to physics 🙈)
- Second priority is: bring the engine to a point where i can use it in [balanced2](https://corpsman.de/index.php?doc=projekte/balanced2)

### What is the planned roadmap ?

- Basic convex hull collisions using the [SAT](https://dyn4j.org/2010/01/sat/) algorithm ✅
- Correct responce (Force  / Torque / Rotation)
- Compound collissions (concave objects)
- Support Planes ✅ (only static, not moving, not elastic)
- Support spheres
- Support cylinders
- Support cones ?
- Speedup the code execution by using all kind of optimizations like:
  - collision spheres (before SAT) ✅ 
  - [octree's](https://en.wikipedia.org/wiki/Octree)
  - further optimizations ?

### What is actually not on the roadmap ?

- joints, springs and all that high level stuff that is not needed for balanced2

This does not mean that there will be some point in far future where i include all that fancy stuff.

### You found bug or you know a good physics tutorial ?

Yes, please contact me, contribute to this project and help to improve it. 

### What is needed to compile and run the examples ?

1. clone this repository
2. download [uvectormath.pas](https://github.com/PascalCorpsman/Examples/blob/master/data_control/uvectormath.pas)

Now you have everything to compile the engine. In order to be able to compile the examples you also need to be able to use OpenGL:

1. install LazOpenGLControl into the Lazarus IDE
2. download [dglOpenGL.pas](https://github.com/SaschaWillems/dglOpenGL/blob/master/dglOpenGL.pas)

### Progress
- 2025.05.04: created repository, readme.md and license.md
- 2025.05.04: Implement basic Object structure, add plane and box, detect collisions between plane and box
- 2025.05.10: SAT Algorithm detects collision between convex hulls (no valid reaction yet)
