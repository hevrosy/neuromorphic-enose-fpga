// ==========================================
// E-Nose: STANDALONE FLUIDIC CHAMBER (Master Assembly)
// Fully parametric, support-free FDM design
// ==========================================

$fn = 60; // Curve resolution

// ==========================================
// 🎛️ PARAMETER CONTROL PANEL
// ==========================================

// --- 1. VIEW MODE ---
// "assembly" = Shows an exploded 3D view of all components
// "print_layout" = Arranges all parts flat on the XY plane for STL export
view_mode = "assembly"; 

// --- 2. GLOBAL DIMENSIONS (MAIN CHAMBER) ---
fc_w = 144;          // Internal chamber width (X axis)
fc_l = 144;          // Internal chamber length (Y axis)
fc_h = 60;           // Internal depth (60mm yields approx 1.2L volume)
fc_r = 15;           // Internal corner radius (for smooth airflow)

wall_t = 4.0;        // Outer wall thickness (4mm ensures structural rigidity and airtightness)
bot_t  = 4.0;        // Bottom thickness

// --- 3. HARDWARE FASTENERS ---
insert_d = 4.2;      // Hole diameter for M3 heat-set inserts (adjust if necessary)
insert_h = 5.5;      // Depth for the heat-set inserts

standoff_d = 9.0;    // Outer diameter of the printed base standoffs
standoff_h = 10.0;   // Height of base standoffs (creates wire routing space under sensors)

// --- 4. MOUNTING SPACING (CRITICAL) ---
sp_mount_xy = 100;   // Spacing between the 4 sensor plate screws (100x100mm square)
hole_off = 78.0;     // Position of the 8 lid screws from the center (156x156mm square)

// --- 5. FAN SPECIFICATIONS ---
fan_size = 62;       // Fan recess width (60mm fan + 2mm tolerance)
fan_hole = 58;       // Main intake hole diameter
fan_mount = 25;      // Distance from center to fan mounting holes (50mm spacing for 60mm fan)

// ==========================================
// 🛠️ GEOMETRY GENERATION
// ==========================================

h_out = fc_h + bot_t; // Total calculated outer height

// ==========================================
// COMPONENT 1: FLOW CHAMBER BASE
// ==========================================
module flow_chamber() {
    difference() {
        union() {
            // Main body with upper flange
            difference() { flared_box(fc_w, fc_l, fc_r); inner_void(fc_w, fc_l, fc_r); }
            
            // Internal standoffs for the sensor plate
            for(x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
                translate([x, y, bot_t]) cylinder(h=standoff_h, d1=standoff_d + 4, d2=standoff_d);
            }
            
            // Pneumatic port bosses (Left wall)
            translate([-(fc_w/2) - wall_t + 2, 40, h_out - 18]) rotate([0, -90, 0]) cylinder(h=10, d=14);
            translate([-(fc_w/2) - wall_t + 2, -40, bot_t + 15]) rotate([0, -90, 0]) cylinder(h=10, d=14);
            
            // Wire potting gland (Right wall)
            translate([(fc_w/2) + wall_t + 6, 0, bot_t + 10]) cube([16, 40, 22], center=true);
        }

        // Blind holes for lid heat-set inserts
        for (pos = [[hole_off, hole_off], [-hole_off, hole_off], [hole_off, -hole_off], [-hole_off, -hole_off],
                    [0, hole_off], [0, -hole_off], [hole_off, 0], [-hole_off, 0]]) {
            translate([pos[0], pos[1], h_out - insert_h]) cylinder(h=insert_h + 1, d=insert_d);
        }
        
        // Blind holes for standoff inserts
        for(x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
            translate([x, y, bot_t + standoff_h - insert_h]) cylinder(h=insert_h + 1, d=insert_d);
        }
        
        // PC4-M6 Pneumatic tap holes
        translate([-(fc_w/2) - wall_t - 8, 40, h_out - 18]) rotate([0, 90, 0]) cylinder(h=wall_t + 10, d=5.4);
        translate([-(fc_w/2) - wall_t - 8, -40, bot_t + 15]) rotate([0, 90, 0]) cylinder(h=wall_t + 10, d=5.4);
        
        // Hollow out the wire gland and routing tunnel
        translate([(fc_w/2) + wall_t + 6, 0, bot_t + 12]) cube([16, 32, 22], center=true);
        translate([(fc_w/2), 0, bot_t + 10]) cube([wall_t + 8, 20, 10], center=true);
    }
}

