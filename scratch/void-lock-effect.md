Ok great. Here's what I'm envisioning
1. back up void_lock_fx_parts.aseprite before we make changes

2. For the in-game void lock effect:
+ seven void fizzles, which originate at random places along the border (not too close to each other)
 - problem: you made these originate at the center of the animation, which for 99% of our animations, is correct. In this case, void fizzles' origin is at their bottom left corner.
+ void bubbles appear in random places, at roughly the rate that Lawrence had animated in the mock-up.
+ void star and void star lines: this one's tricky. what Lawrence did was make a void star appear, then another appear to the right, and it looks like some particle is racing along the "line," causing the star to animate, then continuing along to the next star.
We obviously can't spawn stars completely at random to get the effect, but I'd like it to look not like a looping animation. Any ideas here?

## 
+ This is looking pretty good.
+ One thing I don't like is that the smoke FX stop as soon as their animation ends, which causes smoke particles to dissipate early. We might want to implement the smoke programmatically, which actually shouldn't be that hard - I'll explain how Lawrence animated these by hand.
1a create a variable for the left bound - I *think* Lawrence used 15°
1b create a variable for the right bound - I think Lawrence used 30°
1c create a variable for the innermost despawn boundary (not sure what Lawrence used here)
1d create a variable for the outermost despawn boundary
1e (optional?) I don't think Lawrence gave much thought to this, but you can also apply a range for the velocity of the particles.
2a pick a random trajectory between these bounds
2b spawn a pixel and have it travel along that trajectory
2c if the pixel is between pixels at reference resolution, pick the pixel which it is "most in" to render so that it doesn't flicker (we're doing something like this for the between turn animations with the stars parallax effect)
2d despawn the pixel at a random point between the two despawn boundaries
3 when you decide to despawn the smoke stream and spawn a new one, the particles stop spawning, but don't disappear until they've reached the despawn boundary.

## Let's...
+ add a spawn rate variable and lower it
+ change the angles to 15° to 45°