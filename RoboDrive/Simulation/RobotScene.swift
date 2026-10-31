import SpriteKit
import UIKit

@MainActor final class RobotScene: SKScene {
    private weak var session: DriveSession?
    private let robot = SKNode()
    private let trail = SKShapeNode()
    private var checkpointNodes: [SKShapeNode] = []
    private var lastTime: TimeInterval?
    private var lastRouteCount = 0
    private let unit = 100.0

    init(session: DriveSession) {
        self.session = session
        super.init(size: CGSize(width: 1200, height: 800))
        scaleMode = .aspectFit
        backgroundColor = UIColor(red: 0.09, green: 0.13, blue: 0.19, alpha: 1)
        buildWorld(session.mission)
    }
    required init?(coder: NSCoder) { fatalError("Use init(session:)") }

    private func point(_ p: Vector2) -> CGPoint { CGPoint(x: p.x * unit, y: p.y * unit) }

    private func buildWorld(_ mission: Mission) {
        let gridPath = CGMutablePath()
        for x in stride(from: 0.0, through: 1200.0, by: 50) { gridPath.move(to: CGPoint(x: x, y: 0)); gridPath.addLine(to: CGPoint(x: x, y: 800)) }
        for y in stride(from: 0.0, through: 800.0, by: 50) { gridPath.move(to: CGPoint(x: 0, y: y)); gridPath.addLine(to: CGPoint(x: 1200, y: y)) }
        let grid = SKShapeNode(path: gridPath)
        grid.strokeColor = UIColor.white.withAlphaComponent(0.06); grid.lineWidth = 1
        addChild(grid)
        let border = SKShapeNode(rect: CGRect(x: 3, y: 3, width: 1194, height: 794), cornerRadius: 12)
        border.strokeColor = .systemGray; border.lineWidth = 5; addChild(border)
        for barrier in mission.barriers {
            let node = barrier.round ? SKShapeNode(circleOfRadius: barrier.width * unit / 2) : SKShapeNode(rectOf: CGSize(width: barrier.width * unit, height: barrier.height * unit), cornerRadius: 8)
            node.position = point(Vector2(x: barrier.x, y: barrier.y))
            node.fillColor = UIColor(red: 0.27, green: 0.34, blue: 0.43, alpha: 1)
            node.strokeColor = UIColor(red: 0.42, green: 0.51, blue: 0.62, alpha: 1)
            node.lineWidth = 3; node.zPosition = 2; addChild(node)
        }
        marker(mission.start, label: "СТАРТ", color: .systemBlue)
        if !mission.isFree {
            marker(mission.goal, label: "ФИНИШ", color: .systemGreen)
            for (i, p) in mission.checkpoints.enumerated() {
                let node = marker(p, label: String(i + 1), color: .systemOrange)
                checkpointNodes.append(node)
            }
        }
        trail.strokeColor = .systemCyan; trail.lineWidth = 4; trail.alpha = 0.65
        trail.zPosition = 3; addChild(trail)
        buildRobot(); addChild(robot)
        robot.position = point(mission.start); robot.zRotation = mission.heading
    }

    @discardableResult private func marker(_ p: Vector2, label: String, color: UIColor) -> SKShapeNode {
        let ring = SKShapeNode(circleOfRadius: 58)
        ring.fillColor = color.withAlphaComponent(0.12); ring.strokeColor = color; ring.lineWidth = 3
        ring.position = point(p); addChild(ring)
        let title = SKLabelNode(text: label)
        title.fontName = "AvenirNext-DemiBold"; title.fontSize = 19
        title.fontColor = color; title.verticalAlignmentMode = .center
        ring.addChild(title); return ring
    }

    private func buildRobot() {
        robot.zPosition = 5
        for y in [-24.0, 24.0] {
            let wheel = SKShapeNode(rectOf: CGSize(width: 44, height: 13), cornerRadius: 4)
            wheel.position.y = y; wheel.fillColor = .black; wheel.strokeColor = .systemGray
            robot.addChild(wheel)
        }
        let body = SKShapeNode(rectOf: CGSize(width: 48, height: 39), cornerRadius: 11)
        body.fillColor = .systemBlue; body.strokeColor = UIColor.systemCyan; body.lineWidth = 2
        robot.addChild(body)
        let center = SKShapeNode(circleOfRadius: 10)
        center.fillColor = UIColor.white.withAlphaComponent(0.15); center.strokeColor = .clear
        robot.addChild(center)
        let front = SKShapeNode(rectOf: CGSize(width: 7, height: 24), cornerRadius: 3)
        front.position.x = 17; front.fillColor = .white; front.strokeColor = .clear
        robot.addChild(front)
    }

    func resetClock() { lastTime = nil }

    override func update(_ currentTime: TimeInterval) {
        defer { lastTime = currentTime }
        guard let session else { return }
        let dt = lastTime.map { currentTime - $0 } ?? 0
        session.advance(dt)
        robot.position = point(session.engine.position)
        robot.zRotation = session.engine.heading
        trail.isHidden = !session.showTrail
        if lastRouteCount != session.engine.route.count {
            let path = CGMutablePath()
            for (i, p) in session.engine.route.enumerated() {
                if i == 0 { path.move(to: point(p)) } else { path.addLine(to: point(p)) }
            }
            trail.path = path; lastRouteCount = session.engine.route.count
        }
        for (i, node) in checkpointNodes.enumerated() { node.alpha = i < session.engine.checkpointIndex ? 0.25 : 1 }
    }
}
