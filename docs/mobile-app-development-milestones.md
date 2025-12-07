# Mobile App Development Milestones - Carbon Cube Kenya

**Platform:** Android & iOS
**Timeline:** 3 Months
**Framework:** React Native
**Start Date:**

---

## Table of Contents

1. [Month 1: Foundation &amp; Core Setup](#month-1-foundation--core-setup)
2. [Month 2: Core Features Development](#month-2-core-features-development)
3. [Month 3: Tier Upgrades &amp; Launch](#month-3-tier-upgrades--launch)
4. [Key Deliverables Summary](#key-deliverables-summary)
5. [Technical Stack](#technical-stack)
6. [Risk Management](#risk-management)

---

## Month 1: Foundation & Core Setup

### Week 1-2: Project Initiation & Architecture

#### Project Setup & Environment

- [ ] Initialize React Native project (TypeScript template)
- [ ] Configure development environment
  - [ ] Android Studio setup (Android SDK, emulators)
  - [ ] Xcode setup (iOS Simulator, CocoaPods)
  - [ ] Node.js and npm/yarn configuration
- [ ] Set up Git repository and branching strategy
- [ ] Configure CI/CD pipeline (GitHub Actions / Bitrise)
- [ ] Set up code quality tools (ESLint, Prettier, Husky)

#### Project Structure

- [ ] Create folder structure
  ```
  /src
    /components
    /screens
    /navigation
    /services
    /hooks
    /store
    /utils
    /types
    /constants
  ```
- [ ] Set up absolute imports (path aliases)
- [ ] Configure environment variables (.env files)
- [ ] Set up TypeScript configuration

#### Core Architecture

- [ ] API client setup (Axios with interceptors)
  - [ ] Base URL configuration
  - [ ] Request/Response interceptors
  - [ ] Error handling
  - [ ] Token refresh logic
- [ ] State management setup (Zustand)
  - [ ] Auth store
  - [ ] User store
  - [ ] App state store
- [ ] Navigation setup (React Navigation)
  - [ ] Stack navigator
  - [ ] Tab navigator
  - [ ] Drawer navigator (if needed)
  - [ ] Deep linking configuration
- [ ] Design system foundation
  - [ ] Color palette
  - [ ] Typography system
  - [ ] Spacing system
  - [ ] Component library setup (React Native Paper / NativeBase)

#### Deliverables

- Working React Native project
- Development environment ready
- Basic navigation structure
- API client configured
- State management setup

---

### Week 3-4: Authentication & Onboarding

#### Authentication Implementation

- [ ] Login screen
  - [ ] Email/Phone input
  - [ ] Password input
  - [ ] "Remember me" functionality
  - [ ] Form validation
  - [ ] Error handling
- [ ] Registration screen
  - [ ] User type selection (Buyer/Seller)
  - [ ] Email/Phone registration
  - [ ] Password strength indicator
  - [ ] Terms & Conditions acceptance
- [ ] OAuth integration
  - [ ] Google Sign-In setup
  - [ ] iOS Google Sign-In configuration
  - [ ] Android Google Sign-In configuration
- [ ] OTP verification flow
  - [ ] OTP input screen
  - [ ] Resend OTP functionality
  - [ ] Auto-verify (if possible)
  - [ ] Timer countdown
- [ ] Password reset flow
  - [ ] Request OTP screen
  - [ ] Verify OTP screen
  - [ ] Reset password screen
- [ ] Token management
  - [ ] Secure storage (React Native Keychain / SecureStore)
  - [ ] Token refresh mechanism
  - [ ] Auto-logout on token expiry

#### Onboarding

- [ ] Onboarding screens (3-4 screens)
  - [ ] Welcome screen
  - [ ] Features overview
  - [ ] User type selection
- [ ] First-time user experience
- [ ] Skip onboarding option

#### User Profile Setup

- [ ] Profile creation screen (Buyer)
- [ ] Profile creation screen (Seller)
- [ ] Profile image upload
- [ ] Basic information form
- [ ] Location selection (Kenyan counties)

#### Deep Linking

- [ ] Configure deep links
- [ ] Email verification links
- [ ] Password reset links
- [ ] OAuth callback handling

#### Deliverables

- Complete authentication flow
- OAuth integration working
- Onboarding experience
- User profile setup
- Deep linking configured

---

## Month 2: Core Features Development

### Week 5-6: Buyer Core Features

#### Home Screen

- [ ] Home screen layout
  - [ ] Search bar
  - [ ] Category grid/slider
  - [ ] Featured listings carousel
  - [ ] Recent listings section
  - [ ] Special offers banner
- [ ] Pull-to-refresh
- [ ] Infinite scroll for listings

#### Listing Browsing

- [ ] Ad/Listing list view
  - [ ] Grid view option
  - [ ] List view option
  - [ ] Image lazy loading
  - [ ] Skeleton loaders
- [ ] Ad detail page
  - [ ] Image gallery with zoom
  - [ ] Image carousel/swiper
  - [ ] Product information
  - [ ] Seller information card
  - [ ] Contact seller button
  - [ ] Share functionality
  - [ ] Save to wishlist
- [ ] Category browsing
  - [ ] Category list
  - [ ] Subcategory navigation
  - [ ] Category-based filtering

#### Search & Filters

- [ ] Search functionality
  - [ ] Search input with suggestions
  - [ ] Search results screen
  - [ ] Recent searches
  - [ ] Popular searches
- [ ] Advanced filters
  - [ ] Price range filter
  - [ ] Location filter
  - [ ] Category filter
  - [ ] Sort options (price, date, relevance)
  - [ ] Apply/Reset filters

#### Wishlist

- [ ] Wishlist screen
- [ ] Add/Remove from wishlist
- [ ] Wishlist count badge
- [ ] Quick actions (contact seller, remove)

#### Seller Profile/Shop

- [ ] Seller profile page
  - [ ] Seller information
  - [ ] Seller's listings grid
  - [ ] Seller reviews
  - [ ] Contact seller button
- [ ] Shop page view

#### Image Handling

- [ ] Image caching (React Native Fast Image)
- [ ] Image optimization
- [ ] Placeholder images
- [ ] Error handling for failed images

#### Deliverables

- Complete buyer browsing experience
- Search and filter functionality
- Wishlist feature
- Image optimization

---

### Week 7-8: Seller Core Features

#### Seller Dashboard

- [ ] Dashboard screen
  - [ ] Statistics cards (views, messages, listings)
  - [ ] Recent activity
  - [ ] Quick actions
  - [ ] Current tier display
- [ ] Analytics overview
  - [ ] Views chart
  - [ ] Messages chart
  - [ ] Listing performance

#### Ad Management

- [ ] Ad creation screen
  - [ ] Multi-step form
  - [ ] Title and description
  - [ ] Category selection
  - [ ] Price input
  - [ ] Location selection
  - [ ] Multiple image upload
  - [ ] Image reordering
  - [ ] Preview before publish
- [ ] Ad editing screen
  - [ ] Edit existing ad
  - [ ] Update images
  - [ ] Change status (active/inactive)
- [ ] Ad list (My Listings)
  - [ ] Active listings
  - [ ] Inactive listings
  - [ ] Draft listings
  - [ ] Quick actions (edit, delete, activate)
- [ ] Ad deletion
  - [ ] Confirmation dialog
  - [ ] Soft delete option

#### Image Upload

- [ ] Image picker integration
  - [ ] Camera capture
  - [ ] Gallery selection
  - [ ] Multiple image selection
- [ ] Image compression
- [ ] Upload progress indicator
- [ ] Image preview before upload
- [ ] Image deletion

#### Seller Profile Management

- [ ] Profile edit screen
  - [ ] Business information
  - [ ] Contact details
  - [ ] Profile picture
  - [ ] Business description
- [ ] Document upload (if needed)
- [ ] Profile verification status

#### Tier Management (View Only)

- [ ] Current tier display
  - [ ] Tier name and benefits
  - [ ] Expiration date
  - [ ] Usage statistics
- [ ] Tier comparison (preview)
- [ ] Upgrade prompt (navigate to upgrade screen)

#### Review Management

- [ ] Reviews list
- [ ] Review details
- [ ] Reply to reviews
- [ ] Review statistics

#### Deliverables

- Complete seller dashboard
- Ad CRUD operations
- Image upload system
- Profile management

---

### Week 9-10: Messaging & Communication

#### Real-time Messaging

- [ ] ActionCable integration
  - [ ] WebSocket connection setup
  - [ ] Connection management
  - [ ] Reconnection logic
  - [ ] Authentication with JWT token
- [ ] Conversations list
  - [ ] List of all conversations
  - [ ] Unread message indicators
  - [ ] Last message preview
  - [ ] Timestamp display
  - [ ] Search conversations
- [ ] Chat interface
  - [ ] Message list
  - [ ] Message bubbles (sent/received)
  - [ ] Timestamp for messages
  - [ ] Message status (sent, delivered, read)
  - [ ] Input field with send button
  - [ ] Image sharing in messages
  - [ ] Image preview in chat
  - [ ] Typing indicators (optional)
- [ ] Message actions
  - [ ] Mark as read
  - [ ] Delete conversation
  - [ ] Block user (if applicable)

#### Push Notifications

- [ ] Firebase Cloud Messaging setup
  - [ ] Android FCM configuration
  - [ ] iOS APNs configuration
- [ ] Notification handling
  - [ ] Foreground notifications
  - [ ] Background notifications
  - [ ] Notification tap actions
  - [ ] Notification badges
- [ ] Notification preferences
  - [ ] Enable/disable notifications
  - [ ] Notification types (messages, updates)

#### Contact Seller Flow

- [ ] "Contact Seller" button on ad detail
- [ ] Create new conversation
- [ ] Pre-filled message (optional)
- [ ] Navigate to chat screen

#### Deliverables

- Real-time messaging working
- Push notifications configured
- Complete chat experience

---

## Month 3: Tier Upgrades & Launch

### Week 11-12: Tier Management & Payments

#### Tier Management

- [ ] Tier listing screen
  - [ ] All available tiers
  - [ ] Tier comparison table
  - [ ] Benefits per tier
  - [ ] Pricing information
- [ ] Current tier screen
  - [ ] Current tier details
  - [ ] Expiration countdown
  - [ ] Usage statistics
  - [ ] Benefits breakdown
- [ ] Tier upgrade flow
  - [ ] Select tier screen
  - [ ] Select pricing plan (monthly/yearly)
  - [ ] Review and confirm
  - [ ] Payment method selection

#### M-Pesa Payment Integration

- [ ] M-Pesa SDK integration
  - [ ] Android M-Pesa SDK
  - [ ] iOS M-Pesa SDK (or web-based)
- [ ] STK Push implementation
  - [ ] Initiate payment
  - [ ] Payment request screen
  - [ ] Phone number input
  - [ ] Payment confirmation
- [ ] Payment status tracking
  - [ ] Polling for payment status
  - [ ] Payment success screen
  - [ ] Payment failure handling
  - [ ] Retry payment option
- [ ] Manual payment option
  - [ ] Payment instructions screen
  - [ ] Paybill number display
  - [ ] Account number display
  - [ ] Manual verification flow
- [ ] Payment history
  - [ ] List of all payments
  - [ ] Payment details
  - [ ] Receipt download (if available)

#### Payment Edge Cases

- [ ] Prevent duplicate payments
- [ ] Handle expired payments
- [ ] Payment timeout handling
- [ ] Network error handling
- [ ] Payment verification

#### Deliverables

- Complete tier upgrade flow
- M-Pesa payment integration
- Payment status tracking
- Payment history

---

### Week 13-14: Reviews, Offers & Polish

#### Review System

- [ ] Review listing screen
  - [ ] Reviews for a listing
  - [ ] Reviews for a seller
  - [ ] Rating display
  - [ ] Review text
  - [ ] Review images (if applicable)
- [ ] Submit review screen
  - [ ] Rating selection (stars)
  - [ ] Review text input
  - [ ] Image upload (optional)
  - [ ] Submit review
- [ ] Seller reply to reviews
  - [ ] Reply input
  - [ ] Submit reply
- [ ] Review statistics
  - [ ] Average rating
  - [ ] Rating distribution

#### Offers & Promotions

- [ ] Offers listing screen
  - [ ] Active offers
  - [ ] Featured offers
  - [ ] Flash sales
  - [ ] Upcoming offers
- [ ] Offer detail screen
  - [ ] Offer information
  - [ ] Participating listings
  - [ ] Countdown timer
- [ ] Offer notifications
  - [ ] New offer alerts
  - [ ] Flash sale alerts

#### Profile & Settings

- [ ] Profile screen
  - [ ] User information
  - [ ] Profile picture
  - [ ] Edit profile button
- [ ] Settings screen
  - [ ] Account settings
  - [ ] Notification settings
  - [ ] Privacy settings
  - [ ] Language settings (if applicable)
  - [ ] About section
  - [ ] Help & Support
  - [ ] Terms & Conditions
  - [ ] Privacy Policy
  - [ ] Logout option

#### Additional Features

- [ ] About Us screen
- [ ] FAQ screen
- [ ] Contact Us screen
- [ ] Help center
- [ ] App version display
- [ ] Rate app prompt (optional)

#### UI/UX Polish

- [ ] Loading states
- [ ] Error states
- [ ] Empty states
- [ ] Skeleton loaders
- [ ] Smooth animations
- [ ] Consistent spacing
- [ ] Accessibility improvements

#### Deliverables

- Complete review system
- Offers display
- Settings and profile
- Polished UI/UX

---

### Week 15-16: Testing, Optimization & Launch

#### Testing

- [ ] Unit testing
  - [ ] Critical functions
  - [ ] Utility functions
  - [ ] State management
- [ ] Integration testing
  - [ ] API integration
  - [ ] Navigation flows
  - [ ] Payment flows
- [ ] UI/UX testing
  - [ ] Screen flow testing
  - [ ] Device compatibility
  - [ ] Screen size testing
- [ ] Performance testing
  - [ ] App startup time
  - [ ] Image loading performance
  - [ ] Memory usage
  - [ ] Battery usage
- [ ] Security testing
  - [ ] Token storage security
  - [ ] API security
  - [ ] Data encryption

#### Bug Fixes

- [ ] Critical bugs
- [ ] High priority bugs
- [ ] Medium priority bugs
- [ ] UI/UX improvements

#### Performance Optimization

- [ ] Image optimization
  - [ ] Image compression
  - [ ] Lazy loading
  - [ ] Caching strategy
- [ ] Code optimization
  - [ ] Bundle size optimization
  - [ ] Remove unused dependencies
  - [ ] Code splitting
- [ ] Network optimization
  - [ ] Request batching
  - [ ] Caching strategies
  - [ ] Offline support (basic)

#### App Store Preparation

- [ ] App icons
  - [ ] iOS app icon (all sizes)
  - [ ] Android app icon (all sizes)
- [ ] Screenshots
  - [ ] iOS screenshots (all device sizes)
  - [ ] Android screenshots (all device sizes)
- [ ] App Store listings
  - [ ] App name
  - [ ] App description
  - [ ] Keywords
  - [ ] Privacy policy URL
  - [ ] Support URL
- [ ] App metadata
  - [ ] Version number
  - [ ] Build number
  - [ ] Release notes

#### Beta Testing

- [ ] Internal testing
  - [ ] TestFlight setup (iOS)
  - [ ] Internal testing track (Android)
  - [ ] Test user onboarding
- [ ] Beta feedback collection
  - [ ] Feedback form
  - [ ] Bug reporting
  - [ ] User surveys
- [ ] Beta fixes
  - [ ] Address critical issues
  - [ ] Implement feedback

#### App Store Submission

- [ ] iOS App Store
  - [ ] App Store Connect setup
  - [ ] Build upload
  - [ ] App review submission
  - [ ] Compliance checks
- [ ] Google Play Store
  - [ ] Google Play Console setup
  - [ ] Build upload
  - [ ] App review submission
  - [ ] Compliance checks

#### Launch Preparation

- [ ] Production environment setup
- [ ] API endpoints verification
- [ ] Monitoring setup
  - [ ] Crash reporting (Sentry)
  - [ ] Analytics (Firebase Analytics / Mixpanel)
  - [ ] Performance monitoring
- [ ] Launch checklist
- [ ] Rollback plan

#### Post-Launch

- [ ] Monitor app performance
- [ ] Monitor crash reports
- [ ] Monitor user feedback
- [ ] Hotfix deployment process
- [ ] Support team training

#### Deliverables

- Fully tested app
- Optimized performance
- App store submissions
- Production deployment
- Monitoring in place

---

## Key Deliverables Summary

### Month 1

- Working React Native project
- Complete authentication system
- Onboarding experience
- API integration layer
- Design system foundation

### Month 2

- Complete buyer browsing experience
- Complete seller management system
- Real-time messaging
- Image upload and management

### Month 3

- Tier upgrade payment system
- Review system
- Complete feature set
- Production-ready apps
- App store submissions

---

## Technical Stack

### Core

- **Framework:** React Native (latest stable)
- **Language:** TypeScript
- **State Management:** Zustand
- **Navigation:** React Navigation v6
- **API Client:** Fetch
- **Data Fetching:** TanStack Query (React Query)

### Real-time

- **WebSocket:** @rails/actioncable or react-native-actioncable
- **Push Notifications:** React Native Firebase (FCM/APNs)

### UI/UX

- **Component Library:** React Native Paper or NativeBase
- **Animations:** React Native Reanimated
- **Images:** React Native Fast Image
- **Icons:** React Native Vector Icons

### Payments

- **M-Pesa:** Custom M-Pesa SDK integration or react-native-mpesa

### Storage

- **Secure Storage:** React Native Keychain (iOS) / React Native Keychain (Android)
- **Async Storage:** @react-native-async-storage/async-storage

### Development Tools

- **Linting:** ESLint
- **Formatting:** Prettier
- **Git Hooks:** Husky
- **Testing:** Jest + React Native Testing Library

### Monitoring & Analytics

- **Crash Reporting:** Sentry
- **Analytics:** Firebase Analytics or Mixpanel
- **Performance:** React Native Performance Monitor

---

## Risk Management

### High Priority Risks

1. **M-Pesa Integration Complexity**

   - **Risk:** M-Pesa SDK integration may take longer than expected
   - **Mitigation:** Start M-Pesa integration early, have fallback manual payment option
   - **Contingency:** Use web-based M-Pesa integration if native SDK fails

2. **ActionCable WebSocket Issues**

   - **Risk:** WebSocket connections may be unstable on mobile
   - **Mitigation:** Implement robust reconnection logic, fallback to polling
   - **Contingency:** Use HTTP polling as backup

3. **App Store Review Delays**

   - **Risk:** App store review may take 1-2 weeks
   - **Mitigation:** Submit early, ensure compliance, have all documentation ready
   - **Contingency:** Plan for potential delays in launch date

4. **Image Upload Performance**

   - **Risk:** Large images may cause performance issues
   - **Mitigation:** Implement image compression, optimize upload process
   - **Contingency:** Reduce max image size or number of images

5. **Timeline Pressure**

   - **Risk:** 3 months is tight for full feature set
   - **Mitigation:** Prioritize core features, defer nice-to-haves
   - **Contingency:** Consider phased launch (MVP first, then enhancements)

### Medium Priority Risks

1. **Device Compatibility Issues**

   - **Risk:** App may not work on all devices
   - **Mitigation:** Test on multiple devices early, set minimum OS versions

2. **API Performance**

   - **Risk:** Backend API may not handle mobile load well
   - **Mitigation:** Implement caching, optimize API calls, coordinate with backend team

3. **Third-party Dependencies**

   - **Risk:** Key libraries may have issues or be deprecated
   - **Mitigation:** Use well-maintained libraries, have alternatives ready

---

## Success Metrics

### Technical Metrics

- App crash rate < 1%
- App startup time < 3 seconds
- API response time < 2 seconds
- Image load time < 1 second

### User Metrics

- User registration completion rate > 70%
- Daily active users (target to be set)
- Message response rate (target to be set)
- Tier upgrade conversion rate (target to be set)

---

## Notes

- Regular weekly reviews and adjustments may be needed
- Some features may be moved to post-launch based on priorities
- Regular testing on real devices is crucial

---

**Document Version:** 1.0
**Last Updated:** 14th November 2025
**Status:** Planning Phase
