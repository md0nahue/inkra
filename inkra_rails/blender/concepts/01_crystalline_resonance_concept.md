# 💎 Crystalline Resonance Audio Visualizer

## Core Concept
Creates fractal crystal formations that pulse, rotate, and resonate with audio frequencies. Uses advanced Blender materials to simulate caustics, refractions, and prismatic light effects.

## Visual Elements

### Crystal Formation
- **Geometry**: 12-18 icospheres arranged in golden ratio spiral
- **Fractal Structure**: 3-4 levels of detail, decreasing size per level
- **Deformation**: Elongated along Z-axis (scale: 0.5, 0.5, 2.0) for dramatic crystal shape
- **Random Rotation**: Each crystal randomly oriented for natural look

### Advanced Materials
- **Base**: Principled BSDF with high transmission (0.8)
- **IOR**: 2.4 (diamond-like refraction)
- **Colors**: Cyan to blue spectrum (0.2, 0.8, 1.0)
- **Emission**: Strong glow (strength: 2.0) for mobile visibility
- **Caustics**: Enabled for realistic light focusing

### Animation System
- **Rotation**: Multi-axis rotation at different speeds per crystal
- **Scaling**: Audio-reactive pulsing (1.0 + 0.3 * sin(frequency))
- **Vertical Float**: Gentle oscillation for organic movement
- **Phase Offset**: Each crystal animates with slight delay

## Technical Specifications

### Render Settings
- **Engine**: Cycles (caustics enabled)
- **Samples**: 128-256 (high quality for refractions)
- **Resolution**: 1080x1920 (TikTok format)
- **Denoising**: Enabled (OptiX/OpenImageDenoise)

### Performance Optimization
- **Subdivision**: Limited to maintain real-time feedback
- **Particle Count**: Optimized for mobile viewing
- **Transparency**: Balanced for quality vs speed

## Audio Integration
- **Frequency Mapping**: Different crystals react to different frequency bands
- **Beat Detection**: Scale pulsing synchronized to perceived beats
- **Amplitude Response**: Emission strength varies with audio level
- **Harmonic Resonance**: Crystal rotation speeds based on harmonic content

## Artistic Intent
Represents the crystalline structure of sound itself - each frequency becomes a geometric form that refracts and amplifies the audio energy into visual beauty.

## Use Cases
- **Music Videos**: Electronic, ambient, classical
- **TikTok Content**: High engagement due to prismatic effects
- **Instagram Stories**: Eye-catching for mobile feeds
- **Live Performance**: Real-time audio reactive installations

## Render Time Estimates

### M2 MacBook Pro (10-core GPU)
- **Preview Quality** (64 samples): ~45 minutes for 15 seconds
- **Standard Quality** (128 samples): ~1.5 hours for 15 seconds  
- **High Quality** (256 samples): ~3 hours for 15 seconds

### Cloud GPU (G4DN.xlarge - Tesla T4)
- **Preview Quality**: ~25 minutes for 15 seconds
- **Standard Quality**: ~50 minutes for 15 seconds
- **High Quality**: ~1.5 hours for 15 seconds

### Cloud GPU (P3.2xlarge - Tesla V100)  
- **Preview Quality**: ~12 minutes for 15 seconds
- **Standard Quality**: ~25 minutes for 15 seconds
- **High Quality**: ~45 minutes for 15 seconds

## File Outputs
- **Video**: H.264 MP4 (TikTok compatible)
- **Audio**: AAC codec (remastered source)
- **Blend File**: Reusable template with parameterized controls