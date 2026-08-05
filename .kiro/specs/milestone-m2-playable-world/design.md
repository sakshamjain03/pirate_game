# Design Document: Milestone M2 - Playable World

**Feature:** milestone-m2-playable-world  
**Status:** Design Phase  
**Target Engine:** Godot 4.x  
**Primary Language:** GDScript  

## 1. Overview

Milestone M2 delivers the first playable world for Pirate Empire, establishing the foundational gameplay systems that will support all three core pillars (Build, Explore, Conquer). This milestone focuses on creating an engaging, interactive ocean environment where players can explore, navigate, and interact with the world.

### 1.1 Goal
Create a fully playable world scene where players can:
- Navigate their ship through an ocean environment
- Explore and discover islands
- Transition from the main menu to the world
- Dock at islands to trigger basic events
- Experience core movement and camera controls

### 1.2 Scope (M2)
- **In Scope:**
  - World scene with ocean environment
  - Ocean rendering and water simulation
  - Third-person camera controller
  - Player ship with basic movement
  - Basic island assets and placement
  - Input handling system
  - Main Menu → World transition
  - Docking mechanics at islands
  - Basic event triggers
  
- **Out of Scope:**
  - Combat systems
  - Economy mechanics
  - Building construction
  - AI behavior
  - World streaming
  - Floating origin system
  - Procedural generation
  - Multiplayer functionality
  - Save/load gameplay state

### 1.3 Design Philosophy
- **Mobile-first:** Controls must work well on touch devices
- **Performance:** Optimize for mobile hardware constraints
  - Simple geometry, efficient shaders
  - Limited draw calls and batch rendering
  - Efficient collision detection
- **Modularity:** Each system should be independently testable and replaceable
- **Scalability:** Architecture must support future expansion (more islands, ships, mechanics)

## 2. Architecture

### 2.1 Scene Hierarchy

```
World (Node3D)
├── Environment
│   ├── WorldEnvironment (WorldEnvironment)
│   ├── DirectionalLight (DirectionalLight3D)
│   └── Fog (FogVolume)
├── Ocean (OceanController)
│   ├── WaterMesh (MeshInstance3D)
│   ├── WaterMaterial (ShaderMaterial)
│   └── WaveGenerator (WaveGenerator)
├── PlayerShip (RigidBody3D)
│   ├── ShipModel (Node3D)
│   │   ├── Hull (MeshInstance3D)
│   │   ├── Sails (MeshInstance3D)
│   │   └── Mast (MeshInstance3D)
│   ├── ShipController (ShipController)
│   ├── MovementComponent (ShipMovement)
│   ├── BuoyancyComponent (BuoyancySimulator)
│   └── CollisionShape (CollisionShape3D)
├── CameraRig (CameraRig)
│   ├── CameraPivot (Node3D)
│   ├── CameraArm (SpringArm3D)
│   └── MainCamera (Camera3D)
├── Islands (Node3D)
│   ├── Island_001 (StaticBody3D)
│   │   ├── IslandModel (MeshInstance3D)
│   │   ├── DockArea (Area3D)
│   │   └── IslandTrigger (Area3D)
│   └── Island_002 (StaticBody3D)
├── WorldUI (CanvasLayer)
│   ├── SpeedIndicator (Label)
│   ├── Compass (TextureRect)
│   └── DockPrompt (Panel)
└── Systems (Node)
    ├── InputManager (InputManager)
    ├── WorldManager (WorldManager)
    └── EventManager (EventManager)
```

### 2.2 Script Architecture

**Core Scripts:**
- `WorldManager.gd` - Manages world state, transitions, and high-level logic
- `InputManager.gd` - Handles input mapping and distribution
- `OceanController.gd` - Controls ocean rendering and water simulation
- `ShipController.gd` - Main ship control logic, aggregates components
- `CameraRig.gd` - Third-person camera controller

**Component Scripts:**
- `ShipMovement.gd` - Handles ship physics and movement calculations
- `BuoyancySimulator.gd` - Simulates buoyancy and wave interaction
- `DockingSystem.gd` - Manages docking logic and island interactions
- `WaveGenerator.gd` - Generates procedural ocean waves

