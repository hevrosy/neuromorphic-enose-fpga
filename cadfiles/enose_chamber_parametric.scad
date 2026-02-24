// ============================================================================
// PROJECT: Advanced E-Nose Fluidic Chamber
// VERSION: 1.0.0 (Ultimate Aerodynamic Release)
// DESCRIPTION: A professional, 100% support-free FDM 3D printable chamber 
//              for Electronic Nose (VOC) sensor arrays. Features a closed-loop 
//              tangential vortex airflow, zero-leak TPU gaskets, and universal 
//              sensor mounting.
// ============================================================================

$fn = 60; // Curve resolution for smooth 3D printing

// ============================================================================
// 🎛️ PARAMETER CONTROL PANEL
// ============================================================================

// --- 1. VIEW MODE ---
// Change to "assembly" to see the exploded 3D CAD view.
// Change to "print_layout" to arrange all parts flat on the XY plane for STL export.
view_mode = "assembly"; 

// --- 2. GLOBAL DIMENSIONS (MAIN CHAMBER) ---
fc_w = 144;          // Internal chamber width (X)
fc_l = 144;          // Internal chamber length (Y)
fc_h = 60;           // Internal depth (~1.2L total volume)
fc_r = 15;           // Internal corner radius (promotes smooth cyclonic airflow)
wall_t = 4.0;        // Outer wall thickness (4mm ensures structural rigidity & airtightness)
bot_t  = 4.0;        // Bottom thickness

// --- 3. HARDWARE FASTENERS ---
insert_d = 4.2;      // Hole diameter for M3 heat-set inserts
insert_h = 5.5;      // Depth for M3 heat-set inserts
standoff_d = 9.0;    // Outer diameter of the internal printed standoffs
standoff_h = 10.0;   // Height of base standoffs (provides wire routing space underneath)

// --- 4. MOUNTING SPACING (CRITICAL) ---
sp_mount_xy = 100;   // Spacing between the 4 core assembly bolts (100x100mm square)
hole_off = 78.0;     // Position of the 8 main lid bolts (156x156mm square)

// --- 5. FAN SPECIFICATIONS ---
fan_size = 62;       // Fan recess width (60x60mm fan + 2mm tolerance)
fan_hole = 58;       // Main intake hole diameter
fan_mount = 25;      // Distance from center to fan mounting holes (50mm spacing)

// --- 6. TPU GASKET SETTINGS ---
gasket_h = 3.2;      // Print height (Crushes down to 2.4mm when bolts are tightened)
tol = 0.2;           // Tolerance clearance for snug fit into grooves

// ============================================================================
// 🛠️ GEOMETRY GENERATION
// ============================================================================
h_out = fc_h + bot_t; // Total calculated outer base height

// ----------------------------------------------------------------------------
// COMPONENT 1: FLOW CHAMBER BASE
// Features 2x PC4-M6 pneumatic ports and an external wire potting cup.
// ----------------------------------------------------------------------------
module flow_chamber() {
    difference() {
        union() {
            difference() { flared_box(fc_w, fc_l, fc_r); inner_void(fc_w, fc_l, fc_r); }
            
            // Internal standoffs for the core sensor stack
            for(x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
                translate([x, y, bot_t]) cylinder(h=standoff_h, d1=standoff_d + 4, d2=standoff_d);
            }
            
            // Pneumatic port bosses (Left Wall)
            translate([-(fc_w/2) - wall_t + 2, 40, h_out - 18]) rotate([0, -90, 0]) cylinder(h=10, d=14);
            translate([-(fc_w/2) - wall_t + 2, -40, bot_t + 15]) rotate([0, -90, 0]) cylinder(h=10, d=14);
            
            // External wire potting cup (Right Wall)
            translate([(fc_w/2) + wall_t + 2, 0, 42]) cube([12, 24, 18], center=true);
        }
        
        // Blind holes for Lid M3 heat-set inserts
        for (pos = [[hole_off, hole_off], [-hole_off, hole_off], [hole_off, -hole_off], [-hole_off, -hole_off],
                    [0, hole_off], [0, -hole_off], [hole_off, 0], [-hole_off, 0]]) {
            translate([pos[0], pos[1], h_out - insert_h]) cylinder(h=insert_h + 1, d=insert_d);
        }
        
        // Blind holes for Internal Stack M3 heat-set inserts
        for(x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
            translate([x, y, bot_t + standoff_h - insert_h]) cylinder(h=insert_h + 1, d=insert_d);
        }
        
        // PC4-M6 Pneumatic threads (5.4mm hole perfectly grips M6 thread)
        translate([-(fc_w/2) - wall_t - 8, 40, h_out - 18]) rotate([0, 90, 0]) cylinder(h=wall_t + 10, d=5.4);
        translate([-(fc_w/2) - wall_t - 8, -40, bot_t + 15]) rotate([0, 90, 0]) cylinder(h=wall_t + 10, d=5.4);
        
        // Hollow out the wire potting cup and routing tunnel
        translate([(fc_w/2) + wall_t + 2, 0, 45]) cube([10, 20, 20], center=true); 
        translate([(fc_w/2), 0, 38]) cube([wall_t + 10, 12, 8], center=true);      
    }
}

