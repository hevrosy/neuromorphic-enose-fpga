// ============================================================================
// PROJECT: Advanced E-Nose Fluidic Chamber
// VERSION: 1.2.4 (Fully Parametric, DFM & Aerodynamic Wide-Body Edition)
// DESCRIPTION: A dual-loop, spatiotemporally optimized fluidic plenum for 
// Metal-Oxide (MOX) gas sensor arrays. Features support-free FDM topology, 
// active viscoelastic vibration damping (TPU), and mathematically constrained 
// laminarization for Machine Learning DAQ.
// ============================================================================

$fn = 60; // Curve resolution (60 is optimal for smooth FDM printed cylinders)

// ============================================================================
// PARAMETRIC CONTROL PANEL
// ============================================================================

// Select the rendering mode:
// "assembly"        - Full 3D exploded view of all components
// "print_layout"    - All parts arranged flat on the build plate (Z=0)
// "part_base"       - Export Base only
// "part_plate"      - Export Sensor Plate only
// "part_diffuser"   - Export Honeycomb Diffuser only
// "part_lid"        - Export Main Lid only
// "part_dome"       - Export Wide-Body Fan Dome only
// "tpu_lid_gaskets" - Export Main O-Rings (TPU)
// "tpu_purge_plug"  - Export Ergonomic Purge Valve Plug (TPU)
// "tpu_fan_gasket"  - Export Fan Suspension Gasket (Print x2) (TPU)
// "tpu_washers"     - Export Dome Bolt Washers x4 (TPU)
// "tpu_feet"        - Export Shock-Absorbing Base Feet x4 (TPU)

view_mode = "print_layout"; 

// --- GLOBAL CHAMBER DIMENSIONS ---
fc_w = 144;          // Outer width of the base (mm)
fc_l = 144;          // Outer length of the base (mm)
fc_h = 60;           // Internal height of the primary air column (mm)
fc_r = 15;           // Outer corner radius (improves internal cyclonic flow)
wall_t = 4.0;        // Outer wall thickness (4mm ensures zero-porosity in FDM)
bot_t  = 4.0;        // Base floor thickness (mm)

// --- HARDWARE FASTENERS (Brass Heat-set Inserts) ---
insert_d = 4.2;      // Diameter of the heat-set insert pocket (Standard M3)
insert_h = 5.5;      // Depth of the heat-set insert (mm)

// --- INTERNAL ARCHITECTURE ---
standoff_d = 9.0;    // Diameter of the sensor plate standoffs
standoff_h = 10.0;   // Standoff height (leaves 10mm clearance for wiring)
sp_mount_xy = 100;   // Sensor plate mounting hole spacing (100x100mm square)
hole_off = 78.0;     // Position of the 8 perimeter clamping bolts

// --- FAN SPECIFICATIONS (Target: Sunon EE60201B1) ---
fan_size = 62;       // Outer footprint of the fan frame (60mm + 2mm tolerance)
fan_hole = 58;       // Diameter of the active fan blade intake
fan_mount = 25;      // Mounting hole offset from center (+/- 25mm for 60mm fan)
fan_thickness = 20;  // Fan thickness (Parametrically dictates dome height)

// --- VISCOELASTIC GASKETS AND TOLERANCES ---
tpu_t = 1.2;         // Thickness of a single TPU fan isolation gasket
gasket_h = 3.2;      // Depth of the O-ring grooves in the lid
tol = 0.2;           // General 3D printing clearance tolerance

// --- AUTOMATICALLY CALCULATED VARIABLES ---
h_out = fc_h + bot_t; // Total outer height of the base
// Exact Z-height where the dome's inner pillars must stop to clamp the fan
// Math: Fan thickness + 2x TPU - lid pocket depth (6.1mm) - 0.3mm (crush tolerance)
dome_clamp_z = fan_thickness + (2 * tpu_t) - 6.1 - 0.3; 

