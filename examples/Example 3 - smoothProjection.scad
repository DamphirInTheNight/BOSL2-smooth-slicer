include <BOSL2/std.scad>
include <smoothSlicer.scad>

$fn = 40;
$fa = 2;
radius_definition = 40;
sstep = 1;
sliceHeight = 0.5;
N = 72;
targetAngle = 90;

profile1 = rect([20, 15], rounding = 5, $fa = sstep, $fn = radius_definition);
profile2 = rect([18, 14], rounding = 4, $fa = sstep, $fn = radius_definition);
profile3 = supershape(step = sstep, m1=4, n1=12, n2=9, n3=5.5, a=8, b=9.7, d=12);
profile4 = circle(d=22, $fa = sstep, $fn = radius_definition);

profiles = [profile1, profile1, profile2, profile3, profile4 ];

heights = [ 0, 1.5, 6 , 10, 80];

easings = [ "linear", "out", "out", "quint" ];

//smoothSkin(profiles, heights, easings, slice_height);

for (i = [0 : 11]) {
   
    translate([i * 25, 0, 0])
        polygon(points = smoothProjection(profiles, heights, easings, sliceHeight, targetAngle, N, xCut = i));
}

