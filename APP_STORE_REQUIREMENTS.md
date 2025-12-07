# App Store Requirements & Compliance Guide

## iOS App Store & Google Play Store Standards

**Last Updated:** January 2025  
**App Name:** Carbon Cube Kenya  
**Platforms:** iOS & Android

---

## Table of Contents

1. [iOS App Store Requirements](#ios-app-store-requirements)
2. [Google Play Store Requirements](#google-play-store-requirements)
3. [Common Requirements](#common-requirements)
4. [Privacy & Data Protection](#privacy--data-protection)
5. [Content Guidelines](#content-guidelines)
6. [Technical Requirements](#technical-requirements)
7. [Submission Checklist](#submission-checklist)

---

## iOS App Store Requirements

### 1. App Review Guidelines

#### 1.1 Functionality

- ✅ **App must be complete and functional** - All features must work as described
- ✅ **No placeholder content** - App must contain real content, not placeholder text
- ✅ **No broken links** - All links must work correctly
- ✅ **No crashes or bugs** - App must be stable and perform well
- ✅ **Beta testing required** - Use TestFlight for beta testing before submission

#### 1.2 Performance

- ✅ **Fast launch time** - App should launch in under 3 seconds
- ✅ **Responsive UI** - No lag or freezing during use
- ✅ **Efficient memory usage** - App should not consume excessive memory
- ✅ **Battery optimization** - App should not drain battery excessively
- ✅ **Network efficiency** - Minimize data usage and optimize API calls

#### 1.3 Business Model

- ✅ **Clear monetization** - If using in-app purchases, clearly disclose pricing
- ✅ **No hidden costs** - All costs must be visible before purchase
- ✅ **Subscription clarity** - Subscription terms must be clear and cancellable
- ✅ **Payment processing** - Use Apple's in-app purchase system for digital goods

#### 1.4 Design

- ✅ **Follow Human Interface Guidelines** - Adhere to Apple's design principles
- ✅ **Native iOS look and feel** - Use iOS design patterns and components
- ✅ **Consistent navigation** - Follow iOS navigation conventions
- ✅ **Accessibility** - Support VoiceOver and other accessibility features
- ✅ **Dark mode support** - Support both light and dark appearances

#### 1.5 Legal Requirements

- ✅ **Privacy Policy** - Must have a privacy policy URL
- ✅ **Terms of Service** - Terms of service must be accessible
- ✅ **Data collection disclosure** - Disclose all data collection practices
- ✅ **Age rating** - Accurate age rating based on content
- ✅ **Intellectual property** - Must own or have rights to all content

### 2. Technical Requirements

#### 2.1 iOS Version Support

- ✅ **Minimum iOS version** - Support iOS 13.0 or later (recommended iOS 15.0+)
- ✅ **Latest SDK** - Use latest iOS SDK and Xcode version
- ✅ **64-bit support** - App must support 64-bit architecture
- ✅ **Device compatibility** - Test on multiple device sizes (iPhone SE to iPhone Pro Max)

#### 2.2 App Metadata

- ✅ **App Name** - Maximum 30 characters, must be unique
- ✅ **Subtitle** - Maximum 30 characters (optional)
- ✅ **Description** - Maximum 4000 characters, clear and accurate
- ✅ **Keywords** - Maximum 100 characters, relevant keywords
- ✅ **Support URL** - Valid support website URL
- ✅ **Marketing URL** - Optional marketing website URL
- ✅ **Privacy Policy URL** - Required, must be accessible

#### 2.3 App Icons & Screenshots

- ✅ **App Icon** - 1024x1024px PNG, no transparency, no rounded corners
- ✅ **Screenshots** - Required for all device sizes:
  - iPhone 6.7" (iPhone 14 Pro Max, 15 Pro Max)
  - iPhone 6.5" (iPhone 11 Pro Max, XS Max)
  - iPhone 5.5" (iPhone 8 Plus)
  - iPad Pro 12.9" (if iPad supported)
  - iPad Pro 11" (if iPad supported)
- ✅ **Screenshot count** - Minimum 3, maximum 10 per device size
- ✅ **Preview video** - Optional but recommended (30 seconds max)

#### 2.4 Required Permissions & Usage Descriptions

- ✅ **Location** - `NSLocationWhenInUseUsageDescription` (already in Info.plist)
- ✅ **Camera** - `NSCameraUsageDescription` (if using camera)
- ✅ **Photo Library** - `NSPhotoLibraryUsageDescription` (if accessing photos)
- ✅ **Contacts** - `NSContactsUsageDescription` (if accessing contacts)
- ✅ **Microphone** - `NSMicrophoneUsageDescription` (if using microphone)
- ✅ **Notifications** - User must opt-in for push notifications

#### 2.5 App Transport Security (ATS)

- ✅ **HTTPS required** - All network requests must use HTTPS
- ✅ **NSAllowsArbitraryLoads** - Must be `false` (currently set correctly)
- ✅ **Exception domains** - Only add exceptions if absolutely necessary with justification

### 3. Privacy Requirements

#### 3.1 Privacy Policy

- ✅ **Required** - Must have a privacy policy URL
- ✅ **Accessible** - Must be accessible without login
- ✅ **Comprehensive** - Must cover all data collection practices
- ✅ **Updated** - Must be kept current with app functionality

#### 3.2 App Privacy Details (App Store Connect)

- ✅ **Data collection disclosure** - Declare all data types collected
- ✅ **Data usage** - Explain how data is used
- ✅ **Data linking** - Declare if data is linked to user identity
- ✅ **Tracking** - Declare if app tracks users across apps/websites
- ✅ **Third-party sharing** - Declare data shared with third parties

### 4. Content Rating

- ✅ **Age rating** - Complete questionnaire in App Store Connect
- ✅ **Content descriptors** - Accurately describe all content
- ✅ **Rating justification** - Provide justification for rating

---

## Google Play Store Requirements

### 1. Developer Program Policies

#### 1.1 Restricted Content

- ✅ **No prohibited content** - No sexually explicit, violent, or hateful content
- ✅ **No misleading content** - App must accurately represent functionality
- ✅ **No spam** - No repetitive, low-quality, or misleading apps
- ✅ **No intellectual property violations** - Must own or have rights to all content

#### 1.2 Functionality

- ✅ **Complete and functional** - App must work as described
- ✅ **No crashes** - App must be stable and crash-free
- ✅ **No broken features** - All features must work correctly
- ✅ **Beta testing** - Use internal testing track before production

#### 1.3 Monetization

- ✅ **Clear pricing** - All prices must be clearly displayed
- ✅ **Payment processing** - Use Google Play Billing for in-app purchases
- ✅ **Subscription clarity** - Clear subscription terms and cancellation
- ✅ **No deceptive practices** - No hidden costs or misleading offers

### 2. Technical Requirements

#### 2.1 Android Version Support

- ✅ **Minimum SDK** - Support Android 8.0 (API level 26) or higher (recommended API 28+)
- ✅ **Target SDK** - Target latest Android SDK version
- ✅ **64-bit support** - Must support 64-bit architecture (required since August 2019)
- ✅ **Device compatibility** - Test on multiple screen sizes and densities

#### 2.2 App Metadata

- ✅ **App Name** - Maximum 50 characters
- ✅ **Short Description** - Maximum 80 characters
- ✅ **Full Description** - Maximum 4000 characters
- ✅ **Support URL** - Valid support website URL
- ✅ **Privacy Policy URL** - Required, must be accessible

#### 2.3 App Icons & Graphics

- ✅ **App Icon** - 512x512px PNG, no transparency, 32-bit PNG
- ✅ **Feature Graphic** - 1024x500px PNG (required)
- ✅ **Screenshots** - Minimum 2, maximum 8 per device type:
  - Phone screenshots (required)
  - Tablet screenshots (if tablet supported)
  - TV screenshots (if TV supported)
  - Wear OS screenshots (if Wear OS supported)
- ✅ **Promo video** - Optional YouTube video link

#### 2.4 Required Permissions

- ✅ **Runtime permissions** - Request permissions at runtime (Android 6.0+)
- ✅ **Permission justification** - Explain why each permission is needed
- ✅ **Minimal permissions** - Only request necessary permissions
- ✅ **Permission groups** - Group related permissions logically

#### 2.5 Security Requirements

- ✅ **App signing** - Must use Play App Signing
- ✅ **ProGuard/R8** - Enable code obfuscation for release builds
- ✅ **HTTPS** - All network traffic must use HTTPS
- ✅ **Certificate pinning** - Consider implementing certificate pinning
- ✅ **No hardcoded secrets** - No API keys or secrets in code

### 3. Privacy Requirements

#### 3.1 Privacy Policy

- ✅ **Required** - Must have a privacy policy URL
- ✅ **Accessible** - Must be accessible without login
- ✅ **Comprehensive** - Must cover all data collection practices
- ✅ **Updated** - Must be kept current with app functionality

#### 3.2 Data Safety Section (Play Console)

- ✅ **Data collection** - Declare all data types collected
- ✅ **Data usage** - Explain how data is used
- ✅ **Data sharing** - Declare data shared with third parties
- ✅ **Security practices** - Describe security measures
- ✅ **Data deletion** - Explain how users can delete data

### 4. Content Rating

- ✅ **IARC rating** - Complete IARC questionnaire
- ✅ **Age rating** - Accurate age rating based on content
- ✅ **Content descriptors** - Accurately describe all content

---

## Common Requirements

### 1. Privacy & Data Protection

#### 1.1 GDPR Compliance (if applicable)

- ✅ **Consent** - Obtain explicit consent for data processing
- ✅ **Right to access** - Users can access their data
- ✅ **Right to deletion** - Users can delete their data
- ✅ **Data portability** - Users can export their data
- ✅ **Privacy by design** - Implement privacy from the start

#### 1.2 CCPA Compliance (if applicable)

- ✅ **Do Not Sell** - Provide option to opt-out of data sale
- ✅ **Disclosure** - Disclose data collection practices
- ✅ **Access** - Provide access to collected data

#### 1.3 Data Minimization

- ✅ **Collect only necessary data** - Don't collect unnecessary data
- ✅ **Purpose limitation** - Use data only for stated purposes
- ✅ **Retention limits** - Delete data when no longer needed

### 2. Security Requirements

#### 2.1 Authentication & Authorization

- ✅ **Secure authentication** - Use secure authentication methods
- ✅ **Token management** - Secure token storage (using Keychain/SecureStore)
- ✅ **Session management** - Proper session timeout and management
- ✅ **Password security** - Enforce strong password policies

#### 2.2 Data Encryption

- ✅ **Data in transit** - All data encrypted in transit (HTTPS/TLS)
- ✅ **Data at rest** - Sensitive data encrypted at rest
- ✅ **Key management** - Secure key management practices

#### 2.3 API Security

- ✅ **API authentication** - Secure API authentication
- ✅ **Rate limiting** - Implement rate limiting
- ✅ **Input validation** - Validate all inputs
- ✅ **Error handling** - Don't expose sensitive info in errors

### 3. Accessibility Requirements

#### 3.1 iOS Accessibility

- ✅ **VoiceOver support** - App must work with VoiceOver
- ✅ **Dynamic Type** - Support Dynamic Type for text sizing
- ✅ **Color contrast** - Minimum 4.5:1 contrast ratio
- ✅ **Touch targets** - Minimum 44x44pt touch targets
- ✅ **Accessibility labels** - Provide accessibility labels

#### 3.2 Android Accessibility

- ✅ **TalkBack support** - App must work with TalkBack
- ✅ **Content descriptions** - Provide content descriptions
- ✅ **Touch targets** - Minimum 48dp touch targets
- ✅ **Color contrast** - Minimum 4.5:1 contrast ratio
- ✅ **Text scaling** - Support text scaling

### 4. Performance Requirements

#### 4.1 App Size

- ✅ **iOS** - Keep app size reasonable (under 150MB recommended)
- ✅ **Android** - Use Android App Bundle (AAB) format
- ✅ **Asset optimization** - Optimize images and assets
- ✅ **Code splitting** - Use code splitting where applicable

#### 4.2 Startup Time

- ✅ **Cold start** - Under 3 seconds
- ✅ **Warm start** - Under 1 second
- ✅ **Optimization** - Lazy load non-critical components

#### 4.3 Memory Usage

- ✅ **Memory leaks** - No memory leaks
- ✅ **Memory limits** - Stay within platform memory limits
- ✅ **Image optimization** - Optimize image loading and caching

### 5. Content Guidelines

#### 5.1 User-Generated Content

- ✅ **Moderation** - Moderate user-generated content
- ✅ **Reporting** - Provide reporting mechanism
- ✅ **Terms enforcement** - Enforce terms of service

#### 5.2 Age Appropriateness

- ✅ **Content rating** - Accurate content rating
- ✅ **Age gates** - Implement age gates if needed
- ✅ **Parental controls** - Support parental controls if applicable

---

## Submission Checklist

### Pre-Submission Checklist

#### iOS App Store

- [ ] App is complete and fully functional
- [ ] All features work as described
- [ ] No crashes or bugs
- [ ] Tested on multiple iOS devices and versions
- [ ] App icon (1024x1024px) ready
- [ ] Screenshots for all required device sizes ready
- [ ] App description written (max 4000 characters)
- [ ] Keywords defined (max 100 characters)
- [ ] Privacy policy URL ready and accessible
- [ ] Support URL ready
- [ ] App Store Connect account set up
- [ ] App ID and Bundle Identifier configured
- [ ] Certificates and provisioning profiles set up
- [ ] App signed with distribution certificate
- [ ] All required usage descriptions in Info.plist
- [ ] ATS configured correctly (NSAllowsArbitraryLoads = false)
- [ ] App Privacy details completed in App Store Connect
- [ ] Age rating questionnaire completed
- [ ] TestFlight beta testing completed
- [ ] App reviewed internally before submission

#### Google Play Store

- [ ] App is complete and fully functional
- [ ] All features work as described
- [ ] No crashes or bugs
- [ ] Tested on multiple Android devices and versions
- [ ] App icon (512x512px) ready
- [ ] Feature graphic (1024x500px) ready
- [ ] Screenshots ready (minimum 2, maximum 8)
- [ ] App description written (max 4000 characters)
- [ ] Short description written (max 80 characters)
- [ ] Privacy policy URL ready and accessible
- [ ] Support URL ready
- [ ] Google Play Console account set up
- [ ] App signed with release keystore
- [ ] Play App Signing enabled
- [ ] ProGuard/R8 enabled for release builds
- [ ] 64-bit support implemented
- [ ] Target SDK set to latest version
- [ ] Minimum SDK set appropriately
- [ ] Data Safety section completed
- [ ] Content rating (IARC) completed
- [ ] Internal testing track completed
- [ ] App reviewed internally before submission

### Post-Submission

#### Both Platforms

- [ ] Monitor app reviews and ratings
- [ ] Respond to user reviews promptly
- [ ] Monitor crash reports and fix critical issues
- [ ] Monitor analytics and performance metrics
- [ ] Prepare for app updates and maintenance
- [ ] Keep privacy policy updated
- [ ] Keep app description and screenshots current

---

## Required Files & Configuration

### iOS Configuration Files

#### Info.plist Requirements

```xml
<!-- Already configured -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby listings</string>

<!-- Add if using camera -->
<key>NSCameraUsageDescription</key>
<string>We need camera access to upload listing photos</string>

<!-- Add if accessing photo library -->
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select listing images</string>

<!-- Add if using contacts -->
<key>NSContactsUsageDescription</key>
<string>We need contacts access to help you invite friends</string>

<!-- Add if using microphone -->
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for voice messages</string>
```

### Android Configuration Files

#### AndroidManifest.xml Requirements

```xml
<!-- Add required permissions -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Add if using location -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Add if using camera -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Add if accessing storage -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

#### build.gradle Requirements

```gradle
android {
    defaultConfig {
        minSdkVersion 26  // Android 8.0
        targetSdkVersion 34  // Latest Android version
        versionCode 1
        versionName "1.0.0"
    }

    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

---

## Common Rejection Reasons

### iOS App Store

1. **Crashes or bugs** - App crashes during review
2. **Broken links** - Links don't work or lead to error pages
3. **Placeholder content** - App contains placeholder text or images
4. **Missing privacy policy** - No privacy policy URL or inaccessible
5. **Incomplete functionality** - Features don't work as described
6. **Misleading information** - App description doesn't match functionality
7. **Violation of guidelines** - Content violates App Store guidelines
8. **Performance issues** - App is slow or unresponsive

### Google Play Store

1. **Crashes or ANRs** - App crashes or becomes unresponsive
2. **Misleading content** - App doesn't match description
3. **Missing privacy policy** - No privacy policy or inaccessible
4. **Violation of policies** - Content violates Play Store policies
5. **Security issues** - App has security vulnerabilities
6. **Incomplete Data Safety** - Data Safety section incomplete or inaccurate
7. **Performance issues** - App is slow or consumes excessive resources

---

## Best Practices

### 1. Testing

- ✅ Test on real devices, not just simulators/emulators
- ✅ Test on multiple device sizes and OS versions
- ✅ Test all user flows and edge cases
- ✅ Test with poor network conditions
- ✅ Test accessibility features
- ✅ Test in different languages (if supporting multiple languages)

### 2. App Store Optimization (ASO)

- ✅ Use relevant keywords in app name and description
- ✅ Create compelling screenshots showing key features
- ✅ Write clear, benefit-focused descriptions
- ✅ Encourage positive reviews (but don't incentivize)
- ✅ Respond to all reviews professionally
- ✅ Update app regularly with improvements

### 3. Privacy

- ✅ Be transparent about data collection
- ✅ Collect only necessary data
- ✅ Provide clear privacy policy
- ✅ Allow users to control their data
- ✅ Implement data deletion functionality

### 4. Performance

- ✅ Optimize app size
- ✅ Minimize startup time
- ✅ Optimize memory usage
- ✅ Efficient network usage
- ✅ Battery optimization

---

## Resources

### iOS App Store

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [TestFlight Beta Testing](https://developer.apple.com/testflight/)

### Google Play Store

- [Developer Policy Center](https://play.google.com/about/developer-content-policy/)
- [Play Console Help](https://support.google.com/googleplay/android-developer/)
- [Material Design Guidelines](https://material.io/design)
- [Android Developer Guides](https://developer.android.com/guide)

### Privacy & Security

- [GDPR Compliance Guide](https://gdpr.eu/)
- [CCPA Compliance Guide](https://oag.ca.gov/privacy/ccpa)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)

---

## Notes

- This document should be reviewed and updated regularly as store requirements change
- All requirements marked with ✅ must be implemented before submission
- Use the submission checklist before each app submission
- Keep this document synchronized with actual app implementation
- Document any deviations from requirements with justification

---

**Document Version:** 1.0  
**Last Updated:** January 2025  
**Next Review:** April 2025
