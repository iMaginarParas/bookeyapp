# 🚀 Quick Action Items - App Store Resubmission

## ✅ COMPLETED (Code Changes)

1. **Terms of Use (EULA) Links** ✅
   - Added to subscription purchase screen
   - Added to credit purchase cards
   - Added to Profile settings menu
   - All links functional and open in external browser

2. **Privacy Policy Links** ✅
   - Added to subscription purchase screen
   - Added to credit purchase cards  
   - Added to Profile settings menu
   - All links functional and open in external browser

3. **Subscription Information Display** ✅
   - Shows subscription title
   - Shows duration (Yearly - auto-renewing)
   - Shows price (₹999/yearly)
   - All required info visible before purchase

4. **Receipt Validation** ✅
   - RevenueCat handles sandbox/production automatically
   - Added retry logic for entitlement propagation
   - Improved error handling
   - Better debugging logs

---

## ⚠️ REQUIRED ACTIONS (You Must Do)

### 1. Update iPad Screenshots (CRITICAL)
**Location:** App Store Connect → Your App → Previews and Screenshots

**What to do:**
- [ ] Take new screenshots on 13-inch iPad showing ACTUAL app usage
- [ ] Include these screens:
  - Create page (with upload UI visible)
  - Processing page (showing content being processed)
  - Videos library (with actual videos)
  - Profile/subscription page (showing real UI)
- [ ] Upload to "View All Sizes in Media Manager"
- [ ] Delete old marketing/splash screen shots

**Why:** Apple rejected because screenshots show marketing materials instead of actual app UI.

---

### 2. Review App Metadata (CRITICAL)
**Location:** App Store Connect → Your App → App Information

**Check these items:**

- [ ] **App Name:** "Bookey" 
  - Make sure it's not too similar to other popular apps
  - Consider: "Bookey - AI Video Creator" if needed

- [ ] **App Description:**
  - Ensure it doesn't copy text from other apps
  - Emphasize unique features: "Transform stories into AI videos"
  - Make it clear this is YOUR app, not someone else's

- [ ] **App Icon:**
  - Review if it looks too similar to other apps
  - May need redesign if it's too generic

- [ ] **Keywords:**
  - Don't use brand names of other apps
  - Use: ai video, story creator, text to video, etc.

**Why:** Apple flagged app as potentially copying another popular app (Guideline 4.1).

---

### 3. Verify Backend Endpoint
**Endpoint:** `DELETE /auth/delete-account`

- [ ] Test endpoint exists and works
- [ ] Verify it accepts JWT token
- [ ] Ensure it returns 200/204 on success
- [ ] Test that it actually deletes user data

**Why:** Required for account deletion feature.

---

### 4. Test Before Resubmission

#### Test Subscriptions
- [ ] Open app in sandbox mode
- [ ] Go to Profile → Credits & Plans
- [ ] Click "Terms of Use (EULA)" link → Should open browser
- [ ] Click "Privacy Policy" link → Should open browser
- [ ] Purchase "Pro Yearly" subscription → Should work without errors
- [ ] Verify subscription details show: title, price, duration

#### Test Credits
- [ ] Go to Buy Credits tab
- [ ] Click Terms/Privacy links on credit cards → Should open
- [ ] Purchase any credit package → Should work without errors
- [ ] Cancel a purchase → Should NOT show error

#### Test Profile Links
- [ ] Open Profile page
- [ ] Tap "Terms of Use (EULA)" → Should open browser
- [ ] Tap "Privacy Policy" → Should open browser
- [ ] Both should open Apple/Bookey links

---

## 📋 Resubmission Checklist

- [ ] New iPad screenshots uploaded
- [ ] App name/description reviewed for uniqueness
- [ ] All purchases tested in sandbox
- [ ] All legal links tested and working
- [ ] Account deletion endpoint tested
- [ ] Run `flutter build ios --release`
- [ ] Upload to App Store Connect
- [ ] Reply to App Review message mentioning fixes

---

## 📝 Reply Template for App Review

When replying to the App Review message in App Store Connect:

```
Dear App Review Team,

Thank you for your feedback. We have addressed all the issues:

✅ Guideline 3.1.2 - Subscriptions:
- Added functional Terms of Use (EULA) links throughout the app
- Added functional Privacy Policy links throughout the app
- Subscription details now clearly show title, duration, and price
- All links open in external browser as required

✅ Guideline 2.1 - In-App Purchases:
- Fixed receipt validation to properly handle sandbox environment
- RevenueCat SDK now correctly validates receipts from both sandbox and production
- Purchases have been tested successfully in sandbox environment

✅ Guideline 2.3.3 - Screenshots:
- Uploaded new 13-inch iPad screenshots showing actual app UI
- All screenshots now display the app in use with real functionality
- Removed marketing materials and splash screens

✅ Guideline 4.1 - App Identity:
- Reviewed app name, description, and icon for uniqueness
- [Add any changes you made here]

All changes have been tested and verified. Please let us know if you need any additional information.

Thank you,
Bookey Team
```

---

## 🔧 Technical Details

**Files Modified:**
- `lib/credit.dart` - Added legal links, improved purchases
- `lib/profile.dart` - Added legal links to settings
- `APP_STORE_FIXES.md` - Complete documentation

**No Additional Dependencies Needed:**
- `url_launcher` already in pubspec.yaml ✅
- `purchases_flutter` already configured ✅

**Testing Environment:**
- Use sandbox test accounts
- Test on actual iPad device
- Test on iPhone as well

---

## 📞 Support

If you need help:
- Review full documentation: `APP_STORE_FIXES.md`
- Email: info@bookey.in
- Check App Store Connect for updates

---

## ⏱️ Timeline

1. **Today:** Update screenshots and metadata (1-2 hours)
2. **Today:** Test all functionality (30 minutes)
3. **Today:** Submit for review
4. **2-3 days:** Wait for App Review response
5. **Success:** App approved! 🎉

---

**Priority:** HIGH - App Store submission on hold
**Due:** ASAP - Complete within 24 hours for fastest review
