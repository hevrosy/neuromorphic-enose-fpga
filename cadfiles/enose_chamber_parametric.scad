// ==========================================
// E-Nose: STANDALONE FLUIDIC CHAMBER (Ultimate Master Assembly)
// Fully parametric, support-free FDM design with TPU Gaskets
// ==========================================

$fn = 60; // Curve resolution for smooth 3D printing

// ==========================================
// 🎛️ PARAMETER CONTROL PANEL
// ==========================================

// --- 1. VIEW MODE ---
// "assembly"     = Exploded 3D view of all components
// "print_layout" = All parts arranged flat on the XY plane for STL export
view_mode = "assembly"; 

// --- 2. GLOBAL DIMENSIONS (MAIN CHAMBER) ---
fc_w = 144;          // Internal chamber width
fc_l = 144;          // Internal chamber length
fc_h = 60;           // Internal depth (~1.2L volume)
fc_r = 15;           // Internal corner radius (smooth airflow)

wall_t = 4.0;        // Outer wall thickness (ensures airtightness)
bot_t  = 4.0;        // Bottom thickness

// --- 3. FASTENERS (HEAT-SET INSERTS & STANDOFFS) ---
insert_d = 4.2;      // Hole diameter for M3 heat-set inserts 
insert_h = 5.5;      // Depth for the heat-set inserts
standoff_d = 9.0;    // Outer diameter of the printed standoffs
standoff_h = 10.0;   // Height of base standoffs (wire routing space)

// --- 4. MOUNTING SPACING (CRITICAL DIMENSIONS) ---
sp_mount_xy = 100;   // 100x100mm square for Sensor Plate & Diffuser
hole_off = 78.0;     // 156x156mm square for the 8 main Lid screws

// --- 5. FAN SPECIFICATIONS ---
fan_size = 62;       // Fan recess width (60mm fan + 2mm tolerance)
fan_hole = 58;       // Main intake hole diameter
fan_mount = 25;      // Fan mounting holes (50mm spacing for 60mm fan)

// --- 6. TPU GASKET SETTINGS ---
gasket_h = 3.2;      // Gasket print height (crushes to 2.4mm when tightened)
tol = 0.2;           // Tolerance for snug fit into the grooves

// ==========================================
// 🛠️ GEOMETRY GENERATION
// ==========================================
h_out = fc_h + bot_t; // Total calculated base height

// ------------------------------------------
// COMPONENT 1: FLOW CHAMBER BASE
// ------------------------------------------
module flow_chamber() {
    difference() {
        union() {
            difference() { flared_box(fc_w, fc_l, fc_r); inner_void(fc_w, fc_l, fc_r); }
            for(x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
                translate([x, y, bot_t]) cylinder(h=standoff_h, d1=standoff_d + 4, d2=standoff_d);
            }
            translate([-(fc_w/2) - wall_t + 2, 40, h_out - 18]) rotate([0, -90, 0]) cylinder(h=10, d=14);
            translate([-(fc_w/2) - wall_t + 2, -40, bot_t + 15]) rotate([0, -90, 0]) cylinder(h=10, d=14);
            translate([(fc_w/2) + wall_t + 6, 0, bot_t + 10]) cube([16, 40, 22], center=true);
        }
        for (pos = [[hole_off, hole_off], [-hole_off, hole_off], [hole_off, -hole_off], [-hole_off, -hole_off],
                    [0, hole_off], [0, -hole_off], [hole_off, 0], [-hole_off, 0]]) {
            translate([pos[0], pos[1], h_out - insert_h]) cylinder(h=insert_h + 1, d=insert_d);
        }
        for(x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
            translate([x, y, bot_t + standoff_h - insert_h]) cylinder(h=insert_h + 1, d=insert_d);
        }
        translate([-(fc_w/2) - wall_t - 8, 40, h_out - 18]) rotate([0, 90, 0]) cylinder(h=wall_t + 10, d=5.4);
        translate([-(fc_w/2) - wall_t - 8, -40, bot_t + 15]) rotate([0, 90, 0]) cylinder(h=wall_t + 10, d=5.4);
        translate([(fc_w/2) + wall_t + 6, 0, bot_t + 12]) cube([16, 32, 22], center=true);
        translate([(fc_w/2), 0, bot_t + 10]) cube([wall_t + 8, 20, 10], center=true);
    }
}