// ----------------------------------------------------------------------------
// COMPONENT 1: FLOW CHAMBER BASE
// ----------------------------------------------------------------------------
module flow_chamber() {
    difference() {
        union() {
            difference() { flared_box(fc_w, fc_l, fc_r); inner_void(fc_w, fc_l, fc_r); }
            // Tapered standoffs for structural rigidity
            for(x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
                translate([x, y, bot_t]) cylinder(h=standoff_h, d1=standoff_d + 4, d2=standoff_d);
            }
            // Pneumatic port bosses
            translate([-(fc_w/2) - wall_t + 2, 40, h_out - 20]) rotate([0, -90, 0]) cylinder(h=12, d=24);
            translate([-(fc_w/2) - wall_t + 2, -40, bot_t + 15]) rotate([0, -90, 0]) cylinder(h=10, d=14);
            // Wire potting bay balcony
            translate([(fc_w/2) + 6, 0, 11]) cube([12, 32, 14], center=true);
        }
        
        // Heat-set insert pockets
        for (pos = [[hole_off, hole_off], [-hole_off, hole_off], [hole_off, -hole_off], [-hole_off, -hole_off],
                    [0, hole_off], [0, -hole_off], [hole_off, 0], [-hole_off, 0]]) {
            translate([pos[0], pos[1], h_out - insert_h]) cylinder(h=insert_h + 1, d=insert_d);
        }
        for(x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
            translate([x, y, bot_t + standoff_h - insert_h]) cylinder(h=insert_h + 1, d=insert_d);
        }
        
        // Pneumatic tunnels
        translate([-86.1, 40, h_out - 20]) rotate([0, 90, 0]) cylinder(h=25, d1=16.5, d2=13.5); // 16mm Purge
        translate([-84.1, -40, bot_t + 15]) rotate([0, 90, 0]) cylinder(h=25, d=5.4);           // M6 Thread
        
        // Hot glue wire potting funnels
        translate([(fc_w/2) - 2, 0, 9]) cube([6, 14, 6], center=true); 
        hull() { 
            translate([(fc_w/2) + 1, 0, 9]) cube([0.1, 14, 6], center=true); 
            translate([(fc_w/2) + 12, 0, 15]) cube([0.1, 28, 18], center=true); 
        }
        translate([(fc_w/2) + 8, 0, 18]) cube([14, 34, 14], center=true); 
        
        // Push-fit pockets for TPU isolation feet
        for(x=[-65, 65], y=[-65, 65]) { translate([x, y, -0.1]) cylinder(h=3.5, d=4.0); }
    }
}

// ----------------------------------------------------------------------------
// COMPONENT 2: UNIVERSAL SENSOR PLATE
// ----------------------------------------------------------------------------
module sensor_plate() {
    difference() {
        rounded_box(125, 125, 3, 5); 
        for(x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) { translate([x, y, -1]) cylinder(h=5, d=3.4); }
        translate([(125/2) - 5, 0, 1.5]) cube([15, 30, 5], center=true);
        // Universal 3.2mm grid for diverse sensor arrays
        for(x = [-50 : 7 : 50], y = [-50 : 7 : 50]) {
            if(sqrt(pow(x - sp_mount_xy/2, 2) + pow(y - sp_mount_xy/2, 2)) > 8 && 
               sqrt(pow(x + sp_mount_xy/2, 2) + pow(y - sp_mount_xy/2, 2)) > 8 &&
               sqrt(pow(x - sp_mount_xy/2, 2) + pow(y + sp_mount_xy/2, 2)) > 8 &&
               sqrt(pow(x + sp_mount_xy/2, 2) + pow(y + sp_mount_xy/2, 2)) > 8 &&
               !(x > 45 && y > -20 && y < 20)) {
                translate([x, y, -1]) cylinder(h=5, d=3.2);
            }
        }
    }
}

// ----------------------------------------------------------------------------
// COMPONENT 3: HONEYCOMB DIFFUSER (Laminarization Matrix)
// ----------------------------------------------------------------------------
module diffuser_insert() {
    diff_h = 40; 
    difference() {
        union() {
            difference() { rounded_box(114, 114, 8, 10); translate([0, 0, -1]) rounded_box(110, 110, 10, 8); }
            intersection() { rounded_box(110, 110, 8, 8); hex_grid(114, 114, 8, 3.5, 1.2); }
            for (x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) { translate([x, y, 0]) cylinder(h=diff_h, d=12); }
        }
        for (x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
            translate([x, y, -1]) cylinder(h=diff_h + 2, d=3.4);
            translate([x, y, -0.1]) cylinder(h=2.2, d1=6.5, d2=3.4); 
        }
    }
}

