//
//  Gameplay.m
//  PeevedPenguins
//
//  Created by Deepak Natarajan on 5/7/14.
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "Gameplay.h"
#import "Penguin.h"
#import "CCPhysics+ObjectiveChipmunk.h"

static const float MIN_SPEED = 5.f;

@implementation Gameplay {
    CCPhysicsNode *_physicsNode;
    CCNode *_catapultArm, *_levelNode, *_contentNode, *_pullbackNode, *_mouseJointNode;
    Penguin *_currentPenguin;
    CCPhysicsJoint *_mouseJoint, *_penguinCatapultJoint;
    CCAction *_followPenguin;
}

- (void)didLoadFromCCB {
    // tell this scene to accept touches
    CCLOG(@"Enabling touch for Gameplay scene...");
    self.userInteractionEnabled = TRUE;
    
    CCScene *level = [CCBReader loadAsScene:@"Levels/Level1"];
    [_levelNode addChild:level];
    
    // visualize physics bodies and joints
    _physicsNode.debugDraw = TRUE;
    _pullbackNode.physicsBody.collisionMask = @[];
    _mouseJointNode.physicsBody.collisionMask = @[];
    
    _physicsNode.collisionDelegate = self;
}

- (void)touchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    //[self launchPenguin];
    CGPoint touchLocation = [touch locationInNode:_contentNode];
    
    // start catapult dragging when a touch inside of the catapult arm occurs
    if (CGRectContainsPoint([_catapultArm boundingBox], touchLocation)) {
        // move the mouseJointNode to the touch position
        _mouseJointNode.position = touchLocation;
        // set up a spring joint between the mouseJointNode and the catapultArm
        _mouseJoint = [CCPhysicsJoint connectedSpringJointWithBodyA:_mouseJointNode.physicsBody
                                                              bodyB:_catapultArm.physicsBody
                                                            anchorA:ccp(0,0)
                                                            anchorB:ccp(34,138)
                                                         restLength:0.f
                                                          stiffness:3000.f damping:150.f];
        
        // create a penguin from the ccb-file
        _currentPenguin = (Penguin *)[CCBReader load:@"Penguin"];
        // initially position it on the cata scoop - 34,138 is the position in the node space of the cata arm
        CGPoint penguinPosition = [_catapultArm convertToWorldSpace:ccp(34, 138)];
        // transform the world position to the node space to which the penguin will be added (_physicsNode)
        _currentPenguin.position = [_physicsNode convertToNodeSpace:penguinPosition];
        // add it to the physics world
        [_physicsNode addChild:_currentPenguin];
        // penguin should not rotate in the scoop
        _currentPenguin.physicsBody.allowsRotation = FALSE;
        
        // create a joint to keep the penguin fixed to the scoop until the catapult is released
        _penguinCatapultJoint = [CCPhysicsJoint connectedPivotJointWithBodyA:_currentPenguin.physicsBody
                                                                       bodyB:_catapultArm.physicsBody
                                                                     anchorA:_currentPenguin.anchorPointInPoints];
    }
}

- (void)touchMoved:(UITouch *)touch withEvent:(UIEvent *)event {
    // whenever touchs move, update the position of the mouseJointNode to the touch position
    CGPoint touchLocation = [touch locationInNode:_contentNode];
    _mouseJointNode.position = touchLocation;
}

- (void)touchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    // when touches end, i.e user releases their finger, release the catapult
    [self releaseCatapult];
}

- (void)touchCancelled:(UITouch *)touch withEvent:(UIEvent *)event {
    // when touches are cancelled, i.e user drags their finger off screen or onto something else
    // release the catapult
    [self releaseCatapult];
}