**Manager Scripts:**
- `EventManager.gd` - Handles world events and triggers
- `AudioManager.gd` (existing) - Handles world sounds and ocean audio
- `SceneManager.gd` (existing) - Handles scene transitions

### 2.3 Manager Responsibilities

**WorldManager:**
- Maintains world state (time of day, weather conditions)
- Manages island discovery and exploration state
- Handles transitions between world and other scenes
- Coordinates between other managers

**InputManager:**
- Maps physical inputs to game actions
- Handles touch gestures for mobile
- Provides input buffering and smoothing
- Manages input contexts (menu vs gameplay)

**EventManager:**
- Manages event triggers and conditions
- Handles island docking events
- Coordinates scripted sequences
- Manages basic world events (storms, treasure spawns)

**AudioManager (existing):**
- Plays ocean and ship sounds
- Manages spatial audio for islands
- Handles UI sound effects

### 2.4 Signals (Event-Driven Communication)

```gdscript
# WorldManager signals
signal world_loaded()
signal island_discovered(island_id: String)
signal player_docked(island_id: String)
signal world_event_triggered(event_name: String, data: Dictionary)

# ShipController signals
signal ship_speed_changed(speed: float)
signal ship_damaged(damage: float)
signal ship_docked()
signal ship_undocked()

# InputManager signals
signal input_action_triggered(action: String, strength: float)
signal touch_gesture_detected(gesture: String, data: Dictionary)

# CameraRig signals
signal camera_mode_changed(mode: String)
signal camera_target_changed(target: Node3D)

# DockingSystem signals
signal dock_area_entered(island_id: String)
signal dock_area_exited(island_id: String)
signal dock_initiated(island_id: String)
signal dock_completed(island_id: String)
```

### 2.5 Input Actions

**Input Map Configuration:**
```gdscript
# Movement
const ACTION_SHIP_FORWARD = "ship_forward"
const ACTION_SHIP_BACKWARD = "ship_backward"
const ACTION_SHIP_LEFT = "ship_left"
const ACTION_SHIP_RIGHT = "ship_right"

# Camera
const ACTION_CAMERA_ZOOM_IN = "camera_zoom_in"
const ACTION_CAMERA_ZOOM_OUT = "camera_zoom_out"
const ACTION_CAMERA_ROTATE_LEFT = "camera_rotate_left"
const ACTION_CAMERA_ROTATE_RIGHT = "camera_rotate_right"

# Interactions
const ACTION_DOCK = "dock"
const ACTION_INTERACT = "interact"
const ACTION_PAUSE = "pause"

# Touch gestures (mobile)
const GESTURE_SWIPE = "swipe"
const GESTURE_TAP = "tap"
const GESTURE_PINCH = "pinch"
```

**Mobile Input Handling:**
- Touch screen: Virtual joystick for movement
- Two-finger drag: Camera rotation
- Pinch: Camera zoom
- Tap: Interact with islands
- Swipe: Quick camera adjustments

### 2.6 Camera Behavior

**Third-Person Camera System:**
- SpringArm3D-based camera with smooth follow
- Collision detection to avoid clipping through geometry
- Multiple camera modes:
  - **Follow Mode:** Standard third-person follow
  - **Orbit Mode:** Free rotation around ship
  - **Look Mode:** Focus on target (islands, points of interest)
  
**Camera Features:**
- Smooth interpolation for position and rotation
- Adjustable distance (zoom) with limits
- Collision avoidance (pulls in when obstructed)
- Screen-space UI elements stay visible
- Motion damping for fluid feel

**Camera Constraints:**
- Minimum distance: 10 units (close-up)
- Maximum distance: 50 units (far view)
- Vertical angle limits: -30° to 60°
- Smoothing factor: 0.1s (adjustable)

### 2.7 Ship Movement Architecture

**Physics-Based Movement:**
- RigidBody3D for realistic physics interaction
- Custom buoyancy simulation for wave interaction
- Propulsion system based on sail orientation
- Turning mechanics with realistic momentum

**Movement Components:**
1. **Propulsion System:** Converts wind/sail input to forward force
2. **Steering System:** Applies torque for turning
3. **Buoyancy System:** Simulates water displacement and floating
4. **Drag System:** Simulates water resistance
5. **Stabilization System:** Prevents excessive rocking