// ----------------------------------------------------------------------------
// COMPONENT 4: AERODYNAMIC LID (Fluidic Routing)
// ----------------------------------------------------------------------------
module lid_pro() {
    lid_h = 26; 
    difference() {
        rounded_box(162, 162, lid_h, 19);
        // O-ring gasket grooves
        translate([0, 0, -0.1]) difference() { rounded_box(151.4, 151.4, 2.5, 20.7); translate([0,0,-1]) rounded_box(144.6, 144.6, 4.5, 17.3); }
        translate([0, 0, lid_h - 2.4]) difference() { rounded_box(94, 94, 2.5, 10); translate([0,0,-1]) rounded_box(94 - 6.8, 94 - 6.8, 4.5, 10 - 3.4); }
        
        // Perimeter clamp holes
        for (pos = [[hole_off, hole_off], [-hole_off, hole_off], [hole_off, -hole_off], [-hole_off, -hole_off], [0, hole_off], [0, -hole_off], [hole_off, 0], [-hole_off, 0]]) {
            translate([pos[0], pos[1], -1]) cylinder(h=lid_h + 2, d=3.4);
            translate([pos[0], pos[1], lid_h - 2]) cylinder(h=2.1, d1=3.4, d2=6.5);
        }
        
        // Active fan pocket
        translate([0, 0, lid_h]) cube([fan_size, fan_size, 12.2], center=true);
        for(x=[-fan_mount, fan_mount], y=[-fan_mount, fan_mount]) { 
            translate([x, y, lid_h - 6.1 - insert_h]) cylinder(h=insert_h + 0.1, d=insert_d);
            translate([x, y, lid_h - 6.1 - insert_h - 8]) cylinder(h=8.1, d=3.5);
        }
        
        // Aerodynamic deflector cone
        translate([0, 0, lid_h - 11]) difference() { cylinder(h=8.1, d=fan_hole); translate([0, 0, -0.1]) cylinder(h=8, d1=45, d2=0); }
        
        // 3D cyclonic tangential ducts
        for(i=[0:90:270]) {
            rotate([0, 0, i]) {
                hull() { translate([15, 8, 14]) sphere(d=16); translate([38, 15, 8]) sphere(d=15); }
                hull() { translate([38, 15, 8]) sphere(d=15); translate([54, 32, -2]) sphere(d=14); }
                hull() { translate([54, 32, -2]) sphere(d=14); translate([45, 52, -2]) sphere(d=14); }
            }
        }
        
        // 6.5mm engineered choke points (Controls Delta P)
        for(pos = [[0, 38], [0, -38], [38, 0], [-38, 0]]) { translate([pos[0], pos[1], -1]) cylinder(h=lid_h + 2, d=6.5); }
    }
}

// ----------------------------------------------------------------------------
// COMPONENT 5: DOME (Wide-Body Aerodynamic Shell)
// ----------------------------------------------------------------------------
module fan_dome_ultimate() { 
    th = 32; 
    ow = 98; 
    
    difference() { 
        // 1. OUTER SHELL (82x82 upper bounds to maintain 4mm uniform wall)
        union() { 
            rounded_box(ow, ow, 4, 8); 
            hull() { 
                translate([0, 0, 4]) rounded_box(92, 92, 0.1, 8); 
                translate([0, 0, dome_clamp_z]) rounded_box(82, 82, 0.1, 8); 
                translate([0, 0, th - 4]) rounded_box(82, 82, 4, 8); // Solid 4mm roof block
            } 
        } 
        
        // 2. INNER VOID (74x74 creates a massive 7mm bypass gap around the 60mm fan)
        difference() {
            union() {
                translate([0, 0, -0.1]) rounded_box(84, 84, 4.2, 4); 
                hull() { 
                    translate([0, 0, 4]) rounded_box(84, 84, 0.1, 4); 
                    translate([0, 0, dome_clamp_z]) rounded_box(74, 74, 0.1, 4); 
                }
                hull() { 
                    translate([0, 0, dome_clamp_z]) rounded_box(74, 74, 0.1, 4);
                    translate([0, 0, th - 4 + 0.1]) rounded_box(74, 74, 0.1, 4); 
                }
            }
            // Safeguard solid pillars for clamping load
            for(x=[-fan_mount, fan_mount], y=[-fan_mount, fan_mount]) { 
                translate([x, y, dome_clamp_z]) cylinder(h=th, d=10); 
            } 
        }
        
        // 3. COUNTERBORES
        for(x=[-fan_mount, fan_mount], y=[-fan_mount, fan_mount]) { 
            translate([x, y, -1]) cylinder(h=th+2, d=4.2); 
            translate([x, y, 20.0]) cylinder(h=th, d=8.5); 
        } 
        
        // 4. PNEUMATIC & WIRING PORTS
        translate([0, -(ow/2), 17]) rotate([90, 0, 0]) cylinder(h=30, d=5, center=true); 
        translate([0, 0, th - 5]) cylinder(h=10, d=5.4); 
    } 
}

