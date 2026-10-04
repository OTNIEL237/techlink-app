# 📱 Mobile - Changes Nécessaires pour Migration CamerPay + Abonnement

## 1️⃣ Suppression de la Commission 5%

### Fichier: `mobile/lib/presentation/client/payment_screen.dart`

**Avant (Notchpay + 5% commission):**
```dart
// Lines 144-175 - À REMPLACER
Future<void> _confirmPaymentInDB(String reference) async {
  final amount = (widget.quote['subtotal'] as num?)?.toDouble() ?? 0;
  final commission = amount * NotchPayConfig.commissionRate;  // ❌ 5%
  final netAmount = amount - commission;  // ❌ Amount after cut
  final technicianId = widget.mission['technician_id'] as String? ?? '';
  
  await Supabase.instance.client.from('payments').insert({
    'mission_id': widget.mission['id'],
    'amount': amount,
    'technician_amount': netAmount,  // ❌ After cut
    'platform_fee': commission,  // ❌ 5% commission
    'commission_amount': commission,
    ...
  });
}
```

**Après (CamerPay + 100%):**
```dart
// NEW - Amount = 100% (no commission)
Future<void> _confirmPaymentInDB(String reference) async {
  final amount = (widget.quote['subtotal'] as num?)?.toDouble() ?? 0;
  // ✅ NO commission calculation
  final technicianId = widget.mission['technician_id'] as String? ?? '';
  
  // Payment is already processed by backend via CamerPay
  // Just wait for webhook confirmation
}
```

### Changes Required:
- ✅ Remove `NotchPayConfig.commissionRate` references
- ✅ Remove commission calculation logic
- ✅ Update payment display to show 100% amount
- ✅ Replace CamerPay service initialization
- ✅ Update payment_screen.dart to use CamerPayService instead of NotchPayService

---

## 2️⃣ Créer Écran d'Abonnement

### Nouveau Fichier: `mobile/lib/presentation/subscription/subscription_screen.dart`

**Features:**
- [ ] Display current subscription status (trial/monthly/yearly/none)
- [ ] Display trial end date with days remaining
- [ ] Buttons for:
  - "Upgrade to Monthly" (2000 FCFA)
  - "Upgrade to Yearly" (20000 FCFA)
  - "Renew Subscription" (if expired)
  - "Cancel Subscription"
- [ ] Show CamerPay payment URL in WebView
- [ ] Handle payment completion/failure callbacks

**Key UI Elements:**
```dart
class SubscriptionScreen extends StatefulWidget {
  final String technicianId;
  // Show trial status
  // Show "XX days remaining"
  // Show pricing options
}
```

---

## 3️⃣ Intégration dans Registration Flow

### Fichier: `mobile/lib/presentation/auth/register_screen.dart`

**After creating technician account:**
```dart
// After technician profile creation, call:
1. Start free trial (30 days)
2. Show subscription screen with:
   - "You have 30 days free trial"
   - Option to upgrade to paid subscription
   - Option to skip for now
```

### Fichier: `mobile/lib/presentation/technician/onboarding_screen.dart`

**During technician onboarding:**
- Show trial period start (30 days)
- Show reminder before trial ends
- Option to select subscription plan during onboarding

---

## 4️⃣ Update Payment Screen

### Changes to `payment_screen.dart`:
```dart
// Import
import 'package:techlink/data/services/camerpay_service.dart';

// Replace initializePayment()
Future<void> _initializePayment() async {
  final camerpay = CamerPayService();
  
  final result = await camerpay.initializeMissionPayment(
    missionId: widget.mission['id'],
    amount: widget.quote['subtotal'].toDouble(), // ✅ 100% amount
    clientId: widget.quote['client_id'],
    clientPhone: _clientPhone,
    clientEmail: _clientEmail,
    description: 'Payment for ${widget.mission['id']}',
  );
  
  if (result['success']) {
    // Open payment URL in WebView
    final paymentUrl = result['data']['paymentUrl'];
    _openPaymentInWebView(paymentUrl);
  }
}
```

---

## 5️⃣ Create Subscription Widget

### New Component: `mobile/lib/presentation/shared/subscription_status_widget.dart`

**Display subscription status on home screen:**
```dart
class SubscriptionStatusWidget extends StatefulWidget {
  final String technicianId;
  
  // Shows:
  // ✅ Active Trial (30 days remaining)
  // ✅ Active Subscription (monthly/yearly)
  // ⏳ Subscription expiring soon
  // ❌ Subscription expired - Renew required
}
```

---

## 6️⃣ Update Technician Home Screen

### Fichier: `mobile/lib/presentation/technician/technician_home_screen.dart`

**Add to top:**
```dart
// Show subscription status badge
// - Green if trial/subscription active
// - Red if expired
// - Yellow if expiring soon

Row(
  children: [
    SubscriptionStatusWidget(
      technicianId: currentTechnicianId,
    ),
    if (subscriptionStatus == 'expired') ...[
      ElevatedButton(
        onPressed: _goToSubscriptionScreen,
        child: Text('Renew Subscription'),
      ),
    ],
  ],
)
```

---

## 7️⃣ Replace NotchPay References

### Files to Update:
1. `lib/data/constants/notchpay_config.dart` → Delete or keep as reference
2. `lib/data/services/notchpay_service.dart` → Can be removed (replaced by camerpay_service.dart)
3. All files importing NotchPayConfig → Replace with CamerPayService

### Search for:
```
NotchPayConfig
NotchPayService
notchpay_service
commissionRate
```

---

## 8️⃣ Payment Method Selection

### Update Payment Method Selection (if applicable):

**If user has choice of payment methods:**
```dart
// Remove NotchPay option
// Keep CamerPay as default/only option
// Update UI to show "CamerPay" instead of "NotchPay"
```

---

## Summary of Mobile Changes

| Component | Action | File |
|-----------|--------|------|
| Service Layer | Add CamerPay service | `camerpay_service.dart` ✅ |
| Service Layer | Remove NotchPay service | `notchpay_service.dart` |
| Payment Screen | Remove 5% commission | `payment_screen.dart` |
| Subscription | New subscription screen | `subscription_screen.dart` (NEW) |
| Registration | Add free trial start | `register_screen.dart` |
| Onboarding | Show trial info | `onboarding_screen.dart` |
| Home Screen | Show subscription status | `technician_home_screen.dart` |
| Widgets | Subscription status badge | `subscription_status_widget.dart` (NEW) |

---

## 🔑 Key Points

✅ **Commission Removed**: No more 5% deduction - clients pay 100%, technician receives 100%
✅ **Free Trial**: 30 days automatically added for new technicians
✅ **Subscription Required**: Technicians must pay 2000 FCFA/month or 20000 FCFA/year after trial
✅ **CamerPay Integration**: All payments go through CamerPay
✅ **Payment Flow**: Client → CamerPay → Backend confirmation → Wallet credited

---

## Testing Checklist

- [ ] Payment initialization without commission
- [ ] CamerPay payment URL opens correctly
- [ ] Payment callback confirms successfully
- [ ] Subscription screen displays correctly
- [ ] Trial period shows correct days remaining
- [ ] Subscription renewal works
- [ ] Expired subscription blocks mission access
- [ ] New technician automatically gets 30-day trial
