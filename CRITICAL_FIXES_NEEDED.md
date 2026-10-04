# 🚨 FIXES CRITIQUES REQUISES

## DIAGNOSTIC - État Actuel vs Code Créé

### ✅ CODE CRÉÉ CÔTÉ BACKEND (Fichiers existent)
- ✅ `backend/src/modules/payments/payment.routes.js` - Routes paiement (0% commission)
- ✅ `backend/src/modules/subscriptions.routes.js` - Routes abonnements (6 endpoints)
- ✅ `backend/src/modules/subscriptionController.js` - Logique abonnements
- ✅ `backend/src/utils/camerpay.service.js` - Client CamerPay
- ✅ `backend/src/config/camerpay.js` - Configuration
- ✅ `backend/src/app.js` - Webhooks CamerPay intégrés
- ✅ `supabase/migrations/008_add_subscriptions.sql` - Migration DB

### ❌ CE QUI MANQUE ENCORE (À FAIRE MAINTENANT)

#### 1. **DATABASE MIGRATION** (URGENCE: HIGH)
**Problème:** Les colonnes d'abonnement ne sont probablement pas dans la table `technicians`

**Solution:**
```sql
-- Allez sur https://supabase.com/dashboard
-- Allez dans l'onglet SQL
-- Exécutez la migration: supabase/migrations/008_add_subscriptions.sql
```

**Colonne à vérifier dans table `technicians`:**
```
✓ subscription_type (trial/monthly/yearly/inactive)
✓ trial_end_date
✓ subscription_end_date
✓ subscription_status (active/expired/cancelled)
```

---

#### 2. **BACKEND DEPLOYMENT** (URGENCE: CRITICAL)
**Problème:** Votre backend en production utilise TOUJOURS NotchPay (voir les logs)

**Solution:**
```bash
# Option A: Railway (recommandé - ce que vous utilisiez)
# 1. Connectez-vous à https://railway.app
# 2. Allez dans votre déploiement TechLink
# 3. Vérifiez que les VARIABLES D'ENVIRONNEMENT contiennent:

CAMERPAY_API_KEY=313|V0AUJrh90n2QwxE18SMkLh5h831qpOzqX4kHxwp8fe797d99
CAMERPAY_SECRET_KEY=313|V0AUJrh90n2QwxE18SMkLh5h831qpOzqX4kHxwp8fe797d99
CAMERPAY_WEBHOOK_SECRET=webhook_secret_techlink_2024
BACKEND_URL=https://techlink-backend-production.up.railway.app

# 4. Redéployez avec git push (ou cliquez "Deploy")
```

**Vérification:**
```bash
# Testez que le backend utilise CamerPay:
curl -X POST https://techlink-backend-production.up.railway.app/api/payments/initialize \
  -H "Content-Type: application/json" \
  -d '{
    "missionId": "test",
    "amount": 10000,
    "clientId": "test",
    "clientPhone": "+237600000000",
    "clientEmail": "test@test.com",
    "description": "Test"
  }'

# Si vous voyez "CamerPay" dans la réponse = OK ✅
# Si vous voyez "NotchPay" = À redéployer ❌
```

---

#### 3. **FRONTEND MOBILE** (Déjà partiellement fait)
**Ce qui a été fait:**
- ✅ Created: `mobile/lib/presentation/auth/subscription_selection_screen.dart`
- ✅ Modified: `mobile/lib/presentation/auth/register_screen.dart` 
- ✅ Modified: `mobile/lib/main.dart` (route ajoutée)
- ✅ Existing: `mobile/lib/data/services/camerpay_service.dart`

**À vérifier:**
- ✓ Les imports sont corrects
- ✓ Les routes sont ajoutées au main.dart
- ✓ Recompiler le projet Flutter

```bash
cd mobile
flutter pub get
flutter clean
flutter run  # ou flutter run -d chrome pour web
```

---

## 📋 CHECKLIST - À FAIRE IMMÉDIATEMENT

### PRIORITÉ 1: Base de données (5 min)
- [ ] Allez sur https://supabase.com/dashboard
- [ ] Vérifiez que table `technicians` a colonne `subscription_type`
- [ ] Si manquant: copier/coller `supabase/migrations/008_add_subscriptions.sql` dans SQL editor

### PRIORITÉ 2: Variables d'environnement backend (2 min)
- [ ] Railway: Ajouter CAMERPAY_API_KEY = `313|V0AUJrh90n2QwxE18SMkLh5h831qpOzqX4kHxwp8fe797d99`
- [ ] Railway: Ajouter CAMERPAY_SECRET_KEY = `313|V0AUJrh90n2QwxE18SMkLh5h831qpOzqX4kHxwp8fe797d99`
- [ ] Railway: Ajouter BACKEND_URL = `https://techlink-backend-production.up.railway.app`
- [ ] Déclencher redéploiement

