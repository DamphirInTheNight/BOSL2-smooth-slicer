// change at will
default_target_angle = 90;
default_remapping_vertices = 60;
default_slice_height = 1;
default_easing_function = "quint";

// easing functions
function easeIn(t) = t * t * t;
function easeOut(t) = 1 - pow(1 - t, 3);
function easeSin(t) = 0.5 - 0.5 * cos(180 * t);
function easeSmooth(t) = t * t * (3 - 2 * t);
function easeQuint(t) = t * t * t * (t * (6 * t - 15) + 10);

// easing dispatcher function
function easeFn(type, t) =
    type == "sine"  ? easeSin(t) :
    type == "quint" ? easeQuint(t) :
    type == "smooth" ? easeSmooth(t) :
    type == "in" ? easeIn(t) :
    type == "out" ? easeOut(t) :
    type == "linear" ? t :
    t;

// Bunch of basic function that may have already been integrated elsewhere
function is_cw(p) = sum([for (i=[0:len(p)-1]) let(j=(i+1)%len(p)) (p[j][0] - p[i][0]) * (p[j][1] + p[i][1])]) > 0;
    
function ensure_ccw(p) = is_cw(p) ? reverse(p) : p;

function pos_mod(n, m) = ((n % m) + m) % m;

function min_idx(lst) = let(m = min(lst)) [for (i = [0 : len(lst)-1]) if (lst[i] == m) i][0];

function lerp_path(pA, pB, s) = (1 - s) * pA + s * pB;

// Helper function in order to find spine segment based on Z height
function find_z_idx(spine, z, i = 0) = 
    (i >= len(spine) - 2 || spine[i+1][2] > z) ? i : find_z_idx(spine, z, i + 1);

function getProfileBoundingBox(points) = 
    let(
        yCoord = [for (p = points) p[0]],
        zCoord = [for (p = points) p[1]],
        min_y = min(yCoord),
        max_y = max(yCoord),
        min_z = min(zCoord),
        max_z = max(zCoord),
        length = max_y - min_y,
        height = max_z - min_z
    )
    [length, height, min_y, max_y, min_z, max_z];
        
// can be improved in many ways
// Aligns profile to the desired angle
function alignProfileByAngle(profile, targetAngle = default_target_angle) =
    let(
        center = mean(profile),
        
        // For each point calculates angle from center (-180° ~ +180°)
        angles = [for (p = profile) let(v = p - center) atan2(v.y, v.x)],
        
        // Normalizes angular differences
        angle_diffs = [for (a = angles) abs(pos_mod(a - targetAngle + 180, 360) - 180)],
        
        // Finds closest vertex index
        min_idx = min_idx(angle_diffs),
        n = len(profile)
    )
        
    // Rotates point list imposing found vertex at index 0
    [for (i = [0:n-1]) profile[(i + min_idx) % n]];

// concentrates all remapping profile function into a single one
function readaptProfile(profile, targetAngle = default_target_angle, def = default_remapping_vertices) = 
    alignProfileByAngle(ensure_ccw(resample_path(profile, n = def)), targetAngle);

// Extends previos function readapting profiles for both cases: single or list
function readaptProfiles(profiles, targetAngle = default_target_angle, def = default_remapping_vertices) =
    let(
        is_list_of_profiles = len(profiles) > 0 && is_list(profiles[0]) && is_list(profiles[0][0])
    )
    is_list_of_profiles ? [
        for (i = [0 : len(profiles) - 1])
            readaptProfile(profiles[i], targetAngle, def)
    ] : readaptProfile(profiles, targetAngle, def);

//
// LINEAR SLICING & SKINNING 
//
function smoothSlice(profiles, heights, easings = default_easing_function, sliceHeight = default_slice_height) = [
    for (i = [0 : len(profiles)-2])
        let(
            seg_height = heights[i+1] - heights[i],
            seg_slices = max(1, round(seg_height / sliceHeight)),
            curr_easing = is_list(easings) ? easings[min(i, len(easings)-1)] : easings
        )
        for (step = [0 : (i == len(profiles)-2 ? seg_slices : seg_slices-1)])
            let(
                t = step / seg_slices,
                s = easeFn(curr_easing, t),
                p_interp = lerp_path(profiles[i], profiles[i+1], s),
                z_interp = lerp(heights[i], heights[i+1], t)
            )
            path3d(p_interp, z_interp)
];