**Movement Parameters (Configurable via Resources):**
```gdscript
@export_group("Movement")
@export_range(0.0, 100.0) var max_speed: float = 30.0
@export_range(0.0, 10.0) var acceleration: float = 2.0
@export_range(0.0, 10.0) var deceleration: float = 1.5
@export_range(0.0, 10.0) var turn_rate: float = 1.5
@export_range(0.0, 1.0) var drift_factor: float = 0.3
```

### 2.8 Ocean Rendering Approach

**Visual Requirements:**
- Mobile-friendly performance (60 FPS target)
- Dynamic waves with visible motion
- Realistic water shader with reflections/refractions
- Adjustable water quality settings

**Ocean Implementation:**
1. **Base Mesh:** Low-poly grid mesh for ocean surface
2. **Shader:** Custom water shader with:
   - Wave distortion (vertex displacement)
   - Fresnel effect for water edge
   - Simple reflections (cubemap-based)
   - Depth-based transparency
3. **Wave System:** 
   - Gerstner wave algorithm for realistic waves
   - Multiple wave layers (primary, secondary, ripple)
   - Wind direction influence
   - Performance-optimized calculations

**Performance Optimizations:**
- LOD system for distant water
- Culled backface polygons
- Shader LOD based on distance
- Limited wave count (4-8 waves max)

### 2.9 Folder/File Structure

```
scenes/
├── world/
│   ├── World.tscn
│   ├── Ocean.tscn
│   ├── PlayerShip.tscn
│   ├── CameraRig.tscn
│   ├── Island.tscn (template)
│   └── DockArea.tscn
├── ui/
│   └── WorldHUD.tscn
└── core/
    └── (existing scenes)

scripts/
├── world/
│   ├── WorldManager.gd
│   ├── OceanController.gd
│   ├── ShipController.gd
│   ├── CameraRig.gd
│   ├── ShipMovement.gd
│   ├── BuoyancySimulator.gd
│   ├── DockingSystem.gd
│   ├── WaveGenerator.gd
│   └── InputManager.gd
├── components/
│   ├── ShipComponent.gd (base class)
│   ├── BuoyancyComponent.gd
│   └── MovementComponent.gd
├── managers/
│   ├── WorldManager.gd
│   ├── EventManager.gd
│   └── InputManager.gd
└── core/ (existing)

resources/
├── world/
│   ├── ShipStats.tres
│   ├── OceanSettings.tres
│   ├── CameraSettings.tres
│   └── IslandData.tres
├── materials/
│   ├── OceanMaterial.tres
│   ├── ShipMaterial.tres
│   └── IslandMaterial.tres
└── ui/ (existing)

assets/
├── models/
│   ├── ships/
│   │   └── player_ship.glb
│   └── islands/
│       ├── island_small.glb
│       └── island_large.glb
├── textures/
│   ├── water/
│   │   ├── water_normal.png
│   │   └── water_foam.png
│   └── ships/
└── audio/
    ├── ocean/
    │   ├── waves.wav
    │   └── sea_ambience.wav
    └── ships/
        ├── sail_deploy.wav
        └── sail_retract.wav
```

### 2.10 Resource Definitions

**ShipStats Resource:**
```gdscript
@tool
class_name ShipStats extends Resource

@export_group("Movement")
@export_range(0.0, 100.0) var max_speed: float = 30.0
@export_range(0.0, 10.0) var acceleration: float = 2.0
@export_range(0.0, 10.0) var deceleration: float = 1.5
@export_range(0.0, 10.0) var turn_rate: float = 1.5

@export_group("Physics")
@export_range(0.0, 10000.0) var mass: float = 5000.0
@export_range(0.0, 1.0) var buoyancy: float = 0.8
@export_range(0.0, 1.0) var stability: float = 0.7

@export_group("Visual")
@export var model_path: String = "res://assets/models/ships/player_ship.glb"
@export var material_path: String = "res://resources/materials/ShipMaterial.tres"
```

