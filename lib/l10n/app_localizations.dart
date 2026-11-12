import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ku.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('ku'),
    Locale('tr')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'LabGo'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Healthcare Laboratory System'**
  String get appTagline;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get welcomeBack;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @enterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterYourEmail;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get orContinueWith;

  /// No description provided for @google.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get google;

  /// No description provided for @apple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get apple;

  /// No description provided for @pleaseEnterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterYourEmail;

  /// No description provided for @pleaseEnterAValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterAValidEmail;

  /// No description provided for @emailOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Email or Phone'**
  String get emailOrPhone;

  /// No description provided for @enterYourEmailOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your email or phone number'**
  String get enterYourEmailOrPhone;

  /// No description provided for @pleaseEnterYourEmailOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email or phone number'**
  String get pleaseEnterYourEmailOrPhone;

  /// No description provided for @pleaseEnterAValidEmailOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address or phone number'**
  String get pleaseEnterAValidEmailOrPhone;

  /// No description provided for @pleaseEnterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterYourPassword;

  /// No description provided for @passwordMustBeAtLeast8Characters.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMustBeAtLeast8Characters;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @forgotPasswordFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Forgot password feature coming soon'**
  String get forgotPasswordFeatureComingSoon;

  /// No description provided for @googleSignInComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in coming soon'**
  String get googleSignInComingSoon;

  /// No description provided for @appleSignInComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in coming soon'**
  String get appleSignInComingSoon;

  /// No description provided for @chatFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'In-app chat coming soon'**
  String get chatFeatureComingSoon;

  /// No description provided for @joinLabGoToday.
  ///
  /// In en, this message translates to:
  /// **'Join LabGo today'**
  String get joinLabGoToday;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @enterYourFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterYourFullName;

  /// No description provided for @pleaseEnterYourName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get pleaseEnterYourName;

  /// No description provided for @nameMustBeAtLeast2Characters.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get nameMustBeAtLeast2Characters;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @enterYourPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterYourPhoneNumber;

  /// No description provided for @enterOtherPersonName.
  ///
  /// In en, this message translates to:
  /// **'Enter the other person\'s full name'**
  String get enterOtherPersonName;

  /// No description provided for @enterOtherPersonPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter the other person\'s phone number'**
  String get enterOtherPersonPhone;

  /// No description provided for @pleaseEnterYourPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get pleaseEnterYourPhoneNumber;

  /// No description provided for @pleaseEnterAValidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get pleaseEnterAValidPhoneNumber;

  /// No description provided for @phoneOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Phone Number or Email'**
  String get phoneOrEmail;

  /// No description provided for @enterPhoneOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number or email'**
  String get enterPhoneOrEmail;

  /// No description provided for @pleaseEnterPhoneOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number or email'**
  String get pleaseEnterPhoneOrEmail;

  /// No description provided for @pleaseEnterAValidPhoneOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number or email'**
  String get pleaseEnterAValidPhoneOrEmail;

  /// No description provided for @adminLabLoginBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Admin and lab accounts must sign in from the website, not this app.'**
  String get adminLabLoginBlockedMessage;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @selectDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Select Date of Birth'**
  String get selectDateOfBirth;

  /// No description provided for @pleaseEnterAPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get pleaseEnterAPassword;

  /// No description provided for @passwordMustContainAtLeastOneUppercaseLetter.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one uppercase letter'**
  String get passwordMustContainAtLeastOneUppercaseLetter;

  /// No description provided for @passwordMustContainAtLeastOneLowercaseLetter.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one lowercase letter'**
  String get passwordMustContainAtLeastOneLowercaseLetter;

  /// No description provided for @passwordMustContainAtLeastOneNumber.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one number'**
  String get passwordMustContainAtLeastOneNumber;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @reEnterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get reEnterYourPassword;

  /// No description provided for @pleaseConfirmYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get pleaseConfirmYourPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @iAgreeToThe.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get iAgreeToThe;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// No description provided for @pleaseAgreeToTheTermsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Terms and Conditions'**
  String get pleaseAgreeToTheTermsAndConditions;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registrationFailed;

  /// No description provided for @alreadyHaveAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAnAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @createAPassword.
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get createAPassword;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @labs.
  ///
  /// In en, this message translates to:
  /// **'Labs'**
  String get labs;

  /// No description provided for @labsNearYou.
  ///
  /// In en, this message translates to:
  /// **'Labs near you'**
  String get labsNearYou;

  /// No description provided for @tests.
  ///
  /// In en, this message translates to:
  /// **'tests'**
  String get tests;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'available'**
  String get available;

  /// No description provided for @requestANurse.
  ///
  /// In en, this message translates to:
  /// **'Request a Nurse'**
  String get requestANurse;

  /// No description provided for @discoverLabs.
  ///
  /// In en, this message translates to:
  /// **'Discover Labs'**
  String get discoverLabs;

  /// No description provided for @findPerfectLab.
  ///
  /// In en, this message translates to:
  /// **'Find the perfect lab for your needs'**
  String get findPerfectLab;

  /// No description provided for @searchByLabName.
  ///
  /// In en, this message translates to:
  /// **'Search by lab name'**
  String get searchByLabName;

  /// No description provided for @cities.
  ///
  /// In en, this message translates to:
  /// **'Cities'**
  String get cities;

  /// No description provided for @baghdad.
  ///
  /// In en, this message translates to:
  /// **'Baghdad'**
  String get baghdad;

  /// No description provided for @basra.
  ///
  /// In en, this message translates to:
  /// **'Basra'**
  String get basra;

  /// No description provided for @erbil.
  ///
  /// In en, this message translates to:
  /// **'Erbil'**
  String get erbil;

  /// No description provided for @mosul.
  ///
  /// In en, this message translates to:
  /// **'Mosul'**
  String get mosul;

  /// No description provided for @najaf.
  ///
  /// In en, this message translates to:
  /// **'Najaf'**
  String get najaf;

  /// No description provided for @homeVisitSampleCollection.
  ///
  /// In en, this message translates to:
  /// **'Get home visit & sample collection'**
  String get homeVisitSampleCollection;

  /// No description provided for @featuredLaboratories.
  ///
  /// In en, this message translates to:
  /// **'Featured Laboratories'**
  String get featuredLaboratories;

  /// No description provided for @laboratoriesFound.
  ///
  /// In en, this message translates to:
  /// **'Laboratories Found'**
  String get laboratoriesFound;

  /// No description provided for @loadingLaboratories.
  ///
  /// In en, this message translates to:
  /// **'Loading Laboratories'**
  String get loadingLaboratories;

  /// No description provided for @noLaboratoriesFound.
  ///
  /// In en, this message translates to:
  /// **'No Laboratories Found'**
  String get noLaboratoriesFound;

  /// No description provided for @checkBackLater.
  ///
  /// In en, this message translates to:
  /// **'Check back later'**
  String get checkBackLater;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get goodEvening;

  /// No description provided for @labTestsAtYourDoorstep.
  ///
  /// In en, this message translates to:
  /// **'Lab Tests at Your Doorstep'**
  String get labTestsAtYourDoorstep;

  /// No description provided for @bookTestGetSampleAtHomeReceiveResultsOnline.
  ///
  /// In en, this message translates to:
  /// **'Book test, get sample at home, receive results online.'**
  String get bookTestGetSampleAtHomeReceiveResultsOnline;

  /// No description provided for @laboratories.
  ///
  /// In en, this message translates to:
  /// **'Laboratories'**
  String get laboratories;

  /// No description provided for @otpSentSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'OTP sent successfully'**
  String get otpSentSuccessfully;

  /// No description provided for @otpVerification.
  ///
  /// In en, this message translates to:
  /// **'OTP Verification'**
  String get otpVerification;

  /// No description provided for @enterThe6DigitCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {phone}'**
  String enterThe6DigitCodeSentTo(Object phone);

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @didntReceiveTheCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code?'**
  String get didntReceiveTheCode;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendIn(Object seconds);

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resend;

  /// No description provided for @remainingAttempts.
  ///
  /// In en, this message translates to:
  /// **'{count} remaining attempts'**
  String remainingAttempts(Object count);

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @bloodTests.
  ///
  /// In en, this message translates to:
  /// **'Blood Tests'**
  String get bloodTests;

  /// No description provided for @xRay.
  ///
  /// In en, this message translates to:
  /// **'X-Ray'**
  String get xRay;

  /// No description provided for @mri.
  ///
  /// In en, this message translates to:
  /// **'MRI'**
  String get mri;

  /// No description provided for @ctScan.
  ///
  /// In en, this message translates to:
  /// **'CT Scan'**
  String get ctScan;

  /// No description provided for @ultrasound.
  ///
  /// In en, this message translates to:
  /// **'Ultrasound'**
  String get ultrasound;

  /// No description provided for @pathology.
  ///
  /// In en, this message translates to:
  /// **'Pathology'**
  String get pathology;

  /// No description provided for @microbiology.
  ///
  /// In en, this message translates to:
  /// **'Microbiology'**
  String get microbiology;

  /// No description provided for @biochemistry.
  ///
  /// In en, this message translates to:
  /// **'Biochemistry'**
  String get biochemistry;

  /// No description provided for @genetics.
  ///
  /// In en, this message translates to:
  /// **'Genetics'**
  String get genetics;

  /// No description provided for @allergy.
  ///
  /// In en, this message translates to:
  /// **'Allergy'**
  String get allergy;

  /// No description provided for @cardiology.
  ///
  /// In en, this message translates to:
  /// **'Cardiology'**
  String get cardiology;

  /// No description provided for @neurology.
  ///
  /// In en, this message translates to:
  /// **'Neurology'**
  String get neurology;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @openNow.
  ///
  /// In en, this message translates to:
  /// **'Open Now'**
  String get openNow;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @specialInstructions.
  ///
  /// In en, this message translates to:
  /// **'Special Instructions'**
  String get specialInstructions;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @noDescriptionProvided.
  ///
  /// In en, this message translates to:
  /// **'No description provided for this test.'**
  String get noDescriptionProvided;

  /// No description provided for @addTest.
  ///
  /// In en, this message translates to:
  /// **'Add Test'**
  String get addTest;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get added;

  /// No description provided for @testAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Test added successfully!'**
  String get testAddedSuccessfully;

  /// No description provided for @testAddedToCart.
  ///
  /// In en, this message translates to:
  /// **'Test added to cart'**
  String get testAddedToCart;

  /// No description provided for @testRemoved.
  ///
  /// In en, this message translates to:
  /// **'Test removed'**
  String get testRemoved;

  /// No description provided for @testRemovedFromCart.
  ///
  /// In en, this message translates to:
  /// **'Test removed from cart'**
  String get testRemovedFromCart;

  /// No description provided for @uploadPrescription.
  ///
  /// In en, this message translates to:
  /// **'Upload Prescription'**
  String get uploadPrescription;

  /// No description provided for @uploadPrescriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload your doctor\'s prescription to get the required tests'**
  String get uploadPrescriptionSubtitle;

  /// No description provided for @selectPrescription.
  ///
  /// In en, this message translates to:
  /// **'Select Prescription'**
  String get selectPrescription;

  /// No description provided for @noFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get noFileSelected;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @cartEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add tests to get started with your booking'**
  String get cartEmptySubtitle;

  /// No description provided for @browseTests.
  ///
  /// In en, this message translates to:
  /// **'Browse Tests'**
  String get browseTests;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @prescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Please upload a prescription image to proceed'**
  String get prescriptionRequired;

  /// No description provided for @proceedToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Checkout'**
  String get proceedToCheckout;

  /// No description provided for @showSelectedTests.
  ///
  /// In en, this message translates to:
  /// **'Show the selected tests'**
  String get showSelectedTests;

  /// No description provided for @prescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional - Upload if available'**
  String get prescriptionOptional;

  /// No description provided for @prescriptionUploaded.
  ///
  /// In en, this message translates to:
  /// **'Prescription uploaded'**
  String get prescriptionUploaded;

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get selectLocation;

  /// No description provided for @loadingMap.
  ///
  /// In en, this message translates to:
  /// **'Loading map...'**
  String get loadingMap;

  /// No description provided for @dragPinToAdjust.
  ///
  /// In en, this message translates to:
  /// **'Move the map to place the pin, then type your address'**
  String get dragPinToAdjust;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @enterAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter your full address'**
  String get enterAddress;

  /// No description provided for @locationNotSetYet.
  ///
  /// In en, this message translates to:
  /// **'Location not set yet'**
  String get locationNotSetYet;

  /// No description provided for @profilePictureUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated'**
  String get profilePictureUpdated;

  /// No description provided for @priceQuoteReceived.
  ///
  /// In en, this message translates to:
  /// **'Price Quote Received'**
  String get priceQuoteReceived;

  /// No description provided for @approveQuote.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approveQuote;

  /// No description provided for @rejectQuote.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectQuote;

  /// No description provided for @rejectQuoteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject this quote? The order will be cancelled.'**
  String get rejectQuoteConfirmation;

  /// No description provided for @quoteApproved.
  ///
  /// In en, this message translates to:
  /// **'Quote approved'**
  String get quoteApproved;

  /// No description provided for @quoteRejected.
  ///
  /// In en, this message translates to:
  /// **'Quote rejected'**
  String get quoteRejected;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// No description provided for @iqd.
  ///
  /// In en, this message translates to:
  /// **'IQD'**
  String get iqd;

  /// No description provided for @failedToUpdateProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile picture'**
  String get failedToUpdateProfilePicture;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location'**
  String get useCurrentLocation;

  /// No description provided for @setOnMap.
  ///
  /// In en, this message translates to:
  /// **'Set on Map'**
  String get setOnMap;

  /// No description provided for @landmark.
  ///
  /// In en, this message translates to:
  /// **'Landmark'**
  String get landmark;

  /// No description provided for @enterLandmark.
  ///
  /// In en, this message translates to:
  /// **'Nearby landmark (optional)'**
  String get enterLandmark;

  /// No description provided for @buildingName.
  ///
  /// In en, this message translates to:
  /// **'Building Name'**
  String get buildingName;

  /// No description provided for @enterBuildingName.
  ///
  /// In en, this message translates to:
  /// **'Building or tower name'**
  String get enterBuildingName;

  /// No description provided for @floorNumber.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get floorNumber;

  /// No description provided for @floor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get floor;

  /// No description provided for @apartmentNumber.
  ///
  /// In en, this message translates to:
  /// **'Apartment'**
  String get apartmentNumber;

  /// No description provided for @apartment.
  ///
  /// In en, this message translates to:
  /// **'Apt/House'**
  String get apartment;

  /// No description provided for @deliveryInstructions.
  ///
  /// In en, this message translates to:
  /// **'Delivery Instructions'**
  String get deliveryInstructions;

  /// No description provided for @enterInstructions.
  ///
  /// In en, this message translates to:
  /// **'e.g., Ring the bell twice, Call upon arrival'**
  String get enterInstructions;

  /// No description provided for @confirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm Location'**
  String get confirmLocation;

  /// No description provided for @pleaseEnterAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter your address'**
  String get pleaseEnterAddress;

  /// No description provided for @orderConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Order Confirmation'**
  String get orderConfirmation;

  /// No description provided for @reviewYourOrder.
  ///
  /// In en, this message translates to:
  /// **'Review your order details before confirming'**
  String get reviewYourOrder;

  /// No description provided for @sampleCollectionLocation.
  ///
  /// In en, this message translates to:
  /// **'Sample Collection Location'**
  String get sampleCollectionLocation;

  /// No description provided for @deliveryLocation.
  ///
  /// In en, this message translates to:
  /// **'Delivery Location'**
  String get deliveryLocation;

  /// No description provided for @medicineRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Prescription sent. We will set the price and notify you for approval.'**
  String get medicineRequestSubmitted;

  /// No description provided for @scheduledTests.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Tests'**
  String get scheduledTests;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// No description provided for @confirmOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm Order'**
  String get confirmOrder;

  /// No description provided for @orderPendingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Order Pending Confirmation'**
  String get orderPendingConfirmation;

  /// No description provided for @orderPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your order has been placed and is waiting for admin approval. You will receive a notification once confirmed.'**
  String get orderPendingMessage;

  /// No description provided for @viewOrders.
  ///
  /// In en, this message translates to:
  /// **'View Orders'**
  String get viewOrders;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @noOrdersFound.
  ///
  /// In en, this message translates to:
  /// **'No orders found'**
  String get noOrdersFound;

  /// No description provided for @noOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t placed any orders yet'**
  String get noOrdersSubtitle;

  /// No description provided for @orderDetails.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get orderDetails;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrCode;

  /// No description provided for @orderStatus.
  ///
  /// In en, this message translates to:
  /// **'Order Status'**
  String get orderStatus;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Accepted waiting for nurse'**
  String get confirmed;

  /// No description provided for @waitingForCourier.
  ///
  /// In en, this message translates to:
  /// **'Accepted, waiting for courier'**
  String get waitingForCourier;

  /// No description provided for @viewPrescriptionImage.
  ///
  /// In en, this message translates to:
  /// **'View Photo'**
  String get viewPrescriptionImage;

  /// No description provided for @prescriptionImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Attached Prescription'**
  String get prescriptionImageTitle;

  /// No description provided for @nurseAssigned.
  ///
  /// In en, this message translates to:
  /// **'Nurse on the way'**
  String get nurseAssigned;

  /// No description provided for @assignedNurse.
  ///
  /// In en, this message translates to:
  /// **'Assigned Nurse'**
  String get assignedNurse;

  /// No description provided for @labLocation.
  ///
  /// In en, this message translates to:
  /// **'Lab Location'**
  String get labLocation;

  /// No description provided for @nurseLocation.
  ///
  /// In en, this message translates to:
  /// **'Nurse Location'**
  String get nurseLocation;

  /// No description provided for @distanceAwayLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distanceAwayLabel;

  /// No description provided for @kilometersUnit.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get kilometersUnit;

  /// No description provided for @minutesUnit.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesUnit;

  /// No description provided for @soon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get soon;

  /// Distance to a lab in kilometers
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String distanceAwayKm(String km);

  /// No description provided for @calculatingDistance.
  ///
  /// In en, this message translates to:
  /// **'Calculating distance...'**
  String get calculatingDistance;

  /// No description provided for @enableLocationForDistance.
  ///
  /// In en, this message translates to:
  /// **'Enable location to see distance'**
  String get enableLocationForDistance;

  /// No description provided for @sampleCollected.
  ///
  /// In en, this message translates to:
  /// **'Sample Collected'**
  String get sampleCollected;

  /// No description provided for @atLab.
  ///
  /// In en, this message translates to:
  /// **'Sample at Lab'**
  String get atLab;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @testResults.
  ///
  /// In en, this message translates to:
  /// **'Test Results'**
  String get testResults;

  /// No description provided for @newRequest.
  ///
  /// In en, this message translates to:
  /// **'New Request'**
  String get newRequest;

  /// No description provided for @myResults.
  ///
  /// In en, this message translates to:
  /// **'My Results'**
  String get myResults;

  /// No description provided for @downloadResult.
  ///
  /// In en, this message translates to:
  /// **'Download Result'**
  String get downloadResult;

  /// No description provided for @viewResult.
  ///
  /// In en, this message translates to:
  /// **'View Result'**
  String get viewResult;

  /// No description provided for @resultReady.
  ///
  /// In en, this message translates to:
  /// **'Your test results are ready'**
  String get resultReady;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrder;

  /// No description provided for @cancelOrderReason.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this order?'**
  String get cancelOrderReason;

  /// No description provided for @cancelOrderReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Please tell us why you want to cancel. This helps us improve our service.'**
  String get cancelOrderReasonHint;

  /// No description provided for @cancelReasonPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Changed my mind, found a better price…'**
  String get cancelReasonPlaceholder;

  /// No description provided for @cancelReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a reason (at least 5 characters)'**
  String get cancelReasonRequired;

  /// No description provided for @confirmCancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Yes, Cancel Order'**
  String get confirmCancelOrder;

  /// No description provided for @tapToReviewAndApprovePrice.
  ///
  /// In en, this message translates to:
  /// **'Tap to review and approve the price'**
  String get tapToReviewAndApprovePrice;

  /// No description provided for @orderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled successfully'**
  String get orderCancelled;

  /// No description provided for @orderCreated.
  ///
  /// In en, this message translates to:
  /// **'Order created successfully'**
  String get orderCreated;

  /// No description provided for @sampleCollection.
  ///
  /// In en, this message translates to:
  /// **'Sample Collection'**
  String get sampleCollection;

  /// No description provided for @nurseWillArriveSoon.
  ///
  /// In en, this message translates to:
  /// **'Nurse will arrive soon at your location'**
  String get nurseWillArriveSoon;

  /// No description provided for @rateYourExperience.
  ///
  /// In en, this message translates to:
  /// **'Rate your experience'**
  String get rateYourExperience;

  /// No description provided for @submitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get submitRating;

  /// No description provided for @labRating.
  ///
  /// In en, this message translates to:
  /// **'Lab Rating'**
  String get labRating;

  /// No description provided for @nurseRating.
  ///
  /// In en, this message translates to:
  /// **'Nurse Rating'**
  String get nurseRating;

  /// No description provided for @serviceRating.
  ///
  /// In en, this message translates to:
  /// **'Service Rating'**
  String get serviceRating;

  /// No description provided for @writeFeedback.
  ///
  /// In en, this message translates to:
  /// **'Write your feedback (optional)'**
  String get writeFeedback;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String daysAgo(Object count);

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'test'**
  String get test;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String more(Object count);

  /// No description provided for @scheduleVisit.
  ///
  /// In en, this message translates to:
  /// **'Schedule Visit (Optional)'**
  String get scheduleVisit;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get selectTime;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @selectTimeSlot.
  ///
  /// In en, this message translates to:
  /// **'Select Time Slot'**
  String get selectTimeSlot;

  /// No description provided for @clearDateTime.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearDateTime;

  /// No description provided for @scheduledVisit.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Visit'**
  String get scheduledVisit;

  /// No description provided for @scheduledAt.
  ///
  /// In en, this message translates to:
  /// **'Scheduled at'**
  String get scheduledAt;

  /// No description provided for @orderByPrescription.
  ///
  /// In en, this message translates to:
  /// **'Order by Prescription'**
  String get orderByPrescription;

  /// No description provided for @prescriptionOnlyOrder.
  ///
  /// In en, this message translates to:
  /// **'Prescription-only order'**
  String get prescriptionOnlyOrder;

  /// No description provided for @prescriptionRequiredForOrder.
  ///
  /// In en, this message translates to:
  /// **'Prescription image is required'**
  String get prescriptionRequiredForOrder;

  /// No description provided for @adminWillReviewPrescription.
  ///
  /// In en, this message translates to:
  /// **'Admin will review your prescription and determine the price'**
  String get adminWillReviewPrescription;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @rewardsAndVouchers.
  ///
  /// In en, this message translates to:
  /// **'Rewards & Vouchers'**
  String get rewardsAndVouchers;

  /// No description provided for @governorate.
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get governorate;

  /// No description provided for @memberSincePrefix.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get memberSincePrefix;

  /// No description provided for @accountInfo.
  ///
  /// In en, this message translates to:
  /// **'Account Info'**
  String get accountInfo;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @privacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacySecurity;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @logoutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirmation;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @accountActions.
  ///
  /// In en, this message translates to:
  /// **'Account Actions'**
  String get accountActions;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @applyForNurse.
  ///
  /// In en, this message translates to:
  /// **'Apply for Nurse Position'**
  String get applyForNurse;

  /// No description provided for @joinHealthcareTeam.
  ///
  /// In en, this message translates to:
  /// **'Join our healthcare team'**
  String get joinHealthcareTeam;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @pleaseUploadNationalCard.
  ///
  /// In en, this message translates to:
  /// **'Please upload your national ID card'**
  String get pleaseUploadNationalCard;

  /// No description provided for @pleaseUploadCertificate.
  ///
  /// In en, this message translates to:
  /// **'Please upload your nursing certificate'**
  String get pleaseUploadCertificate;

  /// No description provided for @pleaseSelectMapLocation.
  ///
  /// In en, this message translates to:
  /// **'Please select your location on the map'**
  String get pleaseSelectMapLocation;

  /// No description provided for @failedToSubmit.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit application'**
  String get failedToSubmit;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @nationalCard.
  ///
  /// In en, this message translates to:
  /// **'National ID Card (البطاقة الموحدة)'**
  String get nationalCard;

  /// No description provided for @nationalCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload a clear photo of your national ID'**
  String get nationalCardSubtitle;

  /// No description provided for @nationalCardFront.
  ///
  /// In en, this message translates to:
  /// **'National ID Card - Front'**
  String get nationalCardFront;

  /// No description provided for @nationalCardFrontSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload the front side of your national ID'**
  String get nationalCardFrontSubtitle;

  /// No description provided for @nationalCardBack.
  ///
  /// In en, this message translates to:
  /// **'National ID Card - Back'**
  String get nationalCardBack;

  /// No description provided for @nationalCardBackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload the back side of your national ID'**
  String get nationalCardBackSubtitle;

  /// No description provided for @nursingCertificate.
  ///
  /// In en, this message translates to:
  /// **'Nursing Certificate'**
  String get nursingCertificate;

  /// No description provided for @nursingCertificateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload your nursing certificate or diploma'**
  String get nursingCertificateSubtitle;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @zone.
  ///
  /// In en, this message translates to:
  /// **'Zone'**
  String get zone;

  /// No description provided for @enterCity.
  ///
  /// In en, this message translates to:
  /// **'Enter your city'**
  String get enterCity;

  /// No description provided for @enterZone.
  ///
  /// In en, this message translates to:
  /// **'Enter your zone'**
  String get enterZone;

  /// No description provided for @questionnaire.
  ///
  /// In en, this message translates to:
  /// **'Questionnaire'**
  String get questionnaire;

  /// No description provided for @ownsCarQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you own a car?'**
  String get ownsCarQuestion;

  /// No description provided for @isEmployedQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you currently employed?'**
  String get isEmployedQuestion;

  /// No description provided for @additionalInfo.
  ///
  /// In en, this message translates to:
  /// **'Additional Information'**
  String get additionalInfo;

  /// No description provided for @tellUsAboutYourself.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself, your experience, and why you want to join our team...'**
  String get tellUsAboutYourself;

  /// No description provided for @submitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get submitApplication;

  /// No description provided for @applicationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application Submitted'**
  String get applicationSubmitted;

  /// No description provided for @applicationUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Your application is under review. We will contact you soon.'**
  String get applicationUnderReview;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get submitted;

  /// No description provided for @applicationPending.
  ///
  /// In en, this message translates to:
  /// **'Your application is being reviewed by our team.'**
  String get applicationPending;

  /// No description provided for @applicationUnderReviewDesc.
  ///
  /// In en, this message translates to:
  /// **'We are currently reviewing your qualifications.'**
  String get applicationUnderReviewDesc;

  /// No description provided for @applicationApproved.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! Your application has been approved.'**
  String get applicationApproved;

  /// No description provided for @applicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Unfortunately, your application was not approved.'**
  String get applicationRejected;

  /// No description provided for @applicationOnHold.
  ///
  /// In en, this message translates to:
  /// **'Your application is currently on hold.'**
  String get applicationOnHold;

  /// No description provided for @rejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection Reason'**
  String get rejectionReason;

  /// No description provided for @reapply.
  ///
  /// In en, this message translates to:
  /// **'Reapply'**
  String get reapply;

  /// No description provided for @reapplyForNurse.
  ///
  /// In en, this message translates to:
  /// **'Submit a New Application'**
  String get reapplyForNurse;

  /// No description provided for @nursePortal.
  ///
  /// In en, this message translates to:
  /// **'Nurse Portal'**
  String get nursePortal;

  /// No description provided for @switchToNurseView.
  ///
  /// In en, this message translates to:
  /// **'Switch to Nurse View'**
  String get switchToNurseView;

  /// No description provided for @switchToNurseViewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Access nurse portal and manage orders'**
  String get switchToNurseViewSubtitle;

  /// No description provided for @switchToPatientView.
  ///
  /// In en, this message translates to:
  /// **'Switch to Patient View'**
  String get switchToPatientView;

  /// No description provided for @switchToPatientViewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Access patient portal and book tests'**
  String get switchToPatientViewSubtitle;

  /// No description provided for @availableOrders.
  ///
  /// In en, this message translates to:
  /// **'Available Orders'**
  String get availableOrders;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @noAvailableOrders.
  ///
  /// In en, this message translates to:
  /// **'No Available Orders'**
  String get noAvailableOrders;

  /// No description provided for @noAvailableOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'There are no orders available for assignment'**
  String get noAvailableOrdersSubtitle;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @underReview.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get underReview;

  /// No description provided for @acceptOrder.
  ///
  /// In en, this message translates to:
  /// **'Accept Order'**
  String get acceptOrder;

  /// No description provided for @confirmAcceptOrder.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to accept this order?'**
  String get confirmAcceptOrder;

  /// No description provided for @orderAccepted.
  ///
  /// In en, this message translates to:
  /// **'Order accepted successfully'**
  String get orderAccepted;

  /// No description provided for @invalidQRCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR code'**
  String get invalidQRCode;

  /// No description provided for @qrCodeForLab.
  ///
  /// In en, this message translates to:
  /// **'QR Code for Lab'**
  String get qrCodeForLab;

  /// No description provided for @labWillScan.
  ///
  /// In en, this message translates to:
  /// **'Lab will scan this code when sample arrives'**
  String get labWillScan;

  /// No description provided for @patientInfo.
  ///
  /// In en, this message translates to:
  /// **'Patient Information'**
  String get patientInfo;

  /// No description provided for @labInfo.
  ///
  /// In en, this message translates to:
  /// **'Lab Information'**
  String get labInfo;

  /// No description provided for @collectionLocation.
  ///
  /// In en, this message translates to:
  /// **'Collection Location'**
  String get collectionLocation;

  /// No description provided for @shareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share Location'**
  String get shareLocation;

  /// No description provided for @scanPatientQR.
  ///
  /// In en, this message translates to:
  /// **'Scan Patient QR'**
  String get scanPatientQR;

  /// No description provided for @enterQRManually.
  ///
  /// In en, this message translates to:
  /// **'Enter QR Manually'**
  String get enterQRManually;

  /// No description provided for @scanQRCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQRCode;

  /// No description provided for @invalidQRCodeFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR code format'**
  String get invalidQRCodeFormat;

  /// No description provided for @qrCodeTooShort.
  ///
  /// In en, this message translates to:
  /// **'QR code is too short'**
  String get qrCodeTooShort;

  /// No description provided for @qrCodeTooLong.
  ///
  /// In en, this message translates to:
  /// **'QR code is too long'**
  String get qrCodeTooLong;

  /// No description provided for @enterQRCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter QR Code'**
  String get enterQRCodeTitle;

  /// No description provided for @enterQRCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the QR code manually'**
  String get enterQRCodeSubtitle;

  /// No description provided for @enterQRCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter QR code'**
  String get enterQRCodeHint;

  /// No description provided for @finance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get finance;

  /// No description provided for @financeOverview.
  ///
  /// In en, this message translates to:
  /// **'Financial Overview'**
  String get financeOverview;

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current Balance'**
  String get currentBalance;

  /// No description provided for @totalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Total Earnings'**
  String get totalEarnings;

  /// No description provided for @paidToAdmin.
  ///
  /// In en, this message translates to:
  /// **'Paid to Admin'**
  String get paidToAdmin;

  /// No description provided for @pendingLabPayments.
  ///
  /// In en, this message translates to:
  /// **'Pending Lab Payments'**
  String get pendingLabPayments;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @todayEarnings.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Earnings'**
  String get todayEarnings;

  /// No description provided for @commissionRate.
  ///
  /// In en, this message translates to:
  /// **'Commission Rate'**
  String get commissionRate;

  /// No description provided for @commissionEarned.
  ///
  /// In en, this message translates to:
  /// **'Commission Earned'**
  String get commissionEarned;

  /// No description provided for @labAmount.
  ///
  /// In en, this message translates to:
  /// **'Lab Amount'**
  String get labAmount;

  /// No description provided for @totalCollected.
  ///
  /// In en, this message translates to:
  /// **'Total Collected'**
  String get totalCollected;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactions;

  /// No description provided for @noTransactionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your transaction history will appear here'**
  String get noTransactionsSubtitle;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @settlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get settlement;

  /// No description provided for @settleBalance.
  ///
  /// In en, this message translates to:
  /// **'Settle Balance'**
  String get settleBalance;

  /// No description provided for @pendingSettlements.
  ///
  /// In en, this message translates to:
  /// **'Pending Settlements'**
  String get pendingSettlements;

  /// No description provided for @noPendingSettlements.
  ///
  /// In en, this message translates to:
  /// **'No pending lab payments'**
  String get noPendingSettlements;

  /// No description provided for @noPendingSettlementsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up!'**
  String get noPendingSettlementsSubtitle;

  /// No description provided for @lastSettlement.
  ///
  /// In en, this message translates to:
  /// **'Last settlement'**
  String get lastSettlement;

  /// No description provided for @payLab.
  ///
  /// In en, this message translates to:
  /// **'Pay Lab'**
  String get payLab;

  /// No description provided for @markAsPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as Paid'**
  String get markAsPaid;

  /// No description provided for @labPaymentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm you paid the lab'**
  String get labPaymentConfirm;

  /// No description provided for @labPaymentConfirmMsg.
  ///
  /// In en, this message translates to:
  /// **'Have you paid the lab for this order?'**
  String get labPaymentConfirmMsg;

  /// No description provided for @paymentBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Payment Breakdown'**
  String get paymentBreakdown;

  /// No description provided for @paymentCollected.
  ///
  /// In en, this message translates to:
  /// **'Payment Collected'**
  String get paymentCollected;

  /// No description provided for @payToLab.
  ///
  /// In en, this message translates to:
  /// **'Pay to Lab'**
  String get payToLab;

  /// No description provided for @yourCommission.
  ///
  /// In en, this message translates to:
  /// **'Your Commission'**
  String get yourCommission;

  /// No description provided for @labCommission.
  ///
  /// In en, this message translates to:
  /// **'Lab Commission'**
  String get labCommission;

  /// No description provided for @settled.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get settled;

  /// No description provided for @rememberPayLab.
  ///
  /// In en, this message translates to:
  /// **'Remember to pay the lab when you deliver the sample'**
  String get rememberPayLab;

  /// No description provided for @labReceives.
  ///
  /// In en, this message translates to:
  /// **'Lab Receives'**
  String get labReceives;

  /// No description provided for @commissionType.
  ///
  /// In en, this message translates to:
  /// **'Commission'**
  String get commissionType;

  /// No description provided for @labSettlementType.
  ///
  /// In en, this message translates to:
  /// **'Lab Payment'**
  String get labSettlementType;

  /// No description provided for @adminSettlementType.
  ///
  /// In en, this message translates to:
  /// **'Admin Settlement'**
  String get adminSettlementType;

  /// No description provided for @balanceAdjustmentType.
  ///
  /// In en, this message translates to:
  /// **'Balance Adjustment'**
  String get balanceAdjustmentType;

  /// No description provided for @refreshFinance.
  ///
  /// In en, this message translates to:
  /// **'Refresh Finance Data'**
  String get refreshFinance;

  /// No description provided for @adminShare.
  ///
  /// In en, this message translates to:
  /// **'Admin Share'**
  String get adminShare;

  /// No description provided for @totalPendingToAdmin.
  ///
  /// In en, this message translates to:
  /// **'Total Pending to Admin'**
  String get totalPendingToAdmin;

  /// No description provided for @ordersText.
  ///
  /// In en, this message translates to:
  /// **'orders'**
  String get ordersText;

  /// No description provided for @orderText.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get orderText;

  /// No description provided for @orderTotal.
  ///
  /// In en, this message translates to:
  /// **'Order Total'**
  String get orderTotal;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Bal'**
  String get balance;

  /// No description provided for @failedToLoadFinanceOverview.
  ///
  /// In en, this message translates to:
  /// **'Failed to load finance overview'**
  String get failedToLoadFinanceOverview;

  /// No description provided for @failedToLoadOrderDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load order details'**
  String get failedToLoadOrderDetails;

  /// No description provided for @selectMonth.
  ///
  /// In en, this message translates to:
  /// **'Select Month'**
  String get selectMonth;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @january.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get january;

  /// No description provided for @february.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get february;

  /// No description provided for @march.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get march;

  /// No description provided for @april.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get april;

  /// No description provided for @may.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// No description provided for @june.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get june;

  /// No description provided for @july.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get july;

  /// No description provided for @august.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get august;

  /// No description provided for @september.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get september;

  /// No description provided for @october.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get october;

  /// No description provided for @november.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get november;

  /// No description provided for @december.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get december;

  /// No description provided for @noDataForMonth.
  ///
  /// In en, this message translates to:
  /// **'No data for this month'**
  String get noDataForMonth;

  /// No description provided for @monthlyEarnings.
  ///
  /// In en, this message translates to:
  /// **'Monthly Earnings'**
  String get monthlyEarnings;

  /// No description provided for @completedOrders.
  ///
  /// In en, this message translates to:
  /// **'Completed Orders'**
  String get completedOrders;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchForTestsOrLabs.
  ///
  /// In en, this message translates to:
  /// **'Search for a test or package'**
  String get searchForTestsOrLabs;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No Orders Yet'**
  String get noOrdersYet;

  /// No description provided for @startByOrderingLabTests.
  ///
  /// In en, this message translates to:
  /// **'Start by ordering lab tests from a laboratory'**
  String get startByOrderingLabTests;

  /// No description provided for @specialization.
  ///
  /// In en, this message translates to:
  /// **'Specialization'**
  String get specialization;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get applyFilters;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @loadingLabs.
  ///
  /// In en, this message translates to:
  /// **'Loading labs...'**
  String get loadingLabs;

  /// No description provided for @quickServicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Services'**
  String get quickServicesTitle;

  /// No description provided for @quickServicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Selected tests to start taking a small step towards better wellness.'**
  String get quickServicesSubtitle;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookNow;

  /// No description provided for @havePrescriptionQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you have a prescription?'**
  String get havePrescriptionQuestion;

  /// No description provided for @havePrescriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload it and our team will prepare your order.'**
  String get havePrescriptionSubtitle;

  /// No description provided for @noQuickServicesFound.
  ///
  /// In en, this message translates to:
  /// **'No quick services found'**
  String get noQuickServicesFound;

  /// No description provided for @searchingLabs.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searchingLabs;

  /// No description provided for @noLabsFound.
  ///
  /// In en, this message translates to:
  /// **'No labs found'**
  String get noLabsFound;

  /// No description provided for @tryAdjustingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters or search terms'**
  String get tryAdjustingFilters;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset Filters'**
  String get resetFilters;

  /// No description provided for @selectALab.
  ///
  /// In en, this message translates to:
  /// **'Select a Lab'**
  String get selectALab;

  /// No description provided for @selectLabForNurseRequest.
  ///
  /// In en, this message translates to:
  /// **'Choose a lab for your nurse request'**
  String get selectLabForNurseRequest;

  /// No description provided for @nearMe.
  ///
  /// In en, this message translates to:
  /// **'Near Me'**
  String get nearMe;

  /// No description provided for @topRated.
  ///
  /// In en, this message translates to:
  /// **'Top Rated'**
  String get topRated;

  /// No description provided for @noLabsInArea.
  ///
  /// In en, this message translates to:
  /// **'No labs found in your area'**
  String get noLabsInArea;

  /// No description provided for @loadingOrders.
  ///
  /// In en, this message translates to:
  /// **'Loading orders...'**
  String get loadingOrders;

  /// No description provided for @orderForOtherPerson.
  ///
  /// In en, this message translates to:
  /// **'Order for another person'**
  String get orderForOtherPerson;

  /// No description provided for @orderForOtherPersonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Place this order on behalf of someone else'**
  String get orderForOtherPersonSubtitle;

  /// No description provided for @beneficiaryInfo.
  ///
  /// In en, this message translates to:
  /// **'Beneficiary Information'**
  String get beneficiaryInfo;

  /// No description provided for @beneficiaryName.
  ///
  /// In en, this message translates to:
  /// **'Beneficiary Name'**
  String get beneficiaryName;

  /// No description provided for @beneficiaryPhone.
  ///
  /// In en, this message translates to:
  /// **'Beneficiary Phone'**
  String get beneficiaryPhone;

  /// No description provided for @relationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get relationship;

  /// No description provided for @spouse.
  ///
  /// In en, this message translates to:
  /// **'Spouse'**
  String get spouse;

  /// No description provided for @child.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get child;

  /// No description provided for @parent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get parent;

  /// No description provided for @sibling.
  ///
  /// In en, this message translates to:
  /// **'Sibling'**
  String get sibling;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @pleaseEnterBeneficiaryName.
  ///
  /// In en, this message translates to:
  /// **'Please enter beneficiary name'**
  String get pleaseEnterBeneficiaryName;

  /// No description provided for @pleaseEnterBeneficiaryPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter beneficiary phone'**
  String get pleaseEnterBeneficiaryPhone;

  /// No description provided for @nurseCancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get nurseCancelOrder;

  /// No description provided for @nurseCancelOrderReason.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this order?'**
  String get nurseCancelOrderReason;

  /// No description provided for @nurseCancelOrderSuccess.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled successfully'**
  String get nurseCancelOrderSuccess;

  /// No description provided for @orderReturnedToAvailable.
  ///
  /// In en, this message translates to:
  /// **'Order is now available for other nurses'**
  String get orderReturnedToAvailable;

  /// No description provided for @thankYouForRating.
  ///
  /// In en, this message translates to:
  /// **'Thank you for rating!'**
  String get thankYouForRating;

  /// No description provided for @yourFeedbackHelps.
  ///
  /// In en, this message translates to:
  /// **'Your feedback helps us improve'**
  String get yourFeedbackHelps;

  /// No description provided for @helpUsImprove.
  ///
  /// In en, this message translates to:
  /// **'Help us improve our services'**
  String get helpUsImprove;

  /// No description provided for @rateNow.
  ///
  /// In en, this message translates to:
  /// **'Rate Now'**
  String get rateNow;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @selectBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Select birth date'**
  String get selectBirthDate;

  /// No description provided for @selectRelationship.
  ///
  /// In en, this message translates to:
  /// **'Select relationship'**
  String get selectRelationship;

  /// No description provided for @nurseRequestInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get nurseRequestInfoTitle;

  /// No description provided for @nurseRequestInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload your prescription and select your location. Our admin will review your request, assign a suitable lab near you, and determine the required tests and pricing.'**
  String get nurseRequestInfoDescription;

  /// No description provided for @nurseRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Request Submitted!'**
  String get nurseRequestSubmitted;

  /// No description provided for @nurseRequestSubmittedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your nurse request has been submitted successfully. Our team will review your prescription and assign a lab. You\'ll be notified once your request is confirmed.'**
  String get nurseRequestSubmittedDescription;

  /// No description provided for @submitRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get submitRequest;

  /// No description provided for @orderCreationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create order. Please try again.'**
  String get orderCreationFailed;

  /// No description provided for @offers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offers;

  /// No description provided for @packages.
  ///
  /// In en, this message translates to:
  /// **'Packages'**
  String get packages;

  /// No description provided for @specialOffers.
  ///
  /// In en, this message translates to:
  /// **'Special discounts on tests'**
  String get specialOffers;

  /// No description provided for @limitedTimeOffer.
  ///
  /// In en, this message translates to:
  /// **'Limited time'**
  String get limitedTimeOffer;

  /// No description provided for @exploreNow.
  ///
  /// In en, this message translates to:
  /// **'Explore now'**
  String get exploreNow;

  /// No description provided for @bannerWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Book your tests easily'**
  String get bannerWelcomeTitle;

  /// No description provided for @bannerWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trusted labs near you'**
  String get bannerWelcomeSubtitle;

  /// No description provided for @offersDescription.
  ///
  /// In en, this message translates to:
  /// **'Discover labs with special offers and discounts'**
  String get offersDescription;

  /// No description provided for @noOffersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Offers Available'**
  String get noOffersAvailable;

  /// No description provided for @noOffersDescription.
  ///
  /// In en, this message translates to:
  /// **'Check back later for special deals and discounts'**
  String get noOffersDescription;

  /// No description provided for @starredOffers.
  ///
  /// In en, this message translates to:
  /// **'Featured Offers'**
  String get starredOffers;

  /// No description provided for @allOffers.
  ///
  /// In en, this message translates to:
  /// **'All Offers'**
  String get allOffers;

  /// No description provided for @upTo.
  ///
  /// In en, this message translates to:
  /// **'Up to'**
  String get upTo;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get off;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @onAllTests.
  ///
  /// In en, this message translates to:
  /// **'on all tests'**
  String get onAllTests;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get on;

  /// No description provided for @endsOn.
  ///
  /// In en, this message translates to:
  /// **'Ends on'**
  String get endsOn;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show Less'**
  String get showLess;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @errorLoadingData.
  ///
  /// In en, this message translates to:
  /// **'Error loading data'**
  String get errorLoadingData;

  /// No description provided for @labOffers.
  ///
  /// In en, this message translates to:
  /// **'Lab Offers'**
  String get labOffers;

  /// No description provided for @discountedTests.
  ///
  /// In en, this message translates to:
  /// **'Discounted Tests'**
  String get discountedTests;

  /// No description provided for @copyQRCode.
  ///
  /// In en, this message translates to:
  /// **'Copy QR Code'**
  String get copyQRCode;

  /// No description provided for @qrCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'QR Code copied!'**
  String get qrCodeCopied;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @navigateWithMaps.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigateWithMaps;

  /// No description provided for @shareWithOthers.
  ///
  /// In en, this message translates to:
  /// **'Share with others'**
  String get shareWithOthers;

  /// No description provided for @mapsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Maps app not available'**
  String get mapsNotAvailable;

  /// No description provided for @failedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get failedToLoadImage;

  /// No description provided for @downloadViewPdf.
  ///
  /// In en, this message translates to:
  /// **'Download / View PDF'**
  String get downloadViewPdf;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Please try again.'**
  String get connectionError;

  /// No description provided for @errorSelectingImage.
  ///
  /// In en, this message translates to:
  /// **'Error selecting image'**
  String get errorSelectingImage;

  /// No description provided for @anErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get anErrorOccurred;

  /// No description provided for @failedToCancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel order'**
  String get failedToCancelOrder;

  /// No description provided for @failedToCreateOrder.
  ///
  /// In en, this message translates to:
  /// **'Failed to create order'**
  String get failedToCreateOrder;

  /// No description provided for @failedToLoadOffers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load offers'**
  String get failedToLoadOffers;

  /// No description provided for @failedToSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP'**
  String get failedToSendOtp;

  /// No description provided for @verificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed'**
  String get verificationFailed;

  /// No description provided for @failedToResendOtp.
  ///
  /// In en, this message translates to:
  /// **'Failed to resend OTP'**
  String get failedToResendOtp;

  /// No description provided for @pleaseEnableCamera.
  ///
  /// In en, this message translates to:
  /// **'Please enable camera access in your device settings to scan QR codes'**
  String get pleaseEnableCamera;

  /// No description provided for @failedToAddTestToCart.
  ///
  /// In en, this message translates to:
  /// **'Failed to add test to cart'**
  String get failedToAddTestToCart;

  /// No description provided for @failedToRemoveTestFromCart.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove test from cart'**
  String get failedToRemoveTestFromCart;

  /// No description provided for @failedToGetCart.
  ///
  /// In en, this message translates to:
  /// **'Failed to get cart'**
  String get failedToGetCart;

  /// No description provided for @failedToClearCart.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear cart'**
  String get failedToClearCart;

  /// No description provided for @failedToAddPrescription.
  ///
  /// In en, this message translates to:
  /// **'Failed to add prescription'**
  String get failedToAddPrescription;

  /// No description provided for @failedToRemovePrescription.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove prescription'**
  String get failedToRemovePrescription;

  /// No description provided for @failedToLoadLabs.
  ///
  /// In en, this message translates to:
  /// **'Failed to load labs'**
  String get failedToLoadLabs;

  /// No description provided for @failedToLoadLabDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load lab details'**
  String get failedToLoadLabDetails;

  /// No description provided for @failedToLoadLabsWithOffers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load labs with offers'**
  String get failedToLoadLabsWithOffers;

  /// No description provided for @failedToLoadLabOffers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load lab offers'**
  String get failedToLoadLabOffers;

  /// No description provided for @failedToGetAvailableOrders.
  ///
  /// In en, this message translates to:
  /// **'Failed to get available orders'**
  String get failedToGetAvailableOrders;

  /// No description provided for @failedToGetOrders.
  ///
  /// In en, this message translates to:
  /// **'Failed to get orders'**
  String get failedToGetOrders;

  /// No description provided for @failedToGetOrderDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to get order details'**
  String get failedToGetOrderDetails;

  /// No description provided for @orderAcceptedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Order accepted successfully'**
  String get orderAcceptedSuccessfully;

  /// No description provided for @failedToAcceptOrder.
  ///
  /// In en, this message translates to:
  /// **'Failed to accept order'**
  String get failedToAcceptOrder;

  /// No description provided for @orderStatusUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Order status updated successfully'**
  String get orderStatusUpdatedSuccessfully;

  /// No description provided for @failedToUpdateOrderStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed to update order status'**
  String get failedToUpdateOrderStatus;

  /// No description provided for @notesAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Notes added successfully'**
  String get notesAddedSuccessfully;

  /// No description provided for @failedToAddNotes.
  ///
  /// In en, this message translates to:
  /// **'Failed to add notes'**
  String get failedToAddNotes;

  /// No description provided for @sampleCollectedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Sample collected successfully'**
  String get sampleCollectedSuccessfully;

  /// No description provided for @failedToVerifyQRCode.
  ///
  /// In en, this message translates to:
  /// **'Failed to verify QR code'**
  String get failedToVerifyQRCode;

  /// No description provided for @orderCancelledSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled successfully'**
  String get orderCancelledSuccessfully;

  /// No description provided for @nurseRequestCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Nurse request created successfully'**
  String get nurseRequestCreatedSuccessfully;

  /// No description provided for @failedToCreateNurseRequest.
  ///
  /// In en, this message translates to:
  /// **'Failed to create nurse request'**
  String get failedToCreateNurseRequest;

  /// No description provided for @orderCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Order created successfully'**
  String get orderCreatedSuccessfully;

  /// No description provided for @failedToGetOrdersList.
  ///
  /// In en, this message translates to:
  /// **'Failed to get orders list'**
  String get failedToGetOrdersList;

  /// No description provided for @failedToCancelOrderByPatient.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel order'**
  String get failedToCancelOrderByPatient;

  /// No description provided for @failedToGetOrderById.
  ///
  /// In en, this message translates to:
  /// **'Failed to get order by ID'**
  String get failedToGetOrderById;

  /// No description provided for @failedToGetProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to get profile'**
  String get failedToGetProfile;

  /// No description provided for @failedToUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get failedToUpdateProfile;

  /// No description provided for @failedToUploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload document'**
  String get failedToUploadDocument;

  /// No description provided for @failedToDeleteDocument.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete document'**
  String get failedToDeleteDocument;

  /// No description provided for @failedToSubmitNurseApplication.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit nurse application'**
  String get failedToSubmitNurseApplication;

  /// No description provided for @failedToGetNurseApplicationStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed to get nurse application status'**
  String get failedToGetNurseApplicationStatus;

  /// No description provided for @failedToGetFinanceOverview.
  ///
  /// In en, this message translates to:
  /// **'Failed to get finance overview'**
  String get failedToGetFinanceOverview;

  /// No description provided for @failedToGetTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Failed to get transaction history'**
  String get failedToGetTransactionHistory;

  /// No description provided for @failedToSettleBalance.
  ///
  /// In en, this message translates to:
  /// **'Failed to settle balance'**
  String get failedToSettleBalance;

  /// No description provided for @paymentMarkedAsPaid.
  ///
  /// In en, this message translates to:
  /// **'Payment marked as paid'**
  String get paymentMarkedAsPaid;

  /// No description provided for @failedToMarkAsPaid.
  ///
  /// In en, this message translates to:
  /// **'Failed to mark as paid'**
  String get failedToMarkAsPaid;

  /// No description provided for @failedToSearchOrders.
  ///
  /// In en, this message translates to:
  /// **'Failed to search orders'**
  String get failedToSearchOrders;

  /// No description provided for @noTestsFound.
  ///
  /// In en, this message translates to:
  /// **'No tests found'**
  String get noTestsFound;

  /// No description provided for @searchTests.
  ///
  /// In en, this message translates to:
  /// **'Search tests...'**
  String get searchTests;

  /// No description provided for @prescription.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get prescription;

  /// No description provided for @removePrescription.
  ///
  /// In en, this message translates to:
  /// **'Remove Prescription'**
  String get removePrescription;

  /// No description provided for @prescriptionRemoved.
  ///
  /// In en, this message translates to:
  /// **'Prescription removed'**
  String get prescriptionRemoved;

  /// No description provided for @prescriptionAdded.
  ///
  /// In en, this message translates to:
  /// **'Prescription added'**
  String get prescriptionAdded;

  /// No description provided for @selectPrescriptionImage.
  ///
  /// In en, this message translates to:
  /// **'Select prescription image'**
  String get selectPrescriptionImage;

  /// No description provided for @noPrescriptionSelected.
  ///
  /// In en, this message translates to:
  /// **'No prescription selected'**
  String get noPrescriptionSelected;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @enterPhoneNumberToSendCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number to send the verification code'**
  String get enterPhoneNumberToSendCode;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendCode;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @rememberPassword.
  ///
  /// In en, this message translates to:
  /// **'Remember password?'**
  String get rememberPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @enterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your new password'**
  String get enterNewPassword;

  /// No description provided for @enterNewPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password for your account'**
  String get enterNewPasswordDescription;

  /// No description provided for @enterNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password'**
  String get enterNewPasswordHint;

  /// No description provided for @confirmNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter the new password'**
  String get confirmNewPasswordHint;

  /// No description provided for @passwordResetSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Password Reset Successful'**
  String get passwordResetSuccessful;

  /// No description provided for @passwordResetSuccessfulMessage.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated successfully. You can now login with your new password.'**
  String get passwordResetSuccessfulMessage;

  /// No description provided for @passwordResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Password Reset Failed'**
  String get passwordResetFailed;

  /// No description provided for @pleaseEnterAValidOtp.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid OTP'**
  String get pleaseEnterAValidOtp;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdated;

  /// No description provided for @phoneChangeRequiresOtp.
  ///
  /// In en, this message translates to:
  /// **'Phone change requires OTP verification'**
  String get phoneChangeRequiresOtp;

  /// No description provided for @deleteAccountConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account?'**
  String get deleteAccountConfirmation;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All your data will be permanently deleted.'**
  String get deleteAccountWarning;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully'**
  String get accountDeleted;

  /// No description provided for @accountDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account'**
  String get accountDeleteFailed;

  /// No description provided for @phoneNumberUpdated.
  ///
  /// In en, this message translates to:
  /// **'Phone number updated successfully'**
  String get phoneNumberUpdated;

  /// No description provided for @phoneAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'Phone number is already registered'**
  String get phoneAlreadyRegistered;

  /// No description provided for @privacySecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacySecurityTitle;

  /// No description provided for @privacyIntro.
  ///
  /// In en, this message translates to:
  /// **'At LabGo, we are committed to protecting your privacy and ensuring the security of your personal and health information. This policy explains how we collect, use, and protect your data.'**
  String get privacyIntro;

  /// No description provided for @dataWeCollect.
  ///
  /// In en, this message translates to:
  /// **'Data We Collect'**
  String get dataWeCollect;

  /// No description provided for @personalInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'We collect your name, email, phone number, date of birth, and gender to create and manage your account.'**
  String get personalInfoDesc;

  /// No description provided for @healthData.
  ///
  /// In en, this message translates to:
  /// **'Health Data'**
  String get healthData;

  /// No description provided for @healthDataDesc.
  ///
  /// In en, this message translates to:
  /// **'We store your test results, prescriptions, and medical history to provide laboratory services and track your health journey.'**
  String get healthDataDesc;

  /// No description provided for @locationData.
  ///
  /// In en, this message translates to:
  /// **'Location Data'**
  String get locationData;

  /// No description provided for @locationDataDesc.
  ///
  /// In en, this message translates to:
  /// **'We collect your address and location to enable home sample collection services by our nurses.'**
  String get locationDataDesc;

  /// No description provided for @howWeUseData.
  ///
  /// In en, this message translates to:
  /// **'How We Use Your Data'**
  String get howWeUseData;

  /// No description provided for @serviceProvision.
  ///
  /// In en, this message translates to:
  /// **'Service Provision'**
  String get serviceProvision;

  /// No description provided for @serviceProvisionDesc.
  ///
  /// In en, this message translates to:
  /// **'To process your lab test orders, coordinate sample collection, and deliver results.'**
  String get serviceProvisionDesc;

  /// No description provided for @communication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get communication;

  /// No description provided for @communicationDesc.
  ///
  /// In en, this message translates to:
  /// **'To send order updates, result notifications, and important service information.'**
  String get communicationDesc;

  /// No description provided for @serviceImprovement.
  ///
  /// In en, this message translates to:
  /// **'Service Improvement'**
  String get serviceImprovement;

  /// No description provided for @serviceImprovementDesc.
  ///
  /// In en, this message translates to:
  /// **'To analyze usage patterns and improve our app and services.'**
  String get serviceImprovementDesc;

  /// No description provided for @dataProtection.
  ///
  /// In en, this message translates to:
  /// **'Data Protection'**
  String get dataProtection;

  /// No description provided for @sslEncryption.
  ///
  /// In en, this message translates to:
  /// **'SSL Encryption'**
  String get sslEncryption;

  /// No description provided for @sslEncryptionDesc.
  ///
  /// In en, this message translates to:
  /// **'All data transmitted between your device and our servers is encrypted using industry-standard SSL technology.'**
  String get sslEncryptionDesc;

  /// No description provided for @secureStorage.
  ///
  /// In en, this message translates to:
  /// **'Secure Storage'**
  String get secureStorage;

  /// No description provided for @secureStorageDesc.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored on secure servers with restricted access and regular security audits.'**
  String get secureStorageDesc;

  /// No description provided for @accessControl.
  ///
  /// In en, this message translates to:
  /// **'Access Control'**
  String get accessControl;

  /// No description provided for @accessControlDesc.
  ///
  /// In en, this message translates to:
  /// **'Only authorized personnel can access your information on a need-to-know basis.'**
  String get accessControlDesc;

  /// No description provided for @yourRights.
  ///
  /// In en, this message translates to:
  /// **'Your Rights'**
  String get yourRights;

  /// No description provided for @rightToAccess.
  ///
  /// In en, this message translates to:
  /// **'Right to Access'**
  String get rightToAccess;

  /// No description provided for @rightToAccessDesc.
  ///
  /// In en, this message translates to:
  /// **'You can request a copy of all personal data we hold about you at any time.'**
  String get rightToAccessDesc;

  /// No description provided for @rightToCorrection.
  ///
  /// In en, this message translates to:
  /// **'Right to Correction'**
  String get rightToCorrection;

  /// No description provided for @rightToCorrectionDesc.
  ///
  /// In en, this message translates to:
  /// **'You can request corrections to any inaccurate or incomplete information.'**
  String get rightToCorrectionDesc;

  /// No description provided for @rightToDeletion.
  ///
  /// In en, this message translates to:
  /// **'Right to Deletion'**
  String get rightToDeletion;

  /// No description provided for @rightToDeletionDesc.
  ///
  /// In en, this message translates to:
  /// **'You can request deletion of your account and all associated data.'**
  String get rightToDeletionDesc;

  /// No description provided for @dataPortability.
  ///
  /// In en, this message translates to:
  /// **'Data Portability'**
  String get dataPortability;

  /// No description provided for @dataPortabilityDesc.
  ///
  /// In en, this message translates to:
  /// **'You can request your data in a portable format for transfer to another service.'**
  String get dataPortabilityDesc;

  /// No description provided for @privacyContact.
  ///
  /// In en, this message translates to:
  /// **'Privacy Concerns'**
  String get privacyContact;

  /// No description provided for @privacyContactDesc.
  ///
  /// In en, this message translates to:
  /// **'For any privacy-related questions or concerns, please contact us:'**
  String get privacyContactDesc;

  /// No description provided for @helpSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupportTitle;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get faq;

  /// No description provided for @faqHowToOrder.
  ///
  /// In en, this message translates to:
  /// **'How do I place an order?'**
  String get faqHowToOrder;

  /// No description provided for @faqHowToOrderAnswer.
  ///
  /// In en, this message translates to:
  /// **'Browse laboratories in your area, select the tests you need, add them to your cart, choose your preferred address and time, then confirm your order. A nurse will be assigned to collect your sample at home.'**
  String get faqHowToOrderAnswer;

  /// No description provided for @faqPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'What payment methods are accepted?'**
  String get faqPaymentMethods;

  /// No description provided for @faqPaymentMethodsAnswer.
  ///
  /// In en, this message translates to:
  /// **'We currently accept cash on delivery. The nurse will collect payment when they arrive for sample collection.'**
  String get faqPaymentMethodsAnswer;

  /// No description provided for @faqViewResults.
  ///
  /// In en, this message translates to:
  /// **'How do I view my test results?'**
  String get faqViewResults;

  /// No description provided for @faqViewResultsAnswer.
  ///
  /// In en, this message translates to:
  /// **'Once your results are ready, you\'ll receive a notification. Go to the Orders section, select the completed order, and tap \'View Result\' to download or view your results.'**
  String get faqViewResultsAnswer;

  /// No description provided for @faqCancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Can I cancel my order?'**
  String get faqCancelOrder;

  /// No description provided for @faqCancelOrderAnswer.
  ///
  /// In en, this message translates to:
  /// **'Yes, you can cancel your order before a nurse is assigned. Go to Orders, select the pending order, and tap \'Cancel Order\'.'**
  String get faqCancelOrderAnswer;

  /// No description provided for @faqNurseNoShow.
  ///
  /// In en, this message translates to:
  /// **'What if the nurse doesn\'t arrive?'**
  String get faqNurseNoShow;

  /// No description provided for @faqNurseNoShowAnswer.
  ///
  /// In en, this message translates to:
  /// **'Please contact our support team immediately. We will reassign another nurse or process a full refund if needed.'**
  String get faqNurseNoShowAnswer;

  /// No description provided for @faqResultsTime.
  ///
  /// In en, this message translates to:
  /// **'How long does it take to get results?'**
  String get faqResultsTime;

  /// No description provided for @faqResultsTimeAnswer.
  ///
  /// In en, this message translates to:
  /// **'Result times vary by test type. Most routine blood tests are ready within 24-48 hours. Specialized tests may take 3-7 days.'**
  String get faqResultsTimeAnswer;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @phoneSupport.
  ///
  /// In en, this message translates to:
  /// **'Phone Support'**
  String get phoneSupport;

  /// No description provided for @emailSupport.
  ///
  /// In en, this message translates to:
  /// **'Email Support'**
  String get emailSupport;

  /// No description provided for @whatsappSupport.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsappSupport;

  /// No description provided for @supportHours.
  ///
  /// In en, this message translates to:
  /// **'Support Hours'**
  String get supportHours;

  /// No description provided for @supportHoursValue.
  ///
  /// In en, this message translates to:
  /// **'Sunday - Thursday: 8:00 AM - 8:00 PM'**
  String get supportHoursValue;

  /// No description provided for @reportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an Issue'**
  String get reportIssue;

  /// No description provided for @reportIssueDesc.
  ///
  /// In en, this message translates to:
  /// **'Encountered a problem? Let us know and we\'ll fix it as soon as possible.'**
  String get reportIssueDesc;

  /// No description provided for @appTips.
  ///
  /// In en, this message translates to:
  /// **'App Tips'**
  String get appTips;

  /// No description provided for @tipNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications to receive real-time updates about your orders and results.'**
  String get tipNotifications;

  /// No description provided for @tipProfile.
  ///
  /// In en, this message translates to:
  /// **'Keep your profile information updated for accurate service delivery.'**
  String get tipProfile;

  /// No description provided for @tipAddresses.
  ///
  /// In en, this message translates to:
  /// **'Save your frequently used addresses for faster ordering.'**
  String get tipAddresses;

  /// No description provided for @tipRatings.
  ///
  /// In en, this message translates to:
  /// **'Rate your experience after each order to help us improve our services.'**
  String get tipRatings;

  /// No description provided for @aboutAppTitle.
  ///
  /// In en, this message translates to:
  /// **'About LabGo'**
  String get aboutAppTitle;

  /// No description provided for @appDescriptionFull.
  ///
  /// In en, this message translates to:
  /// **'LabGo is your trusted healthcare companion for laboratory services in Iraq. Book tests from top-rated laboratories, get samples collected at your home by professional nurses, and receive your results digitally - all from one convenient app.'**
  String get appDescriptionFull;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @developerName.
  ///
  /// In en, this message translates to:
  /// **'LabGo Healthcare Solutions'**
  String get developerName;

  /// No description provided for @madeInIraq.
  ///
  /// In en, this message translates to:
  /// **'Made with ❤️ in Iraq'**
  String get madeInIraq;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get rateApp;

  /// No description provided for @rateAppDesc.
  ///
  /// In en, this message translates to:
  /// **'Enjoying LabGo? Leave us a review!'**
  String get rateAppDesc;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get shareApp;

  /// No description provided for @shareAppDesc.
  ///
  /// In en, this message translates to:
  /// **'Share LabGo with friends and family'**
  String get shareAppDesc;

  /// No description provided for @shareAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Check out LabGo - the easiest way to book lab tests and get samples collected at home! Download now:'**
  String get shareAppMessage;

  /// No description provided for @copyrightNotice.
  ///
  /// In en, this message translates to:
  /// **'© 2024 LabGo. All rights reserved.'**
  String get copyrightNotice;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordTitle;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @enterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get enterCurrentPassword;

  /// No description provided for @confirmYourNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm your new password'**
  String get confirmYourNewPassword;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChangedSuccess;

  /// No description provided for @currentPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get currentPasswordIncorrect;

  /// No description provided for @newPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'New password must be at least 8 characters'**
  String get newPasswordTooShort;

  /// No description provided for @selectCity.
  ///
  /// In en, this message translates to:
  /// **'Select City'**
  String get selectCity;

  /// No description provided for @pleaseSelectCity.
  ///
  /// In en, this message translates to:
  /// **'Please select your city'**
  String get pleaseSelectCity;

  /// No description provided for @cityUpdated.
  ///
  /// In en, this message translates to:
  /// **'City updated successfully'**
  String get cityUpdated;

  /// No description provided for @browseAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Browse as Guest'**
  String get browseAsGuest;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get loginRequired;

  /// No description provided for @loginToAddToCart.
  ///
  /// In en, this message translates to:
  /// **'Sign in to add items to your cart'**
  String get loginToAddToCart;

  /// No description provided for @loginToViewResults.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your test results'**
  String get loginToViewResults;

  /// No description provided for @loginToAccessProfile.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your profile'**
  String get loginToAccessProfile;

  /// No description provided for @loginToRequestNurse.
  ///
  /// In en, this message translates to:
  /// **'Sign in to request a nurse'**
  String get loginToRequestNurse;

  /// No description provided for @welcomeGuest.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcomeGuest;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @signInForFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Sign in for full access'**
  String get signInForFullAccess;

  /// No description provided for @guestBrowsingMode.
  ///
  /// In en, this message translates to:
  /// **'You are browsing as a guest'**
  String get guestBrowsingMode;

  /// No description provided for @myCustody.
  ///
  /// In en, this message translates to:
  /// **'My Custody'**
  String get myCustody;

  /// No description provided for @custodyEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No custody items assigned to you yet'**
  String get custodyEmptyState;

  /// No description provided for @custodyStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get custodyStatusAvailable;

  /// No description provided for @custodyStatusInUse.
  ///
  /// In en, this message translates to:
  /// **'In Use'**
  String get custodyStatusInUse;

  /// No description provided for @custodyStatusPendingReturn.
  ///
  /// In en, this message translates to:
  /// **'Pending Return'**
  String get custodyStatusPendingReturn;

  /// No description provided for @custodyStatusReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get custodyStatusReturned;

  /// No description provided for @custodyStatusDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get custodyStatusDamaged;

  /// No description provided for @custodyStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get custodyStatusMissing;

  /// No description provided for @custodyStatusNeedsMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Needs Maintenance'**
  String get custodyStatusNeedsMaintenance;

  /// No description provided for @custodyCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get custodyCode;

  /// No description provided for @custodyQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get custodyQuantity;

  /// No description provided for @custodyValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get custodyValue;

  /// No description provided for @custodyAssignedDate.
  ///
  /// In en, this message translates to:
  /// **'Assigned On'**
  String get custodyAssignedDate;

  /// No description provided for @returnItem.
  ///
  /// In en, this message translates to:
  /// **'Return Item'**
  String get returnItem;

  /// No description provided for @scanQrToConfirmReturn.
  ///
  /// In en, this message translates to:
  /// **'Scan the item\'s QR code to confirm the return'**
  String get scanQrToConfirmReturn;

  /// No description provided for @itemCondition.
  ///
  /// In en, this message translates to:
  /// **'Item Condition'**
  String get itemCondition;

  /// No description provided for @conditionOk.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get conditionOk;

  /// No description provided for @conditionDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get conditionDamaged;

  /// No description provided for @conditionMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get conditionMissing;

  /// No description provided for @custodyReturnedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Item returned successfully'**
  String get custodyReturnedSuccessfully;

  /// No description provided for @custodyCodeMismatch.
  ///
  /// In en, this message translates to:
  /// **'The scanned code does not match this item'**
  String get custodyCodeMismatch;

  /// No description provided for @confirmReturn.
  ///
  /// In en, this message translates to:
  /// **'Confirm Return'**
  String get confirmReturn;

  /// No description provided for @healthMattersTagline.
  ///
  /// In en, this message translates to:
  /// **'Your health matters to us'**
  String get healthMattersTagline;

  /// No description provided for @notificationsFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Notifications coming soon'**
  String get notificationsFeatureComingSoon;

  /// No description provided for @wishlistFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Wishlist coming soon'**
  String get wishlistFeatureComingSoon;

  /// No description provided for @recommendedLaboratories.
  ///
  /// In en, this message translates to:
  /// **'Recommended Laboratories'**
  String get recommendedLaboratories;

  /// No description provided for @recentOrders.
  ///
  /// In en, this message translates to:
  /// **'Recent Orders'**
  String get recentOrders;

  /// No description provided for @bookFromThisLab.
  ///
  /// In en, this message translates to:
  /// **'Book from this lab'**
  String get bookFromThisLab;

  /// No description provided for @addToOrder.
  ///
  /// In en, this message translates to:
  /// **'Add to order'**
  String get addToOrder;

  /// No description provided for @therapeuticPrescription.
  ///
  /// In en, this message translates to:
  /// **'Medical prescription'**
  String get therapeuticPrescription;

  /// No description provided for @digitalResults.
  ///
  /// In en, this message translates to:
  /// **'Digital results'**
  String get digitalResults;

  /// No description provided for @homeCollection.
  ///
  /// In en, this message translates to:
  /// **'Home collection'**
  String get homeCollection;

  /// No description provided for @accredited.
  ///
  /// In en, this message translates to:
  /// **'Accredited'**
  String get accredited;

  /// No description provided for @nearestAppointment.
  ///
  /// In en, this message translates to:
  /// **'Nearest appointment'**
  String get nearestAppointment;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get workingHours;

  /// No description provided for @defaultWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'8 AM – 10 PM'**
  String get defaultWorkingHours;

  /// No description provided for @trackYourOrderLive.
  ///
  /// In en, this message translates to:
  /// **'Track your order live'**
  String get trackYourOrderLive;

  /// No description provided for @technicianOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'The technician is on the way to you'**
  String get technicianOnTheWay;

  /// No description provided for @allOrders.
  ///
  /// In en, this message translates to:
  /// **'All orders'**
  String get allOrders;

  /// No description provided for @sampleLabel.
  ///
  /// In en, this message translates to:
  /// **'Sample label'**
  String get sampleLabel;

  /// No description provided for @invoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;

  /// No description provided for @chooseLaboratory.
  ///
  /// In en, this message translates to:
  /// **'Choose laboratory'**
  String get chooseLaboratory;

  /// No description provided for @chooseTests.
  ///
  /// In en, this message translates to:
  /// **'Choose tests'**
  String get chooseTests;

  /// No description provided for @chooseAppointment.
  ///
  /// In en, this message translates to:
  /// **'Choose appointment'**
  String get chooseAppointment;

  /// No description provided for @orderInformation.
  ///
  /// In en, this message translates to:
  /// **'Order information'**
  String get orderInformation;

  /// No description provided for @confirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get confirmation;

  /// No description provided for @labsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} labs'**
  String labsCount(int count);

  /// No description provided for @testsSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String testsSelectedCount(int count);

  /// No description provided for @testsSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} tests selected'**
  String testsSelectedLabel(int count);

  /// No description provided for @availableTimes.
  ///
  /// In en, this message translates to:
  /// **'Available times'**
  String get availableTimes;

  /// No description provided for @orderConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your order is confirmed'**
  String get orderConfirmedTitle;

  /// No description provided for @orderConfirmedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A sample collection technician will arrive at your location at the scheduled time.'**
  String get orderConfirmedSubtitle;

  /// No description provided for @trackOrder.
  ///
  /// In en, this message translates to:
  /// **'Track order'**
  String get trackOrder;

  /// No description provided for @viewInvoice.
  ///
  /// In en, this message translates to:
  /// **'View invoice'**
  String get viewInvoice;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @pleaseSelectLab.
  ///
  /// In en, this message translates to:
  /// **'Please choose a laboratory'**
  String get pleaseSelectLab;

  /// No description provided for @pleaseSelectTests.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one test'**
  String get pleaseSelectTests;

  /// No description provided for @pleaseSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Please choose an appointment'**
  String get pleaseSelectDate;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get orderNumber;

  /// No description provided for @noTestsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No tests available at this laboratory'**
  String get noTestsAvailable;

  /// No description provided for @sampleCollectionTechnician.
  ///
  /// In en, this message translates to:
  /// **'Sample collection technician'**
  String get sampleCollectionTechnician;

  /// No description provided for @noPackagesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No packages available'**
  String get noPackagesAvailable;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String reviewsCount(int count);

  /// No description provided for @searchOrders.
  ///
  /// In en, this message translates to:
  /// **'Search orders'**
  String get searchOrders;

  /// No description provided for @invoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice number'**
  String get invoiceNumber;

  /// No description provided for @invoiceConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get invoiceConfirmed;

  /// No description provided for @invoiceCancelledStatus.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get invoiceCancelledStatus;

  /// No description provided for @downloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPdf;

  /// No description provided for @printInvoice.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get printInvoice;

  /// No description provided for @patient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patient;

  /// No description provided for @laboratory.
  ///
  /// In en, this message translates to:
  /// **'Laboratory'**
  String get laboratory;

  /// No description provided for @invoiceTests.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get invoiceTests;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// No description provided for @cashOnCollection.
  ///
  /// In en, this message translates to:
  /// **'Cash on collection'**
  String get cashOnCollection;

  /// No description provided for @bankCard.
  ///
  /// In en, this message translates to:
  /// **'Bank card'**
  String get bankCard;

  /// No description provided for @grandTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get grandTotal;

  /// No description provided for @invoiceTestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tests'**
  String invoiceTestsCount(int count);

  /// No description provided for @shareInvoice.
  ///
  /// In en, this message translates to:
  /// **'Share invoice'**
  String get shareInvoice;

  /// No description provided for @invoiceShareMessage.
  ///
  /// In en, this message translates to:
  /// **'LabGo invoice {invoiceNumber}\nAmount: {amount} IQD'**
  String invoiceShareMessage(String invoiceNumber, String amount);

  /// No description provided for @invoicePdfError.
  ///
  /// In en, this message translates to:
  /// **'Could not create the PDF. Please try again.'**
  String get invoicePdfError;

  /// No description provided for @noResultsYet.
  ///
  /// In en, this message translates to:
  /// **'No results yet'**
  String get noResultsYet;

  /// No description provided for @noResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Results appear here after the laboratory sends them.'**
  String get noResultsSubtitle;

  /// No description provided for @openResult.
  ///
  /// In en, this message translates to:
  /// **'Open result'**
  String get openResult;

  /// No description provided for @resultFile.
  ///
  /// In en, this message translates to:
  /// **'Result file'**
  String get resultFile;

  /// No description provided for @sampleCode.
  ///
  /// In en, this message translates to:
  /// **'Sample code'**
  String get sampleCode;

  /// No description provided for @sampleDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get sampleDate;

  /// No description provided for @printLabel.
  ///
  /// In en, this message translates to:
  /// **'Print label'**
  String get printLabel;

  /// No description provided for @stickOnSample.
  ///
  /// In en, this message translates to:
  /// **'Stick this label on the sample tube before sending it to the lab'**
  String get stickOnSample;

  /// addedToFavorites
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get addedToFavorites;

  /// removedFromFavorites
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get removedFromFavorites;

  /// noFavoriteLabsYet
  ///
  /// In en, this message translates to:
  /// **'No favorite labs yet'**
  String get noFavoriteLabsYet;

  /// favoritesHint
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any lab to save it here'**
  String get favoritesHint;

  /// loginToUseFavorites
  ///
  /// In en, this message translates to:
  /// **'Sign in to save your favorite labs'**
  String get loginToUseFavorites;

  /// noNotificationsYet
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// notificationsHint
  ///
  /// In en, this message translates to:
  /// **'We\'ll let you know when something needs your attention'**
  String get notificationsHint;

  /// markAllAsRead
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllAsRead;

  /// loginToViewNotifications
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your notifications'**
  String get loginToViewNotifications;

  /// ageYears
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get ageYears;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en', 'ku', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
    case 'ku': return AppLocalizationsKu();
    case 'tr': return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
