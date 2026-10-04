# 📋 REMAINING TASKS - Mobile Implementation

## Overview
- ✅ **13 tasks completed** (Backend infrastructure ready)
- ⏳ **7 tasks remaining** (Mobile UI + Testing)

---

## 🎯 TASK 1: Create Subscription Screen (Mobile UI)

**File**: `mobile/lib/presentation/subscription/subscription_screen.dart` (NEW)

### UI Components Needed:
```dart
class SubscriptionScreen extends StatefulWidget {
  final String technicianId;
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Display sections:
  
  // 1. Status Section
  //    - If trial active: "Essai Gratuit - XX jours restants"
  //    - If subscribed: "Abonnement Actif - expires DD/MM/YYYY"
  //    - If expired: "Abonnement Expiré - Renouveler"
  
  // 2. Pricing Section
  //    - Monthly: 2,000 FCFA (30 days)
  //    - Yearly: 20,000 FCFA (365 days) - SAVINGS BADGE
  
  // 3. Actions Section
  //    - If trial: [Monthly Button] [Yearly Button]
  //    - If active: [Renew Button] [Cancel Button]
  //    - If expired: [Subscribe Now Button]
  
  // 4. Payment WebView
  //    - Shows CamerPay payment URL when user clicks subscribe
  //    - Handles success/failure callbacks
}
```

### Key Features:
- [x] Display subscription status (trial/active/expired)
- [x] Show days remaining with countdown
- [x] Monthly/Yearly pricing buttons
- [x] CamerPay WebView for payment
- [x] Renew/Cancel buttons
- [x] Loading states
- [x] Error handling

---

## 🎯 TASK 2: Modify Payment Screen (Remove 5% Commission)

**File**: `mobile/lib/presentation/client/payment_screen.dart` (MODIFY)

### Changes Required:

**1. Remove commission calculation:**
```dart
// ❌ REMOVE THESE LINES:
// final commission = amount * NotchPayConfig.commissionRate;
// final netAmount = amount - commission;

// ✅ REPLACE WITH:
// final netAmount = amount;  // 100% goes to technician
```

**2. Update UI to show 100% amount:**
```dart
// ❌ Old:
// Text('Commission (5%): -${commission.toStringAsFixed(0)} FCFA')

// ✅ New:
// Text('Montant du technicien: ${amount.toStringAsFixed(0)} FCFA')
// Subtitle: "Le technicien reçoit 100% du montant"
```

**3. Replace NotchPay with CamerPay:**
```dart
// ❌ Remove:
// import 'package:techlink/data/constants/notchpay_config.dart';

// ✅ Add:
import 'package:techlink/data/services/camerpay_service.dart';

// ❌ Remove NotchPay initialization
// ✅ Add:
final camerpayService = CamerPayService();

// Update payment initiation:
Future<void> _initializePayment() async {
  final result = await camerpayService.initializeMissionPayment(
    missionId: widget.mission['id'],
    amount: widget.quote['subtotal'].toDouble(),
    clientId: clientId,
    clientPhone: clientPhone,
    clientEmail: clientEmail,
    description: 'Mission Payment',
  );
  
  if (result['success']) {
    // Open CamerPay payment URL
    _openPaymentInWebView(result['data']['paymentUrl']);
  }
}
```

---

## 🎯 TASK 3: Create Subscription Status Widget

**File**: `mobile/lib/presentation/shared/subscription_status_widget.dart` (NEW)

### Purpose:
Display subscription status badge on technician home screen

### Widget Output:
```
If Trial Active:
┌──────────────────────────────┐
│ 🎁 Essai Gratuit             │
│    XX jours restants         │
│    [Renouveler]              │
└──────────────────────────────┘

If Subscription Active:
┌──────────────────────────────┐
│ ✅ Abonnement Actif          │
│    Mensuel / Annuel          │
│    Expire: DD/MM/YYYY        │
└──────────────────────────────┘

If Expired:
┌──────────────────────────────┐
│ ❌ Abonnement Expiré         │
│    [Renouveler Maintenant]   │
└──────────────────────────────┘
```

