# Cool-Lect-Early-Childhood-Basic-E-Learning-Game

# 🌟 Cool-LecT: Early Childhood Basic E-Learning Game

**Cool-LecT** is a cozy, top-down **collection-and-delivery adventure** built in **Godot 4**, designed as a playful introduction to early childhood education. Young learners explore themed worlds, gather scattered items, and deliver them to a friendly merchant — turning foundational concepts into hands-on, joyful gameplay.

---

## 🎮 About the Project

Cool-LecT blends light exploration with simple fetch-quest mechanics, wrapping early learning in a warm, approachable loop. Each subject becomes its own themed level, encouraging curiosity and reinforcing basic knowledge through play:

- 🅰️ **Alphabets**  
- 🐾 **Animals**  
- 🎨 **Colors**  
- 🍎 **Fruits**  
- 🔢 **Numbers**  
- 🔺 **Shapes**

The goal is to make learning feel like play — with gentle pacing, simple controls, and positive feedback at every step. There are no failure states, only encouragement and progress.

---

## 🔄 Core Gameplay Loop

Each level follows a consistent, child-friendly structure (first fully implemented in the **Fruits** subject):

1. **Meet the Merchant** — an NPC (currently *Momo*) explains what’s needed via a typewriter-style dialogue box.  
2. **Accept the Mission** — the player chooses to help through a simple Yes/No prompt.  
3. **Collect Items** — scattered objects (like apples) are picked up by interacting, with live progress shown in an **Items Panel**.  
4. **Deliver the Items** — returning to the merchant triggers a thank-you dialogue and completes the level.  

Progress is tracked in a **Mission Panel** — a friendly checklist with stars, clear step indicators, and encouraging visuals.

---

## ✨ Features Implemented

- **Player Movement** — smooth 8-directional controls, with joystick support for touch/mobile.  
- **Interaction System** — unified Interact button for NPCs and collectables.  
- **Dialogue System** — reusable, animated dialogue box with:  
  - Multi-page conversations  
  - Skip-to-full-text option  
  - Responsive font sizing  
  - Dynamic Yes/No prompts  
- **Mission Panel** — step-by-step checklist with stars and clear progress states.  
- **Items Panel** — live tracker with icons and counts.  
- **Quest Tracking** — `QuestManager` autoload for item collection and completion events.  
- **Settings Menu** — pause menu with Resume and Main Menu options.  
- **Environmental Polish** — wind-sway shaders on trees and foliage.  
- **Reusable UI Systems** — dialogue, missions, and item tracking built for all subjects, not just Fruits.  

---

## 🛠 Tech Stack

- **Engine:** Godot 4.6  
- **Language:** GDScript  
- **Art:** Pixel-art tiles and characters (Sprout Lands-inspired), with custom wood-themed UI panels  

---

## 📂 Project Structure (High-Level)

```
scenes/
  characters/      -> Player, Merchant, shared character logic
  collectables/    -> Per-subject item scenes
  components/      -> Reusable node components
  levels/          -> Subject-specific level-select scenes
  objects/         -> Environment props
  world/           -> Core UI panels (dialogue, mission, items, settings)
scripts/
  autoloads/       -> Global singletons (GameUIManager, InteractionManager, QuestManager)
  globals/         -> Shared utilities
  statemachine/    -> Generic node state machine
resources/         -> Shared assets (icons, level data, etc.)
```

---

## 🚀 Roadmap

- [ ] Star rating system via central `GameManager`  
- [ ] Additional HUD polish (Tutorial button, Items Panel refinements)  
- [ ] Expand gameplay loop to Alphabets, Animals, Colors, Numbers, and Shapes  
- [ ] Level transitions and completion screens  

---

## 📝 Development Notes

Cool-LecT is built iteratively, with a strong focus on **reusable systems**. Dialogue, missions, and item tracking are designed to scale across subjects, ensuring new content can be added easily without rebuilding core mechanics.