// ----------------------------------------------------------------------------
// COMPONENT 2: UNIVERSAL SENSOR PLATE
// Features a 7mm generic grid to mount MQ-series, BME688, or any custom PCBs.
// ----------------------------------------------------------------------------
module sensor_plate() {
    difference() {
        rounded_box(125, 125, 3, 5);
        
        // Main mounting holes (Clearance for M3 bolts)
        for(x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
            translate([x, y, -1]) cylinder(h=5, d=3.4); 
        }
        
        // Central wire routing cutout
        translate([(125/2) - 5, 0, 1.5]) cube([15, 30, 5], center=true);
        
        // 7mm Universal Breadboard Grid
        for(x = [-50 : 7 : 50], y = [-50 : 7 : 50]) {
            // Keep exclusion zones around main mounts and wire cutout
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
// COMPONENT 3: FLUSH HONEYCOMB DIFFUSER
// Straightens turbulent airflow into a uniform laminar breeze over the sensors.
// ----------------------------------------------------------------------------
module diffuser_insert() {
    diff_h = 20; // 20mm clearance created above the sensor plate
    
    difference() {
        union() {
            // Main ring
            difference() {
                rounded_box(114, 114, diff_h, 10);
                translate([0, 0, -1]) rounded_box(110, 110, diff_h + 2, 8);
            }
            // Honeycomb Grid
            intersection() {
                rounded_box(110, 110, 8, 8);
                hex_grid(114, 114, 8, 3.5, 1.2);
            }
            // Integrated solid 20mm legs in the corners
            for (x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
                translate([x, y, 0]) cylinder(h=diff_h, d=12);
            }
        }
        
        // M3 bolt clearance and flush countersinks
        for (x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
            translate([x, y, -1]) cylinder(h=diff_h + 2, d=3.4);
            translate([x, y, -0.1]) cylinder(h=2.2, d1=6.5, d2=3.4); 
        }
    }
}

// ----------------------------------------------------------------------------
// COMPONENT 4: AERODYNAMIC LID (The "Vortex Engine")
// Houses the tangential cyclone ducts and the 4 return vents for the flow loop.
// ----------------------------------------------------------------------------
module lid_pro() {
    lid_h = 26; // Thick 26mm roof ensures absolute rigidity and deep duct space
    
    difference() {
        rounded_box(162, 162, lid_h, 19);
        
        // BOTTOM O-Ring Groove (151.4mm - Seals main chamber)
        translate([0, 0, -0.1]) difference() {
            rounded_box(151.4, 151.4, 2.5, 20.7);
            translate([0,0,-1]) rounded_box(144.6, 144.6, 4.5, 17.3);
        }
        
        // TOP O-Ring Groove (94mm - Seals the fan dome and return vents)
        translate([0, 0, lid_h - 2.4]) difference() {
            rounded_box(94, 94, 2.5, 10);
            translate([0,0,-1]) rounded_box(94 - 6.8, 94 - 6.8, 4.5, 10 - 3.4);
        }

        // 8x Main Perimeter Fastener Holes
        for (pos = [[hole_off, hole_off], [-hole_off, hole_off], [hole_off, -hole_off], [-hole_off, -hole_off],
                    [0, hole_off], [0, -hole_off], [hole_off, 0], [-hole_off, 0]]) {
            translate([pos[0], pos[1], -1]) cylinder(h=lid_h + 2, d=3.4);
            translate([pos[0], pos[1], lid_h - 2]) cylinder(h=2.1, d1=3.4, d2=6.5);
        }
        
        // 60mm Fan Recess
        translate([0, 0, lid_h - 3]) cube([fan_size, fan_size, 6.2], center=true);
        for(x=[-fan_mount, fan_mount], y=[-fan_mount, fan_mount]) { translate([x, y, -1]) cylinder(h=lid_h + 2, d=4.2); }
        
        // Central Cone Deflector (Prevents air bouncing straight back into the fan hub)
        translate([0, 0, lid_h - 11]) difference() {
            cylinder(h=8.1, d=fan_hole);
            translate([0, 0, -0.1]) cylinder(h=8, d1=45, d2=0);
        }
        
        // TANGENTIAL VORTEX DUCTS: Injects air rotationally to create a mixing cyclone
        for(i=[0:90:270]) {
            rotate([0, 0, i]) {
                hull() { translate([16, 12, 14]) sphere(d=16); translate([35, 30, 8]) sphere(d=15); }
                hull() { translate([35, 30, 8]) sphere(d=15); translate([52, 42, -2]) sphere(d=14); }
                hull() { translate([52, 42, -2]) sphere(d=14); translate([42, 52, -2]) sphere(d=14); }
            }
        }
        
        // THE RETURN VENTS: Crucial for allowing air to bypass the fan and avoid stalling
        for(pos = [[0, 38], [0, -38], [38, 0], [-38, 0]]) {
            translate([pos[0], pos[1], -1]) cylinder(h=lid_h + 2, d=8);
        }
    }
}

// ----------------------------------------------------------------------------
// COMPONENT 5: ULTIMATE FAN DOME
// Features a PC4-M6 sample inlet, massive air plenum, and suspended pillars.
// ----------------------------------------------------------------------------
module fan_dome_ultimate() { 
    dh = 26; // Internal clearance height (Allows a 20mm thick fan to breathe easily)
    th = 32; // Total height (Leaves a solid 6mm thick roof for the pneumatic thread)
    wt = 3;  // Solid 3mm walls for durability
    ow = 98; // Wide base flange perfectly covers the 94mm gasket

    difference() { 
        // 1. Aerodynamic Outer Shell
        hull() { 
            rounded_box(ow, ow, 4, 10); 
            translate([0, 0, 16]) rounded_box(68, 68, 0.1, 8); 
            translate([0, 0, th - 2]) rounded_box(56, 56, 2, 4); 
        } 
        
        // 2. The Internal Plenum & Fan Cavity
        union() {
            // Base collection zone (Captures air returning from the 4 vents)
            translate([0, 0, -0.1]) rounded_box(ow - 2*wt, ow - 2*wt, 4.2, 10 - wt);
            
            // Precise square cavity for the 60x60mm fan body (up to Z=14.5)
            translate([0, 0, 4]) rounded_box(62, 62, 10.5, 2);
            
            // Cylindrical upper plenum. 
            // Using a cylinder leaves the 4 corners as SOLID plastic pillars for the screws to crush the fan frame!
            translate([0, 0, 14.5]) cylinder(h=dh - 14.5, d=58);
        }
        
        // 3. Fastener Holes & Countersinks 
        for(x=[-fan_mount, fan_mount], y=[-fan_mount, fan_mount]) { 
            translate([x, y, -1]) cylinder(h=th + 5, d=4.2); 
            translate([x, y, th - 2.5]) cylinder(h=3, d1=4.2, d2=8.5); 
        } 
        
        // 4. Side Wire Port (Positioned at Z=17, safely above the fan blades)
        translate([0, -(ow/2), 17]) rotate([90, 0, 0]) cylinder(h=30, d=5, center=true); 

        // 5. Top Pneumatic Port Inlet (For PC4-M6 fitting, draws VOC sample from jar)
        translate([0, 0, dh - 1]) cylinder(h=10, d=5.4); 
    } 
}

// ----------------------------------------------------------------------------
// COMPONENT 6: CUSTOM TPU GASKETS
// MUST be printed in TPU, 106% Flow, and Concentric top/bottom pattern!
// ----------------------------------------------------------------------------
module tpu_gaskets() {
    // Bottom Gasket (Main Chamber Seal)
    difference() {
        rounded_box(151.4 - tol, 151.4 - tol, gasket_h, 20.7);
        translate([0, 0, -1]) rounded_box(144.6 + tol, 144.6 + tol, gasket_h + 2, 17.3);
    }
    // Top Gasket (Fan Dome Seal)
    difference() {
        rounded_box(94 - tol, 94 - tol, gasket_h, 10);
        translate([0, 0, -1]) rounded_box(87.2 + tol, 87.2 + tol, gasket_h + 2, 6.6);
    }
}

// --- HELPER MODULES (Mathematical functions for geometry generation) ---
module rounded_box(w, l, h, r) { if(h>0) hull() { for(x=[-(w/2)+r, (w/2)-r], y=[-(l/2)+r, (l/2)-r]) translate([x, y, 0]) cylinder(h=h, r=r); } }
module flared_box(w_in, l_in, r) { w_out = w_in + 2*wall_t; l_out = l_in + 2*wall_t; union() { rounded_box(w_out, l_out, h_out - 11, r + wall_t); hull() { translate([0, 0, h_out - 11.1]) rounded_box(w_out, l_out, 0.1, r + wall_t); translate([0, 0, h_out - 6]) rounded_box(w_out + 10, l_out + 10, 0.1, r + wall_t + 2); } translate([0, 0, h_out - 6]) rounded_box(w_out + 10, l_out + 10, 6, r + wall_t + 2); } }
module inner_void(w_in, l_in, r) { translate([0, 0, bot_t]) rounded_box(w_in, l_in, fc_h + 1, r); }
module hex_grid(w, l, h, cr, wt) { x_s = cr*1.5; y_s = cr*sqrt(3); difference() { translate([0,0,h/2]) cube([w,l,h], center=true); for(x=[-w/2:x_s:w/2+x_s], y=[-l/2:y_s:l/2+y_s]) { y_o = (round(x/x_s)%2==0)?0:y_s/2; translate([x,y+y_o,-1]) cylinder(h=h+2, r=cr-(wt/2), $fn=6); } } }

// ============================================================================
// RENDER & EXPORT LOGIC
// ============================================================================
if (view_mode == "assembly") {
    // Creates a beautiful exploded view showing exactly how the parts stack.
    explode_gap = 35; 
    
    color("SteelBlue", 0.8) flow_chamber();
    color("LimeGreen") translate([0, 0, bot_t + standoff_h + explode_gap]) sensor_plate();
    color("DarkOrange") translate([0, 0, bot_t + standoff_h + 20 + explode_gap*2]) rotate([180,0,0]) diffuser_insert();
    
    color("DeepSkyBlue", 0.9) translate([0, 0, h_out + explode_gap*3]) 
        difference() { rounded_box(151.4 - tol, 151.4 - tol, gasket_h, 20.7); translate([0, 0, -1]) rounded_box(144.6 + tol, 144.6 + tol, gasket_h + 2, 17.3); }
        
    color("LightSlateGray", 0.9) translate([0, 0, h_out + explode_gap*4]) lid_pro();
    
    color("DeepSkyBlue", 0.9) translate([0, 0, h_out + 26 - 2.4 + explode_gap*5]) 
        difference() { rounded_box(94 - tol, 94 - tol, gasket_h, 10); translate([0, 0, -1]) rounded_box(87.2 + tol, 87.2 + tol, gasket_h + 2, 6.6); }

    color("Beige", 0.9) translate([0, 0, h_out + 26 + explode_gap*6]) fan_dome_ultimate();
    
} else if (view_mode == "print_layout") {
    // Flips all parts to their optimal, support-free printing orientations.
    color("SteelBlue")      translate([0, 0, 0]) flow_chamber();
    color("LimeGreen")      translate([-180, 0, 0]) sensor_plate();
    color("DarkOrange")     translate([180, 0, 0]) diffuser_insert();
    color("LightSlateGray") translate([0, 180, 26]) rotate([180, 0, 0]) lid_pro();
    color("Beige")          translate([-180, 180, 32]) rotate([180, 0, 0]) fan_dome_ultimate();
    color("DeepSkyBlue")    translate([180, 180, 0]) tpu_gaskets();
}

// ----------------------------------------------------------------------------
// HOW TO EXPORT INDIVIDUAL STL FILES:
// Change view_mode to "print_layout". Then, select an object, press F6 (Render), 
// and go to File -> Export -> Export as STL.
// ----------------------------------------------------------------------------