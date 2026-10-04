# TechLink - Plateforme de Services à Domicile

TechLink est une plateforme de mise en relation entre des particuliers (clients) et des techniciens professionnels (plombiers, électriciens, menuisiers, etc.) en Afrique. 

L'application permet aux clients de publier des demandes de services, de recevoir des devis, d'accepter des missions, d'appeler les techniciens (VoIP), et de payer de manière sécurisée.

## 🏗️ Architecture du Projet

Le projet est divisé en trois parties principales :

1. **`mobile/`** : L'application mobile (Client & Technicien)
   - **Framework** : Flutter (Dart)
   - **Architecture** : Riverpod (State Management), GoRouter (Routing)
   - **Fonctionnalités** : Géolocalisation (Flutter Map), Appels VoIP (ZegoCloud), Notifications Push (Firebase)

2. **`backend/`** : L'API de paiement et de webhooks
   - **Framework** : Node.js (Express)
   - **Fonctionnalités** : Initialisation des paiements via CamerPay/NotchPay, traitement des webhooks, interactions complexes.
   - **Base de données** : Supabase (PostgreSQL)

3. **`admin-panel/`** : Tableau de bord administrateur (Legacy)
   - **Framework** : React (Vite)
   - **Note** : Le panneau d'administration migre progressivement vers une interface mobile intégrée.

## 🛠️ Prérequis

- **Flutter SDK** (>= 3.0.0)
- **Node.js** (>= 18.x)
- **Compte Supabase** (Base de données et Authentification)
- **Compte ZegoCloud** (Pour les appels audio/vidéo)
- **Compte CamerPay** (Pour les paiements)

## 🚀 Démarrage Rapide

### 1. Backend (API)

```bash
cd backend
npm install
# Créez un fichier .env basé sur vos clés Supabase et CamerPay
npm run start
```
*Le backend s'exécutera sur `http://localhost:3000` (ou le port défini dans `.env`).*

### 2. Mobile (Flutter App)

```bash
cd mobile
flutter pub get

# Pour l'internationalisation (génère les fichiers de traduction)
flutter gen-l10n

# Créez le fichier .env dans le dossier mobile
flutter run
```

## 🔐 Configuration Supabase

L'application repose fortement sur Supabase pour :
- **L'authentification** : Gestion des utilisateurs (email/password).
- **Base de données** : Tables `users`, `technicians`, `missions`, `quotes`, `payments`.
- **Fonctions RPC** : Exemple `confirm_mission_payment` pour valider les paiements de façon atomique.
- **Stockage** : Avatars et documents.

*(Voir les fichiers dans `supabase/migrations/` pour le schéma complet).*

## 📚 Documentation API (Backend)

La documentation détaillée de l'API backend (Endpoints, Webhooks, Scripts) se trouve dans [BACKEND_API_DOCS.md](./BACKEND_API_DOCS.md).

---
*Généré lors de la Phase 19 (Documentation) - Version 1.0.0*