- (void)releaseCatapult {
    if (_mouseJoint != nil) {
        // releases the joint and let the catapult snap back
        [_mouseJoint invalidate];
        _mouseJoint = nil;
        
        // releases the joint and the penguin is away...
        [_penguinCatapultJoint invalidate];
        _penguinCatapultJoint = nil;
        
        // ..bring back rotation to the penguin
        _currentPenguin.physicsBody.allowsRotation = TRUE;
        
        // follow the flying penguin
        //CCActionFollow *follow = [CCActionFollow actionWithTarget:_currentPenguin worldBoundary:self.boundingBox];
        _followPenguin = [CCActionFollow actionWithTarget:_currentPenguin worldBoundary:self.boundingBox];
        [_contentNode runAction:_followPenguin];
        
        _currentPenguin.launched = TRUE;
    }
}

- (void)launchPenguin {
    // Load the Penguin CCB
    CCNode *penguin = [CCBReader load:@"Penguin"];
    // Position the penguin at the bowl of the catapult
    penguin.position = ccpAdd(_catapultArm.position, ccp(16, 50));
    
    // Add the penguin to the physicsNode of this scene because it - the penguin - has physics enabled
    [_physicsNode addChild:penguin];
    
    // Manually create and apply a force to launch the penguin
    CGPoint launchDirection = ccp(1, 0);
    CGPoint force = ccpMult(launchDirection, 8000);
    [penguin.physicsBody applyForce:force];
    
    // ensure followed object is in visible area	 when starting
    self.position = ccp(0, 0);
    //CCLOG(@"Bound box : %f", self.boundingBox.size.width);
    CCActionFollow *follow = [CCActionFollow actionWithTarget:penguin worldBoundary:self.boundingBox];
    [_contentNode runAction:follow];
}

- (void)retry {
    //reload this level
    [[CCDirector sharedDirector] replaceScene:[CCBReader loadAsScene:@"Gameplay"]];
}

// Collisions
- (void)ccPhysicsCollisionPostSolve:(CCPhysicsCollisionPair *)pair seal:(CCNode *)nodeA wildcard:(CCNode *)nodeB {
    //CCLOG(@"Something collided with a seal!");
    float energy = [pair totalKineticEnergy];
    // if energy is large enough, remove the seal
    if (energy > 5000.f) {
        [[_physicsNode space] addPostStepBlock:^{
            [self sealRemoved:nodeA];
        } key:nodeA];
    }
}

- (void)sealRemoved:(CCNode *)seal {
    CCLOG(@"Removing seal from : %f %f ", seal.position.x, seal.position.y);
    
    // Load particle effect
    CCParticleSystem *explosion = (CCParticleSystem *)[CCBReader load:@"SealExplosion"];
    // Particle effect should clean up, when done.
    explosion.autoRemoveOnFinish = TRUE;
    // place the particle effect on the seals position
    explosion.position = seal.position;
    // add the particle effect to the same node the seal is on!
    [seal.parent addChild:explosion];
    
    // ...finally, remove the seal
    [seal removeFromParent];
}

- (void)update:(CCTime)delta {
    // if speed is below minimum, assume this attempt is over
    if (ccpLength(_currentPenguin.physicsBody.velocity) < MIN_SPEED) {
        [self nextAttempt];
        return;
    }
    
    int xMin = _currentPenguin.boundingBox.origin.x;
    
    if (xMin < self.boundingBox.origin.x) {
        [self nextAttempt];
        return;
    }
    
    int xMax = xMin + _currentPenguin.boundingBox.size.width;
    
    if (xMax > (self.boundingBox.origin.x + self.boundingBox.size.width)) {
        [self nextAttempt];
        return;
    }
}

- (void)nextAttempt {
    if (_currentPenguin.launched) {
        CCLOG(@"Next Attempt!");
        /*
         The most important thing we need to do in the nextAttempt method is scrolling back to the catapult.
         However, since we already are running an action to follow the penguin, we need to stop this action
         before we start another scrolling action (otherwise Cocos2D would understandably be confused about
         these two conflicting instructions).
         */
        _currentPenguin = nil;
        [_contentNode stopAction:_followPenguin];
        
        CCActionMoveTo *actionMoveTo = [CCActionMoveTo actionWithDuration:1.f position:ccp(0,0)];
        [_contentNode runAction:actionMoveTo];
    }
}

@end
