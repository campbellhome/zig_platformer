## bugs

- visually got embedded in one block, but could still move side to side and jump

## possibly-fixed bugs

## cleanup

## short-term features

- stamina
- stamina/dash recharge pellets
- timer
- end block
- quick restart
- spikes
- levels, and moving between rooms
- better level specification
- camera support for rooms larger than one screen
- jump height determined by holding jump longer
- restrict jump to when you are (1) walking, (b) hanging, or (2) falling next to a hang-able wall
- color movement modes (walk, hang, jump, fall, dash)

## long-term features

- sounds
- music - see https://github.com/floooh/sokol-samples/blob/master/sapp/modplay-sapp.c
- YOU ARE A JUICE BOX.  A TRANSLUCENT JUICE BOX.  STAMINA IS JUICE DRAINING.  NEED SLOSHING.

## finished features

- option to quantize dash dir in 45 degree buckets
- moving platforms
- images/textures

## finished cleanup

- rename world to room

## fixed bugs

- can wall grab too low and not be able to move
- coyote time continues during downward dash and prevents the slowdown at end of dash
- coyote time should end when not moving or when input dir is down

