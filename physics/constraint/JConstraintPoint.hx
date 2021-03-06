package jiglib.physics.constraint;

import jiglib.math.*;
import jiglib.physics.RigidBody;
import jiglib.physics.PhysicsSystem;

// Constraints a point on one body to be fixed to a point on another body
class JConstraintPoint extends JConstraint
{
    
    private inline var _maxVelMag : Float = 20;
    private inline var _minVelForProcessing : Float = 0.01;
    
    
    private var _body0 : RigidBody;
    private var _body1 : RigidBody;
    private var _body0Pos : Vector3D;
    private var _body1Pos : Vector3D;
    
    private var _timescale : Float;
    private var _allowedDistance : Float;
    
    private var r0 : Vector3D;
    private var r1 : Vector3D;
    private var _worldPos : Vector3D;
    private var _vrExtra : Vector3D;
    
    /// allowed_distance indicated how much the points are allowed to deviate.
    /// timescale indicates the timescale over which deviation is eliminated
    /// (suggest a few times dt - be careful if there's a variable timestep!)
    /// if timescale < 0 then the value indicates the number of dts
    public function new(body0 : RigidBody, body0Pos : Vector3D, body1 : RigidBody, body1Pos : Vector3D, allowedDistance : Float = 1, timescale : Float = 1)
    {
        super();
        _body0 = body0;
        _body0Pos = body0Pos;
        _body1 = body1;
        _body1Pos = body1Pos;
        _allowedDistance = allowedDistance;
        _timescale = timescale;
        if (_timescale < JMath3D.NUM_TINY) 
        {
            _timescale = JMath3D.NUM_TINY;
        }
        
        _constraintEnabled = false;
        enableConstraint();
    }
    
    override public function enableConstraint() : Void
    {
        if (_constraintEnabled) 
        {
            return;
        }
        _constraintEnabled = true;
        _body0.addConstraint(this);
        _body1.addConstraint(this);
        PhysicsSystem.getInstance().addConstraint(this);
    }
    
    override public function disableConstraint() : Void
    {
        if (!_constraintEnabled) 
        {
            return;
        }
        _constraintEnabled = false;
        _body0.removeConstraint(this);
        _body1.removeConstraint(this);
        PhysicsSystem.getInstance().removeConstraint(this);
    }
    
    override public function preApply(dt : Float) : Void
    {
        this.satisfied = false;
        
        r0 = _body0.currentState.orientation.transformVector(_body0Pos);
        r1 = _body1.currentState.orientation.transformVector(_body1Pos);
        
        var worldPos0 : Vector3D;
        var worldPos1 : Vector3D;
        var deviation : Vector3D;
        var deviationAmount : Float;
        worldPos0 = _body0.currentState.position.add(r0);
        worldPos1 = _body1.currentState.position.add(r1);
        _worldPos = JNumber3D.getScaleVector(worldPos0.add(worldPos1), 0.5);
        
        deviation = worldPos0.subtract(worldPos1);
        deviationAmount = deviation.length;
        if (deviationAmount > _allowedDistance) 
        {
            _vrExtra = JNumber3D.getScaleVector(deviation, (deviationAmount - _allowedDistance) / (deviationAmount * Math.max(_timescale, dt)));
        }
        else 
        {
            _vrExtra = new Vector3D();
        }
    }
    
    override public function apply(dt : Float) : Bool
    {
        this.satisfied = true;
        
        if (!_body0.isActive && !_body1.isActive) 
        {
            return false;
        }
        
        var normalVel : Float;
        var denominator : Float;
        var currentVel0 : Vector3D;
        var currentVel1 : Vector3D;
        var Vr : Vector3D;
        var N : Vector3D;
        var tempVec1 : Vector3D;
        var tempVec2 : Vector3D;
        var normalImpulse : Vector3D;
        currentVel0 = _body0.getVelocity(r0);
        currentVel1 = _body1.getVelocity(r1);
        Vr = _vrExtra.add(currentVel0.subtract(currentVel1));
        
        normalVel = Vr.length;
        if (normalVel < _minVelForProcessing) 
        {
            return false;
        }
        
        if (normalVel > _maxVelMag) 
        {
            Vr = JNumber3D.getScaleVector(Vr, _maxVelMag / normalVel);
            normalVel = _maxVelMag;
        }
        
        N = JNumber3D.getDivideVector(Vr, normalVel);
        tempVec1 = r0.crossProduct(N);
        tempVec1 = _body0.worldInvInertia.transformVector(tempVec1);
        tempVec2 = r1.crossProduct(N);
        tempVec2 = _body1.worldInvInertia.transformVector(tempVec2);
        denominator = _body0.invMass + _body1.invMass + N.dotProduct(tempVec1.crossProduct(r0)) + N.dotProduct(tempVec2.crossProduct(r1));
        if (denominator < JMath3D.NUM_TINY) 
        {
            return false;
        }
        
        normalImpulse = JNumber3D.getScaleVector(N, -normalVel / denominator);
        _body0.applyWorldImpulse(normalImpulse, _worldPos, false);
        _body1.applyWorldImpulse(JNumber3D.getScaleVector(normalImpulse, -1), _worldPos, false);
        
        _body0.setConstraintsAndCollisionsUnsatisfied();
        _body1.setConstraintsAndCollisionsUnsatisfied();
        this.satisfied = true;
        return true;
    }
}


