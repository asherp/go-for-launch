# Technical Architecture & Scale

## Current Implementation

### Recording System
- **Format**: JSON files stored in `res://recordings/`
- **Structure**: Input events with timestamps, position checkpoints
- **File Naming**: Character names (e.g., `bill.json`, `billy_pilgrim.json`)
- **Size**: ~5-10 KB per minute of gameplay

### Player System
- **Script**: `player_1.gd` - Unified script for both player and NPCs
- **NPC Mode**: `is_npc` flag enables NPC behavior
- **Recording**: `player_recorder.gd` handles input recording and playback
- **Navigation**: `NavigationAgent2D` for adaptive pathfinding

### NPC Management
- **Manager**: `npc_manager.gd` spawns and manages NPCs
- **Spawning**: Automatic discovery of recording files
- **Synchronization**: All NPCs start playback simultaneously
- **Floor Detection**: NPCs spawn on correct floor from recording

## Scale Challenges

### Target: 100+ NPCs

#### Current Limitations
- JSON file management may become cumbersome
- File I/O for 100+ recordings on load
- Memory usage for 100+ NPCs with full state
- Pathfinding performance for 100+ simultaneous agents

#### Proposed Solutions

##### Database Migration
- **When**: If file management becomes cumbersome
- **Options**: 
  - SQLite for local storage
  - JSON database for structured queries
  - Custom binary format for performance
- **Benefits**:
  - Faster queries and filtering
  - Better organization
  - Easier management of large datasets

##### Performance Optimizations

**Pathfinding**
- Update frequency culling (distant NPCs update less)
- Pathfinding cache (reuse paths when possible)
- Spatial partitioning (only calculate nearby paths)
- Async pathfinding (spread calculations across frames)

**State Management**
- State update culling (only update visible/active NPCs)
- LOD system (simplified behavior for distant NPCs)
- State compression (store only essential data)
- Incremental updates (only update changed states)

**Memory Management**
- Object pooling for NPCs
- Lazy loading of recordings
- Unload inactive NPCs
- Streaming system for large datasets

## Architecture Considerations

### Recording Storage

#### Current: JSON Files
- **Pros**: Human-readable, easy to debug, simple implementation
- **Cons**: Slower for large datasets, harder to query

#### Future: Database
- **Pros**: Fast queries, easy filtering, better organization
- **Cons**: More complex, requires migration, learning curve

### NPC Spawning

#### Current: Scene-Based
- NPCs spawned as CharacterBody2D nodes
- Added to scene tree
- Managed by NPCManager

#### Considerations for Scale
- **Object Pooling**: Reuse NPC objects instead of creating/destroying
- **Lazy Spawning**: Only spawn NPCs when needed
- **Culling**: Don't spawn NPCs outside view distance
- **Streaming**: Load/unload NPCs based on proximity

### Synchronization

#### Current: Signal-Based
- `all_npcs_started_playback` signal
- All NPCs start simultaneously
- Player recording synchronized with NPC start

#### Scale Considerations
- **Batched Starts**: Start NPCs in batches to avoid frame drops
- **Staggered Initialization**: Spread initialization across frames
- **Priority System**: Start important NPCs first
- **Progressive Loading**: Load NPCs as they become relevant

## Performance Metrics

### Target Metrics (TBD)
- **Frame Rate**: Maintain 60 FPS with 100+ NPCs
- **Memory Usage**: Reasonable memory footprint
- **Load Time**: Acceptable initial load time
- **Update Performance**: Smooth updates for all NPCs

### Measurement Points
- NPC spawn time
- Recording load time
- Pathfinding update time
- State update time
- Memory usage per NPC
- Total memory usage

## Scalability Strategies

### Horizontal Scaling
- Distribute NPCs across multiple threads (if possible)
- Use async operations for I/O
- Parallel pathfinding calculations

### Vertical Scaling
- Optimize algorithms for efficiency
- Reduce redundant calculations
- Cache frequently accessed data
- Use efficient data structures

### Adaptive Quality
- Reduce update frequency for distant NPCs
- Simplify behavior for off-screen NPCs
- Use LOD system for visual representation
- Prioritize important NPCs

## Migration Path

### Phase 1: Current System (JSON Files)
- Works for small to medium scale
- Easy to debug and modify
- Sufficient for initial development

### Phase 2: Optimization (Current System)
- Optimize JSON loading
- Implement culling systems
- Add performance monitoring

### Phase 3: Database Migration (If Needed)
- Migrate to database format
- Implement query system
- Maintain backward compatibility

### Phase 4: Advanced Features
- Streaming system
- Advanced culling
- Multi-threading (if supported)

## Monitoring & Profiling

### Performance Monitoring
- Track frame rate
- Monitor memory usage
- Measure update times
- Identify bottlenecks

### Profiling Tools
- Godot's built-in profiler
- Custom performance metrics
- Debug visualization
- Performance logging

### Optimization Priorities
1. **Critical Path**: Pathfinding and navigation
2. **High Impact**: State updates and interactions
3. **Medium Impact**: Visual rendering
4. **Low Impact**: Debug systems

## Future Considerations

### Multi-Threading
- Godot 4 supports multi-threading
- Could parallelize:
  - Pathfinding calculations
  - State updates
  - Recording playback
- Requires careful synchronization

### Networking (If Needed)
- Could enable multiplayer
- Share recordings across clients
- Synchronize world state
- Complex but possible

### Advanced Features
- Machine learning for NPC behavior
- Procedural objective generation
- Dynamic difficulty adjustment
- Player behavior analysis

