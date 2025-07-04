`include "vector_pkg.svh"
`include "common_defs.svh"

module ray_generator #(
    parameter SCREEN_WIDTH = `SCREEN_WIDTH,
    parameter SCREEN_HEIGHT = `SCREEN_HEIGHT
)(
    input logic clk,
    input logic rst,
    input fp screen_x,  
    input fp screen_y,
    input logic coords_valid,

    input vec3 camera_forward,
    //input fp tan_half_fov, // tan(fov / 2)
    // should be taking aspect ratio as an input? Compute width/height (make division module)
    
    output vec3 ray_direction,
    output logic valid
);

// calculating camera up and right vectors internally using tan approximations

localparam fp FP_ONE = 32'h01000000;
localparam fp FP_TWO = 32'h02000000;
localparam fp INV_HALF_WIDTH = 32'h00051EB8;  // 1/320
localparam fp INV_HALF_HEIGHT = 32'h006AAAAB; // 1/240 precomputed recipricol for now
localparam fp ASPECT_RATIO_640_480 = 32'h01555555;
localparam fp SCALE_X = 32'h00051EB8;   // 2/SCREEN_WIDTH
localparam fp SCALE_Y = 32'h006AAAAB;   // 2/SCREEN_HEIGHT

// camera looking down z axis
localparam vec3 CAMERA_RIGHT = make_vec3(32'h01000000, 32'h00000000, 32'h00000000); // (1,0,0)
localparam vec3 CAMERA_UP    = make_vec3(32'h00000000, 32'h01000000, 32'h00000000); // (0,1,0)

logic valid_r1, valid_r2, valid_r3;
vec3 ray;
fp ray_mag_sq, inv_ray_mag;
fp ndc_x, ndc_y;
fp pixel_x_fp, pixel_y_fp;

// 1: normalizing pixel coords to [-1,1]
always_ff @(posedge clk) begin
    if (!rst) begin
        ndc_x <= '0;
        ndc_y <= '0;
        valid_r1 <= 0;
    end else begin
        valid_r1 <= coords_valid;
        if(coords_valid) begin
            logic [63:0] temp_x, temp_y;

            // [0,2] range
            temp_x = screen_x * SCALE_X;
            temp_y = screen_y * SCALE_Y;

            // [-1,1] range
            ndc_x <= temp_x[31:0] - FP_ONE;
            ndc_y <= FP_ONE - temp_y[31:0];
        end
    end
end

// 2: FOV and aspect ratio to calculate camera up and camera right

// always_ff @(posedge clk) begin
//     if(!rst) begin
//         valid_r2 <= 0;
//     end else begin
//         CAMERA_RIGHT <= fp_mul(fp_mul(ndc_x, ASPECT_RATIO_640_480), tan_half_fov);
//         camera_up <= fp_mul(ndc_y, tan_half_fov);
//         valid_r2 <= valid_r1;
//     end
// end

// ray direction
always_ff @(posedge clk) begin
    if(!rst) begin
        ray <= 0;
        valid_r3 <= 0;
    end else begin
        ray.x <= fp_mul(ndc_x, CAMERA_RIGHT.x) + fp_mul(ndc_y, CAMERA_UP.x) + fp_mul(-FP_ONE, camera_forward.x);
        ray.y <= fp_mul(ndc_x, CAMERA_RIGHT.y) + fp_mul(ndc_y, CAMERA_UP.y) + fp_mul(-FP_ONE, camera_forward.y);
        ray.z <= fp_mul(ndc_x, CAMERA_RIGHT.z) + fp_mul(ndc_y, CAMERA_UP.z) + fp_mul(-FP_ONE, camera_forward.z);
        valid_r3 <= valid_r1;
    end
end

// have to transform to world space if we are rotating camera
// skip for now since we fix camera pos
vec3 world_ray;
always_comb begin
    world_ray = ray;  
    ray_mag_sq = vec3_dot(world_ray, world_ray);
end

inv_sqrt invsq_ray(
    .clk(clk),
    .rst(rst),
    .valid_in(valid_r3),
    .x(ray_mag_sq),
    .valid_out(invsq_valid_out),
    .inv_sqrt(inv_ray_mag)
);

//normalize ray direction
always_ff @(posedge clk) begin
    if(!rst) begin
        ray_direction <= 0;
        valid <= 0;
    end else begin
        if(invsq_valid_out) begin
            ray_direction.x <= fp_mul(world_ray.x, inv_ray_mag);
            ray_direction.y <= fp_mul(world_ray.y, inv_ray_mag);
            ray_direction.z <= fp_mul(world_ray.z, inv_ray_mag);
            valid <= 1;
        end else begin
            valid <= 0;
        end
    end
end

endmodule
