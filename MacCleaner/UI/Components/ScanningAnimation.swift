import SwiftUI
import Combine

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var speed: CGFloat
    var angle: Double
    var size: CGFloat
    var opacity: Double
    var isDataNode: Bool = false
}

struct ScanningAnimation: View {
    let isScanning: Bool
    @State private var particles: [Particle] = []
    @State private var scannerOrbit: Double = 0
    @State private var secondaryOrbit: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            
            ZStack {
                // Background Neural Grid
                Canvas { context, size in
                    // Connection Lines
                    if isScanning {
                        for i in 0..<particles.count {
                            // Only connect nodes close to each other
                            for j in i+1..<min(i+8, particles.count) {
                                let p1 = particles[i].position
                                let p2 = particles[j].position
                                let dist = sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
                                
                                if dist < 60 {
                                    var path = Path()
                                    path.move(to: p1)
                                    path.addLine(to: p2)
                                    
                                    // Pulse opacity based on scanner orbit
                                    let pulse = 0.5 + 0.5 * sin(scannerOrbit * 0.05 + Double(i))
                                    context.stroke(
                                        path,
                                        with: .color(AppTheme.terracotta.opacity(0.15 * (1.0 - Double(dist / 60)) * pulse)),
                                        lineWidth: 0.4
                                    )
                                }
                            }
                        }
                    }
                    
                    // Draw Particles
                    for particle in particles {
                        let rect = CGRect(
                            x: particle.position.x - particle.size / 2,
                            y: particle.position.y - particle.size / 2,
                            width: particle.size,
                            height: particle.size
                        )
                        
                        if particle.isDataNode {
                            context.fill(
                                Path(rect), // Square for data nodes
                                with: .color(AppTheme.terracotta.opacity(particle.opacity))
                            )
                        } else {
                            context.fill(
                                Circle().path(in: rect),
                                with: .color(AppTheme.terracotta.opacity(particle.opacity))
                            )
                        }
                    }
                }
                
                // Orbital Simulation Rings
                Group {
                    // Outer Ring
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(AppTheme.terracotta.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(width: 320, height: 320)
                        .rotationEffect(.degrees(secondaryOrbit))
                    
                    // Middle Ring
                    Circle()
                        .trim(from: 0.4, to: 0.7)
                        .stroke(AppTheme.terracotta.opacity(0.15), style: StrokeStyle(lineWidth: 1))
                        .frame(width: 240, height: 240)
                        .rotationEffect(.degrees(-scannerOrbit * 0.5))
                    
                    // Inner Data Ring
                    Circle()
                        .trim(from: 0, to: 0.1)
                        .stroke(AppTheme.terracotta.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(scannerOrbit * 1.5))
                }
                
                // Central Disk Unit
                ZStack {
                    Circle()
                        .fill(AppTheme.cardBackground)
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.5), radius: 20)
                    
                    // Ring Glow
                    Circle()
                        .stroke(AppTheme.terracotta.opacity(isScanning ? 0.3 : 0.1), lineWidth: 2)
                        .frame(width: 110, height: 110)
                        .scaleEffect(isScanning ? pulseScale : 1.0)
                    
                    Image(systemName: isScanning ? "cpu" : "internaldrive")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .scaleEffect(isScanning ? pulseScale : 1.0)
                    
                    // Orbiting Scanner Head
                    Circle()
                        .trim(from: 0, to: 0.05)
                        .stroke(
                            AppTheme.terracotta,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(scannerOrbit))
                        .blur(radius: 1)
                }
                
                // Tech Status Indicators (Simulation style)
                if isScanning {
                    VStack {
                        Spacer()
                        HStack(spacing: 20) {
                            StatusText(label: "LOGIC", value: "ACTIVE")
                            StatusText(label: "SCAN", value: "OPTIMIZED")
                            StatusText(label: "LOAD", value: String(format: "%.0f%%", scannerOrbit.truncatingRemainder(dividingBy: 100)))
                        }
                        .padding(.bottom, 20)
                        
                        Text("SYSTEM OPTIMAL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.terracotta.opacity(0.8))
                            .padding(.bottom, 40)
                            .kerning(2)
                    }
                }
            }
            .mask(
                // Soften edges to remove lines
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black, .black, .clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onAppear {
                setupInitialParticles(center: center)
            }
            .onReceive(timer) { _ in
                updateParticles(center: center)
                withAnimation(.linear(duration: 0.02)) {
                    scannerOrbit += isScanning ? 4 : 1
                    secondaryOrbit += 0.5
                    if isScanning {
                        pulseScale = 1.0 + 0.05 * sin(scannerOrbit * 0.1)
                    }
                }
            }
        }
    }
    
    // Helper view for simulation status
    struct StatusText: View {
        let label: String
        let value: String
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.secondaryText.opacity(0.5))
                Text(value)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.terracotta)
            }
        }
    }
    
    private func setupInitialParticles(center: CGPoint) {
        for _ in 0..<60 {
            particles.append(createParticle(center: center, randomPos: true))
        }
    }
    
    private func createParticle(center: CGPoint, randomPos: Bool = false) -> Particle {
        let angle = Double.random(in: 0...360) * .pi / 180
        let distance = randomPos ? CGFloat.random(in: 80...300) : 300
        
        return Particle(
            position: CGPoint(
                x: center.x + CGFloat(cos(angle)) * distance,
                y: center.y + CGFloat(sin(angle)) * distance
            ),
            speed: CGFloat.random(in: 0.3...1.5),
            angle: angle,
            size: CGFloat.random(in: 1...3),
            opacity: Double.random(in: 0.1...0.5),
            isDataNode: Double.random(in: 0...1) > 0.8
        )
    }
    
    private func updateParticles(center: CGPoint) {
        for i in 0..<particles.count {
            if isScanning {
                // Simulation effect: swirl and pull
                let dx = center.x - particles[i].position.x
                let dy = center.y - particles[i].position.y
                let dist = sqrt(dx*dx + dy*dy)
                
                if dist < 65 {
                    particles[i] = createParticle(center: center)
                } else {
                    // Swirl effect
                    let swirlSpeed: CGFloat = 0.01
                    let currentAngle = atan2(dy, dx)
                    let newAngle = currentAngle + swirlSpeed
                    let newDist = dist - particles[i].speed
                    
                    particles[i].position.x = center.x - cos(newAngle) * newDist
                    particles[i].position.y = center.y - sin(newAngle) * newDist
                    particles[i].opacity = min(0.6, 1.0 - Double(dist / 300))
                }
            } else {
                // Idle floating - wider orbit
                particles[i].angle += 0.003
                let orbitDist: CGFloat = 140 + CGFloat(i % 10) * 15
                particles[i].position.x = center.x + CGFloat(cos(particles[i].angle)) * orbitDist
                particles[i].position.y = center.y + CGFloat(sin(particles[i].angle)) * orbitDist
                particles[i].opacity = 0.2
            }
        }
    }
}