// ==========================================
// COMPONENT 2: UNIVERSAL SENSOR PLATE
// ==========================================
module sensor_plate() {
    difference() {
        rounded_box(125, 125, 3, 5);
        // Main mounting holes with countersink
        for(x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
            translate([x, y, -1]) cylinder(h=5, d=3.2); 
            translate([x, y, 3 - 1]) cylinder(h=2, d1=3.2, d2=6.5);
        }
        // Wire pass-through window
        translate([(125/2) - 5, 0, 1.5]) cube([15, 30, 5], center=true);
        // Breadboard grid for flexible sensor placement
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

// ==========================================
// COMPONENT 3: HONEYCOMB DIFFUSER
// ==========================================
module diffuser_insert() {
    difference() {
        union() {
            difference() {
                rounded_box(114, 114, 25, 10);
                translate([0, 0, -1]) rounded_box(110, 110, 27, 8);
            }
            intersection() {
                rounded_box(110, 110, 8, 8);
                hex_grid(114, 114, 8, 3.5, 1.2);
            }
            for (x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
                translate([x, y, 0]) cylinder(h=8, d=11);
            }
        }
        for (x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
            translate([x, y, -1]) cylinder(h=10, d=3.2);
            translate([x, y, 6.5]) cylinder(h=2, d1=3.2, d2=6.5);
        }
    }
}

// ==========================================
// COMPONENT 4: AERODYNAMIC LID
// ==========================================
module lid_pro() {
    difference() {
        rounded_box(162, 162, 18, 19);
        // O-Ring Groove (3.4mm wide, suitable for 3mm silicone cord)
        translate([0, 0, -0.1]) difference() {
            rounded_box(151.4, 151.4, 2.5, 20.7);
            translate([0,0,-1]) rounded_box(144.6, 144.6, 4.5, 17.3);
        }
        for (pos = [[hole_off, hole_off], [-hole_off, hole_off], [hole_off, -hole_off], [-hole_off, -hole_off],
                    [0, hole_off], [0, -hole_off], [hole_off, 0], [-hole_off, 0]]) {
            translate([pos[0], pos[1], -1]) cylinder(h=20, d=3.4);
            translate([pos[0], pos[1], 16]) cylinder(h=2.1, d1=3.4, d2=6.5);
        }
        // Fan Recess
        translate([0, 0, 15]) cube([fan_size, fan_size, 6.2], center=true);
        for(x=[-fan_mount, fan_mount], y=[-fan_mount, fan_mount]) { translate([x, y, -1]) cylinder(h=20, d=4.2); }
        
        // Central Air Deflector (Cone)
        translate([0, 0, 8]) difference() {
            cylinder(h=10.1, d=fan_hole);
            translate([0, 0, -0.1]) cylinder(h=8, d1=45, d2=0);
        }
        
        // Tangential Vortex Ducts
        for(i=[0:90:270]) {
            rotate([0, 0, i]) {
                hull() { translate([16, 12, 12]) sphere(d=16); translate([35, 30, 8]) sphere(d=15); }
                hull() { translate([35, 30, 8]) sphere(d=15); translate([52, 42, -2]) sphere(d=14); }
                hull() { translate([52, 42, -2]) sphere(d=14); translate([42, 52, -2]) sphere(d=14); }
            }
        }
    }
}

// ==========================================
// COMPONENT 5: FAN RECIRCULATION DOME
// ==========================================
module fan_dome_v2() { 
    dh=14; wt=2.5; ow=70; th=dh+wt; 
    difference() { 
        hull() { 
            rounded_box(ow, ow, 2, 4); 
            translate([0, 0, th - 2]) rounded_box(ow - (th*1.5), ow - (th*1.5), 2, 2); 
        } 
        translate([0, 0, -0.1]) hull() { 
            rounded_box(ow - 2*wt, ow - 2*wt, 1, 2); 
            translate([0, 0, dh]) rounded_box((ow - (th*1.5)) - 2*wt, (ow - (th*1.5)) - 2*wt, 1, 1); 
        } 
        for(x=[-fan_mount, fan_mount], y=[-fan_mount, fan_mount]) { translate([x, y, -1]) cylinder(h=th + 5, d=4.2); } 
    } 
}

// --- HELPER MODULES ---
module rounded_box(w, l, h, r) { if(h>0) hull() { for(x=[-(w/2)+r, (w/2)-r], y=[-(l/2)+r, (l/2)-r]) translate([x, y, 0]) cylinder(h=h, r=r); } }
module flared_box(w_in, l_in, r) { w_out = w_in + 2*wall_t; l_out = l_in + 2*wall_t; union() { rounded_box(w_out, l_out, h_out - 11, r + wall_t); hull() { translate([0, 0, h_out - 11.1]) rounded_box(w_out, l_out, 0.1, r + wall_t); translate([0, 0, h_out - 6]) rounded_box(w_out + 10, l_out + 10, 0.1, r + wall_t + 2); } translate([0, 0, h_out - 6]) rounded_box(w_out + 10, l_out + 10, 6, r + wall_t + 2); } }
module inner_void(w_in, l_in, r) { translate([0, 0, bot_t]) rounded_box(w_in, l_in, fc_h + 1, r); }
module hex_grid(w, l, h, cr, wt) { x_s = cr*1.5; y_s = cr*sqrt(3); difference() { translate([0,0,h/2]) cube([w,l,h], center=true); for(x=[-w/2:x_s:w/2+x_s], y=[-l/2:y_s:l/2+y_s]) { y_o = (round(x/x_s)%2==0)?0:y_s/2; translate([x,y+y_o,-1]) cylinder(h=h+2, r=cr-(wt/2), $fn=6); } } }

// ==========================================
// RENDER & EXPORT LOGIC
// ==========================================
if (view_mode == "assembly") {
    explode_gap = 40; 
    color("SteelBlue", 0.8) flow_chamber();
    color("LimeGreen") translate([0, 0, bot_t + standoff_h + explode_gap]) sensor_plate();
    color("DarkOrange") translate([0, 0, bot_t + standoff_h + 25 + explode_gap*2]) rotate([180,0,0]) diffuser_insert();
    color("LightSlateGray", 0.9) translate([0, 0, h_out + explode_gap*3]) lid_pro();
    color("Beige", 0.9) translate([0, 0, h_out + 18 + explode_gap*4]) fan_dome_v2();
    
} else if (view_mode == "print_layout") {
    color("SteelBlue") translate([0, 0, 0]) flow_chamber();
    color("LimeGreen") translate([-180, 0, 0]) sensor_plate();
    color("DarkOrange") translate([180, 0, 0]) diffuser_insert();
    // Lids are automatically flipped for support-free printing
    color("LightSlateGray") translate([0, 180, 18]) rotate([180, 0, 0]) lid_pro();
    color("Beige") translate([-180, 180, 16.5]) rotate([180, 0, 0]) fan_dome_v2();
}