### PRIORITÉ 3: Vérifier backend (1 min)
- [ ] Testez endpoint: POST /api/payments/initialize
- [ ] Vérifier qu'il retourne "CamerPay" (pas "NotchPay")

### PRIORITÉ 4: Recompiler mobile (10 min)
```bash
cd c:\Users\Lenovo\techlink-app\mobile
flutter pub get
flutter run
```

---

## 🔍 POURQUOI LES 5% SONT TOUJOURS LÀ?

**Raison:** Votre backend en production utilise ENCORE l'ancien code NotchPay

**Preuve dans vos logs:**
```
DEBUG NotchPay request body: {amount: 20000, currency: XAF, ...}
```

**Vous voyez NotchPay au lieu de CamerPay.**

---

## 🔍 POURQUOI LES ABONNEMENTS N'APPARAISSENT PAS?

**Raisons possibles:**
1. ❌ Database: Colonnes d'abonnement pas dans table `technicians`
2. ❌ Mobile: Nouvel écran `subscription_selection_screen.dart` n'est pas compilé
3. ❌ Backend: Endpoints d'abonnements pas accessibles (route pas déployée)

**Solution:** Appliquez les 4 priorités ci-dessus.

---

## 📞 COMMANDES DE VÉRIFICATION

### Vérifier que CamerPay est actif:
```bash
curl -X GET \
  https://techlink-backend-production.up.railway.app/health

# Doit répondre avec: {"status":"OK","message":"TechLink API running"}
```

### Vérifier que DB est à jour:
```bash
# Depuis Supabase dashboard > SQL Editor:
SELECT column_name 
FROM information_schema.columns 
WHERE table_name='technicians'
ORDER BY ordinal_position;

# Doit contenir: subscription_type, trial_end_date, subscription_end_date
```

---

## ✅ FLUX ATTENDU APRÈS FIX

### Nouveau flux inscription technicien:
```
1. Utilisateur remplit formulaire d'inscription
   ↓
2. Compte créé dans Supabase Auth
   ↓
3. Profil technicien créé dans table 'technicians'
   ↓
4. NOUVEAU: Écran de sélection d'abonnement apparaît
   ├─ Option 1: "Essai gratuit - 30 jours" (badge visible)
   ├─ Option 2: "Abonnement 2000 FCFA/mois"  
   └─ Option 3: "Abonnement 20000 FCFA/an" (meilleure valeur)
   ↓
5. Si "essai gratuit":
   └─ trial_end_date = date actuelle + 30 jours
      subscription_status = 'active'
      ✓ Accès immédiat aux missions
   ↓
6. Si abonnement payant:
   └─ CamerPay WebView s'ouvre
      Après paiement: subscription_end_date = date + 1 mois/1 an
      ✓ Accès immédiat aux missions
```

### Ancien flux (AVANT - ce que vous voir maintenant):
```
Paiement → Déduction 5% → Technician ne reçoit que 95%
Pas d'abonnement → Accès illimité
```

### Nouveau flux (APRÈS - ce que vous verrez bientôt):
```
Abonnement → Technicien actif
Paiement mission → 100% au technicien (0% commission) ✅
```

---

## 📚 FICHIERS CLÉS MODIFIÉS

| Fichier | Statut | Action |
|---------|--------|--------|
| `backend/.env` | ✅ Mis à jour | Clés CamerPay ajoutées |
| `backend/src/modules/payments/payment.routes.js` | ✅ Prêt | 0% commission |
| `backend/src/modules/subscriptions.routes.js` | ✅ Prêt | 6 endpoints |
| `backend/src/app.js` | ✅ Prêt | Webhooks CamerPay |
| `supabase/migrations/008_add_subscriptions.sql` | ⚠️ À appliquer | Colonnes DB |
| `mobile/lib/presentation/auth/subscription_selection_screen.dart` | ✅ Créé | Écran abonnements |
| `mobile/lib/main.dart` | ✅ Mis à jour | Route ajoutée |

---

## 🎯 SUITE PROCHAINE

**Une fois ces 4 points faits:**
1. ✅ DB migration appliquée
2. ✅ Backend redéployé avec clés CamerPay
3. ✅ Mobile recompilée
4. ✅ Tests fonctionnels

**Vous aurez:**
- ✅ Plus de 5% de déduction
- ✅ Abonnements visibles à l'inscription
- ✅ Free trial 30 jours fonctionnel
- ✅ CamerPay en place de NotchPay

---

## 🆘 BESOIN D'AIDE?

Si vous êtes bloqué:

1. **Supabase DB:** Partagez le résultat de:
   ```sql
   \d technicians
   ```

2. **Backend:** Vérifiez les logs Railway:
   ```
   Settings > Logs > filter "CamerPay"
   ```

3. **Mobile:** Erreur de compilation?
   ```bash
   flutter doctor -v
   flutter clean
   flutter pub get
   ```
