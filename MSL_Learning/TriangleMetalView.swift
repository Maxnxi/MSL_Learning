//
//  Untitled.swift
//  MSL_Learning
//
//  Created by Maksim Ponomarev on 1/1/26.
//


import SwiftUI
import MetalKit
import simd


struct TriangleView: UIViewRepresentable {
	
	func makeUIView(context: Context) -> MTKView {
		let metalView = TriangleMetalView(
			frame: .zero,
			device: MTLCreateSystemDefaultDevice()
		)
		return metalView
	}
	
	func updateUIView(_ uiView: MTKView, context: Context) {
		// Updates if needed
	}
}


class TriangleMetalView: MTKView, MTKViewDelegate {
	
	var commandQueue: MTLCommandQueue!
	var pipelineState: MTLRenderPipelineState!
	var vertexBuffer: MTLBuffer!
	var uniformBuffer: MTLBuffer!
	
	var time: Float = 0.0
	var rotation: Float = 0.0
	
	struct Vertex {
		var position: SIMD2<Float>
		var color: SIMD4<Float>
	}
	
	struct Uniforms {
		var modelMatrix: simd_float4x4
		var time: Float
		var scale: Float
	}
	
	required init(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}
	
	override init(frame frameRect: CGRect, device: MTLDevice?) {
		super.init(frame: frameRect, device: device)
		setup()
	}
	
	private func setup() {
		guard let device = MTLCreateSystemDefaultDevice() else {
			fatalError()
		}
		
		self.device = device
		self.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
		
		// 60 FPS для плавной анимации
		self.preferredFramesPerSecond = 60
		
		commandQueue = device.makeCommandQueue()!
		createVertexBuffer()
		createUniformBuffer()
		createPipelineState()
		
		self.delegate = self
	}
	
	private func createVertexBuffer() {
		let vertices: [Vertex] = [
			Vertex(position: SIMD2<Float>(0.0, 0.5),
				   color: SIMD4<Float>(1.0, 0.0, 0.0, 1.0)),
			Vertex(position: SIMD2<Float>(-0.5, -0.5),
				   color: SIMD4<Float>(0.0, 1.0, 0.0, 1.0)),
			Vertex(position: SIMD2<Float>(0.5, -0.5),
				   color: SIMD4<Float>(0.0, 0.0, 1.0, 1.0))
		]
		
		vertexBuffer = device!.makeBuffer(
			bytes: vertices,
			length: vertices.count * MemoryLayout<Vertex>.stride,
			options: .storageModeShared
		)
	}
	
	private func createUniformBuffer() {
		// Создаем buffer для uniforms
		// Будем обновлять его каждый frame
		uniformBuffer = device!.makeBuffer(
			length: MemoryLayout<Uniforms>.stride,
			options: .storageModeShared
		)
	}
	
	private func createPipelineState() {
		let library = device!.makeDefaultLibrary()!
		let vertexFunction = library.makeFunction(name: "vertex_main")!
		let fragmentFunction = library.makeFunction(name: "fragment_main")!
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = vertexFunction
		pipelineDescriptor.fragmentFunction = fragmentFunction
		pipelineDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat
		
		do {
			pipelineState = try device!.makeRenderPipelineState(descriptor: pipelineDescriptor)
		} catch {
			fatalError("Pipeline state error: \(error)")
		}
	}
	
	private func updateUniforms() {
		// Обновляем время и rotation
		time += 1.0 / 60.0  // assuming 60 FPS
		rotation += 0.02    // rotation speed
		
		// Создаем матрицу трансформации
		var modelMatrix = matrix_identity_float4x4
		
		// Rotate around Z axis
		modelMatrix = simd_mul(
			modelMatrix,
			rotationMatrix(
				angle: rotation,
				axis: SIMD3<Float>(0, 0, 1)
			))
		
		// Scale (можно анимировать)
		let scale: Float = 1.0 + sin(time) * 0.2  // pulsing scale
		modelMatrix = simd_mul(modelMatrix, scaleMatrix(scale: SIMD3<Float>(scale, scale, 1)))
		
		// Заполняем uniform структуру
		var uniforms = Uniforms(
			modelMatrix: modelMatrix,
			time: time,
			scale: scale
		)
		
		// Копируем в GPU buffer
		let bufferPointer = uniformBuffer.contents()
		memcpy(bufferPointer, &uniforms, MemoryLayout<Uniforms>.stride)
	}
	
	// Helper функции для создания матриц
	private func rotationMatrix(angle: Float, axis: SIMD3<Float>) -> simd_float4x4 {
		let c = cos(angle)
		let s = sin(angle)
		
		// Rotation вокруг Z оси (простейший случай)
		if axis.z != 0 {
			return simd_float4x4(
				SIMD4<Float>(c, s, 0, 0),
				SIMD4<Float>(-s, c, 0, 0),
				SIMD4<Float>(0, 0, 1, 0),
				SIMD4<Float>(0, 0, 0, 1)
			)
		}
		
		return matrix_identity_float4x4
	}
	
	private func scaleMatrix(scale: SIMD3<Float>) -> simd_float4x4 {
		return simd_float4x4(
			SIMD4<Float>(scale.x, 0, 0, 0),
			SIMD4<Float>(0, scale.y, 0, 0),
			SIMD4<Float>(0, 0, scale.z, 0),
			SIMD4<Float>(0, 0, 0, 1)
		)
	}
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		
	}
	
	func draw(in view: MTKView) {
		guard let drawable = view.currentDrawable,
			  let renderPassDescriptor = view.currentRenderPassDescriptor,
			  let commandBuffer = commandQueue.makeCommandBuffer(),
			  let renderEncoder = commandBuffer.makeRenderCommandEncoder(
				descriptor: renderPassDescriptor
			  ) else { return }
		
		// Обновляем uniforms ПЕРЕД отрисовкой
		updateUniforms()
		
		renderEncoder.setRenderPipelineState(pipelineState)
		
		// Биндим оба buffers
		renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
		renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
		
		// Fragment shader тоже может использовать uniforms
		renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
		
		renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
		renderEncoder.endEncoding()
		
		commandBuffer.present(drawable)
		commandBuffer.commit()
	}
	

}