**OceanSettings Resource:**
```gdscript
@tool
class_name OceanSettings extends Resource

@export_group("Waves")
@export_range(0.0, 10.0) var wave_height: float = 2.0
@export_range(0.0, 10.0) var wave_length: float = 20.0
@export_range(0.0, 10.0) var wave_speed: float = 1.0
@export var wind_direction: Vector2 = Vector2(1.0, 0.0)

@export_group("Visual")
@export_color_no_alpha var water_color: Color = Color("#1a5fb4")
@export_range(0.0, 1.0) var transparency: float = 0.6
@export_range(0.0, 1.0) var reflectivity: float = 0.3
```

### 2.11 Risks

**Technical Risks:**
1. **Performance on Mobile:** Complex ocean shaders and physics may impact mobile performance
   - Mitigation: Implement quality settings, LOD systems, and performance profiling
   
2. **Physics Stability:** RigidBody3D with custom buoyancy may cause instability
   - Mitigation: Thorough testing, damping factors, and fallback behaviors
   
3. **Camera Clipping:** Third-person camera may clip through geometry
   - Mitigation: SpringArm3D collision detection, camera wall avoidance
   
4. **Input Complexity:** Supporting both touch and controller inputs
   - Mitigation: Abstract input layer, extensive testing on target devices

**Design Risks:**
1. **Movement Feel:** Ship movement may feel too heavy or too arcade-like
   - Mitigation: Iterative testing, player feedback, adjustable parameters
   
2. **World Scale:** Getting the right sense of scale for islands vs ocean
   - Mitigation: Reference studies, player testing, adjustable scaling
   
3. **Docking Experience:** Transition from sailing to docking may feel jarring
   - Mitigation: Smooth camera transitions, visual feedback, audio cues

**Scope Risks:**
1. **Feature Creep:** Adding combat or economy systems prematurely
   - Mitigation: Strict adherence to M2 scope, separate backlog for future features
   
2. **Art Asset Delays:** 3D models and textures may take longer than expected
   - Mitigation: Use placeholder assets, prioritize gameplay over polish

### 2.12 Implementation Phases

**Phase 1: Core Systems (Week 1-2)**
- Set up world scene structure
- Implement basic ship movement (without physics)
- Create camera controller
- Establish input handling system
- Set up basic ocean mesh and material

**Phase 2: Physics & Environment (Week 3-4)**
- Implement RigidBody3D-based ship physics
- Add buoyancy simulation
- Create wave generation system
- Add basic island assets and collision
- Implement docking detection system

**Phase 3: Polish & Integration (Week 5-6)**
- Refine movement feel and camera behavior
- Add visual effects (water foam, wake trails)
- Implement audio system integration
- Create world UI (speed, compass, dock prompts)
- Integrate with main menu transition
- Performance optimization and testing

**Phase 4: Testing & Refinement (Week 7-8)**
- Mobile device testing
- Performance profiling and optimization
- User testing for movement feel
- Bug fixing and polish
- Documentation and code review

### 2.13 Success Criteria

**Technical Success:**
- Stable 60 FPS on target mobile devices
- No camera clipping or visual artifacts
- Smooth input response (< 100ms latency)
- Memory usage under 500MB
- Clean, modular code architecture

**Design Success:**
- Intuitive controls (learnable in < 5 minutes)
- Satisfying movement feel
- Clear visual feedback for all actions
- Seamless transitions between states
- Engaging exploration experience

**Milestone Completion:**
- Complete playable world scene
- All M2 scope items implemented
- No blocking bugs
- Documentation updated
- Ready for M3 integration

## 3. Technical Specifications

### 3.1 Performance Targets
- **Frame Rate:** 60 FPS (target), 30 FPS (minimum)
- **Memory:** < 500MB total usage
- **Draw Calls:** < 100 per frame
- **Triangle Count:** < 50k visible triangles
- **Physics Steps:** 60 Hz fixed update

### 3.2 Platform Support
- **Primary:** Android/iOS mobile devices
- **Secondary:** Windows/Mac/Linux (for development)
- **Input Methods:** Touch screen, gamepad, keyboard/mouse

