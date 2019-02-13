//
//  GameScene.swift
//  SwiftyNinja
//
//  Created by Simon Italia on 1/14/19.
//  Copyright © 2019 SDI Group Inc. All rights reserved.
//

import SpriteKit
import AVFoundation
import GameplayKit

enum SequenceType: CaseIterable {
    case oneNoBomb, one, twoWithOneBomb, two, three, four, chain, fastChain
    
}

enum ForceBomb {
    
    case never, always, random
}

enum ForceBonus {
    
    case random
}

class GameScene: SKScene {
    
    let viewController = self
    
    var gameScore: SKLabelNode!
    var score = 0 {
        didSet {
            gameScore.text = "Score: \(score)"
        }
    }
    
    var lives = 3
    var livesImages = [SKSpriteNode]()
    
    //Slice shape Properties
    var activeSliceBackground: SKShapeNode!
    var activeSliceForeground: SKShapeNode!
    
    //Array property to track the points on the screen user touches, to draw a slice shape
    var activeSliceTouchPoints = [CGPoint]()
    
    //Sound properties
    var isSwooshSoundActive = false
    var bombSoundEffect: AVAudioPlayer!
    
    //Property to track active enemies in scene
    var activeEnemies = [SKSpriteNode]()
    
    //Properties for creating enemies
    var popupTime = 0.9
    var sequence = [SequenceType]()
    var sequencePosition = 0
    var chainDelay = 3.0
    var nextSequenceQueued = true
    
    var gameEnded = false
    
    override func didMove(to view: SKView) {
        
        let sceneBackground = SKSpriteNode(imageNamed: "sliceBackground")
        sceneBackground.position = CGPoint(x: 512, y: 384)
        sceneBackground.blendMode = .replace
        sceneBackground.zPosition = -1
        addChild(sceneBackground)
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
            //note! d denotes delta
        physicsWorld.speed = 0.85
        
        createGameScore()
        createLives()
        createSlicesEffects()
        
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]
        