// ------------------------------------------
// COMPONENT 2: UNIVERSAL SENSOR PLATE
// ------------------------------------------
module sensor_plate() {
    difference() {
        rounded_box(125, 125, 3, 5);
        for(x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
            translate([x, y, -1]) cylinder(h=5, d=3.2); 
        }
        translate([(125/2) - 5, 0, 1.5]) cube([15, 30, 5], center=true);
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

// ------------------------------------------
// COMPONENT 3: FLUSH HONEYCOMB DIFFUSER
// ------------------------------------------
module diffuser_insert() {
    diff_h = 20; 
    difference() {
        union() {
            difference() {
                rounded_box(114, 114, diff_h, 10);
                translate([0, 0, -1]) rounded_box(110, 110, diff_h + 2, 8);
            }
            intersection() {
                rounded_box(110, 110, 8, 8);
                hex_grid(114, 114, 8, 3.5, 1.2);
            }
            for (x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
                translate([x, y, 0]) cylinder(h=diff_h, d=12);
            }
        }
        for (x = [-sp_mount_xy/2, sp_mount_xy/2], y = [-sp_mount_xy/2, sp_mount_xy/2]) {
            translate([x, y, -1]) cylinder(h=diff_h + 2, d=3.4);
            translate([x, y, -0.1]) cylinder(h=2.2, d1=6.5, d2=3.4); 
        }
    }
}

// ------------------------------------------
// COMPONENT 4: AERODYNAMIC LID
// ------------------------------------------
module lid_pro() {
    lid_h = 26; 
    difference() {
        rounded_box(162, 162, lid_h, 19);
        translate([0, 0, -0.1]) difference() {
            rounded_box(151.4, 151.4, 2.5, 20.7);
            translate([0,0,-1]) rounded_box(144.6, 144.6, 4.5, 17.3);
        }
        translate([0, 0, lid_h - 2.4]) difference() {
            rounded_box(72, 72, 2.5, 6);
            translate([0,0,-1]) rounded_box(72 - 6.8, 72 - 6.8, 4.5, 6 - 3.4);
        }
        for (pos = [[hole_off, hole_off], [-hole_off, hole_off], [hole_off, -hole_off], [-hole_off, -hole_off],
                    [0, hole_off], [0, -hole_off], [hole_off, 0], [-hole_off, 0]]) {
            translate([pos[0], pos[1], -1]) cylinder(h=lid_h + 2, d=3.4);
            translate([pos[0], pos[1], lid_h - 2]) cylinder(h=2.1, d1=3.4, d2=6.5);
        }
        translate([0, 0, lid_h - 3]) cube([fan_size, fan_size, 6.2], center=true);
        for(x=[-fan_mount, fan_mount], y=[-fan_mount, fan_mount]) { translate([x, y, -1]) cylinder(h=lid_h + 2, d=4.2); }
        translate([0, 0, lid_h - 11]) difference() {
            cylinder(h=8.1, d=fan_hole);
            translate([0, 0, -0.1]) cylinder(h=8, d1=45, d2=0);
        }
        for(i=[0:90:270]) {
            rotate([0, 0, i]) {
                hull() { translate([16, 12, 14]) sphere(d=16); translate([35, 30, 8]) sphere(d=15); }
                hull() { translate([35, 30, 8]) sphere(d=15); translate([52, 42, -2]) sphere(d=14); }
                hull() { translate([52, 42, -2]) sphere(d=14); translate([42, 52, -2]) sphere(d=14); }
            }
        }
    }
}

// ------------------------------------------
// COMPONENT 5: FAN RECIRCULATION DOME
// ------------------------------------------
module fan_dome_v2() { 
    dh=14; wt=3.0; ow=76; th=dh+wt; 
    difference() { 
        hull() { 
            rounded_box(ow, ow, 2, 6); 
            translate([0, 0, th - 2]) rounded_box(ow - (th*1.5), ow - (th*1.5), 2, 2); 
        } 
        translate([0, 0, -0.1]) hull() { 
            rounded_box(ow - 2*wt, ow - 2*wt, 1, 6 - wt); 
            translate([0, 0, dh]) rounded_box((ow - (th*1.5)) - 2*wt, (ow - (th*1.5)) - 2*wt, 1, 1); 
        } 
        for(x=[-fan_mount, fan_mount], y=[-fan_mount, fan_mount]) { translate([x, y, -1]) cylinder(h=th + 5, d=4.2); } 
        
        // КОРЕКЦИЯ: Удължихме режещия цилиндър до h=30, за да пробие чисто скосената стена!
        translate([0, -(ow/2), 9]) rotate([90, 0, 0]) cylinder(h=30, d=5, center=true);
    } 
}

// ------------------------------------------
// COMPONENT 6: TPU GASKETS (SEALS)
// ------------------------------------------
module tpu_gaskets() {
    difference() {
        rounded_box(151.4 - tol, 151.4 - tol, gasket_h, 20.7);
        translate([0, 0, -1]) rounded_box(144.6 + tol, 144.6 + tol, gasket_h + 2, 17.3);
    }
    difference() {
        rounded_box(72 - tol, 72 - tol, gasket_h, 6);
        translate([0, 0, -1]) rounded_box(65.2 + tol, 65.2 + tol, gasket_h + 2, 2.6);
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
    explode_gap = 35; 
    
    color("SteelBlue", 0.8) flow_chamber();
    color("LimeGreen") translate([0, 0, bot_t + standoff_h + explode_gap]) sensor_plate();
    color("DarkOrange") translate([0, 0, bot_t + standoff_h + 20 + explode_gap*2]) rotate([180,0,0]) diffuser_insert();
    
    color("DeepSkyBlue", 0.9) translate([0, 0, h_out + explode_gap*3]) 
        difference() { rounded_box(151.4 - tol, 151.4 - tol, gasket_h, 20.7); translate([0, 0, -1]) rounded_box(144.6 + tol, 144.6 + tol, gasket_h + 2, 17.3); }
        
    color("LightSlateGray", 0.9) translate([0, 0, h_out + explode_gap*4]) lid_pro();
    
    color("DeepSkyBlue", 0.9) translate([0, 0, h_out + 26 + explode_gap*5]) 
        difference() { rounded_box(72 - tol, 72 - tol, gasket_h, 6); translate([0, 0, -1]) rounded_box(65.2 + tol, 65.2 + tol, gasket_h + 2, 2.6); }

    color("Beige", 0.9) translate([0, 0, h_out + 26 + explode_gap*6]) fan_dome_v2();
    
} else if (view_mode == "print_layout") {
   color("SteelBlue")      translate([0, 0, 0]) flow_chamber();
    color("LimeGreen")      translate([-180, 0, 0]) sensor_plate();
    color("DarkOrange")     translate([180, 0, 0]) diffuser_insert();
    color("LightSlateGray") translate([0, 180, 26]) rotate([180, 0, 0]) lid_pro();
    color("Beige")          translate([-180, 180, 17]) rotate([180, 0, 0]) fan_dome_v2();
    color("DeepSkyBlue")    translate([180, 180, 0]) tpu_gaskets();
    
}