### 3.3 Quality Settings
- **Low:** Simple water, no reflections, reduced wave count
- **Medium:** Basic reflections, normal maps, standard waves
- **High:** Full reflections, detailed waves, foam effects
- **Auto:** Dynamic adjustment based on device capability

### 3.4 Data Configuration
All gameplay parameters should be configurable via Resource files:
- Ship movement characteristics
- Camera behavior settings
- Ocean wave parameters
- Island placement and properties
- Input sensitivity and dead zones

## 4. Future Considerations

### 4.1 M3 Integration
This design anticipates integration with M3 (Combat & Economy):
- Ship controller designed to accept combat components
- Event system extensible for combat triggers
- Resource system compatible with economy data
- Architecture supports additional ship types

### 4.2 Scalability
- Modular component system allows easy addition of new features
- Resource-driven configuration supports content expansion
- Signal-based communication minimizes coupling
- Performance-conscious design supports larger worlds

### 4.3 Multiplayer Readiness
While M2 is single-player only, the architecture considers future multiplayer:
- State management separated from presentation
- Event-driven communication simplifies networking
- Component-based design supports client-side prediction
- Input system abstracted for network input

## 5. Conclusion

Milestone M2 establishes the foundational gameplay experience for Pirate Empire, creating an engaging ocean world where players can explore, navigate, and interact. The modular, data-driven architecture ensures scalability for future milestones while maintaining performance on mobile platforms.

The design prioritizes:
1. **Mobile-first controls** that feel intuitive on touch devices
2. **Modular systems** that can be independently developed and tested
3. **Performance optimization** for smooth gameplay on target hardware
4. **Scalable architecture** that supports future content expansion
5. **Clean separation** between gameplay logic and presentation

This design provides a solid foundation for the three core pillars of Pirate Empire (Build, Explore, Conquer) while focusing specifically on the exploration pillar for M2.

## 6. Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Camera Following Bounds
*For any* ship movement and position, the camera shall maintain a distance between minimum and maximum follow distances from the ship, and shall not exceed vertical angle limits.
**Validates: Requirements 2.1.2, 2.3.1, 2.3.2**

### Property 2: Camera Obstacle Avoidance  
*For any* obstacle geometry near the ship, the camera shall adjust its position to avoid clipping through the obstacle while maintaining view of the ship.
**Validates: Requirements 2.3.3**

### Property 3: Smooth Camera Damping
*For any* ship acceleration and movement, the camera shall follow with smooth damping such that camera velocity changes are continuous and bounded by the defined damping factor.
**Validates: Requirements 2.3.4**

### Property 4: Proportional Movement Response
*For any* forward input strength between 0.0 and 1.0, the ship's acceleration shall be proportional to the input strength according to the defined acceleration curve.
**Validates: Requirements 2.4.1**

### Property 5: Realistic Turning Physics
*For any* turn input and current velocity, the ship shall rotate with appropriate momentum and exhibit drift proportional to velocity and turn rate.
**Validates: Requirements 2.4.2, 2.5.2**

### Property 6: Water Resistance Deceleration
*For any* initial velocity when no input is given, the ship shall decelerate at a rate defined by water resistance parameters until reaching zero velocity.
**Validates: Requirements 2.4.3**

### Property 7: Wave Interaction Physics
*For any* wave height at the ship's position, the ship shall pitch and roll proportionally to the wave height and frequency, maintaining stability within defined limits.
**Validates: Requirements 2.4.4, 2.2.3**

### Property 8: Input Response Latency
*For any* valid input command, the system shall process and respond with visible movement within 100 milliseconds.
**Validates: Requirements 2.5.1**

### Property 9: Reverse Maneuverability Constraint
*For any* turn input, the ship's turning rate while moving backward shall be reduced compared to forward movement at the same speed.
**Validates: Requirements 2.5.3**

### Property 10: Docking Proximity Detection
*For any* ship position within a dock area's boundaries, the system shall display docking prompts and enable docking interaction.
**Validates: Requirements 2.6.2, 2.9.1**

### Property 11: Docking Speed Validation
*For any* attempted docking action, if the ship's speed exceeds the maximum docking threshold, docking shall be prevented and appropriate feedback provided.
**Validates: Requirements 2.9.5**