### Code Structure:
```dart
class SubscriptionStatusWidget extends StatefulWidget {
  final String technicianId;
}

// Shows:
// - Icon (trial/active/expired)
// - Color coded (green/red/yellow)
// - Days remaining
// - Quick action buttons
```

---

## 🎯 TASK 4: Update Registration Screen

**File**: `mobile/lib/presentation/auth/register_screen.dart` (MODIFY)

### Changes:

**1. After creating technician account:**
```dart
// ❌ Old (nothing after technician creation):
await Supabase.instance.client.from('technicians').insert({ ... });

// ✅ New (start free trial):
await Supabase.instance.client.from('technicians').insert({ ... });

final camerpayService = CamerPayService();
final trialResult = await camerpayService.startFreeTrial(userId);

if (trialResult['success']) {
  // Show trial confirmation
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('🎉 30 days free trial started!')),
  );
  
  // Navigate to technician home or subscription screen
  Navigator.of(context).pushReplacementNamed('/technician-home');
}
```

**2. Show trial information:**
```dart
// After trial starts, show dialog:
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Bienvenue! 🎉'),
    content: Text(
      'Vous avez 30 jours d\'essai gratuit.\n\n'
      'Après cela, vous devrez vous abonner pour continuer.'
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Commencer'),
      ),
    ],
  ),
);
```

---

## 🎯 TASK 5: Update Technician Home Screen

**File**: `mobile/lib/presentation/technician/technician_home_screen.dart` (MODIFY)

### Add to top section:

**1. Import and initialize:**
```dart
import 'package:techlink/presentation/shared/subscription_status_widget.dart';
import 'package:techlink/data/services/camerpay_service.dart';
```

**2. Add subscription status widget:**
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text('Accueil')),
    body: Column(
      children: [
        // NEW: Subscription status widget
        SubscriptionStatusWidget(
          technicianId: currentTechnicianId,
        ),
        Divider(),
        
        // Existing content:
        // - Available missions
        // - Active missions
        // - Earnings
        // etc.
      ],
    ),
  );
}
```

**3. Handle expired subscriptions:**
```dart
Future<void> _checkSubscriptionStatus() async {
  final camerpayService = CamerPayService();
  final status = await camerpayService.getSubscriptionStatus(
    technicianId: currentTechnicianId,
  );
  
  if (!status['data']['hasActiveTrial'] && 
      !status['data']['hasActiveSubscription']) {
    // Show modal: Subscription expired
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        child: Column(
          children: [
            Text('Abonnement Expiré'),
            Text('Vous ne pouvez pas accepter de missions sans abonnement'),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SubscriptionScreen(
                  technicianId: currentTechnicianId,
                )),
              ),
              child: Text('Renouveler Maintenant'),
            ),
          ],
        ),
      ),
    );
  }
}

// Call in initState:
@override
void initState() {
  super.initState();
  _checkSubscriptionStatus();
}
```

---

## 🎯 TASK 6: Migrate Existing Technicians

**File**: `backend/scripts/migrate-technicians.js` (NEW)

### Script Purpose:
Update existing technicians to have subscription fields

### What it does:
```javascript
// For each technician in database:
// Option A: Give them 1-month free trial
for (const technician of technicians) {
  await startFreeTrial(technician.id);
}

// Option B: Mark them as inactive (must pay to reactivate)
for (const technician of technicians) {
  await supabase.from('technicians').update({
    subscription_status: 'inactive',
  }).eq('id', technician.id);
}
```

### How to run:
```bash
cd backend
node scripts/migrate-technicians.js
```

---

## 🎯 TASK 7: QA Testing (3 Test Cases)

### Test Case 1: Complete Mission Payment Flow
```
✅ Scenario: Client pays for completed mission
1. Mission completed by technician
2. Client initiates payment: 50,000 FCFA
3. CamerPay payment URL opened
4. Client completes payment in WebView
5. CamerPay webhook received
6. Mission status = 'paid'
7. Technician wallet += 50,000 (100%, no deduction)
8. Verify: No commission recorded

