# Guide de Configuration - Milestone 1

Ce guide explique comment configurer la scène principale et le projet Godot pour utiliser les scripts créés.

## 1. Configuration de l'Autoload
Pour que la gestion du temps soit accessible partout :
1. Allez dans **Projet > Paramètres du projet > Autoload**.
2. Ajoutez le script `res://scripts/TimeManager.gd`.
3. Nommez-le `TimeManager`.

## 2. Configuration de la Scène Main
Créez une scène 3D nommée `Main.tscn` avec la structure suivante :

- **Node3D** (nommé "Main")
    - **DirectionalLight3D** (pour l'éclairage)
    - **WorldEnvironment** (pour le ciel/ambiance)
    - **MeshInstance3D** (Sol)
        - Mesh : `PlaneMesh` de grande taille (ex: 100x100)
        - Position : (0, 0, 0)
    - **Camera3D** (RTS Camera)
        - Attachez le script `res://scripts/RTSCamera.gd`.
        - Position : (0, 20, 20) — *Note : Le script se recalibrera automatiquement sur le sol au démarrage.*
    - **Node3D** (GridCursor)
        - Attachez le script `res://scripts/GridCursor.gd`.
        - Ajoutez un enfant **MeshInstance3D** :
            - Mesh : `BoxMesh`
            - Taille : (2, 0.1, 2) - *Note : correspond à la taille de la grille.*
            - Matériau : Créez un `StandardMaterial3D` avec une couleur semi-transparente pour le curseur.

## 3. Input Map (Optionnel mais recommandé)
Bien que les scripts utilisent des codes de touches physiques pour plus de simplicité immédiate, il est recommandé de configurer l'**Input Map** dans les paramètres du projet pour une meilleure flexibilité :
- `ui_accept` est utilisé pour la pause par défaut (Espace).

## 4. Contrôles
- **Caméra** :
    - ZQSD / WASD : Déplacement horizontal.
    - Molette Souris : Zoom.
    - Clic Molette + Mouvement souris : Rotation horizontale.
- **Temps** :
    - `1` : Vitesse normale (1x).
    - `2` : Vitesse rapide (2x).
    - `3` : Vitesse très rapide (4x).
    - `Espace` : Pause / Reprise.
- **Grille** :
    - Le curseur s'aimante automatiquement aux cases de 2.0 unités.