### Property 12: Docking Alignment Automation
*For any* valid docking initiation, the ship shall automatically rotate toward and align with the dock orientation within defined tolerance limits.
**Validates: Requirements 2.9.2**

### Property 13: Docked State Control Transition
*In any* docked state, ship movement controls shall be disabled and island interaction controls shall be enabled, with the transition being immediate and complete.
**Validates: Requirements 2.9.3**

### Property 14: Input Method Priority
*For any* sequence of inputs from multiple devices, the system shall process the most recently active input method, with clear transitions between input methods.
**Validates: Requirements 2.7.4**

### Property 15: Input Sensitivity Application
*For any* change to input sensitivity settings, subsequent input processing shall immediately reflect the new sensitivity values.
**Validates: Requirements 2.7.5**

### Property 16: Event Condition Satisfaction
*For any* world event with defined trigger conditions, when all conditions are satisfied, the event shall trigger exactly once.
**Validates: Requirements 2.10.2**

### Property 17: Event Priority Resolution
*For any* game state where multiple events have satisfied trigger conditions, the event with the highest priority shall trigger first.
**Validates: Requirements 2.10.4**

### Property 18: Docking Event Triggering
*For any* successful docking completion, the system shall trigger appropriate docking events (discovery, interaction) exactly once.
**Validates: Requirements 2.10.1**

### Property 19: Wave Animation Continuity
*For any* time delta, wave positions and heights shall update continuously according to the wave equation, with no discontinuities or visual artifacts.
**Validates: Requirements 2.2.1**

### Property 20: Wake Trail Correlation
*For any* ship velocity, the wake trail's size, intensity, and persistence shall correlate proportionally with the ship's speed and direction.
**Validates: Requirements 2.2.2**

### Property 21: LOD Distance Transitions
*For any* camera distance to ocean or island geometry, the appropriate level of detail (LOD) shall be selected based on defined distance thresholds, with smooth transitions between LOD levels.
**Validates: Requirements 2.2.4**

### Property 22: Day/Night Cycle Consistency
*For any* time value in the day/night cycle, lighting parameters (intensity, color, direction) shall be consistent and follow the defined cycle curve without discontinuities.
**Validates: Requirements 2.1.3**

### Property 23: Input Gesture Mapping
*For any* valid touch gesture (swipe, tap, pinch), the system shall interpret it as the corresponding movement or camera command according to the gesture mapping configuration.
**Validates: Requirements 2.7.1**

### Property 24: Gamepad Button Mapping
*For any* gamepad button press, the system shall trigger the corresponding ship action according to the configured button mapping.
**Validates: Requirements 2.7.2**

### Property 25: Keyboard Input Precision
*For any* keyboard input for movement, the resulting ship movement shall be precise and correspond directly to the key press duration and timing.
**Validates: Requirements 2.7.3**

## 7. Error Handling

### 7.1 Error Categories

**Input Errors:**
- Invalid input values or ranges
- Unsupported input devices
- Conflicting input signals
- Input buffer overflow

**Physics Errors:**
- Numerical instability in physics calculations
- Collision detection failures
- Buoyancy calculation overflow
- RigidBody3D constraint violations

**Scene Errors:**
- Missing or corrupted scene resources
- Node path resolution failures
- Scene transition timeouts
- Memory allocation failures during scene load

**System Errors:**
- Audio system initialization failures
- Resource loading failures
- Save/Load operation failures
- Configuration file corruption

### 7.2 Error Recovery Strategies

**Graceful Degradation:**
- If complex ocean shader fails, fall back to simple water material
- If physics simulation becomes unstable, apply damping and reset
- If audio system fails, continue with visual feedback only
- If input device disconnects, switch to alternate input method

**User Notification:**
- Non-blocking toast messages for recoverable errors
- Modal dialogs for critical failures requiring user action
- Visual indicators for system status (connection, performance)
- Audio cues for important state changes

**Automatic Recovery:**
- Input buffer reset on prolonged inactivity
- Physics state correction on detection of divergence
- Resource reload on corruption detection
- Scene reload on unrecoverable scene errors

**Logging and Diagnostics:**
- Detailed error logging with context information
- Performance metrics collection
- User action tracking for bug reproduction
- Automated error reporting (opt-in)