// Extracts a shape at specific distance along x axis so that extruded complex shapes
//  along Z axis can be used for orthogonal purposes
function smoothProjection(profiles, heights, easings = default_easing_function, sliceHeight = default_slice_height, targetAngle = default_target_angle, def = default_remapping_vertices, xCut = 0) =
    let(
        slices = smoothSlice(readaptProfiles(profiles, targetAngle, def), heights, easings, sliceHeight),
        
        left_side = [
            for (slice = slices)
                let(
                    z_val = slice[0][2],
                    y_ints = [
                        for (j = [0 : len(slice) - 1])
                            let(
                                p1 = slice[j], p2 = slice[(j + 1) % len(slice)],
                                x1 = p1[0], x2 = p2[0], y1 = p1[1], y2 = p2[1]
                            )
                            if ((x1 <= xCut && x2 > xCut) || (x1 >= xCut && x2 < xCut))
                                y1 + (xCut - x1) / (x2 - x1) * (y2 - y1)
                    ]
                )
                if (len(y_ints) >= 2) [min(y_ints), z_val]
        ],
        
        right_side = [
            for (i = [len(slices) - 1 : -1 : 0])
                let(
                    slice = slices[i],
                    z_val = slice[0][2],
                    y_ints = [
                        for (j = [0 : len(slice) - 1])
                            let(
                                p1 = slice[j], p2 = slice[(j + 1) % len(slice)],
                                x1 = p1[0], x2 = p2[0], y1 = p1[1], y2 = p2[1]
                            )
                            if ((x1 <= xCut && x2 > xCut) || (x1 >= xCut && x2 < xCut))
                                y1 + (xCut - x1) / (x2 - x1) * (y2 - y1)
                    ]
                )
                if (len(y_ints) >= 2) [max(y_ints), z_val]
        ]
    )
    concat(left_side, right_side);

// Performs linear skin accepting easings as string or list
module smoothSkin(profiles, heights, easings = default_easing_function, sliceHeight = default_slice_height, targetAngle = default_target_angle, def = default_remapping_vertices) {

    skin(
        smoothSlice(readaptProfiles(profiles, targetAngle, def), heights, easings, sliceHeight),
        method = "direct",
        slices = 0, 
        refine = 1
    );
}

//
// 2D PATH SLICING & SKINNING 
//

function makeSpine(h1, radius, angle, l2, steps = 20) = 
    concat(
        // vertical start length
        [ for (i = [0 : steps-1]) [0, 0, (h1 * i) / steps] ],
        
        // Arc along XZ axis
        [ for (i = [0 : steps]) let(t = (i / steps) * angle) [radius * (1 - cos(t)), 0, h1 + radius * sin(t)] ],
        
        // ending linear length from tangent
        let(
            p_end = [radius * (1 - cos(angle)), 0, h1 + radius * sin(angle)],
            tan_end = [sin(angle), 0, cos(angle)]
        )
        [ for (i = [1 : steps]) p_end + tan_end * (l2 * i / steps) ]
    );
    
module showSpine(spine_points, radius = 0.5) {
    // Usa stroke di BOSL2 per tracciare il percorso 3D
    stroke(spine_points, width = radius);
    
    // Mostra le sfere nei punti chiave per debug
    for (p = spine_points) {
        translate(p) color("red") sphere(r = radius * 1.5);
    }
}

// Slices along 2D path considering normals according to spine
// It preserves heights except for curves, so that exceeding original model's height
// won't affect final geometry
function smoothSlicePath(profiles, heights, spine, easings = default_easing_function, sliceHeight = default_slice_height) = [
    for (i = [0 : len(profiles)-2])
        let(
            seg_height = heights[i+1] - heights[i],
            seg_slices = max(1, round(seg_height / sliceHeight)),
            curr_easing = is_list(easings) ? easings[min(i, len(easings)-1)] : easings
        )
        for (step = [0 : (i == len(profiles)-2 ? seg_slices : seg_slices-1)])
            let(
                t = step / seg_slices,
                s = easeFn(curr_easing, t),
                p_interp = lerp_path(profiles[i], profiles[i+1], s),
                z_interp = lerp(heights[i], heights[i+1], t),
                
                // Trova il punto e la tangente sulla spine corrispondenti a z_interp
                k = find_z_idx(spine, z_interp),
                k1 = min(k + 1, len(spine) - 1),
                dz = spine[k1][2] - spine[k][2],
                u = (dz == 0) ? 0 : (z_interp - spine[k][2]) / dz,
                
                p_spine = (k == k1) ? spine[k] : lerp(spine[k], spine[k1], u),
                tan = (k == k1) ? [0,0,1] : unit(spine[k1] - spine[k]),
                
                m = move(p_spine) * rot(from=[0,0,1], to=tan)
            )
            [ for (pt = apply(m, path3d(p_interp))) pt ]
];
            
// Performs skin along 2d path accepting easings as string or list
module smoothSkinPath(profiles, heights, spine, easings = default_easing_function, sliceHeight = default_slice_height, targetAngle = default_target_angle, def = default_remapping_vertices) {
    
    skin(
        smoothSlicePath(readaptProfiles(profiles, targetAngle, def), heights, spine, easings, sliceHeight),
        method = "direct",
        slices = 0, 
        refine = 1
    );
}