        for _ in 0 ... 1000 {
            let nextSequence = SequenceType.allCases.randomElement()!
            sequence.append(nextSequence)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [unowned self] in
            self.tossEnemies()
        }
        
    }//End didMove() method
    
    func createGameScore() {
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.text = "Score: 0"
        gameScore.horizontalAlignmentMode = .left
        gameScore.fontSize = 48
        addChild(gameScore)

        gameScore.position = CGPoint(x: 8, y: 8)
    
    }//End createGameScore method()
    
    func createLives() {
        for i in 0 ..< 3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
            addChild(spriteNode)
            
            livesImages.append(spriteNode)
        }
        
    }//End createLives() method
    
    func createSlicesEffects() {
        
        activeSliceBackground = SKShapeNode()
        activeSliceBackground.zPosition = 2
        
        activeSliceForeground = SKShapeNode()
        activeSliceForeground.zPosition = 2
        
        activeSliceBackground.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
        activeSliceBackground.lineWidth = 9
        
        activeSliceForeground.strokeColor = UIColor.white
        activeSliceForeground.lineWidth = 5
        
        addChild(activeSliceBackground)
        addChild(activeSliceForeground)
    }
    
    //Track and do stuff when user first touches the screen
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        //1. Remove all existing touch points in activeSlicePoints array, to track just the new / active touch locations
        activeSliceTouchPoints.removeAll(keepingCapacity: true)
        
        //2. Get the active touch location and add it to activeSlicePoints array
        if let touch = touches.first {
            let touchLocation = touch.location(in: self)
            activeSliceTouchPoints.append(touchLocation)
            
            //3. Call redrawActiveSlice() to clear active slice shapes from screen
            redrawActiveSlice()
            
            //4. Remove actions currently attached to slice shapes (like fade
            activeSliceBackground.removeAllActions()
            activeSliceForeground.removeAllActions()
            
            //5. Set both slice shapes to have an alpha value of 1 so they are fully visible
            activeSliceBackground.alpha = 1
            activeSliceForeground.alpha = 1
        }
        
    }//End touchesBegan method
    
    //Track where on the screen the users's start and end touch points are
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if gameEnded {
            return
        }
        
        guard let touch = touches.first else { return }
        
        let touchLocation = touch.location(in: self)
        
        activeSliceTouchPoints.append(touchLocation)
        redrawActiveSlice()
        
        if !isSwooshSoundActive {
            playSwooshSound()
            
        }
        
        //Slice to win code
        let touchedNodes = nodes(at: touchLocation)
        
        for touchedNode in touchedNodes {
            if touchedNode.name == "enemy" || touchedNode.name == "enemyBonus" {
                //Slice enemy penguin nodes
                
                //1. Create particle effect
                let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy")!
                emitter.position = touchedNode.position
                addChild(emitter)
                
                //6. Update player score
                if touchedNode.name == "enemyBonus" {
                    score += 5
                    //Bonus points
                    
                } else {
                    score += 1
                    //Regular points
                }
                
                //2. Clear enemy penguin node, so it can't be swiped repeatedly
                touchedNode.name = ""
                
                //3. Stop enemy penguin node falling animation
                touchedNode.physicsBody?.isDynamic = false
                
                //4. Scale enemy penguin node in and out simultaneously
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([scaleOut, fadeOut])
                
                //5. Remove enemy penguin node from scene, using group object above
                let actionSequence = SKAction.sequence([group, SKAction.removeFromParent()])
                touchedNode.run(actionSequence)
                
                //6 Old code postion
                
                //7. Remove enemy penguion node from aciveEnemies array
                let index = activeEnemies.index(of: touchedNode as! SKSpriteNode)!
                activeEnemies.remove(at: index)
                
                //8. Play enemy penguin node hit sound
                run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
                
            } else if touchedNode.name ==  "bomb" {
                //Destroy bomb
                
                //1. Create particle effect
                let emitter = SKEmitterNode(fileNamed: "sliceHitBomb")!
                emitter.position = touchedNode.parent!.position
                addChild(emitter)
                
                //2. Clear enemy bomb node, so it can't be swiped repeatedly
                touchedNode.name = ""
                
                //3. Stop enemy bomb node falling animation
                touchedNode.parent?.physicsBody?.isDynamic = false
                
                //4. Sclae enemy bomb node in and out simultaneously
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([scaleOut, fadeOut])
                
                //5. Remove enemy bomb node from scene
                let actionSequence = SKAction.sequence([group, SKAction.removeFromParent()])
                touchedNode.parent?.run(actionSequence)
                
                //6. Remove enemy bomb node from aciveEnemies array (refrences enemy image node only, within enemy bombContainer)
                let index = activeEnemies.index(of: touchedNode.parent as! SKSpriteNode)!
                activeEnemies.remove(at: index)
                
                //7. Play enemy bomb node hit sound
                run(SKAction.playSoundFileNamed("explosion", waitForCompletion: false))
                
                //8. End game
                endGame(triggeredByBomb: true)
            }
        }
        
        
    }//End touchesMoved() method
    
    //Animation for when the user stops touching the screen
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        activeSliceBackground.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceForeground.run(SKAction.fadeOut(withDuration: 0.25))
    }
    
    //Allow for screen intrruptions (like a low battery alert) by calling touchesEnded()
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    func redrawActiveSlice() {
        
        //1. Only draw slice shape if we have > 1 points
        if activeSliceTouchPoints.count < 2 {
            activeSliceBackground.path = nil
            activeSliceForeground.path = nil
            return
        }
        
        //2. Keep slice length to max of 12 touch points, then start replacing oldest touch points in array
        while activeSliceTouchPoints.count > 12 {
            activeSliceTouchPoints.remove(at: 0)
        }
        
        //3. Start drawing line from first touch point, then draw connecting line through each subsequent touch point/s
        let path = UIBezierPath()
        path.move(to: activeSliceTouchPoints[0])
        
        for i in 1 ..< activeSliceTouchPoints.count {
            path.addLine(to: activeSliceTouchPoints[i])
        }
        
        //4. Update to drawn lines, with set designs (line width, color etc) as lines are drawn
        activeSliceBackground.path = path.cgPath
        activeSliceForeground.path = path.cgPath
        
    }//End redrawActiveSlice() method
    
    func playSwooshSound() {
        isSwooshSoundActive = true
        
        let randomNumber = Int.random(in: 1...3)
        let soundFileName = "swoosh\(randomNumber).caf"
        
        let swooshSound = SKAction.playSoundFileNamed(soundFileName, waitForCompletion: true)
        
        run(swooshSound) {[unowned self] in
            self.isSwooshSoundActive = false
        }
    }//End playSwooshSound() method
    
    func createEnemy(forceBomb: ForceBomb = .random) {
        
        var enemy: SKSpriteNode!
        var enemyType = Int.random(in: 0...6)
        
        //Set normal enemy penguin node
        if forceBomb == .never && enemyType != 3 {
            enemyType = 1
        
        //Set enemy bomb node
        } else if forceBomb == .always {
            enemyType = 0
            
        } else if forceBomb == .never && enemyType == 3 {
            enemyType = 2
        }
        
        //MARK: - Create bomb enemy
        if enemyType == 0 {
    
            //Bombs
            //1. Bomb and Fuse node images container
            enemy = SKSpriteNode()
            enemy.zPosition = 1
            enemy.name = "bombContainer"
            
            //2. Add Bomb Image and add to enemy bombContainer
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb"
            enemy.addChild(bombImage)
            
            //3. Stop bomb fuse sound effect if playing
            if bombSoundEffect != nil {
                bombSoundEffect.stop()
                bombSoundEffect = nil
            }
            
            //4. Create new bomb fuse sound effect, and play
            let path = Bundle.main.path(forResource: "sliceBombFuse.caf", ofType: nil)!
            let url = URL(fileURLWithPath: path)
            let sound = try! AVAudioPlayer(contentsOf: url)
            bombSoundEffect = sound
            sound.play()
            
            //5. Create particle emitter for bomb fuse and add to enemy bombContainer
            let emitter = SKEmitterNode(fileNamed: "sliceFuse")!
            emitter.position = CGPoint(x: 76, y: 64)
            enemy.addChild(emitter)
            
        //Create bonus enemy penguin node/s
        } else if enemyType == 2 {
                enemy = SKSpriteNode(imageNamed: "penguinBonus")
                run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
                enemy.name = "enemyBonus"
         
        //Create regular enemy penguin node
        } else {
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemy"

        }
        
        //MARK: - Postion and move enemy
        
        //1. Give enemy random position from bottom edge of screen
        let randomPosition = CGPoint(x: Int.random(in: 64...960), y: -128)
        enemy.position = randomPosition
        
        //2. Create random angular velocity (spinning speed)
        let randomAngularVelocity = CGFloat.random(in: -6...6) / 2.0
        
        //3. Create random x velocity (distance to move horizontally in relation to current position)
        var randomXVelocity = 0
        
        if randomPosition.x < 256 {
            randomXVelocity = Int.random(in: 8...15)

        
        } else if randomPosition.x < 512 {
            randomXVelocity = Int.random(in: 3...5)
            
        } else if randomPosition.x < 768 {
            randomXVelocity = -Int.random(in: 3...5)
            
        } else {
            randomXVelocity = -Int.random(in: 8...15)
        }
        
        //4. Create random y velocity to make enemeis move at different speeds
        let randomYVelocity = Int.random(in: 24...32)
        
        //5. Give enemies circular physics body with collisionBitMask set to 0 so enemies don't collide
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
        enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody?.angularVelocity = randomAngularVelocity
        enemy.physicsBody?.collisionBitMask = 0
        
        addChild(enemy)
        activeEnemies.append(enemy)
    
    }//End createEnemy() method
    
    override func update(_ currentTime: TimeInterval) {
        //This method is called before drawing each frame
        
        //Handle new game
        if gameEnded {
            
            //Display alert with score
            let alertController = UIAlertController(title: "Game Over", message: "Your score: \(score)", preferredStyle: .alert)
            
            //Display Play again button
            alertController.addAction(UIAlertAction(title: "Play again?", style: .default, handler: {
                action in self.restartGame()
            }))
            
            self.view?.window?.rootViewController?.present(alertController, animated: true)
            
            gameEnded = false
            
            return
        }
        
        if activeEnemies.count > 0 {
            for node in activeEnemies {
                
                if node.position.y < -140 {
                    node.removeAllActions()
                    
                    if node.name == "enemy" || node.name == "enemyBonus"{
                        node.name = ""
                        subtractLife()
                        
                        node.removeFromParent()
                        
                        if let index = activeEnemies.index(of: node) {
                            activeEnemies.remove(at: index)
                        }
                    
                    } else if node.name == "bombContainer" {
                        node.name = ""
                        node.removeFromParent()
                        
                        if let index = activeEnemies.index(of: node) {
                            activeEnemies.remove(at: index)
                        }
                    }
                }
            }
            
        } else {
            if !nextSequenceQueued {
                DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) { [unowned self] in
                    self.tossEnemies()
                }
                
                nextSequenceQueued = true
            }
        }
        
        var bombCount = 0
        
        //Bomb/s in scene, play fuse sound
        for node in activeEnemies {
            if node.name == "bombContainer" {
                bombCount += 1
                break
            }
        }
        
        if bombCount == 0 {
            //No Bomb in scene, stop fuse sound
            if bombSoundEffect != nil {
                bombSoundEffect.stop()
                bombSoundEffect = nil
            }
        }
        
    }//End update() method
    
    func tossEnemies() {
        
        if gameEnded {
            return
        }
        
        popupTime *= 0.991
        chainDelay *= 0.99
        physicsWorld.speed *= 1.02
        
        let sequenceType = sequence[sequencePosition]
        
        switch sequenceType {
            
        case .oneNoBomb:
            createEnemy(forceBomb: .never)
            
        case .one:
            createEnemy()
            
        case .twoWithOneBomb:
            createEnemy(forceBomb: .never)
            createEnemy(forceBomb: .always)
            
        case .two:
            createEnemy()
            createEnemy()
            
        case .three:
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .four:
            createEnemy()
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .chain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) { [unowned self] in self.createEnemy() }
            
        case .fastChain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) { [unowned self] in self.createEnemy() }
        }
        
        sequencePosition += 1
        nextSequenceQueued = false
    
    }//End tossEenemies() method
    
    func subtractLife() {
        lives -= 1
        
        run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        
        var life: SKSpriteNode
        
        if lives == 2 {
            life = livesImages[0]
            
        } else if lives == 1 {
            life = livesImages[1]
        
        } else {
            life = livesImages[2]
            endGame(triggeredByBomb: false)
        }
        
        //Modify content of existing priteNode (rather than recreate node) withSKTexture
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        
        life.xScale = 1.3
        life.yScale = 1.3
        life.run(SKAction.scale(to: 1, duration: 0.1))
    }
    
    func endGame(triggeredByBomb: Bool) {
        
        if gameEnded {
            return
        }
        
        gameEnded = true
        physicsWorld.speed = 0
        isUserInteractionEnabled = false
        
        let gameOver = SKSpriteNode(imageNamed: "gameOver")
        gameOver.position = CGPoint(x: 512, y: 384)
        gameOver.zPosition = 1
        addChild(gameOver)
        run(SKAction.playSoundFileNamed("gameOver.caf", waitForCompletion: true))
        
        if bombSoundEffect != nil {
            bombSoundEffect.stop()
            bombSoundEffect = nil
        }
        
        if triggeredByBomb {
            livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
            
//            for livesImage in livesImages {
//                livesImage.texture = SKTexture(imageNamed: "sliceLifeGone")
//            }
        }

    } //End endGame() method
    
    func restartGame() {
        
        gameEnded = false
        
        let nextScene = GameScene(size: self.scene!.size)
        nextScene.scaleMode = self.scaleMode
        nextScene.backgroundColor = UIColor.black
        self.view?.presentScene(nextScene, transition: SKTransition.fade(with: UIColor.black, duration: 1.5))
        
    }
}

