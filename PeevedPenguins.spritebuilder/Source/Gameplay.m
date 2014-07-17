//
//  Gameplay.m
//  PeevedPenguins
//
//  Created by Deepak Natarajan on 5/7/14.
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "Gameplay.h"

@implementation Gameplay {
    CCPhysicsNode *_physicsNode;
    CCNode *_catapultArm, *_levelNode, *_contentNode, *_pullbackNode, *_mouseJointNode, *_currentPenguin;
    CCPhysicsJoint *_mouseJoint, *_penguinCatapultJoint;
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
        _currentPenguin = [CCBReader load:@"Penguin"];
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
        CCActionFollow *follow = [CCActionFollow actionWithTarget:_currentPenguin worldBoundary:self.boundingBox];
        [_contentNode runAction:follow];
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

@end