Expected: ✅ Technician receives full amount
```

### Test Case 2: Subscription Payment Flow
```
✅ Scenario: Technician subscribes after trial
1. Trial ending in 2 days (28 days passed)
2. Technician clicks "Renouveler" on subscription screen
3. Chooses: Monthly (2,000 FCFA)
4. Opens CamerPay payment
5. Completes payment
6. CamerPay webhook: payment.success
7. Subscription status = 'active'
8. New end_date = now() + 30 days

Expected: ✅ Subscription activated, technician can continue
```

### Test Case 3: Subscription Blocking Access
```
✅ Scenario: Technician without active subscription cannot accept mission
1. Technician trial expired (0 days left)
2. Subscription not paid
3. Try to accept mission
4. Middleware check: checkSubscriptionStatus
5. Response: 403 Forbidden - "Subscription required"
6. Redirect to subscription screen

Expected: ✅ Access blocked until subscription renewed
```

---

## 📋 Remaining Tasks Checklist

### Mobile UI Implementation
- [ ] Create `subscription_screen.dart` with:
  - [ ] Status display section
  - [ ] Pricing section (2000/20000 FCFA)
  - [ ] Action buttons (Subscribe/Renew/Cancel)
  - [ ] CamerPay WebView integration
  - [ ] Payment callback handling
  - [ ] Loading states
  - [ ] Error messages

- [ ] Create `subscription_status_widget.dart` with:
  - [ ] Trial status display
  - [ ] Active subscription display
  - [ ] Expired subscription display
  - [ ] Days remaining counter
  - [ ] Color-coded badges

- [ ] Modify `payment_screen.dart`:
  - [ ] Remove 5% commission calculation
  - [ ] Update UI to show 100%
  - [ ] Replace NotchPay with CamerPay
  - [ ] Import CamerPayService
  - [ ] Update payment initialization

- [ ] Modify `register_screen.dart`:
  - [ ] Import CamerPayService
  - [ ] Call startFreeTrial() after technician creation
  - [ ] Show trial confirmation dialog
  - [ ] Navigate correctly after trial starts

- [ ] Modify `technician_home_screen.dart`:
  - [ ] Import SubscriptionStatusWidget
  - [ ] Add widget to UI
  - [ ] Import CamerPayService
  - [ ] Add subscription status check in initState
  - [ ] Show modal if subscription expired
  - [ ] Add "Renouveler" button functionality

### Backend Scripts
- [ ] Create migration script for existing technicians:
  - [ ] Connect to Supabase
  - [ ] Get all technicians
  - [ ] Option A: Start trial for all
  - [ ] Option B: Mark inactive
  - [ ] Log results

### QA & Testing
- [ ] Test Case 1: Mission payment (100%, no commission)
- [ ] Test Case 2: Subscription payment and activation
- [ ] Test Case 3: Blocked access without subscription

---

## 📊 Progress Summary

```
COMPLETED: ✅✅✅✅✅✅✅✅✅✅✅✅✅ (13 tasks)
├─ Database migrations
├─ CamerPay integration
├─ Payment routes
├─ Subscription routes
├─ Subscription logic
├─ Webhooks
├─ Middleware
├─ Mobile service
├─ Documentation
└─ More...

REMAINING: ⏳⏳⏳⏳⏳⏳⏳ (7 tasks)
├─ Mobile screens (3)
├─ Mobile integration (2)
├─ Data migration (1)
└─ QA testing (1)
```

---

## 🚀 Estimated Timeline

- **Mobile Screens**: 2-3 days (3 screens to create)
- **Integration**: 1-2 days (2 screens to modify)
- **Migration**: 0.5-1 day (script + testing)
- **QA**: 1-2 days (3 test cases)

**Total**: ~5-8 days to complete everything

---

## 💡 Tips for Implementation

1. **Start with subscription screen** - Most complex UI
2. **Copy payment screen structure** - Then modify
3. **Test locally first** - Before deploying
4. **Use WebView for payments** - CamerPay URLs
5. **Handle all states** - Loading, Success, Error

---

**Good luck! Questions? Check MOBILE_CHANGES.md for detailed guidance.** 📱
