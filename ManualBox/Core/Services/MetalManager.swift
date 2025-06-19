import Metal
import Foundation

/// Metal资源管理类，用于预初始化Metal设备并确保metallib库正确加载
class MetalManager {
    static let shared = MetalManager()
    
    // Metal设备实例
    private(set) var device: MTLDevice?
    
    // Metal库
    private(set) var library: MTLLibrary?
    
    // 初始化标志
    private(set) var isInitialized = false
    
    private init() {
        // 初始化Metal资源
        initializeMetal()
    }
    
    /// 初始化Metal设备和库
    private func initializeMetal() {
        // 获取系统默认的Metal设备
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("警告: 设备不支持Metal")
            return
        }
        
        self.device = device
        
        // 尝试加载默认Metal库
        // 首先尝试从主应用包加载
        if let libraryURL = Bundle.main.url(forResource: "default", withExtension: "metallib") {
            if let library = try? device.makeLibrary(URL: libraryURL) {
                self.library = library
                isInitialized = true
                print("Metal库从URL成功加载")
                return
            }
            print("从URL加载Metal库失败")
        }
        
        // 尝试使用与应用链接的默认库
        if let library = device.makeDefaultLibrary() {
            self.library = library
            isInitialized = true
            print("Metal默认库成功加载")
            return
        }
        
        print("加载默认Metal库失败")
        
        // 尝试使用源代码编译
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        
        kernel void dummyKernel(uint2 gid [[thread_position_in_grid]]) {}
        """
        
        let options = MTLCompileOptions()
        options.languageVersion = .version2_0
        
        do {
            library = try device.makeLibrary(source: source, options: options)
            isInitialized = true
            print("Metal库从源码成功编译")
        } catch {
            print("Metal源码编译失败: \(error.localizedDescription)")
        }
    }
    
    /// 检查Metal是否可用
    var isMetalAvailable: Bool {
        return device != nil && isInitialized
    }
    
    /// 预热Metal子系统
    func warmUpMetalSubsystem() {
        guard let device = device else {
            return
        }
        
        // 创建一个简单的命令队列来验证Metal子系统工作正常
        guard let commandQueue = device.makeCommandQueue() else {
            print("无法创建Metal命令队列")
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("无法创建Metal命令缓冲区")
            return
        }
        
        commandBuffer.commit()
        print("Metal子系统预热完成")
    }
}