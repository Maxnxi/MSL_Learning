//
//  Shader.metal
//  MSL_Learning
//
//  Created by Maksim Ponomarev on 1/1/26.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
	float2 position;
	float4 color;
};

struct VertexOut {
	float4 position [[position]];
	float4 color;
};

struct Uniforms {
	float4x4 modelMatrix;
	float time;
	float scale;
};

vertex VertexOut vertex_main(
	constant Vertex* verticies [[buffer(0)]],
	constant Uniforms& uniforms [[buffer(1)]],
	uint vertexID [[vertex_id]]
) {
	VertexOut out;
	
	float4 position = float4(verticies[vertexID].position, 0, 1);
	out.position = uniforms.modelMatrix * position;
	
	out.color = verticies[vertexID].color;
	return out;
}

fragment float4 fragment_main(
							  VertexOut in [[stage_in]],
							  constant Uniforms& uniforms [[buffer(1)]]
							  ) {
	float pulse = (sin(uniforms.time * 2.0) + 1.0) * 0.5;
	return in.color * (0.7 + pulse * 0.3);
}