// ============================================================================
// MODULAR VISCOELASTIC COMPONENTS (TPU 95A)
// ============================================================================

module tpu_lid_gaskets() {
    difference() { rounded_box(151.4 - tol, 151.4 - tol, gasket_h, 20.7); translate([0, 0, -1]) rounded_box(144.6 + tol, 144.6 + tol, gasket_h + 2, 17.3); }
    translate([130, 0, 0]) difference() { rounded_box(94 - tol, 94 - tol, gasket_h, 10); translate([0, 0, -1]) rounded_box(87.2 + tol, 87.2 + tol, gasket_h + 2, 6.6); }
}

module tpu_purge_plug() {
    // Features an ergonomic teardrop pull-tab for support-free horizontal printing
    union() {
        cylinder(h=14, d1=14.5, d2=16.5);
        translate([0, 0, 14]) hull() {
            cylinder(h=3, d=22); 
            translate([15, 0, 0]) cylinder(h=3, d=10); 
        }
    }
}

module tpu_fan_gasket() {
    difference() {
        rounded_box(60, 60, tpu_t, 4); 
        translate([0, 0, -1]) cylinder(h=4, d=58);
        for(x=[-fan_mount, fan_mount], y=[-fan_mount, fan_mount]) { translate([x, y, -1]) cylinder(h=4, d=4.2); }
    }
}

module tpu_washers() {
    for(x=[-15, 15], y=[-15, 15]) { 
        translate([x, y, 0]) difference() { cylinder(h=1.2, d=7.5); translate([0, 0, -1]) cylinder(h=4, d=3.4); } 
    }
}

module tpu_feet() {
    for(x=[-20, 20], y=[-20, 20]) { 
        translate([x, y, 0]) union() { cylinder(h=4, d1=16, d2=12); translate([0, 0, 4]) cylinder(h=3.2, d=4.2); } 
    }
}

// --- GEOMETRIC HELPERS ---
module rounded_box(w, l, h, r) { if(h>0) hull() { for(x=[-(w/2)+r, (w/2)-r], y=[-(l/2)+r, (l/2)-r]) translate([x, y, 0]) cylinder(h=h, r=r); } }
module flared_box(w_in, l_in, r) { w_out = w_in + 2*wall_t; l_out = l_in + 2*wall_t; union() { rounded_box(w_out, l_out, h_out - 11, r + wall_t); hull() { translate([0, 0, h_out - 11.1]) rounded_box(w_out, l_out, 0.1, r + wall_t); translate([0, 0, h_out - 6]) rounded_box(w_out + 10, l_out + 10, 0.1, r + wall_t + 2); } translate([0, 0, h_out - 6]) rounded_box(w_out + 10, l_out + 10, 6, r + wall_t + 2); } }
module inner_void(w_in, l_in, r) { translate([0, 0, bot_t]) rounded_box(w_in, l_in, fc_h + 1, r); }
module hex_grid(w, l, h, cr, wt) { x_s = cr*1.5; y_s = cr*sqrt(3); difference() { translate([0,0,h/2]) cube([w,l,h], center=true); for(x=[-w/2:x_s:w/2+x_s], y=[-l/2:y_s:l/2+y_s]) { y_o = (round(x/x_s)%2==0)?0:y_s/2; translate([x,y+y_o,-1]) cylinder(h=h+2, r=cr-(wt/2), $fn=6); } } }