### 7.3 Specific Error Scenarios

**Scene Transition Failure:**
- Attempt scene load up to 3 times with increasing delays
- If all attempts fail, return to main menu with error message
- Preserve user progress up to last successful save
- Log detailed error information for debugging

**Physics Instability:**
- Detect abnormal velocity or position values
- Apply corrective forces to stabilize simulation
- If instability persists, reset ship to last stable position
- Notify user with "Physics reset" indicator

**Memory Pressure:**
- Monitor memory usage during gameplay
- Trigger garbage collection when thresholds exceeded
- Unload distant or non-essential resources
- If critical, prompt user to restart application

**Input Device Loss:**
- Detect device disconnection
- Switch to next available input method
- Notify user of input method change
- Re-establish connection when device available

## 8. Testing Strategy

### 8.1 Property-Based Testing

**Test Framework:** Godot 4.x with GDScript testing framework
**Test Iterations:** Minimum 100 iterations per property test
**Random Seed Control:** Configurable seeds for reproducible tests
**Failure Reporting:** Detailed counterexamples with minimal reproducing cases

**Property Test Categories:**
1. **Camera Properties:** Test camera bounds, smoothing, collision avoidance
2. **Movement Properties:** Test acceleration, turning, drift, resistance
3. **Physics Properties:** Test buoyancy, wave interaction, collision response
4. **Input Properties:** Test mapping, latency, priority, sensitivity
5. **Docking Properties:** Test proximity, alignment, state transitions
6. **Event Properties:** Test triggering, priority, condition satisfaction

### 8.2 Unit Testing

**Example-Based Unit Tests:**
- Scene loading and initialization
- Specific movement scenarios (forward, turn, stop)
- Docking sequence completion
- Event triggering with specific conditions
- Audio system integration
- UI element visibility and interaction

**Edge Case Tests:**
- Extreme input values (min/max)
- Boundary conditions (docking thresholds)
- Rapid state transitions
- Memory pressure scenarios
- Concurrent input handling
- Network interruption simulation

### 8.3 Integration Testing

**Scene Integration Tests:**
- Main menu to world scene transition
- World scene to island docking transition
- Multiple island interaction sequences
- Camera mode transitions
- Audio system integration across scenes

**System Integration Tests:**
- Input system with movement physics
- Event system with game state
- Audio system with game events
- UI system with player actions
- Save system with game progress

### 8.4 Performance Testing

**Frame Rate Testing:**
- Target: 60 FPS on reference mobile devices
- Minimum: 30 FPS on minimum spec devices
- Stress: Maintain performance with multiple islands/ships

**Memory Testing:**
- Initial load memory usage
- Peak memory during gameplay
- Memory leak detection over extended sessions
- Garbage collection effectiveness

**Input Latency Testing:**
- Touch input to visual response: < 100ms
- Button press to action: < 50ms
- Gesture recognition time: < 200ms
- Camera response time: < 150ms

### 8.5 Mobile-Specific Testing

**Touch Input Testing:**
- Virtual joystick accuracy and responsiveness
- Multi-touch gesture recognition
- Screen edge interaction
- Touch target sizing (minimum 44x44 pixels)

**Performance Scaling:**
- Quality setting adaptation
- Battery consumption monitoring
- Thermal throttling response
- Memory warning handling

**Device Compatibility:**
- Screen size and aspect ratio adaptation
- Notch and cutout handling
- Orientation change support
- System gesture conflict avoidance

### 8.6 Test Automation

**Continuous Integration:**
- Automated test execution on commit
- Performance regression detection
- Code coverage reporting
- Static analysis and linting

**Test Reporting:**
- Detailed test results with screenshots
- Performance metrics visualization
- Error classification and prioritization
- Trend analysis over time

**Manual Testing Checklist:**
- [ ] Movement feels responsive and satisfying
- [ ] Camera controls are intuitive
- [ ] Docking sequence is clear and reliable
- [ ] Visual feedback matches actions
- [ ] Audio enhances gameplay experience
- [ ] Performance is smooth on target devices
- [ ] No visual artifacts or clipping
- [ ] Error messages are helpful and actionable