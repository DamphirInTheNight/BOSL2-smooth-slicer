include <BOSL2/std.scad>
include <smoothSlicer.scad>

$fn = 40;
$fa = 2;
radius_definition = 40;
sstep = 1;
slice_height = 0.5;
N = 72;
remapping_angle = 90;

firstVertLength = 10;
bendingRadius = 60;
bendingAngle = 30;
exitStraightLength = 20;
bendingSteps = 15;

spine = makeSpine(firstVertLength, bendingRadius, bendingAngle, exitStraightLength, steps = bendingSteps);

profile1 = rect([20, 15], rounding = 5, $fa = sstep, $fn = radius_definition);
profile2 = rect([18, 14], rounding = 4, $fa = sstep, $fn = radius_definition);
profile3 = supershape(step = sstep, m1=4, n1=12, n2=9, n3=5.5, a=8, b=9.7, d=10);
profile4 = circle(d=18, $fa = sstep, $fn = radius_definition);

profiles = [profile1, profile1, profile2, profile3, profile4];
heights = [0, 1.5, 7 , 30, 80, ];
easings = [ "linear", "out", "out", "quint" ];

smoothSkinPath(profiles, heights, spine, easings, slice_height, remapping_angle, N);