// ============================================================================
// RENDER ENGINE LOGIC
// ============================================================================
if (view_mode == "assembly") {
    explode_gap = 35; 
    diff_h = 40; 
    
    color("SteelBlue", 0.8) flow_chamber();
    color("DeepSkyBlue") { for(x=[-65, 65], y=[-65, 65]) { translate([x, y, -5 - explode_gap/2]) union() { cylinder(h=4, d1=16, d2=12); translate([0, 0, 4]) cylinder(h=3.2, d=4.2); } } }
    color("LimeGreen") translate([0, 0, bot_t + standoff_h + explode_gap]) sensor_plate();
    color("DarkOrange") translate([0, 0, bot_t + standoff_h + diff_h + explode_gap*2]) rotate([180,0,0]) diffuser_insert();
    color("DeepSkyBlue", 0.9) translate([0, 0, h_out + explode_gap*3]) difference() { rounded_box(151.4 - tol, 151.4 - tol, gasket_h, 20.7); translate([0, 0, -1]) rounded_box(144.6 + tol, 144.6 + tol, gasket_h + 2, 17.3); }
    color("LightSlateGray", 0.9) translate([0, 0, h_out + explode_gap*4]) lid_pro();
    color("DeepSkyBlue", 0.9) translate([0, 0, h_out + 26 - 3 + explode_gap*4.5]) tpu_fan_gasket();
    color("DeepSkyBlue", 0.9) translate([0, 0, h_out + 26 + fan_thickness/2 + explode_gap*5.5]) tpu_fan_gasket();
    color("DeepSkyBlue", 0.9) translate([0, 0, h_out + 26 - 2.4 + explode_gap*6]) difference() { rounded_box(94 - tol, 94 - tol, gasket_h, 10); translate([0, 0, -1]) rounded_box(87.2 + tol, 87.2 + tol, gasket_h + 2, 6.6); }
    color("Beige", 0.9) translate([0, 0, h_out + 26 + explode_gap*7]) fan_dome_ultimate();
    color("DeepSkyBlue", 0.9) { for(x=[-fan_mount, fan_mount], y=[-fan_mount, fan_mount]) { translate([x, y, h_out + 26 + 20.0 + explode_gap*7.5]) difference() { cylinder(h=1.2, d=7.5); translate([0, 0, -1]) cylinder(h=4, d=3.4); } } }
    color("DeepSkyBlue", 0.9) translate([-(fc_w/2) - wall_t - 20, 40, h_out - 20]) rotate([0, 90, 0]) tpu_purge_plug();
    
} else if (view_mode == "print_layout") {
    color("SteelBlue")      translate([0, 0, 0]) flow_chamber();
    color("LimeGreen")      translate([-180, 0, 0]) sensor_plate();
    color("DarkOrange")     translate([180, 0, 0]) diffuser_insert();
    color("LightSlateGray") translate([0, 180, 0]) lid_pro();
    color("Beige")          translate([-180, 180, 0]) fan_dome_ultimate();
    
    color("DeepSkyBlue") {
        translate([200, -50, 0]) tpu_lid_gaskets();
        translate([200, 100, 0]) tpu_fan_gasket();
        translate([280, 100, 17]) rotate([180, 0, 0]) tpu_purge_plug();
        translate([200, 160, 0]) tpu_washers();
        translate([260, 160, 0]) tpu_feet();
    }
} 
// INDIVIDUAL PART EXPORT LOGIC
else if (view_mode == "part_base") { flow_chamber(); }
else if (view_mode == "part_plate") { sensor_plate(); }
else if (view_mode == "part_diffuser") { diffuser_insert(); }
else if (view_mode == "part_lid") { lid_pro(); }
else if (view_mode == "part_dome") { fan_dome_ultimate(); }
else if (view_mode == "tpu_lid_gaskets") { tpu_lid_gaskets(); }
else if (view_mode == "tpu_purge_plug") { translate([0, 0, 17]) rotate([180, 0, 0]) tpu_purge_plug(); }
else if (view_mode == "tpu_fan_gasket") { tpu_fan_gasket(); }
else if (view_mode == "tpu_washers") { tpu_washers(); }
else if (view_mode == "tpu_feet") { tpu_feet(); }
