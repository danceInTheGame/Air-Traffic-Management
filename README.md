# ATC Dashboard

Projet Flutter d'affichage et de simulation de trafic aérien (ATC Dashboard).

**Résumé :** application Flutter multi-plateforme (desktop/web/mobile) fournie avec les sources Dart dans `lib/`.

**Contenu :**
- Code : `lib/`
- Actifs : `assets/`
- Tests : `test/`

**Prérequis**
- Flutter SDK (stable) installé et accessible via la variable `PATH`.
- Pour les outils Python (lint, docs) : Python 3.8+ et `pip`.

Installation des dépendances Python :

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Installation des dépendances Dart/Flutter :

```bash
flutter pub get
```

Exécution (développement)

```bash
# Exécuter sur le device par défaut (ex. linux, chrome, android)
flutter run
```

Build

```bash
# Build release pour Linux
flutter build linux
# Build web
flutter build web
```

Tests

```bash
flutter test
```

Lint & formatage

```bash
# Dart/Flutter
flutter analyze
# Python tools (si des scripts existent)
black .
flake8 .
isort .
```

Documentation

Ce dépôt inclut un `requirements.txt` pour installer les outils Python utiles (Sphinx / MkDocs) si vous souhaitez maintenir une documentation HTML. Exemple de génération Sphinx :

```bash
# si vous avez un dossier docs/ avec Sphinx configuré
sphinx-build -b html docs/source docs/build
```

Déploiement Vercel

Ce projet Flutter n'est pas une application Python native, mais Vercel a détecté `requirements.txt` et s'attendait à un point d'entrée Python. J'ai ajouté un `pyproject.toml` + `main.py` Flask pour servir le build web Flutter depuis `build/web`.

Pour déployer sur Vercel :

1. Générer le build web Flutter :

```bash
flutter build web
```

2. Commiter le dossier `build/web` ou déployer via un pipeline qui génère le build avant l'upload.

3. Pousser sur GitHub et laisser Vercel exécuter le server Python.


CI / GitHub Actions

Un workflow `CI` est fourni dans `.github/workflows/ci.yml` pour lancer `flutter analyze` et `flutter test` à chaque `push` et `pull_request`.

Pousser sur GitHub

```bash
git add .
git commit -m "Add requirements.txt, README and CI workflow"
git push origin main
```

Contribuer

- Ouvrez une issue pour discuter d'une fonctionnalité.
- Faites une branche dédiée, tests et PRs bien décrites.

---
Si vous voulez, je peux aussi :
- ajouter un dossier `docs/` initial avec Sphinx/MkDocs ;
- configurer `pre-commit` et le fichier `.pre-commit-config.yaml` ;
- adapter le `requirements.txt` avec des versions précises.
# atc_dashboard

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
